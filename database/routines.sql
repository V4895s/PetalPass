-- Procedures and triggers
USE petalpass;
DROP PROCEDURE IF EXISTS register_for_event;
DROP PROCEDURE IF EXISTS cancel_registration;
DROP TRIGGER IF EXISTS block_past_events;
DROP TRIGGER IF EXISTS log_cancel;

DELIMITER //

-- Confirms the student if seats remain, otherwise adds them to the waitlist.
CREATE PROCEDURE register_for_event(IN p_user INT, IN p_event INT)
BEGIN
  DECLARE v_cap INT;
  DECLARE v_taken INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;
  SELECT capacity INTO v_cap FROM events WHERE event_id = p_event FOR UPDATE;
  SELECT COUNT(*) INTO v_taken FROM registrations
   WHERE event_id = p_event AND status = 'confirmed';
  INSERT INTO registrations (user_id, event_id, status)
  VALUES (p_user, p_event, IF(v_taken < v_cap, 'confirmed', 'waitlist'));
  COMMIT;

  SELECT status FROM registrations WHERE user_id = p_user AND event_id = p_event;
END //

-- Cancels, then promotes the longest-waiting student if a seat was freed.
CREATE PROCEDURE cancel_registration(IN p_user INT, IN p_event INT)
BEGIN
  DECLARE v_status VARCHAR(10);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;
  SELECT status INTO v_status FROM registrations
   WHERE user_id = p_user AND event_id = p_event FOR UPDATE;
  DELETE FROM registrations WHERE user_id = p_user AND event_id = p_event;
  IF v_status = 'confirmed' THEN
    UPDATE registrations SET status = 'confirmed'
     WHERE event_id = p_event AND status = 'waitlist'
     ORDER BY registered_at, registration_id LIMIT 1;
  END IF;
  COMMIT;
END //

-- Trigger 1: no registering for events that already happened.
CREATE TRIGGER block_past_events BEFORE INSERT ON registrations
FOR EACH ROW
BEGIN
  IF (SELECT event_date FROM events WHERE event_id = NEW.event_id) < CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This event has already taken place';
  END IF;
END //

-- Trigger 2: audit every cancellation.
CREATE TRIGGER log_cancel AFTER DELETE ON registrations
FOR EACH ROW
BEGIN
  INSERT INTO cancellation_log (user_id, event_id, old_status)
  VALUES (OLD.user_id, OLD.event_id, OLD.status);
END //

DELIMITER ;
