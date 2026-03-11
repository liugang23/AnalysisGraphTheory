function fig_handle = visualize_micro_structure(analysis_results, pair_network, opts)
% VISUALIZE_MICRO_STRUCTURE - 微观结构与拓扑画布
% 包含4个子图，展示节点、社区、聚类、关键节点特征
    
    % 设置窗口大小
    switch opts.FigureQuality
        case 'high'
            fig_position = [100, 100, 1600, 1200];
        case 'medium'
            fig_position = [100, 100, 1400, 1000];
        case 'low'
            fig_position = [100, 100, 1200, 800];
    end
    
    fig_handle = figure('Position', fig_position, ...
        'Name', '网络微观结构', ...
        'NumberTitle', 'off', ...
        'Color', 'white');
    
    % === 关键修改：显式创建坐标轴句柄 ===
    ax(1) = subplot(2, 2, 1);
    ax(2) = subplot(2, 2, 2);
    ax(3) = subplot(2, 2, 3);
    ax(4) = subplot(2, 2, 4);
    
    % 2×2布局
    %% 子图1: 中心性排名条形图
    plot_centrality_ranking(ax(1), analysis_results, pair_network, opts.ShowTitles);
    
    %% 子图2: 社区结构网络图
    plot_community_network(ax(2), analysis_results, pair_network, opts.ShowTitles);
    
    %% 子图3: 聚类系数分布图
    plot_clustering_distribution(ax(3), analysis_results, opts.ShowTitles);
    
    %% 子图4: 关键节点识别图
    plot_key_nodes_identification(ax(4), analysis_results, pair_network, opts.ShowTitles);
    
    % 添加主标题
    if opts.ShowTitles
        sgtitle('网络微观结构与拓扑分析', 'FontSize', 16, 'FontWeight', 'bold');
    end
end

function plot_centrality_ranking(ax, analysis_results, pair_network, show_titles)
% PLOT_CENTRALITY_RANKING - 绘制中心性排名条形图
% 
% 功能：可视化Top K节点的中心性排名
% 输入：
%   analysis_results: 网络分析结果结构体
%   pair_network: 网络结构体
%   show_titles: 是否显示标题

    % === 强制激活指定坐标轴 ===
    axes(ax);
    hold(ax, 'on'); % 确保后续绘图叠加
    
    % 检查数据可用性
    if ~isfield(analysis_results, 'centrality') || ~analysis_results.centrality.is_success
        text(0.5, 0.5, '中心性数据不可用', 'HorizontalAlignment', 'center');
        return;
    end
    
    centrality_data = analysis_results.centrality;
    
    % 1. 获取Top K节点（默认Top 10）
    top_k = 10;
    node_labels = pair_network.node_labels;
    
    % 提取度中心性数据
    if isfield(centrality_data.degree_centrality, 'values')
        degree_values = centrality_data.degree_centrality.values;
    elseif isfield(centrality_data, 'degree_centrality')
        degree_values = centrality_data.degree_centrality;
    else
        text(0.5, 0.5, '无度中心性数据', 'HorizontalAlignment', 'center');
        return;
    end
    
    % 2. 对节点按度中心性排序
    [sorted_degrees, sort_idx] = sort(degree_values, 'descend');
    n_nodes = length(degree_values);
    display_k = min(top_k, n_nodes);
    
    % 3. 创建条形图
    bar_handle = barh(1:display_k, sorted_degrees(1:display_k), ...
        'FaceColor', [0.2, 0.4, 0.8], ...
        'EdgeColor', [0.1, 0.2, 0.6], ...
        'FaceAlpha', 0.7);
    
    % 4. 添加节点标签
    yticklabels_array = cell(display_k, 1);
    for i = 1:display_k
        node_idx = sort_idx(i);
        if length(node_labels) >= node_idx
            yticklabels_array{i} = node_labels{node_idx};
        else
            yticklabels_array{i} = sprintf('节点%d', node_idx);
        end
    end
    
    set(gca, 'YTick', 1:display_k, 'YTickLabel', yticklabels_array);
    
    % 5. 设置坐标轴属性
    xlabel('度中心性', 'FontSize', 10, 'FontWeight', 'bold');
    ylabel('节点', 'FontSize', 10, 'FontWeight', 'bold');
    
    grid on;
    set(gca, 'GridAlpha', 0.3);
    box on;
    
    % 6. 在条形末端添加数值
    for i = 1:display_k
        text(sorted_degrees(i), i, ...
            sprintf(' %.2f', sorted_degrees(i)), ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'middle', ...
            'FontSize', 8, 'FontWeight', 'bold');
    end
    
    % 7. 添加统计信息
    if isfield(centrality_data.degree_centrality, 'stats')
        stats = centrality_data.degree_centrality.stats;
        
        summary_text = {};
        if isfield(stats, 'mean')
            summary_text{end+1} = sprintf('平均值: %.3f', stats.mean);
        end
        if isfield(stats, 'max')
            summary_text{end+1} = sprintf('最大值: %.3f', stats.max);
        end
        if isfield(stats, 'min')
            summary_text{end+1} = sprintf('最小值: %.3f', stats.min);
        end
        
        if ~isempty(summary_text)
            text(0.7, 0.05, summary_text, ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 9, 'BackgroundColor', [1, 1, 1, 0.8]);
        end
    end
    
    % 8. 添加标题
    if show_titles
        title('度中心性排名 (Top 10)', 'FontSize', 12, 'FontWeight', 'bold');
    end
    hold(ax, 'off'); % 绘图结束，关闭叠加
