function result = network_analyze_community_structure(net, opts)
% ANALYZE_COMMUNITY_STRUCTURE - 分析网络社区结构
    
    result = struct();
    result.module_name = '社区结构分析';
    result.module_version = '1.0.0';
    result.start_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    try
        % 创建图对象
        if strcmp(net.graph_type, 'undirected')
            G = graph(net.adjacency, 'upper');
        else
            G = digraph(net.adjacency);
        end
        
        n_nodes = net.n_nodes;
        
        % 1. 使用Louvain算法检测社区
        result.community_detection = struct();
        
        try
            if strcmp(net.graph_type, 'undirected')
                % 无向图Louvain算法
                [communities, modularity] = louvain_algorithm_undirected(net.adjacency);
            else
                % 有向图Louvain算法
                [communities, modularity] = louvain_algorithm_directed(net.adjacency);
            end
            
            result.community_detection.community_assignments = communities;
            result.community_detection.modularity = modularity;
            result.community_detection.n_communities = max(communities);
            result.community_detection.is_success = true;
            
        catch
            % 如果Louvain失败，使用简单的连通分量
            if strcmp(net.graph_type, 'undirected')
                communities = conncomp(G);
            else
                communities = conncomp(G, 'Type', 'weak');
            end
            
            result.community_detection.community_assignments = communities;
            result.community_detection.modularity = calculate_modularity_simple(net.adjacency, communities);
            result.community_detection.n_communities = max(communities);
            result.community_detection.is_success = false;
            result.community_detection.error = '使用连通分量作为社区划分';
        end
        
        % 2. 社区统计
        if result.community_detection.is_success || isfield(result.community_detection, 'community_assignments')
            communities = result.community_detection.community_assignments;
            n_communities = result.community_detection.n_communities;
            
            result.community_stats = struct();
            
            % 社区大小分布
            community_sizes = zeros(1, n_communities);
            for i = 1:n_communities
                community_sizes(i) = sum(communities == i);
            end
            
            result.community_stats.community_sizes = community_sizes;
            result.community_stats.n_communities = n_communities;
            result.community_stats.largest_community_size = max(community_sizes);
            result.community_stats.smallest_community_size = min(community_sizes);
            result.community_stats.average_community_size = mean(community_sizes);
            
            % 社区大小统计
            if length(community_sizes) >= 2
                result.community_stats.community_size_std = std(community_sizes);
                result.community_stats.size_imbalance = std(community_sizes) / mean(community_sizes);
            else
                result.community_stats.community_size_std = 0;
                result.community_stats.size_imbalance = 0;
            end
            
            % 社区内连接密度
            result.community_stats.intra_community_density = calculate_intra_community_density(...
                net.adjacency, communities);
            
            % 社区间连接强度
            result.community_stats.inter_community_strength = calculate_inter_community_strength(...
                net.adjacency, communities);
        end
        
        % 3. 模块度分析
        result.modularity_analysis = struct();
        
        if isfield(result.community_detection, 'modularity')
            modularity = result.community_detection.modularity;
            result.modularity_analysis.modularity_value = modularity;
            
            % 模块度评估
            if modularity > 0.6
                result.modularity_analysis.assessment = '强模块结构';
                result.modularity_analysis.quality = '优秀';
            elseif modularity > 0.3
                result.modularity_analysis.assessment = '中等模块结构';
                result.modularity_analysis.quality = '良好';
            elseif modularity > 0.1
                result.modularity_analysis.assessment = '弱模块结构';
                result.modularity_analysis.quality = '一般';
            else
                result.modularity_analysis.assessment = '无明显模块结构';
                result.modularity_analysis.quality = '较差';
            end
            
            % 与随机网络比较
            if net.density > 0
                random_modularity = 0;  % 随机网络的模块度接近0
                result.modularity_analysis.vs_random = modularity - random_modularity;
                
                if modularity > 0.3
                    result.modularity_analysis.significance = '显著高于随机网络';
                else
                    result.modularity_analysis.significance = '与随机网络差异不大';
                end
            end
        end
        
        % 4. 社区质量评估
        result.community_quality = struct();
        
        if isfield(result.community_stats, 'size_imbalance')
            imbalance = result.community_stats.size_imbalance;
            
            if imbalance < 0.3
                result.community_quality.size_balance = '社区大小均衡';
                result.community_quality.balance_quality = '优秀';
            elseif imbalance < 0.6
                result.community_quality.size_balance = '社区大小中等不平衡';
                result.community_quality.balance_quality = '良好';
            else
                result.community_quality.size_balance = '社区大小高度不平衡';
                result.community_quality.balance_quality = '较差';
            end
        end
        
        if isfield(result.community_stats, 'intra_community_density')
            intra_density = result.community_stats.intra_community_density;
            if intra_density > net.density * 2
                result.community_quality.intra_connection = '社区内部连接紧密';
            else
                result.community_quality.intra_connection = '社区内部连接一般';
            end
        end
        
        % 5. 评估
        result.assessment = struct();
        
        if isfield(result.modularity_analysis, 'assessment')
            result.assessment.modularity_assessment = result.modularity_analysis.assessment;
        end
        
        if isfield(result.community_stats, 'n_communities')
            n_comms = result.community_stats.n_communities;
            
            if n_comms == 1
                result.assessment.community_structure = '单社区网络';
                result.assessment.recommendation = '网络未显示出明显的社区结构';
            elseif n_comms <= 3
                result.assessment.community_structure = '少数社区结构';
                result.assessment.recommendation = '网络具有清晰的社区划分';
            elseif n_comms <= 10
                result.assessment.community_structure = '多社区结构';
                result.assessment.recommendation = '网络具有复杂的社区结构';
            else
                result.assessment.community_structure = '高度碎片化社区';
                result.assessment.recommendation = '网络社区结构较为碎片化';
            end
        end
        
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        result.is_success = true;
        
    catch ME
        result.error_message = ME.message;
        result.error_location = sprintf('%s (行: %d)', ME.stack(1).name, ME.stack(1).line);
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        result.is_success = false;
    end
