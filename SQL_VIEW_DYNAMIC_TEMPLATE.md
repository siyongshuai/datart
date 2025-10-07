# SQL视图动态模板技术说明

## 技术概述

Datart SQL视图中的`<#if>`等标签使用的是 **FreeMarker模板引擎** 技术。

### 核心技术栈

- **模板引擎**: Apache FreeMarker 2.3.31
- **处理位置**: `SqlQueryScriptProcessor.java` 第59-71行
- **配置类**: `FreemarkerContext.java`
- **依赖**: `spring-boot-starter-freemarker`

### 工作原理

```java
// 在执行SQL前，使用FreeMarker处理脚本中的条件表达式
Map<String, ?> dataMap = queryScript.getVariables()
    .stream()
    .collect(Collectors.toMap(ScriptVariable::getName,
        variable -> {
            if (CollectionUtils.isEmpty(variable.getValues())) {
                return "";
            } else if (variable.getValues().size() == 1) {
                return variable.getValues().iterator().next();
            } else return variable.getValues();
        }));

script = FreemarkerContext.process(queryScript.getScript(), dataMap);
```

**处理流程**：
1. 将变量转换为数据模型（dataMap）
2. FreeMarker解析SQL脚本中的模板标签
3. 根据变量值动态生成SQL语句
4. 继续进行变量替换和SQL解析

---

## 支持的FreeMarker标签

Datart SQL视图支持FreeMarker的所有标准指令标签。以下是常用标签列表：

### 1. **条件判断标签**

#### `<#if>` - 条件判断
```sql
SELECT * FROM users
WHERE 1=1
<#if age??>
  AND age = ${age}
</#if>
<#if name??>
  AND name = '${name}'
</#if>
```

#### `<#if>...<#else>` - 条件分支
```sql
SELECT * FROM orders
WHERE 1=1
<#if status??>
  AND status = '${status}'
<#else>
  AND status = 'PENDING'
</#if>
```

#### `<#if>...<#elseif>...<#else>` - 多条件分支
```sql
SELECT * FROM products
WHERE 1=1
<#if category == 'electronics'>
  AND price > 1000
<#elseif category == 'books'>
  AND price > 50
<#else>
  AND price > 0
</#if>
```

### 2. **循环标签**

#### `<#list>` - 列表遍历
```sql
SELECT * FROM users
WHERE id IN (
<#list userIds as id>
  ${id}<#sep>,</#sep>
</#list>
)
```

#### 带索引的循环
```sql
SELECT * FROM products
WHERE (
<#list categories as cat>
  category = '${cat}' <#sep>OR</#sep>
</#list>
)
```

### 3. **变量赋值标签**

#### `<#assign>` - 定义变量
```sql
<#assign tableName = "users_" + year>
SELECT * FROM ${tableName}
WHERE create_time >= '${startDate}'
```

#### `<#global>` - 全局变量
```sql
<#global defaultLimit = 100>
SELECT * FROM products
LIMIT ${defaultLimit}
```

#### `<#local>` - 局部变量
```sql
<#local prefix = "TB_">
SELECT * FROM ${prefix}${tableName}
```

### 4. **包含与导入标签**

#### `<#include>` - 包含模板（不常用于SQL）
```sql
-- 理论上可以包含其他SQL片段
<#include "common_where.sql">
```

### 5. **宏定义标签**

#### `<#macro>` - 定义宏
```sql
<#macro whereClause table>
  WHERE ${table}.deleted = 0
  AND ${table}.status = 'ACTIVE'
</#macro>

SELECT * FROM users
<@whereClause table="users"/>
```

### 6. **开关标签**

#### `<#switch>` - 多分支选择
```sql
SELECT 
  <#switch orderType>
    <#case "daily">
      DATE(order_time) as time_group
      <#break>
    <#case "monthly">
      DATE_FORMAT(order_time, '%Y-%m') as time_group
      <#break>
    <#case "yearly">
      YEAR(order_time) as time_group
      <#break>
    <#default>
      order_time as time_group
  </#switch>
FROM orders
```

### 7. **其他实用标签**

#### `<#attempt>...<#recover>` - 异常处理
```sql
<#attempt>
  ${dynamicColumn}
<#recover>
  'default_column'
</#attempt>
```

#### `<#compress>` - 压缩空白
```sql
<#compress>
  SELECT * 
  FROM users
  WHERE status = 'ACTIVE'
</#compress>
```

