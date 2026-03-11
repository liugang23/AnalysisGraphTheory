function [report_text, report_struct] = generate_cycle_analysis_report(cycle_analysis_results, varargin)
% GENERATE_CYCLE_ANALYSIS_REPORT - 生成环结构分析评估报告
% 
% 【功能描述】
% 基于环结构分析结果，生成一份结构完整、内容专业、具有明确指导意义的评估报告。
% 报告包含：摘要、详细分析、风险评估、改进建议、决策支持等部分。
%
% 【输入参数】
%   cycle_analysis_results: 环结构分析结果结构体（来自 analyze_network_cycles）
%   varargin: 可选参数
%       'ReportLevel': 报告详细程度 ('executive'(摘要), 'standard'(标准), 'technical'(技术))
%       'NetworkContext': 网络背景信息结构体（可选，包含网络名称、分析时间等）
%       'OutputFormat': 输出格式 ('text'(默认), 'struct')
%       'MaxCycleExamples': 报告中展示的环示例数量 (默认: 5)
%       'ShowStatistics': 是否显示详细统计 (默认: true)
%       'IncludeRecommendations': 是否包含改进建议 (默认: true)
%
% 【输出参数】
%   report_text: 格式化文本报告
%   report_struct: 结构化的报告数据
%
% 【报告结构】
% 1. 报告摘要
% 2. 环结构概览
% 3. 关键发现
% 4. 风险评估
% 5. 改进建议
% 6. 决策支持
% 7. 技术附录
%
% 【调用示例】
%   % 生成标准报告
%   [report, data] = generate_cycle_analysis_report(cycle_results);
%   
%   % 生成高层摘要报告
%   [report, data] = generate_cycle_analysis_report(cycle_results, ...
%       'ReportLevel', 'executive', ...
%       'NetworkContext', struct('name', '价量指标网络', 'analysis_date', '2024-01'));

    %% 1. 参数解析
    p = inputParser;
    addRequired(p, 'cycle_analysis_results', @isstruct);
    addParameter(p, 'ReportLevel', 'standard', ...
        @(x) ismember(x, {'executive', 'standard', 'technical'}));
    addParameter(p, 'NetworkContext', struct(), @isstruct);
    addParameter(p, 'OutputFormat', 'text', @(x) ismember(x, {'text', 'struct'}));
    addParameter(p, 'MaxCycleExamples', 5, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'ShowStatistics', true, @islogical);
    addParameter(p, 'IncludeRecommendations', true, @islogical);
    p.parse(cycle_analysis_results, varargin{:});
    
    opts = p.Results;
    
    %% 2. 初始化报告结构
    report_struct = struct();
    report_struct.report_metadata = struct();
    report_struct.report_metadata.generation_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    report_struct.report_metadata.report_level = opts.ReportLevel;
    report_struct.report_metadata.network_context = opts.NetworkContext;
    
    %% 3. 提取关键分析结果
    cycle_data = extract_cycle_data_for_report(cycle_analysis_results, opts);
    report_struct.analysis_data = cycle_data;
    
    %% 4. 生成报告各部分
    report_lines = {};
    
    % 4.1 报告头
    report_lines = [report_lines; generate_report_header(cycle_data, opts.NetworkContext)];
    
    % 4.2 执行摘要（高层摘要）
    report_lines = [report_lines; generate_executive_summary(cycle_data)];
    
    % 4.3 环结构概览
    report_lines = [report_lines; generate_cycle_overview(cycle_data, opts.ShowStatistics)];
    
    % 4.4 关键发现
    report_lines = [report_lines; generate_key_findings(cycle_data)];
    
    % 4.5 风险评估
    report_lines = [report_lines; generate_risk_assessment(cycle_data)];
    
    % 4.6 改进建议
    if opts.IncludeRecommendations
        report_lines = [report_lines; generate_improvement_recommendations(cycle_data)];
    end
    
    % 4.7 决策支持
    report_lines = [report_lines; generate_decision_support(cycle_data)];
    
    % 4.8 技术附录（技术报告级别）
    if strcmp(opts.ReportLevel, 'technical')
        report_lines = [report_lines; generate_technical_appendix(cycle_data, opts.MaxCycleExamples)];
    end
    
    % 4.9 报告尾
    report_lines = [report_lines; generate_report_footer(cycle_data)];
    
    %% 5. 生成最终报告
    report_text = strjoin(report_lines, '\n');
    
    %% 6. 输出结构化的报告数据
    report_struct.report_text = report_text;
    report_struct.report_sections = struct(...
        'executive_summary', generate_executive_summary(cycle_data), ...
        'cycle_overview', generate_cycle_overview(cycle_data, opts.ShowStatistics), ...
        'key_findings', generate_key_findings(cycle_data), ...
        'risk_assessment', generate_risk_assessment(cycle_data), ...
        'improvement_recommendations', generate_improvement_recommendations(cycle_data), ...
        'decision_support', generate_decision_support(cycle_data) ...
    );
    
    fprintf('环结构分析报告生成完成 (级别: %s)\n', opts.ReportLevel);
