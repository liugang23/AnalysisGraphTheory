function [pairwise_results, pair_network] = connectivity_network_pipeline(...
    normalized_data, feature_names, dates_display)
%% 图论：连通性分析

%% =================  完整网络分析流程 =================
    % 1. 生成完全交叉配对
    fprintf('阶段1: 生成配对数据\n');
    [paired_data, pair_info] = create_price_volume_pairs(...
            normalized_data, feature_names, ...
            'verbose', true, ...      % 显示详细信息
            'min_period_gap', 5, ...  % 最小间隔
            'analysis_type', 'all');  % 全配对  
        
    % 2. 单独执行配对连通性分析
    fprintf('阶段2: 连通性分析\n');
    fprintf('========================================\n\n');
    % 选择分析方法: 'correlation', 'granger', 'transfer_entropy', 'cross_correlation', 'all'
    analysis_type = 'granger';  % 使用Granger因果检验
    pairwise_results = connectivity_pairwise_analyze(...
        paired_data, pair_info, analysis_type, ...
        'max_lag', 5, ...                       % 最大滞后阶数
        'significance_level', 0.05, ...         % 显著性水平
        'bootstrap_reps', 1000, ...             % 自助法重复次数
        'enable_robustness', true, ...          % 启用鲁棒性检查
        'robustness_n_bootstrap', 200, ...      % 鲁棒性自助法次数
        'robustness_noise_level', 0.01, ...     % 噪声水平
        'robustness_threshold', 0.7, ...        % 鲁棒性评分阈值
        'enable_nonlinear_test', true, ...      % 新增：启用非线性检测
        'bds_m', 2:5, ...                       % 新增：BDS嵌入维度
        'bds_epsilon', 0.5:0.5:1.5, ...         % 新增：BDS epsilon参数
        'verbose', true);
    
    % 3. 验证连通性分析结果
    fprintf('阶段3: 连通性结果验证\n');
    fprintf('========================================\n\n');
    
    % 3.1 基本结构验证
    [is_valid, validation_msg] = validate_connectivity_results(pairwise_results);
    if ~is_valid
        error('连通性分析结果验证失败: %s', validation_msg);
    end
%    fprintf('? 连通性分析结果结构验证通过\n');

    % 3.2 详细结果检查
    fprintf('\n详细结果检查:\n');
    fprintf('  配对总数: %d\n', length(pairwise_results.pair_info));
    fprintf('  有效结果数: %d\n', sum(~cellfun(@isempty, pairwise_results.connectivity)));

    % 检查前3个配对的结果
    for i = 1:min(3, length(pairwise_results.connectivity))
        if ~isempty(pairwise_results.connectivity{i})
            result = pairwise_results.connectivity{i};
            fprintf('\n  配对 %d:\n', i);
            if isfield(result, 'direction')
                fprintf('    方向: %s\n', result.direction);
            end
            if isfield(result, 'p_value_x2y')
                fprintf('    p_value_x2y: %.4f, 显著: %s\n', ...
                    result.p_value_x2y, bool2str(result.p_value_x2y < 0.05));
            end
            if isfield(result, 'p_value_y2x')
                fprintf('    p_value_y2x: %.4f, 显著: %s\n', ...
                    result.p_value_y2x, bool2str(result.p_value_y2x < 0.05));
            end
        end
    end
    % 基本使用
%    connectivity_report = evaluate_pairwise_connectivity(pairwise_results);

    % 详细报告并保存
    connectivity_report = evaluate_pairwise_connectivity(pairwise_results, ...
        'ReportLevel', 'detailed', ...
        'SaveReport', true, ...
        'OutputFigures', true);

    % 查看报告
    disp(connectivity_report.formatted_text);
    
    
    
    
    

    %% 4. 网络构建
    fprintf('阶段4: 网络构建\n');
    fprintf('========================================\n\n');

    pair_network = build_pair_network_complete(...
        pairwise_results, ...
        paired_data, ...
        analysis_type, pairwise_results.parameters.significance_level);
    
    % 5. 网络结构验证
    fprintf('阶段5: 网络结构验证\n');
    fprintf('========================================\n\n');

    [network_valid, network_msg] = validate_network_structure(pair_network);
    if ~network_valid
        warning('网络结构验证警告: %s', network_msg);
    else
        fprintf('? 网络结构验证通过\n');
    end
    
    fprintf('网络基本信息:\n');
    fprintf('  节点数: %d\n', pair_network.n_nodes);
    fprintf('  边数: %d\n', sum(pair_network.adjacency(:)));
    fprintf('  网络密度: %.4f\n', pair_network.density);
    
    % 基本使用
