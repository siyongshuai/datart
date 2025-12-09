# Datart 多选下拉框变量机制详解

本文档详细介绍 Datart 中多选下拉框控件如何控制变量，以及变量值如何传递到 SQL 视图中进行处理。

---

## 目录

- [1. 概述](#1-概述)
- [2. 数据结构](#2-数据结构)
- [3. 前端传递机制](#3-前端传递机制)
- [4. 后端处理机制](#4-后端处理机制)
- [5. SQL 替换规则](#5-sql-替换规则)
- [6. FreeMarker 中的变量表现](#6-freemarker-中的变量表现)
- [7. 实际示例](#7-实际示例)
- [8. 核心源码位置](#8-核心源码位置)

---

## 1. 概述

### 核心结论

**无论多选下拉框选了一个值还是多个值，传递到 SQL 视图的变量始终是一个集合（Set）**。系统会根据集合中值的个数智能处理 SQL 语句。

### 处理流程

```
用户选择下拉框值
       ↓
前端收集 controllerValues 数组
       ↓
转换为 { value, valueType } 格式
       ↓
通过 API 传递 params 参数
       ↓
后端解析为 ScriptVariable.values (Set<String>)
       ↓
根据值的个数进行 SQL 替换
       ↓
生成最终可执行 SQL
```

---

## 2. 数据结构

### 2.1 后端变量结构

```java
// 文件: core/src/main/java/datart/core/data/provider/ScriptVariable.java

public class ScriptVariable extends TypedValue {
    
    private String name;                    // 变量名称
    
    private VariableTypeEnum type;          // 变量类型: QUERY / PERMISSION
    
    private Set<String> values;             // 变量值集合（关键！）
    
    private ValueType valueType;            // 值类型: STRING / NUMERIC / DATE / FRAGMENT
    
    private boolean expression;             // 是否为表达式
    
    private boolean disabled;               // 是否禁用
    
    private String format;                  // 格式（日期格式等）
}
```

**关键点**：`values` 字段是 `Set<String>` 类型，天然支持 0 个、1 个或多个值。

### 2.2 前端请求结构

```typescript
// 文件: frontend/src/app/types/ChartDataRequest.ts

export type ChartDataRequest = {
  viewId: string;
  // ...
  params?: Record<string, string[]>;  // 变量参数：变量名 -> 值数组
  // ...
};
```

---

## 3. 前端传递机制

### 3.1 控制器值收集

```typescript
// 文件: frontend/src/app/pages/DashBoardPage/utils/index.ts

export const getWidgetControlValues = (opt: {
  type: ControllerFacadeTypes;
  relatedViewItem: RelatedView;
  config: ControllerConfig;
}): false | { value: any; valueType: string }[] => {
  
  const { type, relatedViewItem, config } = opt;
  const valueType = relatedViewItem.fieldValueType;

  // 非日期类型控制器
  if (!config?.controllerValues?.[0]) {
    return false;
  }

  // 将 controllerValues 数组转换为 {value, valueType} 格式
  const values = config.controllerValues
    .filter(ele => {
      if (typeof ele === 'number') return true;
      if (typeof ele === 'string' && ele.trim() !== '') return true;
      return false;
    })
    .map(ele => ({
      value: typeof ele === 'string' ? ele.trim() : ele,
      valueType: valueType || 'STRING',
    }));
    
  return values[0] ? values : false;
};
```

### 3.2 变量参数组装

```typescript
// 文件: frontend/src/app/pages/DashBoardPage/utils/index.ts

// 关联变量逻辑
if (relatedViewItem.relatedCategory === ChartDataViewFieldCategory.Variable) {
  // 所有选中的值都会传递，不限制为1个
  const curValues = values.map(item => String(item.value));
  
  if (Array.isArray(relatedViewItem.fieldValue)) {
    // range类型：关联两个变量
    variableParams[key1] = [curValues?.[0]];
    variableParams[key2] = [curValues?.[1]];
  } else {
    // 单个变量：取值逻辑不限制为1个
    variableParams[key] = curValues;  // 传递所有选中的值
  }
}
```

---

## 4. 后端处理机制

### 4.1 变量值设置

```java
// 文件: server/src/main/java/datart/server/service/impl/DataProviderServiceImpl.java

private List<ScriptVariable> parseVariables(View view, ViewExecuteParam param) {
    List<ScriptVariable> variables = new LinkedList<>();
    variables.addAll(getOrgVariables(view.getOrgId()));
    variables.addAll(getViewVariables(view.getId()));
    
    variables.stream()
        .filter(v -> v.getType().equals(VariableTypeEnum.QUERY))
        .forEach(v -> {
            // 通过参数传值，进行参数替换
            if (!CollectionUtils.isEmpty(param.getParams()) 
                && param.getParams().containsKey(v.getName())) {
                // 将前端传来的值数组设置到变量的 values 集合中
                v.setValues(param.getParams().get(v.getName()));
            } else {
                // 没有参数传值，使用默认值逻辑
                if (v.isExpression()) {
                    v.setValueType(ValueType.FRAGMENT);
                }
            }
        });
    return variables;
}
```

### 4.2 变量值转换为 SQL 节点

```java
// 文件: data-providers/data-provider-base/src/main/java/datart/data/provider/calcite/SqlNodeUtils.java

public static List<SqlNode> createSqlNodes(ScriptVariable variable, SqlParserPos sqlParserPos) {
    if (CollectionUtils.isEmpty(variable.getValues())) {
        return Collections.singletonList(SqlLiteral.createNull(sqlParserPos));
    }
    
    switch (variable.getValueType()) {
        case STRING:
            // 每个值转换为字符串字面量
            return variable.getValues().stream()
                .map(SqlSimpleStringLiteral::new)
                .collect(Collectors.toList());
        case NUMERIC:
            return variable.getValues().stream()
                .map(v -> SqlLiteral.createExactNumeric(v, sqlParserPos))
                .collect(Collectors.toList());
        case DATE:
            return variable.getValues().stream()
                .map(v -> createDateSqlNode(v, variable.getFormat()))
                .collect(Collectors.toList());
        // ...
    }
}

public static SqlNode toSingleSqlLiteral(ScriptVariable variable, SqlParserPos sqlParserPos) {
    List<SqlNode> sqlLiterals = createSqlNodes(variable, sqlParserPos);
    if (sqlLiterals.size() == 1) {
        return sqlLiterals.get(0);           // 单值：返回单个节点
    } else {
        return new SqlNodeList(sqlLiterals, sqlParserPos);  // 多值：返回节点列表
    }
}
```

---

## 5. SQL 替换规则

### 5.1 替换规则总览

```java
// 文件: data-providers/data-provider-base/src/main/java/datart/data/provider/script/VariablePlaceholder.java
```

#### 权限变量（PERMISSION）替换规则

| 情况 | 处理方式 |
|------|---------|
| 变量不存在 | 替换整个表达式为 `1=1` |
| 变量存在但值为空 | 替换整个表达式为 `1=0` |
| 一个表达式中有多个变量 | 直接替换 |
| 只有一个变量，值个数=1 | 直接替换 |
| 只有一个变量，值个数>1 | 调用 `autoFixSqlCall` 优化 |

#### 查询变量（QUERY）替换规则

| 情况 | 处理方式 |
|------|---------|
| 变量不存在或值为空 | 返回 `IS NULL` 条件 |
| 一个表达式中有多个不同变量 | 直接替换 |
| 只有一个变量，值个数=1 | 直接替换 |
| 只有一个变量，值个数>1，且是布尔表达式 | 调用 `autoFixSqlCall` 优化 |

### 5.2 多值时的运算符自动优化

```java
protected SqlCall autoFixSqlCall(ScriptVariable variable) {
    SqlKind kind = sqlCall.getOperator().kind;

    switch (kind) {
        case EQUALS:
            // = 转换为 IN
            sqlOperator = SqlStdOperatorTable.IN;
            break;
            
        case NOT_EQUALS:
            // != 转换为 NOT IN
            sqlOperator = SqlStdOperatorTable.NOT_IN;
            break;
            
        case LIKE:
            // LIKE 转换为 OR ... LIKE ...
            sqlOperator = SqlStdOperatorTable.OR;
            operandList = variable.getValues().stream().map(val -> {
                return SqlNodeUtils.createSqlBasicCall(
                    SqlStdOperatorTable.LIKE, 
                    Arrays.asList(column, new SqlSimpleStringLiteral(val))
                );
            }).collect(Collectors.toList());
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

### 5.3 运算符转换表

| 原运算符 | 单值处理 | 多值处理 |
|---------|---------|---------|
| `=` | `= 'value'` | `IN ('v1', 'v2', 'v3')` |
| `!=` | `!= 'value'` | `NOT IN ('v1', 'v2', 'v3')` |
| `LIKE` | `LIKE 'value'` | `(LIKE 'v1' OR LIKE 'v2' OR LIKE 'v3')` |
| `NOT LIKE` | `NOT LIKE 'value'` | `(NOT LIKE 'v1' AND NOT LIKE 'v2')` |
| `>` | `> value` | `> min(values)` |
| `>=` | `>= value` | `>= min(values)` |
| `<` | `< value` | `< max(values)` |
| `<=` | `<= value` | `<= max(values)` |

---

## 6. FreeMarker 中的变量表现

### 6.1 变量转换逻辑

```java
// 文件: data-providers/data-provider-base/src/main/java/datart/data/provider/calcite/SqlQueryScriptProcessor.java

// 用 FreeMarker 处理脚本中的条件表达式
Map<String, ?> dataMap = queryScript.getVariables()
    .stream()
    .collect(Collectors.toMap(ScriptVariable::getName,
        variable -> {
            if (CollectionUtils.isEmpty(variable.getValues())) {
                return "";                              // 空值 → 空字符串
            } else if (variable.getValues().size() == 1) {
                return variable.getValues().iterator().next();  // 单值 → 字符串
            } else {
                return variable.getValues();            // 多值 → Set集合
            }
        }));

script = FreemarkerContext.process(queryScript.getScript(), dataMap);
```

### 6.2 FreeMarker 中的类型表现

| 选择情况 | FreeMarker 中的类型 | 判断方式 |
|---------|-------------------|---------|
| 未选任何值 | 空字符串 `""` | `!var??` 或 `var == ""` |
| 选了 1 个值 | 字符串 `"value"` | `!var?is_sequence` |
| 选了多个值 | 集合 `Set<String>` | `var?is_sequence` |

### 6.3 FreeMarker 常用判断

```sql
<#-- 判断变量是否存在且有值 -->
<#if var?? && var != "">

<#-- 判断是否为多值（集合） -->
<#if var?is_sequence>

<#-- 判断集合是否包含某值 -->
<#if var?seq_contains("all")>

<#-- 获取集合大小 -->
<#if var?size gt 0>

<#-- 遍历集合 -->
<#list var as item>${item}<#sep>,</#sep></#list>
```

---

## 7. 实际示例

### 7.1 SQL 视图中使用变量占位符

```sql
-- SQL 视图
SELECT * FROM orders WHERE department = $dept$
```

| 多选框选择 | 生成的 SQL |
|-----------|-----------|
| 不选 | `WHERE department IS NULL` |
| 选 1 个值：`销售部` | `WHERE department = '销售部'` |
| 选多个值：`销售部`, `技术部` | `WHERE department IN ('销售部', '技术部')` |

### 7.2 FreeMarker 条件判断

```sql
-- SQL 视图（使用 FreeMarker）
SELECT * FROM orders
WHERE 1=1
<#if dept?? && dept != "">
  <#if dept?is_sequence>
    AND department IN (<#list dept as d>'${d}'<#sep>,</#sep></#list>)
  <#else>
    AND department = '${dept}'
  </#if>
</#if>
```

| 多选框选择 | 生成的 SQL |
|-----------|-----------|
| 不选 | `WHERE 1=1` |
| 选 `销售部` | `WHERE 1=1 AND department = '销售部'` |
| 选 `销售部`, `技术部` | `WHERE 1=1 AND department IN ('销售部','技术部')` |

---

## 8. 核心源码位置

### 8.1 后端核心文件

| 文件 | 作用 |
|------|------|
| `core/.../ScriptVariable.java` | 变量数据结构定义 |
| `server/.../DataProviderServiceImpl.java` | 变量解析和传递 |
| `data-providers/.../VariablePlaceholder.java` | SQL 变量替换核心逻辑 |
| `data-providers/.../SqlNodeUtils.java` | SQL 节点生成工具 |
| `data-providers/.../SqlQueryScriptProcessor.java` | FreeMarker 处理 |

### 8.2 前端核心文件

| 文件 | 作用 |
|------|------|
| `frontend/.../DashBoardPage/utils/index.ts` | 控制器值处理 |
| `frontend/.../ChartDataRequestBuilder.ts` | 请求构建器 |
| `frontend/.../types/ChartDataRequest.ts` | 请求类型定义 |

---

## 总结

1. **变量始终是集合**：即使只选一个值，后端也是用 `Set<String>` 存储
2. **智能 SQL 优化**：系统根据值的个数自动调整 SQL 运算符
3. **FreeMarker 类型差异**：单值是字符串，多值是集合，需要用 `?is_sequence` 判断
4. **SQL 注入防护**：使用 `$var$` 占位符比 FreeMarker 的 `${var}` 更安全

---

**文档版本**: 1.0  
**最后更新**: 2025-12-09
