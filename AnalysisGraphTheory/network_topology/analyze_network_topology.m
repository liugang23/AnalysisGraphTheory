function [analysis_results, integrated_results] = analyze_network_topology(pair_network, varargin)
% ANALYZE_NETWORK_TOPOLOGY - 网络拓扑分析计算函数
% 
% 【功能定位】
% 专注计算网络拓扑特征，不生成任何报告。
% 这是纯粹的"计算模块"，输出原始分析结果。
%
% 【输入参数】
%   pair_network: 网络结构体
%   varargin: 可选参数
%       'TopK': 显示前K个中心节点 (默认: 5)
%       'Verbose': 是否显示进度 (默认: true)
%
% 【输出参数】
%   analysis_results: 结构体，包含9个分析模块的结果
%   integrated_results: 结构体，整合后的分析结果
%
% 【调用示例】
%   % 只进行分析计算
%   [results, integrated] = analyze_network_topology(pair_network);
%   
%   % 带参数的分析计算
%   [results, integrated] = analyze_network_topology(pair_network, ...
%       'TopK', 10, 'Verbose', false);

    fprintf('【网络拓扑分析】开始运行...\n');
    start_time = tic;
    
    %% 1. 参数解析（只保留计算相关参数）
    p = inputParser;
    addRequired(p, 'pair_network', @isstruct);
    addParameter(p, 'TopK', 5, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'Verbose', true, @islogical);
    p.parse(pair_network, varargin{:});
    opts = p.Results;
    
    %% 2. 网络验证
    if opts.Verbose
        fprintf('步骤1: 验证网络...\n');
    end
    [is_valid, error_msg, graph_type] = validate_network(pair_network);

    if ~is_valid
        error('网络验证失败: %s', error_msg);
    end
    
    % 2. 转换网络为MATLAB标准图对象
    G = convert_network_to_matlab_graph(pair_network);
    
    if opts.Verbose
        fprintf('网络转换完成: 节点数=%d, 边数=%d, 类型=%s\n', ...
            numnodes(G), numedges(G), class(G));
    end
    
    %% 3. 执行9个核心分析模块（纯计算）
    if opts.Verbose
        fprintf('步骤2: 执行分析模块\n');
    end
    
    analysis_results = struct();
    
    % 3.1 基本属性分析
    if opts.Verbose, fprintf('  3.1 基本属性分析...\n'); end
    [analysis_results.basic, success_basic] = safe_execution(...
        @network_analyze_basic_properties, G, opts);
    
    % 3.2 连通性分析
    if opts.Verbose, fprintf('  3.2 连通性分析...\n'); end
    [analysis_results.connectivity, success_connectivity] = safe_execution(...
        @network_analyze_connectivity, pair_network, opts);
    
    % 3.3 度分布分析
    if opts.Verbose, fprintf('  3.3 度分布分析...\n'); end
    [analysis_results.degree, success_degree] = safe_execution(...
        @network_analyze_degree_distribution, pair_network, opts);
    
    % 3.4 中心性分析
    if opts.Verbose, fprintf('  3.4 中心性分析...\n'); end
    [analysis_results.centrality, success_centrality] = safe_execution(...
        @network_analyze_centrality, pair_network, opts);
    
    % 3.5 聚类分析
    if opts.Verbose, fprintf('  3.5 聚类分析...\n'); end
    [analysis_results.clustering, success_clustering] = safe_execution(...
        @network_analyze_clustering_properties, pair_network, opts);
    
    % 3.6 社区结构分析
    if opts.Verbose, fprintf('  3.6 社区结构分析...\n'); end
    [analysis_results.community, success_community] = safe_execution(...
        @network_analyze_community_structure, pair_network, opts);
    
    % 3.7 鲁棒性分析
    if opts.Verbose, fprintf('  3.7 鲁棒性分析...\n'); end
    [analysis_results.robustness, success_robustness] = safe_execution(...
        @network_analyze_robustness, pair_network, opts);
    
    % 3.8 路径分析
    if opts.Verbose, fprintf('  3.8 路径分析...\n'); end
    [analysis_results.path, success_path] = safe_execution(...
        @network_analyze_path_properties, pair_network, opts);
    
    % 3.9 关键节点识别
    if opts.Verbose, fprintf('  3.9 关键节点识别...\n'); end
    [analysis_results.keynodes, success_keynodes] = safe_execution(...
        @network_analyze_identify_key_nodes, pair_network, opts);
    
    %% 调试：检查哪些模块失败
    fprintf('\n=== 模块执行状态调试 ===\n');
    module_stats = [
        success_basic, success_connectivity, success_degree, success_centrality, ...
        success_clustering, success_community, success_robustness, success_path, success_keynodes
    ];
    module_names = {'basic', 'connectivity', 'degree', 'centrality', 'clustering', ...
                    'community', 'robustness', 'path', 'keynodes'};

    for i = 1:length(module_stats)
        if module_stats(i)
            fprintf('  ? %s: 成功\n', module_names{i});
        else
            fprintf('  ? %s: 失败\n', module_names{i});

            % 显示错误信息
            if isfield(analysis_results, module_names{i}) && ...
               isfield(analysis_results.(module_names{i}), 'error_message')
                fprintf('     错误: %s\n', analysis_results.(module_names{i}).error_message);
            end
        end
    end
    
    %% 4. 整合分析结果（纯计算，不评估）
    if opts.Verbose
        fprintf('\n步骤3: 整合分析结果\n');
    end
    integrated_results = integrate_results(analysis_results);
    
    %% 5. 计算摘要
    computation_time = toc(start_time);
    if opts.Verbose
        fprintf('\n【网络拓扑分析完成】\n');
        fprintf('计算时间: %.2f 秒\n', computation_time);
        fprintf('成功模块: %d/%d\n', ...
            sum([success_basic, success_connectivity, success_degree, success_centrality, ...
                 success_clustering, success_community, success_robustness, success_path, success_keynodes]), 9);
    end
    
    %% 6. 返回计算结果
    % 注意：不包含任何报告相关字段
    analysis_results.computation_time = computation_time;
    analysis_results.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
