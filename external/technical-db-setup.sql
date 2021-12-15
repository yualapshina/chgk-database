CREATE DATABASE technical;

CREATE ROLE "chgk-user" WITH
	LOGIN
	SUPERUSER
	CREATEDB
	CREATEROLE
	INHERIT
	REPLICATION
	CONNECTION LIMIT -1
	PASSWORD 'noonewilleverguess';
	
CREATE EXTENSION dblink;

SELECT pg_namespace.nspname, pg_proc.proname 
FROM pg_proc, pg_namespace 
WHERE pg_proc.pronamespace=pg_namespace.oid 
   AND pg_proc.proname LIKE '%dblink%';

CREATE TYPE person_row AS (id INT, name TEXT, profession TEXT, address TEXT, won INT, lost INT);
CREATE TYPE game_row AS (id INT, day DATE, info TEXT, exppoints INT, viepoints INT, musicpause TEXT, link TEXT);
CREATE TYPE lineup_row AS (game_id INT, expert_id INT, status TEXT);
CREATE TYPE round_row AS (game_id INT, viewer_id INT, status INT, question TEXT, answer TEXT, props TEXT, reward TEXT);

CREATE OR REPLACE FUNCTION create_chgk() RETURNS VOID AS $$
BEGIN
	IF EXISTS (SELECT 1 FROM pg_database WHERE datname = 'chgk') THEN
		RAISE NOTICE 'Database already exists'; 
	ELSE
	PERFORM dblink_exec('dbname=technical user=chgk-user password=noonewilleverguess', 'CREATE DATABASE chgk');
	PERFORM dblink_connect_u('mainconn', 'dbname=chgk user=chgk-user password=noonewilleverguess');
	PERFORM dblink_exec('mainconn', 
		'CREATE TABLE experts(
		id SERIAL PRIMARY KEY,
		name TEXT,
		profession TEXT,
		address TEXT,
		won INT CHECK(won >= 0) DEFAULT 0,
		lost INT CHECK(lost >= 0) DEFAULT 0);');
	PERFORM dblink_exec('mainconn', 
		'CREATE TABLE viewers(
		id SERIAL PRIMARY KEY,
		name TEXT,
		profession TEXT,
		address TEXT,
		won INT CHECK(won >= 0) DEFAULT 0,
		lost INT CHECK(lost >= 0) DEFAULT 0);');
	PERFORM dblink_exec('mainconn', 
		'CREATE TABLE games(
		id SERIAL PRIMARY KEY,
		date DATE,
		info TEXT,
		expert_points INT CHECK(expert_points >= 0 AND expert_points <= 6) DEFAULT 0,
		viewer_points INT CHECK(viewer_points >= 0AND viewer_points <= 6) DEFAULT 0,
		music_pause TEXT,
		link TEXT);');
	PERFORM dblink_exec('mainconn', 
		'CREATE TABLE lineups(
		game_id INT REFERENCES games(id),
		expert_id INT REFERENCES experts(id),
		status TEXT,
		CONSTRAINT pk_lineup_id PRIMARY KEY (game_id, expert_id));');
	PERFORM dblink_exec('mainconn', 
		'CREATE TABLE rounds(
		game_id INT REFERENCES games(id),
		viewer_id INT REFERENCES viewers(id),
		status INT,
		question TEXT,
		answer TEXT,
		props TEXT,
		reward INT CHECK(reward >= 0),
		CONSTRAINT pk_round_id PRIMARY KEY (game_id, viewer_id));');
	
	PERFORM dblink_exec('mainconn', 'CREATE INDEX expname_idx ON experts(name);');
	PERFORM dblink_exec('mainconn', 'CREATE INDEX viename_idx ON viewers(name);');
	PERFORM dblink_exec('mainconn', 'CREATE INDEX info_idx ON games(info);');
	PERFORM dblink_exec('mainconn', 'CREATE INDEX status_idx ON lineups(status);');
	PERFORM dblink_exec('mainconn', 'CREATE INDEX question_idx ON rounds(question);');
		
	PERFORM dblink_disconnect('mainconn');	
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION drop_chgk() RETURNS VOID AS $$
BEGIN
	IF EXISTS (SELECT 1 FROM pg_database WHERE datname = 'chgk') THEN
	PERFORM dblink_exec('dbname=technical user=chgk-user password=noonewilleverguess', 'DROP DATABASE chgk');
	ELSE
	RAISE NOTICE 'Database does not exists';
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION clear_all() RETURNS VOID AS $$
BEGIN
	PERFORM * FROM rounds_func(param => 'CLEAR');
	PERFORM * FROM lineups_func(param => 'CLEAR');
	PERFORM * FROM games_func(param => 'CLEAR');
	PERFORM * FROM viewers_func(param => 'CLEAR');
	PERFORM * FROM experts_func(param => 'CLEAR');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fill_default() RETURNS VOID AS $$
