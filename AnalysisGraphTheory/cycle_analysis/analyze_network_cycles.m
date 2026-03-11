function cycle_analysis_results = analyze_network_cycles(pair_network, varargin)
% ANALYZE_NETWORK_CYCLES - 环结构分析主函数
% 
% 【功能描述】
% 执行完整的网络环结构分析，包括简单环检测、三角形闭合、有向环分析、反馈回路识别、
% 环统计特征计算和环结构评估6个子模块。
%
% 【输入参数】
%   pair_network: 网络结构体，必须包含：
%       - adjacency: 邻接矩阵 (n×n)
%       - graph_type: 图类型 ('directed' 或 'undirected')
%       - node_labels: 节点标签 (可选)
%       - n_nodes: 节点数量
%   varargin: 可选参数
%       'MaxCycleLength': 最大环长度 (默认: 6  6指的是包含6个节点的闭环)
%            - 3: 只检测三角形（最基本的闭环）
%            - 4-6: 检测中等长度的环（常见业务循环）  关注短期反馈 4  % 检测三角形和四边形；平衡检测范围 6  % 检测中等长度环
%            - 7-10: 检测较长的循环（复杂的反馈机制） 全面分析  8  % 检测较长反馈环  在金融网络中，超过8个节点的环通常过于复杂，难以解释
%            - >10: 通常过于复杂，计算量大且意义有限
%       'EnableTriangleAnalysis': 是否启用三角形分析 (默认: true)
%       'EnableFeedbackLoops': 是否启用反馈回路分析 (默认: true)
%       'CycleDetectionMethod': 环检测方法 
%            'dfs'   默认，对于无向图（相关性网络） 简单高效
%            'johnson'  对于有向图（Granger因果网络） 专门优化有向环检测
%            'tarjan' 如果关注强连通分量 适合系统稳定性分析
%       'Verbose': 是否显示处理信息 (默认: true)
%
% 【输出参数】
%   cycle_analysis_results: 结构体，包含以下子模块结果：
%       - simple_cycles: 简单环检测结果
%       - triangles: 三角形闭合分析结果
%       - directed_cycles: 有向环分析结果
%       - feedback_loops: 反馈回路识别结果
%       - cycle_stats: 环统计特征结果
%       - cycle_assessment: 环结构评估结果
%       - metadata: 分析元数据
%
% 【算法原理】
% 1. 简单环检测: 基于深度优先搜索(DFS)或Johnson算法
% 2. 三角形闭合: 计算闭合系数、传递性
% 3. 有向环分析: 强连通分量分析
% 4. 反馈回路: 识别闭合的因果链
%
% 【调用示例】
%   % 基本分析
%   cycle_results = analyze_network_cycles(pair_network);
%   
%   % 自定义参数分析
%   cycle_results = analyze_network_cycles(pair_network, ...
%       'MaxCycleLength', 8, ...            % 最大环长度
%       'CycleDetectionMethod', 'johnson', ...   % 环检测方法
%       'EnableFeedbackLoops', false, ...        % 是否启用反馈回路分析 (默认: true)
%       'Verbose', true);                        % 是否显示处理信息 (默认: true)

    %% 1. 参数解析与初始化
    fprintf('【环结构分析模块】开始运行...\n');
    start_time = tic;
    
    % 参数解析器
    p = inputParser;
    addRequired(p, 'pair_network', @isstruct);
    addParameter(p, 'MaxCycleLength', 6, @(x) isnumeric(x) && x >= 3);
    addParameter(p, 'EnableTriangleAnalysis', true, @islogical);
    addParameter(p, 'EnableFeedbackLoops', true, @islogical);
    addParameter(p, 'CycleDetectionMethod', 'dfs', ...
        @(x) ismember(x, {'dfs', 'tarjan', 'johnson'}));
    addParameter(p, 'Verbose', true, @islogical);
    p.parse(pair_network, varargin{:});
    
    opts = p.Results;
    
    % 初始化结果结构
    cycle_analysis_results = struct();
    cycle_analysis_results.parameters = opts;
    cycle_analysis_results.metadata.start_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    cycle_analysis_results.metadata.network_type = pair_network.graph_type;
    cycle_analysis_results.metadata.n_nodes = pair_network.n_nodes;
    
    % 验证输入网络
    [is_valid, error_msg] = validate_network_for_cycle_analysis(pair_network);
    if ~is_valid
        error('网络验证失败: %s', error_msg);
    end
    
    %% 2. 提取网络数据
    adjacency = pair_network.adjacency;
    is_directed = strcmp(pair_network.graph_type, 'directed');
    n_nodes = pair_network.n_nodes;
    
    if opts.Verbose
        fprintf('网络信息:\n');
        fprintf('  节点数: %d\n', n_nodes);
        fprintf('  边数: %d\n', sum(adjacency(:)));
        fprintf('  图类型: %s\n', pair_network.graph_type);
        fprintf('  最大环长度: %d\n', opts.MaxCycleLength);
        fprintf('  环检测方法: %s\n', opts.CycleDetectionMethod);
        fprintf('\n');
    end
    
    %% 3. 执行6个子模块分析
    if opts.Verbose
        fprintf('执行环结构分析子模块:\n');
    end
    
    % 3.1 简单环检测
    if opts.Verbose
        fprintf('  3.1 简单环检测...\n');
    end
    cycle_analysis_results.simple_cycles = analyze_simple_cycles(...
        adjacency, is_directed, opts.MaxCycleLength, opts.CycleDetectionMethod, opts.Verbose);
    
    % 3.2 三角形闭合分析（如果启用且网络至少有3个节点）
    if opts.EnableTriangleAnalysis && n_nodes >= 3
        if opts.Verbose
            fprintf('  3.2 三角形闭合分析...\n');
        end
        cycle_analysis_results.triangles = analyze_triangles(...
            adjacency, is_directed, opts.Verbose);
    else
        cycle_analysis_results.triangles = struct('enabled', false, ...
            'message', '三角形分析被禁用或节点数不足');
    end
    
    % 3.3 有向环分析（仅适用于有向图）
    if is_directed
        if opts.Verbose
            fprintf('  3.3 有向环分析...\n');
        end
        cycle_analysis_results.directed_cycles = analyze_directed_cycles(...
            adjacency, opts.MaxCycleLength, opts.Verbose);
    else
        cycle_analysis_results.directed_cycles = struct('enabled', false, ...
            'message', '无向图，不进行有向环分析');
    end
    
    % 3.4 反馈回路识别（仅适用于有向图且启用）
    if is_directed && opts.EnableFeedbackLoops
        if opts.Verbose
            fprintf('  3.4 反馈回路识别...\n');
        end
        cycle_analysis_results.feedback_loops = identify_feedback_loops(...
            adjacency, opts.MaxCycleLength, opts.Verbose);
    else
        cycle_analysis_results.feedback_loops = struct('enabled', false, ...
            'message', '反馈回路分析被禁用或网络为无向图');
    end
    
    % 3.5 环统计特征计算
    if opts.Verbose
        fprintf('  3.5 环统计特征计算...\n');
    end
    cycle_analysis_results.cycle_stats = calculate_cycle_statistics(...
        cycle_analysis_results, n_nodes, opts.Verbose);
    
    % 3.6 环结构评估
    if opts.Verbose
        fprintf('  3.6 环结构评估...\n');
    end
    cycle_analysis_results.cycle_assessment = assess_cycle_structures(...
        cycle_analysis_results, opts.Verbose);
    
    %% 4. 生成元数据和摘要
    cycle_analysis_results.metadata.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    cycle_analysis_results.metadata.computation_time = toc(start_time);
    cycle_analysis_results.metadata.n_successful_modules = count_successful_modules(cycle_analysis_results);
    
    %% 5. 显示分析摘要
    if opts.Verbose
        display_cycle_analysis_summary(cycle_analysis_results);
    end
    
    fprintf('【环结构分析完成】总耗时: %.2f 秒\n', ...
        cycle_analysis_results.metadata.computation_time);
