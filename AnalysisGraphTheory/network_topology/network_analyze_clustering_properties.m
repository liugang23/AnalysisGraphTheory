function result = network_analyze_clustering_properties(net, opts)
% ANALYZE_CLUSTERING_PROPERTIES - 分析网络聚类特性
    
    result = struct();
    result.module_name = '聚类分析';
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
        
        % 1. 局部聚类系数计算
        result.local_clustering = struct();
        
        if strcmp(net.graph_type, 'undirected')
            % 无向图聚类系数
            try
                local_cc = clustering_coefficient_undirected(net.adjacency);
                result.local_clustering.values = local_cc;
                result.local_clustering.is_success = true;
            catch
                result.local_clustering.values = NaN(n_nodes, 1);
                result.local_clustering.is_success = false;
                result.local_clustering.error = '局部聚类系数计算失败';
            end
        else
            % 有向图聚类系数
            try
                local_cc = clustering_coefficient_directed(net.adjacency);
                result.local_clustering.values = local_cc;
                result.local_clustering.is_success = true;
            catch
                result.local_clustering.values = NaN(n_nodes, 1);
                result.local_clustering.is_success = false;
                result.local_clustering.error = '有向图聚类系数计算失败';
            end
        end
        
        % 2. 全局聚类系数
        result.global_clustering = struct();
        
        if isfield(result.local_clustering, 'is_success') && result.local_clustering.is_success
            local_values = result.local_clustering.values;
            valid_values = local_values(~isnan(local_values));
            
            if ~isempty(valid_values)
                result.global_clustering.value = mean(valid_values);
                result.global_clustering.is_success = true;
            else
                result.global_clustering.value = NaN;
                result.global_clustering.is_success = false;
            end
        else
            result.global_clustering.value = NaN;
            result.global_clustering.is_success = false;
        end
        
        % 3. 传递性（Transitivity）
        result.transitivity = struct();
        
        try
            if strcmp(net.graph_type, 'undirected')
                trans_value = calculate_transitivity_undirected(net.adjacency);
            else
                trans_value = calculate_transitivity_directed(net.adjacency);
            end
            result.transitivity.value = trans_value;
            result.transitivity.is_success = true;
        catch
            result.transitivity.value = NaN;
            result.transitivity.is_success = false;
            result.transitivity.error = '传递性计算失败';
        end
        
        % 4. 小世界性初步检查
        result.small_world_analysis = struct();
        
        if result.global_clustering.is_success && ~isnan(result.global_clustering.value)
            % 与随机网络比较
            if net.density > 0
                % 随机网络的期望聚类系数等于连接概率
                random_cc = net.density;
                result.small_world_analysis.clustering_ratio = result.global_clustering.value / random_cc;
                result.small_world_analysis.random_network_cc = random_cc;
                
                if result.small_world_analysis.clustering_ratio > 2
                    result.small_world_analysis.assessment = '高度聚类 (可能是小世界网络)';
                elseif result.small_world_analysis.clustering_ratio > 1.5
                    result.small_world_analysis.assessment = '中等聚类';
                else
                    result.small_world_analysis.assessment = '低聚类';
                end
            end
        end
        
        % 5. 聚类统计
        if result.local_clustering.is_success
            local_values = result.local_clustering.values;
            valid_values = local_values(~isnan(local_values));
            
            if ~isempty(valid_values)
                result.clustering_stats = struct();
                result.clustering_stats.mean = mean(valid_values);
                result.clustering_stats.median = median(valid_values);
                result.clustering_stats.std = std(valid_values);
                result.clustering_stats.min = min(valid_values);
                result.clustering_stats.max = max(valid_values);
                
                % 高聚类节点比例
                high_cluster_threshold = 0.5;
                high_cluster_nodes = sum(valid_values > high_cluster_threshold);
                result.clustering_stats.high_cluster_ratio = high_cluster_nodes / length(valid_values);
            end
        end
        
        % 6. 评估
        result.assessment = struct();
        
        if result.global_clustering.is_success && ~isnan(result.global_clustering.value)
            global_cc = result.global_clustering.value;
            
            if global_cc > 0.5
                result.assessment.global_clustering_assessment = '网络高度聚类';
                result.assessment.global_clustering_quality = '优秀';
            elseif global_cc > 0.2
                result.assessment.global_clustering_assessment = '网络中等聚类';
                result.assessment.global_clustering_quality = '良好';
            else
                result.assessment.global_clustering_assessment = '网络低聚类';
                result.assessment.global_clustering_quality = '一般';
            end
        end
        
        if isfield(result.small_world_analysis, 'assessment')
            result.assessment.small_world_potential = result.small_world_analysis.assessment;
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
function cc = clustering_coefficient_undirected(A)
% 计算无向图聚类系数
    n = size(A, 1);
    cc = zeros(n, 1);
    
    for i = 1:n
        % 找到邻居节点
        neighbors = find(A(i, :));
        k = length(neighbors);
        
        if k < 2
            cc(i) = 0;
            continue;
        end
        
        % 计算邻居间的连接数
        subgraph = A(neighbors, neighbors);
        num_triangles = sum(subgraph(:)) / 2;
        
        % 计算最大可能三角形数
        max_triangles = k * (k - 1) / 2;
        
        if max_triangles > 0
            cc(i) = num_triangles / max_triangles;
        else
            cc(i) = 0;
        end
    end
