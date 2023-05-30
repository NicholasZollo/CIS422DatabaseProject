-- Online Game Community System 
-- Design and Implementation with DBMS Project

-- Tables

CREATE TABLE User ( 
Username VARCHAR(30) PRIMARY KEY, 
Password VARCHAR(24) NOT NULL, 
Email VARCHAR(40) NOT NULL UNIQUE, 
RegistrationDate DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, 
Points INT NOT NULL DEFAULT 0); 

CREATE TABLE Level (  
LevelName VARCHAR(30) PRIMARY KEY, 
Creator VARCHAR(30) NOT NULL,  
LevelFile VARCHAR(50) NOT NULL UNIQUE,  
AverageQuality DECIMAL(4, 2) NOT NULL DEFAULT 5, 
AverageDifficulty DECIMAL(4, 2) NOT NULL DEFAULT 5); 

CREATE TABLE Completes ( 
Username VARCHAR(30) NOT NULL, 
LevelName VARCHAR(30) NOT NULL, 
SpeedOfCompletion TIME(2) NOT NULL, 
DateTimeOfCompletion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,  
ReplayFile VARCHAR(50) UNIQUE, 
PRIMARY KEY (Username, LevelName)); 

CREATE TABLE Message ( 
MessageId INT PRIMARY KEY AUTO_INCREMENT, 
Sender VARCHAR(30) NOT NULL, 
Recipient VARCHAR(30), 
MessageText VARCHAR(500) NOT NULL, 
DateTimeSent DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP); 

CREATE TABLE LevelComment ( 
MessageId INT PRIMARY KEY, 
LevelName VARCHAR(30) NOT NULL, 
DifficultyRating INT, 
QualityRating INT);

-- Views

CREATE VIEW LevelRanking(Level, User, Time, Ranking, DateAchieved) AS 
SELECT L.LevelName, C.Username, C.SpeedOfCompletion, RANK() OVER ( 
PARTITION BY C.LevelName 
ORDER BY C.SpeedOfCompletion) level_rank, C.DateTimeOfCompletion 
FROM Level L, Completes C 
WHERE L.LevelName = C.LevelName 
ORDER BY L.LevelName, level_rank; 

CREATE VIEW OverallRanking (User, Ranking, Points) AS 
SELECT Username, RANK() OVER ( 
ORDER BY Points DESC) ovr_rank, Points 
FROM User; 

CREATE VIEW CompletionPoints (Level, User, Points) AS 
SELECT LR1.Level, LR1.User, (40*L.AverageDifficulty + 800 *(1 - LR1.Ranking /  
(SELECT COUNT(*) 
FROM LevelRanking LR2 
WHERE LR1.Level = LR2.Level))) points 
FROM LevelRanking LR1, Level L 
WHERE LR1.Level = L.LevelName 
ORDER BY LR1.User, points DESC; 

CREATE VIEW UserProfile (Username, RegistrationDate, Points, OverallRank) AS 
SELECT U.Username, U.RegistrationDate, U.Points, O.Ranking 
FROM User U, OverallRanking O 
WHERE U.Username = O.User; 

CREATE VIEW LevelProfile (LevelName, Creator, AverageQuality, AverageDifficulty, LevelFile) AS 
SELECT LevelName, Creator, AverageQuality, AverageDifficulty, LevelFile 
FROM Level; 

CREATE VIEW PublicMessageBox (Sender, DateTimeSent, MessageText) AS 
SELECT Sender, DateTimeSent, MessageText 
FROM Message 
WHERE Recipient IS NULL AND (NOT EXISTS( 
SELECT * 
FROM LevelComment 
WHERE Message.MessageId = LevelComment.MessageId) ) 
ORDER BY DateTimeSent DESC; 

CREATE VIEW LevelCommentView (LevelName, Sender, DateTimeSent, MessageText, QualityRating, DifficultyRating) AS 
SELECT L.LevelName, M.Sender, M.DateTimeSent, M.MessageText, LC.QualityRating, LC.DifficultyRating 
FROM Level L, LevelComment LC, Message M 
WHERE L.LevelName = LC.LevelName AND M.MessageId = LC.MessageId 
ORDER BY L.LevelName, M.DateTimeSent DESC; 

