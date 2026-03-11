function [processed_results, process_stats] = results_post_processor(...
    pairwise_results, processing_stats, params)
% RESULTS_POST_PROCESSOR - 结果后处理核心模块
%
% 【功能描述】
% 对批量配对分析结果进行核心后处理，包括多重比较校正、
% 数据质量汇总、显著性统计、鲁棒性汇总等基础统计。
%
% 【主要功能】
% 1. 多重比较校正（FDR/Bonferroni）
% 2. 数据质量信息汇总
% 3. 显著性结果统计
% 4. 鲁棒性结果整合
% 5. 基础处理统计增强
%
% 输入参数:
%   pairwise_results: 结构体数组，每个元素为单个配对的分析结果
%
%   processing_stats: 结构体，原始处理统计信息
%
%   params: 结构体，分析参数
%           - 必需字段: significance_level
%           - 可选字段: enable_robustness_check, 等
%
% 输出参数:
%   processed_results: 结构体数组，校正后的结果
%
%   process_stats: 结构体，后处理统计，包含:
%     - correction_applied: 逻辑值，是否应用校正
%     - correction_method: 字符串，校正方法
%     - quality_summary: 结构体，数据质量摘要
%     - significance_summary: 结构体，显著性统计
%     - robustness_summary: 结构体，鲁棒性统计
%     - processing_time: 标量，处理时间
%     - n_results_processed: 整数，处理的结果数
%
% 示例:
%   [corrected_results, stats] = results_post_processor(...
%       results, stats, params);
%
% 版本: 3.0
% 作者: Financial Network Analysis Toolbox
% 创建日期: 2024-12-28
% =========================================================================

%% 初始化
start_time = tic;
processed_results = pairwise_results;
process_stats = struct();

fprintf('执行结果后处理...\n');

%% 1. 多重比较校正
fprintf('  - 多重比较校正...\n');
[processed_results, correction_info] = apply_multiple_comparison_correction(...
    processed_results, params.significance_level);

process_stats.correction_applied = correction_info.applied;
process_stats.correction_method = correction_info.method;
process_stats.n_tests_corrected = correction_info.n_tests;

%% 2. 数据质量汇总
fprintf('  - 数据质量汇总...\n');
quality_summary = summarize_data_quality(processed_results);
process_stats.quality_summary = quality_summary;

%% 3. 显著性统计
fprintf('  - 显著性统计...\n');
significance_summary = summarize_significance_results(processed_results, params);
process_stats.significance_summary = significance_summary;

%% 4. 鲁棒性结果汇总
if isfield(params, 'enable_robustness_check') && params.enable_robustness_check
    fprintf('  - 鲁棒性汇总...\n');
    robustness_summary = summarize_robustness_results(processed_results);
    process_stats.robustness_summary = robustness_summary;
else
    process_stats.robustness_summary = struct(...
        'n_robust', 0, 'n_total', 0, 'message', '鲁棒性检查未启用');
end

%% 5. 基础处理统计
process_stats.processing_time = toc(start_time);
process_stats.n_results_processed = length(processed_results);
process_stats.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

% 继承原始处理统计
if ~isempty(processing_stats)
    process_stats.original_stats = processing_stats;
    
    % 计算增强指标
    if isfield(processing_stats, 'total_time') && processing_stats.total_time > 0
        process_stats.post_processing_ratio = ...
            process_stats.processing_time / processing_stats.total_time * 100;
    end
end

fprintf('后处理完成 (耗时: %.2f 秒)\n', process_stats.processing_time);

end

%% ==================== 核心后处理函数 ====================

