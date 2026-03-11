function module_result = time_lag_analysis_module(X, Y, main_params, module_config)
% TIME_LAG_ANALYSIS_MODULE 时滞估计子模块
% 
% 【核心功能】
% 专门处理"领先滞后周期"分析，计算两个时间序列之间的最佳时间延迟。
% 这是连通性分析的第三个子模块，解决"领先多久"的时间跨度问题。
%
% 【科学逻辑】
% 1. 计算互相关函数（CCF）评估不同时间延迟下的相关性
% 2. 寻找使互相关最大的滞后阶数作为最佳领先滞后
% 3. 进行统计显著性检验，区分真实领先滞后与随机波动
% 4. 输出标准化的滞后周期、相关强度和显著性结果
%
% 【输入参数】
%   X: 第一个时间序列（N×1向量），通常是领先序列
%   Y: 第二个时间序列（N×1向量），通常是滞后序列
%   main_params: 主函数参数结构体，包含：
%       - significance_level: 显著性水平
%       - verbose: 详细输出标志
%   module_config: 本子模块的配置结构体，包含：
%       - max_lag: 最大滞后阶数
%       - normalize: 是否对互相关函数进行归一化
%
% 【输出参数】
%   module_result: 结构体，包含以下字段：
%       - result: 互相关分析结果结构体
%           .cross_corr_function: 互相关函数值数组
%           .lags: 对应的滞后阶数数组
%           .max_cross_corr: 最大互相关系数
%           .optimal_lag: 最佳滞后阶数
%           .p_value: 显著性p值
%           .confidence_interval: 置信区间
%       - significance: 布尔值，是否存在显著领先滞后关系
%       - lag_info: 滞后信息结构体
%       - computation_time: 计算时间
%       - module_name: 模块标识
%
% 【算法细节】
% 1. 互相关函数：计算不同滞后下的皮尔逊相关系数
% 2. 显著性检验：基于Bartlett公式的标准误计算
% 3. 置信区间：基于标准正态分布的95%置信区间
%
% 【调用示例】
%   config = struct('max_lag', 10, 'normalize', true);
%   result = time_lag_analysis_module(ret_series, obv_series, params, config);

%% 1. 参数验证与初始化
start_time = tic;

% 检查输入数据
if nargin < 4
    error('time_lag_analysis_module需要4个输入参数');
end

if ~isvector(X) || ~isvector(Y)
    error('输入X和Y必须是向量');
end

if length(X) ~= length(Y)
    error('输入序列长度必须相等: %d != %d', length(X), length(Y));
end

% 确保main_params存在verbose字段
if ~isfield(main_params, 'verbose')
    main_params.verbose = false;
end

n_obs = length(X);

% 检查配置参数
if ~isfield(module_config, 'max_lag')
    error('module_config必须包含max_lag字段');
end
if ~isfield(module_config, 'normalize')
    module_config.normalize = true;
end

% 初始化结果结构
module_result = struct();
module_result.result = struct();
module_result.module_name = 'time_lag_analysis';
module_result.config = module_config;

%% 2. 数据预处理
% 移除缺失值
valid_idx = ~isnan(X) & ~isnan(Y);
X_clean = X(valid_idx);
Y_clean = Y(valid_idx);
n_valid = length(X_clean);

if n_valid < 20
    fprintf('有效观测值不足(%d < 20)，无法进行可靠的时滞分析', n_valid);
    % 返回默认的空结果
    module_result.result.cross_corr_function = [];
    module_result.result.lags = [];
    module_result.result.max_cross_corr = NaN;
    module_result.result.optimal_lag = NaN;
    module_result.result.p_value = NaN;
    module_result.significance = false;
    module_result.lag_info = struct('optimal_lag', NaN, 'lag_type', 'cross_correlation');
    module_result.computation_time = toc(start_time);
    return;
end

% 数据去趋势（提高稳定性）
X_detrend = detrend(X_clean);
Y_detrend = detrend(Y_clean);

