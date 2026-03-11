function [analysis_summary, report_text] = report_generator(...
    processed_results, process_stats, params, start_time)
% REPORT_GENERATOR - 分析报告生成模块
%
% 【功能描述】
% 生成完整的连通性分析报告，包括性能指标、网络预览、
% 详细统计和格式化报告文本。
%
% 【主要功能】
% 1. 性能指标计算与评估
% 2. 网络指标预览与分析
% 3. 报告文本生成
% 4. 摘要结构体构建
%
% 输入参数:
%   processed_results: 结构体数组，后处理后的结果
%
%   process_stats: 结构体，后处理统计
%
%   params: 结构体，分析参数
%
%   start_time: tic计时器句柄
%
% 输出参数:
%   analysis_summary: 结构体，完整的分析摘要
%     - analysis_parameters: 分析参数
%     - processing_stats: 处理统计
%     - quality_summary: 数据质量摘要
%     - significance_summary: 显著性统计
%     - robustness_summary: 鲁棒性统计
%     - network_metrics: 网络指标预览
%     - performance_metrics: 性能指标
%     - timestamp: 时间戳
%     - version: 系统版本
%
%   report_text: 字符串，格式化的报告文本
%
% 示例:
%   [summary, report] = report_generator(...
%       results, stats, params, tic_handle);
%
% 版本: 3.0
% 作者: Financial Network Analysis Toolbox
% 创建日期: 2024-12-28
% =========================================================================

%% 初始化
analysis_summary = struct();
report_lines = {};

fprintf('生成分析报告...\n');

%% 1. 分析参数记录
analysis_summary.analysis_parameters = extract_analysis_parameters(params);

%% 2. 处理统计整合
analysis_summary.processing_stats = enhance_processing_stats(process_stats, start_time);

%% 3. 继承后处理统计
if isfield(process_stats, 'quality_summary')
    analysis_summary.quality_summary = process_stats.quality_summary;
end
if isfield(process_stats, 'significance_summary')
    analysis_summary.significance_summary = process_stats.significance_summary;
end
if isfield(process_stats, 'robustness_summary')
    analysis_summary.robustness_summary = process_stats.robustness_summary;
end

%% 4. 网络指标预览
analysis_summary.network_metrics = preview_network_metrics(processed_results);

%% 5. 性能指标计算
analysis_summary.performance_metrics = calculate_performance_metrics(...
    analysis_summary.processing_stats, processed_results);

%% 6. 元数据
analysis_summary.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
analysis_summary.version = '3.0_modular';
analysis_summary.generation_time = toc(tic);

%% 7. 生成报告文本
report_text = generate_report_text(analysis_summary, params);

fprintf('报告生成完成\n');

end

%% ==================== 核心报告函数 ====================

function params_struct = extract_analysis_parameters(params)
% 提取分析参数
    params_struct = struct();
    
    % 必需参数
    if isfield(params, 'analysis_type')
        params_struct.analysis_type = params.analysis_type;
    end
    if isfield(params, 'significance_level')
        params_struct.significance_level = params.significance_level;
    end
    
    % 可选参数
    optional_params = {'max_lag', 'bootstrap_reps', 'enable_robustness_check', ...
        'robustness_method', 'enable_nonlinear_test', 'nonlinear_method', ...
        'use_parallel', 'data_quality_check', 'min_valid_obs'};
    
    for i = 1:length(optional_params)
        param_name = optional_params{i};
        if isfield(params, param_name)
            params_struct.(param_name) = params.(param_name);
        end
    end
    
    % 计算参数总数
    params_struct.n_parameters = length(fieldnames(params_struct));
end

