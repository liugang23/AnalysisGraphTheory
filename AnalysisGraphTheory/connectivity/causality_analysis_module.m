function module_result = causality_analysis_module(X, Y, main_params, module_config)
% CAUSALITY_ANALYSIS_MODULE 因果性分析子模块
% 
% 【核心功能】
% 专门处理"因果关系方向"分析，判断两个时间序列之间的因果方向。
% 这是连通性分析的第二个子模块，解决"谁领先谁"的因果推断问题。
%
% 【修改说明 v2.0】
% 1. 已禁用数据标准化：为保证输出的F统计量、效应大小等权重指标具有跨配对可比性，
%    以供下游构建加权网络，本函数不再对输入序列进行 (X-mean)/std 的标准化。
% 2. 输出原始统计量：所有统计量（F, p, RSS, 效应大小）均基于原始数据尺度计算。
% 3. 补充元数据：在结果中保存输入序列的均值与标准差，供下游必要时进行全局标准化。
%
% 【输入参数】
%   X: 第一个时间序列（N×1向量），通常是源序列
%   Y: 第二个时间序列（N×1向量），通常是目标序列
%   main_params: 主函数参数结构体，包含：
%       - significance_level: 显著性水平
%       - verbose: 详细输出标志
%   module_config: 本子模块的配置结构体，包含：
%       - max_lag: 最大滞后阶数
%       - enable_nonlinear: 是否启用非线性检测
%       - bds_m: 非线性检测嵌入维度
%       - bds_epsilon: 非线性检测距离阈值
%
% 【输出参数】
%   module_result: 结构体，包含以下字段：
%       - result: Granger因果分析结果结构体
%           .direction: 因果方向 ('x_to_y', 'y_to_x', 'bidirectional', 'none')
%           .f_statistic_x2y: X→Y的F统计量 (基于原始尺度，具有跨配对可比性)
%           .f_statistic_y2x: Y→X的F统计量
%           .p_value_x2y: X→Y的显著性p值
%           .p_value_y2x: Y→X的显著性p值
%           .optimal_lag: VAR模型的最优滞后阶数 (统一滞后)
%           .aic_values: AIC信息准则值数组
%           .bic_values: BIC信息准则值数组
%           .rss_r_x2y, .rss_u_x2y, .rss_r_y2x, .rss_u_y2x: 残差平方和
%           .effect_size_x2y, .effect_size_y2x: 效应大小 (基于原始尺度)
%           .variance_explained_x2y, .variance_explained_y2x: 解释方差比例
%       - nonlinear_result: 非线性检测结果（如果启用）
%       - significance: 布尔值，是否存在显著因果关系
%       - lag_info: 滞后信息结构体
%       - computation_time: 计算时间
%       - module_name: 模块标识
%       - data_metadata: 输入数据的元信息 (均值、标准差、样本数)

%% 1. 参数验证与初始化
start_time = tic;

% 检查输入数据
if nargin < 4
    error('causality_analysis_module需要4个输入参数');
end

if ~isvector(X) || ~isvector(Y)
    error('输入X和Y必须是向量');
end

if length(X) ~= length(Y)
    error('输入序列长度必须相等: %d != %d', length(X), length(Y));
end

n_obs = length(X);

% 检查配置参数
if ~isfield(module_config, 'max_lag')
    error('module_config必须包含max_lag字段');
end
if ~isfield(module_config, 'enable_nonlinear')
    module_config.enable_nonlinear = false;
end

% 初始化结果结构
module_result = struct();
module_result.result = struct();
module_result.module_name = 'causality_analysis';
module_result.config = module_config;

%% 2. 数据预处理
% 移除缺失值
valid_idx = ~isnan(X) & ~isnan(Y);
X_clean = X(valid_idx);
Y_clean = Y(valid_idx);
n_valid = length(X_clean);

if n_valid < 20
    warning('有效观测值不足(%d < 20)，无法进行可靠的Granger因果分析', n_valid);
    % 返回默认的空结果
    module_result.result.direction = 'none';
    module_result.result.f_statistic_x2y = NaN;
    module_result.result.f_statistic_y2x = NaN;
    module_result.result.p_value_x2y = NaN;
    module_result.result.p_value_y2x = NaN;
    module_result.result.optimal_lag = NaN;
    module_result.significance = false;
    module_result.lag_info = struct('optimal_lag', NaN, 'lag_type', 'granger');
    module_result.computation_time = toc(start_time);
    return;
end