function [results_corrected, correction_info] = apply_multiple_comparison_correction(results, alpha)
% 应用多重比较校正
    
    results_corrected = results;
    correction_info = struct('applied', false, 'method', 'none', 'n_tests', 0);
    
    % 收集所有p值
    all_p_values = [];
    pair_indices = [];
    value_positions = {};
    
    for i = 1:length(results)
        if ~isempty(results(i).significance) && isfield(results(i).significance, 'p_values')
            p_vals = results(i).significance.p_values(:);
            valid_idx = ~isnan(p_vals) & ~isinf(p_vals);
            
            if any(valid_idx)
                valid_p_vals = p_vals(valid_idx);
                all_p_values = [all_p_values; valid_p_vals];
                pair_indices = [pair_indices; i*ones(sum(valid_idx), 1)];
                
                % 记录位置信息
                for j = 1:length(valid_p_vals)
                    value_positions{end+1} = struct(...
                        'pair_idx', i, ...
                        'value_idx', find(valid_idx, j, 'first'), ...
                        'p_value', valid_p_vals(j));
                end
            end
        end
    end
    
    % 如果没有p值，直接返回
    if isempty(all_p_values)
        return;
    end
    
    correction_info.n_tests = length(all_p_values);
    
    % 应用FDR校正
    try
        [~, ~, ~, adj_p] = fdr_bh(all_p_values, alpha, 'pdep', 'yes');
        correction_info.applied = true;
        correction_info.method = 'fdr_bh';
        correction_info.original_p_values = all_p_values;
        correction_info.adjusted_p_values = adj_p;
        
        % 将校正后的p值分配回各个配对
        for k = 1:length(adj_p)
            pos_info = value_positions{k};
            pair_idx = pos_info.pair_idx;
            value_idx = pos_info.value_idx;
            
            if ~isfield(results_corrected(pair_idx).significance, 'adjusted_p')
                % 初始化adjusted_p字段
                p_size = size(results_corrected(pair_idx).significance.p_values);
                results_corrected(pair_idx).significance.adjusted_p = nan(p_size);
            end
            
            % 分配校正后的p值
            if isfield(results_corrected(pair_idx).significance, 'adjusted_p')
                if isvector(results_corrected(pair_idx).significance.adjusted_p)
                    results_corrected(pair_idx).significance.adjusted_p(value_idx) = adj_p(k);
                else
                    % 对于矩阵形式的p值
                    [row, col] = ind2sub(size(results_corrected(pair_idx).significance.p_values), value_idx);
                    results_corrected(pair_idx).significance.adjusted_p(row, col) = adj_p(k);
                end
            end
            
            % 更新显著性判断
            if isfield(results_corrected(pair_idx).significance, 'is_significant')
                if adj_p(k) < alpha
                    results_corrected(pair_idx).significance.is_significant = true;
                end
            end
        end
        
    catch ME
        warning('FDR校正失败: %s，使用Bonferroni校正', ME.message);
        
        % 使用Bonferroni校正
        n_tests = length(all_p_values);
        bonferroni_alpha = alpha / n_tests;
        
        for i = 1:length(results)
            if ~isempty(results(i).significance) && isfield(results(i).significance, 'p_values')
                p_vals = results(i).significance.p_values;
                adj_p_vals = min(p_vals * n_tests, 1);
                
                if ~isfield(results_corrected(i).significance, 'adjusted_p')
                    results_corrected(i).significance.adjusted_p = adj_p_vals;
                else
                    results_corrected(i).significance.adjusted_p = adj_p_vals;
                end
                
                % 更新显著性判断
                if isfield(results_corrected(i).significance, 'is_significant')
                    if any(adj_p_vals(:) < alpha)
                        results_corrected(i).significance.is_significant = true;
                    end
                end
            end
        end
        
        correction_info.applied = true;
        correction_info.method = 'bonferroni';
        correction_info.corrected_alpha = bonferroni_alpha;
    end
    
    % 统计校正效果
    if correction_info.applied
        original_sig = sum(all_p_values < alpha);
        if strcmp(correction_info.method, 'fdr_bh')
            corrected_sig = sum(adj_p < alpha);
        else
            corrected_sig = sum(all_p_values < bonferroni_alpha);
        end
        
        correction_info.original_significant = original_sig;
        correction_info.corrected_significant = corrected_sig;
        correction_info.reduction_percent = (original_sig - corrected_sig) / original_sig * 100;
    end
