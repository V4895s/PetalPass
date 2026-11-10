-- DDL: tables, constraints, views
DROP DATABASE IF EXISTS petalpass;
CREATE DATABASE petalpass;
USE petalpass;

CREATE TABLE users (
  user_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(150) NOT NULL UNIQUE,
  role ENUM('student','admin') NOT NULL DEFAULT 'student',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE events (
  event_id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(150) NOT NULL,
  category ENUM('Tech','Culture','Sports','Workshop') NOT NULL,
  description TEXT,
  venue VARCHAR(150) NOT NULL,
  event_date DATE NOT NULL,
  event_time TIME NOT NULL,
  capacity INT NOT NULL CHECK (capacity > 0),
  created_by INT NULL,
  FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE SET NULL,
  INDEX idx_event_date (event_date)
);

CREATE TABLE registrations (
  registration_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  event_id INT NOT NULL,
  status ENUM('confirmed','waitlist') NOT NULL,
  registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_user_event (user_id, event_id),
  FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
  FOREIGN KEY (event_id) REFERENCES events(event_id) ON DELETE CASCADE
);

CREATE TABLE cancellation_log (
  log_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  event_id INT NOT NULL,
  old_status VARCHAR(10),
  cancelled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Vector search: each event is a sparse term-weight vector
CREATE TABLE event_terms (
  event_id INT NOT NULL,
  term VARCHAR(40) NOT NULL,
  weight DOUBLE NOT NULL,
  PRIMARY KEY (event_id, term),
  FOREIGN KEY (event_id) REFERENCES events(event_id) ON DELETE CASCADE
);

CREATE VIEW event_norms AS
SELECT event_id, SQRT(SUM(weight * weight)) AS norm
FROM event_terms GROUP BY event_id;

CREATE VIEW event_fill AS
SELECT e.event_id, e.capacity,
       COUNT(r.registration_id) AS taken,
       COUNT(r.registration_id) / e.capacity AS fill
FROM events e
LEFT JOIN registrations r ON r.event_id = e.event_id AND r.status = 'confirmed'
GROUP BY e.event_id, e.capacity;
