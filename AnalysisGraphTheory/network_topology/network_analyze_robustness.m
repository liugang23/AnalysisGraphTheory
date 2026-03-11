function result = network_analyze_robustness(net, opts)
% ANALYZE_NETWORK_ROBUSTNESS - 分析网络鲁棒性
    
    result = struct();
    result.module_name = '鲁棒性分析';
    result.module_version = '1.0.0';
    result.start_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    try
        n_nodes = net.n_nodes;
        
        % 检查网络是否适合鲁棒性分析
        if n_nodes < 10
            result.assessment = struct();
            result.assessment.status = '跳过';
            result.assessment.reason = '节点数太少 (<10)，不适合鲁棒性分析';
            result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            result.is_success = true;
            return;
        end
        
        if net.n_edges < 5
            result.assessment = struct();
            result.assessment.status = '跳过';
            result.assessment.reason = '边数太少 (<5)，不适合鲁棒性分析';
            result.end_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            result.is_success = true;
            return;
        end
        
        % 1. 创建图对象
        if strcmp(net.graph_type, 'undirected')
            G = graph(net.adjacency, 'upper');
        else
            G = digraph(net.adjacency);
        end
        
        % 2. 随机攻击模拟
        result.random_attack = struct();
        
        % 模拟参数
        n_simulations = 5;  % 减少模拟次数以提高速度
        attack_steps = 20;  % 攻击步骤数
        step_size = max(1, floor(n_nodes / attack_steps));
        
        % 初始化存储数组
        efficiency_random = zeros(n_simulations, attack_steps);
        lcc_size_random = zeros(n_simulations, attack_steps);  % 最大连通分量大小
        n_components_random = zeros(n_simulations, attack_steps);
        
        fprintf('    进行随机攻击模拟...\n');
        
        for sim = 1:n_simulations
            % 复制原始图
            G_temp = G;
            
            % 随机攻击顺序
            attack_order = randperm(n_nodes);
            
            for step = 1:attack_steps
                % 移除节点
                nodes_to_remove = attack_order(1:min(step*step_size, n_nodes));
                G_temp = rmnode(G_temp, nodes_to_remove);
                
                % 计算当前网络指标
                if numnodes(G_temp) > 0
                    % 网络效率
                    try
                        D = distances(G_temp);
                        D(D == Inf) = NaN;
                        valid_pairs = ~isnan(D) & D > 0;
                        
                        if any(valid_pairs(:))
                            efficiency = 1 ./ D(valid_pairs);
                            efficiency_random(sim, step) = mean(efficiency, 'omitnan');
                        else
                            efficiency_random(sim, step) = 0;
                        end
                    catch
                        efficiency_random(sim, step) = 0;
                    end
                    
                    % 最大连通分量大小
                    if strcmp(net.graph_type, 'undirected')
                        comp_sizes = conncomp(G_temp);
                    else
                        comp_sizes = conncomp(G_temp, 'Type', 'weak');
                    end
                    
                    lcc_size_random(sim, step) = max(histcounts(comp_sizes, 1:max(comp_sizes)+1));
                    n_components_random(sim, step) = max(comp_sizes);
                else
                    efficiency_random(sim, step) = 0;
                    lcc_size_random(sim, step) = 0;
                    n_components_random(sim, step) = 0;
                end
            end
        end
        
        % 计算统计量
        result.random_attack.efficiency_mean = mean(efficiency_random, 1, 'omitnan');
        result.random_attack.efficiency_std = std(efficiency_random, 0, 1, 'omitnan');
        result.random_attack.lcc_size_mean = mean(lcc_size_random, 1, 'omitnan');
        result.random_attack.n_components_mean = mean(n_components_random, 1, 'omitnan');
        
        % 3. 针对性攻击模拟（按度中心性）
        result.targeted_attack = struct();
        
        % 按度中心性排序
        if isfield(net, 'node_degrees')
            degrees = net.node_degrees;
        else
            degrees = sum(net.adjacency, 2);
        end
        
        [~, degree_order] = sort(degrees, 'descend');
        
        fprintf('    进行针对性攻击模拟...\n');
        
        for sim = 1:n_simulations
            % 复制原始图
            G_temp = G;
            
            for step = 1:attack_steps
                % 移除节点
                nodes_to_remove = degree_order(1:min(step*step_size, n_nodes));
                G_temp = rmnode(G_temp, nodes_to_remove);
                
                % 计算当前网络指标
                if numnodes(G_temp) > 0
                    % 网络效率
                    try
                        D = distances(G_temp);
                        D(D == Inf) = NaN;
                        valid_pairs = ~isnan(D) & D > 0;
                        
                        if any(valid_pairs(:))
                            efficiency = 1 ./ D(valid_pairs);
                            result.targeted_attack.efficiency(sim, step) = mean(efficiency, 'omitnan');
                        else
                            result.targeted_attack.efficiency(sim, step) = 0;
                        end
                    catch
                        result.targeted_attack.efficiency(sim, step) = 0;
                    end
                    
                    % 最大连通分量大小
                    if strcmp(net.graph_type, 'undirected')
                        comp_sizes = conncomp(G_temp);
                    else
                        comp_sizes = conncomp(G_temp, 'Type', 'weak');
                    end
                    
                    result.targeted_attack.lcc_size(sim, step) = max(histcounts(comp_sizes, 1:max(comp_sizes)+1));
                    result.targeted_attack.n_components(sim, step) = max(comp_sizes);
                else
                    result.targeted_attack.efficiency(sim, step) = 0;
                    result.targeted_attack.lcc_size(sim, step) = 0;
                    result.targeted_attack.n_components(sim, step) = 0;
                end
            end
        end
        
        % 计算统计量
        result.targeted_attack.efficiency_mean = mean(result.targeted_attack.efficiency, 1, 'omitnan');
        result.targeted_attack.efficiency_std = std(result.targeted_attack.efficiency, 0, 1, 'omitnan');
        result.targeted_attack.lcc_size_mean = mean(result.targeted_attack.lcc_size, 1, 'omitnan');
        result.targeted_attack.n_components_mean = mean(result.targeted_attack.n_components, 1, 'omitnan');
        
        % 4. 鲁棒性指标计算
        result.robustness_metrics = struct();
        
        % 曲线下面积 (AUC)
        attack_proportion = (1:attack_steps) / attack_steps;
        
        if all(~isnan(result.random_attack.efficiency_mean))
            result.robustness_metrics.random_attack_auc = trapz(attack_proportion, ...
                result.random_attack.efficiency_mean);
        else
            result.robustness_metrics.random_attack_auc = NaN;
        end
        
        if all(~isnan(result.targeted_attack.efficiency_mean))
            result.robustness_metrics.targeted_attack_auc = trapz(attack_proportion, ...
                result.targeted_attack.efficiency_mean);
        else
            result.robustness_metrics.targeted_attack_auc = NaN;
        end
        
        % 临界点分析
        result.robustness_metrics.critical_points = struct();
        
        % 随机攻击临界点（效率下降到50%）
        if all(~isnan(result.random_attack.efficiency_mean))
            initial_efficiency = result.random_attack.efficiency_mean(1);
            if initial_efficiency > 0
                threshold = 0.5 * initial_efficiency;
                idx = find(result.random_attack.efficiency_mean < threshold, 1);
                if ~isempty(idx)
                    result.robustness_metrics.critical_points.random_attack = ...
                        attack_proportion(idx);
                end
            end
        end
        
        % 针对性攻击临界点
        if all(~isnan(result.targeted_attack.efficiency_mean))
            initial_efficiency = result.targeted_attack.efficiency_mean(1);
            if initial_efficiency > 0
                threshold = 0.5 * initial_efficiency;
                idx = find(result.targeted_attack.efficiency_mean < threshold, 1);
                if ~isempty(idx)
                    result.robustness_metrics.critical_points.targeted_attack = ...
                        attack_proportion(idx);
                end
            end
        end
        
        % 攻击抵抗差距
        if isfield(result.robustness_metrics.critical_points, 'random_attack') && ...
           isfield(result.robustness_metrics.critical_points, 'targeted_attack')
            result.robustness_metrics.attack_resistance_gap = ...
                result.robustness_metrics.critical_points.targeted_attack - ...
                result.robustness_metrics.critical_points.random_attack;
        end
        
        % 5. 鲁棒性评估
        result.robustness_assessment = struct();
        
        if isfield(result.robustness_metrics, 'random_attack_auc') && ...
           ~isnan(result.robustness_metrics.random_attack_auc)
            
            auc_random = result.robustness_metrics.random_attack_auc;
            
            if auc_random > 0.7
                result.robustness_assessment.random_attack_robustness = '高度鲁棒';
                result.robustness_assessment.random_attack_quality = '优秀';
            elseif auc_random > 0.5
                result.robustness_assessment.random_attack_robustness = '中等鲁棒';
                result.robustness_assessment.random_attack_quality = '良好';
            else
                result.robustness_assessment.random_attack_robustness = '脆弱';
                result.robustness_assessment.random_attack_quality = '较差';
            end
        end
        
        if isfield(result.robustness_metrics, 'targeted_attack_auc') && ...
           ~isnan(result.robustness_metrics.targeted_attack_auc)
            
            auc_targeted = result.robustness_metrics.targeted_attack_auc;
            
            if auc_targeted > 0.5
                result.robustness_assessment.targeted_attack_robustness = '抗针对性攻击';
                result.robustness_assessment.targeted_attack_quality = '良好';
            else
                result.robustness_assessment.targeted_attack_robustness = '对针对性攻击脆弱';
                result.robustness_assessment.targeted_attack_quality = '需改进';
            end
        end
        
        % 综合评估
        if isfield(result.robustness_assessment, 'random_attack_robustness') && ...
           isfield(result.robustness_assessment, 'targeted_attack_robustness')
            
            if strcmp(result.robustness_assessment.random_attack_robustness, '高度鲁棒') && ...
               strcmp(result.robustness_assessment.targeted_attack_robustness, '抗针对性攻击')
                result.robustness_assessment.overall_robustness = '网络鲁棒性优秀';
                result.robustness_assessment.overall_quality = '优秀';
            elseif strcmp(result.robustness_assessment.random_attack_robustness, '中等鲁棒') && ...
                   strcmp(result.robustness_assessment.targeted_attack_robustness, '抗针对性攻击')
                result.robustness_assessment.overall_robustness = '网络鲁棒性良好';
                result.robustness_assessment.overall_quality = '良好';
            else
                result.robustness_assessment.overall_robustness = '网络鲁棒性一般';
                result.robustness_assessment.overall_quality = '需改进';
            end
        end
        
        % 6. 建议
        result.robustness_recommendations = {};
        
        if isfield(result.robustness_metrics, 'critical_points')
            if isfield(result.robustness_metrics.critical_points, 'targeted_attack')
                critical_point = result.robustness_metrics.critical_points.targeted_attack;
                if critical_point < 0.3
                    result.robustness_recommendations{end+1} = ...
                        sprintf('网络对针对性攻击脆弱，移除%.0f%%的重要节点即导致网络崩溃', critical_point*100);
                end
            end
        end
        
        if isfield(result.robustness_assessment, 'targeted_attack_robustness')
            if strcmp(result.robustness_assessment.targeted_attack_robustness, '对针对性攻击脆弱')
                result.robustness_recommendations{end+1} = ...
                    '网络对针对性攻击脆弱，建议增加冗余连接保护关键节点';
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