%% 3. 计算互相关函数
try
    if main_params.verbose
        fprintf('    [时滞估计模块] 计算互相关函数 (max_lag=%d)...\n', module_config.max_lag);
    end
    
    % 计算互相关函数
    [ccf_values, lags, max_ccf, optimal_lag] = calculate_cross_correlation(...
        X_detrend, Y_detrend, module_config.max_lag, module_config.normalize);
    
    % 保存互相关函数结果
    module_result.result.cross_corr_function = ccf_values;
    module_result.result.lags = lags;
    module_result.result.max_cross_corr = max_ccf;
    module_result.result.optimal_lag = optimal_lag;
    module_result.result.n_obs = n_valid;
    
catch ME
    fprintf('互相关函数计算失败: %s', ME.message);
    % 返回错误结果
    module_result.result.max_cross_corr = NaN;
    module_result.result.optimal_lag = NaN;
    module_result.result.p_value = NaN;
    module_result.significance = false;
    module_result.lag_info = struct('optimal_lag', NaN, 'lag_type', 'cross_correlation');
    module_result.computation_time = toc(start_time);
    return;
end

%% 4. 计算统计显著性
try
    % 计算显著性p值
    p_value = calculate_ccf_significance(max_ccf, n_valid, module_config.max_lag);
    module_result.result.p_value = p_value;
    
    % 计算置信区间
    se = 1 / sqrt(n_valid);  % 互相关系数的近似标准误
    z_critical = norminv(1 - main_params.significance_level/2);
    ci_lower = max_ccf - z_critical * se;
    ci_upper = max_ccf + z_critical * se;
    
    module_result.result.confidence_interval = [ci_lower, ci_upper];
    module_result.result.standard_error = se;
    
catch ME
    fprintf('显著性检验计算失败: %s', ME.message);
    module_result.result.p_value = NaN;
    module_result.result.confidence_interval = [NaN, NaN];
end

%% 5. 计算显著性判断
module_result.significance = (module_result.result.p_value < main_params.significance_level) && ...
                             ~isnan(module_result.result.p_value);

% 标记显著滞后点
significant_lags = [];
if ~isnan(p_value) && module_result.significance
    % 找出所有显著高于阈值的滞后点
    threshold = 2 / sqrt(n_valid);  % 近似95%置信边界
    significant_indices = find(abs(ccf_values) > threshold);
    significant_lags = lags(significant_indices);
end

module_result.result.significant_lags = significant_lags;
module_result.result.significance_threshold = 2 / sqrt(n_valid);

%% 6. 构建滞后信息
module_result.lag_info = struct();
module_result.lag_info.optimal_lag = module_result.result.optimal_lag;
module_result.lag_info.lag_type = 'cross_correlation';
module_result.lag_info.is_significant = module_result.significance;
module_result.lag_info.significant_lags = significant_lags;
module_result.lag_info.max_cross_corr = module_result.result.max_cross_corr;

% 确定方向性（基于最佳滞后的符号）
if optimal_lag > 0
    module_result.lag_info.direction = 'x_leads_y';
    module_result.lag_info.lead_time = optimal_lag;
elseif optimal_lag < 0
    module_result.lag_info.direction = 'y_leads_x';
    module_result.lag_info.lead_time = -optimal_lag;
else
    module_result.lag_info.direction = 'synchronous';
    module_result.lag_info.lead_time = 0;
end

%% 7. 添加额外统计信息
% 计算互相关函数的对称性
if length(ccf_values) >= 3
    positive_lags = ccf_values(lags > 0);
    negative_lags = ccf_values(lags < 0);
    
    if ~isempty(positive_lags) && ~isempty(negative_lags)
        symmetry_index = mean(abs(positive_lags)) - mean(abs(negative_lags));
        module_result.result.symmetry_index = symmetry_index;
    end
end

% 计算互相关函数的平滑度
if length(ccf_values) > 2
    smoothness = mean(abs(diff(ccf_values)));
    module_result.result.smoothness = smoothness;
end

%% 8. 记录计算时间
module_result.computation_time = toc(start_time);

