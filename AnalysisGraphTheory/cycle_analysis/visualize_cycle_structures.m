function [fig_handles, viz_stats] = visualize_cycle_structures(cycle_analysis_results, pair_network, varargin)
% VISUALIZE_CYCLE_STRUCTURES - 环结构分析可视化函数
% 
% 【功能描述】
% 专门针对环结构分析结果的可视化功能，展示网络中的环、三角形、反馈回路等结构。
% 生成包含多个子图的画布，全面展示环结构的特征和分布。
%
% 【输入参数】
%   cycle_analysis_results: 环结构分析结果结构体
%   pair_network: 原始网络结构体（包含adjacency, node_labels）
%   varargin: 可选参数
%       'VisualizationMode': 可视化模式
%           - 'complete' (默认): 生成完整可视化
%           - 'cycle_distribution': 只生成环分布图
%           - 'topology': 只生成环拓扑图
%           - 'feedback': 只生成反馈回路图
%       'Layout': 布局算法 ('force'(默认), 'circle', 'subspace')
%       'HighlightKeyCycles': 是否高亮关键环 (默认: true)
%       'MaxCyclesToShow': 图中显示的最大环数量 (默认: 10)
%       'NodeLabels': 是否显示节点标签 (默认: true)
%       'FigureQuality': 图形质量 ('high'(默认), 'medium', 'low')
%       'SaveFigures': 是否保存图形 (默认: false)
%       'OutputDir': 保存目录 (默认: 'cycle_visualization/')
%       'FigureFormat': 保存格式 ('png'(默认), 'pdf', 'svg')
%       'Verbose': 是否显示处理信息 (默认: true)
%
% 【输出参数】
%   fig_handles: 图形句柄结构体
%   viz_stats: 可视化统计信息
%
% 【可视化内容】
% 1. 环大小分布图
% 2. 环类型分布图
% 3. 环拓扑图
% 4. 三角形闭合图
% 5. 反馈回路可视化
% 6. 强连通分量图
%
% 【调用示例】
%   % 完整可视化
%   [figs, stats] = visualize_cycle_structures(cycle_results, pair_network);
%   
%   % 1. 生成完整的环结构可视化
%   [figs, stats] = visualize_cycle_structures(cycle_results, pair_network, ...
%       'VisualizationMode', 'complete', ...
%       'Layout', 'subspace', ...
%       'MaxCyclesToShow', 8, ...
%       'FigureQuality', 'high', ...
%       'SaveFigures', true, ...
%       'OutputDir', 'cycle_analysis_plots/', ...
%       'FigureFormat', 'pdf', ...
%       'Verbose', true);
%
%   % 2. 只生成环分布图
%   [figs, stats] = visualize_cycle_structures(cycle_results, pair_network, ...
%       'VisualizationMode', 'cycle_distribution', ...
%       'FigureQuality', 'medium');
%
%   % 3. 只生成环拓扑图
%   [figs, stats] = visualize_cycle_structures(cycle_results, pair_network, ...
%       'VisualizationMode', 'topology', ...
%       'Layout', 'force', ...
%       'NodeLabels', true, ...
%       'MaxCyclesToShow', 5);

    %% 1. 参数解析
    start_time = tic;
    
    p = inputParser;
    addRequired(p, 'cycle_analysis_results', @isstruct);
    addRequired(p, 'pair_network', @isstruct);
    
    addParameter(p, 'VisualizationMode', 'complete', ...
        @(x) ismember(x, {'complete', 'cycle_distribution', 'topology', 'feedback'}));
    addParameter(p, 'Layout', 'force', ...
        @(x) ismember(x, {'force', 'circle', 'subspace'}));
    addParameter(p, 'HighlightKeyCycles', true, @islogical);
    addParameter(p, 'MaxCyclesToShow', 10, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'NodeLabels', true, @islogical);
    addParameter(p, 'FigureQuality', 'high', ...
        @(x) ismember(x, {'high', 'medium', 'low'}));
    addParameter(p, 'SaveFigures', false, @islogical);
    addParameter(p, 'OutputDir', 'cycle_visualization/', @ischar);
    addParameter(p, 'FigureFormat', 'png', ...
        @(x) ismember(x, {'png', 'pdf', 'svg', 'fig'}));
    addParameter(p, 'Verbose', true, @islogical);
    
    p.parse(cycle_analysis_results, pair_network, varargin{:});
    opts = p.Results;
    
    %% 2. 初始化
    if opts.Verbose
        fprintf('\n========================================\n');
        fprintf('环结构分析可视化\n');
        fprintf('========================================\n');
    end
    
    fig_handles = struct();
    viz_stats = struct();
    viz_stats.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    % 准备保存目录
    if opts.SaveFigures && ~exist(opts.OutputDir, 'dir')
        mkdir(opts.OutputDir);
    end
    
    %% 3. 提取数据
    cycle_data = extract_cycle_data_for_visualization(cycle_analysis_results, pair_network, opts);
    
    %% 4. 根据模式生成可视化
    mode = opts.VisualizationMode;
    n_figs_generated = 0;
    
    % 4.1 环统计分布图
    if any(strcmp(mode, {'complete', 'cycle_distribution'}))
        if opts.Verbose
            fprintf('生成图1: 环统计分布图...\n');
        end
        
        fig_handles.distribution_fig = plot_cycle_distribution(cycle_data, opts);
        n_figs_generated = n_figs_generated + 1;
        
        if opts.SaveFigures
            save_figure(fig_handles.distribution_fig, opts.OutputDir, ...
                'cycle_distribution', opts.FigureFormat, opts.Verbose);
        end
    end
    
    % 4.2 环拓扑图
    if any(strcmp(mode, {'complete', 'topology'}))
        if opts.Verbose
            fprintf('生成图2: 环拓扑结构图...\n');
        end
        
        fig_handles.topology_fig = plot_cycle_topology(cycle_data, pair_network, opts);
        n_figs_generated = n_figs_generated + 1;
        
        if opts.SaveFigures
            save_figure(fig_handles.topology_fig, opts.OutputDir, ...
                'cycle_topology', opts.FigureFormat, opts.Verbose);
        end
    end
    
    % 4.3 反馈回路图
    if any(strcmp(mode, {'complete', 'feedback'}))
        if opts.Verbose
            fprintf('生成图3: 反馈回路可视化...\n');
        end
        
        fig_handles.feedback_fig = plot_feedback_loops(cycle_data, pair_network, opts);
        n_figs_generated = n_figs_generated + 1;
        
        if opts.SaveFigures
            save_figure(fig_handles.feedback_fig, opts.OutputDir, ...
                'feedback_loops', opts.FigureFormat, opts.Verbose);
        end
    end
    
    %% 5. 完成
    viz_stats.n_figs_generated = n_figs_generated;
    viz_stats.generation_time = toc(start_time);
    
    if opts.Verbose
        fprintf('\n========================================\n');
        fprintf('可视化完成\n');
        fprintf('生成图形数量: %d\n', n_figs_generated);
        fprintf('总耗时: %.2f 秒\n', viz_stats.generation_time);
        fprintf('========================================\n\n');
    end
