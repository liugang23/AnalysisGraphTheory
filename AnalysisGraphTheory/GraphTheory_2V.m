function GraphTheory_2V(normalized_data, feature_names, dates_display, stockCode)
% 网络分析主管道
% 工作流程：
%   1、生成完全交叉配对 → 2、 连通性分析 → 3、 网络构建 → 4、 网络拓扑分析 → 5、 可视化
    
    timestamp = cell2mat(dates_display(end));
    %% 0. 初始化日志系统
    init_logging_system_enhanced(...
        'log_dir', 'analysis_logs', ...   % 日志目录
        'log_level', 'INFO', ...          % 日志级别
        'clean_old_logs', false);         % 是否清理旧日志
    
    % 记录分析开始
    log_message_enhanced('PIPELINE', stockCode, 'GraphTheory_2V', 'pipeline_start', '开始处理股票', 'INFO');
        
    %% 1. 生成完全交叉配对
   log_message_enhanced('PIPELINE', stockCode, 'create_price_volume_pairs', 'stage_1_start', '生成完全交叉配对', 'INFO');
    
    [paired_data, pair_info] = create_price_volume_pairs(...
            normalized_data, feature_names, ...
            'verbose', true, ...      % 显示详细信息
            'min_period_gap', 5, ...  % 最小间隔
            'analysis_type', 'all');  % 全配对  
        
    %% 2. 单独执行配对连通性分析
    log_message_enhanced('PIPELINE', stockCode, 'connectivity_pairwise_analyze_modular', 'stage_2_start', '开始连通性分析', 'INFO');
    
    analysis_type = 'granger';         % cross_correlation 互相关系数    % granger 因果关系
    pairwise_results = connectivity_pairwise_analyze_modular(...
        paired_data, pair_info, analysis_type, ...
        'max_lag', 5, ...                  % 最大滞后阶数
        'significance_level', 0.05, ...    % 显著性水平
        'bootstrap_reps', 1000, ...        % 自助法重复次数
        'enable_robustness', true, ...     % 启用鲁棒性检查  根据自己的计算资源和精度要求来决定是否开启。开启鲁棒性检查会增加200-1000次的额外计算（取决于 robustness_n_bootstrap的设置），计算时间会显著增加。
        'robustness_n_bootstrap', 200, ... % 鲁棒性自助法次数
        'robustness_noise_level', 0.01, ...% 噪声水平
        'robustness_threshold', 0.7, ...   % 鲁棒性评分阈值
        'enable_nonlinear_test', true, ... % 启用非线性检测
        'bds_m', 2:5, ...                  % BDS? 代表 Brock-Dechert-Scheinkman 检验，是一种用于检测时间序列非线性相关性和随机性的统计检验方法；2:5? 表示使用嵌入维度 2、3、4、5 进行多维度检验
        'bds_epsilon', 0.5:0.5:1.5, ...    % bds_epsilon? 是 BDS 检验的距离阈值参数; 0.5:0.5:1.5? 表示使用 0.5、1.0、1.5 三个不同的阈值进行检验
        'verbose', true);                  % 详细输出控制参数  true表示开启详细输出，false表示静默模式

    % 2.1： 验证连通性分析结果
%    connectivity_report = evaluate_pairwise_connectivity(pairwise_results, ...
%        'ReportLevel', 'detailed', ...  % 详情模式
%        'SaveReport', true, ...         % 保存报告
%        'OutputFigures', true);         % 生成图表

    % 查看报告
%    disp(connectivity_report.formatted_text);
    
    %% 3. 网络构建
    pair_network = build_pair_network_complete(...
        pairwise_results, ...
        paired_data, ...
        analysis_type, pairwise_results.parameters.significance_level);
    
    % 步骤 3.1: 自动提取源数据信息
    source_info = extract_source_data_info(pairwise_results);
    
    % 验证提取的信息
    fprintf('\n源数据信息摘要:\n');
    fprintf('  期望节点数: %d (实际构建: %d)\n', ...
        source_info.n_nodes_expected, pair_network.n_nodes);
    fprintf('  唯一变量数: %d\n', length(source_info.var_names));

    % 步骤 3.2: 使用源数据信息进行严格验证
    [is_valid, report] = validate_network_structure(pair_network, ...
        'validation_level', 'strict', ...
        'source_data_info', source_info, ...
        'verbose', true);
    
    % 步骤3.3: 验证结果处理
    if is_valid
        fprintf('? 网络构建验证通过 (严格级别)\n');

        % 检查节点标签匹配
        if isfield(report, 'basic_stats')
            fprintf('   节点数: %d, 边数: %d\n', ...
                report.basic_stats.n_nodes, report.basic_stats.n_edges);
        end
    else
        fprintf('? 网络构建验证失败\n');

        % 显示详细错误
        if isfield(report, 'failed_checks')
            for i = 1:length(report.failed_checks)
                fprintf('  错误 %d: %s\n', i, report.failed_checks{i});
            end
        end

        if isfield(report, 'warnings')
            for i = 1:length(report.warnings)
                fprintf('  警告 %d: %s\n', i, report.warnings{i});
            end
        end
    end
    
    % 步骤3.4: 网络构建图形展示
    [figure2, stats] = plot_network_structure(pair_network, ...
    'FigureTitle', '价量网络结构验证 (Granger因果)', ...    % 图形标题
    'Layout', 'subspace', ...           % 按ret/obv分组布局
    'NodeColor', 'type', ...            % 按类型着色
    'ShowNodeLabels', true, ...         % 显示标签，检查节点名称
    'HighlightIsolatedNodes', true, ...             % 高亮孤立节点，发现数据问题
    'FigurePosition', [100, 100, 1400, 900], ...    % 稍大窗口
    'SaveFigure', true, ...
    'SavePath', sprintf('network_validation_%s.png', datestr(now, 'yyyymmdd')), ...
    'Verbose', true);
    
    % 查看统计摘要
    disp(stats);
    
    %% 4. 网络拓扑分析
    % 只分析，不报告
