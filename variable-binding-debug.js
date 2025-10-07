/**
 * 多选下拉框绑定变量调试工具
 * 在浏览器控制台运行此脚本，检查变量绑定问题
 */

// 调试函数：检查控制器配置
function debugControllerBinding(controllerWidget) {
  console.group('🔍 控制器配置检查');
  
  const content = controllerWidget.config.content;
  const { relatedViews, config, type } = content;
  
  console.log('1️⃣ 控制器类型:', type);
  console.log('2️⃣ 控制器值:', config.controllerValues);
  
  relatedViews.forEach((relatedView, index) => {
    console.group(`关联配置 #${index + 1}`);
    console.log('- 关联类别:', relatedView.relatedCategory);
    console.log('- 字段/变量名:', relatedView.fieldValue);
    console.log('- 值类型:', relatedView.fieldValueType);
    console.log('- ViewId:', relatedView.viewId);
    
    // 检查问题
    const issues = [];
    if (relatedView.relatedCategory !== 'Variable' && relatedView.relatedCategory !== 'Field') {
      issues.push('❌ 关联类别异常');
    }
    if (!relatedView.fieldValue) {
      issues.push('❌ 未设置字段/变量名');
    }
    if (!config.controllerValues || config.controllerValues.length === 0) {
      issues.push('⚠️  控制器值为空');
    }
    
    if (issues.length > 0) {
      console.error('发现问题:', issues);
    } else {
      console.log('✅ 配置正常');
    }
    console.groupEnd();
  });
  
  console.groupEnd();
}

// 调试函数：检查变量参数
function debugVariableParams(variableParams) {
  console.group('🔍 变量参数检查');
  
  if (!variableParams || Object.keys(variableParams).length === 0) {
    console.error('❌ variableParams 为空！');
    console.log('可能原因：');
    console.log('1. 控制器未选择值');
    console.log('2. 控制器未正确关联变量');
    console.log('3. 关联类别不是 Variable');
  } else {
    Object.entries(variableParams).forEach(([key, values]) => {
      console.group(`变量: ${key}`);
      console.log('- 值:', values);
      console.log('- 类型:', Array.isArray(values) ? 'Array' : typeof values);
      console.log('- 数量:', Array.isArray(values) ? values.length : 1);
      
      if (Array.isArray(values) && values.length === 0) {
        console.warn('⚠️  值数组为空');
      } else if (!Array.isArray(values)) {
        console.error('❌ 值不是数组！期望格式: string[]');
      } else {
        console.log('✅ 格式正确');
      }
      console.groupEnd();
    });
  }
  
  console.groupEnd();
}

// 调试函数：检查 Chart 变量配置
function debugChartVariables(chartDataView) {
  console.group('🔍 Chart 变量配置检查');
  
  const config = typeof chartDataView.config === 'string' 
    ? JSON.parse(chartDataView.config) 
    : chartDataView.config;
  
  const variables = config?.variables || [];
  
  if (variables.length === 0) {
    console.warn('⚠️  数据集没有配置变量');
  } else {
    variables.forEach((variable, index) => {
      console.group(`变量 #${index + 1}: ${variable.name}`);
      console.log('- 名称:', variable.name);
      console.log('- 类型:', variable.type);
      console.log('- 值类型:', variable.valueType);
      console.log('- 默认值:', variable.defaultValue);
      console.log('- 是否表达式:', variable.expression);
      
      // 检查默认值格式
      if (variable.defaultValue) {
        try {
          const parsed = JSON.parse(variable.defaultValue);
          console.log('- 默认值解析结果:', parsed);
          
          if (Array.isArray(parsed)) {
            console.log('✅ 默认值格式正确（数组）');
          } else {
            console.error('❌ 默认值不是数组格式！期望: ["value1", "value2"]');
          }
        } catch (e) {
          console.error('❌ 默认值不是有效的 JSON:', e.message);
        }
      } else {
        console.warn('⚠️  没有设置默认值');
      }
      
      console.groupEnd();
    });
  }
  
  console.groupEnd();
}

