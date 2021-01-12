from collections import Counter
from logging import warning, error

import freeOrionAIInterface as fo
import FleetUtilsAI
from aistate_interface import get_aistate
from EnumsAI import MissionType
from freeorion_tools import dict_to_tuple, tuple_to_dict, cache_for_current_turn
from ShipDesignAI import get_ship_part
from AIDependencies import INVALID_ID, CombatTarget
from freeorion_tools import combine_ratings

_issued_errors = []


def get_allowed_targets(partname: str) -> int:
    """Return the allowed targets for a given hangar or shortrange weapon"""
    try:
        return CombatTarget.PART_ALLOWED_TARGETS[partname]
    except KeyError:
        if partname not in _issued_errors:
            error("AI has no targeting information for weapon part %s. Will assume any target allowed."
                  "Please update CombatTarget.PART_ALLOWED_TARGETS in AIDependencies.py ")
            _issued_errors.append(partname)
        return CombatTarget.ANY


@cache_for_current_turn
def get_empire_standard_military_ship_stats():
    """Get the current empire standard military ship stats, i.e. the most common ship type within the empire.

    :return: Stats of most common military ship in the empire
    :rtype: ShipCombatStats
    """
    stats_dict = Counter()
    for fleet_id in FleetUtilsAI.get_empire_fleet_ids_by_role(MissionType.MILITARY):
        ship_stats = FleetCombatStats(fleet_id, max_stats=True).get_ship_combat_stats()
        stats_dict.update(ship_stats)

    most_commons = stats_dict.most_common(1)
    if most_commons:
        return most_commons[0][0]
    else:
        return default_ship_stats()


def default_ship_stats():
    """ Return some ship stats to assume if no other intel is available.

    :return: Some weak standard ship
    :rtype: ShipCombatStats
    """
    attacks = (6.0, 1)
    structure = 15
    shields = 0
    fighters = 0
    launch_rate = 0
    fighter_damage = 0
    flak_shots = 0
    has_interceptors = False
    damage_vs_planets = 0
    has_bomber = False
    return ShipCombatStats(stats=(attacks, structure, shields,
                                  fighters, launch_rate, fighter_damage,
                                  flak_shots, has_interceptors,
                                  damage_vs_planets, has_bomber))


