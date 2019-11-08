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

import smtplib
import ConfigParser

# Constants defined by the C++ game engine
NO_TEAM_ID = -1


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
        self.default_roles = [fo.roleType.clientTypePlayer]
        self.mailconf = ConfigParser.ConfigParser()
        self.mailconf.read(fo.get_user_config_dir() + "/mail.cfg")
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
        otp = "%0.5d" % random.randint(999, 99999)
        try:
            with self.conn:
                with self.conn.cursor() as curs:
                    curs.execute(""" SELECT * FROM auth.check_contact(%s, %s, %s) """,
                                 (player_name, otp, fo.get_galaxy_setup_data().gameUID))
                    for r in curs:
                        if r[0] == "xmpp":
                            try:
                                req = urllib2.Request("http://localhost:8083/")
                                req.add_header("X-XMPP-To", r[1])
                                req.add_data("%s is logging. Enter OTP into freeorion client: %s" % (player_name, otp))
                                urllib2.urlopen(req).read()
                                info("OTP was send to %s via XMPP" % player_name)
                            except:
                                error("Cann't send xmpp message to %s" % player_name)
                        elif r[0] == "email":
                            try:
                                server = smtplib.SMTP_SSL(self.mailconf.get('mail', 'server'), 465)
                                server.ehlo()
                                server.login(self.mailconf.get('mail', 'login'), self.mailconf.get('mail', 'passwd'))
                                server.sendmail(self.mailconf.get('mail', 'from'), r[1], """From:
                                        %s\r\nTo: %s\r\nSubject: FreeOrion OTP\r\n\r\nPassword %s
                                        for player %s""" % (self.mailconf.get('mail', 'from'), r[1], otp, player_name))
                                server.close()
                                info("OTP was send to %s via email" % player_name)
                            except:
                                exctype, value = sys.exc_info()[:2]
                                error("Cann't send email to %s: %s %s" % (player_name, exctype, value))
                        else:
                            warn("Unsupported protocol %s for %s" % (r[0], player_name))
        except psycopg2.InterfaceError:
            self.conn = psycopg2.connect(self.dsn)
            exctype, value = sys.exc_info()[:2]
            error("Cann't check player %s: %s %s" % (player_name, exctype, value))

        # in longturn games always require authorization
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
        """Returns list of PlayerSetupData to use in quickstart"""
        info("Loading players for game %s" % fo.get_galaxy_setup_data().gameUID)
        players = []
        try:
            with self.conn:
                with self.conn.cursor() as curs:
                    curs.execute(""" SELECT u.player_name, MIN(p.species), MIN(p.team_id)
                            FROM auth.users u
                            INNER JOIN auth.contacts c
                            ON c.player_name = u.player_name
                            INNER JOIN games.players p
                            ON p.player_name = u.player_name
                            INNER JOIN games.games g
                            ON g.game_uid = p.game_uid
                            WHERE c.is_active
                            AND c.delete_ts IS NULL
                            AND p.is_confirmed
                            AND g.game_uid = %s
                            GROUP BY u.player_name """,
                                 (fo.get_galaxy_setup_data().gameUID,))
                    for r in curs:
                        psd = fo.PlayerSetupData()
                        psd.player_name = r[0]
                        psd.empire_name = r[0]
                        psd.starting_species = r[1].encode('utf-8')
                        psd.starting_team = r[2]
                        players.append(psd)
        except psycopg2.InterfaceError:
            self.conn = psycopg2.connect(self.dsn)
            exctype, value = sys.exc_info()[:2]
            error("Cann't load players: %s %s" % (exctype, value))
        return players

    def send_outbound_chat_message(self, text, player_name, allow_email):
        """ Send message to player """
        subject = "FreeOrion LT %s Notification" % fo.get_galaxy_setup_data().gameUID
        try:
            with self.conn:
                with self.conn.cursor() as curs:
                    curs.execute("""SELECT c.protocol, c.address
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
                                 (player_name, player_name, fo.get_galaxy_setup_data().gameUID))
                    for r in curs:
                        if r[0] == "xmpp":
                            try:
                                req = urllib2.Request("http://localhost:8083/")
                                req.add_header("X-XMPP-To", r[1])
                                req.add_data("%s\r\n%s" % (subject, text))
                                urllib2.urlopen(req).read()
                                info("Message was send to %s via XMPP" % player_name)
                            except:
                                error("Cann't send xmpp message to %s" % player_name)
                        elif r[0] == "email" and allow_email:
                            try:
                                server = smtplib.SMTP_SSL(self.mailconf.get('mail', 'server'), 465)
                                server.ehlo()
                                server.login(self.mailconf.get('mail', 'login'), self.mailconf.get('mail', 'passwd'))
                                server.sendmail(self.mailconf.get('mail', 'from'), r[1], """From:
                                        %s\r\nTo: %s\r\nSubject: %s\r\n\r\n
                                        %s""" % (self.mailconf.get('mail', 'from'), r[1], subject, text))
                                server.close()
                                info("Message was send to %s via email" % player_name)
                            except:
                                exctype, value = sys.exc_info()[:2]
                                error("Cann't send email to %s: %s %s" % (player_name, exctype, value))
                        else:
                            warn("Unsupported protocol %s for %s" % (r[0], player_name))
        except psycopg2.InterfaceError:
            self.conn = psycopg2.connect(self.dsn)
            exctype, value = sys.exc_info()[:2]
            error("Cann't send message: %s %s" % (exctype, value))
            return False
        return True

    def get_player_delegation(self, player_name):
        """Returns list of players delegated by this player"""
        players = []
        try:
            with self.conn:
                with self.conn.cursor() as curs:
                    curs.execute("""SELECT player_name
                            FROM games.players p
                            WHERE p.game_uid = %s
                            AND p.delegate_name = %s """,
                                 (fo.get_galaxy_setup_data().gameUID, player_name))
                    for r in curs:
                        players.append(r[0])
        except psycopg2.InterfaceError:
            self.conn = psycopg2.connect(self.dsn)
            exctype, value = sys.exc_info()[:2]
            error("Cann't get delegation info: %s %s" % (exctype, value))
        return players
