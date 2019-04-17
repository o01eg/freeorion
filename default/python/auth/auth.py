from logging import warn, info, error

from common.configure_logging import redirect_logging_to_freeorion_logger

# Logging is redirected before other imports so that import errors appear in log files.
redirect_logging_to_freeorion_logger()

import sys

import random

import freeorion as fo

import psycopg2
import psycopg2.extensions
psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)

import urllib2


class AuthProvider:
    def __init__(self):
        self.dsn = ""
        with open(fo.get_user_config_dir() + "/db.txt", "r") as f:
            for line in f:
                self.dsn = line
                break
        self.conn = psycopg2.connect(self.dsn)
        self.roles_symbols = {
            'h': fo.roleType.host, 'm': fo.roleType.clientTypeModerator,
            'p': fo.roleType.clientTypePlayer, 'o': fo.roleType.clientTypeObserver,
            'g': fo.roleType.galaxySetup
        }
        self.default_roles = [fo.roleType.galaxySetup, fo.roleType.clientTypePlayer]
        info("Auth initialized")

    def __parse_roles(self, roles_str):
        roles = []
        for c in roles_str:
            r = self.roles_symbols.get(c)
            if r is None:
                warn("unknown role symbol '%c'" % c)
            else:
                roles.append(r)
        return roles

    def is_require_auth_or_return_roles(self, player_name):
        """Returns True if player should be authenticated or list of roles for anonymous players"""
        otp = "%0.6d" % random.randint(999, 999999)
        known_login = False
        try:
            with self.conn:
                with self.conn.cursor() as curs:
                    curs.execute(""" SELECT * FROM auth.check_contact(%s, %s) """,
                                 (player_name, otp))
                    for r in curs:
                        known_login = True
                        if r[0] == "xmpp":
                            req = urllib2.Request("http://localhost:8083/")
                            req.add_header("X-XMPP-To", r[1])
                            req.add_data("Enter OTP into freeorion client: %s" % otp)
                            urllib2.urlopen(req).read()
                        else:
                            warn("Unsupported protocol %s for %s" % (r[0], player_name))
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
                    curs.execute(""" SELECT auth.check_otp(%s, %s) """,
                                 (player_name, auth))
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
        raise NameError('Not supported')