end

function plot_community_network(ax, analysis_results, pair_network, show_titles)
% PLOT_COMMUNITY_NETWORK - 绘制社区结构网络图
% 
% 功能：可视化网络的社区划分结果
% 输入：
%   ax: 目标坐标轴句柄
%   analysis_results: 网络分析结果结构体
%   pair_network: 网络结构体
%   show_titles: 是否显示标题

    % === 关键修复：激活指定坐标轴 ===
    axes(ax);
    hold(ax, 'on');
    
    % 检查数据可用性
    if ~isfield(analysis_results, 'community') || ~analysis_results.community.is_success
        text(0.5, 0.5, '社区结构数据不可用', 'HorizontalAlignment', 'center');
        return;
    end
    
    community_data = analysis_results.community;
    
    % 1. 获取社区分配
    if isfield(community_data.community_detection, 'community_assignments')
        communities = community_data.community_detection.community_assignments;
    else
        text(0.5, 0.5, '无社区分配数据', 'HorizontalAlignment', 'center');
        return;
    end
    
    % 2. 创建图对象
    adjacency = pair_network.adjacency;
    % === 关键修复：强制转换为 double 类型 ===
    adjacency = double(adjacency);
    % === 再次检查：确保转换后数据正常 ===
    if isempty(adjacency) || all(adjacency(:) == 0)
        text(0.5, 0.5, '邻接矩阵为空或全零', 'HorizontalAlignment', 'center');
        hold(ax, 'off');
        return;
    end
    if strcmp(pair_network.graph_type, 'undirected')
        G = graph(adjacency, 'upper');
    else
        G = digraph(adjacency);
    end
    
    % 3. 计算力导向布局
    try
        % 方法1：尝试使用plot获取布局
        fig_temp = figure('Visible', 'off');
        h = plot(G, 'Layout', 'force');
        layout_coords = [h.XData' h.YData'];
        close(fig_temp);
        
    catch ME
        fprintf('   计算力导向布局 失败: %s\n', ME.message);
        % 方法2：如果plot方法失败，使用内置布局
        try
            % 尝试'force'布局
            layout_coords = layout_force(G, 200);
        catch ME
            fprintf('   计算力导向布局 2 失败: %s\n', ME.message);
            % 方法3：使用简单的圆形或随机布局
            layout_coords = layout_simple(G);
        end
    end
    
    try
        % 4. 为不同社区分配颜色
        n_communities = max(communities);
        community_colors = hsv(n_communities);

        node_colors = zeros(length(communities), 3);
        for i = 1:length(communities)
            if communities(i) > 0 && communities(i) <= n_communities
                node_colors(i, :) = community_colors(communities(i), :);
            else
                node_colors(i, :) = [0.5, 0.5, 0.5];  % 灰色表示未分配社区
            end
        end
    catch ME
        fprintf('   为不同社区分配颜色失败: %s\n', ME.message);
        node_colors = repmat([0.7, 0.7, 0.7], length(communities), 1);
    end
    
    % 5. 绘制网络
    % 绘制边
    if ~isempty(G.Edges)
        for i = 1:height(G.Edges)
            source_idx = G.Edges.EndNodes(i, 1);
            target_idx = G.Edges.EndNodes(i, 2);
            
            x_points = [layout_coords(source_idx, 1), layout_coords(target_idx, 1)];
            y_points = [layout_coords(source_idx, 2), layout_coords(target_idx, 2)];
            
            plot(x_points, y_points, 'Color', [0.7, 0.7, 0.7], ...
                'LineWidth', 0.5, 'HandleVisibility', 'off');
        end
    end
    
    % === 修复：计算节点大小 ===
    if isa(G, 'digraph')
        % 有向图：使用出度
        try
            node_degrees = outdegree(G);
        catch
            node_degrees = ones(numnodes(G), 1) * 5;  % 默认值
        end
    else
        % 无向图：使用度中心性
        try
            % 尝试centrality函数
            node_degrees = centrality(G, 'degree');
        catch
            % 备用方案：使用degree函数
            try
                node_degrees = degree(G);
            catch
                node_degrees = ones(numnodes(G), 1) * 5;  % 默认值
            end
        end
    end
    
    % 标准化节点大小
    if max(node_degrees) > 0
        node_sizes = 50 + 100 * (node_degrees / max(node_degrees));
    else
        node_sizes = 50 * ones(size(node_degrees));
    end
    
    scatter(layout_coords(:, 1), layout_coords(:, 2), node_sizes, node_colors, 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 1);
    
    % 6. 添加社区图例
    legend_text = cell(n_communities, 1);
    for i = 1:n_communities
        community_size = sum(communities == i);
        legend_text{i} = sprintf('社区%d (%d节点)', i, community_size);
    end
    
    % 创建图例
    legend_handles = gobjects(n_communities, 1);
    for i = 1:n_communities
        legend_handles(i) = plot(NaN, NaN, 'o', ...
            'MarkerSize', 8, 'MarkerFaceColor', community_colors(i, :), ...
            'MarkerEdgeColor', 'k', 'LineWidth', 1);
    end
    
    if n_communities > 0
        legend(legend_handles, legend_text, 'Location', 'best', 'FontSize', 8);
    end
    
    % 7. 添加社区统计
    if isfield(community_data.community_stats, 'community_sizes')
        community_sizes = community_data.community_stats.community_sizes;
        
        stats_text = sprintf('共%d个社区\n最大社区: %d节点\n最小社区: %d节点', ...
            n_communities, max(community_sizes), min(community_sizes));
        
        text(0.02, 0.02, stats_text, ...
            'Units', 'normalized', ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'bottom', ...
            'FontSize', 9, 'BackgroundColor', [1, 1, 1, 0.8]);
    end
    
    % 8. 美化图形
    axis equal;
    axis off;
    
    % 9. 添加标题
    if show_titles
        title('社区结构网络图', 'FontSize', 12, 'FontWeight', 'bold');
    end
    
    hold(ax, 'off');
