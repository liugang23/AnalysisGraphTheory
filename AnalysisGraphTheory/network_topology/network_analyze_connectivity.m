function result = network_analyze_connectivity(net, opts)
% ANALYZE_NETWORK_CONNECTIVITY - 增强版网络连通性分析
    
    result = struct();
    result.module_name = '连通性分析';
    result.module_version = '1.1.0';  % 版本升级
    result.start_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    try
        % 创建图对象
        if isfield(net, 'graph_type') && strcmp(net.graph_type, 'undirected')
            G = graph(net.adjacency, 'upper');
            is_directed = false;
        else
            G = digraph(net.adjacency);
            is_directed = true;
        end
        
        n_nodes = net.n_nodes;
        
        % 1. 连通分量分析
        result.components = struct();
        
        if ~is_directed
            % 无向图：计算连通分量
            [bins, binsizes] = conncomp(G);
            n_components = max(bins);
            
            % 无向图字段
            result.components.n_components = n_components;
            result.components.component_sizes = binsizes;
            result.components.is_connected = (n_components == 1);
            result.components.largest_component_size = max(binsizes);
            result.components.largest_component_ratio = max(binsizes) / n_nodes;
            
            % 为保持一致性，添加弱/强分量字段
            result.components.n_weak_components = n_components;
            result.components.weak_component_sizes = binsizes;
            result.components.is_weakly_connected = (n_components == 1);
            result.components.largest_weak_component_size = max(binsizes);
            result.components.largest_weak_component_ratio = max(binsizes) / n_nodes;
            result.components.n_strong_components = n_components;
            result.components.strong_component_sizes = binsizes;
            result.components.largest_strong_component_size = max(binsizes);
            result.components.largest_strong_component_ratio = max(binsizes) / n_nodes;
            
        else
            % 有向图：计算弱连通分量
            [bins_weak, sizes_weak] = conncomp(G, 'Type', 'weak');
            n_weak_components = max(bins_weak);
            
            % 有向图：计算强连通分量
            [bins_strong, sizes_strong] = conncomp(G, 'Type', 'strong');
            n_strong_components = max(bins_strong);
            
            % 有向图字段
            result.components.n_weak_components = n_weak_components;
            result.components.weak_component_sizes = sizes_weak;
            result.components.n_strong_components = n_strong_components;
            result.components.strong_component_sizes = sizes_strong;
            result.components.is_weakly_connected = (n_weak_components == 1);
            result.components.largest_weak_component_size = max(sizes_weak);
            result.components.largest_weak_component_ratio = max(sizes_weak) / n_nodes;
            result.components.largest_strong_component_size = max(sizes_strong);
            result.components.largest_strong_component_ratio = max(sizes_strong) / n_nodes;
            
            % 添加节点分配信息
            result.components.node_weak_components = bins_weak;
            result.components.node_strong_components = bins_strong;
            
            % 为保持向后兼容，添加通用字段
            result.components.n_components = n_weak_components;
            result.components.component_sizes = sizes_weak;
            result.components.is_connected = (n_weak_components == 1);
            result.components.largest_component_size = max(sizes_weak);
            result.components.largest_component_ratio = max(sizes_weak) / n_nodes;
        end
        
        % 2. 连通性统计
        result.components.weak_component_stats = struct(...
            'mean', mean(result.components.weak_component_sizes), ...
            'std', std(result.components.weak_component_sizes), ...
            'min', min(result.components.weak_component_sizes), ...
            'max', max(result.components.weak_component_sizes));
        
        if is_directed && isfield(result.components, 'strong_component_sizes')
            result.components.strong_component_stats = struct(...
                'mean', mean(result.components.strong_component_sizes), ...
                'std', std(result.components.strong_component_sizes), ...
                'min', min(result.components.strong_component_sizes), ...
                'max', max(result.components.strong_component_sizes));
        end
        
        % 3. 连通性评估
        result.assessment = struct();
        
        if ~is_directed
            if result.components.is_connected
                result.assessment.connectivity_status = '全连通网络';
                result.assessment.connectivity_quality = '优秀';
            else
                largest_ratio = result.components.largest_component_ratio;
                if largest_ratio > 0.8
                    result.assessment.connectivity_status = sprintf('基本连通 (最大连通分量占比%.1f%%)', largest_ratio*100);
                    result.assessment.connectivity_quality = '良好';
                elseif largest_ratio > 0.5
                    result.assessment.connectivity_status = sprintf('部分连通 (最大连通分量占比%.1f%%)', largest_ratio*100);
                    result.assessment.connectivity_quality = '中等';
                else
                    result.assessment.connectivity_status = sprintf('高度不连通 (最大连通分量占比%.1f%%)', largest_ratio*100);
                    result.assessment.connectivity_quality = '较差';
                end
            end
        else
            if result.components.is_weakly_connected
                if n_strong_components == 1
                    result.assessment.connectivity_status = '完全连通网络';
                    result.assessment.connectivity_quality = '优秀';
                else
                    result.assessment.connectivity_status = '弱连通网络';
                    result.assessment.connectivity_quality = '良好';
                    
                    % 添加强连通分量信息
                    if n_strong_components <= 3
                        result.assessment.additional_info = sprintf('包含%d个强连通分量', n_strong_components);
                    else
                        result.assessment.additional_info = sprintf('网络包含%d个强连通分量', n_strong_components);
                    end
                end
            else
                largest_ratio = result.components.largest_weak_component_ratio;
                if largest_ratio > 0.8
                    result.assessment.connectivity_status = sprintf('基本弱连通 (最大弱连通分量占比%.1f%%)', largest_ratio*100);
                    result.assessment.connectivity_quality = '良好';
                elseif largest_ratio > 0.5
                    result.assessment.connectivity_status = sprintf('部分弱连通 (最大弱连通分量占比%.1f%%)', largest_ratio*100);
                    result.assessment.connectivity_quality = '中等';
                else
                    result.assessment.connectivity_status = sprintf('高度不连通 (最大弱连通分量占比%.1f%%)', largest_ratio*100);
                    result.assessment.connectivity_quality = '较差';
                end
            end
        end
        
        % 4. 添加对比分析
        result.components.comparison = struct(...
            'weak_vs_strong_equal', result.components.n_weak_components == result.components.n_strong_components, ...
            'is_fully_connected', result.components.is_weakly_connected && (result.components.n_strong_components == 1));
        
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        result.is_success = true;
        
    catch ME
        result.error_message = ME.message;
        result.error_location = sprintf('%s (行: %d)', ME.stack(1).name, ME.stack(1).line);
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        result.is_success = false;
    end
end