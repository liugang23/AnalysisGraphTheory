function result = analyze_triangles(adjacency, is_directed, verbose)
% ANALYZE_TRIANGLES - 分析网络中的三角形闭合
% 
% 【功能】统计三角形数量、计算闭合系数、传递性
% 【算法】基于邻接矩阵的立方运算
% 【输出】三角形数量、闭合系数、传递性
    
    result = struct();
    result.module_name = '三角形闭合分析';
    result.is_success = false;
    result.start_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    try
        n_nodes = size(adjacency, 1);
        
        if is_directed
            % 有向图三角形分析
            [triangles, clustering_coefficient, transitivity] = ...
                analyze_triangles_directed(adjacency);
        else
            % 无向图三角形分析
            [triangles, clustering_coefficient, transitivity] = ...
                analyze_triangles_undirected(adjacency);
        end
        
        % 组织结果
        result.triangles = triangles;  % 所有三角形列表
        result.n_triangles = size(triangles, 1);
        result.global_clustering_coefficient = clustering_coefficient;
        result.transitivity = transitivity;
        
        % 计算局部聚类系数
        result.local_clustering = calculate_local_clustering_coefficient(adjacency, is_directed);
        
        % 三角形参与节点统计
        if result.n_triangles > 0
            triangle_nodes = unique(triangles(:));
            result.n_nodes_in_triangles = length(triangle_nodes);
            result.triangle_node_ratio = result.n_nodes_in_triangles / n_nodes;
        end
        
        result.is_success = true;
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        
        if verbose
            fprintf('      检测到 %d 个三角形，全局聚类系数: %.4f\n', ...
                result.n_triangles, result.global_clustering_coefficient);
        end
        
    catch ME
        result.error_message = ME.message;
        result.error_location = sprintf('%s (行: %d)', ME.stack(1).name, ME.stack(1).line);
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        if verbose
            fprintf('      三角形分析失败: %s\n', ME.message);
        end
    end
end