end

function [result, success] = safe_execution(func_handle, varargin)
% SAFE_EXECUTION - 安全执行函数
    
    result = struct();
    success = false;
    
    try
        result = func_handle(varargin{:});
        success = true;
        
    catch ME
        % 记录错误信息
        result.error_message = ME.message;
        result.error_location = sprintf('%s (行: %d)', ME.stack(1).name, ME.stack(1).line);
        result.error_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        
        fprintf('    执行失败: %s\n', ME.message);
    end
end

function integrated_results = integrate_results(analysis_results)
% INTEGRATE_RESULTS - 基于实际代码的网络分析结果整合函数
% 从您提供的9个分析模块中提取关键结果，整合为统一格式
    
    integrated_results = struct();
    
    %% 1. 从基本属性分析提取
    if isfield(analysis_results, 'basic') && isfield(analysis_results.basic, 'is_success') && ...
       analysis_results.basic.is_success
        basic = analysis_results.basic;
        
        % 网络规模
        if isfield(basic, 'network_size')
            integrated_results.n_nodes = basic.network_size.n_nodes;
            integrated_results.n_edges = basic.network_size.n_edges;
            integrated_results.max_possible_edges = basic.network_size.max_possible_edges;
        end
        
        % 密度分析
        if isfield(basic, 'density_analysis')
            integrated_results.density = basic.density_analysis.density;
            integrated_results.density_category = basic.density_analysis.density_category;
        end
        
        % 图类型
        if isfield(basic, 'graph_type_analysis')
            integrated_results.graph_type = basic.graph_type_analysis.graph_type;
            integrated_results.is_directed = basic.graph_type_analysis.is_directed;
            integrated_results.is_symmetric = basic.graph_type_analysis.is_symmetric;
        end
        
        % 评估
        if isfield(basic, 'assessment')
            integrated_results.size_assessment = basic.assessment.size_assessment;
            integrated_results.density_assessment = basic.assessment.density_assessment;
        end
    end
    
    %% 2. 从连通性分析提取 - 修复字段名
    if isfield(analysis_results, 'connectivity') && ...
       isfield(analysis_results.connectivity, 'is_success') && ...
       analysis_results.connectivity.is_success
        
        connectivity = analysis_results.connectivity;
        
        if isfield(connectivity, 'components')
            % 获取网络类型
            is_directed = false;
            if isfield(integrated_results, 'is_directed')
                is_directed = integrated_results.is_directed;
            end
            
            if is_directed
                % === 有向图：使用弱/强分量 ===
                if isfield(connectivity.components, 'n_weak_components')
                    % 弱连通分量
                    integrated_results.n_weak_components = connectivity.components.n_weak_components;
                    integrated_results.weak_component_sizes = connectivity.components.weak_component_sizes;
                    integrated_results.is_weakly_connected = connectivity.components.is_weakly_connected;
                    integrated_results.largest_weak_component_size = connectivity.components.largest_weak_component_size;
                    integrated_results.largest_weak_component_ratio = connectivity.components.largest_weak_component_ratio;
                    
                    % 强连通分量
                    if isfield(connectivity.components, 'n_strong_components')
                        integrated_results.n_strong_components = connectivity.components.n_strong_components;
                        integrated_results.strong_component_sizes = connectivity.components.strong_component_sizes;
                        
                        % 计算最大强连通分量
                        if ~isempty(integrated_results.strong_component_sizes)
                            integrated_results.largest_strong_component_size = max(integrated_results.strong_component_sizes);
                            integrated_results.largest_strong_component_ratio = integrated_results.largest_strong_component_size / integrated_results.n_nodes;
                        end
                    end
                    
                    % 保持向后兼容
                    integrated_results.n_components = integrated_results.n_weak_components;
                    integrated_results.component_sizes = integrated_results.weak_component_sizes;
                    integrated_results.is_connected = integrated_results.is_weakly_connected;
                    integrated_results.largest_component_size = integrated_results.largest_weak_component_size;
                    integrated_results.largest_component_ratio = integrated_results.largest_weak_component_ratio;
                end
                
            else
                % === 无向图：使用通用分量 ===
                if isfield(connectivity.components, 'n_components')
                    integrated_results.n_components = connectivity.components.n_components;
                    integrated_results.component_sizes = connectivity.components.component_sizes;
                    integrated_results.is_connected = connectivity.components.is_connected;
                    integrated_results.largest_component_size = connectivity.components.largest_component_size;
                    integrated_results.largest_component_ratio = connectivity.components.largest_component_ratio;
                    
                    % 为无向图设置弱/强分量相同
                    integrated_results.n_weak_components = integrated_results.n_components;
                    integrated_results.weak_component_sizes = integrated_results.component_sizes;
                    integrated_results.is_weakly_connected = integrated_results.is_connected;
                    integrated_results.largest_weak_component_size = integrated_results.largest_component_size;
                    integrated_results.largest_weak_component_ratio = integrated_results.largest_component_ratio;
                    integrated_results.n_strong_components = integrated_results.n_components;
                    integrated_results.strong_component_sizes = integrated_results.component_sizes;
                    integrated_results.largest_strong_component_size = integrated_results.largest_component_size;
                    integrated_results.largest_strong_component_ratio = integrated_results.largest_component_ratio;
                end
            end
        end
        
        % 保留评估字段
        if isfield(connectivity, 'assessment')
            integrated_results.connectivity_status = connectivity.assessment.connectivity_status;
            integrated_results.connectivity_quality = connectivity.assessment.connectivity_quality;
        end
    end
    
    %% 3. 从度分布分析提取
    if isfield(analysis_results, 'degree') && isfield(analysis_results.degree, 'is_success') && ...
       analysis_results.degree.is_success
        degree = analysis_results.degree;
        
        if isfield(degree, 'degree_stats')
            integrated_results.degree_mean = degree.degree_stats.mean;
            integrated_results.degree_median = degree.degree_stats.median;
            integrated_results.degree_std = degree.degree_stats.std;
            integrated_results.degree_min = degree.degree_stats.min;
            integrated_results.degree_max = degree.degree_stats.max;
            integrated_results.degree_total = degree.degree_stats.total;
        end
        
        if isfield(degree, 'degree_heterogeneity')
            integrated_results.degree_heterogeneity = degree.degree_heterogeneity;
        end
        
        if isfield(degree, 'heterogeneity_assessment')
            integrated_results.heterogeneity_assessment = degree.heterogeneity_assessment;
        end
        
        if isfield(degree, 'assessment')
            integrated_results.degree_distribution_type = degree.assessment.degree_distribution_type;
            integrated_results.degree_recommendation = degree.assessment.recommendation;
        end
        
        % 度分布数据
        if isfield(degree, 'degree_distribution')
            integrated_results.degree_distribution = degree.degree_distribution;
        end
    end
    
    %% 4. 从中心性分析提取
    if isfield(analysis_results, 'centrality') && isfield(analysis_results.centrality, 'is_success') && ...
       analysis_results.centrality.is_success
        centrality = analysis_results.centrality;
        
        % 度中心性
        if isfield(centrality, 'degree_centrality')
            integrated_results.degree_centrality = centrality.degree_centrality;
        end
        
        % 介数中心性
        if isfield(centrality, 'betweenness_centrality')
            integrated_results.betweenness_centrality = centrality.betweenness_centrality;
        end
        
        % 接近中心性
        if isfield(centrality, 'closeness_centrality')
            integrated_results.closeness_centrality = centrality.closeness_centrality;
        end
        
        % 特征向量中心性
        if isfield(centrality, 'eigenvector_centrality')
            integrated_results.eigenvector_centrality = centrality.eigenvector_centrality;
        end
        
        % 综合重要性
        if isfield(centrality, 'composite_importance')
            integrated_results.composite_importance = centrality.composite_importance;
        end
        
        % 评估
        if isfield(centrality, 'assessment')
            integrated_results.centrality_analysis_status = centrality.assessment.centrality_analysis_status;
            integrated_results.centrality_recommendation = centrality.assessment.recommendation;
        end
    end
    
    %% 5. 从聚类分析提取
    if isfield(analysis_results, 'clustering') && isfield(analysis_results.clustering, 'is_success') && ...
       analysis_results.clustering.is_success
        clustering = analysis_results.clustering;
        
        % 局部聚类系数
        if isfield(clustering, 'local_clustering')
            integrated_results.local_clustering = clustering.local_clustering;
        end
        
        % 全局聚类系数
        if isfield(clustering, 'global_clustering')
            integrated_results.global_clustering = clustering.global_clustering;
        end
        
        % 传递性
        if isfield(clustering, 'transitivity')
            integrated_results.transitivity = clustering.transitivity;
        end
        
        % 小世界分析
        if isfield(clustering, 'small_world_analysis')
            integrated_results.small_world_analysis = clustering.small_world_analysis;
        end
        
        % 聚类统计
        if isfield(clustering, 'clustering_stats')
            integrated_results.clustering_stats = clustering.clustering_stats;
        end
        
        % 评估
        if isfield(clustering, 'assessment')
            if isfield(clustering.assessment, 'global_clustering_assessment')
                integrated_results.clustering_assessment = clustering.assessment.global_clustering_assessment;
            end
            if isfield(clustering.assessment, 'global_clustering_quality')
                integrated_results.clustering_quality = clustering.assessment.global_clustering_quality;
            end
            if isfield(clustering.assessment, 'small_world_potential')
                integrated_results.small_world_potential = clustering.assessment.small_world_potential;
            end
        end
    end
    
    %% 6. 从社区结构分析提取
    if isfield(analysis_results, 'community') && isfield(analysis_results.community, 'is_success') && ...
       analysis_results.community.is_success
        community = analysis_results.community;
        
        % 社区检测结果
        if isfield(community, 'community_detection')
            integrated_results.community_assignments = community.community_detection.community_assignments;
            integrated_results.modularity = community.community_detection.modularity;
            integrated_results.n_communities = community.community_detection.n_communities;
        end
        
        % 社区统计
        if isfield(community, 'community_stats')
            integrated_results.community_stats = community.community_stats;
        end
        
        % 模块度分析
        if isfield(community, 'modularity_analysis')
            integrated_results.modularity_analysis = community.modularity_analysis;
        end
        
        % 社区质量
        if isfield(community, 'community_quality')
            integrated_results.community_quality = community.community_quality;
        end
        
        % 评估
        if isfield(community, 'assessment')
            integrated_results.community_structure = community.assessment.community_structure;
            integrated_results.community_recommendation = community.assessment.recommendation;
        end
    end
    
    %% 7. 从鲁棒性分析提取
    if isfield(analysis_results, 'robustness') && isfield(analysis_results.robustness, 'is_success') && ...
       analysis_results.robustness.is_success
        robustness = analysis_results.robustness;
        
        % 随机攻击结果
        if isfield(robustness, 'random_attack')
            integrated_results.random_attack = robustness.random_attack;
        end
        
        % 针对性攻击结果
        if isfield(robustness, 'targeted_attack')
            integrated_results.targeted_attack = robustness.targeted_attack;
        end
        
        % 鲁棒性指标
        if isfield(robustness, 'robustness_metrics')
            integrated_results.robustness_metrics = robustness.robustness_metrics;
        end
        
        % 鲁棒性评估
        if isfield(robustness, 'robustness_assessment')
            integrated_results.robustness_assessment = robustness.robustness_assessment;
        end
        
        % 建议
        if isfield(robustness, 'robustness_recommendations')
            integrated_results.robustness_recommendations = robustness.robustness_recommendations;
        end
    end
    
    %% 8. 从路径分析提取
    if isfield(analysis_results, 'path') && isfield(analysis_results.path, 'is_success') && ...
       analysis_results.path.is_success
        path = analysis_results.path;
        
        % 路径统计
        if isfield(path, 'path_statistics')
            integrated_results.path_statistics = path.path_statistics;
        end
        
        % 直径分析
        if isfield(path, 'diameter_analysis')
            integrated_results.diameter_analysis = path.diameter_analysis;
        end
        
        % 效率分析
        if isfield(path, 'efficiency_analysis')
            integrated_results.efficiency_analysis = path.efficiency_analysis;
        end
        
        % 小世界特性
        if isfield(path, 'small_world_analysis')
            integrated_results.path_small_world_analysis = path.small_world_analysis;
        end
        
        % 评估
        if isfield(path, 'path_assessment')
            integrated_results.path_assessment = path.path_assessment;
        end
        
        % 建议
        if isfield(path, 'path_recommendations')
            integrated_results.path_recommendations = path.path_recommendations;
        end
    end
    
    %% 9. 从关键节点识别提取
    if isfield(analysis_results, 'keynodes') && isfield(analysis_results.keynodes, 'is_success') && ...
       analysis_results.keynodes.is_success
        keynodes = analysis_results.keynodes;
        
        % 如果keynodes模块有具体结果，提取它们
        if isfield(keynodes, 'key_nodes')
            integrated_results.key_nodes = keynodes.key_nodes;
        end
        
        if isfield(keynodes, 'node_importance')
            integrated_results.node_importance = keynodes.node_importance;
        end
    end
    
    %% 10. 添加连通性对比分析
    if isfield(integrated_results, 'n_weak_components') && ...
       isfield(integrated_results, 'n_strong_components')
        
        integrated_results.connectivity_comparison = struct();
        integrated_results.connectivity_comparison.weak_vs_strong_equal = ...
            integrated_results.n_weak_components == integrated_results.n_strong_components;
        integrated_results.connectivity_comparison.is_fully_connected = ...
            integrated_results.is_weakly_connected && (integrated_results.n_strong_components == 1);
        
        % 连通性质量评估
        if integrated_results.connectivity_comparison.is_fully_connected
            integrated_results.connectivity_comparison.quality = 'excellent';
            integrated_results.connectivity_comparison.description = '网络完全连通（既是弱连通也是强连通）';
        elseif integrated_results.is_weakly_connected
            if integrated_results.n_strong_components == 1
                integrated_results.connectivity_comparison.quality = 'good';
                integrated_results.connectivity_comparison.description = '网络弱连通且强连通';
            else
                integrated_results.connectivity_comparison.quality = 'moderate';
                integrated_results.connectivity_comparison.description = sprintf('网络弱连通，但有%d个强连通分量', ...
                    integrated_results.n_strong_components);
            end
        else
            integrated_results.connectivity_comparison.quality = 'poor';
            integrated_results.connectivity_comparison.description = sprintf('网络不连通，有%d个弱连通分量', ...
                integrated_results.n_weak_components);
        end
    end
    
    %% 11. 添加元数据
    integrated_results.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    % 如果有计算时间
    if isfield(analysis_results, 'computation_time')
        integrated_results.computation_time = analysis_results.computation_time;
    end
    
    % 添加模块执行状态
    module_names = {'basic', 'connectivity', 'degree', 'centrality', 'clustering', ...
                'community', 'robustness', 'path', 'keynodes'};
    human_names = {'基本属性分析', '连通性分析', '度分布分析', '中心性分析', '聚类分析', ...
                '社区结构分析', '鲁棒性分析', '路径分析', '关键节点识别'};
    success_counts = 0;
    failed_modules = {};
    
    for i = 1:length(module_names)
        module = module_names{i};
        if isfield(analysis_results, module) && isfield(analysis_results.(module), 'is_success')
            integrated_results.([module '_success']) = analysis_results.(module).is_success;

            if analysis_results.(module).is_success
                success_counts = success_counts + 1;
            else
                failed_modules{end+1} = human_names{i};

                % 记录错误信息
                if isfield(analysis_results.(module), 'error_message')
                    integrated_results.failed_modules_info.(module) = struct(...
                        'name', human_names{i}, ...
                        'error_message', analysis_results.(module).error_message, ...
                        'error_location', getfield_safe(analysis_results.(module), 'error_location', 'unknown'), ...
                        'error_time', getfield_safe(analysis_results.(module), 'error_time', 'unknown'));
                end
            end
        end
    end
    
    integrated_results.total_success_modules = success_counts;
    integrated_results.total_modules = length(module_names);
    integrated_results.success_rate = success_counts / length(module_names);
    integrated_results.failed_modules_list = failed_modules;
    integrated_results.failed_modules_count = length(failed_modules);

    % 修改输出信息
    if ~isempty(failed_modules)
        fprintf('\n分析结果整合完成: %d/%d 个模块成功\n', success_counts, length(module_names));
        fprintf('失败模块 (%d个): %s\n', ...
            length(failed_modules), strjoin(failed_modules, ', '));
    else
        fprintf('分析结果整合完成: 所有 %d 个模块均成功\n', success_counts);
    end
