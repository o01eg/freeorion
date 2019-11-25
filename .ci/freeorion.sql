
CREATE TABLE chat_history(
 ts TIMESTAMP WITHOUT TIME ZONE NOT NULL,
 player_name VARCHAR(100) NULL,
 text TEXT NOT NULL,
 text_color BIGINT NULL
);

CREATE EXTENSION pgcrypto;
CREATE EXTENSION citext;

CREATE SCHEMA auth;

CREATE TABLE auth.users (
 player_name CITEXT PRIMARY KEY,
 create_ts TIMESTAMP WITHOUT TIME ZONE NOT NULL
);

CREATE TYPE auth.contact_protocol AS ENUM ('xmpp', 'email');

CREATE TABLE auth.contacts (
 player_name CITEXT REFERENCES auth.users(player_name),
 protocol auth.contact_protocol NOT NULL,
 address CITEXT NOT NULL,
 is_active BOOLEAN NOT NULL,
 create_ts TIMESTAMP WITHOUT TIME ZONE NOT NULL,
 delete_ts TIMESTAMP WITHOUT TIME ZONE,
 CONSTRAINT pk_contact PRIMARY KEY (protocol, address)
);

CREATE TABLE auth.otp (
 player_name CITEXT PRIMARY KEY REFERENCES auth.users(player_name),
 otp TEXT NOT NULL,
 create_ts TIMESTAMP WITHOUT TIME ZONE NOT NULL
);

CREATE FUNCTION auth.check_contact(player_name_param CITEXT, otp CHAR(6))
RETURNS TABLE (
 protocol auth.contact_protocol,
 address CITEXT) AS
$$
BEGIN
 CREATE TEMP TABLE tmp_cnts ON COMMIT DROP AS
 SELECT c.protocol, c.address
 FROM auth.users u
 LEFT JOIN auth.contacts c ON c.player_name = u.player_name
  AND c.is_active = TRUE
  AND c.delete_ts IS NULL
 WHERE u.player_name = player_name_param;
 
 IF EXISTS (SELECT * FROM tmp_cnts t WHERE t.protocol IS NOT NULL AND t.address IS NOT NULL) THEN
  WITH hashed_otp AS (VALUES (crypt(otp, gen_salt('bf', 8))))
  INSERT INTO auth.otp (player_name, otp, create_ts)
  VALUES (player_name_param, (TABLE hashed_otp), NOW()::timestamp)
  ON CONFLICT (player_name) DO UPDATE SET otp = (TABLE hashed_otp), create_ts = NOW()::timestamp;
 END IF;

 RETURN QUERY SELECT *
 FROM tmp_cnts;
END
$$ LANGUAGE plpgsql;

CREATE FUNCTION auth.check_otp(player_name_param CITEXT, otp CHAR(6))
RETURNS BOOLEAN AS
$$
  WITH hashed_otp AS (DELETE FROM auth.otp WHERE otp.player_name = player_name_param RETURNING otp.otp)
  SELECT (TABLE hashed_otp) IS NOT NULL AND (TABLE hashed_otp) = crypt(otp, (TABLE hashed_otp));
$$ LANGUAGE sql VOLATILE;

CREATE SCHEMA games;

CREATE TABLE games.games (
 game_uid VARCHAR(20) PRIMARY KEY,
 start_ts TIMESTAMP WITHOUT TIME ZONE NOT NULL
);
GRANT SELECT ON games.games TO freeorion;

CREATE TABLE games.players (
 game_uid VARCHAR(20) REFERENCES games.games(game_uid),
 player_name CITEXT REFERENCES auth.users(player_name),
 is_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
 species VARCHAR(20) NOT NULL DEFAULT 'RANDOM',
 delegate_name CITEXT REFERENCES auth.users(player_name) NULL,
 team_id INT NOT NULL DEFAULT -1,
 CONSTRAINT pk_players PRIMARY KEY (game_uid, player_name)
);
GRANT SELECT ON games.players TO freeorion;

