function result = network_analyze_identify_key_nodes(net, opts)
% IDENTIFY_KEY_NODES - 识别网络关键节点
    
    result = struct();
    result.module_name = '关键节点识别';
    result.module_version = '1.0.0';
    result.start_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    try
        n_nodes = net.n_nodes;
        
        % 检查网络是否适合关键节点识别
        if n_nodes < 3
            result.assessment = struct();
            result.assessment.status = '跳过';
            result.assessment.reason = '节点数太少 (<3)，不适合关键节点识别';
            result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            result.is_success = true;
            return;
        end
        
        if net.n_edges < 2
            result.assessment = struct();
            result.assessment.status = '跳过';
            result.assessment.reason = '边数太少 (<2)，不适合关键节点识别';
            result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            result.is_success = true;
            return;
        end
        
        % 创建图对象
        if strcmp(net.graph_type, 'undirected')
            G = graph(net.adjacency, 'upper');
        else
            G = digraph(net.adjacency);
        end
        
        % 1. 收集多种中心性指标
        result.centrality_measures = struct();
        n_measures = 0;
        
        % 度中心性
        try
            deg_cent = centrality(G, 'degree');
            result.centrality_measures.degree_centrality = struct();
            result.centrality_measures.degree_centrality.values = deg_cent;
            result.centrality_measures.degree_centrality.is_success = true;
            n_measures = n_measures + 1;
        catch
            result.centrality_measures.degree_centrality.is_success = false;
        end
        
        % 介数中心性
        try
            bet_cent = centrality(G, 'betweenness');
            result.centrality_measures.betweenness_centrality = struct();
            result.centrality_measures.betweenness_centrality.values = bet_cent;
            result.centrality_measures.betweenness_centrality.is_success = true;
            n_measures = n_measures + 1;
        catch
            result.centrality_measures.betweenness_centrality.is_success = false;
        end
        
        % 接近中心性
        try
            close_cent = centrality(G, 'closeness');
            result.centrality_measures.closeness_centrality = struct();
            result.centrality_measures.closeness_centrality.values = close_cent;
            result.centrality_measures.closeness_centrality.is_success = true;
            n_measures = n_measures + 1;
        catch
            result.centrality_measures.closeness_centrality.is_success = false;
        end
        
        % 特征向量中心性
        try
            eig_cent = centrality(G, 'eigenvector');
            result.centrality_measures.eigenvector_centrality = struct();
            result.centrality_measures.eigenvector_centrality.values = eig_cent;
            result.centrality_measures.eigenvector_centrality.is_success = true;
            n_measures = n_measures + 1;
        catch
            result.centrality_measures.eigenvector_centrality.is_success = false;
        end
        
        % 2. 计算综合重要性得分
        result.composite_importance = struct();
        
        if n_measures >= 2
            % 初始化综合得分数组
            composite_scores = zeros(n_nodes, 1);
            measure_weights = zeros(n_measures, 1);
            measure_names = {};
            
            idx = 1;
            
            % 处理度中心性
            if result.centrality_measures.degree_centrality.is_success
                values = result.centrality_measures.degree_centrality.values;
                if max(values) > min(values)
                    normalized = (values - min(values)) / (max(values) - min(values));
                else
                    normalized = zeros(size(values));
                end
                composite_scores = composite_scores + normalized;
                measure_weights(idx) = 1.0;
                measure_names{idx} = 'degree_centrality';
                idx = idx + 1;
            end
            
            % 处理介数中心性
            if result.centrality_measures.betweenness_centrality.is_success
                values = result.centrality_measures.betweenness_centrality.values;
                if max(values) > min(values)
                    normalized = (values - min(values)) / (max(values) - min(values));
                else
                    normalized = zeros(size(values));
                end
                composite_scores = composite_scores + normalized;
                measure_weights(idx) = 1.2;  % 介数中心性权重稍高
                measure_names{idx} = 'betweenness_centrality';
                idx = idx + 1;
            end
            
            % 处理接近中心性
            if result.centrality_measures.closeness_centrality.is_success
                values = result.centrality_measures.closeness_centrality.values;
                if max(values) > min(values)
                    normalized = (values - min(values)) / (max(values) - min(values));
                else
                    normalized = zeros(size(values));
                end
                composite_scores = composite_scores + normalized;
                measure_weights(idx) = 1.0;
                measure_names{idx} = 'closeness_centrality';
                idx = idx + 1;
            end
            
            % 处理特征向量中心性
            if result.centrality_measures.eigenvector_centrality.is_success
                values = result.centrality_measures.eigenvector_centrality.values;
                if max(values) > min(values)
                    normalized = (values - min(values)) / (max(values) - min(values));
                else
                    normalized = zeros(size(values));
                end
                composite_scores = composite_scores + normalized;
                measure_weights(idx) = 1.1;  % 特征向量中心性权重稍高
                measure_names{idx} = 'eigenvector_centrality';
                idx = idx + 1;
            end
            
            % 计算加权综合得分
            total_weight = sum(measure_weights(1:idx-1));
            if total_weight > 0
                composite_scores = composite_scores / total_weight;
            end
            
            result.composite_importance.scores = composite_scores;
            result.composite_importance.measure_weights = measure_weights(1:idx-1);
            result.composite_importance.measure_names = measure_names;
            result.composite_importance.n_measures_used = idx - 1;
            result.composite_importance.is_success = true;
            
        else
            result.composite_importance.is_success = false;
            result.composite_importance.error = sprintf('可用中心性指标不足: %d (需要至少2个)', n_measures);
        end
        
        % 3. 识别Top-K关键节点
        result.key_nodes_identification = struct();
        
        if result.composite_importance.is_success
            top_k = min(opts.TopK, n_nodes);
            composite_scores = result.composite_importance.scores;
            
            % 排序获取Top-K节点
            [sorted_scores, sorted_indices] = sort(composite_scores, 'descend');
            
            result.key_nodes_identification.top_k_indices = sorted_indices(1:top_k);
            result.key_nodes_identification.top_k_labels = net.node_labels(result.key_nodes_identification.top_k_indices);
            result.key_nodes_identification.top_k_scores = sorted_scores(1:top_k);
            result.key_nodes_identification.top_k = top_k;
            result.key_nodes_identification.is_success = true;
            
            % 提取详细的关键节点信息
            result.key_nodes_identification.detailed_info = cell(top_k, 1);
            
            for i = 1:top_k
                node_idx = sorted_indices(i);
                node_info = struct();
                node_info.rank = i;
                node_info.index = node_idx;
                node_info.label = net.node_labels{node_idx};
                node_info.composite_score = sorted_scores(i);
                
                % 收集各中心性指标得分
                if result.centrality_measures.degree_centrality.is_success
                    node_info.degree_centrality = result.centrality_measures.degree_centrality.values(node_idx);
                end
                if result.centrality_measures.betweenness_centrality.is_success
                    node_info.betweenness_centrality = result.centrality_measures.betweenness_centrality.values(node_idx);
                end
                if result.centrality_measures.closeness_centrality.is_success
                    node_info.closeness_centrality = result.centrality_measures.closeness_centrality.values(node_idx);
                end
                if result.centrality_measures.eigenvector_centrality.is_success
                    node_info.eigenvector_centrality = result.centrality_measures.eigenvector_centrality.values(node_idx);
                end
                
                result.key_nodes_identification.detailed_info{i} = node_info;
            end
            
        else
            result.key_nodes_identification.is_success = false;
        end
        
        % 4. 节点重要性分类
        result.node_classification = struct();
        
        if result.composite_importance.is_success
            composite_scores = result.composite_importance.scores;
            
            % 定义分类阈值
            hub_threshold = 0.7;     % 枢纽节点阈值
            important_threshold = 0.4; % 重要节点阈值
            peripheral_threshold = 0.2; % 边缘节点阈值
            
            % 统计各类节点数量
            hub_nodes = composite_scores >= hub_threshold;
            important_nodes = (composite_scores >= important_threshold) & (composite_scores < hub_threshold);
            moderate_nodes = (composite_scores >= peripheral_threshold) & (composite_scores < important_threshold);
            peripheral_nodes = composite_scores < peripheral_threshold;
            
            result.node_classification.hub_nodes = find(hub_nodes);
            result.node_classification.important_nodes = find(important_nodes);
            result.node_classification.moderate_nodes = find(moderate_nodes);
            result.node_classification.peripheral_nodes = find(peripheral_nodes);
            
            result.node_classification.hub_count = sum(hub_nodes);
            result.node_classification.important_count = sum(important_nodes);
            result.node_classification.moderate_count = sum(moderate_nodes);
            result.node_classification.peripheral_count = sum(peripheral_nodes);
            
            result.node_classification.hub_proportion = result.node_classification.hub_count / n_nodes;
            result.node_classification.important_proportion = result.node_classification.important_count / n_nodes;
            result.node_classification.moderate_proportion = result.node_classification.moderate_count / n_nodes;
            result.node_classification.peripheral_proportion = result.node_classification.peripheral_count / n_nodes;
            
            result.node_classification.is_success = true;
        end
        
        % 5. 网络结构类型判断
        result.network_structure = struct();
        
        if isfield(result.node_classification, 'hub_proportion')
            hub_prop = result.node_classification.hub_proportion;
            
            if hub_prop > 0.2
                result.network_structure.type = '集中式网络';
                result.network_structure.description = '存在明显的枢纽节点，网络结构集中';
                result.network_structure.characteristic = '对枢纽节点的依赖性高，对针对性攻击脆弱';
            elseif hub_prop > 0.05
                result.network_structure.type = '混合式网络';
                result.network_structure.description = '存在少量枢纽节点，结构较为平衡';
                result.network_structure.characteristic = '兼具集中和分布式特性，鲁棒性较好';
            else
                result.network_structure.type = '分布式网络';
                result.network_structure.description = '节点重要性分布均匀，无明显枢纽';
                result.network_structure.characteristic = '鲁棒性较好，但对随机故障可能更敏感';
            end
            
            result.network_structure.is_success = true;
        end
        
        % 6. 关键节点评估
        result.key_nodes_assessment = struct();
        
        if result.key_nodes_identification.is_success
            top_scores = result.key_nodes_identification.top_k_scores;
            
            if length(top_scores) >= 3
                % 评估关键节点的区分度
                score_diff = diff(top_scores);
                avg_diff = mean(score_diff);
                
                if avg_diff > 0.1
                    result.key_nodes_assessment.distinctness = '关键节点区分度明显';
                    result.key_nodes_assessment.distinctness_quality = '优秀';
                elseif avg_diff > 0.05
                    result.key_nodes_assessment.distinctness = '关键节点有一定区分度';
                    result.key_nodes_assessment.distinctness_quality = '良好';
                else
                    result.key_nodes_assessment.distinctness = '关键节点区分度不明显';
                    result.key_nodes_assessment.distinctness_quality = '一般';
                end
                
                % 评估顶级节点的重要性
                top_score = top_scores(1);
                if top_score > 0.8
                    result.key_nodes_assessment.top_node_importance = '存在非常核心的枢纽节点';
                elseif top_score > 0.6
                    result.key_nodes_assessment.top_node_importance = '存在重要的枢纽节点';
                else
                    result.key_nodes_assessment.top_node_importance = '枢纽节点重要性一般';
                end
            end
        end
        
        % 7. 建议
        result.key_nodes_recommendations = {};
        
        if isfield(result.node_classification, 'hub_proportion')
            hub_prop = result.node_classification.hub_proportion;
            
            if hub_prop > 0.3
                result.key_nodes_recommendations{end+1} = ...
                    sprintf('枢纽节点比例较高(%.1f%%)，网络对针对性攻击脆弱，建议增加冗余保护', hub_prop*100);
            elseif hub_prop < 0.05
                result.key_nodes_recommendations{end+1} = ...
                    '网络无明显枢纽节点，结构较为分布式，鲁棒性较好';
            end
        end
        
        if result.key_nodes_identification.is_success && length(result.key_nodes_identification.top_k_labels) >= 3
            result.key_nodes_recommendations{end+1} = ...
                '建议重点关注以下关键节点，它们对网络结构有重要影响:';
            
            for i = 1:min(3, length(result.key_nodes_identification.top_k_labels))
                result.key_nodes_recommendations{end+1} = ...
                    sprintf('  %d. %s (综合得分: %.3f)', ...
                    i, result.key_nodes_identification.top_k_labels{i}, ...
                    result.key_nodes_identification.top_k_scores(i));
            end
        end
        
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        result.is_success = true;
        
    catch ME
        result.error_message = ME.message;
        result.error_location = sprintf('%s (行: %d)', ME.stack(1).name, ME.stack(1).line);
        result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        result.is_success = false;
    end
end