end

function [is_valid, error_msg] = validate_network_for_cycle_analysis(pair_network)
% 验证网络是否适合进行环结构分析
    
    is_valid = false;
    error_msg = '';
    
    % 必需字段检查
    required_fields = {'adjacency', 'graph_type', 'n_nodes'};
    for i = 1:length(required_fields)
        if ~isfield(pair_network, required_fields{i})
            error_msg = sprintf('缺少必需字段: %s', required_fields{i});
            return;
        end
    end
    
    % 邻接矩阵检查
    adj = pair_network.adjacency;
    if ~ismatrix(adj) || size(adj, 1) ~= size(adj, 2)
        error_msg = '邻接矩阵必须是方阵';
        return;
    end
    
    if pair_network.n_nodes ~= size(adj, 1)
        error_msg = sprintf('节点数量(%d)与邻接矩阵维度(%d)不匹配', ...
            pair_network.n_nodes, size(adj, 1));
        return;
    end
    
    % 图类型检查
    valid_types = {'directed', 'undirected'};
    if ~ismember(pair_network.graph_type, valid_types)
        error_msg = sprintf('图类型必须是: %s', strjoin(valid_types, ' 或 '));
        return;
    end
    
    is_valid = true;
    error_msg = '网络验证通过';
end

function n_success = count_successful_modules(cycle_results)
% 统计成功执行的模块数量
    
    module_names = {'simple_cycles', 'triangles', 'directed_cycles', ...
                   'feedback_loops', 'cycle_stats', 'cycle_assessment'};
    n_success = 0;
    
    for i = 1:length(module_names)
        module = module_names{i};
        if isfield(cycle_results, module) && isfield(cycle_results.(module), 'is_success')
            if cycle_results.(module).is_success
                n_success = n_success + 1;
            end
        end
    end
