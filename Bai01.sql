CREATE DATABASE mini_social_network;
USE mini_social_network;


-- Users
CREATE TABLE Users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Posts
CREATE TABLE Posts (
    post_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE
);

-- Comments
CREATE TABLE Comments (
    comment_id INT AUTO_INCREMENT PRIMARY KEY,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES Posts(post_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE
);

-- Likes
CREATE TABLE Likes (
    user_id INT NOT NULL,
    post_id INT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, post_id),
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (post_id) REFERENCES Posts(post_id) ON DELETE CASCADE
);

-- Friends
CREATE TABLE Friends (
    user_id INT NOT NULL,
    friend_id INT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, friend_id),
    CHECK (status IN ('pending', 'accepted')),
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (friend_id) REFERENCES Users(user_id) ON DELETE CASCADE
);

DELIMITER $$

-- F01: Đăng ký người dùng
CREATE PROCEDURE sp_register_user(
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255),
    IN p_email VARCHAR(100)
)
BEGIN
    DECLARE cnt INT;

    START TRANSACTION;

    SELECT COUNT(*) INTO cnt
    FROM Users
    WHERE username = p_username OR email = p_email;

    IF cnt > 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Username hoặc Email đã tồn tại';
    ELSE
        INSERT INTO Users(username, password, email)
        VALUES (p_username, p_password, p_email);
        COMMIT;
    END IF;
END$$

-- F02: Đăng bài viết
CREATE PROCEDURE sp_create_post(
    IN p_user_id INT,
    IN p_content TEXT
)
BEGIN
    INSERT INTO Posts(user_id, content)
    VALUES (p_user_id, p_content);
END$$

-- F10: Gợi ý bạn bè (bạn của bạn)
CREATE PROCEDURE sp_friend_suggestion(
    IN p_user_id INT
)
BEGIN
    SELECT DISTINCT f2.friend_id AS suggested_friend
    FROM Friends f1
    JOIN Friends f2 ON f1.friend_id = f2.user_id
    WHERE f1.user_id = p_user_id
      AND f2.friend_id <> p_user_id
      AND f2.friend_id NOT IN (
          SELECT friend_id FROM Friends WHERE user_id = p_user_id
      );
END$$

DELIMITER ;

DELIMITER $$

-- F03: Không cho like trùng
CREATE TRIGGER trg_before_like
BEFORE INSERT ON Likes
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM Likes
        WHERE user_id = NEW.user_id
          AND post_id = NEW.post_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không thể like trùng bài viết';
    END IF;
END$$

-- F04: Không cho gửi kết bạn với chính mình
CREATE TRIGGER trg_before_friend_request
BEFORE INSERT ON Friends
FOR EACH ROW
BEGIN
    IF NEW.user_id = NEW.friend_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không thể kết bạn với chính mình';
    END IF;
END$$

-- F06: Chấp nhận kết bạn thì tạo quan hệ ngược
CREATE TRIGGER trg_after_accept_friend
AFTER UPDATE ON Friends
FOR EACH ROW
BEGIN
    IF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
        INSERT IGNORE INTO Friends(user_id, friend_id, status)
        VALUES (NEW.friend_id, NEW.user_id, 'accepted');
    END IF;
END$$

DELIMITER ;


-- F07: Xem thông tin người dùng
CREATE VIEW vw_user_profile AS
SELECT user_id, username, email, created_at
FROM Users;

-- F09: Báo cáo hoạt động người dùng
CREATE VIEW vw_user_activity AS
SELECT 
    u.user_id,
    u.username,
    COUNT(DISTINCT p.post_id) AS total_posts,
    COUNT(DISTINCT c.comment_id) AS total_comments,
    COUNT(DISTINCT l.post_id) AS total_likes
FROM Users u
LEFT JOIN Posts p ON u.user_id = p.user_id
LEFT JOIN Comments c ON u.user_id = c.user_id
LEFT JOIN Likes l ON u.user_id = l.user_id
GROUP BY u.user_id, u.username;

DELIMITER $$

CREATE PROCEDURE sp_delete_user(IN p_user_id INT)
BEGIN
    START TRANSACTION;

    DELETE FROM Users WHERE user_id = p_user_id;

    COMMIT;
END$$

DELIMITER ;