CREATE VIEW PrivateMessageHistory (Sender, Recipient, DateTimeSent, MessageText) AS 
SELECT Sender, Recipient, DateTimeSent, MessageText 
FROM Message 
WHERE Recipient IS NOT NULL 
ORDER BY Recipient, Sender, DateTimeSent DESC;

-- Constraints

ALTER TABLE User ENGINE=InnoDB; 
ALTER TABLE Level ENGINE=InnoDB; 
ALTER TABLE Completes ENGINE=InnoDB; 
ALTER TABLE Message ENGINE=InnoDB; 
ALTER TABLE LevelComment ENGINE=InnoDB; 

ALTER TABLE Level 
ADD FOREIGN KEY (Creator) REFERENCES User(Username) ON UPDATE CASCADE ON DELETE CASCADE; 

ALTER TABLE Completes 
ADD FOREIGN KEY (Username) REFERENCES User(Username) ON UPDATE CASCADE ON DELETE CASCADE; 

ALTER TABLE Completes 
ADD FOREIGN KEY (LevelName) REFERENCES Level(LevelName) ON DELETE CASCADE; 

ALTER TABLE Message 
ADD FOREIGN KEY (Sender) REFERENCES User(Username) ON UPDATE CASCADE ON DELETE CASCADE; 

ALTER TABLE Message 
ADD FOREIGN KEY (Recipient) REFERENCES User(Username) ON UPDATE CASCADE ON DELETE CASCADE; 

ALTER TABLE LevelComment 
ADD FOREIGN KEY (MessageId) REFERENCES Message(MessageId) ON UPDATE CASCADE ON DELETE CASCADE; 

ALTER TABLE LevelComment 
ADD FOREIGN KEY (LevelName) REFERENCES Level(LevelName) ON UPDATE CASCADE ON DELETE CASCADE; 

ALTER TABLE LevelComment  
ADD CONSTRAINT QualityRatingValue CHECK (QualityRating < 11 AND 
QualityRating > 0); 

ALTER TABLE LevelComment 
ADD CONSTRAINT DifficultyRatingValue CHECK (DifficultyRating < 11 AND 
DifficultyRating > 0); 

ALTER TABLE User 
ADD CONSTRAINT PasswordLength CHECK (LENGTH(Password) >= 8); 

ALTER TABLE User 
ADD CONSTRAINT CheckEmail CHECK (Email LIKE '%___@___%.__%');

-- Triggers

DELIMITER $$ 

CREATE TRIGGER ImproveTime  
BEFORE UPDATE ON Completes 
FOR EACH ROW  
BEGIN 
IF (OLD.SpeedOfCompletion < NEW.SpeedOfCompletion) THEN 
SIGNAL SQLSTATE '45000' 
SET MESSAGE_TEXT = ' Speed of Completion must improve to update. '; 
END IF; 
END$$ 

CREATE TRIGGER LevelCommentPublic 
BEFORE INSERT ON LevelComment 
FOR EACH ROW 
BEGIN 
IF((SELECT Recipient 
FROM Message 
WHERE Message.MessageId = new.MessageId) IS NOT NULL)	 
THEN 
SIGNAL SQLSTATE '45000' 
SET MESSAGE_TEXT = 'Level Comments must be public messages.'; 
END IF; 
END$$ 

CREATE TRIGGER UpdateAverageRatings 
AFTER INSERT ON LevelComment 
FOR EACH ROW 
UPDATE Level 
SET AverageQuality = ( 
SELECT AVG(QualityRating) 
FROM LevelComment 
WHERE LevelComment.LevelName = new.LevelName ), 
AverageDifficulty = ( 
SELECT AVG(DifficultyRating) 
FROM LevelComment 
WHERE LevelComment.LevelName = new.LevelName ) 
WHERE Level.LevelName = new.LevelName $$ 

