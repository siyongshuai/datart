# SQL视图变量类型快速参考 / SQL View Variable Types Quick Reference

## 前端用户可见类型 / Frontend User-Facing Types

| 类型 Type | 值 Value | 中文 Chinese | 英文 English | 说明 Description |
|-----------|----------|--------------|--------------|------------------|
| String | STRING | 字符 | String | 字符串类型 / String type |
| Number | NUMERIC | 数值 | Number | 数值类型 / Numeric type |
| Date | DATE | 日期 | Date | 日期类型 / Date type |
| Expression | FRAGMENT | 表达式 | Expression | SQL片段 / SQL fragment |

**定义位置 / Definition:**
- Frontend: `frontend/src/app/pages/MainPage/pages/VariablePage/constants.ts`
- Backend: `core/src/main/java/datart/core/base/consts/ValueType.java`

---

## 后端完整支持类型 / Backend Full Support Types

| 类型 Type | 带引号 Quoted | 说明 Description |
|-----------|---------------|------------------|
| STRING | ✅ Yes | 字符串 / String |
| NUMERIC | ❌ No | 数值 / Numeric |
| DATE | ✅ Yes | 日期 / Date |
| BOOLEAN | ✅ Yes | 布尔值 / Boolean |
| IDENTIFIER | ❌ No | SQL标识符 / SQL identifier |
| FRAGMENT | ❌ No | SQL片段(不处理) / SQL fragment (do nothing) |
| SNIPPET | ❌ No | SQL代码片段(解析为节点) / SQL snippet (parsed to node) |
| KEYWORD | ❌ No | SQL关键字 / SQL keyword |

**定义位置 / Definition:** `core/src/main/java/datart/core/base/consts/ValueType.java`

---

## 变量分类 / Variable Categories

### 按类型 / By Type
- **QUERY** - 查询变量 / Query variable
- **PERMISSION** - 权限变量 / Permission variable

### 按作用域 / By Scope
- **PUBLIC** - 公共 / Public
- **PRIVATE** - 私有 / Private

---

## 关键文件位置 / Key File Locations

### 核心定义 / Core Definitions
```
core/src/main/java/datart/core/base/consts/ValueType.java
core/src/main/java/datart/core/entity/Variable.java
frontend/src/app/pages/MainPage/pages/VariablePage/constants.ts
frontend/src/app/pages/MainPage/pages/VariablePage/slice/types.ts
```

### 处理逻辑 / Processing Logic
```
data-providers/data-provider-base/src/main/java/datart/data/provider/script/VariablePlaceholder.java
data-providers/data-provider-base/src/main/java/datart/data/provider/calcite/SqlNodeUtils.java
```

### API / Services
```
server/src/main/java/datart/server/controller/VariableController.java
server/src/main/java/datart/server/service/impl/VariableServiceImpl.java
```

---

## 详细文档 / Detailed Documentation

- 中文详细文档: [SQL_VIEW_VARIABLE_TYPES.md](./SQL_VIEW_VARIABLE_TYPES.md)
- English Documentation: [SQL_VIEW_VARIABLE_TYPES_EN.md](./SQL_VIEW_VARIABLE_TYPES_EN.md)