% === 修改点 [A]：禁用标准化，保存元数据 ===
% 不再进行 (X-mean)/std 的标准化，以保证输出统计量的原始尺度和跨配对可比性。
% 直接使用清洗后的数据。
X_norm = X_clean;
Y_norm = Y_clean;

% 计算并保存原始数据的元信息，供下游参考
x_mean = mean(X_clean);
x_std = std(X_clean);
y_mean = mean(Y_clean);
y_std = std(Y_clean);

module_result.data_metadata = struct(...
    'x_mean', x_mean, ...
    'x_std', x_std, ...
    'y_mean', y_mean, ...
    'y_std', y_std, ...
    'n_valid', n_valid, ...
    'scale_note', 'All output statistics (F, effect size, RSS) are based on original data scale, NOT normalized.');
% === 修改结束 ===

%% 3. 执行线性Granger因果检验
try
    if main_params.verbose
        fprintf('    [因果性模块] 执行线性Granger因果检验 (max_lag=%d)...\n', module_config.max_lag);
    end
    
    % 调用重构后的Granger因果检验函数 (已输出RSS字段)
    granger_result = perform_granger_causality_test(X_norm, Y_norm, module_config.max_lag, main_params.significance_level);
    
    % 保存线性Granger结果
    module_result.result = granger_result;
    module_result.result.n_obs = n_valid;
    
catch ME
    warning('Granger因果检验失败: %s', ME.message);
    % 返回错误结果
    module_result.result.direction = 'error';
    module_result.significance = false;
    module_result.lag_info = struct('optimal_lag', NaN, 'lag_type', 'granger');
    module_result.computation_time = toc(start_time);
    return;
end

%% 4. 非线性Granger检测（如果启用）
if module_config.enable_nonlinear
    try
        if main_params.verbose
            fprintf('    [因果性模块] 执行非线性Granger检测...\n');
        end
        
        % 检查BDS参数是否存在
        if isfield(module_config, 'bds_m') && isfield(module_config, 'bds_epsilon')
            % 准备非线性检测参数
            nonlinear_params.significance_level = main_params.significance_level;
            nonlinear_params.bds_m = module_config.bds_m;
            nonlinear_params.bds_epsilon = module_config.bds_epsilon;
            nonlinear_params.verbose = main_params.verbose;
            
            % 调用非线性检测函数 (需确保此函数已适配新接口)
            % 注意：非线性检测函数也应使用未标准化的数据 X_norm, Y_norm
            nonlinear_result = check_nonlinear_granger(...
                X_norm, Y_norm, granger_result, nonlinear_params);
            
            % 保存非线性结果
            module_result.nonlinear_result = nonlinear_result;
            
            % 如果存在纯非线性因果关系，更新主结果
            if isfield(nonlinear_result, 'x2y_nonlinear') && nonlinear_result.x2y_nonlinear && ~granger_result.is_significant_x2y
                module_result.result.has_nonlinear_x2y = true;
            end
            if isfield(nonlinear_result, 'y2x_nonlinear') && nonlinear_result.y2x_nonlinear && ~granger_result.is_significant_y2x
                module_result.result.has_nonlinear_y2x = true;
            end
            
        else
            warning('非线性检测参数不完整，跳过非线性检测');
        end
        
    catch ME
        warning('非线性Granger检测失败: %s', ME.message);
    end
end

%% 5. 计算显著性判断
% 判断是否存在显著因果关系（线性或非线性）
has_significant_linear = module_result.result.is_significant_x2y || module_result.result.is_significant_y2x;
has_significant_nonlinear = false;

if module_config.enable_nonlinear && isfield(module_result, 'nonlinear_result')
    has_significant_nonlinear = (isfield(module_result.nonlinear_result, 'x2y_nonlinear') && module_result.nonlinear_result.x2y_nonlinear) || ...
                                (isfield(module_result.nonlinear_result, 'y2x_nonlinear') && module_result.nonlinear_result.y2x_nonlinear);
end

module_result.significance = has_significant_linear || has_significant_nonlinear;

% 记录关系类型
if has_significant_linear && has_significant_nonlinear
    module_result.result.connection_type = 'linear_and_nonlinear';
elseif has_significant_linear
    module_result.result.connection_type = 'linear_only';
elseif has_significant_nonlinear
    module_result.result.connection_type = 'nonlinear_only';
else
    module_result.result.connection_type = 'none';
end

%% 6. 构建滞后信息
module_result.lag_info = struct();
% === 修改点 [C]：使用统一的最优滞后字段 ===
module_result.lag_info.optimal_lag = module_result.result.optimal_lag;
module_result.lag_info.lag_type = 'granger';
module_result.lag_info.is_significant = module_result.significance;
% === 修改结束 ===