CREATE TRIGGER UpdateUserPointsInsert 
AFTER INSERT ON Completes 
FOR EACH ROW 
UPDATE User 
SET Points = ( 
SELECT SUM(Points) 
FROM CompletionPoints 
WHERE CompletionPoints.User = new.Username) 
WHERE User.Username = new.Username $$ 

CREATE TRIGGER UpdateUserPointsUpdate 
AFTER UPDATE ON Completes 
FOR EACH ROW 
UPDATE User 
SET Points = ( 
SELECT SUM(Points) 
FROM CompletionPoints 
WHERE CompletionPoints.User = new.Username) 
WHERE User.Username = new.Username $$ 

CREATE TRIGGER UpdateUserPointsDelete 
AFTER DELETE ON Completes 
FOR EACH ROW 
UPDATE User 
SET Points = ( 
SELECT SUM(Points) 
FROM CompletionPoints 
WHERE CompletionPoints.User = old.Username) 
WHERE User.Username = old.Username $$ 

CREATE TRIGGER UpdateUserPointsComment 
AFTER INSERT ON LevelComment 
FOR EACH ROW 
UPDATE User 
SET Points = ( 
SELECT SUM(Points) 
FROM CompletionPoints 
WHERE CompletionPoints.User = User.Username) $$ 

DELIMITER ; 

-- Data

INSERT INTO User (Username, Password, Email) 
VALUES ('hello145', 'Password1234', 'helloitsme@gmail.com'), 
('bye2', 'goodbye54321', 'thisisyou@yahoo.com'), 
('Nick', 'porkhammer', 'nickz1998@gmail.com'), 
('Beyza', 'HFdk$s43jb3!7', 'beyza1524@gmail.com'), 
('Zach', '0123456789', 'cool_zach_XD@gmail.com'), 
('Gamer3421', '4XmLqkDez7o', 'Gamer932@gmail.com'), 
('Sheri3753', 'SheriPass8342', ' sheri.543@gmail.com'), 
('Ryan12', 'V3PBkfh382', 'ryan_546@gmail.com'), 
('haleygames', 'haley92834!!', 'haley1875@gmail.com'), 
('jacob890', 'jacob_234!', 'jacob.G123@gmail.com');  

INSERT INTO Level (Creator, LevelName, LevelFile) 
VALUES ('hello145', 'Playground', 'https://www.game.com/files/Level1.lvl'), 
('hello145', 'Playground for Pros', 'https://www.game.com/files/Level2.lvl'), 
('Zach', 'Clouds', 'https://www.game.com/files/Level3.lvl'), 
('bye2', 'cool level', 'https://www.game.com/files/Level4.lvl'), 
('Nick', 'Factory', 'https://www.game.com/files/Level5.lvl'), 
('hello145', 'Volcano', 'https://www.game.com/files/Level6.lvl'), 
('Nick', 'Fortress', 'https://www.game.com/files/Level7.lvl'), 
('Zach', 'Hell', 'https://www.game.com/files/Level8.lvl'), 
('Sheri3753', 'my first level', 'https://www.game.com/files/Level9.lvl'), 
('Sheri3753', 'pastel world', 'https://www.game.com/files/Level10.lvl'); 