class ShipCombatStats:
    """Stores all relevant stats of a ship for combat strength evaluation."""
    class BasicStats:
        """Stores non-fighter-related stats."""
        def __init__(self, attacks, structure, shields):
            """

            :param attacks:
            :type attacks: dict[float, int]|None
            :param structure:
            :type structure: int|None
            :param shields:
            :type shields: int|None
            :return:
            """
            self.structure = 1.0 if structure is None else structure
            self.shields = 0.0 if shields is None else shields
            self.attacks = {} if attacks is None else tuple_to_dict(attacks)  # type: dict[float, int]

        def get_stats(self, hashable=False):
            """

            :param hashable: if hashable, return tuple instead of attacks-dict
            :return: attacks, structure, shields
            """
            if not hashable:
                return self.attacks, self.structure, self.shields
            else:
                return dict_to_tuple(self.attacks), self.structure, self.shields

        def __str__(self):
            return str(self.get_stats())

    class FighterStats:
        """ Stores fighter-related stats """
        def __init__(self, capacity, launch_rate, damage):
            self.capacity = capacity
            self.launch_rate = launch_rate
            self.damage = damage

        def __str__(self):
            return str(self.get_stats())

        def get_stats(self):
            """
            :return: capacity, launch_rate, damage
            """
            return self.capacity, self.launch_rate, self.damage

    class AntiFighterStats:
        def __init__(self, flak_shots: int, has_interceptors: bool):
            """
            :param flak_shots: number of shots per bout with flak weapon part
            :param has_interceptors: true if mounted hangar parts have interceptor ability (interceptors/fighters)
            """
            self.flak_shots = flak_shots
            self.has_interceptors = has_interceptors

        def __str__(self):
            return str(self.get_stats())

        def get_stats(self):
            """
            :return: flak_shots, has_interceptors
            """
            return self.flak_shots, self.has_interceptors

    class AntiPlanetStats:
        def __init__(self, damage_vs_planets, has_bomber):
            self.damage_vs_planets = damage_vs_planets
            self.has_bomber = has_bomber

        def get_stats(self):
            return self.damage_vs_planets, self.has_bomber

        def __str__(self):
            return str(self.get_stats())

    def __init__(self, ship_id=INVALID_ID, max_stats=False, stats=None):
        self.__ship_id = ship_id
        self._max_stats = max_stats
        if stats:
            self._basic_stats = self.BasicStats(*stats[0:3])  # TODO: Should probably determine size dynamically
            self._fighter_stats = self.FighterStats(*stats[3:6])
            self._anti_fighter_stats = self.AntiFighterStats(*stats[6:8])
            self._anti_planet_stats = self.AntiPlanetStats(*stats[8:])
        else:
            self._basic_stats = self.BasicStats(None, None, None)
            self._fighter_stats = self.FighterStats(None, None, None)
            self._anti_fighter_stats = self.AntiFighterStats(0, False)
            self._anti_planet_stats = self.AntiPlanetStats(0, False)
            self.__get_stats_from_ship()

    def __hash__(self):
        return hash(self.get_basic_stats(hashable=True))

    def __str__(self):
        return str(self.get_stats())

    def __get_stats_from_ship(self):
        """Read and store combat related stats from ship"""
        universe = fo.getUniverse()
        ship = universe.getShip(self.__ship_id)
        if not ship:
            return  # TODO: Add some estimate for stealthed ships

        if self._max_stats:
            structure = ship.initialMeterValue(fo.meterType.maxStructure)
            shields = ship.initialMeterValue(fo.meterType.maxShield)
        else:
            structure = ship.initialMeterValue(fo.meterType.structure)
            shields = ship.initialMeterValue(fo.meterType.shield)
        attacks = {}
        fighter_launch_rate = 0
        fighter_capacity = 0
        fighter_damage = 0
        flak_shots = 0
        has_bomber = False
        has_interceptors = False
        damage_vs_planets = 0
        design = ship.design
        if design and (ship.isArmed or ship.hasFighters):
            meter_choice = fo.meterType.maxCapacity if self._max_stats else fo.meterType.capacity
            for partname in design.parts:
                if not partname:
                    continue
                pc = get_ship_part(partname).partClass
                if pc == fo.shipPartClass.shortRange:
                    allowed_targets = get_allowed_targets(partname)
                    damage = ship.currentPartMeterValue(meter_choice, partname)
                    shots = ship.currentPartMeterValue(fo.meterType.secondaryStat, partname)
                    if allowed_targets & CombatTarget.SHIP:
                        attacks[damage] = attacks.get(damage, 0) + shots
                    if allowed_targets & CombatTarget.FIGHTER:
                        flak_shots += 1
                    if allowed_targets & CombatTarget.PLANET:
                        damage_vs_planets += damage * shots
                elif pc == fo.shipPartClass.fighterBay:
                    fighter_launch_rate += ship.currentPartMeterValue(fo.meterType.capacity, partname)
                elif pc == fo.shipPartClass.fighterHangar:
                    allowed_targets = get_allowed_targets(partname)
                    # for hangars, capacity meter is already counting contributions from ALL hangars.
                    fighter_capacity = ship.currentPartMeterValue(meter_choice, partname)
                    part_damage = ship.currentPartMeterValue(fo.meterType.secondaryStat, partname)
                    if part_damage != fighter_damage and fighter_damage > 0:
                        # the C++ code fails also in this regard, so FOCS content *should* not allow this.
                        # TODO: Depending on future implementation, might actually need to handle this case.
                        warning("Multiple hangar types present on one ship, estimates expected to be wrong.")
                    if allowed_targets & CombatTarget.SHIP:
                        fighter_damage = max(fighter_damage, part_damage)
                    if allowed_targets & CombatTarget.PLANET:
                        has_bomber = True
                    if allowed_targets & CombatTarget.FIGHTER:
                        has_interceptors = True

        self._basic_stats = self.BasicStats(attacks, structure, shields)
        self._fighter_stats = self.FighterStats(fighter_capacity, fighter_launch_rate, fighter_damage)
        self._anti_fighter_stats = self.AntiFighterStats(flak_shots, has_interceptors)
        self._anti_planet_stats = self.AntiPlanetStats(damage_vs_planets, has_bomber)

    def get_basic_stats(self, hashable=False):
        """Get non-fighter-related combat stats of the ship.

        :param hashable: if true, returns tuple instead of attacks-dict
        :return: attacks, structure, shields
        :rtype: (dict|tuple, float, float)
        """
        return self._basic_stats.get_stats(hashable=hashable)

    def get_fighter_stats(self):
        """ Get fighter related combat stats
        :return: capacity, launch_rate, damage
        """
        return self._fighter_stats.get_stats()

    def get_anti_fighter_stats(self):
        """Get anti-fighter related stats
        :return: flak_shots, has_interceptors
        """
        return self._anti_fighter_stats.get_stats()

    def get_anti_planet_stats(self):
        return self._anti_planet_stats.get_stats()

    def get_rating(self, enemy_stats=None, ignore_fighters=False):
        """Calculate a rating against specified enemy.

        If no enemy is specified, will rate against the empire standard enemy

        :param enemy_stats: Enemy stats to be rated against - if None
        :type enemy_stats: ShipCombatStats
        :param ignore_fighters: If True, acts as if fighters are not launched
        :type ignore_fighters: bool
        :return: rating against specified enemy
        :rtype: float
        """
        # adjust base stats according to enemy stats
        def _rating():
            return my_total_attack * my_structure

        # The fighter rating calculations are heavily based upon the enemy stats.
        # So, for now, we compare at least against a certain standard enemy.
        enemy_stats = enemy_stats or get_aistate().get_standard_enemy()
        my_attacks, my_structure, my_shields = self.get_basic_stats()
        # e_avg_attack = 1
        if enemy_stats:
            e_attacks, e_structure, e_shields = enemy_stats.get_basic_stats()
            my_structure *= self.__calculate_shield_factor(e_attacks, my_shields)
            my_total_attack = sum(n*max(dmg - e_shields, .001) for dmg, n in my_attacks.items())
        else:
            my_total_attack = sum(n*dmg for dmg, n in my_attacks.items())
            my_structure += my_shields

        if ignore_fighters:
            return _rating()
        my_total_attack += self.estimate_fighter_damage()

        # TODO: Consider enemy fighters

        return _rating()

    def __calculate_shield_factor(self, e_attacks: dict, my_shields: float) -> float:
        """
        Calculates shield factor based on enemy attacks and our shields.

        It is possible to have e_attacks with number attacks == 0,
        in that case we consider that there is an issue with the enemy stats and we jut set value to 1.0.
        """
        if not e_attacks:
            return 1.0
        e_total_attack = sum(n * dmg for dmg, n in e_attacks.items())
        if e_total_attack:
            e_net_attack = sum(n * max(dmg - my_shields, .001) for dmg, n in e_attacks.items())
            e_net_attack = max(e_net_attack, .1 * e_total_attack)
            shield_factor = e_total_attack / e_net_attack
            return max(1.0, shield_factor)
        else:
            return 1.0

    def estimate_fighter_damage(self):
        capacity, launch_rate, fighter_damage = self.get_fighter_stats()
        if launch_rate == 0:
            return 0
        full_launch_bouts = capacity // launch_rate
        survival_rate = 0.2  # TODO estimate chance of a fighter not to be shot down in a bout
        flying_fighters = 0
        total_fighter_damage = 0
        # Cut that values down to a single turn (four bouts means max three launch bouts)
        num_bouts = fo.getGameRules().getInt("RULE_NUM_COMBAT_ROUNDS")
        for firing_bout in range(num_bouts - 1):
            if firing_bout < full_launch_bouts:
                flying_fighters = (flying_fighters * survival_rate) + launch_rate
            elif firing_bout == full_launch_bouts:
                # now handle a bout with lower capacity launch
                flying_fighters = (flying_fighters * survival_rate) + (capacity % launch_rate)
            else:
                flying_fighters = (flying_fighters * survival_rate)
            total_fighter_damage += fighter_damage * flying_fighters
        return total_fighter_damage / num_bouts

    def get_rating_vs_planets(self):
        """Heuristic to estimate combat strength against planets"""
        damage = self._anti_planet_stats.damage_vs_planets
        if self._anti_planet_stats.has_bomber:
            damage += self.estimate_fighter_damage()
        return damage * (self._basic_stats.structure + self._basic_stats.shields)

    def get_stats(self, hashable=False):
        """ Get all combat related stats of the ship.

        :param hashable: if true, return tuple instead of dict for attacks
        :return: attacks, structure, shields, fighter-capacity, fighter-launch_rate, fighter-damage
        """
        return (self.get_basic_stats(hashable=hashable) + self.get_fighter_stats()
                + self.get_anti_fighter_stats() + self.get_anti_planet_stats())