%    [analysis_results, ~] = evaluate_constructed_network_main(pair_network, ...
%        'AnalysisOnly', true);         % AnalysisOnly   true 代表只做分析

    % 4.1 分析和报告都做
    [analysis_results, network_report] = evaluate_constructed_network_main(pair_network, ...
        'AnalysisOnly', false, ...     % false 不只是做分析 
        'ReportLevel', 'standard', ... % ReportLevel  报告等级  standard 标准
        'SaveReport', true);           % SaveReport   保存报告
    
    % 4.2 网络拓扑分析可视化
    [figs, stats] = plot_network_topology_analysis_main(analysis_results, pair_network);
    
    %% 5.环结构分析
    log_message_enhanced('PIPELINE', 'SYSTEM', ...
        'GraphTheory_2V', 'stage_5_start', ...
        '开始环结构分析', 'INFO');

    cycle_results = analyze_network_cycles(pair_network, ...
        'MaxCycleLength', 8, ...                % 检测长环
        'CycleDetectionMethod', 'tarjan', ...   % 对价量网络通用
        'EnableFeedbackLoops', true, ...        % 金融网络需要关注反馈
        'Verbose', true);                       % 显示详细过程
    
    % 5.1 生成评估报告
    [report_text, report_data] = generate_cycle_analysis_report(cycle_results, ...
        'ReportLevel', 'standard', ...
        'NetworkContext', struct('name', '价量指标网络', 'period', '2024-01'), ...
        'IncludeRecommendations', true);

    % 5.2 查看报告
    disp(report_text);

    % 5.3 保存报告到文件
    fid = fopen('cycle_analysis_report.txt', 'w');
    fprintf(fid, '%s', report_text);
    fclose(fid);
    
    % 5.4. 生成完整的环结构可视化
    [figs, stats] = visualize_cycle_structures(cycle_results, pair_network, ...
        'VisualizationMode', 'complete', ...
        'Layout', 'subspace', ...
        'MaxCyclesToShow', 8, ...
        'FigureQuality', 'high', ...
        'SaveFigures', true, ...
        'OutputDir', 'cycle_analysis_plots/', ...
        'FigureFormat', 'pdf', ...
        'Verbose', true);
    
    %% 新增：马尔科夫分析（第一阶段）
    % 如果有时间序列数据
%    if isfield(data, 'time_series') && length(data.time_series) > 10
%        fprintf('\n【开始马尔科夫分析 - 第一阶段】\n');
        
        % 构建网络时间序列
%        network_series = build_network_time_series(data.time_series);
        
        % 执行基础马尔科夫分析
%        [markov_results, validation] = analyze_network_markov_basic(...
%            network_series, ...
%            'StateDefinition', 'density', ...
%            'ValidationMethod', 'chi2', ...
%            'Verbose', true);
        
        % 生成马尔科夫分析报告
%        markov_report = generate_markov_analysis_report(markov_results, validation);
        
        % 集成到总体结果
%        integrated_results.markov_analysis = markov_results;
%        integrated_results.markov_validation = validation;
%        integrated_results.markov_report = markov_report;
        
        % 基于马尔科夫结果给出建议
%        if markov_results.markov_property_passed
%            fprintf('? 马尔科夫模型适用，可进行状态预测\n');
            
            % 预测下一状态
%            current_state = identify_current_state(pair_network, markov_results);
%            next_state_prob = markov_results.transition_matrix(current_state, :);
            
%            fprintf('  当前状态: %s\n', ...
%                markov_results.state_info.state_names{current_state});
%            fprintf('  下一状态预测:\n');
%            for i = 1:length(next_state_prob)
%                fprintf('    → %s: %.1f%%\n', ...
%                    markov_results.state_info.state_names{i}, next_state_prob(i)*100);
%            end
%        end
%    end
    
    %% 返回集成结果
%    integrated_results.topology = topology_results;
%    integrated_results.cycles = cycle_results;
%    integrated_results.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    log_message_enhanced('PIPELINE', 'SYSTEM', ...
        'GraphTheory_2V', 'pipeline_complete', ...
        '分析完成', 'INFO', 'struct_details', struct(...
            'total_time_seconds', toc(start_time), ...
            'n_networks_built', 1, ...
            'success', true));
    
end