end

function plot_clustering_distribution(ax, analysis_results, show_titles)
% PLOT_CLUSTERING_DISTRIBUTION - 绘制聚类系数分布图
% 
% 功能：可视化节点局部聚类系数的分布
% 输入：
%   ax: 目标坐标轴句柄
%   analysis_results: 网络分析结果结构体
%   show_titles: 是否显示标题

    % === 关键修复：激活指定坐标轴 ===
    axes(ax);
    hold(ax, 'on');
    
    % 检查数据可用性
    if ~isfield(analysis_results, 'clustering') || ~analysis_results.clustering.is_success
        text(0.5, 0.5, '聚类分析数据不可用', 'HorizontalAlignment', 'center');
        return;
    end
    
    clustering_data = analysis_results.clustering;
    
    % 1. 获取局部聚类系数
    if isfield(clustering_data.local_clustering, 'values')
        local_cc = clustering_data.local_clustering.values;
    else
        text(0.5, 0.5, '无局部聚类系数数据', 'HorizontalAlignment', 'center');
        return;
    end
    
    % 过滤无效值
    valid_cc = local_cc(~isnan(local_cc) & ~isinf(local_cc));
    
    if isempty(valid_cc)
        text(0.5, 0.5, '无有效聚类系数数据', 'HorizontalAlignment', 'center');
        return;
    end
    
    % 2. 绘制直方图
    histogram(valid_cc, 'BinMethod', 'auto', ...
        'FaceColor', [0.8, 0.4, 0.2], ...
        'EdgeColor', [0.6, 0.3, 0.1], ...
        'FaceAlpha', 0.7, ...
        'Normalization', 'probability');
    
    % 3. 添加统计参考线
    mean_cc = mean(valid_cc, 'omitnan');
    median_cc = median(valid_cc, 'omitnan');
    
    y_limits = ylim;
    
    % 平均值线
    plot([mean_cc, mean_cc], [0, y_limits(2)], ...
        'r--', 'LineWidth', 2.5, 'Color', [0.8, 0.2, 0.2]);
    
    text(mean_cc, y_limits(2)*0.95, ...
        sprintf('平均: %.3f', mean_cc), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'top', ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'Color', [0.8, 0.2, 0.2], ...
        'BackgroundColor', [1, 1, 1, 0.8]);
    
    % 中位数线
    plot([median_cc, median_cc], [0, y_limits(2)], ...
        'g--', 'LineWidth', 2.5, 'Color', [0.2, 0.6, 0.2]);
    
    text(median_cc, y_limits(2)*0.85, ...
        sprintf('中位: %.3f', median_cc), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'top', ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'Color', [0.2, 0.6, 0.2], ...
        'BackgroundColor', [1, 1, 1, 0.8]);
    
    % 4. 设置坐标轴属性
    xlabel('局部聚类系数', 'FontSize', 10, 'FontWeight', 'bold');
    ylabel('频率', 'FontSize', 10, 'FontWeight', 'bold');
    
    xlim([0, 1.1]);
    grid on;
    grid minor;
    set(gca, 'GridAlpha', 0.3, 'MinorGridAlpha', 0.1);
    box on;
    
    % 5. 添加全局聚类系数
    if isfield(clustering_data, 'global_clustering')
        if isfield(clustering_data.global_clustering, 'value')
            global_cc = clustering_data.global_clustering.value;
            
            text(0.95, 0.95, sprintf('全局CC: %.3f', global_cc), ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'top', ...
                'FontSize', 10, 'FontWeight', 'bold', ...
                'BackgroundColor', [1, 1, 1, 0.8]);
        end
    end
    
    % 6. 添加传递性
    if isfield(clustering_data, 'transitivity')
        if isfield(clustering_data.transitivity, 'value')
            transitivity = clustering_data.transitivity.value;
            
            text(0.95, 0.85, sprintf('传递性: %.3f', transitivity), ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'top', ...
                'FontSize', 10, 'FontWeight', 'bold', ...
                'BackgroundColor', [1, 1, 1, 0.8]);
        end
    end
    
    % 7. 添加小世界分析
    if isfield(clustering_data, 'small_world_analysis')
        if isfield(clustering_data.small_world_analysis, 'assessment')
            assessment = clustering_data.small_world_analysis.assessment;
            
            text(0.05, 0.05, assessment, ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 9, 'BackgroundColor', [1, 1, 1, 0.8]);
        end
    end
    
    % 8. 添加统计摘要
    stats_text = {sprintf('样本数: %d', length(valid_cc)), ...
                  sprintf('标准差: %.3f', std(valid_cc, 'omitnan')), ...
                  sprintf('最小值: %.3f', min(valid_cc)), ...
                  sprintf('最大值: %.3f', max(valid_cc))};
    
    % 使用相对位置
    x_pos = 0.7;
    y_pos = 0.7;
    annotation('textbox', [x_pos, y_pos, 0.25, 0.2], ...
        'String', stats_text, 'FontSize', 9, ...
        'BackgroundColor', [1, 1, 1, 0.8], ...
        'EdgeColor', [0.8, 0.8, 0.8]);
    
    % 9. 添加标题
    if show_titles
        title('局部聚类系数分布', 'FontSize', 12, 'FontWeight', 'bold');
    end
    
    hold(ax, 'off');
