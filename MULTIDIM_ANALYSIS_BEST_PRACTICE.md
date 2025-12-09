# Datart 多维灵活分析最佳实践

本文档介绍如何通过多选下拉框实现动态多维组合分析，让用户可以灵活选择分析维度。

---

## 目录

- [1. 需求场景](#1-需求场景)
- [2. 解决方案概述](#2-解决方案概述)
- [3. 完整实现](#3-完整实现)
- [4. 模板详解](#4-模板详解)
- [5. 扩展场景](#5-扩展场景)
- [6. 最佳实践建议](#6-最佳实践建议)
- [7. 常见问题](#7-常见问题)

---

## 1. 需求场景

### 1.1 典型需求

用户希望通过下拉框灵活控制数据分析的维度组合：

- 选择「全部」→ 该维度不参与分组，显示汇总数据
- 选择具体值 → 该维度参与分组和过滤

### 1.2 示例场景

销售数据分析，包含三个可选维度：

| 维度 | 可选值 |
|------|-------|
| 地区 | 全部、华东、华南、华北、西南... |
| 类别 | 全部、电子、服装、食品、家居... |
| 渠道 | 全部、线上、线下、直营、加盟... |

**用户期望的交互效果**：

| 用户选择 | 分析结果 |
|---------|---------|
| 地区=全部, 类别=全部, 渠道=全部 | 显示总销售额（无维度拆分） |
| 地区=华东, 类别=全部, 渠道=全部 | 按华东地区汇总 |
| 地区=华东+华南, 类别=电子, 渠道=全部 | 按地区+类别交叉分析 |
| 地区=全部, 类别=电子+服装, 渠道=线上 | 按类别+渠道交叉分析 |

---

## 2. 解决方案概述

### 2.1 技术方案

使用 **FreeMarker 模板引擎** 实现动态 SQL 生成：

```
用户选择下拉框值
       ↓
FreeMarker 解析变量
       ↓
动态生成 SELECT / WHERE / GROUP BY
       ↓
执行最终 SQL
```

### 2.2 设计原则

1. **配置与逻辑分离**：维度配置集中管理，便于维护
2. **函数封装复用**：通用判断逻辑封装为函数
3. **循环处理维度**：避免重复代码
4. **约定优于配置**：使用 `all` 作为「全部」的标识值

---

## 3. 完整实现

### 3.1 变量配置

为每个维度创建一个多选下拉框变量：

| 变量名 | 变量类型 | 值类型 | 可选值 |
|--------|---------|--------|-------|
| `region` | 查询变量 | 字符 | `all`, `华东`, `华南`, `华北`, `西南` |
| `category` | 查询变量 | 字符 | `all`, `电子`, `服装`, `食品`, `家居` |
| `channel` | 查询变量 | 字符 | `all`, `线上`, `线下`, `直营`, `加盟` |
| `startDate` | 查询变量 | 日期 | - |
| `endDate` | 查询变量 | 日期 | - |

### 3.2 完整 SQL 模板

```sql
<#--
================================================================================
  动态多维分析 SQL 模板
  
  功能说明：
  - 每个维度独立控制，选择 "all" 表示不参与分组
  - 选择具体值则参与 SELECT / WHERE / GROUP BY
  
  维护说明：
  - 添加新维度：只需在 dimConfig 中添加一行配置
  - 修改字段名：修改对应维度的 field 值
  - 修改显示名：修改对应维度的 alias 值
================================================================================
-->

<#-- ==================== 第一部分：维度配置 ==================== -->
<#--
  配置说明：
  - var   : 变量名（对应下拉框控件绑定的变量）
  - field : 数据库表中的字段名
  - alias : SELECT 输出时的显示别名
-->
<#assign dimConfig = [
  {"var": "region",   "field": "region_name",   "alias": "地区"},
  {"var": "category", "field": "category_name", "alias": "类别"},
  {"var": "channel",  "field": "channel_name",  "alias": "渠道"}
]>


<#-- ==================== 第二部分：工具函数 ==================== -->

<#--
  函数：isActive
  功能：判断维度变量是否有效（存在、非空、不包含 all）
  参数：var - 变量值
  返回：true = 需要参与分组, false = 不参与分组
-->
<#function isActive var>
  <#-- 变量不存在或为空字符串 -->
  <#if !var?? || var == "">
    <#return false>
  </#if>
  
  <#-- 多选情况：变量是集合类型 -->
  <#if var?is_sequence>
    <#-- 集合为空 或 包含 "all" -->
    <#if var?size == 0 || var?seq_contains("all")>
      <#return false>
    </#if>
    <#return true>
  </#if>
  
  <#-- 单选情况：变量是字符串类型 -->
  <#return var != "all">
</#function>

<#--
  函数：getValues
  功能：获取变量的值列表（统一返回数组格式）
  参数：var - 变量值
  返回：值的列表
-->
<#function getValues var>
  <#if var?is_sequence>
    <#return var>
  <#else>
    <#return [var]>
  </#if>
</#function>


<#-- ==================== 第三部分：解析活跃维度 ==================== -->

<#assign activeDims = []>
<#list dimConfig as dim>
  <#-- 通过 .vars 动态获取变量值 -->
  <#assign varValue = .vars[dim.var]!>
  
  <#if isActive(varValue)>
    <#-- 将维度配置和实际值合并存储 -->
    <#assign activeDims = activeDims + [dim + {"values": getValues(varValue)}]>
  </#if>
</#list>


<#-- ==================== 第四部分：主 SQL ==================== -->

SELECT 
  <#-- 动态 SELECT 字段：只输出活跃维度 -->
  <#list activeDims as dim>
  ${dim.field} AS ${dim.alias},
  </#list>
  
  <#-- 固定指标字段 -->
  SUM(amount) AS 销售额,
  COUNT(*) AS 订单数,
  COUNT(DISTINCT customer_id) AS 客户数,
  ROUND(SUM(amount) / COUNT(*), 2) AS 客单价

FROM sales_order

WHERE 1=1
  <#-- 公共时间过滤条件 -->
  <#if startDate?? && startDate != "">
  AND order_date >= '${startDate}'
  </#if>
  <#if endDate?? && endDate != "">
  AND order_date <= '${endDate}'
  </#if>
  
  <#-- 动态维度过滤条件 -->
  <#list activeDims as dim>
  AND ${dim.field} IN (<#list dim.values as v>'${v}'<#sep>, </#sep></#list>)
  </#list>

<#-- 动态 GROUP BY：只有活跃维度时才添加 -->
<#if activeDims?size gt 0>
GROUP BY 
  <#list activeDims as dim>
  ${dim.field}<#sep>,
  </#sep></#list>
</#if>

ORDER BY 销售额 DESC
```

### 3.3 精简版模板（生产环境推荐）

```sql
<#-- 配置 -->
<#assign D = [
  {"v": "region",   "f": "region_name",   "a": "地区"},
  {"v": "category", "f": "category_name", "a": "类别"},
  {"v": "channel",  "f": "channel_name",  "a": "渠道"}
]>

<#-- 工具函数 -->
<#function ok x>
  <#if !x?? || x == ""><#return false>
  <#elseif x?is_sequence><#return x?size gt 0 && !x?seq_contains("all")>
  <#else><#return x != "all">
  </#if>
</#function>
<#function vals x><#if x?is_sequence><#return x><#else><#return [x]></#if></#function>

<#-- 解析活跃维度 -->
<#assign A = []>
<#list D as d>
  <#assign xv = .vars[d.v]!>
  <#if ok(xv)><#assign A = A + [d + {"vals": vals(xv)}]></#if>
</#list>

<#-- 主 SQL -->
SELECT 
  <#list A as d>${d.f} AS ${d.a}, </#list>
  SUM(amount) AS 销售额,
  COUNT(*) AS 订单数
FROM sales_order
WHERE 1=1
  AND order_date BETWEEN $startDate$ AND $endDate$
  <#list A as d>AND ${d.f} IN (<#list d.vals as v>'${v}'<#sep>,</#sep></#list>) </#list>
<#if A?size gt 0>GROUP BY <#list A as d>${d.f}<#sep>, </#sep></#list></#if>
ORDER BY 销售额 DESC
```

---

## 4. 模板详解

### 4.1 核心函数说明

#### isActive 函数

```sql
<#function isActive var>
  <#if !var?? || var == "">
    <#return false>           <#-- 不存在或空字符串 → 不激活 -->
  </#if>
  <#if var?is_sequence>
    <#if var?size == 0 || var?seq_contains("all")>
      <#return false>         <#-- 空集合或包含all → 不激活 -->
    </#if>
    <#return true>            <#-- 有具体值 → 激活 -->
  </#if>
  <#return var != "all">      <#-- 单值且不是all → 激活 -->
</#function>
```

**判断逻辑流程图**：

```
变量值
  │
  ├─ 不存在/空 ──────────────────→ 不激活
  │
  ├─ 是集合 ─┬─ 空集合 ──────────→ 不激活
  │          ├─ 包含 "all" ──────→ 不激活
  │          └─ 有具体值 ────────→ 激活 ✓
  │
  └─ 是字符串 ─┬─ 等于 "all" ────→ 不激活
               └─ 其他值 ────────→ 激活 ✓
```

### 4.2 动态变量获取

```sql
<#-- 通过 .vars 内置变量动态获取变量值 -->
<#assign varValue = .vars[dim.var]!>
```

- `.vars` 是 FreeMarker 的内置变量，包含当前作用域的所有变量
- `[dim.var]` 使用方括号语法动态访问
- `!` 是默认值运算符，变量不存在时返回空

### 4.3 生成的 SQL 示例

#### 场景 1：全部选 all

```
region = all, category = all, channel = all
```

```sql
SELECT 
  SUM(amount) AS 销售额,
  COUNT(*) AS 订单数
FROM sales_order
WHERE 1=1
  AND order_date BETWEEN '2024-01-01' AND '2024-12-31'
ORDER BY 销售额 DESC
```

#### 场景 2：单维度分析

```
region = 华东, 华南
category = all
channel = all
```

```sql
SELECT 
  region_name AS 地区,
  SUM(amount) AS 销售额,
  COUNT(*) AS 订单数
FROM sales_order
WHERE 1=1
  AND order_date BETWEEN '2024-01-01' AND '2024-12-31'
  AND region_name IN ('华东', '华南')
GROUP BY region_name
ORDER BY 销售额 DESC
```

#### 场景 3：多维度交叉分析

```
region = 华东
category = 电子, 服装
channel = 线上
```

```sql
SELECT 
  region_name AS 地区,
  category_name AS 类别,
  channel_name AS 渠道,
  SUM(amount) AS 销售额,
  COUNT(*) AS 订单数
FROM sales_order
WHERE 1=1
  AND order_date BETWEEN '2024-01-01' AND '2024-12-31'
  AND region_name IN ('华东')
  AND category_name IN ('电子', '服装')
  AND channel_name IN ('线上')
GROUP BY region_name, category_name, channel_name
ORDER BY 销售额 DESC
```

---

## 5. 扩展场景

### 5.1 添加新维度

只需在配置数组中添加一行：

```sql
<#assign dimConfig = [
  {"var": "region",   "field": "region_name",   "alias": "地区"},
  {"var": "category", "field": "category_name", "alias": "类别"},
  {"var": "channel",  "field": "channel_name",  "alias": "渠道"},
  {"var": "brand",    "field": "brand_name",    "alias": "品牌"}    <#-- 新增 -->
]>
```

然后创建对应的变量 `brand`，添加 `all` 和具体品牌值即可。

### 5.2 支持日期维度的动态粒度

```sql
<#assign dimConfig = [
  {"var": "region",    "field": "region_name",                        "alias": "地区"},
  {"var": "category",  "field": "category_name",                      "alias": "类别"},
  {"var": "timeGrain", "field": "DATE_FORMAT(order_date, '%Y-%m')",   "alias": "月份"}
]>
```

### 5.3 支持维度排序

```sql
<#assign dimConfig = [
  {"var": "region",   "field": "region_name",   "alias": "地区",  "sort": 1},
  {"var": "category", "field": "category_name", "alias": "类别",  "sort": 2},
  {"var": "channel",  "field": "channel_name",  "alias": "渠道",  "sort": 3}
]>

<#-- 按 sort 排序活跃维度 -->
<#assign activeDims = activeDims?sort_by("sort")>
```

### 5.4 支持维度关联表

```sql
<#assign dimConfig = [
  {"var": "region",   "field": "r.region_name",   "alias": "地区",  "join": "LEFT JOIN dim_region r ON o.region_id = r.id"},
  {"var": "category", "field": "c.category_name", "alias": "类别",  "join": "LEFT JOIN dim_category c ON o.category_id = c.id"},
  {"var": "channel",  "field": "ch.channel_name", "alias": "渠道",  "join": "LEFT JOIN dim_channel ch ON o.channel_id = ch.id"}
]>

SELECT 
  <#list activeDims as dim>${dim.field} AS ${dim.alias}, </#list>
  SUM(o.amount) AS 销售额
FROM sales_order o
  <#list activeDims as dim>
  ${dim.join}
  </#list>
WHERE 1=1
  <#list activeDims as dim>AND ${dim.field} IN (...) </#list>
<#if activeDims?size gt 0>GROUP BY <#list activeDims as dim>${dim.field}<#sep>, </#sep></#list></#if>
```

### 5.5 支持不同聚合函数

```sql
<#assign metrics = [
  {"field": "amount",      "agg": "SUM",   "alias": "销售额"},
  {"field": "*",           "agg": "COUNT", "alias": "订单数"},
  {"field": "customer_id", "agg": "COUNT DISTINCT", "alias": "客户数"}
]>

SELECT 
  <#list activeDims as d>${d.field} AS ${d.alias}, </#list>
  <#list metrics as m>
    <#if m.agg == "COUNT DISTINCT">
      COUNT(DISTINCT ${m.field}) AS ${m.alias}<#sep>, </#sep>
    <#else>
      ${m.agg}(${m.field}) AS ${m.alias}<#sep>, </#sep>
    </#if>
  </#list>
FROM ...
```

---

## 6. 最佳实践建议

### 6.1 变量命名规范

| 类型 | 命名规则 | 示例 |
|------|---------|------|
| 维度变量 | 小驼峰，简洁 | `region`, `category`, `channel` |
| 时间变量 | 带日期后缀 | `startDate`, `endDate` |
| 过滤变量 | 带 Filter 后缀 | `statusFilter`, `typeFilter` |

### 6.2 「全部」选项设计

推荐使用 `all` 作为「全部」的值：

```
✅ 推荐：all（简洁、无歧义）
❌ 不推荐：全部、ALL、*、-1（可能与业务值冲突）
```

### 6.3 下拉框选项设计

```
地区
├── 全部（值: all）  ← 第一个选项
├── 华东
├── 华南
├── 华北
└── 西南
```

### 6.4 默认值设置

建议将「全部」设为默认值，用户打开页面即可看到汇总数据：

```
变量默认值: ["all"]
```

### 6.5 控制器配置

| 配置项 | 推荐值 | 说明 |
|--------|-------|------|
| 允许多选 | 是 | 支持选择多个具体值 |
| SQL 操作符 | IN | 自动生成 IN 条件 |
| 关联类型 | 变量 | 关联到 SQL 变量 |

### 6.6 性能优化

1. **添加索引**：为常用维度字段添加数据库索引
2. **限制结果集**：添加 `LIMIT` 限制返回行数
3. **分区裁剪**：时间字段使用分区表

```sql
<#-- 添加结果集限制 -->
ORDER BY 销售额 DESC
LIMIT 1000
```

---

## 7. 常见问题

### Q1: 如何让「全部」和具体值互斥？

在前端控制器中配置「单选时清除其他选项」，或在 SQL 中处理：

```sql
<#-- 如果同时选了 all 和其他值，all 优先 -->
<#if var?is_sequence && var?seq_contains("all")>
  <#-- 不参与分组 -->
</#if>
```

### Q2: 如何支持「仅看已选」和「排除已选」？

添加一个模式变量：

```sql
<#assign filterMode = filterMode!"include">  <#-- include / exclude -->

<#if filterMode == "include">
  AND ${dim.field} IN (...)
<#else>
  AND ${dim.field} NOT IN (...)
</#if>
```

### Q3: 如何处理大量维度值的性能问题？

1. 使用值列表变量而非直接拼接
2. 考虑使用临时表
3. 限制最大可选数量

### Q4: 如何调试生成的 SQL？

在 SQL 视图的「运行」功能中可以查看最终生成的 SQL。也可以添加注释标记：

```sql
<#-- DEBUG: activeDims = ${activeDims?size} -->
SELECT ...
```

### Q5: 变量值包含特殊字符怎么办？

使用 FreeMarker 的转义函数：

```sql
'${v?replace("'", "''")}'  <#-- 转义单引号 -->
```

或使用 Datart 的变量占位符（自动处理转义）：

```sql
AND field = $varName$
```

---

## 附录：完整文件模板

### A. 标准版模板文件

保存为 `dynamic_multidim_analysis.sql`：

```sql
<#-- ========== 配置区 ========== -->
<#assign dimConfig = [
  {"var": "region",   "field": "region_name",   "alias": "地区"},
  {"var": "category", "field": "category_name", "alias": "类别"},
  {"var": "channel",  "field": "channel_name",  "alias": "渠道"}
]>

<#-- ========== 工具函数 ========== -->
<#function isActive var>
  <#if !var?? || var == ""><#return false></#if>
  <#if var?is_sequence><#return var?size gt 0 && !var?seq_contains("all")></#if>
  <#return var != "all">
</#function>

<#function getValues var>
  <#if var?is_sequence><#return var><#else><#return [var]></#if>
</#function>

<#-- ========== 解析维度 ========== -->
<#assign activeDims = []>
<#list dimConfig as dim>
  <#assign varValue = .vars[dim.var]!>
  <#if isActive(varValue)>
    <#assign activeDims = activeDims + [dim + {"values": getValues(varValue)}]>
  </#if>
</#list>

<#-- ========== 主 SQL ========== -->
SELECT 
  <#list activeDims as dim>${dim.field} AS ${dim.alias}, </#list>
  SUM(amount) AS 销售额,
  COUNT(*) AS 订单数,
  COUNT(DISTINCT customer_id) AS 客户数
FROM sales_order
WHERE 1=1
  <#if startDate?? && startDate != "">AND order_date >= '${startDate}'</#if>
  <#if endDate?? && endDate != "">AND order_date <= '${endDate}'</#if>
  <#list activeDims as dim>AND ${dim.field} IN (<#list dim.values as v>'${v}'<#sep>, </#sep></#list>) </#list>
<#if activeDims?size gt 0>GROUP BY <#list activeDims as dim>${dim.field}<#sep>, </#sep></#list></#if>
ORDER BY 销售额 DESC
LIMIT 10000
```

### B. 变量配置清单

| 变量名 | 类型 | 值类型 | 默认值 | 说明 |
|--------|------|--------|-------|------|
| region | 查询变量 | STRING | ["all"] | 地区维度 |
| category | 查询变量 | STRING | ["all"] | 类别维度 |
| channel | 查询变量 | STRING | ["all"] | 渠道维度 |
| startDate | 查询变量 | DATE | 当月第一天 | 开始日期 |
| endDate | 查询变量 | DATE | 当天 | 结束日期 |

---

**文档版本**: 1.0  
**最后更新**: 2025-12-09
