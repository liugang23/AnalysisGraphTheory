function result = network_analyze_centrality(net, opts)
% ANALYZE_NETWORK_CENTRALITY - 分析网络中心性
    
    result = struct();
    result.module_name = '中心性分析';
    result.module_version = '1.0.0';
    result.start_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    try
        % 1. 创建图对象
        n_nodes = net.n_nodes;  % 先获取节点数

        % 方法1：使用节点名称创建图对象
        if isfield(net, 'node_labels')
            % 如果有节点标签，使用节点标签创建
            node_names = net.node_labels;
        else
            % 如果没有标签，创建默认节点名
            node_names = arrayfun(@(x) sprintf('Node%d', x), 1:n_nodes, 'UniformOutput', false);
        end
        
        if strcmp(net.graph_type, 'undirected')
            % 无向图
            G = graph(net.adjacency, node_names, 'upper');
        else
            % 有向图
            G = digraph(net.adjacency, node_names);
        end
    
        fprintf('图对象创建成功: 节点数=%d, 边数=%d\n', numnodes(G), numedges(G));
    
        top_k = min(opts.TopK, n_nodes);
        % 2. 度中心性
        result.degree_centrality = struct();
        
        % 检查图是否为空
        if numedges(G) == 0
            fprintf('警告: 图是空的，没有边\n');
            deg_cent = zeros(n_nodes, 1);
        else
            try
                % 尝试使用centrality函数
                deg_cent = centrality(G, 'degree');
            catch
                % 如果centrality失败，使用基本函数
                fprintf('使用degree/indegree/outdegree计算度中心性\n');
                if isa(G, 'digraph')
                    % 有向图
                    indeg = indegree(G);
                    outdeg = outdegree(G);
                    deg_cent = indeg + outdeg;
                else
                    % 无向图
                    deg_cent = degree(G);
                end
            end
        end

        result.degree_centrality.values = deg_cent;
        
        % 获取前K个节点
        [sorted_vals, sorted_idx] = sort(deg_cent, 'descend');
        result.degree_centrality.top_k_indices = sorted_idx(1:min(top_k, length(sorted_idx)));

        if isfield(net, 'node_labels')
            result.degree_centrality.top_k_labels = net.node_labels(result.degree_centrality.top_k_indices);
        end
        result.degree_centrality.top_k_values = deg_cent(result.degree_centrality.top_k_indices);
    
        % 3. 介数中心性
        result.betweenness_centrality = struct();
    
        if numedges(G) == 0
            bet_cent = zeros(n_nodes, 1);
        else
            try
                bet_cent = centrality(G, 'betweenness');
            catch
                fprintf('betweenness中心性计算失败，返回零向量\n');
                bet_cent = zeros(n_nodes, 1);
            end
        end
    
        result.betweenness_centrality.values = bet_cent;
        [sorted_vals, sorted_idx] = sort(bet_cent, 'descend');
        result.betweenness_centrality.top_k_indices = sorted_idx(1:min(top_k, length(sorted_idx)));

        if isfield(net, 'node_labels')
            result.betweenness_centrality.top_k_labels = net.node_labels(result.betweenness_centrality.top_k_indices);
        end
        result.betweenness_centrality.top_k_values = bet_cent(result.betweenness_centrality.top_k_indices);
    
    catch ME
        fprintf('  - 分析网络中心性 介数中心性 失败: %s\n', ME.message);
        fprintf('    错误位置: %s (行: %d)\n', ME.stack(1).name, ME.stack(1).line);
    
        % 确保返回错误信息
        if exist('result', 'var')
            result.error_message = ME.message;
            result.error_location = sprintf('%s (行: %d)', ME.stack(1).name, ME.stack(1).line);
            result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            result.is_success = false;
        end
    end
    
	% 4. 接近中心性
	result.closeness_centrality = struct();
    try
        % 1. 创建一个无权重的图副本
        % 如果原图有权重，我们创建一个新图，边权重设为1
        % 如果原图本来就没有权重，这一步也不会出错
        
        % 获取原图的边信息
        s = G.Edges.EndNodes(:,1); % 起点
        t = G.Edges.EndNodes(:,2); % 终点
        
        % 创建新图 (不带权重)
        G_no_weight = digraph(s, t);
        
        % 2. 计算距离 (此时计算的是跳数)
        dist = distances(G_no_weight);
        
        % 接近中心性公式: 1 / (所有距离之和)
        % 注意：如果图不连通，dist 中会有 Inf，需要处理
        % 这里我们假设图是连通的，或者忽略 Inf 值
        sum_dist = sum(dist, 2); % 沿着列求和，得到每个节点到其他节点的距离和
        
        % 防止除以0或Inf
        close_cent = 1 ./ sum_dist;
        
        % 处理不连通的情况：如果距离和是 Inf，接近中心性设为 0
        close_cent(isinf(sum_dist)) = 0;
       
        result.closeness_centrality.values = close_cent;
        result.closeness_centrality.top_k_indices = get_top_k_indices(close_cent, top_k);
        result.closeness_centrality.top_k_labels = net.node_labels(result.closeness_centrality.top_k_indices);
        result.closeness_centrality.top_k_values = close_cent(result.closeness_centrality.top_k_indices);
    catch ME
        fprintf('  - 分析网络中心性 接近中心性 失败: %s\n', ME.message);
        result.closeness_centrality.values = NaN(n_nodes, 1);
        result.closeness_centrality.error = '计算失败 (可能存在不连通的节点)';
    end
        
	% 5. 特征向量中心性
	result.eigenvector_centrality = struct();
	try
        % 获取图的邻接矩阵
        A = adjacency(G);
        
        % 计算邻接矩阵的最大特征值对应的特征向量
        % 'largestabs' 表示计算绝对值最大的特征值
        % 'eigs' 函数用于计算稀疏矩阵的特征值
        [V, D] = eigs(A, 1, 'largestabs');
        
        % 特征向量中心性就是这个特征向量
        % 注意：特征向量可能有正有负，通常取绝对值或直接使用
        % 这里我们直接使用计算出的特征向量
        eig_cent = V;
        
        % 归一化处理（可选，使向量长度为1）
        % eig_cent = eig_cent / norm(eig_cent);
        
        % 处理符号问题：特征向量中心性通常定义为非负值
        % 如果特征向量全是负数，取反
        if all(eig_cent < 0)
            eig_cent = -eig_cent;
        end
        
        result.eigenvector_centrality.values = eig_cent;
        result.eigenvector_centrality.top_k_indices = get_top_k_indices(eig_cent, top_k);
        result.eigenvector_centrality.top_k_labels = net.node_labels(result.eigenvector_centrality.top_k_indices);
        result.eigenvector_centrality.top_k_values = eig_cent(result.eigenvector_centrality.top_k_indices);
    catch ME
        fprintf('  - 分析网络中心性 特征向量中心性 失败: %s\n', ME.message);
        result.eigenvector_centrality.values = NaN(n_nodes, 1);
        result.eigenvector_centrality.error = '计算失败';
	end
        
    try
        % 6. 综合重要节点识别
        result.composite_importance = struct();
        composite_scores = zeros(n_nodes, 1);
        
        % 标准化并组合中心性指标
        valid_centralities = {};
        
        if ~all(isnan(result.degree_centrality.values))
            valid_centralities{end+1} = 'degree_centrality';
        end
        if ~all(isnan(result.betweenness_centrality.values))
            valid_centralities{end+1} = 'betweenness_centrality';
        end
        if ~all(isnan(result.closeness_centrality.values))
            valid_centralities{end+1} = 'closeness_centrality';
        end
        if ~all(isnan(result.eigenvector_centrality.values))
            valid_centralities{end+1} = 'eigenvector_centrality';
        end
        
        % 计算综合得分
        for i = 1:length(valid_centralities)
            cent_type = valid_centralities{i};
            values = result.(cent_type).values;
            
            % 标准化到0-1范围
            if max(values) > min(values)
                normalized = (values - min(values)) / (max(values) - min(values));
            else
                normalized = zeros(size(values));
            end
            
            composite_scores = composite_scores + normalized;
        end
        
        if ~isempty(valid_centralities)
            composite_scores = composite_scores / length(valid_centralities);
        end
        
        result.composite_importance.scores = composite_scores;
        result.composite_importance.top_k_indices = get_top_k_indices(composite_scores, top_k);
        result.composite_importance.top_k_labels = net.node_labels(result.composite_importance.top_k_indices);
        result.composite_importance.top_k_values = composite_scores(result.composite_importance.top_k_indices);
    catch ME
        fprintf('  - 分析网络中心性 综合重要节点识别 失败: %s\n', ME.message);
    end
        
    try
        % 7. 评估
        result.assessment = struct();
        if length(valid_centralities) >= 2
            result.assessment.centrality_analysis_status = '完整';
            result.assessment.recommendation = '多种中心性指标计算成功，结果可靠';
        else
            result.assessment.centrality_analysis_status = '部分';
            result.assessment.recommendation = '部分中心性指标计算失败，结果需谨慎使用';
        end
        
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        result.is_success = true;
        
    catch ME
        result.error_message = ME.message;
        fprintf('  - 分析网络中心性 评估 失败: %s\n', ME.message);
        result.error_location = sprintf('%s (行: %d)', ME.stack(1).name, ME.stack(1).line);
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        result.is_success = false;
    end
end

function top_indices = get_top_k_indices(values, k)
% 获取排名前K的索引
    [sorted_values, sorted_indices] = sort(values, 'descend');
    top_indices = sorted_indices(1:min(k, length(values)));
end