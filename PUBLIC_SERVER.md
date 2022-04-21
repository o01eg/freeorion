# Setup SQL data

Public server uses PostgreSQL.

Create `freeorion` database:

```sql
CREATE DATABASE freeorion;
```

Create user `freeorion` for freeoriond server:
```sql
CREATE USER freeorion;
```

There re-login psql into `freeorion` database. All next commands will be applied on `freeorion`:

First, revoke privileges to create table for non-root users:

```sql
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
```

## Chat data

Create table and grant freeoriond server to read from it and write new messages:

```sql
CREATE TABLE chat_history(
 ts TIMESTAMP WITHOUT TIME ZONE NOT NULL,
 player_name VARCHAR(100) NULL,
 text TEXT NOT NULL,
 text_color BIGINT NULL
);
GRANT SELECT, INSERT ON chat_history TO freeorion;
```

## Auth data

Enable `pgcrypto` extension to have safe storage for passwords:

```sql
CREATE EXTENSION pgcrypto;
```

Enable `citext` extension to have case-insensitive column for logins and addresses;

```sql
CREATE EXTENSION citext;
```

Use separate schema as it contains sensitive data and grants access to freeoriond user:

```sql
CREATE SCHEMA auth;
GRANT USAGE ON SCHEMA auth TO freeorion;
```

Create tables to store users, their contact data and OTPs:
```sql
CREATE TABLE auth.users (
 player_name CITEXT PRIMARY KEY,
 create_ts TIMESTAMP WITHOUT TIME ZONE NOT NULL
);

CREATE TYPE auth.contact_protocol AS ENUM ('xmpp');

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
```

Next create functions to work with auth data.

First is to check player in database. If player found function should save OTP and return active
contacts or `NULL` of there no available contacts. If there no player in database then function
returns 0 rows.

```sql
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
  AND c.protocol = 'xmpp'
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
```

Second function checks if entered OTP correct:

```sql
CREATE FUNCTION auth.check_otp(player_name_param CITEXT, otp CHAR(6))
RETURNS BOOLEAN AS
$$
  WITH hashed_otp AS (DELETE FROM auth.otp WHERE otp.player_name = player_name_param RETURNING otp.otp)
  SELECT (TABLE hashed_otp) IS NOT NULL AND (TABLE hashed_otp) = crypt(otp, (TABLE hashed_otp));
$$ LANGUAGE sql VOLATILE;
```

Granting required priveleges for freeoriond:

```sql
GRANT SELECT ON auth.users TO freeorion;
GRANT SELECT ON auth.contacts TO freeorion;
GRANT SELECT, INSERT, UPDATE, DELETE ON auth.otp TO freeorion;
```

There could try with users:

```sql
INSERT INTO auth.users (player_name, create_ts) VALUES ('testUser', NOW()::timestamp);
INSERT INTO auth.users (player_name, create_ts) VALUES ('testUserWithContact', NOW()::timestamp);

INSERT INTO auth.contacts (player_name, protocol, address, is_active, create_ts)
VALUES ('testUserWithContact', 'xmpp', 'test@example.com', TRUE, NOW()::timestamp);
```

Then try as `freeorion` user:

```sql
SELECT auth.check_contact('testUserWithContact', '123456');
/* returns this users contacts */
SELECT auth.check_otp('testUserWithContact', '123456');
/* returns true */
SELECT auth.check_otp('testUserWithContact', '123456');
/* returns false on next checks or with wrong otp */

SELECT auth.check_contact('testUser', '123456');
/* returns empty row */
SELECT auth.check_otp('testUser', '123456');
/* always returns false */

SELECT auth.check_contact('testUnknown', '123456');
/* returns empty row */
SELECT auth.check_otp('testUnknown', '123456');
/* always returns false */

```

# Add emails (2019-05-13)

Add new type to contact enum:

```sql
ALTER TYPE auth.contact_protocol ADD VALUE 'email';
```

Allow to use different protocols:

```sql
DROP FUNCTION auth.check_contact;
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
```

Now it possible to add new type of contacts:

```sql
INSERT INTO auth.contacts (player_name, protocol, address, is_active, create_ts)
VALUES ('testUserWithContact', 'email', 'test@example.com', TRUE, NOW()::timestamp);
```

# Add games (2019-06-21)

To manage multiple games in the one database create table with games. As there planned to be a much
data let's create separate scheme:

