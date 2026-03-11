function [is_valid, validation_report] = validate_network_structure(pair_network, varargin)
% VALIDATE_NETWORK_STRUCTURE 网络构建结果基础验证
% 
% 【功能定位】
% 在网络构建完成后、网络拓扑分析开始前，对网络构建结果进行数据质量验证。
% 这是一个质量控制关卡，旨在发现网络构建算法中的BUG、数据结构问题、数值异常等。
%
% 【验证范围】- 仅验证网络结构本身，不进行拓扑分析
% 1. 数据结构完整性验证
% 2. 数值合理性验证（范围、类型）
% 3. 维度一致性验证
% 4. 基本逻辑验证（避免明显错误）
%
% 【输入参数】
%   pair_network: 网络构建结果结构体
%   varargin: 可选参数
%       'validation_level': 验证级别
%           - 'basic'    : 仅验证必需字段和维度 (默认)
%           - 'standard' : 基本验证 + 数值合理性检查
%           - 'strict'   : 严格验证，包含完整一致性检查
%       'source_data_info': 原始数据信息结构体（可选）
%           - n_nodes_expected: 期望的节点数
%           - var_names: 变量名列表
%       'verbose': 是否显示详细验证信息 (默认: false)
%
% 【输出参数】
%   is_valid: 布尔值，验证是否通过
%   validation_report: 结构体，包含详细验证结果
%       - passed_checks: 通过的检查项
%       - failed_checks: 失败的检查项
%       - warnings: 警告信息
%       - basic_stats: 网络基本统计
%       - validation_time: 验证时间
%
% 【验证内容】
% 级别1 (basic): 必需字段、矩阵维度、节点标签一致性
% 级别2 (standard): 权重范围、自环检查、对称性检查
% 级别3 (strict): 与源数据一致性、NaN值检查、孤立节点检查
%
% 【调用示例】
%   % 基本验证
%   [is_valid, report] = validate_network_structure(pair_network);
%   
%   % 标准验证（推荐）
%   [is_ok, report] = validate_network_structure(pair_network, ...
%    'validation_level', 'standard', ...
%    'verbose', true);
%
%   % 带原始数据信息的严格验证
%   source_info.n_nodes_expected = 50;
%   source_info.var_names = {'ret_5', 'OBV_20', ...};
%   [is_valid, report] = validate_network_structure(pair_network, ...
%       'validation_level', 'strict', ...
%       'source_data_info', source_info, ...
%       'verbose', true);

%% 1. 参数解析
p = inputParser;
addRequired(p, 'pair_network', @(x) isstruct(x) || isempty(x));
addParameter(p, 'validation_level', 'basic', ...
    @(x) ismember(x, {'basic', 'standard', 'strict'}));
addParameter(p, 'source_data_info', struct(), @isstruct);
addParameter(p, 'verbose', false, @islogical);
parse(p, pair_network, varargin{:});

validation_level = p.Results.validation_level;
source_info = p.Results.source_data_info;
verbose = p.Results.verbose;

%% 2. 初始化验证结果
is_valid = false;
validation_report = struct();
validation_report.validation_level = validation_level;
validation_report.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
validation_report.passed_checks = {};
validation_report.failed_checks = {};
validation_report.warnings = {};

start_time = tic;

%% 3. 级别1：基本结构验证 (所有级别都执行)
% 3.1 检查是否为结构体
if ~isstruct(pair_network)
    validation_report.failed_checks{end+1} = '输入不是结构体';
    validation_report.validation_time = toc(start_time);
    if verbose, fprintf('? 验证失败: 输入不是结构体\n'); end
    return;
end
validation_report.passed_checks{end+1} = '输入是有效的结构体';

% 3.2 检查必需字段
required_fields_basic = {
    'adjacency', ...   % 邻接矩阵 (必需)
    'node_labels', ... % 节点标签 (必需)
    'n_nodes'       % 节点数量 (必需)
};

% 可选字段（某些网络类型可能没有）
optional_fields = {
    'weights', ...     % 权重矩阵
    'edge_weights', ...% 边权重（替代weights）
    'edge_labels', ... % 边标签
    'edge_directions', ...% 边方向
    'pair_indices', ...% 配对索引
    'density', ...     % 网络密度
    'is_directed', ... % 是否有向
    'creation_time' % 创建时间
};

missing_required = {};
for i = 1:length(required_fields_basic)
    if ~isfield(pair_network, required_fields_basic{i})
        missing_required{end+1} = required_fields_basic{i};
    end
end

