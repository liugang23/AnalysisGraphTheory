function [formatted_report, overall_assessment] = generate_network_report(analysis_results, integrated_results, varargin)
% GENERATE_NETWORK_REPORT - 独立的网络分析报告生成函数
% 
% 【功能定位】
% 专注生成格式化报告，不进行任何计算。
% 这是纯粹的"报告模块"，输入是analysis_results，输出是报告。
%
% 【输入参数】
%   analysis_results: 网络拓扑分析结果（来自analyze_network_topology）
%   integrated_results: 整合后的分析结果
%   varargin: 可选参数
%       'ReportLevel': 报告详细程度 ('brief', 'standard'(默认), 'detailed')
%       'SaveReport': 是否保存报告文件 (默认: false)
%       'ReportFileName': 保存文件名
%
% 【输出参数】
%   formatted_report: 格式化文本报告
%   overall_assessment: 综合评估结果
%
% 【调用示例】
%   % 先生成分析结果
%   [analysis_results, integrated] = analyze_network_topology(pair_network);
%   
%   % 再生成报告
%   [report, assessment] = generate_network_report(analysis_results, integrated, ...
%       'ReportLevel', 'detailed', 'SaveReport', true);

    fprintf('【网络分析报告】开始生成...\n');
    start_time = tic;
    
    %% 1. 参数解析（只保留报告相关参数）
    p = inputParser;
    addRequired(p, 'analysis_results', @isstruct);
    addRequired(p, 'integrated_results', @isstruct);
    addParameter(p, 'ReportLevel', 'standard', ...
        @(x) ismember(x, {'brief', 'standard', 'detailed'}));
    addParameter(p, 'SaveReport', false, @islogical);
    addParameter(p, 'ReportFileName', '', @ischar);
    p.parse(analysis_results, integrated_results, varargin{:});
    opts = p.Results;
    
    % 设置默认文件名
    if isempty(opts.ReportFileName)
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        opts.ReportFileName = sprintf('Network_Analysis_Report_%s.txt', timestamp);
    end
    
    %% 2. 生成综合评估（从原主函数迁移）
    fprintf('步骤1: 生成综合评估...\n');
    overall_assessment = generate_overall_assessment(integrated_results);
    
    %% 3. 生成格式化报告（从原主函数迁移）
    fprintf('步骤2: 生成格式化报告...\n');
    formatted_report = generate_formatted_report(...
        integrated_results, overall_assessment, opts.ReportLevel);
    
    %% 4. 保存报告文件（从原主函数迁移）
    if opts.SaveReport
        fprintf('步骤3: 保存报告文件...\n');
        save_report_to_file(formatted_report, opts.ReportFileName);
    end
    
    %% 5. 完成
    report_time = toc(start_time);
    fprintf('\n【网络分析报告生成完成】\n');
    fprintf('报告详细程度: %s\n', opts.ReportLevel);
    fprintf('生成时间: %.2f 秒\n', report_time);
    if opts.SaveReport
        fprintf('报告已保存: %s\n', opts.ReportFileName);
    end
end