class FleetCombatStats:
    """Stores combat related stats of the fleet."""
    def __init__(self, fleet_id=INVALID_ID, max_stats=False):
        self.__fleet_id = fleet_id
        self._max_stats = max_stats
        self.__ship_stats = []
        self.__get_stats_from_fleet()

    def get_ship_stats(self, hashable=False):
        """Get combat stats of all ships in fleet.

        :param hashable: if true, returns tuple instead of dict for attacks
        :type hashable: bool
        :return: list of ship stats
        :rtype: list
        """
        return map(lambda x: x.get_stats(hashable=hashable), self.__ship_stats)

    def get_ship_combat_stats(self):
        """Returns list of ShipCombatStats of fleet."""
        return list(self.__ship_stats)

    def get_rating(self, enemy_stats=None, ignore_fighters=False):
        """Calculates the rating of the fleet by combining all its ships ratings.

        :param enemy_stats: enemy to be rated against
        :type enemy_stats: ShipCombatStats
        :param ignore_fighters: If True, acts as if fighters are not launched
        :type ignore_fighters: bool
        :return: Rating of the fleet
        :rtype: float
        """
        return combine_ratings(x.get_rating(enemy_stats, ignore_fighters) for x in self.__ship_stats)

    def get_rating_vs_planets(self):
        return combine_ratings(x.get_rating_vs_planets() for x in self.__ship_stats)

    def __get_stats_from_fleet(self):
        """Calculate fleet combat stats (i.e. the stats of all its ships)."""
        universe = fo.getUniverse()
        fleet = universe.getFleet(self.__fleet_id)
        if not fleet:
            return
        for ship_id in fleet.shipIDs:
            self.__ship_stats.append(ShipCombatStats(ship_id, self._max_stats))