% 注意：已删除原代码中引用已废弃字段 optimal_lag_x2y, optimal_lag_y2x 的逻辑
% 以及基于F值判断“主导滞后”的逻辑，因为滞后是模型阶数属性，无“主导”之分。

%% 7. 添加额外统计信息
% 计算效应大小（标准化回归系数）- 基于原始数据尺度
% === 修改点 [A-延续]：使用未标准化的数据计算效应大小 ===
if isfield(module_result.result, 'optimal_lag')
    module_result.result.effect_size_x2y = calculate_effect_size(X_norm, Y_norm, module_result.result.optimal_lag);
    module_result.result.effect_size_y2x = calculate_effect_size(Y_norm, X_norm, module_result.result.optimal_lag);
else
    module_result.result.effect_size_x2y = NaN;
    module_result.result.effect_size_y2x = NaN;
end

% 计算解释方差比例 (R?，已解释方差的比例)
% 公式: R? = 1 - (RSS_unrestricted / RSS_restricted)
if isfield(module_result.result, 'rss_u_x2y') && isfield(module_result.result, 'rss_r_x2y')
    if module_result.result.rss_r_x2y > 0
        module_result.result.variance_explained_x2y = 1 - (module_result.result.rss_u_x2y / module_result.result.rss_r_x2y);
    else
        module_result.result.variance_explained_x2y = NaN;
    end
else
    module_result.result.variance_explained_x2y = NaN;
end

if isfield(module_result.result, 'rss_u_y2x') && isfield(module_result.result, 'rss_r_y2x')
    if module_result.result.rss_r_y2x > 0
        module_result.result.variance_explained_y2x = 1 - (module_result.result.rss_u_y2x / module_result.result.rss_r_y2x);
    else
        module_result.result.variance_explained_y2x = NaN;
    end
else
    module_result.result.variance_explained_y2x = NaN;
end
% === 修改结束 ===

%% 8. 记录计算时间
module_result.computation_time = toc(start_time);

%% 9. 详细输出
if main_params.verbose
    % 显示主要结果
    direction_symbol = '';
    switch module_result.result.direction
        case 'x_to_y'
            direction_symbol = 'X→Y';
        case 'y_to_x'
            direction_symbol = 'Y→X';
        case 'bidirectional'
            direction_symbol = 'X?Y';
        case 'none'
            direction_symbol = '无关系';
    end
    
    % === 修改点 [D]：更新输出信息，反映无标准化计算 ===
    fprintf('    [因果性模块] 完成: 方向=%s, 最优滞后=%d (基于原始数据尺度)\n', ...
        direction_symbol, ...
        module_result.result.optimal_lag);
    
    fprintf('                 统计量: F(X→Y)=%.2f(p=%.4f), F(Y→X)=%.2f(p=%.4f)\n', ...
        module_result.result.f_statistic_x2y, ...
        module_result.result.p_value_x2y, ...
        module_result.result.f_statistic_y2x, ...
        module_result.result.p_value_y2x);
    % === 修改结束 ===
    
    if module_config.enable_nonlinear && isfield(module_result, 'nonlinear_result')
        fprintf('      非线性: X→Y:%s, Y→X:%s\n', ...
            bool2str(module_result.nonlinear_result.x2y_nonlinear), ...
            bool2str(module_result.nonlinear_result.y2x_nonlinear));
    end
    
    % 显示效应大小和解释方差
    if isfield(module_result.result, 'effect_size_x2y')
        fprintf('                 效应大小: X→Y=%.4f, Y→X=%.4f\n', ...
            module_result.result.effect_size_x2y, ...
            module_result.result.effect_size_y2x);
    end
    if isfield(module_result.result, 'variance_explained_x2y')
        fprintf('                 解释方差: X→Y=%.3f, Y→X=%.3f\n', ...
            module_result.result.variance_explained_x2y, ...
            module_result.result.variance_explained_y2x);
    end
end

end

%% ==================== 辅助函数 ====================