end

%% 辅助函数
function [communities, modularity] = louvain_algorithm_undirected(A)
% 简化的Louvain算法（无向图）
    n = size(A, 1);
    communities = (1:n)';  % 初始每个节点一个社区
    
    % 简化的模块度优化
    m = sum(A(:)) / 2;  % 总边数
    k = sum(A, 2);      % 节点度
    
    % 迭代优化
    improved = true;
    max_iterations = 10;
    iteration = 0;
    
    while improved && iteration < max_iterations
        improved = false;
        iteration = iteration + 1;
        
        for i = 1:n
            current_community = communities(i);
            best_community = current_community;
            best_deltaQ = 0;
            
            % 获取邻居社区
            neighbors = find(A(i, :));
            neighbor_communities = unique(communities(neighbors));
            
            for j = 1:length(neighbor_communities)
                test_community = neighbor_communities(j);
                if test_community ~= current_community
                    % 计算模块度变化
                    deltaQ = calculate_delta_modularity_undirected(A, communities, i, test_community, m, k);
                    
                    if deltaQ > best_deltaQ
                        best_deltaQ = deltaQ;
                        best_community = test_community;
                    end
                end
            end
            
            if best_community ~= current_community && best_deltaQ > 0
                communities(i) = best_community;
                improved = true;
            end
        end
    end
    
    % 重新编号社区
    [~, ~, communities] = unique(communities);
    
    % 计算最终模块度
    modularity = calculate_modularity_undirected(A, communities, m, k);
end

function [communities, modularity] = louvain_algorithm_directed(A)
% 简化的Louvain算法（有向图）
    n = size(A, 1);
    communities = (1:n)';  % 初始每个节点一个社区
    
    % 简化的模块度优化
    m = sum(A(:));  % 总边数
    k_out = sum(A, 2);  % 出度
    k_in = sum(A, 1)';  % 入度
    
    % 迭代优化
    improved = true;
    max_iterations = 10;
    iteration = 0;
    
    while improved && iteration < max_iterations
        improved = false;
        iteration = iteration + 1;
        
        for i = 1:n
            current_community = communities(i);
            best_community = current_community;
            best_deltaQ = 0;
            
            % 获取邻居社区
            neighbors = union(find(A(i, :)), find(A(:, i)));
            neighbor_communities = unique(communities(neighbors));
            
            for j = 1:length(neighbor_communities)
                test_community = neighbor_communities(j);
                if test_community ~= current_community
                    % 计算模块度变化
                    deltaQ = calculate_delta_modularity_directed(A, communities, i, test_community, m, k_out, k_in);
                    
                    if deltaQ > best_deltaQ
                        best_deltaQ = deltaQ;
                        best_community = test_community;
                    end
                end
            end
            
            if best_community ~= current_community && best_deltaQ > 0
                communities(i) = best_community;
                improved = true;
            end
        end
    end
    
    % 重新编号社区
    [~, ~, communities] = unique(communities);
    
    % 计算最终模块度
    modularity = calculate_modularity_directed(A, communities, m, k_out, k_in);
