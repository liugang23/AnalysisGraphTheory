function evaluation_report = evaluate_pairwise_connectivity(pairwise_results, varargin)
% EVALUATE_PAIRWISE_CONNECTIVITY - 对连通性分析结果进行评估并生成详细报告
%
% 输入:
%   pairwise_results - 从 connectivity_pairwise_analyze 返回的结果结构体
%   varargin - 可选的名称-值参数对:
%       'ReportLevel' - 报告详细程度 ('brief', 'standard'(默认), 'detailed')
%       'SaveReport'  - 是否将文本报告保存为 .txt 文件 (false(默认) | true)
%       'ReportFileName' - 保存报告的文件名 (默认: 'Connectivity_Evaluation_Report_YYYYMMDD_HHMMSS.txt')
%       'OutputFigures' - 是否生成并保存评估图表 (false(默认) | true)
%       'FigureFormat' - 图表保存格式 ('png'(默认), 'fig', 'pdf')
%       'Alpha' - 用于显著性评估的阈值 (默认: 0.05)
%
% 输出:
%   evaluation_report - 结构体，包含以下部分的详细评估结果:
%       .metadata - 分析元数据
%       .data_quality - 数据处理质量评估
%       .connectivity_stats - 连通性统计分布
%       .significance_eval - 显著性检验评估
%       .robustness_eval - 鲁棒性评估 (如启用)
%       .nonlinear_eval - 非线性检测评估 (如启用)
%       .consistency_checks - 结果一致性检查
%       .overall_assessment - 综合评分与建议
%       .formatted_text - 格式化后的文本报告 (字符串)
%
% 示例1：生成图表（默认png格式）
% report = evaluate_pairwise_connectivity(pairwise_results, ...
%     'OutputFigures', true);
% 示例2：生成指定格式的图表
% report = evaluate_pairwise_connectivity(pairwise_results, ...
%     'OutputFigures', true, ...
%     'FigureFormat', 'pdf');  % 可选: 'png', 'fig', 'pdf', 'jpg'
% 示例3：不生成图表
% report = evaluate_pairwise_connectivity(pairwise_results, ...
%     'OutputFigures', false);  % 默认就是false

    % ==================== 1. 参数解析与初始化 ====================
    fprintf('【连通性分析结果评估模块】开始运行...\n');
    start_time = tic;
    
    % 设置输入解析器
    p = inputParser;
    p.addParameter('ReportLevel', 'standard', @(x) ismember(x, {'brief', 'standard', 'detailed'}));
    p.addParameter('SaveReport', false, @islogical);
    p.addParameter('ReportFileName', '', @ischar);
    p.addParameter('OutputFigures', false, @islogical);
    p.addParameter('FigureFormat', 'png', @(x) ismember(x, {'png', 'fig', 'pdf', 'jpg'}));
    p.addParameter('Alpha', 0.05, @(x) isnumeric(x) && isscalar(x) && x>0 && x<1);
    p.parse(varargin{:});
    
    opts = p.Results;
    if isempty(opts.ReportFileName)
        opts.ReportFileName = sprintf('Connectivity_Evaluation_Report_%s.txt', ...
            datestr(now, 'yyyymmdd_HHMMSS'));
    end
    
    % 初始化报告结构
    report = struct();
    report.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    report.evaluation_options = opts;
    
    % ==================== 2. 验证输入结构 ====================
    if ~isstruct(pairwise_results)
        error('输入 pairwise_results 必须是一个结构体。');
    end
    required_fields = {'pair_info', 'connectivity', 'analysis_type'};
    missing_fields = setdiff(required_fields, fieldnames(pairwise_results));
    if ~isempty(missing_fields)
        error('输入结构体缺少必需字段: %s', strjoin(missing_fields, ', '));
    end
    
    % 获取基本信息
    n_pairs = length(pairwise_results.pair_info);
    if n_pairs == 0
        warning('pairwise_results 中没有配对数据。');
        evaluation_report = report;
        return;
    end
    analysis_type = pairwise_results.analysis_type;
    
    fprintf('  正在评估 %d 个配对的分析结果 (分析类型: %s)...\n', n_pairs, analysis_type);
    
    % ==================== 3. 提取元数据 ====================
    report.metadata = extract_metadata_from_results(pairwise_results);
    
    % ==================== 4. 评估数据处理质量 ====================
    fprintf('  评估模块 1/6: 数据处理质量...\n');
    report.data_quality = evaluate_data_processing_quality(pairwise_results);
    
    % ==================== 5. 评估连通性统计分布 ====================
    fprintf('  评估模块 2/6: 连通性统计分布...\n');
    report.connectivity_stats = evaluate_connectivity_statistics(pairwise_results, analysis_type, opts);
    
    % ==================== 6. 评估显著性结果 ====================
    fprintf('  评估模块 3/6: 显著性检验...\n');
    report.significance_eval = evaluate_significance_results(pairwise_results, analysis_type, opts.Alpha);
    
    % ==================== 7. 评估鲁棒性 (如启用) ====================
    fprintf('  评估模块 4/6: 鲁棒性检查...\n');
    if isfield(pairwise_results, 'robustness_score')
        report.robustness_eval = evaluate_robustness_results(pairwise_results);
    else
        report.robustness_eval = struct('enabled', false, 'message', '未启用鲁棒性检查');
    end
    
    % ==================== 8. 评估非线性检测 (如启用) ====================
    fprintf('  评估模块 5/6: 非线性检测...\n');
    report.nonlinear_eval = evaluate_nonlinear_results(pairwise_results, analysis_type);
    
    % ==================== 9. 结果一致性检查 ====================
    fprintf('  评估模块 6/6: 结果一致性检查...\n');
    report.consistency_checks = perform_consistency_checks(pairwise_results, analysis_type, opts.Alpha);
    
    % ==================== 10. 生成综合评估与建议 ====================
    report.overall_assessment = generate_overall_assessment(report, n_pairs);
    
    % ==================== 11. 生成格式化文本报告 ====================
    report.formatted_text = generate_formatted_text_report(report, opts.ReportLevel);
    
    % ==================== 12. 显示摘要 ====================
    display_evaluation_summary(report);
    
    % ==================== 13. 可选: 保存报告 ====================
    if opts.SaveReport
        save_text_report(report.formatted_text, opts.ReportFileName);
        fprintf('  评估报告已保存至: %s\n', opts.ReportFileName);
    end
    
    % ==================== 14. 可选: 生成图表 ====================
    if opts.OutputFigures
        fprintf('  正在生成评估图表...\n');
        generate_evaluation_figures(report, pairwise_results, opts);
    end
    
    % ==================== 15. 完成 ====================
    report.computation_time = toc(start_time);
    evaluation_report = report;
    fprintf('【评估完成】总计耗时: %.2f 秒\n', report.computation_time);