function granger_result = perform_granger_causality_test(X, Y, max_lag, alpha)
% PERFORM_GRANGER_CAUSALITY_TEST 执行统计严谨的Granger因果检验（核心计算函数）
% 本函数重构了原逻辑，严格分离“最优滞后选择”与“假设检验”步骤。
%
% 【输入参数】
%   X: 第一个时间序列 (N×1)，应确保为平稳序列
%   Y: 第二个时间序列 (N×1)，应确保为平稳序列
%   max_lag: 考虑的最大滞后阶数
%   alpha: 显著性水平
%
% 【输出参数】
%   granger_result: 结构体，包含以下字段：
%       .direction: 因果方向 ('x_to_y', 'y_to_x', 'bidirectional', 'none')
%       .f_statistic_x2y: X->Y的F统计量
%       .f_statistic_y2x: Y->X的F统计量
%       .p_value_x2y: X->Y的p值
%       .p_value_y2x: Y->X的p值
%       .optimal_lag: 基于BIC选择的VAR模型最优滞后阶数 (标量)
%       .is_significant_x2y: X->Y是否显著
%       .is_significant_y2x: Y->X是否显著
%       .aic_values: 各滞后阶数的AIC值数组
%       .bic_values: 各滞后阶数的BIC值数组
%       .test_alpha: 使用的显著性水平
%       .n_obs: 有效观测值数量
%       .estimation_time: 时间戳
%
% 【算法步骤】
%   1. 为双变量系统(X,Y)拟合VAR(1)到VAR(max_lag)模型，计算AIC和BIC。
%   2. 选择BIC最小的滞后阶数作为最优滞后 p_opt。
%   3. 在 p_opt 阶下，分别构建检验X->Y和Y->X的受限/无限制模型。
%   4. 计算F统计量: F = [(RSS_r - RSS_u)/p_opt] / [RSS_u/(T - k)]，
%      其中 k = 2*p_opt + 1，T 为有效样本数。
%   5. 计算p值: p = 1 - fcdf(F, p_opt, T-k)
%   6. 判断显著性并确定因果方向。

%% 1. 输入验证与初始化
T = length(X);
if length(Y) ~= T
    error('序列长度不一致: X(%d) != Y(%d)', T, length(Y));
end
if max_lag < 1 || max_lag >= T/2
    error('max_lag=%d 不合理，应在1和%d之间', max_lag, floor(T/2));
end

granger_result = struct();
granger_result.max_lag = max_lag;
granger_result.alpha = alpha;
granger_result.n_obs = T;

%% 2. 为双变量VAR系统选择最优滞后阶数 (基于BIC)
% 初始化存储数组
aic_vals = zeros(max_lag, 1);
bic_vals = zeros(max_lag, 1);

