function robust_result = check_granger_robustness(X, Y, original_granger_result, params)
% 功能: 对Granger因果检验结果进行自助法鲁棒性验证
% 输入:
%   X, Y: 原始时间序列 (列向量)
%   original_granger_result: 您现有的 granger_causality_test 函数返回的结构体
%   params: 控制参数的结构体，可包含:
%        - n_bootstrap: 自助法重复次数 (默认 200)
%        - noise_level: 添加噪声的幅度 (默认 0.01，即1%的标准差)
%        - significance_level: 显著性水平 (默认 0.05)
% 输出:
%   robust_result: 包含原始结果和鲁棒性评估的结构体
%
% 实现逻辑: 通过相位随机化生成替代数据，重新计算Granger，比较结论一致性。

    % 1. 参数设置与验证
    if nargin < 4
        params = struct();
    end
    if ~isfield(params, 'n_bootstrap')
        params.n_bootstrap = 200; % 默认200次
    end
    if ~isfield(params, 'noise_level')
        params.noise_level = 0.01; % 1% 的噪声
    end
    if ~isfield(params, 'significance_level')
        params.significance_level = 0.05;
    end

    % 2. 提取原始结果关键信息
    original_F = original_granger_result.F_statistic;
    original_p = original_granger_result.p_value;
    original_significant = original_granger_result.significant; % 是否显著
    optimal_lag = original_granger_result.optimal_lag; % 使用原始检验确定的最优滞后
    
    n_obs = length(X);
    
    % 3. 自助法循环
    bootstrap_F_stats = zeros(params.n_bootstrap, 1);
    bootstrap_p_values = zeros(params.n_bootstrap, 1);
    
    for b = 1:params.n_bootstrap
        % 3.1 生成替代数据 (相位随机化 - 保留频谱，破坏时序相位/因果关系)
        X_surrogate = surrogate_phase_randomization(X);
        Y_surrogate = surrogate_phase_randomization(Y);
        
        % 3.2 添加微小高斯噪声 (模拟数据不确定性)
        X_perturbed = X_surrogate + params.noise_level * std(X_surrogate) * randn(size(X_surrogate));
        Y_perturbed = Y_surrogate + params.noise_level * std(Y_surrogate) * randn(size(Y_surrogate));
        
        % 3.3 使用相同的滞后阶数重新进行Granger检验
        % 注意: 这里调用您已有的 granger_causality_test 函数
        try
            [F_temp, p_temp] = granger_causality_test(X_perturbed, Y_perturbed, optimal_lag);
            bootstrap_F_stats(b) = F_temp;
            bootstrap_p_values(b) = p_temp;
        catch ME
            % 如果某次bootstrap失败，记录NaN
            warning('Bootstrap iteration %d failed: %s', b, ME.message);
            bootstrap_F_stats(b) = NaN;
            bootstrap_p_values(b) = NaN;
        end
    end
    
    % 4. 清理无效结果
    valid_idx = ~isnan(bootstrap_F_stats) & ~isnan(bootstrap_p_values);
    if sum(valid_idx) < params.n_bootstrap * 0.5
        warning('超过50%%的bootstrap迭代失败，鲁棒性评估可能不可靠。');
    end
    bootstrap_F_stats = bootstrap_F_stats(valid_idx);
    bootstrap_p_values = bootstrap_p_values(valid_idx);
    
    if isempty(bootstrap_F_stats)
        robustness_score = 0;
        ci_lower = NaN;
        ci_upper = NaN;
    else
        % 5. 计算鲁棒性评分
        % 5.1 显著性一致性: 自助样本结论与原始结论一致的比例
        bootstrap_significant = bootstrap_p_values < params.significance_level;
        proportion_consistent = mean(bootstrap_significant == original_significant);
        
        % 5.2 效应量稳定性: 原始F值是否在自助法F值的置信区间内
        ci_lower = prctile(bootstrap_F_stats, 2.5);
        ci_upper = prctile(bootstrap_F_stats, 97.5);
        f_in_ci = (original_F >= ci_lower) && (original_F <= ci_upper);
        
        % 5.3 综合评分 (权重可调)
        robustness_score = 0.7 * proportion_consistent + 0.3 * f_in_ci;
    end
    
    % 6. 判断是否鲁棒
    is_robust = robustness_score > 0.7; % 阈值可根据需求调整
    
    % 7. 组装输出结果
    robust_result = struct();
    robust_result.original_result = original_granger_result;
    robust_result.bootstrap_F_stats = bootstrap_F_stats;
    robust_result.bootstrap_p_values = bootstrap_p_values;
    robust_result.robustness_score = robustness_score;
    robust_result.is_robust = is_robust;
    robust_result.confidence_interval_95 = [ci_lower, ci_upper];
    robust_result.proportion_consistent = proportion_consistent;
end

function surrogate = surrogate_phase_randomization(ts)
% 通过相位随机化生成替代时间序列
% 输入: ts - 原始时间序列
% 输出: surrogate - 替代序列 (保持功率谱，破坏相位关系)
    n = length(ts);
    ts_fft = fft(ts);
    amplitude = abs(ts_fft);
    phase = angle(ts_fft);
    
    % 生成随机相位 (保留0频率分量，即均值)
    random_phase = 2 * pi * rand(size(phase)) - pi;
    random_phase(1) = 0; % 保持直流分量不变
    
    if mod(n, 2) == 0
        % 偶数长度: 保持Nyquist频率的相位不变，并确保对称性以获得实数序列
        random_phase(n/2+1) = 0;
        random_phase(2:n/2) = random_phase(2:n/2);
        random_phase(n/2+2:end) = -flip(random_phase(2:n/2));
    else
        % 奇数长度: 确保对称性
        random_phase(2:(n+1)/2) = random_phase(2:(n+1)/2);
        random_phase((n+3)/2:end) = -flip(random_phase(2:(n+1)/2));
    end
    
    new_phase = phase + random_phase;
    surrogate_fft = amplitude .* exp(1i * new_phase);
    surrogate = real(ifft(surrogate_fft));
    
    % 保持与原序列相同的均值和标准差
    surrogate = (surrogate - mean(surrogate)) / std(surrogate);
    surrogate = surrogate * std(ts) + mean(ts);
end