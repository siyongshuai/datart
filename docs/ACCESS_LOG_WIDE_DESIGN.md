# access_log_wide 宽表设计说明

## 概述

以 `access_log` 为核心的宽表，支持**任意粒度**和**任意资源类型**的多维分析。

## 表结构

| 维度 | 字段 | 说明 | 分析场景 |
|------|------|------|----------|
| **主键** | id | 原 access_log.id | 去重、溯源 |
| **时间** | access_time | 访问时间 | 精确时间筛选 |
| **时间** | year, month, day, hour | 年/月/日/时 | 按任意时间粒度聚合 |
| **时间** | day_of_week, week_of_year, quarter | 星期/周/季度 | 周期性分析 |
| **时间** | date_str, month_str | YYYY-MM-DD, YYYY-MM | 报表分组 |
| **访问** | access_type, duration | 操作类型、耗时 | 行为与性能分析 |
| **用户** | user_id, username, user_name, user_email | 操作用户信息 | 用户活跃度、Top用户 |
| **组织** | org_id, org_name | 资源所属组织 | 组织级报表、多租户分析 |
| **资源** | resource_type, resource_id, resource_name | 资源类型与名称 | 资源热度、类型分布 |
| **资源** | resource_parent_id, resource_folder_id | 层级关系 | 文件夹/目录级分析 |
| **资源** | resource_view_id, resource_source_id | 关联视图/数据源 | 血缘分析、依赖分析 |
| **资源** | resource_create_by, resource_status | 创建者、状态 | 资源生命周期分析 |

## 资源类型映射

| resource_type | 来源表 | org_id | resource_name |
|---------------|--------|--------|---------------|
| DASHBOARD | dashboard | dashboard.org_id | dashboard.name |
| DATACHART | datachart | datachart.org_id | datachart.name |
| VIEW | view | view.org_id | view.name |
| SOURCE | source | source.org_id | source.name |
| STORYBOARD | storyboard | storyboard.org_id | storyboard.name |
| SCHEDULE | schedule | schedule.org_id | schedule.name |
| FOLDER | folder | folder.org_id | folder.name |
| ROLE | role | role.org_id | role.name |
| USER | user | (需关联 rel_user_organization) | user.username |
| WIDGET | widget→dashboard | dashboard.org_id | (通过 dashboard) |

## 多维分析示例

### 1. 按日统计各资源类型访问量

```sql
SELECT date_str, resource_type, COUNT(*) AS pv
FROM access_log_wide
WHERE access_type = 'READ'
GROUP BY date_str, resource_type
ORDER BY date_str, pv DESC;
```

### 2. 按组织统计月度活跃用户数

```sql
SELECT month_str, org_name, COUNT(DISTINCT user_id) AS mau
FROM access_log_wide
WHERE access_type IN ('READ','UPDATE')
GROUP BY month_str, org_name;
```

### 3. 按小时分布分析访问高峰

```sql
SELECT hour, resource_type, COUNT(*) AS cnt
FROM access_log_wide
WHERE date_str >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
GROUP BY hour, resource_type
ORDER BY hour, cnt DESC;
```

### 4. Top 10 最热仪表板

```sql
SELECT resource_id, resource_name, org_name, COUNT(*) AS read_count
FROM access_log_wide
WHERE resource_type = 'DASHBOARD' AND access_type = 'READ'
GROUP BY resource_id, resource_name, org_name
ORDER BY read_count DESC
LIMIT 10;
```

### 5. 按季度统计各操作类型分布

```sql
SELECT CONCAT(year, '-Q', quarter) AS quarter_str, access_type, COUNT(*) AS cnt
FROM access_log_wide
GROUP BY year, quarter, access_type
ORDER BY year, quarter, cnt DESC;
```

### 6. 用户级访问耗时分析

```sql
SELECT user_name, resource_type, AVG(duration) AS avg_duration_ms
FROM access_log_wide
WHERE duration IS NOT NULL AND duration > 0
GROUP BY user_id, resource_type;
```

### 7. 文件夹级聚合（通过 resource_parent_id）

```sql
SELECT resource_parent_id, resource_type, COUNT(*) AS cnt
FROM access_log_wide
WHERE resource_parent_id IS NOT NULL
GROUP BY resource_parent_id, resource_type;
```

## 使用方式

### 实时查询（视图）

```sql
SELECT * FROM v_access_log_wide
WHERE date_str = '2025-03-16' AND resource_type = 'DASHBOARD';
```

### 物化表同步

```sql
-- 全量同步（首次或重建）
CALL sp_sync_access_log_wide(1);

-- 增量同步（定时任务，如每小时）
CALL sp_sync_access_log_wide(0);
```

### 建议的定时任务

- **全量同步**: 每周或每月执行一次，用于数据修复或重建
- **增量同步**: 每小时或每 15 分钟执行，保持宽表与 access_log 一致

## 索引说明

| 索引名 | 字段 | 用途 |
|--------|------|------|
| idx_access_time | access_time | 时间范围查询 |
| idx_year_month | year, month | 月度报表 |
| idx_date_str | date_str | 按日聚合 |
| idx_user_id | user_id | 用户维度分析 |
| idx_org_id | org_id | 组织维度分析 |
| idx_resource_type | resource_type | 资源类型筛选 |
| idx_resource_id | resource_id | 单资源分析 |
| idx_access_type | access_type | 操作类型筛选 |
| idx_resource_type_time | resource_type, access_time | 资源+时间组合 |
| idx_org_time | org_id, access_time | 组织+时间组合 |
| idx_user_time | user_id, access_time | 用户+时间组合 |

## 迁移文件

- `server/src/main/resources/db/migration/V2025.03.16__access_log_wide.sql`

## 注意事项

1. **access_log 写入**: 当前 `AccessLogServiceImpl` 中 `logMapper.insert` 被注释，需确认是否启用日志写入
2. **视图性能**: `v_access_log_wide` 含多表 LEFT JOIN，数据量大时建议使用物化表 `access_log_wide` + 定时同步
3. **USER 类型 org_id**: 当 resource_type=USER 时，org_id 可能为空，需通过 rel_user_organization 补充（可后续扩展视图）
