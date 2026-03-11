function [markov_results, validation_results] = analyze_network_markov_basic(network_series, varargin)
% ANALYZE_NETWORK_MARKOV_BASIC - 网络马尔科夫分析（第一阶段：基础二状态模型）
% 
% 【功能描述】
% 对网络时间序列进行基础马尔科夫分析，使用二状态模型验证马尔科夫性质。
% 这是马尔科夫分析的第一阶段，验证马尔科夫模型在您的网络中是否适用。
%
% 【输入参数】
%   network_series: 网络时间序列结构体数组
%       network_series(i).adjacency: 第i个时间点的邻接矩阵
%       network_series(i).timestamp: 时间戳
%       network_series(i).node_labels: 节点标签
%   varargin: 可选参数
%       'StateDefinition': 状态定义方法 ('density'(默认), 'connectivity', 'custom')
%       'DensityThreshold': 密度阈值 (默认: 中位数)
%       'ValidationMethod': 验证方法 ('chi2'(默认), 'lrt', 'bootstrap')
%       'NumLags': 检验滞后阶数 (默认: 1)
%       'SignificanceLevel': 显著性水平 (默认: 0.05)
%       'Verbose': 是否显示处理信息 (默认: true)
%
% 【输出参数】
%   markov_results: 马尔科夫分析结果结构体
%       .transition_matrix: 状态转移概率矩阵
%       .steady_state: 稳态分布
%       .state_sequence: 状态序列
%       .state_durations: 各状态持续时间统计
%       .markov_property_passed: 马尔科夫性质是否通过检验
%   validation_results: 验证结果结构体
%
% 【算法原理】
% 1. 基于网络密度定义二状态（高密度/低密度）
% 2. 估计状态转移概率矩阵
% 3. 检验马尔科夫性质（无记忆性）
% 4. 计算稳态分布
%
% 【调用示例】
%   % 基本调用
%   [results, validation] = analyze_network_markov_basic(network_series);
%   
%   % 自定义参数
%   [results, validation] = analyze_network_markov_basic(network_series, ...
%       'StateDefinition', 'density', ...
%       'DensityThreshold', 0.2, ...
%       'ValidationMethod', 'bootstrap', ...
%       'Verbose', true);

    %% 1. 参数解析
    fprintf('【马尔科夫分析 - 第一阶段】开始运行...\n');
    start_time = tic;
    
    p = inputParser;
    addRequired(p, 'network_series', @(x) isstruct(x) && ~isempty(x));
    addParameter(p, 'StateDefinition', 'density', ...
        @(x) ismember(x, {'density', 'connectivity', 'custom'}));
    addParameter(p, 'DensityThreshold', 'median', ...
        @(x) isnumeric(x) || strcmp(x, 'median'));
    addParameter(p, 'ValidationMethod', 'chi2', ...
        @(x) ismember(x, {'chi2', 'lrt', 'bootstrap'}));
    addParameter(p, 'NumLags', 1, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'SignificanceLevel', 0.05, @(x) isnumeric(x) && x > 0 && x < 1);
    addParameter(p, 'Verbose', true, @islogical);
    p.parse(network_series, varargin{:});
    
    opts = p.Results;
    n_periods = length(network_series);
    
    if opts.Verbose
        fprintf('分析参数:\n');
        fprintf('  时间序列长度: %d 个时期\n', n_periods);
        fprintf('  状态定义方法: %s\n', opts.StateDefinition);
        fprintf('  验证方法: %s\n', opts.ValidationMethod);
        fprintf('  显著性水平: %.3f\n', opts.SignificanceLevel);
        fprintf('\n');
    end
    
    %% 2. 数据准备
    if opts.Verbose
        fprintf('步骤1: 准备网络时间序列数据...\n');
    end
    
    % 计算每个时间点的网络特征
    network_features = extract_network_features_series(network_series, opts.Verbose);
    
    %% 3. 状态定义
    if opts.Verbose
        fprintf('步骤2: 定义网络状态...\n');
    end
    
    [state_sequence, state_info] = define_basic_states(...
        network_features, opts.StateDefinition, opts.DensityThreshold, opts.Verbose);
    
    %% 4. 估计转移概率矩阵
    if opts.Verbose
        fprintf('步骤3: 估计状态转移概率矩阵...\n');
    end
    
    transition_matrix = estimate_transition_matrix(state_sequence, opts.Verbose);
    
    %% 5. 检验马尔科夫性质
    if opts.Verbose
        fprintf('步骤4: 检验马尔科夫性质...\n');
    end
    
    [markov_property_passed, test_stats] = validate_markov_property(...
        state_sequence, transition_matrix, opts.ValidationMethod, ...
        opts.NumLags, opts.SignificanceLevel, opts.Verbose);
    
    %% 6. 计算稳态分布
    if opts.Verbose
        fprintf('步骤5: 计算稳态分布...\n');
    end
    
    steady_state = calculate_steady_state_distribution(transition_matrix, opts.Verbose);
    
    %% 7. 计算状态持续时间统计
    if opts.Verbose
        fprintf('步骤6: 计算状态持续时间统计...\n');
    end
    
    state_durations = calculate_state_durations(state_sequence, state_info, opts.Verbose);
    
    %% 8. 组织结果
    markov_results = struct();
    markov_results.transition_matrix = transition_matrix;
    markov_results.steady_state = steady_state;
    markov_results.state_sequence = state_sequence;
    markov_results.state_info = state_info;
    markov_results.state_durations = state_durations;
    markov_results.markov_property_passed = markov_property_passed;
    markov_results.network_features = network_features;
    
    validation_results = struct();
    validation_results.test_stats = test_stats;
    validation_results.validation_method = opts.ValidationMethod;
    validation_results.significance_level = opts.SignificanceLevel;
    
    %% 9. 生成分析报告
    if opts.Verbose
        fprintf('步骤7: 生成分析报告...\n');
    end
    
    markov_results.analysis_report = generate_markov_analysis_report(...
        markov_results, validation_results, n_periods);
    
    %% 10. 完成
    markov_results.computation_time = toc(start_time);
    markov_results.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    markov_results.analysis_stage = 'phase1_basic';
    
    if opts.Verbose
        fprintf('\n【马尔科夫分析完成】\n');
        fprintf('总耗时: %.2f 秒\n', markov_results.computation_time);
        fprintf('马尔科夫性质检验: %s\n', ...
            bool2str(markov_results.markov_property_passed));
        
        if markov_property_passed
            fprintf('? 通过马尔科夫性质检验，模型适用\n');
        else
            fprintf('??  未通过马尔科夫性质检验，模型可能不适用\n');
        end
    end
end