%% 9. 详细输出
if main_params.verbose
    % 显示主要结果
    direction_str = '';
    switch module_result.lag_info.direction
        case 'x_leads_y'
            direction_str = sprintf('X领先Y %d期', module_result.lag_info.lead_time);
        case 'y_leads_x'
            direction_str = sprintf('Y领先X %d期', module_result.lag_info.lead_time);
        case 'synchronous'
            direction_str = '同步';
    end
    
    fprintf('    [时滞估计模块] 完成: %s\n', direction_str);
    fprintf('                 最大互相关系数: %.3f (p=%.4f)\n', ...
        module_result.result.max_cross_corr, ...
        module_result.result.p_value);
    
    if ~isempty(significant_lags)
        fprintf('                 显著滞后点: %s\n', mat2str(significant_lags));
    end
    
    fprintf('                 置信区间: [%.3f, %.3f]\n', ...
        module_result.result.confidence_interval(1), ...
        module_result.result.confidence_interval(2));
end

end

%% ==================== 辅助函数 ====================

function [ccf_values, lags, max_ccf, optimal_lag] = calculate_cross_correlation(X, Y, max_lag, normalize_flag)
% 计算互相关函数的核心函数
    
    n = length(X);
    
    % 生成滞后序列
    lags = -max_lag:max_lag;
    n_lags = length(lags);
    ccf_values = zeros(n_lags, 1);
    
    % 计算每个滞后的互相关系数
    for i = 1:n_lags
        lag = lags(i);
        
        if lag >= 0
            % X领先Y（X的过去值影响Y的当前值）
            % 逻辑：用X的早期段与Y的晚期段对齐，考察X对Y的领先效应
            x_segment = X(1:n-lag);
            y_segment = Y(lag+1:n);
        else
            % Y领先X（Y的过去值影响X的当前值）
            % 逻辑：lag为负时，用Y的早期段与X的晚期段对齐
            lag = -lag;  % 转为正数以方便索引
            x_segment = X(lag+1:n);
            y_segment = Y(1:n-lag);
            lag = -lag;  % 恢复负值以保持lags数组的一致性
        end
        
        % 计算相关系数
        if length(x_segment) > 2 && length(y_segment) > 2
            try
                % 使用corrcoef计算皮尔逊相关系数
                corr_matrix = corrcoef(x_segment, y_segment, 'Rows', 'complete');
                
                % 确保corr_matrix是有效的2×2矩阵
                if all(size(corr_matrix) == [2, 2])
                    ccf_values(i) = corr_matrix(1, 2);
                else
                    ccf_values(i) = NaN;
                end
            catch ME
                % 如果计算失败，记录NaN
                ccf_values(i) = NaN;
                if main_params.verbose
                    fprintf('      滞后 %d 计算失败: %s\n', lag, ME.message);
                end
            end
        else
            ccf_values(i) = NaN;  % 数据段太短，无法计算可靠的相关性
        end
    end
    
    % 处理NaN值：用前后有效值的平均值插补缺失值
    ccf_values = handle_missing_ccf_values(ccf_values);
    
    % 归一化处理（如果需要）
    if normalize_flag
        max_abs_value = max(abs(ccf_values));
        if max_abs_value > 0
            ccf_values = ccf_values / max_abs_value;
        end
    end
    
    % 找到最大互相关系数及其对应的滞后
    valid_indices = ~isnan(ccf_values);
    if any(valid_indices)
        [max_ccf, max_idx] = max(abs(ccf_values(valid_indices)));
        % 映射回原始索引
        original_indices = find(valid_indices);
        max_idx_original = original_indices(max_idx);
        optimal_lag = lags(max_idx_original);
        max_ccf = ccf_values(max_idx_original);  % 带符号的最大值
        
        % 确保找到的是局部最大值而非边界值
        if max_idx_original > 1 && max_idx_original < n_lags
            % 检查是否是真正的峰值
            prev_val = ccf_values(max_idx_original - 1);
            next_val = ccf_values(max_idx_original + 1);
            if max_ccf > prev_val && max_ccf > next_val
                % 是局部最大值
            else
                % 寻找真正的局部最大值
                [max_ccf, optimal_lag] = find_local_peak(ccf_values, lags);
            end
        end
    else
        % 所有值都是NaN的情况
        max_ccf = NaN;
        optimal_lag = NaN;
    end