function overall_assessment = generate_overall_assessment(integrated_results)
% GENERATE_OVERALL_ASSESSMENT - 生成网络综合评估
% 
% 功能：基于9个分析模块的整合结果，生成综合评分和评估
% 输入：integrated_results - 整合后的分析结果
% 输出：overall_assessment - 综合评估结构体

    overall_assessment = struct();
    
    %% 1. 计算综合评分（加权平均）
    weights = struct(...
        'size_importance', 0.15, ...       % 网络规模权重
        'density_importance', 0.20, ...    % 网络密度权重
        'connectivity_importance', 0.15, ... % 连通性权重
        'centrality_importance', 0.20, ...  % 中心性权重
        'clustering_importance', 0.15, ...  % 聚类权重
        'robustness_importance', 0.15 ...   % 鲁棒性权重
    );
    
    scores = struct();
    total_weight = 0;
    weighted_sum = 0;
    
    %% 2. 评估各项指标
    % 2.1 网络规模评估
    if isfield(integrated_results, 'n_nodes')
        n_nodes = integrated_results.n_nodes;
        if n_nodes < 10
            scores.size_score = 3;
            overall_assessment.size_assessment = '小型网络，分析价值有限';
        elseif n_nodes < 50
            scores.size_score = 6;
            overall_assessment.size_assessment = '中等规模网络，适合分析';
        else
            scores.size_score = 8;
            overall_assessment.size_assessment = '大型网络，分析价值高';
        end
        weighted_sum = weighted_sum + scores.size_score * weights.size_importance;
        total_weight = total_weight + weights.size_importance;
    end
    
    % 2.2 网络密度评估
    if isfield(integrated_results, 'density')
        density = integrated_results.density;
        if density < 0.01
            scores.density_score = 3;
            overall_assessment.density_assessment = '网络过于稀疏，可能丢失重要连接';
        elseif density < 0.1
            scores.density_score = 5;
            overall_assessment.density_assessment = '网络密度适中';
        elseif density < 0.4
            scores.density_score = 7;
            overall_assessment.density_assessment = '网络密度较高，连接丰富';
        else
            scores.density_score = 4;
            overall_assessment.density_assessment = '网络过于稠密，可能包含噪声';
        end
        weighted_sum = weighted_sum + scores.density_score * weights.density_importance;
        total_weight = total_weight + weights.density_importance;
    end
    
    % 2.3 连通性评估
    if isfield(integrated_results, 'is_connected')
        if integrated_results.is_connected
            scores.connectivity_score = 8;
            overall_assessment.connectivity_assessment = '网络全连通，结构完整';
        else
            connectivity_ratio = integrated_results.largest_component_ratio;
            if connectivity_ratio > 0.8
                scores.connectivity_score = 7;
                overall_assessment.connectivity_assessment = sprintf('基本连通（最大连通分量占比%.1f%%）', connectivity_ratio*100);
            elseif connectivity_ratio > 0.5
                scores.connectivity_score = 5;
                overall_assessment.connectivity_assessment = sprintf('部分连通（最大连通分量占比%.1f%%）', connectivity_ratio*100);
            else
                scores.connectivity_score = 3;
                overall_assessment.connectivity_assessment = sprintf('高度不连通（最大连通分量占比%.1f%%）', connectivity_ratio*100);
            end
        end
        weighted_sum = weighted_sum + scores.connectivity_score * weights.connectivity_importance;
        total_weight = total_weight + weights.connectivity_importance;
    end
    
    % 2.4 中心性评估
    if isfield(integrated_results, 'degree_heterogeneity')
        heterogeneity = integrated_results.degree_heterogeneity;
        if heterogeneity > 1.5
            scores.centrality_score = 8;
            overall_assessment.centrality_assessment = '网络存在明显枢纽节点，适合枢纽分析';
        elseif heterogeneity > 0.8
            scores.centrality_score = 6;
            overall_assessment.centrality_assessment = '网络节点度分布中等异质';
        else
            scores.centrality_score = 4;
            overall_assessment.centrality_assessment = '网络节点度分布相对均匀';
        end
        weighted_sum = weighted_sum + scores.centrality_score * weights.centrality_importance;
        total_weight = total_weight + weights.centrality_importance;
    end
    
    % 2.5 聚类评估
    if isfield(integrated_results, 'clustering_assessment')
        if contains(integrated_results.clustering_assessment, '高度聚类')
            scores.clustering_score = 8;
            overall_assessment.clustering_assessment = '网络高度聚类，社区结构明显';
        elseif contains(integrated_results.clustering_assessment, '中等聚类')
            scores.clustering_score = 6;
            overall_assessment.clustering_assessment = '网络中等聚类';
        else
            scores.clustering_score = 4;
            overall_assessment.clustering_assessment = '网络低聚类';
        end
        weighted_sum = weighted_sum + scores.clustering_score * weights.clustering_importance;
        total_weight = total_weight + weights.clustering_importance;
    end
    
    % 2.6 鲁棒性评估
    if isfield(integrated_results, 'robustness_assessment')
        if contains(integrated_results.robustness_assessment, '高度鲁棒')
            scores.robustness_score = 8;
            overall_assessment.robustness_assessment = '网络鲁棒性优秀，抗攻击能力强';
        elseif contains(integrated_results.robustness_assessment, '中等鲁棒')
            scores.robustness_score = 6;
            overall_assessment.robustness_assessment = '网络鲁棒性良好';
        else
            scores.robustness_score = 3;
            overall_assessment.robustness_assessment = '网络鲁棒性一般，对攻击敏感';
        end
        weighted_sum = weighted_sum + scores.robustness_score * weights.robustness_importance;
        total_weight = total_weight + weights.robustness_importance;
    end
    
    %% 3. 计算综合评分
    if total_weight > 0
        overall_assessment.overall_score = weighted_sum / total_weight;
    else
        overall_assessment.overall_score = 0;
    end
    
    %% 4. 生成综合评级
    score = overall_assessment.overall_score;
    if score >= 8
        overall_assessment.rating = '优秀';
        overall_assessment.recommendation = '网络结构优秀，适合进行深入分析和策略开发';
    elseif score >= 6
        overall_assessment.rating = '良好';
        overall_assessment.recommendation = '网络结构良好，具有分析价值';
    elseif score >= 4
        overall_assessment.rating = '一般';
        overall_assessment.recommendation = '网络结构一般，分析需谨慎';
    else
        overall_assessment.rating = '较差';
        overall_assessment.recommendation = '网络结构较差，建议优化数据或调整参数重新分析';
    end
    
    %% 5. 添加详细评估
    overall_assessment.scores = scores;
    overall_assessment.weights = weights;
    overall_assessment.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    %% 6. 计算改进建议
    improvement_suggestions = {};
    
    if isfield(scores, 'density_score') && scores.density_score < 4
        improvement_suggestions{end+1} = '网络密度过低，建议降低显著性阈值或增加数据量';
    end
    
    if isfield(scores, 'connectivity_score') && scores.connectivity_score < 4
        improvement_suggestions{end+1} = '网络连通性差，建议检查数据质量或调整网络构建参数';
    end
    
    if isfield(scores, 'robustness_score') && scores.robustness_score < 4
        improvement_suggestions{end+1} = '网络鲁棒性不足，建议增加冗余连接或保护关键节点';
    end
    
    if ~isempty(improvement_suggestions)
        overall_assessment.improvement_suggestions = improvement_suggestions;
    end