```sql
CREATE SCHEMA games;
GRANT USAGE ON SCHEMA games TO freeorion;
```

Create table itself:

```sql
CREATE TABLE games.games (
 game_uid VARCHAR(20) PRIMARY KEY,
 start_ts TIMESTAMP WITHOUT TIME ZONE NOT NULL
);
GRANT SELECT ON games.games TO freeorion;
```

Create table to link users and games:

```sql
CREATE TABLE games.players (
 game_uid VARCHAR(20) REFERENCES games.games(game_uid),
 player_name CITEXT REFERENCES auth.users(player_name),
 is_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
 species VARCHAR(20) NOT NULL DEFAULT 'RANDOM',
 CONSTRAINT pk_players PRIMARY KEY (game_uid, player_name)
);
GRANT SELECT ON games.players TO freeorion;
```

# Prepare teams and delegation (2019-09-14)

Add new argument to accept game UID to search for player delegate:

```sql
DROP FUNCTION auth.check_contact;
CREATE FUNCTION auth.check_contact(player_name_param CITEXT, otp CHAR(6), game_uid VARCHAR(20))
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
```

Add field for delegate player:

```sql
ALTER TABLE games.players ADD COLUMN delegate_name CITEXT REFERENCES auth.users(player_name) NULL;
```

Add field for team id:

```sql
ALTER TABLE games.players ADD COLUMN team_id INT NOT NULL DEFAULT -1;
```

# Add delegate support (2019-09-29)
Alter function to send OTP to delegate also:

```sql
DROP FUNCTION auth.check_contact;
CREATE FUNCTION auth.check_contact(player_name_param CITEXT, otp CHAR(6), game_uid_param VARCHAR(20))
RETURNS TABLE (
 protocol auth.contact_protocol,
 address CITEXT) AS
$$
BEGIN
 CREATE TEMP TABLE tmp_cnts ON COMMIT DROP AS
 SELECT c.protocol, c.address
 FROM auth.users u
 INNER JOIN auth.contacts c ON c.player_name = u.player_name
  AND c.is_active = TRUE
  AND c.delete_ts IS NULL
 WHERE u.player_name = player_name_param
 UNION ALL
 SELECT c.protocol, c.address
 FROM games.players p
 INNER JOIN auth.users u ON u.player_name = p.delegate_name
 INNER JOIN auth.contacts c ON c.player_name = u.player_name
  AND c.is_active = TRUE
  AND c.delete_ts IS NULL
 WHERE p.player_name = player_name_param
 AND p.game_uid = game_uid_param
 AND delegate_name IS NOT NULL;

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
```

# Use in-game delegation support (2019-10-29)

Alter function to don't send OTP to delegate now:

```sql
DROP FUNCTION auth.check_contact;
CREATE FUNCTION auth.check_contact(player_name_param CITEXT, otp CHAR(6), game_uid_param VARCHAR(20))
RETURNS TABLE (
 protocol auth.contact_protocol,
 address CITEXT) AS
$$
BEGIN
 CREATE TEMP TABLE tmp_cnts ON COMMIT DROP AS
 SELECT c.protocol, c.address
 FROM auth.users u
 INNER JOIN auth.contacts c ON c.player_name = u.player_name
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
```

# Share chat between servers (2020-10-03)

Choose one server where chat will remain alive

```sql
ALTER TABLE chat_history ADD COLUMN server_id INT NOT NULL DEFAULT 1;
```

# Add allowed client type for user in the game (2021-02-14)

In each game client could participate a different role.

```sql
CREATE TYPE auth.client_types AS ENUM ('p', 'o', 'm');

ALTER TABLE games.players ADD COLUMN client_type auth.client_types NOT NULL DEFAULT 'p';
```

# Add static passwords for future web interface

Add static passwords which could be set via protected with HTTPS web interface.

```sql
ALTER TABLE auth.users ADD COLUMN web_password TEXT NULL;

ALTER TABLE auth.users ADD COLUMN game_password TEXT NULL;
```

The first is for web interface itself. The second for game client and should be changed frequently.

# Get available roles after authentication