if ~isempty(missing_required)
    validation_report.failed_checks{end+1} = ...
        sprintf('缺少必需字段: %s', strjoin(missing_required, ', '));
    validation_report.validation_time = toc(start_time);
    if verbose
        fprintf('? 验证失败: 缺少必需字段: %s\n', strjoin(missing_required, ', '));
    end
    return;
end
validation_report.passed_checks{end+1} = '所有必需字段存在';

% 3.3 检查节点数量一致性
n_nodes = pair_network.n_nodes;
if ~isnumeric(n_nodes) || ~isscalar(n_nodes) || n_nodes <= 0
    validation_report.failed_checks{end+1} = ...
        sprintf('n_nodes无效: 必须是正标量，当前: %s', mat2str(n_nodes));
    validation_report.validation_time = toc(start_time);
    if verbose, fprintf('? 验证失败: n_nodes无效\n'); end
    return;
end
validation_report.passed_checks{end+1} = sprintf('n_nodes有效: %d', n_nodes);

% 3.4 检查邻接矩阵维度
adj = pair_network.adjacency;
if ~ismatrix(adj) || size(adj, 1) ~= size(adj, 2)
    validation_report.failed_checks{end+1} = ...
        sprintf('邻接矩阵不是方阵: %dx%d', size(adj,1), size(adj,2));
    validation_report.validation_time = toc(start_time);
    if verbose, fprintf('? 验证失败: 邻接矩阵不是方阵\n'); end
    return;
end

if size(adj, 1) ~= n_nodes
    validation_report.failed_checks{end+1} = ...
        sprintf('邻接矩阵维度不匹配: %dx%d, 期望: %dx%d', ...
        size(adj,1), size(adj,2), n_nodes, n_nodes);
    validation_report.validation_time = toc(start_time);
    if verbose, fprintf('? 验证失败: 邻接矩阵维度不匹配\n'); end
    return;
end
validation_report.passed_checks{end+1} = '邻接矩阵维度正确';

% 3.5 检查节点标签
node_labels = pair_network.node_labels;
if ~iscell(node_labels) && ~isstring(node_labels) && ~ischar(node_labels)
    validation_report.failed_checks{end+1} = ...
        'node_labels必须是元胞数组、字符串数组或字符数组';
    validation_report.validation_time = toc(start_time);
    if verbose, fprintf('? 验证失败: node_labels类型无效\n'); end
    return;
end

if length(node_labels) ~= n_nodes
    validation_report.failed_checks{end+1} = ...
        sprintf('节点标签数量不匹配: %d, 期望: %d', length(node_labels), n_nodes);
    validation_report.validation_time = toc(start_time);
    if verbose, fprintf('? 验证失败: 节点标签数量不匹配\n'); end
    return;
end
validation_report.passed_checks{end+1} = '节点标签数量正确';

