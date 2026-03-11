function [network_stats, node_statistics] = network_statistics_calculator(...
    network_matrices, node_info, param_info)
% NETWORK_STATISTICS_CALCULATOR - 网络统计计算模块
%
% 功能描述:
%   计算网络的拓扑统计指标，包括度分布、聚类系数、路径分析、中心性度量等
%   为网络分析提供全面的定量指标
%
% 输入参数:
%   network_matrices: 网络矩阵结构体
%                    - adjacency: 邻接矩阵
%                    - weights: 权重矩阵
%                    - directions: 方向矩阵
%                    - lags: 滞后矩阵
%                    - significance: 显著性矩阵
%   node_info: 节点信息结构体
%              - node_labels: 节点标签元胞数组
%              - ret_nodes: 收益节点标签
%              - obv_nodes: OBV节点标签
%              - n_nodes: 总节点数
%   param_info: 参数信息结构体
%               - analysis_type: 分析类型
%
% 输出参数:
%   network_stats: 网络级统计结构体
%                  - n_edges: 边数
%                  - n_edges_directed: 有向边数
%                  - density: 网络密度
%                  - clustering_coefficient: 聚类系数
%                  - average_path_length: 平均路径长度
%                  - diameter: 网络直径
%                  - degree_stats: 度分布统计
%                  - weighted_degree_stats: 加权度统计
%                  - modularity: 模块度
%                  - assortativity: 度同配性
%                  - small_worldness: 小世界性
%   node_statistics: 节点级统计结构体
%                    - node_degrees: 节点度向量
%                    - weighted_degrees: 加权度向量
%                    - degree_centrality: 度中心性
%                    - closeness_centrality: 接近中心性
%                    - betweenness_centrality: 介数中心性
%                    - eigenvector_centrality: 特征向量中心性
%                    - clustering_coefficients: 节点聚类系数
%
% 工作流程:
%   1. 计算基本网络统计（边数、密度）
%   2. 计算节点级统计（度、中心性）
%   3. 计算网络拓扑统计（聚类系数、路径分析）
%   4. 计算高级网络指标（模块度、同配性）
%
% 版本: 1.0
% 作者: Financial Network Analysis Toolbox
% 创建时间: 2024-12-28
% 最后修改: 2024-12-28
%
% 使用示例:
%   [net_stats, node_stats] = network_statistics_calculator(matrices, node_info, params);

%% 1. 模块初始化和参数准备
fprintf('\n[模块3] 网络统计计算模块开始\n');
fprintf('============================================================\n');
start_time = tic;

% 输入验证
if nargin < 3
    error('错误: 需要3个输入参数，但只提供了 %d 个。', nargin);
end

% 从输入参数提取值
adjacency_matrix = network_matrices.adjacency;
weight_matrix = network_matrices.weights;
analysis_type = param_info.analysis_type;

node_labels = node_info.node_labels;
n_nodes = node_info.n_nodes;
ret_nodes = node_info.ret_nodes;
obv_nodes = node_info.obv_nodes;

fprintf('参数配置:\n');
fprintf('  - 节点数量: %d\n', n_nodes);
fprintf('  - 收益节点: %d\n', length(ret_nodes));
fprintf('  - OBV节点: %d\n', length(obv_nodes));
fprintf('  - 分析类型: %s\n', upper(analysis_type));

%% 2. 计算基本网络统计
fprintf('\n计算基本网络统计...\n');

% 计算节点度
node_degrees = sum(adjacency_matrix, 2);
weighted_degrees = sum(weight_matrix, 2);

% 计算网络边数
if strcmp(analysis_type, 'correlation')
    % 无向图
    max_possible_edges = n_nodes * (n_nodes - 1) / 2;
    n_edges = sum(adjacency_matrix(:)) / 2;
    n_edges_directed = n_edges * 2;  % 有向计数是两倍
else
    % 有向图
    max_possible_edges = n_nodes * (n_nodes - 1);
    n_edges = sum(adjacency_matrix(:));
    n_edges_directed = n_edges;  % 有向计数相同
end

% 计算网络密度
if max_possible_edges > 0
    network_density = n_edges / max_possible_edges;
