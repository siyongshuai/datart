# FreeMarker标签快速参考 / FreeMarker Tags Quick Reference

## 技术栈 / Technology Stack

**模板引擎 / Template Engine**: Apache FreeMarker 2.3.31

**核心文件 / Core Files**:
- `FreemarkerContext.java` - FreeMarker配置
- `SqlQueryScriptProcessor.java` - SQL脚本处理器

---

## 常用标签列表 / Common Tags List

### 1. 条件判断 / Conditional

| 标签 Tag | 用途 Purpose | 示例 Example |
|----------|--------------|--------------|
| `<#if condition>` | 条件判断 / If statement | `<#if age??> AND age = ${age} </#if>` |
| `<#else>` | 否则分支 / Else branch | `<#if status??> ... <#else> ... </#if>` |
| `<#elseif condition>` | 否则如果 / Else if | `<#if x>...<#elseif y>...<#else>...</#if>` |
| `<#switch>` | 多分支选择 / Switch | `<#switch var><#case "a">...<#break></#switch>` |

### 2. 循环遍历 / Loops

| 标签 Tag | 用途 Purpose | 示例 Example |
|----------|--------------|--------------|
| `<#list seq as item>` | 列表遍历 / List iteration | `<#list ids as id>${id}<#sep>,</#sep></#list>` |
| `<#sep>` | 分隔符 / Separator | `<#list items as x>${x}<#sep>,</#sep></#list>` |
| `<#break>` | 跳出循环 / Break loop | `<#list items as x><#if x==5><#break></#if></#list>` |

### 3. 变量操作 / Variables

| 标签 Tag | 用途 Purpose | 示例 Example |
|----------|--------------|--------------|
| `<#assign var=value>` | 定义变量 / Define variable | `<#assign table = "users_" + year>` |
| `<#global var=value>` | 全局变量 / Global variable | `<#global limit = 100>` |
| `<#local var=value>` | 局部变量 / Local variable | `<#local prefix = "TB_">` |

### 4. 宏与包含 / Macros & Include

| 标签 Tag | 用途 Purpose | 示例 Example |
|----------|--------------|--------------|
| `<#macro name>` | 定义宏 / Define macro | `<#macro where table>WHERE ${table}.id>0</#macro>` |
| `<@macroName/>` | 调用宏 / Call macro | `<@where table="users"/>` |
| `<#include path>` | 包含模板 / Include template | `<#include "common.sql">` |

### 5. 其他实用标签 / Other Utilities

| 标签 Tag | 用途 Purpose | 示例 Example |
|----------|--------------|--------------|
| `<#-- comment -->` | 注释 / Comment | `<#-- This is a comment -->` |
| `<#compress>` | 压缩空白 / Compress whitespace | `<#compress>SELECT * FROM users</#compress>` |
| `<#attempt>...<#recover>` | 异常处理 / Exception handling | `<#attempt>${var}<#recover>default</#attempt>` |

---

## 常用内置函数 / Common Built-in Functions

### 判断函数 / Testing Functions

| 函数 Function | 说明 Description | 示例 Example |
|---------------|------------------|--------------|
| `??` | 变量是否存在 / Variable exists | `<#if user??>` |
| `?has_content` | 是否有内容 / Has content | `<#if list?has_content>` |
| `?is_string` | 是否为字符串 / Is string | `<#if var?is_string>` |
| `?is_number` | 是否为数字 / Is number | `<#if var?is_number>` |
| `?is_sequence` | 是否为序列 / Is sequence | `<#if var?is_sequence>` |

### 字符串函数 / String Functions

| 函数 Function | 说明 Description | 示例 Example |
|---------------|------------------|--------------|
| `?upper_case` | 转大写 / To uppercase | `${name?upper_case}` |
| `?lower_case` | 转小写 / To lowercase | `${name?lower_case}` |
| `?trim` | 去空格 / Trim | `${text?trim}` |
| `?length` | 获取长度 / Get length | `${str?length}` |
| `?replace(old,new)` | 替换 / Replace | `${text?replace("a","b")}` |
| `?substring(start,end)` | 截取子串 / Substring | `${str?substring(0,5)}` |

### 序列函数 / Sequence Functions

| 函数 Function | 说明 Description | 示例 Example |
|---------------|------------------|--------------|
| `?size` | 获取大小 / Get size | `${list?size}` |
| `?join(sep)` | 连接 / Join | `${list?join(",")}` |
| `?first` | 第一个元素 / First element | `${list?first}` |
| `?last` | 最后一个元素 / Last element | `${list?last}` |
| `?reverse` | 反转 / Reverse | `<#list items?reverse as x>` |

### 数字函数 / Number Functions

| 函数 Function | 说明 Description | 示例 Example |
|---------------|------------------|--------------|
| `?c` | 计算机格式 / Computer format | `${num?c}` |
| `?string` | 转字符串 / To string | `${num?string}` |
| `?round` | 四舍五入 / Round | `${num?round}` |
| `?floor` | 向下取整 / Floor | `${num?floor}` |
| `?ceiling` | 向上取整 / Ceiling | `${num?ceiling}` |

### 默认值 / Default Values

| 函数 Function | 说明 Description | 示例 Example |
|---------------|------------------|--------------|
| `!` or `?default` | 默认值 / Default value | `${status!"ACTIVE"}` or `${status?default("ACTIVE")}` |

---

## 运算符 / Operators