```sql
DROP FUNCTION auth.check_otp(player_name_param CITEXT, otp CHAR(6));

CREATE FUNCTION auth.check_otp(player_name_param CITEXT, otp CHAR(6), game_uid_param VARCHAR(20))
RETURNS TABLE (
 authenticated BOOLEAN,
 client_type auth.client_types) AS
$$
 BEGIN
  CREATE TEMP TABLE tmp_cnts ON COMMIT DROP AS
  WITH hashed_otp AS (DELETE FROM auth.otp WHERE otp.player_name = player_name_param RETURNING otp.otp)
  SELECT (TABLE hashed_otp) IS NOT NULL AND (TABLE hashed_otp) = crypt(otp, (TABLE hashed_otp));

  RETURN QUERY SELECT t.*, p.client_type
  FROM tmp_cnts t
  CROSS JOIN games.players p
  WHERE p.player_name = player_name_param
  AND p.game_uid = game_uid_param;
 END
$$ LANGUAGE plpgsql;
```

# Allow NULL roles without game

```sql
CREATE FUNCTION auth.check_otp(player_name_param CITEXT, otp CHAR(6))
RETURNS BOOLEAN AS
$$
  WITH hashed_otp AS (DELETE FROM auth.otp WHERE otp.player_name = player_name_param RETURNING otp.otp)
  SELECT (TABLE hashed_otp) IS NOT NULL AND (TABLE hashed_otp) = crypt(otp, (TABLE hashed_otp));
$$ LANGUAGE sql VOLATILE;
```

# Add table to store turn time

```sql
CREATE TABLE games.turns (
 game_uid VARCHAR(20) REFERENCES games.games(game_uid),
 turn INT NOT NULL,
 turn_ts TIMESTAMP WITHOUT TIME ZONE NOT NULL,
 CONSTRAINT pk_turns PRIMARY KEY (game_uid, turn)
);
GRANT SELECT, INSERT, UPDATE ON games.turns TO freeorion;
```

# Add fields to games for RSS channel

```sql
ALTER TABLE games.games ADD COLUMN fo_forum_url VARCHAR(512) NULL;
ALTER TABLE games.games ADD COLUMN create_ts TIMESTAMP WITHOUT TIME ZONE NULL;
```

# Add table to store tokens to reset password

```sql
CREATE TABLE auth.reset_tokens (
 player_name CITEXT REFERENCES auth.users(player_name) PRIMARY KEY,
 token UUID NOT NULL,
 ip_address TEXT NULL,
 create_ts TIMESTAMP WITHOUT TIME ZONE NOT NULL,
 last_error TEXT NULL,
 UNIQUE(token)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON auth.reset_tokens TO freeorion;
```

# Check permanent password

```sql
DROP FUNCTION auth.check_otp(player_name_param CITEXT, otp CHAR(6), game_uid_param VARCHAR(20));

CREATE FUNCTION auth.check_otp(player_name_param CITEXT, otp CHAR(6), game_uid_param VARCHAR(20))
RETURNS TABLE (
 authenticated BOOLEAN,
 client_type auth.client_types) AS
$$
 BEGIN
  CREATE TEMP TABLE tmp_cnts ON COMMIT DROP AS
  WITH hashed_otp AS (DELETE FROM auth.otp WHERE otp.player_name = player_name_param RETURNING otp.otp)
  SELECT (TABLE hashed_otp) IS NOT NULL AND (TABLE hashed_otp) = crypt(otp, (TABLE hashed_otp))
    OR u.game_password = crypt(otp, u.game_password)
  FROM auth.users u WHERE u.player_name = player_name_param;

  RETURN QUERY SELECT t.*, p.client_type
  FROM tmp_cnts t
  CROSS JOIN games.players p
  WHERE p.player_name = player_name_param
  AND p.game_uid = game_uid_param;
 END
$$ LANGUAGE plpgsql;
```

# Check permanent password without game uid

```sql
DROP FUNCTION auth.check_otp(player_name_param CITEXT, otp CHAR(6));

CREATE FUNCTION auth.check_otp(player_name_param CITEXT, otp CHAR(6))
RETURNS BOOLEAN AS
$$
  WITH hashed_otp AS (DELETE FROM auth.otp WHERE otp.player_name = player_name_param RETURNING otp.otp)
  SELECT (TABLE hashed_otp) IS NOT NULL AND (TABLE hashed_otp) = crypt(otp, (TABLE hashed_otp))
    OR u.game_password = crypt(otp, u.game_password)
  FROM auth.users u WHERE u.player_name = player_name_param;
$$ LANGUAGE sql VOLATILE;
```

# Add some notes to add in RSS

```sql
ALTER TABLE games.games ADD COLUMN notes_html VARCHAR(4096) NULL;
```

