function result = network_analyze_basic_properties(net, varargin)
% NETWORK_ANALYZE_BASIC_PROPERTIES - 分析网络基本属性
    
    result = struct();
    result.module_name = '基本属性分析';
    result.module_version = '2.0.0';
    result.start_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    try
        % 1. 确定网络类型
        if isa(net, 'digraph') || isa(net, 'graph')
            % 情况1：输入是MATLAB图对象
            is_directed = isa(net, 'digraph');
            n_nodes = numnodes(net);  % 使用 numnodes 获取节点数
            
            % 从图对象获取边数
            n_edges = numedges(net);
            
            % 计算最大可能边数
            if is_directed
                max_possible_edges = n_nodes * (n_nodes - 1);
            else
                max_possible_edges = n_nodes * (n_nodes - 1) / 2;
            end
            
        else
            % 情况2：输入是结构体
            % 确定网络类型
            is_directed = true;  % 默认有向图
            if isfield(net, 'graph_type')
                if strcmp(net.graph_type, 'undirected')
                    is_directed = false;
                end
            elseif isfield(net, 'analysis_type')
                if strcmp(net.analysis_type, 'correlation')
                    is_directed = false;
                end
            end
            
            % 获取节点数
            if isfield(net, 'n_nodes')
                n_nodes = net.n_nodes;
            else
                error('结构体中缺少 n_nodes 字段');
            end
            
            % 从邻接矩阵计算边数
            if isfield(net, 'adjacency')
                adjacency_sum = sum(net.adjacency(:));
                
                if is_directed
                    n_edges = adjacency_sum;
                    max_possible_edges = n_nodes * (n_nodes - 1);
                else
                    n_edges = adjacency_sum / 2;
                    max_possible_edges = n_nodes * (n_nodes - 1) / 2;
                end
            elseif isfield(net, 'n_edges')
                n_edges = net.n_edges;
                if is_directed
                    max_possible_edges = n_nodes * (n_nodes - 1);
                else
                    max_possible_edges = n_nodes * (n_nodes - 1) / 2;
                end
            else
                error('无法确定边数：缺少 adjacency 或 n_edges 字段');
            end
        end
        
        % 网络规模统计
        result.network_size = struct();
        result.network_size.n_nodes = n_nodes;
        result.network_size.n_edges = n_edges;
        result.network_size.max_possible_edges = max_possible_edges;
        
        % 计算有向边数
        if is_directed
            result.network_size.n_edges_directed = n_edges;
        else
            result.network_size.n_edges_directed = n_edges * 2;
        end
        
        % 计算网络密度
        if max_possible_edges > 0
            network_density = n_edges / max_possible_edges;
        else
            network_density = 0;
        end
        result.network_size.network_density = network_density;
    catch ME    
        fprintf('  - network_analyze_basic_properties 网络规模统计 失败: %s\n', ME.message);
        result.error_message = ME.message;
        result.error_location = sprintf('%s (行: %d)', ME.stack(1).name, ME.stack(1).line);
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        result.is_success = false;
        return;  % 出错后直接返回
    end 
    
    try
        %% 3. 密度分析
        result.density_analysis = struct();
        result.density_analysis.density = network_density;
        result.density_analysis.density_category = get_density_category(network_density);
        result.density_analysis.sparsity = 1 - network_density;
        result.density_analysis.is_dense = network_density > 0.5;
        result.density_analysis.is_sparse = network_density < 0.3;
        result.density_analysis.actual_edges = n_edges;
        result.density_analysis.max_possible_edges = max_possible_edges;
        
        %% 4. 图类型分析
        result.graph_type_analysis = struct();
        if is_directed
            result.graph_type_analysis.graph_type = 'directed';
        else
            result.graph_type_analysis.graph_type = 'undirected';
        end
        result.graph_type_analysis.is_directed = is_directed;
        
        % 1. 获取邻接矩阵
        if isa(net, 'digraph') || isa(net, 'graph')
            % 如果是图对象，使用 adjacency 函数获取矩阵
            adj = adjacency(net);
        elseif isfield(net, 'adjacency')
            % 如果是结构体，直接使用字段
            adj = net.adjacency;
        else
            % 如果都没有，设为 false 并跳过
            result.graph_type_analysis.is_symmetric = false;
            return; % 或者 continue，取决于你的函数结构
        end
        
        % 2. 进行对称性检查
        if isequal(adj, adj')
            result.graph_type_analysis.is_symmetric = true;
        else
            result.graph_type_analysis.is_symmetric = false;
        end
        
        % 权重信息（仅对结构体）
        if ~isa(net, 'digraph') && ~isa(net, 'graph') && isfield(net, 'weights')
            weights = net.weights;
            result.graph_type_analysis.has_weights = true;
            result.graph_type_analysis.weight_stats = struct(...
                'mean', mean(weights(:), 'omitnan'), ...
                'std', std(weights(:), 'omitnan'), ...
                'min', min(weights(:), [], 'omitnan'), ...
                'max', max(weights(:), [], 'omitnan'));
        else
            result.graph_type_analysis.has_weights = false;
        end
    catch ME    
        fprintf('  - network_analyze_basic_properties 密度分析 失败: %s\n', ME.message);
    end  
    
	try
        %% 5. 评估
        result.assessment = struct();
        
        % 5.1 规模评估
        if n_nodes < 10
            result.assessment.size_assessment = '小型网络';
        elseif n_nodes < 50
            result.assessment.size_assessment = '中型网络';
        elseif n_nodes < 200
            result.assessment.size_assessment = '大型网络';
        else
            result.assessment.size_assessment = '超大型网络';
        end
        
        % 5.2 密度评估
        density_cat = get_density_category(network_density);
        switch density_cat
            case 'extremely_sparse'
                result.assessment.density_assessment = '极度稀疏';
            case 'very_sparse'
                result.assessment.density_assessment = '非常稀疏';
            case 'sparse'
                result.assessment.density_assessment = '稀疏';
            case 'moderate'
                result.assessment.density_assessment = '中等密度';
            case 'dense'
                result.assessment.density_assessment = '稠密';
            case 'very_dense'
                result.assessment.density_assessment = '非常稠密';
            case 'almost_complete'
                result.assessment.density_assessment = '接近完全连接';
        end
        
        % 5.3 连通性评估
        if n_edges < n_nodes
            result.assessment.connectivity_potential = '可能不连通';
        elseif n_edges < 2*n_nodes
            result.assessment.connectivity_potential = '可能连通';
        else
            result.assessment.connectivity_potential = '很可能连通';
        end
        
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        result.is_success = true;
	catch ME
        result.error_message = ME.message;
        fprintf('  - network_analyze_basic_properties 评估失败: %s\n', ME.message);
        result.error_location = sprintf('%s (行: %d)', ME.stack(1).name, ME.stack(1).line);
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        result.is_success = false;
	end
end

function category = get_density_category(density)
% GET_DENSITY_CATEGORY - 根据密度值分类
    
    if density < 0.01
        category = 'extremely_sparse';
    elseif density < 0.05
        category = 'very_sparse';
    elseif density < 0.1
        category = 'sparse';
    elseif density < 0.3
        category = 'moderate';
    elseif density < 0.5
        category = 'dense';
    elseif density < 0.8
        category = 'very_dense';
    else
        category = 'almost_complete';
    end
end
