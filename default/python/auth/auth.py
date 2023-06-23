from logging import error, info, warning

from common.configure_logging import redirect_logging_to_freeorion_logger

# Logging is redirected before other imports so that import errors appear in log files.
redirect_logging_to_freeorion_logger()


import asyncio
import email
import freeorion as fo
import random
import sys

import aiohttp
import aiosmtplib
import psycopg2
import psycopg2.extensions

psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)

import configparser

# Constants defined by the C++ game engine
NO_TEAM_ID = -1


class AuthProvider:
    def __init__(self):
        self.dsn = ""
        with open(fo.get_user_config_dir() + "/db.txt") as f:
            for line in f:
                self.dsn = line
                break
        self.dsn_ro = self.dsn
        try:
            with open(fo.get_user_config_dir() + "/db-ro.txt") as f:
                for line in f:
                    self.dsn_ro = line
                    break
        except OSError:
            exctype, value = sys.exc_info()[:2]
            warning(f"Read RO DSN: {exctype} {value}")
        self.conn = psycopg2.connect(self.dsn)
        self.conn_ro = psycopg2.connect(self.dsn_ro)
        self.roles_symbols = {
            "h": fo.roleType.host,
            "m": fo.roleType.clientTypeModerator,
            "p": fo.roleType.clientTypePlayer,
            "o": fo.roleType.clientTypeObserver,
            "g": fo.roleType.galaxySetup,
        }
        self.default_roles = [fo.roleType.clientTypePlayer]
        self.mailconf = configparser.ConfigParser()
        self.mailconf.read(fo.get_user_config_dir() + "/mail.cfg")

        info("Auth initialized")

    def __parse_roles(self, roles_str):
        roles = []
        for c in roles_str:
            r = self.roles_symbols.get(c)
            if r is None:
                warning("unknown role symbol '%c'" % c)
            else:
                roles.append(r)
        return roles

    async def __send_email(self, recipient, player_name, subject, text):
        try:
            message = email.message.EmailMessage()
            message["From"] = self.mailconf.get("mail", "from")
            message["To"] = recipient
            message["Subject"] = subject
            message.set_content(text)

            await aiosmtplib.send(
                message,
                hostname=self.mailconf.get("mail", "server"),
                port=465,
                use_tls=True,
                username=self.mailconf.get("mail", "login"),
                password=self.mailconf.get("mail", "passwd"),
            )
            info("OTP was send to %s via email" % player_name)
        except Exception:
            exctype, value = sys.exc_info()[:2]
            error(f"Cann't send email in async to {player_name}: {exctype} {value}")

    async def __send_xmpp(self, recipient, player_name, text):
        try:
            async with aiohttp.ClientSession() as session:
                await session.post("http://localhost:8083/", data=text, headers={"X-XMPP-To": recipient})
            info("OTP was send to %s via xmpp" % player_name)
        except Exception:
            exctype, value = sys.exc_info()[:2]
            error(f"Cann't send xmpp in async to {player_name}: {exctype} {value}")

    def is_require_auth_or_return_roles(self, player_name: str, ip_address: str):
        """Returns True if player should be authenticated, False if user not allowed,
        or list of roles for anonymous players"""
        # check if otp needed
        have_password = False
        have_user = False
        try:
            with self.conn:
                with self.conn.cursor() as curs:
                    curs.execute(
                        """ SELECT game_password IS NOT NULL FROM auth.users WHERE player_name = %s """,
                        (player_name,),
                    )
                    for r in curs:
                        have_password = not not r[0]
                        have_user = True
        except psycopg2.InterfaceError:
            self.conn = psycopg2.connect(self.dsn)
            exctype, value = sys.exc_info()[:2]
            error(f"Cann't check player {player_name}: {exctype} {value}")

        if not have_user:
            return False
        elif have_password:
            return True

        otp = "%0.5d" % random.randint(999, 99999)
        sent_otp = False
        try:
            with self.conn:
                with self.conn.cursor() as curs:
                    curs.execute(
                        """ SELECT * FROM auth.check_contact(%s, %s, %s) """,
                        (player_name, otp, fo.get_galaxy_setup_data().gameUID),
                    )
                    for r in curs:
                        if r[0] == "xmpp":
                            try:
                                loop = asyncio.get_event_loop()
                                loop.create_task(
                                    self.__send_xmpp(
                                        r[1],
                                        player_name,
                                        f"{player_name} is logging. Enter OTP into freeorion client: {otp}",
                                    ),
                                    name="XMPPOTP",
                                )
                                sent_otp = True
                            except Exception:
                                exctype, value = sys.exc_info()[:2]
                                error(f"Cann't send xmpp message to {player_name}: {exctype} {value}")
                        elif r[0] == "email":
                            info("Try to send OTP to %s via email" % player_name)
                            try:
                                loop = asyncio.get_event_loop()
                                loop.create_task(
                                    self.__send_email(
                                        r[1], player_name, "FreeOrion OTP", f"Password {otp} for player {player_name}"
                                    ),
                                    name="EmailOTP",
                                )
                                sent_otp = True
                            except Exception:
                                exctype, value = sys.exc_info()[:2]
                                error(f"Cann't send email to {player_name}: {exctype} {value}")
                        else:
                            warning(f"Unsupported protocol {r[0]} for {player_name}")
        except psycopg2.InterfaceError:
            self.conn = psycopg2.connect(self.dsn)
            exctype, value = sys.exc_info()[:2]
            error(f"Cann't check player {player_name}: {exctype} {value}")

        # in longturn games always require authorization
        return sent_otp

    def is_success_auth_and_return_roles(self, player_name, auth):
        """Return False if passowrd doesn't match or list of roles for authenticated player"""
        authenticated = False
        roles = []
        try:
            with self.conn:
                with self.conn.cursor() as curs:
                    curs.execute(
                        """ SELECT * FROM auth.check_otp(%s, %s, %s) """,
                        (player_name, auth, fo.get_galaxy_setup_data().gameUID),
                    )
                    for r in curs:
                        authenticated = not not r[0]
                        role = self.roles_symbols.get(r[1])
                        if role is not None:
                            roles.append(role)
                        info(f"Player {player_name} was accepted {authenticated!r}")
        except psycopg2.InterfaceError:
            self.conn = psycopg2.connect(self.dsn)
            exctype, value = sys.exc_info()[:2]
            error(f"Cann't check OTP {player_name}: {exctype} {value}")

        if authenticated:
            return roles
        else:
            return False

    def list_players(self):
        """Returns list of PlayerSetupData to use in quickstart"""
        info("Loading players for game %s" % fo.get_galaxy_setup_data().gameUID)
        players = []
        try:
            with self.conn_ro:
                with self.conn_ro.cursor() as curs:
                    curs.execute(
                        """ SELECT u.player_name, MIN(p.species), MIN(p.team_id)
                            FROM auth.users u
                            INNER JOIN games.players p
                            ON p.player_name = u.player_name
                            INNER JOIN games.games g
                            ON g.game_uid = p.game_uid
                            WHERE p.is_confirmed
                            AND p.client_type = 'p'
                            AND g.game_uid = %s
                            GROUP BY u.player_name """,
                        (fo.get_galaxy_setup_data().gameUID,),
                    )
                    for r in curs:
                        psd = fo.PlayerSetupData()
                        psd.player_name = r[0]
                        psd.empire_name = r[0]
                        psd.starting_species = r[1]
                        psd.starting_team = r[2]
                        players.append(psd)
        except psycopg2.InterfaceError:
            self.conn_ro = psycopg2.connect(self.dsn_ro)
            exctype, value = sys.exc_info()[:2]
            error(f"Cann't load players: {exctype} {value}")
        random.shuffle(players)
        return players

    def send_outbound_chat_message(self, text, player_name, allow_email):
        """Send message to player"""
        subject = "FreeOrion LT %s Notification" % fo.get_galaxy_setup_data().gameUID
        try:
            with self.conn_ro:
                with self.conn_ro.cursor() as curs:
                    curs.execute(
                        """SELECT c.protocol, c.address
                            FROM auth.users u
                            INNER JOIN auth.contacts c
                            ON c.player_name = u.player_name
                            WHERE u.player_name = %s
                            AND c.is_active
                            AND c.delete_ts IS NULL
                            UNION ALL
                            SELECT c.protocol, c.address
                            FROM games.players p
                            INNER JOIN auth.users u
                            ON u.player_name = p.delegate_name
                            INNER JOIN auth.contacts c
                            ON c.player_name = u.player_name
                            WHERE p.player_name = %s
                            AND p.game_uid = %s
                            AND p.delegate_name IS NOT NULL
                            AND c.is_active
                            AND c.delete_ts IS NULL
                            """,
                        (player_name, player_name, fo.get_galaxy_setup_data().gameUID),
                    )
                    for r in curs:
                        if r[0] == "xmpp":
                            try:
                                loop = asyncio.get_event_loop()
                                loop.create_task(
                                    self.__send_xmpp(r[1], player_name, f"{subject}\r\n{text}"), name="XMPPOTP"
                                )
                            except Exception:
                                exctype, value = sys.exc_info()[:2]
                                error(f"Cann't send xmpp message to {player_name}: {exctype} {value}")
                        elif r[0] == "email" and allow_email:
                            try:
                                loop = asyncio.get_event_loop()
                                loop.create_task(self.__send_email(r[1], player_name, subject, text), name="EmailTurn")
                            except Exception:
                                exctype, value = sys.exc_info()[:2]
                                error(f"Cann't send email to {player_name}: {exctype} {value}")
                        else:
                            warning(f"Unsupported protocol {r[0]} for {player_name}")
        except psycopg2.InterfaceError:
            self.conn_ro = psycopg2.connect(self.dsn_ro)
            exctype, value = sys.exc_info()[:2]
            error(f"Cann't send message: {exctype} {value}")
            return False
        return True

    def get_player_delegation(self, player_name):
        """Returns list of players delegated by this player"""
        players = []
        try:
            with self.conn_ro:
                with self.conn_ro.cursor() as curs:
                    curs.execute(
                        """SELECT player_name
                            FROM games.players p
                            WHERE p.game_uid = %s
                            AND p.delegate_name = %s """,
                        (fo.get_galaxy_setup_data().gameUID, player_name),
                    )
                    for r in curs:
                        players.append(r[0])
        except psycopg2.InterfaceError:
            self.conn_ro = psycopg2.connect(self.dsn_ro)
            exctype, value = sys.exc_info()[:2]
            error(f"Cann't get delegation info: {exctype} {value}")
        return players