end

function ccf_clean = handle_missing_ccf_values(ccf_values)
% 处理互相关函数中的NaN值
% 使用线性插值填补缺失值
    
    n = length(ccf_values);
    ccf_clean = ccf_values;
    
    % 查找所有NaN的位置
    nan_indices = find(isnan(ccf_values));
    
    for idx = 1:length(nan_indices)
        i = nan_indices(idx);
        
        % 查找前后最近的非NaN值
        prev_val = NaN;
        prev_dist = Inf;
        next_val = NaN;
        next_dist = Inf;
        
        % 向前查找
        for j = i-1:-1:1
            if ~isnan(ccf_values(j))
                prev_val = ccf_values(j);
                prev_dist = i - j;
                break;
            end
        end
        
        % 向后查找
        for j = i+1:n
            if ~isnan(ccf_values(j))
                next_val = ccf_values(j);
                next_dist = j - i;
                break;
            end
        end
        
        % 根据找到的相邻值进行插值
        if ~isnan(prev_val) && ~isnan(next_val)
            % 线性插值
            weight_prev = next_dist / (prev_dist + next_dist);
            weight_next = prev_dist / (prev_dist + next_dist);
            ccf_clean(i) = weight_prev * prev_val + weight_next * next_val;
        elseif ~isnan(prev_val)
            % 只有前一个值，使用前值
            ccf_clean(i) = prev_val;
        elseif ~isnan(next_val)
            % 只有后一个值，使用后值
            ccf_clean(i) = next_val;
        else
            % 没有可用的相邻值，设置为0
            ccf_clean(i) = 0;
        end
    end
end

function [max_ccf, optimal_lag] = find_local_peak(ccf_values, lags)
% 寻找互相关函数的局部峰值
    
    n = length(ccf_values);
    local_maxima = [];
    local_maxima_lags = [];
    
    % 寻找所有局部最大值
    for i = 2:n-1
        if ccf_values(i) > ccf_values(i-1) && ccf_values(i) > ccf_values(i+1)
            local_maxima(end+1) = ccf_values(i);
            local_maxima_lags(end+1) = lags(i);
        end
    end
    
    if ~isempty(local_maxima)
        % 找到绝对值最大的局部最大值
        [max_abs, max_idx] = max(abs(local_maxima));
        max_ccf = local_maxima(max_idx);
        optimal_lag = local_maxima_lags(max_idx);
    else
        % 如果没有找到局部最大值，使用全局最大值
        [max_ccf, max_idx] = max(abs(ccf_values));
        optimal_lag = lags(max_idx);
        max_ccf = ccf_values(max_idx);
    end
end

function p_value = calculate_ccf_significance(max_ccf, n_obs, max_lag)
% CALCULATE_CCF_SIGNIFICANCE 计算互相关函数峰值的显著性p值
% 基于Bartlett公式，假设序列为白噪声。
%
% 输入:
%   max_ccf: 最大互相关系数（绝对值）
%   n_obs: 有效观测值数量
%   max_lag: 计算互相关时使用的最大滞后
%
% 输出:
%   p_value: 双侧检验的p值

    if n_obs <= max_lag + 2
        p_value = NaN;
        return;
    end
    
    % Bartlett标准误：1/sqrt(N)，适用于白噪声假设下的互相关系数
    se = 1 / sqrt(n_obs);
    
    % 计算z统计量
    z_stat = abs(max_ccf) / se;
    
    % 计算p值（双侧检验）
    % 注意：这里使用正态分布近似。对于小样本或非白噪声序列，这可能不精确。
    p_value = 2 * (1 - normcdf(z_stat));
    
    % 确保p值在合理范围内
    p_value = max(min(p_value, 1), 0);
end
