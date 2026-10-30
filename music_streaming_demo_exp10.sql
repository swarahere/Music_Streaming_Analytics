
USE music_analytics;

-- 1. Most Streamed Songs with Ranking
SELECT
    s.title,
    s.artist,
    COUNT(p.play_id) AS total_plays,
    DENSE_RANK() OVER (
        ORDER BY COUNT(p.play_id) DESC
    ) AS song_rank
FROM songs s
LEFT JOIN plays p ON s.song_id = p.song_id
GROUP BY s.song_id, s.title, s.artist
ORDER BY song_rank;


-- 2. Listener Activity Leaderboard
SELECT
    l.name AS listener,
    COUNT(p.play_id) AS total_plays,
    COALESCE(SUM(p.minutes_played), 0) AS total_minutes,
    DENSE_RANK() OVER (
        ORDER BY COUNT(p.play_id) DESC
    ) AS listener_rank
FROM listeners l
LEFT JOIN plays p ON l.listener_id = p.listener_id
GROUP BY l.listener_id, l.name
ORDER BY listener_rank;


-- 3. Most Popular Music Genres
SELECT
    s.genre,
    COUNT(p.play_id) AS total_streams,
    ROUND(AVG(p.minutes_played), 2) AS avg_minutes
FROM songs s
JOIN plays p ON s.song_id = p.song_id
GROUP BY s.genre
ORDER BY total_streams DESC;


-- 4. Daily Streaming Activity
SELECT
    played_on,
    COUNT(*) AS total_streams,
    SUM(minutes_played) AS listening_minutes
FROM plays
GROUP BY played_on
ORDER BY played_on;


-- 5. Top Artists
SELECT
    s.artist,
    COUNT(p.play_id) AS total_plays,
    COUNT(DISTINCT s.song_id) AS songs_streamed
FROM songs s
JOIN plays p ON s.song_id = p.song_id
GROUP BY s.artist
ORDER BY total_plays DESC;


-- 6. Favorite Genre for Each Listener
WITH genre_counts AS (
    SELECT
        l.listener_id,
        l.listener_name,
        s.genre,
        COUNT(*) AS play_count,
        RANK() OVER (
            PARTITION BY l.listener_id
            ORDER BY COUNT(*) DESC
        ) AS genre_rank
    FROM listeners l
    JOIN plays p ON l.listener_id = p.listener_id
    JOIN songs s ON p.song_id = s.song_id
    GROUP BY l.listener_id, l.listener_name, s.genre
)
SELECT
    listener_name AS listener,
    genre,
    play_count
FROM genre_counts
WHERE genre_rank = 1;


-- 7. Stored Procedure Demonstration
CALL GetListenerReport(1);
