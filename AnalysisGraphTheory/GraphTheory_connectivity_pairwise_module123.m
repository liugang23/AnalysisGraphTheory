function [pairwise_results, pair_network] = GraphTheory_connectivity_pairwise_module(...
    pair_data, pair_info, analysis_type, varargin)
% 配对连通性分析主函数
%
% 功能：对生成的配对进行多种连通性分析
%
% 输入：
%   pair_data    : 1×M cell，来自generate_complete_cross_pairs的输出
%   pair_labels  : 1×M cell，配对标签
%   analysis_type: 分析类型，可选：
%                  'correlation' - 相关系数
%                  'granger'     - Granger因果检验
%                  'transfer_entropy' - 转移熵
%                  'cross_correlation' - 互相关系数
%                  'all'        - 所有方法
%
% 可选参数（名称-值对）：
%   'max_lag'    : 最大滞后阶数（默认：5）
%   'significance_level': 显著性水平（默认：0.05）
%   'bootstrap_reps': 自助法重复次数（默认：1000）
%
% 输出：
%   pairwise_results : M×1 结构数组，每个配对的分析结果
%   pair_network     : 结构体，配对网络整体特征
%
% 科学逻辑：
%   1. 分别分析每个收益-成交量配对的关系
%   2. 计算多种连通性指标
%   3. 构建配对网络，识别关键路径
%

% 输入验证
if nargin < 3
    error('至少需要3个输入参数：paired_data, pair_info, analysis_type');
end

% 从 pair_info 中提取 pair_labels
if isfield(pair_info, 'pair_descriptions')
    pair_labels = pair_info.pair_descriptions;  % 使用中文描述
elseif isfield(pair_info, 'pairs')
    % 从 pairs 生成标签
    pair_labels = cell(1, length(pair_info.pairs));
    for i = 1:length(pair_info.pairs)
        pair_labels{i} = sprintf('%s→%s', ...
            pair_info.pairs{i}{1}, pair_info.pairs{i}{2});
    end
else
    error('pair_info 必须包含 pairs 或 pair_descriptions 字段');
end

%% 参数设置和校验
p = inputParser;
validAnalysisTypes = {'correlation', 'granger', 'transfer_entropy', 'cross_correlation', 'all'};
addRequired(p, 'pair_data', @iscell);
addRequired(p, 'pair_labels', @iscell);
addRequired(p, 'analysis_type', @(x) any(validatestring(x, validAnalysisTypes)));
addParameter(p, 'max_lag', 5, @isnumeric);
addParameter(p, 'significance_level', 0.05, @isnumeric);
addParameter(p, 'bootstrap_reps', 1000, @isnumeric);
parse(p, pair_data, pair_labels, analysis_type, varargin{:});

% 提取参数
max_lag = p.Results.max_lag;
alpha = p.Results.significance_level;
n_bootstrap = p.Results.bootstrap_reps;
analysis_type = p.Results.analysis_type;

% 检查数据一致性
n_pairs = length(pair_data);
if n_pairs ~= length(pair_labels)
    error('pair_data和pair_labels长度不一致');
end

fprintf('\n========================================\n');
fprintf('开始配对连通性分析\n');
fprintf('分析类型: %s\n', analysis_type);
fprintf('配对数量: %d\n', n_pairs);
fprintf('最大滞后阶数: %d\n', max_lag);
fprintf('显著性水平: %.3f\n', alpha);
fprintf('========================================\n\n');

%% 初始化结果结构
pairwise_results = struct();
pairwise_results.pair_info = cell(n_pairs, 1);
pairwise_results.connectivity = cell(n_pairs, 1);
pairwise_results.significance = cell(n_pairs, 1);
pairwise_results.lag_info = cell(n_pairs, 1);

%% 逐个配对分析
for i = 1:n_pairs
    fprintf('分析配对 %2d/%2d: %s\n', i, n_pairs, pair_labels{i});
    
    % 提取当前配对数据
    current_pair = pair_data{i};
