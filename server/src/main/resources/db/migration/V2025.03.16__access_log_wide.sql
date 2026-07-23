-- ---------------------------------------------------------------------------
-- access_log_wide: 以 access_log 为核心的宽表，支持任意粒度、任意资源类型的多维分析
-- ---------------------------------------------------------------------------
-- 设计说明:
-- 1. 时间维度: year/month/day/hour/day_of_week/week_of_year/quarter 支持按任意时间粒度聚合
-- 2. 用户维度: user_id/username/user_name 支持多粒度用户分析
-- 3. 组织维度: org_id/org_name 支持组织级分析
-- 4. 资源维度: resource_type/resource_name/resource_parent_id 支持多资源类型分析
-- 5. 访问维度: access_type/duration 支持行为与性能分析
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table: access_log_wide
-- ----------------------------
DROP TABLE IF EXISTS `access_log_wide`;
CREATE TABLE `access_log_wide` (
  -- 主键与溯源
  `id` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT '主键，来自 access_log.id',
  `access_time` datetime(3) NULL DEFAULT NULL COMMENT '访问时间(毫秒精度)',
  `duration` int(11) NULL DEFAULT NULL COMMENT '访问耗时(ms)',
  `access_type` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT '访问类型: READ/UPDATE/CREATE/DELETE/ARCHIVE/UNARCHIVE/LOGIN',

  -- 时间维度
  `year` smallint(6) NULL DEFAULT NULL COMMENT '年',
  `month` tinyint(4) NULL DEFAULT NULL COMMENT '月(1-12)',
  `day` tinyint(4) NULL DEFAULT NULL COMMENT '日(1-31)',
  `hour` tinyint(4) NULL DEFAULT NULL COMMENT '时(0-23)',
  `day_of_week` tinyint(4) NULL DEFAULT NULL COMMENT '星期(1-7, 1=Monday)',
  `week_of_year` tinyint(4) NULL DEFAULT NULL COMMENT '年内第几周(1-53)',
  `quarter` tinyint(4) NULL DEFAULT NULL COMMENT '季度(1-4)',
  `date_str` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '日期字符串 YYYY-MM-DD',
  `month_str` varchar(7) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '月份字符串 YYYY-MM',

  -- 用户维度
  `user_id` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT '操作用户ID',
  `username` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '用户登录名',
  `user_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '用户显示名',
  `user_email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '用户邮箱',

  -- 组织维度
  `org_id` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '资源所属组织ID',
  `org_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '组织名称',

  -- 资源维度
  `resource_type` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '资源类型: DASHBOARD/DATACHART/VIEW/SOURCE/STORYBOARD/SCHEDULE/FOLDER/ROLE/USER',
  `resource_id` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT '资源ID',
  `resource_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '资源名称',
  `resource_parent_id` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '资源父级ID',
  `resource_create_by` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '资源创建者ID',
  `resource_status` tinyint(6) NULL DEFAULT NULL COMMENT '资源状态',
  `resource_folder_id` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '资源所属文件夹ID(VIZ类)',
  `resource_view_id` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '关联视图ID(DATACHART)',
  `resource_source_id` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '关联数据源ID(VIEW)',

  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_access_time` (`access_time`) USING BTREE,
  INDEX `idx_year_month` (`year`, `month`) USING BTREE,
  INDEX `idx_date_str` (`date_str`) USING BTREE,
  INDEX `idx_user_id` (`user_id`) USING BTREE,
  INDEX `idx_org_id` (`org_id`) USING BTREE,
  INDEX `idx_resource_type` (`resource_type`) USING BTREE,
  INDEX `idx_resource_id` (`resource_id`) USING BTREE,
  INDEX `idx_access_type` (`access_type`) USING BTREE,
  INDEX `idx_resource_type_time` (`resource_type`, `access_time`) USING BTREE,
  INDEX `idx_org_time` (`org_id`, `access_time`) USING BTREE,
  INDEX `idx_user_time` (`user_id`, `access_time`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci
  COMMENT = '访问日志宽表: 支持任意粒度、任意资源类型的多维分析' ROW_FORMAT = Dynamic;

-- ----------------------------
-- View: v_access_log_wide (实时填充视图)
-- 从 access_log 关联各资源表，按 resource_type 聚合 org_id/resource_name
-- ----------------------------
DROP VIEW IF EXISTS `v_access_log_wide`;
CREATE VIEW `v_access_log_wide` AS
SELECT
  a.id,
  a.access_time,
  a.duration,
  a.access_type,

  -- 时间维度
  YEAR(a.access_time) AS year,
  MONTH(a.access_time) AS month,
  DAY(a.access_time) AS day,
  HOUR(a.access_time) AS hour,
  DAYOFWEEK(a.access_time) AS day_of_week,
  WEEK(a.access_time, 3) AS week_of_year,
  QUARTER(a.access_time) AS quarter,
  DATE_FORMAT(a.access_time, '%Y-%m-%d') AS date_str,
  DATE_FORMAT(a.access_time, '%Y-%m') AS month_str,

  -- 用户维度
  a.user AS user_id,
  u.username,
  u.name AS user_name,
  u.email AS user_email,

  -- 组织维度 (资源无 org 时从用户所属组织补充，如 USER 类型)
  COALESCE(
    d.org_id, dc.org_id, v.org_id, s.org_id, sb.org_id, sch.org_id, f.org_id, r.org_id,
    wd.org_id, (SELECT org_id FROM rel_user_organization ruo WHERE ruo.user_id = a.user LIMIT 1)
  ) AS org_id,
  o.name AS org_name,

  -- 资源维度
  a.resource_type AS resource_type,
  a.resource_id AS resource_id,
  COALESCE(d.name, dc.name, v.name, s.name, sb.name, sch.name, f.name, r.name, u2.username) AS resource_name,
  COALESCE(v.parent_id, s.parent_id, sb.parent_id, sch.parent_id, f.parent_id, fd.parent_id) AS resource_parent_id,
  COALESCE(d.create_by, dc.create_by, v.create_by, s.create_by, sb.create_by, sch.create_by) AS resource_create_by,
  COALESCE(d.status, dc.status, v.status, s.status, sb.status) AS resource_status,
  fd.id AS resource_folder_id,
  dc.view_id AS resource_view_id,
  v.source_id AS resource_source_id

FROM access_log a
LEFT JOIN `user` u ON a.user = u.id
LEFT JOIN dashboard d ON a.resource_type = 'DASHBOARD' AND a.resource_id = d.id
LEFT JOIN datachart dc ON a.resource_type = 'DATACHART' AND a.resource_id = dc.id
LEFT JOIN `view` v ON a.resource_type = 'VIEW' AND a.resource_id = v.id
LEFT JOIN source s ON a.resource_type = 'SOURCE' AND a.resource_id = s.id
LEFT JOIN storyboard sb ON a.resource_type = 'STORYBOARD' AND a.resource_id = sb.id
LEFT JOIN schedule sch ON a.resource_type = 'SCHEDULE' AND a.resource_id = sch.id
LEFT JOIN folder f ON a.resource_type = 'FOLDER' AND a.resource_id = f.id
LEFT JOIN role r ON a.resource_type = 'ROLE' AND a.resource_id = r.id
LEFT JOIN `user` u2 ON a.resource_type = 'USER' AND a.resource_id = u2.id
LEFT JOIN widget w ON a.resource_type = 'WIDGET' AND a.resource_id = w.id
LEFT JOIN dashboard wd ON w.dashboard_id = wd.id
LEFT JOIN folder fd ON fd.rel_type = a.resource_type AND fd.rel_id = a.resource_id
  AND a.resource_type IN ('DASHBOARD','DATACHART','STORYBOARD')
LEFT JOIN organization o ON o.id = COALESCE(d.org_id, dc.org_id, v.org_id, s.org_id, sb.org_id, sch.org_id, f.org_id, r.org_id, wd.org_id, (SELECT org_id FROM rel_user_organization ruo WHERE ruo.user_id = a.user LIMIT 1));

-- ----------------------------
-- 存储过程: 同步 access_log_wide (全量或增量)
-- 用法: CALL sp_sync_access_log_wide(1);  -- 1=全量, 0=增量
-- ----------------------------
DROP PROCEDURE IF EXISTS `sp_sync_access_log_wide`;
DELIMITER ;;
CREATE PROCEDURE `sp_sync_access_log_wide`(IN full_sync TINYINT)
BEGIN
  IF full_sync = 1 THEN
    TRUNCATE TABLE access_log_wide;
    INSERT INTO access_log_wide SELECT * FROM v_access_log_wide;
  ELSE
    INSERT INTO access_log_wide
    SELECT v.* FROM v_access_log_wide v
    WHERE NOT EXISTS (SELECT 1 FROM access_log_wide w WHERE w.id = v.id);
  END IF;
END;;
DELIMITER ;

SET FOREIGN_KEY_CHECKS = 1;