end

function value = getfield_safe(structure, fieldname, default_value)
% 安全获取字段值，如果字段不存在返回默认值
    if isfield(structure, fieldname)
        value = structure.(fieldname);
    else
        value = default_value;
    end
end

function [is_valid, error_msg, graph_type] = validate_network(pair_network, varargin)
% VALIDATE_NETWORK 验证网络数据的完整性和合理性
%
% 输入:
%   pair_network - 邻接矩阵 (n x n) 或 包含邻接矩阵的结构体
%   varargin - 可选参数对
%
% 输出:
%   is_valid - 是否有效 (true/false)
%   error_msg - 错误信息字符串

    % 默认参数
    default_params.verbose = false;
    default_params.strict_mode = true;
    
    % 解析可选参数
    params = parse_parameters(default_params, varargin);
    
    % 初始化结果
    is_valid = true;
    error_msg = '';
    
    % === 关键修复：在函数最开始定义 graph_type，确保全局可用 ===
    graph_type = 'directed'; % 默认假设为有向图，防止未定义错误
    original_structure = false;
    A = [];
    
    try
        % 1. 获取输入数据
        input_data = pair_network;
        
        % 2. 如果输入是结构体，尝试提取 graph_type 和 邻接矩阵
        if isstruct(input_data)
            original_structure = true;
            
            % 尝试提取 graph_type
            if isfield(input_data, 'graph_type')
                graph_type = input_data.graph_type; % 覆盖默认值
                
                % === 修正：验证graph_type的有效性 ===
                if ~strcmp(graph_type, 'directed') && ~strcmp(graph_type, 'undirected')
                    is_valid = false;
                    error_msg = sprintf('无效的graph_type: %s (必须为"directed"或"undirected")', graph_type);
                    return;
                end
                
                if params.verbose
                    fprintf('从结构体获取 graph_type: %s\n', graph_type);
                end
            else
                % 如果没有graph_type字段，需要警告或自动检测
                if params.verbose
                    fprintf('警告: 结构体中没有graph_type字段\n');
                end
                % 注意：这里graph_type保持默认值'directed'
            end
            
            % 尝试提取邻接矩阵
            if isfield(input_data, 'adjacency')
                A = input_data.adjacency;
            elseif isfield(input_data, 'adjacency_matrix')
                A = input_data.adjacency_matrix;
            elseif isfield(input_data, 'adj')
                A = input_data.adj;
            elseif isfield(input_data, 'A')
                A = input_data.A;
            else
                is_valid = false;
                error_msg = '输入结构体缺少邻接矩阵字段 (adjacency, adjacency_matrix, adj, A)';
                return;
            end
        else
            % 直接传入矩阵
            A = input_data;
        end
        
        % 3. 基本矩阵检查
        [n_rows, n_cols] = size(A);
        if n_rows ~= n_cols
            is_valid = false;
            error_msg = sprintf('邻接矩阵不是方阵 (%d×%d)', n_rows, n_cols);
            return;
        end
        
        if n_rows < 2
            is_valid = false;
            error_msg = sprintf('节点数太少 (%d)', n_rows);
            return;
        end
        
        % 4. 数据类型检查
        if islogical(A)
            A = double(A);
        elseif ~isnumeric(A)
            is_valid = false;
            error_msg = '邻接矩阵必须为数值型或逻辑型';
            return;
        end
        
        % === 修正：如果没有从结构体获取到graph_type，根据矩阵对称性猜测 ===
        if original_structure && ~isfield(input_data, 'graph_type')
            % 结构体但没有graph_type字段，根据矩阵对称性猜测
            if isequal(A, A')
                graph_type = 'undirected';  % 对称矩阵，可能是无向图
            else
                graph_type = 'directed';    % 非对称矩阵，可能是有向图
            end
            if params.verbose
                fprintf('根据矩阵对称性自动检测graph_type: %s\n', graph_type);
            end
        end
        
        % 5. 验证通过的提示信息
        if is_valid
            error_msg = sprintf('网络验证通过 (类型: %s)', graph_type);
        end
        
    catch ME
        % 如果发生异常，确保 graph_type 仍然存在
        is_valid = false;
        error_msg = sprintf('验证过程中发生异常 (当前graph_type: %s): %s', graph_type, ME.message);
    end
    
    % === 第二阶段验证：基于 graph_type 的具体检查 ===
    try
        % 6. 对称性检查 (仅针对无向图)
        if strcmp(graph_type, 'undirected')
            if ~issymmetric(A)
                is_valid = false;
                error_msg = '无向图但邻接矩阵不对称';
                return;
            end
        end
        
        % 7. 自环检查
        self_loops = diag(A);
        if any(self_loops ~= 0)
            is_valid = false;
            error_msg = sprintf('发现 %d 个自环', sum(self_loops ~= 0));
            return;
        end
        
        % 8. 特殊值检查
        if any(isnan(A(:)))
            is_valid = false;
            error_msg = '发现 NaN 值';
            return;
        end
        
        if any(isinf(A(:)))
            is_valid = false;
            error_msg = '发现 Inf 值';
            return;
        end
        
        % 9. 权重合理性检查
        if any(A(:) < 0)
            is_valid = false;
            error_msg = '发现负权重';
            return;
        end
        
        % 10. 连通性检查
        n_edges = nnz(A);
        if n_edges == 0
            is_valid = false;
            error_msg = '网络没有边';
            return;
        end
        
        % 11. 计算连通分量 (根据 graph_type 选择图类型)
        try
            if strcmp(graph_type, 'undirected')
                G = graph(A > 0, 'upper'); % 无向图
            else
                G = digraph(A > 0);        % 有向图
            end
            
            % 对于有向图，通常检查弱连通性；无向图直接连通性
            if strcmp(graph_type, 'undirected')
                components = conncomp(G);
            else
                components = conncomp(G, 'Type', 'weak');
            end
            
            n_components = max(components);
            
        catch ME2
            is_valid = false;
            error_msg = ['连通性计算异常: ', ME2.message];
            return;
        end
        
        if n_components > 1
            is_valid = false;
            error_msg = sprintf('网络不连通，包含 %d 个连通分量', n_components);
            return;
        end
        
        % 12. 稀疏性检查
        density = n_edges / (n_rows^2);
        if density < 1e-6
            is_valid = false;
            error_msg = sprintf('网络密度过低 (%.2e)', density);
            return;
        end
        
        % 13. 孤立节点检查
        if strcmp(graph_type, 'undirected')
            degrees = sum(A ~= 0, 2); 
        else
            % 有向图检查入度和出度
            out_degrees = sum(A ~= 0, 2);
            in_degrees = sum(A ~= 0, 1)';
            degrees = out_degrees + in_degrees; % 总度数
        end
        
        if any(degrees == 0)
            isolated_nodes = sum(degrees == 0);
            is_valid = false;
            error_msg = sprintf('发现 %d 个孤立节点', isolated_nodes);
            return;
        end
        
    catch ME
        is_valid = false;
        error_msg = ['验证过程中发生异常: ', ME.message];
    end
end

function G = convert_network_to_matlab_graph(pair_network)
    % 1. 检测graph_type
    if isfield(pair_network, 'graph_type')
        graph_type = pair_network.graph_type;
    else
        % 根据矩阵对称性自动检测
        if isequal(pair_network.adjacency, pair_network.adjacency')
            graph_type = 'undirected';
        else
            graph_type = 'directed';
        end
    end
    
    % 2. 提取边的起点和终点
    [start_nodes, end_nodes] = find(pair_network.adjacency);
    
    % 3. 提取权重
    if isfield(pair_network, 'weights')
        % adjacency 为单精度 这里需要通过 logical 转换为逻辑型
        adj_logical = logical(pair_network.adjacency);
        edge_weights = pair_network.weights(adj_logical);
    else
        edge_weights = [];
    end
    
    % 4. 使用检测到的graph_type
    if strcmp(graph_type, 'undirected')
        G = graph(start_nodes, end_nodes, edge_weights, pair_network.n_nodes);
    else
        G = digraph(start_nodes, end_nodes, edge_weights, pair_network.n_nodes);
    end
    
    % 5. 添加节点标签
    if isfield(pair_network, 'node_labels')
        G.Nodes.Name = pair_network.node_labels(:);
    end
end

% 辅助函数：解析参数
function params = parse_parameters(default_params, varargin)
    params = default_params;
    if nargin > 1 && ~isempty(varargin)
        % 简单的参数解析逻辑
        % 假设 varargin 是键值对
        for i = 1:2:numel(varargin)
            if i+1 <= numel(varargin)
                key = varargin{i};
                value = varargin{i+1};
                if isfield(params, key)
                    params.(key) = value;
                end
            end
        end
    end
end
