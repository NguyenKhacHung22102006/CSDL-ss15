CREATE DATABASE mini_social_network_practice;
USE mini_social_network_practice;

CREATE TABLE Users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Posts (
    post_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    like_count INT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE
);

CREATE TABLE Comments (
    comment_id INT AUTO_INCREMENT PRIMARY KEY,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES Posts(post_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE
);

CREATE TABLE Likes (
    user_id INT,
    post_id INT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, post_id),
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (post_id) REFERENCES Posts(post_id) ON DELETE CASCADE
);

CREATE TABLE Friends (
    user_id INT,
    friend_id INT,
    status VARCHAR(20) DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, friend_id),
    CHECK (status IN ('pending','accepted')),
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (friend_id) REFERENCES Users(user_id) ON DELETE CASCADE
);

CREATE TABLE user_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    action VARCHAR(100),
    log_time DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE post_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    post_id INT,
    action VARCHAR(100),
    log_time DATETIME DEFAULT CURRENT_TIMESTAMP
);

DELIMITER $$

CREATE PROCEDURE sp_register_user(
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255),
    IN p_email VARCHAR(100)
)
BEGIN
    DECLARE cnt INT;
    START TRANSACTION;
    SELECT COUNT(*) INTO cnt FROM Users
    WHERE username = p_username OR email = p_email;
    IF cnt > 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Trung username hoac email';
    ELSE
        INSERT INTO Users(username,password,email)
        VALUES(p_username,p_password,p_email);
        COMMIT;
    END IF;
END$$

CREATE TRIGGER trg_user_log
AFTER INSERT ON Users
FOR EACH ROW
BEGIN
    INSERT INTO user_log(user_id,action)
    VALUES(NEW.user_id,'Dang ky tai khoan');
END$$

CREATE PROCEDURE sp_create_post(
    IN p_user_id INT,
    IN p_content TEXT
)
BEGIN
    IF p_content IS NULL OR p_content='' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Noi dung rong';
    ELSE
        INSERT INTO Posts(user_id,content)
        VALUES(p_user_id,p_content);
    END IF;
END$$

CREATE TRIGGER trg_post_log
AFTER INSERT ON Posts
FOR EACH ROW
BEGIN
    INSERT INTO post_log(post_id,action)
    VALUES(NEW.post_id,'Dang bai viet');
END$$

CREATE TRIGGER trg_like_inc
AFTER INSERT ON Likes
FOR EACH ROW
BEGIN
    UPDATE Posts SET like_count = like_count + 1
    WHERE post_id = NEW.post_id;
END$$

CREATE TRIGGER trg_like_dec
AFTER DELETE ON Likes
FOR EACH ROW
BEGIN
    UPDATE Posts SET like_count = like_count - 1
    WHERE post_id = OLD.post_id;
END$$

CREATE PROCEDURE sp_send_friend_request(
    IN p_sender INT,
    IN p_receiver INT
)
BEGIN
    IF p_sender = p_receiver THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Khong tu ket ban';
    END IF;
    IF EXISTS (
        SELECT 1 FROM Friends
        WHERE user_id=p_sender AND friend_id=p_receiver
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Da ton tai loi moi';
    END IF;
    INSERT INTO Friends(user_id,friend_id,status)
    VALUES(p_sender,p_receiver,'pending');
END$$

CREATE TRIGGER trg_accept_friend
AFTER UPDATE ON Friends
FOR EACH ROW
BEGIN
    IF OLD.status='pending' AND NEW.status='accepted' THEN
        INSERT IGNORE INTO Friends(user_id,friend_id,status)
        VALUES(NEW.friend_id,NEW.user_id,'accepted');
    END IF;
END$$

CREATE PROCEDURE sp_update_friend(
    IN p_u1 INT,
    IN p_u2 INT,
    IN p_action VARCHAR(10)
)
BEGIN
    START TRANSACTION;
    IF p_action='delete' THEN
        DELETE FROM Friends WHERE
        (user_id=p_u1 AND friend_id=p_u2)
        OR (user_id=p_u2 AND friend_id=p_u1);
    ELSE
        UPDATE Friends SET status='accepted'
        WHERE user_id=p_u1 AND friend_id=p_u2;
    END IF;
    COMMIT;
END$$

CREATE PROCEDURE sp_delete_post(
    IN p_post_id INT,
    IN p_user_id INT
)
BEGIN
    DECLARE owner_id INT;
    START TRANSACTION;
    SELECT user_id INTO owner_id FROM Posts WHERE post_id=p_post_id;
    IF owner_id<>p_user_id THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Khong co quyen xoa';
    ELSE
        DELETE FROM Posts WHERE post_id=p_post_id;
        COMMIT;
    END IF;
END$$

CREATE PROCEDURE sp_delete_user(
    IN p_user_id INT
)
BEGIN
    START TRANSACTION;
    DELETE FROM Users WHERE user_id=p_user_id;
    COMMIT;
END$$

DELIMITER ;

INSERT INTO Users(username,password,email) VALUES
('hung','123','hung@gmail.com'),
('an','123','an@gmail.com'),
('binh','123','binh@gmail.com');

CALL sp_create_post(1,'Bai viet 1');
CALL sp_create_post(1,'Bai viet 2');
CALL sp_create_post(2,'Bai viet 3');

INSERT INTO Likes VALUES (2,1,NOW());
INSERT INTO Likes VALUES (3,1,NOW());
DELETE FROM Likes WHERE user_id=2 AND post_id=1;

CALL sp_send_friend_request(1,2);
UPDATE Friends SET status='accepted' WHERE user_id=1 AND friend_id=2;

CALL sp_delete_post(1,1);

CALL sp_delete_user(3);

SELECT * FROM Users;
SELECT * FROM Posts;
SELECT * FROM Friends;
SELECT * FROM user_log;
SELECT * FROM post_log;