else
    network_density = 0;
end

fprintf('  - 边数: %d (有向计数: %d)\n', n_edges, n_edges_directed);
fprintf('  - 网络密度: %.4f\n', network_density);

%% 3. 计算度分布统计
fprintf('计算度分布统计...\n');

% 度分布统计
if any(node_degrees > 0)
    non_zero_degrees = node_degrees(node_degrees > 0);
    degree_stats.min = min(non_zero_degrees);
    degree_stats.max = max(node_degrees);
    degree_stats.mean = mean(non_zero_degrees);
    degree_stats.std = std(non_zero_degrees);
    degree_stats.median = median(non_zero_degrees);
    degree_stats.variance = var(non_zero_degrees);
    degree_stats.skewness = skewness(non_zero_degrees);
    degree_stats.kurtosis = kurtosis(non_zero_degrees);
else
    degree_stats.min = 0;
    degree_stats.max = 0;
    degree_stats.mean = 0;
    degree_stats.std = 0;
    degree_stats.median = 0;
    degree_stats.variance = 0;
    degree_stats.skewness = 0;
    degree_stats.kurtosis = 0;
end

% 加权度统计
if any(weighted_degrees > 0)
    non_zero_weighted = weighted_degrees(weighted_degrees > 0);
    weighted_degree_stats.min = min(non_zero_weighted);
    weighted_degree_stats.max = max(weighted_degrees);
    weighted_degree_stats.mean = mean(non_zero_weighted);
    weighted_degree_stats.std = std(non_zero_weighted);
    weighted_degree_stats.median = median(non_zero_weighted);
    weighted_degree_stats.variance = var(non_zero_weighted);
else
    weighted_degree_stats.min = 0;
    weighted_degree_stats.max = 0;
    weighted_degree_stats.mean = 0;
    weighted_degree_stats.std = 0;
    weighted_degree_stats.median = 0;
    weighted_degree_stats.variance = 0;
end

%% 4. 计算网络拓扑统计
fprintf('计算网络拓扑统计...\n');

% 聚类系数
clustering_coefficient = calculate_clustering_coefficient_mat(adjacency_matrix, analysis_type);
fprintf('  - 聚类系数: %.3f\n', clustering_coefficient);

% 节点聚类系数
node_clustering_coefficients = calculate_node_clustering_coefficients(adjacency_matrix, analysis_type);

% 平均路径长度和直径
if n_edges > 0
    [average_path_length, diameter] = calculate_path_statistics(adjacency_matrix, analysis_type);
    fprintf('  - 平均路径长度: %.3f\n', average_path_length);
    fprintf('  - 网络直径: %.3f\n', diameter);
else
    average_path_length = Inf;
    diameter = 0;
    fprintf('  - 平均路径长度: Inf (无连接)\n');
    fprintf('  - 网络直径: 0 (无连接)\n');
end

%% 5. 计算中心性度量
fprintf('计算中心性度量...\n');

% 度中心性
degree_centrality = calculate_degree_centrality(node_degrees, n_nodes, analysis_type);

% 接近中心性
if average_path_length < Inf
    closeness_centrality = calculate_closeness_centrality_mat(adjacency_matrix, analysis_type);
else
    closeness_centrality = zeros(n_nodes, 1);
end

% 介数中心性
if average_path_length < Inf
    betweenness_centrality = calculate_betweenness_centrality_mat(adjacency_matrix, analysis_type);
else
    betweenness_centrality = zeros(n_nodes, 1);
end

% 特征向量中心性
if n_edges > 0
    eigenvector_centrality = calculate_eigenvector_centrality_mat(adjacency_matrix);
else
    eigenvector_centrality = zeros(n_nodes, 1);
end

%% 6. 计算高级网络指标
fprintf('计算高级网络指标...\n');

% 模块度
if n_edges > 0
    modularity = calculate_modularity_mat(adjacency_matrix, analysis_type);
else
    modularity = 0;
end

% 度同配性（仅适用于无向图）
if strcmp(analysis_type, 'correlation') && n_edges > 0
    assortativity = calculate_assortativity_mat(adjacency_matrix);
else
    assortativity = NaN;
