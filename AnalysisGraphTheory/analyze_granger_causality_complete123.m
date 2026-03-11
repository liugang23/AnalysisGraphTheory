function [result] = analyze_granger_causality_complete(ret_series, obv_series, max_lag, alpha)
% GRANGER_CAUSALITY_COMPLETE - 完整的Granger因果检验函数
%
% 功能: 执行双变量Granger因果检验，提供完整的统计结果
% 数学原理: 基于F-检验，比较包含与不包含预测变量滞后项的回归模型
%
% 输入参数:
%   ret_series   : 收益率时间序列 (N×1 向量)
%   obv_series   : 成交量时间序列 (N×1 向量)
%   max_lag      : 最大滞后阶数 (整数, ≥1)
%   alpha        : 显著性水平 (标量, 0<α<1)
%
% 输出参数:
%   result : 结构体，包含以下字段:
%     - direction: 因果关系方向
%                  'x_to_y': ret→obv
%                  'y_to_x': obv→ret
%                  'bidirectional': 双向
%                  'no_causality': 无因果
%     - causality_strength: 因果强度 (-1到1)
%     - optimal_lag_x2y: ret→obv的最优滞后
%     - optimal_lag_y2x: obv→ret的最优滞后
%     - p_value_x2y: ret→obv的p值
%     - p_value_y2x: obv→ret的p值
%     - f_statistic_x2y: ret→obv的F统计量
%     - f_statistic_y2x: obv→ret的F统计量
%     - significant_x2y: ret→obv是否显著 (逻辑值)
%     - significant_y2x: obv→ret是否显著 (逻辑值)
%     - all_p_values_x2y: 各滞后阶数的p值
%     - all_p_values_y2x: 各滞后阶数的p值
%     - all_f_stats_x2y: 各滞后阶数的F统计量
%     - all_f_stats_y2x: 各滞后阶数的F统计量
%     - aic_x2y: AIC准则值
%     - aic_y2x: AIC准则值
%     - net_causality: 净因果强度
%
% 使用示例:
%   [result] = analyze_granger_causality_complete(ret, obv, 5, 0.05);
%
% 版本: 1.0
% 作者: Financial Analysis Toolbox
% 日期: 2024-12-28

%% 1. 输入验证
if nargin < 4
    error('需要4个输入参数: ret_series, obv_series, max_lag, alpha');
end

% 验证序列长度
if length(ret_series) ~= length(obv_series)
    error('收益率和成交量序列长度必须一致');
end

n = length(ret_series);
if n < max_lag + 20
    warning('序列长度可能不足，建议增加数据或减少滞后阶数');
end

% 验证显著性水平
if alpha <= 0 || alpha >= 1
    error('显著性水平alpha必须在(0,1)区间内');
end

%% 2. 数据预处理
% 标准化处理 (消除量纲影响)
ret_norm = (ret_series - mean(ret_series)) / std(ret_series);
obv_norm = (obv_series - mean(obv_series)) / std(obv_series);

% 处理NaN值
valid_idx = ~isnan(ret_norm) & ~isnan(obv_norm);
ret_clean = ret_norm(valid_idx);
obv_clean = obv_norm(valid_idx);
n_clean = length(ret_clean);

%% 3. 确定最优滞后阶数
% 初始化存储数组
p_values_x2y = zeros(max_lag, 1);
p_values_y2x = zeros(max_lag, 1);
f_stats_x2y = zeros(max_lag, 1);
f_stats_y2x = zeros(max_lag, 1);
aic_x2y = zeros(max_lag, 1);
aic_y2x = zeros(max_lag, 1);

% 遍历所有滞后阶数
for lag = 1:max_lag
    % 检验 ret → obv
    [p_x2y, fstat_x2y, ~] = granger_test_single(obv_clean, ret_clean, lag, n_clean);
    p_values_x2y(lag) = p_x2y;
    f_stats_x2y(lag) = fstat_x2y;
    aic_x2y(lag) = calculate_aic(obv_clean, ret_clean, lag);
    
    % 检验 obv → ret
    [p_y2x, fstat_y2x, ~] = granger_test_single(ret_clean, obv_clean, lag, n_clean);
    p_values_y2x(lag) = p_y2x;
    f_stats_y2x(lag) = fstat_y2x;
    aic_y2x(lag) = calculate_aic(ret_clean, obv_clean, lag);
end

% 基于AIC选择最优滞后
[~, optimal_lag_x2y] = min(aic_x2y);
[~, optimal_lag_y2x] = min(aic_y2x);

% 使用最优滞后进行最终检验
[p_final_x2y, f_final_x2y, ~] = granger_test_single(obv_clean, ret_clean, optimal_lag_x2y, n_clean);
[p_final_y2x, f_final_y2x, ~] = granger_test_single(ret_clean, obv_clean, optimal_lag_y2x, n_clean);

% 显著性判断
sig_x2y = (p_final_x2y < alpha);
sig_y2x = (p_final_y2x < alpha);

%% 4. 确定因果关系方向
if sig_x2y && ~sig_y2x
    direction = 'x_to_y';        % ret → obv
    causality_strength = 1;
elseif ~sig_x2y && sig_y2x
    direction = 'y_to_x';        % obv → ret
    causality_strength = -1;