function enhanced_stats = enhance_processing_stats(process_stats, start_time)
% 增强处理统计
    enhanced_stats = process_stats;
    
    % 计算总时间
    if ~isempty(start_time)
        enhanced_stats.total_time = toc(start_time);
    end
    
    % 计算效率指标
    if isfield(enhanced_stats, 'total_time') && enhanced_stats.total_time > 0
        if isfield(enhanced_stats, 'n_results_processed')
            enhanced_stats.pairs_per_second = enhanced_stats.n_results_processed / enhanced_stats.total_time;
        end
        
        if isfield(enhanced_stats, 'original_stats') && isfield(enhanced_stats.original_stats, 'processed_pairs')
            enhanced_stats.analysis_efficiency = enhanced_stats.original_stats.processed_pairs / enhanced_stats.total_time;
        end
    end
    
    % 成功率分级
    if isfield(enhanced_stats, 'original_stats') && isfield(enhanced_stats.original_stats, 'success_rate')
        success_rate = enhanced_stats.original_stats.success_rate;
        if success_rate >= 90
            enhanced_stats.success_grade = '优秀';
        elseif success_rate >= 80
            enhanced_stats.success_grade = '良好';
        elseif success_rate >= 70
            enhanced_stats.success_grade = '一般';
        else
            enhanced_stats.success_grade = '需改进';
        end
    end
    
    % 内存使用估计
    if isfield(enhanced_stats, 'original_stats')
        enhanced_stats.memory_info = estimate_memory_usage(enhanced_stats.original_stats);
    end
end

