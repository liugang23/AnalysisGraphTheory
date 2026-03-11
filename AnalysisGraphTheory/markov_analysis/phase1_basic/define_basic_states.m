function [state_sequence, state_info] = define_basic_states(...
    network_features, method, threshold, verbose)
% DEFINE_BASIC_STATES - 定义基础二状态
    
    n_periods = length(network_features.density);
    state_sequence = zeros(n_periods, 1);
    
    switch method
        case 'density'
            % 基于网络密度定义状态
            densities = network_features.density;
            
            % 确定阈值
            if ischar(threshold) && strcmp(threshold, 'median')
                density_threshold = median(densities);
            else
                density_threshold = threshold;
            end
            
            % 定义状态
            state_sequence(densities >= density_threshold) = 1;  % 高密度状态
            state_sequence(densities < density_threshold) = 2;   % 低密度状态
            
            state_info.method = 'density_based';
            state_info.threshold = density_threshold;
            state_info.state_names = {'高密度状态', '低密度状态'};
            state_info.state_descriptions = { ...
                '网络连接紧密，信息传播效率高', ...
                '网络连接稀疏，信息传播效率低'};
            
            if verbose
                fprintf('  状态定义: 基于网络密度 (阈值=%.4f)\n', density_threshold);
                fprintf('  高密度状态: %d 个时期\n', sum(state_sequence == 1));
                fprintf('  低密度状态: %d 个时期\n', sum(state_sequence == 2));
            end
            
        case 'connectivity'
            % 基于连通性定义状态
            connectivity_ratios = network_features.connectivity_ratio;
            
            if ischar(threshold) && strcmp(threshold, 'median')
                conn_threshold = median(connectivity_ratios);
            else
                conn_threshold = threshold;
            end
            
            state_sequence(connectivity_ratios >= conn_threshold) = 1;  % 高连通
            state_sequence(connectivity_ratios < conn_threshold) = 2;   % 低连通
            
            state_info.method = 'connectivity_based';
            state_info.threshold = conn_threshold;
            state_info.state_names = {'高连通状态', '低连通状态'};
            state_info.state_descriptions = { ...
                '网络高度连通，系统集成度高', ...
                '网络连通性低，可能存在孤立部分'};
            
        case 'custom'
            % 自定义状态定义（可由用户扩展）
            error('自定义状态定义需要在第二阶段实现');
            
        otherwise
            error('未知的状态定义方法: %s', method);
    end
    
    % 添加统计信息
    state_info.n_states = 2;
    state_info.state_counts = [sum(state_sequence == 1), sum(state_sequence == 2)];
    state_info.state_proportions = state_info.state_counts / n_periods;
    
    if verbose
        fprintf('  状态比例: 状态1=%.1f%%, 状态2=%.1f%%\n', ...
            state_info.state_proportions(1)*100, state_info.state_proportions(2)*100);
    end
end