%% 4. 级别2：数值合理性验证 (standard和strict级别)
if any(strcmp(validation_level, {'standard', 'strict'}))
    % 4.1 检查邻接矩阵值域
    if ~islogical(adj) && ~isnumeric(adj)
        validation_report.failed_checks{end+1} = ...
            '邻接矩阵必须是逻辑型或数值型';
    elseif isnumeric(adj)
        % 检查数值范围
        min_val = min(adj(:));
        max_val = max(adj(:));
        
        if min_val < 0
            validation_report.warnings{end+1} = ...
                sprintf('邻接矩阵包含负值: min=%.4f', min_val);
        end
        
        if max_val > 1 && ~all(adj(:) == 0 | adj(:) == 1)
            validation_report.warnings{end+1} = ...
                sprintf('邻接矩阵值超出[0,1]范围: max=%.4f', max_val);
        end
        
        validation_report.passed_checks{end+1} = ...
            sprintf('邻接矩阵值域检查: [%.4f, %.4f]', min_val, max_val);
    end
    
    % 4.2 检查自环（对角线元素）
    diag_vals = diag(adj);
    if any(diag_vals ~= 0)
        self_loop_count = sum(diag_vals ~= 0);
        validation_report.warnings{end+1} = ...
            sprintf('发现 %d 个自环（节点连接到自身）', self_loop_count);
    end
    
    % 4.3 检查权重矩阵（如果存在）
    if isfield(pair_network, 'weights')
        weights = pair_network.weights;
        
        % 检查维度
        if ~isequal(size(weights), size(adj))
            validation_report.failed_checks{end+1} = ...
                '权重矩阵与邻接矩阵维度不一致';
        end
        
        % 检查NaN和Inf
        nan_count = sum(isnan(weights(:)));
        inf_count = sum(isinf(weights(:)));
        
        if nan_count > 0
            validation_report.warnings{end+1} = ...
                sprintf('权重矩阵包含 %d 个NaN值', nan_count);
        end
        if inf_count > 0
            validation_report.warnings{end+1} = ...
                sprintf('权重矩阵包含 %d 个Inf值', inf_count);
        end
        
        if nan_count == 0 && inf_count == 0
            validation_report.passed_checks{end+1} = '权重矩阵无NaN/Inf值';
        end
        
        % 检查权重与邻接矩阵的一致性
        if isnumeric(adj)
            % 使用容差比较
            tolerance = 1e-10;

            % 对于加权网络，检查非零权重对应非零邻接
            non_zero_adj = adj ~= 0;
            non_zero_weights = abs(weights) > tolerance;  % 使用容差

            if ~isequal(non_zero_weights, non_zero_adj)
                mismatch_count = sum(non_zero_weights(:) ~= non_zero_adj(:));

                % 详细检查不匹配位置
                mismatch_indices = find(non_zero_weights ~= non_zero_adj);
                if ~isempty(mismatch_indices)
                    fprintf('\n? 权重/邻接矩阵不匹配详细检查:\n');
                    for i = 1:min(5, length(mismatch_indices))
                        [row, col] = ind2sub(size(adj), mismatch_indices(i));
                        fprintf('  位置(%d,%d): adj=%.6f, weight=%.6e\n', ...
                            row, col, adj(row,col), weights(row,col));
                    end
                end

                validation_report.warnings{end+1} = ...
                    sprintf('权重与邻接矩阵不匹配: %d 个位置不一致', mismatch_count);
            end
        end
    end
    
    % 4.4 检查网络密度（如果存在）
    % 4.4 检查网络密度（如果存在）
    if isfield(pair_network, 'density')
        density = pair_network.density;
        if density < 0 || density > 1
            validation_report.warnings{end+1} = ...
                sprintf('网络密度异常: %.4f (应在[0,1]范围内)', density);
        end
        
        % 验证计算是否准确
        if isfield(pair_network, 'adjacency')
            % 确定网络类型
            if isfield(pair_network, 'analysis_type')
                analysis_type = pair_network.analysis_type;
            elseif isfield(pair_network, 'graph_type')
                if strcmp(pair_network.graph_type, 'undirected')
                    analysis_type = 'correlation';
                else
                    analysis_type = 'granger';
                end
            else
                % 默认有向图
                analysis_type = 'granger';
            end
            
            actual_edges = sum(adj(:) ~= 0);
            
            % 根据网络类型计算最大可能边数
            if strcmp(analysis_type, 'correlation')
                % 无向图
                max_possible_edges = n_nodes * (n_nodes - 1) / 2;
                % 无向图的实际边数是连接数的一半
                actual_edges_for_density = actual_edges / 2;
            else
                % 有向图
                max_possible_edges = n_nodes * (n_nodes - 1);
                actual_edges_for_density = actual_edges;
            end
            
            if max_possible_edges > 0
                calculated_density = actual_edges_for_density / max_possible_edges;
                
                % 1. 统一精度到12位小数，避免浮点数精度问题
                precision = 1e12;  % 12位精度
                stored_density_rounded = round(density * precision) / precision;
                recalculated_density_rounded = round(calculated_density * precision) / precision;
                
                % 2. 比较精度
                rounded_diff = abs(stored_density_rounded - recalculated_density_rounded);
                original_diff = abs(density - calculated_density);
                
                % 3. 判断标准
                tolerance_strict = 1e-12;     % 严格容差
                tolerance_relaxed = 1e-6;     % 宽松容差
                
                if original_diff > tolerance_relaxed && rounded_diff > tolerance_strict
                    % 真正的不一致
                    validation_report.warnings{end+1} = ...
                        sprintf('网络密度计算不一致: 存储=%.12f, 计算=%.12f, 差异=%.2e', ...
                        density, calculated_density, original_diff);
                    
                    % 添加详细信息
                    validation_report.density_debug = struct(...
                        'network_type', analysis_type, ...
                        'n_nodes', n_nodes, ...
                        'actual_connections', actual_edges, ...
                        'actual_edges_for_density', actual_edges_for_density, ...
                        'max_possible_edges', max_possible_edges, ...
                        'stored_density', density, ...
                        'calculated_density', calculated_density, ...
                        'original_diff', original_diff, ...
                        'rounded_diff', rounded_diff, ...
                        'is_significant', true);
                    
                elseif original_diff > 1e-10 && original_diff <= tolerance_relaxed
                    % 微小差异，很可能是浮点数精度问题
                    if verbose
                        fprintf('? 注意: 密度有微小差异 %.2e (浮点数精度)\n', original_diff);
                        fprintf('   存储值: %.15f\n', density);
                        fprintf('   计算值: %.15f\n', calculated_density);
                    end
                    
                    % 记录但不报错
                    validation_report.consistency_notes.density_precision_issue = true;
                    validation_report.consistency_notes.density_original_diff = original_diff;
                    
                else
                    % 完全一致
                    if verbose
                        fprintf('? 密度计算完全一致: %.12f\n', density);
                    end
                end
            end
        end
    end
