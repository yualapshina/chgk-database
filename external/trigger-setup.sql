		CREATE OR REPLACE FUNCTION lineup_change_func()
		RETURNS TRIGGER AS $$
		BEGIN
			IF TG_OP = 'INSERT' THEN 
				WITH t AS (SELECT CASE WHEN expert_points = 6 THEN 1 ELSE 0 END win, 
				CASE WHEN viewer_points = 6 THEN 1 ELSE 0 END lose FROM games WHERE id = NEW.game_id) 
				UPDATE experts SET won = won + t.win, lost = lost + t.lose FROM t WHERE id = NEW.expert_id;
			ELSE
				WITH t AS (SELECT CASE WHEN expert_points = 6 THEN 1 ELSE 0 END win, 
				CASE WHEN viewer_points = 6 THEN 1 ELSE 0 END lose FROM games WHERE id = OLD.game_id) 
				UPDATE experts SET won = won - t.win, lost = lost - t.lose FROM t WHERE id = OLD.expert_id;
			END IF;
			RETURN NEW;
		END;
		$$ LANGUAGE plpgsql;
		
		CREATE OR REPLACE TRIGGER lineup_change
			AFTER INSERT OR DELETE ON lineups
			FOR EACH ROW
			EXECUTE PROCEDURE lineup_change_func();
			
		CREATE OR REPLACE FUNCTION game_change_func()
		RETURNS TRIGGER AS $$
		BEGIN
			IF NEW.expert_points = 6 AND OLD.expert_points != 6 THEN
				UPDATE experts SET won = won + 1 WHERE EXISTS 
				(SELECT l.expert_id, l.game_id FROM lineups AS l WHERE l.expert_id = id AND l.game_id = NEW.id);
			END IF;
			IF NEW.expert_points != 6 AND OLD.expert_points = 6 THEN
				UPDATE experts SET won = won - 1 WHERE EXISTS 
				(SELECT l.expert_id, l.game_id FROM lineups AS l WHERE l.expert_id = id AND l.game_id = NEW.id);
			END IF;
			IF NEW.viewer_points = 6 AND OLD.viewer_points != 6 THEN
				UPDATE experts SET lost = lost + 1 WHERE EXISTS 
				(SELECT l.expert_id, l.game_id FROM lineups AS l WHERE l.expert_id = id AND l.game_id = NEW.id);
			END IF;
			IF NEW.viewer_points != 6 AND OLD.viewer_points = 6 THEN
				UPDATE experts SET lost = lost - 1 WHERE EXISTS 
				(SELECT l.expert_id, l.game_id FROM lineups AS l WHERE l.expert_id = id AND l.game_id = NEW.id);
			END IF;
			RETURN NEW;
		END;
		$$ LANGUAGE plpgsql;
		
		CREATE OR REPLACE TRIGGER game_change
			AFTER UPDATE ON games
			FOR EACH ROW
			EXECUTE PROCEDURE game_change_func();
			
		CREATE OR REPLACE FUNCTION round_change_func()
		RETURNS TRIGGER AS $$
		BEGIN
			IF TG_OP = 'DELETE' THEN 
				WITH t AS (SELECT SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END) win, 
				   	SUM(CASE WHEN status = -1 THEN 1 ELSE 0 END) lose FROM rounds WHERE game_id = OLD.game_id)
				UPDATE games SET expert_points = t.win, viewer_points = t.lose FROM t WHERE id = OLD.game_id;
				WITH t AS (SELECT SUM(CASE WHEN status = -1 THEN 1 ELSE 0 END) win, 
				   	SUM(CASE WHEN status = -1 THEN 0 ELSE 1 END) lose FROM rounds WHERE viewer_id = OLD.viewer_id)
				UPDATE viewers SET won = t.win, lost = t.lose FROM t WHERE id = OLD.viewer_id;		
			ELSE
				WITH t AS (SELECT SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END) win, 
				   	SUM(CASE WHEN status = -1 THEN 1 ELSE 0 END) lose FROM rounds WHERE game_id = NEW.game_id)
				UPDATE games SET expert_points = t.win, viewer_points = t.lose FROM t WHERE id = NEW.game_id;
				WITH t AS (SELECT SUM(CASE WHEN status = -1 THEN 1 ELSE 0 END) win, 
				   	SUM(CASE WHEN status = -1 THEN 0 ELSE 1 END) lose FROM rounds WHERE viewer_id = NEW.viewer_id)
				UPDATE viewers SET won = t.win, lost = t.lose FROM t WHERE id = NEW.viewer_id;		
			END IF;			
			RETURN NEW;
		END;
		$$ LANGUAGE plpgsql;
		
		CREATE OR REPLACE TRIGGER round_change
			AFTER UPDATE OR INSERT OR DELETE ON rounds
			FOR EACH ROW
			EXECUTE PROCEDURE round_change_func();