function network_metrics = preview_network_metrics(results)
% 预览网络指标
    
    network_metrics = struct();
    
    n_pairs = length(results);
    if n_pairs == 0
        network_metrics.message = '无有效配对结果';
        return;
    end
    
    % 提取显著配对信息
    significant_pairs = 0;
    directions = {};
    lags = [];
    effect_sizes = [];
    correlation_strengths = [];
    
    for i = 1:n_pairs
        if ~isempty(results(i).significance) && isfield(results(i).significance, 'is_significant')
            if results(i).significance.is_significant
                significant_pairs = significant_pairs + 1;
                
                % 方向
                if ~isempty(results(i).connectivity) && isfield(results(i).connectivity, 'direction')
                    directions{end+1} = results(i).connectivity.direction;
                end
                
                % 滞后
                if ~isempty(results(i).lag_info)
                    if isfield(results(i).lag_info, 'dominant_lag')
                        lags = [lags; results(i).lag_info.dominant_lag];
                    elseif isfield(results(i).lag_info, 'optimal_lag')
                        lags = [lags; results(i).lag_info.optimal_lag];
                    end
                end
                
                % 效应量
                if ~isempty(results(i).connectivity)
                    if isfield(results(i).connectivity, 'effect_size')
                        effect_sizes = [effect_sizes; results(i).connectivity.effect_size];
                    elseif isfield(results(i).connectivity, 'correlation')
                        corr_val = results(i).connectivity.correlation;
                        correlation_strengths = [correlation_strengths; abs(corr_val)];
                    end
                end
            end
        end
    end
    
    % 基本网络指标
    network_metrics.n_total_pairs = n_pairs;
    network_metrics.n_significant_edges = significant_pairs;
    
    if n_pairs > 0
        network_metrics.edge_density = significant_pairs / n_pairs;
        network_metrics.connectivity_ratio = significant_pairs / n_pairs;
    else
        network_metrics.edge_density = 0;
        network_metrics.connectivity_ratio = 0;
    end
    
    % 方向统计
    if ~isempty(directions)
        [unique_dirs, ~, idx] = unique(directions);
        dir_counts = accumarray(idx, 1);
        
        dir_stats = struct();
        for j = 1:length(unique_dirs)
            dir_name = strrep(unique_dirs{j}, ' ', '_');
            dir_name = strrep(dir_name, '-', '_');
            dir_name = strrep(dir_name, '→', '_to_');
            dir_stats.(dir_name) = struct(...
                'count', dir_counts(j), ...
                'percent', dir_counts(j)/length(directions)*100);
        end
        
        network_metrics.direction_stats = dir_stats;
        network_metrics.dominant_direction = unique_dirs{find(dir_counts == max(dir_counts), 1)};
    end
    
    % 滞后统计
    if ~isempty(lags)
        valid_lags = lags(~isnan(lags) & ~isinf(lags) & lags > 0);
        if ~isempty(valid_lags)
            network_metrics.lag_stats = calculate_statistics(valid_lags, '滞后');
            
            % 滞后分布
            max_lag = max(valid_lags);
            if max_lag <= 10
                edges = 0:max_lag;
            else
                edges = 0:ceil(max_lag/5):max_lag;
            end
            counts = histcounts(valid_lags, edges);
            
            network_metrics.lag_distribution = struct(...
                'bins', edges(1:end-1), ...
                'counts', counts, ...
                'percentages', counts/length(valid_lags)*100);
        end
    end
    
    % 效应量/相关性强度统计
    if ~isempty(effect_sizes)
        network_metrics.effect_size_stats = calculate_statistics(effect_sizes, '效应量');
    elseif ~isempty(correlation_strengths)
        network_metrics.correlation_stats = calculate_statistics(correlation_strengths, '相关性强度');
        
        % 相关性强度分级
        thresholds = [0.1, 0.3, 0.5, 0.7, 0.9];
        strength_labels = {'可忽略', '弱', '中等', '强', '极强'};
        strength_counts = zeros(1, length(thresholds));
        
        for t = 1:length(thresholds)
            if t == 1
                strength_counts(t) = sum(correlation_strengths < thresholds(t));
            elseif t == length(thresholds)
                strength_counts(t) = sum(correlation_strengths >= thresholds(t));
            else
                strength_counts(t) = sum(correlation_strengths >= thresholds(t-1) & correlation_strengths < thresholds(t));
            end
        end
        
        network_metrics.correlation_strength = struct(...
            'thresholds', thresholds, ...
            'labels', {strength_labels}, ...
            'counts', strength_counts, ...
            'percentages', strength_counts/length(correlation_strengths)*100);
    end
    
    % 网络密度评估
    if network_metrics.edge_density > 0.8
        network_metrics.density_assessment = '非常稠密';
    elseif network_metrics.edge_density > 0.5
        network_metrics.density_assessment = '稠密';
    elseif network_metrics.edge_density > 0.3
        network_metrics.density_assessment = '中等密度';
    elseif network_metrics.edge_density > 0.1
        network_metrics.density_assessment = '稀疏';
    else
        network_metrics.density_assessment = '非常稀疏';
    end
    
    % 预测网络规模
    if isfield(results(1).pair_info, 'x_name')
        % 尝试估计节点数
        all_nodes = {};
        for i = 1:min(100, n_pairs)  % 采样部分配对
            if ~isempty(results(i).pair_info)
                all_nodes{end+1} = results(i).pair_info.x_name;
                all_nodes{end+1} = results(i).pair_info.y_name;
            end
        end
        unique_nodes = unique(all_nodes);
        network_metrics.estimated_nodes = length(unique_nodes);
        
        if network_metrics.estimated_nodes > 0
            max_possible_edges = network_metrics.estimated_nodes * (network_metrics.estimated_nodes - 1);
            if max_possible_edges > 0
                network_metrics.actual_vs_possible = significant_pairs / max_possible_edges;
            end
        end
    end
end