end

function quality_summary = summarize_data_quality(results)
% 汇总数据质量信息
    
    quality_summary = struct();
    
    n_pairs = length(results);
    if n_pairs == 0
        quality_summary.message = '无有效结果';
        return;
    end
    
    quality_passed = 0;
    quality_failed = 0;
    all_issues = {};
    n_valid_obs = [];
    
    for i = 1:n_pairs
        if ~isempty(results(i).pair_info) && isfield(results(i).pair_info, 'data_quality')
            quality = results(i).pair_info.data_quality;
            
            if quality.passed
                quality_passed = quality_passed + 1;
            else
                quality_failed = quality_failed + 1;
            end
            
            % 收集问题
            if isfield(quality, 'issues') && ~isempty(quality.issues)
                all_issues = [all_issues, quality.issues];
            end
            
            % 收集有效观测数
            if isfield(results(i).pair_info, 'n_valid')
                n_valid_obs(end+1) = results(i).pair_info.n_valid;
            end
        end
    end
    
    quality_summary.n_pairs = n_pairs;
    quality_summary.n_quality_passed = quality_passed;
    quality_summary.n_quality_failed = quality_failed;
    quality_summary.pass_rate = quality_passed / n_pairs * 100;
    quality_summary.fail_rate = quality_failed / n_pairs * 100;
    
    % 观测数统计
    if ~isempty(n_valid_obs)
        quality_summary.obs_stats = struct(...
            'mean', mean(n_valid_obs), ...
            'median', median(n_valid_obs), ...
            'std', std(n_valid_obs), ...
            'min', min(n_valid_obs), ...
            'max', max(n_valid_obs), ...
            'n_below_20', sum(n_valid_obs < 20), ...
            'n_below_50', sum(n_valid_obs < 50), ...
            'n_below_100', sum(n_valid_obs < 100));
    end
    
    % 问题统计
    if ~isempty(all_issues)
        [unique_issues, ~, idx] = unique(all_issues);
        counts = accumarray(idx, 1);
        total_issues = sum(counts);
        
        [sorted_counts, sort_idx] = sort(counts, 'descend');
        n_top = min(5, length(sorted_counts));
        
        quality_summary.top_issues = unique_issues(sort_idx(1:n_top));
        quality_summary.issue_counts = sorted_counts(1:n_top);
        quality_summary.total_issues = total_issues;
        quality_summary.issues_per_pair = total_issues / n_pairs;
        
        % 问题类型分布
        issue_categories = {'缺失值', '常数序列', '异常值', '平稳性', '其他'};
        category_counts = zeros(1, 5);
        
        for j = 1:length(all_issues)
            issue = all_issues{j};
            if contains(issue, '缺失值')
                category_counts(1) = category_counts(1) + 1;
            elseif contains(issue, '常数')
                category_counts(2) = category_counts(2) + 1;
            elseif contains(issue, '异常值')
                category_counts(3) = category_counts(3) + 1;
            elseif contains(issue, '平稳')
                category_counts(4) = category_counts(4) + 1;
            else
                category_counts(5) = category_counts(5) + 1;
            end
        end
        
        quality_summary.issue_categories = issue_categories;
        quality_summary.category_counts = category_counts;
        quality_summary.category_percentages = category_counts / total_issues * 100;
    else
        quality_summary.top_issues = {};
        quality_summary.issue_counts = [];
        quality_summary.total_issues = 0;
        quality_summary.issues_per_pair = 0;
    end
end

