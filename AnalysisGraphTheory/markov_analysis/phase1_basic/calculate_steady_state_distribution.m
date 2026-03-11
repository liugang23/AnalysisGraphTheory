function steady_state = calculate_steady_state_distribution(transition_matrix, verbose)
% CALCULATE_STEADY_STATE_DISTRIBUTION - 计算稳态分布
    
    n_states = size(transition_matrix, 1);
    
    % 计算转移矩阵的特征值和特征向量
    [V, D] = eig(transition_matrix');
    
    % 找到特征值为1的特征向量
    idx = find(abs(diag(D) - 1) < 1e-10);
    
    if isempty(idx)
        % 如果没有精确的1，使用幂法
        steady_state = ones(1, n_states) / n_states;
    else
        % 提取对应的特征向量
        steady_vec = V(:, idx(1));
        
        % 归一化
        steady_state = abs(steady_vec)' / sum(abs(steady_vec));
    end
    
    % 确保是行向量
    steady_state = steady_state(:)';
    
    if verbose
        fprintf('  稳态分布:\n');
        for i = 1:n_states
            fprintf('    状态%d: %.3f\n', i, steady_state(i));
        end
    end
end