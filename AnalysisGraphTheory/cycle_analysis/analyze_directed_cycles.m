function result = analyze_directed_cycles(adjacency, max_length, verbose)
% ANALYZE_DIRECTED_CYCLES - 分析有向图中的环结构
% 
% 【功能】识别有向图中的有向环，分析强连通分量
% 【算法】基于Tarjan或Kosaraju算法
% 【输出】有向环列表、强连通分量、环的因果方向
    
    result = struct();
    result.module_name = '有向环分析';
    result.is_success = false;
    result.start_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    try
        n_nodes = size(adjacency, 1);
        
        % 检测强连通分量（SCC）
        [sccs, scc_index] = find_strongly_connected_components(adjacency);
        
        % 检测有向环
        directed_cycles = detect_directed_cycles(adjacency, max_length);
        
        % 组织结果
        result.strongly_connected_components = sccs;
        result.n_sccs = length(sccs);
        result.scc_sizes = cellfun(@length, sccs);
        
        result.directed_cycles = directed_cycles;
        result.n_directed_cycles = length(directed_cycles);
        
        % 计算SCC统计
        if result.n_sccs > 0
            result.scc_stats.largest_scc_size = max(result.scc_sizes);
            result.scc_stats.smallest_scc_size = min(result.scc_sizes);
            result.scc_stats.mean_scc_size = mean(result.scc_sizes);
            result.scc_stats.scc_size_distribution = histcounts(result.scc_sizes, 1:n_nodes+1);
        end
        
        % 分析环的方向模式
        if result.n_directed_cycles > 0
            result.cycle_directions = analyze_cycle_directions(directed_cycles, adjacency);
        end
        
        result.is_success = true;
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        
        if verbose
            fprintf('      发现 %d 个强连通分量，%d 个有向环\n', ...
                result.n_sccs, result.n_directed_cycles);
        end
        
    catch ME
        result.error_message = ME.message;
        result.error_location = sprintf('%s (行: %d)', ME.stack(1).name, ME.stack(1).line);
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        if verbose
            fprintf('      有向环分析失败: %s\n', ME.message);
        end
    end
end