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

