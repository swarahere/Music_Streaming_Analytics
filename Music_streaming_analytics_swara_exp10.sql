-- MUSIC STREAMING ANALYTICS SYSTEM - ADVANCED UPGRADE (MySQL 8.0+)
USE music_analytics;

-- 1. Indexes for faster filtering and joining (safe to rerun)
SET @index_exists = (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name='plays' AND index_name='idx_plays_date');
SET @sql = IF(@index_exists = 0, 'CREATE INDEX idx_plays_date ON plays(played_on)', 'SELECT ''Date index already exists'' AS info');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @index_exists = (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name='plays' AND index_name='idx_plays_listener_date');
SET @sql = IF(@index_exists = 0, 'CREATE INDEX idx_plays_listener_date ON plays(listener_id, played_on)', 'SELECT ''Listener/date index already exists'' AS info');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2. Views: reusable analytics results
CREATE OR REPLACE VIEW listener_summary AS
SELECT l.listener_id, l.listener_name, l.city,
       COUNT(p.play_id) AS total_plays,
       COALESCE(SUM(p.minutes_played),0) AS total_minutes,
       COUNT(DISTINCT p.song_id) AS unique_songs
FROM listeners l LEFT JOIN plays p ON p.listener_id = l.listener_id
GROUP BY l.listener_id, l.listener_name, l.city;

CREATE OR REPLACE VIEW daily_streaming_trends AS
SELECT played_on, COUNT(*) AS total_streams, SUM(minutes_played) AS total_minutes,
       COUNT(DISTINCT listener_id) AS active_listeners
FROM plays GROUP BY played_on;

-- 3. Trigger: block invalid listening durations
DROP TRIGGER IF EXISTS validate_play_duration_insert;
DROP TRIGGER IF EXISTS validate_play_duration_update;
DELIMITER $$
CREATE TRIGGER validate_play_duration_insert
BEFORE INSERT ON plays FOR EACH ROW
BEGIN
    IF NEW.minutes_played IS NULL OR NEW.minutes_played <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Listening duration must be greater than 0';
    END IF;
END$$
CREATE TRIGGER validate_play_duration_update
BEFORE UPDATE ON plays FOR EACH ROW
BEGIN
    IF NEW.minutes_played IS NULL OR NEW.minutes_played <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Listening duration must be greater than 0';
    END IF;
END$$

-- 4. Stored procedure: analytics for a chosen listener
DROP PROCEDURE IF EXISTS GetListenerReport$$
CREATE PROCEDURE GetListenerReport(IN selected_listener_id INT)
BEGIN
    SELECT * FROM listener_summary WHERE listener_id = selected_listener_id;
    SELECT s.title, s.artist, s.genre, COUNT(*) AS times_played,
           SUM(p.minutes_played) AS total_minutes
    FROM plays p JOIN songs s ON s.song_id = p.song_id
    WHERE p.listener_id = selected_listener_id
    GROUP BY s.song_id, s.title, s.artist, s.genre
    ORDER BY times_played DESC, s.title;
END$$
DELIMITER ;

-- 5. ANALYTICS REPORTS (run individually to screenshot)
-- Report A: Song popularity with ranking (window function)
SELECT title, artist, genre, play_count, total_minutes,
       DENSE_RANK() OVER (ORDER BY play_count DESC) AS popularity_rank
FROM song_popularity ORDER BY popularity_rank, title;

-- Report B: Listener leaderboard (window function)
SELECT listener_name, city, total_plays, total_minutes, unique_songs,
       DENSE_RANK() OVER (ORDER BY total_plays DESC) AS activity_rank
FROM listener_summary ORDER BY activity_rank, listener_name;

-- Report C: Favorite genre of each listener (CTE + window function)
WITH genre_counts AS (
    SELECT l.listener_id, l.listener_name, s.genre, COUNT(*) AS genre_plays
    FROM plays p JOIN listeners l ON l.listener_id=p.listener_id
    JOIN songs s ON s.song_id=p.song_id
    GROUP BY l.listener_id, l.listener_name, s.genre
), ranked_genres AS (
    SELECT *, DENSE_RANK() OVER (PARTITION BY listener_id ORDER BY genre_plays DESC) AS genre_rank
    FROM genre_counts
)
SELECT listener_name, genre AS favorite_genre, genre_plays
FROM ranked_genres WHERE genre_rank=1 ORDER BY listener_name, favorite_genre;
-- Ties are shown as multiple favorite genres.

-- Report D: Daily streaming activity
SELECT * FROM daily_streaming_trends ORDER BY played_on;

-- Report E: Artist performance
SELECT artist, SUM(play_count) AS total_streams, SUM(total_minutes) AS total_minutes
FROM song_popularity GROUP BY artist ORDER BY total_streams DESC, artist;

-- Report F: Call stored procedure (two result grids)
CALL GetListenerReport(1);


