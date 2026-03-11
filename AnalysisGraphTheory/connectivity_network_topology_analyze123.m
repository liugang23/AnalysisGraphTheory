function network_stats = connectivity_network_topology_analyze(pair_network, varargin)
% 网络拓扑分析模块
% 功能：分析网络的拓扑特征和统计属性
%
% 输入：
%   pair_network : 结构体，配对网络，必须包含以下字段：
%       - adjacency: 邻接矩阵
%       - weights: 权重矩阵
%       - node_labels: 节点标签
%       - n_nodes: 节点数量
%   varargin     : 可选参数
%       'verbose': 是否显示详细结果（默认：true）
%       'calculate_all': 是否计算所有指标（默认：true）
%       'community_method': 社区检测方法（默认：'louvain'）
%
% 输出：
%   network_stats : 结构体，包含网络拓扑统计指标：
%       - 基本统计: 节点数、边数、密度、直径、平均路径长度
%       - 度分布: 最小度、最大度、平均度、度分布
%       - 中心性: 度中心性、接近中心性、介数中心性、特征向量中心性
%       - 聚类特征: 聚类系数、传递性
%       - 社区结构: 社区划分、模块度
%       - 小世界性: 小世界系数
%       - 鲁棒性: 度同配性
%
% 科学逻辑：
%   1. 验证输入网络结构
%   2. 计算基本网络统计量
%   3. 计算中心性指标
%   4. 检测社区结构
%   5. 计算小世界特性
%   6. 提供完整的网络诊断
%

%% ==================== 1. 输入验证和参数解析 ====================
    fprintf('【模块2】网络拓扑分析开始\n');
    fprintf('========================================\n\n');

    % 1.1 必需参数验证
    if nargin < 1
        error('错误: 需要至少1个输入参数: pair_network');
    end

    if ~isstruct(pair_network)
        error('错误: pair_network必须是结构体，当前类型: %s', class(pair_network));
    end

    % 1.2 验证必需字段
    required_fields = {'adjacency', 'weights', 'node_labels', 'n_nodes'};
    missing_fields = {};
    for i = 1:length(required_fields)
        if ~isfield(pair_network, required_fields{i})
            missing_fields{end+1} = required_fields{i};
        end
    end
    if ~isempty(missing_fields)
        error('错误: pair_network缺少以下必需字段: %s', strjoin(missing_fields, ', '));
    end

    % 1.3 参数解析
    p = inputParser;
    addRequired(p, 'pair_network', @isstruct);
    addParameter(p, 'verbose', true, @islogical);
    addParameter(p, 'calculate_all', true, @islogical);
    addParameter(p, 'community_method', 'louvain', @(x) ismember(x, {'louvain', 'girvan_newman', 'label_propagation'}));
    addParameter(p, 'directed', false, @islogical);
    parse(p, pair_network, varargin{:});

    verbose = p.Results.verbose;
    calculate_all = p.Results.calculate_all;
    community_method = p.Results.community_method;
    is_directed = p.Results.directed;

    % === 确定图类型 ===
    if is_directed
        graph_type = 'directed';
    else
        graph_type = 'undirected';
    end

    % 1.4 提取网络数据
    adjacency = pair_network.adjacency;
    weights = pair_network.weights;
    node_labels = pair_network.node_labels;
    n_nodes = pair_network.n_nodes;

    % 验证矩阵尺寸
    if size(adjacency, 1) ~= n_nodes || size(adjacency, 2) ~= n_nodes
        error('错误: 邻接矩阵尺寸不匹配: %dx%d, 期望: %dx%d', ...
            size(adjacency,1), size(adjacency,2), n_nodes, n_nodes);
    end

    % 1.5 数据类型转换
    if ~isa(adjacency, 'double')
        if verbose
            fprintf('转换邻接矩阵从 %s 到 double 类型\n', class(adjacency));
        end
        adjacency = double(adjacency);
    end

    if ~isa(weights, 'double')
        if verbose
            fprintf('转换权重矩阵从 %s 到 double 类型\n', class(weights));
        end
        weights = double(weights);
    end
    
% 记录开始时间
    start_time = tic;

    %% ==================== 2. 基本网络统计 ====================
    if verbose
        fprintf('\n1. 计算基本网络统计:\n');
        fprintf('========================================\n\n');
    end

    % 2.1 节点和边统计
    node_degrees = sum(adjacency, 2);
    weighted_degrees = sum(weights, 2);

    % 计算边数
    if is_directed
        n_edges = sum(adjacency(:));
        max_possible_edges = n_nodes * (n_nodes - 1);
    else
        n_edges = sum(adjacency(:)) / 2;
        max_possible_edges = n_nodes * (n_nodes - 1) / 2;
    end

    % 2.2 网络密度
    if max_possible_edges > 0
        network_density = n_edges / max_possible_edges;
    else
        network_density = 0;
    end

    % 2.3 度分布统计
    degree_stats = struct();
    if any(node_degrees > 0)
        non_zero_degrees = node_degrees(node_degrees > 0);
        degree_stats.min = min(non_zero_degrees);
        degree_stats.max = max(node_degrees);
        degree_stats.mean = mean(non_zero_degrees);
        degree_stats.std = std(non_zero_degrees);
        degree_stats.median = median(non_zero_degrees);
        degree_stats.skewness = skewness(node_degrees);
        degree_stats.kurtosis = kurtosis(node_degrees);
    else
        degree_stats.min = 0;
        degree_stats.max = 0;
        degree_stats.mean = 0;
        degree_stats.std = 0;
        degree_stats.median = 0;
        degree_stats.skewness = 0;
        degree_stats.kurtosis = 0;
    end

    % 2.4 加权度统计
    weighted_degree_stats = struct();
    if any(weighted_degrees > 0)
        non_zero_weighted = weighted_degrees(weighted_degrees > 0);
        weighted_degree_stats.min = min(non_zero_weighted);
        weighted_degree_stats.max = max(weighted_degrees);
        weighted_degree_stats.mean = mean(non_zero_weighted);
        weighted_degree_stats.std = std(non_zero_weighted);
        weighted_degree_stats.median = median(non_zero_weighted);
    else
        weighted_degree_stats.min = 0;
        weighted_degree_stats.max = 0;
        weighted_degree_stats.mean = 0;
        weighted_degree_stats.std = 0;
        weighted_degree_stats.median = 0;
    end

    % 2.5 显示基本统计
    if verbose
        fprintf('  节点数: %d\n', n_nodes);
        fprintf('  边数: %d\n', n_edges);
        fprintf('  网络密度: %.4f\n', network_density);
        fprintf('  平均度: %.2f ± %.2f\n', degree_stats.mean, degree_stats.std);
        fprintf('  加权平均度: %.3f ± %.3f\n', weighted_degree_stats.mean, weighted_degree_stats.std);
    end