end

%% ==================== 报告生成辅助函数 ====================

function cycle_data = extract_cycle_data_for_report(cycle_results, opts)
% 从环结构分析结果中提取报告所需数据
    
    cycle_data = struct();
    
    % 基本网络信息
    if isfield(cycle_results, 'metadata')
        cycle_data.network_type = cycle_results.metadata.network_type;
        cycle_data.n_nodes = cycle_results.metadata.n_nodes;
        cycle_data.computation_time = cycle_results.metadata.computation_time;
    end
    
    % 简单环数据
    if isfield(cycle_results, 'simple_cycles') && cycle_results.simple_cycles.is_success
        simple = cycle_results.simple_cycles;
        cycle_data.n_simple_cycles = simple.n_cycles;
        if cycle_data.n_simple_cycles > 0
            cycle_data.simple_cycle_lengths = simple.cycle_lengths;
            cycle_data.min_cycle_length = simple.stats.min_length;
            cycle_data.max_cycle_length = simple.stats.max_length;
            cycle_data.mean_cycle_length = simple.stats.mean_length;
            cycle_data.cycle_length_distribution = simple.length_distribution;
            
            % 随机选择几个环作为示例
            if cycle_data.n_simple_cycles > 0 && isfield(simple, 'cycles')
                n_examples = min(opts.MaxCycleExamples, cycle_data.n_simple_cycles);
                example_indices = randperm(cycle_data.n_simple_cycles, n_examples);
                cycle_data.cycle_examples = simple.cycles(example_indices);
            end
        end
    end
    
    % 三角形数据
    if isfield(cycle_results, 'triangles') && cycle_results.triangles.is_success
        triangles = cycle_results.triangles;
        cycle_data.n_triangles = triangles.n_triangles;
        cycle_data.global_clustering_coefficient = triangles.global_clustering_coefficient;
        cycle_data.transitivity = triangles.transitivity;
        if isfield(triangles, 'local_clustering')
            cycle_data.mean_local_clustering = mean(triangles.local_clustering, 'omitnan');
        end
    end
    
    % 有向环数据
    if isfield(cycle_results, 'directed_cycles') && cycle_results.directed_cycles.is_success
        directed = cycle_results.directed_cycles;
        cycle_data.n_directed_cycles = directed.n_directed_cycles;
        cycle_data.n_sccs = directed.n_sccs;
        if isfield(directed, 'scc_sizes')
            cycle_data.scc_sizes = directed.scc_sizes;
            cycle_data.largest_scc_size = directed.scc_stats.largest_scc_size;
        end
    end
    
    % 反馈回路数据
    if isfield(cycle_results, 'feedback_loops') && cycle_results.feedback_loops.is_success
        feedback = cycle_results.feedback_loops;
        cycle_data.n_feedback_loops = feedback.n_feedback_loops;
        if isfield(feedback, 'feedback_strength')
            cycle_data.feedback_strength = feedback.feedback_strength;
        end
    end
    
    % 环统计特征
    if isfield(cycle_results, 'cycle_stats') && cycle_results.cycle_stats.is_success
        stats = cycle_results.cycle_stats;
        cycle_data.total_cycles = stats.total_cycles;
        if isfield(stats, 'stats')
            cycle_data.stats = stats.stats;
        end
        if isfield(stats, 'type_distribution')
            cycle_data.type_distribution = stats.type_distribution;
        end
        cycle_data.cycle_density = stats.cycle_density;
    end
    
    % 评估结果
    if isfield(cycle_results, 'cycle_assessment') && cycle_results.cycle_assessment.is_success
        assessment = cycle_results.cycle_assessment;
        cycle_data.overall_score = assessment.overall_score;
        cycle_data.overall_assessment = assessment.overall_assessment;
        cycle_data.quality_assessment = assessment.quality_assessment;
        cycle_data.stability_rating = assessment.stability_rating;
        cycle_data.functional_impact = assessment.functional_impact;
    end
    
    % 计算衍生指标
    cycle_data = calculate_derived_metrics(cycle_data);
