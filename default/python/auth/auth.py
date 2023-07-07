from logging import error, info, warning

from common.configure_logging import redirect_logging_to_freeorion_logger

# Logging is redirected before other imports so that import errors appear in log files.
redirect_logging_to_freeorion_logger()

import freeorion as fo
import random
import sys
import asyncio
import aiosmtplib
import email

import psycopg2
import psycopg2.extensions

psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)

import configparser
import smtplib
import urllib.request

# Constants defined by the C++ game engine
NO_TEAM_ID = -1


class AuthProvider:
    def __init__(self):
        self.dsn = ""
        with open(fo.get_user_config_dir() + "/db.txt", "r") as f:
            for line in f:
                self.dsn = line
                break
        self.dsn_ro = self.dsn
        try:
            with open(fo.get_user_config_dir() + "/db-ro.txt", "r") as f:
                for line in f:
                    self.dsn_ro = line
                    break
        except IOError:
            exctype, value = sys.exc_info()[:2]
            warning("Read RO DSN: %s %s" % (exctype, value))
        self.conn = psycopg2.connect(self.dsn)
        self.conn_ro = psycopg2.connect(self.dsn_ro)
        self.roles_symbols = {
            "h": fo.roleType.host,
            "m": fo.roleType.clientTypeModerator,
            "p": fo.roleType.clientTypePlayer,
            "o": fo.roleType.clientTypeObserver,
            "g": fo.roleType.galaxySetup,
        }
        self.default_roles = [fo.roleType.galaxySetup, fo.roleType.clientTypePlayer]
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

    async def __send_email(self, recipient, otp, player_name):
        try:
            message = email.message.EmailMessage()
            message["From"] = self.mailconf.get("mail", "from")
            message["To"] = recipient
            message["Subject"] = "FreeOrion OTP"
            message.set_content("Password %s for player %s" % (otp, player_name))

            await aiosmtplib.send(
                message,
                hostname=self.mailconf.get("mail", "server"),
                port=465,
                use_tls=True,
                username=self.mailconf.get("mail", "login"),
                password=self.mailconf.get("mail", "passwd"),
                validate_certs=self.mailconf.getboolean("mail", "validate_certs", fallback=True)
            )
            info("OTP was send to %s via email" % player_name)
        except Exception:
            exctype, value = sys.exc_info()[:2]
            error("Cann't send email in async to %s: %s %s" % (player_name, exctype, value))

    def is_require_auth_or_return_roles(self, player_name: str, ip_address: str):
        """Returns True if player should be authenticated or list of roles for anonymous players"""
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
            error("Cann't check player %s: %s %s" % (player_name, exctype, value))

        if not have_user:
            return self.default_roles
        elif have_password:
            return True

        otp = "%0.5d" % random.randint(999, 99999)
        known_login = False
        try:
            with self.conn:
                with self.conn.cursor() as curs:
                    curs.execute(
                        """ SELECT * FROM auth.check_contact(%s, %s, %s) """,
                        (player_name, otp, fo.get_galaxy_setup_data().gameUID),
                    )
                    for r in curs:
                        known_login = True
                        if r[0] == "xmpp":
                            try:
                                req = urllib.request.Request(
                                    "http://localhost:8083/",
                                    (
                                        "%s is logging. Enter OTP into freeorion client: %s" % (player_name, otp)
                                    ).encode(),
                                )
                                req.add_header("X-XMPP-To", r[1])
                                urllib.request.urlopen(req).read()
                                info("OTP was send to %s via XMPP" % player_name)
                            except Exception:
                                exctype, value = sys.exc_info()[:2]
                                error("Cann't send xmpp message to %s: %s %s" % (player_name, exctype, value))
                        elif r[0] == "email":
                            info("Try to send OTP to %s via email" % player_name)
                            try:
                                loop = asyncio.get_event_loop()
                                loop.create_task(self.__send_email(r[1], otp, player_name), name="Email")
                            except Exception:
                                exctype, value = sys.exc_info()[:2]
                                error("Cann't send email to %s: %s %s" % (player_name, exctype, value))
                        else:
                            warning("Unsupported protocol %s for %s" % (r[0], player_name))
        except psycopg2.InterfaceError:
            self.conn = psycopg2.connect(self.dsn)
            exctype, value = sys.exc_info()[:2]
            error("Cann't check player %s: %s %s" % (player_name, exctype, value))
            known_login = True
        if not known_login:
            # default list of roles
            return self.default_roles
        return True

    def is_success_auth_and_return_roles(self, player_name, auth):
        """Return False if passowrd doesn't match or list of roles for authenticated player"""
        authenticated = False
        try:
            with self.conn:
                with self.conn.cursor() as curs:
                    curs.execute(""" SELECT * FROM auth.check_otp(%s, %s) """, (player_name, auth))
                    for r in curs:
                        authenticated = not not r[0]
                        info("Player %s was accepted %r" % (player_name, authenticated))
        except psycopg2.InterfaceError:
            self.conn = psycopg2.connect(self.dsn)
            exctype, value = sys.exc_info()[:2]
            error("Cann't check OTP %s: %s %s" % (player_name, exctype, value))

        if authenticated:
            return self.default_roles
        else:
            return False

    def list_players(self):
        """Not supported for public server"""
        raise NameError("Not supported")

    def get_player_delegation(self, player_name):
        """Returns list of players delegated by this player"""
        return []
