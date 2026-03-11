function result = assess_cycle_structures(cycle_results, verbose)
% ASSESS_CYCLE_STRUCTURES - 评估环结构对网络功能的影响
% 
% 【功能】评估环的稳定性、重要性、对网络功能的影响
% 【输出】环结构质量评估、网络稳定性评分、功能影响分析
    
    result = struct();
    result.module_name = '环结构评估';
    result.is_success = false;
    result.start_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    try
        % 初始化评估结果
        result.quality_assessment = struct();
        result.stability_rating = struct();
        result.functional_impact = struct();
        
        % 1. 环结构丰富度评估
        if isfield(cycle_results.cycle_stats, 'total_cycles')
            total_cycles = cycle_results.cycle_stats.total_cycles;
            
            if total_cycles == 0
                result.quality_assessment.cycle_richness = '无环结构';
                result.quality_assessment.richness_score = 1;
            elseif total_cycles < 5
                result.quality_assessment.cycle_richness = '稀疏环结构';
                result.quality_assessment.richness_score = 3;
            elseif total_cycles < 20
                result.quality_assessment.cycle_richness = '中等环结构';
                result.quality_assessment.richness_score = 5;
            else
                result.quality_assessment.cycle_richness = '丰富环结构';
                result.quality_assessment.richness_score = 7;
            end
        end
        
        % 2. 环多样性评估
        if isfield(cycle_results.cycle_stats, 'type_distribution')
            type_dist = cycle_results.cycle_stats.type_distribution;
            n_types = length(fieldnames(type_dist));
            
            if n_types == 0
                result.quality_assessment.cycle_diversity = '无多样性';
                result.quality_assessment.diversity_score = 1;
            elseif n_types == 1
                result.quality_assessment.cycle_diversity = '单一类型';
                result.quality_assessment.diversity_score = 3;
            elseif n_types == 2
                result.quality_assessment.cycle_diversity = '中等多样性';
                result.quality_assessment.diversity_score = 5;
            else
                result.quality_assessment.cycle_diversity = '高多样性';
                result.quality_assessment.diversity_score = 7;
            end
        end
        
        % 3. 稳定性评估（基于反馈回路）
        if isfield(cycle_results.feedback_loops, 'stability_analysis')
            stability = cycle_results.feedback_loops.stability_analysis;
            
            if stability.overall_stability > 0.7
                result.stability_rating.overall_stability = '高度稳定';
                result.stability_rating.stability_score = 8;
            elseif stability.overall_stability > 0.4
                result.stability_rating.overall_stability = '中等稳定';
                result.stability_rating.stability_score = 5;
            else
                result.stability_rating.overall_stability = '不稳定';
                result.stability_rating.stability_score = 2;
            end
        end
        
        % 4. 功能影响评估
        result.functional_impact.assessment = assess_functional_impact(cycle_results);
        result.functional_impact.recommendations = generate_recommendations(cycle_results);
        
        % 5. 综合评分
        scores = [];
        if isfield(result.quality_assessment, 'richness_score')
            scores(end+1) = result.quality_assessment.richness_score;
        end
        if isfield(result.quality_assessment, 'diversity_score')
            scores(end+1) = result.quality_assessment.diversity_score;
        end
        if isfield(result.stability_rating, 'stability_score')
            scores(end+1) = result.stability_rating.stability_score;
        end
        
        if ~isempty(scores)
            result.overall_score = mean(scores);
            
            if result.overall_score >= 7
                result.overall_assessment = '环结构优秀';
            elseif result.overall_score >= 5
                result.overall_assessment = '环结构良好';
            elseif result.overall_score >= 3
                result.overall_assessment = '环结构一般';
            else
                result.overall_assessment = '环结构需改进';
            end
        end
        
        result.is_success = true;
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        
        if verbose
            fprintf('      环结构评估: %s (评分: %.1f/10)\n', ...
                result.overall_assessment, result.overall_score);
        end
        
    catch ME
        result.error_message = ME.message;
        result.error_location = sprintf('%s (行: %d)', ME.stack(1).name, ME.stack(1).line);
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        if verbose
            fprintf('      环结构评估失败: %s\n', ME.message);
        end
    end
end