%    network_report = evaluate_constructed_network(pair_network);

    % 详细报告包含鲁棒性模拟
    network_report = evaluate_constructed_network_main(pair_network, ...
        'ReportLevel', 'detailed', ...
        'SaveReport', true, ...
        'TopK', 5);

    % 查看报告
    disp(network_report.formatted_text);
    
    % 示例1: 连通性分析可视化
    % -------------------------------------------------
    % 基本可视化
    fig1 = plot_pairwise_connectivity(pairwise_results);

    % 显著性详细分析
%    fig2 = plot_pairwise_connectivity(pairwise_results, ...
%        'FigureType', 'significance', ...
%        'SaveFigure', true, ...
%        'FigureName', 'Connectivity_Significance');

    % 鲁棒性分析
%    fig3 = plot_pairwise_connectivity(pairwise_results, ...
%        'FigureType', 'robustness', ...
%        'ColorMap', 'viridis');

    % 示例2: 网络可视化
    % -------------------------------------------------
    % 基本网络图
%    fig4 = plot_pairwise_network(pair_network);

    % 圆形布局，按介数中心性调整节点大小
%    fig5 = plot_pairwise_network(pair_network, ...
%        'Layout', 'circle', ...
%        'NodeSize', 'betweenness', ...
%        'NodeColor', 'type', ...
%        'SaveFigure', true);

    % 力导向布局，按社区着色
%    fig6 = plot_pairwise_network(pair_network, ...
%        'Layout', 'force', ...
%        'NodeColor', 'community', ...
%        'EdgeWidth', 'weight', ...
%        'ShowLabels', true);
    

    % 6. 网络拓扑分析
    network_stats = connectivity_network_topology_analyze(...
        pair_network, ...
        'verbose', true, ...
        'calculate_all', true);

    % 保存最终结果
    final_result = struct();
    final_result.pairwise_results = pairwise_results;
    final_result.pair_network = pair_network;
    final_result.network_stats = network_stats;
    final_result.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    fprintf('完整网络分析流程完成！\n');
    fprintf('========================================\n\n');

end

function [is_valid, message] = validate_connectivity_results(pairwise_results)
% 验证连通性分析结果结构
    is_valid = false;
    message = '';
    
    if ~isstruct(pairwise_results)
        message = 'pairwise_results 不是结构体';
        return;
    end
    
    required_fields = {'pair_info', 'connectivity', 'analysis_type', 'parameters'};
    for i = 1:length(required_fields)
        if ~isfield(pairwise_results, required_fields{i})
            message = sprintf('缺少必需字段: %s', required_fields{i});
            return;
        end
    end
    
    % 检查结果一致性
    n_pairs = length(pairwise_results.pair_info);
    if length(pairwise_results.connectivity) ~= n_pairs
        message = sprintf('配对数量不一致: pair_info=%d, connectivity=%d', ...
            n_pairs, length(pairwise_results.connectivity));
        return;
    end
    
    is_valid = true;
    message = '验证通过';
end

function [is_valid, message] = validate_network_structure(pair_network)
% 验证网络结构
    is_valid = false;
    message = '';
    
    if ~isstruct(pair_network)
        message = 'pair_network 不是结构体';
        return;
    end
    
    required_fields = {'adjacency', 'weights', 'node_labels', 'n_nodes'};
    for i = 1:length(required_fields)
        if ~isfield(pair_network, required_fields{i})
            message = sprintf('缺少必需字段: %s', required_fields{i});
            return;
        end
    end
    
    % 检查矩阵尺寸
    n = pair_network.n_nodes;
    if size(pair_network.adjacency, 1) ~= n || size(pair_network.adjacency, 2) ~= n
        message = sprintf('邻接矩阵尺寸不匹配: %dx%d, 期望: %dx%d', ...
            size(pair_network.adjacency,1), size(pair_network.adjacency,2), n, n);
        return;
    end
    
    is_valid = true;
    message = '验证通过';
end

function str = bool2str(bool_val)
% 逻辑值转字符串
    if bool_val
        str = '是';
    else
        str = '否';
    end
end