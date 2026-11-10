# PetalPass: smart campus event registration

Frontend (HTML/JS) → Backend (Node + Express) → Database (MySQL). All queries are written as raw SQL.

## Setup
1. Install Node.js and MySQL 8 or newer.
2. Create the database, in this order:
   ```bash
   mysql -u root -p < database/schema.sql
   mysql -u root -p < database/routines.sql
   mysql -u root -p < database/seed.sql
   ```
3. Start the backend:
   ```bash
   cd backend
   cp .env.example .env      # then put your MySQL password in .env
   npm install
   npm start
   ```
4. Open http://localhost:3000

Sign in with any name and email. `admin@petalpass.edu` gets the Admin page. There are no API keys: the only secret is your own MySQL password, kept in `.env` (git-ignored).

## Where each requirement lives
| Requirement | File |
|---|---|
| DDL (tables, keys, CHECK, UNIQUE, views) | `database/schema.sql` |
| DML (INSERT, UPDATE, DELETE) | `database/seed.sql`, `database/queries.sql`, `backend/server.js` |
| Joins | `database/queries.sql` (queries 1-3), `backend/server.js` |
| Correlated queries | `database/queries.sql` (queries 4-6) |
| Stored procedures | `database/routines.sql`: `register_for_event`, `cancel_registration` |
| Triggers | `database/routines.sql`: `block_past_events`, `log_cancel` |
| Vector search | `event_terms` table, `event_norms` view, `/api/events/:id/similar`, `/api/search` |
| How JS calls the SQL | `backend/server.js` (`CALL register_for_event(?, ?)`, etc.), `frontend/index.html` (`fetch`) |

## Demo script
1. Show `schema.sql`, then run the queries in `queries.sql` one by one in the MySQL console.
2. Open the app, sign in as a student, and register for "Inter-department Cricket". It is full, so you get the waitlist. `CALL register_for_event` in `server.js` is what runs.
3. Cancel a confirmed seat and show the waitlisted student promoted and the row in `cancellation_log`.
4. Open any event and show "Similar events". That is the cosine-similarity SQL in `/api/events/:id/similar`.
5. Sign in as admin, add an event, and show it in the `events` table.
