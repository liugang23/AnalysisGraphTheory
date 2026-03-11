function result = analyze_simple_cycles(adjacency, is_directed, max_length, method, verbose)
% ANALYZE_SIMPLE_CYCLES - 检测网络中的简单环
% 
% 【功能】检测网络中所有长度不超过max_length的简单环
% 【算法】基于深度优先搜索(DFS)或Johnson算法
% 【输出】环的节点序列、环的长度、环的数量统计
    
    result = struct();
    result.module_name = '简单环检测';
    result.is_success = false;
    result.start_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    try
        n_nodes = size(adjacency, 1);
        
        % 根据方法选择检测算法
        switch method
            case 'dfs'
                cycles = detect_cycles_dfs(adjacency, is_directed, max_length);
            case 'johnson'
                cycles = detect_cycles_johnson(adjacency, is_directed, max_length);
            case 'tarjan'
                cycles = detect_cycles_tarjan(adjacency, is_directed, max_length);
            otherwise
                cycles = detect_cycles_dfs(adjacency, is_directed, max_length);
        end
        
        % 组织结果
        result.cycles = cycles;  % 环的节点序列
        result.n_cycles = length(cycles);
        result.cycle_lengths = cellfun(@length, cycles);
        
        % 计算统计
        if result.n_cycles > 0
            result.stats.min_length = min(result.cycle_lengths);
            result.stats.max_length = max(result.cycle_lengths);
            result.stats.mean_length = mean(result.cycle_lengths);
            result.stats.median_length = median(result.cycle_lengths);
            
            % 环长度分布
            [result.length_distribution.counts, result.length_distribution.edges] = ...
                histcounts(result.cycle_lengths, 3:max_length+1);
        end
        
        result.is_success = true;
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        
        if verbose
            fprintf('      检测到 %d 个简单环 (长度: %d-%d)\n', ...
                result.n_cycles, result.stats.min_length, result.stats.max_length);
        end
        
    catch ME
        result.error_message = ME.message;
        result.error_location = sprintf('%s (行: %d)', ME.stack(1).name, ME.stack(1).line);
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        if verbose
            fprintf('      简单环检测失败: %s\n', ME.message);
        end
    end
end