#### `<#escape>` - 字符转义
```sql
<#escape x as x?html>
  -- 转义特殊字符
</#escape>
```

### 8. **注释标签**

#### `<#-- -->` - 模板注释
```sql
<#-- 这是FreeMarker注释，不会出现在最终SQL中 -->
SELECT * FROM users
-- 这是SQL注释，会保留
```

---

## 内置函数和运算符

### 常用内置函数

#### 判断函数
- `??` - 判断变量是否存在
- `?has_content` - 判断是否有内容
- `?is_string` - 判断是否为字符串
- `?is_number` - 判断是否为数字
- `?is_sequence` - 判断是否为序列（数组）

```sql
<#if userIds?? && userIds?has_content>
  WHERE id IN (
  <#list userIds as id>
    ${id}<#sep>,</#sep>
  </#list>
  )
</#if>
```

#### 字符串函数
- `?upper_case` - 转大写
- `?lower_case` - 转小写
- `?trim` - 去空格
- `?length` - 获取长度
- `?replace(old, new)` - 替换

```sql
<#assign tableName = tableName?upper_case>
SELECT * FROM ${tableName}
```

#### 序列函数
- `?size` - 获取大小
- `?join(sep)` - 连接
- `?first` - 第一个元素
- `?last` - 最后一个元素

```sql
<#if categories?size gt 0>
  WHERE category IN ('${categories?join("','")}')
</#if>
```

#### 数字函数
- `?string` - 转字符串
- `?c` - 计算机格式（无千分位）
- `?round` - 四舍五入

```sql
WHERE price > ${minPrice?c}
```

### 比较运算符

- `==` 或 `=` - 等于
- `!=` - 不等于
- `>` 或 `gt` - 大于
- `>=` 或 `gte` - 大于等于
- `<` 或 `lt` - 小于
- `<=` 或 `lte` - 小于等于

### 逻辑运算符

- `&&` 或 `AND` - 逻辑与
- `||` 或 `OR` - 逻辑或
- `!` 或 `NOT` - 逻辑非

```sql
<#if (status == 'ACTIVE') && (age gte 18)>
  -- 条件成立
</#if>
```

---

## 实际应用示例

### 示例1: 动态WHERE条件
```sql
SELECT * FROM orders
WHERE 1=1
<#if startDate??>
  AND order_date >= '${startDate}'
</#if>
<#if endDate??>
  AND order_date <= '${endDate}'
</#if>
<#if status??>
  AND status = '${status}'
</#if>
<#if userIds?? && userIds?has_content>
  AND user_id IN (
  <#list userIds as id>
    ${id}<#sep>,</#sep>
  </#list>
  )
</#if>
```

### 示例2: 动态SELECT字段
```sql
SELECT 
  id,
  name,
  <#if includeEmail?? && includeEmail == true>
  email,
  </#if>
  <#if includePhone?? && includePhone == true>
  phone,
  </#if>
  create_time
FROM users
```

### 示例3: 动态GROUP BY
```sql
SELECT 
  <#if groupBy == 'day'>
    DATE(order_time) as time_group,
  <#elseif groupBy == 'month'>
    DATE_FORMAT(order_time, '%Y-%m') as time_group,
  <#else>
    YEAR(order_time) as time_group,
  </#if>
  SUM(amount) as total_amount
FROM orders
GROUP BY time_group
```

### 示例4: 动态JOIN
```sql
SELECT u.*, o.order_count
FROM users u
<#if includeOrders?? && includeOrders == true>
LEFT JOIN (
  SELECT user_id, COUNT(*) as order_count
  FROM orders
  GROUP BY user_id
) o ON u.id = o.user_id
</#if>
```

### 示例5: 多表名切换
```sql
<#assign baseTable = "sales_" + region?lower_case>
SELECT * FROM ${baseTable}
WHERE sale_date BETWEEN '${startDate}' AND '${endDate}'
```

---

## 配置说明

### FreeMarker配置位置
**文件**: `data-providers/data-provider-base/src/main/java/datart/data/provider/freemarker/FreemarkerContext.java`

```java
static {
    conf = new Configuration(Configuration.VERSION_2_3_31);
    // 模板从字符串加载
    conf.setTemplateLoader(new StringTemplateLoader());
    // 使freemarker支持 null 值
    conf.setClassicCompatible(true);
}
```