### 比较运算符 / Comparison Operators

| 运算符 Operator | 说明 Description |
|-----------------|------------------|
| `==` or `=` | 等于 / Equals |
| `!=` | 不等于 / Not equals |
| `>` or `gt` | 大于 / Greater than |
| `>=` or `gte` | 大于等于 / Greater or equal |
| `<` or `lt` | 小于 / Less than |
| `<=` or `lte` | 小于等于 / Less or equal |

### 逻辑运算符 / Logical Operators

| 运算符 Operator | 说明 Description |
|-----------------|------------------|
| `&&` or `AND` | 逻辑与 / Logical AND |
| `\|\|` or `OR` | 逻辑或 / Logical OR |
| `!` or `NOT` | 逻辑非 / Logical NOT |

### 算术运算符 / Arithmetic Operators

| 运算符 Operator | 说明 Description |
|-----------------|------------------|
| `+` | 加 / Addition |
| `-` | 减 / Subtraction |
| `*` | 乘 / Multiplication |
| `/` | 除 / Division |
| `%` | 取模 / Modulo |

---

## 实用示例 / Practical Examples

### 示例1: 动态WHERE条件 / Dynamic WHERE Conditions
```sql
SELECT * FROM orders WHERE 1=1
<#if status??>
  AND status = '${status}'
</#if>
<#if userIds?? && userIds?has_content>
  AND user_id IN (<#list userIds as id>${id}<#sep>,</#sep></#list>)
</#if>
```

### 示例2: 动态字段选择 / Dynamic Field Selection
```sql
SELECT id, name
<#if includeEmail?? && includeEmail == true>
  , email
</#if>
<#if includePhone?? && includePhone == true>
  , phone
</#if>
FROM users
```

### 示例3: 条件分支 / Conditional Branches
```sql
SELECT 
<#switch groupBy>
  <#case "day">
    DATE(create_time) as time_group
    <#break>
  <#case "month">
    DATE_FORMAT(create_time, '%Y-%m') as time_group
    <#break>
  <#default>
    create_time as time_group
</#switch>
FROM orders
```

### 示例4: 宏定义 / Macro Definition
```sql
<#macro commonWhere table>
WHERE ${table}.deleted = 0 AND ${table}.status = 'ACTIVE'
</#macro>

SELECT * FROM users <@commonWhere table="users"/>
```

### 示例5: 列表处理 / List Processing
```sql
WHERE category IN (
<#if categories??>
  <#list categories as cat>
    '${cat}'<#sep>,</#sep>
  </#list>
<#else>
  'default'
</#if>
)
```

---

## 注意事项 / Important Notes

### ⚠️ SQL注入防护 / SQL Injection Protection
```sql
-- ❌ 不安全 / Unsafe
WHERE name = '${userName}'

-- ✅ 安全 / Safe (使用变量替换机制)
WHERE name = $userName$
```

### ⚠️ 空值处理 / Null Handling
```sql
-- 检查变量 / Check variable
<#if var??>
  AND field = '${var}'
</#if>

-- 提供默认值 / Provide default
AND status = '${status!"ACTIVE"}'
```

### ⚠️ 数据库兼容性 / Database Compatibility
```sql
-- 注意不同数据库语法差异
-- Mind different database syntax

-- MySQL
<#if useLimit??>LIMIT ${limit}</#if>

-- Oracle  
<#if useLimit??>FETCH FIRST ${limit} ROWS ONLY</#if>
```

---

## 处理流程 / Processing Flow

```
SQL脚本(含FreeMarker标签)
SQL Script (with FreeMarker tags)
           ↓
FreemarkerContext.process()
           ↓
生成SQL(含变量占位符 $var$)
Generated SQL (with placeholders $var$)
           ↓
变量替换
Variable Replacement
           ↓
最终可执行SQL
Final Executable SQL
```

---

## 参考资料 / References

- **FreeMarker官方文档**: https://freemarker.apache.org/docs/
- **指令参考**: https://freemarker.apache.org/docs/ref_directive_alphaidx.html
- **内置函数**: https://freemarker.apache.org/docs/ref_builtins.html

---

## 核心文件位置 / Core File Locations

```
data-providers/data-provider-base/src/main/java/datart/data/provider/
├── freemarker/
│   ├── FreemarkerContext.java          # FreeMarker配置
│   └── StringTemplateLoader.java       # 模板加载器
└── calcite/
    └── SqlQueryScriptProcessor.java    # SQL脚本处理(59-71行)
```

**依赖配置 / Dependency**: 
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-freemarker</artifactId>
</dependency>
```

---

## 总结 / Summary

✅ **支持所有FreeMarker 2.3.31标准指令**
✅ **Supports all FreeMarker 2.3.31 standard directives**

**主要功能 / Main Features**:
- 条件判断 / Conditional statements (`<#if>`)
- 循环遍历 / Loops (`<#list>`)
- 变量操作 / Variables (`<#assign>`)
- 宏定义 / Macros (`<#macro>`)
- 多分支选择 / Switch (`<#switch>`)
- 异常处理 / Exception handling (`<#attempt>`)

**应用场景 / Use Cases**:
- 动态WHERE条件 / Dynamic WHERE conditions
- 动态SELECT字段 / Dynamic SELECT fields
- 动态表名/字段名 / Dynamic table/column names
- 条件性JOIN / Conditional JOINs
- 动态GROUP BY / Dynamic GROUP BY
