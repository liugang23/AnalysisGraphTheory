function [fig_handle, summary_stats] = plot_network_structure(pair_network, varargin)
% PLOT_NETWORK_STRUCTURE - 网络构建结果结构验证图
% 
% 【功能定位】
% 在网络构建完成后，为验证数据结构组装是否正确而绘制的“骨架图”。
% 本图旨在直观展示：1) 所有节点是否被识别；2) 显著的配对关系是否被正确连接。
% 这是网络分析流程中“构建”阶段的专属可视化，与后续的“拓扑分析”图功能分离。
%
% 【核心设计原则】
% 1. 聚焦“验证”：检查节点、边、权重等基础数据结构是否正确映射。
% 2. 清晰直观：通过布局、颜色、尺寸等视觉编码，使网络基本结构一目了然。
% 3. 避免过度解读：不计算或展示复杂的拓扑指标（如中心性、社区），这些属于“分析”阶段。
%
% 【输入参数】
%   pair_network: 网络构建结果结构体 (必须包含以下字段)
%       - adjacency: 邻接矩阵 (n×n)
%       - node_labels: 节点标签元胞数组 (1×n)
%       - weights: 权重矩阵 (n×n) [可选，但推荐]
%       - n_nodes: 节点数量 [可选]
%       - analysis_type: 分析类型 ('correlation', 'granger', 'all') [可选]
%   varargin: 可选参数名称-值对
%       'FigureTitle': 图形标题 (默认: '网络结构图 (构建阶段)')
%       'NodeSize': 基础节点尺寸 (默认: 100)
%       'NodeColor': 节点颜色 ('ret'节点, 'obv'节点, 'all') 或 RGB向量
%       'EdgeWidthRange': 边宽范围 [min, max]，基于权重缩放 (默认: [0.5, 3])
%       'EdgeColor': 边颜色 (默认: [0.3, 0.3, 0.3] 灰色)
%       'ShowNodeLabels': 是否显示节点标签 (默认: true)
%       'LabelFontSize': 节点标签字体大小 (默认: 8)
%       'Layout': 布局算法 ('force'(默认), 'circle', 'layered', 'subspace')
%       'HighlightIsolatedNodes': 是否高亮孤立节点 (默认: true)
%       'FigurePosition': 图形位置和大小 [x, y, width, height] (默认: [100, 100, 1200, 800])
%       'SaveFigure': 是否保存图形 (默认: false)
%       'SavePath': 保存路径 (默认: 'network_structure_plot.png')
%       'Dpi': 保存图片分辨率 (默认: 300)
%       'Verbose': 是否显示处理信息 (默认: true)
%
% 【输出参数】
%   fig_handle: 图形句柄
%   summary_stats: 结构体，包含图形中展示的基本统计摘要
%
% 【调用示例】
%   % 基本调用
%   fig = visualize_network_structure(pair_network);
%
%   % 自定义参数调用
%   [fig, stats] = visualize_network_structure(pair_network, ...
%       'FigureTitle', '价量配对网络结构 (Granger因果)',
%       'NodeColor', 'type', ...               % 按ret/obv类型着色
%       'Layout', 'circle', ...                % 环形布局
%       'EdgeWidthRange', [1, 5], ...          % 更粗的边
%       'SaveFigure', true, ...                % 保存图片
%       'SavePath', 'my_network_structure.svg', ...
%       'Verbose', true);
%
%   % 用于验证的小型图
%   fig = visualize_network_structure(pair_network, ...
%       'ShowNodeLabels', false, ...           % 节点多时关闭标签
%       'NodeSize', 50, ...                    % 小节点
%       'FigurePosition', [100, 100, 600, 450]); % 小图窗
%   % 基本验证图
%   figure1 = visualize_network_structure(pair_network);