function perf_metrics = calculate_performance_metrics(stats, results)
% 计算性能指标
    perf_metrics = struct();
    
    % 时间性能
    if isfield(stats, 'total_time')
        perf_metrics.total_time_seconds = stats.total_time;
        perf_metrics.total_time_minutes = stats.total_time / 60;
        
        if isfield(stats, 'n_results_processed') && stats.n_results_processed > 0
            perf_metrics.time_per_result = stats.total_time / stats.n_results_processed;
        end
    end
    
    % 处理效率
    if isfield(stats, 'pairs_per_second')
        perf_metrics.processing_speed = stats.pairs_per_second;
        
        if perf_metrics.processing_speed > 10
            perf_metrics.speed_rating = '极快';
        elseif perf_metrics.processing_speed > 1
            perf_metrics.speed_rating = '快速';
        elseif perf_metrics.processing_speed > 0.1
            perf_metrics.speed_rating = '中等';
        else
            perf_metrics.speed_rating = '较慢';
        end
    end
    
    % 成功率
    if isfield(stats, 'success_grade')
        perf_metrics.success_quality = stats.success_grade;
    end
    
    % 内存使用
    if isfield(stats, 'memory_info')
        perf_metrics.memory_usage = stats.memory_info;
    end
    
    % 结果大小估计
    if ~isempty(results)
        result_size = whos('results');
        perf_metrics.result_size_mb = result_size.bytes / 1024 / 1024;
        
        if perf_metrics.result_size_mb < 1
            perf_metrics.size_rating = '很小';
        elseif perf_metrics.result_size_mb < 10
            perf_metrics.size_rating = '较小';
        elseif perf_metrics.result_size_mb < 100
            perf_metrics.size_rating = '中等';
        elseif perf_metrics.result_size_mb < 1000
            perf_metrics.size_rating = '较大';
        else
            perf_metrics.size_rating = '很大';
        end
        
        % 每个配对的大小
        if length(results) > 0
            sample_size = whos('results(1)');
            perf_metrics.size_per_pair_kb = sample_size.bytes / 1024;
        end
    end
    
    % 综合性能评分
    perf_metrics.overall_performance = assess_overall_performance(perf_metrics);
end

function mem_info = estimate_memory_usage(stats)
% 估计内存使用
    mem_info = struct();
    
    % 基于处理数量粗略估计
    if isfield(stats, 'processed_pairs')
        n_pairs = stats.processed_pairs;
        
        % 每个配对的估计大小（字节）
        bytes_per_pair = 5000;  % 估计值，可根据实际情况调整
        
        mem_info.estimated_memory_bytes = n_pairs * bytes_per_pair;
        mem_info.estimated_memory_mb = mem_info.estimated_memory_bytes / 1024 / 1024;
        mem_info.estimated_memory_gb = mem_info.estimated_memory_mb / 1024;
        
        if mem_info.estimated_memory_mb < 100
            mem_info.memory_rating = '低';
        elseif mem_info.estimated_memory_mb < 500
            mem_info.memory_rating = '中等';
        elseif mem_info.estimated_memory_mb < 2000
            mem_info.memory_rating = '高';
        else
            mem_info.memory_rating = '非常高';
        end
    end
end

function performance = assess_overall_performance(metrics)
% 评估整体性能
    performance = struct();
    
    % 初始化评分
    scores = struct('time', 0, 'efficiency', 0, 'success', 0, 'memory', 0);
    weights = struct('time', 0.3, 'efficiency', 0.3, 'success', 0.3, 'memory', 0.1);
    
    % 时间评分
    if isfield(metrics, 'total_time_seconds')
        if metrics.total_time_seconds < 60
            scores.time = 90;
        elseif metrics.total_time_seconds < 300
            scores.time = 70;
        elseif metrics.total_time_seconds < 1800
            scores.time = 50;
        else
            scores.time = 30;
        end
    end
    
    % 效率评分
    if isfield(metrics, 'processing_speed')
        if metrics.processing_speed > 5
            scores.efficiency = 95;
        elseif metrics.processing_speed > 1
            scores.efficiency = 80;
        elseif metrics.processing_speed > 0.1
            scores.efficiency = 60;
        else
            scores.efficiency = 40;
        end
    end
    
    % 成功率评分
    if isfield(metrics, 'success_quality')
        switch metrics.success_quality
            case '优秀'
                scores.success = 95;
            case '良好'
                scores.success = 80;
            case '一般'
                scores.success = 65;
            case '需改进'
                scores.success = 40;
        end
    end
    
    % 内存评分
    if isfield(metrics, 'memory_usage') && isfield(metrics.memory_usage, 'memory_rating')
        switch metrics.memory_usage.memory_rating
            case '低'
                scores.memory = 90;
            case '中等'
                scores.memory = 70;
            case '高'
                scores.memory = 50;
            case '非常高'
                scores.memory = 30;
        end
    end
    
    % 计算总分
    total_score = scores.time * weights.time + ...
                  scores.efficiency * weights.efficiency + ...
                  scores.success * weights.success + ...
                  scores.memory * weights.memory;
    
    performance.raw_scores = scores;
    performance.weights = weights;
    performance.total_score = total_score;
    
    % 性能等级
    if total_score >= 90
        performance.grade = '优秀';
        performance.color = 'green';
    elseif total_score >= 80
        performance.grade = '良好';
        performance.color = 'lightgreen';
    elseif total_score >= 70
        performance.grade = '满意';
        performance.color = 'yellow';
    elseif total_score >= 60
        performance.grade = '合格';
        performance.color = 'orange';
    else
        performance.grade = '需改进';
        performance.color = 'red';
    end
    
    performance.recommendations = generate_performance_recommendations(metrics, scores);