end

% 小世界性（简化计算）
if n_edges > 0 && average_path_length < Inf
    small_worldness = calculate_small_worldness_approx(adjacency_matrix, analysis_type, ...
        clustering_coefficient, average_path_length);
else
    small_worldness = NaN;
end

fprintf('  - 模块度: %.3f\n', modularity);
if ~isnan(assortativity)
    fprintf('  - 度同配性: %.3f\n', assortativity);
end
if ~isnan(small_worldness)
    fprintf('  - 小世界性: %.3f\n', small_worldness);
end

%% 7. 构建节点统计结构
node_statistics = struct();
node_statistics.node_degrees = node_degrees;
node_statistics.weighted_degrees = weighted_degrees;
node_statistics.degree_centrality = degree_centrality;
node_statistics.closeness_centrality = closeness_centrality;
node_statistics.betweenness_centrality = betweenness_centrality;
node_statistics.eigenvector_centrality = eigenvector_centrality;
node_statistics.clustering_coefficients = node_clustering_coefficients;

% 添加节点标签
node_statistics.node_labels = node_labels;
node_statistics.n_nodes = n_nodes;

%% 8. 构建网络统计结构
network_stats = struct();
network_stats.n_edges = n_edges;
network_stats.n_edges_directed = n_edges_directed;
network_stats.density = network_density;
network_stats.clustering_coefficient = clustering_coefficient;
network_stats.average_path_length = average_path_length;
network_stats.diameter = diameter;
network_stats.degree_stats = degree_stats;
network_stats.weighted_degree_stats = weighted_degree_stats;
network_stats.modularity = modularity;
network_stats.assortativity = assortativity;
network_stats.small_worldness = small_worldness;

% 添加连接性统计
network_stats.is_connected = (average_path_length < Inf);
if network_stats.is_connected
    network_stats.connectivity_status = 'connected';
else
    network_stats.connectivity_status = 'disconnected';
end

% 添加网络类型信息
if strcmp(analysis_type, 'correlation')
    network_stats.graph_type = 'undirected';
else
    network_stats.graph_type = 'directed';
end

%% 9. 计算运行时间和模块信息
elapsed_time = toc(start_time);
module_info = struct();
module_info.module_name = 'network_statistics_calculator';
module_info.version = '1.0';
module_info.computation_time = elapsed_time;
module_info.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

% 将模块信息添加到统计结果
network_stats.module_info = module_info;
node_statistics.module_info = module_info;

%% 10. 输出摘要
fprintf('\n网络统计摘要:\n');
fprintf('  - 节点数: %d\n', n_nodes);
fprintf('  - 边数: %d (有向: %d)\n', n_edges, n_edges_directed);
fprintf('  - 网络密度: %.4f\n', network_density);
fprintf('  - 聚类系数: %.3f\n', clustering_coefficient);
fprintf('  - 平均路径长度: %.3f\n', average_path_length);
fprintf('  - 连接状态: %s\n', network_stats.connectivity_status);
fprintf('  - 图类型: %s\n', network_stats.graph_type);

fprintf('\n[模块3] 网络统计计算模块完成\n');
fprintf('============================================================\n');
fprintf('运行时间: %.2f 秒\n', elapsed_time);
fprintf('模块信息:\n');
fprintf('  - 名称: %s\n', module_info.module_name);
fprintf('  - 版本: %s\n', module_info.version);
fprintf('  - 完成时间: %s\n', module_info.timestamp);
fprintf('============================================================\n\n');

end

%% ==================== 辅助函数 ====================

