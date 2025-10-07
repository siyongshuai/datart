# SQL View Dynamic Template Technology

## Technology Overview

The `<#if>` and other tags in Datart SQL views use **Apache FreeMarker Template Engine** technology.

### Core Technology Stack

- **Template Engine**: Apache FreeMarker 2.3.31
- **Processing Location**: `SqlQueryScriptProcessor.java` lines 59-71
- **Configuration Class**: `FreemarkerContext.java`
- **Dependency**: `spring-boot-starter-freemarker`

### How It Works

```java
// Before executing SQL, use FreeMarker to process conditional expressions in the script
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

**Processing Flow**:
1. Convert variables to data model (dataMap)
2. FreeMarker parses template tags in SQL script
3. Dynamically generate SQL statements based on variable values
4. Continue with variable replacement and SQL parsing

---

## Supported FreeMarker Tags

Datart SQL views support all standard FreeMarker directive tags. Here are commonly used tags:

### 1. **Conditional Tags**

#### `<#if>` - Conditional Statement
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

#### `<#if>...<#else>` - Conditional Branch
```sql
SELECT * FROM orders
WHERE 1=1
<#if status??>
  AND status = '${status}'
<#else>
  AND status = 'PENDING'
</#if>
```

#### `<#if>...<#elseif>...<#else>` - Multiple Conditions
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

### 2. **Loop Tags**

#### `<#list>` - List Iteration
```sql
SELECT * FROM users
WHERE id IN (
<#list userIds as id>
  ${id}<#sep>,</#sep>
</#list>
)
```

#### Loop with Index
```sql
SELECT * FROM products
WHERE (
<#list categories as cat>
  category = '${cat}' <#sep>OR</#sep>
</#list>
)
```

### 3. **Variable Assignment Tags**

#### `<#assign>` - Define Variable
```sql
<#assign tableName = "users_" + year>
SELECT * FROM ${tableName}
WHERE create_time >= '${startDate}'
```

#### `<#global>` - Global Variable
```sql
<#global defaultLimit = 100>
SELECT * FROM products
LIMIT ${defaultLimit}
```

#### `<#local>` - Local Variable
```sql
<#local prefix = "TB_">
SELECT * FROM ${prefix}${tableName}
```

### 4. **Include and Import Tags**

#### `<#include>` - Include Template
```sql
-- Can theoretically include other SQL fragments
<#include "common_where.sql">
```

### 5. **Macro Definition Tags**

#### `<#macro>` - Define Macro
```sql
<#macro whereClause table>
  WHERE ${table}.deleted = 0
  AND ${table}.status = 'ACTIVE'
</#macro>

SELECT * FROM users
<@whereClause table="users"/>
```

### 6. **Switch Tags**

#### `<#switch>` - Multiple Choice
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

### 7. **Other Utility Tags**

#### `<#attempt>...<#recover>` - Exception Handling
```sql
<#attempt>
  ${dynamicColumn}
<#recover>
  'default_column'
</#attempt>
```

#### `<#compress>` - Compress Whitespace
```sql
<#compress>
  SELECT * 
  FROM users
  WHERE status = 'ACTIVE'
</#compress>
```

#### `<#escape>` - Character Escape
```sql
<#escape x as x?html>
  -- Escape special characters
</#escape>
```

### 8. **Comment Tags**

#### `<#-- -->` - Template Comments
```sql
<#-- This is a FreeMarker comment, won't appear in final SQL -->
SELECT * FROM users
-- This is a SQL comment, will be kept
```

---

## Built-in Functions and Operators

### Common Built-in Functions

#### Testing Functions
- `??` - Check if variable exists
- `?has_content` - Check if has content
- `?is_string` - Check if is string
- `?is_number` - Check if is number
- `?is_sequence` - Check if is sequence (array)

```sql
<#if userIds?? && userIds?has_content>
  WHERE id IN (
  <#list userIds as id>
    ${id}<#sep>,</#sep>
  </#list>
  )
</#if>
```

#### String Functions
- `?upper_case` - Convert to uppercase
- `?lower_case` - Convert to lowercase
- `?trim` - Trim whitespace
- `?length` - Get length
- `?replace(old, new)` - Replace

```sql
<#assign tableName = tableName?upper_case>
SELECT * FROM ${tableName}
```

#### Sequence Functions
- `?size` - Get size
- `?join(sep)` - Join
- `?first` - First element
- `?last` - Last element

```sql
<#if categories?size gt 0>
  WHERE category IN ('${categories?join("','")}')
</#if>
```

#### Number Functions
- `?string` - Convert to string
- `?c` - Computer format (no thousand separator)
- `?round` - Round

```sql
WHERE price > ${minPrice?c}
```

### Comparison Operators

- `==` or `=` - Equals
- `!=` - Not equals
- `>` or `gt` - Greater than
- `>=` or `gte` - Greater than or equal
- `<` or `lt` - Less than
- `<=` or `lte` - Less than or equal

### Logical Operators

- `&&` or `AND` - Logical AND
- `||` or `OR` - Logical OR
- `!` or `NOT` - Logical NOT

