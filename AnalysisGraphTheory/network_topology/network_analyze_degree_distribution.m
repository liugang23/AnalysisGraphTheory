function result = network_analyze_degree_distribution(net, opts)
% ANALYZE_DEGREE_DISTRIBUTION - 分析节点度分布
    
    result = struct();
    result.module_name = '度分布分析';
    result.module_version = '1.0.0';
    result.start_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    try
        % 1. 计算节点度
        if isfield(net, 'node_degrees')
            degrees = net.node_degrees;
        else
            % 手动计算度
            if strcmp(net.graph_type, 'undirected')
                degrees = sum(net.adjacency, 2);
            else
                degrees = sum(net.adjacency, 2);  % 出度
            end
        end
        
        % 2. 基本统计
        result.degree_stats = struct();
        result.degree_stats.mean = mean(degrees);
        result.degree_stats.median = median(degrees);
        result.degree_stats.std = std(degrees);
        result.degree_stats.min = min(degrees);
        result.degree_stats.max = max(degrees);
        result.degree_stats.total = sum(degrees);
        result.degree_stats.n_valid = length(degrees);
        
        % 3. 度分布直方图
        [counts, edges] = histcounts(degrees, 'BinMethod', 'integers');
        centers = (edges(1:end-1) + edges(2:end)) / 2;
        
        result.degree_distribution = struct();
        result.degree_distribution.counts = counts;
        result.degree_distribution.centers = centers;
        result.degree_distribution.edges = edges;
        
        % 4. 度异质性
        if result.degree_stats.mean > 0
            result.degree_heterogeneity = result.degree_stats.std / result.degree_stats.mean;
            
            if result.degree_heterogeneity > 1.5
                result.heterogeneity_assessment = '高度异质 (存在枢纽节点)';
            elseif result.degree_heterogeneity > 0.8
                result.heterogeneity_assessment = '中等异质';
            else
                result.heterogeneity_assessment = '同质';
            end
        else
            result.degree_heterogeneity = NaN;
            result.heterogeneity_assessment = '无法计算';
        end
        
        % 5. 评估
        result.assessment = struct();
        
        if result.degree_heterogeneity > 1.5
            result.assessment.degree_distribution_type = '无标度网络特性';
            result.assessment.recommendation = '网络存在明显的枢纽节点，适合枢纽-辐射型分析';
        else
            result.assessment.degree_distribution_type = '均匀度分布';
            result.assessment.recommendation = '节点度分布相对均匀，无明显枢纽节点';
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