function [node_info, network_matrices, param_info, compute_stats] = network_construction_core(pairwise_results, pair_data, analysis_type, alpha)
% NETWORK_CONSTRUCTION_CORE - 网络构建核心模块
%
% 功能描述:
%   从配对连通性分析结果中提取节点信息，初始化网络矩阵，创建节点映射
%   这是网络构建的第一个阶段，主要负责数据结构准备
%
% 输入参数:
%   pairwise_results: 配对连通性分析结果结构体
%                    - pair_info: 配对信息元胞数组
%                    - connectivity: 连通性结果元胞数组
%   pair_data: 原始配对数据元胞数组
%   analysis_type: 分析类型 ('correlation', 'granger', 'all')
%   alpha: 显著性水平 (默认=0.05)
%
% 输出参数:
%   node_info: 节点信息结构体
%              - node_labels: 节点标签元胞数组
%              - node_index_map: 节点索引映射容器
%              - ret_nodes: 收益节点标签
%              - obv_nodes: OBV节点标签
%              - ret_indices: 收益节点索引
%              - obv_indices: OBV节点索引
%              - n_nodes: 总节点数
%   network_matrices: 网络矩阵结构体
%                     - adjacency: 邻接矩阵
%                     - weights: 权重矩阵
%                     - directions: 方向矩阵
%                     - lags: 滞后矩阵
%                     - significance: 显著性矩阵
%   param_info: 参数信息结构体
%               - n_pairs: 配对数量
%               - analysis_type: 分析类型
%               - alpha: 显著性水平
%               - min_corr: 最小相关系数阈值
%   compute_stats: 计算统计信息结构体
%               - 包含各阶段的计算详情和性能统计
%
% 工作流程:
%   1. 验证输入参数
%   2. 从配对数据中提取所有唯一节点
%   3. 创建节点标签和索引映射
%   4. 初始化网络矩阵
%
% 使用示例:
%   [node_info, matrices, params, stats] = network_construction_core(pairwise_results, pair_data, 'granger', 0.05);

    %% 1. 参数验证和准备
    fprintf('\n[模块1] 网络构建核心模块开始\n');
    fprintf('============================================================\n');
    start_time = tic;
    
    % 1.1 初始化计算统计结构
    compute_stats = struct();
    compute_stats.timings = struct(...
        'validation_start', tic, ...
        'validation_end', 0, ...
        'extraction_start', 0, ...
        'extraction_end', 0, ...
        'processing_start', 0, ...
        'processing_end', 0, ...
        'matrix_start', 0, ...
        'matrix_end', 0, ...
        'assembly_start', 0, ...
        'assembly_end', 0, ...
        'total_duration', 0);

    % 模块元信息
    compute_stats.module_info = struct(...
        'module_name', 'network_construction_core', ...
        'version', '1.0', ...
        'start_time', datetime('now'), ...
        'analysis_type', '', ...  % 稍后填充
        'significance_level', 0);

    % 分阶段统计容器
    compute_stats.validation = struct();
    compute_stats.extraction = struct();
    compute_stats.processing = struct();
    compute_stats.mapping = struct();
    compute_stats.matrix_init = struct();
    compute_stats.assembly = struct();
    compute_stats.node_info = struct();

    % 验证输入参数数量
    if nargin < 4
        error('错误: 需要4个输入参数，但只提供了 %d 个。', nargin);
    end

    % 验证analysis_type
    valid_analysis_types = {'correlation', 'granger', 'all'};
    analysis_type = lower(analysis_type);
    if ~ischar(analysis_type) || ~ismember(analysis_type, valid_analysis_types)
        error('错误: analysis_type必须是以下之一: %s', strjoin(valid_analysis_types, ', '));
    end

    % 验证alpha
    if ~isnumeric(alpha) || ~isscalar(alpha) || alpha <= 0 || alpha >= 1
        error('错误: alpha必须是0到1之间的标量，当前值: %.4f', alpha);
    end

    % 验证pairwise_results结构
    if ~isstruct(pairwise_results)
        error('错误: pairwise_results必须是结构体，当前类型: %s', class(pairwise_results));
    end

    required_fields = {'pair_info', 'connectivity'};
    missing_fields = {};
    for i = 1:length(required_fields)
        if ~isfield(pairwise_results, required_fields{i})
            missing_fields{end+1} = required_fields{i};
        end
    end
    if ~isempty(missing_fields)
        error('错误: pairwise_results缺少必需字段: %s', strjoin(missing_fields, ', '));
    end

    % 验证数据一致性
    n_pairs = length(pairwise_results.pair_info);
    if n_pairs == 0
        error('错误: pairwise_results.pair_info为空');
    end
    if length(pairwise_results.connectivity) ~= n_pairs
        error('错误: 配对数量和连通性结果数量不匹配: %d != %d', ...
            n_pairs, length(pairwise_results.connectivity));
    end

    % 设置最小相关性阈值
    if strcmp(analysis_type, 'correlation')
        min_corr = 0.3;
    else
        min_corr = 0;
    end
    
    % 记录验证统计
    validation_stats = struct();
    validation_stats.nargin_check = nargin;
    validation_stats.n_pairs = n_pairs;
    validation_stats.required_fields_missing = missing_fields;  % 即使为空也没问题
    validation_stats.analysis_type_valid = ismember(analysis_type, valid_analysis_types);
    validation_stats.alpha_valid = (isnumeric(alpha) && isscalar(alpha) && alpha > 0 && alpha < 1);
    validation_stats.pairwise_results_is_struct = isstruct(pairwise_results);
    validation_stats.data_consistency_check = (length(pairwise_results.connectivity) == n_pairs);
    validation_stats.min_corr = min_corr;
    validation_stats.status = 'passed';
    compute_stats.validation = validation_stats;
    compute_stats.timings.validation_end = toc(compute_stats.timings.validation_start);
    
    % 更新模块元信息
    compute_stats.module_info.analysis_type = analysis_type;
    compute_stats.module_info.significance_level = alpha;
    compute_stats.module_info.timestamp = datetime('now');

    % 创建参数信息结构
    param_info = struct();
    param_info.n_pairs = n_pairs;
    param_info.analysis_type = analysis_type;
    param_info.alpha = alpha;
    param_info.min_corr = min_corr;
    param_info.valid_analysis_types = valid_analysis_types;

    fprintf('输入验证通过:\n');
    fprintf('  - 配对数量: %d\n', n_pairs);
    fprintf('  - 分析类型: %s\n', upper(analysis_type));
    fprintf('  - 显著性水平: α = %.3f\n', alpha);
    if min_corr > 0
        fprintf('  - 最小相关系数阈值: %.2f\n', min_corr);
    end

    %% 2. 提取所有唯一节点
    fprintf('\n开始节点提取...\n');
    compute_stats.timings.extraction_start = tic;

    % 初始化节点集合
    all_ret_nodes = {};  % 存储收益节点名称
    all_obv_nodes = {};  % 存储OBV节点名称
    node_extraction_stats = struct(...
        'total_pairs_processed', 0, ...
        'invalid_structures', 0, ...
        'missing_fields', 0, ...
        'data_format', 'unknown');

    % 进度显示设置
    progress_interval = max(1, floor(n_pairs/20));
    fprintf('从配对信息中提取节点...\n');

    % 从pairwise_results.pair_info中提取节点信息
    for i = 1:n_pairs
        node_extraction_stats.total_pairs_processed = node_extraction_stats.total_pairs_processed + 1;

        % 显示进度
        if mod(i, progress_interval) == 0
            progress_percent = round(i/n_pairs*100);
            fprintf('\b\b\b\b%3d%%', progress_percent);
        end

        % 检查配对信息是否有效
        if isempty(pairwise_results.pair_info{i}) || ~isstruct(pairwise_results.pair_info{i})
            node_extraction_stats.invalid_structures = node_extraction_stats.invalid_structures + 1;
            continue;
        end

        current_info = pairwise_results.pair_info{i};

        % 提取收益节点名称
        if isfield(current_info, 'ret_name')
            ret_name = current_info.ret_name;
            if ~isempty(ret_name) && ischar(ret_name) && ~ismember(ret_name, all_ret_nodes)
                all_ret_nodes{end+1} = ret_name;
            end
        else
            node_extraction_stats.missing_fields = node_extraction_stats.missing_fields + 1;
        end

        % 提取OBV节点名称
        if isfield(current_info, 'obv_name')
            obv_name = current_info.obv_name;
            if ~isempty(obv_name) && ischar(obv_name) && ~ismember(obv_name, all_obv_nodes)
                all_obv_nodes{end+1} = obv_name;
            end
        else
            node_extraction_stats.missing_fields = node_extraction_stats.missing_fields + 1;
        end
    end

    fprintf('\b\b\b\b100%%\n');
    compute_stats.timings.extraction_end = toc(compute_stats.timings.extraction_start);

    % 记录提取统计
    compute_stats.extraction = struct(...
        'total_pairs_processed', n_pairs, ...
        'progress_interval', progress_interval, ...
        'ret_nodes_found', length(all_ret_nodes), ...
        'obv_nodes_found', length(all_obv_nodes), ...
        'total_nodes_found', length(all_ret_nodes) + length(all_obv_nodes), ...
        'node_extraction_stats', node_extraction_stats, ...
        'status', 'completed');

    % 检查是否找到节点
    if isempty(all_ret_nodes) && isempty(all_obv_nodes)
        error('错误: 未发现任何节点！可能原因:\n1. pairwise_results.pair_info 中没有节点名称信息\n2. 所有配对都被跳过');
    end

    % 合并所有节点
    node_labels = [all_ret_nodes, all_obv_nodes];
    n_nodes = length(node_labels);

    % 检查是否有重复节点
    unique_nodes = unique(node_labels);
    duplicate_count = length(node_labels) - length(unique_nodes);
    if duplicate_count > 0
        fprintf('?? 发现重复节点，正在进行去重...\n');
        fprintf('   去重前: %d 个节点\n', n_nodes);
        fprintf('   去重后: %d 个节点\n', length(unique_nodes));

        % 使用唯一节点
        node_labels = unique_nodes;
        n_nodes = length(unique_nodes);

        % 重新创建ret和obv节点列表
        all_ret_nodes = intersect(all_ret_nodes, unique_nodes, 'stable');
        all_obv_nodes = intersect(all_obv_nodes, unique_nodes, 'stable');
    end
    
    %% 2.5 对节点进行排序，确保索引顺序一致
    fprintf('对节点标签进行字母数字排序...\n');
    compute_stats.timings.processing_start = tic;
    
    % 对节点标签进行字母数字排序
    node_labels = sort(node_labels);  % sort函数默认按字典序排序

    % 更新去重后的ret和obv节点列表（按排序后的顺序）
    all_ret_nodes = intersect(all_ret_nodes, node_labels, 'sorted');
    all_obv_nodes = intersect(all_obv_nodes, node_labels, 'sorted');

    fprintf('   排序完成。示例节点: %s\n', strjoin(node_labels(1:min(5, n_nodes)), ', '));
    if n_nodes > 5
        fprintf('   ... 共 %d 个节点\n', n_nodes);
    end

    fprintf('节点提取完成:\n');
    fprintf('  - 发现的收益节点: %d\n', length(all_ret_nodes));
    fprintf('  - 发现的OBV节点: %d\n', length(all_obv_nodes));
    fprintf('  - 总节点数: %d\n', n_nodes);
    
    % 记录节点处理统计
    compute_stats.processing = struct(...
        'original_nodes_count', length([all_ret_nodes, all_obv_nodes]) + duplicate_count, ...
        'unique_nodes_count', length(unique_nodes), ...
        'duplicate_count', duplicate_count, ...
        'nodes_sorted', true, ...
        'sort_method', 'alphabetical', ...
        'duplicate_warning_issued', (duplicate_count > 0), ...
        'n_nodes', n_nodes, ...
        'status', 'completed');
    
    compute_stats.timings.processing_end = toc(compute_stats.timings.processing_start);
    
    %% 3. 创建节点索引映射
    fprintf('\n创建节点索引映射...\n');
    compute_stats.timings.mapping_start = tic;
    
    % 创建从节点名称到索引的映射
    node_index_map = containers.Map('KeyType', 'char', 'ValueType', 'double');

    % 由于节点已排序，索引顺序现在是确定且可复现的
    for i = 1:n_nodes
        node_name = node_labels{i};
        if isKey(node_index_map, node_name)
            % 由于前面已经去重和排序，这里理论上不应该再有重复
            warning('严重: 发现未预期的重复节点名称: %s', node_name);
        end
        node_index_map(node_name) = i;
    end

    % 验证映射完整性
    missing_nodes = {};
    for i = 1:n_nodes
        if ~isKey(node_index_map, node_labels{i})
            missing_nodes{end+1} = node_labels{i};
        end
    end
    
    compute_stats.mapping = struct(...
        'node_index_map_size', n_nodes, ...
        'mapping_entries_processed', n_nodes, ...
        'missing_nodes', missing_nodes, ...
        'missing_node_count', length(missing_nodes), ...
        'mapping_status', isempty(missing_nodes), ...
        'warnings_issued', false, ...
        'status', 'completed');

    if ~isempty(missing_nodes)
        compute_stats.mapping.warnings_issued = true;
        error('错误: 以下节点在映射中缺失: %s', strjoin(missing_nodes, ', '));
    else
        fprintf('  ? 所有节点映射成功\n');
    end
    compute_stats.timings.mapping_end = toc(compute_stats.timings.mapping_start);
    
    %% 4. 初始化网络矩阵
    fprintf('\n初始化网络矩阵...\n');
    fprintf('矩阵大小: %d × %d\n', n_nodes, n_nodes);
    compute_stats.timings.matrix_start = tic;

    % 计算内存需求
    matrix_count = 5;  % 邻接矩阵、权重矩阵、方向矩阵、滞后矩阵、显著性矩阵
    total_elements = n_nodes * n_nodes * matrix_count;
    fprintf('  - 矩阵数量: %d\n', matrix_count);
    fprintf('  - 总元素数: %.0f\n', total_elements);
    fprintf('  - 估算内存: %.2f MB\n', total_elements * 8 / 1024 / 1024);

    % 初始化所有矩阵
    adjacency_matrix = zeros(n_nodes, n_nodes, 'single');    % 使用单精度节省内存
    weight_matrix = zeros(n_nodes, n_nodes, 'single');       % 使用单精度节省内存
    % 定义方向编码常量
    DIRECTION_NONE = int8(0);          % 无方向（用于相关性分析或无向边）
    DIRECTION_RET_TO_OBV = int8(1);    % ret → OBV 方向
    DIRECTION_OBV_TO_RET = int8(-1);   % OBV → ret 方向
    DIRECTION_BIDIRECTIONAL = int8(2); % 双向（ret ? OBV）
    
    % 保存方向编码到param_info，供后续使用
    param_info.direction_codes = struct(...
        'NONE', DIRECTION_NONE, ...
        'RET_TO_OBV', DIRECTION_RET_TO_OBV, ...
        'OBV_TO_RET', DIRECTION_OBV_TO_RET, ...
        'BIDIRECTIONAL', DIRECTION_BIDIRECTIONAL);

    % 初始化方向矩阵
    direction_matrix = zeros(n_nodes, n_nodes, 'int8') + DIRECTION_NONE;      % 使用int8节省内存
    lag_matrix = zeros(n_nodes, n_nodes, 'uint8');           % 使用uint8节省内存
    significance_matrix = ones(n_nodes, n_nodes, 'single');  % 默认p=1（不显著）

    fprintf('网络矩阵初始化完成。\n');
    
    % 记录矩阵初始化统计
    compute_stats.matrix_init = struct(...
        'n_nodes', n_nodes, ...
        'matrix_dimensions', [n_nodes, n_nodes], ...
        'matrix_count', matrix_count, ...
        'total_elements', total_elements, ...
        'estimated_memory_mb', total_elements * 8 / 1024 / 1024, ...
        'data_types', {{'single', 'single', 'int8', 'uint8', 'single'}}, ...
        'direction_codes', param_info.direction_codes, ...
        'status', 'initialized');
    
    compute_stats.timings.matrix_end = toc(compute_stats.timings.matrix_start);

    %% 5. 创建节点信息结构
    compute_stats.timings.assembly_start = tic;
    
    % 确定收益和OBV节点索引
    ret_indices = zeros(1, length(all_ret_nodes));
    obv_indices = zeros(1, length(all_obv_nodes));

    for i = 1:length(all_ret_nodes)
        ret_indices(i) = node_index_map(all_ret_nodes{i});
    end
    for i = 1:length(all_obv_nodes)
        obv_indices(i) = node_index_map(all_obv_nodes{i});
    end

    % 创建节点信息结构
    node_info = struct();
    node_info.node_labels = node_labels;
    node_info.node_index_map = node_index_map;
    node_info.ret_nodes = all_ret_nodes;
    node_info.obv_nodes = all_obv_nodes;
    node_info.ret_indices = ret_indices;
    node_info.obv_indices = obv_indices;
    node_info.n_nodes = n_nodes;
    node_info.node_extraction_stats = node_extraction_stats;

    % 记录排序和去重信息
    node_info.consistency_info = struct();
    node_info.consistency_info.nodes_sorted = true;  % 标记已排序
    node_info.consistency_info.sort_method = 'alphabetical';
    node_info.consistency_info.duplicates_removed = (length(unique_nodes) < length([all_ret_nodes, all_obv_nodes]));
    node_info.consistency_info.original_node_count = length([all_ret_nodes, all_obv_nodes]);
    node_info.consistency_info.final_node_count = n_nodes;
    
    % 记录节点信息统计
    compute_stats.node_info = struct(...
        'ret_nodes_count', length(all_ret_nodes), ...
        'obv_nodes_count', length(all_obv_nodes), ...
        'total_nodes', n_nodes, ...
        'ret_indices_count', length(ret_indices), ...
        'obv_indices_count', length(obv_indices), ...
        'node_index_map_size', n_nodes, ...
        'consistency_info', node_info.consistency_info, ...
        'status', 'assembled');

    %% 6. 创建网络矩阵结构
    network_matrices = struct();
    network_matrices.adjacency = adjacency_matrix;
    network_matrices.weights = weight_matrix;
    network_matrices.directions = direction_matrix;
    network_matrices.lags = lag_matrix;
    network_matrices.significance = significance_matrix;
    
    compute_stats.timings.assembly_end = toc(compute_stats.timings.assembly_start);

    %% 7. 计算运行时间和模块信息
    elapsed_time = toc(start_time);
    
    % 汇总计时信息
    compute_stats.timings.total_duration = elapsed_time;
    compute_stats.timings.stage_breakdown = struct(...
        'validation_time', compute_stats.timings.validation_end, ...
        'extraction_time', compute_stats.timings.extraction_end - compute_stats.timings.extraction_start, ...
        'processing_time', compute_stats.timings.processing_end - compute_stats.timings.processing_start, ...
        'mapping_time', compute_stats.timings.mapping_end - compute_stats.timings.mapping_start, ...
        'matrix_init_time', compute_stats.timings.matrix_end - compute_stats.timings.matrix_start, ...
        'assembly_time', compute_stats.timings.assembly_end - compute_stats.timings.assembly_start, ...
        'total_time', elapsed_time);

    % 性能统计
    compute_stats.performance = struct(...
        'pairs_per_second', n_pairs / elapsed_time, ...
        'nodes_per_second', n_nodes / elapsed_time, ...
        'memory_per_node_mb', (total_elements * 8 / 1024 / 1024) / n_nodes, ...
        'processing_speed', sprintf('%.2f pairs/sec', n_pairs / elapsed_time));

    % 总体统计
    compute_stats.summary = struct(...
        'total_pairs_processed', n_pairs, ...
        'total_nodes_found', length(all_ret_nodes) + length(all_obv_nodes) + duplicate_count, ...
        'final_node_count', n_nodes, ...
        'duplicates_removed', duplicate_count, ...
        'successful_mappings', n_nodes, ...
        'overall_status', 'completed', ...
        'module_version', '1.0', ...
        'timestamp', datetime('now'));

    % 更新模块元信息
    compute_stats.module_info.computation_time = elapsed_time;
    compute_stats.module_info.end_time = datetime('now');

    fprintf('\n[模块1] 网络构建核心模块完成\n');
    fprintf('============================================================\n');
    fprintf('运行时间: %.2f 秒\n', elapsed_time);
    fprintf('性能统计:\n');
    fprintf('  - 配对数: %d\n', n_pairs);
    fprintf('  - 节点数: %d\n', n_nodes);
    fprintf('  - 处理速度: %.2f 对/秒\n', n_pairs / elapsed_time);
    fprintf('  - 节点处理速度: %.2f 节点/秒\n', n_nodes / elapsed_time);
    fprintf('  - 重复节点数: %d\n', duplicate_count);
    fprintf('模块信息:\n');
    fprintf('  - 名称: %s\n', compute_stats.module_info.module_name);
    fprintf('  - 版本: %s\n', compute_stats.module_info.version);
    fprintf('  - 完成时间: %s\n', datestr(compute_stats.module_info.end_time, 'yyyy-mm-dd HH:MM:SS'));
    fprintf('============================================================\n\n');
end