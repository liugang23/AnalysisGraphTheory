function transition_matrix = estimate_transition_matrix(state_sequence, verbose)
% ESTIMATE_TRANSITION_MATRIX - 估计状态转移概率矩阵
    
    n_states = max(state_sequence);
    transition_counts = zeros(n_states, n_states);
    
    % 计算转移次数
    for t = 1:length(state_sequence)-1
        from_state = state_sequence(t);
        to_state = state_sequence(t+1);
        transition_counts(from_state, to_state) = ...
            transition_counts(from_state, to_state) + 1;
    end
    
    % 计算转移概率
    transition_matrix = zeros(n_states, n_states);
    for i = 1:n_states
        row_total = sum(transition_counts(i, :));
        if row_total > 0
            transition_matrix(i, :) = transition_counts(i, :) / row_total;
        else
            transition_matrix(i, :) = 1 / n_states;  % 均匀分布
        end
    end
    
    if verbose
        fprintf('  转移概率矩阵:\n');
        for i = 1:n_states
            fprintf('    从状态%d: ', i);
            for j = 1:n_states
                fprintf('→状态%d: %.3f  ', j, transition_matrix(i, j));
            end
            fprintf('\n');
        end
    end
end