end

%% ==================== 核心评估辅助函数 ====================

function meta = extract_metadata_from_results(results)
% 从结果中提取元数据
    meta = struct();
    if isfield(results, 'analysis_type')
        meta.analysis_type = results.analysis_type;
    end
    if isfield(results, 'timestamp')
        meta.analysis_timestamp = results.timestamp;
    end
    if isfield(results, 'version')
        meta.analysis_version = results.version;
    end
    if isfield(results, 'parameters')
        meta.parameters = results.parameters;
    end
    if isfield(results, 'processing_stats')
        meta.processing_stats = results.processing_stats;
    end
end

function quality = evaluate_data_processing_quality(results)
% 评估数据处理质量
    stats = results.processing_stats;
    n_pairs = stats.total_pairs;
    
    quality = struct();
    quality.total_pairs = n_pairs;
    quality.processed_pairs = stats.processed_pairs;
    quality.successful_pairs = stats.successful_pairs;
    quality.skipped_pairs = stats.skipped_pairs;
    quality.failed_pairs = stats.failed_pairs;
    
    % 计算比率
    if stats.processed_pairs > 0
        quality.success_rate = stats.successful_pairs / stats.processed_pairs * 100;
        quality.skip_rate = stats.skipped_pairs / stats.processed_pairs * 100;
        quality.failure_rate = stats.failed_pairs / stats.processed_pairs * 100;
    else
        quality.success_rate = 0;
        quality.skip_rate = 0;
        quality.failure_rate = 0;
    end
    
    % 收集有效观测值
    n_obs_list = [];
    n_valid_list = [];
    for i = 1:length(results.pair_info)
        if ~isempty(results.pair_info{i}) && isfield(results.pair_info{i}, 'n_obs')
            n_obs_list(end+1) = results.pair_info{i}.n_obs;
            n_valid_list(end+1) = results.pair_info{i}.n_valid;
        end
    end
    
    if ~isempty(n_obs_list)
        quality.n_obs_stats.mean = mean(n_obs_list);
        quality.n_obs_stats.median = median(n_obs_list);
        quality.n_obs_stats.min = min(n_obs_list);
        quality.n_obs_stats.max = max(n_obs_list);
        quality.n_obs_stats.std = std(n_obs_list);
        
        quality.n_valid_stats.mean = mean(n_valid_list);
        quality.n_valid_stats.median = median(n_valid_list);
        quality.n_valid_stats.min = min(n_valid_list);
        quality.n_valid_stats.max = max(n_valid_list);
    end
    
    % 质量评级
    if quality.success_rate >= 95 && quality.n_obs_stats.mean > 100
        quality.quality_rating = '优秀';
        quality.rating_score = 5;
    elseif quality.success_rate >= 85
        quality.quality_rating = '良好';
        quality.rating_score = 4;
    elseif quality.success_rate >= 70
        quality.quality_rating = '一般';
        quality.rating_score = 3;
    else
        quality.quality_rating = '需审查';
        quality.rating_score = 2;
    end
    
    % 被跳过配对的主要原因
    if quality.skip_rate > 20
        quality.skip_warning = sprintf('有较高比例(%.1f%%)的配对被跳过，建议检查数据质量。', quality.skip_rate);
    else
        quality.skip_warning = '';
    end
end

function stats = evaluate_connectivity_statistics(results, analysis_type, opts)
% 评估连通性统计分布
    stats = struct();
    stats.analysis_type = analysis_type;
    
    % 初始化收集列表
    all_corrs = [];
    all_f_stats_x2y = [];
    all_f_stats_y2x = [];
    all_p_x2y = [];
    all_p_y2x = [];
    all_directions = {};
    
    for i = 1:length(results.connectivity)
        res = results.connectivity{i};
        if isempty(res)
            continue;
        end
        
        % 根据分析类型提取统计量
        switch analysis_type
            case 'correlation'
                if isfield(res, 'correlation')
                    all_corrs(end+1) = res.correlation;
                end
                if isfield(res, 'p_value')
                    all_p_x2y(end+1) = res.p_value; % 对于相关性，x2y和y2x相同
                end
                
            case {'granger', 'nonlinear_granger'}
                % 处理嵌套或扁平结构
                if isfield(res, 'granger')
                    granger_res = res.granger;
                else
                    granger_res = res;
                end
                
                if isfield(granger_res, 'f_statistic_x2y')
                    all_f_stats_x2y(end+1) = granger_res.f_statistic_x2y;
                end
                if isfield(granger_res, 'f_statistic_y2x')
                    all_f_stats_y2x(end+1) = granger_res.f_statistic_y2x;
                end
                if isfield(granger_res, 'p_value_x2y')
                    all_p_x2y(end+1) = granger_res.p_value_x2y;
                end
                if isfield(granger_res, 'p_value_y2x')
                    all_p_y2x(end+1) = granger_res.p_value_y2x;
                end
                if isfield(granger_res, 'direction')
                    all_directions{end+1} = granger_res.direction;
                end
                
            case 'all'
                % 综合分析: 收集所有方法的统计量
                if isfield(res, 'correlation') && isfield(res.correlation, 'correlation')
                    all_corrs(end+1) = res.correlation.correlation;
                end
                if isfield(res, 'granger')
                    if isfield(res.granger, 'f_statistic_x2y')
                        all_f_stats_x2y(end+1) = res.granger.f_statistic_x2y;
                    end
                    if isfield(res.granger, 'f_statistic_y2x')
                        all_f_stats_y2x(end+1) = res.granger.f_statistic_y2x;
                    end
                    if isfield(res.granger, 'direction')
                        all_directions{end+1} = res.granger.direction;
                    end
                end
        end
    end
    
    % 计算描述性统计
    if ~isempty(all_corrs)
        stats.correlation = calculate_descriptive_stats(all_corrs, '相关系数');
    end
    if ~isempty(all_f_stats_x2y)
        stats.f_statistic_x2y = calculate_descriptive_stats(all_f_stats_x2y, 'F统计量(X→Y)');
    end
    if ~isempty(all_f_stats_y2x)
        stats.f_statistic_y2x = calculate_descriptive_stats(all_f_stats_y2x, 'F统计量(Y→X)');
    end
    if ~isempty(all_p_x2y)
        stats.p_value_x2y = calculate_descriptive_stats(all_p_x2y, 'p值(X→Y)');
    end
    if ~isempty(all_p_y2x)
        stats.p_value_y2x = calculate_descriptive_stats(all_p_y2x, 'p值(Y→X)');
    end
    
    % 方向分布统计
    if ~isempty(all_directions)
        [unique_dirs, ~, idx] = unique(all_directions);
        counts = accumarray(idx, 1);
        dir_stats = struct();
        for d = 1:length(unique_dirs)
            dir_stats.(matlab.lang.makeValidName(unique_dirs{d})) = counts(d);
        end
        stats.direction_distribution = dir_stats;
    end
