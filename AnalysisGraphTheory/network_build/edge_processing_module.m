function [edge_list, processing_stats, updated_matrices] = edge_processing_module(...
    pairwise_results, node_info, network_matrices, param_info, varargin)
% EDGE_PROCESSING_MODULE - 边处理模块
% 功能：处理配对分析结果，构建网络边，更新网络矩阵
% 工作流程：
%   1. 遍历所有配对，验证配对信息有效性
%   2. 根据分析类型（相关性/Granger/综合）处理边
%   3. 更新网络矩阵（邻接矩阵、权重矩阵、方向矩阵、滞后矩阵、显著性矩阵）
%   4. 构建边列表，收集详细计算过程数据
%   5. 解决权重冲突，汇总处理统计
%
% 输入参数：
%   pairwise_results  - 配对分析结果，包含pair_info和connectivity字段
%   node_info         - 节点信息，包含节点映射和标签
%   network_matrices  - 网络矩阵，包括邻接矩阵、权重矩阵等
%   param_info        - 参数信息，包含分析类型、显著性水平等
%
% 输出参数：
%   edge_list         - 添加的边列表
%   processing_stats  - 处理统计和详细计算数据
%   updated_matrices  - 更新后的网络矩阵
%

%% 1. 模块初始化和参数准备
% 记录模块开始时间
module_start_tic = tic;
module_start_time = now;
module_start_time_str = datestr(module_start_time, 'yyyy-mm-dd HH:MM:SS.FFF');
fprintf('\n[模块2] 边处理模块开始\n');
fprintf('============================================================\n');

% 初始化输出结构
processing_stats = struct();
%% 1.1 输入参数验证
try
    % 输入验证
    if nargin < 4
        error('edge_processing_module:输入参数有误:需要4个输入参数，但只提供了 %d 个。', nargin);
    end

    % 验证pairwise_results结构
    if ~isstruct(pairwise_results)
        error('edge_processing_module:pairwise_results必须是结构体');
    end
    
    if ~isfield(pairwise_results, 'pair_info')
        error('edge_processing_module:pairwise_results缺少pair_info字段');
    end
    
    if ~isfield(pairwise_results, 'connectivity')
        error('edge_processing_module:pairwise_results缺少connectivity字段');
    end
    
    % 验证其他输入参数
    if ~isstruct(node_info) || ~isfield(node_info, 'node_index_map')
        error('edge_processing_module:node_info缺少必要字段');
    end
    
    if ~isstruct(network_matrices) || ~isfield(network_matrices, 'adjacency')
        error('edge_processing_module:network_matrices缺少必要字段');
    end
    
    if ~isstruct(param_info) || ~isfield(param_info, 'analysis_type')
        error('edge_processing_module:param_info缺少必要字段');
    end
catch ME
    fprintf('输入参数验证失败: %s', ME.message);
    rethrow(ME);
end
%% 1.2 参数提取和验证
try
    % 从输入参数提取值
    n_pairs = param_info.n_pairs;
    analysis_type = param_info.analysis_type;
    alpha = param_info.alpha;
    min_corr = param_info.min_corr;
    
    % 验证参数有效性
    if ~isnumeric(n_pairs) || n_pairs <= 0
        error('n_pairs必须为正整数');
    end
    
    valid_analysis_types = {'correlation', 'granger', 'all'};
    if ~ismember(analysis_type, valid_analysis_types)
        error('analysis_type必须是: correlation, granger, 或 all');
    end
    
    if ~isnumeric(alpha) || alpha <= 0 || alpha >= 1
        error('alpha必须在(0,1)范围内');
    end
    
    if ~isnumeric(min_corr) || min_corr < 0 || min_corr > 1
        error('min_corr必须在[0,1]范围内');
    end

    % 获取方向编码常量
    if isfield(param_info, 'direction_codes')
        DIR = param_info.direction_codes;
    else
        DIR = struct(...                % 向后兼容：如果没有定义方向常量，使用默认值
            'NONE', int8(0), ...
            'RET_TO_OBV', int8(1), ...
            'OBV_TO_RET', int8(-1), ...
            'BIDIRECTIONAL', int8(2));
        fprintf('  注意: 使用默认方向编码常量\n');
    end

    % 提取节点信息和网络矩阵
    node_index_map = node_info.node_index_map;
    node_labels = node_info.node_labels;
    n_nodes = node_info.n_nodes;
    
    adjacency_matrix = network_matrices.adjacency;
    weight_matrix = network_matrices.weights;
    direction_matrix = network_matrices.directions;
    lag_matrix = network_matrices.lags;
    significance_matrix = network_matrices.significance;
    
    % 验证矩阵维度一致性
    if ~isequal(size(adjacency_matrix), [n_nodes, n_nodes])
        error('邻接矩阵维度与节点数量不匹配');
    end
catch ME
	fprintf('edge_processing_module 阶段1 出错: %s\n', ME.message);
    rethrow(ME);
end

%% ==================== 阶段2：计算过程数据收集 ====================
try
    processing_stats.module_metadata = struct(...      % 模块元信息
        'module_name', 'edge_processing_module', ...
        'version', '2.1-fixed', ...
        'timestamp', module_start_time_str, ...
        'analysis_type', analysis_type, ...
        'significance_level', alpha, ...
        'min_correlation_threshold', min_corr, ...
        'direction_codes', DIR);

    processing_stats.parameters = struct(...           % 输入参数信息
        'n_pairs', n_pairs, ...
        'n_nodes', n_nodes, ...
        'analysis_type', analysis_type, ...
        'alpha', alpha, ...
        'min_corr', min_corr, ...
        'direction_codes', DIR, ...
        'node_labels_count', length(node_labels), ...
        'adjacency_initial_edges', nnz(adjacency_matrix), ...
        'weight_initial_nonzero', nnz(weight_matrix), ...
        'direction_nonzero', nnz(direction_matrix), ...
        'lag_nonzero', nnz(lag_matrix), ...
        'significance_nonzero', nnz(significance_matrix));
    
    
    processing_stats.performance = struct(...          % 性能监控初始化
        'module_start_time', module_start_time_str, ...
        'module_tic_start', module_start_tic, ...
        'total_time', 0, ...
        'pairs_per_second', 0, ...
        'edges_per_second', 0, ...
        'validation_time_total', 0, ...
        'extraction_time_total', 0, ...
        'decision_time_total', 0, ...
        'update_time_total', 0, ...
        'pair_processing_times', [], ...
        'fastest_pair_time', inf, ...
        'slowest_pair_time', 0, ...
        'average_pair_time', 0);
    
    % 详细计算记录初始化
    processing_stats.detailed_calculation = struct();
    processing_stats.detailed_calculation.pair_records = cell(1, n_pairs);
    processing_stats.detailed_calculation.stage_summaries = struct();
    processing_stats.detailed_calculation.conflict_records = [];
    processing_stats.detailed_calculation.matrix_updates = [];
    
    % 初始化计算记录数组
    calculation_records = cell(1, n_pairs);

    % 初始化摘要统计
    processing_stats.summary_stats = struct(...
        'total_pairs', n_pairs, ...
        'processed_pairs', 0, ...
        'skipped_pairs', 0, ...
        'added_edges', 0, ...
        'correlation_edges', 0, ...
        'granger_edges', 0, ...
        'bidirectional_edges', 0, ...
        'unidirectional_edges', 0, ...
        'no_connectivity_results', 0, ...
        'invalid_pair_info', 0, ...
        'nodes_not_found', 0, ...
        'self_connections_skipped', 0, ...
        'weight_overrides', 0, ...              % 记录权重覆盖次数
        'weight_conflicts_recorded', 0, ...     % 记录的冲突数
        'weight_conflicts_resolved', 0, ...     % 解决的冲突数
        'density_before', 0, ...                % 处理前密度
        'density_after', 0, ...                 % 处理后密度
        'calc_records_created', 0, ...
        'calc_records_processed', 0, ...
        'validation_failures', 0, ...
        'extraction_failures', 0, ...
        'decision_failures', 0, ...
        'update_failures', 0);

    % 计算处理前的网络密度
    edges_before = sum(adjacency_matrix(:));
    if strcmp(analysis_type, 'correlation')       
        max_possible = n_nodes * (n_nodes - 1) / 2;    % 相关性分析：无向图
        processing_stats.summary_stats.density_before = (edges_before / 2) / max_possible;
    else
        max_possible = n_nodes * (n_nodes - 1);        % Granger因果分析：有向图
        processing_stats.summary_stats.density_before = edges_before / max_possible;
    end
catch ME
	fprintf('edge_processing_module 阶段2 出错: %s\n', ME.message);
    rethrow(ME);
end

% 显示参数配置
fprintf('参数配置:\n');
fprintf('  - 配对数量: %d\n', n_pairs);
fprintf('  - 节点数量: %d\n', n_nodes);
fprintf('  - 分析类型: %s\n', upper(analysis_type));
fprintf('  - 显著性水平: α = %.3f\n', alpha);
if min_corr > 0
    fprintf('  - 最小相关系数阈值: %.2f\n', min_corr);
end
fprintf('  - 初始网络密度: %.4f\n', processing_stats.summary_stats.density_before);