end

function plot_key_nodes_identification(ax, analysis_results, pair_network, show_titles)
% PLOT_KEY_NODES_IDENTIFICATION - 绘制关键节点识别图
% 
% 功能：可视化网络中的关键节点
% 输入：
%   ax: 目标坐标轴句柄
%   analysis_results: 网络分析结果结构体
%   pair_network: 网络结构体
%   show_titles: 是否显示标题

    % === 关键修复：激活指定坐标轴 ===
    axes(ax);
    hold(ax, 'on');
    
    % 检查数据可用性
    if ~isfield(analysis_results, 'keynodes') || ~analysis_results.keynodes.is_success
        text(0.5, 0.5, '关键节点数据不可用', 'HorizontalAlignment', 'center');
        return;
    end
    
    keynodes_data = analysis_results.keynodes;
    
    % 1. 获取关键节点
    if isfield(keynodes_data, 'key_nodes')
        key_nodes = keynodes_data.key_nodes;
    else
        text(0.5, 0.5, '无关键节点数据', 'HorizontalAlignment', 'center');
        return;
    end
    
    % 2. 创建简单的网络图显示关键节点
    adjacency = pair_network.adjacency;
    if strcmp(pair_network.graph_type, 'undirected')
        G = graph(adjacency, 'upper');
    else
        G = digraph(adjacency);
    end
    
    % 3. 计算布局
    try
        fig_temp = figure('Visible', 'off');
        h = plot(G, 'Layout', 'circle');
        layout_coords = [h.XData' h.YData'];
        close(fig_temp);
    catch
        % 备用布局
        n_nodes = numnodes(G);
        theta = linspace(0, 2*pi, n_nodes+1);
        theta = theta(1:end-1);
        layout_coords = [cos(theta)' sin(theta)'] * 5;
    end
    
    % 4. 准备节点颜色和大小
    n_nodes = numnodes(G);
    node_colors = repmat([0.7, 0.7, 0.7], n_nodes, 1);  % 默认灰色
    node_sizes = ones(n_nodes, 1) * 20;  % 默认大小
    
    % 标记关键节点
    for i = 1:length(key_nodes)
        node_idx = key_nodes(i);
        if node_idx <= n_nodes
            node_colors(node_idx, :) = [0.8, 0.2, 0.2];  % 红色表示关键节点
            node_sizes(node_idx) = 100;  % 放大关键节点
        end
    end
    
    % 5. 绘制网络
    % 绘制边
    if ~isempty(G.Edges)
        for i = 1:height(G.Edges)
            source_idx = G.Edges.EndNodes(i, 1);
            target_idx = G.Edges.EndNodes(i, 2);
            
            x_points = [layout_coords(source_idx, 1), layout_coords(target_idx, 1)];
            y_points = [layout_coords(source_idx, 2), layout_coords(target_idx, 2)];
            
            % 如果连接涉及关键节点，用粗线
            if ismember(source_idx, key_nodes) || ismember(target_idx, key_nodes)
                line_width = 2;
                line_color = [0.8, 0.2, 0.2, 0.3];  % 半透明红色
            else
                line_width = 0.5;
                line_color = [0.7, 0.7, 0.7, 0.3];  % 半透明灰色
            end
            
            plot(x_points, y_points, 'Color', line_color, ...
                'LineWidth', line_width, 'HandleVisibility', 'off');
        end
    end
    
    % 绘制节点
    scatter(layout_coords(:, 1), layout_coords(:, 2), node_sizes, node_colors, 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 1);
    
    % 6. 标记关键节点
    for i = 1:length(key_nodes)
        node_idx = key_nodes(i);
        if node_idx <= n_nodes && length(pair_network.node_labels) >= node_idx
            text(layout_coords(node_idx, 1), layout_coords(node_idx, 2) + 0.1, ...
                pair_network.node_labels{node_idx}, ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 9, 'FontWeight', 'bold', ...
                'BackgroundColor', [1, 1, 1, 0.8]);
        end
    end
    
    % 7. 添加图例
    legend_handles = gobjects(2, 1);
    legend_handles(1) = scatter(NaN, NaN, 100, [0.7, 0.7, 0.7], 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 1);
    legend_handles(2) = scatter(NaN, NaN, 100, [0.8, 0.2, 0.2], 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 1);
    
    legend(legend_handles, {'普通节点', '关键节点'}, ...
        'Location', 'best', 'FontSize', 8);
    
    % 8. 添加关键节点统计
    if isfield(keynodes_data, 'node_importance')
        node_importance = keynodes_data.node_importance;
        
        % 显示重要性评分
        importance_text = cell(length(key_nodes), 1);
        for i = 1:min(5, length(key_nodes))
            node_idx = key_nodes(i);
            if length(pair_network.node_labels) >= node_idx
                label = pair_network.node_labels{node_idx};
            else
                label = sprintf('节点%d', node_idx);
            end
            
            if length(node_importance) >= node_idx
                score = node_importance(node_idx);
                importance_text{i} = sprintf('%s: %.3f', label, score);
            end
        end
        
        if ~isempty(importance_text)
            text(0.02, 0.02, importance_text, ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 9, 'BackgroundColor', [1, 1, 1, 0.8]);
        end
    end
    
    % 9. 美化图形
    axis equal;
    axis off;
    
    % 10. 添加标题
    if show_titles
        title('关键节点识别', 'FontSize', 12, 'FontWeight', 'bold');
        
        % 添加副标题
        subtitle(sprintf('共识别到 %d 个关键节点', length(key_nodes)), ...
            'FontSize', 10);
    end
    
    hold(ax, 'off');