%    ret_series = current_pair.ret_data;
%    obv_series = current_pair.obv_data;
    ret_series = current_pair(:, 1);  % 第一列
    obv_series = current_pair(:, 2);  % 第二列
    
    % 去除NaN
    valid_idx = ~isnan(ret_series) & ~isnan(obv_series);
    if sum(valid_idx) < 20
        warning('配对 %s 有效观测值不足20个，跳过', pair_labels{i});
        continue;
    end
    
    ret_clean = ret_series(valid_idx);
    obv_clean = obv_series(valid_idx);
    n_obs = length(ret_clean);
    
    % 计算相关系数
    if n_obs >= 2
        try
            corr_matrix = corrcoef(ret_clean, obv_clean, 'Rows', 'complete');
            corr_value = corr_matrix(1, 2);
        catch
            corr_value = NaN;
        end
    else
        corr_value = NaN;
    end
    
    % 保存配对信息
    pairwise_results.pair_info{i} = struct(...
        'label', pair_labels{i}, ...
        'ret_name', pair_info.pairs{i}{1}, ...                      % 从 pair_info 获取
        'obv_name', pair_info.pairs{i}{2}, ...                      % 从 pair_info 获取
        'pair_description', pair_info.pair_descriptions{i}, ...     % 中文描述
        'pair_type', pair_info.pair_types{i}, ...                   % 关系类型
        'ret_idx', pair_info.pair_indices(i, 1), ...                % 索引信息
        'obv_idx', pair_info.pair_indices(i, 2), ...                # 索引信息
        'n_obs', n_obs, ...
        'correlation', corr_value);  % 从分析结果获取
    
    % 根据分析类型选择方法
    switch analysis_type
        case 'correlation'
            result = analyze_correlation(ret_clean, obv_clean, alpha, n_bootstrap);
            
        case 'granger'
            result = analyze_granger_causality(ret_clean, obv_clean, max_lag, alpha);
            
        case 'transfer_entropy'
            result = analyze_transfer_entropy(ret_clean, obv_clean, max_lag);
            
        case 'cross_correlation'
            result = analyze_cross_correlation(ret_clean, obv_clean, max_lag, alpha);
            
        case 'all'
            % 执行所有分析
            result_all = struct();
            result_all.correlation = analyze_correlation(ret_clean, obv_clean, alpha, n_bootstrap);
            result_all.granger = analyze_granger_causality(ret_clean, obv_clean, max_lag, alpha);
            result_all.cross_correlation = analyze_cross_correlation(ret_clean, obv_clean, max_lag, alpha);
            result = result_all;
    end
    
    % 保存结果
    pairwise_results.connectivity{i} = result;
    
    % 计算显著性
    pairwise_results.significance{i} = calculate_significance(result, analysis_type, alpha);
    
    % 提取滞后信息
    pairwise_results.lag_info{i} = extract_lag_info(result, analysis_type);
    
    % 显示简要结果
    display_pair_result(i, pair_labels{i}, result, analysis_type);
end

%% 构建配对网络
fprintf('\n构建配对网络...\n');
pair_network = build_pair_network_complete(pairwise_results, pair_data, analysis_type, alpha);

%% 网络分析
fprintf('\n进行网络分析...\n');
pair_network = analyze_pair_network(pair_network);

%% 生成摘要报告
%fprintf('\n生成分析报告...\n');
%summary_report = generate_summary_report(pairwise_results, pair_network, analysis_type);

% 保存到输出
% pairwise_results.summary = summary_report;
pairwise_results.network = pair_network;
pairwise_results.analysis_type = analysis_type;
pairwise_results.parameters = struct(...
    'max_lag', max_lag, ...
    'significance_level', alpha, ...
    'bootstrap_reps', n_bootstrap);

fprintf('\n========================================\n');
fprintf('配对连通性分析完成\n');
fprintf('========================================\n');

end

function result = analyze_granger_causality(x, y, max_lag, alpha)
% Granger因果检验分析
%
% 输入：
%   x, y: 两个时间序列
%   max_lag: 最大滞后阶数
%   alpha: 显著性水平
%
% 输出：
%   result: 包含Granger因果检验结果的结构体
%

    %% 数据准备
    n = length(x);
    if n ~= length(y)
        error('序列长度不一致');
    end

    % 标准化（可选，Granger因果对尺度不敏感）
    x_norm = (x - mean(x)) / std(x);
    y_norm = (y - mean(y)) / std(y);

    %% 确定最优滞后阶数
    optimal_lag_x2y = 0;
    optimal_lag_y2x = 0;
    min_aic_x2y = Inf;
    min_aic_y2x = Inf;

    p_values_x2y = zeros(max_lag, 1);
    p_values_y2x = zeros(max_lag, 1);
    f_stats_x2y = zeros(max_lag, 1);
    f_stats_y2x = zeros(max_lag, 1);

    for lag = 1:max_lag
        % 检验 x 是否 Granger-cause y
        [~, p_x2y, fstat_x2y] = granger_cause_test(y_norm, x_norm, lag, n);
        p_values_x2y(lag) = p_x2y;
        f_stats_x2y(lag) = fstat_x2y;

        % 计算AIC
        [~, aic_x2y] = calculate_aic(y_norm, x_norm, lag);
        if aic_x2y < min_aic_x2y
            min_aic_x2y = aic_x2y;
            optimal_lag_x2y = lag;
        end

        % 检验 y 是否 Granger-cause x
        [~, p_y2x, fstat_y2x] = granger_cause_test(x_norm, y_norm, lag, n);
        p_values_y2x(lag) = p_y2x;
        f_stats_y2x(lag) = fstat_y2x;

        [~, aic_y2x] = calculate_aic(x_norm, y_norm, lag);
        if aic_y2x < min_aic_y2x
            min_aic_y2x = aic_y2x;
            optimal_lag_y2x = lag;
        end
    end

    %% 使用最优滞后进行最终检验
    % x -> y
    [h_x2y, p_x2y, fstat_x2y, crit_val_x2y] = granger_cause_test(...
        y_norm, x_norm, optimal_lag_x2y, n);

    % y -> x
    [h_y2x, p_y2x, fstat_y2x, crit_val_y2x] = granger_cause_test(...
        x_norm, y_norm, optimal_lag_y2x, n);

    %% 确定因果关系方向
    if h_x2y && ~h_y2x
        direction = 'x_to_y';  % x引导y
        causality_strength = 1;
    elseif ~h_x2y && h_y2x
        direction = 'y_to_x';  % y引导x
        causality_strength = -1;
    elseif h_x2y && h_y2x
        direction = 'bidirectional';  % 双向因果
        causality_strength = 0;  % 需要进一步判断强度
    else
        direction = 'no_causality';  % 无因果
        causality_strength = 0;
    end

    % 如果是双向，比较因果强度
    if strcmp(direction, 'bidirectional')
        % 使用F统计量比值
        if fstat_x2y > fstat_y2x
            causality_strength = fstat_x2y / (fstat_x2y + fstat_y2x);
        else
            causality_strength = -fstat_y2x / (fstat_x2y + fstat_y2x);
        end
    end

    %% 构建结果结构
    result = struct();
    result.direction = direction;
    result.causality_strength = causality_strength;
    result.optimal_lag_x2y = optimal_lag_x2y;
    result.optimal_lag_y2x = optimal_lag_y2x;
    result.p_value_x2y = p_x2y;
    result.p_value_y2x = p_y2x;
    result.f_statistic_x2y = fstat_x2y;
    result.f_statistic_y2x = fstat_y2x;
    result.significant_x2y = (p_x2y < alpha);
    result.significant_y2x = (p_y2x < alpha);
    result.all_p_values_x2y = p_values_x2y;
    result.all_p_values_y2x = p_values_y2x;
    result.all_f_stats_x2y = f_stats_x2y;
    result.all_f_stats_y2x = f_stats_y2x;
    result.test_statistics = struct(...
        'critical_value_x2y', crit_val_x2y, ...
        'critical_value_y2x', crit_val_y2x, ...
        'aic_x2y', min_aic_x2y, ...
        'aic_y2x', min_aic_y2x);

    % 计算因果净值（x对y的净影响）
    result.net_causality = fstat_x2y - fstat_y2x;

