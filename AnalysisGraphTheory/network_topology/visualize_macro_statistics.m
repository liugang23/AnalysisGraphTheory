function fig_handle = visualize_macro_statistics(analysis_results, pair_network, opts)
% VISUALIZE_MACRO_STATISTICS - 宏观统计与健康度画布
% 包含2-3个子图，展示网络整体特征
    
    % 根据图形质量设置窗口大小
    switch opts.FigureQuality
        case 'high'
            fig_position = [100, 100, 1400, 600];
        case 'medium'
            fig_position = [100, 100, 1200, 500];
        case 'low'
            fig_position = [100, 100, 1000, 400];
    end
    
    fig_handle = figure('Position', fig_position, ...
        'Name', '网络宏观统计', ...
        'NumberTitle', 'off', ...
        'Color', 'white');
    
    %% 子图1: 网络基本属性仪表盘
    subplot(1, 3, 1);
    plot_network_dashboard(analysis_results, opts.ShowTitles);
    
    %% 子图2: 度分布直方图
    subplot(1, 3, 2);
    plot_degree_distribution(analysis_results, opts.ShowTitles);
    
    %% 子图3: 连通性热力图 (可选，根据网络大小)
    subplot(1, 3, 3);
    plot_connectivity_heatmap(pair_network, opts.ShowTitles);
    
    % 添加主标题
    if opts.ShowTitles
        sgtitle('网络宏观统计与健康度分析', 'FontSize', 16, 'FontWeight', 'bold');
    end
end

function plot_network_dashboard(analysis_results, show_titles)
% PLOT_NETWORK_DASHBOARD - 绘制网络基本属性仪表盘
% 
% 功能：可视化网络的基本属性，包括节点数、边数、密度、平均度等
% 输入：
%   analysis_results: 网络分析结果结构体
%   show_titles: 是否显示标题

    % 检查数据可用性
    if ~isfield(analysis_results, 'basic') || ~analysis_results.basic.is_success
        text(0.5, 0.5, '基本属性数据不可用', 'HorizontalAlignment', 'center');
        return;
    end
    
    basic_data = analysis_results.basic;
    
    % 创建仪表盘布局
    hold on;
    
    % 1. 创建半圆形仪表盘背景
    theta = linspace(0, pi, 100);
    radius = 1;
    x_circle = radius * cos(theta);
    y_circle = radius * sin(theta);
    
    % 填充背景
    fill([x_circle, 0], [y_circle, 0], [0.95, 0.95, 0.95], ...
        'EdgeColor', [0.8, 0.8, 0.8], 'LineWidth', 1);
    
    % 2. 添加刻度
    n_ticks = 5;
    tick_angles = linspace(0, pi, n_ticks);
    tick_length = 0.1;
    
    for i = 1:n_ticks
        angle = tick_angles(i);
        
        % 主刻度
        plot([(radius-tick_length)*cos(angle), radius*cos(angle)], ...
             [(radius-tick_length)*sin(angle), radius*sin(angle)], ...
             'k-', 'LineWidth', 1.5);
        
        % 刻度标签
        if i > 1 && i < n_ticks
            text((radius+tick_length*2)*cos(angle), ...
                 (radius+tick_length*2)*sin(angle), ...
                 num2str((i-1)/(n_ticks-1)), ...
                 'HorizontalAlignment', 'center', ...
                 'FontSize', 9);
        end
    end
    
    % 3. 提取指标数据
    indicators = {};
    values = [];
    max_values = [];
    
    % 节点数
    if isfield(basic_data.network_size, 'n_nodes')
        n_nodes = basic_data.network_size.n_nodes;
        indicators{end+1} = '节点数';
        values(end+1) = n_nodes;
        max_values(end+1) = max(100, n_nodes * 1.5);
    end
    
    % 边数
    if isfield(basic_data.network_size, 'n_edges')
        n_edges = basic_data.network_size.n_edges;
        indicators{end+1} = '边数';
        values(end+1) = n_edges;
        max_values(end+1) = max(200, n_edges * 1.5);
    end
    
    % 网络密度
    if isfield(basic_data.density_analysis, 'density')
        density = basic_data.density_analysis.density;
        indicators{end+1} = '密度';
        values(end+1) = density;
        max_values(end+1) = 1.0;
    end
    
    % 最大可能边数
    if isfield(basic_data.network_size, 'max_possible_edges')
        max_edges = basic_data.network_size.max_possible_edges;
        indicators{end+1} = '最大边数';
        values(end+1) = max_edges;
        max_values(end+1) = max_edges;
    end
    
    n_indicators = length(indicators);
    
    % 4. 为每个指标绘制仪表盘
    for i = 1:n_indicators
        % 计算位置
        angle_spacing = pi / (n_indicators + 1);
        start_angle = angle_spacing;
        current_angle = start_angle + (i-1) * angle_spacing;
        
        % 计算指针角度
        normalized_value = values(i) / max_values(i);
        pointer_angle = normalized_value * pi;
        
        % 绘制指针
        pointer_length = radius * 0.7;
        plot([0, pointer_length*cos(current_angle)], ...
             [0, pointer_length*sin(current_angle)], ...
             'k-', 'LineWidth', 1, 'Color', [0.7, 0.7, 0.7]);
        
        % 绘制当前值指针
        plot([0, pointer_length*cos(pointer_angle)], ...
             [0, pointer_length*sin(pointer_angle)], ...
             'r-', 'LineWidth', 3, 'Color', [0.8, 0.2, 0.2]);
        
        % 添加指标标签
        label_x = (radius + 0.2) * cos(current_angle);
        label_y = (radius + 0.2) * sin(current_angle);
        
        text(label_x, label_y, indicators{i}, ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 10, 'FontWeight', 'bold');
        
        % 添加数值显示
        if strcmp(indicators{i}, '密度')
            value_str = sprintf('%.4f', values(i));
        else
            value_str = num2str(round(values(i)));
        end
        
        value_x = (radius + 0.1) * cos(current_angle);
        value_y = (radius + 0.1) * sin(current_angle) - 0.1;
        
        text(value_x, value_y, value_str, ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 9, 'FontWeight', 'bold', ...
            'BackgroundColor', [1, 1, 1, 0.7]);
    end
    
    % 5. 添加评估信息
    if isfield(basic_data, 'assessment')
        assessment_text = {};
        
        if isfield(basic_data.assessment, 'size_assessment')
            assessment_text{end+1} = basic_data.assessment.size_assessment;
        end
        
        if isfield(basic_data.assessment, 'density_assessment')
            assessment_text{end+1} = basic_data.assessment.density_assessment;
        end
        
        if ~isempty(assessment_text)
            text(0, -0.3, assessment_text, ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 9, 'BackgroundColor', [1, 1, 1, 0.8]);
        end
    end
    
    % 6. 设置图形属性
    axis equal;
    axis([-1.5, 1.5, -0.5, 1.5]);
    axis off;
    hold off;
    
    % 7. 添加标题
    if show_titles
        title('网络基本属性仪表盘', 'FontSize', 12, 'FontWeight', 'bold');
    end