end

function display_cycle_analysis_summary(cycle_results)
% 显示环结构分析摘要
    
    fprintf('\n【环结构分析摘要】\n');
    fprintf('========================================\n');
    
    % 基本统计
    if isfield(cycle_results.cycle_stats, 'total_cycles')
        fprintf('总环数: %d\n', cycle_results.cycle_stats.total_cycles);
    end
    
    if isfield(cycle_results.cycle_stats, 'stats')
        stats = cycle_results.cycle_stats.stats;
        if isfield(stats, 'mean_cycle_length')
            fprintf('平均环长度: %.2f\n', stats.mean_cycle_length);
        end
    end
    
    % 三角形统计
    if isfield(cycle_results.triangles, 'n_triangles')
        fprintf('三角形数量: %d\n', cycle_results.triangles.n_triangles);
    end
    
    if isfield(cycle_results.triangles, 'global_clustering_coefficient')
        fprintf('全局聚类系数: %.4f\n', cycle_results.triangles.global_clustering_coefficient);
    end
    
    % 有向环统计
    if isfield(cycle_results.directed_cycles, 'n_directed_cycles')
        fprintf('有向环数量: %d\n', cycle_results.directed_cycles.n_directed_cycles);
    end
    
    % 反馈回路
    if isfield(cycle_results.feedback_loops, 'n_feedback_loops')
        fprintf('反馈回路数量: %d\n', cycle_results.feedback_loops.n_feedback_loops);
    end
    
    % 评估结果
    if isfield(cycle_results.cycle_assessment, 'overall_assessment')
        fprintf('\n环结构评估: %s\n', cycle_results.cycle_assessment.overall_assessment);
    end
    
    if isfield(cycle_results.cycle_assessment, 'overall_score')
        fprintf('综合评分: %.1f/10\n', cycle_results.cycle_assessment.overall_score);
    end
    
    % 模块执行状态
    n_success = cycle_results.metadata.n_successful_modules;
    fprintf('模块执行: %d/%d 成功\n', n_success, 6);
    
    fprintf('========================================\n');
end

