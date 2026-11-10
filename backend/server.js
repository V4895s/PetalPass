const express = require("express");
const path = require("path");
const db = require("./db");

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, "../frontend")));

// ---------- helpers ----------
const handle = (fn) => (req, res) =>
  fn(req, res).catch((e) => {
    if (e.code === "ER_DUP_ENTRY") return res.status(409).json({ error: "You are already registered for this event" });
    if (e.sqlState === "45000") return res.status(400).json({ error: e.sqlMessage }); // raised by triggers
    console.error(e);
    res.status(500).json({ error: "Server error" });
  });

async function isAdmin(userId) {
  const [rows] = await db.query("SELECT role FROM users WHERE user_id = ?", [userId]);
  return rows.length > 0 && rows[0].role === "admin";
}

// ---------- vector search: turn text into a term-weight vector ----------
const STOP = new Set("the and for with are you your from that this will all can have into over its our out their each by".split(" "));
function vectorize(text) {
  const v = {};
  for (const w of text.toLowerCase().match(/[a-z]{3,}/g) || []) if (!STOP.has(w)) v[w] = (v[w] || 0) + 1;
  return v;
}
async function indexEvent(id, title, category, description) {
  const v = vectorize(`${title} ${title} ${category} ${category} ${description || ""}`);
  await db.query("DELETE FROM event_terms WHERE event_id = ?", [id]);
  const rows = Object.entries(v).map(([term, weight]) => [id, term, weight]);
  if (rows.length) await db.query("INSERT INTO event_terms (event_id, term, weight) VALUES ?", [rows]);
}

// ---------- routes ----------
app.post("/api/login", handle(async (req, res) => {
  const { name, email } = req.body;
  await db.query(
    "INSERT INTO users (name, email) VALUES (?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name)",
    [name, String(email).toLowerCase()]
  );
  const [rows] = await db.query("SELECT user_id AS id, name, email, role FROM users WHERE email = ?", [String(email).toLowerCase()]);
  res.json(rows[0]);
}));

app.get("/api/events", handle(async (req, res) => {
  const [rows] = await db.query(
    `SELECT e.event_id AS id, e.title, e.category AS cat,
            DATE_FORMAT(e.event_date, '%Y-%m-%d') AS date,
            TIME_FORMAT(e.event_time, '%H:%i') AS time,
            e.venue, e.capacity AS cap, e.description AS \`desc\`, f.taken
     FROM events e JOIN event_fill f ON f.event_id = e.event_id
     ORDER BY e.event_date`
  );
  res.json(rows);
}));

app.get("/api/events/:id/similar", handle(async (req, res) => {
  const [rows] = await db.query(
    `SELECT e.event_id AS id, e.title,
            SUM(a.weight * b.weight) / (na.norm * nb.norm) AS score
     FROM event_terms a
     JOIN event_terms b  ON b.term = a.term AND b.event_id <> a.event_id
     JOIN event_norms na ON na.event_id = a.event_id
     JOIN event_norms nb ON nb.event_id = b.event_id
     JOIN events e       ON e.event_id = b.event_id
     WHERE a.event_id = ?
     GROUP BY e.event_id, e.title, na.norm, nb.norm
     ORDER BY score DESC LIMIT 3`,
    [req.params.id]
  );
  res.json(rows);
}));

app.get("/api/search", handle(async (req, res) => {
  const q = Object.entries(vectorize(req.query.q || "")).map(([t, w]) => ({ t, w }));
  if (!q.length) return res.json([]);
  const [rows] = await db.query(
    `WITH q AS (
       SELECT term, weight FROM JSON_TABLE(?, '$[*]'
         COLUMNS (term VARCHAR(40) PATH '$.t', weight DOUBLE PATH '$.w')) jt),
     qn AS (SELECT SQRT(SUM(weight * weight)) AS norm FROM q)
     SELECT e.event_id AS id, e.title,
            SUM(q.weight * t.weight) / (qn.norm * n.norm) AS score
     FROM q
     JOIN event_terms t ON t.term = q.term
     JOIN event_norms n ON n.event_id = t.event_id
     JOIN events e ON e.event_id = t.event_id
     CROSS JOIN qn
     GROUP BY e.event_id, e.title, qn.norm, n.norm
     ORDER BY score DESC LIMIT 5`,
    [JSON.stringify(q)]
  );
  res.json(rows);
}));

app.get("/api/registrations", handle(async (req, res) => {
  const [rows] = await db.query(
    `SELECT r.event_id AS eventId, r.status
     FROM registrations r JOIN events e ON e.event_id = r.event_id
     WHERE r.user_id = ? ORDER BY e.event_date`,
    [req.query.userId]
  );
  res.json(rows);
}));

app.post("/api/register", handle(async (req, res) => {
  const [result] = await db.query("CALL register_for_event(?, ?)", [req.body.userId, req.body.eventId]);
  res.json({ status: result[0][0].status });
}));

app.post("/api/cancel", handle(async (req, res) => {
  await db.query("CALL cancel_registration(?, ?)", [req.body.userId, req.body.eventId]);
  res.json({ ok: true });
}));

app.post("/api/events", handle(async (req, res) => {
  const b = req.body;
  if (!(await isAdmin(b.userId))) return res.status(403).json({ error: "Admins only" });
  const [r] = await db.query(
    `INSERT INTO events (title, category, description, venue, event_date, event_time, capacity, created_by)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [b.title, b.category, b.description, b.venue, b.date, b.time, b.capacity, b.userId]
  );
  await indexEvent(r.insertId, b.title, b.category, b.description);
  res.json({ id: r.insertId });
}));

app.delete("/api/events/:id", handle(async (req, res) => {
  if (!(await isAdmin(req.query.userId))) return res.status(403).json({ error: "Admins only" });
  await db.query("DELETE FROM events WHERE event_id = ?", [req.params.id]);
  res.json({ ok: true });
}));

// ---------- start ----------
(async () => {
  // Build vectors for any event that doesn't have them yet (e.g. the seed data)
  const [todo] = await db.query(
    `SELECT e.event_id, e.title, e.category, e.description FROM events e
     WHERE NOT EXISTS (SELECT 1 FROM event_terms t WHERE t.event_id = e.event_id)`
  );
  for (const e of todo) await indexEvent(e.event_id, e.title, e.category, e.description);
  const port = process.env.PORT || 3000;
  app.listen(port, () => console.log(`PetalPass running at http://localhost:${port}`));
})().catch((e) => { console.error("Could not start. Is MySQL running and .env correct?", e.message); process.exit(1); });