end

function desc_stats = calculate_descriptive_stats(data, label)
% 计算描述性统计
    desc_stats = struct();
    desc_stats.label = label;
    
    % 移除NaN值 - R2018a 需要手动处理NaN
    clean_data = data(~isnan(data));
    
    if isempty(clean_data) || length(clean_data) < 2
        % 如果没有足够有效数据，返回NaN
        desc_stats.mean = NaN;
        desc_stats.median = NaN;
        desc_stats.std = NaN;
        desc_stats.min = NaN;
        desc_stats.max = NaN;
        desc_stats.skewness = NaN;
        desc_stats.kurtosis = NaN;
        desc_stats.prctile_25 = NaN;
        desc_stats.prctile_75 = NaN;
        desc_stats.iqr = NaN;
        desc_stats.n_valid = 0;
        return;
    end
    
    % 基本统计量 (R2018a 版本)
    desc_stats.mean = mean(clean_data);
    desc_stats.median = median(clean_data);
    desc_stats.std = std(clean_data);
    desc_stats.min = min(clean_data);
    desc_stats.max = max(clean_data);
    desc_stats.n_valid = length(clean_data);
    
    % 偏度计算 - R2018a 兼容版本
    n = length(clean_data);
    if n >= 3
        mu = desc_stats.mean;
        sigma = desc_stats.std;
        if sigma > 0
            % 手动计算偏度
            desc_stats.skewness = sum(((clean_data - mu) / sigma).^3) / n;
        else
            desc_stats.skewness = 0;
        end
    else
        desc_stats.skewness = NaN;
    end
    
    % 峰度计算 - R2018a 兼容版本
    if n >= 4
        mu = desc_stats.mean;
        sigma = desc_stats.std;
        if sigma > 0
            % 手动计算峰度 (超额峰度)
            desc_stats.kurtosis = sum(((clean_data - mu) / sigma).^4) / n - 3;
        else
            desc_stats.kurtosis = 0;
        end
    else
        desc_stats.kurtosis = NaN;
    end
    
    % 百分位数
    desc_stats.prctile_25 = prctile(clean_data, 25);
    desc_stats.prctile_75 = prctile(clean_data, 75);
    desc_stats.iqr = desc_stats.prctile_75 - desc_stats.prctile_25;
end

function sig_eval = evaluate_significance_results(results, analysis_type, alpha)
% 评估显著性结果
    sig_eval = struct();
    sig_eval.alpha = alpha;
    
    n_pairs = length(results.connectivity);
    sig_flags = false(n_pairs, 1);
    p_values_all = [];
    test_count = 0;
    
    for i = 1:n_pairs
        res = results.connectivity{i};
        if isempty(res)
            continue;
        end
        
        switch analysis_type
            case 'correlation'
                if isfield(res, 'p_value')
                    p_val = res.p_value;
                    p_values_all(end+1) = p_val;
                    test_count = test_count + 1;
                    if p_val < alpha
                        sig_flags(i) = true;
                    end
                end
                
            case {'granger', 'nonlinear_granger'}
                if isfield(res, 'granger')
                    granger_res = res.granger;
                else
                    granger_res = res;
                end
                
                if isfield(granger_res, 'p_value_x2y') && isfield(granger_res, 'p_value_y2x')
                    p_x2y = granger_res.p_value_x2y;
                    p_y2x = granger_res.p_value_y2x;
                    p_values_all = [p_values_all, p_x2y, p_y2x];
                    test_count = test_count + 2;
                    
                    if p_x2y < alpha || p_y2x < alpha
                        sig_flags(i) = true;
                    end
                end
                
            case 'all'
                % 检查每种方法
                if isfield(res, 'correlation') && isfield(res.correlation, 'p_value')
                    p_val = res.correlation.p_value;
                    p_values_all(end+1) = p_val;
                    test_count = test_count + 1;
                    if p_val < alpha
                        sig_flags(i) = true;
                    end
                end
                if isfield(res, 'granger')
                    if isfield(res.granger, 'p_value_x2y') && isfield(res.granger, 'p_value_y2x')
                        p_x2y = res.granger.p_value_x2y;
                        p_y2x = res.granger.p_value_y2x;
                        p_values_all = [p_values_all, p_x2y, p_y2x];
                        test_count = test_count + 2;
                        
                        if p_x2y < alpha || p_y2x < alpha
                            sig_flags(i) = true;
                        end
                    end
                end
        end
    end
    
    % 基本统计
    sig_eval.total_pairs = n_pairs;
    sig_eval.significant_pairs = sum(sig_flags);
    sig_eval.significant_proportion = sum(sig_flags) / n_pairs * 100;
    sig_eval.total_tests = test_count;
    
    if ~isempty(p_values_all)
        % p值分布
        sig_eval.p_value_distribution = calculate_descriptive_stats(p_values_all, 'p值');
        
        % 多重检验问题评估
        sig_eval.expected_false_positives = alpha * test_count;
        sig_eval.observed_significant_tests = sum(p_values_all < alpha);
        
        if test_count > 1
            % 计算FDR校正
            try
                [~, ~, ~, adj_p] = fdr_bh(p_values_all, alpha, 'pdep', 'yes');
                sig_eval.fdr_corrected_significant = sum(adj_p < alpha);
                sig_eval.fdr_correction_ratio = sig_eval.fdr_corrected_significant / sig_eval.observed_significant_tests;
                
                if sig_eval.observed_significant_tests > sig_eval.expected_false_positives * 5
                    sig_eval.multiple_testing_warning = '检测到大量显著性结果，建议应用多重检验校正。';
                else
                    sig_eval.multiple_testing_warning = '';
                end
            catch
                sig_eval.fdr_corrected_significant = NaN;
                sig_eval.multiple_testing_warning = '无法计算FDR校正，请确保fdr_bh函数在路径中。';
            end
        end
    end
    
    % 评估显著性结果的可靠性
    if sig_eval.significant_proportion > 80
        sig_eval.reliability_note = '高显著性比例，结果可能过于乐观，建议检查数据或方法。';
    elseif sig_eval.significant_proportion < 5
        sig_eval.reliability_note = '低显著性比例，可能表明弱连接性或数据噪声较大。';
    else
        sig_eval.reliability_note = '显著性比例在合理范围内。';
    end
