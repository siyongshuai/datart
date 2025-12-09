# Datart SQL 视图模板引擎机制

本文档详细介绍 Datart SQL 视图的模板引擎机制，包括 FreeMarker 模板处理和 Datart 变量替换的完整处理流程，以及相应的代码依据。

---

## 目录

- [1. 机制概述](#1-机制概述)
- [2. 架构设计](#2-架构设计)
- [3. 处理流程详解](#3-处理流程详解)
- [4. 核心代码依据](#4-核心代码依据)
- [5. 两种机制的本质区别](#5-两种机制的本质区别)
- [6. 设计哲学](#6-设计哲学)
- [7. 源码文件索引](#7-源码文件索引)

---

## 1. 机制概述

### 1.1 核心定义

**SQL 视图 = FreeMarker 模板 + Datart 变量绑定 → SQL 文本生成器**

SQL 视图本质上不是一个合法的 SQL 语句，而是一个**文本模板**，混合了三种语法：
- SQL 语法
- FreeMarker 模板语法（`<#if>`, `<#list>`, `${}` 等）
- Datart 变量占位符（`$variableName$`）

### 1.2 核心结论

1. **Datart 是 SQL 文本的装配工厂**，不是 SQL 语法检查器
2. **最终输出是纯文本**，可能是合法 SQL，也可能不是
3. **SQL 正确性验证是数据库引擎的职责**，不是 Datart 的职责

---

## 2. 架构设计

### 2.1 分层架构

```
┌─────────────────────────────────────────────────────────────┐
│                    第一层：模板定义层                         │
│  SQL 视图模板（混合 SQL + FreeMarker + Datart 变量）          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    第二层：数据绑定层                         │
│  将用户输入、控制器值、权限数据转换为模板变量                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    第三层：FreeMarker 渲染层                  │
│  处理 <#if>、<#list>、${} 等标签，生成中间 SQL                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    第四层：变量替换层                         │
│  处理 $var$ 占位符，进行类型转换和 SQL 优化                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    第五层：SQL 执行层                         │
│  数据库引擎解析并执行 SQL，验证语法正确性                      │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 处理流程图

```
SQL 模板                     数据模型
    │                           │
    └───────────┬───────────────┘
                │
                ▼
    ┌───────────────────────┐
    │   FreeMarker 引擎      │  ← 第一阶段：模板渲染
    │   (文本模板处理器)      │
    └───────────┬───────────┘
                │
                ▼
         中间 SQL 文本
      (仍包含 $var$ 占位符)
                │
                ▼
    ┌───────────────────────┐
    │   FRAGMENT 变量替换    │  ← 第二阶段：表达式替换
    └───────────┬───────────┘
                │
                ▼
    ┌───────────────────────┐
    │   SQL 解析器           │  ← 第三阶段：SQL 解析
    │   (Calcite/Regex)     │
    └───────────┬───────────┘
                │
                ▼
    ┌───────────────────────┐
    │   变量占位符替换        │  ← 第四阶段：值替换
    │   (类型转换+SQL优化)   │
    └───────────┬───────────┘
                │
                ▼
          最终 SQL 文本
                │
                ▼
    ┌───────────────────────┐
    │   数据库引擎           │  ← 执行阶段
    │   (MySQL/PG/Oracle)   │
    └───────────────────────┘
```

---

## 3. 处理流程详解

### 3.1 阶段一：FreeMarker 模板渲染

**入口文件**: `SqlQueryScriptProcessor.java`

**处理逻辑**:
1. 将变量转换为 FreeMarker 数据模型
2. 调用 FreeMarker 引擎处理模板标签
3. 输出中间 SQL（仍包含 `$var$` 占位符）

**代码依据**:

```java
// 文件: data-providers/data-provider-base/src/main/java/datart/data/provider/calcite/SqlQueryScriptProcessor.java
// 行号: 59-71

//用freemarker处理脚本中的条件表达式
Map<String, ?> dataMap = queryScript.getVariables()
        .stream()
        .collect(Collectors.toMap(ScriptVariable::getName,
                variable -> {
                    if (CollectionUtils.isEmpty(variable.getValues())) {
                        return "";                              // 空值 → 空字符串
                    } else if (variable.getValues().size() == 1) {
                        return variable.getValues().iterator().next();  // 单值 → 字符串
                    } else return variable.getValues();         // 多值 → 集合
                }));

script = FreemarkerContext.process(queryScript.getScript(), dataMap);
```

**FreeMarker 上下文配置**:

```java
// 文件: data-providers/data-provider-base/src/main/java/datart/data/provider/freemarker/FreemarkerContext.java
// 行号: 29-53

public class FreemarkerContext {

    private static final Configuration conf;

    static {
        conf = new Configuration(Configuration.VERSION_2_3_31);
        //模板从字符串加载
        conf.setTemplateLoader(new StringTemplateLoader());
        // 使freemarker支持 null 值
        conf.setClassicCompatible(true);
    }

    public static String process(String content, Map<String, ?> dataModel) {
        String key = DigestUtils.md5DigestAsHex(content.getBytes());
        try {
            StringTemplateLoader.SCRIPT_MAP.put(key, content);
            Template template = conf.getTemplate(key);
            StringWriter writer = new StringWriter();
            template.process(dataModel, writer);
            return writer.toString();
        } catch (Exception e) {
            log.error("freemarker parse error", e);
        }
        return content;
    }
}
```

**模板缓存机制**:

```java
// 文件: data-providers/data-provider-base/src/main/java/datart/data/provider/freemarker/StringTemplateLoader.java
// 行号: 29-52

public class StringTemplateLoader implements TemplateLoader {

    // LRU缓存，最多存储1000个模板
    public static final Map<String, String> SCRIPT_MAP = Collections.synchronizedMap(new LRUMap<>(1000));

    @Override
    public Object findTemplateSource(String name) throws IOException {
        return SCRIPT_MAP.get(name);
    }

    @Override
    public Reader getReader(Object templateSource, String encoding) throws IOException {
        return new StringReader(templateSource.toString());
    }
}
```

### 3.2 阶段二：FRAGMENT 变量替换

**处理逻辑**: 替换表达式类型（FRAGMENT）的变量，直接文本替换

**代码依据**:

```java
// 文件: data-providers/data-provider-base/src/main/java/datart/data/provider/script/SqlStringUtils.java
// 行号: 60-74

/**
 * 替换脚本中的表达式类型变量
 */
public static String replaceFragmentVariables(String sql, List<ScriptVariable> variables) {
    if (CollectionUtils.isEmpty(variables)) {
        return sql;
    }
    for (ScriptVariable variable : variables) {
        if (ValueType.FRAGMENT.equals(variable.getValueType())) {
            int size = Iterables.size(variable.getValues());
            if (size != 1) {
                Exceptions.tr(DataProviderException.class, 
                    "message.provider.variable.expression.size", size + ":" + variable.getValues());
            }
            sql = sql.replace(variable.getNameWithQuote(), Iterables.get(variable.getValues(), 0));
        }
    }
    return sql;
}
```

### 3.3 阶段三：SQL 解析与变量定位

**处理逻辑**: 
1. 首先尝试使用 Calcite SQL 解析器定位变量
2. 解析失败则回退到正则表达式匹配

**代码依据**:

```java
// 文件: data-providers/data-provider-base/src/main/java/datart/data/provider/jdbc/SqlScriptRender.java
// 行号: 127-166

public String replaceVariables(String selectSql) throws SqlParseException {

    if (StringUtils.isBlank(selectSql)
            || CollectionUtils.isEmpty(queryScript.getVariables())
            || !containsVariable(selectSql)) {
        return selectSql;
    }

    Map<String, ScriptVariable> variableMap = new CaseInsensitiveMap<>();
    for (ScriptVariable variable : queryScript.getVariables()) {
        variableMap.put(variable.getNameWithQuote(), variable);
    }

    List<VariablePlaceholder> placeholders = null;
    try {
        // 优先使用 SQL 解析器
        placeholders = SqlParserVariableResolver.resolve(sqlDialect, selectSql, variableMap);
    } catch (Exception e) {
        // 解析失败，回退到正则匹配
        SqlParseError sqlParseError = new SqlParseError(e);
        sqlParseError.setSql(selectSql);
        RequestContext.putWarning(MessageResolver.getMessage("message.provider.sql.parse.failed"), sqlParseError);
        placeholders = RegexVariableResolver.resolve(sqlDialect, selectSql, variableMap);
    }

    // 按优先级排序占位符
    placeholders = placeholders.stream()
            .sorted(Comparator.comparingDouble(holder -> 
                (holder instanceof SimpleVariablePlaceholder) 
                    ? 1000 + holder.getOriginalSqlFragment().length() 
                    : -holder.getOriginalSqlFragment().length()))
            .collect(Collectors.toList());

    // 执行替换
    for (VariablePlaceholder placeholder : placeholders) {
        ReplacementPair replacementPair = placeholder.replacementPair();
        selectSql = StringUtils.replaceIgnoreCase(selectSql, 
            replacementPair.getPattern(), replacementPair.getReplacement());
    }

    return selectSql;
}
```

**Calcite SQL 解析器方式**:

```java
// 文件: data-providers/data-provider-base/src/main/java/datart/data/provider/jdbc/SqlParserVariableResolver.java
// 行号: 38-50

public class SqlParserVariableResolver {

    public static List<VariablePlaceholder> resolve(SqlDialect sqlDialect, String srcSql, 
            Map<String, ScriptVariable> variableMap) throws SqlParseException {
        if (StringUtils.isBlank(srcSql) || CollectionUtils.isEmpty(variableMap)) {
            return Collections.emptyList();
        }
        // 使用 Calcite 解析 SQL
        SqlNode sqlNode = SqlParserUtils.createParser(srcSql, sqlDialect).parseQuery();
        // 访问者模式遍历 SQL 节点，定位变量
        SqlVariableVisitor visitor = new SqlVariableVisitor(sqlDialect, srcSql, 
            Const.DEFAULT_VARIABLE_QUOTE, variableMap);
        sqlNode.accept(visitor);
        return visitor.getVariablePlaceholders();
    }
}
```

**正则表达式回退方式**:

```java
// 文件: data-providers/data-provider-base/src/main/java/datart/data/provider/jdbc/RegexVariableResolver.java
// 行号: 36-66

public class RegexVariableResolver {

    // 匹配变量表达式的正则模板
    public static final String REG_VARIABLE_EXPRESSION_TEMPLATE = 
        "\\S+\\s*(IN|NOT\\s+IN|IS\\s+NULL|NOT\\s+NULL|LIKE|NOT\\s+LIKE|EXISTS|>|<|=|!=|<>|>=|<=){1}\\s*\\S*\\({0,1}(%s){1}\\){0,1}";

    public static List<VariablePlaceholder> resolve(SqlDialect sqlDialect, String srcSql, 
            Map<String, ScriptVariable> variableMap) {

        if (StringUtils.isBlank(srcSql) || CollectionUtils.isEmpty(variableMap)) {
            return Collections.emptyList();
        }

        // 使用正则匹配所有变量
        Matcher matcher = Const.VARIABLE_PATTERN.matcher(srcSql);
        Map<String, ScriptVariable> variablePlaceholderMap = new HashMap<>();
        while (matcher.find()) {
            String group = matcher.group();
            ScriptVariable scriptVariable = variableMap.get(group);
            if (scriptVariable != null) {
                variablePlaceholderMap.put(group, scriptVariable);
            }
        }

        List<VariablePlaceholder> placeholders = new LinkedList<>();
        for (Map.Entry<String, ScriptVariable> entry : variablePlaceholderMap.entrySet()) {
            placeholders.addAll(createPlaceholder(sqlDialect, srcSql, entry.getKey(), entry.getValue()));
        }
        return placeholders;
    }
}
```

### 3.4 阶段四：变量值替换与 SQL 优化

**处理逻辑**: 
1. 根据变量类型进行值转换
2. 根据值的个数进行 SQL 运算符优化

**代码依据**:

```java
// 文件: data-providers/data-provider-base/src/main/java/datart/data/provider/script/VariablePlaceholder.java
// 行号: 36-45

public ReplacementPair replacementPair() {

    if (CollectionUtils.isEmpty(variables)) {
        return replacePermissionVariable(variables);
    }

    // 根据变量类型选择替换策略
    return variables.stream().allMatch(variable -> 
            VariableTypeEnum.PERMISSION.equals(variable.getType())) 
        ? replacePermissionVariable(variables)
        : replaceQueryVariable(variables);
}
```

**查询变量替换规则**:

```java
// 文件: data-providers/data-provider-base/src/main/java/datart/data/provider/script/VariablePlaceholder.java
// 行号: 251-278

/**
 * 查询变量替换规则：
 * 1、变量不存在或者变量值为空，直接返回
 * 2、一个表达式中有多个不同变量，直接替换
 * 3、一个表达式中只有一个变量，且表达式是一个布尔表达式，根据值的个数进行优化
 * 4、其它情况，直接替换
 */
private ReplacementPair replaceQueryVariable(List<ScriptVariable> variables) {
    if (CollectionUtils.isEmpty(variables)) {
        return new ReplacementPair(originalSqlFragment, originalSqlFragment);
    }
    try {
        if (variables.size() > 1) {
            for (ScriptVariable variable : variables) {
                replaceVariable(sqlCall, variable);
            }
            return new ReplacementPair(originalSqlFragment, SqlNodeUtils.toSql(sqlCall, sqlDialect, false));
        }
        ScriptVariable variable = variables.get(0);
        if (CollectionUtils.isEmpty(variable.getValues())) {
            log.warn("The query variable [" + variable.getName() + "] do not have default values");
            SqlCall isNullSqlCall = createIsNullSqlCall(sqlCall.getOperandList().get(0));
            return new ReplacementPair(originalSqlFragment, SqlNodeUtils.toSql(isNullSqlCall, sqlDialect, false));
        }
        // 多值且是逻辑表达式时，进行 SQL 优化
        if (variable.getValues().size() > 1 && SqlValidateUtils.isLogicExpressionSqlCall(sqlCall)) {
            SqlCall fixedCall = autoFixSqlCall(variable);
            return new ReplacementPair(originalSqlFragment, SqlNodeUtils.toSql(fixedCall, sqlDialect, false));
        } else {
            replaceVariable(sqlCall, variable);
            return new ReplacementPair(originalSqlFragment, SqlNodeUtils.toSql(sqlCall, sqlDialect, false));
        }
    } catch (ParamReplaceException e) {
        return replaceAsSting();
    }
}
```

**多值时的运算符自动优化**:

```java
// 文件: data-providers/data-provider-base/src/main/java/datart/data/provider/script/VariablePlaceholder.java
// 行号: 55-113

protected SqlCall autoFixSqlCall(ScriptVariable variable) throws ParamReplaceException {
    SqlOperator sqlOperator = sqlCall.getOperator();
    List<SqlNode> operandList = new ArrayList<>();
    SqlKind kind = sqlCall.getOperator().kind;

    switch (kind) {
        case GREATER_THAN:
        case GREATER_THAN_OR_EQUAL:
            // > 或 >= 取最小值
            reduceVariableToMin(variable);
            replaceVariable(sqlCall, variable);
            operandList.addAll(sqlCall.getOperandList());
            break;
        case LESS_THAN:
        case LESS_THAN_OR_EQUAL:
            // < 或 <= 取最大值
            reduceVariableToMax(variable);
            replaceVariable(sqlCall, variable);
            operandList.addAll(sqlCall.getOperandList());
            break;
        case EQUALS:
            // = 转换为 IN
            sqlOperator = SqlStdOperatorTable.IN;
            replaceVariable(sqlCall, variable);
            operandList.addAll(sqlCall.getOperandList());
            break;
        case NOT_EQUALS:
            // != 转换为 NOT IN
            sqlOperator = SqlStdOperatorTable.NOT_IN;
            replaceVariable(sqlCall, variable);
            operandList.addAll(sqlCall.getOperandList());
            break;
        case LIKE:
            // LIKE 转换为多个 LIKE 用 OR/AND 连接
            SqlLikeOperator likeOperator = (SqlLikeOperator) sqlCall.getOperator();
            if (likeOperator.isNegated()) {
                sqlOperator = SqlStdOperatorTable.AND;
                operandList = variable.getValues().stream().map(val -> {
                    ArrayList<SqlNode> operands = new ArrayList<>();
                    operands.add(sqlCall.getOperandList().get(0));
                    operands.add(new SqlSimpleStringLiteral(val));
                    return SqlNodeUtils.createSqlBasicCall(SqlStdOperatorTable.NOT_LIKE, operands);
                }).collect(Collectors.toList());
            } else {
                sqlOperator = SqlStdOperatorTable.OR;
                operandList = variable.getValues().stream().map(val -> {
                    ArrayList<SqlNode> operands = new ArrayList<>();
                    operands.add(sqlCall.getOperandList().get(0));
                    operands.add(new SqlSimpleStringLiteral(val));
                    return SqlNodeUtils.createSqlBasicCall(SqlStdOperatorTable.LIKE, operands);
                }).collect(Collectors.toList());
            }
            break;
        default:
            replaceVariable(sqlCall, variable);
            operandList.addAll(sqlCall.getOperandList());
            break;
    }
    return SqlNodeUtils.createSqlBasicCall(sqlOperator, operandList);
}
```

### 3.5 阶段五：SQL 执行

**处理逻辑**: 将最终 SQL 文本提交到数据库执行

**代码依据**:

```java
// 文件: data-providers/jdbc-data-provider/src/main/java/datart/data/provider/jdbc/adapters/JdbcDataProviderAdapter.java
// 行号: 449-477

/**
 * 在数据源执行，组装完整SQL，提交至数据源执行
 */
public Dataframe executeOnSource(QueryScript script, ExecuteParam executeParam) throws Exception {

    Dataframe dataframe;
    String sql;

    // 创建渲染器
    SqlScriptRender render = new SqlScriptRender(script
            , executeParam
            , getSqlDialect()
            , jdbcProperties.isEnableSpecialSql()
            , driverInfo.getQuoteIdentifiers());

    if (supportPaging()) {
        sql = render.render(true, true, false);
        log.debug(sql);
        dataframe = execute(sql);  // 执行 SQL
    } else {
        sql = render.render(true, false, false);
        log.debug(sql);
        dataframe = execute(sql, executeParam.getPageInfo());
    }

    dataframe.setScript(sql);
    return dataframe;
}
```

---

## 4. 核心代码依据

### 4.1 变量定义常量

```java
// 文件: core/src/main/java/datart/core/base/consts/Const.java
// 行号: 49-57

/**
 * 脚本变量
 */
//默认的变量引用符号
public static final String DEFAULT_VARIABLE_QUOTE = "$";

//变量匹配符
public static final Pattern VARIABLE_PATTERN = Pattern.compile("\\$\\S+\\$");

//变量正则模板
public static final String VARIABLE_PATTERN_TEMPLATE = "\\$%s\\$";
```

### 4.2 渲染入口

```java
// 文件: data-providers/data-provider-base/src/main/java/datart/data/provider/jdbc/SqlScriptRender.java
// 行号: 79-112

public String render(boolean withExecuteParam, boolean withPage, boolean onlySelectStatement) 
        throws SqlParseException {
    
    // 步骤1: 调用脚本处理器（包含 FreeMarker 渲染）
    QueryScriptProcessResult result = getScriptProcessor().process(queryScript);
    
    String selectSql;
    
    // 步骤2: 构建 SQL（添加 GROUP BY、ORDER BY 等）
    if (withExecuteParam) {
        selectSql = SqlBuilder.builder()
                .withExecuteParam(executeParam)
                .withDialect(sqlDialect)
                .withQueryScriptProcessResult(result)
                .withAddDefaultNamePrefix(result.isWithDefaultPrefix())
                .withDefaultNamePrefix(result.getTablePrefix())
                .withPage(withPage)
                .withQuoteIdentifiers(quoteIdentifiers)
                .build();
    } else {
        selectSql = SqlBuilder.builder()
                .withDialect(sqlDialect)
                .withQueryScriptProcessResult(result)
                .build();
    }
    
    // 步骤3: 替换 FRAGMENT 类型变量
    selectSql = SqlStringUtils.replaceFragmentVariables(selectSql, queryScript.getVariables());
    
    // 步骤4: 清理 SQL
    selectSql = SqlStringUtils.cleanupSql(selectSql);
    
    // 步骤5: 替换其他类型变量
    selectSql = replaceVariables(selectSql);
    
    // 步骤6: 存储最终 SQL 到上下文
    RequestContext.setSql(selectSql);

    return selectSql;
}
```

### 4.3 变量类型值转换

```java
// 文件: data-providers/data-provider-base/src/main/java/datart/data/provider/calcite/SqlNodeUtils.java
// 行号: 83-108

public static List<SqlNode> createSqlNodes(ScriptVariable variable, SqlParserPos sqlParserPos) {
    if (CollectionUtils.isEmpty(variable.getValues())) {
        return Collections.singletonList(SqlLiteral.createNull(sqlParserPos));
    }
    switch (variable.getValueType()) {
        case STRING:
            return variable.getValues().stream()
                    .map(SqlSimpleStringLiteral::new)
                    .collect(Collectors.toList());
        case NUMERIC:
            return variable.getValues().stream()
                    .map(v -> SqlLiteral.createExactNumeric(v, sqlParserPos))
                    .collect(Collectors.toList());
        case BOOLEAN:
            return variable.getValues().stream()
                    .map(v -> SqlLiteral.createBoolean(Boolean.parseBoolean(v), sqlParserPos))
                    .collect(Collectors.toList());
        case DATE:
            return variable.getValues().stream()
                    .map(v -> createDateSqlNode(v, variable.getFormat()))
                    .collect(Collectors.toList());
        case FRAGMENT:
            return variable.getValues().stream()
                    .map(SqlFragment::new)
                    .collect(Collectors.toList());
        default:
            Exceptions.msg("error data type " + variable.getValueType());
    }
    return null;
}
```

---

## 5. 两种机制的本质区别

### 5.1 FreeMarker：通用文本模板引擎

| 特性 | 说明 |
|------|------|
| **本质** | 通用文本模板引擎，不理解 SQL 语义 |
| **能力** | 条件判断、循环遍历、宏定义、函数调用 |
| **输出** | 任意文本（SQL、HTML、JSON 等） |
| **安全性** | 无 SQL 注入防护，直接文本替换 |
| **执行时机** | 第一阶段处理 |
| **变量类型** | 单值=字符串，多值=集合 |

**代码依据**:

```java
// FreeMarker 不区分变量类型，统一转为 Map
Map<String, ?> dataMap = queryScript.getVariables()
    .stream()
    .collect(Collectors.toMap(ScriptVariable::getName,
        variable -> {
            if (CollectionUtils.isEmpty(variable.getValues())) {
                return "";              // 空 → 空字符串
            } else if (variable.getValues().size() == 1) {
                return variable.getValues().iterator().next();  // 单值 → 字符串
            } else return variable.getValues();  // 多值 → 集合
        }));
```

### 5.2 Datart 变量：SQL 感知的智能替换器

| 特性 | 说明 |
|------|------|
| **本质** | SQL 感知的变量替换器 |
| **能力** | 类型转换、运算符优化、SQL 注入防护 |
| **输出** | 合法的 SQL 片段 |
| **安全性** | 自动转义特殊字符，防止 SQL 注入 |
| **执行时机** | 第二阶段处理（FreeMarker 之后） |
| **变量类型** | 严格区分 STRING/NUMERIC/DATE/FRAGMENT |

**代码依据**:

```java
// Datart 变量根据类型生成不同的 SQL 节点
switch (variable.getValueType()) {
    case STRING:
        // 字符串类型：自动添加引号和转义
        return variable.getValues().stream()
            .map(SqlSimpleStringLiteral::new)
            .collect(Collectors.toList());
    case NUMERIC:
        // 数值类型：不添加引号
        return variable.getValues().stream()
            .map(v -> SqlLiteral.createExactNumeric(v, sqlParserPos))
            .collect(Collectors.toList());
    // ...
}
```

### 5.3 对比示例

**输入模板**:
```sql
SELECT * FROM users WHERE name = '${userName}' AND age > $age$
```

**处理过程**:

| 阶段 | 处理器 | 处理内容 | 输出 |
|------|--------|---------|------|
| 1 | FreeMarker | `${userName}` | `SELECT * FROM users WHERE name = 'John' AND age > $age$` |
| 2 | Datart | `$age$` | `SELECT * FROM users WHERE name = 'John' AND age > 25` |

**关键区别**:
- `${userName}` 由 FreeMarker 直接替换，**无类型处理**
- `$age$` 由 Datart 替换，**根据类型生成正确的 SQL 字面量**

---

## 6. 设计哲学

### 6.1 核心理念

```
"Datart 是一个 SQL 文本的装配工厂，
  不是 SQL 的语法检查器，
  更不是 SQL 的执行者。"
```

### 6.2 职责划分

| 组件 | 职责 | 不负责 |
|------|------|--------|
| **FreeMarker** | 处理模板逻辑 | 不理解 SQL 语义 |
| **Datart 变量** | 安全的值替换 | 不验证 SQL 语法 |
| **SqlBuilder** | 构建查询结构 | 不执行 SQL |
| **数据库引擎** | 执行 SQL | 不处理模板 |

### 6.3 设计优势

1. **最大灵活性**: 可以生成任意数据库的任意查询
2. **关注点分离**: 模板、数据、执行各司其职
3. **可扩展性**: 支持新数据库只需实现方言适配器

### 6.4 设计代价

1. **责任转移**: SQL 正确性由模板作者保证
2. **错误延迟**: 语法错误在执行时才发现
3. **调试困难**: 需要查看最终生成的 SQL

---

## 7. 源码文件索引

### 7.1 FreeMarker 相关

| 文件 | 作用 |
|------|------|
| `data-providers/.../freemarker/FreemarkerContext.java` | FreeMarker 配置和处理入口 |
| `data-providers/.../freemarker/StringTemplateLoader.java` | 字符串模板加载器（LRU缓存） |
| `data-providers/.../calcite/SqlQueryScriptProcessor.java` | 调用 FreeMarker 处理脚本 |

### 7.2 变量替换相关

| 文件 | 作用 |
|------|------|
| `core/.../consts/Const.java` | 变量匹配正则定义 |
| `core/.../provider/ScriptVariable.java` | 变量数据结构 |
| `data-providers/.../script/VariablePlaceholder.java` | 变量占位符处理核心逻辑 |
| `data-providers/.../script/SqlStringUtils.java` | SQL 字符串处理工具 |
| `data-providers/.../calcite/SqlNodeUtils.java` | SQL 节点生成工具 |

### 7.3 SQL 解析相关

| 文件 | 作用 |
|------|------|
| `data-providers/.../jdbc/SqlParserVariableResolver.java` | Calcite SQL 解析方式定位变量 |
| `data-providers/.../jdbc/RegexVariableResolver.java` | 正则表达式方式定位变量 |
| `data-providers/.../jdbc/SqlScriptRender.java` | SQL 脚本渲染器（总入口） |

### 7.4 执行相关

| 文件 | 作用 |
|------|------|
| `data-providers/.../jdbc/adapters/JdbcDataProviderAdapter.java` | JDBC 数据提供者适配器 |
| `data-providers/.../calcite/SqlBuilder.java` | SQL 构建器（添加 GROUP BY 等） |

---

## 附录：完整处理流程代码调用链

```
JdbcDataProviderAdapter.executeOnSource()
    │
    ├─→ new SqlScriptRender(script, executeParam, sqlDialect)
    │
    └─→ render.render(true, true, false)
            │
            ├─→ getScriptProcessor().process(queryScript)
            │       │
            │       └─→ SqlQueryScriptProcessor.process()
            │               │
            │               ├─→ 构建 dataMap（变量 → FreeMarker数据模型）
            │               │
            │               └─→ FreemarkerContext.process(script, dataMap)
            │                       │
            │                       ├─→ Template.process(dataModel, writer)
            │                       │
            │                       └─→ 返回中间SQL（含 $var$）
            │
            ├─→ SqlBuilder.build()（添加 GROUP BY、ORDER BY 等）
            │
            ├─→ SqlStringUtils.replaceFragmentVariables()（替换 FRAGMENT 变量）
            │
            ├─→ SqlStringUtils.cleanupSql()（清理 SQL）
            │
            └─→ replaceVariables(selectSql)
                    │
                    ├─→ SqlParserVariableResolver.resolve()（Calcite 解析）
                    │       │
                    │       └─→ 失败则 RegexVariableResolver.resolve()（正则匹配）
                    │
                    └─→ placeholder.replacementPair()
                            │
                            ├─→ replaceQueryVariable() 或 replacePermissionVariable()
                            │       │
                            │       └─→ autoFixSqlCall()（多值时的运算符优化）
                            │
                            └─→ 返回最终SQL
```

---

**文档版本**: 1.0  
**最后更新**: 2025-12-09  
**适用版本**: Datart 1.x