function cc = calculate_clustering_coefficient_mat(adjacency, analysis_type)
% 计算网络聚类系数
    
    n_nodes = size(adjacency, 1);
    cc_values = zeros(n_nodes, 1);
    
    if strcmp(analysis_type, 'correlation')
        % 无向图
        adjacency_sym = adjacency | adjacency';  % 确保对称
    else
        % 有向图
        adjacency_sym = adjacency;
    end
    
    for i = 1:n_nodes
        neighbors = find(adjacency_sym(i, :));
        k = length(neighbors);
        
        if k < 2
            cc_values(i) = 0;
        else
            % 计算三角形数量
            triangles = 0;
            for a = 1:k-1
                for b = a+1:k
                    if adjacency_sym(neighbors(a), neighbors(b))
                        triangles = triangles + 1;
                    end
                end
            end
            
            % 计算可能的最大三角形数
            max_triangles = k * (k - 1) / 2;
            if max_triangles > 0
                cc_values(i) = triangles / max_triangles;
            else
                cc_values(i) = 0;
            end
        end
    end
    
    % 计算平均聚类系数
    non_zero_cc = cc_values(cc_values > 0);
    if ~isempty(non_zero_cc)
        cc = mean(non_zero_cc);
    else
        cc = 0;
    end
end

function node_cc = calculate_node_clustering_coefficients(adjacency, analysis_type)
% 计算每个节点的聚类系数
    
    n_nodes = size(adjacency, 1);
    node_cc = zeros(n_nodes, 1);
    
    if strcmp(analysis_type, 'correlation')
        % 无向图
        adjacency_sym = adjacency | adjacency';
    else
        % 有向图
        adjacency_sym = adjacency;
    end
    
    for i = 1:n_nodes
        neighbors = find(adjacency_sym(i, :));
        k = length(neighbors);
        
        if k < 2
            node_cc(i) = 0;
        else
            % 计算三角形数量
            triangles = 0;
            for a = 1:k-1
                for b = a+1:k
                    if adjacency_sym(neighbors(a), neighbors(b))
                        triangles = triangles + 1;
                    end
                end
            end
            
            % 计算可能的最大三角形数
            max_triangles = k * (k - 1) / 2;
            if max_triangles > 0
                node_cc(i) = triangles / max_triangles;
            else
                node_cc(i) = 0;
            end
        end
    end
end

function [apl, diameter] = calculate_path_statistics(adjacency, analysis_type)
% 计算平均路径长度和网络直径
    
    n_nodes = size(adjacency, 1);
    
    if strcmp(analysis_type, 'granger')
        % === 有向图处理 ===
        G = digraph(adjacency);
        
        try
            % 计算距离矩阵
            distances_mat = distances(G);
            
            % 移除对角线和无穷大
            distances_mat(1:n_nodes+1:end) = NaN;
            distances_mat(isinf(distances_mat)) = NaN;
            
            % 计算平均路径长度
            valid_dists = distances_mat(~isnan(distances_mat));
            if ~isempty(valid_dists)
                apl = mean(valid_dists);
                diameter = max(valid_dists);
            else
                apl = Inf;
                diameter = 0;
            end
            
        catch
            % 如果失败，使用BFS
            apl = calculate_directed_apl_bfs(adjacency);
            diameter = 0;
        end
        
    else
        % === 无向图处理 ===
        G = graph(adjacency, 'upper');
        
        try
            distances_mat = distances(G);
            distances_mat(1:n_nodes+1:end) = NaN;
            valid_dists = distances_mat(~isnan(distances_mat));
            
            if ~isempty(valid_dists)
                apl = mean(valid_dists);
                diameter = max(valid_dists);
            else
                apl = Inf;
                diameter = 0;
            end
        catch
            apl = Inf;
            diameter = 0;
        end
    end
end

function apl = calculate_directed_apl_bfs(adjacency)
% BFS计算有向图的平均路径长度
    
    n_nodes = size(adjacency, 1);
    all_path_lengths = [];
    
    for source = 1:n_nodes
        % BFS从源节点开始
        visited = false(1, n_nodes);
        distance = inf(1, n_nodes);
        queue = source;
        
        visited(source) = true;
        distance(source) = 0;
        
        while ~isempty(queue)
            current = queue(1);
            queue(1) = [];
            
            % 找到所有出邻居
            neighbors = find(adjacency(current, :));
            
            for neighbor = neighbors
                if ~visited(neighbor)
                    visited(neighbor) = true;
                    distance(neighbor) = distance(current) + 1;
                    queue(end+1) = neighbor;
                end
            end
        end
        
        % 添加到路径长度列表
        valid_dists = distance(isfinite(distance) & distance > 0);
        all_path_lengths = [all_path_lengths, valid_dists];
    end
    
    if ~isempty(all_path_lengths)
        apl = mean(all_path_lengths);
    else
        apl = Inf;
    end