end

function [h, p, fstat, crit_val] = granger_cause_test(y, x, lag, n)
% 执行Granger因果检验
% 简化实现，实际中应使用更稳健的方法

    % 构建滞后矩阵
    ylags = zeros(n-lag, lag);
    xlags = zeros(n-lag, lag);
    y_current = y(lag+1:end);

    for l = 1:lag
        ylags(:, l) = y(l:n-lag+l-1);
        xlags(:, l) = x(l:n-lag+l-1);
    end

    % 受限模型（只包含y的滞后）
    X_restricted = [ones(n-lag, 1), ylags];
    beta_restricted = X_restricted \ y_current;
    resid_restricted = y_current - X_restricted * beta_restricted;
    RSS_restricted = sum(resid_restricted.^2);

    % 无限制模型（包含y和x的滞后）
    X_unrestricted = [ones(n-lag, 1), ylags, xlags];
    beta_unrestricted = X_unrestricted \ y_current;
    resid_unrestricted = y_current - X_unrestricted * beta_unrestricted;
    RSS_unrestricted = sum(resid_unrestricted.^2);

    % F检验
    df_num = lag;  % 限制的参数数量
    df_den = n - 2*lag - 1;  % 无限制模型的自由度

    fstat = ((RSS_restricted - RSS_unrestricted) / df_num) / (RSS_unrestricted / df_den);
    p = 1 - fcdf(fstat, df_num, df_den);
    crit_val = finv(1 - 0.05, df_num, df_den);
    h = (p < 0.05);

end

function [aic, bic] = calculate_aic(y, x, lag)
    % 计算AIC和BIC
    n = length(y);
    ylags = zeros(n-lag, lag);
    xlags = zeros(n-lag, lag);
    y_current = y(lag+1:end);

    for l = 1:lag
        ylags(:, l) = y(l:n-lag+l-1);
        xlags(:, l) = x(l:n-lag+l-1);
    end

    X = [ones(n-lag, 1), ylags, xlags];
    beta = X \ y_current;
    resid = y_current - X * beta;
    RSS = sum(resid.^2);

    k = size(X, 2);  % 参数数量
    aic = n * log(RSS/n) + 2*k;
    bic = n * log(RSS/n) + k * log(n);

end

%% ==================== 辅助函数 ====================

function [edge_added, edge_info] = process_correlation_edge(...
    connectivity_result, ret_idx, obv_idx, ret_name, obv_name, adjacency, weights, directions, significance, alpha, min_corr)
% 处理相关性边
%
% 输入:
%   connectivity_result: 连通性分析结果
%   ret_idx, obv_idx: 节点索引
%   ret_name, obv_name: 节点名称
%   adjacency, weights, directions, significance: 网络矩阵
%   alpha: 显著性水平
%   min_corr: 最小相关系数阈值
%
% 输出:
%   edge_added: 是否添加了边
%   edge_info: 边信息结构体
%

