# Datart `$var$` 与 FreeMarker `${}` 深度对比

本文档深入分析 Datart SQL 视图中两种变量语法的本质区别、执行机制、安全特性和最佳实践。

---

## 目录

- [1. 概述](#1-概述)
- [2. 本质区别](#2-本质区别)
- [3. 执行时机与顺序](#3-执行时机与顺序)
- [4. 语法与使用方式](#4-语法与使用方式)
- [5. 类型处理差异](#5-类型处理差异)
- [6. 多值处理差异](#6-多值处理差异)
- [7. 安全性对比](#7-安全性对比)
- [8. 适用场景决策](#8-适用场景决策)
- [9. 混合使用模式](#9-混合使用模式)
- [10. 常见错误与陷阱](#10-常见错误与陷阱)
- [11. 代码依据](#11-代码依据)
- [12. 总结](#12-总结)

---

## 1. 概述

### 1.1 两种语法的定义

| 语法 | 归属 | 示例 | 本质 |
|------|------|------|------|
| `$var$` | Datart 变量系统 | `WHERE age > $minAge$` | SQL感知的智能替换 |
| `${}` | FreeMarker 模板引擎 | `SELECT * FROM ${tableName}` | 纯文本插值 |

### 1.2 一句话区分

```
${}  是"文本替换器"——它不知道自己在生成SQL
$var$ 是"SQL值生成器"——它理解SQL语义并安全处理
```

---

## 2. 本质区别

### 2.1 FreeMarker `${}`：通用文本模板插值

```
┌─────────────────────────────────────────────────────────┐
│                    FreeMarker 引擎                       │
│                                                         │
│  输入: "Hello, ${name}!"      数据: {name: "World"}    │
│                    ↓                                    │
│  输出: "Hello, World!"                                  │
│                                                         │
│  特点:                                                  │
│  - 不知道输出是SQL、HTML还是纯文本                       │
│  - 纯粹的字符串拼接                                      │
│  - 无任何安全处理                                        │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Datart `$var$`：SQL感知的值替换器

```
┌─────────────────────────────────────────────────────────┐
│                    Datart 变量处理器                     │
│                                                         │
│  输入: "WHERE name = $name$"                            │
│  变量: {name: "John's Shop", type: STRING}              │
│                    ↓                                    │
│  处理:                                                  │
│  1. 识别这是SQL WHERE子句                               │
│  2. 识别变量类型是STRING                                │
│  3. 添加引号并转义特殊字符                               │
│                    ↓                                    │
│  输出: "WHERE name = 'John''s Shop'"                    │
└─────────────────────────────────────────────────────────┘
```

### 2.3 核心差异表

| 维度 | FreeMarker `${}` | Datart `$var$` |
|------|------------------|----------------|
| **设计目的** | 通用文本模板 | SQL值替换 |
| **SQL感知** | ❌ 不理解SQL | ✅ 理解SQL语义 |
| **类型处理** | ❌ 无 | ✅ STRING/NUMERIC/DATE等 |
| **引号处理** | ❌ 手动添加 | ✅ 自动根据类型 |
| **转义处理** | ❌ 无 | ✅ 自动转义 |
| **多值处理** | ❌ 手动循环 | ✅ 自动转IN |
| **SQL注入防护** | ❌ 无 | ✅ 有 |

---

## 3. 执行时机与顺序

### 3.1 处理流程

```
SQL模板
   │
   ▼
┌──────────────────────────────────────┐
│  阶段1: FreeMarker 处理               │
│  - 处理 <#if>, <#list> 等标签        │
│  - 处理 ${} 插值                      │  ← FreeMarker 在这里执行
│  - 输出: 中间SQL (仍含 $var$)         │
└──────────────────────────────────────┘
   │
   ▼
┌──────────────────────────────────────┐
│  阶段2: FRAGMENT 变量替换             │
│  - 替换表达式类型变量                  │
└──────────────────────────────────────┘
   │
   ▼
┌──────────────────────────────────────┐
│  阶段3: SQL 解析                      │
│  - Calcite 或 正则解析                │
│  - 定位 $var$ 占位符位置              │
└──────────────────────────────────────┘
   │
   ▼
┌──────────────────────────────────────┐
│  阶段4: Datart 变量替换               │  ← Datart $var$ 在这里执行
│  - 根据类型生成SQL字面量              │
│  - 多值时优化运算符                   │
│  - 输出: 最终SQL                      │
└──────────────────────────────────────┘
   │
   ▼
数据库执行
```

### 3.2 执行顺序的影响

**示例模板**:
```sql
SELECT * FROM ${tableName}
WHERE status = '${status}'
  AND age > $minAge$
```

**数据**:
```
tableName = "users"
status = "active"
minAge = 18 (NUMERIC类型)
```

**阶段1后 (FreeMarker处理后)**:
```sql
SELECT * FROM users
WHERE status = 'active'
  AND age > $minAge$
```

**阶段4后 (Datart处理后)**:
```sql
SELECT * FROM users
WHERE status = 'active'
  AND age > 18
```

### 3.3 关键认知

```
FreeMarker 看不到 Datart 变量的最终值
Datart 看不到 FreeMarker 变量（已被替换）
```

这意味着：
- 在 `<#if>` 中判断的是 FreeMarker 数据模型中的值
- `$var$` 的替换发生在 FreeMarker 完成之后

---

## 4. 语法与使用方式

### 4.1 FreeMarker `${}` 语法

```sql
<#-- 基础插值 -->
${variableName}

<#-- 带默认值 -->
${variableName!"default"}
${variableName?default("default")}

<#-- 内置函数 -->
${name?upper_case}
${name?lower_case}
${list?join(",")}
${number?string("0.00")}

<#-- 表达式计算 -->
${a + b}
${"prefix_" + tableName}

<#-- 条件表达式 -->
${condition?then("yes", "no")}
```

### 4.2 Datart `$var$` 语法

```sql
<#-- 基础用法（只有这一种形式） -->
$variableName$

<#-- 变量名规则 -->
$age$           -- 简单名称
$min_age$       -- 下划线
$startDate$     -- 驼峰命名

<#-- 在SQL中的位置 -->
WHERE column = $var$           -- 等于条件
WHERE column > $var$           -- 比较条件
WHERE column IN ($var$)        -- IN条件（多值自动展开）
WHERE column LIKE $var$        -- LIKE条件
```

### 4.3 语法对比

| 特性 | FreeMarker `${}` | Datart `$var$` |
|------|------------------|----------------|
| 默认值 | `${var!"default"}` | 在变量定义时设置 |
| 字符串处理 | `${var?upper_case}` | 不支持 |
| 数学运算 | `${a + b}` | 不支持 |
| 字符串拼接 | `${"a" + var}` | 不支持 |
| 条件输出 | `${cond?then(a,b)}` | 不支持 |

---

## 5. 类型处理差异

### 5.1 FreeMarker：无类型概念

```sql
<#-- FreeMarker 不区分类型，全部当作文本处理 -->

<#assign name = "John">
<#assign age = 25>
<#assign date = "2024-01-01">

WHERE name = '${name}'      -- 需要手动加引号
  AND age = ${age}          -- 数字不加引号（手动判断）
  AND date = '${date}'      -- 需要手动加引号
```

**问题**: 类型处理完全由模板作者负责

### 5.2 Datart：严格类型处理

```sql
<#-- 假设变量定义 -->
<#-- name: STRING 类型 -->
<#-- age: NUMERIC 类型 -->
<#-- date: DATE 类型 -->

WHERE name = $name$         -- 自动加引号: WHERE name = 'John'
  AND age = $age$           -- 不加引号: AND age = 25
  AND date = $date$         -- 自动加引号: AND date = '2024-01-01'
```

### 5.3 类型处理对比表

| 变量类型 | FreeMarker `${}` | Datart `$var$` |
|---------|------------------|----------------|
| STRING | `'${var}'` (手动加引号) | `'value'` (自动) |
| NUMERIC | `${var}` | `123` (自动不加引号) |
| DATE | `'${var}'` (手动加引号) | `'2024-01-01'` (自动) |
| BOOLEAN | `${var}` | `TRUE` / `FALSE` |
| FRAGMENT | 不适用 | 直接替换（不处理） |

### 5.4 代码依据

```java
// 文件: data-providers/.../calcite/SqlNodeUtils.java

public static List<SqlNode> createSqlNodes(ScriptVariable variable, SqlParserPos pos) {
    switch (variable.getValueType()) {
        case STRING:
            // 字符串：创建带引号的字面量
            return variable.getValues().stream()
                    .map(SqlSimpleStringLiteral::new)  // 自动处理引号和转义
                    .collect(Collectors.toList());
        case NUMERIC:
            // 数字：创建数值字面量（无引号）
            return variable.getValues().stream()
                    .map(v -> SqlLiteral.createExactNumeric(v, pos))
                    .collect(Collectors.toList());
        case DATE:
            // 日期：作为字符串处理
            return variable.getValues().stream()
                    .map(v -> createDateSqlNode(v, variable.getFormat()))
                    .collect(Collectors.toList());
        // ...
    }
}
```

---

## 6. 多值处理差异

### 6.1 FreeMarker：手动循环

```sql
<#-- 变量: categories = ["电子", "服装", "食品"] -->

<#-- 必须手动循环生成 IN 列表 -->
WHERE category IN (
  <#list categories as cat>
    '${cat}'<#sep>, </#sep>
  </#list>
)

<#-- 生成结果 -->
WHERE category IN ('电子', '服装', '食品')
```

**问题**:
- 代码冗长
- 需要手动处理引号
- 需要手动处理分隔符
- 空列表需要特殊处理

### 6.2 Datart：自动智能处理

```sql
<#-- 变量: category (多选，值为 ["电子", "服装", "食品"]) -->

<#-- 简单写法 -->
WHERE category = $category$

<#-- 自动生成结果 -->
WHERE category IN ('电子', '服装', '食品')
```

**Datart 的智能转换**:

| 原SQL | 单值结果 | 多值结果 |
|-------|---------|---------|
| `= $var$` | `= 'value'` | `IN ('v1', 'v2', 'v3')` |
| `!= $var$` | `!= 'value'` | `NOT IN ('v1', 'v2', 'v3')` |
| `LIKE $var$` | `LIKE 'value'` | `(LIKE 'v1' OR LIKE 'v2')` |
| `> $var$` | `> value` | `> min(values)` |
| `< $var$` | `< value` | `< max(values)` |

### 6.3 代码依据

```java
// 文件: data-providers/.../script/VariablePlaceholder.java

protected SqlCall autoFixSqlCall(ScriptVariable variable) {
    SqlKind kind = sqlCall.getOperator().kind;

    switch (kind) {
        case EQUALS:
            // = 自动转换为 IN
            sqlOperator = SqlStdOperatorTable.IN;
            break;
        case NOT_EQUALS:
            // != 自动转换为 NOT IN
            sqlOperator = SqlStdOperatorTable.NOT_IN;
            break;
        case LIKE:
            // LIKE 转换为多个 OR
            sqlOperator = SqlStdOperatorTable.OR;
            operandList = variable.getValues().stream()
                .map(val -> createLikeCall(column, val))
                .collect(Collectors.toList());
            break;
        case GREATER_THAN:
        case GREATER_THAN_OR_EQUAL:
            // > 或 >= 取最小值
            reduceVariableToMin(variable);
            break;
        case LESS_THAN:
        case LESS_THAN_OR_EQUAL:
            // < 或 <= 取最大值
            reduceVariableToMax(variable);
            break;
    }
}
```

---

## 7. 安全性对比

### 7.1 SQL注入风险分析

**攻击场景**: 用户输入 `John'; DROP TABLE users; --`

#### FreeMarker `${}` —— 危险 ❌

```sql
<#-- 模板 -->
SELECT * FROM users WHERE name = '${userName}'

<#-- 恶意输入后的结果 -->
SELECT * FROM users WHERE name = 'John'; DROP TABLE users; --'
```

**结果**: SQL注入成功，users表被删除

#### Datart `$var$` —— 安全 ✅

```sql
<#-- 模板 -->
SELECT * FROM users WHERE name = $userName$

<#-- 恶意输入后的结果 -->
SELECT * FROM users WHERE name = 'John''; DROP TABLE users; --'
```

**结果**: 单引号被转义为 `''`，攻击失败，只是查询一个奇怪的名字

### 7.2 转义机制

**Datart 的 SqlSimpleStringLiteral 处理**:

```java
// 自动将 ' 转义为 ''
// 输入: John's Shop
// 输出: 'John''s Shop'
```

### 7.3 安全对比表

| 攻击类型 | FreeMarker `${}` | Datart `$var$` |
|---------|------------------|----------------|
| 单引号注入 | ❌ 危险 | ✅ 自动转义 |
| 双引号注入 | ❌ 危险 | ✅ 自动转义 |
| 注释截断 | ❌ 危险 | ✅ 安全 |
| 联合查询注入 | ❌ 危险 | ✅ 安全 |
| 布尔盲注 | ❌ 危险 | ✅ 安全 |

### 7.4 安全使用建议

```sql
<#-- ❌ 绝对不要这样做 -->
WHERE password = '${userInput}'

<#-- ✅ 正确做法 -->
WHERE password = $userInput$
```

---

## 8. 适用场景决策

### 8.1 决策流程图

```
需要输出什么内容？
        │
        ├─── SQL标识符（表名、字段名、别名）
        │           │
        │           └──→ 使用 FreeMarker ${}
        │                 例: SELECT * FROM ${tableName}
        │
        ├─── SQL关键字（ASC、DESC、AND、OR）
        │           │
        │           └──→ 使用 FreeMarker ${}
        │                 例: ORDER BY name ${sortDir}
        │
        ├─── SQL结构片段（JOIN子句、子查询）
        │           │
        │           └──→ 使用 FreeMarker ${} 或 FRAGMENT变量
        │                 例: ${joinClause}
        │
        ├─── 在 <#list>/<#if> 内部输出
        │           │
        │           ├── 输出标识符 → 使用 ${}
        │           │     例: <#list cols as c>${c.name}</#list>
        │           │
        │           └── 输出值 → 视情况
        │                 结构化循环 → '${v}'
        │                 简单值 → 改用 $var$
        │
        └─── 用户输入的过滤值
                    │
                    └──→ 必须使用 Datart $var$
                          例: WHERE name = $userName$
```

### 8.2 场景对照表

| 场景 | 推荐语法 | 示例 | 原因 |
|------|---------|------|------|
| 动态表名 | `${}` | `FROM ${tbl}` | 表名是标识符 |
| 动态字段名 | `${}` | `SELECT ${col}` | 字段名是标识符 |
| 动态别名 | `${}` | `AS ${alias}` | 别名是标识符 |
| 排序方向 | `${}` | `ORDER BY x ${dir}` | ASC/DESC是关键字 |
| 动态JOIN | `${}` | `${joinClause}` | SQL结构片段 |
| **字符串过滤值** | `$var$` | `= $name$` | **防注入** |
| **数值过滤值** | `$var$` | `> $age$` | 类型安全 |
| **日期过滤值** | `$var$` | `>= $startDate$` | 类型安全 |
| **多选过滤值** | `$var$` | `IN $categories$` | 自动展开 |

### 8.3 简单记忆法

```
结构用 ${}
  值用 $var$
```

更详细版本：

```
"放在 FROM 后面的" → ${}    （表名）
"放在 SELECT 后面的" → ${}  （字段名）
"放在 = 后面的" → $var$     （值）
"用户输入的" → $var$        （必须！）
```

---

## 9. 混合使用模式

### 9.1 最佳实践模板

```sql
<#-- ========== 配置区（使用FreeMarker）========== -->
<#assign dimConfig = [
  {"field": "region_name", "alias": "地区"},
  {"field": "category_name", "alias": "类别"}
]>

<#-- 解析活跃维度 -->
<#assign activeDims = []>
<#list dimConfig as d>
  <#assign varValue = .vars[d.field]!>
  <#if varValue?? && varValue != "" && varValue != "all">
    <#assign activeDims = activeDims + [d]>
  </#if>
</#list>

<#-- ========== 主SQL ========== -->
SELECT 
  <#-- 动态字段名：FreeMarker ${} -->
  <#list activeDims as d>
  ${d.field} AS ${d.alias},
  </#list>
  SUM(amount) AS 销售额

<#-- 动态表名：FreeMarker ${} -->
FROM ${tableName!"sales_order"}

WHERE 1=1
  <#-- 用户输入的过滤值：Datart $var$ -->
  AND order_date >= $startDate$
  AND order_date <= $endDate$
  
  <#-- FreeMarker 循环内的值（需要手动加引号） -->
  <#list activeDims as d>
  AND ${d.field} IN (
    <#assign vals = .vars[d.field]>
    <#if vals?is_sequence>
      <#list vals as v>'${v}'<#sep>, </#sep></#list>
    <#else>
      '${vals}'
    </#if>
  )
  </#list>

<#-- 动态 GROUP BY：FreeMarker ${} -->
<#if activeDims?size gt 0>
GROUP BY 
  <#list activeDims as d>
  ${d.field}<#sep>, </#sep>
  </#list>
</#if>

<#-- 动态排序：FreeMarker ${} -->
ORDER BY 销售额 ${sortDirection!"DESC"}
```

### 9.2 各部分语法标注

```sql
SELECT 
  ${d.field}          <-- FreeMarker（字段名）
  AS ${d.alias},      <-- FreeMarker（别名）
  SUM(amount) AS 销售额

FROM ${tableName}     <-- FreeMarker（表名）

WHERE 1=1
  AND date >= $startDate$   <-- Datart（用户输入值）
  AND date <= $endDate$     <-- Datart（用户输入值）
  AND ${d.field} IN (       <-- FreeMarker（字段名）
    '${v}'                  <-- FreeMarker + 手动引号（循环内的值）
  )

GROUP BY ${d.field}   <-- FreeMarker（字段名）

ORDER BY 销售额 ${sortDir}  <-- FreeMarker（关键字）
```

---

## 10. 常见错误与陷阱

### 10.1 错误1：用 `${}` 处理用户输入

```sql
<#-- ❌ 危险！ -->
WHERE name = '${userName}'

<#-- ✅ 正确 -->
WHERE name = $userName$
```

### 10.2 错误2：用 `$var$` 作为表名

```sql
<#-- ❌ 错误：$var$ 会加引号 -->
SELECT * FROM $tableName$
-- 结果: SELECT * FROM 'users'  （语法错误）

<#-- ✅ 正确 -->
SELECT * FROM ${tableName}
-- 结果: SELECT * FROM users
```

### 10.3 错误3：在 FreeMarker 条件中判断 Datart 变量

```sql
<#-- ❌ 错误：$minAge$ 在 FreeMarker 阶段还未被处理 -->
<#if $minAge$ gt 0>
  AND age > $minAge$
</#if>

<#-- ✅ 正确：使用 FreeMarker 变量进行判断 -->
<#if minAge?? && minAge gt 0>
  AND age > $minAge$
</#if>
```

### 10.4 错误4：忘记 FreeMarker 循环中的引号

```sql
<#-- ❌ 错误：字符串值没有引号 -->
WHERE category IN (
  <#list categories as c>${c}<#sep>, </#sep></#list>
)
-- 结果: WHERE category IN (电子, 服装)  （语法错误）

<#-- ✅ 正确：手动添加引号 -->
WHERE category IN (
  <#list categories as c>'${c}'<#sep>, </#sep></#list>
)
-- 结果: WHERE category IN ('电子', '服装')
```

### 10.5 错误5：混淆变量作用域

```sql
<#-- ❌ 错误理解 -->
<#-- 以为 FreeMarker 处理后 Datart 变量值会变 -->

<#assign modifiedValue = minAge + 10>
AND age > $modifiedValue$   -- 错误！Datart 不认识 modifiedValue

<#-- ✅ 正确理解 -->
<#-- FreeMarker 变量和 Datart 变量是两个独立的系统 -->
<#-- Datart 只处理在变量配置中定义的变量 -->
```

### 10.6 陷阱总结表

| 陷阱 | 错误写法 | 正确写法 | 原因 |
|------|---------|---------|------|
| 用户输入 | `'${input}'` | `$input$` | SQL注入 |
| 表名 | `$tableName$` | `${tableName}` | 会加引号 |
| 字段名 | `$fieldName$` | `${fieldName}` | 会加引号 |
| 关键字 | `$sortDir$` | `${sortDir}` | 会加引号 |
| FreeMarker条件 | `<#if $var$>` | `<#if var??>` | 执行时机 |
| 循环内字符串 | `${v}` | `'${v}'` | 缺少引号 |

---

## 11. 代码依据

### 11.1 FreeMarker 处理入口

```java
// 文件: data-providers/.../calcite/SqlQueryScriptProcessor.java
// 行号: 59-71

// FreeMarker 数据模型转换
Map<String, ?> dataMap = queryScript.getVariables()
    .stream()
    .collect(Collectors.toMap(ScriptVariable::getName,
        variable -> {
            if (CollectionUtils.isEmpty(variable.getValues())) {
                return "";              // 空值 → 空字符串
            } else if (variable.getValues().size() == 1) {
                return variable.getValues().iterator().next();  // 单值 → 字符串
            } else return variable.getValues();  // 多值 → 集合
        }));

// 调用 FreeMarker 处理
script = FreemarkerContext.process(queryScript.getScript(), dataMap);
```

### 11.2 FreeMarker 引擎配置

```java
// 文件: data-providers/.../freemarker/FreemarkerContext.java
// 行号: 33-53

static {
    conf = new Configuration(Configuration.VERSION_2_3_31);
    conf.setTemplateLoader(new StringTemplateLoader());
    conf.setClassicCompatible(true);  // 支持 null 值
}

public static String process(String content, Map<String, ?> dataModel) {
    String key = DigestUtils.md5DigestAsHex(content.getBytes());
    StringTemplateLoader.SCRIPT_MAP.put(key, content);
    Template template = conf.getTemplate(key);
    StringWriter writer = new StringWriter();
    template.process(dataModel, writer);  // FreeMarker 渲染
    return writer.toString();
}
```

### 11.3 Datart 变量替换入口

```java
// 文件: data-providers/.../jdbc/SqlScriptRender.java
// 行号: 127-166

public String replaceVariables(String selectSql) throws SqlParseException {
    // 构建变量映射
    Map<String, ScriptVariable> variableMap = new CaseInsensitiveMap<>();
    for (ScriptVariable variable : queryScript.getVariables()) {
        variableMap.put(variable.getNameWithQuote(), variable);
    }

    // 解析变量占位符
    List<VariablePlaceholder> placeholders = 
        SqlParserVariableResolver.resolve(sqlDialect, selectSql, variableMap);

    // 执行替换
    for (VariablePlaceholder placeholder : placeholders) {
        ReplacementPair pair = placeholder.replacementPair();
        selectSql = StringUtils.replaceIgnoreCase(
            selectSql, pair.getPattern(), pair.getReplacement());
    }

    return selectSql;
}
```

### 11.4 变量常量定义

```java
// 文件: core/src/main/java/datart/core/base/consts/Const.java
// 行号: 52-57

// Datart 变量使用 $ 作为界定符
public static final String DEFAULT_VARIABLE_QUOTE = "$";

// 变量匹配正则: $xxx$
public static final Pattern VARIABLE_PATTERN = Pattern.compile("\\$\\S+\\$");
```

---

## 12. 总结

### 12.1 核心区别

| 维度 | FreeMarker `${}` | Datart `$var$` |
|------|------------------|----------------|
| **定位** | 文本模板插值 | SQL值替换器 |
| **执行时机** | 第一阶段 | 第四阶段 |
| **SQL感知** | ❌ | ✅ |
| **类型处理** | ❌ | ✅ |
| **多值处理** | 手动循环 | 自动转IN |
| **安全性** | 无防护 | 防SQL注入 |
| **适用场景** | SQL结构 | SQL值 |

### 12.2 黄金法则

```
┌─────────────────────────────────────────────────┐
│                                                 │
│   SQL结构（表名、字段名、关键字）→ 用 ${}        │
│                                                 │
│   SQL值（过滤条件的值）→ 用 $var$               │
│                                                 │
│   用户输入 → 必须用 $var$                        │
│                                                 │
└─────────────────────────────────────────────────┘
```

### 12.3 速查表

| 我要输出... | 用什么 | 示例 |
|------------|--------|------|
| 表名 | `${}` | `FROM ${tableName}` |
| 字段名 | `${}` | `SELECT ${col}` |
| 别名 | `${}` | `AS ${alias}` |
| ASC/DESC | `${}` | `ORDER BY x ${dir}` |
| JOIN子句 | `${}` | `${joinClause}` |
| **字符串值** | `$var$` | `= $name$` |
| **数值** | `$var$` | `> $age$` |
| **日期** | `$var$` | `>= $date$` |
| **用户输入** | `$var$` | `= $input$` |

### 12.4 安全优先原则

```
当不确定用哪个时，优先选择 $var$

因为：
- $var$ 更安全（防SQL注入）
- $var$ 更智能（自动类型处理）
- $var$ 更简洁（多值自动展开）

只有在必须使用 ${} 时才使用它：
- 表名、字段名等标识符
- SQL关键字
- 在 FreeMarker 循环内输出结构
```

---

**文档版本**: 1.0  
**最后更新**: 2025-12-09  
**适用版本**: Datart 1.x