BEGIN
	PERFORM clear_all();
	PERFORM dblink_connect_u('mainconn', 'dbname=chgk user=chgk-user password=noonewilleverguess');
	PERFORM dblink_exec('mainconn', E'COPY experts (name, profession, address) 
						FROM \'D:/all/millecent/chgk-database/external/experts.csv\' 
						DELIMITER \';\' CSV HEADER ENCODING \'WIN1251\' QUOTE E\'\\"\' NULL \'NULL\' ESCAPE E\'\\\\\';'); 
	PERFORM dblink_exec('mainconn', E'COPY viewers (name, profession, address) 
						FROM \'D:/all/millecent/chgk-database/external/viewers.csv\' 
						DELIMITER \';\' CSV HEADER ENCODING \'WIN1251\' QUOTE E\'\\"\' NULL \'NULL\' ESCAPE E\'\\\\\';'); 
	PERFORM dblink_exec('mainconn', E'COPY games (date, info, music_pause, link) 
						FROM \'D:/all/millecent/chgk-database/external/games.csv\' 
						DELIMITER \';\' CSV HEADER ENCODING \'WIN1251\' QUOTE E\'\\"\' NULL \'NULL\' ESCAPE E\'\\\\\';'); 
	PERFORM dblink_exec('mainconn', E'COPY lineups (game_id, expert_id, status) 
						FROM \'D:/all/millecent/chgk-database/external/lineups.csv\' 
						DELIMITER \';\' CSV HEADER ENCODING \'WIN1251\' QUOTE E\'\\"\' NULL \'NULL\' ESCAPE E\'\\\\\';'); 
	PERFORM dblink_exec('mainconn', E'COPY rounds (game_id, viewer_id, status, question, answer, props, reward) 
						FROM \'D:/all/millecent/chgk-database/external/rounds.csv\' 
						DELIMITER \';\' CSV HEADER ENCODING \'WIN1251\' QUOTE E\'\\"\' NULL \'NULL\' ESCAPE E\'\\\\\';'); 
	PERFORM dblink_disconnect('mainconn');
	
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION disconnect_on_error() RETURNS VOID AS $$
BEGIN
	IF (SELECT dblink_get_connections()) IS NOT NULL
	THEN PERFORM dblink_disconnect('mainconn');
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION experts_func(param TEXT DEFAULT NULL, id INT DEFAULT NULL, searchby TEXT DEFAULT '', orderby TEXT DEFAULT 'id', 
							 name TEXT DEFAULT NULL, prof TEXT DEFAULT NULL, addr TEXT DEFAULT NULL) 