edge_added = false;
edge_info = struct();

% 检查相关性结果
if ~isfield(connectivity_result, 'correlation')
    return;
end

corr_result = connectivity_result.correlation;
if ~isstruct(corr_result) || ~isfield(corr_result, 'correlation') || ~isfield(corr_result, 'p_value')
    return;
end

corr_val = corr_result.correlation;
p_val = corr_result.p_value;

% 检查显著性
if abs(corr_val) >= min_corr && p_val < alpha
    edge_added = true;
    
    % 创建边信息
    edge_info.edge_id = sprintf('corr_%s_%s', ret_name, obv_name);
    edge_info.analysis_type = 'correlation';
    edge_info.from_node = ret_name;
    edge_info.to_node = obv_name;
    edge_info.from_idx = ret_idx;
    edge_info.to_idx = obv_idx;
    edge_info.direction = 'undirected';  % 相关性是无向的
    edge_info.weight = abs(corr_val);
    edge_info.original_correlation = corr_val;
    edge_info.p_value = p_val;
    edge_info.lag = 0;  % 相关性通常不考虑滞后
    edge_info.is_significant = true;
    edge_info.added = true;
    
    if ~isfield(corr_result, 'lag')
        edge_info.lag = 0;
    else
        edge_info.lag = corr_result.lag;
    end
end
end

function [edge_added, edge_info] = process_granger_edge(...
    connectivity_result, ret_idx, obv_idx, ret_name, obv_name, ...
    adjacency, weights, directions, lags, significance, alpha)
% 处理Granger因果边
%
% 输入输出参数同process_correlation_edge
%

    edge_added = false;
    edge_info = struct();

    % 检查Granger结果
    if ~isfield(connectivity_result, 'granger')
        return;
    end

    granger_result = connectivity_result.granger;
    if ~isstruct(granger_result) || ...
       ~isfield(granger_result, 'significant_x2y') || ...
       ~isfield(granger_result, 'significant_y2x')
        return;
    end

    sig_x2y = granger_result.significant_x2y;
    sig_y2x = granger_result.significant_y2x;

    % 判断连接方向
    if sig_x2y && ~sig_y2x
        % ret → OBV
        edge_added = true;
        edge_info = create_granger_edge_info(...
            'ret_to_obv', ret_name, obv_name, ret_idx, obv_idx, ...
            granger_result, alpha);

    elseif ~sig_x2y && sig_y2x
        % OBV → ret
        edge_added = true;
        edge_info = create_granger_edge_info(...
            'obv_to_ret', obv_name, ret_name, obv_idx, ret_idx, ...
            granger_result, alpha);

    elseif sig_x2y && sig_y2x
        % 双向
        edge_added = true;
        edge_info = create_bidirectional_edge_info(...
            ret_name, obv_name, ret_idx, obv_idx, granger_result, alpha);
    end
end

function edge_info = create_granger_edge_info(...
    direction, from_node, to_node, from_idx, to_idx, granger_result, alpha)
% 创建单向Granger边信息

    if strcmp(direction, 'ret_to_obv')
        weight = granger_result.f_statistic_x2y;
        p_val = granger_result.p_value_x2y;
        lag = granger_result.optimal_lag_x2y;
    else
        weight = granger_result.f_statistic_y2x;
        p_val = granger_result.p_value_y2x;
        lag = granger_result.optimal_lag_y2x;
    end

    edge_info = struct();
    edge_info.edge_id = sprintf('granger_%s_%s_%s', direction, from_node, to_node);
    edge_info.analysis_type = 'granger';
    edge_info.direction = direction;
    edge_info.from_node = from_node;
    edge_info.to_node = to_node;
    edge_info.from_idx = from_idx;
    edge_info.to_idx = to_idx;
    edge_info.weight = weight;
    edge_info.p_value = p_val;
    edge_info.lag = lag;
    edge_info.is_significant = p_val < alpha;
    edge_info.added = true;

    % 添加原始统计量
    if strcmp(direction, 'ret_to_obv')
        edge_info.f_statistic = granger_result.f_statistic_x2y;
        edge_info.p_value_original = granger_result.p_value_x2y;
        edge_info.optimal_lag = granger_result.optimal_lag_x2y;
    else
        edge_info.f_statistic = granger_result.f_statistic_y2x;
        edge_info.p_value_original = granger_result.p_value_y2x;
        edge_info.optimal_lag = granger_result.optimal_lag_y2x;
    end
end

function edge_info = create_bidirectional_edge_info(...
    ret_name, obv_name, ret_idx, obv_idx, granger_result, alpha)
