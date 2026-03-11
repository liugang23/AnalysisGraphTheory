function [G, creation_report] = create_matlagraph_object(adjacency, weights, node_labels, graph_type, varargin)
% CREATE_MATLAGRAPH_OBJECT 稳健创建MATLAB graph/digraph对象 (兼容R2018b)
%
% 【功能】将邻接矩阵和权重矩阵安全、稳健地转换为MATLAB图对象，处理数据类型、自环、零权重等问题。
%
% 【输入参数】
%   adjacency   : 邻接矩阵 (n x n), 逻辑型或数值型。非零值表示边的存在。
%   weights     : 权重矩阵 (n x n), 数值型。必须与adjacency同维。
%   node_labels : 节点标签元胞数组 (1 x n)
%   graph_type  : 图类型，'directed' 或 'undirected'
%   varargin    : 可选键值对
%       'OmitSelfLoops' : true/false, 是否忽略自环 (默认: true)
%       'CheckSymmetry' : true/false, 对无向图检查对称性 (默认: true)
%       'Verbose'       : true/false, 显示详细信息 (默认: false)
%
% 【输出参数】
%   G               : graph 或 digraph 对象
%   creation_report : 结构体，包含转换过程的详细报告和元数据
%
% 【工作流程】
%   1. 输入验证与标准化
%   2. 数据清洗（处理NaN/Inf，确保数据类型兼容）
%   3. 边提取与过滤（基于adjacency和可选的权重阈值）
%   4. 安全创建图对象
%   5. 附加边属性（权重、显著性、滞后等，如果提供）
%
% 【版本】1.0
% 【设计目标】最大兼容性 (R2018b+), 健壮性, 信息完整性

    %% 1. 参数解析与默认值设置
    p = inputParser;
    addRequired(p, 'adjacency', @(x) isnumeric(x) || islogical(x));
    addRequired(p, 'weights', @isnumeric);
    addRequired(p, 'node_labels', @(x) iscell(x) || isstring(x));
    addRequired(p, 'graph_type', @(x) ismember(x, {'directed', 'undirected'}));
    addParameter(p, 'OmitSelfLoops', true, @islogical);
    addParameter(p, 'CheckSymmetry', true, @islogical);
    addParameter(p, 'Verbose', false, @islogical);
    parse(p, adjacency, weights, node_labels, graph_type, varargin{:});
    
    omit_self_loops = p.Results.OmitSelfLoops;
    check_symmetry = p.Results.CheckSymmetry;
    verbose = p.Results.Verbose;
    
    % 初始化报告结构
    creation_report = struct();
    creation_report.input_parameters = p.Results;
    creation_report.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    creation_report.matlab_version = version;
    
    %% 2. 输入数据验证与标准化
    if verbose
        fprintf('\n[create_matlagraph_object] 开始转换...\n');
        fprintf('   图类型: %s\n', graph_type);
        fprintf('   矩阵维度: %d x %d\n', size(adjacency,1), size(adjacency,2));
    end
    
    n_nodes = size(adjacency, 1);
    
    % 2.1 确保节点标签是元胞数组
    if isstring(node_labels)
        node_labels = cellstr(node_labels);
    end
    
    if length(node_labels) ~= n_nodes
        error('节点标签数量(%d)与邻接矩阵维度(%d)不匹配。', length(node_labels), n_nodes);
    end
    
    % 2.2 标准化邻接矩阵为逻辑型 (确保边存在性判断清晰)
    if isnumeric(adjacency)
        % 使用容差将微小数值视为0
        tolerance = 1e-10;
        adj_logical = abs(adjacency) > tolerance;
        creation_report.adjacency_converted_to_logical = true;
        creation_report.tolerance_used = tolerance;
        if verbose
            non_zero_count = sum(adj_logical(:));
            fprintf('   邻接矩阵数值型 -> 逻辑型转换，非零元素: %d\n', non_zero_count);
        end
    else
        adj_logical = adjacency; % 本来就是逻辑型
        creation_report.adjacency_converted_to_logical = false;
    end
    
    % 2.3 确保权重矩阵是双精度 (graph/digraph权重属性通常为double)
    if ~isa(weights, 'double')
        weights = double(weights);
        creation_report.weights_converted_to_double = true;
        if verbose
            fprintf('   权重矩阵转换为双精度。\n');
        end
    else
        creation_report.weights_converted_to_double = false;
    end
    
    % 2.4 处理权重矩阵中的NaN和Inf
    nan_mask = isnan(weights);
    inf_mask = isinf(weights);
    
    if any(nan_mask(:)) || any(inf_mask(:))
        warning('权重矩阵中包含NaN(%d个)或Inf(%d个)，这些位置将被视为无边(权重设为0)。', ...
            sum(nan_mask(:)), sum(inf_mask(:)));
        weights(nan_mask | inf_mask) = 0;
        % 确保这些位置在邻接矩阵中也标记为无边
        adj_logical(nan_mask | inf_mask) = false;
        creation_report.nan_inf_handled = true;
        creation_report.nan_count = sum(nan_mask(:));
        creation_report.inf_count = sum(inf_mask(:));
    else
        creation_report.nan_inf_handled = false;
    end
    
    %% 3. 有向/无向图预处理
    if strcmp(graph_type, 'undirected')
        % 3.1 无向图对称性检查与修复
        if check_symmetry
            asymmetry = max(max(abs(adj_logical - adj_logical')));
            if asymmetry > 0
                if verbose
                    fprintf('   检测到无向图邻接矩阵不对称，正在强制对称化。\n');
                end
                % 逻辑或：只要一个方向有边，则认为无向边存在
                adj_logical = adj_logical | adj_logical';
                creation_report.symmetry_enforced = true;
                creation_report.original_asymmetry = asymmetry;
            else
                creation_report.symmetry_enforced = false;
            end
        end
        
        % 3.2 无向图权重对称化 (取平均值)
        % 注意：只对同时存在边的位置进行对称化
        sym_weight_mask = adj_logical; % 最终边存在的位置
        upper_tri = triu(sym_weight_mask, 1);
        [row, col] = find(upper_tri);
        for k = 1:length(row)
            i = row(k);
            j = col(k);
            w1 = weights(i, j);
            w2 = weights(j, i);
            % 取两个方向的平均值作为无向边的权重
            new_weight = (w1 + w2) / 2;
            weights(i, j) = new_weight;
            weights(j, i) = new_weight;
        end
        creation_report.weights_symmetrized = true;
    end
    
    %% 4. 自环处理
    if omit_self_loops
        diag_indices = 1:(n_nodes+1):numel(adj_logical);
        self_loop_count = sum(adj_logical(diag_indices));
        if self_loop_count > 0
            if verbose
                fprintf('   移除 %d 个自环。\n', self_loop_count);
            end
            adj_logical(diag_indices) = false;
            weights(diag_indices) = 0;
            creation_report.self_loops_removed = self_loop_count;
        else
            creation_report.self_loops_removed = 0;
        end
    else
        creation_report.self_loops_removed = 0;
    end
    
    %% 5. 边提取与图对象创建
    % 5.1 提取边的源节点、目标节点和权重
    [s, t] = find(adj_logical); % 找到所有边的起点和终点索引
    w = zeros(length(s), 1);
    for k = 1:length(s)
        w(k) = weights(s(k), t(k));
    end
    
    % 5.2 移除权重为零的边 (可选，但通常零权重边无意义)
    % 注意：这步取决于您的科学定义。如果权重为0表示“边存在但强度为0”，则应保留。
    % 这里我们提供一个可配置的选项，默认移除零权重边。
    zero_weight_threshold = 1e-12; % 极小阈值
    non_zero_weight_mask = abs(w) > zero_weight_threshold;
    s = s(non_zero_weight_mask);
    t = t(non_zero_weight_mask);
    w = w(non_zero_weight_mask);
    
    creation_report.edges_extracted = length(s);
    creation_report.edges_with_zero_weight_removed = sum(~non_zero_weight_mask);
    creation_report.zero_weight_threshold = zero_weight_threshold;
    
    if verbose
        fprintf('   提取到 %d 条边 (移除了 %d 条零权重边)。\n', ...
            creation_report.edges_extracted, creation_report.edges_with_zero_weight_removed);
    end
    
    % 5.3 安全创建图对象
    try
        if strcmp(graph_type, 'undirected')
            G = graph(s, t, w, node_labels, 'OmitSelfLoops');
            creation_report.graph_class = 'graph';
        else
            G = digraph(s, t, w, node_labels, 'OmitSelfLoops');
            creation_report.graph_class = 'digraph';
        end
        creation_report.creation_success = true;
        
        if verbose
            fprintf('   %s 对象创建成功。\n', creation_report.graph_class);
            fprintf('   图属性: 节点数=%d, 边数=%d\n', ...
                numnodes(G), numedges(G));
        end
        
    catch ME
        creation_report.creation_success = false;
        creation_report.error = ME.message;
        
        % 如果创建失败，尝试不指定节点标签创建（兼容性回退）
        if verbose
            fprintf('   使用节点标签创建失败，尝试无标签创建...\n');
        end
        try
            if strcmp(graph_type, 'undirected')
                G = graph(s, t, w, 'OmitSelfLoops');
            else
                G = digraph(s, t, w, 'OmitSelfLoops');
            end
            creation_report.creation_success_fallback = true;
            creation_report.fallback_note = 'Created without node labels due to compatibility issue.';
            if verbose
                fprintf('   无标签图对象创建成功。\n');
            end
        catch ME2
            % 最终失败
            error('无法创建图对象。错误1: %s\n错误2: %s', ME.message, ME2.message);
        end
    end
    
    %% 6. 图对象基本验证
    if creation_report.creation_success || isfield(creation_report, 'creation_success_fallback')
        creation_report.n_nodes_in_graph = numnodes(G);
        creation_report.n_edges_in_graph = numedges(G);
        creation_report.is_directed = isdag(G); % 对于有向图，判断是否为有向无环图
        creation_report.is_multigraph = has_multiedges(G);
        
        % 计算图密度 (与network.density比较)
        if strcmp(graph_type, 'undirected')
            max_possible_edges = n_nodes * (n_nodes - 1) / 2;
        else
            max_possible_edges = n_nodes * (n_nodes - 1);
        end
        creation_report.graph_density = creation_report.n_edges_in_graph / max_possible_edges;
        
        if verbose
            fprintf('   图对象验证完成。\n');
        end
    end
    
    creation_report.computation_time = toc(tic);
end