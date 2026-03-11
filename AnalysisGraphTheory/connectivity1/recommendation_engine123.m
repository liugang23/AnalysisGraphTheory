function [recommendations, priority_scores] = recommendation_engine(...
    analysis_summary, params, user_context)
% RECOMMENDATION_ENGINE - 智能分析建议引擎
%
% 【功能描述】
% 基于分析结果和上下文信息，生成智能化的分析建议和改进方案。
% 支持多维度评估和优先级排序。
%
% 【主要功能】
% 1. 多维度问题诊断
% 2. 智能建议生成
% 3. 优先级评估与排序
% 4. 上下文感知建议
%
% 输入参数:
%   analysis_summary: 结构体，分析摘要
%
%   params: 结构体，分析参数
%
%   user_context: 结构体，用户上下文（可选）
%                - experience_level: 字符串，用户经验水平
%                - analysis_purpose: 字符串，分析目的
%                - resource_constraints: 结构体，资源限制
%
% 输出参数:
%   recommendations: 元胞数组，建议列表
%                   每个建议为结构体，包含:
%                     - id: 字符串，建议ID
%                     - text: 字符串，建议文本
%                     - category: 字符串，建议类别
%                     - priority: 数值，优先级(1-5)
%                     - rationale: 字符串，建议依据
%                     - action_steps: 元胞数组，具体步骤
%                     - expected_impact: 字符串，预期影响
%
%   priority_scores: 结构体，各维度的优先级评分
%
% 示例:
%   [recs, scores] = recommendation_engine(summary, params, context);
%
% 版本: 3.0
% 作者: Financial Network Analysis Toolbox
% 创建日期: 2024-12-28
% =========================================================================

%% 初始化
recommendations = {};
priority_scores = struct();

% 默认用户上下文
if nargin < 3 || isempty(user_context)
    user_context = struct(...
        'experience_level', 'intermediate', ...
        'analysis_purpose', 'exploratory', ...
        'resource_constraints', struct('time', 'moderate', 'memory', 'moderate'));
end

fprintf('生成分析建议...\n');

%% 1. 多维度问题诊断
diagnostics = perform_multidimensional_diagnosis(analysis_summary, params, user_context);

%% 2. 生成建议
recommendations = generate_recommendations(diagnostics, analysis_summary, user_context);

%% 3. 优先级评估
priority_scores = assess_recommendation_priority(recommendations, diagnostics, user_context);

%% 4. 排序建议
recommendations = sort_recommendations_by_priority(recommendations, priority_scores);

fprintf('生成 %d 条分析建议\n', length(recommendations));

end

%% ==================== 核心建议函数 ====================

function diagnostics = perform_multidimensional_diagnosis(summary, params, context)
% 执行多维度问题诊断
    
    diagnostics = struct();
    
    %% 维度1: 数据质量诊断
    diagnostics.data_quality = diagnose_data_quality(summary);
    
    %% 维度2: 统计功效诊断
    diagnostics.statistical_power = diagnose_statistical_power(summary, params);
    
    %% 维度3: 方法适用性诊断
    diagnostics.method_suitability = diagnose_method_suitability(summary, params);
    
    %% 维度4: 结果可靠性诊断
    diagnostics.result_reliability = diagnose_result_reliability(summary);
    
    %% 维度5: 性能效率诊断
    diagnostics.performance_efficiency = diagnose_performance_efficiency(summary);
    
    %% 维度6: 解释合理性诊断
    diagnostics.interpretation_plausibility = diagnose_interpretation_plausibility(summary, context);
    
    %% 综合诊断评分
    diagnostics.overall_score = calculate_overall_diagnostic_score(diagnostics);
    diagnostics.severity_level = assess_overall_severity(diagnostics.overall_score);
    
    %% 生成诊断摘要
    diagnostics.summary = generate_diagnostic_summary(diagnostics);
end