% 创建双向Granger边信息

    edge_info = struct();
    edge_info.edge_id = sprintf('granger_bidirectional_%s_%s', ret_name, obv_name);
    edge_info.analysis_type = 'granger';
    edge_info.direction = 'bidirectional';
    edge_info.from_node = ret_name;
    edge_info.to_node = obv_name;
    edge_info.from_idx = ret_idx;
    edge_info.to_idx = obv_idx;
    edge_info.weight_ret_to_obv = granger_result.f_statistic_x2y;
    edge_info.weight_obv_to_ret = granger_result.f_statistic_y2x;
    edge_info.p_value_ret_to_obv = granger_result.p_value_x2y;
    edge_info.p_value_obv_to_ret = granger_result.p_value_y2x;
    edge_info.lag_ret_to_obv = granger_result.optimal_lag_x2y;
    edge_info.lag_obv_to_ret = granger_result.optimal_lag_y2x;
    edge_info.is_significant = true;
    edge_info.added = true;

    % 使用较小的p值作为该边的p值
    edge_info.p_value = min(granger_result.p_value_x2y, granger_result.p_value_y2x);
    edge_info.weight = max(granger_result.f_statistic_x2y, granger_result.f_statistic_y2x);
    edge_info.lag = max(granger_result.optimal_lag_x2y, granger_result.optimal_lag_y2x);
end

function [significance_result, lag_info] = calculate_significance(connectivity_result, analysis_type, alpha)
% 计算配对连通性结果的显著性
%
% 输入：
%   connectivity_result: 连通性分析结果结构体
%   analysis_type: 分析类型
%   alpha: 显著性水平
%
% 输出：
%   significance_result: 显著性判断结果
%   lag_info: 滞后信息
%

significance_result = false;
lag_info = struct();

switch analysis_type
    case 'correlation'
        if isfield(connectivity_result, 'correlation')
            p_val = connectivity_result.correlation.p_value;
            significance_result = (p_val < alpha);
            
            % 提取滞后信息（相关分析无滞后）
            lag_info.optimal_lag = 0;
            lag_info.max_corr_lag = connectivity_result.correlation.max_corr_lag;
        end
        
    case 'granger'
        if isfield(connectivity_result, 'direction')
            % Granger因果检验
            p_x2y = connectivity_result.p_value_x2y;
            p_y2x = connectivity_result.p_value_y2x;
            
            significance_x2y = (p_x2y < alpha);
            significance_y2x = (p_y2x < alpha);
            
            % 只要有一个方向显著，就认为是显著连接
            significance_result = significance_x2y || significance_y2x;
            
            lag_info.optimal_lag_x2y = connectivity_result.optimal_lag_x2y;
            lag_info.optimal_lag_y2x = connectivity_result.optimal_lag_y2x;
            lag_info.direction = connectivity_result.direction;
        end
        
    case 'cross_correlation'
        if isfield(connectivity_result, 'max_cross_corr')
            p_val = connectivity_result.p_value;
            significance_result = (p_val < alpha);
            
            lag_info.optimal_lag = connectivity_result.optimal_lag;
            lag_info.max_cross_corr = connectivity_result.max_cross_corr;
        end
        
    case 'all'
        % 对于综合分析，只要任一方法显著就认为是显著
        sig_flags = [];
        
        if isfield(connectivity_result, 'correlation')
            sig_flags = [sig_flags, connectivity_result.correlation.p_value < alpha];
        end
        
        if isfield(connectivity_result, 'granger')
            p_x2y = connectivity_result.granger.p_value_x2y;
            p_y2x = connectivity_result.granger.p_value_y2x;
            sig_flags = [sig_flags, p_x2y < alpha, p_y2x < alpha];
        end
        
        if isfield(connectivity_result, 'cross_correlation')
            sig_flags = [sig_flags, connectivity_result.cross_correlation.p_value < alpha];
        end
        
        significance_result = any(sig_flags);
        
        % 提取滞后信息
        lag_info = struct();
        if isfield(connectivity_result, 'granger')
            lag_info.granger_lag_x2y = connectivity_result.granger.optimal_lag_x2y;
            lag_info.granger_lag_y2x = connectivity_result.granger.optimal_lag_y2x;
        end
        if isfield(connectivity_result, 'cross_correlation')
            lag_info.ccf_lag = connectivity_result.cross_correlation.optimal_lag;
        end
        
    otherwise
        error('不支持的analysis_type: %s', analysis_type);
end

end

function display_pair_result(pair_idx, pair_label, result, analysis_type)
% 显示配对分析结果
fprintf('  ');
switch analysis_type
    case 'correlation'
        fprintf('相关系数: %.3f, p值: %.4f', ...
            result.correlation, result.p_value);
        if result.p_value < 0.05
            fprintf(' *');
        end
        if result.p_value < 0.01
            fprintf('*');
        end
        if result.p_value < 0.001
            fprintf('*');
        end
        
    case 'granger'
        fprintf('方向: %s, ', result.direction);
        fprintf('X→Y: p=%.4f (lag=%d), ', result.p_value_x2y, result.optimal_lag_x2y);
        fprintf('Y→X: p=%.4f (lag=%d)', result.p_value_y2x, result.optimal_lag_y2x);
        
    case 'cross_correlation'
        fprintf('最大互相关: %.3f (lag=%d), p=%.4f', ...
            result.max_cross_corr, result.optimal_lag, result.p_value);
            
    case 'all'
        fprintf('多方法结果: ');
        if isfield(result, 'correlation')
            fprintf('corr=%.3f(p=%.3f) ', result.correlation.correlation, result.correlation.p_value);
        end
        if isfield(result, 'granger')
            fprintf('granger=%s ', result.granger.direction);
        end
        if isfield(result, 'cross_correlation')
            fprintf('ccf=%.3f ', result.cross_correlation.max_cross_corr);
        end