%   % 详细的验证图（推荐）
%    [figure2, stats] = visualize_network_structure(pair_network, ...
%        'FigureTitle', '价量网络结构验证 (Granger因果)', ...
%        'Layout', 'subspace', ...      % 按ret/obv分组布局
%        'NodeColor', 'type', ...       % 按类型着色
%        'ShowNodeLabels', true, ...
%        'SaveFigure', true, ...
%        'SavePath', 'network_validation.png', ...
%        'Verbose', true);
%

%% 1. 输入验证和参数解析
fprintf('\n========================================\n');
fprintf('网络结构验证图生成\n');
fprintf('========================================\n');

start_time = tic;

% 1.1 必需输入验证
if nargin < 1
    error('必须提供网络结构体 pair_network 作为输入。');
end

if ~isstruct(pair_network)
    error('输入 pair_network 必须是结构体。');
end

% 1.2 检查必需字段
required_fields = {'adjacency', 'node_labels'};
missing_fields = {};
for i = 1:length(required_fields)
    if ~isfield(pair_network, required_fields{i})
        missing_fields{end+1} = required_fields{i};
    end
end
if ~isempty(missing_fields)
    error('网络结构体缺少必需字段: %s', strjoin(missing_fields, ', '));
end

% 1.3 获取基本网络参数
adj_matrix = pair_network.adjacency;
node_labels = pair_network.node_labels;
n_nodes = size(adj_matrix, 1);

% 验证矩阵维度
if length(node_labels) ~= n_nodes
    error('节点标签数量 (%d) 与邻接矩阵维度 (%d) 不匹配。', ...
        length(node_labels), n_nodes);
end