end

function cycle_data = calculate_derived_metrics(cycle_data)
% 计算衍生指标
    
    % 1. 环丰富度指标
    if isfield(cycle_data, 'total_cycles')
        cycle_data.cycle_richness_index = cycle_data.total_cycles / max(1, cycle_data.n_nodes);
        
        if cycle_data.total_cycles == 0
            cycle_data.richness_level = '无环';
            cycle_data.richness_description = '网络中没有检测到任何环结构，表明系统为树状或链状结构。';
        elseif cycle_data.total_cycles < 5
            cycle_data.richness_level = '稀疏';
            cycle_data.richness_description = '环结构稀疏，网络近似树状，信息传播路径单一。';
        elseif cycle_data.total_cycles < 20
            cycle_data.richness_level = '中等';
            cycle_data.richness_description = '存在适度数量的环结构，网络具有中等复杂度。';
        else
            cycle_data.richness_level = '丰富';
            cycle_data.richness_description = '环结构丰富，网络复杂度高，信息传播路径多样。';
        end
    end
    
    % 2. 环多样性指标
    if isfield(cycle_data, 'type_distribution')
        n_types = length(fieldnames(cycle_data.type_distribution));
        cycle_data.diversity_score = min(10, n_types * 2.5);
        
        if n_types == 0
            cycle_data.diversity_level = '无多样性';
        elseif n_types == 1
            cycle_data.diversity_level = '单一';
        elseif n_types == 2
            cycle_data.diversity_level = '中等';
        else
            cycle_data.diversity_level = '多样';
        end
    end
    
    % 3. 稳定性指标
    if isfield(cycle_data, 'stability_rating')
        if isfield(cycle_data.stability_rating, 'stability_score')
            score = cycle_data.stability_rating.stability_score;
            if score >= 7
                cycle_data.stability_level = '高稳定性';
                cycle_data.stability_implication = '环结构稳定，系统抗干扰能力强，反馈机制可靠。';
            elseif score >= 4
                cycle_data.stability_level = '中稳定性';
                cycle_data.stability_implication = '环结构稳定性一般，系统在外部扰动下可能出现结构变化。';
            else
                cycle_data.stability_level = '低稳定性';
                cycle_data.stability_implication = '环结构不稳定，系统脆弱，容易发生结构重组。';
            end
        end
    end
    
    % 4. 聚类特征指标
    if isfield(cycle_data, 'global_clustering_coefficient')
        cc = cycle_data.global_clustering_coefficient;
        if cc > 0.6
            cycle_data.clustering_feature = '强局部聚集';
            cycle_data.clustering_implication = '节点倾向于形成紧密的局部团体，信息在社区内快速传播。';
        elseif cc > 0.3
            cycle_data.clustering_feature = '中等局部聚集';
            cycle_data.clustering_implication = '存在一定的局部聚集性，但整体结构相对开放。';
        else
            cycle_data.clustering_feature = '弱局部聚集';
            cycle_data.clustering_implication = '网络结构相对均匀，缺乏明显的局部团体。';
        end
    end
    
    % 5. 反馈强度指标
    if isfield(cycle_data, 'feedback_strength')
        fs = cycle_data.feedback_strength;
        if fs > 0.7
            cycle_data.feedback_intensity = '强反馈';
            cycle_data.feedback_implication = '存在强烈的自我强化机制，容易产生趋势延续或泡沫。';
        elseif fs > 0.4
            cycle_data.feedback_intensity = '中等反馈';
            cycle_data.feedback_implication = '存在适度的反馈机制，可能产生短期的趋势效应。';
        else
            cycle_data.feedback_intensity = '弱反馈';
            cycle_data.feedback_implication = '反馈机制较弱，系统趋向于均值回归。';
        end
    end
    
    % 6. 系统复杂度综合评分
    if isfield(cycle_data, 'overall_score')
        score = cycle_data.overall_score;
        if score >= 8
            cycle_data.system_complexity = '高度复杂系统';
            cycle_data.complexity_implication = '网络结构复杂，行为难以预测，需谨慎决策。';
        elseif score >= 6
            cycle_data.system_complexity = '中等复杂系统';
            cycle_data.complexity_implication = '网络具有一定复杂性，但主要模式可识别。';
        elseif score >= 4
            cycle_data.system_complexity = '简单系统';
            cycle_data.complexity_implication = '网络结构简单，行为相对可预测。';
        else
            cycle_data.system_complexity = '极简系统';
            cycle_data.complexity_implication = '网络结构极其简单，信息传播路径有限。';
        end
    end
    
    return;