RETURNS SETOF person_row AS $$
BEGIN
   	PERFORM dblink_connect_u('mainconn', 'dbname=chgk user=chgk-user password=noonewilleverguess');
	
	IF param = 'CLEAR' THEN
		PERFORM dblink_exec('mainconn', 'DELETE FROM experts'); 
		PERFORM dblink_exec('mainconn', 'ALTER SEQUENCE experts_id_seq RESTART'); END IF;
	IF param = 'ADD' THEN
		PERFORM dblink_exec('mainconn', E'INSERT INTO experts(name, profession, address) 
							VALUES(\'' || name  || E'\', \'' || prof || E'\', \'' || addr || E'\')'); END IF;
   	IF param = 'UPDATEROW' THEN
		IF name IS NOT NULL THEN PERFORM dblink_exec('mainconn', E'UPDATE experts SET name = \'' || name || E'\' WHERE id = ' || id); END IF;
		IF prof IS NOT NULL THEN PERFORM dblink_exec('mainconn', E'UPDATE experts SET profession = \'' || prof || E'\' WHERE id = ' || id); END IF;
		IF addr IS NOT NULL THEN PERFORM dblink_exec('mainconn', E'UPDATE experts SET address = \'' || addr || E'\' WHERE id = ' || id); END IF;
	END IF;
	IF param = 'DELETEROW' THEN
		PERFORM dblink_exec('mainconn', 'DELETE FROM experts WHERE id = ' || id); END IF;
	IF param = 'DELETESEARCH' THEN
		PERFORM dblink_exec('mainconn', E'DELETE FROM experts WHERE name LIKE \'%' || name || E'%\''); END IF;
	
	PERFORM dblink_disconnect('mainconn');
	RETURN QUERY SELECT * FROM dblink('dbname=chgk user=chgk-user password=noonewilleverguess', 
									  E'SELECT * FROM experts WHERE name LIKE \'%' || searchby || E'%\' ORDER BY ' || orderby)
	AS temp(id INT, name TEXT, profession TEXT, address TEXT, won INT, lost INT);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION viewers_func(param TEXT DEFAULT NULL, id INT DEFAULT NULL, searchby TEXT DEFAULT '', orderby TEXT DEFAULT 'id', 
							 name TEXT DEFAULT NULL, prof TEXT DEFAULT NULL, addr TEXT DEFAULT NULL) 
RETURNS SETOF person_row AS $$
BEGIN
   	PERFORM dblink_connect_u('mainconn', 'dbname=chgk user=chgk-user password=noonewilleverguess');
	
	IF param = 'CLEAR' THEN
		PERFORM dblink_exec('mainconn', 'DELETE FROM viewers'); 
		PERFORM dblink_exec('mainconn', 'ALTER SEQUENCE viewers_id_seq RESTART'); END IF;
	IF param = 'ADD' THEN
		PERFORM dblink_exec('mainconn', E'INSERT INTO viewers(name, profession, address) 
							VALUES(\'' || name  || E'\', \'' || prof || E'\', \'' || addr || E'\')'); END IF;
   	IF param = 'UPDATEROW' THEN
		IF name IS NOT NULL THEN PERFORM dblink_exec('mainconn', E'UPDATE viewers SET name = \'' || name || E'\' WHERE id = ' || id); END IF;
		IF prof IS NOT NULL THEN PERFORM dblink_exec('mainconn', E'UPDATE viewers SET profession = \'' || prof || E'\' WHERE id = ' || id); END IF;
		IF addr IS NOT NULL THEN PERFORM dblink_exec('mainconn', E'UPDATE viewers SET address = \'' || addr || E'\' WHERE id = ' || id); END IF;
	END IF;
	IF param = 'DELETEROW' THEN
		PERFORM dblink_exec('mainconn', 'DELETE FROM viewers WHERE id = ' || id); END IF;
	IF param = 'DELETESEARCH' THEN
		PERFORM dblink_exec('mainconn', E'DELETE FROM viewers WHERE name LIKE \'%' || name || E'%\''); END IF;
	
	PERFORM dblink_disconnect('mainconn');
	RETURN QUERY SELECT * FROM dblink('dbname=chgk user=chgk-user password=noonewilleverguess', 
									  E'SELECT * FROM viewers WHERE name LIKE \'%' || searchby || E'%\' ORDER BY ' || orderby)
	AS temp(id INT, name TEXT, profession TEXT, address TEXT, won INT, lost INT);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION games_func(param TEXT DEFAULT NULL, id INT DEFAULT NULL, searchby TEXT DEFAULT '', orderby TEXT DEFAULT 'id', 
							 day TEXT DEFAULT NULL, info TEXT DEFAULT NULL, musicpause TEXT DEFAULT NULL, link TEXT DEFAULT NULL) 
RETURNS SETOF game_row AS $$
BEGIN
   	PERFORM dblink_connect_u('mainconn', 'dbname=chgk user=chgk-user password=noonewilleverguess');
	
	IF param = 'CLEAR' THEN
		PERFORM dblink_exec('mainconn', 'DELETE FROM games'); 
		PERFORM dblink_exec('mainconn', 'ALTER SEQUENCE games_id_seq RESTART'); END IF;
	IF param = 'ADD' THEN
		PERFORM dblink_exec('mainconn', E'INSERT INTO games(date, info, music_pause, link) 
							VALUES(\'' || day  || E'\', \'' || info || E'\', \'' || musicpause || E'\', \'' || link || E'\')'); END IF;
   	IF param = 'UPDATEROW' THEN
		IF day IS NOT NULL THEN PERFORM dblink_exec('mainconn', E'UPDATE games SET date = \'' || day || E'\' WHERE id = ' || id); END IF;
		IF info IS NOT NULL THEN PERFORM dblink_exec('mainconn', E'UPDATE games SET info = \'' || info || E'\' WHERE id = ' || id); END IF;
		IF musicpause IS NOT NULL THEN PERFORM dblink_exec('mainconn', E'UPDATE games SET music_pause = \'' || musicpause || E'\' WHERE id = ' || id); END IF;
		IF link IS NOT NULL THEN PERFORM dblink_exec('mainconn', E'UPDATE games SET link = \'' || link || E'\' WHERE id = ' || id); END IF;
	END IF;
	IF param = 'DELETEROW' THEN
		PERFORM dblink_exec('mainconn', 'DELETE FROM games WHERE id = ' || id); END IF;
	IF param = 'DELETESEARCH' THEN
		PERFORM dblink_exec('mainconn', E'DELETE FROM games WHERE info LIKE \'%' || info || E'%\''); END IF;
	
	PERFORM dblink_disconnect('mainconn');
	RETURN QUERY SELECT * FROM dblink('dbname=chgk user=chgk-user password=noonewilleverguess', 
									  E'SELECT * FROM games WHERE info LIKE \'%' || searchby || E'%\' ORDER BY ' || orderby)
	AS temp(id INT, day DATE, info TEXT, exppoints INT, viepoints INT, musicpause TEXT, link TEXT);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lineups_func(param TEXT DEFAULT NULL, game_id INT DEFAULT NULL, expert_id INT DEFAULT NULL, searchby TEXT DEFAULT '', 
							  orderby TEXT DEFAULT 'game_id', status TEXT DEFAULT NULL) 
RETURNS SETOF lineup_row AS $$
BEGIN
   	PERFORM dblink_connect_u('mainconn', 'dbname=chgk user=chgk-user password=noonewilleverguess');
	
	IF param = 'CLEAR' THEN
		PERFORM dblink_exec('mainconn', 'DELETE FROM lineups'); END IF;
	IF param = 'ADD' THEN
		PERFORM dblink_exec('mainconn', E'INSERT INTO lineups(game_id, expert_id, status) 
							VALUES(' || game_id || E', ' || expert_id || E', \'' || status || E'\')'); END IF;
   	IF param = 'UPDATEROW' THEN
		IF status IS NOT NULL THEN PERFORM dblink_exec('mainconn', 
							E'UPDATE lineups SET status = \'' || status || E'\' WHERE game_id = ' || game_id || 'AND expert_id = ' || expert_id); END IF;
	END IF;
	IF param = 'DELETEROW' THEN
		PERFORM dblink_exec('mainconn', 'DELETE FROM lineups WHERE game_id = ' || game_id || 'AND expert_id = ' || expert_id); END IF;
	IF param = 'DELETESEARCH' THEN
		PERFORM dblink_exec('mainconn', E'DELETE FROM lineups WHERE status LIKE \'%' || status || E'%\''); END IF;
	
	PERFORM dblink_disconnect('mainconn');
	RETURN QUERY SELECT * FROM dblink('dbname=chgk user=chgk-user password=noonewilleverguess',
									  E'SELECT * FROM lineups WHERE status LIKE \'%' || searchby || E'%\' ORDER BY ' || orderby)
	AS temp(game_id INT, expert_id INT, status TEXT);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rounds_func(param TEXT DEFAULT NULL, game_id INT DEFAULT NULL, viewer_id INT DEFAULT NULL, searchby TEXT DEFAULT '', 
					orderby TEXT DEFAULT 'game_id', status INT DEFAULT NULL, question TEXT DEFAULT NULL, answer TEXT DEFAULT NULL, props TEXT DEFAULT NULL, reward INT DEFAULT NULL) 
RETURNS SETOF round_row AS $$
BEGIN
   	PERFORM dblink_connect_u('mainconn', 'dbname=chgk user=chgk-user password=noonewilleverguess');
	
	IF param = 'CLEAR' THEN
		PERFORM dblink_exec('mainconn', 'DELETE FROM rounds'); END IF;
	IF param = 'ADD' THEN
		PERFORM dblink_exec('mainconn', E'INSERT INTO rounds(game_id, viewer_id, status, question, answer, props, reward) 
							VALUES(' || game_id  || E', ' || viewer_id || E', ' || status || E', \'' || question 
							|| E'\', \'' || answer || E'\', \'' || props || E'\', ' || reward || E')'); END IF;
   	IF param = 'UPDATEROW' THEN
		IF status IS NOT NULL THEN PERFORM dblink_exec('mainconn', E'UPDATE rounds SET status = ' || status || 
													   E' WHERE game_id = ' || game_id || E' AND viewer_id = ' || viewer_id); END IF;
		IF question IS NOT NULL THEN PERFORM dblink_exec('mainconn', E'UPDATE rounds SET question = \'' || question || 
														 E'\' WHERE game_id = ' || game_id || E' AND viewer_id = ' || viewer_id); END IF;
		IF answer IS NOT NULL THEN PERFORM dblink_exec('mainconn', E'UPDATE rounds SET answer = \'' || answer || 
													   E'\' WHERE game_id = ' || game_id || E' AND viewer_id = ' || viewer_id); END IF;
		IF props IS NOT NULL THEN PERFORM dblink_exec('mainconn', E'UPDATE rounds SET props = \'' || props || 
													  E'\' WHERE game_id = ' || game_id || E' AND viewer_id = ' || viewer_id); END IF;
		IF reward IS NOT NULL THEN PERFORM dblink_exec('mainconn', E'UPDATE rounds SET reward = ' || reward || 
													   E' WHERE game_id = ' || game_id || E' AND viewer_id = ' || viewer_id); END IF;
	END IF;
	IF param = 'DELETEROW' THEN
		PERFORM dblink_exec('mainconn', 'DELETE FROM rounds WHERE game_id = ' || game_id || E' AND viewer_id = ' || viewer_id); END IF;
	IF param = 'DELETESEARCH' THEN
		PERFORM dblink_exec('mainconn', E'DELETE FROM rounds WHERE question LIKE \'%' || question || E'%\''); END IF;
	
	PERFORM dblink_disconnect('mainconn');
	RETURN QUERY SELECT * FROM dblink('dbname=chgk user=chgk-user password=noonewilleverguess', 
									  E'SELECT * FROM rounds WHERE question LIKE \'%' || searchby || E'%\' ORDER BY ' || orderby)
	AS temp(game_id INT, viewer_id INT, status INT, question TEXT, answer TEXT, props TEXT, reward TEXT);
END;
$$ LANGUAGE plpgsql;


