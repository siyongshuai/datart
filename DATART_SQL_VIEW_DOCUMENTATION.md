# Datart SQL视图技术文档索引 / SQL View Documentation Index

本文档索引整合了Datart SQL视图的所有技术文档，包括变量类型、动态模板等核心功能说明。

This index integrates all technical documentation for Datart SQL views, including variable types, dynamic templates, and other core features.

---

## 📚 文档列表 / Document List

### 1. 变量类型文档 / Variable Types Documentation

#### 中文详细文档 / Chinese Documentation
📄 **[SQL_VIEW_VARIABLE_TYPES.md](./SQL_VIEW_VARIABLE_TYPES.md)**
- SQL视图支持的变量类型完整说明
- 前端和后端类型对照
- 变量替换规则详解
- 相关API和文件位置

#### English Documentation
📄 **[SQL_VIEW_VARIABLE_TYPES_EN.md](./SQL_VIEW_VARIABLE_TYPES_EN.md)**
- Complete description of variable types supported by SQL views
- Frontend and backend type comparison
- Variable replacement rules
- Related APIs and file locations

#### 快速参考 / Quick Reference
📄 **[VARIABLE_TYPES_SUMMARY.md](./VARIABLE_TYPES_SUMMARY.md)**
- 双语快速参考表格
- 关键文件位置速查
- Bilingual quick reference tables
- Key file locations

---

### 2. 动态模板文档 / Dynamic Template Documentation

#### 中文详细文档 / Chinese Documentation
📄 **[SQL_VIEW_DYNAMIC_TEMPLATE.md](./SQL_VIEW_DYNAMIC_TEMPLATE.md)**
- FreeMarker模板引擎技术详解
- 所有支持的标签列表
- 实用示例和最佳实践
- 配置和注意事项

#### English Documentation
📄 **[SQL_VIEW_DYNAMIC_TEMPLATE_EN.md](./SQL_VIEW_DYNAMIC_TEMPLATE_EN.md)**
- FreeMarker template engine technical details
- List of all supported tags
- Practical examples and best practices
- Configuration and important notes

#### 快速参考 / Quick Reference
📄 **[FREEMARKER_TAGS_REFERENCE.md](./FREEMARKER_TAGS_REFERENCE.md)**
- 双语标签快速参考
- 常用函数和运算符
- 实用代码片段
- Bilingual tags quick reference
- Common functions and operators
- Useful code snippets

---

## 🎯 核心技术栈 / Core Technology Stack

### 变量系统 / Variable System
- **前端类型 / Frontend Types**: STRING, NUMERIC, DATE, FRAGMENT
- **后端类型 / Backend Types**: STRING, NUMERIC, DATE, BOOLEAN, IDENTIFIER, FRAGMENT, SNIPPET, KEYWORD
- **变量格式 / Variable Format**: `$variableName$`

### 动态模板 / Dynamic Template
- **模板引擎 / Template Engine**: Apache FreeMarker 2.3.31
- **标签格式 / Tag Format**: `<#if>`, `<#list>`, `<#assign>`, etc.
- **依赖 / Dependency**: `spring-boot-starter-freemarker`

---

## 📖 快速入门 / Quick Start

### 1. 使用变量 / Using Variables

#### 定义变量 / Define Variables
在视图属性中创建变量，支持4种类型：
Create variables in view properties, supporting 4 types:

- **字符 / String** (STRING)
- **数值 / Number** (NUMERIC)  
- **日期 / Date** (DATE)
- **表达式 / Expression** (FRAGMENT)

#### 在SQL中使用 / Use in SQL
```sql
SELECT * FROM users
WHERE age > $age$
  AND name = $name$
  AND create_time > $startDate$
```

### 2. 使用动态模板 / Using Dynamic Templates

#### 条件判断 / Conditional Statement
```sql
SELECT * FROM orders
WHERE 1=1
<#if status??>
  AND status = '${status}'
</#if>
<#if userId??>
  AND user_id = ${userId}
</#if>
```

#### 循环遍历 / Loop Iteration
```sql
SELECT * FROM products
WHERE id IN (
<#list productIds as id>
  ${id}<#sep>,</#sep>
</#list>
)
```

#### 动态表名 / Dynamic Table Name
```sql
<#assign tableName = "sales_" + region?lower_case>
SELECT * FROM ${tableName}
WHERE year = ${year}
```

---

## 🔧 技术实现 / Technical Implementation

### 处理流程 / Processing Flow

```
1. SQL脚本(含FreeMarker标签和变量)
   SQL Script (with FreeMarker tags and variables)
        ↓
2. FreeMarker模板处理
   FreeMarker Template Processing
        ↓
3. 生成SQL(含变量占位符 $var$)
   Generated SQL (with variable placeholders)
        ↓
4. FRAGMENT类型变量替换
   FRAGMENT Variable Replacement
        ↓
5. SQL解析和优化
   SQL Parsing and Optimization
        ↓
6. 其他类型变量替换
   Other Variable Types Replacement
        ↓
7. 最终可执行SQL
   Final Executable SQL
```

### 核心文件 / Core Files

#### 变量处理 / Variable Processing
```
data-providers/data-provider-base/src/main/java/datart/data/provider/
├── script/
│   ├── VariablePlaceholder.java        # 变量占位符处理
│   └── SqlStringUtils.java             # SQL字符串工具
└── jdbc/
    └── SqlScriptRender.java            # SQL脚本渲染器
```

