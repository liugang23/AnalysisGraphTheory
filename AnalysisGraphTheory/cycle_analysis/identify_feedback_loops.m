function result = identify_feedback_loops(adjacency, max_length, verbose)
% IDENTIFY_FEEDBACK_LOOPS - 识别网络中的反馈回路
% 
% 【功能】识别闭合的因果链，分析反馈机制
% 【算法】基于有向环检测和因果分析
% 【输出】反馈回路列表、反馈强度、稳定性评估
    
    result = struct();
    result.module_name = '反馈回路识别';
    result.is_success = false;
    result.start_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    try
        % 检测有向环作为候选反馈回路
        directed_cycles = detect_directed_cycles(adjacency, max_length);
        
        % 过滤真正的反馈回路（基于权重或因果强度）
        feedback_loops = filter_feedback_loops(directed_cycles, adjacency);
        
        % 组织结果
        result.feedback_loops = feedback_loops;
        result.n_feedback_loops = length(feedback_loops);
        
        % 分析反馈特性
        if result.n_feedback_loops > 0
            result.feedback_stats = analyze_feedback_characteristics(feedback_loops, adjacency);
            
            % 反馈类型分类
            result.feedback_types = classify_feedback_types(feedback_loops, adjacency);
            
            % 反馈稳定性分析
            result.stability_analysis = assess_feedback_stability(feedback_loops, adjacency);
        end
        
        % 计算反馈强度
        result.feedback_strength = calculate_feedback_strength(adjacency);
        
        result.is_success = true;
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        
        if verbose
            fprintf('      识别到 %d 个反馈回路\n', result.n_feedback_loops);
        end
        
    catch ME
        result.error_message = ME.message;
        result.error_location = sprintf('%s (行: %d)', ME.stack(1).name, ME.stack(1).line);
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        if verbose
            fprintf('      反馈回路识别失败: %s\n', ME.message);
        end
    end
end