INSERT INTO Completes (Username, LevelName, SpeedOfCompletion, ReplayFile) 
VALUES ('Ryan12', 'Playground', '00:01:29.65', 'https://www.game.com/files/Replay1.mp4'), 
('Ryan12', 'Playground for Pros', '01:22:56.35', 'https://www.game.com/files/Replay2.mp4'), 
('Ryan12', 'Clouds', '00:02:40.00', 'https://www.game.com/files/Replay3.mp4'), 
('Ryan12', 'cool level', '00:03:12.24', 'https://www.game.com/files/Replay4.mp4'), 
('Ryan12', 'Factory', '00:05:01.35', 'https://www.game.com/files/Replay5.mp4'), 
('Ryan12', 'Volcano', '00:12:32.98', 'https://www.game.com/files/Replay6.mp4'), 
('Ryan12', 'Fortress', '00:08:32.63', 'https://www.game.com/files/Replay7.mp4'), 
('Ryan12', 'Hell', '05:46:59.33', 'https://www.game.com/files/Replay8.mp4'), 
('Ryan12', 'my first level', '00:00:46.91', 'https://www.game.com/files/Replay9.mp4'), 
('Ryan12', 'pastel world', '00:02:15.65', 'https://www.game.com/files/Replay10.mp4'),  
('hello145', 'Playground', '00:02:34.56', 'https://www.game.com/files/Replay11.mp4'), 
('hello145', 'Playground for Pros', '02:01:54.06', NULL), 
('hello145', 'Clouds', '00:08:54.06', NULL), 
('hello145', 'Factory', '00:35:54.06', NULL), 
('hello145', 'Volcano', '00:15:54.06', NULL), 
('hello145', 'Fortress', '02:01:54.06', NULL), 
('hello145', 'pastel world', '00:03:54.06', NULL), 
('Zach', 'Playground', '00:03:52.16', NULL), 
('Zach', 'Playground for Pros', '01:34:05.20', 'https://www.game.com/files/Replay12.mp4'), 
('Zach', 'Clouds', '00:04:05.34', NULL), 
('Zach', 'cool level', '00:05:40.44', NULL), 
('Zach', 'Factory', '00:08:40.44', NULL), 
('Zach', 'Volcano', '00:11:29.31', 'https://www.game.com/files/Replay14.mp4'), 
('Zach', 'Fortress', '00:11:29.31', NULL), 
('Zach', 'my first level', '00:11:29.31', NULL), 
('Zach', 'pastel world', '00:04:29.31', NULL), 
('Nick', 'Playground', '00:01:23.16', 'https://www.game.com/files/Replay13.mp4'), 
('Nick', 'Playground for Pros', '04:44:35.24', NULL), 
('Nick', 'Factory', '00:05:25.24', NULL), 
('Nick', 'Fortress', '00:08:35.24', NULL), 
('Nick', 'Hell', '02:44:35.24', 'https://www.game.com/files/Replay15.mp4'), 
('bye2', 'Playground', '00:34:35.24', NULL), 
('bye2', 'cool level', '00:44:35.24', NULL), 
('Beyza', 'Playground', '00:24:35.24', NULL), 
('Beyza', 'Playground for Pros', '05:24:35.24', NULL), 
('Beyza', 'Clouds', '00:54:35.24', NULL), 
('Beyza', 'cool level', '00:54:35.24', NULL), 
('Beyza', 'Factory', '01:24:35.24', NULL), 
('Beyza', 'Volcano', '02:24:35.24', NULL), 
('Beyza', 'Fortress', '01:54:35.24', NULL), 
('Beyza', 'Hell', '11:34:35.24', NULL), 
('Beyza', 'my first level', '00:14:35.24', NULL), 
('Beyza', 'pastel world', '00:24:35.24', NULL),  
('Gamer3421', 'Playground', '00:20:30.24', NULL), 
('Gamer3421', 'Clouds', '00:20:30.24', NULL), 
('Gamer3421', 'cool level', '00:20:30.24', NULL), 
('Gamer3421', 'Factory', '00:20:30.24', NULL), 
('Gamer3421', 'Volcano', '00:20:30.24', NULL), 
('Gamer3421', 'Fortress', '00:20:30.24', NULL), 
('Gamer3421', 'my first level', '00:20:30.24', NULL), 
('Gamer3421', 'pastel world', '00:20:30.24', NULL), 
('Sheri3753', 'Playground', '00:08:30.24', NULL), 
('Sheri3753', 'my first level', '00:00:45.24', NULL), 
('Sheri3753', 'pastel world', '00:02:30.24', NULL), 
('haleygames', 'Playground', '00:04:35.13', NULL), 
('haleygames', 'Clouds', '00:03:59.24', NULL), 
('haleygames', 'Volcano', '00:33:59.24', NULL), 
('haleygames', 'Factory', '00:13:59.24', NULL), 
('haleygames', 'pastel world', '00:04:59.24', NULL), 
('jacob890', 'Playground', '00:14:39.24', NULL); 

