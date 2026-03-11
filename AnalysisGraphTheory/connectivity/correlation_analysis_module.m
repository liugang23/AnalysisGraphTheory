function module_result = correlation_analysis_module(X, Y, main_params, module_config)
% CORRELATION_ANALYSIS_MODULE 关联性检测子模块
% 
% 【核心功能】
% 专门处理"关系强度"分析，计算两个时间序列之间的统计关联性。
% 这是连通性分析的第一个子模块，解决"有没有关系"和"关系有多强"的问题。
%
% 【科学逻辑】
% 1. 计算基础相关系数（皮尔逊相关）作为关系强度的核心指标
% 2. 进行统计显著性检验，区分真实关系与随机噪声
% 3. 可选的自助法（Bootstrap）验证，评估结果的稳定性
% 4. 输出标准化的结果结构，便于主函数整合
%
% 【输入参数】
%   X: 第一个时间序列（N×1向量），通常是收益率序列
%   Y: 第二个时间序列（N×1向量），通常是成交量序列
%   main_params: 主函数参数结构体，包含：
%       - significance_level: 显著性水平
%       - bootstrap_reps: 自助法重复次数
%       - verbose: 详细输出标志
%   module_config: 本子模块的配置结构体，包含：
%       - method: 相关计算方法（默认'pearson'）
%       - enable_bootstrap: 是否启用自助法
%
% 【输出参数】
%   module_result: 结构体，包含以下字段：
%       - result: 关联性分析结果结构体
%           .correlation: 相关系数值
%           .p_value: 显著性p值
%           .confidence_interval: 置信区间（如果计算了）
%           .bootstrap_stats: 自助法统计信息（如果启用了）
%       - significance: 布尔值，是否显著
%       - lag_info: 滞后信息结构体（本模块通常lag=0）
%       - computation_time: 计算时间
%       - module_name: 模块标识
%
% 【算法细节】
% 1. 皮尔逊相关系数：衡量线性相关强度
% 2. t检验：计算相关系数的统计显著性
% 3. 自助法：通过重采样评估相关系数的稳定性
%
% 【调用示例】
%   config = struct('method', 'pearson', 'enable_bootstrap', true);
%   result = correlation_analysis_module(ret_series, obv_series, params, config);

%% 1. 参数验证与初始化
start_time = tic;

% 检查输入数据
if nargin < 4
    error('correlation_analysis_module需要4个输入参数');
end

if ~isvector(X) || ~isvector(Y)
    error('输入X和Y必须是向量');
end

if length(X) ~= length(Y)
    error('输入序列长度必须相等: %d != %d', length(X), length(Y));
end

n_obs = length(X);

% 设置默认配置
if ~isfield(module_config, 'method')
    module_config.method = 'pearson';
end
if ~isfield(module_config, 'enable_bootstrap')
    module_config.enable_bootstrap = false;
end

% 初始化结果结构
module_result = struct();
module_result.result = struct();
module_result.module_name = 'correlation_analysis';
module_result.config = module_config;

%% 2. 数据预处理
% 移除缺失值
valid_idx = ~isnan(X) & ~isnan(Y);
X_clean = X(valid_idx);
Y_clean = Y(valid_idx);
n_valid = length(X_clean);

if n_valid < 10
    warning('有效观测值不足(%d < 10)，无法进行可靠的相关性分析', n_valid);
    module_result.result.correlation = NaN;
    module_result.result.p_value = NaN;
    module_result.significance = false;
    module_result.lag_info = struct('optimal_lag', 0, 'lag_type', 'correlation');
    module_result.computation_time = toc(start_time);
    return;
end

%% 3. 计算基础相关系数
try
    % 计算相关系数矩阵
    corr_matrix = corrcoef(X_clean, Y_clean, 'Rows', 'complete');
    r_value = corr_matrix(1, 2);
    
    % 计算显著性p值（t检验）
    if n_valid > 2
        t_stat = r_value * sqrt((n_valid - 2) / (1 - r_value^2));
        p_value = 2 * (1 - tcdf(abs(t_stat), n_valid - 2));
    else
        p_value = NaN;
    end
    
    % 保存基础结果
    module_result.result.correlation = r_value;
    module_result.result.p_value = p_value;
    module_result.result.n_obs = n_valid;
    module_result.result.method = module_config.method;
    