end

function centrality = calculate_degree_centrality(degrees, n_nodes, analysis_type)
% 计算度中心性
    
    if strcmp(analysis_type, 'granger')
        % 有向图：最大可能的度 = 2*(n-1)
        max_possible = 2 * (n_nodes - 1);
    else
        % 无向图：最大可能的度 = (n-1)
        max_possible = n_nodes - 1;
    end
    
    if max_possible > 0
        centrality = degrees / max_possible;
    else
        centrality = zeros(n_nodes, 1);
    end
    
    % 调试输出
    fprintf('\n[调试] 度中心性计算:\n');
    fprintf('  节点数: %d, 分析类型: %s\n', n_nodes, analysis_type);
    fprintf('  最大可能度: %.1f\n', max_possible);
    fprintf('  实际度范围: [%d, %d]\n', min(degrees), max(degrees));
    fprintf('  度中心性范围: [%.4f, %.4f]\n', min(centrality), max(centrality));
end

function closeness = calculate_closeness_centrality_mat(adjacency, analysis_type)
% 计算接近中心性
    
    n_nodes = size(adjacency, 1);
    closeness = zeros(n_nodes, 1);
    
    if strcmp(analysis_type, 'correlation')
        % 无向图
        G = graph(adjacency, 'upper');
    else
        % 有向图
        G = digraph(adjacency);
    end
    
    try
        distances_mat = distances(G);
        
        for i = 1:n_nodes
            valid_dists = distances_mat(i, distances_mat(i,:) < Inf & distances_mat(i,:) > 0);
            if ~isempty(valid_dists)
                closeness(i) = length(valid_dists) / sum(valid_dists);
            end
        end
        
    catch
        % 简化计算
        for i = 1:n_nodes
            distances = bfs_distances(adjacency, i, strcmp(analysis_type, 'correlation'));
            valid_dists = distances(distances > 0);
            if ~isempty(valid_dists)
                closeness(i) = length(valid_dists) / sum(valid_dists);
            end
        end
    end
    
    % 归一化
    if any(closeness > 0)
        closeness = closeness / max(closeness);
    end
end

