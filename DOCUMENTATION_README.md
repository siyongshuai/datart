# Datart SQL视图技术文档 / SQL View Technical Documentation

## 📚 文档概述 / Documentation Overview

本文档集提供了Datart SQL视图的完整技术文档，包括变量系统和动态模板功能的详细说明。

This documentation set provides complete technical documentation for Datart SQL views, including detailed descriptions of the variable system and dynamic template features.

---

## 📖 快速导航 / Quick Navigation

### 📑 主索引文档 / Main Index
**[DATART_SQL_VIEW_DOCUMENTATION.md](./DATART_SQL_VIEW_DOCUMENTATION.md)** - 完整文档索引和技术概览

### 🔤 变量类型 / Variable Types
- **[SQL_VIEW_VARIABLE_TYPES.md](./SQL_VIEW_VARIABLE_TYPES.md)** - 中文详细文档
- **[SQL_VIEW_VARIABLE_TYPES_EN.md](./SQL_VIEW_VARIABLE_TYPES_EN.md)** - English Documentation
- **[VARIABLE_TYPES_SUMMARY.md](./VARIABLE_TYPES_SUMMARY.md)** - 快速参考

### 🏷️ 动态模板 / Dynamic Templates  
- **[SQL_VIEW_DYNAMIC_TEMPLATE.md](./SQL_VIEW_DYNAMIC_TEMPLATE.md)** - 中文详细文档
- **[SQL_VIEW_DYNAMIC_TEMPLATE_EN.md](./SQL_VIEW_DYNAMIC_TEMPLATE_EN.md)** - English Documentation
- **[FREEMARKER_TAGS_REFERENCE.md](./FREEMARKER_TAGS_REFERENCE.md)** - 快速参考

---

## 🎯 核心功能 / Core Features

### 1️⃣ 变量系统 / Variable System

**支持的变量类型 / Supported Variable Types:**
- STRING (字符串)
- NUMERIC (数值)
- DATE (日期)
- FRAGMENT (表达式/SQL片段)

**使用示例 / Usage Example:**
```sql
SELECT * FROM users
WHERE age > $age$
  AND name = $name$
  AND create_time >= $startDate$
```

### 2️⃣ 动态模板 / Dynamic Templates

**使用FreeMarker 2.3.31模板引擎 / Using FreeMarker 2.3.31 Template Engine**

**支持的标签 / Supported Tags:**
- `<#if>` - 条件判断 / Conditional
- `<#list>` - 循环遍历 / Loop
- `<#assign>` - 变量赋值 / Variable assignment
- `<#switch>` - 多分支选择 / Switch
- `<#macro>` - 宏定义 / Macro definition

**使用示例 / Usage Example:**
```sql
SELECT * FROM orders
WHERE 1=1
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

---

## 🚀 快速开始 / Quick Start

### 步骤1: 创建变量 / Step 1: Create Variables
在视图的"属性"面板中创建变量，设置名称、类型和默认值。

Create variables in the view's "Properties" panel, set name, type, and default value.

### 步骤2: 在SQL中使用变量 / Step 2: Use Variables in SQL
```sql
-- 使用变量占位符 $变量名$
-- Use variable placeholder $variableName$
SELECT * FROM products WHERE price > $minPrice$
```

### 步骤3: 添加动态条件 / Step 3: Add Dynamic Conditions
```sql
-- 使用FreeMarker标签
-- Use FreeMarker tags
SELECT * FROM users
WHERE 1=1
<#if department??>
  AND department = '${department}'
</#if>
```

---

## 📊 技术架构 / Technical Architecture

### 处理流程 / Processing Flow

```
用户SQL (User SQL)
  ↓
FreeMarker模板处理 (Template Processing)
  ↓
变量替换 (Variable Replacement)
  ↓
SQL解析优化 (SQL Parsing & Optimization)
  ↓