end

function robust_eval = evaluate_robustness_results(results)
% 评估鲁棒性结果
    robust_eval = struct();
    robust_eval.enabled = true;
    
    % 始终初始化这些字段
    robust_eval.robust_proportion = NaN;
    robust_eval.robust_count = 0;
    robust_eval.total_assessed = 0;
    
    % 检查是否有鲁棒性数据
    if ~isfield(results, 'robustness_score')
        robust_eval.message = '未启用鲁棒性检查';
        return;
    end
    
    % 提取鲁棒性分数
    robustness_scores = [];
    is_robust_flags = [];
    
    for i = 1:length(results.robustness_score)
        if ~isempty(results.robustness_score{i})
            robustness_scores(end+1) = results.robustness_score{i};
        end
        if ~isempty(results.is_robust{i})
            is_robust_flags(end+1) = results.is_robust{i};
        end
    end
    
    if isempty(robustness_scores)
        robust_eval.message = '未找到有效的鲁棒性评分数据。';
        return;
    end
    
    % 鲁棒性评分统计
    robust_eval.score_stats = calculate_descriptive_stats(robustness_scores, '鲁棒性评分');
    
    % 鲁棒性比例
    robust_eval.total_assessed = length(is_robust_flags);
    robust_eval.robust_count = sum(is_robust_flags);
    robust_eval.non_robust_count = sum(~is_robust_flags);
    robust_eval.robust_proportion = robust_eval.robust_count / robust_eval.total_assessed * 100;
    
    % 阈值评估
    if isfield(results.parameters, 'robustness_threshold')
        threshold = results.parameters.robustness_threshold;
        robust_eval.threshold = threshold;
        robust_eval.above_threshold = sum(robustness_scores >= threshold);
        robust_eval.below_threshold = sum(robustness_scores < threshold);
        
        if robust_eval.robust_proportion > 80
            robust_eval.assessment = '鲁棒性优秀，大部分结果稳定可靠。';
        elseif robust_eval.robust_proportion > 50
            robust_eval.assessment = '鲁棒性中等，部分结果可能需要谨慎解释。';
        else
            robust_eval.assessment = '鲁棒性较低，许多结果对数据扰动敏感，建议进一步验证。';
        end
    end
end

function nonlinear_eval = evaluate_nonlinear_results(results, analysis_type)
% 评估非线性检测结果
    nonlinear_eval = struct();
    
    % 检查是否启用了非线性检测
    if ~strcmp(analysis_type, 'nonlinear_granger') && ...
       ~strcmp(analysis_type, 'all_with_nonlinear') && ...
       ~(strcmp(analysis_type, 'granger') && isfield(results.parameters, 'enable_nonlinear_test') && ...
         results.parameters.enable_nonlinear_test)
        nonlinear_eval.enabled = false;
        nonlinear_eval.message = '未启用非线性检测';
        return;
    end
    
    nonlinear_eval.enabled = true;
    
    % 收集非线性检测结果
    has_linear_x2y = [];
    has_linear_y2x = [];
    has_nonlinear_x2y = [];
    has_nonlinear_y2x = [];
    connection_types = {};
    
    for i = 1:length(results.connectivity)
        res = results.connectivity{i};
        if isempty(res)
            continue;
        end
        
        % 根据分析类型提取非线性结果
        if strcmp(analysis_type, 'nonlinear_granger')
            nonlinear_res = res;
        elseif isfield(res, 'nonlinear')
            nonlinear_res = res.nonlinear;
        elseif isfield(res, 'nonlinear_granger')
            nonlinear_res = res.nonlinear_granger;
        else
            continue;
        end
        
        if ~isstruct(nonlinear_res)
            continue;
        end
        
        % 收集统计量
        if isfield(nonlinear_res, 'has_linear_granger_x2y')
            has_linear_x2y(end+1) = nonlinear_res.has_linear_granger_x2y;
        end
        if isfield(nonlinear_res, 'has_linear_granger_y2x')
            has_linear_y2x(end+1) = nonlinear_res.has_linear_granger_y2x;
        end
        if isfield(nonlinear_res, 'has_nonlinear_x2y')
            has_nonlinear_x2y(end+1) = nonlinear_res.has_nonlinear_x2y;
        end
        if isfield(nonlinear_res, 'has_nonlinear_y2x')
            has_nonlinear_y2x(end+1) = nonlinear_res.has_nonlinear_y2x;
        end
        if isfield(nonlinear_res, 'connection_type')
            connection_types{end+1} = nonlinear_res.connection_type;
        end
    end
    
    % 计算统计
    nonlinear_eval.total_assessed = length(has_linear_x2y);
    
    if ~isempty(has_linear_x2y)
        nonlinear_eval.linear_x2y_proportion = mean(has_linear_x2y) * 100;
    end
    if ~isempty(has_linear_y2x)
        nonlinear_eval.linear_y2x_proportion = mean(has_linear_y2x) * 100;
    end
    if ~isempty(has_nonlinear_x2y)
        nonlinear_eval.nonlinear_x2y_proportion = mean(has_nonlinear_x2y) * 100;
    end
    if ~isempty(has_nonlinear_y2x)
        nonlinear_eval.nonlinear_y2x_proportion = mean(has_nonlinear_y2x) * 100;
    end
    
    % 关系类型统计
    if ~isempty(connection_types)
        [unique_types, ~, idx] = unique(connection_types);
        counts = accumarray(idx, 1);
        type_stats = struct();
        for t = 1:length(unique_types)
            valid_name = matlab.lang.makeValidName(unique_types{t});
            type_stats.(valid_name) = counts(t);
        end
        nonlinear_eval.connection_type_distribution = type_stats;
        
        % 主要发现
        if isfield(type_stats, 'both')
            nonlinear_eval.main_finding = '检测到显著的线性和非线性混合因果关系。';
        elseif isfield(type_stats, 'nonlinear_only')
            nonlinear_eval.main_finding = '检测到显著的非线性因果关系，线性关系不显著。';
        elseif isfield(type_stats, 'linear_only')
            nonlinear_eval.main_finding = '主要检测到线性因果关系，非线性成分不显著。';
        else
            nonlinear_eval.main_finding = '未检测到显著的因果关系。';
        end
    end