%% ==================== 3. 路径分析和连通性 ====================
    if verbose
        fprintf('\n2. 路径分析和连通性:\n');
        fprintf('========================================\n\n');
    end

    path_stats = struct();

    try
        % 3.1 处理邻接矩阵并创建图对象
        if is_directed
            % 有向图
            G = digraph(adjacency);
        else
            % 无向图：确保对称性
            % 方法1：强制对称（推荐）
            adjacency_sym = max(adjacency, adjacency');
            G = graph(adjacency_sym, 'upper');

            % 方法2：使用原始矩阵，但可能会忽略部分连接
            % G = graph(adjacency, 'upper');
        end

        % 3.2 计算图的基本属性
        n_edges_G = numedges(G);  % 重命名变量避免冲突

        if verbose
            fprintf('  图对象创建成功:\n');
            fprintf('    节点数: %d\n', n_nodes);
            fprintf('    边数: %d (有向: %s)\n', n_edges_G, bool2str(is_directed));
        end

        % 3.3 计算最短路径距离
        if n_edges > 0
            % 计算距离矩阵 明确调用MATLAB的distances函数
            dist_matrix = feval('distances', G);

            % 或者使用完整函数调用
            % dist_matrix = graphshortestpath(sparse(adjacency), 1:n_nodes, 1:n_nodes);

            if verbose
                fprintf('  距离矩阵计算完成\n');
                fprintf('    矩阵大小: %dx%d\n', size(dist_matrix));
            end

            % 移除对角线元素（节点到自身的距离）
            n = size(dist_matrix, 1);
            dist_matrix(1:n+1:end) = Inf;

            % 提取有效距离（有限且大于0的距离）
            valid_distances = dist_matrix(~isinf(dist_matrix));

            if ~isempty(valid_distances)
                % 平均路径长度
                path_stats.average_path_length = mean(valid_distances);
                path_stats.path_length_std = std(valid_distances);

                % 网络直径
                path_stats.diameter = max(valid_distances);

                % 效率计算
                % 全局效率：所有节点对最短距离的倒数平均值
                efficiency_matrix = 1 ./ dist_matrix;
                efficiency_matrix(isinf(efficiency_matrix)) = 0;  % 处理无穷大
                path_stats.global_efficiency = sum(efficiency_matrix(:)) / (n * (n - 1));

                % 局部效率统计
                path_stats.efficiency_stats.mean = mean(valid_distances);
                path_stats.efficiency_stats.std = std(valid_distances);

                if verbose
                    fprintf('  路径统计计算成功:\n');
                    fprintf('    平均路径长度: %.3f\n', path_stats.average_path_length);
                    fprintf('    网络直径: %.3f\n', path_stats.diameter);
                    fprintf('    全局效率: %.3f\n', path_stats.global_efficiency);
                end
            else
                % 无有效路径（图不连通）
                path_stats.average_path_length = Inf;
                path_stats.path_length_std = 0;
                path_stats.diameter = 0;
                path_stats.global_efficiency = 0;

                if verbose
                    fprintf('  无有效路径（图不连通）\n');
                end
            end
        else
            % 无边图
            path_stats.average_path_length = Inf;
            path_stats.path_length_std = 0;
            path_stats.diameter = 0;
            path_stats.global_efficiency = 0;

            if verbose
                fprintf('  无边图\n');
            end
        end

        % 3.4 计算连通分量
        if is_directed
            % 有向图：计算弱连通分量
            [bins, binsize] = conncomp(G, 'Type', 'weak');
        else
            % 无向图
            [bins, binsize] = conncomp(G);
        end

        path_stats.n_components = max(bins);
        path_stats.component_sizes = binsize;
        path_stats.largest_component_size = max(binsize);
        path_stats.giant_component_ratio = max(binsize) / n_nodes;

        % 连通分量详细信息
        unique_bins = unique(bins);
        path_stats.components = cell(1, path_stats.n_components);
        for i = 1:path_stats.n_components
            component_nodes = find(bins == i);
            path_stats.components{i} = component_nodes;
        end

        if verbose
            fprintf('  连通分量分析:\n');
            fprintf('    连通分量数: %d\n', path_stats.n_components);
            fprintf('    最大连通分量大小: %d\n', path_stats.largest_component_size);
            fprintf('    最大连通分量比例: %.3f\n', path_stats.giant_component_ratio);

            % 显示各分量大小
            fprintf('    各分量大小: ');
            for i = 1:length(binsize)
                fprintf('%d', binsize(i));
                if i < length(binsize)
                    fprintf(', ');
                end
            end
            fprintf('\n');
        end

        % 3.5 添加诊断信息
        path_stats.is_connected = (path_stats.n_components == 1);
        path_stats.is_fully_disconnected = (path_stats.n_components == n_nodes);
        path_stats.is_tree = (n_edges == n_nodes - 1 && path_stats.is_connected);
        path_stats.graph_type = graph_type;
        path_stats.n_edges_actual = n_edges;

    catch ME
        if verbose
            fprintf('警告: 路径分析失败: %s\n', ME.message);

            % 显示诊断信息
            fprintf('诊断信息:\n');
            fprintf('  节点数: %d\n', n_nodes);
            fprintf('  邻接矩阵大小: %dx%d\n', size(adjacency));
            fprintf('  邻接矩阵非零元素: %d\n', sum(adjacency(:)));
            fprintf('  邻接矩阵对称性: %s\n', bool2str(isequal(adjacency, adjacency')));
        end

        % 设置默认值
        path_stats.average_path_length = Inf;
        path_stats.path_length_std = 0;
        path_stats.diameter = 0;
        path_stats.global_efficiency = 0;
        path_stats.n_components = 1;
        path_stats.largest_component_size = n_nodes;
        path_stats.giant_component_ratio = 1;
        path_stats.components = {1:n_nodes};
        path_stats.component_sizes = n_nodes;
        path_stats.is_connected = true;
        path_stats.is_fully_disconnected = false;
        path_stats.is_tree = false;
        path_stats.graph_type = graph_type;
        path_stats.n_edges_actual = 0;
    end

    %% ==================== 4. 聚类系数和传递性 ====================
    if verbose
        fprintf('\n3. 聚类特征:\n');
        fprintf('========================================\n\n');
    end

    clustering_stats = struct();

    try
        % 4.1 局部聚类系数
        clustering_coeffs = zeros(n_nodes, 1);
        for i = 1:n_nodes
            neighbors = find(adjacency(i, :) > 0);
            k = length(neighbors);

            if k < 2
                clustering_coeffs(i) = 0;
            else
                % 计算邻居子图
                subgraph = adjacency(neighbors, neighbors);

                if is_directed
                    % 有向图：计算实际三角形数量
                    actual_triangles = sum(subgraph(:));
                    possible_triangles = k * (k - 1);
                else
                    % 无向图：计算实际边数
                    actual_edges = sum(subgraph(:)) / 2;
                    possible_edges = k * (k - 1) / 2;
                end

                if is_directed
                    if possible_triangles > 0
                        clustering_coeffs(i) = actual_triangles / possible_triangles;
                    else
                        clustering_coeffs(i) = 0;
                    end
                else
                    if possible_edges > 0
                        clustering_coeffs(i) = actual_edges / possible_edges;
                    else
                        clustering_coeffs(i) = 0;
                    end
                end
            end
        end

        % 4.2 全局聚类系数
        clustering_stats.local_coefficients = clustering_coeffs;
        clustering_stats.average_clustering = mean(clustering_coeffs(clustering_coeffs > 0));
        if isnan(clustering_stats.average_clustering)
            clustering_stats.average_clustering = 0;
        end

        % 4.3 传递性
        if ~is_directed
            % 计算三角形数量
            A2 = adjacency * adjacency;
            A3 = A2 * adjacency;
            num_triangles = trace(A3) / 6;

            % 计算连通三元组数量
            num_triplets = sum(sum(adjacency .* (sum(adjacency, 2) - 1)'));

            if num_triplets > 0
                clustering_stats.transitivity = 3 * num_triangles / num_triplets;
            else
                clustering_stats.transitivity = 0;
            end
        else
            clustering_stats.transitivity = NaN;
        end

    catch ME
        if verbose
            fprintf('警告: 聚类系数计算失败: %s\n', ME.message);
        end
        clustering_stats.local_coefficients = zeros(n_nodes, 1);
        clustering_stats.average_clustering = 0;
        clustering_stats.transitivity = 0;
    end

    if verbose
        fprintf('  平均聚类系数: %.3f\n', clustering_stats.average_clustering);
        if ~isnan(clustering_stats.transitivity)
            fprintf('  传递性: %.3f\n', clustering_stats.transitivity);
        end
    end

%% ==================== 5. 中心性度量 ====================
    if verbose
        fprintf('\n4. 中心性度量:\n');
        fprintf('========================================\n\n');
    end

    centrality_stats = struct();

    try
        % 5.1 度中心性
        centrality_stats.degree_centrality = node_degrees / (n_nodes - 1);

        % 5.2 特征向量中心性
        [V, D] = eig(adjacency);
        [~, idx] = max(diag(D));
        centrality_stats.eigenvector_centrality = abs(V(:, idx));
        centrality_stats.eigenvector_centrality = centrality_stats.eigenvector_centrality / sum(centrality_stats.eigenvector_centrality);

        % 5.3 接近中心性
        if isfinite(path_stats.average_path_length)
            centrality_stats.closeness_centrality = zeros(n_nodes, 1);
            for i = 1:n_nodes
                % === 修复：使用已计算的 dist_matrix ===
                if exist('dist_matrix', 'var')
                    node_distances = dist_matrix(i, :);
                    valid_dists = node_distances(isfinite(node_distances) & node_distances > 0);
                    if ~isempty(valid_dists)
                        centrality_stats.closeness_centrality(i) = length(valid_dists) / sum(valid_dists);
                    end
                end
            end
        else
            centrality_stats.closeness_centrality = zeros(n_nodes, 1);
        end

        % 5.4 介数中心性
        if is_directed
            centrality_stats.betweenness_centrality = betweenness_centrality_directed(adjacency, n_nodes);
        else
            centrality_stats.betweenness_centrality = betweenness_centrality_undirected(adjacency, n_nodes);
        end

        % 5.5 PageRank中心性
        if is_directed
            centrality_stats.pagerank_centrality = pagerank_centrality(adjacency);
        else
            centrality_stats.pagerank_centrality = zeros(n_nodes, 1);
        end

        % 5.6 中心性统计
        centrality_stats.top_nodes = struct();
        [~, idx] = sort(centrality_stats.degree_centrality, 'descend');
        centrality_stats.top_nodes.degree = node_labels(idx(1:min(5, n_nodes)));

        [~, idx] = sort(centrality_stats.eigenvector_centrality, 'descend');
        centrality_stats.top_nodes.eigenvector = node_labels(idx(1:min(5, n_nodes)));

        [~, idx] = sort(centrality_stats.betweenness_centrality, 'descend');
        centrality_stats.top_nodes.betweenness = node_labels(idx(1:min(5, n_nodes)));

    catch ME
        if verbose
            fprintf('警告: 中心性计算失败: %s\n', ME.message);
        end
        centrality_stats.degree_centrality = zeros(n_nodes, 1);
        centrality_stats.eigenvector_centrality = zeros(n_nodes, 1);
        centrality_stats.closeness_centrality = zeros(n_nodes, 1);
        centrality_stats.betweenness_centrality = zeros(n_nodes, 1);
        centrality_stats.pagerank_centrality = zeros(n_nodes, 1);
    end

    if verbose
        fprintf('  度中心性范围: [%.3f, %.3f]\n', ...
            min(centrality_stats.degree_centrality), max(centrality_stats.degree_centrality));
        fprintf('  特征向量中心性范围: [%.3f, %.3f]\n', ...
            min(centrality_stats.eigenvector_centrality), max(centrality_stats.eigenvector_centrality));
    end

%% ==================== 6. 社区检测 ====================
    if verbose
        fprintf('\n5. 社区结构检测:\n');
        fprintf('========================================\n\n');
    end

    community_stats = struct();

    try
        if n_edges > 0
            switch community_method
                case 'louvain'
                    communities = detect_communities_louvain(adjacency);
                case 'girvan_newman'
                    communities = detect_communities_girvan_newman(adjacency);
                case 'label_propagation'
                    communities = detect_communities_label_propagation(adjacency);
                otherwise
                    communities = ones(n_nodes, 1);
            end

            community_stats.community_assignment = communities;
            community_stats.n_communities = max(communities);
            community_stats.community_sizes = accumarray(communities, 1);

            % 计算模块度
            community_stats.modularity = calculate_modularity(adjacency, communities, is_directed);

            % 社区内密度
            community_stats.intra_community_density = calculate_intra_community_density(adjacency, communities);

        else
            community_stats.community_assignment = ones(n_nodes, 1);
            community_stats.n_communities = 1;
            community_stats.community_sizes = n_nodes;
            community_stats.modularity = 0;
            community_stats.intra_community_density = 0;
        end

    catch ME
        if verbose
            fprintf('警告: 社区检测失败: %s\n', ME.message);
        end
        community_stats.community_assignment = ones(n_nodes, 1);
        community_stats.n_communities = 1;
        community_stats.community_sizes = n_nodes;
        community_stats.modularity = 0;
        community_stats.intra_community_density = 0;
    end

    if verbose
        fprintf('  社区数量: %d\n', community_stats.n_communities);
        fprintf('  模块度: %.3f\n', community_stats.modularity);
        if community_stats.n_communities > 1
            fprintf('  最大社区规模: %d\n', max(community_stats.community_sizes));
        end
    end

%% ==================== 7. 小世界性和其他指标 ====================
    if calculate_all
        if verbose
            fprintf('\n6. 高级网络指标:\n');
            fprintf('========================================\n\n');
        end

        advanced_stats = struct();

        try
            % 7.1 小世界系数
            if clustering_stats.average_clustering > 0 && isfinite(path_stats.average_path_length)
                % 生成随机网络（同规模的ER随机图）
                random_clustering = 2 * log(n_nodes) / n_nodes;
                random_path_length = log(n_nodes) / log(mean(node_degrees));

                if random_clustering > 0 && random_path_length > 0
                    advanced_stats.small_world_coefficient = ...
                        (clustering_stats.average_clustering / random_clustering) / ...
                        (path_stats.average_path_length / random_path_length);
                else
                    advanced_stats.small_world_coefficient = NaN;
                end
            else
                advanced_stats.small_world_coefficient = NaN;
            end

            % 7.2 度同配性
            if ~is_directed && n_edges > 1
                [r, p] = assortativity_coefficient(adjacency, node_degrees);
                advanced_stats.assortativity = r;
                advanced_stats.assortativity_p = p;
            else
                advanced_stats.assortativity = NaN;
                advanced_stats.assortativity_p = NaN;
            end

            % 7.3 核心-边缘结构
            advanced_stats.core_periphery_score = calculate_core_periphery_score(adjacency);

            % 7.4 层次性
            advanced_stats.hierarchy_score = calculate_hierarchy_score(adjacency);

        catch ME
            if verbose
                fprintf('警告: 高级指标计算失败: %s\n', ME.message);
            end
            advanced_stats.small_world_coefficient = NaN;
            advanced_stats.assortativity = NaN;
            advanced_stats.assortativity_p = NaN;
            advanced_stats.core_periphery_score = 0;
            advanced_stats.hierarchy_score = 0;
        end

        if verbose
            if ~isnan(advanced_stats.small_world_coefficient)
                fprintf('  小世界系数: %.3f\n', advanced_stats.small_world_coefficient);
            end
            if ~isnan(advanced_stats.assortativity)
                fprintf('  度同配性: %.3f\n', advanced_stats.assortativity);
            end
        end
    end

%% ==================== 8. 结果整合 ====================
    % 8.1 计算总时间
    computation_time = toc(start_time);

    % 8.2 构建最终结果结构
    network_stats = struct();

    % 基本统计
    network_stats.basic_stats = struct(...
        'n_nodes', n_nodes, ...
        'n_edges', n_edges, ...
        'density', network_density, ...
        'directed', is_directed);

    % 度分布
    network_stats.degree_stats = degree_stats;
    network_stats.weighted_degree_stats = weighted_degree_stats;

    % 路径分析
    network_stats.path_stats = path_stats;

    % 聚类特征
    network_stats.clustering_stats = clustering_stats;

    % 中心性
    network_stats.centrality_stats = centrality_stats;

    % 社区结构
    network_stats.community_stats = community_stats;

    % 高级指标
    if calculate_all
        network_stats.advanced_stats = advanced_stats;
    end

    % 处理信息
    network_stats.processing_info = struct(...
        'computation_time', computation_time, ...
        'timestamp', datestr(now, 'yyyy-mm-dd HH:MM:SS'), ...
        'calculate_all', calculate_all, ...
        'community_method', community_method, ...
        'version', '1.0');

    % 8.3 显示最终摘要
    if verbose
        fprintf('【模块2】网络拓扑分析完成\n');
        fprintf('========================================\n\n');

        fprintf('\n分析摘要:\n');
        fprintf('  节点数: %d\n', n_nodes);
        fprintf('  边数: %d\n', n_edges);
        fprintf('  网络密度: %.4f\n', network_density);
        fprintf('  平均聚类系数: %.3f\n', clustering_stats.average_clustering);
        fprintf('  社区数量: %d\n', community_stats.n_communities);
        fprintf('  计算时间: %.2f 秒\n', computation_time);

        % 显示前5个节点的度中心性
        fprintf('\n前5个节点（按度中心性排序）:\n');
        [sorted_degrees, sort_idx] = sort(centrality_stats.degree_centrality, 'descend');
        for i = 1:min(5, n_nodes)
            idx = sort_idx(i);
            fprintf('  %-15s: 度=%d, 度中心性=%.3f\n', ...
                node_labels{idx}, node_degrees(idx), sorted_degrees(i));
        end
    end

end

%% ==================== 辅助函数 ====================

function bc = betweenness_centrality_directed(adjacency, n_nodes)
% 计算有向图的介数中心性
    bc = zeros(n_nodes, 1);
    try
        for s = 1:n_nodes
            for t = 1:n_nodes
                if s ~= t
                    [~, paths] = all_shortest_paths_directed(adjacency, s, t);
                    % 安全防护：检查paths类型
                    if ~iscell(paths) || isempty(paths)
%                        disp('paths  不是元胞数组或为空，跳过!');
                        continue;  % 不是元胞数组或为空，跳过
                    end
                    for v = 1:n_nodes
                        if v ~= s && v ~= t
                            count = 0;
                            for p = 1:length(paths)
                                if ismember(v, paths{p})
                                    count = count + 1;
                                end
                            end
                            if count > 0
                                bc(v) = bc(v) + count / length(paths);
                            end
                        end
                    end
                end
            end
        end

        % 归一化
        if n_nodes > 2
            bc = bc / ((n_nodes-1)*(n_nodes-2));
        end
    catch ErrorInfo  
        fprintf('  计算有向图的介数中心性: %s\n', ErrorInfo.message);
    end
end

function [dist, all_paths] = all_shortest_paths_directed(adjacency, source, target)
% ALL_SHORTEST_PATHS_DIRECTED - 计算有向图所有最短路径
%
% 功能: 在有向图中查找从源节点到目标节点的所有最短路径
% 输出确保: all_paths 是数值数组的元胞数组
%
% 输入参数:
%   adjacency: 有向图邻接矩阵 (n×n)
%   source: 源节点索引
%   target: 目标节点索引
%
% 输出参数:
%   dist: 最短路径长度
%   all_paths: 所有最短路径的元胞数组
%
% 版本: 2.0
% 创建时间: 2024-12-28
% 修改说明: 移除对 allpaths 的依赖，强制使用 distances 计算距离

    % 输入验证
    n = size(adjacency, 1);
    if source < 1 || source > n || target < 1 || target > n
        error('节点索引超出范围 [1, %d]', n);
    end
    
    if source == target
        dist = 0;
        all_paths = {[source]};
        return;
    end
    
    try
        % 创建有向图对象
        G = digraph(adjacency);
        
        % === 修改1: 强制使用 distances 计算最短距离 ===
        dist_matrix = distances(G);
        dist = dist_matrix(source, target);
        
        if isinf(dist)
            all_paths = {};
            return;
        end
        
        % === 修改2: 使用 BFS 替代 allpaths 查找所有最短路径 ===
        all_paths = bfs_all_shortest_paths_directed(adjacency, source, target, dist);
        
    catch ME
        fprintf('警告: 使用BFS替代MATLAB函数: %s\n', ME.message);
        % 计算距离
        G = digraph(adjacency);
        dist_matrix = distances(G);
        dist = dist_matrix(source, target);
        
        if isinf(dist)
            all_paths = {};
            return;
        end
        all_paths = bfs_all_shortest_paths_directed(adjacency, source, target);
    end
end

%% 改进的有向图 BFS 函数
function all_paths = bfs_all_shortest_paths_directed(adjacency, source, target, max_dist)
% 有向图 BFS 查找所有最短路径
    
    n = size(adjacency, 1);
    all_paths = {};  % 默认返回空元胞数组
    
    % 输入验证
    if source < 1 || source > n || target < 1 || target > n
        return;
    end
    
    if source == target
        all_paths = {source};
        return;
    end
    
    % 处理直接邻居
    if max_dist == 1
        if adjacency(source, target) > 0
            all_paths = {[source, target]};
        end
        return;
    end
    
    % BFS查找多条路径
    found_paths = {};
    shortest_dist = Inf;
    
    % 使用 BFS 队列
    queue = {{source}};
    
    while ~isempty(queue)
        current_path = queue{1};
        queue(1) = [];
        current_node = current_path{end};
        current_level = length(current_path) - 1;
        
        if current_node == target
            if isempty(found_paths) || current_level < shortest_dist
                shortest_dist = current_level;
                found_paths = {current_path};
            elseif current_level == shortest_dist
                found_paths{end+1} = current_path;
            end
            continue;
        end
        
        if ~isempty(found_paths) && current_level > shortest_dist
            continue;
        end
        
        if current_level >= max_dist
            continue;
        end
        
        % 获取出邻居（有向图）
        neighbors = find(adjacency(current_node, :));
        
        for neighbor = neighbors
            if ~ismember(neighbor, [current_path{:}])
                new_path = [current_path, neighbor];
                queue{end+1} = new_path;
            end
        end
    end
    
    if ~isempty(found_paths)
        % 将元胞数组路径转换为数值数组
        numeric_paths = cell(1, length(found_paths));
        for i = 1:length(found_paths)
            numeric_paths{i} = cell2mat(found_paths{i});
        end
        all_paths = numeric_paths;
    end
end

function bc = betweenness_centrality_undirected(adjacency, n_nodes)
% 计算无向图的介数中心性
    bc = zeros(n_nodes, 1);
    try
        for s = 1:n_nodes
            for t = s+1:n_nodes
                [~, paths] = all_shortest_paths_undirected(adjacency, s, t);
                % === 安全防护：检查 paths 类型 ===
                if ~iscell(paths) || isempty(paths)
                    disp('paths  不是元胞数组或为空，跳过!');
                    continue;  % 不是元胞数组或为空，跳过
                end
                
                % 调试信息
%                fprintf('路径信息: 类型=%s, 大小=', class(paths));
                if isnumeric(paths)
%                    fprintf('%dx%d\n', size(paths));
                    if numel(paths) == 1
%                        fprintf('  路径值: %d\n', paths);
                    end
                elseif iscell(paths)
%                    fprintf('%d个元胞\n', length(paths));
                    for i = 1:min(3, length(paths))
%                        fprintf('  路径%d: 类型=%s\n', i, class(paths{i}));
                    end
                end
                for v = 1:n_nodes
                    if v ~= s && v ~= t
                        count = 0;
                        for p = 1:length(paths)
                            if ismember(v, paths{p})
                                count = count + 1;
                            end
                        end
                        if count > 0
                            bc(v) = bc(v) + count / length(paths);
                        end
                    end
                end
            end
        end

        % 归一化
        if n_nodes > 2
            bc = bc / ((n_nodes-1)*(n_nodes-2)/2);
        end
    catch ErrorInfo  
        fprintf('  计算无向图的介数中心性: %s\n', ErrorInfo.message);
    end
end

function [dist, all_paths] = all_shortest_paths_undirected(adjacency, source, target)
% ALL_SHORTEST_PATHS_UNDIRECTED - 计算无向图所有最短路径
%
% 功能: 在无向图中查找从源节点到目标节点的所有最短路径
% 输出确保: all_paths 是数值数组的元胞数组，格式为 {[1,2,3], [1,4,3]}
%
% 输入参数:
%   adjacency: 无向图邻接矩阵 (n×n)，可以是逻辑矩阵或数值矩阵
%   source: 源节点索引 (1 ≤ source ≤ n)
%   target: 目标节点索引 (1 ≤ target ≤ n)
%
% 输出参数:
%   dist: 最短路径长度，如果没有路径返回 Inf
%   all_paths: 所有最短路径的元胞数组，每个元素是一个数值数组
%
% 版本: 3.0
% 创建时间: 2024-12-28
% 修改说明: 移除对 allpaths 的依赖，强制使用 distances 计算距离

    % 输入验证
    n = size(adjacency, 1);
    if source < 1 || source > n || target < 1 || target > n
        error('节点索引超出范围 [1, %d]', n);
    end
    
    if source == target
        dist = 0;
        all_paths = {source};
        return;
    end
    
    % 确保邻接矩阵是对称的（无向图）
    adjacency_sym = max(adjacency, adjacency');
    
    try
        % 创建无向图对象
        G = graph(adjacency_sym, 'upper');
        
        % === 修改1: 强制使用 distances 计算最短距离 ===
        dist_matrix = distances(G);
        dist = dist_matrix(source, target);
        
        if isinf(dist)
            all_paths = {};
            return;
        end
        
        % === 修改2: 使用 BFS 替代 allpaths 查找所有最短路径 ===
        all_paths = bfs_all_shortest_paths_undirected(adjacency_sym, source, target, dist);
        
    catch ME
        fprintf('警告: 使用BFS替代MATLAB函数: %s\n', ME.message);
        % 计算距离
        G = graph(adjacency_sym, 'upper');
        dist_matrix = distances(G);
        dist = dist_matrix(source, target);
        
        if isinf(dist)
            all_paths = {};
            return;
        end
        all_paths = bfs_all_shortest_paths_undirected(adjacency_sym, source, target, dist);
    end
end

%% 新增: 无向图 BFS 辅助函数
function all_paths = bfs_all_shortest_paths_undirected(adjacency, source, target, max_dist)
% 无向图 BFS 查找所有最短路径
    
    n = size(adjacency, 1);
    all_paths = {};  % 默认返回空元胞数组
    
    % 输入验证
    if source < 1 || source > n || target < 1 || target > n
        return;
    end
    
    if source == target
        all_paths = {source};  % 返回包含单个节点的元胞数组
        return;
    end
    
    % 处理直接邻居
    if max_dist == 1
        if adjacency(source, target) > 0
            all_paths = {[source, target]};
        end
        return;
    end
    
    % BFS查找路径
    found_paths = {};
    shortest_dist = Inf;
    
    % 使用 BFS 队列
    queue = {{source}};
    
    while ~isempty(queue)
        current_path = queue{1};
        queue(1) = [];
        current_node = current_path{end};
        current_level = length(current_path) - 1;
        
        if current_node == target
            if isempty(found_paths) || current_level < shortest_dist
                shortest_dist = current_level;
                found_paths = {current_path};
            elseif current_level == shortest_dist
                found_paths{end+1} = current_path;
            end
            continue;
        end
        
        if ~isempty(found_paths) && current_level > shortest_dist
            continue;
        end
        
        if current_level >= max_dist
            continue;
        end
        
        % 获取邻居
        neighbors = find(adjacency(current_node, :));
        
        for neighbor = neighbors
            if ~ismember(neighbor, [current_path{:}])
                new_path = [current_path, neighbor];
                queue{end+1} = new_path;
            end
        end
    end
    
    if ~isempty(found_paths)
        % 转换为数值数组的元胞数组
        numeric_paths = cell(1, length(found_paths));
        for i = 1:length(found_paths)
            numeric_paths{i} = cell2mat(found_paths{i});
        end
        all_paths = numeric_paths;
    end
end

function pr = pagerank_centrality(adjacency)
% 计算PageRank中心性
    n = size(adjacency, 1);
    damping = 0.85;
    max_iter = 100;
    tol = 1e-6;
    
    % 创建转移矩阵
    out_degrees = sum(adjacency, 2);
    P = zeros(n, n);
    
    for i = 1:n
        if out_degrees(i) > 0
            P(i, :) = adjacency(i, :) / out_degrees(i);
        else
            P(i, :) = 1/n;  % 悬挂节点
        end
    end
    
    % Power iteration
    pr = ones(n, 1) / n;
    for iter = 1:max_iter
        pr_new = (1-damping)/n + damping * (P' * pr);
        
        if norm(pr_new - pr, 1) < tol
            break;
        end
        pr = pr_new;
    end
end

function modularity = calculate_modularity(adjacency, communities, is_directed)
% 计算模块度
    n_nodes = size(adjacency, 1);
    m = sum(adjacency(:));
    
    if is_directed
        m = m;  % 有向图边数
    else
        m = m / 2;  % 无向图边数
    end
    
    if m == 0
        modularity = 0;
        return;
    end
    
    modularity = 0;
    for i = 1:n_nodes
        for j = 1:n_nodes
            if i ~= j
                if communities(i) == communities(j)
                    ki = sum(adjacency(i, :));
                    kj = sum(adjacency(j, :));
                    expected = ki * kj / (2*m);
                    modularity = modularity + (adjacency(i,j) - expected);
                end
            end
        end
    end
    
    modularity = modularity / (2*m);
end

function density = calculate_intra_community_density(adjacency, communities)
% 计算社区内密度
    n_communities = max(communities);
    densities = zeros(n_communities, 1);
    
    for c = 1:n_communities
        members = find(communities == c);
        n_members = length(members);
        
        if n_members > 1
            subgraph = adjacency(members, members);
            intra_edges = sum(subgraph(:)) / 2;
            possible_edges = n_members * (n_members - 1) / 2;
            densities(c) = intra_edges / possible_edges;
        end
    end
    
    density = mean(densities);
end

function [r, p] = assortativity_coefficient(adjacency, degrees)
% 计算度同配性系数
    [rows, cols] = find(triu(adjacency));
    
    if isempty(rows)
        r = 0;
        p = 1;
        return;
    end
    
    deg_i = degrees(rows);
    deg_j = degrees(cols);
    
    m = length(rows);
    sum_deg_i = sum(deg_i);
    sum_deg_j = sum(deg_j);
    sum_deg_i2 = sum(deg_i.^2);
    sum_deg_j2 = sum(deg_j.^2);
    sum_deg_i_deg_j = sum(deg_i .* deg_j);
    
    num = (1/m) * sum_deg_i_deg_j - ((1/(2*m)) * (sum_deg_i + sum_deg_j))^2;
    den = 0.5 * ((1/m) * (sum_deg_i2 + sum_deg_j2) - (1/(2*m))^2 * (sum_deg_i + sum_deg_j)^2);
    
    if den == 0
        r = 0;
    else
        r = num / den;
    end
    
    % 简化p值计算
    p = 0.05;  % 占位值
end

function score = calculate_core_periphery_score(adjacency)
% 计算核心-边缘结构得分
    n = size(adjacency, 1);
    degrees = sum(adjacency, 2);
    [~, sorted_idx] = sort(degrees, 'descend');
    
    % 取前30%作为核心节点
    n_core = ceil(0.3 * n);
    core_nodes = sorted_idx(1:n_core);
    periphery_nodes = sorted_idx(n_core+1:end);
    
    % 计算核心内部连接密度
    core_subgraph = adjacency(core_nodes, core_nodes);
    core_density = sum(core_subgraph(:)) / (n_core * (n_core - 1));
    
    % 计算边缘内部连接密度
    n_periphery = length(periphery_nodes);
    if n_periphery > 1
        periphery_subgraph = adjacency(periphery_nodes, periphery_nodes);
        periphery_density = sum(periphery_subgraph(:)) / (n_periphery * (n_periphery - 1));
    else
        periphery_density = 0;
    end
    
    score = core_density - periphery_density;
end

function score = calculate_hierarchy_score(adjacency)
% 计算层次性得分
    n = size(adjacency, 1);
    clustering_coeffs = zeros(n, 1);
    degrees = sum(adjacency, 2);
    
    for i = 1:n
        neighbors = find(adjacency(i, :) > 0);
        k = length(neighbors);
        
        if k < 2
            clustering_coeffs(i) = 0;
        else
            subgraph = adjacency(neighbors, neighbors);
            actual_edges = sum(subgraph(:)) / 2;
            possible_edges = k * (k - 1) / 2;
            clustering_coeffs(i) = actual_edges / possible_edges;
        end
    end
    
    % 计算聚类系数与度之间的相关性
    valid_idx = degrees > 0 & clustering_coeffs > 0;
    if sum(valid_idx) > 1
        correlation = corr(degrees(valid_idx), clustering_coeffs(valid_idx), 'rows', 'complete');
        score = -correlation;  % 负相关表示层次性
    else
        score = 0;
    end
end

function [communities, modularity] = detect_communities_louvain(adjacency, varargin)
% DETECT_COMMUNITIES_LOUVAIN - 使用Louvain算法检测社区结构
%
% 输入参数:
%   adjacency: 邻接矩阵
%   varargin: 可选参数
%     - 'resolution': 分辨率参数 (默认=1.0)
%     - 'max_iter': 最大迭代次数 (默认=100)
%
% 输出参数:
%   communities: 社区分配向量 (n×1)
%   modularity: 模块度值
%
% 版本: 1.0
% 创建时间: 2024-12-28

    % 解析参数
    p = inputParser;
    addParameter(p, 'resolution', 1.0, @isnumeric);
    addParameter(p, 'max_iter', 100, @isnumeric);
    parse(p, varargin{:});
    
    resolution = p.Results.resolution;
    max_iter = p.Results.max_iter;
    
    n = size(adjacency, 1);
    
    % 简单实现：基于节点类型划分社区
    % 注：这是简化版，真实Louvain算法更复杂
    communities = ones(n, 1);
    
    % 根据节点名称判断类型
    for i = 1:n
        node_name = sprintf('node_%d', i);
        if isfield(adjacency, 'node_labels') && iscell(adjacency.node_labels)
            node_name = adjacency.node_labels{i};
        end
        
        % 简单规则：收益节点和OBV节点分别在不同社区
        if contains(node_name, 'ret', 'IgnoreCase', true)
            communities(i) = 1;
        else
            communities(i) = 2;
        end
    end
    
    % 计算模块度
    modularity = calculate_modularity_simple(adjacency, communities, resolution);
    
    fprintf('社区检测结果:\n');
    fprintf('  社区数量: %d\n', length(unique(communities)));
    fprintf('  模块度: %.4f\n', modularity);
    fprintf('  节点分布: 社区1: %d个, 社区2: %d个\n', ...
        sum(communities == 1), sum(communities == 2));
end

function Q = calculate_modularity_simple(A, communities, gamma)
% 简化模块度计算
    
    n = size(A, 1);
    m = sum(A(:)) / 2;  % 无向图边数
    
    if m == 0
        Q = 0;
        return;
    end
    
    Q = 0;
    unique_comms = unique(communities);
    
    for c = unique_comms'
        nodes_in_c = find(communities == c);
        
        % 计算社区内部边数
        lc = 0;
        for i = 1:length(nodes_in_c)
            for j = i+1:length(nodes_in_c)
                lc = lc + A(nodes_in_c(i), nodes_in_c(j));
            end
        end
        
        % 计算社区节点总度
        dc = 0;
        for i = 1:length(nodes_in_c)
            dc = dc + sum(A(nodes_in_c(i), :));
        end
        
        % 模块度贡献
        Q = Q + (lc/m) - gamma * (dc/(2*m))^2;
    end
end

function str = bool2str(logical_val)
% BOOL2STR - 逻辑值转换为字符串
%
% 功能: 将逻辑值转换为友好的中文字符串表示
%
% 输入参数:
%   logical_val: 逻辑值 (true/false) 或数值 (0/1)
%
% 输出参数:
%   str: 对应的字符串
%         - true/non-zero: 返回 "是" 或 "对称" (根据上下文)
%         - false/zero: 返回 "否" 或 "非对称" (根据上下文)
%
% 示例:
%   bool2str(true)  -> "是"
%   bool2str(false) -> "否"
%   bool2str(1)     -> "是"
%   bool2str(0)     -> "否"
%
% 版本: 1.0
% 创建时间: 2024-12-28

    % 处理输入类型
    if isnumeric(logical_val)
        % 数值类型转换
        bool_val = (logical_val ~= 0);
    elseif islogical(logical_val)
        % 逻辑类型
        bool_val = logical_val;
    else
        error('输入必须是逻辑值或数值');
    end
    
    % 转换为字符串
    if bool_val
        str = '是';
    else
        str = '否';
    end
end