end

function plot_degree_distribution(analysis_results, show_titles)
% PLOT_DEGREE_DISTRIBUTION - 绘制度分布直方图（修复版）
% 
% 功能：可视化节点度的分布情况，判断网络类型
% 修复内容：
% 1. 修复单精度（single）到双精度（double）的转换问题
% 2. 增强坐标轴范围的健壮性
% 3. 添加错误处理机制
% 输入：
%   analysis_results: 网络分析结果结构体
%   show_titles: 是否显示标题

    % 检查数据可用性
    if ~isfield(analysis_results, 'degree') || ~analysis_results.degree.is_success
        text(0.5, 0.5, '度分布数据不可用', 'HorizontalAlignment', 'center');
        return;
    end
    
    degree_data = analysis_results.degree;
    
    % 1. 获取度分布数据
    if isfield(degree_data, 'degree_distribution')
        % 使用已有的度分布数据
        counts = degree_data.degree_distribution.counts;
        centers = degree_data.degree_distribution.centers;
        
        % 确保centers是数值向量
        if iscell(centers)
            centers = cell2mat(centers);
        end
        
    elseif isfield(analysis_results, 'node_degrees')
        % 从原始度数据计算分布
        degrees = analysis_results.node_degrees;
        [counts, edges] = histcounts(degrees, 'BinMethod', 'auto');
        centers = (edges(1:end-1) + edges(2:end)) / 2;
        
    else
        text(0.5, 0.5, '无度分布数据', 'HorizontalAlignment', 'center');
        return;
    end
    
    % === 修复1：确保counts和centers是双精度 ===
    counts = ensure_double(counts);
    centers = ensure_double(centers);
    
    % 2. 绘制主直方图
    bar(centers, counts, 'FaceColor', [0.2, 0.4, 0.8], ...
        'EdgeColor', [0.1, 0.2, 0.6], 'FaceAlpha', 0.7, ...
        'BarWidth', 0.8);
    
    hold on;
    
    % 3. 添加统计信息
    if isfield(degree_data, 'degree_stats')
        stats = degree_data.degree_stats;
        
        % 绘制平均值线
        if isfield(stats, 'mean')
            % === 修复2：转换为双精度 ===
            mean_val = ensure_double(stats.mean);
            
            % === 修复3：安全获取坐标轴范围 ===
            y_limits = get_axis_limits();
            
            % === 修复4：验证坐标值有效性 ===
            if is_valid_coordinate(mean_val) && is_valid_coordinate(y_limits(2))
                % 绘制平均线
                plot([mean_val, mean_val], [0, y_limits(2)], ...
                    'r--', 'LineWidth', 2, 'Color', [0.8, 0.2, 0.2]);

                % 绘制平均文本
                try
                    text_y = ensure_double(y_limits(2)) * 0.95;
                    if is_valid_coordinate(text_y)
                        text(mean_val, text_y, ...
                            sprintf('平均: %.1f', mean_val), ...
                            'HorizontalAlignment', 'center', ...
                            'VerticalAlignment', 'top', ...
                            'FontSize', 9, 'FontWeight', 'bold', ...
                            'Color', [0.8, 0.2, 0.2], ...
                            'BackgroundColor', [1, 1, 1, 0.8]);
                    end
                catch ME
                    fprintf('绘制平均文本失败: %s\n', ME.message);
                end
            else
                fprintf('警告: 平均值坐标无效: mean_val=%.6f, y_limit=%.6f\n', ...
                    mean_val, y_limits(2));
            end
        end
        
        % 绘制中位数线
        if isfield(stats, 'median')
            % === 修复5：中位数也转换为双精度 ===
            median_val = ensure_double(stats.median);
            y_limits = get_axis_limits();
            
            if is_valid_coordinate(median_val) && is_valid_coordinate(y_limits(2))
                % 绘制中位数线
                plot([median_val, median_val], [0, y_limits(2)], ...
                    'g--', 'LineWidth', 2, 'Color', [0.2, 0.6, 0.2]);
                
                % 绘制中位数文本
                try
                    text_y = ensure_double(y_limits(2)) * 0.85;
                    if is_valid_coordinate(text_y)
                        text(median_val, text_y, ...
                            sprintf('中位: %.1f', median_val), ...
                            'HorizontalAlignment', 'center', ...
                            'VerticalAlignment', 'top', ...
                            'FontSize', 9, 'FontWeight', 'bold', ...
                            'Color', [0.2, 0.6, 0.2], ...
                            'BackgroundColor', [1, 1, 1, 0.8]);
                    end
                catch ME
                    fprintf('绘制中位数文本失败: %s\n', ME.message);
                end
            end
        end
    end
    
    % 4. 检查是否具有幂律特征
    if isfield(degree_data, 'degree_heterogeneity')
        heterogeneity = ensure_double(degree_data.degree_heterogeneity);
        
        if heterogeneity > 1.5
            % 可能具有无标度特征，添加对数坐标曲线
            try
                % 过滤零值
                non_zero_idx = counts > 0;
                if sum(non_zero_idx) >= 3
                    log_counts = log(counts(non_zero_idx));
                    log_centers = log(centers(non_zero_idx));
                    
                    % 确保转换后的值是双精度
                    log_counts = ensure_double(log_counts);
                    log_centers = ensure_double(log_centers);
                    
                    % 拟合线性回归
                    valid_idx = isfinite(log_counts) & isfinite(log_centers);
                    if sum(valid_idx) >= 2
                        p = polyfit(log_centers(valid_idx), log_counts(valid_idx), 1);
                        
                        % 绘制拟合线
                        x_fit = linspace(min(log_centers(valid_idx)), max(log_centers(valid_idx)), 100);
                        y_fit = polyval(p, x_fit);
                        
                        plot(exp(x_fit), exp(y_fit), 'r-', 'LineWidth', 2, ...
                            'Color', [0.8, 0.2, 0.2]);
                        
                        % 显示拟合信息
                        slope = ensure_double(p(1));
                        text(0.05, 0.95, sprintf('斜率: %.2f', slope), ...
                            'Units', 'normalized', ...
                            'HorizontalAlignment', 'left', ...
                            'VerticalAlignment', 'top', ...
                            'FontSize', 9, ...
                            'BackgroundColor', [1, 1, 1, 0.8]);
                    end
                end
            catch ME
                fprintf('幂律拟合失败: %s\n', ME.message);
            end
        end
    end
    
    % 5. 设置坐标轴属性
    xlabel('节点度', 'FontSize', 10, 'FontWeight', 'bold');
    ylabel('频数', 'FontSize', 10, 'FontWeight', 'bold');
    grid on;
    box on;
    
    % 设置美观的网格
    grid on;
    grid minor;
    set(gca, 'GridAlpha', 0.3, 'MinorGridAlpha', 0.1);
    
    % 6. 添加评估信息
    if isfield(degree_data, 'assessment')
        assessment_text = {};
        
        if isfield(degree_data.assessment, 'degree_distribution_type')
            assessment_text{end+1} = degree_data.assessment.degree_distribution_type;
        end
        
        if isfield(degree_data, 'heterogeneity_assessment')
            assessment_text{end+1} = degree_data.heterogeneity_assessment;
        end
        
        if ~isempty(assessment_text)
            text(0.05, 0.05, assessment_text, ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 9, 'BackgroundColor', [1, 1, 1, 0.8]);
        end
    end
    
    % 7. 添加统计摘要
    if isfield(degree_data, 'degree_stats')
        stats = degree_data.degree_stats;
        
        summary_text = {};
        if isfield(stats, 'mean')
            summary_text{end+1} = sprintf('平均度: %.2f', ensure_double(stats.mean));
        end
        if isfield(stats, 'std')
            summary_text{end+1} = sprintf('标准差: %.2f', ensure_double(stats.std));
        end
        if isfield(stats, 'max')
            summary_text{end+1} = sprintf('最大度: %d', ensure_double(stats.max));
        end
        if isfield(degree_data, 'degree_heterogeneity')
            summary_text{end+1} = sprintf('异质性: %.2f', ...
                ensure_double(degree_data.degree_heterogeneity));
        end
        
        if ~isempty(summary_text)
            annotation('textbox', [0.7, 0.7, 0.25, 0.2], ...
                'String', summary_text, 'FontSize', 9, ...
                'BackgroundColor', [1, 1, 1, 0.8], ...
                'EdgeColor', [0.8, 0.8, 0.8]);
        end
    end
    
    hold off;
    
    % 8. 添加标题
    if show_titles
        title('节点度分布', 'FontSize', 12, 'FontWeight', 'bold');
    end