end

function consistency = perform_consistency_checks(results, analysis_type, alpha)
% 执行结果一致性检查
    consistency = struct();
    consistency.checks_performed = {};
    
    n_pairs = length(results.connectivity);
    checks = {};
    
    % 检查1: Granger方向与同期相关性符号
    if strcmp(analysis_type, 'all') || strcmp(analysis_type, 'granger')
        direction_correlation_consistent = 0;
        total_checked = 0;
        
        for i = 1:n_pairs
            pair_info = results.pair_info{i};
            res = results.connectivity{i};
            if isempty(pair_info) || isempty(res)
                continue;
            end
            
            % 获取相关系数
            if isfield(pair_info, 'correlation')
                corr_val = pair_info.correlation;
            else
                continue;
            end
            
            % 获取Granger方向
            if strcmp(analysis_type, 'all')
                if isfield(res, 'granger')
                    granger_res = res.granger;
                else
                    continue;
                end
            else
                granger_res = res;
            end
            
            if ~isfield(granger_res, 'direction')
                continue;
            end
            
            direction = granger_res.direction;
            
            % 一致性检查: 如果存在显著Granger因果，相关系数符号应与方向一致
            if strcmp(direction, 'X_to_Y') && corr_val > 0
                direction_correlation_consistent = direction_correlation_consistent + 1;
            elseif strcmp(direction, 'Y_to_X') && corr_val < 0
                direction_correlation_consistent = direction_correlation_consistent + 1;
            elseif strcmp(direction, 'bidirectional')
                % 双向关系，相关系数可正可负
                direction_correlation_consistent = direction_correlation_consistent + 1;
            end
            total_checked = total_checked + 1;
        end
        
        if total_checked > 0
            consistency_ratio = direction_correlation_consistent / total_checked * 100;
            checks{end+1} = sprintf('Granger方向与相关系数符号一致性: %.1f%% (%d/%d)', ...
                consistency_ratio, direction_correlation_consistent, total_checked);
            
            if consistency_ratio < 60
                checks{end+1} = '警告: 方向与相关性符号一致性较低，建议审查异常配对。';
            end
        end
    end
    
    % 检查2: 鲁棒性与显著性一致性
    if isfield(results, 'is_robust')
        robust_significant_consistent = 0;
        total_checked = 0;
        
        for i = 1:n_pairs
            if isempty(results.is_robust{i}) || isempty(results.connectivity{i})
                continue;
            end
            
            % 检查该配对是否显著
            is_sig = false;
            res = results.connectivity{i};
            
            if strcmp(analysis_type, 'granger')
                if isfield(res, 'significant_x2y') && isfield(res, 'significant_y2x')
                    is_sig = res.significant_x2y || res.significant_y2x;
                end
            end
            
            % 一致性: 显著的结果应该更可能是鲁棒的
            if is_sig && results.is_robust{i}
                robust_significant_consistent = robust_significant_consistent + 1;
            elseif ~is_sig && ~results.is_robust{i}
                robust_significant_consistent = robust_significant_consistent + 1;
            end
            total_checked = total_checked + 1;
        end
        
        if total_checked > 0
            consistency_ratio = robust_significant_consistent / total_checked * 100;
            checks{end+1} = sprintf('显著性与鲁棒性一致性: %.1f%%', consistency_ratio);
        end
    end
    
    consistency.checks_performed = checks;
end