最终SQL (Final SQL)
```

### 核心组件 / Core Components

1. **FreemarkerContext** - 模板引擎配置
2. **SqlQueryScriptProcessor** - SQL脚本处理器
3. **VariablePlaceholder** - 变量占位符处理
4. **SqlScriptRender** - SQL渲染器

---

## 💡 使用建议 / Best Practices

### ✅ 推荐做法 / Recommended

1. **变量使用** / Variable Usage
   ```sql
   -- 使用变量占位符，安全且自动处理类型
   WHERE name = $userName$
   ```

2. **空值检查** / Null Check
   ```sql
   <#if variable??>
     AND field = '${variable}'
   </#if>
   ```

3. **列表处理** / List Processing
   ```sql
   <#if list?has_content>
     WHERE id IN (<#list list as item>${item}<#sep>,</#sep></#list>)
   </#if>
   ```

### ❌ 避免做法 / Avoid

1. **直接插值** / Direct Interpolation
   ```sql
   -- 可能有SQL注入风险
   WHERE name = '${userName}'  
   ```

2. **不检查存在性** / Not Checking Existence
   ```sql
   -- 变量不存在时会报错
   AND status = '${status}'
   ```

---

## 🔗 相关资源 / Related Resources

### 官方文档 / Official Docs
- Datart文档: http://running-elephant.gitee.io/datart-docs/
- FreeMarker文档: https://freemarker.apache.org/docs/

### 代码仓库 / Repository
- GitHub: https://github.com/running-elephant/datart
- Gitee: https://gitee.com/running-elephant/datart

### 社区 / Community
- Issue: https://gitee.com/running-elephant/datart/issues
- 插件示例: https://gitee.com/running-elephant/datart-extension-charts

---

## ❓ 常见问题 / FAQ

### Q1: 变量和FreeMarker标签有什么区别？
**A:** 
- 变量 (`$var$`) 用于值替换，系统自动处理类型和安全性
- FreeMarker标签 (`<#if>`) 用于控制SQL结构，实现动态逻辑

### Q2: 如何防止SQL注入？
**A:** 
- 优先使用变量占位符 `$var$`
- 避免直接使用FreeMarker插值 `${var}` 插入用户输入

### Q3: 支持哪些FreeMarker功能？
**A:** 
- 支持FreeMarker 2.3.31的所有标准指令和内置函数
- 详见 [FREEMARKER_TAGS_REFERENCE.md](./FREEMARKER_TAGS_REFERENCE.md)

### Q4: 如何在不同数据库间保持兼容？
**A:** 
- 使用FreeMarker条件判断处理不同数据库语法
- 参考文档中的数据库兼容性示例

---

## 📝 文档列表 / Document List

| 文档 Document | 语言 Language | 类型 Type | 说明 Description |
|---------------|---------------|-----------|------------------|
| [DATART_SQL_VIEW_DOCUMENTATION.md](./DATART_SQL_VIEW_DOCUMENTATION.md) | 双语 Bilingual | 索引 Index | 完整文档索引 |
| [SQL_VIEW_VARIABLE_TYPES.md](./SQL_VIEW_VARIABLE_TYPES.md) | 中文 Chinese | 详细 Detailed | 变量类型完整说明 |
| [SQL_VIEW_VARIABLE_TYPES_EN.md](./SQL_VIEW_VARIABLE_TYPES_EN.md) | English | Detailed | Variable types documentation |
| [VARIABLE_TYPES_SUMMARY.md](./VARIABLE_TYPES_SUMMARY.md) | 双语 Bilingual | 参考 Reference | 变量类型快速参考 |
| [SQL_VIEW_DYNAMIC_TEMPLATE.md](./SQL_VIEW_DYNAMIC_TEMPLATE.md) | 中文 Chinese | 详细 Detailed | 动态模板完整说明 |
| [SQL_VIEW_DYNAMIC_TEMPLATE_EN.md](./SQL_VIEW_DYNAMIC_TEMPLATE_EN.md) | English | Detailed | Dynamic template documentation |
| [FREEMARKER_TAGS_REFERENCE.md](./FREEMARKER_TAGS_REFERENCE.md) | 双语 Bilingual | 参考 Reference | FreeMarker标签快速参考 |

---

## 🤝 贡献 / Contributing

欢迎贡献改进文档！

Welcome to contribute and improve documentation!

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

---

## 📄 许可证 / License

Apache 2.0 License

---

**创建时间 / Created**: 2025-10-07  
**维护者 / Maintainer**: Datart Community
