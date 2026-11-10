-- Queries to demo. Run after schema.sql, routines.sql and seed.sql, and after starting the backend once.
USE petalpass;

-- DML --------------------------------------------------------------
UPDATE events SET capacity = capacity + 5 WHERE event_id = 3;
DELETE FROM registrations WHERE user_id = 6 AND event_id = 2;   -- fires log_cancel trigger
SELECT * FROM cancellation_log;

-- JOINS ------------------------------------------------------------
-- 1. Inner join, three tables: who is registered for what
SELECT u.name, e.title, r.status
FROM registrations r
JOIN users u  ON u.user_id  = r.user_id
JOIN events e ON e.event_id = r.event_id
ORDER BY e.event_date, r.registered_at;

-- 2. Left join: events nobody has confirmed for yet
SELECT e.title, COUNT(r.registration_id) AS confirmed
FROM events e
LEFT JOIN registrations r ON r.event_id = e.event_id AND r.status = 'confirmed'
GROUP BY e.event_id, e.title
HAVING confirmed = 0;

-- 3. Aggregate: registrations and fill rate per category
SELECT e.category, COUNT(r.registration_id) AS registrations,
       ROUND(AVG(f.fill) * 100) AS avg_fill_pct
FROM events e
JOIN event_fill f ON f.event_id = e.event_id
LEFT JOIN registrations r ON r.event_id = e.event_id
GROUP BY e.category;

-- CORRELATED QUERIES ----------------------------------------------
-- 4. Events that fill faster than the average event in their own category
SELECT e.title, e.category, ROUND(s.fill * 100) AS fill_pct
FROM event_fill s
JOIN events e ON e.event_id = s.event_id
WHERE s.fill > (SELECT AVG(s2.fill)
                FROM event_fill s2
                JOIN events e2 ON e2.event_id = s2.event_id
                WHERE e2.category = e.category);

-- 5. Events that currently have a waitlist
SELECT e.title FROM events e
WHERE EXISTS (SELECT 1 FROM registrations r
              WHERE r.event_id = e.event_id AND r.status = 'waitlist');

-- 6. Students registered for more events than the average student
SELECT u.name,
       (SELECT COUNT(*) FROM registrations r WHERE r.user_id = u.user_id) AS total
FROM users u
WHERE (SELECT COUNT(*) FROM registrations r WHERE r.user_id = u.user_id) >
      (SELECT AVG(c) FROM (SELECT COUNT(*) AS c FROM registrations GROUP BY user_id) t);

-- PROCEDURES AND TRIGGERS -----------------------------------------
CALL register_for_event(6, 3);   -- cricket is full, so this returns 'waitlist'
CALL register_for_event(6, 3);   -- duplicate: fails on UNIQUE (user_id, event_id)
CALL cancel_registration(2, 3);  -- frees a seat, oldest waitlisted student is promoted
SELECT * FROM registrations WHERE event_id = 3;

-- VECTOR SEARCH (cosine similarity, pure SQL) ----------------------
-- Events similar to event 1 (CodeSprint)
SELECT e.title,
       ROUND(SUM(a.weight * b.weight) / (na.norm * nb.norm), 3) AS similarity
FROM event_terms a
JOIN event_terms b  ON b.term = a.term AND b.event_id <> a.event_id
JOIN event_norms na ON na.event_id = a.event_id
JOIN event_norms nb ON nb.event_id = b.event_id
JOIN events e       ON e.event_id = b.event_id
WHERE a.event_id = 1
GROUP BY e.event_id, e.title, na.norm, nb.norm
ORDER BY similarity DESC;

-- Free-text search: the query is turned into a vector and compared the same way
WITH q AS (
  SELECT term, weight FROM JSON_TABLE(
    '[{"t":"startup","w":1},{"t":"pitch","w":1},{"t":"hackathon","w":1}]',
    '$[*]' COLUMNS (term VARCHAR(40) PATH '$.t', weight DOUBLE PATH '$.w')) jt),
qn AS (SELECT SQRT(SUM(weight * weight)) AS norm FROM q)
SELECT e.title, ROUND(SUM(q.weight * t.weight) / (qn.norm * n.norm), 3) AS score
FROM q
JOIN event_terms t ON t.term = q.term
JOIN event_norms n ON n.event_id = t.event_id
JOIN events e ON e.event_id = t.event_id
CROSS JOIN qn
GROUP BY e.event_id, e.title, qn.norm, n.norm
ORDER BY score DESC;