function assessment = generate_overall_assessment(report, n_pairs)
% 生成综合评估与建议
    assessment = struct();
    
    % 计算综合评分 (0-10分)
    scores = [];
    
    % 1. 数据质量评分 (0-2分)
    if isfield(report.data_quality, 'rating_score')
        scores(end+1) = report.data_quality.rating_score;
    else
        scores(end+1) = 3; % 默认中等
    end
    
    % 2. 显著性结果评分 (0-2分)
    if isfield(report.significance_eval, 'significant_proportion')
        sig_prop = report.significance_eval.significant_proportion;
        if sig_prop > 80
            scores(end+1) = 1; % 可能过拟合
        elseif sig_prop > 20 && sig_prop <= 80
            scores(end+1) = 2; % 合理范围
        else
            scores(end+1) = 1; % 可能信号弱
        end
    else
        scores(end+1) = 1.5;
    end
    
    % 3. 鲁棒性评分 (0-2分)
    if isfield(report.robustness_eval, 'robust_proportion')
        robust_prop = report.robustness_eval.robust_proportion;
        if robust_prop > 70
            scores(end+1) = 2;
        elseif robust_prop > 40
            scores(end+1) = 1.5;
        else
            scores(end+1) = 1;
        end
    else
        scores(end+1) = 1; % 未启用鲁棒性检查
    end
    
    % 4. 非线性检测评分 (0-2分) - 如果启用
    if isfield(report.nonlinear_eval, 'enabled') && report.nonlinear_eval.enabled
        if isfield(report.nonlinear_eval, 'nonlinear_x2y_proportion')
            nonlin_prop = report.nonlinear_eval.nonlinear_x2y_proportion;
            if nonlin_prop > 0
                scores(end+1) = 2; % 检测到非线性
            else
                scores(end+1) = 1; % 未检测到
            end
        else
            scores(end+1) = 1.5;
        end
    end
    
    % 5. 样本量评分 (0-2分)
    if isfield(report.data_quality, 'n_obs_stats')
        avg_n_obs = report.data_quality.n_obs_stats.mean;
        if avg_n_obs > 200
            scores(end+1) = 2;
        elseif avg_n_obs > 100
            scores(end+1) = 1.5;
        elseif avg_n_obs > 50
            scores(end+1) = 1;
        else
            scores(end+1) = 0.5;
        end
    else
        scores(end+1) = 1;
    end
    
    % 计算平均分并转换为0-10分制
    avg_score = mean(scores);
    overall_score = (avg_score / 2) * 10; % 转换到0-10分
    
    assessment.overall_score = overall_score;
    assessment.score_components = scores;
    
    % 根据评分给出等级
    if overall_score >= 8.5
        assessment.rating = '优秀';
        assessment.recommendation = '结果高度可靠，可直接用于进一步分析。';
    elseif overall_score >= 7.0
        assessment.rating = '良好';
        assessment.recommendation = '结果质量良好，大部分分析可靠。';
    elseif overall_score >= 5.0
        assessment.rating = '一般';
        assessment.recommendation = '结果质量一般，建议审查低质量配对并考虑重新分析。';
    else
        assessment.rating = '需改进';
        assessment.recommendation = '结果质量有待提高，建议检查数据质量、调整分析参数或方法。';
    end
    
    % 生成具体建议
    recommendations = {};
    
    if isfield(report.data_quality, 'skip_rate') && report.data_quality.skip_rate > 20
        recommendations{end+1} = sprintf('有 %.1f%% 的配对被跳过，建议检查数据完整性和质量。', report.data_quality.skip_rate);
    end
    
    if isfield(report.significance_eval, 'multiple_testing_warning') && ...
       ~isempty(report.significance_eval.multiple_testing_warning)
        recommendations{end+1} = report.significance_eval.multiple_testing_warning;
    end
    
    if isfield(report.robustness_eval, 'robust_proportion') && ...
       report.robustness_eval.robust_proportion < 50
        recommendations{end+1} = '鲁棒性结果比例较低，建议对关键发现进行进一步验证。';
    end
    
    if n_pairs < 20
        recommendations{end+1} = sprintf('配对数量较少 (%d)，统计效力可能不足，结论需谨慎。', n_pairs);
    end
    
    assessment.specific_recommendations = recommendations;
end