### 关键配置项

1. **版本**: `Configuration.VERSION_2_3_31`
2. **模板加载器**: 自定义的`StringTemplateLoader`，从内存字符串加载模板
3. **经典兼容模式**: `setClassicCompatible(true)` - 支持null值处理

---

## 注意事项

### 1. **SQL注入防护**
FreeMarker标签本身不做SQL注入防护，使用时需要注意：
```sql
-- ❌ 危险：直接插入用户输入
WHERE name = '${userName}'

-- ✅ 安全：使用变量替换机制
WHERE name = $userName$
```

### 2. **变量为空的处理**
```sql
-- 推荐做法：检查变量是否存在
<#if status??>
  AND status = '${status}'
</#if>

-- 或者提供默认值
AND status = '${status!"ACTIVE"}'
```

### 3. **SQL语法兼容**
FreeMarker处理后的SQL需要符合目标数据库语法：
```sql
-- MySQL
<#if useLimit??>
  LIMIT ${limit}
</#if>

-- Oracle (不同语法)
<#if useLimit??>
  FETCH FIRST ${limit} ROWS ONLY
</#if>
```

### 4. **性能考虑**
- FreeMarker模板缓存使用LRU策略，最多缓存1000个模板
- 复杂的模板嵌套可能影响SQL生成性能

---

## 处理流程

```
SQL脚本（含FreeMarker标签）
    ↓
FreemarkerContext.process() - 处理FreeMarker标签
    ↓
生成的SQL（含变量占位符 $var$）
    ↓
SqlStringUtils.replaceFragmentVariables() - 替换FRAGMENT类型变量
    ↓
SqlStringUtils.cleanupSql() - 清理SQL
    ↓
SqlScriptRender.replaceVariables() - 替换其他类型变量
    ↓
最终可执行的SQL
```

---

## 相关文件

### 核心实现文件
1. **FreemarkerContext.java** - FreeMarker上下文配置
   - 路径: `data-providers/data-provider-base/src/main/java/datart/data/provider/freemarker/FreemarkerContext.java`
   
2. **StringTemplateLoader.java** - 字符串模板加载器
   - 路径: `data-providers/data-provider-base/src/main/java/datart/data/provider/freemarker/StringTemplateLoader.java`

3. **SqlQueryScriptProcessor.java** - SQL脚本处理器
   - 路径: `data-providers/data-provider-base/src/main/java/datart/data/provider/calcite/SqlQueryScriptProcessor.java`
   - 第59-71行: FreeMarker模板处理逻辑

4. **SqlScriptRender.java** - SQL脚本渲染器
   - 路径: `data-providers/data-provider-base/src/main/java/datart/data/provider/jdbc/SqlScriptRender.java`

### 依赖配置
**pom.xml**: `data-providers/data-provider-base/pom.xml`
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-freemarker</artifactId>
</dependency>
```

---

## 参考资料

- **FreeMarker官方文档**: https://freemarker.apache.org/docs/
- **FreeMarker 2.3.31 API**: https://freemarker.apache.org/docs/api/
- **指令参考**: https://freemarker.apache.org/docs/ref_directive_alphaidx.html
- **内置函数**: https://freemarker.apache.org/docs/ref_builtins.html

---

## 总结

Datart SQL视图使用 **Apache FreeMarker 2.3.31** 作为模板引擎，支持所有FreeMarker标准指令：

**主要标签**:
- ✅ `<#if>` - 条件判断
- ✅ `<#list>` - 列表循环
- ✅ `<#assign>` - 变量赋值
- ✅ `<#switch>` - 多分支选择
- ✅ `<#macro>` - 宏定义
- ✅ `<#include>` - 包含其他模板
- ✅ `<#compress>` - 压缩空白
- ✅ `<#attempt>` - 异常处理

**常用运算符和函数**:
- 判断: `??`, `?has_content`, `?is_string`
- 字符串: `?upper_case`, `?lower_case`, `?replace`
- 序列: `?size`, `?join`, `?first`, `?last`
- 比较: `==`, `!=`, `>`, `<`, `>=`, `<=`
- 逻辑: `&&`, `||`, `!`

通过FreeMarker模板引擎，可以实现灵活强大的动态SQL生成能力，满足各种复杂的数据查询场景。
