function result = calculate_cycle_statistics(cycle_results, n_nodes, verbose)
% CALCULATE_CYCLE_STATISTICS - 计算环的统计特征
% 
% 【功能】综合各子模块结果，计算环的总体统计特征
% 【输出】环的数量、大小、分布、密度等统计
    
    result = struct();
    result.module_name = '环统计特征';
    result.is_success = false;
    result.start_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    try
        % 初始化统计
        result.total_cycles = 0;
        result.cycle_lengths = [];
        result.cycle_types = {};
        
        % 汇总简单环统计
        if isfield(cycle_results.simple_cycles, 'n_cycles') && ...
           cycle_results.simple_cycles.n_cycles > 0
            result.simple_cycles_count = cycle_results.simple_cycles.n_cycles;
            result.simple_cycle_lengths = cycle_results.simple_cycles.cycle_lengths;
            result.total_cycles = result.total_cycles + result.simple_cycles_count;
            result.cycle_lengths = [result.cycle_lengths; result.simple_cycle_lengths(:)];
            result.cycle_types = [result.cycle_types; repmat({'simple'}, result.simple_cycles_count, 1)];
        end
        
        % 汇总三角形统计
        if isfield(cycle_results.triangles, 'n_triangles') && ...
           cycle_results.triangles.n_triangles > 0
            result.triangles_count = cycle_results.triangles.n_triangles;
            result.total_cycles = result.total_cycles + result.triangles_count;
            result.cycle_lengths = [result.cycle_lengths; 3 * ones(result.triangles_count, 1)];
            result.cycle_types = [result.cycle_types; repmat({'triangle'}, result.triangles_count, 1)];
        end
        
        % 汇总有向环统计
        if isfield(cycle_results.directed_cycles, 'n_directed_cycles') && ...
           cycle_results.directed_cycles.n_directed_cycles > 0
            result.directed_cycles_count = cycle_results.directed_cycles.n_directed_cycles;
            result.total_cycles = result.total_cycles + result.directed_cycles_count;
        end
        
        % 计算总体统计
        if ~isempty(result.cycle_lengths)
            result.stats.min_cycle_length = min(result.cycle_lengths);
            result.stats.max_cycle_length = max(result.cycle_lengths);
            result.stats.mean_cycle_length = mean(result.cycle_lengths);
            result.stats.median_cycle_length = median(result.cycle_lengths);
            result.stats.std_cycle_length = std(result.cycle_lengths);
            
            % 环长度分布
            unique_lengths = unique(result.cycle_lengths);
            result.length_distribution = histcounts(result.cycle_lengths, ...
                [unique_lengths; max(unique_lengths)+1]-0.5);
            
            % 环密度（每节点平均环数）
            result.cycle_density = result.total_cycles / n_nodes;
        end
        
        % 环类型分布
        if ~isempty(result.cycle_types)
            [unique_types, ~, idx] = unique(result.cycle_types);
            type_counts = accumarray(idx, 1);
            result.type_distribution = struct();
            for i = 1:length(unique_types)
                result.type_distribution.(unique_types{i}) = type_counts(i);
            end
        end
        
        result.is_success = true;
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        
        if verbose
            fprintf('      总环数: %d，平均长度: %.2f\n', ...
                result.total_cycles, result.stats.mean_cycle_length);
        end
        
    catch ME
        result.error_message = ME.message;
        result.error_location = sprintf('%s (行: %d)', ME.stack(1).name, ME.stack(1).line);
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        if verbose
            fprintf('      环统计计算失败: %s\n', ME.message);
        end
    end
end