end

function lines = generate_report_header(cycle_data, network_context)
% 生成报告头
    
    lines = {};
    
    lines{end+1} = repmat('=', 1, 60);
    lines{end+1} = '网络环结构分析评估报告';
    lines{end+1} = repmat('=', 1, 60);
    lines{end+1} = '';
    
    % 网络背景信息
    if ~isempty(fieldnames(network_context))
        lines{end+1} = '【网络背景】';
        fields = fieldnames(network_context);
        for i = 1:length(fields)
            lines{end+1} = sprintf('  %s: %s', fields{i}, ...
                mat2str(network_context.(fields{i})));
        end
        lines{end+1} = '';
    end
    
    % 报告基本信息
    lines{end+1} = '【报告信息】';
    lines{end+1} = sprintf('  生成时间: %s', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    lines{end+1} = sprintf('  网络类型: %s', cycle_data.network_type);
    lines{end+1} = sprintf('  节点数量: %d', cycle_data.n_nodes);
    if isfield(cycle_data, 'computation_time')
        lines{end+1} = sprintf('  分析耗时: %.2f 秒', cycle_data.computation_time);
    end
    lines{end+1} = '';
    
    return;
end

function lines = generate_executive_summary(cycle_data)
% 生成执行摘要（高层管理人员阅读）
    
    lines = {};
    lines{end+1} = '1. 执行摘要';
    lines{end+1} = repmat('-', 1, 40);
    
    % 总体评估
    if isfield(cycle_data, 'overall_assessment')
        lines{end+1} = sprintf('总体评估: %s (评分: %.1f/10)', ...
            cycle_data.overall_assessment, cycle_data.overall_score);
    end
    
    % 关键指标摘要
    summary_points = {};
    
    if isfield(cycle_data, 'total_cycles')
        summary_points{end+1} = sprintf('? 检测到 %d 个环结构', cycle_data.total_cycles);
    end
    
    if isfield(cycle_data, 'richness_level')
        summary_points{end+1} = sprintf('? 环丰富度: %s', cycle_data.richness_level);
    end
    
    if isfield(cycle_data, 'diversity_level')
        summary_points{end+1} = sprintf('? 环多样性: %s', cycle_data.diversity_level);
    end
    
    if isfield(cycle_data, 'stability_level')
        summary_points{end+1} = sprintf('? 结构稳定性: %s', cycle_data.stability_level);
    end
    
    if isfield(cycle_data, 'clustering_feature')
        summary_points{end+1} = sprintf('? 聚类特征: %s', cycle_data.clustering_feature);
    end
    
    if isfield(cycle_data, 'feedback_intensity')
        summary_points{end+1} = sprintf('? 反馈强度: %s', cycle_data.feedback_intensity);
    end
    
    if isfield(cycle_data, 'system_complexity')
        summary_points{end+1} = sprintf('? 系统复杂度: %s', cycle_data.system_complexity);
    end
    
    % 添加摘要点
    for i = 1:length(summary_points)
        lines{end+1} = summary_points{i};
    end
    
    lines{end+1} = '';
    
    % 核心结论
    lines{end+1} = '【核心结论】';
    
    conclusion_parts = {};
    
    % 根据丰富度
    if isfield(cycle_data, 'richness_description')
        conclusion_parts{end+1} = cycle_data.richness_description;
    end
    
    % 根据稳定性
    if isfield(cycle_data, 'stability_implication')
        conclusion_parts{end+1} = cycle_data.stability_implication;
    end
    
    % 根据反馈
    if isfield(cycle_data, 'feedback_implication')
        conclusion_parts{end+1} = cycle_data.feedback_implication;
    end
    
    % 根据复杂度
    if isfield(cycle_data, 'complexity_implication')
        conclusion_parts{end+1} = cycle_data.complexity_implication;
    end
    
    % 去重并组合
    unique_conclusions = unique(conclusion_parts);
    for i = 1:length(unique_conclusions)
        lines{end+1} = sprintf('  %d. %s', i, unique_conclusions{i});
    end
    
    lines{end+1} = '';
    
    return;
end

function lines = generate_cycle_overview(cycle_data, show_stats)
% 生成环结构概览
    
    lines = {};
    lines{end+1} = '2. 环结构概览';
    lines{end+1} = repmat('-', 1, 40);
    
    % 2.1 总体统计
    lines{end+1} = '2.1 总体统计';
    
    stats_table = {};
    
    if isfield(cycle_data, 'total_cycles')
        stats_table{end+1} = sprintf('  总环数: %d', cycle_data.total_cycles);
    end
    
    if isfield(cycle_data, 'n_simple_cycles')
        stats_table{end+1} = sprintf('  简单环数: %d', cycle_data.n_simple_cycles);
    end
    
    if isfield(cycle_data, 'n_triangles')
        stats_table{end+1} = sprintf('  三角形数: %d', cycle_data.n_triangles);
    end
    
    if isfield(cycle_data, 'n_directed_cycles')
        stats_table{end+1} = sprintf('  有向环数: %d', cycle_data.n_directed_cycles);
    end
    
    if isfield(cycle_data, 'n_feedback_loops')
        stats_table{end+1} = sprintf('  反馈回路数: %d', cycle_data.n_feedback_loops);
    end
    
    if isfield(cycle_data, 'n_sccs')
        stats_table{end+1} = sprintf('  强连通分量: %d', cycle_data.n_sccs);
    end
    
    % 添加统计表
    for i = 1:length(stats_table)
        lines{end+1} = stats_table{i};
    end
    
    lines{end+1} = '';
    
    % 2.2 环大小分布
    if isfield(cycle_data, 'simple_cycle_lengths') && ~isempty(cycle_data.simple_cycle_lengths)
        lines{end+1} = '2.2 环大小分布';
        
        lines{end+1} = sprintf('  最小环长度: %d', cycle_data.min_cycle_length);
        lines{end+1} = sprintf('  最大环长度: %d', cycle_data.max_cycle_length);
        lines{end+1} = sprintf('  平均环长度: %.2f', cycle_data.mean_cycle_length);
        
        if show_stats && isfield(cycle_data, 'cycle_length_distribution')
            lines{end+1} = '  环长度分布:';
            counts = cycle_data.cycle_length_distribution.counts;
            edges = cycle_data.cycle_length_distribution.edges;
            
            for i = 1:length(counts)
                if counts(i) > 0
                    lines{end+1} = sprintf('    长度 %d: %d 个', edges(i), counts(i));
                end
            end
        end
        
        lines{end+1} = '';
    end
    
    % 2.3 聚类特征
    if isfield(cycle_data, 'global_clustering_coefficient')
        lines{end+1} = '2.3 聚类特征';
        lines{end+1} = sprintf('  全局聚类系数: %.4f', cycle_data.global_clustering_coefficient);
        
        if isfield(cycle_data, 'transitivity')
            lines{end+1} = sprintf('  传递性: %.4f', cycle_data.transitivity);
        end
        
        if isfield(cycle_data, 'mean_local_clustering')
            lines{end+1} = sprintf('  平均局部聚类系数: %.4f', cycle_data.mean_local_clustering);
        end
        
        lines{end+1} = '';
    end
    
    % 2.4 类型分布
    if isfield(cycle_data, 'type_distribution')
        lines{end+1} = '2.4 环类型分布';
        
        types = fieldnames(cycle_data.type_distribution);
        for i = 1:length(types)
            count = cycle_data.type_distribution.(types{i});
            percentage = count / cycle_data.total_cycles * 100;
            lines{end+1} = sprintf('  %s: %d (%.1f%%)', types{i}, count, percentage);
        end
        
        lines{end+1} = '';
    end
    
    return;
end

function lines = generate_key_findings(cycle_data)
% 生成关键发现
    
    lines = {};
    lines{end+1} = '3. 关键发现';
    lines{end+1} = repmat('-', 1, 40);
    
    findings = {};
    
    % 发现1: 环丰富度
    if isfield(cycle_data, 'richness_level')
        if strcmp(cycle_data.richness_level, '丰富')
            findings{end+1} = '网络环结构异常丰富，表明系统具有高度的内部连接性和复杂的相互作用机制。';
        elseif strcmp(cycle_data.richness_level, '稀疏')
            findings{end+1} = '网络环结构稀疏，系统更接近于树状或链状结构，信息传播路径较为单一。';
        end
    end
    
    % 发现2: 聚类特征
    if isfield(cycle_data, 'clustering_feature')
        if strcmp(cycle_data.clustering_feature, '强局部聚集')
            findings{end+1} = '检测到强烈的局部聚集效应，节点倾向于形成紧密的小团体，这可能导致信息的局部快速传播。';
        end
    end
    
    % 发现3: 反馈机制
    if isfield(cycle_data, 'feedback_intensity')
        if strcmp(cycle_data.feedback_intensity, '强反馈')
            findings{end+1} = '存在强烈的正反馈回路，这种机制可能导致趋势的自我强化和放大效应。';
        elseif strcmp(cycle_data.feedback_intensity, '弱反馈')
            findings{end+1} = '反馈机制较弱，系统更倾向于均值回归而非趋势延续。';
        end
    end
    
    % 发现4: 强连通分量
    if isfield(cycle_data, 'largest_scc_size')
        scc_ratio = cycle_data.largest_scc_size / cycle_data.n_nodes;
        if scc_ratio > 0.7
            findings{end+1} = sprintf('存在大型强连通分量（包含%d个节点，占%.1f%%），这表明网络中存在高度互连的核心区域。', ...
                cycle_data.largest_scc_size, scc_ratio*100);
        end
    end
    
    % 发现5: 环大小特征
    if isfield(cycle_data, 'mean_cycle_length')
        if cycle_data.mean_cycle_length < 4
            findings{end+1} = '环的平均长度较短（<4），表明系统主要受短期、直接的相互作用影响。';
        elseif cycle_data.mean_cycle_length > 6
            findings{end+1} = '环的平均长度较长（>6），表明系统存在复杂的多步相互作用链。';
        end
    end
    
    % 如果没有发现，添加默认信息
    if isempty(findings)
        findings{end+1} = '网络环结构特征不明显，系统相对简单。';
    end
    
    % 添加编号
    for i = 1:length(findings)
        lines{end+1} = sprintf('  %d. %s', i, findings{i});
    end
    
    lines{end+1} = '';
    
    return;
end

function lines = generate_risk_assessment(cycle_data)
% 生成风险评估
    
    lines = {};
    lines{end+1} = '4. 风险评估';
    lines{end+1} = repmat('-', 1, 40);
    
    risks = {};
    risk_levels = struct();
    
    % 风险1: 反馈过度风险
    if isfield(cycle_data, 'feedback_intensity')
        if strcmp(cycle_data.feedback_intensity, '强反馈')
            risks{end+1} = '强反馈回路可能导致系统过度反应，产生泡沫或崩溃风险。';
            risk_levels.feedback_risk = '高';
        elseif strcmp(cycle_data.feedback_intensity, '中等反馈')
            risks{end+1} = '中等强度的反馈可能放大市场波动，增加短期风险。';
            risk_levels.feedback_risk = '中';
        end
    end
    
    % 风险2: 稳定性风险
    if isfield(cycle_data, 'stability_level')
        if strcmp(cycle_data.stability_level, '低稳定性')
            risks{end+1} = '环结构稳定性低，系统对外部扰动敏感，容易发生结构性变化。';
            risk_levels.stability_risk = '高';
        elseif strcmp(cycle_data.stability_level, '中稳定性')
            risks{end+1} = '环结构稳定性一般，在极端条件下可能出现系统失稳。';
            risk_levels.stability_risk = '中';
        end
    end
    
    % 风险3: 复杂性风险
    if isfield(cycle_data, 'system_complexity')
        if strcmp(cycle_data.system_complexity, '高度复杂系统')
            risks{end+1} = '系统高度复杂，行为难以预测，决策不确定性高。';
            risk_levels.complexity_risk = '高';
        end
    end
    
    % 风险4: 集中性风险
    if isfield(cycle_data, 'largest_scc_size')
        if cycle_data.largest_scc_size / cycle_data.n_nodes > 0.5
            risks{end+1} = sprintf('大型强连通分量（%d个节点）可能导致风险的高度集中。', cycle_data.largest_scc_size);
            risk_levels.concentration_risk = '中';
        end
    end
    
    % 如果没有识别到风险
    if isempty(risks)
        risks{end+1} = '未识别到显著的环结构相关风险。';
    end
    
    % 输出风险列表
    for i = 1:length(risks)
        lines{end+1} = sprintf('  %d. %s', i, risks{i});
    end
    
    lines{end+1} = '';
    
    % 风险等级汇总
    if ~isempty(fieldnames(risk_levels))
        lines{end+1} = '风险等级汇总:';
        fields = fieldnames(risk_levels);
        for i = 1:length(fields)
            lines{end+1} = sprintf('  ? %s: %s', strrep(fields{i}, '_', ' '), risk_levels.(fields{i}));
        end
    end
    
    lines{end+1} = '';
    
    return;
end

function lines = generate_improvement_recommendations(cycle_data)
% 生成改进建议
    
    lines = {};
    lines{end+1} = '5. 改进建议';
    lines{end+1} = repmat('-', 1, 40);
    
    recommendations = {};
    
    % 建议1: 针对反馈过强
    if isfield(cycle_data, 'feedback_intensity')
        if strcmp(cycle_data.feedback_intensity, '强反馈')
            recommendations{end+1} = '引入负反馈机制或阻尼项，以平衡系统的自我强化效应。';
        end
    end
    
    % 建议2: 针对稳定性低
    if isfield(cycle_data, 'stability_level')
        if strcmp(cycle_data.stability_level, '低稳定性')
            recommendations{end+1} = '增加网络冗余连接，提高系统对节点失效的鲁棒性。';
        end
    end
    
    % 建议3: 针对复杂性高
    if isfield(cycle_data, 'system_complexity')
        if strcmp(cycle_data.system_complexity, '高度复杂系统')
            recommendations{end+1} = '考虑简化网络结构，移除不必要的连接，降低系统复杂度。';
        end
    end
    
    % 建议4: 针对环丰富度
    if isfield(cycle_data, 'richness_level')
        if strcmp(cycle_data.richness_level, '稀疏')
            recommendations{end+1} = '增加关键节点间的连接，丰富信息传播路径，提高网络效率。';
        elseif strcmp(cycle_data.richness_level, '丰富')
            recommendations{end+1} = '监控关键环路的稳定性，防止过度复杂化导致系统不可预测。';
        end
    end
    
    % 建议5: 一般性建议
    recommendations{end+1} = '定期监控环结构的变化，特别是反馈回路的强度和稳定性。';
    recommendations{end+1} = '结合其他网络指标（如中心性、社区结构）进行综合分析。';
    
    % 输出建议
    for i = 1:length(recommendations)
        lines{end+1} = sprintf('  %d. %s', i, recommendations{i});
    end
    
    lines{end+1} = '';
    
    return;
end

function lines = generate_decision_support(cycle_data)
% 生成决策支持
    
    lines = {};
    lines{end+1} = '6. 决策支持';
    lines{end+1} = repmat('-', 1, 40);
    
    decision_points = {};
    
    % 决策点1: 投资策略选择
    if isfield(cycle_data, 'feedback_intensity')
        if strcmp(cycle_data.feedback_intensity, '强反馈')
            decision_points{end+1} = '考虑趋势跟踪策略，利用正反馈效应获取收益。';
        elseif strcmp(cycle_data.feedback_intensity, '弱反馈')
            decision_points{end+1} = '考虑均值回归策略，系统更倾向于回归均衡状态。';
        end
    end
    
    % 决策点2: 风险管理
    if isfield(cycle_data, 'stability_level')
        if strcmp(cycle_data.stability_level, '低稳定性')
            decision_points{end+1} = '降低仓位，增加对冲，防范系统结构性变化风险。';
        end
    end
    
    % 决策点3: 监控重点
    if isfield(cycle_data, 'largest_scc_size')
        if cycle_data.largest_scc_size / cycle_data.n_nodes > 0.3
            decision_points{end+1} = '重点关注强连通分量内的核心节点，这些节点的变化可能影响整个系统。';
        end
    end
    
    % 决策点4: 时间尺度
    if isfield(cycle_data, 'mean_cycle_length')
        if cycle_data.mean_cycle_length < 4
            decision_points{end+1} = '关注短期交易机会，系统对短期变化反应更敏感。';
        elseif cycle_data.mean_cycle_length > 6
            decision_points{end+1} = '考虑中长期投资视角，系统存在较长的相互作用链。';
        end
    end
    
    % 决策点5: 多样化程度
    if isfield(cycle_data, 'diversity_level')
        if strcmp(cycle_data.diversity_level, '单一')
            decision_points{end+1} = '策略应相对集中，专注于主导的环结构类型。';
        elseif strcmp(cycle_data.diversity_level, '多样')
            decision_points{end+1} = '可考虑多样化策略组合，适应不同类型的环结构。';
        end
    end
    
    % 输出决策点
    if isempty(decision_points)
        decision_points{end+1} = '基于当前环结构分析，建议保持谨慎观察态度。';
    end
    
    for i = 1:length(decision_points)
        lines{end+1} = sprintf('  ? %s', decision_points{i});
    end
    
    lines{end+1} = '';
    
    return;
end

function lines = generate_technical_appendix(cycle_data, max_examples)
% 生成技术附录
    
    lines = {};
    lines{end+1} = '附录A. 技术细节';
    lines{end+1} = repmat('-', 1, 40);
    
    % 环示例
    if isfield(cycle_data, 'cycle_examples') && ~isempty(cycle_data.cycle_examples)
        lines{end+1} = 'A.1 环结构示例';
        
        n_show = min(length(cycle_data.cycle_examples), max_examples);
        for i = 1:n_show
            cycle = cycle_data.cycle_examples{i};
            lines{end+1} = sprintf('  示例 %d: [%s] (长度: %d)', ...
                i, strjoin(cellstr(num2str(cycle(:))), '→'), length(cycle));
        end
        lines{end+1} = '';
    end
    
    % 详细统计
    if isfield(cycle_data, 'stats')
        lines{end+1} = 'A.2 详细统计';
        stats = cycle_data.stats;
        
        if isfield(stats, 'min_cycle_length')
            lines{end+1} = sprintf('  最小环长度: %d', stats.min_cycle_length);
        end
        if isfield(stats, 'max_cycle_length')
            lines{end+1} = sprintf('  最大环长度: %d', stats.max_cycle_length);
        end
        if isfield(stats, 'mean_cycle_length')
            lines{end+1} = sprintf('  平均环长度: %.3f', stats.mean_cycle_length);
        end
        if isfield(stats, 'median_cycle_length')
            lines{end+1} = sprintf('  中位数环长度: %.1f', stats.median_cycle_length);
        end
        if isfield(stats, 'std_cycle_length')
            lines{end+1} = sprintf('  环长度标准差: %.3f', stats.std_cycle_length);
        end
    end
    
    lines{end+1} = '';
    
    return;
end

function lines = generate_report_footer(cycle_data)
% 生成报告尾
    
    lines = {};
    lines{end+1} = repmat('=', 1, 60);
    lines{end+1} = '报告结束';
    lines{end+1} = repmat('=', 1, 60);
    
    return;
end

%% 字符串重复函数（MATLAB 2016a+ 兼容）
function s = repstr(c, n)
% 重复字符串
    s = repmat(c, 1, n);
end