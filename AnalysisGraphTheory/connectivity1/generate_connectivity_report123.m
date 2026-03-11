function report = generate_connectivity_report(pairwise_results, start_time, params)
% GENERATE_CONNECTIVITY_REPORT - 生成连通性分析报告
    
    %% 1. 计算基本统计
    total_pairs = length(pairwise_results);
    
    % 计算成功分析的数量
    success_count = 0;
    for i = 1:total_pairs
        if ~isempty(pairwise_results(i).connectivity)
            success_count = success_count + 1;
        end
    end
    
    % 计算显著性统计
    [significance_stats, correlation_stats, direction_stats] = calculate_basic_statistics(pairwise_results, params);
    
    %% 2. 计算性能指标
    total_time = toc(start_time);
    
    %% 3. 生成报告结构
    report = struct();
    
    % 分析概述
    report.analysis_overview = struct(...
        'total_pairs', total_pairs, ...
        'successful_analyses', success_count, ...
        'success_rate', success_count/total_pairs*100, ...
        'analysis_type', params.analysis_type, ...
        'significance_level', params.significance_level, ...
        'enable_nonlinear_test', params.enable_nonlinear_test, ...
        'enable_robustness_check', params.enable_robustness_check);
    
    % 显著性统计
    report.significance_statistics = significance_stats;
    
    % 相关性统计
    report.correlation_statistics = correlation_stats;
    
    % 因果关系方向统计
    report.direction_statistics = direction_stats;
    
    % 性能指标
    report.performance_metrics = struct(...
        'total_time', total_time, ...
        'time_per_pair', total_time/success_count, ...
        'timestamp', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    
    % 分析建议
    report.recommendations = generate_recommendations(report, params);
    
    %% 4. 显示报告
    if params.verbose
        display_report(report);
    end
end

%% 内部函数
function [significance_stats, correlation_stats, direction_stats] = calculate_basic_statistics(pairwise_results, params)
% 计算基本统计
    
    significance_stats = struct('significant_pairs', 0, 'significance_rate', 0);
    correlation_stats = struct('mean', 0, 'std', 0, 'min', 0, 'max', 0);
    direction_stats = struct('bidirectional', 0, 'x_to_y', 0, 'y_to_x', 0, 'none', 0);
    
    % 收集数据
    corr_values = [];
    sig_count = 0;
    
    for i = 1:length(pairwise_results)
        if isempty(pairwise_results(i).connectivity)
            continue;
        end
        
        % 相关性统计
        if isfield(pairwise_results(i).pair_info, 'correlation')
            corr_value = pairwise_results(i).pair_info.correlation;
            if ~isnan(corr_value)
                corr_values = [corr_values, corr_value];
            end
        end
        
        % 显著性统计
        if isfield(pairwise_results(i).significance, 'is_significant')
            if pairwise_results(i).significance.is_significant
                sig_count = sig_count + 1;
            end
        end
        
        % 方向统计
        if isfield(pairwise_results(i).connectivity, 'direction')
            direction = pairwise_results(i).connectivity.direction;
            switch direction
                case 'bidirectional'
                    direction_stats.bidirectional = direction_stats.bidirectional + 1;
                case 'x_to_y'
                    direction_stats.x_to_y = direction_stats.x_to_y + 1;
                case 'y_to_x'
                    direction_stats.y_to_x = direction_stats.y_to_x + 1;
                otherwise
                    direction_stats.none = direction_stats.none + 1;
            end
        end
    end
    
    % 计算汇总统计
    if ~isempty(corr_values)
        correlation_stats.mean = mean(corr_values);
        correlation_stats.std = std(corr_values);
        correlation_stats.min = min(corr_values);
        correlation_stats.max = max(corr_values);
    end
    
    if sig_count > 0
        significance_stats.significant_pairs = sig_count;
        significance_stats.significance_rate = sig_count / length(pairwise_results) * 100;
    end
end

function recommendations = generate_recommendations(report, params)
% 生成分析建议
    
    recommendations = {};
    
    % 基于显著性比例的建议
    sig_rate = report.significance_statistics.significance_rate;
    if sig_rate > 90
        recommendations{end+1} = sprintf('显著性比例非常高(%.1f%%)，可能需要调整显著性水平或进行多重比较校正。', sig_rate);
    elseif sig_rate < 10
        recommendations{end+1} = sprintf('显著性比例较低(%.1f%%)，考虑增加样本量或检查数据质量。', sig_rate);
    end
    
    % 基于相关系数的建议
    mean_corr = report.correlation_statistics.mean;
    if abs(mean_corr) < 0.1
        recommendations{end+1} = sprintf('平均相关系数较低(%.3f)，连接强度较弱。', mean_corr);
    end
    
    % 基于性能的建议
    if report.performance_metrics.time_per_pair > 5 && ~params.use_parallel
        recommendations{end+1} = '单对分析时间较长，建议启用并行计算。';
    end
    
    % 默认建议
    if isempty(recommendations)
        recommendations{end+1} = '分析结果良好，可考虑进行网络构建和进一步分析。';
    end
end

function display_report(report)
% 显示报告
    
    fprintf('\n========================================\n');
    fprintf('   连通性分析报告\n');
    fprintf('========================================\n\n');
    
    fprintf('分析概述:\n');
    fprintf('  - 总配对数量: %d\n', report.analysis_overview.total_pairs);
    fprintf('  - 成功分析: %d (%.1f%%)\n', ...
        report.analysis_overview.successful_analyses, ...
        report.analysis_overview.success_rate);
    fprintf('  - 分析类型: %s\n', report.analysis_overview.analysis_type);
    fprintf('  - 显著性水平: %.3f\n', report.analysis_overview.significance_level);
    
    fprintf('\n统计摘要:\n');
    fprintf('  - 显著配对: %d/%d (%.1f%%)\n', ...
        report.significance_statistics.significant_pairs, ...
        report.analysis_overview.total_pairs, ...
        report.significance_statistics.significance_rate);
    
    fprintf('  - 平均相关系数: %.3f (标准差: %.3f)\n', ...
        report.correlation_statistics.mean, ...
        report.correlation_statistics.std);
    
    if isfield(report, 'direction_statistics')
        total_directed = report.direction_statistics.bidirectional + ...
                        report.direction_statistics.x_to_y + ...
                        report.direction_statistics.y_to_x;
        if total_directed > 0
            fprintf('\n因果关系方向:\n');
            fprintf('  - 双向: %d (%.1f%%)\n', ...
                report.direction_statistics.bidirectional, ...
                report.direction_statistics.bidirectional/total_directed*100);
            fprintf('  - X→Y: %d (%.1f%%)\n', ...
                report.direction_statistics.x_to_y, ...
                report.direction_statistics.x_to_y/total_directed*100);
            fprintf('  - Y→X: %d (%.1f%%)\n', ...
                report.direction_statistics.y_to_x, ...
                report.direction_statistics.y_to_x/total_directed*100);
        end
    end
    
    fprintf('\n性能指标:\n');
    fprintf('  - 总时间: %.2f 秒\n', report.performance_metrics.total_time);
    fprintf('  - 平均每对: %.3f 秒\n', report.performance_metrics.time_per_pair);
    
    if ~isempty(report.recommendations)
        fprintf('\n分析建议:\n');
        for i = 1:length(report.recommendations)
            fprintf('  %d. %s\n', i, report.recommendations{i});
        end
    end
    
    fprintf('\n时间戳: %s\n', report.performance_metrics.timestamp);
    fprintf('\n');
end