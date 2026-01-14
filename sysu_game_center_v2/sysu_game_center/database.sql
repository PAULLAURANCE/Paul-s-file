
/*P是主键、F是外键
关系模式：
用户表（用户编号P，用户昵称，用户等级，用户余额，用户邮箱，用户密码）
游戏信息表（游戏编号P，开发商编号F，游戏名称，价格，已售数量，发布日期）
游戏开发商表（开发商编号P，开发商名称，余额，所属国家）
DLC信息表（DLC编号P，游戏编号F，DLC名称，价格，已售数量，发布日期）
用户游戏库明细表（消费记录编号P，用户编号F，商品类型，游戏编号F，DLC编号F，购买日期）
好友关系表（关系编号P，用户编号F，用户编号F）
评分记录表（评分记录编号P，用户编号F，游戏编号F，分值（0-10分），评分日期）
愿望单表（愿望单记录编号P，用户编号F，游戏编号F，愿望单记录创建日期）
*/


/*=======================建表语句========================*/
CREATE DATABASE IF NOT EXISTS sysu_game_center
DEFAULT CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;
USE sysu_game_center;

-- 1. 游戏开发商表
CREATE TABLE `Developer` (
    `dev_id` INT AUTO_INCREMENT COMMENT '开发商编号P',
    `dev_name` VARCHAR(100) NOT NULL COMMENT '开发商名称',
    `balance` DECIMAL(15, 2) DEFAULT 0.00 COMMENT '余额',
    `country` VARCHAR(50) COMMENT '所属国家',
    PRIMARY KEY (`dev_id`)
) ENGINE=InnoDB;
-- 2. 用户表
CREATE TABLE `User` (
    `user_id` INT AUTO_INCREMENT COMMENT '用户编号P',
    `nickname` VARCHAR(50) NOT NULL COMMENT '用户昵称',
    `user_level` INT DEFAULT 1 COMMENT '用户等级',
    `balance` DECIMAL(15, 2) DEFAULT 0.00 COMMENT '用户余额',
    `email` VARCHAR(100) UNIQUE NOT NULL COMMENT '用户邮箱',
    `password` VARCHAR(255) NOT NULL COMMENT '用户密码',
    PRIMARY KEY (`user_id`)
) ENGINE=InnoDB;
-- 3. 游戏信息表
CREATE TABLE `Game` (
    `game_id` INT AUTO_INCREMENT COMMENT '游戏编号P',
    `dev_id` INT NOT NULL COMMENT '开发商编号F',
    `game_name` VARCHAR(150) NOT NULL COMMENT '游戏名称',
    `price` DECIMAL(10, 2) DEFAULT 0.00 COMMENT '价格',
    `sold_count` INT DEFAULT 0 COMMENT '已售数量',
    `release_date` DATE COMMENT '发布日期',
    PRIMARY KEY (`game_id`),
    CONSTRAINT `fk_game_dev` FOREIGN KEY (`dev_id`) REFERENCES `Developer` (`dev_id`) ON DELETE CASCADE
) ENGINE=InnoDB;
-- 4. DLC信息表
CREATE TABLE `DLC` (
    `dlc_id` INT AUTO_INCREMENT COMMENT 'DLC编号P',
    `game_id` INT NOT NULL COMMENT '游戏编号F',
    `dlc_name` VARCHAR(150) NOT NULL COMMENT 'DLC名称',
    `price` DECIMAL(10, 2) DEFAULT 0.00 COMMENT '价格',
    `sold_count` INT DEFAULT 0 COMMENT '已售数量',
    `release_date` DATE COMMENT '发布日期',
    PRIMARY KEY (`dlc_id`),
    CONSTRAINT `fk_dlc_game` FOREIGN KEY (`game_id`) REFERENCES `Game` (`game_id`) ON DELETE CASCADE
) ENGINE=InnoDB;
-- 5. 用户游戏库明细表
CREATE TABLE `UserLibrary` (
    `record_id` INT AUTO_INCREMENT COMMENT '消费记录编号P',
    `user_id` INT NOT NULL COMMENT '用户编号F',
    `item_type` ENUM('Game', 'DLC') NOT NULL COMMENT '商品类型',
    `game_id` INT DEFAULT NULL COMMENT '游戏编号F(如果是DLC则指向所属游戏)',
    `dlc_id` INT DEFAULT NULL COMMENT 'DLC编号F(如果购买的是本体则可为空)',
    `purchase_date` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '购买日期',
    PRIMARY KEY (`record_id`),
    CONSTRAINT `fk_lib_user` FOREIGN KEY (`user_id`) REFERENCES `User` (`user_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_lib_game` FOREIGN KEY (`game_id`) REFERENCES `Game` (`game_id`),
    CONSTRAINT `fk_lib_dlc` FOREIGN KEY (`dlc_id`) REFERENCES `DLC` (`dlc_id`)
) ENGINE=InnoDB;
-- 6. 好友关系表
CREATE TABLE `Friendship` (
    `rel_id` INT AUTO_INCREMENT COMMENT '关系编号P',
    `user_id` INT NOT NULL COMMENT '用户编号F',
    `friend_id` INT NOT NULL COMMENT '好友的用户编号F',
    PRIMARY KEY (`rel_id`),
    UNIQUE KEY `unique_friendship` (`user_id`, `friend_id`), -- 避免重复添加好友
    CONSTRAINT `fk_friend_user` FOREIGN KEY (`user_id`) REFERENCES `User` (`user_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_friend_other` FOREIGN KEY (`friend_id`) REFERENCES `User` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB;
-- 7. 评分记录表
CREATE TABLE `Rating` (
    `rating_id` INT AUTO_INCREMENT COMMENT '评分记录编号P',
    `user_id` INT NOT NULL COMMENT '用户编号F',
    `game_id` INT NOT NULL COMMENT '游戏编号F',
    `score` TINYINT NOT NULL COMMENT '分值（0-10分）',
    `rating_date` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '评分日期',
    PRIMARY KEY (`rating_id`),
    CONSTRAINT `fk_rate_user` FOREIGN KEY (`user_id`) REFERENCES `User` (`user_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_rate_game` FOREIGN KEY (`game_id`) REFERENCES `Game` (`game_id`) ON DELETE CASCADE
) ENGINE=InnoDB;
-- 8. 愿望单表
CREATE TABLE `Wishlist` (
    `wish_id` INT AUTO_INCREMENT COMMENT '愿望单记录编号P',
    `user_id` INT NOT NULL COMMENT '用户编号F',
    `game_id` INT NOT NULL COMMENT '游戏编号F',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '愿望单记录创建日期',
    PRIMARY KEY (`wish_id`),
    CONSTRAINT `fk_wish_user` FOREIGN KEY (`user_id`) REFERENCES `User` (`user_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_wish_game` FOREIGN KEY (`game_id`) REFERENCES `Game` (`game_id`) ON DELETE CASCADE
) ENGINE=InnoDB;


/*=======================触发器语句========================*/
DELIMITER //
CREATE TRIGGER `tg_before_friendship_insert`
BEFORE INSERT ON `Friendship`
FOR EACH ROW
BEGIN
    -- 不允许加自己好友
    IF NEW.user_id = NEW.friend_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Self-friending is not allowed.';
    END IF;
    -- 去重，确保 (2,1) 也强制转成 (1,2)，配合唯一索引生效
    IF NEW.user_id > NEW.friend_id THEN
        SET @tmp = NEW.user_id;
        SET NEW.user_id = NEW.friend_id;
        SET NEW.friend_id = @tmp;
    END IF;
END//
DELIMITER ;

DELIMITER //
-- 1. 开发商注销：自动删除其旗下的所有游戏 (Game)
CREATE TRIGGER `tg_before_developer_delete`
BEFORE DELETE ON `Developer`
FOR EACH ROW
BEGIN
    DELETE FROM `Game` WHERE dev_id = OLD.dev_id;
END//
-- 2. 游戏下架：自动删除对应的 DLC 和 愿望单
CREATE TRIGGER `tg_before_game_delete`
BEFORE DELETE ON `Game`
FOR EACH ROW
BEGIN
    -- 级联删除 DLC
    DELETE FROM `DLC` WHERE game_id = OLD.game_id;
    -- 级联删除 愿望单（没买的人就不让买了）
    DELETE FROM `Wishlist` WHERE game_id = OLD.game_id;
    DELETE FROM `Rating` WHERE game_id = OLD.game_id;
END//
-- 3. 用户注销：清理该用户所有的足迹
CREATE TRIGGER `tg_before_user_delete`
BEFORE DELETE ON `User`
FOR EACH ROW
BEGIN
    DELETE FROM `Wishlist` WHERE user_id = OLD.user_id;
    DELETE FROM `Friendship` WHERE user_id = OLD.user_id OR friend_id = OLD.user_id;
    DELETE FROM `Rating` WHERE user_id = OLD.user_id;
    -- 注意：UserLibrary 一般不建议物理删除，但如果硬要删：
    DELETE FROM `UserLibrary` WHERE user_id = OLD.user_id;
END//
DELIMITER ;


/*=======================权限分配语句以及视图创建语句========================*/
-- 1. 创建角色
CREATE ROLE IF NOT EXISTS 'admin_role';
CREATE ROLE IF NOT EXISTS 'player_role';
CREATE ROLE IF NOT EXISTS 'developer_role';
-- 2. 管理员全权限
GRANT ALL PRIVILEGES ON sysu_game_center.* TO 'admin_role' WITH GRANT OPTION;
-- 3. 基础查询权限（商店公共数据）
GRANT SELECT ON sysu_game_center.Game TO 'player_role';
GRANT SELECT ON sysu_game_center.DLC TO 'player_role';
GRANT SELECT ON sysu_game_center.Developer TO 'player_role';
-- 1. 个人库视图：仅允许查询自己的游戏
CREATE OR REPLACE VIEW view_player_my_library AS
SELECT l.* FROM UserLibrary l
JOIN User u ON l.user_id = u.user_id
WHERE u.nickname = SUBSTRING_INDEX(USER(), '@', 1);
-- 2. 个人愿望单视图：允许 CRUD 自己的愿望单
-- WITH CHECK OPTION 保证了：你只能 INSERT 自己的 user_id，改也只能改自己的
CREATE OR REPLACE VIEW view_player_my_wishlist AS
SELECT w.* FROM Wishlist w
JOIN User u ON w.user_id = u.user_id
WHERE u.nickname = SUBSTRING_INDEX(USER(), '@', 1)
WITH CHECK OPTION;
-- 3. 个人评分视图：允许 CRUD 自己的评分
CREATE OR REPLACE VIEW view_player_my_rating AS
SELECT r.* FROM Rating r
JOIN User u ON r.user_id = u.user_id
WHERE u.nickname = SUBSTRING_INDEX(USER(), '@', 1)
WITH CHECK OPTION;
-- 4. 个人好友视图：允许查看和管理涉及自己的关系
-- 注意：这里允许 user_id 或 friend_id 是自己
CREATE OR REPLACE VIEW view_player_my_friendship AS
SELECT f.* FROM Friendship f
JOIN User u ON (f.user_id = u.user_id OR f.friend_id = u.user_id)
WHERE u.nickname = SUBSTRING_INDEX(USER(), '@', 1)
WITH CHECK OPTION;
-- 5. 开发者游戏视图：只能增删改查属于该开发商的游戏
CREATE OR REPLACE VIEW view_dev_my_games AS
SELECT g.* FROM Game g
JOIN Developer d ON g.dev_id = d.dev_id
WHERE d.dev_name = SUBSTRING_INDEX(USER(), '@', 1)
WITH CHECK OPTION;
-- 6. 开发者销售额视图：只能看自己游戏的销售库记录
CREATE OR REPLACE VIEW view_dev_my_sales AS
SELECT l.* FROM UserLibrary l
JOIN Game g ON l.game_id = g.game_id
JOIN Developer d ON g.dev_id = d.dev_id
WHERE d.dev_name = SUBSTRING_INDEX(USER(), '@', 1);
-- 撤销可能存在的直接表权限
-- REVOKE ALL PRIVILEGES ON sysu_game_center.* FROM 'player_role';
-- REVOKE ALL PRIVILEGES ON sysu_game_center.* FROM 'developer_role';
-- --- 为普通用户分配视图权限 ---
GRANT SELECT ON sysu_game_center.Game TO 'player_role';
GRANT SELECT ON sysu_game_center.DLC TO 'player_role';
GRANT SELECT ON sysu_game_center.view_player_my_library TO 'player_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON sysu_game_center.view_player_my_wishlist TO 'player_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON sysu_game_center.view_player_my_rating TO 'player_role';
GRANT SELECT, INSERT, DELETE ON sysu_game_center.view_player_my_friendship TO 'player_role';
-- --- 为开发商分配视图权限 ---
GRANT SELECT, INSERT, UPDATE ON sysu_game_center.view_dev_my_games TO 'player_role';
GRANT SELECT ON sysu_game_center.view_dev_my_sales TO 'developer_role';


/*=======================插入数据语句========================*/
INSERT INTO `Developer` (`dev_id`, `dev_name`, `balance`, `country`) VALUES
(1, 'Valve Corporation', 100000.00, 'USA'),
(2, 'Nintendo', 500000.00, 'Japan');
INSERT INTO `User` (`user_id`, `nickname`, `user_level`, `balance`, `email`, `password`) VALUES
-- 管理员
(1, 'root', 99, 100000.00, 'root@sysu.com', '123456'),
-- 开发商关联用户 (账号名对应 Developer 表的 dev_name)
(2, 'Valve Corporation', 10, 0.00, 'valve_staff@valve.com', 'valve123'),
(3, 'Nintendo', 10, 0.00, 'nintendo_staff@nintendo.com', 'nin123'),
-- 普通玩家
(4, '张三', 1, 500.00, 'zhangsan@test.com', '123456'),
(5, '李四', 1, 200.00, 'lisi@test.com', '123456'),
(6, '王五', 2, 1000.00, 'wangwu@test.com', '123456');
INSERT INTO `Game` (`game_id`, `dev_id`, `game_name`, `price`, `sold_count`, `release_date`) VALUES
-- Valve 的游戏
(101, 1, 'Half-Life: Alyx', 198.00, 5000, '2020-03-23'),
(102, 1, 'Portal 2', 42.00, 100000, '2011-04-19'),
-- Nintendo 的游戏
(201, 2, 'The Legend of Zelda: Breath of the Wild', 398.00, 20000, '2017-03-03'),
(202, 2, 'Super Mario Odyssey', 350.00, 15000, '2017-10-27'),
(203, 2, 'Animal Crossing: New Horizons', 350.00, 30000, '2020-03-20');
INSERT INTO `DLC` (`dlc_id`, `game_id`, `dlc_name`, `price`, `sold_count`, `release_date`) VALUES
(501, 101, 'Half-Life: Alyx - Soundtrack', 37.00, 1000, '2020-03-23'),
(502, 101, 'Half-Life: Alyx - Art Book', 50.00, 800, '2020-04-01'),
(503, 101, 'Half-Life: Alyx - Commentary Mod', 0.00, 3000, '2020-11-12');