// 调试函数：检查请求参数
function debugChartDataRequest(requestParams) {
  console.group('🔍 Chart 数据请求参数检查');
  
  console.log('ViewId:', requestParams.viewId);
  console.log('Filters:', requestParams.filters);
  console.log('Params (变量):', requestParams.params);
  
  if (requestParams.params) {
    console.group('变量参数详情');
    Object.entries(requestParams.params).forEach(([key, values]) => {
      console.log(`${key}:`, values);
      
      // 检查格式
      if (!Array.isArray(values)) {
        console.error(`❌ ${key} 的值不是数组！`);
      } else if (values.length === 0) {
        console.warn(`⚠️  ${key} 的值为空`);
      } else {
        console.log(`✅ ${key} 格式正确，${values.length} 个值`);
      }
    });
    console.groupEnd();
  } else {
    console.warn('⚠️  请求中没有变量参数');
  }
  
  console.groupEnd();
}

// 模拟 SQL 变量替换
function simulateSqlReplacement(sql, params) {
  console.group('🔍 SQL 变量替换模拟');
  
  console.log('原始 SQL:', sql);
  console.log('变量参数:', params);
  
  let resultSql = sql;
  
  if (params && Object.keys(params).length > 0) {
    Object.entries(params).forEach(([varName, values]) => {
      const pattern = new RegExp(`\\$${varName}\\$`, 'gi');
      
      if (values && Array.isArray(values) && values.length > 0) {
        // 模拟字符串类型的格式化（带引号）
        const formattedValues = values.map(v => `'${v}'`).join(',');
        resultSql = resultSql.replace(pattern, formattedValues);
        console.log(`✅ 替换 $${varName}$ => ${formattedValues}`);
      } else {
        console.error(`❌ 变量 $${varName}$ 值为空，可能会被替换为 IS NULL`);
      }
    });
  } else {
    console.warn('⚠️  没有变量参数，变量不会被替换');
  }
  
  console.log('替换后 SQL:', resultSql);
  console.groupEnd();
  
  return resultSql;
}

// 完整检查流程
function fullDebugCheck(options = {}) {
  const {
    controllerWidget,
    variableParams,
    chartDataView,
    requestParams,
    sql
  } = options;
  
  console.log('========================================');
  console.log('多选下拉框绑定变量 - 完整检查');
  console.log('========================================');
  
  if (controllerWidget) {
    debugControllerBinding(controllerWidget);
  }
  
  if (variableParams !== undefined) {
    debugVariableParams(variableParams);
  }
  
  if (chartDataView) {
    debugChartVariables(chartDataView);
  }
  
  if (requestParams) {
    debugChartDataRequest(requestParams);
  }
  
  if (sql && requestParams?.params) {
    simulateSqlReplacement(sql, requestParams.params);
  }
  
  console.log('========================================');
  console.log('检查完成');
  console.log('========================================');
}

// 使用示例
console.log(`
%c多选下拉框绑定变量调试工具已加载！

使用方法：
1. 检查控制器配置：
   debugControllerBinding(controllerWidget)

2. 检查变量参数：
   debugVariableParams(variableParams)

3. 检查 Chart 变量：
   debugChartVariables(chartDataView)

4. 检查请求参数：
   debugChartDataRequest(requestParams)

5. 模拟 SQL 替换：
   simulateSqlReplacement(sql, params)

6. 完整检查：
   fullDebugCheck({
     controllerWidget,
     variableParams,
     chartDataView,
     requestParams,
     sql
   })

示例：
const widget = widgetMap['widget-id'];
debugControllerBinding(widget);
`, 'color: #4CAF50; font-size: 14px; font-weight: bold;');

// 导出函数
if (typeof window !== 'undefined') {
  window.debugControllerBinding = debugControllerBinding;
  window.debugVariableParams = debugVariableParams;
  window.debugChartVariables = debugChartVariables;
  window.debugChartDataRequest = debugChartDataRequest;
  window.simulateSqlReplacement = simulateSqlReplacement;
  window.fullDebugCheck = fullDebugCheck;
}
