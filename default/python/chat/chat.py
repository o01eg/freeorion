from logging import info, error

from common.configure_logging import redirect_logging_to_freeorion_logger

# Logging is redirected before other imports so that import errors appear in log files.
redirect_logging_to_freeorion_logger()

import sys

import freeorion as fo

import psycopg2
import psycopg2.extensions
psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)

import urllib.request


class ChatHistoryProvider:
    def __init__(self):
        """
        Initializes ChatProvider. Doesn't accept arguments.
        """
        self.dsn = ""
        with open(fo.get_user_config_dir() + "/db.txt", "r") as f:
            for line in f:
                self.dsn = line
                break
        self.conn = psycopg2.connect(self.dsn)
        info("Chat initialized")

    def load_history(self):
        """
        Loads chat history from external sources.

        Returns list of tuples:
            (unixtime timestamp, player name, text, text color of type freeorion.GGColor)
        """
        info("Loading history...")
        # c = fo.GGColor(255, 128, 128, 255)
        # e = (123456789012, "P1", "Test1", c)
        # return [e]
        res = []
        with self.conn:
            with self.conn.cursor() as curs:
                curs.execute(""" SELECT date_part('epoch', ts)::int, player_name, text,
                    text_color / 256 / 256 / 256 % 256,
                    text_color / 256 / 256 % 256,
                    text_color / 256 % 256,
                    text_color % 256
                    FROM (
                        SELECT *
                        FROM chat_history
                        ORDER BY ts DESC
                        LIMIT 500
                    ) d
                    ORDER BY ts""")
                for r in curs:
                    c = fo.GGColor(r[3], r[4], r[5], r[6])
                    e = (r[0], r[1], r[2], c)
                    res.append(e)
        return res

    def put_history_entity(self, timestamp, player_name, text, text_color):
        """
        Put chat into external storage.

        Return True if successfully stored. False otherwise.

        Arguments:
        timestamp -- unixtime, number of seconds from 1970-01-01 00:00:00 UTC
        player_name -- player name
        text -- chat text
        text_color -- freeorion.GGColor
        """
        info("Chat %s: %s %s" % (player_name, text, text_color))
        saved = False
        while not saved:
            try:
                with self.conn:
                    with self.conn.cursor() as curs:
                        curs.execute(""" INSERT INTO chat_history (ts, player_name, text, text_color)
                                     VALUES (to_timestamp(%s) at time zone 'utc', %s, %s, %s)""",
                                     (timestamp, player_name, text, 256 * (256 * (256 * text_color.r + text_color.g) + text_color.b) + text_color.a))
                        saved = True
                try:
                    req = urllib.request.Request("http://localhost:8083/", ("<%s> %s" % (player_name, text)).encode())
                    req.add_header("X-XMPP-Muc", "smac")
                    urllib.request.urlopen(req).read()
                    info("Chat message was send via XMPP")
                except Exception:
                    exctype, value = sys.exc_info()[:2]
                    error("Cann't send chat message %s: %s %s" % (text, exctype, value))
            except psycopg2.InterfaceError:
                self.conn = psycopg2.connect(self.dsn)
                saved = False
                exctype, value = sys.exc_info()[:2]
                error("Cann't save chat message %s: %s %s" % (text, exctype, value))
        return True