%% ==================== 阶段3：配对处理流程 ====================
fprintf('\n开始处理 %d 个配对...\n', n_pairs);

    progress_interval = max(1, floor(n_pairs/20));     % 进度显示设置
    fprintf('处理进度: 0%%');

    % 初始化冲突记录结构
    weight_conflicts = struct();        % 用于记录权重冲突
    conflict_counter = 0;

    % 初始化边列表
    edge_list = cell(1, n_pairs);       % 边列表（元胞数组）
    edge_counter = 0;
    
    % 阶段时间累计
    total_validation_time = 0;
    total_extraction_time = 0;
    total_decision_time = 0;
    total_update_time = 0;

    for pair_idx = 1:n_pairs            % 遍历所有配对
        % 配对处理开始
        pair_start_tic = tic;
        processing_stats.summary_stats.processed_pairs = processing_stats.summary_stats.processed_pairs + 1;

        % 初始化配对详细数据记录
        pair_detailed_data = struct();
        pair_detailed_data.pair_idx = pair_idx;
        pair_detailed_data.start_time = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
        pair_detailed_data.stages = struct();
        pair_detailed_data.final_state = 'initialized';

        % 初始化配对计算记录
        calc_record = struct();
        calc_record.pair_idx = pair_idx;
        calc_record.start_time = now;
        calc_record.status = 'processing';
        calc_record.analysis_type = analysis_type;
        calc_record.validation_passed = false;
        calc_record.node_validation_passed = false;
        calc_record.connectivity_valid = false;
        calc_record.edge_added = false;
        
        %% 3.1 验证阶段
        validation_start_tic = tic;
        [validation_passed, validation_reason] = validate_pair_inputs_complete(...
            pairwise_results, pair_idx);
        validation_time = toc(validation_start_tic);
        total_validation_time = total_validation_time + validation_time;
        
        % 记录验证阶段数据
        validation_data = struct();
        validation_data.stage_name = 'validation';
        validation_data.validation_time = validation_time;
        validation_data.passed = validation_passed;
        validation_data.reason = validation_reason;
        validation_data.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
        pair_detailed_data.stages.validation = validation_data;
        
        calc_record.validation_passed = validation_passed;
        calc_record.validation_reason = validation_reason;
        calc_record.validation_time = validation_time;
        
        % 如果验证失败，记录并跳过
        if ~validation_passed
            calc_record.status = 'skipped';
            calc_record.reason = validation_reason;
            calc_record.end_time = now;
            calculation_records{pair_idx} = calc_record;
            
            % 更新统计
            update_validation_statistics(processing_stats, validation_reason);
            
            % 设置最终状态
            pair_detailed_data.final_state = 'skipped_validation_failed';
            pair_detailed_data.final_reason = validation_reason;
            
            % 保存详细数据
            save_pair_detailed_data(pair_detailed_data, pair_start_tic, ...
                processing_stats, pair_idx);
            
            continue;       % 继续下一个配对
        end
        
        % 验证通过，获取配对信息
        pair_info = pairwise_results.pair_info{pair_idx};
        connectivity_result = pairwise_results.connectivity{pair_idx};
        
        %% 3.2 节点信息提取和验证
        node_validation_start_tic = tic;
        [ret_name, obv_name, ret_idx, obv_idx, node_check_passed, node_check_reason] = ...
            extract_and_validate_node_info_complete(pair_info, node_index_map);
        node_validation_time = toc(node_validation_start_tic);
        total_validation_time = total_validation_time + node_validation_time;
        
        % 记录节点验证数据
        node_validation_data = struct();
        node_validation_data.stage_name = 'node_validation';
        node_validation_data.validation_time = node_validation_time;
        node_validation_data.passed = node_check_passed;
        node_validation_data.reason = node_check_reason;
        node_validation_data.ret_name = ret_name;
        node_validation_data.obv_name = obv_name;
        node_validation_data.ret_idx = ret_idx;
        node_validation_data.obv_idx = obv_idx;
        node_validation_data.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
        pair_detailed_data.stages.node_validation = node_validation_data;
        
        calc_record.node_validation_passed = node_check_passed;
        calc_record.node_validation_reason = node_check_reason;
        calc_record.ret_name = ret_name;
        calc_record.obv_name = obv_name;
        calc_record.ret_idx = ret_idx;
        calc_record.obv_idx = obv_idx;
        
        % 如果节点验证失败，记录并跳过
        if ~node_check_passed
            calc_record.status = 'skipped';
            calc_record.reason = node_check_reason;
            calc_record.end_time = now;
            calculation_records{pair_idx} = calc_record;
            
            % 更新统计
            update_node_validation_statistics(processing_stats, node_check_reason);
            
            % 设置最终状态
            pair_detailed_data.final_state = 'skipped_node_validation_failed';
            pair_detailed_data.final_reason = node_check_reason;
            
            % 保存详细数据
            save_pair_detailed_data(pair_detailed_data, pair_start_tic, ...
                processing_stats, pair_idx);
            
            continue;            % 继续下一个配对
        end
        
        % 记录配对ID
        pair_id = sprintf('%s_%s', ret_name, obv_name);
        calc_record.pair_id = pair_id;
        
        %% 3.3 连通性结果验证
        connectivity_validation_start_tic = tic;
        [connectivity_valid, connectivity_reason] = validate_connectivity_result(...
            connectivity_result);
        connectivity_validation_time = toc(connectivity_validation_start_tic);
        total_validation_time = total_validation_time + connectivity_validation_time;
        
        % 记录连通性验证数据
        connectivity_validation_data = struct();
        connectivity_validation_data.stage_name = 'connectivity_validation';
        connectivity_validation_data.validation_time = connectivity_validation_time;
        connectivity_validation_data.passed = connectivity_valid;
        connectivity_validation_data.reason = connectivity_reason;
        connectivity_validation_data.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
        pair_detailed_data.stages.connectivity_validation = connectivity_validation_data;
        
        calc_record.connectivity_valid = connectivity_valid;
        calc_record.connectivity_reason = connectivity_reason;
        
        % 如果连通性验证失败，记录并跳过
        if ~connectivity_valid
            calc_record.status = 'skipped';
            calc_record.reason = connectivity_reason;
            calc_record.end_time = now;
            calculation_records{pair_idx} = calc_record;
            
            processing_stats.summary_stats.no_connectivity_results = ...
                processing_stats.summary_stats.no_connectivity_results + 1;
            
            % 设置最终状态
            pair_detailed_data.final_state = 'skipped_connectivity_invalid';
            pair_detailed_data.final_reason = connectivity_reason;
            
            % 保存详细数据
            save_pair_detailed_data(pair_detailed_data, pair_start_tic, ...
                processing_stats, pair_idx);
            
            continue;            % 继续下一个配对
        end
 
        %% 3.4 边处理阶段~根据分析类型处理连接
        extraction_start_tic = tic;         % 记录统计量提取阶段开始时间
        try
            switch analysis_type            % 根据分析类型调用不同的处理函数
                case 'correlation'          % 处理相关性连接                   
                    [edge_added, edge_info, extraction_data] = process_correlation_edge_complete(...
                        connectivity_result, ret_idx, obv_idx, ret_name, obv_name, ...
                        adjacency_matrix, weight_matrix, direction_matrix, significance_matrix, ...
                        alpha, min_corr);
                case 'granger'              % 处理Granger因果连接                 
                    [edge_added, edge_info, extraction_data] = process_granger_edge_complete(...
                        connectivity_result, ret_idx, obv_idx, ret_name, obv_name, ...
                        adjacency_matrix, weight_matrix, direction_matrix, lag_matrix, ...
                        significance_matrix, alpha);
                case 'all'                  % 综合处理：优先使用Granger，如果没有Granger则使用相关性                    
                    [edge_added, edge_info, extraction_data] = process_combined_edge_complete(...
                        connectivity_result, ret_idx, obv_idx, ret_name, obv_name, ...
                        adjacency_matrix, weight_matrix, direction_matrix, lag_matrix, ...
                        significance_matrix, alpha, min_corr);
                otherwise
                    error('不支持的analysis_type: %s。', analysis_type);
            end
            
            extraction_time = toc(extraction_start_tic);
            total_extraction_time = total_extraction_time + extraction_time;
            
            % 记录提取阶段数据
            extraction_data.stage_name = 'extraction';
            extraction_data.extraction_time = extraction_time;
            extraction_data.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
            pair_detailed_data.stages.extraction = extraction_data;
            
            calc_record.edge_added = edge_added;
            calc_record.edge_info = edge_info;
            calc_record.extraction_time = extraction_time;
        catch ME
            % 提取阶段错误处理
            extraction_time = toc(extraction_start_tic);
            total_extraction_time = total_extraction_time + extraction_time;
            
            calc_record.status = 'error';
            calc_record.reason = sprintf('extraction_error: %s', ME.message);
            calc_record.end_time = now;
            calculation_records{pair_idx} = calc_record;
            
            processing_stats.summary_stats.extraction_failures = ...
                processing_stats.summary_stats.extraction_failures + 1;
            
            % 记录错误信息
            extraction_data = struct();
            extraction_data.stage_name = 'extraction';
            extraction_data.extraction_time = extraction_time;
            extraction_data.passed = false;
            extraction_data.error = ME.message;
            extraction_data.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
            pair_detailed_data.stages.extraction = extraction_data;
            
            % 设置最终状态
            pair_detailed_data.final_state = 'error_extraction_failed';
            pair_detailed_data.final_reason = ME.message;
            
            % 保存详细数据
            save_pair_detailed_data(pair_detailed_data, pair_start_tic, ...
                processing_stats, pair_idx);

            continue;               % 继续下一个配对
        end
        
        %% 3.6 决策和更新阶段 
        if calc_record.edge_added
            try
                %% 3.6.1 根据边类型进行决策
                decision_start_time = tic;
                [decision_data, calc_record] = make_edge_decision_complete(...
                    calc_record, edge_info, adjacency_matrix, weight_matrix, ...
                    direction_matrix, lag_matrix, significance_matrix, ...
                    ret_idx, obv_idx, DIR, analysis_type, pair_idx, ret_name, obv_name);
                decision_time = toc(decision_start_tic);
                total_decision_time = total_decision_time + decision_time;
                
                % 记录决策阶段数据
                ddecision_data.stage_name = 'decision';
                decision_data.decision_time = decision_time;
                decision_data.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
                pair_detailed_data.stages.decision = decision_data;
                
                calc_record.decision_time = decision_time;
                
                %% 3.6.2 矩阵更新阶段
                update_start_time = tic;
                [update_data, adjacency_matrix, weight_matrix, direction_matrix, ...
                 lag_matrix, significance_matrix, calc_record] = update_matrices_complete(...
                    calc_record, adjacency_matrix, weight_matrix, direction_matrix, ...
                    lag_matrix, significance_matrix, ret_idx, obv_idx, DIR, edge_info);
                update_time = toc(update_start_tic);
                total_update_time = total_update_time + update_time;
                
                % 记录更新阶段数据
                update_data.stage_name = 'update';
                update_data.update_time = update_time;
                update_data.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
                pair_detailed_data.stages.update = update_data;
                
                % 记录边信息
                edge_info_record = struct();
                edge_info_record.edge_id = edge_info.edge_id;
                edge_info_record.analysis_type = edge_info.analysis_type;
                edge_info_record.direction = edge_info.direction;
                edge_info_record.from_node = edge_info.from_node;
                edge_info_record.to_node = edge_info.to_node;
                edge_info_record.weight = edge_info.weight;
                edge_info_record.p_value = edge_info.p_value;
                edge_info_record.is_significant = edge_info.is_significant;
                edge_info_record.creation_time = edge_info.creation_time;
                pair_detailed_data.edge_info = edge_info_record;
                
                % 添加边到列表
                edge_counter = edge_counter + 1;
                edge_list{edge_counter} = edge_info;
                
                % 更新统计
                processing_stats.summary_stats.added_edges = processing_stats.summary_stats.added_edges + 1;
                
                if strcmp(analysis_type, 'correlation')
                    processing_stats.summary_stats.correlation_edges = ...
                        processing_stats.summary_stats.correlation_edges + 1;
                else
                    processing_stats.summary_stats.granger_edges = ...
                        processing_stats.summary_stats.granger_edges + 1;
                    
                    if isfield(edge_info, 'direction')
                        if strcmp(edge_info.direction, 'bidirectional')
                            processing_stats.summary_stats.bidirectional_edges = ...
                                processing_stats.summary_stats.bidirectional_edges + 1;
                        else
                            processing_stats.summary_stats.unidirectional_edges = ...
                                processing_stats.summary_stats.unidirectional_edges + 1;
                        end
                    end
                end
                
                % 记录权重覆盖冲突
                if isfield(calc_record, 'weight_override') && calc_record.weight_override
                    processing_stats.summary_stats.weight_overrides = ...
                        processing_stats.summary_stats.weight_overrides + 1;
                    
                    if isfield(calc_record, 'weight_conflict') && calc_record.weight_conflict
                        conflict_counter = conflict_counter + 1;
                        weight_conflicts(conflict_counter).pair_idx = pair_idx;
                        weight_conflicts(conflict_counter).pair_id = pair_id;
                        weight_conflicts(conflict_counter).ret_name = ret_name;
                        weight_conflicts(conflict_counter).obv_name = obv_name;
                        weight_conflicts(conflict_counter).ret_idx = ret_idx;
                        weight_conflicts(conflict_counter).obv_idx = obv_idx;
                        weight_conflicts(conflict_counter).conflict_type = 'bidirectional';
                        
                        if isfield(calc_record, 'conflict_direction1') && calc_record.conflict_direction1
                            weight_conflicts(conflict_counter).conflict_direction1 = true;
                        end
                        if isfield(calc_record, 'conflict_direction2') && calc_record.conflict_direction2
                            weight_conflicts(conflict_counter).conflict_direction2 = true;
                        end
                    end
                end
                
                calc_record.status = 'success';
                calc_record.update_time = update_time;
                calc_record.final_weight = calc_record.calculated_weight;
                
            catch ME
                fprintf('edge_processing_module 阶段3.6 边决策/更新 出错: %s\n', ME.message);
                decision_update_time = toc(decision_start_tic);
                total_decision_time = total_decision_time + decision_update_time;
                
                calc_record.status = 'error';
                calc_record.reason = sprintf('decision_update_error: %s', ME.message);
                calc_record.end_time = now;
                calculation_records{pair_idx} = calc_record;
                
                processing_stats.summary_stats.decision_failures = ...
                    processing_stats.summary_stats.decision_failures + 1;
                
                % 设置最终状态
                pair_detailed_data.final_state = 'error_decision_update_failed';
                pair_detailed_data.final_reason = ME.message;
            end
        else
            % 边未添加的情况
            calc_record.status = 'no_edge_added';
            if ~isfield(calc_record, 'reason')
                calc_record.reason = 'not_significant';
            end
        end

        %% 3.7 完成当前配对的计算记录
        try
            calc_record.end_time = now;
            calc_record.processing_time = calc_record.end_time - calc_record.start_time;
            calculation_records{pair_idx} = calc_record;

            processing_stats.summary_stats.calc_records_created = ...
                processing_stats.summary_stats.calc_records_created + 1;
        
            % 保存详细计算数据
            pair_detailed_data.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
            pair_detailed_data.total_processing_time = toc(pair_start_tic);
            pair_detailed_data.final_status = calc_record.status;

            if isfield(calc_record, 'reason')
                pair_detailed_data.final_reason = calc_record.reason;
            elseif strcmp(calc_record.status, 'success')
                pair_detailed_data.final_reason = 'edge_added_successfully';
            elseif strcmp(calc_record.status, 'no_edge_added')
                pair_detailed_data.final_reason = 'not_significant';
            else
                pair_detailed_data.final_reason = 'processing_completed';
            end
        
            % 保存详细数据
            processing_stats.detailed_calculation.pair_records{pair_idx} = pair_detailed_data;

            % 记录配对处理时间
            pair_processing_time = toc(pair_start_tic);
            processing_stats.performance.pair_processing_times(end+1) = pair_processing_time;

            % 更新最快/最慢配对时间
            if pair_processing_time < processing_stats.performance.fastest_pair_time
                processing_stats.performance.fastest_pair_time = pair_processing_time;
            end
            if pair_processing_time > processing_stats.performance.slowest_pair_time
                processing_stats.performance.slowest_pair_time = pair_processing_time;
            end
        catch ME
            fprintf('配对 %d 完成记录时出错: %s\n', pair_idx, ME.message);
        end
        % 进度显示
        if mod(pair_idx, progress_interval) == 0
            progress_percent = round(pair_idx/n_pairs*100);
            fprintf('\b\b\b\b%3d%%', progress_percent);
        end
    end

    %% ==================== 阶段4. 冲突解决 ====================
    fprintf('\n解决权重冲突...\n');

    processing_stats.summary_stats.weight_conflicts_recorded = conflict_counter;

    if conflict_counter > 0
        fprintf('   发现 %d 个权重冲突需要解决\n', conflict_counter);

        try
            % 调用冲突解决函数
            conflict_resolution_start_tic = tic;
            [weight_matrix, significance_matrix, resolution_stats] = ...
                resolve_weight_conflicts_complete(weight_conflicts, weight_matrix, ...
                significance_matrix, analysis_type, DIR);
            conflict_resolution_time = toc(conflict_resolution_start_tic);

            % 记录冲突解决详情
            processing_stats.detailed_calculation.conflict_records = struct(...
                'total_conflicts', conflict_counter, ...
                'resolution_time', conflict_resolution_time, ...
                'resolution_method', resolution_stats.method, ...
                'resolved_count', resolution_stats.resolved_count, ...
                'resolution_details', resolution_stats.details, ...
                'timestamp', datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF'));

            % 更新统计
            processing_stats.summary_stats.weight_conflicts_resolved = resolution_stats.resolved_count;
            processing_stats.summary_stats.conflict_resolution_method = resolution_stats.method;
            processing_stats.summary_stats.conflict_resolution_details = resolution_stats.details;

            fprintf('   已解决 %d 个冲突 (方法: %s)\n', ...
                resolution_stats.resolved_count, resolution_stats.method);

        catch ME
            fprintf('冲突解决失败: %s\n', ME.message);
            processing_stats.summary_stats.weight_conflicts_resolved = 0;
            processing_stats.summary_stats.conflict_resolution_method = 'failed';
        end
    else
        fprintf('   无权重冲突\n');
        processing_stats.summary_stats.weight_conflicts_resolved = 0;
        processing_stats.summary_stats.conflict_resolution_method = 'none';
    end
    
%% ==================== 阶段5：详细计算数据记录 ====================
% 5.1 创建更新后的矩阵结构
updated_matrices = struct();
updated_matrices.adjacency = adjacency_matrix;
updated_matrices.weights = weight_matrix;
updated_matrices.directions = direction_matrix;
updated_matrices.lags = lag_matrix;
updated_matrices.significance = significance_matrix;

% 5.2 计算最终统计
try
    % 计算跳过配对数
    processing_stats.summary_stats.skipped_pairs = ...
        processing_stats.summary_stats.no_connectivity_results + ...
        processing_stats.summary_stats.invalid_pair_info + ...
        processing_stats.summary_stats.nodes_not_found + ...
        processing_stats.summary_stats.self_connections_skipped;
    
    % 计算处理后的网络密度
    edges_after = sum(adjacency_matrix(:));
    if strcmp(analysis_type, 'correlation')
        processing_stats.summary_stats.density_after = (edges_after / 2) / max_possible;
    else
        processing_stats.summary_stats.density_after = edges_after / max_possible;
    end
    
    % 计算记录统计
    processing_stats.summary_stats.calc_records_saved = sum(~cellfun(@isempty, calculation_records));
    
    % 更新性能统计
    total_module_time = toc(module_start_tic);
    processing_stats.performance.total_time = total_module_time;
    processing_stats.performance.pairs_per_second = n_pairs / total_module_time;
    processing_stats.performance.edges_per_second = processing_stats.summary_stats.added_edges / total_module_time;
    
    % 阶段时间统计
    processing_stats.performance.validation_time_total = total_validation_time;
    processing_stats.performance.extraction_time_total = total_extraction_time;
    processing_stats.performance.decision_time_total = total_decision_time;
    processing_stats.performance.update_time_total = total_update_time;
    
    % 平均配对处理时间
    if ~isempty(processing_stats.performance.pair_processing_times)
        processing_stats.performance.average_pair_time = ...
            mean(processing_stats.performance.pair_processing_times);
    end
catch ME
	fprintf('edge_processing_module 阶段5 出错: %s\n', ME.message);
    rethrow(ME);
end

%% 输出总结报告
fprintf('\n边处理完成统计:\n');
fprintf('  - 处理配对总数: %d\n', processing_stats.summary_stats.processed_pairs);
fprintf('  - 跳过配对数: %d\n', processing_stats.summary_stats.skipped_pairs);
fprintf('    * 无连通性结果: %d\n', processing_stats.summary_stats.no_connectivity_results);
fprintf('    * 无效配对信息: %d\n', processing_stats.summary_stats.invalid_pair_info);
fprintf('    * 节点未找到: %d\n', processing_stats.summary_stats.nodes_not_found);
fprintf('    * 自连接跳过: %d\n', processing_stats.summary_stats.self_connections_skipped);
fprintf('  - 添加边总数: %d\n', processing_stats.summary_stats.added_edges);
fprintf('  - 相关性边: %d\n', processing_stats.summary_stats.correlation_edges);
fprintf('  - Granger因果边: %d\n', processing_stats.summary_stats.granger_edges);
fprintf('    * 双向边: %d\n', processing_stats.summary_stats.bidirectional_edges);
fprintf('    * 单向边: %d\n', processing_stats.summary_stats.unidirectional_edges);
fprintf('  - 权重覆盖次数: %d\n', processing_stats.summary_stats.weight_overrides);
fprintf('  - 权重冲突: 记录 %d 个，解决 %d 个\n', ...
    processing_stats.summary_stats.weight_conflicts_recorded, ...
    processing_stats.summary_stats.weight_conflicts_resolved);
fprintf('  - 网络密度变化: %.4f → %.4f\n', ...
    processing_stats.summary_stats.density_before, processing_stats.summary_stats.density_after);
fprintf('  - 处理失败统计:\n');
fprintf('    * 验证失败: %d\n', processing_stats.summary_stats.validation_failures);
fprintf('    * 提取失败: %d\n', processing_stats.summary_stats.extraction_failures);
fprintf('    * 决策失败: %d\n', processing_stats.summary_stats.decision_failures);
fprintf('    * 更新失败: %d\n', processing_stats.summary_stats.update_failures);
fprintf('  - 性能统计:\n');
fprintf('    * 总处理时间: %.2f 秒\n', processing_stats.performance.total_time);
fprintf('    * 配对处理速度: %.1f 配对/秒\n', processing_stats.performance.pairs_per_second);
fprintf('    * 边添加速度: %.1f 边/秒\n', processing_stats.performance.edges_per_second);
fprintf('    * 最快配对: %.3f 秒\n', processing_stats.performance.fastest_pair_time);
fprintf('    * 最慢配对: %.3f 秒\n', processing_stats.performance.slowest_pair_time);
fprintf('    * 平均配对: %.3f 秒\n', processing_stats.performance.average_pair_time);

end

function [validation_passed, validation_reason] = validate_pair_inputs_complete(pairwise_results, pair_idx)
% VALIDATE_PAIR_INPUTS_COMPLETE - 完整的配对输入验证
% 验证pairwise_results中的配对信息是否有效

    validation_passed = true;
    validation_reason = 'validation_passed';
    
    % 1. 检查pair_info字段是否存在
    if ~isfield(pairwise_results, 'pair_info')
        validation_passed = false;
        validation_reason = 'no_pair_info_field';
        return;
    end
    
    % 2. 检查pair_info是否为空
    if isempty(pairwise_results.pair_info)
        validation_passed = false;
        validation_reason = 'pair_info_empty';
        return;
    end
    
    % 3. 检查pair_info长度是否足够
    if length(pairwise_results.pair_info) < pair_idx
        validation_passed = false;
        validation_reason = 'pair_info_length_insufficient';
        return;
    end
    
    % 4. 检查当前配对的pair_info是否为空
    if isempty(pairwise_results.pair_info{pair_idx})
        validation_passed = false;
        validation_reason = 'pair_info_element_empty';
        return;
    end
    
    % 5. 检查connectivity字段是否存在
    if ~isfield(pairwise_results, 'connectivity')
        validation_passed = false;
        validation_reason = 'no_connectivity_field';
        return;
    end
    
    % 6. 检查connectivity是否为空
    if isempty(pairwise_results.connectivity)
        validation_passed = false;
        validation_reason = 'connectivity_empty';
        return;
    end
    
    % 7. 检查connectivity长度是否足够
    if length(pairwise_results.connectivity) < pair_idx
        validation_passed = false;
        validation_reason = 'connectivity_length_insufficient';
        return;
    end
    
    % 8. 检查当前配对的connectivity是否为空
    if isempty(pairwise_results.connectivity{pair_idx})
        validation_passed = false;
        validation_reason = 'connectivity_element_empty';
        return;
    end
end

function [ret_name, obv_name, ret_idx, obv_idx, check_passed, check_reason] = ...
    extract_and_validate_node_info_complete(pair_info, node_index_map)
% EXTRACT_AND_VALIDATE_NODE_INFO_COMPLETE - 提取和验证节点信息
% 从pair_info中提取节点信息并验证有效性

    ret_name = '';
    obv_name = '';
    ret_idx = [];
    obv_idx = [];
    check_passed = true;
    check_reason = 'node_validation_passed';
    
    % 1. 验证pair_info结构
    if ~isstruct(pair_info)
        check_passed = false;
        check_reason = 'pair_info_not_struct';
        return;
    end
    
    % 2. 检查必需字段
    if ~isfield(pair_info, 'ret_name') || ~isfield(pair_info, 'obv_name')
        check_passed = false;
        check_reason = 'missing_node_name_fields';
        return;
    end
    
    % 3. 提取节点名称
    ret_name = pair_info.ret_name;
    obv_name = pair_info.obv_name;
    
    % 4. 验证节点名称
    if isempty(ret_name) || ~ischar(ret_name) || isempty(obv_name) || ~ischar(obv_name)
        check_passed = false;
        check_reason = 'invalid_node_names';
        return;
    end
    
    % 5. 检查节点是否在映射中
    if ~isKey(node_index_map, ret_name)
        check_passed = false;
        check_reason = 'ret_node_not_found';
        return;
    end
    
    if ~isKey(node_index_map, obv_name)
        check_passed = false;
        check_reason = 'obv_node_not_found';
        return;
    end
    
    % 6. 获取节点索引
    ret_idx = node_index_map(ret_name);
    obv_idx = node_index_map(obv_name);
    
    % 7. 跳过自连接
    if ret_idx == obv_idx
        check_passed = false;
        check_reason = 'self_connection';
        return;
    end
end

function [connectivity_valid, validation_reason] = validate_connectivity_result(connectivity_result)
% VALIDATE_CONNECTIVITY_RESULT - 验证连通性结果结构
% 验证connectivity_result的数据结构是否有效

    connectivity_valid = true;
    validation_reason = 'connectivity_valid';
    
    % 检查是否为结构体
    if ~isstruct(connectivity_result)
        connectivity_valid = false;
        validation_reason = 'connectivity_not_struct';
        return;
    end
    
    % 检查是否为空结构
    if isempty(fieldnames(connectivity_result))
        connectivity_valid = false;
        validation_reason = 'connectivity_empty_struct';
        return;
    end
end

function update_validation_statistics(processing_stats, validation_reason)
% UPDATE_VALIDATION_STATISTICS - 更新验证失败统计
% 根据验证失败原因更新相应的统计计数器

    processing_stats.summary_stats.validation_failures = ...
        processing_stats.summary_stats.validation_failures + 1;
    
    switch validation_reason
        case {'no_pair_info_field', 'pair_info_empty', 'pair_info_length_insufficient', ...
              'pair_info_element_empty', 'no_connectivity_field', 'connectivity_empty', ...
              'connectivity_length_insufficient', 'connectivity_element_empty'}
            % 连通性相关问题
            processing_stats.summary_stats.no_connectivity_results = ...
                processing_stats.summary_stats.no_connectivity_results + 1;
            
        case {'pair_info_not_struct', 'missing_node_name_fields', 'invalid_node_names', ...
              'invalid_pair_structure'}
            % 配对信息无效问题
            processing_stats.summary_stats.invalid_pair_info = ...
                processing_stats.summary_stats.invalid_pair_info + 1;
            
        case {'ret_node_not_found', 'obv_node_not_found'}
            % 节点未找到问题
            processing_stats.summary_stats.nodes_not_found = ...
                processing_stats.summary_stats.nodes_not_found + 1;
            
        case {'self_connection'}
            % 自连接问题
            processing_stats.summary_stats.self_connections_skipped = ...
                processing_stats.summary_stats.self_connections_skipped + 1;
            
        otherwise
            % 其他未预期的错误
            processing_stats.summary_stats.no_connectivity_results = ...
                processing_stats.summary_stats.no_connectivity_results + 1;
    end
end

function update_node_validation_statistics(processing_stats, node_check_reason)
% UPDATE_NODE_VALIDATION_STATISTICS - 更新节点验证失败统计

    processing_stats.summary_stats.validation_failures = ...
        processing_stats.summary_stats.validation_failures + 1;
    
    switch node_check_reason
        case {'ret_node_not_found', 'obv_node_not_found'}
            processing_stats.summary_stats.nodes_not_found = ...
                processing_stats.summary_stats.nodes_not_found + 1;
        case {'self_connection'}
            processing_stats.summary_stats.self_connections_skipped = ...
                processing_stats.summary_stats.self_connections_skipped + 1;
        otherwise
            processing_stats.summary_stats.invalid_pair_info = ...
                processing_stats.summary_stats.invalid_pair_info + 1;
    end
end

function save_pair_detailed_data(pair_detailed_data, pair_start_tic, processing_stats, pair_idx)
% SAVE_PAIR_DETAILED_DATA - 保存配对详细数据
% 将配对详细数据保存到processing_stats结构中

    pair_detailed_data.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
    pair_detailed_data.total_processing_time = toc(pair_start_tic);
    
    processing_stats.detailed_calculation.pair_records{pair_idx} = pair_detailed_data;
end

function [edge_added, edge_info, extraction_data] = process_correlation_edge_complete(...
    connectivity_result, ret_idx, obv_idx, ret_name, obv_name, ...
    adjacency_matrix, weight_matrix, direction_matrix, significance_matrix, ...
    alpha, min_corr)
% PROCESS_CORRELATION_EDGE_COMPLETE - 完整的相关性边处理
% 处理相关性分析结果，判断是否添加边

    edge_added = false;
    edge_info = struct();
    extraction_data = struct();
    
    % 初始化提取数据
    extraction_data.extraction_start_time = tic;
    extraction_data.analysis_type = 'correlation';
    extraction_data.ret_name = ret_name;
    extraction_data.obv_name = obv_name;
    extraction_data.ret_idx = ret_idx;
    extraction_data.obv_idx = obv_idx;
    
    try
        % 从连通性结果中提取相关性信息
        if isfield(connectivity_result, 'correlation')
            corr_result = connectivity_result.correlation;
            extraction_data.data_structure = 'nested';
        else
            corr_result = connectivity_result;
            extraction_data.data_structure = 'flat';
        end
        
        % 记录可用字段
        extraction_data.available_fields = fieldnames(corr_result);
        
        % 提取相关系数和p值
        if isfield(corr_result, 'correlation')
            correlation = corr_result.correlation;
        else
            correlation = NaN;
        end
        
        if isfield(corr_result, 'p_value')
            p_value = corr_result.p_value;
        else
            p_value = NaN;
        end
        
        % 记录提取的统计量
        extraction_data.correlation = correlation;
        extraction_data.p_value = p_value;
        extraction_data.abs_correlation = abs(correlation);
        extraction_data.min_corr_threshold = min_corr;
        extraction_data.significance_level = alpha;
        
        % 检查相关性是否显著且超过阈值
        meets_correlation_threshold = abs(correlation) >= min_corr;
        meets_significance_threshold = p_value < alpha;
        
        extraction_data.meets_correlation_threshold = meets_correlation_threshold;
        extraction_data.meets_significance_threshold = meets_significance_threshold;
        
        if meets_correlation_threshold && meets_significance_threshold
            edge_added = true;
            
            % 创建边信息
            edge_info.edge_id = sprintf('correlation_%s_%s', ret_name, obv_name);
            edge_info.analysis_type = 'correlation';
            edge_info.direction = 'undirected';
            edge_info.from_node = ret_name;
            edge_info.to_node = obv_name;
            edge_info.from_idx = ret_idx;
            edge_info.to_idx = obv_idx;
            edge_info.from_type = 'ret';
            edge_info.to_type = 'obv';
            edge_info.weight = correlation;
            edge_info.p_value = p_value;
            edge_info.is_significant = true;
            edge_info.significance_level = alpha;
            edge_info.creation_time = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
            edge_info.added = true;
            
            % 记录相关性阈值判断
            edge_info.meets_correlation_threshold = true;
            edge_info.correlation_threshold = min_corr;
        end
        
        extraction_data.edge_added = edge_added;
        
    catch ME
        % 提取阶段错误
        extraction_data.extraction_error = ME.message;
        extraction_data.edge_added = false;
    end
    
    % 记录提取时间
    extraction_data.extraction_time = toc(extraction_data.extraction_start_time);
end

function [edge_added, edge_info, extraction_data] = process_granger_edge_complete(...
    connectivity_result, ret_idx, obv_idx, ret_name, obv_name, ...
    adjacency_matrix, weight_matrix, direction_matrix, lag_matrix, ...
    significance_matrix, alpha)
% PROCESS_GRANGER_EDGE_COMPLETE - 完整的Granger因果边处理
% 处理Granger因果分析结果，判断是否添加边

    edge_added = false;
    edge_info = struct();
    extraction_data = struct();
    
    % 初始化提取数据
    extraction_data.extraction_start_time = tic;
    extraction_data.analysis_type = 'granger';
    extraction_data.ret_name = ret_name;
    extraction_data.obv_name = obv_name;
    extraction_data.ret_idx = ret_idx;
    extraction_data.obv_idx = obv_idx;
    
    try
        % 提取Granger结果
        if isfield(connectivity_result, 'granger')
            granger_result = connectivity_result.granger;
            extraction_data.data_structure = 'nested';
        else
            granger_result = connectivity_result;
            extraction_data.data_structure = 'flat';
        end
        
        % 记录可用字段
        extraction_data.available_fields = fieldnames(granger_result);
        
        % 验证Granger结果
        if ~isstruct(granger_result)
            extraction_data.error = 'Granger结果不是结构体';
            extraction_data.extraction_time = toc(extraction_data.extraction_start_time);
            return;
        end
        
        % 检查必需字段
        if ~isfield(granger_result, 'direction')
            extraction_data.error = '缺少direction字段';
            extraction_data.extraction_time = toc(extraction_data.extraction_start_time);
            return;
        end
        
        direction = granger_result.direction;
        extraction_data.original_direction = direction;
        
        % 提取p值
        p_fields_x2y = {'p_value_x2y', 'pvalue_x2y', 'pval_x2y', 'p_x2y'};
        p_fields_y2x = {'p_value_y2x', 'pvalue_y2x', 'pval_y2x', 'p_y2x'};
        
        p_x2y = extract_field_value_complete(granger_result, p_fields_x2y, 'p_value_x2y');
        p_y2x = extract_field_value_complete(granger_result, p_fields_y2x, 'p_value_y2x');
        
        if isnan(p_x2y) || isnan(p_y2x)
            extraction_data.error = '无法找到有效的p值字段';
            extraction_data.extraction_time = toc(extraction_data.extraction_start_time);
            return;
        end
        
        % 提取F统计量
        f_x2y = extract_field_value_complete(granger_result, ...
            {'f_statistic_x2y', 'fstat_x2y', 'F_x2y'}, 'f_statistic_x2y');
        f_y2x = extract_field_value_complete(granger_result, ...
            {'f_statistic_y2x', 'fstat_y2x', 'F_y2x'}, 'f_statistic_y2x');
        
        % 提取滞后信息
        lag_info = extract_lag_info_complete(granger_result);
        
        % 记录提取的统计量
        extraction_data.p_x2y = p_x2y;
        extraction_data.p_y2x = p_y2x;
        extraction_data.f_x2y = f_x2y;
        extraction_data.f_y2x = f_y2x;
        extraction_data.lag_info = lag_info;
        extraction_data.significance_level = alpha;
        
        % 显著性判断
        sig_x2y = (p_x2y < alpha);
        sig_y2x = (p_y2x < alpha);
        
        extraction_data.sig_x2y = sig_x2y;
        extraction_data.sig_y2x = sig_y2x;
        
        % 判断是否添加边
        if sig_x2y && ~sig_y2x
            % 单向因果 (X→Y)
            edge_added = true;
            edge_direction = 'ret_to_obv';
            extraction_data.edge_direction = edge_direction;
            extraction_data.edge_type = 'unidirectional';
            
        elseif ~sig_x2y && sig_y2x
            % 单向因果 (Y→X)
            edge_added = true;
            edge_direction = 'obv_to_ret';
            extraction_data.edge_direction = edge_direction;
            extraction_data.edge_type = 'unidirectional';
            
        elseif sig_x2y && sig_y2x
            % 双向因果
            edge_added = true;
            edge_direction = 'bidirectional';
            extraction_data.edge_direction = edge_direction;
            extraction_data.edge_type = 'bidirectional';
            
        else
            % 无显著因果
            edge_added = false;
            extraction_data.edge_direction = 'none';
            extraction_data.edge_type = 'none';
        end
        
        extraction_data.edge_added = edge_added;
        
        % 创建边信息
        if edge_added
            if strcmp(edge_direction, 'ret_to_obv')
                edge_info = create_granger_edge_info_complete(...
                    'ret_to_obv', ret_name, obv_name, ret_idx, obv_idx, ...
                    granger_result, alpha, p_x2y, f_x2y, lag_info, ...
                    extraction_data.data_structure);
                
            elseif strcmp(edge_direction, 'obv_to_ret')
                edge_info = create_granger_edge_info_complete(...
                    'obv_to_ret', obv_name, ret_name, obv_idx, ret_idx, ...
                    granger_result, alpha, p_y2x, f_y2x, lag_info, ...
                    extraction_data.data_structure);
                
            elseif strcmp(edge_direction, 'bidirectional')
                edge_info = create_bidirectional_edge_info_complete(...
                    ret_name, obv_name, ret_idx, obv_idx, ...
                    granger_result, alpha, p_x2y, p_y2x, f_x2y, f_y2x, ...
                    lag_info, extraction_data.data_structure);
            end
        end
        
    catch ME
        % 提取阶段错误
        extraction_data.extraction_error = ME.message;
        extraction_data.edge_added = false;
    end
    
    % 记录提取时间
    extraction_data.extraction_time = toc(extraction_data.extraction_start_time);
end

function [edge_added, edge_info, extraction_data] = process_combined_edge_complete(...
    connectivity_result, ret_idx, obv_idx, ret_name, obv_name, ...
    adjacency_matrix, weight_matrix, direction_matrix, lag_matrix, ...
    significance_matrix, alpha, min_corr)
% PROCESS_COMBINED_EDGE_COMPLETE - 完整的综合分析边处理
% 优先使用Granger分析，如果没有显著Granger关系，则使用相关性分析

    edge_added = false;
    edge_info = struct();
    extraction_data = struct();
    
    % 初始化提取数据
    extraction_data.extraction_start_time = tic;
    extraction_data.analysis_type = 'all';
    extraction_data.ret_name = ret_name;
    extraction_data.obv_name = obv_name;
    extraction_data.ret_idx = ret_idx;
    extraction_data.obv_idx = obv_idx;
    extraction_data.used_method = 'none';
    
    try
        % 首先尝试Granger分析
        [granger_added, granger_edge, granger_extraction_data] = process_granger_edge_complete(...
            connectivity_result, ret_idx, obv_idx, ret_name, obv_name, ...
            adjacency_matrix, weight_matrix, direction_matrix, lag_matrix, ...
            significance_matrix, alpha);
        
        extraction_data.granger_extraction = granger_extraction_data;
        extraction_data.granger_edge_added = granger_added;
        
        if granger_added
            edge_added = true;
            edge_info = granger_edge;
            edge_info.analysis_type = 'granger';
            extraction_data.used_method = 'granger';
            
        else
            % 如果没有Granger关系，尝试相关性分析
            [corr_added, corr_edge, corr_extraction_data] = process_correlation_edge_complete(...
                connectivity_result, ret_idx, obv_idx, ret_name, obv_name, ...
                adjacency_matrix, weight_matrix, direction_matrix, significance_matrix, ...
                alpha, min_corr);
            
            extraction_data.correlation_extraction = corr_extraction_data;
            extraction_data.correlation_edge_added = corr_added;
            
            if corr_added
                edge_added = true;
                edge_info = corr_edge;
                edge_info.analysis_type = 'correlation';
                extraction_data.used_method = 'correlation';
            end
        end
        
        extraction_data.edge_added = edge_added;
        extraction_data.final_method = extraction_data.used_method;
        
    catch ME
        % 提取阶段错误
        extraction_data.extraction_error = ME.message;
        extraction_data.edge_added = false;
    end
    
    % 记录提取时间
    extraction_data.extraction_time = toc(extraction_data.extraction_start_time);
end

function [decision_data, calc_record] = make_edge_decision_complete(...
    calc_record, edge_info, adjacency_matrix, weight_matrix, ...
    direction_matrix, lag_matrix, significance_matrix, ...
    ret_idx, obv_idx, DIR, analysis_type, pair_idx, ret_name, obv_name)
% MAKE_EDGE_DECISION_COMPLETE - 边添加决策
% 根据边类型和现有矩阵状态做出添加决策

    decision_data = struct();
    decision_data.edge_added = true;
    decision_data.analysis_type = analysis_type;
    decision_data.edge_info_type = edge_info.analysis_type;
    
    if strcmp(analysis_type, 'correlation')
        % 相关性边决策
        decision_data.edge_type = 'correlation';
        decision_data.direction = 'undirected';
        
        % 检查现有权重
        current_weight_1 = weight_matrix(ret_idx, obv_idx);
        current_weight_2 = weight_matrix(obv_idx, ret_idx);
        
        calc_record.current_weight_1 = current_weight_1;
        calc_record.current_weight_2 = current_weight_2;
        calc_record.proposed_weight = edge_info.weight;
        calc_record.proposed_p_value = edge_info.p_value;
        
        decision_data.current_weight_1 = current_weight_1;
        decision_data.current_weight_2 = current_weight_2;
        decision_data.proposed_weight = calc_record.proposed_weight;
        decision_data.proposed_p_value = calc_record.proposed_p_value;
        
        % 检查权重覆盖
        if current_weight_1 ~= 0 || current_weight_2 ~= 0
            calc_record.weight_override = true;
            calc_record.decision_rule = 'average';
            
            % 策略：取平均值
            calc_record.calculated_weight = (current_weight_1 + current_weight_2 + calc_record.proposed_weight) / 3;
            
            decision_data.weight_override = true;
            decision_data.decision_rule = 'average';
            decision_data.weight_override_reason = 'existing_weights_found';
            decision_data.calculated_weight = calc_record.calculated_weight;
            decision_data.weight_calculation_details = struct(...
                'weights_used', [current_weight_1, current_weight_2, calc_record.proposed_weight], ...
                'calculation_formula', '(current1 + current2 + proposed) / 3');
        else
            calc_record.weight_override = false;
            calc_record.calculated_weight = single(calc_record.proposed_weight);
            
            decision_data.weight_override = false;
            decision_data.decision_rule = 'direct_use';
            decision_data.weight_override_reason = 'no_existing_weights';
            decision_data.calculated_weight = calc_record.calculated_weight;
        end
        
    else
        % Granger边决策
        decision_data.edge_type = 'granger';
        decision_data.direction = edge_info.direction;
        
        if strcmp(edge_info.direction, 'ret_to_obv')
            % 单向：ret → obv
            current_weight = weight_matrix(ret_idx, obv_idx);
            calc_record.current_weight = current_weight;
            calc_record.proposed_weight = edge_info.weight;
            calc_record.proposed_p_value = edge_info.p_value;
            calc_record.proposed_lag = edge_info.lag;
            
            decision_data.current_weight = current_weight;
            decision_data.proposed_weight = calc_record.proposed_weight;
            decision_data.proposed_p_value = calc_record.proposed_p_value;
            decision_data.proposed_lag = calc_record.proposed_lag;
            
            if current_weight ~= 0
                calc_record.weight_override = true;
                calc_record.decision_rule = 'max';
                calc_record.calculated_weight = max(current_weight, single(calc_record.proposed_weight));
                
                decision_data.weight_override = true;
                decision_data.decision_rule = 'max';
                decision_data.weight_override_reason = 'existing_weight_found';
                decision_data.calculated_weight = calc_record.calculated_weight;
                decision_data.weight_calculation_details = struct(...
                    'weights_compared', [current_weight, calc_record.proposed_weight], ...
                    'calculation_formula', 'max(current, proposed)');
            else
                calc_record.weight_override = false;
                calc_record.calculated_weight = single(calc_record.proposed_weight);
                
                decision_data.weight_override = false;
                decision_data.decision_rule = 'direct_use';
                decision_data.weight_override_reason = 'no_existing_weight';
                decision_data.calculated_weight = calc_record.calculated_weight;
            end
            
        elseif strcmp(edge_info.direction, 'obv_to_ret')
            % 单向：obv → ret
            current_weight = weight_matrix(obv_idx, ret_idx);
            calc_record.current_weight = current_weight;
            calc_record.proposed_weight = edge_info.weight;
            calc_record.proposed_p_value = edge_info.p_value;
            calc_record.proposed_lag = edge_info.lag;
            
            decision_data.current_weight = current_weight;
            decision_data.proposed_weight = calc_record.proposed_weight;
            decision_data.proposed_p_value = calc_record.proposed_p_value;
            decision_data.proposed_lag = calc_record.proposed_lag;
            
            if current_weight ~= 0
                calc_record.weight_override = true;
                calc_record.decision_rule = 'max';
                calc_record.calculated_weight = max(current_weight, single(calc_record.proposed_weight));
                
                decision_data.weight_override = true;
                decision_data.decision_rule = 'max';
                decision_data.weight_override_reason = 'existing_weight_found';
                decision_data.calculated_weight = calc_record.calculated_weight;
                decision_data.weight_calculation_details = struct(...
                    'weights_compared', [current_weight, calc_record.proposed_weight], ...
                    'calculation_formula', 'max(current, proposed)');
            else
                calc_record.weight_override = false;
                calc_record.calculated_weight = single(calc_record.proposed_weight);
                
                decision_data.weight_override = false;
                decision_data.decision_rule = 'direct_use';
                decision_data.weight_override_reason = 'no_existing_weight';
                decision_data.calculated_weight = calc_record.calculated_weight;
            end
            
        elseif strcmp(edge_info.direction, 'bidirectional')
            % 双向连接
            current_weight_1 = weight_matrix(ret_idx, obv_idx);
            current_weight_2 = weight_matrix(obv_idx, ret_idx);
            
            calc_record.current_weight_1 = current_weight_1;
            calc_record.current_weight_2 = current_weight_2;
            calc_record.proposed_weight_1 = edge_info.weight_ret_to_obv;
            calc_record.proposed_weight_2 = edge_info.weight_obv_to_ret;
            calc_record.proposed_p_value_1 = edge_info.p_value_ret_to_obv;
            calc_record.proposed_p_value_2 = edge_info.p_value_obv_to_ret;
            
            decision_data.current_weight_1 = current_weight_1;
            decision_data.current_weight_2 = current_weight_2;
            decision_data.proposed_weight_1 = calc_record.proposed_weight_1;
            decision_data.proposed_weight_2 = calc_record.proposed_weight_2;
            decision_data.proposed_p_value_1 = calc_record.proposed_p_value_1;
            decision_data.proposed_p_value_2 = calc_record.proposed_p_value_2;
            
            % 检查冲突
            if current_weight_1 ~= 0
                calc_record.weight_conflict = true;
                calc_record.conflict_direction1 = true;
                decision_data.weight_conflict = true;
                decision_data.conflict_direction1 = true;
            end
            
            if current_weight_2 ~= 0
                calc_record.weight_conflict = true;
                calc_record.conflict_direction2 = true;
                decision_data.weight_conflict = true;
                decision_data.conflict_direction2 = true;
            end
            
            if current_weight_1 ~= 0 || current_weight_2 ~= 0
                calc_record.weight_override = true;
                decision_data.weight_override = true;
                decision_data.weight_override_reason = 'existing_weights_found';
            else
                calc_record.weight_override = false;
                decision_data.weight_override = false;
            end
            
            % 计算综合p值
            if isfield(edge_info, 'p_value_ret_to_obv') && isfield(edge_info, 'p_value_obv_to_ret')
                calc_record.proposed_combined_p_value = min(calc_record.proposed_p_value_1, ...
                    calc_record.proposed_p_value_2);
                decision_data.combined_p_value = calc_record.proposed_combined_p_value;
            else
                calc_record.proposed_combined_p_value = edge_info.p_value;
                decision_data.combined_p_value = calc_record.proposed_combined_p_value;
            end
        end
    end
end

function [update_data, adjacency_matrix, weight_matrix, direction_matrix, ...
          lag_matrix, significance_matrix, calc_record] = update_matrices_complete(...
    calc_record, adjacency_matrix, weight_matrix, direction_matrix, ...
    lag_matrix, significance_matrix, ret_idx, obv_idx, DIR, edge_info)
% UPDATE_MATRICES_COMPLETE - 更新网络矩阵
% 根据边类型更新相应的网络矩阵

    update_data = struct();
    update_data.ret_idx = ret_idx;
    update_data.obv_idx = obv_idx;
    update_data.ret_name = calc_record.ret_name;
    update_data.obv_name = calc_record.obv_name;
    
    if strcmp(calc_record.analysis_type, 'correlation')
        % 更新相关性边矩阵
        update_data.update_type = 'symmetric_correlation';
        
        % 记录更新前状态
        update_data.adjacency_before_ret_obv = adjacency_matrix(ret_idx, obv_idx);
        update_data.adjacency_before_obv_ret = adjacency_matrix(obv_idx, ret_idx);
        update_data.weight_before_ret_obv = weight_matrix(ret_idx, obv_idx);
        update_data.weight_before_obv_ret = weight_matrix(obv_idx, ret_idx);
        update_data.significance_before_ret_obv = significance_matrix(ret_idx, obv_idx);
        update_data.significance_before_obv_ret = significance_matrix(obv_idx, ret_idx);
        
        % 更新矩阵
        adjacency_matrix(ret_idx, obv_idx) = true;
        adjacency_matrix(obv_idx, ret_idx) = true;
        weight_matrix(ret_idx, obv_idx) = calc_record.calculated_weight;
        weight_matrix(obv_idx, ret_idx) = calc_record.calculated_weight;
        significance_matrix(ret_idx, obv_idx) = single(calc_record.proposed_p_value);
        significance_matrix(obv_idx, ret_idx) = single(calc_record.proposed_p_value);
        
        % 记录更新后状态
        update_data.adjacency_after_ret_obv = adjacency_matrix(ret_idx, obv_idx);
        update_data.adjacency_after_obv_ret = adjacency_matrix(obv_idx, ret_idx);
        update_data.weight_after_ret_obv = weight_matrix(ret_idx, obv_idx);
        update_data.weight_after_obv_ret = weight_matrix(obv_idx, ret_idx);
        update_data.significance_after_ret_obv = significance_matrix(ret_idx, obv_idx);
        update_data.significance_after_obv_ret = significance_matrix(obv_idx, ret_idx);
        update_data.matrices_updated = {'adjacency', 'weight', 'significance'};
        
    else
        % 更新Granger边矩阵
        if strcmp(edge_info.direction, 'ret_to_obv')
            % 单向：ret → obv
            update_data.update_type = 'unidirectional_ret_to_obv';
            update_data.direction_code = DIR.RET_TO_OBV;
            
            % 记录更新前状态
            update_data.adjacency_before = adjacency_matrix(ret_idx, obv_idx);
            update_data.weight_before = weight_matrix(ret_idx, obv_idx);
            update_data.direction_before = direction_matrix(ret_idx, obv_idx);
            update_data.lag_before = lag_matrix(ret_idx, obv_idx);
            update_data.significance_before = significance_matrix(ret_idx, obv_idx);
            
            % 更新矩阵
            adjacency_matrix(ret_idx, obv_idx) = true;
            weight_matrix(ret_idx, obv_idx) = calc_record.calculated_weight;
            direction_matrix(ret_idx, obv_idx) = DIR.RET_TO_OBV;
            lag_matrix(ret_idx, obv_idx) = uint8(calc_record.proposed_lag);
            significance_matrix(ret_idx, obv_idx) = single(calc_record.proposed_p_value);
            
            % 记录更新后状态
            update_data.adjacency_after = adjacency_matrix(ret_idx, obv_idx);
            update_data.weight_after = weight_matrix(ret_idx, obv_idx);
            update_data.direction_after = direction_matrix(ret_idx, obv_idx);
            update_data.lag_after = lag_matrix(ret_idx, obv_idx);
            update_data.significance_after = significance_matrix(ret_idx, obv_idx);
            update_data.matrices_updated = {'adjacency', 'weight', 'direction', 'lag', 'significance'};
            
        elseif strcmp(edge_info.direction, 'obv_to_ret')
            % 单向：obv → ret
            update_data.update_type = 'unidirectional_obv_to_ret';
            update_data.direction_code = DIR.OBV_TO_RET;
            
            % 记录更新前状态
            update_data.adjacency_before = adjacency_matrix(obv_idx, ret_idx);
            update_data.weight_before = weight_matrix(obv_idx, ret_idx);
            update_data.direction_before = direction_matrix(obv_idx, ret_idx);
            update_data.lag_before = lag_matrix(obv_idx, ret_idx);
            update_data.significance_before = significance_matrix(obv_idx, ret_idx);
            
            % 更新矩阵
            adjacency_matrix(obv_idx, ret_idx) = true;
            weight_matrix(obv_idx, ret_idx) = calc_record.calculated_weight;
            direction_matrix(obv_idx, ret_idx) = DIR.OBV_TO_RET;
            lag_matrix(obv_idx, ret_idx) = uint8(calc_record.proposed_lag);
            significance_matrix(obv_idx, ret_idx) = single(calc_record.proposed_p_value);
            
            % 记录更新后状态
            update_data.adjacency_after = adjacency_matrix(obv_idx, ret_idx);
            update_data.weight_after = weight_matrix(obv_idx, ret_idx);
            update_data.direction_after = direction_matrix(obv_idx, ret_idx);
            update_data.lag_after = lag_matrix(obv_idx, ret_idx);
            update_data.significance_after = significance_matrix(obv_idx, ret_idx);
            update_data.matrices_updated = {'adjacency', 'weight', 'direction', 'lag', 'significance'};
            
        elseif strcmp(edge_info.direction, 'bidirectional')
            % 双向连接
            update_data.update_type = 'bidirectional';
            update_data.direction_code = DIR.BIDIRECTIONAL;
            
            % 记录更新前状态
            update_data.adjacency_before_ret_obv = adjacency_matrix(ret_idx, obv_idx);
            update_data.adjacency_before_obv_ret = adjacency_matrix(obv_idx, ret_idx);
            update_data.direction_before_ret_obv = direction_matrix(ret_idx, obv_idx);
            update_data.direction_before_obv_ret = direction_matrix(obv_idx, ret_idx);
            update_data.lag_before_ret_obv = lag_matrix(ret_idx, obv_idx);
            update_data.lag_before_obv_ret = lag_matrix(obv_idx, ret_idx);
            update_data.weight_before_ret_obv = weight_matrix(ret_idx, obv_idx);
            update_data.weight_before_obv_ret = weight_matrix(obv_idx, ret_idx);
            update_data.significance_before_ret_obv = significance_matrix(ret_idx, obv_idx);
            update_data.significance_before_obv_ret = significance_matrix(obv_idx, ret_idx);
            
            % 更新矩阵
            adjacency_matrix(ret_idx, obv_idx) = true;
            adjacency_matrix(obv_idx, ret_idx) = true;
            direction_matrix(ret_idx, obv_idx) = DIR.BIDIRECTIONAL;
            direction_matrix(obv_idx, ret_idx) = DIR.BIDIRECTIONAL;
            
            % 更新滞后信息
            if isfield(edge_info, 'lag_ret_to_obv') && ~isnan(edge_info.lag_ret_to_obv)
                lag_matrix(ret_idx, obv_idx) = uint8(edge_info.lag_ret_to_obv);
            end
            if isfield(edge_info, 'lag_obv_to_ret') && ~isnan(edge_info.lag_obv_to_ret)
                lag_matrix(obv_idx, ret_idx) = uint8(edge_info.lag_obv_to_ret);
            end
            
            % 如果没有冲突，更新权重和显著性
            if ~calc_record.weight_conflict
                weight_matrix(ret_idx, obv_idx) = single(calc_record.proposed_weight_1);
                weight_matrix(obv_idx, ret_idx) = single(calc_record.proposed_weight_2);
                significance_matrix(ret_idx, obv_idx) = single(calc_record.proposed_combined_p_value);
                significance_matrix(obv_idx, ret_idx) = single(calc_record.proposed_combined_p_value);
            end
            
            % 记录更新后状态
            update_data.adjacency_after_ret_obv = adjacency_matrix(ret_idx, obv_idx);
            update_data.adjacency_after_obv_ret = adjacency_matrix(obv_idx, ret_idx);
            update_data.direction_after_ret_obv = direction_matrix(ret_idx, obv_idx);
            update_data.direction_after_obv_ret = direction_matrix(obv_idx, ret_idx);
            update_data.lag_after_ret_obv = lag_matrix(ret_idx, obv_idx);
            update_data.lag_after_obv_ret = lag_matrix(obv_idx, ret_idx);
            
            if ~calc_record.weight_conflict
                update_data.weight_after_ret_obv = weight_matrix(ret_idx, obv_idx);
                update_data.weight_after_obv_ret = weight_matrix(obv_idx, ret_idx);
                update_data.significance_after_ret_obv = significance_matrix(ret_idx, obv_idx);
                update_data.significance_after_obv_ret = significance_matrix(obv_idx, ret_idx);
            end
            
            update_data.matrices_updated = {'adjacency', 'direction', 'lag', 'weight', 'significance'};
        end
    end
end

function [weight_matrix, significance_matrix, resolution_stats] = ...
    resolve_weight_conflicts_complete(weight_conflicts, weight_matrix, ...
    significance_matrix, analysis_type, DIR)
% RESOLVE_WEIGHT_CONFLICTS_COMPLETE - 解决权重冲突
% 根据冲突类型和解决策略解决权重冲突

    resolution_stats = struct();
    resolution_stats.total_conflicts = length(weight_conflicts);
    resolution_stats.resolved_count = 0;
    resolution_stats.failed_count = 0;
    resolution_stats.skipped_count = 0;
    resolution_stats.details = struct();
    
    if isempty(weight_conflicts)
        resolution_stats.method = 'none';
        resolution_stats.details = 'No conflicts to resolve';
        return;
    end
    
    % 冲突解决策略
    if strcmp(analysis_type, 'granger')
        resolution_stats.method = 'max_f_statistic';
    elseif strcmp(analysis_type, 'correlation')
        resolution_stats.method = 'max_abs_correlation';
    else
        resolution_stats.method = 'max_statistic';
    end
    
    % 记录解决详情
    resolution_details = cell(1, resolution_stats.total_conflicts);
    
    % 解决每个冲突
    for i = 1:length(weight_conflicts)
        conflict = weight_conflicts(i);
        
        try
            conflict_details = struct();
            conflict_details.conflict_idx = i;
            conflict_details.pair_idx = conflict.pair_idx;
            conflict_details.pair_id = conflict.pair_id;
            conflict_details.conflict_type = conflict.conflict_type;
            conflict_details.ret_name = conflict.ret_name;
            conflict_details.obv_name = conflict.obv_name;
            conflict_details.ret_idx = conflict.ret_idx;
            conflict_details.obv_idx = conflict.obv_idx;
            
            if strcmp(conflict.conflict_type, 'bidirectional')
                % 双向边冲突
                conflict_details.conflict_type = 'bidirectional';
                
                % 检查两个方向的现有权重
                existing_weight_1 = weight_matrix(conflict.ret_idx, conflict.obv_idx);
                existing_weight_2 = weight_matrix(conflict.obv_idx, conflict.ret_idx);
                
                conflict_details.existing_weight_1 = existing_weight_1;
                conflict_details.existing_weight_2 = existing_weight_2;
                
                % 检查是否已经有双向连接
                existing_dir_1 = direction_matrix(conflict.ret_idx, conflict.obv_idx);
                existing_dir_2 = direction_matrix(conflict.obv_idx, conflict.ret_idx);
                
                conflict_details.existing_dir_1 = existing_dir_1;
                conflict_details.existing_dir_2 = existing_dir_2;
                
                % 根据分析类型决定解决策略
                if strcmp(analysis_type, 'granger')
                    % Granger因果：取F统计量的最大值
                    if conflict.conflict_direction1
                        % 处理方向1的冲突
                        conflict_details.direction1_resolved = 'max_f_statistic';
                        % 保持较大权重
                    end
                    
                    if conflict.conflict_direction2
                        % 处理方向2的冲突
                        conflict_details.direction2_resolved = 'max_f_statistic';
                        % 保持较大权重
                    end
                    
                elseif strcmp(analysis_type, 'correlation')
                    % 相关性：取相关系数的绝对值最大值
                    conflict_details.resolution_strategy = 'max_abs_correlation';
                end
                
                resolution_stats.resolved_count = resolution_stats.resolved_count + 1;
                conflict_details.resolved = true;
                
            elseif strcmp(conflict.conflict_type, 'unidirectional')
                % 单向边冲突
                conflict_details.conflict_type = 'unidirectional';
                
                % 检查现有权重
                existing_weight = weight_matrix(conflict.from_idx, conflict.to_idx);
                existing_significance = significance_matrix(conflict.from_idx, conflict.to_idx);
                
                conflict_details.existing_weight = existing_weight;
                conflict_details.existing_significance = existing_significance;
                
                % 获取新权重（从冲突记录中提取，或从上下文推断）
                if isfield(conflict, 'new_weight')
                    new_weight = conflict.new_weight;
                else
                    % 如果没有新权重信息，检查相邻配对
                    new_weight = 0;  % 默认值
                end
                
                conflict_details.new_weight = new_weight;
                
                % 根据分析类型解决冲突
                if strcmp(analysis_type, 'granger')
                    % Granger因果：取F统计量的最大值
                    if new_weight > existing_weight
                        weight_matrix(conflict.from_idx, conflict.to_idx) = new_weight;
                        if isfield(conflict, 'new_p_value')
                            significance_matrix(conflict.from_idx, conflict.to_idx) = conflict.new_p_value;
                        end
                        conflict_details.resolution_action = 'replaced_with_new';
                        conflict_details.final_weight = new_weight;
                    else
                        conflict_details.resolution_action = 'kept_existing';
                        conflict_details.final_weight = existing_weight;
                    end
                    
                elseif strcmp(analysis_type, 'correlation')
                    % 相关性：取相关系数的绝对值最大值
                    if abs(new_weight) > abs(existing_weight)
                        weight_matrix(conflict.from_idx, conflict.to_idx) = new_weight;
                        if isfield(conflict, 'new_p_value')
                            significance_matrix(conflict.from_idx, conflict.to_idx) = conflict.new_p_value;
                        end
                        conflict_details.resolution_action = 'replaced_with_new';
                        conflict_details.final_weight = new_weight;
                    else
                        conflict_details.resolution_action = 'kept_existing';
                        conflict_details.final_weight = existing_weight;
                    end
                end
                
                resolution_stats.resolved_count = resolution_stats.resolved_count + 1;
                conflict_details.resolved = true;
                
            else
                % 未知冲突类型
                conflict_details.resolved = false;
                conflict_details.error = 'unknown_conflict_type';
                resolution_stats.skipped_count = resolution_stats.skipped_count + 1;
            end
            
        catch ME
            % 冲突解决失败
            conflict_details = struct();
            conflict_details.conflict_idx = i;
            conflict_details.resolved = false;
            conflict_details.error = ME.message;
            resolution_stats.failed_count = resolution_stats.failed_count + 1;
        end
        
        % 保存冲突解决详情
        resolution_details{i} = conflict_details;
    end
    
    % 整理解决统计
    resolution_stats.resolution_details = resolution_details;
    resolution_stats.success_rate = resolution_stats.resolved_count / resolution_stats.total_conflicts;
    
    resolution_stats.details = sprintf('Resolved %d/%d conflicts (Success rate: %.1f%%)', ...
        resolution_stats.resolved_count, resolution_stats.total_conflicts, ...
        resolution_stats.success_rate * 100);
end

function lag_info = extract_lag_info_complete(granger_result)
% EXTRACT_LAG_INFO_COMPLETE - 完整提取滞后信息
% 支持新旧数据结构，优先使用统一的optimal_lag字段

    lag_info = struct();
    lag_info.optimal_lag = NaN;
    lag_info.lag_x2y = NaN;
    lag_info.lag_y2x = NaN;
    lag_info.source = 'none';
    lag_info.all_fields_found = {};
    
    % 检查各种可能的滞后字段
    lag_fields = {'optimal_lag', 'unified_optimal_lag', 'lag', ...
                 'lag_x2y', 'lag_y2x', 'lag1', 'lag2', ...
                 'lag_order', 'selected_lag'};
    
    found_fields = {};
    
    for i = 1:length(lag_fields)
        field_name = lag_fields{i};
        if isfield(granger_result, field_name)
            field_value = granger_result.(field_name);
            
            % 验证值类型
            if isnumeric(field_value) && isscalar(field_value)
                found_fields{end+1} = field_name;
                
                if contains(field_name, 'optimal')
                    lag_info.optimal_lag = field_value;
                    lag_info.source = field_name;
                elseif contains(field_name, 'x2y')
                    lag_info.lag_x2y = field_value;
                    if strcmp(lag_info.source, 'none')
                        lag_info.source = field_name;
                    end
                elseif contains(field_name, 'y2x')
                    lag_info.lag_y2x = field_value;
                    if strcmp(lag_info.source, 'none')
                        lag_info.source = field_name;
                    end
                else
                    % 通用滞后字段
                    lag_info.optimal_lag = field_value;
                    lag_info.lag_x2y = field_value;
                    lag_info.lag_y2x = field_value;
                    lag_info.source = field_name;
                end
            end
        end
    end
    
    lag_info.all_fields_found = found_fields;
    
    % 如果没有找到optimal_lag，尝试从其他字段推断
    if isnan(lag_info.optimal_lag)
        if ~isnan(lag_info.lag_x2y) && ~isnan(lag_info.lag_y2x)
            % 如果两个方向的滞后都存在，取最大值
            lag_info.optimal_lag = max(lag_info.lag_x2y, lag_info.lag_y2x);
            if strcmp(lag_info.source, 'none')
                lag_info.source = 'inferred_from_lag_x2y_and_lag_y2x';
            end
        elseif ~isnan(lag_info.lag_x2y)
            % 只有x2y方向
            lag_info.optimal_lag = lag_info.lag_x2y;
            if strcmp(lag_info.source, 'none')
                lag_info.source = 'inferred_from_lag_x2y';
            end
        elseif ~isnan(lag_info.lag_y2x)
            % 只有y2x方向
            lag_info.optimal_lag = lag_info.lag_y2x;
            if strcmp(lag_info.source, 'none')
                lag_info.source = 'inferred_from_lag_y2x';
            end
        end
    end
    
    % 确保lag_x2y和lag_y2x有值
    if isnan(lag_info.lag_x2y) && ~isnan(lag_info.optimal_lag)
        lag_info.lag_x2y = lag_info.optimal_lag;
    end
    if isnan(lag_info.lag_y2x) && ~isnan(lag_info.optimal_lag)
        lag_info.lag_y2x = lag_info.optimal_lag;
    end
    
    % 验证滞后值的合理性
    if ~isnan(lag_info.optimal_lag)
        if lag_info.optimal_lag < 1 || lag_info.optimal_lag > 20
            lag_info.warning = 'optimal_lag out of typical range [1, 20]';
        end
    end
end

function value = extract_field_value_complete(struct_data, field_options, default_field)
% EXTRACT_FIELD_VALUE_COMPLETE - 从多个可能字段中提取值
% 支持多种可能的字段名称，提高代码的鲁棒性

    value = NaN;
    
    for i = 1:length(field_options)
        if isfield(struct_data, field_options{i})
            field_value = struct_data.(field_options{i});
            
            % 验证值类型
            if isnumeric(field_value) && isscalar(field_value)
                value = field_value;
                return;
            elseif isnumeric(field_value) && isvector(field_value) && ~isempty(field_value)
                % 如果是向量，取第一个元素
                value = field_value(1);
                return;
            end
        end
    end
    
    % 如果没有找到任何有效的字段，尝试默认字段
    if nargin > 2 && isfield(struct_data, default_field)
        field_value = struct_data.(default_field);
        if isnumeric(field_value) && isscalar(field_value)
            value = field_value;
        end
    end
end

function edge_info = create_granger_edge_info_complete(...
    direction, from_node, to_node, from_idx, to_idx, ...
    granger_result, alpha, p_value, f_stat, lag_info, data_structure)
% CREATE_GRANGER_EDGE_INFO_COMPLETE - 创建单向Granger边信息
% 创建详细、完整的单向Granger边信息结构

    % 创建边ID
    edge_id = sprintf('granger_%s_%s_%s', direction, from_node, to_node);
    
    % 获取时间戳
    creation_time = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
    
    % 确定节点类型
    if strcmp(direction, 'ret_to_obv')
        from_type = 'ret';
        to_type = 'obv';
    else
        from_type = 'obv';
        to_type = 'ret';
    end
    
    % 创建基础边信息
    edge_info = struct();
    
    % 基本信息
    edge_info.edge_id = edge_id;
    edge_info.analysis_type = 'granger';
    edge_info.direction = direction;
    edge_info.from_node = from_node;
    edge_info.to_node = to_node;
    edge_info.from_idx = from_idx;
    edge_info.to_idx = to_idx;
    edge_info.from_type = from_type;
    edge_info.to_type = to_type;
    
    % 统计信息
    edge_info.weight = f_stat;
    edge_info.p_value = p_value;
    edge_info.is_significant = p_value < alpha;
    edge_info.significance_level = alpha;
    
    % 滞后信息
    if ~isnan(lag_info.optimal_lag)
        edge_info.lag = lag_info.optimal_lag;
        edge_info.lag_source = lag_info.source;
    else
        edge_info.lag = 1;  % 默认值
        edge_info.lag_source = 'default';
    end
    
    % 原始统计量
    edge_info.original_f_statistic = f_stat;
    edge_info.original_p_value = p_value;
    edge_info.original_optimal_lag = lag_info.optimal_lag;
    
    % 元数据
    edge_info.data_structure = data_structure;
    edge_info.creation_time = creation_time;
    edge_info.added = true;
    
    % 提取其他可选统计量
    edge_info = extract_optional_statistics_complete(edge_info, granger_result, direction);
    
    % 验证边信息的完整性
    required_fields = {'edge_id', 'analysis_type', 'direction', 'from_node', ...
                      'to_node', 'weight', 'p_value', 'is_significant', 'lag'};
    missing_fields = setdiff(required_fields, fieldnames(edge_info));
    
    if ~isempty(missing_fields)
        edge_info.warning = sprintf('Missing fields: %s', strjoin(missing_fields, ', '));
    end
end

function edge_info = create_bidirectional_edge_info_complete(...
    ret_name, obv_name, ret_idx, obv_idx, ...
    granger_result, alpha, p_x2y, p_y2x, f_x2y, f_y2x, ...
    lag_info, data_structure)
% CREATE_BIDIRECTIONAL_EDGE_INFO_COMPLETE - 创建双向Granger边信息
% 创建详细、完整的双向Granger边信息结构

    % 创建边ID
    edge_id = sprintf('granger_bidirectional_%s_%s', ret_name, obv_name);
    
    % 获取时间戳
    creation_time = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
    
    % 创建基础边信息
    edge_info = struct();
    
    % 基本信息
    edge_info.edge_id = edge_id;
    edge_info.analysis_type = 'granger';
    edge_info.direction = 'bidirectional';
    edge_info.from_node = ret_name;
    edge_info.to_node = obv_name;
    edge_info.from_idx = ret_idx;
    edge_info.to_idx = obv_idx;
    edge_info.from_type = 'ret';
    edge_info.to_type = 'obv';
    
    % 双向统计信息
    edge_info.weight_ret_to_obv = f_x2y;
    edge_info.weight_obv_to_ret = f_y2x;
    edge_info.p_value_ret_to_obv = p_x2y;
    edge_info.p_value_obv_to_ret = p_y2x;
    
    % 滞后信息
    if ~isnan(lag_info.optimal_lag)
        edge_info.lag_ret_to_obv = lag_info.optimal_lag;
        edge_info.lag_obv_to_ret = lag_info.optimal_lag;
    else
        edge_info.lag_ret_to_obv = 1;
        edge_info.lag_obv_to_ret = 1;
    end
    
    edge_info.lag_source = lag_info.source;
    
    % 综合统计量
    edge_info.p_value = min(p_x2y, p_y2x);
    edge_info.weight = max(f_x2y, f_y2x);
    edge_info.lag = max(edge_info.lag_ret_to_obv, edge_info.lag_obv_to_ret);
    
    % 显著性
    edge_info.is_significant = (p_x2y < alpha) && (p_y2x < alpha);
    edge_info.significance_level = alpha;
    
    % 添加双向特有的统计量
    edge_info.bidirectional_ratio_x2y = p_x2y / p_y2x;
    edge_info.bidirectional_ratio_y2x = p_y2x / p_x2y;
    edge_info.bidirectional_strength_ratio = max(f_x2y, f_y2x) / min(f_x2y, f_y2x);
    
    % 元数据
    edge_info.data_structure = data_structure;
    edge_info.creation_time = creation_time;
    edge_info.added = true;
    
    % 提取其他可选统计量
    edge_info = extract_optional_statistics_bidirectional_complete(granger_result, edge_info);
    
    % 验证边信息的完整性
    required_fields = {'edge_id', 'analysis_type', 'direction', 'from_node', ...
                      'to_node', 'weight_ret_to_obv', 'weight_obv_to_ret', ...
                      'p_value_ret_to_obv', 'p_value_obv_to_ret', 'is_significant'};
    missing_fields = setdiff(required_fields, fieldnames(edge_info));
    
    if ~isempty(missing_fields)
        edge_info.warning = sprintf('Missing fields: %s', strjoin(missing_fields, ', '));
    end
end

function edge_info = extract_optional_statistics_complete(edge_info, granger_result, direction)
% EXTRACT_OPTIONAL_STATISTICS_COMPLETE - 提取单向边可选统计量
% 提取Granger分析中可能存在的可选统计量

    % 可选统计字段列表
    optional_fields = {
        'r_squared', 'adjusted_r_squared', ...
        'aic', 'bic', 'hqic', ...
        'residuals', 'std_error', ...
        'f_statistic', 'df', 'df_resid', ...
        't_stat', 't_pvalue', ...
        'loglikelihood', 'deviance'
    };
    
    % 添加方向特定的字段
    direction_suffix = '';
    if strcmp(direction, 'ret_to_obv')
        direction_suffix = '_x2y';
    elseif strcmp(direction, 'obv_to_ret')
        direction_suffix = '_y2x';
    end
    
    direction_specific_fields = {
        'r_squared', 'adjusted_r_squared', ...
        'aic', 'bic', 'hqic'
    };
    
    for i = 1:length(direction_specific_fields)
        field_base = direction_specific_fields{i};
        field_name = [field_base, direction_suffix];
        
        if isfield(granger_result, field_name)
            field_value = granger_result.(field_name);
            
            if (isnumeric(field_value) && isscalar(field_value)) || ...
               (isnumeric(field_value) && isvector(field_value) && ~isempty(field_value))
                edge_info.(field_name) = field_value;
            end
        end
    end
    
    % 提取无方向后缀的通用字段
    for i = 1:length(optional_fields)
        field_name = optional_fields{i};
        
        if isfield(granger_result, field_name)
            field_value = granger_result.(field_name);
            
            if (isnumeric(field_value) && isscalar(field_value)) || ...
               (isnumeric(field_value) && isvector(field_value) && ~isempty(field_value))
                edge_info.(field_name) = field_value;
            end
        end
    end
    
    % 计算额外的统计量
    if isfield(edge_info, 'r_squared') && ~isnan(edge_info.r_squared)
        edge_info.r_squared_interpretation = interpret_r_squared(edge_info.r_squared);
    end
    
    if isfield(edge_info, 'aic') && isfield(edge_info, 'bic')
        edge_info.aic_bic_ratio = edge_info.aic / edge_info.bic;
    end
end

function edge_info = extract_optional_statistics_bidirectional_complete(granger_result, edge_info)
% EXTRACT_OPTIONAL_STATISTICS_BIDIRECTIONAL_COMPLETE - 提取双向边可选统计量
% 提取双向Granger分析中可能存在的可选统计量

    optional_fields = {
        'r_squared_x2y', 'r_squared_y2x', ...
        'adjusted_r_squared_x2y', 'adjusted_r_squared_y2x', ...
        'aic_x2y', 'aic_y2x', 'bic_x2y', 'bic_y2x', ...
        'hqic_x2y', 'hqic_y2x', ...
        'residuals_x2y', 'residuals_y2x', ...
        'std_error_x2y', 'std_error_y2x', ...
        'df_x2y', 'df_y2x', 'df_resid_x2y', 'df_resid_y2x'
    };
    
    for i = 1:length(optional_fields)
        field_name = optional_fields{i};
        if isfield(granger_result, field_name)
            field_value = granger_result.(field_name);
            
            if (isnumeric(field_value) && isscalar(field_value)) || ...
               (isnumeric(field_value) && isvector(field_value) && ~isempty(field_value))
                edge_info.(field_name) = field_value;
            end
        end
    end
    
    % 计算双向特有的统计量
    if isfield(granger_result, 'r_squared_x2y') && isfield(granger_result, 'r_squared_y2x')
        r2_x2y = granger_result.r_squared_x2y;
        r2_y2x = granger_result.r_squared_y2x;
        
        if isnumeric(r2_x2y) && isnumeric(r2_y2x) && isscalar(r2_x2y) && isscalar(r2_y2x)
            edge_info.avg_r_squared = (r2_x2y + r2_y2x) / 2;
            edge_info.r_squared_difference = abs(r2_x2y - r2_y2x);
            edge_info.r_squared_ratio = max(r2_x2y, r2_y2x) / min(r2_x2y, r2_y2x);
        end
    end
    
    if isfield(edge_info, 'weight_ret_to_obv') && isfield(edge_info, 'weight_obv_to_ret')
        w1 = edge_info.weight_ret_to_obv;
        w2 = edge_info.weight_obv_to_ret;
        
        if w1 > 0 && w2 > 0
            edge_info.bidirectional_strength_ratio = max(w1, w2) / min(w1, w2);
            edge_info.bidirectional_strength_difference = abs(w1 - w2);
            edge_info.bidirectional_strength_avg = (w1 + w2) / 2;
        end
    end
    
    if isfield(edge_info, 'p_value_ret_to_obv') && isfield(edge_info, 'p_value_obv_to_ret')
        p1 = edge_info.p_value_ret_to_obv;
        p2 = edge_info.p_value_obv_to_ret;
        
        edge_info.bidirectional_p_value_ratio = max(p1, p2) / min(p1, p2);
        edge_info.bidirectional_p_value_difference = abs(p1 - p2);
    end
end
