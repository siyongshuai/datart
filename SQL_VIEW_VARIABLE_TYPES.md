# SQL视图支持的变量类型

本文档提取了系统中SQL视图支持的所有变量类型。

## 概述

系统在前端和后端定义了变量类型，前端暴露给用户的是后端类型的一个子集。

## 前端变量类型（用户可见）

定义位置：`frontend/src/app/pages/MainPage/pages/VariablePage/constants.ts`

### VariableValueTypes 枚举

| 枚举值 | 值 | 中文名称 | 英文名称 | 说明 |
|--------|-----|---------|---------|------|
| String | 'STRING' | 字符 | String | 字符串类型 |
| Number | 'NUMERIC' | 数值 | Number | 数值类型 |
| Date | 'DATE' | 日期 | Date | 日期类型 |
| Expression | 'FRAGMENT' | 表达式 | Expression | SQL片段/表达式 |

## 后端变量类型（完整支持）

定义位置：`core/src/main/java/datart/core/base/consts/ValueType.java`

### ValueType 枚举

| 类型 | 说明 | 用途 |
|------|------|------|
| STRING | 字符串类型 | 存储文本数据，在SQL中会被引号包裹 |
| NUMERIC | 数值类型 | 存储数字数据，在SQL中不会被引号包裹 |
| DATE | 日期类型 | 存储日期时间数据，支持格式化 |
| BOOLEAN | 布尔类型 | 存储真/假值 |
| IDENTIFIER | 标识符类型 | 用于SQL标识符（如表名、列名） |
| FRAGMENT | 片段类型 | SQL片段，直接插入不做处理（do nothing） |
| SNIPPET | 代码片段类型 | 会被解析为SQL节点（will be parsed to sql node） |
| KEYWORD | 关键字类型 | SQL关键字 |

## 变量类型处理逻辑

### 值格式化规则

在 `VariablePlaceholder.java` 中，不同类型的变量在SQL替换时有不同的处理方式：

#### 不带引号的类型：
- NUMERIC
- KEYWORD
- SNIPPET
- FRAGMENT
- IDENTIFIER

这些类型的值在插入SQL时不会被引号包裹。

#### 带引号的类型：
- STRING
- DATE
- BOOLEAN（未在上述列表中，默认会被引号包裹）

这些类型的值在插入SQL时会被引号包裹。

### 变量替换规则

#### 权限变量（PERMISSION）替换规则：
1. 权限变量不存在 → 替换整个表达式为 `1=1`
2. 权限变量存在但值为空 → 替换整个表达式为 `1=0`
3. 一个表达式中有多个变量 → 直接替换
4. 一个表达式中只有一个变量 → 根据值个数进行替换
5. 其它情况 → 直接替换

#### 查询变量（QUERY）替换规则：
1. 变量不存在或变量值为空 → 直接返回原表达式
2. 一个表达式中有多个不同变量 → 直接替换
3. 一个表达式中只有一个变量，且表达式是布尔表达式 → 根据值的个数进行优化
4. 其它情况 → 直接替换

### 运算符优化

对于权限变量和查询变量，系统会根据值的个数自动优化SQL运算符：

| 原运算符 | 多值优化 | 处理方式 |
|---------|---------|---------|
| = | IN | 等于转换为IN |
| != | NOT IN | 不等于转换为NOT IN |
| LIKE | OR ... LIKE ... | 多个LIKE用OR连接 |
| NOT LIKE | AND ... NOT LIKE ... | 多个NOT LIKE用AND连接 |
| > | - | 取最小值 |
| >= | - | 取最小值 |
| < | - | 取最大值 |
| <= | - | 取最大值 |

## 变量实体定义

### 后端实体（Java）

```java
public class Variable extends BaseEntity {
    private String orgId;         // 组织ID
    private String viewId;        // 视图ID
    private String sourceId;      // 来源ID
    private String name;          // 变量名称
    private String type;          // 变量类型（QUERY/PERMISSION）
    private String valueType;     // 值类型（STRING/NUMERIC/DATE等）
    private String format;        // 格式（日期格式等）
    private Boolean encrypt;      // 是否加密
    private String label;         // 标签
    private String defaultValue;  // 默认值
    private Boolean expression;   // 是否为表达式
}
```