function report_text = generate_formatted_text_report(report, level)
% 生成格式化的文本报告
    lines = {};
    
    % 标题
    lines{end+1} = repmat('=', 1, 60);  % 改为字符向量
    lines{end+1} = '连通性分析结果评估报告';
    lines{end+1} = sprintf('生成时间: %s', report.timestamp);
    lines{end+1} = repmat('=', 1, 60);  % 改为字符向量
    lines{end+1} = '';
    
    % 1. 元数据
    lines{end+1} = '1. 分析元数据';
    lines{end+1} = repmat('-', 1, 40);  % 改为字符向量
    if isfield(report.metadata, 'analysis_type')
        lines{end+1} = sprintf('分析类型: %s', report.metadata.analysis_type);
    end
    if isfield(report.metadata, 'analysis_timestamp')
        lines{end+1} = sprintf('分析时间: %s', report.metadata.analysis_timestamp);
    end
    if isfield(report.metadata, 'analysis_version')
        lines{end+1} = sprintf('分析版本: %s', report.metadata.analysis_version);
    end
    lines{end+1} = '';
    
    % 2. 数据处理质量
    lines{end+1} = '2. 数据处理质量评估';
    lines{end+1} = repmat('-', 1, 40);
    dq = report.data_quality;
    lines{end+1} = sprintf('总配对数量: %d', dq.total_pairs);
    lines{end+1} = sprintf('成功处理: %d (%.1f%%)', dq.successful_pairs, dq.success_rate);
    lines{end+1} = sprintf('被跳过: %d (%.1f%%)', dq.skipped_pairs, dq.skip_rate);
    lines{end+1} = sprintf('处理失败: %d (%.1f%%)', dq.failed_pairs, dq.failure_rate);
    
    if isfield(dq, 'n_obs_stats')
        lines{end+1} = sprintf('平均有效观测值: %.1f (范围: %d-%d)', ...
            dq.n_obs_stats.mean, dq.n_obs_stats.min, dq.n_obs_stats.max);
    end
    
    lines{end+1} = sprintf('质量评级: %s (评分: %.1f/5)', dq.quality_rating, dq.rating_score);
    
    if isfield(dq, 'skip_warning') && ~isempty(dq.skip_warning)
        lines{end+1} = sprintf('注意: %s', dq.skip_warning);
    end
    lines{end+1} = '';
    
    % 3. 连通性统计
    if strcmp(level, 'standard') || strcmp(level, 'detailed')
        lines{end+1} = '3. 连通性统计分布';
        lines{end+1} = repmat('-', 1, 40);
        
        cs = report.connectivity_stats;
        if isfield(cs, 'correlation')
            lines{end+1} = '相关系数统计:';
            lines{end+1} = sprintf('  均值: %.3f, 标准差: %.3f, 范围: [%.3f, %.3f]', ...
                cs.correlation.mean, cs.correlation.std, cs.correlation.min, cs.correlation.max);
        end
        
        if isfield(cs, 'f_statistic_x2y')
            lines{end+1} = 'Granger F统计量 (X→Y):';
            lines{end+1} = sprintf('  均值: %.2f, 中位数: %.2f, 范围: [%.2f, %.2f]', ...
                cs.f_statistic_x2y.mean, cs.f_statistic_x2y.median, ...
                cs.f_statistic_x2y.min, cs.f_statistic_x2y.max);
        end
        
        if isfield(cs, 'direction_distribution')
            lines{end+1} = '因果关系方向分布:';
            dirs = cs.direction_distribution;
            dir_fields = fieldnames(dirs);
            for f = 1:length(dir_fields)
                lines{end+1} = sprintf('  %s: %d', dir_fields{f}, dirs.(dir_fields{f}));
            end
        end
        lines{end+1} = '';
    end
    
    % 4. 显著性评估
    lines{end+1} = '4. 显著性检验评估 (α = 0.05)';
    lines{end+1} = repmat('-', 1, 40);
    se = report.significance_eval;
    lines{end+1} = sprintf('显著配对比例: %.1f%% (%d/%d)', ...
        se.significant_proportion, se.significant_pairs, se.total_pairs);
    lines{end+1} = sprintf('总检验次数: %d', se.total_tests);
    lines{end+1} = sprintf('观测到的显著检验: %d', se.observed_significant_tests);
    lines{end+1} = sprintf('期望的假阳性数量: %.1f', se.expected_false_positives);
    
    if isfield(se, 'fdr_corrected_significant')
        lines{end+1} = sprintf('FDR校正后显著检验: %d', se.fdr_corrected_significant);
    end
    
    if isfield(se, 'reliability_note')
        lines{end+1} = sprintf('评估: %s', se.reliability_note);
    end
    
    if isfield(se, 'multiple_testing_warning') && ~isempty(se.multiple_testing_warning)
        lines{end+1} = sprintf('注意: %s', se.multiple_testing_warning);
    end
    lines{end+1} = '';
    
    % 5. 鲁棒性评估
    lines{end+1} = '5. 鲁棒性评估';
    lines{end+1} = repmat('-', 1, 40);
    re = report.robustness_eval;
    if re.enabled
        % === 修复：先检查字段是否存在 ===
        if isfield(re, 'robust_proportion') && isfield(re, 'robust_count') && isfield(re, 'total_assessed')
            lines{end+1} = sprintf('鲁棒配对比例: %.1f%% (%d/%d)', ...
                re.robust_proportion, re.robust_count, re.total_assessed);
        else
            lines{end+1} = '鲁棒性数据不完整';
        end

        if isfield(re, 'score_stats')
            lines{end+1} = sprintf('鲁棒性评分: 均值=%.3f, 范围=[%.3f, %.3f]', ...
                re.score_stats.mean, re.score_stats.min, re.score_stats.max);
        end

        if isfield(re, 'assessment')
            lines{end+1} = sprintf('评估: %s', re.assessment);
        end
    else
        lines{end+1} = re.message;
    end
    lines{end+1} = '';
    
    % 6. 非线性检测评估
    lines{end+1} = '6. 非线性检测评估';
    lines{end+1} = repmat('-', 1, 40);
    ne = report.nonlinear_eval;
    if ne.enabled
        if isfield(ne, 'linear_x2y_proportion')
            lines{end+1} = sprintf('线性因果关系 (X→Y): %.1f%%', ne.linear_x2y_proportion);
        end
        if isfield(ne, 'nonlinear_x2y_proportion')
            lines{end+1} = sprintf('非线性因果关系 (X→Y): %.1f%%', ne.nonlinear_x2y_proportion);
        end
        
        if isfield(ne, 'main_finding')
            lines{end+1} = sprintf('主要发现: %s', ne.main_finding);
        end
    else
        lines{end+1} = ne.message;
    end
    lines{end+1} = '';
    
    % 7. 一致性检查
    if strcmp(level, 'detailed')
        lines{end+1} = '7. 结果一致性检查';
        lines{end+1} = repmat('-', 1, 40);
        cc = report.consistency_checks;
        if ~isempty(cc.checks_performed)
            for i = 1:length(cc.checks_performed)
                lines{end+1} = cc.checks_performed{i};
            end
        else
            lines{end+1} = '未执行一致性检查。';
        end
        lines{end+1} = '';
    end
    
    % 8. 综合评估
    lines{end+1} = '8. 综合评估与建议';
    lines{end+1} = repmat('-', 1, 40);
    oa = report.overall_assessment;
    lines{end+1} = sprintf('综合评分: %.1f/10 (%s)', oa.overall_score, oa.rating);
    lines{end+1} = sprintf('总体建议: %s', oa.recommendation);
    
    if ~isempty(oa.specific_recommendations)
        lines{end+1} = '具体建议:';
        for i = 1:length(oa.specific_recommendations)
            lines{end+1} = sprintf('  %d. %s', i, oa.specific_recommendations{i});
        end
    end
    
    lines{end+1} = '';
%    lines{end+1} = repmat('=', 1, 60);
    lines{end+1} = '报告结束';
%    lines{end+1} = repmat('=', 1, 60);
    
    % 转换为文本
    report_text = strjoin(lines, '\n');
end

function display_evaluation_summary(report)
% 在命令行显示评估摘要
    fprintf('\n');
    fprintf('【评估摘要】\n');
    fprintf('%-30s: %s\n', '分析类型', report.metadata.analysis_type);
    
    dq = report.data_quality;
    fprintf('%-30s: %d 配对\n', '总配对数量', dq.total_pairs);
    fprintf('%-30s: %.1f%% (%d/%d)\n', '成功处理比例', ...
        dq.success_rate, dq.successful_pairs, dq.processed_pairs);
    
    se = report.significance_eval;
    fprintf('%-30s: %.1f%% (%d/%d)\n', '显著配对比例', ...
        se.significant_proportion, se.significant_pairs, se.total_pairs);
    
    if report.robustness_eval.enabled
        re = report.robustness_eval;
        fprintf('%-30s: %.1f%% (%d/%d)\n', '鲁棒配对比例', ...
            re.robust_proportion, re.robust_count, re.total_assessed);
    end
    
    oa = report.overall_assessment;
    fprintf('%-30s: %.1f/10 (%s)\n', '综合评分', oa.overall_score, oa.rating);
    fprintf('\n');
end