function recs = generate_recommendations(diagnostics, summary, context)
% 生成具体建议
    
    recs = {};
    rec_id = 1;
    
    %% 1. 数据质量相关建议
    data_recs = generate_data_quality_recommendations(diagnostics.data_quality, summary, context);
    recs = [recs, data_recs];
    rec_id = rec_id + length(data_recs);
    
    %% 2. 统计功效相关建议
    power_recs = generate_statistical_power_recommendations(diagnostics.statistical_power, summary, context);
    recs = [recs, power_recs];
    rec_id = rec_id + length(power_recs);
    
    %% 3. 方法相关建议
    method_recs = generate_method_recommendations(diagnostics.method_suitability, summary, context);
    recs = [recs, method_recs];
    rec_id = rec_id + length(method_recs);
    
    %% 4. 结果可靠性建议
    reliability_recs = generate_reliability_recommendations(diagnostics.result_reliability, summary, context);
    recs = [recs, reliability_recs];
    rec_id = rec_id + length(reliability_recs);
    
    %% 5. 性能优化建议
    performance_recs = generate_performance_recommendations(diagnostics.performance_efficiency, summary, context);
    recs = [recs, performance_recs];
    rec_id = rec_id + length(performance_recs);
    
    %% 6. 结果解释建议
    interpretation_recs = generate_interpretation_recommendations(diagnostics.interpretation_plausibility, summary, context);
    recs = [recs, interpretation_recs];
    
    %% 7. 综合建议
    if diagnostics.overall_score >= 80
        recs{end+1} = struct(...
            'id', sprintf('REC_OVERALL_%03d', rec_id), ...
            'text', '整体分析质量良好，结果可靠，可以基于当前结果进行进一步分析或决策。', ...
            'category', '综合', ...
            'priority', 1, ...
            'rationale', sprintf('综合诊断评分%.1f/100，属于良好水平。', diagnostics.overall_score), ...
            'action_steps', {'继续当前分析流程', '考虑扩展到更复杂的网络分析'}, ...
            'expected_impact', '保持分析质量');
    end
end

function scores = assess_recommendation_priority(recommendations, diagnostics, context)
% 评估建议优先级
    
    scores = struct();
    
    % 初始化评分维度
    dim_weights = struct(...
        'data_quality', 0.25, ...
        'statistical_power', 0.20, ...
        'method_suitability', 0.15, ...
        'result_reliability', 0.20, ...
        'performance', 0.10, ...
        'interpretation', 0.10);
    
    % 用户上下文调整权重
    if strcmp(context.experience_level, 'beginner')
        dim_weights.method_suitability = dim_weights.method_suitability + 0.10;
        dim_weights.interpretation = dim_weights.interpretation + 0.05;
    elseif strcmp(context.experience_level, 'expert')
        dim_weights.performance = dim_weights.performance + 0.05;
        dim_weights.result_reliability = dim_weights.result_reliability + 0.05;
    end
    
    if strcmp(context.analysis_purpose, 'publication')
        dim_weights.result_reliability = dim_weights.result_reliability + 0.10;
        dim_weights.statistical_power = dim_weights.statistical_power + 0.05;
    end
    
    % 归一化权重
    total_weight = sum(struct2array(dim_weights));
    field_names = fieldnames(dim_weights);
    for i = 1:length(field_names)
        dim_weights.(field_names{i}) = dim_weights.(field_names{i}) / total_weight;
    end
    
    scores.dimension_weights = dim_weights;
    
    % 计算每个建议的优先级得分
    for i = 1:length(recommendations)
        rec = recommendations{i};
        
        % 基础优先级（来自建议本身）
        base_priority = rec.priority;
        
        % 维度匹配得分
        dim_match = calculate_dimension_match_score(rec.category, diagnostics);
        
        % 上下文相关性
        context_relevance = calculate_context_relevance(rec, context);
        
        % 计算综合优先级得分
        priority_score = base_priority * 0.4 + ...
                         dim_match * 0.4 + ...
                         context_relevance * 0.2;
        
        % 存储得分
        rec.priority_score = priority_score;
        recommendations{i} = rec;
    end
    
    scores.recommendations = recommendations;
    scores.priority_calibration = struct(...
        'base_weight', 0.4, ...
        'dimension_weight', 0.4, ...
        'context_weight', 0.2);
end

function sorted_recs = sort_recommendations_by_priority(recommendations, scores)
% 按优先级排序建议
    
    if isempty(recommendations)
        sorted_recs = {};
        return;
    end
    
    % 提取优先级得分
    priority_scores = zeros(length(recommendations), 1);
    for i = 1:length(recommendations)
        if isfield(recommendations{i}, 'priority_score')
            priority_scores(i) = recommendations{i}.priority_score;
        else
            priority_scores(i) = recommendations{i}.priority;
        end
    end
    
    % 按得分降序排序
    [sorted_scores, sort_idx] = sort(priority_scores, 'descend');
    sorted_recs = recommendations(sort_idx);
    
    % 更新排序后的优先级
    for i = 1:length(sorted_recs)
        sorted_recs{i}.display_priority = i;
        sorted_recs{i}.priority_quartile = ceil(i / ceil(length(sorted_recs)/4));
    end
    
    % 添加排序信息
    if isfield(scores, 'recommendations')
        scores.sorting_info = struct(...
            'n_recommendations', length(sorted_recs), ...
            'average_priority', mean(sorted_scores), ...
            'top_quartile_threshold', sorted_scores(ceil(length(sorted_scores)/4)));
    end
end

%% ==================== 诊断函数 ====================