end

%% === 辅助函数：确保双精度 ===
function double_val = ensure_double(value)
% ENSURE_DOUBLE - 确保输出是双精度
% 处理单精度、整数、逻辑等各种类型
    
    if isempty(value)
        double_val = NaN;
        return;
    end
    
    if ~isnumeric(value) && ~islogical(value)
        % 对于非数值，尝试转换
        try
            double_val = double(value);
        catch
            double_val = NaN;
        end
        return;
    end
    
    % 转换为双精度
    double_val = double(value);
end

%% === 辅助函数：安全获取坐标轴范围 ===
function limits = get_axis_limits()
% GET_AXIS_LIMITS - 安全获取坐标轴范围
    
    limits = ylim;
    
    % 检查返回的范围
    if isempty(limits) || length(limits) < 2
        limits = [0, 1];
    end
    
    % 转换为双精度
    limits = ensure_double(limits);
    
    % 处理无效值
    if any(isnan(limits))
        limits = [0, 1];
    end
    
    if any(isinf(limits))
        limits = [0, 1];
    end
end

%% === 辅助函数：验证坐标有效性 ===
function valid = is_valid_coordinate(value)
% IS_VALID_COORDINATE - 验证坐标值是否有效
    
    valid = true;
    
    if isempty(value)
        valid = false;
        return;
    end
    
    if ~isnumeric(value)
        valid = false;
        return;
    end
    
    if isnan(value) || isinf(value)
        valid = false;
        return;
    end
    
    % 检查是否为标量
    if ~isscalar(value)
        valid = false;
    end
