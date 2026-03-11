function fig_handle = visualize_dynamic_robustness(analysis_results, pair_network, opts)
% VISUALIZE_DYNAMIC_ROBUSTNESS - 动态演化与鲁棒性画布
% 包含1-2个子图，展示鲁棒性和路径特征
    
    % 设置窗口大小
    switch opts.FigureQuality
        case 'high'
            fig_position = [100, 100, 1200, 500];
        case 'medium'
            fig_position = [100, 100, 1000, 400];
        case 'low'
            fig_position = [100, 100, 800, 300];
    end
    
    fig_handle = figure('Position', fig_position, ...
        'Name', '网络动态特性', ...
        'NumberTitle', 'off', ...
        'Color', 'white');
    
    % 1×2布局
    %% 子图1: 鲁棒性攻击曲线
    subplot(1, 2, 1);
    plot_robustness_curves(analysis_results, opts.ShowTitles);
    
    %% 子图2: 路径长度分布图
    subplot(1, 2, 2);
    plot_path_length_distribution(analysis_results, opts.ShowTitles);
    
    % 添加主标题
    if opts.ShowTitles
        sgtitle('网络动态演化与鲁棒性分析', 'FontSize', 16, 'FontWeight', 'bold');
    end
end

function plot_robustness_curves(analysis_results, pair_network, show_titles)
% PLOT_ROBUSTNESS_CURVES - 绘制鲁棒性攻击曲线
% 
% 功能：可视化网络在随机攻击和针对性攻击下的鲁棒性表现
% 输入：
%   analysis_results: 网络分析结果结构体
%   pair_network: 网络结构体
%   show_titles: 是否显示标题

    % 检查数据可用性
    if ~isfield(analysis_results, 'robustness') || ~analysis_results.robustness.is_success
        text(0.5, 0.5, '鲁棒性数据不可用', 'HorizontalAlignment', 'center');
        return;
    end
    
    robustness_data = analysis_results.robustness;
    
    % 1. 提取攻击曲线数据
    attack_data = {};
    attack_labels = {};
    attack_colors = [];
    
    % 检查随机攻击数据
    if isfield(robustness_data, 'random_attack')
        if isfield(robustness_data.random_attack, 'efficiency_mean')
            attack_data{end+1} = robustness_data.random_attack.efficiency_mean;
            attack_labels{end+1} = '随机攻击';
            attack_colors(end+1, :) = [0.2, 0.4, 0.8];  % 蓝色
        end
    end
    
    % 检查针对性攻击数据
    if isfield(robustness_data, 'targeted_attack')
        if isfield(robustness_data.targeted_attack, 'efficiency_mean')
            attack_data{end+1} = robustness_data.targeted_attack.efficiency_mean;
            attack_labels{end+1} = '针对性攻击';
            attack_colors(end+1, :) = [0.8, 0.2, 0.2];  % 红色
        end
    end
    
    if isempty(attack_data)
        text(0.5, 0.5, '无攻击曲线数据', 'HorizontalAlignment', 'center');
        return;
    end
    
    % 2. 创建X轴（攻击比例）
    n_points = length(attack_data{1});
    attack_proportions = linspace(0, 1, n_points) * 100;  % 转换为百分比
    
    % 3. 绘制攻击曲线
    hold on;
    for i = 1:length(attack_data)
        plot(attack_proportions, attack_data{i}, ...
            'Color', attack_colors(i, :), ...
            'LineWidth', 2.5, ...
            'Marker', 'o', ...
            'MarkerSize', 6, ...
            'MarkerFaceColor', attack_colors(i, :), ...
            'DisplayName', attack_labels{i});
        
        % 添加误差带（如果有标准差数据）
        if i == 1 && isfield(robustness_data.random_attack, 'efficiency_std')
            if ~isempty(robustness_data.random_attack.efficiency_std)
                efficiency_std = robustness_data.random_attack.efficiency_std;
                upper_bound = attack_data{i} + efficiency_std;
                lower_bound = max(attack_data{i} - efficiency_std, 0);
                
                fill([attack_proportions, fliplr(attack_proportions)], ...
                     [upper_bound, fliplr(lower_bound)], ...
                     attack_colors(i, :), 'FaceAlpha', 0.2, 'EdgeColor', 'none');
            end
        end
    end
    
    % 4. 设置坐标轴属性
    xlabel('攻击比例 (%)', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('网络效率', 'FontSize', 11, 'FontWeight', 'bold');
    
    xlim([0, 100]);
    ylim([0, 1.1]);
    
    grid on;
    grid minor;
    set(gca, 'GridAlpha', 0.3, 'MinorGridAlpha', 0.1);
    box on;
    
    % 5. 添加50%效率参考线
    plot([0, 100], [0.5, 0.5], 'k--', 'LineWidth', 1, ...
        'Color', [0.5, 0.5, 0.5], 'DisplayName', '50%效率阈值');
    
    % 6. 添加图例
    legend('Location', 'best', 'FontSize', 9, 'Box', 'off');
    
    % 7. 添加鲁棒性评估
    if isfield(robustness_data, 'robustness_assessment')
        assessment = robustness_data.robustness_assessment;
        
        assessment_text = {};
        if isfield(assessment, 'random_attack_robustness')
            assessment_text{end+1} = sprintf('随机攻击: %s', assessment.random_attack_robustness);
        end
        if isfield(assessment, 'targeted_attack_robustness')
            assessment_text{end+1} = sprintf('针对性攻击: %s', assessment.targeted_attack_robustness);
        end
        if isfield(assessment, 'overall_robustness')
            assessment_text{end+1} = sprintf('综合评估: %s', assessment.overall_robustness);
        end
        
        if ~isempty(assessment_text)
            text(0.05, 0.05, assessment_text, ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 9, 'BackgroundColor', [1, 1, 1, 0.8]);
        end
    end
    
    % 8. 计算并显示关键指标
    if length(attack_data) >= 2
        % 计算随机攻击和针对性攻击的差异
        random_curve = attack_data{1};
        targeted_curve = attack_data{2};
        
        % 计算曲线下面积 (AUC)
        auc_random = trapz(attack_proportions, random_curve) / 100;
        auc_targeted = trapz(attack_proportions, targeted_curve) / 100;
        
        % 计算临界攻击比例（效率降到50%时）
        [~, random_critical_idx] = min(abs(random_curve - 0.5));
        [~, targeted_critical_idx] = min(abs(targeted_curve - 0.5));
        
        random_critical = attack_proportions(random_critical_idx);
        targeted_critical = attack_proportions(targeted_critical_idx);
        
        % 显示关键指标
        metrics_text = {sprintf('AUC(随机): %.3f', auc_random), ...
                       sprintf('AUC(针对性): %.3f', auc_targeted), ...
                       sprintf('临界点(随机): %.1f%%', random_critical), ...
                       sprintf('临界点(针对性): %.1f%%', targeted_critical)};
        
        annotation('textbox', [0.6, 0.7, 0.35, 0.2], ...
            'String', metrics_text, 'FontSize', 9, ...
            'BackgroundColor', [1, 1, 1, 0.8], ...
            'EdgeColor', [0.8, 0.8, 0.8]);
    end
    
    hold off;
    
    % 9. 添加标题
    if show_titles
        title('网络鲁棒性攻击曲线', 'FontSize', 12, 'FontWeight', 'bold');
    end
end

function plot_path_length_distribution(analysis_results, show_titles)
% PLOT_PATH_LENGTH_DISTRIBUTION - 绘制路径长度分布图
% 
% 功能：可视化网络中最短路径长度的分布情况
% 输入：
%   analysis_results: 网络分析结果结构体
%   show_titles: 是否显示标题

    % 检查数据可用性
    if ~isfield(analysis_results, 'path') || ~analysis_results.path.is_success
        text(0.5, 0.5, '路径分析数据不可用', 'HorizontalAlignment', 'center');
        return;
    end
    
    path_data = analysis_results.path;
    
    % 1. 获取路径长度数据
    if isfield(path_data.path_statistics, 'path_length_distribution')
        % 使用已有的分布数据
        counts = path_data.path_statistics.path_length_distribution.counts;
        centers = path_data.path_statistics.path_length_distribution.centers;
        
    elseif isfield(path_data, 'distance_matrix')
        % 从距离矩阵计算路径长度
        distance_matrix = path_data.distance_matrix;
        finite_distances = distance_matrix(isfinite(distance_matrix) & distance_matrix > 0);
        
        if isempty(finite_distances)
            text(0.5, 0.5, '无有效路径长度数据', 'HorizontalAlignment', 'center');
            return;
        end
        
        [counts, edges] = histcounts(finite_distances, 'BinMethod', 'auto');
        centers = (edges(1:end-1) + edges(2:end)) / 2;
        
    else
        text(0.5, 0.5, '无路径长度数据', 'HorizontalAlignment', 'center');
        return;
    end
    
    % 2. 绘制路径长度分布直方图
    bar(centers, counts, 'FaceColor', [0.4, 0.6, 0.2], ...
        'EdgeColor', [0.3, 0.4, 0.1], 'FaceAlpha', 0.7, ...
        'BarWidth', 0.8);
    
    hold on;
    
    % 3. 添加统计参考线
    if isfield(path_data.path_statistics, 'average_path_length')
        avg_length = path_data.path_statistics.average_path_length;
        y_limits = ylim;
        
        % 平均路径长度线
        plot([avg_length, avg_length], [0, y_limits(2)], ...
            'r--', 'LineWidth', 2.5, 'Color', [0.8, 0.2, 0.2]);
        
        text(avg_length, y_limits(2)*0.95, ...
            sprintf('平均: %.2f', avg_length), ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'top', ...
            'FontSize', 10, 'FontWeight', 'bold', ...
            'Color', [0.8, 0.2, 0.2], ...
            'BackgroundColor', [1, 1, 1, 0.8]);
    end
    
    if isfield(path_data.diameter_analysis, 'diameter')
        diameter = path_data.diameter_analysis.diameter;
        y_limits = ylim;
        
        % 网络直径线
        plot([diameter, diameter], [0, y_limits(2)], ...
            'g--', 'LineWidth', 2.5, 'Color', [0.2, 0.6, 0.2]);
        
        text(diameter, y_limits(2)*0.85, ...
            sprintf('直径: %.1f', diameter), ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'top', ...
            'FontSize', 10, 'FontWeight', 'bold', ...
            'Color', [0.2, 0.6, 0.2], ...
            'BackgroundColor', [1, 1, 1, 0.8]);
    end
    
    % 4. 设置坐标轴属性
    xlabel('最短路径长度', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('频数', 'FontSize', 11, 'FontWeight', 'bold');
    
    grid on;
    grid minor;
    set(gca, 'GridAlpha', 0.3, 'MinorGridAlpha', 0.1);
    box on;
    
    % 5. 添加路径分析评估
    if isfield(path_data, 'path_assessment')
        assessment_text = {};
        
        if isfield(path_data.path_assessment, 'path_length_assessment')
            assessment_text{end+1} = path_data.path_assessment.path_length_assessment;
        end
        
        if isfield(path_data.path_assessment, 'efficiency_assessment')
            assessment_text{end+1} = path_data.path_assessment.efficiency_assessment;
        end
        
        if ~isempty(assessment_text)
            text(0.05, 0.05, assessment_text, ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 9, 'BackgroundColor', [1, 1, 1, 0.8]);
        end
    end
    
    % 6. 添加统计摘要
    if isfield(path_data.path_statistics, 'average_path_length')
        stats = path_data.path_statistics;
        
        summary_text = {};
        if isfield(stats, 'average_path_length')
            summary_text{end+1} = sprintf('平均路径: %.3f', stats.average_path_length);
        end
        if isfield(stats, 'path_length_std')
            summary_text{end+1} = sprintf('标准差: %.3f', stats.path_length_std);
        end
        if isfield(stats, 'path_length_median')
            summary_text{end+1} = sprintf('中位数: %.2f', stats.path_length_median);
        end
        if isfield(stats, 'path_length_max')
            summary_text{end+1} = sprintf('最大值: %.1f', stats.path_length_max);
        end
        
        if ~isempty(summary_text)
            annotation('textbox', [0.7, 0.7, 0.25, 0.2], ...
                'String', summary_text, 'FontSize', 9, ...
                'BackgroundColor', [1, 1, 1, 0.8], ...
                'EdgeColor', [0.8, 0.8, 0.8]);
        end
    end
    
    % 7. 检查小世界特性
    if isfield(path_data, 'efficiency_analysis')
        if isfield(path_data.efficiency_analysis, 'global_efficiency')
            efficiency = path_data.efficiency_analysis.global_efficiency;
            
            % 在图中显示网络效率
            text(0.95, 0.95, sprintf('效率: %.3f', efficiency), ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'top', ...
                'FontSize', 10, 'FontWeight', 'bold', ...
                'BackgroundColor', [1, 1, 1, 0.8]);
        end
    end
    
    hold off;
    
    % 8. 添加标题
    if show_titles
        title('最短路径长度分布', 'FontSize', 12, 'FontWeight', 'bold');
    end
end