function save_text_report(report_text, filename)
% 保存文本报告到文件
    fid = fopen(filename, 'w', 'n', 'UTF-8');
    if fid == -1
        warning('无法打开文件 %s 进行写入。', filename);
        return;
    end
    
    % 替换换行符为系统的换行符
    if ispc
        report_text = strrep(report_text, '\n', '\r\n');
    end
    
    fprintf(fid, '%s', report_text);
    fclose(fid);
end

function generate_evaluation_figures(report, results, opts)
% 生成评估图表
    % 创建图形保存目录
    fig_dir = 'evaluation_figures';
    if ~exist(fig_dir, 'dir')
        mkdir(fig_dir);
    end
    
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    
    % 图1: 显著性p值分布
    if isfield(report.significance_eval, 'p_value_distribution')
        figure('Position', [100, 100, 800, 600], 'Visible', 'off');
        subplot(2,2,1);
        
        % 收集所有p值
        all_p_values = [];
        for i = 1:length(results.connectivity)
            res = results.connectivity{i};
            if isempty(res)
                continue;
            end
            
            if strcmp(results.analysis_type, 'correlation') && isfield(res, 'p_value')
                all_p_values(end+1) = res.p_value;
            elseif (strcmp(results.analysis_type, 'granger') || strcmp(results.analysis_type, 'nonlinear_granger'))
                if isfield(res, 'p_value_x2y')
                    all_p_values = [all_p_values, res.p_value_x2y];
                end
                if isfield(res, 'p_value_y2x')
                    all_p_values = [all_p_values, res.p_value_y2x];
                end
            end
        end
        
        if ~isempty(all_p_values)
            histogram(all_p_values, 20, 'Normalization', 'probability');
            xlabel('p值');
            ylabel('频率');
            title('p值分布');
            grid on;
            
            % 添加显著性阈值线
            hold on;
            yl = ylim;
            plot([0.05, 0.05], yl, 'r--', 'LineWidth', 1.5);
            legend('p值分布', 'α=0.05', 'Location', 'best');
            
            % 图2: QQ图检验正态性
            subplot(2,2,2);
            qqplot(all_p_values);
            title('p值QQ图 (检验正态性)');
            grid on;
            
            % 图3: 累积分布函数
            subplot(2,2,3);
            [f, x] = ecdf(all_p_values);
            plot(x, f, 'b-', 'LineWidth', 2);
            xlabel('p值');
            ylabel('累积概率');
            title('p值累积分布函数');
            grid on;
            
            % 图4: 显著性比例
            subplot(2,2,4);
            sig_prop = report.significance_eval.significant_proportion;
            bar(1, sig_prop, 'FaceColor', [0.2, 0.6, 0.8]);
            ylim([0, 100]);
            ylabel('百分比 (%)');
            title(sprintf('显著配对比例: %.1f%%', sig_prop));
            grid on;
            
            % 保存图形
            fig_name = fullfile(fig_dir, sprintf('p_value_distribution_%s.%s', timestamp, opts.FigureFormat));
            saveas(gcf, fig_name);
        end
        close(gcf);
    end
    
    % 图5: 鲁棒性评分分布 (如果启用)
    if report.robustness_eval.enabled
        figure('Position', [100, 100, 600, 400], 'Visible', 'off');
        
        robustness_scores = [];
        for i = 1:length(results.robustness_score)
            if ~isempty(results.robustness_score{i})
                robustness_scores(end+1) = results.robustness_score{i};
            end
        end
        
        if ~isempty(robustness_scores)
            histogram(robustness_scores, 15, 'Normalization', 'probability', ...
                'FaceColor', [0.8, 0.2, 0.2]);
            xlabel('鲁棒性评分');
            ylabel('频率');
            title(sprintf('鲁棒性评分分布 (均值=%.3f)', mean(robustness_scores)));
            grid on;
            
            % 添加阈值线
            if isfield(results.parameters, 'robustness_threshold')
                threshold = results.parameters.robustness_threshold;
                hold on;
                yl = ylim;
                plot([threshold, threshold], yl, 'k--', 'LineWidth', 1.5);
                legend('评分分布', sprintf('阈值=%.2f', threshold), 'Location', 'best');
            end
            
            fig_name = fullfile(fig_dir, sprintf('robustness_scores_%s.%s', timestamp, opts.FigureFormat));
            saveas(gcf, fig_name);
        end
        close(gcf);
    end
    
    fprintf('  图表已保存至目录: %s\n', fig_dir);
end

%% 补充函数: FDR校正函数 (BH方法)
function [h, crit_p, adj_p, adj_p_sidak] = fdr_bh(pvals, q, method, report)
% FDR_BH 假发现率校正 (Benjamini & Hochberg, 1995)
% 这是从MATLAB File Exchange获取的FDR校正函数
% 如果没有这个函数，可以从File Exchange下载或使用下面的简化版本

% 使用简化版本的FDR校正
    if nargin < 2 || isempty(q)
        q = 0.05;
    end
    if nargin < 3 || isempty(method)
        method = 'pdep';
    end
    if nargin < 4 || isempty(report)
        report = 'no';
    end

    p = pvals(:);
    m = length(p);
    if m == 0
        error('p向量为空');
    end

    % 排序p值
    [ps, idx] = sort(p);

    % 计算BH校正的p值
    if strcmpi(method, 'pdep')
        % BH校正
        adj_p = ps * m ./ (1:m)';
    else
        % BY校正
        c_m = sum(1./(1:m));
        adj_p = ps * m ./ (1:m)' / c_m;
    end

    % 确保调整后的p值不递减
    for i = m-1:-1:1
        if adj_p(i) > adj_p(i+1)
            adj_p(i) = adj_p(i+1);
        end
    end

    % 确保调整后的p值不超过1
    adj_p(adj_p > 1) = 1;

    % 恢复原始顺序
    adj_p_sorted = adj_p;
    adj_p(idx) = adj_p_sorted;

    % 计算显著性
    h = adj_p < q;
    crit_p = max(ps(adj_p_sorted <= q));
    if isempty(crit_p)
        crit_p = 0;
    end

    % 可选: ?idák校正
    adj_p_sidak = 1 - (1 - p) .^ m;
end