end

function recommendations = generate_performance_recommendations(metrics, scores)
% 生成性能改进建议
    recommendations = {};
    
    % 时间相关建议
    if isfield(scores, 'time') && scores.time < 70
        if isfield(metrics, 'total_time_seconds') && metrics.total_time_seconds > 300
            recommendations{end+1} = '分析时间较长，考虑启用并行计算或优化算法';
        end
    end
    
    % 效率相关建议
    if isfield(scores, 'efficiency') && scores.efficiency < 70
        if isfield(metrics, 'processing_speed') && metrics.processing_speed < 0.5
            recommendations{end+1} = '处理效率较低，考虑减少分析配对数或简化分析方法';
        end
    end
    
    % 成功率相关建议
    if isfield(scores, 'success') && scores.success < 70
        recommendations{end+1} = '分析成功率有待提高，建议检查数据质量和参数设置';
    end
    
    % 内存相关建议
    if isfield(scores, 'memory') && scores.memory < 60
        if isfield(metrics, 'memory_usage') && metrics.memory_usage.estimated_memory_mb > 1000
            recommendations{end+1} = '内存使用较高，考虑分批处理或优化数据存储';
        end
    end
    
    % 结果大小建议
    if isfield(metrics, 'result_size_mb') && metrics.result_size_mb > 500
        recommendations{end+1} = sprintf('结果文件较大(%.1f MB)，考虑使用稀疏存储或精简输出', metrics.result_size_mb);
    end
    
    if isempty(recommendations)
        recommendations{end+1} = '性能表现良好，继续保持当前配置';
    end
end