#### 模板处理 / Template Processing
```
data-providers/data-provider-base/src/main/java/datart/data/provider/
├── freemarker/
│   ├── FreemarkerContext.java          # FreeMarker上下文
│   └── StringTemplateLoader.java       # 字符串模板加载器
└── calcite/
    └── SqlQueryScriptProcessor.java    # SQL脚本处理器
```

#### 类型定义 / Type Definitions
```
core/src/main/java/datart/core/
├── base/consts/
│   └── ValueType.java                  # 值类型枚举
└── entity/
    └── Variable.java                   # 变量实体

frontend/src/app/pages/MainPage/pages/
└── VariablePage/
    ├── constants.ts                    # 前端类型常量
    └── slice/types.ts                  # 前端类型定义
```

---

## 💡 最佳实践 / Best Practices

### 1. 变量使用 / Variable Usage

#### ✅ 推荐 / Recommended
```sql
-- 使用变量占位符，系统自动处理类型和转义
-- Use variable placeholders, system handles type and escaping
SELECT * FROM users WHERE name = $userName$
```

#### ❌ 不推荐 / Not Recommended
```sql
-- FreeMarker直接插值，可能有SQL注入风险
-- Direct FreeMarker interpolation, may have SQL injection risk
SELECT * FROM users WHERE name = '${userName}'
```

### 2. 条件判断 / Conditional Statements

#### ✅ 推荐 / Recommended
```sql
-- 先检查变量是否存在
-- Check if variable exists first
<#if status??>
  AND status = '${status}'
</#if>

-- 或提供默认值
-- Or provide default value
AND status = '${status!"ACTIVE"}'
```

#### ❌ 不推荐 / Not Recommended
```sql
-- 不检查变量是否存在，可能报错
-- Not checking variable existence, may cause error
AND status = '${status}'
```

### 3. 列表处理 / List Processing

#### ✅ 推荐 / Recommended
```sql
-- 检查列表是否有内容
-- Check if list has content
<#if userIds?? && userIds?has_content>
  AND user_id IN (
  <#list userIds as id>
    ${id}<#sep>,</#sep>
  </#list>
  )
</#if>
```

### 4. 数据库兼容 / Database Compatibility

```sql
-- 注意不同数据库的语法差异
-- Mind syntax differences across databases

-- MySQL
<#if dbType == 'mysql'>
  LIMIT ${limit}
<#elseif dbType == 'oracle'>
  FETCH FIRST ${limit} ROWS ONLY
<#elseif dbType == 'sqlserver'>
  TOP ${limit}
</#if>
```

---

## ⚠️ 注意事项 / Important Notes

### 安全性 / Security
1. **SQL注入防护** / SQL Injection Protection
   - 优先使用变量占位符 `$var$` 而非 FreeMarker `${var}`
   - Prefer variable placeholders `$var$` over FreeMarker `${var}`

2. **输入验证** / Input Validation
   - 始终验证用户输入
   - Always validate user inputs

### 性能 / Performance
1. **模板缓存** / Template Caching
   - FreeMarker模板使用LRU缓存，最多1000个
   - FreeMarker templates use LRU cache, max 1000 templates

2. **复杂度控制** / Complexity Control
   - 避免过度复杂的嵌套模板
   - Avoid overly complex nested templates

### 兼容性 / Compatibility
1. **数据库差异** / Database Differences
   - 注意不同数据库的SQL语法差异
   - Mind SQL syntax differences across databases

2. **版本兼容** / Version Compatibility
   - FreeMarker 2.3.31特性支持
   - FreeMarker 2.3.31 features support

---

## 🔗 相关链接 / Related Links

### 官方文档 / Official Documentation
- **Datart官方文档**: http://running-elephant.gitee.io/datart-docs/
- **FreeMarker官方文档**: https://freemarker.apache.org/docs/
- **FreeMarker指令参考**: https://freemarker.apache.org/docs/ref_directive_alphaidx.html
- **FreeMarker内置函数**: https://freemarker.apache.org/docs/ref_builtins.html

### 代码仓库 / Code Repository
- **Datart GitHub**: https://github.com/running-elephant/datart
- **Datart Gitee**: https://gitee.com/running-elephant/datart

### 社区支持 / Community Support
- **Issue讨论**: https://gitee.com/running-elephant/datart/issues
- **插件示例**: https://gitee.com/running-elephant/datart-extension-charts

---

## 📝 文档更新记录 / Update History

| 日期 Date | 版本 Version | 更新内容 Updates |
|-----------|--------------|------------------|
| 2025-10-07 | 1.0.0 | 初始版本，包含变量类型和动态模板完整文档 / Initial version with complete variable types and dynamic template documentation |

---

## 📞 获取帮助 / Get Help

### 问题反馈 / Report Issues
- 创建Issue: https://gitee.com/running-elephant/datart/issues

### 社区讨论 / Community Discussion
- 加入微信群参与讨论
- Join WeChat group for discussions

### 贡献文档 / Contribute
- 欢迎提交PR改进文档
- Welcome to submit PRs to improve documentation

---

## 📄 许可证 / License

本文档遵循 Apache 2.0 许可证
This documentation follows Apache 2.0 License

---

**最后更新 / Last Updated**: 2025-10-07

**维护者 / Maintainer**: Datart Community