end

%% 辅助布局函数（兼容MATLAB 2018b）

function coords = layout_force(G, iterations)
% LAYOUT_FORCE - 力导向布局算法（简化版）
% 适用于MATLAB 2018b及更早版本
    
    n_nodes = numnodes(G);
    
    % 初始化随机位置
    coords = rand(n_nodes, 2) * 10;
    
    if iterations <= 0
        iterations = 100;
    end
    
    % 力导向布局参数
    k = sqrt(1/n_nodes) * 5;  % 最优距离常数
    t = 1;  % 温度
    dt = t / iterations;  % 冷却率
    
    % 创建邻接矩阵
    A = adjacency(G);
    
    for iter = 1:iterations
        % 初始化力
        forces = zeros(n_nodes, 2);
        
        % 计算节点间的排斥力
        for i = 1:n_nodes
            for j = (i+1):n_nodes
                if i ~= j
                    % 计算距离
                    dx = coords(i,1) - coords(j,1);
                    dy = coords(i,2) - coords(j,2);
                    d = sqrt(dx^2 + dy^2 + 0.01);  % 避免除零
                    
                    % 排斥力
                    repulsive_force = k^2 / d;
                    
                    forces(i,1) = forces(i,1) + (dx/d) * repulsive_force;
                    forces(i,2) = forces(i,2) + (dy/d) * repulsive_force;
                    forces(j,1) = forces(j,1) - (dx/d) * repulsive_force;
                    forces(j,2) = forces(j,2) - (dy/d) * repulsive_force;
                end
            end
        end
        
        % 计算边的吸引力
        if isa(G, 'digraph')
            edges = G.Edges.EndNodes;
        else
            edges = G.Edges.EndNodes;
        end
        
        for e = 1:size(edges, 1)
            i = edges(e, 1);
            j = edges(e, 2);
            
            % 计算距离
            dx = coords(i,1) - coords(j,1);
            dy = coords(i,2) - coords(j,2);
            d = sqrt(dx^2 + dy^2 + 0.01);
            
            % 吸引力
            attractive_force = d^2 / k;
            
            forces(i,1) = forces(i,1) - (dx/d) * attractive_force;
            forces(i,2) = forces(i,2) - (dy/d) * attractive_force;
            forces(j,1) = forces(j,1) + (dx/d) * attractive_force;
            forces(j,2) = forces(j,2) + (dy/d) * attractive_force;
        end
        
        % 应用力
        force_magnitude = sqrt(sum(forces.^2, 2));
        max_force = max(force_magnitude);
        if max_force > 0
            forces = forces ./ max_force * t;
        end
        
        coords = coords + forces;
        
        % 冷却
        t = t * (1 - dt);
    end
end

function coords = layout_simple(G)
% LAYOUT_SIMPLE - 简单布局算法
    
    n_nodes = numnodes(G);
    
    if n_nodes < 20
        % 小网络使用圆形布局
        theta = linspace(0, 2*pi, n_nodes+1);
        theta = theta(1:end-1);
        coords = [cos(theta)' sin(theta)'] * 5;
    else
        % 大网络使用随机布局
        coords = rand(n_nodes, 2) * 10;
    end
end
