#ifndef _CombatSystem_h_
#define _CombatSystem_h_

#include "../universe/Universe.h"
#include "../universe/ScriptingContext.h"
#include "CombatEvent.h"


/** Contains information about the state of a combat before or after the combat occurs. */
struct CombatInfo {
public:
    /** Assembles objects from \a universe_ that are in the system with ID
      * system_id_ and puts them into a new ObjectMap, without the rest of
      * the Universe contents. */
    CombatInfo(int system_id_, int turn_,
               Universe& universe_,
               EmpireManager& empires_,
               const EmpireManager::DiploStatusMap& diplo_statuses_,
               const GalaxySetupData& galaxy_setup_data_,
               SpeciesManager& species_,
               const SupplyManager& supply_);

    /** Returns System object in this CombatInfo's objects if one exists with id system_id. */
    std::shared_ptr<const System> GetSystem() const;

    /** Returns System object in this CombatInfo's objects if one exists with id system_id. */
    std::shared_ptr<System> GetSystem();

    std::shared_ptr<const Empire> GetEmpire(int id) const;
    std::shared_ptr<Empire> GetEmpire(int id);

    const Universe&                                universe; // universe in which combat occurs, used for general info getting, but not object state info
    EmpireManager&                                 empires;
    const Universe::EmpireObjectVisibilityTurnMap& empire_object_vis_turns;
    const EmpireManager::DiploStatusMap&           diplo_statuses;
    const GalaxySetupData&                         galaxy_setup_data;
    SpeciesManager&                                species;
    const SupplyManager&                           supply;

    ObjectMap                           objects;                       ///< actual state of objects relevant to combat, filtered and copied for system where combat occurs, not necessarily consistent with contents of universe's ObjectMap
    Universe::EmpireObjectVisibilityMap empire_object_visibility;      ///< indexed by empire id and object id, the visibility level the empire has of each object.  may be increased during battle
    int                                 bout = 0;                      ///< current combat bout, used with CombatBout ValueRef for implementing bout dependent targeting. First combat bout is 1
    int                                 turn = INVALID_GAME_TURN;      ///< main game turn
    int                                 system_id = INVALID_OBJECT_ID; ///< ID of system where combat is occurring (could be INVALID_OBJECT_ID ?)
    std::set<int>                       empire_ids;                    ///< IDs of empires involved in combat
    std::set<int>                       damaged_object_ids;            ///< ids of objects damaged during this battle
    std::set<int>                       destroyed_object_ids;          ///< ids of objects destroyed during this battle
    std::map<int, std::set<int>>        destroyed_object_knowers;      ///< indexed by empire ID, the set of ids of objects the empire knows were destroyed during the combat
    std::vector<CombatEventPtr>         combat_events;                 ///< list of combat attack events that occur in combat

    float GetMonsterDetection() const;

private:
    void    GetEmpireIdsToSerialize(             std::set<int>&                         filtered_empire_ids,                int encoding_empire) const;
    void    GetObjectsToSerialize(               ObjectMap&                             filtered_objects,                   int encoding_empire) const;
    void    GetDamagedObjectsToSerialize(        std::set<int>&                         filtered_damaged_objects,           int encoding_empire) const;
    void    GetDestroyedObjectsToSerialize(      std::set<int>&                         filtered_destroyed_objects,         int encoding_empire) const;
    void    GetDestroyedObjectKnowersToSerialize(std::map<int, std::set<int>>&          filtered_destroyed_object_knowers,  int encoding_empire) const;
    void    GetEmpireObjectVisibilityToSerialize(Universe::EmpireObjectVisibilityMap&   filtered_empire_object_visibility,  int encoding_empire) const;
    void    GetCombatEventsToSerialize(          std::vector<CombatEventPtr>&           filtered_combat_events,             int encoding_empire) const;

    void    InitializeObjectVisibility();

    template <typename Archive>
    friend void serialize(Archive&, CombatInfo&, unsigned int const);
};

/** Auto-resolves a battle. */
void AutoResolveCombat(CombatInfo& combat_info);



#endif