end

function plot_connectivity_heatmap(pair_network, show_titles)
% PLOT_CONNECTIVITY_HEATMAP - 绘制连通性热力图
% 
% 功能：可视化网络的连接矩阵，显示节点间的连接强度
% 输入：
%   pair_network: 网络结构体
%   show_titles: 是否显示标题

    % 检查数据可用性
    if ~isfield(pair_network, 'adjacency')
        text(0.5, 0.5, '邻接矩阵数据不可用', 'HorizontalAlignment', 'center');
        return;
    end
    
    adjacency = pair_network.adjacency;
    n_nodes = size(adjacency, 1);
    
    % 限制显示节点数（避免过大热力图）
    max_nodes_to_show = 50;
    if n_nodes > max_nodes_to_show
        % 提示用户网络过大
        text(0.5, 0.5, sprintf('网络过大(%d节点)，不显示热力图', n_nodes), ...
            'HorizontalAlignment', 'center', 'FontSize', 10);
        return;
    end
    
    % 1. 处理邻接矩阵
    % 如果是无向图，只显示上三角
    if isfield(pair_network, 'graph_type') && strcmp(pair_network.graph_type, 'undirected')
        adjacency_display = triu(adjacency);
    else
        adjacency_display = adjacency;
    end
    
    % 2. 绘制热力图
    imagesc(adjacency_display);
    
    % 3. 设置颜色映射
    colormap(jet);
    colorbar;
    
    % 设置对称的颜色范围
    if any(adjacency_display(:) < 0)
        % 有正值和负值
        max_abs = max(abs(adjacency_display(:)));
        caxis([-max_abs, max_abs]);
    else
        % 只有非负值
        caxis([0, max(adjacency_display(:))]);
    end
    
    % 4. 添加节点标签
    if isfield(pair_network, 'node_labels') && n_nodes <= 30
        % 显示所有节点标签
        xticks(1:n_nodes);
        yticks(1:n_nodes);
        
        labels = pair_network.node_labels;
        if length(labels) == n_nodes
            xticklabels(labels);
            yticklabels(labels);
            
            % 旋转x轴标签避免重叠
            xtickangle(45);
            
            % 设置标签字体大小
            set(gca, 'FontSize', 8);
        end
    else
        % 网络太大，不显示所有标签
        xticks([]);
        yticks([]);
        
        % 在角落显示节点数
        text(0.02, 0.98, sprintf('%d节点', n_nodes), ...
            'Units', 'normalized', ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'top', ...
            'FontSize', 9, 'BackgroundColor', [1, 1, 1, 0.8]);
    end
    
    % 5. 添加连接强度统计
    if n_nodes <= 20
        % 在热力图上显示数值
        for i = 1:n_nodes
            for j = 1:n_nodes
                value = adjacency_display(i, j);
                if value ~= 0
                    text(j, i, sprintf('%.2f', value), ...
                        'HorizontalAlignment', 'center', ...
                        'VerticalAlignment', 'middle', ...
                        'FontSize', 7, 'FontWeight', 'bold', ...
                        'Color', 'white');
                end
            end
        end
    end
    
    % 6. 添加对称性指示
    if isfield(pair_network, 'graph_type')
        if strcmp(pair_network.graph_type, 'undirected')
            symmetry_text = '对称矩阵 (无向图)';
        else
            symmetry_text = '非对称矩阵 (有向图)';
        end
        
        text(0.02, 0.02, symmetry_text, ...
            'Units', 'normalized', ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'bottom', ...
            'FontSize', 9, 'BackgroundColor', [1, 1, 1, 0.8]);
    end
    
    % 7. 添加连接统计
    n_edges = sum(adjacency(:) ~= 0);
    density = n_edges / (n_nodes * n_nodes);
    
    if isfield(pair_network, 'graph_type') && strcmp(pair_network.graph_type, 'undirected')
        density = density * 2;  % 无向图对称
    end
    
    stats_text = {sprintf('边数: %d', n_edges), ...
                  sprintf('密度: %.4f', density)};
    
    annotation('textbox', [0.7, 0.02, 0.25, 0.1], ...
        'String', stats_text, 'FontSize', 9, ...
        'BackgroundColor', [1, 1, 1, 0.8], ...
        'EdgeColor', [0.8, 0.8, 0.8]);
    
    % 8. 美化坐标轴
    axis square;
    box on;
    grid off;
    
    % 设置坐标轴方向
    set(gca, 'YDir', 'normal');
    
    % 9. 添加标题
    if show_titles
        title('连接矩阵热力图', 'FontSize', 12, 'FontWeight', 'bold');

        % 10. 添加图类型说明
        if isfield(pair_network, 'analysis_type')
            % 先定义 subtitle_text 变量
            subtitle_text = sprintf('分析类型: %s', pair_network.analysis_type);
            % 再使用 text 函数添加副标题
            text(0.5, 1.02, subtitle_text, ...
                 'Units', 'normalized', ...
                 'HorizontalAlignment', 'center', ...
                 'FontSize', 10);
        end
    end
end