INSERT INTO Message (Sender, Recipient, MessageText) 
VALUES ('hello145', NULL, 'Hi everyone :) Hope you like my levels!'), 
('Nick', 'Zach', 'How did you beat Playground for Pros so fast?'), 
('Nick', NULL, 'OMG I JUST BEAT PLAYGROUND FOR PROS!!'), 
('Nick', NULL, 'This level is really fun to play over and over and improve your time.'), 
('Zach', NULL, 'The hardest and most fun level I played yet. Tests all of the skills in the game.'), 
('Gamer3421', NULL, 'I cant beat it..'), 
('Zach', NULL, 'this level is really fun to speedrun!'), 
('Zach', NULL, 'sorry but I dont really like it'), 
('Nick', NULL, 'what is this? Try harder next time!!!'), 
('Ryan12', NULL, 'its not good, but kinda fun to speedrun'), 
('Ryan12', NULL, 'old classic, one of my favorites'), 
('jacob890', NULL, 'i liked it'), 
('Sheri3753', NULL, 'I based my own levels off of this one, since its so good.'), 
('Ryan12', NULL, 'good level for people who want to get into harder stuff'), 
('Ryan12', NULL, 'really really good'), 
('Beyza', NULL, 'this was really hard for me for some reason'), 
('Ryan12', NULL, 'tough at first, but it has some really cool speedrun strats'), 
('Nick', NULL, 'my favorite level'), 
('Zach', NULL, 'grinding the world record made me hate this level'), 
('hello145', NULL, 'I really liked it. Tough but fair.'), 
('Gamer3421', NULL, 'really really fun'), 
('Beyza', NULL, 'TOO hard. This took me WEEKS'), 
('hello145', NULL, 'A good start, but not too interesting.'), 
('hello145', NULL, 'The visuals on this are really amazing. The map is fun too!'), 
('haleygames', NULL, 'soooo pretty'), 
('Nick', NULL, 'ryan is so good'), 
('jacob890', NULL, 'how do I play?'), 
('jacob890', NULL, 'im new'), 
('haleygames', NULL, 'hi guys :)'), 
('hello145', NULL, 'omg ryan'), 
('Zach', NULL, 'pow'), 
('Nick', NULL, 'nice run'), 
('Beyza', NULL, 'real?'), 
('Nick', 'Ryan12', 'ur the goat'), 
('Zach', 'Ryan12', 'no way u went that fast'), 
('Ryan12', 'Beyza', 'nice fucking job'), 
('Zach', 'Beyza', 'how did you beat Hell??? How long did that take omg'), 
('jacob890', 'haleygames', 'wyd?'), 
('hello145', 'Nick', 'im making a new level, do you mind testing it?'); 

INSERT INTO LevelComment (MessageId, LevelName, DifficultyRating, QualityRating) 
VALUES (4, 'Playground', 2, 8), 
(5, 'Playground for Pros', 8, 9), 
(6, 'Hell', 10, NULL), 
(7, 'Clouds', 4, 8), 
(8, 'cool level', 5, 2), 
(9, 'cool level', 6, 1), 
(10, 'cool level', 3, 4), 
(11, 'Playground', 4, 10), 
(12, 'Playground', 5, 8), 
(13, 'Playground', 4, 10), 
(14, 'Playground for Pros', 8, 7), 
(15, 'Clouds', 4, 9), 
(16, 'Factory', 8, 7), 
(17, 'Factory', 6, 9), 
(18, 'Factory', 5, 10), 
(19, 'Volcano', 7, 5), 
(20, 'Fortress', 8, 9), 
(21, 'Fortress', 7, 9), 
(22, 'Hell', 10, 7), 
(23, 'my first level', 3, 5), 
(24, 'pastel world', 5, 9), 
(25, 'pastel world', 4, 8), 
(26, 'pastel world', 4, 8); 