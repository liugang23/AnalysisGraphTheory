function network_series = build_network_time_series(time_series_data)
% 从时间序列数据构建网络序列
    n_periods = size(time_series_data, 3);
    network_series = struct();
    
    for t = 1:n_periods
        % 提取当前时期数据
        current_data = time_series_data(:, :, t);
        
        % 构建网络（使用您现有的网络构建函数）
        pair_network = build_pair_network_complete(current_data, ...);
        
        % 存储
        network_series(t).adjacency = pair_network.adjacency;
        network_series(t).node_labels = pair_network.node_labels;
        network_series(t).timestamp = t;
        network_series(t).density = pair_network.density;
    end
end