function sig_summary = summarize_significance_results(results, params)
% 汇总显著性结果
    
    sig_summary = struct();
    
    n_pairs = length(results);
    if n_pairs == 0
        sig_summary.message = '无有效结果';
        return;
    end
    
    % 初始化统计
    significant_pairs = 0;
    all_p_values = [];
    adjusted_p_values = [];
    method_stats = struct();
    
    % 按分析类型分组
    if isfield(params, 'analysis_type')
        analysis_type = params.analysis_type;
    else
        analysis_type = 'unknown';
    end
    
    for i = 1:n_pairs
        if ~isempty(results(i).significance)
            % 总体显著性
            if isfield(results(i).significance, 'is_significant')
                if results(i).significance.is_significant
                    significant_pairs = significant_pairs + 1;
                end
            end
            
            % 收集p值
            if isfield(results(i).significance, 'p_values')
                p_vals = results(i).significance.p_values(:);
                valid_p = p_vals(~isnan(p_vals) & ~isinf(p_vals));
                all_p_values = [all_p_values; valid_p];
            end
            
            % 收集校正后的p值
            if isfield(results(i).significance, 'adjusted_p')
                adj_p = results(i).significance.adjusted_p(:);
                valid_adj = adj_p(~isnan(adj_p) & ~isinf(adj_p));
                adjusted_p_values = [adjusted_p_values; valid_adj];
            end
            
            % 按方法统计
            if isfield(results(i).significance, 'significance_by_method')
                methods = fieldnames(results(i).significance.significance_by_method);
                for j = 1:length(methods)
                    method = methods{j};
                    if ~isfield(method_stats, method)
                        method_stats.(method) = struct('significant', 0, 'total', 0);
                    end
                    
                    method_stats.(method).total = method_stats.(method).total + 1;
                    if results(i).significance.significance_by_method.(method)
                        method_stats.(method).significant = method_stats.(method).significant + 1;
                    end
                end
            end
        end
    end
    
    % 基本统计
    sig_summary.n_pairs = n_pairs;
    sig_summary.n_significant = significant_pairs;
    sig_summary.percent_significant = significant_pairs / n_pairs * 100;
    sig_summary.analysis_type = analysis_type;
    
    if isfield(params, 'significance_level')
        sig_summary.significance_level = params.significance_level;
    end
    
    % 原始p值统计
    if ~isempty(all_p_values)
        sig_summary.p_value_stats = calculate_statistics(all_p_values, '原始p值');
        
        % p值分布
        edges = [0, 0.001, 0.01, 0.05, 0.1, 0.2, 0.5, 1];
        counts = histcounts(all_p_values, edges);
        sig_summary.p_value_distribution = struct(...
            'bins', edges, ...
            'counts', counts, ...
            'percentages', counts / length(all_p_values) * 100, ...
            'cumulative', cumsum(counts) / length(all_p_values) * 100);
        
        % 与阈值比较
        if isfield(params, 'significance_level')
            alpha = params.significance_level;
            sig_summary.below_threshold = sum(all_p_values < alpha);
            sig_summary.percent_below_threshold = sum(all_p_values < alpha) / length(all_p_values) * 100;
        end
    end
    
    % 校正后p值统计
    if ~isempty(adjusted_p_values)
        sig_summary.adjusted_p_stats = calculate_statistics(adjusted_p_values, '校正p值');
        
        if isfield(params, 'significance_level')
            alpha = params.significance_level;
            sig_summary.adjusted_below_threshold = sum(adjusted_p_values < alpha);
            sig_summary.adjusted_percent_below = sum(adjusted_p_values < alpha) / length(adjusted_p_values) * 100;
        end
    end
    
    % 方法级统计
    if ~isempty(fieldnames(method_stats))
        methods = fieldnames(method_stats);
        method_summary = struct();
        
        for k = 1:length(methods)
            method = methods{k};
            stats = method_stats.(method);
            
            method_summary.(method) = struct(...
                'significant', stats.significant, ...
                'total', stats.total, ...
                'percent', stats.significant / max(1, stats.total) * 100, ...
                'method_name', method);
        end
        
        % 按百分比排序
        method_names = fieldnames(method_summary);
        percentages = zeros(length(method_names), 1);
        for m = 1:length(method_names)
            percentages(m) = method_summary.(method_names{m}).percent;
        end
        
        [sorted_percents, sort_idx] = sort(percentages, 'descend');
        sorted_methods = method_names(sort_idx);
        
        sig_summary.methods_by_sensitivity = sorted_methods;
        sig_summary.methods_percentages = sorted_percents;
        sig_summary.method_summary = method_summary;
    end
    
    % 效应量统计（如果可用）
    effect_sizes = [];
    for i = 1:n_pairs
        if ~isempty(results(i).connectivity) && isfield(results(i).significance, 'is_significant')
            if results(i).significance.is_significant
                % 尝试提取效应量
                if isfield(results(i).connectivity, 'effect_size')
                    effect_sizes = [effect_sizes; results(i).connectivity.effect_size];
                elseif isfield(results(i).connectivity, 'correlation')
                    effect_sizes = [effect_sizes; abs(results(i).connectivity.correlation)];
                elseif isfield(results(i).connectivity, 'f_statistic_x2y')
                    effect_sizes = [effect_sizes; results(i).connectivity.f_statistic_x2y];
                end
            end
        end
    end
    
    if ~isempty(effect_sizes)
        sig_summary.effect_size_stats = calculate_statistics(effect_sizes, '效应量');
        
        % 效应量强度分级
        strong = sum(effect_sizes >= 0.5);
        moderate = sum(effect_sizes >= 0.3 & effect_sizes < 0.5);
        weak = sum(effect_sizes >= 0.1 & effect_sizes < 0.3);
        negligible = sum(effect_sizes < 0.1);
        
        sig_summary.effect_strength = struct(...
            'strong', struct('count', strong, 'percent', strong/length(effect_sizes)*100), ...
            'moderate', struct('count', moderate, 'percent', moderate/length(effect_sizes)*100), ...
            'weak', struct('count', weak, 'percent', weak/length(effect_sizes)*100), ...
            'negligible', struct('count', negligible, 'percent', negligible/length(effect_sizes)*100));
    end