end

function formatted_report = generate_formatted_report(integrated_results, overall_assessment, report_level)
% GENERATE_FORMATTED_REPORT - 生成格式化网络分析报告
% 
% 功能：将分析结果转换为格式化的文本报告
% 输入：
%   integrated_results - 整合后的分析结果
%   overall_assessment - 综合评估结果
%   report_level - 报告详细程度 ('brief', 'standard', 'detailed')
% 输出：formatted_report - 格式化文本字符串

    % 初始化报告
    report_lines = {};
    
    % 添加报告头
    report_lines{end+1} = repmat('=', 1, 60);
    report_lines{end+1} = '网络结构分析报告';
    report_lines{end+1} = repmat('=', 1, 60);
    report_lines{end+1} = '';
    report_lines{end+1} = sprintf('生成时间: %s', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    report_lines{end+1} = sprintf('报告详细程度: %s', report_level);
    report_lines{end+1} = '';
    
    % 1. 执行摘要
    report_lines{end+1} = '1. 执行摘要';
    report_lines{end+1} = repmat('-', 1, 40);
    
    if isfield(overall_assessment, 'rating')
        report_lines{end+1} = sprintf('综合评级: %s', overall_assessment.rating);
    end
    
    if isfield(overall_assessment, 'overall_score')
        report_lines{end+1} = sprintf('综合评分: %.1f/10', overall_assessment.overall_score);
    end
    
    if isfield(overall_assessment, 'recommendation')
        report_lines{end+1} = sprintf('核心建议: %s', overall_assessment.recommendation);
    end
    
    report_lines{end+1} = '';
    
    % 2. 网络基本信息
    report_lines{end+1} = '2. 网络基本信息';
    report_lines{end+1} = repmat('-', 1, 40);
    
    if isfield(integrated_results, 'n_nodes')
        report_lines{end+1} = sprintf('节点数量: %d', integrated_results.n_nodes);
    end
    
    if isfield(integrated_results, 'n_edges')
        report_lines{end+1} = sprintf('边数量: %d', integrated_results.n_edges);
    end
    
    if isfield(integrated_results, 'density')
        report_lines{end+1} = sprintf('网络密度: %.4f', integrated_results.density);
    end
    
    if isfield(integrated_results, 'graph_type')
        report_lines{end+1} = sprintf('图类型: %s', integrated_results.graph_type);
    end
    
    report_lines{end+1} = '';
    
    % 3. 连通性分析
    if isfield(integrated_results, 'is_connected')
        report_lines{end+1} = '3. 连通性分析';
        report_lines{end+1} = repmat('-', 1, 40);
        
        if integrated_results.is_connected
            report_lines{end+1} = '连通状态: 全连通网络';
        else
            report_lines{end+1} = sprintf('连通状态: 非全连通 (最大连通分量占比: %.1f%%)', ...
                integrated_results.largest_component_ratio * 100);
        end
        
        report_lines{end+1} = '';
    end
    
    % 4. 中心性分析
    if isfield(integrated_results, 'degree_heterogeneity')
        report_lines{end+1} = '4. 中心性分析';
        report_lines{end+1} = repmat('-', 1, 40);
        
        report_lines{end+1} = sprintf('度异质性: %.4f', integrated_results.degree_heterogeneity);
        
        if isfield(integrated_results, 'heterogeneity_assessment')
            report_lines{end+1} = sprintf('度分布特征: %s', integrated_results.heterogeneity_assessment);
        end
        
        report_lines{end+1} = '';
    end
    
    % 5. 聚类分析
    if isfield(integrated_results, 'clustering_assessment')
        report_lines{end+1} = '5. 聚类分析';
        report_lines{end+1} = repmat('-', 1, 40);
        
        report_lines{end+1} = sprintf('聚类特征: %s', integrated_results.clustering_assessment);
        
        if isfield(integrated_results, 'clustering_quality')
            report_lines{end+1} = sprintf('聚类质量: %s', integrated_results.clustering_quality);
        end
        
        report_lines{end+1} = '';
    end
    
    % 6. 社区结构分析
    if isfield(integrated_results, 'community_structure')
        report_lines{end+1} = '6. 社区结构分析';
        report_lines{end+1} = repmat('-', 1, 40);
        
        report_lines{end+1} = sprintf('社区结构: %s', integrated_results.community_structure);
        
        if isfield(integrated_results, 'modularity')
            report_lines{end+1} = sprintf('模块度: %.4f', integrated_results.modularity);
        end
        
        report_lines{end+1} = '';
    end
    
    % 7. 鲁棒性分析
    if isfield(integrated_results, 'robustness_assessment')
        report_lines{end+1} = '7. 鲁棒性分析';
        report_lines{end+1} = repmat('-', 1, 40);
        
        report_lines{end+1} = sprintf('鲁棒性评估: %s', integrated_results.robustness_assessment);
        
        if isfield(integrated_results, 'robustness_recommendations')
            report_lines{end+1} = '鲁棒性建议:';
            for i = 1:length(integrated_results.robustness_recommendations)
                report_lines{end+1} = sprintf('  %d. %s', i, integrated_results.robustness_recommendations{i});
            end
        end
        
        report_lines{end+1} = '';
    end
    
    % 8. 路径分析
    if isfield(integrated_results, 'path_assessment')
        report_lines{end+1} = '8. 路径分析';
        report_lines{end+1} = repmat('-', 1, 40);
        
        report_lines{end+1} = sprintf('路径特征: %s', integrated_results.path_assessment.path_length_assessment);
        
        if isfield(integrated_results.path_assessment, 'efficiency_assessment')
            report_lines{end+1} = sprintf('网络效率: %s', integrated_results.path_assessment.efficiency_assessment);
        end
        
        report_lines{end+1} = '';
    end
    
    % 9. 综合评估
    if isfield(overall_assessment, 'scores')
        report_lines{end+1} = '9. 综合评估详情';
        report_lines{end+1} = repmat('-', 1, 40);
        
        fields = fieldnames(overall_assessment.scores);
        for i = 1:length(fields)
            if ~isempty(strfind(fields{i}, 'score'))
                report_lines{end+1} = sprintf('  %s: %.1f/10', ...
                    strrep(fields{i}, '_', ' '), overall_assessment.scores.(fields{i}));
            end
        end
        
        report_lines{end+1} = '';
    end
    
    % 10. 改进建议
    if isfield(overall_assessment, 'improvement_suggestions')
        report_lines{end+1} = '10. 改进建议';
        report_lines{end+1} = repmat('-', 1, 40);
        
        for i = 1:length(overall_assessment.improvement_suggestions)
            report_lines{end+1} = sprintf('  %d. %s', i, overall_assessment.improvement_suggestions{i});
        end
        
        report_lines{end+1} = '';
    end
    
    % 详细报告级别
    if strcmp(report_level, 'detailed')
        % 添加更多详细信息
        report_lines{end+1} = '附录A: 详细统计';
        report_lines{end+1} = repmat('-', 1, 40);
        
        % 可以添加度分布、中心性排名等详细信息
    end
    
    % 报告尾
    report_lines{end+1} = repmat('=', 1, 60);
    report_lines{end+1} = '报告结束';
    report_lines{end+1} = repmat('=', 1, 60);
    
    % 合并所有行为字符串
    formatted_report = strjoin(report_lines, '\n');
end

function save_report_to_file(formatted_report, filename)
% SAVE_REPORT_TO_FILE - 保存报告到文件
% 
% 功能：将生成的网络分析报告保存到指定文件
% 输入：
%   formatted_report: 格式化的报告文本字符串
%   filename: 保存的文件名（可选路径）
% 输出：无，但会在指定位置生成文件
    
    % 1. 检查输入有效性
    if isempty(formatted_report)
        warning('报告内容为空，跳过保存');
        return;
    end
    
    % 2. 确保filename是有效的
    if isempty(filename)
        % 使用默认文件名
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        filename = sprintf('Network_Analysis_Report_%s.txt', timestamp);
    end
    
    % 3. 确保文件扩展名
    [filepath, name, ext] = fileparts(filename);
    if isempty(ext)
        filename = [filename, '.txt'];
    end
    
    % 4. 确保目录存在
    if ~isempty(filepath) && ~exist(filepath, 'dir')
        mkdir(filepath);
    end
    
    % 5. 保存文件
    try
        fid = fopen(filename, 'w', 'n', 'UTF-8');
        if fid == -1
            error('无法打开文件: %s', filename);
        end
        
        % 写入报告内容
        fprintf(fid, '%s', formatted_report);
        fclose(fid);
        
        fprintf('报告已保存: %s\n', filename);
        
    catch ME
        warning('保存报告失败: %s', ME.message);
        
        % 尝试备用编码
        try
            fid = fopen(filename, 'w');
            fprintf(fid, '%s', formatted_report);
            fclose(fid);
            fprintf('使用默认编码重新保存成功: %s\n', filename);
        catch ME2
            error('最终保存失败: %s', ME2.message);
        end
    end
end

% 辅助函数：重复字符串
function s = repstr(c, n)
    s = repmat(c, 1, n);
end