elseif sig_x2y && sig_y2x
    direction = 'bidirectional'; % 双向因果
    % 比较因果强度
    if f_final_x2y > f_final_y2x
        causality_strength = f_final_x2y / (f_final_x2y + f_final_y2x);
    else
        causality_strength = -f_final_y2x / (f_final_x2y + f_final_y2x);
    end
else
    direction = 'no_causality';  % 无因果
    causality_strength = 0;
end

%% 5. 计算净因果强度
net_causality = f_final_x2y - f_final_y2x;

%% 6. 构建结果结构
result = struct();

% 主要结果
result.direction = direction;
result.causality_strength = causality_strength;
result.optimal_lag_x2y = optimal_lag_x2y;
result.optimal_lag_y2x = optimal_lag_y2x;
result.p_value_x2y = p_final_x2y;
result.p_value_y2x = p_final_y2x;
result.f_statistic_x2y = f_final_x2y;
result.f_statistic_y2x = f_final_y2x;
result.significant_x2y = sig_x2y;
result.significant_y2x = sig_y2x;

% 详细统计量
result.all_p_values_x2y = p_values_x2y;
result.all_p_values_y2x = p_values_y2x;
result.all_f_stats_x2y = f_stats_x2y;
result.all_f_stats_y2x = f_stats_y2x;
result.aic_x2y = aic_x2y;
result.aic_y2x = aic_y2x;
result.net_causality = net_causality;

% 元数据
result.n_observations = n_clean;
result.max_lag = max_lag;
result.significance_level = alpha;
result.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

%% 7. 显示简要结果
fprintf('\nGranger因果检验结果:\n');
fprintf('  方向: %s\n', direction);
fprintf('  ret→obv: p=%.4f (lag=%d), F=%.4f, 显著: %s\n', ...
    p_final_x2y, optimal_lag_x2y, f_final_x2y, bool2str(sig_x2y));
fprintf('  obv→ret: p=%.4f (lag=%d), F=%.4f, 显著: %s\n', ...
    p_final_y2x, optimal_lag_y2x, f_final_y2x, bool2str(sig_y2x));
fprintf('  观测值数量: %d\n', n_clean);

end

%% ==================== 内部辅助函数 ====================

function [p_value, f_stat, critical_value] = granger_test_single(y, x, lag, n)
% GRANGER_TEST_SINGLE - 单方向Granger因果检验
%
% 检验 x 是否 Granger-cause y
% 数学原理: F = [(RSS_r - RSS_ur)/m] / [RSS_ur/(n-2m-1)]
%
% 输入:
%   y: 被预测变量
%   x: 预测变量
%   lag: 滞后阶数
%   n: 样本数量
%
% 输出:
%   p_value: p值
%   f_stat: F统计量
%   critical_value: 临界值

    % 构建滞后矩阵
    y_lags = zeros(n-lag, lag);
    x_lags = zeros(n-lag, lag);
    y_current = y(lag+1:end);
    
    for l = 1:lag
        y_lags(:, l) = y(l:n-lag+l-1);
        x_lags(:, l) = x(l:n-lag+l-1);
    end
    
    % 受限模型 (只包含y的滞后)
    X_restricted = [ones(n-lag, 1), y_lags];
    beta_restricted = X_restricted \ y_current;
    resid_restricted = y_current - X_restricted * beta_restricted;
    RSS_restricted = sum(resid_restricted.^2);
    
    % 无限制模型 (包含y和x的滞后)
    X_unrestricted = [ones(n-lag, 1), y_lags, x_lags];
    beta_unrestricted = X_unrestricted \ y_current;
    resid_unrestricted = y_current - X_unrestricted * beta_unrestricted;
    RSS_unrestricted = sum(resid_unrestricted.^2);
    
    % F检验统计量
    df_num = lag;  % 限制的参数数量
    df_den = n - 2*lag - 1;  % 无限制模型的自由度
    
    f_stat = ((RSS_restricted - RSS_unrestricted) / df_num) / (RSS_unrestricted / df_den);
    p_value = 1 - fcdf(f_stat, df_num, df_den);
    critical_value = finv(1 - 0.05, df_num, df_den);
    
end

function aic = calculate_aic(y, x, lag)
% CALCULATE_AIC - 计算Akaike信息准则
%
% 用于选择最优滞后阶数
% AIC = n*log(RSS/n) + 2*k
%
% 输入:
%   y: 被预测变量
%   x: 预测变量
%   lag: 滞后阶数
%
% 输出:
%   aic: AIC值

    n = length(y);
    y_lags = zeros(n-lag, lag);
    x_lags = zeros(n-lag, lag);
    y_current = y(lag+1:end);
    
    for l = 1:lag
        y_lags(:, l) = y(l:n-lag+l-1);
        x_lags(:, l) = x(l:n-lag+l-1);
    end
    
    X = [ones(n-lag, 1), y_lags, x_lags];
    beta = X \ y_current;
    resid = y_current - X * beta;
    RSS = sum(resid.^2);
    
    k = size(X, 2);  % 参数数量
    aic = n * log(RSS/n) + 2*k;
    
end

function str = bool2str(bool_val)
% BOOL2STR - 逻辑值转字符串
    if bool_val
        str = '是';
    else
        str = '否';
    end
end