end

function robustness_summary = summarize_robustness_results(results)
% 汇总鲁棒性结果
    
    robustness_summary = struct();
    
    n_pairs = length(results);
    if n_pairs == 0
        robustness_summary.message = '无有效结果';
        return;
    end
    
    robust_pairs = 0;
    all_scores = [];
    method_counts = containers.Map('KeyType', 'char', 'ValueType', 'double');
    
    for i = 1:n_pairs
        if ~isempty(results(i).robustness)
            % 鲁棒性判断
            if isfield(results(i).robustness, 'is_robust')
                if results(i).robustness.is_robust
                    robust_pairs = robust_pairs + 1;
                end
            end
            
            % 收集鲁棒性评分
            if isfield(results(i).robustness, 'robustness_score')
                score = results(i).robustness.robustness_score;
                if ~isnan(score)
                    all_scores = [all_scores; score];
                end
            end
            
            % 统计方法使用
            if isfield(results(i).robustness, 'method_used')
                method = results(i).robustness.method_used;
                if isKey(method_counts, method)
                    method_counts(method) = method_counts(method) + 1;
                else
                    method_counts(method) = 1;
                end
            end
        end
    end
    
    % 基本统计
    robustness_summary.n_pairs = n_pairs;
    robustness_summary.n_robust = robust_pairs;
    robustness_summary.percent_robust = robust_pairs / n_pairs * 100;
    robustness_summary.n_with_robustness = sum(~cellfun(@isempty, {results.robustness}));
    
    % 评分统计
    if ~isempty(all_scores)
        robustness_summary.score_stats = calculate_statistics(all_scores, '鲁棒性评分');
        
        % 评分分布
        edges = 0:0.1:1.1;
        counts = histcounts(all_scores, edges);
        percentages = counts / length(all_scores) * 100;
        
        robustness_summary.score_distribution = struct(...
            'bins', edges(1:end-1), ...
            'bin_centers', edges(1:end-1) + 0.05, ...
            'counts', counts, ...
            'percentages', percentages, ...
            'cumulative', cumsum(percentages));
        
        % 阈值分析
        thresholds = [0.5, 0.6, 0.7, 0.8, 0.9];
        threshold_counts = zeros(1, length(thresholds));
        for t = 1:length(thresholds)
            threshold_counts(t) = sum(all_scores >= thresholds(t));
        end
        
        robustness_summary.threshold_analysis = struct(...
            'thresholds', thresholds, ...
            'counts_above', threshold_counts, ...
            'percentages_above', threshold_counts / length(all_scores) * 100);
    end
    
    % 方法统计
    if ~isempty(method_counts)
        methods = keys(method_counts);
        counts = values(method_counts);
        
        robustness_summary.methods_used = methods;
        robustness_summary.method_counts = cell2mat(counts);
        robustness_summary.method_percentages = cell2mat(counts) / n_pairs * 100;
        
        % 按使用频率排序
        [sorted_counts, sort_idx] = sort(cell2mat(counts), 'descend');
        robustness_summary.methods_by_frequency = methods(sort_idx);
        robustness_summary.counts_by_frequency = sorted_counts;
    end
    
    % 鲁棒性与显著性关系
    robust_and_sig = 0;
    robust_not_sig = 0;
    not_robust_sig = 0;
    not_robust_not_sig = 0;
    
    for i = 1:n_pairs
        has_robustness = ~isempty(results(i).robustness) && isfield(results(i).robustness, 'is_robust');
        has_significance = ~isempty(results(i).significance) && isfield(results(i).significance, 'is_significant');
        
        if has_robustness && has_significance
            is_robust = results(i).robustness.is_robust;
            is_sig = results(i).significance.is_significant;
            
            if is_robust && is_sig
                robust_and_sig = robust_and_sig + 1;
            elseif is_robust && ~is_sig
                robust_not_sig = robust_not_sig + 1;
            elseif ~is_robust && is_sig
                not_robust_sig = not_robust_sig + 1;
            else
                not_robust_not_sig = not_robust_not_sig + 1;
            end
        end
    end
    
    total_classified = robust_and_sig + robust_not_sig + not_robust_sig + not_robust_not_sig;
    if total_classified > 0
        robustness_summary.robustness_significance_matrix = struct(...
            'robust_and_sig', robust_and_sig, ...
            'robust_not_sig', robust_not_sig, ...
            'not_robust_sig', not_robust_sig, ...
            'not_robust_not_sig', not_robust_not_sig, ...
            'total_classified', total_classified, ...
            'percent_robust_and_sig', robust_and_sig/total_classified*100, ...
            'percent_robust_among_sig', robust_and_sig/(robust_and_sig+not_robust_sig)*100, ...
            'percent_sig_among_robust', robust_and_sig/(robust_and_sig+robust_not_sig)*100);
    end
end

%% ==================== 辅助函数 ====================

function stats = calculate_statistics(data, label)
% 计算基本的统计量
    stats = struct();
    stats.label = label;
    stats.n = length(data);
    stats.mean = mean(data, 'omitnan');
    stats.median = median(data, 'omitnan');
    stats.std = std(data, 'omitnan');
    stats.min = min(data, [], 'omitnan');
    stats.max = max(data, [], 'omitnan');
    stats.range = stats.max - stats.min;
    stats.iqr = iqr(data);
    stats.skewness = skewness(data);
    stats.kurtosis = kurtosis(data);
    stats.mad = mad(data, 0);  % 中位数绝对偏差
    stats.cv = stats.std / abs(stats.mean) * 100;  % 变异系数
end