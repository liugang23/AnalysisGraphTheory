function result = network_analyze_path_properties(net, opts)
% ANALYZE_PATH_PROPERTIES - 分析网络路径特性
    
    result = struct();
    result.module_name = '路径分析';
    result.module_version = '1.0.0';
    result.start_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    try
        % 检查网络是否适合路径分析
        n_nodes = net.n_nodes;
        n_edges = net.n_edges;
        
        if n_nodes < 2
            result.assessment = struct();
            result.assessment.status = '跳过';
            result.assessment.reason = '节点数太少 (<2)，无法进行路径分析';
            result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            result.is_success = true;
            return;
        end
        
        if n_edges < 1
            result.assessment = struct();
            result.assessment.status = '跳过';
            result.assessment.reason = '边数太少 (<1)，无法进行路径分析';
            result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            result.is_success = true;
            return;
        end
        
        % 创建图对象
        if strcmp(net.graph_type, 'undirected')
            G = graph(net.adjacency, 'upper');
        else
            G = digraph(net.adjacency);
        end
        
        % 1. 计算最短路径
        result.path_computation = struct();
        
        try
            % 计算所有节点对的最短路径长度
            D = distances(G);
            
            % 将不可达路径设为Inf
            D(D == Inf) = Inf;
            
            result.path_computation.distance_matrix = D;
            result.path_computation.is_success = true;
            result.path_computation.message = '最短路径计算成功';
            
        catch ME
            result.path_computation.distance_matrix = [];
            result.path_computation.is_success = false;
            result.path_computation.error = sprintf('最短路径计算失败: %s', ME.message);
            result.path_computation.message = '使用替代方法计算路径特性';
            
            % 使用简单方法估算
            D = estimate_distances(net.adjacency, net.graph_type);
        end
        
        % 2. 基本路径统计
        result.path_statistics = struct();
        
        if isfield(result.path_computation, 'distance_matrix') && ...
           ~isempty(result.path_computation.distance_matrix)
            D = result.path_computation.distance_matrix;
            
            % 只考虑有限距离（排除Inf）
            finite_distances = D(isfinite(D) & D > 0);
            
            if ~isempty(finite_distances)
                % 平均路径长度
                result.path_statistics.average_path_length = mean(finite_distances);
                result.path_statistics.path_length_std = std(finite_distances);
                result.path_statistics.path_length_min = min(finite_distances);
                result.path_statistics.path_length_max = max(finite_distances);
                
                % 路径长度分布
                [counts, edges] = histcounts(finite_distances, 'BinMethod', 'integers');
                centers = (edges(1:end-1) + edges(2:end)) / 2;
                
                result.path_statistics.path_length_distribution = struct();
                result.path_statistics.path_length_distribution.counts = counts;
                result.path_statistics.path_length_distribution.centers = centers;
                result.path_statistics.path_length_distribution.edges = edges;
                
                % 计算中位数
                result.path_statistics.path_length_median = median(finite_distances);
                
                % 计算分位数
                result.path_statistics.path_length_quartiles = prctile(finite_distances, [25, 50, 75]);
                
                result.path_statistics.is_success = true;
            else
                result.path_statistics.is_success = false;
                result.path_statistics.error = '没有有效的有限距离值';
            end
        end
        
        % 3. 网络直径
        result.diameter_analysis = struct();
        
        if isfield(result.path_statistics, 'is_success') && result.path_statistics.is_success
            result.diameter_analysis.diameter = result.path_statistics.path_length_max;
            result.diameter_analysis.is_success = true;
            
            % 直径评估
            if result.diameter_analysis.diameter > 10
                result.diameter_analysis.assessment = '网络直径较大，节点间距离较远';
            elseif result.diameter_analysis.diameter > 5
                result.diameter_analysis.assessment = '网络直径中等';
            else
                result.diameter_analysis.assessment = '网络直径较小，节点间距离较近';
            end
        end
        
        % 4. 网络效率
        result.efficiency_analysis = struct();
        
        if isfield(result.path_computation, 'distance_matrix') && ...
           ~isempty(result.path_computation.distance_matrix)
            D = result.path_computation.distance_matrix;
            
            try
                efficiency = calculate_network_efficiency_matrix(D);
                result.efficiency_analysis.global_efficiency = efficiency;
                result.efficiency_analysis.is_success = true;
                
                % 效率评估
                if efficiency > 0.7
                    result.efficiency_analysis.assessment = '网络效率很高，信息传递迅速';
                elseif efficiency > 0.4
                    result.efficiency_analysis.assessment = '网络效率中等';
                else
                    result.efficiency_analysis.assessment = '网络效率较低，信息传递较慢';
                end
                
            catch
                result.efficiency_analysis.global_efficiency = NaN;
                result.efficiency_analysis.is_success = false;
            end
        end
        
        % 5. 小世界特性分析
        result.small_world_analysis = struct();
        
        if isfield(result.path_statistics, 'is_success') && result.path_statistics.is_success && ...
           isfield(result, 'clustering_reference')
            % 需要聚类系数作为参考
            try
                % 计算小世界性
                [sigma, omega] = calculate_small_world_measures(...
                    result.path_statistics.average_path_length, ...
                    result.clustering_reference, ...
                    net.density, n_nodes);
                
                result.small_world_analysis.sigma = sigma;  % 小世界性指数
                result.small_world_analysis.omega = omega;  % 小世界性度量
                result.small_world_analysis.is_success = true;
                
                % 小世界网络判断
                if sigma > 1 && sigma < 3
                    result.small_world_analysis.assessment = '具有小世界特性';
                    result.small_world_analysis.network_type = '小世界网络';
                else
                    result.small_world_analysis.assessment = '无明显小世界特性';
                    result.small_world_analysis.network_type = '非小世界网络';
                end
                
            catch
                result.small_world_analysis.is_success = false;
            end
        end
        
        % 6. 路径特性评估
        result.path_assessment = struct();
        
        if isfield(result.path_statistics, 'is_success') && result.path_statistics.is_success
            avg_path = result.path_statistics.average_path_length;
            
            if avg_path < 2
                result.path_assessment.path_length_assessment = '路径长度很短，网络连接紧密';
                result.path_assessment.path_quality = '优秀';
            elseif avg_path < 4
                result.path_assessment.path_length_assessment = '路径长度适中';
                result.path_assessment.path_quality = '良好';
            else
                result.path_assessment.path_length_assessment = '路径长度较长，网络连接较松散';
                result.path_assessment.path_quality = '一般';
            end
        end
        
        if isfield(result.efficiency_analysis, 'is_success') && result.efficiency_analysis.is_success
            efficiency = result.efficiency_analysis.global_efficiency;
            
            if efficiency > 0.6
                result.path_assessment.efficiency_assessment = '网络效率很高';
            elseif efficiency > 0.3
                result.path_assessment.efficiency_assessment = '网络效率中等';
            else
                result.path_assessment.efficiency_assessment = '网络效率较低';
            end
        end
        
        % 7. 建议
        result.path_recommendations = {};
        
        if isfield(result.path_statistics, 'average_path_length')
            avg_path = result.path_statistics.average_path_length;
            if avg_path > 5
                result.path_recommendations{end+1} = ...
                    sprintf('平均路径长度较长(%.2f)，建议增加连接以提高网络效率', avg_path);
            end
        end
        
        if isfield(result.efficiency_analysis, 'global_efficiency')
            efficiency = result.efficiency_analysis.global_efficiency;
            if efficiency < 0.3
                result.path_recommendations{end+1} = ...
                    sprintf('网络效率较低(%.3f)，可能存在连通性问题', efficiency);
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
function D = estimate_distances(A, graph_type)
% 估算距离矩阵
    
    n = size(A, 1);
    D = Inf(n, n);
    
    % 初始化直接连接的距离
    for i = 1:n
        for j = 1:n
            if i ~= j && A(i, j) > 0
                D(i, j) = 1;
            end
        end
        D(i, i) = 0;
    end
    
    % 简化的Floyd-Warshall算法（最多3步）
    for k = 1:n
        for i = 1:n
            for j = 1:n
                if D(i, k) < Inf && D(k, j) < Inf
                    new_dist = D(i, k) + D(k, j);
                    if new_dist < D(i, j)
                        D(i, j) = new_dist;
                    end
                end
            end
        end
    end
    
    % 对称化（如果是无向图）
    if strcmp(graph_type, 'undirected')
        D = min(D, D');
    end
end

function efficiency = calculate_network_efficiency_matrix(D)
% 计算网络效率
    
    n = size(D, 1);
    total_efficiency = 0;
    count = 0;
    
    for i = 1:n
        for j = 1:n
            if i ~= j && D(i, j) < Inf && D(i, j) > 0
                total_efficiency = total_efficiency + 1 / D(i, j);
                count = count + 1;
            end
        end
    end
    
    if count > 0
        efficiency = total_efficiency / count;
    else
        efficiency = 0;
    end
end

function [sigma, omega] = calculate_small_world_measures(L, C, p, n)
% 计算小世界性指标
    
    % 随机网络的期望路径长度
    L_rand = log(n) / log(n * p);
    
    % 随机网络的期望聚类系数
    C_rand = p;
    
    % 避免除以0
    if C_rand == 0 || L_rand == 0
        sigma = 0;
        omega = 0;
        return;
    end
    
    % 小世界性指数
    sigma = (C / C_rand) / (L / L_rand);
    
    % 小世界性度量
    omega = (L_rand / L) - (C / C_rand);
end