% 1.4 设置输入解析器
p = inputParser;
p.addParameter('FigureTitle', '网络结构图 (构建阶段)', @ischar);
p.addParameter('NodeSize', 100, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('NodeColor', 'type', @(x) ischar(x) || (isnumeric(x) && length(x)==3));
p.addParameter('EdgeWidthRange', [0.5, 3], @(x) isnumeric(x) && length(x)==2 && all(x>0));
p.addParameter('EdgeColor', [0.3, 0.3, 0.3], @(x) isnumeric(x) && length(x)==3);
p.addParameter('ShowNodeLabels', true, @islogical);
p.addParameter('LabelFontSize', 8, @(x) isnumeric(x) && isscalar(x) && x>0);
p.addParameter('Layout', 'force', @(x) ismember(x, {'force', 'circle', 'layered', 'subspace'}));
p.addParameter('HighlightIsolatedNodes', true, @islogical);
p.addParameter('FigurePosition', [100, 100, 1200, 800], @(x) isnumeric(x) && length(x)==4);
p.addParameter('SaveFigure', false, @islogical);
p.addParameter('SavePath', 'network_structure_plot.png', @ischar);
p.addParameter('Dpi', 300, @(x) isnumeric(x) && isscalar(x) && x>0);
p.addParameter('Verbose', true, @islogical);
p.parse(varargin{:});

opts = p.Results;

% 1.5 显示输入参数
if opts.Verbose
    fprintf('输入参数:\n');
    fprintf('  节点数量: %d\n', n_nodes);
    fprintf('  边数量: %d\n', sum(adj_matrix(:)));
    fprintf('  布局算法: %s\n', opts.Layout);
    fprintf('  图形标题: %s\n', opts.FigureTitle);
    fprintf('  是否保存: %s\n', bool2str(opts.SaveFigure));
    if opts.SaveFigure
        fprintf('  保存路径: %s\n', opts.SavePath);
    end
end

%% 2. 准备可视化数据
if opts.Verbose
    fprintf('\n准备可视化数据...\n');
end

% 2.1 确定节点颜色
% 根据节点类型(ret/obv)或统一颜色
if ischar(opts.NodeColor) && strcmp(opts.NodeColor, 'type')
    % 按节点类型着色: ret节点蓝色, obv节点红色
    node_colors = zeros(n_nodes, 3);
    for i = 1:n_nodes
        label = node_labels{i};
        if contains(label, 'ret')
            % 收益率节点: 蓝色
            node_colors(i, :) = [0.2, 0.4, 0.8];  % 蓝色
        elseif contains(label, 'OBV') || contains(label, 'obv')
            % OBV节点: 红色
            node_colors(i, :) = [0.8, 0.2, 0.2];  % 红色
        else
            % 其他节点: 灰色
            node_colors(i, :) = [0.6, 0.6, 0.6];  % 灰色
        end
    end
    color_scheme = '按类型 (ret:蓝, obv:红)';
else
    % 统一颜色
    if ischar(opts.NodeColor)
        % 如果是颜色名字符串
        try
            node_colors = repmat(colorstr2rgb(opts.NodeColor), n_nodes, 1);
        catch
            warning('无法识别颜色字符串 "%s"，使用默认蓝色。', opts.NodeColor);
            node_colors = repmat([0.2, 0.4, 0.8], n_nodes, 1);
        end
    else
        % 如果是RGB向量
        node_colors = repmat(opts.NodeColor(:)', n_nodes, 1);
    end
    color_scheme = '统一颜色';
end

% 2.2 计算节点度(用于节点尺寸)
node_degrees = sum(adj_matrix, 2) + sum(adj_matrix, 1)';  % 入度+出度
% 归一化节点度，用于尺寸调整
if max(node_degrees) > 0
    norm_degrees = node_degrees / max(node_degrees);
else
    norm_degrees = ones(n_nodes, 1);
end
node_sizes = opts.NodeSize * (0.5 + 0.5 * norm_degrees);  % 尺寸在0.5-1倍之间变化

% 2.3 准备边数据
% 提取边的起点、终点
[source_nodes, target_nodes] = find(adj_matrix);
n_edges = length(source_nodes);

% 2.4 计算边权重(如果存在)
if isfield(pair_network, 'weights')
    weight_matrix = pair_network.weights;
    edge_weights = zeros(n_edges, 1);
    for i = 1:n_edges
        edge_weights(i) = weight_matrix(source_nodes(i), target_nodes(i));
    end
    has_weights = true;
    
    % 归一化权重用于边宽
    if max(abs(edge_weights)) > 0
        norm_weights = abs(edge_weights) / max(abs(edge_weights));
    else
        norm_weights = zeros(n_edges, 1);
    end
    edge_widths = opts.EdgeWidthRange(1) + ...
                 (opts.EdgeWidthRange(2) - opts.EdgeWidthRange(1)) * norm_weights;
else
    has_weights = false;
    edge_widths = ones(n_edges, 1) * mean(opts.EdgeWidthRange);
end

% 2.5 识别孤立节点
isolated_nodes = find(node_degrees == 0);
n_isolated = length(isolated_nodes);

%% 3. 创建图形
if opts.Verbose
    fprintf('创建图形窗口...\n');
end

fig_handle = figure('Position', opts.FigurePosition, ...
    'Name', '网络结构验证图', ...
    'NumberTitle', 'off', ...
    'Color', 'white');

%% 4. 计算节点布局
if opts.Verbose
    fprintf('计算节点布局 (%s)...\n', opts.Layout);
end

switch opts.Layout
    case 'force'
        % 力导向布局 (默认) - 最自然的网络布局
        G = graph(adj_matrix, node_labels, 'OmitSelfLoops');
        layout_coords = layout(G, 'force', 'Iterations', 300, 'WeightEffect', 'inverse');
        
    case 'circle'
        % 环形布局 - 结构清晰
        G = graph(adj_matrix, node_labels, 'OmitSelfLoops');
        layout_coords = layout(G, 'circle');
        
    case 'layered'
        % 分层布局 - 适合有向图
        try
            G = digraph(adj_matrix, node_labels);
            layout_coords = layered_layout_custom(G, node_labels);
        catch
            G = graph(adj_matrix, node_labels, 'OmitSelfLoops');
            layout_coords = layout(G, 'layered');
        end
        
    case 'subspace'
        % 子空间布局 - 按节点类型分组
        layout_coords = subspace_layout_custom(node_labels, adj_matrix);
        
    otherwise
        error('不支持的布局算法: %s', opts.Layout);
end

% 确保布局坐标是二维的
if size(layout_coords, 2) == 3
    layout_coords = layout_coords(:, 1:2);  % 只取前两维
end

%% 5. 绘制网络
if opts.Verbose
    fprintf('绘制网络元素...\n');
end

% 5.1 绘制边
if n_edges > 0
    hold on;
    
    % 绘制每条边
    for i = 1:n_edges
        source_idx = source_nodes(i);
        target_idx = target_nodes(i);
        
        x_points = [layout_coords(source_idx, 1), layout_coords(target_idx, 1)];
        y_points = [layout_coords(source_idx, 2), layout_coords(target_idx, 2)];
        
        % 绘制边
        line_handle = plot(x_points, y_points, ...
            'Color', opts.EdgeColor, ...
            'LineWidth', edge_widths(i), ...
            'LineStyle', '-', ...
            'HandleVisibility', 'off');
        
        % 如果有权重信息，可以添加颜色映射
        if has_weights
            % 根据权重正负使用不同颜色
            if edge_weights(i) > 0
                set(line_handle, 'Color', [0.2, 0.6, 0.2]);  % 绿色表示正相关
            elseif edge_weights(i) < 0
                set(line_handle, 'Color', [0.8, 0.2, 0.2]);  % 红色表示负相关
            end
        end
    end
end

% 5.2 绘制节点
scatter_handle = scatter(layout_coords(:, 1), layout_coords(:, 2), ...
    node_sizes, node_colors, 'filled', ...
    'MarkerEdgeColor', 'k', ...
    'LineWidth', 1.5, ...
    'DisplayName', '节点');

% 5.3 高亮孤立节点
if opts.HighlightIsolatedNodes && n_isolated > 0
    scatter(layout_coords(isolated_nodes, 1), layout_coords(isolated_nodes, 2), ...
        node_sizes(isolated_nodes) * 1.2, ...  % 稍大一点
        [1, 0.8, 0], ...  % 黄色
        'o', 'LineWidth', 2, ...
        'MarkerEdgeColor', [0.8, 0.4, 0], ...  % 橙色边框
        'DisplayName', '孤立节点');
end

% 5.4 添加节点标签
if opts.ShowNodeLabels
    text_handles = cell(n_nodes, 1);
    for i = 1:n_nodes
        % 计算标签偏移，避免覆盖节点
        offset_x = double(node_sizes(i)) / 500;  % 确保为double
        offset_y = double(node_sizes(i)) / 500;  % 确保为double
        
        % 确保坐标是double类型
        x_coord = double(layout_coords(i, 1)) + offset_x;
        y_coord = double(layout_coords(i, 2)) + offset_y;
        
        text_handles{i} = text(x_coord, y_coord, ...
            node_labels{i}, ...
            'FontSize', opts.LabelFontSize, ...
            'FontWeight', 'normal', ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'Interpreter', 'none', ...
            'BackgroundColor', [1, 1, 1, 0.7], ...  % 半透明背景
            'Margin', 1, ...
            'EdgeColor', 'none');
    end
end

%% 6. 图形美化和标注
if opts.Verbose
    fprintf('添加图形标注...\n');
end

% 6.1 设置坐标轴
axis equal;
axis off;
box off;
grid off;

% 添加标题
title(opts.FigureTitle, 'FontSize', 14, 'FontWeight', 'bold');

% 6.2 添加图例
legend_items = {'节点'};
if opts.HighlightIsolatedNodes && n_isolated > 0
    legend_items{end+1} = '孤立节点';
end
if has_weights
    legend_items{end+1} = '边(权重)';
end

if length(legend_items) > 1
    legend(legend_items, 'Location', 'best', 'FontSize', 9);
end

% 6.3 添加颜色说明
if ischar(opts.NodeColor) && strcmp(opts.NodeColor, 'type')
    annotation('textbox', [0.02, 0.02, 0.2, 0.1], ...
        'String', {'颜色说明:', '蓝色: ret节点', '红色: OBV节点', '灰色: 其他'}, ...
        'FontSize', 8, ...
        'BackgroundColor', [1, 1, 1, 0.8], ...
        'EdgeColor', 'none', ...
        'FitBoxToText', 'on');
end

% 6.4 添加统计信息框 (修复了类型转换问题)
% 确保所有数值都是double类型
network_density = double(sum(adj_matrix(:)) / (n_nodes * (n_nodes - 1)));

summary_text = sprintf(['网络统计:\n' ...
    '节点数: %d\n' ...
    '边数: %d\n' ...
    '网络密度: %.4f\n' ...
    '孤立节点: %d\n' ...
    '最大节点度: %d\n' ...
    '布局算法: %s'], ...
    n_nodes, sum(adj_matrix(:)), ...
    network_density, ...
    n_isolated, max(node_degrees), opts.Layout);

% 确保annotation位置是double
annotation_pos = [0.75, 0.02, 0.23, 0.15];
annotation_pos = double(annotation_pos);

annotation('textbox', annotation_pos, ...
    'String', summary_text, ...
    'FontSize', 9, ...
    'BackgroundColor', [1, 1, 1, 0.9], ...
    'EdgeColor', [0.3, 0.3, 0.3], ...
    'LineWidth', 1, ...
    'FitBoxToText', 'on');

%% 7. 生成统计摘要
summary_stats = struct();
summary_stats.n_nodes = n_nodes;
summary_stats.n_edges = sum(adj_matrix(:));
summary_stats.network_density = network_density; % 使用double类型
summary_stats.n_isolated_nodes = n_isolated;
summary_stats.max_degree = max(node_degrees);
summary_stats.min_degree = min(node_degrees);
summary_stats.mean_degree = mean(node_degrees);
summary_stats.layout_algorithm = opts.Layout;
summary_stats.color_scheme = color_scheme;
summary_stats.has_weights = has_weights;

% 如果有权重，添加权重统计
if has_weights
    summary_stats.weight_mean = mean(edge_weights);
    summary_stats.weight_std = std(edge_weights);
    summary_stats.weight_min = min(edge_weights);
    summary_stats.weight_max = max(edge_weights);
end

%% 8. 保存图形
if opts.SaveFigure
    if opts.Verbose
        fprintf('保存图形到: %s\n', opts.SavePath);
    end
    
    [save_dir, save_name, save_ext] = fileparts(opts.SavePath);
    
    % 确保目录存在
    if ~isempty(save_dir) && ~exist(save_dir, 'dir')
        mkdir(save_dir);
    end
    
    % 根据扩展名选择保存格式
    if isempty(save_ext)
        save_ext = '.png';
        opts.SavePath = [opts.SavePath, save_ext];
    end
    
    save_format = save_ext(2:end);  % 去掉点号
    
    try
        saveas(fig_handle, opts.SavePath, save_format);
        
        % 对于位图格式，设置DPI
        if ismember(lower(save_format), {'png', 'jpg', 'jpeg', 'tiff'})
            print(fig_handle, opts.SavePath, ['-d' save_format], ['-r' num2str(opts.Dpi)]);
        end
        
        if opts.Verbose
            fprintf('  保存成功: %s\n', opts.SavePath);
        end
        
        summary_stats.saved_path = opts.SavePath;
        summary_stats.saved_format = save_format;
        summary_stats.saved_dpi = opts.Dpi;
        
    catch ME
        warning(ME.identifier, ' 保存图形失败： %s', ME.message)
        summary_stats.save_error = ME.message;
    end
end

%% 9. 完成
elapsed_time = toc(start_time);
if opts.Verbose
    fprintf('\n图形生成完成!\n');
    fprintf('生成时间: %.2f 秒\n', elapsed_time);
    fprintf('节点数: %d, 边数: %d\n', n_nodes, sum(adj_matrix(:)));
    
    if n_isolated > 0
        fprintf('发现 %d 个孤立节点\n', n_isolated);
    end
    
    fprintf('========================================\n\n');
end

summary_stats.generation_time = elapsed_time;
summary_stats.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

end

%% ==================== 辅助函数 ====================

function coords = layered_layout_custom(G, node_labels)
% 自定义分层布局
    n_nodes = numnodes(G);
    
    % 根据节点类型分配层
    layers = zeros(n_nodes, 1);
    for i = 1:n_nodes
        label = node_labels{i};
        if contains(label, 'ret')
            layers(i) = 1;  % ret节点在第一层
        elseif contains(label, 'OBV') || contains(label, 'obv')
            layers(i) = 2;  % obv节点在第二层
        else
            layers(i) = 3;  % 其他在第三层
        end
    end
    
    % 计算x坐标（在层内均匀分布）
    unique_layers = unique(layers);
    n_layers = length(unique_layers);
    
    coords = zeros(n_nodes, 2);
    for l = 1:n_layers
        layer_idx = find(layers == unique_layers(l));
        n_in_layer = length(layer_idx);
        
        % y坐标由层决定
        y_coord = (n_layers - l) * 2;  % 从顶部开始
        
        % x坐标在层内均匀分布
        if n_in_layer > 1
            x_coords = linspace(-1, 1, n_in_layer);
        else
            x_coords = 0;
        end
        
        for i = 1:n_in_layer
            coords(layer_idx(i), :) = [x_coords(i), y_coord];
        end
    end
end

function coords = subspace_layout_custom(node_labels, adj_matrix)
% 子空间布局：将ret和obv节点分别聚类
    n_nodes = length(node_labels);
    
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
    
    coords = zeros(n_nodes, 2);
    
    % ret节点放在左侧
    n_ret = length(ret_indices);
    if n_ret > 0
        if n_ret == 1
            coords(ret_indices, :) = [-2, 0];
        else
            angles = linspace(0, 2*pi, n_ret+1);
            angles = angles(1:end-1);
            radius = 1.5;
            coords(ret_indices, 1) = -2 + radius * cos(angles)';
            coords(ret_indices, 2) = radius * sin(angles)';
        end
    end
    
    % obv节点放在右侧
    n_obv = length(obv_indices);
    if n_obv > 0
        if n_obv == 1
            coords(obv_indices, :) = [2, 0];
        else
            angles = linspace(0, 2*pi, n_obv+1);
            angles = angles(1:end-1);
            radius = 1.5;
            coords(obv_indices, 1) = 2 + radius * cos(angles)';
            coords(obv_indices, 2) = radius * sin(angles)';
        end
    end
    
    % 其他节点放在中间
    n_other = length(other_indices);
    if n_other > 0
        if n_other == 1
            coords(other_indices, :) = [0, 0];
        else
            angles = linspace(0, 2*pi, n_other+1);
            angles = angles(1:end-1);
            radius = 0.8;
            coords(other_indices, 1) = radius * cos(angles)';
            coords(other_indices, 2) = radius * sin(angles)';
        end
    end
end

function rgb = colorstr2rgb(color_str)
% 颜色字符串转RGB
    color_str = lower(color_str);
    
    switch color_str
        case 'red'
            rgb = [1, 0, 0];
        case 'green'
            rgb = [0, 1, 0];
        case 'blue'
            rgb = [0, 0, 1];
        case 'cyan'
            rgb = [0, 1, 1];
        case 'magenta'
            rgb = [1, 0, 1];
        case 'yellow'
            rgb = [1, 1, 0];
        case 'black'
            rgb = [0, 0, 0];
        case 'white'
            rgb = [1, 1, 1];
        case 'gray'
            rgb = [0.5, 0.5, 0.5];
        otherwise
            rgb = [0.2, 0.4, 0.8];  % 默认蓝色
    end
end

function str = bool2str(bool_val)
% 逻辑值转字符串
    if bool_val
        str = '是';
    else
        str = '否';
    end
end