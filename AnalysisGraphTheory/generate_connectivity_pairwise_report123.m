function generate_connectivity_pairwise_report(network, pairwise_results, pair_data, output_dir, report_type)
% =========================================================================
% GENERATE_CONNECTIVITY_PAIRWISE_REPORT 生成网络分析综合报告
% =========================================================================
%
% 功能：为网络分析结果生成详细、可定制的综合报告
% 可以输出为：1) 控制台报告 2) 文本文件 3) HTML文件 4) Word文档
%
% 【修改说明】
% 现在pairwise_results和pair_data是可选的，如果没有提供，只从network中获取信息
%
% 【使用示例】
% -------------------------------------------------------------------------
% 示例1：内部调用（完整参数）
%   generate_connectivity_pairwise_report(network, pairwise_results, pair_data, '.', 'console');
%
% 示例2：外部调用（只需要network）
%   generate_connectivity_pairwise_report(network, [], [], './reports', 'html');
%
% 示例3：外部调用（简写）
%   generate_connectivity_pairwise_report(network, '.', 'console');  % 自动识别参数
%
% 示例4：默认调用
%   generate_connectivity_pairwise_report(network);  % 默认当前目录和控制台报告
% =========================================================================

%% ==================== 参数验证和初始化 ====================
% 处理参数数量，让pairwise_results和pair_data可选
% 如果只有1个参数，就是network
% 如果有3个参数，可能是：network, output_dir, report_type
% 如果有5个参数，就是原来的完整调用

fprintf('================================================================\n');
fprintf('                    网络分析报告生成系统\n');
fprintf('================================================================\n');

% 根据参数数量自动调整
if nargin == 1
    % 只有network，使用默认参数
    pairwise_results = [];
    pair_data = [];
    output_dir = '.';
    report_type = 'console';
    fprintf('调用方式: 默认（控制台报告）\n');
    
elseif nargin == 3
    % 3个参数：network, output_dir, report_type
    % 这种情况是外部调用，没有pairwise_results和pair_data
    output_dir = pairwise_results;  % 第二个参数是output_dir
    report_type = pair_data;        % 第三个参数是report_type
    pairwise_results = [];          % 清空
    pair_data = [];                 % 清空
    fprintf('调用方式: 外部调用（无需配对结果）\n');
    
elseif nargin == 5
    % 5个参数：原始的完整调用
    fprintf('调用方式: 完整调用（包含配对结果）\n');
    
else
    error('错误: 参数数量错误。用法:\n1. generate_connectivity_pairwise_report(network)\n2. generate_connectivity_pairwise_report(network, output_dir, report_type)\n3. generate_connectivity_pairwise_report(network, pairwise_results, pair_data, output_dir, report_type)');
end