end

function cc = clustering_coefficient_directed(A)
% 计算有向图聚类系数
    n = size(A, 1);
    cc = zeros(n, 1);
    
    for i = 1:n
        % 找到邻居节点（出边和入边）
        out_neighbors = find(A(i, :));
        in_neighbors = find(A(:, i));
        all_neighbors = union(out_neighbors, in_neighbors);
        
        k = length(all_neighbors);
        
        if k < 2
            cc(i) = 0;
            continue;
        end
        
        % 计算有向三角形数
        num_triangles = 0;
        for j = 1:length(all_neighbors)
            for m = j+1:length(all_neighbors)
                n1 = all_neighbors(j);
                n2 = all_neighbors(m);
                
                % 检查是否存在三角形
                if (A(n1, n2) || A(n2, n1)) && (A(i, n1) || A(n1, i)) && (A(i, n2) || A(n2, i))
                    num_triangles = num_triangles + 1;
                end
            end
        end
        
        % 计算最大可能三角形数
        max_triangles = k * (k - 1);
        
        if max_triangles > 0
            cc(i) = num_triangles / max_triangles;
        else
            cc(i) = 0;
        end
    end
end

function transitivity = calculate_transitivity_undirected(A)
% 计算无向图传递性
    n = size(A, 1);
    
    % 计算三角形数量
    triangles = 0;
    for i = 1:n
        for j = i+1:n
            if A(i, j)
                for k = j+1:n
                    if A(j, k) && A(i, k)
                        triangles = triangles + 1;
                    end
                end
            end
        end
    end
    
    % 计算连通三元组数量
    connected_triples = 0;
    for i = 1:n
        k = sum(A(i, :));
        connected_triples = connected_triples + k * (k - 1) / 2;
    end
    
    if connected_triples > 0
        transitivity = 3 * triangles / connected_triples;
    else
        transitivity = 0;
    end
end

function transitivity = calculate_transitivity_directed(A)
% 计算有向图传递性
    n = size(A, 1);
    
    % 计算有向三角形数量
    triangles = 0;
    for i = 1:n
        for j = 1:n
            if i ~= j && A(i, j)
                for k = 1:n
                    if k ~= i && k ~= j && A(j, k) && A(k, i)
                        triangles = triangles + 1;
                    end
                end
            end
        end
    end
    
    % 计算有向三元组数量
    connected_triples = 0;
    for i = 1:n
        for j = 1:n
            if i ~= j && A(i, j)
                for k = 1:n
                    if k ~= i && k ~= j && (A(j, k) || A(k, j))
                        connected_triples = connected_triples + 1;
                    end
                end
            end
        end
    end
    
    if connected_triples > 0
        transitivity = triangles / connected_triples;
    else
        transitivity = 0;
    end
end