function report_text = generate_report_text(summary, params)
% 生成格式化的报告文本
    
    report_lines = {};
    
    % 报告头部
    report_lines{end+1} = '========================================';
    report_lines{end+1} = '   连通性分析报告';
    report_lines{end+1} = '========================================';
    report_lines{end+1} = '';
    
    % 1. 基本信息
    report_lines{end+1} = '1. 基本信息';
    report_lines{end+1} = '   - 分析时间: ' + string(summary.timestamp);
    report_lines{end+1} = '   - 系统版本: ' + string(summary.version);
    report_lines{end+1} = '   - 分析类型: ' + string(summary.analysis_parameters.analysis_type);
    report_lines{end+1} = '';
    
    % 2. 处理统计
    report_lines{end+1} = '2. 处理统计';
    if isfield(summary.processing_stats, 'original_stats')
        stats = summary.processing_stats.original_stats;
        report_lines{end+1} = sprintf('   - 总配对数量: %d', stats.total_pairs);
        report_lines{end+1} = sprintf('   - 成功分析: %d (%.1f%%)', stats.successful_pairs, stats.success_rate);
        report_lines{end+1} = sprintf('   - 跳过/失败: %d (%.1f%%)', stats.skipped_pairs, stats.skip_rate);
    end
    report_lines{end+1} = sprintf('   - 总处理时间: %.2f 秒', summary.performance_metrics.total_time_seconds);
    report_lines{end+1} = '';
    
    % 3. 数据质量
    report_lines{end+1} = '3. 数据质量摘要';
    if isfield(summary, 'quality_summary')
        qual = summary.quality_summary;
        report_lines{end+1} = sprintf('   - 通过检查: %d (%.1f%%)', qual.n_quality_passed, qual.pass_rate);
        report_lines{end+1} = sprintf('   - 未通过: %d (%.1f%%)', qual.n_quality_failed, qual.fail_rate);
        
        if isfield(qual, 'obs_stats')
            report_lines{end+1} = sprintf('   - 平均有效观测: %.0f', qual.obs_stats.mean);
        end
    end
    report_lines{end+1} = '';
    
    % 4. 显著性结果
    report_lines{end+1} = '4. 显著性统计';
    if isfield(summary, 'significance_summary')
        sig = summary.significance_summary;
        report_lines{end+1} = sprintf('   - 显著配对: %d/%d (%.1f%%)', ...
            sig.n_significant, sig.n_pairs, sig.percent_significant);
        
        if isfield(sig, 'p_value_stats')
            report_lines{end+1} = sprintf('   - 平均p值: %.4f', sig.p_value_stats.mean);
        end
        
        if isfield(sig, 'effect_size_stats')
            report_lines{end+1} = sprintf('   - 平均效应量: %.3f', sig.effect_size_stats.mean);
        end
    end
    report_lines{end+1} = '';
    
    % 5. 鲁棒性结果
    if isfield(params, 'enable_robustness_check') && params.enable_robustness_check
        report_lines{end+1} = '5. 鲁棒性统计';
        if isfield(summary, 'robustness_summary')
            robust = summary.robustness_summary;
            report_lines{end+1} = sprintf('   - 鲁棒配对: %d/%d (%.1f%%)', ...
                robust.n_robust, robust.n_pairs, robust.percent_robust);
            
            if isfield(robust, 'score_stats')
                report_lines{end+1} = sprintf('   - 平均鲁棒性评分: %.3f', robust.score_stats.mean);
            end
        end
        report_lines{end+1} = '';
    end
    
    % 6. 网络指标
    report_lines{end+1} = '6. 网络指标预览';
    if isfield(summary, 'network_metrics')
        net = summary.network_metrics;
        report_lines{end+1} = sprintf('   - 网络密度: %.3f (%s)', ...
            net.edge_density, net.density_assessment);
        report_lines{end+1} = sprintf('   - 显著边数: %d', net.n_significant_edges);
        
        if isfield(net, 'dominant_direction')
            report_lines{end+1} = sprintf('   - 主导方向: %s', net.dominant_direction);
        end
        
        if isfield(net, 'lag_stats')
            report_lines{end+1} = sprintf('   - 平均滞后: %.1f', net.lag_stats.mean);
        end
    end
    report_lines{end+1} = '';
    
    % 7. 性能评估
    report_lines{end+1} = '7. 性能评估';
    if isfield(summary.performance_metrics, 'overall_performance')
        perf = summary.performance_metrics.overall_performance;
        report_lines{end+1} = sprintf('   - 综合评分: %.1f/100 (%s)', ...
            perf.total_score, perf.grade);
        
        if isfield(summary.performance_metrics, 'processing_speed')
            report_lines{end+1} = sprintf('   - 处理速度: %.2f 配对/秒', ...
                summary.performance_metrics.processing_speed);
        end
    end
    report_lines{end+1} = '';
    
    % 报告尾部
    report_lines{end+1} = '========================================';
    report_lines{end+1} = '   报告结束';
    report_lines{end+1} = '========================================';
    
    % 转换为文本
    report_text = strjoin(report_lines, '\n');
end