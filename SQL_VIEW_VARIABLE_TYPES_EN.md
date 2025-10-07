# SQL View Supported Variable Types

This document extracts all variable types supported by SQL views in the system.

## Overview

The system defines variable types in both frontend and backend. The frontend exposes a subset of backend types to users.

## Frontend Variable Types (User-Facing)

Definition Location: `frontend/src/app/pages/MainPage/pages/VariablePage/constants.ts`

### VariableValueTypes Enum

| Enum | Value | Chinese Name | English Name | Description |
|------|-------|--------------|--------------|-------------|
| String | 'STRING' | 字符 | String | String type |
| Number | 'NUMERIC' | 数值 | Number | Numeric type |
| Date | 'DATE' | 日期 | Date | Date/DateTime type |
| Expression | 'FRAGMENT' | 表达式 | Expression | SQL fragment/expression |

## Backend Variable Types (Full Support)

Definition Location: `core/src/main/java/datart/core/base/consts/ValueType.java`

### ValueType Enum

| Type | Description | Usage |
|------|-------------|-------|
| STRING | String type | Store text data, will be quoted in SQL |
| NUMERIC | Numeric type | Store numeric data, won't be quoted in SQL |
| DATE | Date type | Store date/datetime data, supports formatting |
| BOOLEAN | Boolean type | Store true/false values |
| IDENTIFIER | Identifier type | For SQL identifiers (table names, column names) |
| FRAGMENT | Fragment type | SQL fragment, inserted directly without processing (do nothing) |
| SNIPPET | Snippet type | Will be parsed to SQL node |
| KEYWORD | Keyword type | SQL keywords |

## Variable Type Processing Logic

### Value Formatting Rules

In `VariablePlaceholder.java`, different types of variables have different processing methods during SQL replacement:

#### Types Without Quotes:
- NUMERIC
- KEYWORD
- SNIPPET
- FRAGMENT
- IDENTIFIER

Values of these types won't be quoted when inserted into SQL.

#### Types With Quotes:
- STRING
- DATE
- BOOLEAN (not in the above list, will be quoted by default)

Values of these types will be quoted when inserted into SQL.

### Variable Replacement Rules

#### Permission Variable (PERMISSION) Replacement Rules:
1. Permission variable doesn't exist → Replace entire expression with `1=1`
2. Permission variable exists but value is empty → Replace entire expression with `1=0`
3. Multiple variables in one expression → Direct replacement
4. One variable in one expression → Replace based on number of values
5. Other cases → Direct replacement

#### Query Variable (QUERY) Replacement Rules:
1. Variable doesn't exist or value is empty → Return original expression
2. Multiple different variables in one expression → Direct replacement
3. One variable in one expression, and expression is boolean → Optimize based on number of values
4. Other cases → Direct replacement

### Operator Optimization

For permission and query variables, the system automatically optimizes SQL operators based on the number of values:

| Original Operator | Multi-value Optimization | Processing |
|------------------|-------------------------|------------|
| = | IN | Equals converted to IN |
| != | NOT IN | Not equals converted to NOT IN |
| LIKE | OR ... LIKE ... | Multiple LIKE connected with OR |
| NOT LIKE | AND ... NOT LIKE ... | Multiple NOT LIKE connected with AND |
| > | - | Use minimum value |
| >= | - | Use minimum value |
| < | - | Use maximum value |
| <= | - | Use maximum value |

## Variable Entity Definition

### Backend Entity (Java)

```java
public class Variable extends BaseEntity {
    private String orgId;         // Organization ID
    private String viewId;        // View ID
    private String sourceId;      // Source ID
    private String name;          // Variable name
    private String type;          // Variable type (QUERY/PERMISSION)
    private String valueType;     // Value type (STRING/NUMERIC/DATE, etc.)
    private String format;        // Format (date format, etc.)
    private Boolean encrypt;      // Whether to encrypt
    private String label;         // Label
    private String defaultValue;  // Default value
    private Boolean expression;   // Whether it's an expression
}
```

### Frontend Interface (TypeScript)

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

## Variable Types

Besides value types (ValueType), variables also have type classifications:

| Type | Description |
|------|-------------|
| QUERY | Query variable, used for dynamic query conditions |
| PERMISSION | Permission variable, used for data permission control |

## Variable Scopes

| Scope | Description |
|-------|-------------|
| PUBLIC | Public variable |
| PRIVATE | Private variable |

## Related APIs

### Backend Endpoints

- `GET /api/v1/variables?viewId={viewId}` - Get all variables of a view
- `GET /api/v1/views/{viewId}` - Get view details (including variables)
- `POST /api/v1/variables` - Create variable
- `PUT /api/v1/variables/{id}` - Update variable
- `DELETE /api/v1/variables/{id}` - Delete variable

### Service Layer Methods

- `VariableService.listByView(viewId)` - List variables by view ID
- `VariableService.listViewVariableRels(viewId)` - Get view variable relationships
- `VariableService.listViewQueryVariables(viewId)` - Get view query variables
- `VariableService.delViewVariables(viewId)` - Delete all variables of a view

## File Location Index

### Core Definition Files
- Backend value type: `core/src/main/java/datart/core/base/consts/ValueType.java`
- Frontend value type: `frontend/src/app/pages/MainPage/pages/VariablePage/constants.ts`
- Variable entity: `core/src/main/java/datart/core/entity/Variable.java`
- Frontend interface: `frontend/src/app/pages/MainPage/pages/VariablePage/slice/types.ts`

### Processing Logic Files
- Variable placeholder processing: `data-providers/data-provider-base/src/main/java/datart/data/provider/script/VariablePlaceholder.java`
- SQL node utilities: `data-providers/data-provider-base/src/main/java/datart/data/provider/calcite/SqlNodeUtils.java`
- SQL builder: `data-providers/data-provider-base/src/main/java/datart/data/provider/calcite/SqlBuilder.java`

### Service Layer Files
- Variable service: `server/src/main/java/datart/server/service/impl/VariableServiceImpl.java`
- View service: `server/src/main/java/datart/server/service/impl/ViewServiceImpl.java`
- Data provider service: `server/src/main/java/datart/server/service/impl/DataProviderServiceImpl.java`

### Controller Files
- Variable controller: `server/src/main/java/datart/server/controller/VariableController.java`
- View controller: `server/src/main/java/datart/server/controller/ViewController.java`

### Frontend Pages
- Variable management page: `frontend/src/app/pages/MainPage/pages/VariablePage/`
- View properties panel: `frontend/src/app/pages/MainPage/pages/ViewPage/Main/Properties/Variables.tsx`

### Internationalization Files
- English: `frontend/src/locales/en/translation.json`
- Chinese: `frontend/src/locales/zh/translation.json`

## Summary

The SQL view variable type system is comprehensive. At the user interface level, it provides 4 common types (String, Number, Date, Expression), while the underlying implementation supports 8 types to meet more complex SQL processing needs. Through intelligent SQL parsing and replacement mechanisms, the system can automatically optimize SQL statements based on variable types and the number of values, providing flexible and powerful dynamic SQL construction capabilities.