end

function deltaQ = calculate_delta_modularity_undirected(A, communities, node, new_community, m, k)
% 计算无向图模块度变化
    n = size(A, 1);
    current_community = communities(node);
    
    if current_community == new_community
        deltaQ = 0;
        return;
    end
    
    % 计算当前社区的贡献
    nodes_in_current = find(communities == current_community);
    nodes_in_new = find(communities == new_community);
    
    % 移除节点对当前社区的影响
    sum_in_current = sum(sum(A(nodes_in_current, nodes_in_current))) / 2;
    sum_tot_current = sum(k(nodes_in_current));
    
    % 添加节点对新社区的影响
    sum_in_new = sum(sum(A([nodes_in_new; node], [nodes_in_new; node]))) / 2;
    sum_tot_new = sum(k([nodes_in_new; node]));
    
    % 计算模块度变化
    deltaQ = (sum_in_new / m - (sum_tot_new / (2*m))^2) ...
           - (sum_in_current / m - (sum_tot_current / (2*m))^2) ...
           - (sum(A(node, node)) / m - (k(node) / (2*m))^2);
end

function modularity = calculate_modularity_simple(A, communities)
% 计算简化的模块度
    n = size(A, 1);
    n_communities = max(communities);
    modularity = 0;
    
    m = sum(A(:)) / 2;  % 总边数
    k = sum(A, 2);      % 节点度
    
    for c = 1:n_communities
        nodes_in_c = find(communities == c);
        
        if isempty(nodes_in_c)
            continue;
        end
        
        % 社区内连接数
        lc = sum(sum(A(nodes_in_c, nodes_in_c))) / 2;
        
        % 社区总度数
        dc = sum(k(nodes_in_c));
        
        if m > 0
            modularity = modularity + (lc / m) - (dc / (2*m))^2;
        end
    end
end

function intra_density = calculate_intra_community_density(A, communities)
% 计算社区内部连接密度
    n_communities = max(communities);
    densities = zeros(1, n_communities);
    
    for c = 1:n_communities
        nodes_in_c = find(communities == c);
        n_nodes = length(nodes_in_c);
        
        if n_nodes <= 1
            densities(c) = 0;
            continue;
        end
        
        % 社区内子图
        subgraph = A(nodes_in_c, nodes_in_c);
        
        % 计算密度
        max_possible = n_nodes * (n_nodes - 1) / 2;
        if max_possible > 0
            densities(c) = sum(subgraph(:)) / 2 / max_possible;
        else
            densities(c) = 0;
        end
    end
    
    intra_density = mean(densities(densities > 0));
    if isnan(intra_density)
        intra_density = 0;
    end
end

function inter_strength = calculate_inter_community_strength(A, communities)
% 计算社区间连接强度
    n_communities = max(communities);
    strengths = zeros(n_communities, n_communities);
    
    for c1 = 1:n_communities
        nodes_c1 = find(communities == c1);
        for c2 = 1:n_communities
            if c1 ~= c2
                nodes_c2 = find(communities == c2);
                
                % 计算社区间连接数
                connections = sum(sum(A(nodes_c1, nodes_c2)));
                
                % 标准化
                n1 = length(nodes_c1);
                n2 = length(nodes_c2);
                max_possible = n1 * n2;
                
                if max_possible > 0
                    strengths(c1, c2) = connections / max_possible;
                end
            end
        end
    end
    
    % 平均社区间连接强度
    inter_strength = mean(strengths(strengths > 0));
    if isnan(inter_strength)
        inter_strength = 0;
    end
end