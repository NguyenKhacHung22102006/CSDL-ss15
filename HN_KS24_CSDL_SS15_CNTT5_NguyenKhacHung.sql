DROP DATABASE IF EXISTS Student_Management;
CREATE DATABASE Student_Management;
USE Student_Management;

CREATE TABLE Students (
    StudentID CHAR(5) PRIMARY KEY,
    Full_Name VARCHAR(50) NOT NULL,
    TotalDebt DECIMAL(10,2) DEFAULT 0
);

CREATE TABLE Subjects (
    SubjectID CHAR(5) PRIMARY KEY,
    Subject_Name VARCHAR(50) NOT NULL,
    Credits INT CHECK (Credits > 0)
);

CREATE TABLE Grades (
    StudentID CHAR(5),
    SubjectID CHAR(5),
    Score DECIMAL(4,2) CHECK (Score BETWEEN 0 AND 10),
    PRIMARY KEY (StudentID, SubjectID),
    FOREIGN KEY (StudentID) REFERENCES Students(StudentID),
    FOREIGN KEY (SubjectID) REFERENCES Subjects(SubjectID)
);

CREATE TABLE GradeLog (
    LogID INT PRIMARY KEY AUTO_INCREMENT,
    StudentID CHAR(5),
    OldScore DECIMAL(4,2),
    NewScore DECIMAL(4,2),
    ChangeDatea DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO Students (StudentID, Full_Name, TotalDebt) VALUES
('SV01', 'Ho Khanh Linh', 5000000),
('SV03', 'Tran Thi Khanh Huyen', 0);

INSERT INTO Subjects (SubjectID, Subject_Name, Credits) VALUES
('SB01', 'Co so du lieu', 3),
('SB02', 'Lap trinh Java', 4),
('SB03', 'Lap trinh C', 3);

INSERT INTO Grades (StudentID, SubjectID, Score) VALUES
('SV01', 'SB01', 8.5),
('SV03', 'SB02', 3.0);

DELIMITER $$

CREATE TRIGGER tg_CheckScore
BEFORE INSERT ON Grades
FOR EACH ROW
BEGIN
    IF NEW.Score < 0 THEN
        SET NEW.Score = 0;
    ELSEIF NEW.Score > 10 THEN
        SET NEW.Score = 10;
    END IF;
END$$

CREATE TRIGGER tg_LogGradeUpdate
AFTER UPDATE ON Grades
FOR EACH ROW
BEGIN
    IF OLD.Score <> NEW.Score THEN
        INSERT INTO GradeLog (StudentID, OldScore, NewScore, ChangeDatea)
        VALUES (OLD.StudentID, OLD.Score, NEW.Score, NOW());
    END IF;
END$$

CREATE TRIGGER tg_PreventPassUpdate
BEFORE UPDATE ON Grades
FOR EACH ROW
BEGIN
    IF OLD.Score >= 4.0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Khong duoc sua diem khi da qua mon';
    END IF;
END$$

CREATE PROCEDURE sp_PayTuition()
BEGIN
    DECLARE v_Debt DECIMAL(10,2);

    START TRANSACTION;

    UPDATE Students
    SET TotalDebt = TotalDebt - 2000000
    WHERE StudentID = 'SV01';

    SELECT TotalDebt INTO v_Debt
    FROM Students
    WHERE StudentID = 'SV01';

    IF v_Debt < 0 THEN
        ROLLBACK;
    ELSE
        COMMIT;
    END IF;
END$$

CREATE PROCEDURE sp_DeleteStudentGrade (
    IN p_StudentID CHAR(5),
    IN p_SubjectID CHAR(5)
)
BEGIN
    DECLARE v_OldScore DECIMAL(4,2);

    START TRANSACTION;

    SELECT Score INTO v_OldScore
    FROM Grades
    WHERE StudentID = p_StudentID
      AND SubjectID = p_SubjectID;

    INSERT INTO GradeLog (StudentID, OldScore, NewScore, ChangeDatea)
    VALUES (p_StudentID, v_OldScore, NULL, NOW());

    DELETE FROM Grades
    WHERE StudentID = p_StudentID
      AND SubjectID = p_SubjectID;

    IF ROW_COUNT() = 0 THEN
        ROLLBACK;
    ELSE
        COMMIT;
    END IF;
END$$

DELIMITER ;

START TRANSACTION;

INSERT INTO Students (StudentID, Full_Name)
VALUES ('SV02', 'Ha Bich Ngoc');

UPDATE Students
SET TotalDebt = 5000000
WHERE StudentID = 'SV02';

COMMIT;

SELECT * FROM Students;
SELECT * FROM Grades;
SELECT * FROM GradeLog;