function dq_diag = diagnose_data_quality(summary)
% 数据质量诊断
    dq_diag = struct('score', 100, 'issues', {}, 'severity', 'low');
    
    if isfield(summary, 'quality_summary')
        qual = summary.quality_summary;
        
        % 评分计算
        score = 100;
        
        % 通过率
        if isfield(qual, 'pass_rate')
            if qual.pass_rate < 50
                score = score - 40;
                dq_diag.severity = 'high';
                dq_diag.issues{end+1} = '数据质量通过率过低';
            elseif qual.pass_rate < 80
                score = score - 20;
                dq_diag.severity = 'medium';
                dq_diag.issues{end+1} = '数据质量通过率一般';
            end
        end
        
        % 观测数
        if isfield(qual, 'obs_stats')
            if qual.obs_stats.mean < 20
                score = score - 30;
                dq_diag.severity = 'high';
                dq_diag.issues{end+1} = '有效观测数过少';
            elseif qual.obs_stats.mean < 50
                score = score - 15;
                if ~strcmp(dq_diag.severity, 'high')
                    dq_diag.severity = 'medium';
                end
                dq_diag.issues{end+1} = '有效观测数偏少';
            end
            
            if qual.obs_stats.n_below_20 > qual.n_pairs * 0.3
                score = score - 20;
                dq_diag.severity = 'high';
                dq_diag.issues{end+1} = '大量配对观测数不足';
            end
        end
        
        % 问题数量
        if isfield(qual, 'issues_per_pair')
            if qual.issues_per_pair > 2
                score = score - 25;
                dq_diag.severity = 'high';
                dq_diag.issues{end+1} = '平均问题数过多';
            elseif qual.issues_per_pair > 1
                score = score - 10;
                if ~strcmp(dq_diag.severity, 'high')
                    dq_diag.severity = 'medium';
                end
                dq_diag.issues{end+1} = '存在较多数据问题';
            end
        end
        
        dq_diag.score = max(0, score);
        
        % 建议阈值
        dq_diag.thresholds = struct(...
            'pass_rate_good', 90, ...
            'pass_rate_acceptable', 70, ...
            'min_obs_good', 100, ...
            'min_obs_acceptable', 30, ...
            'max_issues_per_pair', 0.5);
        
        dq_diag.metrics = struct(...
            'actual_pass_rate', qual.pass_rate, ...
            'actual_mean_obs', qual.obs_stats.mean, ...
            'actual_issues_per_pair', qual.issues_per_pair);
    end
end

function recs = generate_data_quality_recommendations(diagnosis, summary, context)
% 生成数据质量建议
    
    recs = {};
    
    if diagnosis.score < 60
        % 严重数据质量问题
        recs{end+1} = struct(...
            'id', 'REC_DATA_001', ...
            'text', '数据质量存在严重问题，需优先处理。', ...
            'category', '数据质量', ...
            'priority', 5, ...
            'rationale', sprintf('数据质量评分: %.1f/100，存在%d个问题', ...
                diagnosis.score, length(diagnosis.issues)), ...
            'action_steps', {...
                '检查原始数据源的完整性', ...
                '处理缺失值和异常值', ...
                '增加数据清洗步骤', ...
                '考虑使用插值或数据重建方法'}, ...
            'expected_impact', '大幅提升分析可靠性');
        
    elseif diagnosis.score < 80
        % 中等数据质量问题
        recs{end+1} = struct(...
            'id', 'REC_DATA_002', ...
            'text', '数据质量有待改进，建议进行数据增强。', ...
            'category', '数据质量', ...
            'priority', 3, ...
            'rationale', sprintf('数据质量评分: %.1f/100', diagnosis.score), ...
            'action_steps', {...
                '增加数据清洗的严格度', ...
                '考虑使用更稳健的统计方法', ...
                '对异常值进行winsorize处理'}, ...
            'expected_impact', '提升结果稳定性');
    end
    
    % 具体问题建议
    for i = 1:length(diagnosis.issues)
        issue = diagnosis.issues{i};
        
        if contains(issue, '观测数')
            recs{end+1} = struct(...
                'id', sprintf('REC_DATA_%03d', 100+i), ...
                'text', '样本量不足，考虑增加数据或使用小样本方法。', ...
                'category', '数据质量', ...
                'priority', 4, ...
                'rationale', issue, ...
                'action_steps', {...
                    '收集更多时间序列数据', ...
                    '考虑使用bootstrap增加样本', ...
                    '使用小样本校正方法'}, ...
                'expected_impact', '提高统计功效');
                
        elseif contains(issue, '通过率')
            recs{end+1} = struct(...
                'id', sprintf('REC_DATA_%03d', 200+i), ...
                'text', '数据质量检查通过率偏低，需加强数据预处理。', ...
                'category', '数据质量', ...
                'priority', 3, ...
                'rationale', issue, ...
                'action_steps', {...
                    '检查数据质量检查阈值设置', ...
                    '增加数据转换步骤（如标准化）', ...
                    '使用更宽松的数据质量标准进行探索性分析'}, ...
                'expected_impact', '提高数据可用性');
        end
    end
end