### 前端接口（TypeScript）

```typescript
export interface Variable {
  id: string;
  orgId: string;
  viewId?: string;
  name: string;
  label?: string;
  type: VariableTypes;              // QUERY | PERMISSION
  valueType: VariableValueTypes;    // STRING | NUMERIC | DATE | FRAGMENT
  encrypt: boolean;
  permission: number;
  defaultValue?: string;
  expression?: boolean;
  createBy?: string;
  createTime?: string;
  updateBy?: string;
  updateTime?: string;
  dateFormat?: DateFormat;
}
```

## 变量类型（Variable Types）

除了值类型（ValueType），变量还有类型分类：

| 类型 | 说明 |
|------|------|
| QUERY | 查询变量，用于动态查询条件 |
| PERMISSION | 权限变量，用于数据权限控制 |

## 变量作用域（Variable Scopes）

| 作用域 | 说明 |
|--------|------|
| PUBLIC | 公共变量 |
| PRIVATE | 私有变量 |

## 相关API

### 后端接口

- `GET /api/v1/variables?viewId={viewId}` - 获取视图的所有变量
- `GET /api/v1/views/{viewId}` - 获取视图详情（包含变量）
- `POST /api/v1/variables` - 创建变量
- `PUT /api/v1/variables/{id}` - 更新变量
- `DELETE /api/v1/variables/{id}` - 删除变量

### 服务层方法

- `VariableService.listByView(viewId)` - 按视图ID列出变量
- `VariableService.listViewVariableRels(viewId)` - 获取视图变量关系
- `VariableService.listViewQueryVariables(viewId)` - 获取视图查询变量
- `VariableService.delViewVariables(viewId)` - 删除视图的所有变量

## 文件位置索引

### 核心定义文件
- 后端值类型：`core/src/main/java/datart/core/base/consts/ValueType.java`
- 前端值类型：`frontend/src/app/pages/MainPage/pages/VariablePage/constants.ts`
- 变量实体：`core/src/main/java/datart/core/entity/Variable.java`
- 前端接口：`frontend/src/app/pages/MainPage/pages/VariablePage/slice/types.ts`

### 处理逻辑文件
- 变量占位符处理：`data-providers/data-provider-base/src/main/java/datart/data/provider/script/VariablePlaceholder.java`
- SQL节点工具：`data-providers/data-provider-base/src/main/java/datart/data/provider/calcite/SqlNodeUtils.java`
- SQL构建器：`data-providers/data-provider-base/src/main/java/datart/data/provider/calcite/SqlBuilder.java`

### 服务层文件
- 变量服务：`server/src/main/java/datart/server/service/impl/VariableServiceImpl.java`
- 视图服务：`server/src/main/java/datart/server/service/impl/ViewServiceImpl.java`
- 数据提供者服务：`server/src/main/java/datart/server/service/impl/DataProviderServiceImpl.java`

### 控制器文件
- 变量控制器：`server/src/main/java/datart/server/controller/VariableController.java`
- 视图控制器：`server/src/main/java/datart/server/controller/ViewController.java`

### 前端页面
- 变量管理页面：`frontend/src/app/pages/MainPage/pages/VariablePage/`
- 视图属性面板：`frontend/src/app/pages/MainPage/pages/ViewPage/Main/Properties/Variables.tsx`

### 国际化文件
- 英文：`frontend/src/locales/en/translation.json`
- 中文：`frontend/src/locales/zh/translation.json`

## 总结

SQL视图支持的变量类型体系完整，从用户界面层面提供了4种常用类型（字符、数值、日期、表达式），而在底层实现中支持8种类型以满足更复杂的SQL处理需求。系统通过智能的SQL解析和替换机制，能够根据变量类型和值的数量自动优化SQL语句，提供灵活强大的动态SQL构建能力。
