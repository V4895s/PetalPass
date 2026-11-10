-- DML: sample data
USE petalpass;

INSERT INTO users (name, email, role) VALUES
 ('Admin', 'admin@petalpass.edu', 'admin'),
 ('Asha Rao', 'asha@petalpass.edu', 'student'),
 ('Rohan Mehta', 'rohan@petalpass.edu', 'student'),
 ('Meera Nair', 'meera@petalpass.edu', 'student'),
 ('Karthik S', 'karthik@petalpass.edu', 'student'),
 ('Divya K', 'divya@petalpass.edu', 'student');

INSERT INTO events (title, category, description, venue, event_date, event_time, capacity, created_by) VALUES
 ('CodeSprint 2026','Tech','A day-long hackathon. Form teams of up to four, pick a problem statement, and ship a working prototype by evening.','Innovation Center','2026-11-24','10:00',20,1),
 ('Rangotsav Cultural Night','Culture','Music, dance and theatre performed by student clubs across departments.','Open Air Theatre','2026-12-02','18:30',50,1),
 ('Inter-department Cricket','Sports','Knockout cricket tournament with eight teams. Captains register their squad of eleven.','Main Ground','2026-11-28','08:00',3,1),
 ('Intro to SQL Indexing','Workshop','Hands-on session on how indexes speed up queries, using a real event dataset and query plans.','Lab 3, CS Block','2026-11-18','14:00',10,1),
 ('Startup Pitch Evening','Tech','Ten student teams pitch their startup ideas to a panel of alumni founders and investors.','Auditorium','2026-12-09','17:00',15,1);

INSERT INTO registrations (user_id, event_id, status) VALUES
 (2,1,'confirmed'),(3,1,'confirmed'),(4,1,'confirmed'),(5,1,'confirmed'),
 (2,2,'confirmed'),(3,2,'confirmed'),(6,2,'confirmed'),
 (2,3,'confirmed'),(3,3,'confirmed'),(4,3,'confirmed'),(5,3,'waitlist'),
 (3,4,'confirmed'),(6,4,'confirmed'),
 (2,5,'confirmed');
-- event_terms (vectors) are filled automatically when the backend starts.