for lag = 1:max_lag
    % 创建滞后数据矩阵
    [X_lagged, Y_lagged, T_effective] = create_lagged_matrix_for_var(X, Y, lag);
    
    % 设计矩阵: [常数, X_lag1..lag, Y_lag1..lag]
    Z = [ones(T_effective, 1), X_lagged, Y_lagged];
    
    % 响应变量: [X(t), Y(t)]
    Y_response = [X(lag+1:end), Y(lag+1:end)];
    
    % 多元最小二乘估计
    B = (Z' * Z) \ (Z' * Y_response);
    residuals = Y_response - Z * B;
    
    % 残差协方差矩阵
    Sigma = (residuals' * residuals) / T_effective;
    
    % 对数似然 (多元正态假设)
    k_total = size(Z, 2) * 2; % 参数总数: (1+2*lag) * 2
    logL = -T_effective/2 * (2*(1+log(2*pi)) + log(det(Sigma)));
    
    % 信息准则
    aic_vals(lag) = 2*k_total - 2*logL;
    bic_vals(lag) = k_total*log(T_effective) - 2*logL;
end

% 选择BIC最小的滞后阶数
[~, p_opt] = min(bic_vals);
granger_result.optimal_lag = p_opt;
granger_result.aic_values = aic_vals;
granger_result.bic_values = bic_vals;

%% 3. 在最优滞后 p_opt 下执行Granger因果检验
try
    % 3.1 准备 p_opt 阶数据
    [X_lagged_opt, Y_lagged_opt, T_eff_opt] = create_lagged_matrix_for_var(X, Y, p_opt);
    Z_full = [ones(T_eff_opt, 1), X_lagged_opt, Y_lagged_opt];

    % 响应变量
    X_response = X(p_opt+1:end);
    Y_response = Y(p_opt+1:end);

    % 定义滞后项在Z_full中的索引
    % Z_full结构: [常数, X_lag1..X_lagP, Y_lag1..Y_lagP]
    X_lags_idx = (1+1):(1+p_opt);
    Y_lags_idx = (1+p_opt+1):(1+2*p_opt);

    % 3.1 检验 X -> Y
    % 无限制模型: 包含X和Y的所有滞后
    Z_unrestricted_y = Z_full;
    % 受限模型: 排除X的滞后
    Z_restricted_y = Z_full(:, [1, Y_lags_idx]);

    beta_unrestricted_y = (Z_unrestricted_y' * Z_unrestricted_y) \ (Z_unrestricted_y' * Y_response);
    beta_restricted_y = (Z_restricted_y' * Z_restricted_y) \ (Z_restricted_y' * Y_response);
    
    % ===== 计算并保存残差平方和 =====
    residuals_unrestricted_y = Y_response - Z_unrestricted_y * beta_unrestricted_y;
    residuals_restricted_y = Y_response - Z_restricted_y * beta_restricted_y;
    
    RSS_unrestricted_y = sum(residuals_unrestricted_y.^2);
    RSS_restricted_y = sum(residuals_restricted_y.^2);
    
    % 计算F统计量
    q = p_opt; % 约束个数
    k_unrestricted = size(Z_unrestricted_y, 2); % 1 + 2*p_opt
    df_denom = T_eff_opt - k_unrestricted;

    F_x2y = ((RSS_restricted_y - RSS_unrestricted_y) / q) / (RSS_unrestricted_y / df_denom);
    p_x2y = 1 - fcdf(F_x2y, q, df_denom);

    % 3.2 检验 Y -> X
    % 无限制模型: 包含X和Y的所有滞后
    Z_unrestricted_x = Z_full;
    % 受限模型: 排除Y的滞后
    Z_restricted_x = Z_full(:, [1, X_lags_idx]);

    beta_unrestricted_x = (Z_unrestricted_x' * Z_unrestricted_x) \ (Z_unrestricted_x' * X_response);
    beta_restricted_x = (Z_restricted_x' * Z_restricted_x) \ (Z_restricted_x' * X_response);
    
    % ===== 计算并保存残差平方和 =====
    residuals_unrestricted_x = X_response - Z_unrestricted_x * beta_unrestricted_x;
    residuals_restricted_x = X_response - Z_restricted_x * beta_restricted_x;

    RSS_unrestricted_x = sum(residuals_unrestricted_x.^2);
    RSS_restricted_x = sum(residuals_restricted_x.^2);

    F_y2x = ((RSS_restricted_x - RSS_unrestricted_x) / q) / (RSS_unrestricted_x / df_denom);
    p_y2x = 1 - fcdf(F_y2x, q, df_denom);
catch ME
	fprintf('在最优滞后 p_opt 下执行Granger因果检验 失败: %s', ME.message);
end
%% 4. 整合检验结果
granger_result.f_statistic_x2y = F_x2y;
granger_result.f_statistic_y2x = F_y2x;
granger_result.p_value_x2y = p_x2y;
granger_result.p_value_y2x = p_y2x;
granger_result.is_significant_x2y = p_x2y < alpha;
granger_result.is_significant_y2x = p_y2x < alpha;
granger_result.optimal_lag = p_opt;
granger_result.test_alpha = alpha;

% ===== 【关键修改：添加残差平方和字段】 =====
granger_result.rss_r_x2y = RSS_restricted_y; % 检验X->Y时的受限模型RSS
granger_result.rss_u_x2y = RSS_unrestricted_y; % 检验X->Y时的非受限模型RSS
granger_result.rss_r_y2x = RSS_restricted_x; % 检验Y->X时的受限模型RSS
granger_result.rss_u_y2x = RSS_unrestricted_x; % 检验Y->X时的非受限模型RSS
% ============================================

% 确定因果方向
if granger_result.is_significant_x2y && granger_result.is_significant_y2x
    granger_result.direction = 'bidirectional';
elseif granger_result.is_significant_x2y
    granger_result.direction = 'x_to_y';
elseif granger_result.is_significant_y2x
    granger_result.direction = 'y_to_x';
else
    granger_result.direction = 'none';
end
granger_result.aic_values = aic_vals;
granger_result.bic_values = bic_vals;
granger_result.estimation_time = datetime('now');

end

%% 辅助函数：为VAR模型创建滞后数据矩阵
function [X_lagged, Y_lagged, T_effective] = create_lagged_matrix_for_var(X, Y, lag)
% CREATE_LAGGED_MATRIX_FOR_VAR 为双变量VAR模型创建滞后矩阵
% 输入: X, Y (列向量), lag (滞后阶数)
% 输出: 
%   X_lagged: (T-lag)×lag 矩阵, 第j列为 X(t-j)
%   Y_lagged: (T-lag)×lag 矩阵, 第j列为 Y(t-j)
%   T_effective: 有效样本数 T-lag
    
    T = length(X);
    T_effective = T - lag;
    
    X_lagged = zeros(T_effective, lag);
    Y_lagged = zeros(T_effective, lag);
    
    for l = 1:lag
        X_lagged(:, l) = X(lag+1-l:end-l);
        Y_lagged(:, l) = Y(lag+1-l:end-l);
    end
end

function effect_size = calculate_effect_size(X, Y, lag)
% 计算因果效应的标准化大小
    
    if lag < 1 || isnan(lag)
        effect_size = NaN;
        return;
    end
    
    T = length(Y);
    n_obs = T - lag;
    
    % 创建滞后矩阵
    Y_lags = zeros(n_obs, lag);
    X_lags = zeros(n_obs, lag);
    
    for l = 1:lag
        Y_lags(:, l) = Y(lag+1-l:end-l);
        X_lags(:, l) = X(lag+1-l:end-l);
    end
    
    % 构建设计矩阵
    X_design = [ones(n_obs, 1), Y_lags, X_lags];
    
    % 拟合模型
    beta = (X_design' * X_design) \ (X_design' * Y(lag+1:end));
    
    % 提取X的系数（标准化后的）
    if length(beta) > lag + 1
        effect_size = beta(end);  % 最后一个X的系数
    else
        effect_size = NaN;
    end
end

function nonlinear_result = check_nonlinear_granger(X, Y, granger_linear_result, params)
% CHECK_NONLINEAR_GRANGER 非线性Granger因果关系检测（重构版，用于集成）
% 本版本已重构，用于与新版 `perform_granger_causality_test` 函数集成。
%
% 【核心功能】检测线性Granger检验不显著的残差中是否存在非线性依赖，
% 从而识别“纯粹”的非线性因果关系。
%
% 【输入参数】
%   X, Y: 已标准化和平稳化处理后的输入时间序列（列向量）
%   granger_linear_result: 新版 `perform_granger_causality_test` 函数的输出结果
%   params: 参数结构体，应包含：
%       .significance_level: 显著性水平
%       .bds_m: BDS检验嵌入维度数组
%       .bds_epsilon: BDS检验距离阈值数组
%       .verbose: 是否显示详细输出
%
% 【输出参数】
%   nonlinear_result: 结构体，包含以下字段：
%     .x2y_nonlinear: 布尔值，X->Y方向是否存在纯粹非线性因果关系
%     .y2x_nonlinear: 布尔值，Y->X方向是否存在纯粹非线性因果关系
%     .bds_stats_x2y: X->Y方向BDS统计量矩阵
%     .bds_pvals_x2y: X->Y方向BDS检验p值矩阵
%     .bds_stats_y2x: Y->X方向BDS统计量矩阵
%     .bds_pvals_y2x: Y->X方向BDS检验p值矩阵
%     .var_residuals_x: VAR模型在X方程上的残差
%     .var_residuals_y: VAR模型在Y方程上的残差
%     .estimation_success: 布尔值，模型估计是否成功
%     .test_summary: 文本摘要

    %% 1. 参数初始化与验证
    if nargin < 4
        error('需要4个输入参数: X, Y, granger_linear_result, params');
    end
    
    default_params.significance_level = 0.05;
    default_params.bds_m = 2:5;
    default_params.bds_epsilon = [];
    default_params.verbose = false;
    
    params = merge_structs(default_params, params);
    
    alpha = params.significance_level;
    bds_m = params.bds_m;
    bds_epsilon = params.bds_epsilon;
    verbose = params.verbose;
    
    % 初始化输出结构
    nonlinear_result = struct();
    nonlinear_result.x2y_nonlinear = false;
    nonlinear_result.y2x_nonlinear = false;
    nonlinear_result.estimation_success = false;
    nonlinear_result.test_summary = '';

    %% 2. 准备VAR模型滞后阶数
    % 从线性Granger结果中获取统一的最优滞后
    if ~isfield(granger_linear_result, 'optimal_lag')
        if verbose
            fprintf('线性Granger结果中未找到optimal_lag字段，使用滞后1。');
        end
        var_lag = 1;
    else
        var_lag = granger_linear_result.optimal_lag;
        if var_lag < 1
            var_lag = 1;
        end
    end
    
    %% 3. 拟合双变量VAR模型并提取残差
    if verbose
        fprintf('    [非线性检测] 拟合VAR(%d)模型...\n', var_lag);
    end
    
    try
        % 调用重构的VAR拟合函数
        var_model = fit_bivariate_var(X, Y, var_lag);
        
        if ~var_model.estimation_success
            error('VAR模型拟合失败');
        end
        
        residuals_x = var_model.residuals_x;
        residuals_y = var_model.residuals_y;
        
        nonlinear_result.var_residuals_x = residuals_x;
        nonlinear_result.var_residuals_y = residuals_y;
        nonlinear_result.estimation_success = true;
        
        if verbose
            fprintf('      模型拟合成功，残差标准差: X=%.4f, Y=%.4f\n', ...
                std(residuals_x), std(residuals_y));
        end
        
    catch ME
        if verbose
            fprintf('    [非线性检测] VAR模型拟合失败: %s\n', ME.message);
        end
        nonlinear_result.test_summary = sprintf('VAR拟合失败: %s', ME.message);
        return; % 模型拟合失败，直接返回
    end
    
    %% 4. 对残差进行BDS检验 (检验非线性)
    if verbose
        fprintf('    [非线性检测] 执行BDS检验 (m=%s)...\n', mat2str(bds_m));
    end
    
    % 设置BDS的epsilon参数（如果未提供）
    if isempty(bds_epsilon)
        data_std = std([residuals_x; residuals_y]);
        bds_epsilon = [0.5, 1.0, 1.5] * data_std;
    end
    
    try
        % 检验X->Y方向 (检验X的残差)
        [bds_stats_x2y, bds_pvals_x2y] = perform_bds_test(residuals_x, bds_m, bds_epsilon);
        nonlinear_result.bds_stats_x2y = bds_stats_x2y;
        nonlinear_result.bds_pvals_x2y = bds_pvals_x2y;
        
        % 判断X->Y方向是否存在显著非线性
        % 逻辑: 如果任一(m, epsilon)组合下的p值 < alpha，则认为存在非线性
        is_nonlinear_x2y = any(bds_pvals_x2y(:) < alpha);
        nonlinear_result.x2y_nonlinear = is_nonlinear_x2y;
        
    catch ME
        if verbose
            fprintf('    [非线性检测] X->Y方向BDS检验失败: %s\n', ME.message);
        end
        nonlinear_result.x2y_nonlinear = false;
    end
    
    try
        % 检验Y->X方向 (检验Y的残差)
        [bds_stats_y2x, bds_pvals_y2x] = perform_bds_test(residuals_y, bds_m, bds_epsilon);
        nonlinear_result.bds_stats_y2x = bds_stats_y2x;
        nonlinear_result.bds_pvals_y2x = bds_pvals_y2x;
        
        is_nonlinear_y2x = any(bds_pvals_y2x(:) < alpha);
        nonlinear_result.y2x_nonlinear = is_nonlinear_y2x;
        
    catch ME
        if verbose
            fprintf('    [非线性检测] Y->X方向BDS检验失败: %s\n', ME.message);
        end
        nonlinear_result.y2x_nonlinear = false;
    end
    
    %% 5. 生成结果摘要
    summary_parts = {};
    if nonlinear_result.x2y_nonlinear
        summary_parts{end+1} = 'X→Y(非线性)';
    end
    if nonlinear_result.y2x_nonlinear
        summary_parts{end+1} = 'Y→X(非线性)';
    end
    
    if isempty(summary_parts)
        nonlinear_result.test_summary = '无非线性因果关系';
    else
        nonlinear_result.test_summary = strjoin(summary_parts, ', ');
    end
    
    if verbose
        if nonlinear_result.x2y_nonlinear || nonlinear_result.y2x_nonlinear
            fprintf('    [非线性检测] 发现非线性关系: %s\n', nonlinear_result.test_summary);
        else
            fprintf('    [非线性检测] 未发现显著非线性关系\n');
        end
    end
end

%% ========== 辅助函数1: 合并结构体 ==========
function S = merge_structs(S1, S2)
% 将S2的字段合并到S1，S2中的字段覆盖S1中的同名字段
    S = S1;
    fields = fieldnames(S2);
    for i = 1:length(fields)
        S.(fields{i}) = S2.(fields{i});
    end
end

%% ========== 辅助函数2: 拟合双变量VAR模型 ==========
function var_model = fit_bivariate_var(X, Y, p)
% FIT_BIVARIATE_VAR 拟合双变量VAR(p)模型
% 输入: X, Y (T×1向量), p (滞后阶数)
% 输出: 结构体 var_model
%   .coefficients: (2p+1)×2 系数矩阵
%   .residuals_x: X方程的残差
%   .residuals_y: Y方程的残差
%   .r2_x: X方程的R方
%   .r2_y: Y方程的R方
%   .estimation_success: 布尔值
    
    T = length(X);
    if length(Y) ~= T
        error('序列长度必须相等');
    end
    
    var_model = struct();
    var_model.estimation_success = false;
    
    if p >= T/2
        fprintf('滞后阶数p=%d 相对于样本量T=%d 过高', p, T);
        return;
    end
    
    % 创建滞后数据矩阵
    n_obs = T - p;
    Z = ones(n_obs, 1); % 常数项
    for lag = 1:p
        Z = [Z, X(p+1-lag:end-lag), Y(p+1-lag:end-lag)];
    end
    
    % 响应变量
    Y_response = [X(p+1:end), Y(p+1:end)];
    
    try
        % 多元最小二乘估计
        B = (Z' * Z) \ (Z' * Y_response);
        residuals = Y_response - Z * B;
        
        % 保存结果
        var_model.coefficients = B;
        var_model.residuals_x = residuals(:, 1);
        var_model.residuals_y = residuals(:, 2);
        
        % 计算R方
        TSS_x = sum((X(p+1:end) - mean(X(p+1:end))).^2);
        TSS_y = sum((Y(p+1:end) - mean(Y(p+1:end))).^2);
        RSS_x = sum(var_model.residuals_x.^2);
        RSS_y = sum(var_model.residuals_y.^2);
        
        var_model.r2_x = 1 - RSS_x/TSS_x;
        var_model.r2_y = 1 - RSS_y/TSS_y;
        var_model.estimation_success = true;
        
    catch ME
        if ~isempty(which('verbosedisp'))
            fprintf('VAR模型估计失败: %s', ME.message);
        end
    end
end

%% ========== 辅助函数3: 执行BDS检验 ==========
function [bds_stats, bds_pvals] = perform_bds_test(series, m_values, epsilon_values)
% PERFORM_BDS_TEST 执行BDS检验 (Brock-Dechert-Scheinkman test)
% 这是一个简化的BDS检验实现，用于检测序列的非线性/随机性。
% 注意: 生产环境应使用成熟的统计工具箱实现。
%
% 输入:
%   series: 时间序列 (向量)
%   m_values: 嵌入维度数组，如 [2,3,4,5]
%   epsilon_values: 距离阈值数组，如 [0.5, 1.0, 1.5]*std(series)
%
% 输出:
%   bds_stats: 统计量矩阵 (length(m_values) × length(epsilon_values))
%   bds_pvals: p值矩阵，同上
    
    n = length(series);
    n_m = length(m_values);
    n_eps = length(epsilon_values);
    
    bds_stats = zeros(n_m, n_eps);
    bds_pvals = zeros(n_m, n_eps);
    
    for i_m = 1:n_m
        m = m_values(i_m);
        if m >= n/2
            bds_stats(i_m, :) = NaN;
            bds_pvals(i_m, :) = NaN;
            continue;
        end
        
        for i_eps = 1:n_eps
            epsilon = epsilon_values(i_eps);
            
            % 计算关联积分 C(m, epsilon)
            C_m = compute_correlation_integral(series, m, epsilon);
            C_1 = compute_correlation_integral(series, 1, epsilon);
            
            % 计算BDS统计量
            if C_1 > 0 && C_m > 0
                % 简化计算，实际BDS统计量有更复杂的方差公式
                sigma_m = sqrt(4 * sum((1:n).^(-1))); % 近似标准差
                bds_stat = sqrt(n) * (C_m - C_1^m) / sigma_m;
                bds_stats(i_m, i_eps) = bds_stat;
                % 双尾检验p值
                bds_pvals(i_m, i_eps) = 2 * (1 - normcdf(abs(bds_stat)));
            else
                bds_stats(i_m, i_eps) = NaN;
                bds_pvals(i_m, i_eps) = NaN;
            end
        end
    end
end

%% ========== 辅助函数4: 计算关联积分 ==========
function C = compute_correlation_integral(series, m, epsilon)
% 计算关联积分 C(m, epsilon)
% 定义为: 序列m维嵌入中，距离小于epsilon的点对比例
    
    n = length(series);
    if m >= n
        C = 0;
        return;
    end
    
    % 创建m维嵌入向量
    embedded = zeros(n - m + 1, m);
    for i = 1:m
        embedded(:, i) = series(i:end-m+i);
    end
    
    n_points = size(embedded, 1);
    count = 0;
    
    % 简化计算: 随机抽样比较以提高速度
    max_pairs = min(1000, n_points*(n_points-1)/2);
    for k = 1:max_pairs
        i = randi(n_points);
        j = randi(n_points);
        if i ~= j
            dist = max(abs(embedded(i, :) - embedded(j, :)));
            if dist < epsilon
                count = count + 1;
            end
        end
    end
    
    C = count / max_pairs;
end