end

%% 5. 级别3：严格验证 (strict级别)
if strcmp(validation_level, 'strict')
    % 5.1 与源数据一致性检查
    if isfield(source_info, 'n_nodes_expected')
        if n_nodes ~= source_info.n_nodes_expected
            validation_report.warnings{end+1} = ...
                sprintf('节点数量与源数据不匹配: 网络=%d, 源数据=%d', ...
                n_nodes, source_info.n_nodes_expected);
        end
    end
    
    if isfield(source_info, 'var_names')
        source_vars = source_info.var_names;
        if length(node_labels) == length(source_vars)
            % 检查标签是否匹配
            if iscell(node_labels)
                match_count = sum(strcmp(node_labels(:), source_vars(:)));
            else
                match_count = sum(string(node_labels(:)) == string(source_vars(:)));
            end
            
            if match_count < length(node_labels)
                validation_report.warnings{end+1} = ...
                    sprintf('节点标签与源变量名部分不匹配: %d/%d 匹配', ...
                    match_count, length(node_labels));
            end
        end
    end
    
    % 5.2 孤立节点检查
    if isfield(pair_network, 'adjacency')
        node_degrees = sum(adj ~= 0, 1) + sum(adj ~= 0, 2)';  % 入度+出度
        isolated_nodes = find(node_degrees == 0);
        
        if ~isempty(isolated_nodes)
            validation_report.warnings{end+1} = ...
                sprintf('发现 %d 个孤立节点（无连接）', length(isolated_nodes));
        end
    end
    
    % 5.3 对称性检查（如果是无向图）
    if isfield(pair_network, 'is_directed')
        if ~pair_network.is_directed
            % 无向图应该对称
            if ~issymmetric(adj)
                asymm = sum(sum(abs(adj - adj')));
                validation_report.warnings{end+1} = ...
                    sprintf('无向图不对称: 不对称度=%.4f', asymm);
            end
        end
    else
        % 尝试推断是否无向
        if issymmetric(adj)
            validation_report.passed_checks{end+1} = '邻接矩阵对称（推断为无向图）';
        end
    end
end

%% 6. 生成基本统计信息
validation_report.basic_stats = struct();
validation_report.basic_stats.n_nodes = n_nodes;

if isfield(pair_network, 'adjacency')
    adj_nonzero = adj ~= 0;
    validation_report.basic_stats.n_edges = sum(adj_nonzero(:));
    validation_report.basic_stats.edge_density = ...
        validation_report.basic_stats.n_edges / (n_nodes * n_nodes);
    
    % 如果是方阵且无自环
    validation_report.basic_stats.edge_density_no_self = ...
        validation_report.basic_stats.n_edges / (n_nodes * (n_nodes - 1));
end

if isfield(pair_network, 'weights')
    validation_report.basic_stats.weight_stats.mean = mean(pair_network.weights(:), 'omitnan');
    validation_report.basic_stats.weight_stats.std = std(pair_network.weights(:), 'omitnan');
    validation_report.basic_stats.weight_stats.min = min(pair_network.weights(:), [], 'omitnan');
    validation_report.basic_stats.weight_stats.max = max(pair_network.weights(:), [], 'omitnan');
end

%% 7. 确定最终验证结果
% 如果有任何failed_checks，验证不通过
if ~isempty(validation_report.failed_checks)
    is_valid = false;
    validation_report.overall_result = '验证失败';
    
    if verbose
        fprintf('? 验证失败:\n');
        for i = 1:length(validation_report.failed_checks)
            fprintf('   - %s\n', validation_report.failed_checks{i});
        end
    end
else
    is_valid = true;
    validation_report.overall_result = '验证通过';
    
    if verbose
        fprintf('? 验证通过 (级别: %s)\n', validation_level);
        fprintf('   节点数: %d, 边数: %d\n', ...
            validation_report.basic_stats.n_nodes, ...
            validation_report.basic_stats.n_edges);
        
        if ~isempty(validation_report.warnings)
            fprintf('   ??  警告:\n');
            for i = 1:length(validation_report.warnings)
                fprintf('     - %s\n', validation_report.warnings{i});
            end
        end
    end
end

%% 8. 记录验证时间
validation_report.validation_time = toc(start_time);

if verbose && validation_report.validation_time > 0.1
    fprintf('   验证耗时: %.3f 秒\n', validation_report.validation_time);
end

end