catch ME
    warning('相关系数计算失败: %s', ME.message);
    module_result.result.correlation = NaN;
    module_result.result.p_value = NaN;
    module_result.significance = false;
    module_result.lag_info = struct('optimal_lag', 0, 'lag_type', 'correlation');
    module_result.computation_time = toc(start_time);
    return;
end

%% 4. 自助法验证（如果启用）
if module_config.enable_bootstrap && main_params.bootstrap_reps > 0 && n_valid >= 20
    try
        if main_params.verbose
            fprintf('    [关联性模块] 执行自助法验证 (%d次重复)...\n', main_params.bootstrap_reps);
        end
        
        bootstrap_corrs = zeros(main_params.bootstrap_reps, 1);
        
        for b = 1:main_params.bootstrap_reps
            % 自助法重采样（有放回）
            indices = randi(n_valid, n_valid, 1);
            X_boot = X_clean(indices);
            Y_boot = Y_clean(indices);
            
            % 计算自助样本的相关系数
            corr_mat_boot = corrcoef(X_boot, Y_boot, 'Rows', 'complete');
            bootstrap_corrs(b) = corr_mat_boot(1, 2);
        end
        
        % 移除无效值
        valid_bootstrap = ~isnan(bootstrap_corrs);
        bootstrap_corrs = bootstrap_corrs(valid_bootstrap);
        
        if ~isempty(bootstrap_corrs)
            % 计算置信区间
            ci_lower = prctile(bootstrap_corrs, 2.5);
            ci_upper = prctile(bootstrap_corrs, 97.5);
            
            % 计算标准误
            bootstrap_se = std(bootstrap_corrs);
            
            % 保存自助法结果
            module_result.result.bootstrap_stats = struct();
            module_result.result.bootstrap_stats.correlations = bootstrap_corrs;
            module_result.result.bootstrap_stats.confidence_interval = [ci_lower, ci_upper];
            module_result.result.bootstrap_stats.standard_error = bootstrap_se;
            module_result.result.bootstrap_stats.mean_correlation = mean(bootstrap_corrs);
            module_result.result.bootstrap_stats.n_valid = sum(valid_bootstrap);
            
            % 检查原始相关系数是否在置信区间内
            in_ci = (r_value >= ci_lower) && (r_value <= ci_upper);
            module_result.result.bootstrap_stats.in_confidence_interval = in_ci;
            
            if main_params.verbose
                fprintf('      自助法结果: CI=[%.3f, %.3f], SE=%.4f, 原始值在CI内: %s\n', ...
                    ci_lower, ci_upper, bootstrap_se, bool2str(in_ci));
            end
        end
        
    catch ME
        warning('自助法验证失败: %s', ME.message);
    end
end

%% 5. 计算显著性判断
module_result.significance = (p_value < main_params.significance_level) && ~isnan(p_value);

%% 6. 构建滞后信息
% 关联性分析通常不考虑滞后，但为了统一接口，设置lag=0
module_result.lag_info = struct();
module_result.lag_info.optimal_lag = 0;
module_result.lag_info.lag_type = 'correlation';
module_result.lag_info.is_significant = module_result.significance;

%% 7. 添加额外统计信息
module_result.result.effect_size = r_value;  % 相关系数本身就是效应量
module_result.result.significant = module_result.significance;
module_result.result.significance_level = main_params.significance_level;

% 计算决定系数（R?）
module_result.result.r_squared = r_value^2;

%% 8. 记录计算时间
module_result.computation_time = toc(start_time);

%% 9. 详细输出
if main_params.verbose
    significance_star = '';
    if module_result.significance
        if p_value < 0.001
            significance_star = '***';
        elseif p_value < 0.01
            significance_star = '**';
        elseif p_value < 0.05
            significance_star = '*';
        end
    end
    
    fprintf('    [关联性模块] 完成: r=%.3f, p=%.4f%s, n=%d\n', ...
        r_value, p_value, significance_star, n_valid);
    
    if module_config.enable_bootstrap && isfield(module_result.result, 'bootstrap_stats')
        fprintf('                自助法: CI=[%.3f, %.3f], SE=%.4f\n', ...
            module_result.result.bootstrap_stats.confidence_interval(1), ...
            module_result.result.bootstrap_stats.confidence_interval(2), ...
            module_result.result.bootstrap_stats.standard_error);
    end
end

end