fprintf('开始时间: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf('输出目录: %s\n', output_dir);
fprintf('报告类型: %s\n', upper(report_type));
fprintf('----------------------------------------------------------------\n');

% 记录开始时间
start_time = tic;

% 验证network结构
validate_network_structure(network);

% 验证report_type
valid_report_types = {'console', 'text', 'html', 'full', 'custom'};
if ~ismember(lower(report_type), valid_report_types)
    error('错误: report_type必须是以下之一: %s', strjoin(valid_report_types, ', '));
end

% 创建输出目录
if ~strcmpi(report_type, 'console')
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
        fprintf('创建输出目录: %s\n', output_dir);
    end
end

%% ==================== 计算网络统计指标 ====================
fprintf('\n正在计算网络统计指标...\n');

% 获取网络基本信息
basic_stats = compute_basic_statistics(network);

% 计算节点统计
node_stats = compute_node_statistics(network);

% 计算边统计 - 修改为接受可选参数
edge_stats = compute_edge_statistics(network, pairwise_results, pair_data);

% 计算拓扑指标
topology_stats = compute_topology_statistics(network);

% 计算社区结构（如果不存在）
if ~isfield(network, 'communities') || isempty(network.communities)
    fprintf('检测社区结构...\n');
    try
        network.communities = detect_communities_louvain(network.adjacency);
        network.modularity = compute_modularity(network.adjacency, network.communities);
    catch
        fprintf('警告: 社区检测失败，使用默认社区\n');
        network.communities = ones(network.n_nodes, 1);
        network.modularity = 0;
    end
end

%% ==================== 生成报告 ====================
switch lower(report_type)
    case 'console'
        % 生成控制台报告
        fprintf('\n----------------------------------------------------------------\n');
        fprintf('                    控制台报告\n');
        fprintf('----------------------------------------------------------------\n');
        generate_console_report(network, basic_stats, node_stats, edge_stats, topology_stats);
        
    case 'text'
        % 生成文本文件报告
        fprintf('\n生成文本文件报告...\n');
        generate_text_report(network, basic_stats, node_stats, edge_stats, topology_stats, output_dir);
        
    case 'html'
        % 生成HTML报告
        fprintf('\n生成HTML报告...\n');
        generate_html_report(network, basic_stats, node_stats, edge_stats, topology_stats, output_dir);
        
    case 'full'
        % 生成完整报告
        fprintf('\n生成完整报告...\n');
        generate_full_report(network, basic_stats, node_stats, edge_stats, topology_stats, output_dir, pairwise_results, pair_data);
        
    case 'custom'
        % 生成自定义报告
        fprintf('\n生成自定义报告...\n');
        generate_custom_report(network, basic_stats, node_stats, edge_stats, topology_stats, output_dir, pairwise_results, pair_data);
        
    otherwise
        error('不支持的报告类型: %s', report_type);
end

%% ==================== 完成和输出 ====================
elapsed_time = toc(start_time);
fprintf('\n----------------------------------------------------------------\n');
fprintf('报告生成完成！\n');
fprintf('总用时: %.2f 秒\n', elapsed_time);
fprintf('输出目录: %s\n', output_dir);
fprintf('================================================================\n');

end

%% ==================== 辅助函数 ====================

function validate_network_structure(network)
% 验证网络结构
if ~isstruct(network)
    error('错误: network必须是结构体');
end

required_fields = {'adjacency', 'node_labels', 'n_nodes'};
for i = 1:length(required_fields)
    if ~isfield(network, required_fields{i})
        error('错误: network缺少必需字段: %s', required_fields{i});
    end
end

% 验证邻接矩阵
if ~ismatrix(network.adjacency) || size(network.adjacency, 1) ~= size(network.adjacency, 2)
    error('错误: network.adjacency必须是方阵');
end

% 验证节点标签
if length(network.node_labels) ~= network.n_nodes
    error('错误: node_labels数量与n_nodes不匹配');
end
end

function basic_stats = compute_basic_statistics(network)
% 计算基本统计
basic_stats = struct();

% 网络基本信息
basic_stats.n_nodes = network.n_nodes;
if isfield(network, 'n_edges')
    basic_stats.n_edges = network.n_edges;
else
    % 计算边数
    if isfield(network, 'adjacency')
        if isfield(network, 'directions') && any(network.directions(:) ~= 0)
            % 有向图
            basic_stats.n_edges = sum(network.adjacency(:));
        else
            % 无向图
            basic_stats.n_edges = sum(network.adjacency(:)) / 2;
        end
    else
        basic_stats.n_edges = 0;
    end
end

% 网络密度
if isfield(network, 'density')
    basic_stats.density = network.density;
else
    if isfield(network, 'adjacency')
        n = size(network.adjacency, 1);
        if isfield(network, 'directions') && any(network.directions(:) ~= 0)
            % 有向图
            max_edges = n * (n - 1);
        else
            % 无向图
            max_edges = n * (n - 1) / 2;
        end
        basic_stats.density = basic_stats.n_edges / max_edges;
    else
        basic_stats.density = 0;
    end
end

% 分析类型
if isfield(network, 'analysis_type')
    basic_stats.analysis_type = network.analysis_type;
else
    basic_stats.analysis_type = 'unknown';
end

% 显著性水平
if isfield(network, 'alpha')
    basic_stats.alpha = network.alpha;
else
    basic_stats.alpha = 0.05;
end

% 构建时间
if isfield(network, 'construction_time')
    basic_stats.construction_time = network.construction_time;
else
    basic_stats.construction_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
end
end

function node_stats = compute_node_statistics(network)
% 计算节点统计
node_stats = struct();

n_nodes = network.n_nodes;
node_stats.node_labels = network.node_labels;

% 分离节点类型
node_stats.ret_nodes = [];
node_stats.obv_nodes = [];

for i = 1:n_nodes
    label = network.node_labels{i};
    if contains(lower(label), 'ret')
        node_stats.ret_nodes(end+1) = i;
    elseif contains(lower(label), 'obv')
        node_stats.obv_nodes(end+1) = i;
    end
end

node_stats.n_ret_nodes = length(node_stats.ret_nodes);
node_stats.n_obv_nodes = length(node_stats.obv_nodes);

% 节点度
if isfield(network, 'node_degrees')
    node_stats.degrees = network.node_degrees;
else
    node_stats.degrees = sum(network.adjacency, 2);
end

% 加权度
if isfield(network, 'weighted_degrees')
    node_stats.weighted_degrees = network.weighted_degrees;
elseif isfield(network, 'weights')
    node_stats.weighted_degrees = sum(network.weights, 2);
else
    node_stats.weighted_degrees = node_stats.degrees;
end

% 中心性指标
if isfield(network, 'degree_centrality')
    node_stats.degree_centrality = network.degree_centrality;
else
    node_stats.degree_centrality = node_stats.degrees / (n_nodes - 1);
end

if isfield(network, 'betweenness_centrality')
    node_stats.betweenness_centrality = network.betweenness_centrality;
else
    % 如果没有介数中心性，计算一个简化版本
    node_stats.betweenness_centrality = zeros(n_nodes, 1);
    for i = 1:n_nodes
        for j = 1:n_nodes
            for k = 1:n_nodes
                if i ~= j && i ~= k && j ~= k
                    if network.adjacency(j, k) > 0
                        node_stats.betweenness_centrality(i) = node_stats.betweenness_centrality(i) + 1;
                    end
                end
            end
        end
    end
    node_stats.betweenness_centrality = node_stats.betweenness_centrality / ((n_nodes-1)*(n_nodes-2));
end

if isfield(network, 'eigenvector_centrality')
    node_stats.eigenvector_centrality = network.eigenvector_centrality;
else
    % 如果没有特征向量中心性，使用度中心性近似
    node_stats.eigenvector_centrality = node_stats.degree_centrality;
end

% 聚类系数
if isfield(network, 'clustering_coeffs')
    node_stats.clustering_coeffs = network.clustering_coeffs;
else
    node_stats.clustering_coeffs = zeros(n_nodes, 1);
    for i = 1:n_nodes
        neighbors = find(network.adjacency(i, :) > 0);
        k = length(neighbors);
        if k <= 1
            node_stats.clustering_coeffs(i) = 0;
        else
            connections = 0;
            for m = 1:k
                for n = m+1:k
                    if network.adjacency(neighbors(m), neighbors(n)) > 0
                        connections = connections + 1;
                    end
                end
            end
            node_stats.clustering_coeffs(i) = 2 * connections / (k * (k - 1));
        end
    end
end

% 统计汇总
node_stats.degree_stats.min = min(node_stats.degrees);
node_stats.degree_stats.max = max(node_stats.degrees);
node_stats.degree_stats.mean = mean(node_stats.degrees);
node_stats.degree_stats.std = std(node_stats.degrees);
node_stats.degree_stats.median = median(node_stats.degrees);

non_zero_weights = node_stats.weighted_degrees(node_stats.weighted_degrees > 0);
if ~isempty(non_zero_weights)
    node_stats.weighted_stats.min = min(non_zero_weights);
    node_stats.weighted_stats.max = max(node_stats.weighted_degrees);
    node_stats.weighted_stats.mean = mean(non_zero_weights);
    node_stats.weighted_stats.std = std(non_zero_weights);
else
    node_stats.weighted_stats.min = 0;
    node_stats.weighted_stats.max = 0;
    node_stats.weighted_stats.mean = 0;
    node_stats.weighted_stats.std = 0;
end
node_stats.weighted_stats.median = median(node_stats.weighted_degrees);

% 排名
[~, node_stats.degree_rank] = sort(node_stats.degrees, 'descend');
[~, node_stats.weighted_rank] = sort(node_stats.weighted_degrees, 'descend');
[~, node_stats.betweenness_rank] = sort(node_stats.betweenness_centrality, 'descend');
[~, node_stats.eigenvector_rank] = sort(node_stats.eigenvector_centrality, 'descend');
end

function edge_stats = compute_edge_statistics(network, pairwise_results, pair_data)
% 修改：让pairwise_results和pair_data可选
% 计算边统计
edge_stats = struct();

% 获取边信息
if isfield(network, 'edge_list') && ~isempty(network.edge_list)
    edge_stats.edge_list = network.edge_list;
    edge_stats.n_edges = length(network.edge_list);
    
    % 边类型统计
    edge_stats.n_correlation_edges = 0;
    edge_stats.n_granger_edges = 0;
    edge_stats.n_bidirectional_edges = 0;
    edge_stats.n_ret_to_obv = 0;
    edge_stats.n_obv_to_ret = 0;
    
    for i = 1:length(network.edge_list)
        edge = network.edge_list(i);
        if isfield(edge, 'analysis_type')
            if strcmp(edge.analysis_type, 'correlation')
                edge_stats.n_correlation_edges = edge_stats.n_correlation_edges + 1;
            elseif strcmp(edge.analysis_type, 'granger')
                edge_stats.n_granger_edges = edge_stats.n_granger_edges + 1;
                if isfield(edge, 'direction')
                    if strcmp(edge.direction, 'ret_to_obv')
                        edge_stats.n_ret_to_obv = edge_stats.n_ret_to_obv + 1;
                    elseif strcmp(edge.direction, 'obv_to_ret')
                        edge_stats.n_obv_to_ret = edge_stats.n_obv_to_ret + 1;
                    elseif strcmp(edge.direction, 'bidirectional')
                        edge_stats.n_bidirectional_edges = edge_stats.n_bidirectional_edges + 1;
                    end
                end
            end
        end
    end
    
    % 权重统计
    weights = [];
    for i = 1:length(network.edge_list)
        if isfield(network.edge_list(i), 'weight')
            weights(end+1) = network.edge_list(i).weight;
        end
    end
    
    if ~isempty(weights)
        edge_stats.weight_stats.min = min(weights);
        edge_stats.weight_stats.max = max(weights);
        edge_stats.weight_stats.mean = mean(weights);
        edge_stats.weight_stats.std = std(weights);
        edge_stats.weight_stats.median = median(weights);
    else
        edge_stats.weight_stats.min = 0;
        edge_stats.weight_stats.max = 0;
        edge_stats.weight_stats.mean = 0;
        edge_stats.weight_stats.std = 0;
        edge_stats.weight_stats.median = 0;
    end
    
else
    % 如果没有edge_list，从邻接矩阵重建基本信息
    adjacency = network.adjacency;
    n = network.n_nodes;
    edge_stats.edge_list = [];
    edge_count = 0;
    
    for i = 1:n
        for j = i+1:n
            if adjacency(i, j) > 0
                edge_count = edge_count + 1;
                edge.from_node = network.node_labels{i};
                edge.to_node = network.node_labels{j};
                edge.weight = adjacency(i, j);
                edge.analysis_type = 'unknown';
                edge.direction = 'undirected';
                edge.p_value = NaN;
                edge.lag = 0;
                
                edge_stats.edge_list = [edge_stats.edge_list; edge];
            end
        end
    end
    
    edge_stats.n_edges = edge_count;
    edge_stats.n_correlation_edges = edge_count;
    edge_stats.n_granger_edges = 0;
    edge_stats.n_bidirectional_edges = 0;
    edge_stats.n_ret_to_obv = 0;
    edge_stats.n_obv_to_ret = 0;
    
    if edge_count > 0
        weights = [edge_stats.edge_list.weight];
        edge_stats.weight_stats.min = min(weights);
        edge_stats.weight_stats.max = max(weights);
        edge_stats.weight_stats.mean = mean(weights);
        edge_stats.weight_stats.std = std(weights);
        edge_stats.weight_stats.median = median(weights);
    else
        edge_stats.weight_stats.min = 0;
        edge_stats.weight_stats.max = 0;
        edge_stats.weight_stats.mean = 0;
        edge_stats.weight_stats.std = 0;
        edge_stats.weight_stats.median = 0;
    end
end

% 如果提供了pairwise_results，可以获取更详细的边信息
if ~isempty(pairwise_results) && ~isempty(pair_data)
    % 尝试从pairwise_results获取更详细的信息
    % 这部分是可选的，有就补充，没有就算了
    try
        % 补充边的详细信息
        for i = 1:length(edge_stats.edge_list)
            edge = edge_stats.edge_list(i);
            from_idx = find(strcmp(edge.from_node, network.node_labels), 1);
            to_idx = find(strcmp(edge.to_node, network.node_labels), 1);
            
            % 寻找对应的配对结果
            for j = 1:length(pairwise_results)
                if (strcmp(pairwise_results(j).var1, edge.from_node) && ...
                    strcmp(pairwise_results(j).var2, edge.to_node)) || ...
                   (strcmp(pairwise_results(j).var1, edge.to_node) && ...
                    strcmp(pairwise_results(j).var2, edge.from_node))
                    
                    % 补充信息
                    if isfield(pairwise_results(j), 'correlation_p')
                        edge.p_value = pairwise_results(j).correlation_p;
                    end
                    if isfield(pairwise_results(j), 'lag')
                        edge.lag = pairwise_results(j).lag;
                    end
                    if isfield(pairwise_results(j), 'analysis_type')
                        edge.analysis_type = pairwise_results(j).analysis_type;
                    end
                    
                    edge_stats.edge_list(i) = edge;
                    break;
                end
            end
        end
    catch
        % 如果获取失败，不影响主要功能
    end
end

% 计算边的其他统计
if isfield(network, 'weights')
    edge_weights = network.weights(network.weights > 0);
    if ~isempty(edge_weights)
        edge_stats.avg_edge_weight = mean(edge_weights);
        edge_stats.max_edge_weight = max(edge_weights);
        edge_stats.min_edge_weight = min(edge_weights);
    else
        edge_stats.avg_edge_weight = 0;
        edge_stats.max_edge_weight = 0;
        edge_stats.min_edge_weight = 0;
    end
end
end

% 其他的函数保持不变，和原来的一样
% （compute_topology_statistics, generate_console_report, generate_text_report等函数保持不变）