```sql
<#if (status == 'ACTIVE') && (age gte 18)>
  -- Condition met
</#if>
```

---

## Practical Examples

### Example 1: Dynamic WHERE Conditions
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

### Example 2: Dynamic SELECT Fields
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

### Example 3: Dynamic GROUP BY
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

### Example 4: Dynamic JOIN
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

### Example 5: Dynamic Table Names
```sql
<#assign baseTable = "sales_" + region?lower_case>
SELECT * FROM ${baseTable}
WHERE sale_date BETWEEN '${startDate}' AND '${endDate}'
```

---

## Configuration

### FreeMarker Configuration Location
**File**: `data-providers/data-provider-base/src/main/java/datart/data/provider/freemarker/FreemarkerContext.java`

```java
static {
    conf = new Configuration(Configuration.VERSION_2_3_31);
    // Load templates from strings
    conf.setTemplateLoader(new StringTemplateLoader());
    // Enable FreeMarker to support null values
    conf.setClassicCompatible(true);
}
```

### Key Configuration Items

1. **Version**: `Configuration.VERSION_2_3_31`
2. **Template Loader**: Custom `StringTemplateLoader`, loads templates from memory strings
3. **Classic Compatible Mode**: `setClassicCompatible(true)` - Supports null value handling

---

## Important Notes

### 1. **SQL Injection Protection**
FreeMarker tags themselves don't provide SQL injection protection:
```sql
-- ❌ Dangerous: Direct user input
WHERE name = '${userName}'

-- ✅ Safe: Use variable replacement mechanism
WHERE name = $userName$
```

### 2. **Null Variable Handling**
```sql
-- Recommended: Check if variable exists
<#if status??>
  AND status = '${status}'
</#if>

-- Or provide default value
AND status = '${status!"ACTIVE"}'
```

### 3. **SQL Syntax Compatibility**
FreeMarker-processed SQL must conform to target database syntax:
```sql
-- MySQL
<#if useLimit??>
  LIMIT ${limit}
</#if>

-- Oracle (different syntax)
<#if useLimit??>
  FETCH FIRST ${limit} ROWS ONLY
</#if>
```

### 4. **Performance Considerations**
- FreeMarker template cache uses LRU strategy, max 1000 templates
- Complex template nesting may affect SQL generation performance

---

## Processing Flow

```
SQL Script (with FreeMarker tags)
    ↓
FreemarkerContext.process() - Process FreeMarker tags
    ↓
Generated SQL (with variable placeholders $var$)
    ↓
SqlStringUtils.replaceFragmentVariables() - Replace FRAGMENT type variables
    ↓
SqlStringUtils.cleanupSql() - Clean up SQL
    ↓
SqlScriptRender.replaceVariables() - Replace other type variables
    ↓
Final executable SQL
```

---

## Related Files

### Core Implementation Files
1. **FreemarkerContext.java** - FreeMarker context configuration
   - Path: `data-providers/data-provider-base/src/main/java/datart/data/provider/freemarker/FreemarkerContext.java`
   
2. **StringTemplateLoader.java** - String template loader
   - Path: `data-providers/data-provider-base/src/main/java/datart/data/provider/freemarker/StringTemplateLoader.java`

3. **SqlQueryScriptProcessor.java** - SQL script processor
   - Path: `data-providers/data-provider-base/src/main/java/datart/data/provider/calcite/SqlQueryScriptProcessor.java`
   - Lines 59-71: FreeMarker template processing logic

4. **SqlScriptRender.java** - SQL script renderer
   - Path: `data-providers/data-provider-base/src/main/java/datart/data/provider/jdbc/SqlScriptRender.java`

### Dependency Configuration
**pom.xml**: `data-providers/data-provider-base/pom.xml`
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-freemarker</artifactId>
</dependency>
```

---

## References

- **FreeMarker Official Documentation**: https://freemarker.apache.org/docs/
- **FreeMarker 2.3.31 API**: https://freemarker.apache.org/docs/api/
- **Directive Reference**: https://freemarker.apache.org/docs/ref_directive_alphaidx.html
- **Built-in Functions**: https://freemarker.apache.org/docs/ref_builtins.html

---

## Summary

Datart SQL views use **Apache FreeMarker 2.3.31** as the template engine, supporting all FreeMarker standard directives:

**Main Tags**:
- ✅ `<#if>` - Conditional statement
- ✅ `<#list>` - List iteration
- ✅ `<#assign>` - Variable assignment
- ✅ `<#switch>` - Multiple choice
- ✅ `<#macro>` - Macro definition
- ✅ `<#include>` - Include templates
- ✅ `<#compress>` - Compress whitespace
- ✅ `<#attempt>` - Exception handling

**Common Operators and Functions**:
- Testing: `??`, `?has_content`, `?is_string`
- String: `?upper_case`, `?lower_case`, `?replace`
- Sequence: `?size`, `?join`, `?first`, `?last`
- Comparison: `==`, `!=`, `>`, `<`, `>=`, `<=`
- Logical: `&&`, `||`, `!`

Through FreeMarker template engine, flexible and powerful dynamic SQL generation capabilities can be achieved to meet various complex data query scenarios.