def get_fleet_rating(fleet_id, enemy_stats=None):
    """Get rating for the fleet against specified enemy.

    :param fleet_id: fleet to be rated
    :type fleet_id: int
    :param enemy_stats: enemy to be rated against
    :type enemy_stats: ShipCombatStats
    :return: Rating
    :rtype: float
    """
    return FleetCombatStats(fleet_id, max_stats=False).get_rating(enemy_stats)


def get_fleet_rating_against_planets(fleet_id):
    return FleetCombatStats(fleet_id, max_stats=False).get_rating_vs_planets()


def get_ship_rating(ship_id, enemy_stats=None):
    return ShipCombatStats(ship_id, max_stats=False).get_rating(enemy_stats)


def weight_attack_troops(troops, grade):
    """Re-weights troops on a ship based on species piloting grade.

    :type troops: float
    :type grade: str
    :return: piloting grade weighted troops
    :rtype: float
    """
    weight = {'NO': 0.0, 'BAD': 0.5, '': 1.0, 'GOOD': 1.5, 'GREAT': 2.0, 'ULTIMATE': 3.0}.get(grade, 1.0)
    return troops * weight


def weight_shields(shields, grade):
    """Re-weights shields based on species defense bonus."""
    offset = {'NO': 0, 'BAD': 0, '': 0, 'GOOD': 1.0, 'GREAT': 0, 'ULTIMATE': 0}.get(grade, 0)
    return shields + offset


def rating_needed(target, current=0):
    """Estimate the needed rating to achieve target rating.

    :param target: Target rating to be reached
    :type target: float
    :param current: Already existing rating
    :type current: float
    :return: Estimated missing rating to reach target
    :rtype: float
    """
    if current >= target or target <= 0:
        return 0
    else:
        return target + current - 2 * (target * current)**0.5


def rating_difference(first_rating, second_rating):

    """Return the absolute nonlinear difference between ratings.

    :param first_rating: rating of a first force
    :type first_rating: float
    :param second_rating: rating of a second force
    :type second_rating: float
    :return: Estimated rating by which the greater force (nonlinearly) exceeds the lesser
    :rtype: float
    """

    return rating_needed(max(first_rating, second_rating), min(first_rating, second_rating))