function distances = bfs_distances(adjacency, source, is_undirected)
% 使用BFS计算从源节点到所有节点的距离
    
    n_nodes = size(adjacency, 1);
    distances = inf(1, n_nodes);
    visited = false(1, n_nodes);
    queue = source;
    
    visited(source) = true;
    distances(source) = 0;
    
    while ~isempty(queue)
        current = queue(1);
        queue(1) = [];
        
        if is_undirected
            neighbors = find(adjacency(current, :) | adjacency(:, current)');
        else
            neighbors = find(adjacency(current, :));
        end
        
        for neighbor = neighbors
            if ~visited(neighbor)
                visited(neighbor) = true;
                distances(neighbor) = distances(current) + 1;
                queue(end+1) = neighbor;
            end
        end
    end
end

function betweenness = calculate_betweenness_centrality_mat(adjacency, analysis_type)
% 计算介数中心性（简化版本）
    
    n_nodes = size(adjacency, 1);
    betweenness = zeros(n_nodes, 1);
    
    if strcmp(analysis_type, 'correlation')
        % 无向图
        is_directed = false;
    else
        % 有向图
        is_directed = true;
    end
    
    % 简化版本：使用连接性作为近似
    for s = 1:n_nodes
        for t = 1:n_nodes
            if s ~= t
                % 查找最短路径
                [~, paths] = find_shortest_paths(adjacency, s, t, is_directed);
                
                for p = 1:length(paths)
                    path = paths{p};
                    for v = 1:length(path)
                        if path{v} ~= s && path{v} ~= t
                            betweenness(path{v}) = betweenness(path{v}) + 1/length(paths);
                        end
                    end
                end
            end
        end
    end
    
    % 归一化
    if any(betweenness > 0)
        betweenness = betweenness / max(betweenness);
    end
end

function [dist, paths] = find_shortest_paths(adjacency, source, target, is_directed)
% 查找从源节点到目标节点的所有最短路径（简化版本）
    
    n_nodes = size(adjacency, 1);
    dist = Inf;
    paths = {};
    
    % 使用BFS查找最短路径
    queue = {{source}};
    visited = false(1, n_nodes);
    visited(source) = true;
    shortest_dist = Inf;
    
    while ~isempty(queue)
        current_path = queue{1};
        queue(1) = [];
        current_node = current_path{end};
        current_dist = length(current_path) - 1;
        
        if current_node == target
            if current_dist < shortest_dist
                shortest_dist = current_dist;
                paths = {current_path};
            elseif current_dist == shortest_dist
                paths{end+1} = current_path;
            end
            continue;
        end
        
        if current_dist > shortest_dist
            continue;
        end
        
        % 获取邻居
        if is_directed
            neighbors = find(adjacency(current_node, :));
        else
            neighbors = find(adjacency(current_node, :) | adjacency(:, current_node)');
        end
        
        for neighbor = neighbors
            if ~visited(neighbor) || (neighbor == target)
                visited(neighbor) = true;
                new_path = [current_path, neighbor];
                queue{end+1} = new_path;
            end
        end
    end
    
    if ~isempty(paths)
        dist = shortest_dist;
    end
end

function eigenvector = calculate_eigenvector_centrality_mat(adjacency)
% 计算特征向量中心性
    
    try
        [V, D] = eig(double(adjacency));
        [~, idx] = max(diag(D));
        eigenvector = abs(V(:, idx));
        
        % 归一化
        if any(eigenvector)
            eigenvector = eigenvector / sum(eigenvector);
        end
        
    catch
        n_nodes = size(adjacency, 1);
        eigenvector = ones(n_nodes, 1) / n_nodes;
    end
end

function modularity = calculate_modularity_mat(adjacency, analysis_type)
% 计算模块度（简化版本）
    
    n_nodes = size(adjacency, 1);
    
    % 1. 计算总边数
    if strcmp(analysis_type, 'correlation')
        % 无向图
        m = sum(adjacency(:)) / 2;  % 实际边数
    else
        % 有向图
        m = sum(adjacency(:));
    end
    
    if m == 0 || m < 1e-10
        modularity = 0;
        return;
    end
    
    % 2. 更合理的社区划分
    communities = detect_communities_improved(adjacency, analysis_type);
    
    % 3. 计算模块度
    Q = 0;
    for i = 1:n_nodes
        for j = 1:n_nodes
            if i ~= j
                % 计算期望连接数
                if strcmp(analysis_type, 'correlation')
                    % 无向图
                    ki = sum(adjacency(i,:));
                    kj = sum(adjacency(j,:));
                    expected = (ki * kj) / (2 * m);
                else
                    % 有向图
                    ki_out = sum(adjacency(i,:));
                    kj_in = sum(adjacency(:,j));
                    expected = (ki_out * kj_in) / m;
                end
                
                % 添加贡献
                if communities(i) == communities(j)
                    if strcmp(analysis_type, 'correlation')
                        % 无向图：对称计算
                        Aij = adjacency(i,j);
                        Q = Q + (Aij - expected);
                    else
                        % 有向图
                        Aij = adjacency(i,j);
                        Q = Q + (Aij - expected);
                    end
                end
            end
        end
    end
    
    % 4. 归一化
    if strcmp(analysis_type, 'correlation')
        modularity = Q / (2 * m);
    else
        modularity = Q / m;
    end
    
    % 5. 防止数值错误
    if isnan(modularity) || isinf(modularity)
        modularity = 0;
    end
end

function communities = detect_communities_improved(adjacency, analysis_type)
% 改进的社区检测 - 鲁棒版本
    
    n_nodes = size(adjacency, 1);
    communities = ones(n_nodes, 1);
    
    if n_nodes < 3
        return;
    end
    
    % 1. 计算合适的度中心性
    if strcmp(analysis_type, 'correlation')
        % 无向图：总度
        node_strength = sum(adjacency, 2);
    else
        % 有向图：综合考虑出度和入度
        out_degree = sum(adjacency, 2);
        in_degree = sum(adjacency, 1)';
        node_strength = out_degree + in_degree;  % 总连接强度
    end
    
    % 2. 使用K-means进行更合理的划分
    try
        % 尝试K-means聚类
        k = min(3, ceil(n_nodes/10));  % 动态确定社区数
        k = max(2, k);  % 至少2个社区
        
        % 准备特征向量
        features = [node_strength, centrality_scores(adjacency, analysis_type)];
        
        % 执行K-means
        [communities, ~] = kmeans(features, k, 'Replicates', 3, 'MaxIter', 100);
        
    catch
        % 如果K-means失败，回退到基于度的划分
        fprintf('? K-means失败，使用基于度的简单划分\n');
        [~, sorted_idx] = sort(node_strength, 'descend');
        
        % 动态确定社区数
        if n_nodes > 20
            n_communities = 3;
        else
            n_communities = 2;
        end
        
        % 基于度进行划分
        for i = 1:n_nodes
            idx = sorted_idx(i);
            if i <= floor(n_nodes/3)
                communities(idx) = 1;
            elseif i <= floor(2*n_nodes/3)
                communities(idx) = 2;
            else
                communities(idx) = 3;
            end
        end
    end
    
    % 确保社区编号从1开始连续
    unique_comms = unique(communities);
    for i = 1:length(unique_comms)
        communities(communities == unique_comms(i)) = i;
    end
end

function cent_scores = centrality_scores(adjacency, analysis_type)
% 计算其他中心性作为特征
    n_nodes = size(adjacency, 1);
    cent_scores = zeros(n_nodes, 1);
    
    if strcmp(analysis_type, 'correlation')
        % 无向图：特征向量中心性
        try
            [V, ~] = eig(double(adjacency));
            cent_scores = abs(V(:, end));  % 最大特征值对应的特征向量
        catch
            cent_scores = sum(adjacency, 2);
        end
    else
        % 有向图：PageRank近似
        try
            G = digraph(adjacency);
            pr = centrality(G, 'pagerank');
            cent_scores = pr;
        catch
            cent_scores = sum(adjacency, 2) + sum(adjacency, 1)';
        end
    end
end

function assortativity = calculate_assortativity_mat(adjacency)
% 计算度同配性（仅用于无向图）
    
    n_nodes = size(adjacency, 1);
    
    % 计算度
    degrees = sum(adjacency, 2);
    
    % 找到边
    [rows, cols] = find(triu(adjacency));
    m = length(rows);
    
    if m == 0
        assortativity = 0;
        return;
    end
    
    % 计算同配系数
    deg_i = degrees(rows);
    deg_j = degrees(cols);
    
    sum_deg_i = sum(deg_i);
    sum_deg_j = sum(deg_j);
    sum_deg_i2 = sum(deg_i.^2);
    sum_deg_j2 = sum(deg_j.^2);
    sum_deg_i_deg_j = sum(deg_i .* deg_j);
    
    num = (1/m) * sum_deg_i_deg_j - ((1/(2*m)) * (sum_deg_i + sum_deg_j))^2;
    den = 0.5 * ((1/m) * (sum_deg_i2 + sum_deg_j2) - (1/(2*m))^2 * (sum_deg_i + sum_deg_j)^2);
    
    if den == 0
        assortativity = 0;
    else
        assortativity = num / den;
    end
end

function sigma = calculate_small_worldness_approx(adjacency, analysis_type, cc, apl)
% 计算小世界性（近似版本）
    
    n_nodes = size(adjacency, 1);
    
    % 计算随机网络的聚类系数和平均路径长度
    if strcmp(analysis_type, 'correlation')
        % 无向随机网络
        p = sum(adjacency(:)) / (n_nodes*(n_nodes-1));
        cc_random = p;
        apl_random = log(n_nodes) / log(n_nodes * p);
    else
        % 有向随机网络
        p = sum(adjacency(:)) / (n_nodes*(n_nodes-1));
        cc_random = p;
        apl_random = log(n_nodes) / log(n_nodes * p);
    end
    
    if cc_random > 0 && apl_random > 0
        sigma = (cc / cc_random) / (apl / apl_random);
    else
        sigma = NaN;
    end
end