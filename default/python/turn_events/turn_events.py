from logging import error, info

from common.configure_logging import redirect_logging_to_freeorion_logger

# Logging is redirected before other imports so that import errors appear in log files.
redirect_logging_to_freeorion_logger()

import freeorion as fo
import sys
from math import cos, pi, sin
from random import choice, random, uniform

import asyncio
import aiohttp
import psycopg2
import psycopg2.extensions

from universe_tables import MONSTER_FREQUENCY

psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)


async def send_xmpp(text: str):
    try:
        async with aiohttp.ClientSession() as session:
            info(f"Sending {text} to chat...")
            await session.post("http://localhost:8083/", data=text, headers={"X-XMPP-Muc": "smac"})
        info("Chat notification was send via XMPP")
    except Exception:
         exctype, value = sys.exc_info()[:2]
         error(f"Cann't send chat notification: {exctype} {value}")


def execute_turn_events():
    print("Executing turn events for turn", fo.current_turn())

    if fo.get_options_db_option_bool("network.server.send-turn-chat"):
        try:
            loop = asyncio.get_event_loop()
            loop.create_task(send_xmpp("%s: Turn %d has come to an end." % (fo.get_galaxy_setup_data().gameUID, fo.current_turn())), name="XMPPTurn")
        except Exception:
            exctype, value = sys.exc_info()[:2]
            error(f"Cann't send chat notification: {exctype} {value}")

    try:
        dsn = ""
        with open(fo.get_user_config_dir() + "/db.txt") as f:
            for line in f:
                dsn = line
                break
        conn = psycopg2.connect(dsn)
        with conn:
            with conn.cursor() as curs:
                curs.execute(
                    """INSERT INTO games.turns(game_uid, turn, turn_ts) VALUES(%s, %s,
                        NOW()::timestamp)
                                ON CONFLICT (game_uid, turn) DO UPDATE SET turn_ts =
                                EXCLUDED.turn_ts""",
                    (fo.get_galaxy_setup_data().gameUID, fo.current_turn()),
                )
    except Exception:
        exctype, value = sys.exc_info()[:2]
        error(f"Cann't update turn time: {exctype} {value}")

    # creating fields
    systems = fo.get_systems()
    radius = fo.get_universe_width() / 2.0
    field_types = ["FLD_MOLECULAR_CLOUD", "FLD_ION_STORM", "FLD_NANITE_SWARM", "FLD_METEOR_BLIZZARD", "FLD_VOID_RIFT"]

    if random() < max(0.00015 * radius, 0.03):
        field_type = choice(field_types)
        size = 5.0
        dist_from_center = uniform(0.35, 1.0) * radius
        angle = random() * 2.0 * pi
        x = radius + (dist_from_center * sin(angle))
        y = radius + (dist_from_center * cos(angle))

        print("...creating new", field_type, "field, at distance", dist_from_center, "from center")
        if fo.create_field(field_type, x, y, size) == fo.invalid_object():
            print("Turn events: couldn't create new field", file=sys.stderr)

    # creating monsters
    gsd = fo.get_galaxy_setup_data()
    monster_freq = MONSTER_FREQUENCY[gsd.monsterFrequency]
    # monster freq ranges from 0.0 .. 1/30 (= one monster per 30 systems) .. 1/3 (= one monster per 3 systems) .. 99/100 (almost everywhere)
    # (example: low monsters and 150 Systems results in 150 / 30 * 0.01 = 0.05)
    if monster_freq > 0 and random() < len(systems) * monster_freq * 0.01:
        # only spawn Krill at the moment, other monsters can follow in the future
        if random() < 1:
            monster_type = "SM_KRILL_1"
        else:
            monster_type = "SM_FLOATER"

        # search for systems without planets or fleets
        candidates = [s for s in systems if len(fo.sys_get_planets(s)) <= 0 and len(fo.sys_get_fleets(s)) <= 0]
        if not candidates:
            print("Turn events: unable to find system for monster spawn", file=sys.stderr)
        else:
            system = choice(candidates)
            print("...creating new", monster_type, "at", fo.get_name(system))

            # create monster fleet
            monster_fleet = fo.create_monster_fleet(system)
            # if fleet creation fails, report an error
            if monster_fleet == fo.invalid_object():
                print("Turn events: unable to create new monster fleet", file=sys.stderr)
            else:
                # create monster, if creation fails, report an error
                monster = fo.create_monster(monster_type, monster_fleet)
                if monster == fo.invalid_object():
                    print("Turn events: unable to create monster in fleet", file=sys.stderr)

    return True