end

%% ==================== 核心可视化函数 ====================

function fig_handle = plot_cycle_distribution(cycle_data, opts)
% 绘制环统计分布图
    
    % 设置图形大小
    switch opts.FigureQuality
        case 'high'
            fig_position = [100, 100, 1200, 800];
        case 'medium'
            fig_position = [100, 100, 1000, 600];
        case 'low'
            fig_position = [100, 100, 800, 500];
    end
    
    fig_handle = figure('Position', fig_position, ...
        'Name', '环统计分布', ...
        'NumberTitle', 'off', ...
        'Color', 'white');
    
    % 2×3布局
    % 子图1: 环大小分布
    subplot(2, 3, 1);
    if isfield(cycle_data, 'simple_cycle_lengths') && ~isempty(cycle_data.simple_cycle_lengths)
        histogram(cycle_data.simple_cycle_lengths, 'BinMethod', 'integers', ...
            'FaceColor', [0.2, 0.4, 0.8], 'EdgeColor', 'black');
        xlabel('环长度');
        ylabel('数量');
        title('环大小分布');
        grid on;
        
        % 添加统计信息
        stats_text = sprintf('平均: %.2f\n最大: %d\n最小: %d', ...
            cycle_data.mean_cycle_length, cycle_data.max_cycle_length, ...
            cycle_data.min_cycle_length);
        text(0.05, 0.95, stats_text, 'Units', 'normalized', ...
            'VerticalAlignment', 'top', 'BackgroundColor', [1, 1, 1, 0.8]);
    else
        text(0.5, 0.5, '无环数据', 'HorizontalAlignment', 'center');
    end
    
    % 子图2: 环类型分布
    subplot(2, 3, 2);
    if isfield(cycle_data, 'type_distribution')
        types = fieldnames(cycle_data.type_distribution);
        counts = zeros(length(types), 1);
        for i = 1:length(types)
            counts(i) = cycle_data.type_distribution.(types{i});
        end
        
        % 创建条形图
        bar_handle = bar(counts, 'FaceColor', [0.8, 0.2, 0.2]);
        set(gca, 'XTickLabel', types, 'XTick', 1:length(types));
        xlabel('环类型');
        ylabel('数量');
        title('环类型分布');
        grid on;
        
        % 添加数值标签
        for i = 1:length(counts)
            text(i, counts(i), num2str(counts(i)), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
        end
    else
        text(0.5, 0.5, '无类型数据', 'HorizontalAlignment', 'center');
    end
    
    % 子图3: 总环数量
    subplot(2, 3, 3);
    if isfield(cycle_data, 'total_cycles')
        % 创建仪表盘样式的显示
        theta = linspace(0, 2*pi, 100);
        r = 1;
        fill(r*cos(theta), r*sin(theta), [0.9, 0.9, 0.9], 'EdgeColor', 'none');
        hold on;
        
        % 根据环数量设置指针角度
        max_cycles = max(50, cycle_data.total_cycles * 1.2);
        pointer_angle = (cycle_data.total_cycles / max_cycles) * pi;
        
        % 绘制指针
        plot([0, 0.8*cos(pointer_angle - pi/2)], ...
             [0, 0.8*sin(pointer_angle - pi/2)], 'r-', 'LineWidth', 3);
        
        % 添加刻度
        for angle = [0, pi/4, pi/2, 3*pi/4, pi]
            plot([0.9*cos(angle - pi/2), cos(angle - pi/2)], ...
                 [0.9*sin(angle - pi/2), sin(angle - pi/2)], 'k-', 'LineWidth', 1);
        end
        
        % 添加数字
        text(0, 0, sprintf('%d', cycle_data.total_cycles), ...
            'HorizontalAlignment', 'center', 'FontSize', 20, 'FontWeight', 'bold');
        
        axis equal;
        axis off;
        title('总环数量');
    end
    
    % 子图4: 聚类系数
    subplot(2, 3, 4);
    if isfield(cycle_data, 'global_clustering_coefficient')
        % 绘制雷达图显示多个聚类指标
        metrics = {'全局聚类', '传递性', '局部聚类'};
        values = zeros(1, 3);
        values(1) = cycle_data.global_clustering_coefficient;
        
        if isfield(cycle_data, 'transitivity')
            values(2) = cycle_data.transitivity;
        end
        
        if isfield(cycle_data, 'mean_local_clustering')
            values(3) = cycle_data.mean_local_clustering;
        end
        
        polarplot_radar(metrics, values, '聚类特征', [0, 1]);
    end
    
    % 子图5: 强连通分量
    subplot(2, 3, 5);
    if isfield(cycle_data, 'scc_sizes') && ~isempty(cycle_data.scc_sizes)
        % 绘制饼图显示SCC大小分布
        [sorted_sizes, sorted_idx] = sort(cycle_data.scc_sizes, 'descend');
        n_to_show = min(5, length(sorted_sizes));
        
        if length(sorted_sizes) > n_to_show
            other_sizes = sum(sorted_sizes(n_to_show+1:end));
            sizes_to_show = [sorted_sizes(1:n_to_show), other_sizes];
            labels = [arrayfun(@(x) sprintf('SCC%d', x), 1:n_to_show, 'UniformOutput', false), {'其他'}];
        else
            sizes_to_show = sorted_sizes;
            labels = arrayfun(@(x) sprintf('SCC%d', x), 1:length(sizes_to_show), 'UniformOutput', false);
        end
        
        pie(sizes_to_show, labels);
        title('强连通分量大小分布');
    end
    
    % 子图6: 反馈回路
    subplot(2, 3, 6);
    if isfield(cycle_data, 'feedback_strength')
        % 绘制热力图风格的反馈强度显示
        strength = cycle_data.feedback_strength;
        imagesc([strength, 0; 0, strength]);
        colormap(flipud(hot));
        colorbar;
        axis off;
        
        % 添加文本
        text(1, 1, sprintf('反馈强度\n%.3f', strength), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', 12, 'FontWeight', 'bold');
        title('反馈强度');
    end
    
    % 添加主标题
    sgtitle('环结构统计分布', 'FontSize', 16, 'FontWeight', 'bold');
end

function fig_handle = plot_cycle_topology(cycle_data, pair_network, opts)
% 绘制环拓扑结构图
    
    % 设置图形大小
    switch opts.FigureQuality
        case 'high'
            fig_position = [100, 100, 1000, 800];
        case 'medium'
            fig_position = [100, 100, 800, 600];
        case 'low'
            fig_position = [100, 100, 600, 450];
    end
    
    fig_handle = figure('Position', fig_position, ...
        'Name', '环拓扑结构', ...
        'NumberTitle', 'off', ...
        'Color', 'white');
    
    % 提取网络数据
    adjacency = pair_network.adjacency;
    node_labels = pair_network.node_labels;
    n_nodes = size(adjacency, 1);
    
    % 创建图对象
    if strcmp(pair_network.graph_type, 'undirected')
        G = graph(adjacency, 'upper');
    else
        G = digraph(adjacency);
    end
    
    % 计算布局
    switch opts.Layout
        case 'force'
            layout_coords = layout(G, 'force', 'Iterations', 300);
        case 'circle'
            layout_coords = layout(G, 'circle');
        case 'subspace'
            % 子空间布局：将ret和obv节点分别聚类
            layout_coords = calculate_subspace_layout(node_labels);
    end
    
    % 绘制基础网络
    hold on;
    
    % 1. 绘制边
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
    
    % 2. 绘制检测到的环
    if isfield(cycle_data, 'simple_cycles') && cycle_data.n_simple_cycles > 0
        cycles = cycle_data.simple_cycles;
        
        % 选择要显示的环
        n_cycles_to_show = min(opts.MaxCyclesToShow, cycle_data.n_simple_cycles);
        
        % 按环长度排序，优先显示短环
        cycle_lengths = cycle_data.simple_cycle_lengths;
        [~, sort_idx] = sort(cycle_lengths);
        
        % 为环分配颜色
        cycle_colors = jet(n_cycles_to_show);
        
        for i = 1:n_cycles_to_show
            cycle_idx = sort_idx(i);
            cycle_nodes = cycles{cycle_idx};
            cycle_len = length(cycle_nodes);
            
            % 闭合环
            cycle_nodes_closed = [cycle_nodes; cycle_nodes(1)];
            
            % 获取环节点的坐标
            cycle_coords = layout_coords(cycle_nodes_closed, :);
            
            % 绘制环
            plot(cycle_coords(:, 1), cycle_coords(:, 2), ...
                'Color', cycle_colors(i, :), ...
                'LineWidth', 2, ...
                'LineStyle', '-', ...
                'DisplayName', sprintf('环%d (长度:%d)', i, cycle_len));
        end
    end
    
    % 3. 绘制三角形
    if isfield(cycle_data, 'triangles') && cycle_data.n_triangles > 0
        triangles = cycle_data.triangles;
        n_triangles_to_show = min(5, size(triangles, 1));
        
        for i = 1:n_triangles_to_show
            tri_nodes = triangles(i, :);
            tri_nodes_closed = [tri_nodes, tri_nodes(1)];
            
            tri_coords = layout_coords(tri_nodes_closed, :);
            
            % 填充三角形
            fill(tri_coords(:, 1), tri_coords(:, 2), [0.9, 0.9, 0.2], ...
                'FaceAlpha', 0.3, 'EdgeColor', [0.8, 0.8, 0], ...
                'LineWidth', 1.5, 'DisplayName', sprintf('三角形%d', i));
        end
    end
    
    % 4. 绘制节点
    node_colors = zeros(n_nodes, 3);
    for i = 1:n_nodes
        label = node_labels{i};
        if contains(label, 'ret')
            node_colors(i, :) = [0.2, 0.4, 0.8];  % 蓝色表示ret节点
        elseif contains(label, 'OBV') || contains(label, 'obv')
            node_colors(i, :) = [0.8, 0.2, 0.2];  % 红色表示obv节点
        else
            node_colors(i, :) = [0.6, 0.6, 0.6];  % 灰色表示其他节点
        end
    end
    
    scatter(layout_coords(:, 1), layout_coords(:, 2), 100, node_colors, 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 1.5, 'DisplayName', '节点');
    
    % 5. 添加节点标签
    if opts.NodeLabels
        for i = 1:n_nodes
            text(layout_coords(i, 1) + 0.02, layout_coords(i, 2) + 0.02, ...
                node_labels{i}, 'FontSize', 8, 'Interpreter', 'none', ...
                'BackgroundColor', [1, 1, 1, 0.7]);
        end
    end
    
    % 6. 图形美化
    axis equal;
    axis off;
    box off;
    grid off;
    
    % 添加图例
    if isfield(cycle_data, 'simple_cycles') && cycle_data.n_simple_cycles > 0
        legend('Location', 'best', 'FontSize', 9);
    end
    
    % 添加标题
    title_str = '环拓扑结构';
    if isfield(cycle_data, 'total_cycles')
        title_str = sprintf('%s (总环数: %d)', title_str, cycle_data.total_cycles);
    end
    title(title_str, 'FontSize', 14, 'FontWeight', 'bold');
    
    % 添加统计信息
    stats_text = {};
    if isfield(cycle_data, 'n_simple_cycles')
        stats_text{end+1} = sprintf('简单环: %d', cycle_data.n_simple_cycles);
    end
    if isfield(cycle_data, 'n_triangles')
        stats_text{end+1} = sprintf('三角形: %d', cycle_data.n_triangles);
    end
    if isfield(cycle_data, 'n_directed_cycles')
        stats_text{end+1} = sprintf('有向环: %d', cycle_data.n_directed_cycles);
    end
    
    if ~isempty(stats_text)
        annotation('textbox', [0.02, 0.02, 0.3, 0.1], ...
            'String', stats_text, 'FontSize', 9, ...
            'BackgroundColor', [1, 1, 1, 0.8], 'EdgeColor', 'none');
    end
end

function fig_handle = plot_feedback_loops(cycle_data, pair_network, opts)
% 绘制反馈回路可视化
    
    % 设置图形大小
    switch opts.FigureQuality
        case 'high'
            fig_position = [100, 100, 1200, 600];
        case 'medium'
            fig_position = [100, 100, 1000, 500];
        case 'low'
            fig_position = [100, 100, 800, 400];
    end
    
    fig_handle = figure('Position', fig_position, ...
        'Name', '反馈回路分析', ...
        'NumberTitle', 'off', ...
        'Color', 'white');
    
    % 提取网络数据
    adjacency = pair_network.adjacency;
    node_labels = pair_network.node_labels;
    is_directed = strcmp(pair_network.graph_type, 'directed');
    
    % 只有有向图才有反馈回路
    if ~is_directed
        text(0.5, 0.5, '无向图，无反馈回路', 'HorizontalAlignment', 'center');
        return;
    end
    
    % 创建有向图对象
    G = digraph(adjacency);
    
    % 3个子图布局
    % 子图1: 强连通分量
    subplot(1, 3, 1);
    if isfield(cycle_data, 'scc_sizes') && ~isempty(cycle_data.scc_sizes)
        % 绘制SCC大小分布条形图
        bar(cycle_data.scc_sizes, 'FaceColor', [0.2, 0.6, 0.8]);
        xlabel('强连通分量编号');
        ylabel('大小');
        title(sprintf('强连通分量 (共%d个)', cycle_data.n_sccs));
        grid on;
        
        % 添加数值标签
        for i = 1:length(cycle_data.scc_sizes)
            text(i, cycle_data.scc_sizes(i), num2str(cycle_data.scc_sizes(i)), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
        end
    else
        text(0.5, 0.5, '无强连通分量数据', 'HorizontalAlignment', 'center');
    end
    
    % 子图2: 反馈回路拓扑
    subplot(1, 3, 2);
    if isfield(cycle_data, 'feedback_loops') && cycle_data.n_feedback_loops > 0
        feedback_loops = cycle_data.feedback_loops;
        
        % 计算布局
        layout_coords = layout(G, 'layered');
        
        % 绘制基础网络
        plot(G, 'XData', layout_coords(:, 1), 'YData', layout_coords(:, 2), ...
            'NodeColor', [0.8, 0.8, 0.8], 'EdgeColor', [0.7, 0.7, 0.7], ...
            'NodeLabel', {}, 'ArrowSize', 8, 'LineWidth', 0.5);
        hold on;
        
        % 高亮反馈回路
        n_loops_to_show = min(3, cycle_data.n_feedback_loops);
        loop_colors = hsv(n_loops_to_show);
        
        for i = 1:n_loops_to_show
            loop_nodes = feedback_loops{i};
            loop_len = length(loop_nodes);
            
            if loop_len >= 2
                % 绘制反馈回路的边
                for j = 1:loop_len
                    source = loop_nodes(j);
                    target = loop_nodes(mod(j, loop_len) + 1);
                    
                    % 获取坐标
                    source_coord = layout_coords(source, :);
                    target_coord = layout_coords(target, :);
                    
                    % 绘制箭头
                    arrow_scale = 0.3;
                    dx = target_coord(1) - source_coord(1);
                    dy = target_coord(2) - source_coord(2);
                    
                    quiver(source_coord(1), source_coord(2), dx, dy, ...
                        arrow_scale, 'Color', loop_colors(i, :), ...
                        'LineWidth', 2, 'MaxHeadSize', 0.5, ...
                        'DisplayName', sprintf('反馈回路%d', i));
                end
                
                % 高亮节点
                scatter(layout_coords(loop_nodes, 1), layout_coords(loop_nodes, 2), ...
                    100, loop_colors(i, :), 'filled', ...
                    'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
            end
        end
        
        % 添加节点标签
        for i = 1:length(node_labels)
            text(layout_coords(i, 1) + 0.02, layout_coords(i, 2) + 0.02, ...
                node_labels{i}, 'FontSize', 8, 'Interpreter', 'none');
        end
        
        axis equal;
        axis off;
        title(sprintf('反馈回路 (共%d个)', cycle_data.n_feedback_loops));
        
        if n_loops_to_show > 0
            legend('Location', 'best', 'FontSize', 8);
        end
    else
        text(0.5, 0.5, '无反馈回路', 'HorizontalAlignment', 'center');
    end
    
    % 子图3: 反馈强度分析
    subplot(1, 3, 3);
    if isfield(cycle_data, 'feedback_strength')
        % 绘制反馈强度仪表盘
        strength = cycle_data.feedback_strength;
        
        % 绘制半圆
        theta = linspace(0, pi, 100);
        r = 1;
        fill(r*cos(theta), r*sin(theta), [0.9, 0.9, 0.9], 'EdgeColor', 'none');
        hold on;
        
        % 绘制刻度
        for angle = linspace(0, pi, 6)
            plot([0.9*cos(angle), cos(angle)], [0.9*sin(angle), sin(angle)], ...
                'k-', 'LineWidth', 1);
        end
        
        % 绘制指针
        pointer_angle = strength * pi;
        plot([0, 0.8*cos(pointer_angle)], [0, 0.8*sin(pointer_angle)], ...
            'r-', 'LineWidth', 3);
        
        % 添加标签
        text(0, 0, sprintf('%.3f', strength), ...
            'HorizontalAlignment', 'center', 'FontSize', 16, 'FontWeight', 'bold');
        
        % 添加刻度标签
        text(cos(0), sin(0)+0.1, '0', 'HorizontalAlignment', 'center');
        text(cos(pi/2), sin(pi/2)+0.1, '0.5', 'HorizontalAlignment', 'center');
        text(cos(pi), sin(pi)+0.1, '1.0', 'HorizontalAlignment', 'center');
        
        axis equal;
        axis off;
        title('反馈强度');
        
        % 添加评估
        if strength > 0.7
            assessment = '强反馈';
            color = [0.8, 0.2, 0.2];
        elseif strength > 0.4
            assessment = '中等反馈';
            color = [0.8, 0.8, 0.2];
        else
            assessment = '弱反馈';
            color = [0.2, 0.8, 0.2];
        end
        
        text(0, -0.3, assessment, 'HorizontalAlignment', 'center', ...
            'FontSize', 12, 'FontWeight', 'bold', 'Color', color);
    end
    
    % 添加主标题
    sgtitle('反馈回路分析', 'FontSize', 16, 'FontWeight', 'bold');
end

%% ==================== 辅助函数 ====================

function cycle_data = extract_cycle_data_for_visualization(cycle_results, pair_network, opts)
% 提取可视化所需数据
    
    cycle_data = struct();
    
    % 基本网络信息
    cycle_data.n_nodes = pair_network.n_nodes;
    cycle_data.node_labels = pair_network.node_labels;
    cycle_data.is_directed = strcmp(pair_network.graph_type, 'directed');
    
    % 简单环数据
    if isfield(cycle_results, 'simple_cycles') && cycle_results.simple_cycles.is_success
        simple = cycle_results.simple_cycles;
        cycle_data.simple_cycles = simple.cycles;
        cycle_data.n_simple_cycles = simple.n_cycles;
        cycle_data.simple_cycle_lengths = simple.cycle_lengths;
        
        if cycle_data.n_simple_cycles > 0
            cycle_data.min_cycle_length = simple.stats.min_length;
            cycle_data.max_cycle_length = simple.stats.max_length;
            cycle_data.mean_cycle_length = simple.stats.mean_length;
        end
    end
    
    % 三角形数据
    if isfield(cycle_results, 'triangles') && cycle_results.triangles.is_success
        triangles = cycle_results.triangles;
        cycle_data.triangles = triangles.triangles;
        cycle_data.n_triangles = triangles.n_triangles;
        cycle_data.global_clustering_coefficient = triangles.global_clustering_coefficient;
        
        if isfield(triangles, 'transitivity')
            cycle_data.transitivity = triangles.transitivity;
        end
        
        if isfield(triangles, 'local_clustering')
            cycle_data.mean_local_clustering = mean(triangles.local_clustering, 'omitnan');
        end
    end
    
    % 有向环数据
    if isfield(cycle_results, 'directed_cycles') && cycle_results.directed_cycles.is_success
        directed = cycle_results.directed_cycles;
        cycle_data.directed_cycles = directed.directed_cycles;
        cycle_data.n_directed_cycles = directed.n_directed_cycles;
        cycle_data.sccs = directed.strongly_connected_components;
        cycle_data.n_sccs = directed.n_sccs;
        cycle_data.scc_sizes = directed.scc_sizes;
        
        if isfield(directed, 'scc_stats')
            cycle_data.largest_scc_size = directed.scc_stats.largest_scc_size;
        end
    end
    
    % 反馈回路数据
    if isfield(cycle_results, 'feedback_loops') && cycle_results.feedback_loops.is_success
        feedback = cycle_results.feedback_loops;
        cycle_data.feedback_loops = feedback.feedback_loops;
        cycle_data.n_feedback_loops = feedback.n_feedback_loops;
        
        if isfield(feedback, 'feedback_strength')
            cycle_data.feedback_strength = feedback.feedback_strength;
        end
    end
    
    % 环统计特征
    if isfield(cycle_results, 'cycle_stats') && cycle_results.cycle_stats.is_success
        stats = cycle_results.cycle_stats;
        cycle_data.total_cycles = stats.total_cycles;
        
        if isfield(stats, 'type_distribution')
            cycle_data.type_distribution = stats.type_distribution;
        end
        
        if isfield(stats, 'stats')
            cycle_data.stats = stats.stats;
        end
    end
end

function layout_coords = calculate_subspace_layout(node_labels)
% 计算子空间布局
    n_nodes = length(node_labels);
    layout_coords = zeros(n_nodes, 2);
    
    % 识别ret和obv节点
    is_ret = false(n_nodes, 1);
    is_obv = false(n_nodes, 1);
    
    for i = 1:n_nodes
        label = node_labels{i};
        if contains(label, 'ret')
            is_ret(i) = true;
        elseif contains(label, 'OBV') || contains(label, 'obv')
            is_obv(i) = true;
        end
    end
    
    ret_indices = find(is_ret);
    obv_indices = find(is_obv);
    other_indices = find(~is_ret & ~is_obv);
    
    % ret节点放在左侧
    n_ret = length(ret_indices);
    if n_ret > 0
        if n_ret == 1
            layout_coords(ret_indices, :) = [-2, 0];
        else
            angles = linspace(0, 2*pi, n_ret+1);
            angles = angles(1:end-1);
            radius = 1.5;
            layout_coords(ret_indices, 1) = -2 + radius * cos(angles)';
            layout_coords(ret_indices, 2) = radius * sin(angles)';
        end
    end
    
    % obv节点放在右侧
    n_obv = length(obv_indices);
    if n_obv > 0
        if n_obv == 1
            layout_coords(obv_indices, :) = [2, 0];
        else
            angles = linspace(0, 2*pi, n_obv+1);
            angles = angles(1:end-1);
            radius = 1.5;
            layout_coords(obv_indices, 1) = 2 + radius * cos(angles)';
            layout_coords(obv_indices, 2) = radius * sin(angles)';
        end
    end
    
    % 其他节点放在中间
    n_other = length(other_indices);
    if n_other > 0
        if n_other == 1
            layout_coords(other_indices, :) = [0, 0];
        else
            angles = linspace(0, 2*pi, n_other+1);
            angles = angles(1:end-1);
            radius = 0.8;
            layout_coords(other_indices, 1) = radius * cos(angles)';
            layout_coords(other_indices, 2) = radius * sin(angles)';
        end
    end
end

function polarplot_radar(categories, values, title_str, value_range)
% 绘制雷达图
    n_categories = length(categories);
    angles = linspace(0, 2*pi, n_categories+1);
    angles = angles(1:end-1);
    
    % 闭合数据
    values_closed = [values, values(1)];
    angles_closed = [angles, angles(1)];
    
    % 绘制雷达图
    polarplot(angles_closed, values_closed, 'b-o', 'LineWidth', 2, 'MarkerSize', 8);
    thetalim([0, 360]);
    rlim(value_range);
    
    % 设置角度标签
    thetaticks(rad2deg(angles));
    thetaticklabels(categories);
    
    title(title_str);
    grid on;
end

function save_figure(fig_handle, output_dir, filename_prefix, format, verbose)
% 保存图形
    if ~ishandle(fig_handle)
        return;
    end
    
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    filename = sprintf('%s_%s.%s', filename_prefix, timestamp, format);
    filepath = fullfile(output_dir, filename);
    
    try
        saveas(fig_handle, filepath, format);
        if verbose
            fprintf('  保存图形: %s\n', filename);
        end
    catch ME
        if verbose
            fprintf('  警告: 保存图形失败: %s\n', ME.message);
        end
    end
end