end
fprintf('\n');
end

function network = analyze_pair_network(pair_network)
% 分析配对网络特征
    % 记录原始数据类型
    adj_original_type = class(pair_network.adjacency);
    weights_original_type = class(pair_network.weights);
    
    % 创建计算用的副本
    adjacency = pair_network.adjacency;      % 可能保持原始类型
    weights = pair_network.weights;          % 可能保持原始类型
    node_labels = pair_network.node_labels;
    n_nodes = pair_network.n_nodes;
    
    fprintf('网络分析 - 输入数据检查:\n');
    fprintf('  邻接矩阵: %s 类型, %dx%d 尺寸\n', ...
        adj_original_type, size(adjacency, 1), size(adjacency, 2));
    fprintf('  权重矩阵: %s 类型, %dx%d 尺寸\n', ...
        weights_original_type, size(weights, 1), size(weights, 2));
    
    % 1. 节点度分布（原始类型可计算）
    node_degrees = sum(adjacency, 2);
    
    % 对于加权度，确保权重是数值类型
    if ~isnumeric(weights)
        error('权重矩阵必须是数值类型，当前是 %s', class(weights));
    end
    weighted_degrees = sum(double(weights), 2);  % 转换为double求和

    % 2. 聚类系数
    clustering_coeffs = zeros(n_nodes, 1);
    for i = 1:n_nodes
        % 逻辑索引兼容多种数值类型
        neighbors = find(adjacency(i, :) > 0);
        k = length(neighbors);
        if k < 2
            clustering_coeffs(i) = 0;
        else
            % 计算邻居之间的实际边数
            subgraph = adjacency(neighbors, neighbors);
            actual_edges = sum(subgraph(:)) / 2;  % 无向图
            possible_edges = k * (k - 1) / 2;
            clustering_coeffs(i) = actual_edges / possible_edges;
        end
    end

    % 3. 中心性度量
    % 度中心性
    degree_centrality = node_degrees / (n_nodes - 1);

    % 特征向量中心性 - 需要double类型
    fprintf('计算特征向量中心性...\n');
    if ~isa(adjacency, 'double')
        fprintf('  转换邻接矩阵为double类型用于特征值计算\n');
        adjacency_for_eig = double(adjacency);
    else
        adjacency_for_eig = adjacency;
    end
    
    % 确保对称性
    if ~issymmetric(adjacency_for_eig)
        fprintf('  注意: 邻接矩阵不对称，进行对称化处理\n');
        adjacency_for_eig = max(adjacency_for_eig, adjacency_for_eig');
    end
    
    try
        [V, D] = eig(adjacency_for_eig);
        [~, idx] = max(diag(D));
        eigenvector_centrality = abs(V(:, idx));
    catch ME
        fprintf('警告: 特征值计算失败: %s\n', ME.message);
        fprintf('  使用度中心性作为替代\n');
        eigenvector_centrality = degree_centrality;
    end

    % 4. 社区检测（简单版）
    % 使用模块度最大化
    communities = detect_communities(adjacency_for_eig);

    % 5. 路径分析
    % 计算平均路径长度
    try
        distances = graphallshortestpaths(sparse(adjacency_for_eig), 'Directed', false);
        valid_distances = distances(distances < Inf & distances > 0);
        if ~isempty(valid_distances)
            average_path_length = mean(valid_distances);
        else
            average_path_length = Inf;
        end
    catch ME
        fprintf('警告: 路径分析失败: %s\n', ME.message);
        distances = [];
        average_path_length = Inf;
    end

    % 6. 网络密度
    possible_edges = n_nodes * (n_nodes - 1) / 2;
    actual_edges = sum(adjacency(:)) / 2;
    network_density = actual_edges / possible_edges;

    % 保存结果
    pair_network.network_stats = struct();
    pair_network.network_stats.node_degrees = node_degrees;
    pair_network.network_stats.weighted_degrees = weighted_degrees;
    pair_network.network_stats.clustering_coeffs = clustering_coeffs;
    pair_network.network_stats.degree_centrality = degree_centrality;
    pair_network.network_stats.eigenvector_centrality = eigenvector_centrality;
    pair_network.network_stats.communities = communities;
    pair_network.network_stats.average_path_length = average_path_length;
    pair_network.network_stats.network_density = network_density;
    
    if ~isempty(distances)
        pair_network.network_stats.diameter = max(distances(distances < Inf));
    else
        pair_network.network_stats.diameter = 0;
    end
    
    % 记录数据类型信息
    pair_network.network_stats.data_type_info = struct(...
        'adjacency_original_type', adj_original_type, ...
        'weights_original_type', weights_original_type, ...
        'adjacency_used_type', class(adjacency_for_eig));

    % 7. 分离收益和OBV的网络特征
    ret_nodes = pair_network.ret_nodes;
    obv_nodes = pair_network.obv_nodes;

    pair_network.ret_stats = struct();
    if ~isempty(ret_nodes)
        pair_network.ret_stats.avg_degree = mean(node_degrees(ret_nodes));
        pair_network.ret_stats.avg_clustering = mean(clustering_coeffs(ret_nodes));
    else
        pair_network.ret_stats.avg_degree = NaN;
        pair_network.ret_stats.avg_clustering = NaN;
    end

    pair_network.obv_stats = struct();
    if ~isempty(obv_nodes)
        pair_network.obv_stats.avg_degree = mean(node_degrees(obv_nodes));
        pair_network.obv_stats.avg_clustering = mean(clustering_coeffs(obv_nodes));
    else
        pair_network.obv_stats.avg_degree = NaN;
        pair_network.obv_stats.avg_clustering = NaN;
    end

    fprintf('网络分析完成:\n');
    fprintf('  节点数: %d\n', n_nodes);
    fprintf('  边数: %d\n', actual_edges);
    fprintf('  网络密度: %.3f\n', network_density);
    fprintf('  平均路径长度: %.3f\n', average_path_length);
    fprintf('  网络直径: %.3f\n', pair_network.network_stats.diameter);
    fprintf('  收益节点平均度: %.2f\n', pair_network.ret_stats.avg_degree);
    fprintf('  OBV节点平均度: %.2f\n', pair_network.obv_stats.avg_degree);
    
    % 显示类型转换信息
    if ~strcmp(adj_original_type, 'double')
        fprintf('  注意: 邻接矩阵从 %s 转换为 double 用于特征值计算\n', adj_original_type);
    end

    network = pair_network;
end

function communities = detect_communities(adjacency)
% 简单的社区检测算法（Louvain方法简化版）
    n_nodes = size(adjacency, 1);
    communities = (1:n_nodes)';  % 初始：每个节点一个社区

    % 简化版：基于连接密度合并社区
    max_iter = 10;
    for iter = 1:max_iter
        changed = false;
        for i = 1:n_nodes
            % 找到节点i的邻居
            neighbors = find(adjacency(i, :) > 0);
            if isempty(neighbors)
                continue;
            end

            % 计算节点i与各社区的连接强度
            unique_comms = unique(communities(neighbors));
            best_comm = communities(i);
            best_modularity_gain = 0;

            for comm = unique_comms'
                if comm == communities(i)
                    continue;
                end

                % 计算模块度增益（简化）
                gain = calculate_modularity_gain(i, comm, communities, adjacency);
                if gain > best_modularity_gain
                    best_modularity_gain = gain;
                    best_comm = comm;
                end
            end

            if best_comm ~= communities(i)
                communities(i) = best_comm;
                changed = true;
            end
        end

        if ~changed
            break;
        end
    end
end

function gain = calculate_modularity_gain(node, new_comm, communities, adjacency)
% 计算模块度增益（简化版）
    current_comm = communities(node);
    n_nodes = size(adjacency, 1);

    % 计算当前社区的模块度贡献
    ki = sum(adjacency(node, :));
    kj_in_current = 0;
    kj_in_new = 0;

    for j = 1:n_nodes
        if j == node
            continue;
        end

        kj = sum(adjacency(j, :));
        if communities(j) == current_comm
            kj_in_current = kj_in_current + kj;
        end
        if communities(j) == new_comm
            kj_in_new = kj_in_new + kj;
        end
    end

    % 简化模块度增益计算
    m = sum(adjacency(:)) / 2;
    gain = (kj_in_new - kj_in_current) / (2 * m);

end

function result = analyze_correlation(x, y, alpha, n_bootstrap)
% 相关系数分析
correlation = corr(x, y, 'rows', 'complete');
n = sum(~isnan(x) & ~isnan(y));

% 计算p值（t检验）
t_stat = correlation * sqrt((n-2) / (1-correlation^2));
p_value = 2 * (1 - tcdf(abs(t_stat), n-2));

% 自助法置信区间
if n_bootstrap > 0
    boot_corr = zeros(n_bootstrap, 1);
    for b = 1:n_bootstrap
        idx = randi(n, n, 1);
        boot_corr(b) = corr(x(idx), y(idx), 'rows', 'complete');
    end
    ci_lower = prctile(boot_corr, 100*alpha/2);
    ci_upper = prctile(boot_corr, 100*(1-alpha/2));
else
    ci_lower = NaN;
    ci_upper = NaN;
end

result = struct();
result.correlation = correlation;
result.p_value = p_value;
result.n_obs = n;
result.t_statistic = t_stat;
result.ci_lower = ci_lower;
result.ci_upper = ci_upper;
if n_bootstrap > 0
    result.bootstrapped_corr = boot_corr;
end
end

function result = analyze_cross_correlation(x, y, max_lag, alpha)
% 互相关系数分析
    x_clean = x(~isnan(x) & ~isnan(y));
    y_clean = y(~isnan(x) & ~isnan(y));
    n = length(x_clean);

    % 计算互相关系数
    ccf_values = zeros(2*max_lag+1, 1);
    p_values = zeros(2*max_lag+1, 1);
    lags = -max_lag:max_lag;

    for i = 1:length(lags)
        lag = lags(i);
        if lag < 0
            x_lagged = x_clean(1:end+lag);
            y_lead = y_clean(1-lag:end);
        elseif lag > 0
            x_lagged = x_clean(1+lag:end);
            y_lead = y_clean(1:end-lag);
        else
            x_lagged = x_clean;
            y_lead = y_clean;
        end

        [ccf, p] = corrcoef(x_lagged, y_lead, 'rows', 'complete');
        ccf_values(i) = ccf(1,2);
        p_values(i) = p(1,2);
    end

    % 找到最大互相关系数及其滞后
    [max_ccf, max_idx] = max(abs(ccf_values));
    optimal_lag = lags(max_idx);
    max_ccf_value = ccf_values(max_idx);
    max_ccf_p = p_values(max_idx);

    result = struct();
    result.ccf_values = ccf_values;
    result.p_values = p_values;
    result.lags = lags;
    result.max_cross_corr = max_ccf_value;
    result.optimal_lag = optimal_lag;
    result.p_value = max_ccf_p;
    result.significant_lags = lags(p_values < alpha);
end

function lag_info_struct = extract_lag_info(result, analysis_type)
% 从分析结果中提取滞后信息
%
% 输入：
%   result: 分析结果结构体
%   analysis_type: 分析类型
%
% 输出：
%   lag_info_struct: 滞后信息结构体
%

lag_info_struct = struct();

switch analysis_type
    case 'correlation'
        % 相关分析无滞后，但可能有最大相关滞后
        if isfield(result, 'max_corr_lag')
            lag_info_struct.optimal_lag = result.max_corr_lag;
        else
            lag_info_struct.optimal_lag = 0;
        end
        lag_info_struct.lag_type = 'correlation';
        
    case 'granger'
        % Granger因果检验滞后信息
        lag_info_struct.optimal_lag_x2y = result.optimal_lag_x2y;
        lag_info_struct.optimal_lag_y2x = result.optimal_lag_y2x;
        lag_info_struct.lag_type = 'granger';
        
        % 确定主导滞后
        if result.f_statistic_x2y > result.f_statistic_y2x
            lag_info_struct.dominant_lag = result.optimal_lag_x2y;
            lag_info_struct.dominant_direction = 'x_to_y';
        else
            lag_info_struct.dominant_lag = result.optimal_lag_y2x;
            lag_info_struct.dominant_direction = 'y_to_x';
        end
        
    case 'cross_correlation'
        % 互相关系数滞后信息
        lag_info_struct.optimal_lag = result.optimal_lag;
        lag_info_struct.max_cross_corr = result.max_cross_corr;
        lag_info_struct.lag_type = 'cross_correlation';
        lag_info_struct.significant_lags = result.significant_lags;
        
    case 'all'
        % 综合分析的滞后信息
        lag_info_struct = struct();
        
        if isfield(result, 'correlation')
            if isfield(result.correlation, 'max_corr_lag')
                lag_info_struct.corr_lag = result.correlation.max_corr_lag;
            else
                lag_info_struct.corr_lag = 0;
            end
        end
        
        if isfield(result, 'granger')
            lag_info_struct.granger_lag_x2y = result.granger.optimal_lag_x2y;
            lag_info_struct.granger_lag_y2x = result.granger.optimal_lag_y2x;
            
            % 判断主导滞后
            if result.granger.f_statistic_x2y > result.granger.f_statistic_y2x
                lag_info_struct.dominant_granger_lag = result.granger.optimal_lag_x2y;
                lag_info_struct.dominant_granger_direction = 'x_to_y';
            else
                lag_info_struct.dominant_granger_lag = result.granger.optimal_lag_y2x;
                lag_info_struct.dominant_granger_direction = 'y_to_x';
            end
        end
        
        if isfield(result, 'cross_correlation')
            lag_info_struct.ccf_lag = result.cross_correlation.optimal_lag;
            lag_info_struct.max_ccf = result.cross_correlation.max_cross_corr;
        end
        
        % 确定最终滞后（优先使用Granger滞后，如果可用）
        if isfield(lag_info_struct, 'dominant_granger_lag')
            lag_info_struct.final_lag = lag_info_struct.dominant_granger_lag;
            lag_info_struct.final_method = 'granger';
        elseif isfield(lag_info_struct, 'ccf_lag')
            lag_info_struct.final_lag = lag_info_struct.ccf_lag;
            lag_info_struct.final_method = 'cross_correlation';
        else
            lag_info_struct.final_lag = lag_info_struct.corr_lag;
            lag_info_struct.final_method = 'correlation';
        end
        
    otherwise
        warning('不支持的analysis_type: %s', analysis_type);
        lag_info_struct.optimal_lag = NaN;
        lag_info_struct.lag_type = 'unknown';
end
end
