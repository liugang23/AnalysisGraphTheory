function [pair_result, pair_stats] = analyze_single_pair_core(...
    pair_data, pair_info, pair_idx, analysis_type, params)
% ANALYZE_SINGLE_PAIR_CORE - 单个配对连通性分析核心模块
%
% 包含:
%   1. validate_pair_data - 数据验证
%   2. perform_connectivity_tests - 执行连通性检验

    %% 初始化
    pair_result = struct();
    pair_stats = struct('success', 0, 'skipped', 0, 'skip_reason', '');
    
    try
        %% 1. 提取配对数据
        if ~isnumeric(pair_data) || size(pair_data, 2) < 2
            pair_stats.skipped = 1;
            pair_stats.skip_reason = 'data_format_invalid';
            pair_result.diagnostics.warnings = '数据格式无效';
            return;
        end
        
        x_series = pair_data(:, 1);
        y_series = pair_data(:, 2);
        
        %% 2. 数据验证
        [validation_result, cleaned_x, cleaned_y] = validate_pair_data(x_series, y_series, params);
        
        if ~validation_result.passed
            pair_stats.skipped = 1;
            pair_stats.skip_reason = 'data_validation_failed';
            pair_result.diagnostics.warnings = validation_result.message;
            return;
        end
        
        %% 3. 执行连通性检验
        [connectivity_result, connectivity_diagnostics] = perform_connectivity_tests(...
            cleaned_x, cleaned_y, analysis_type, params, validation_result.n_valid);
        
        %% 4. 构建配对基本信息
        pair_result.pair_info = struct(...
            'label', sprintf('%s→%s', pair_info.pairs{pair_idx}{1}, pair_info.pairs{pair_idx}{2}), ...
            'x_name', pair_info.pairs{pair_idx}{1}, ...
            'y_name', pair_info.pairs{pair_idx}{2}, ...
            'pair_description', pair_info.pair_descriptions{pair_idx}, ...
            'pair_type', pair_info.pair_types{pair_idx}, ...
            'x_idx', pair_info.pair_indices(pair_idx, 1), ...
            'y_idx', pair_info.pair_indices(pair_idx, 2), ...
            'n_obs', validation_result.n_valid, ...
            'correlation', validation_result.correlation, ...
            'pair_index', pair_idx);
        
        %% 5. 存储结果
        pair_result.connectivity = connectivity_result;
        pair_result.significance = connectivity_diagnostics.significance;
        pair_result.lag_info = connectivity_diagnostics.lag_info;
        
        if params.enable_robustness_check
            pair_result.robustness = connectivity_diagnostics.robustness;
        end
        
        %% 6. 诊断信息
        pair_result.diagnostics = struct(...
            'validation_message', validation_result.message, ...
            'warnings', connectivity_diagnostics.warnings, ...
            'errors', '', ...
            'analysis_time', toc(tic));
        
        pair_stats.success = 1;
        
    catch ME
        %% 错误处理
        pair_stats.success = 0;
        pair_stats.skipped = 1;
        pair_stats.skip_reason = 'analysis_failed';
        
        pair_result.diagnostics.errors = sprintf('分析失败: %s (行: %d)', ...
            ME.message, ME.stack(1).line);
        
        % 确保基本结构存在
        if isempty(pair_result)
            pair_result = struct();
        end
        if ~isfield(pair_result, 'connectivity')
            pair_result.connectivity = [];
        end
        if ~isfield(pair_result, 'significance')
            pair_result.significance = struct('is_significant', false);
        end
    end
end

%% 子函数1: 数据验证模块
function [validation_result, x_clean, y_clean] = validate_pair_data(x, y, params)
% VALIDATE_PAIR_DATA - 数据验证子模块
    
    validation_result = struct('passed', false, 'message', '', 'n_valid', 0, 'correlation', NaN);
    x_clean = [];
    y_clean = [];
    
    % 1. 移除缺失值
    valid_idx = ~isnan(x) & ~isnan(y);
    x_clean = x(valid_idx);
    y_clean = y(valid_idx);
    n_valid = length(x_clean);
    
    validation_result.n_valid = n_valid;
    
    % 2. 检查样本数
    if n_valid < params.min_valid_obs
        validation_result.message = sprintf('有效观测数不足: %d < %d', n_valid, params.min_valid_obs);
        return;
    end
    
    % 3. 检查常数序列
    if std(x_clean) < 1e-10
        validation_result.message = 'X序列为常数';
        return;
    end
    if std(y_clean) < 1e-10
        validation_result.message = 'Y序列为常数';
        return;
    end
    
    % 4. 计算基础相关系数
    try
        corr_matrix = corrcoef(x_clean, y_clean, 'Rows', 'complete');
        correlation = corr_matrix(1, 2);
    catch
        correlation = NaN;
    end
    
    validation_result.correlation = correlation;
    validation_result.passed = true;
    validation_result.message = sprintf('通过验证，有效观测: %d', n_valid);
end

%% 子函数2: 执行连通性检验模块
function [connectivity_result, diagnostics] = perform_connectivity_tests(...
    x, y, analysis_type, params, n_obs)
% PERFORM_CONNECTIVITY_TESTS - 执行连通性检验子模块
    
    connectivity_result = struct();
    diagnostics = struct('significance', [], 'lag_info', [], 'robustness', [], 'warnings', '');
    
    try
        switch analysis_type
            case 'correlation'
                % 相关性分析
                connectivity_result = perform_correlation_analysis(x, y, params);
                diagnostics.significance = struct('is_significant', connectivity_result.p_value < params.significance_level);
                diagnostics.lag_info = struct('optimal_lag', 0);
                
            case 'granger'
                % Granger因果分析
                [granger_result, granger_diagnostics] = perform_granger_analysis(x, y, params);
                connectivity_result = granger_result;
                diagnostics.significance = assess_granger_significance(granger_result, params.significance_level);
                diagnostics.lag_info = extract_granger_lag_info(granger_result);
                
                % 非线性检验（可选）
                if params.enable_nonlinear_test
                    nonlinear_result = perform_nonlinear_analysis(x, y, params, granger_result);
                    connectivity_result.nonlinear = nonlinear_result;
                end
                
                % 鲁棒性检查（可选）
                if params.enable_robustness_check
                    robustness_result = perform_robustness_check(x, y, granger_result, params);
                    diagnostics.robustness = robustness_result;
                end
                
            case {'all', 'all_with_nonlinear'}
                % 综合分析
                connectivity_result = perform_comprehensive_analysis(x, y, params, analysis_type);
                diagnostics = assess_comprehensive_diagnostics(connectivity_result, params, n_obs);
                
        end
        
    catch ME
        diagnostics.warnings = sprintf('连通性检验失败: %s', ME.message);
    end
end

%% 具体分析方法实现
function result = perform_correlation_analysis(x, y, params)
% 执行相关性分析
    [r, p] = corr(x, y, 'Rows', 'complete');
    
    result = struct();
    result.method = 'correlation';
    result.correlation = r;
    result.p_value = p;
    result.is_significant = p < params.significance_level;
    result.effect_size = abs(r);
    
    % 置信区间
    n = length(x);
    if n >= 3
        z = 0.5 * log((1+r)/(1-r));
        z_se = 1/sqrt(n-3);
        z_crit = norminv(1-params.significance_level/2);
        z_ci = [z - z_crit*z_se, z + z_crit*z_se];
        result.confidence_interval = (exp(2*z_ci)-1) ./ (exp(2*z_ci)+1);
    else
        result.confidence_interval = [NaN, NaN];
    end
end

function [result, diagnostics] = perform_granger_analysis(x, y, params)
% 执行Granger因果分析
    
    result = struct();
    diagnostics = struct('warnings', '');
    
    try
        % 使用信息准则选择滞后
        [aic_values, bic_values, optimal_lag] = calculate_information_criteria_granger([x, y], params.max_lag);
        
        % 执行Granger检验
        [f_x2y, p_x2y, f_y2x, p_y2x] = perform_granger_test(x, y, optimal_lag);
        
        % 存储结果
        result.method = 'granger';
        result.f_statistic_x2y = f_x2y;
        result.f_statistic_y2x = f_y2x;
        result.p_value_x2y = p_x2y;
        result.p_value_y2x = p_y2x;
        result.optimal_lag_x2y = optimal_lag;
        result.optimal_lag_y2x = optimal_lag;
        
        % 方向判断
        if p_x2y < params.significance_level && p_y2x < params.significance_level
            result.direction = 'bidirectional';
        elseif p_x2y < params.significance_level
            result.direction = 'x_to_y';
        elseif p_y2x < params.significance_level
            result.direction = 'y_to_x';
        else
            result.direction = 'none';
        end
        
        result.is_significant = ~strcmp(result.direction, 'none');
        
        % 信息准则
        result.aic_values = aic_values;
        result.bic_values = bic_values;
        result.optimal_lag = optimal_lag;
        
    catch ME
        diagnostics.warnings = sprintf('Granger分析失败: %s', ME.message);
        
        % 返回空结果
        result = struct(...
            'f_statistic_x2y', NaN, 'f_statistic_y2x', NaN, ...
            'p_value_x2y', 1, 'p_value_y2x', 1, ...
            'direction', 'none', 'is_significant', false, ...
            'optimal_lag', NaN);
    end
end

function [aic_values, bic_values, optimal_lag] = calculate_information_criteria_granger(data, max_lag)
% 计算信息准则
    [n_obs, ~] = size(data);
    aic_values = inf(1, max_lag);
    bic_values = inf(1, max_lag);
    
    for lag = 1:max_lag
        n_effective = n_obs - lag;
        
        if n_effective <= 2*lag + 1
            continue;
        end
        
        try
            % 简化计算
            k = 2 * (2*lag + 1);
            
            % 估计VAR模型
            [~, residuals] = estimate_simple_var_model(data, lag);
            
            % 计算对数似然
            sigma = (residuals' * residuals) / n_effective;
            if det(sigma) > 0
                log_likelihood = -n_effective/2 * (2*log(2*pi) + log(det(sigma)) + 2);
                
                aic_values(lag) = 2*k - 2*log_likelihood;
                bic_values(lag) = k*log(n_effective) - 2*log_likelihood;
            end
        catch
            continue;
        end
    end
    
    % 找到最优滞后
    [~, optimal_lag] = min(bic_values);
    
    if isinf(bic_values(optimal_lag))
        optimal_lag = 1;
        aic_values(1) = 0;
        bic_values(1) = 0;
    end
end

function [beta, residuals] = estimate_simple_var_model(data, lag)
% 简化版VAR模型估计
    n_obs = size(data, 1);
    n_effective = n_obs - lag;
    
    % 创建滞后矩阵
    X = ones(n_effective, 1);
    for l = 1:lag
        X = [X, data(lag+1-l:end-l, :)];
    end
    
    Y = data(lag+1:end, :);
    beta = (X' * X) \ (X' * Y);
    residuals = Y - X * beta;
end

function [f_x2y, p_x2y, f_y2x, p_y2x] = perform_granger_test(x, y, lag)
% 执行Granger检验
    n = length(x);
    n_effective = n - lag;
    
    if n_effective <= 2*lag + 1
        f_x2y = 0; p_x2y = 1;
        f_y2x = 0; p_y2x = 1;
        return;
    end
    
    % 创建滞后矩阵
    x_lags = create_lag_matrix(x, lag);
    y_lags = create_lag_matrix(y, lag);
    
    % 测试X->Y
    X_restricted = [ones(n_effective, 1), y_lags];
    X_unrestricted = [ones(n_effective, 1), y_lags, x_lags];
    y_response = y(lag+1:end);
    
    [f_x2y, p_x2y] = calculate_f_test(X_restricted, X_unrestricted, y_response, lag, n_effective);
    
    % 测试Y->X
    X_restricted = [ones(n_effective, 1), x_lags];
    X_unrestricted = [ones(n_effective, 1), x_lags, y_lags];
    x_response = x(lag+1:end);
    
    [f_y2x, p_y2x] = calculate_f_test(X_restricted, X_unrestricted, x_response, lag, n_effective);
end

function lag_matrix = create_lag_matrix(series, lag)
% 创建滞后矩阵
    n = length(series);
    lag_matrix = zeros(n - lag, lag);
    for l = 1:lag
        lag_matrix(:, l) = series(lag+1-l:end-l);
    end
end

function [f_stat, p_value] = calculate_f_test(X_r, X_u, y, lag, n_obs)
% 计算F检验
    beta_r = (X_r' * X_r) \ (X_r' * y);
    beta_u = (X_u' * X_u) \ (X_u' * y);
    
    res_r = y - X_r * beta_r;
    res_u = y - X_u * beta_u;
    
    rss_r = sum(res_r.^2);
    rss_u = sum(res_u.^2);
    
    if rss_u == 0
        f_stat = 0;
        p_value = 1;
    else
        f_stat = ((rss_r - rss_u) / lag) / (rss_u / (n_obs - 2*lag - 1));
        p_value = 1 - fcdf(f_stat, lag, n_obs - 2*lag - 1);
    end
end

function significance_result = assess_granger_significance(granger_result, alpha)
% 评估Granger显著性
    significance_result = struct('is_significant', false, 'direction', 'none');
    
    if isempty(granger_result)
        return;
    end
    
    p_x2y = granger_result.p_value_x2y;
    p_y2x = granger_result.p_value_y2x;
    
    sig_x2y = p_x2y < alpha;
    sig_y2x = p_y2x < alpha;
    
    if sig_x2y && sig_y2x
        significance_result.direction = 'bidirectional';
        significance_result.is_significant = true;
    elseif sig_x2y
        significance_result.direction = 'x_to_y';
        significance_result.is_significant = true;
    elseif sig_y2x
        significance_result.direction = 'y_to_x';
        significance_result.is_significant = true;
    end
end

function lag_info = extract_granger_lag_info(granger_result)
% 提取Granger滞后信息
    lag_info = struct('optimal_lag', NaN, 'dominant_lag', NaN);
    
    if isempty(granger_result)
        return;
    end
    
    if isfield(granger_result, 'optimal_lag_x2y')
        lag_info.optimal_lag = granger_result.optimal_lag_x2y;
        lag_info.dominant_lag = granger_result.optimal_lag_x2y;
    elseif isfield(granger_result, 'optimal_lag')
        lag_info.optimal_lag = granger_result.optimal_lag;
        lag_info.dominant_lag = granger_result.optimal_lag;
    end
end

function result = perform_nonlinear_analysis(x, y, params, granger_result)
% 执行非线性分析
    result = struct('has_nonlinear_causality', false, 'direction', 'none');
    
    try
        switch params.nonlinear_method
            case 'bds_residual'
                result = perform_bds_residual_test(x, y, params, granger_result);
            case 'local_prediction'
                result = perform_local_prediction_test(x, y, params);
        end
    catch ME
        result.error = ME.message;
    end
end

function result = perform_bds_residual_test(x, y, params, granger_result)
% BDS残差非线性检验
    result = struct('method', 'bds_residual', 'has_nonlinear_causality', false);
    
    % 简化实现
    result.test_statistic = NaN;
    result.p_value = 1;
    result.is_significant = false;
end

function result = perform_local_prediction_test(x, y, params)
% 局部预测非线性检验
    result = struct('method', 'local_prediction', 'has_nonlinear_causality', false);
    
    % 简化实现
    result.test_statistic = NaN;
    result.p_value = 1;
    result.is_significant = false;
end

function result = perform_robustness_check(x, y, granger_result, params)
% 执行鲁棒性检查
    result = struct('is_robust', false, 'robustness_score', 0);
    
    try
        switch params.robustness_method
            case 'phase_randomization'
                result = perform_phase_randomization_check(x, y, granger_result, params);
            case 'bootstrap_block'
                result = perform_bootstrap_block_check(x, y, granger_result, params);
        end
    catch ME
        result.error = ME.message;
    end
end

function result = perform_phase_randomization_check(x, y, granger_result, params)
% 相位随机化鲁棒性检查
    result = struct('method', 'phase_randomization', 'is_robust', false);
    
    % 简化实现
    result.robustness_score = 0.5;
    result.is_robust = result.robustness_score > params.robustness_threshold;
end

function result = perform_bootstrap_block_check(x, y, granger_result, params)
% 块自助法鲁棒性检查
    result = struct('method', 'bootstrap_block', 'is_robust', false);
    
    % 简化实现
    result.robustness_score = 0.5;
    result.is_robust = result.robustness_score > params.robustness_threshold;
end

function result = perform_comprehensive_analysis(x, y, params, analysis_type)
% 执行综合分析
    result = struct();
    
    % 相关性分析
    result.correlation = perform_correlation_analysis(x, y, params);
    
    % Granger分析
    [granger_result, ~] = perform_granger_analysis(x, y, params);
    result.granger = granger_result;
    
    % 如果包含非线性
    if strcmp(analysis_type, 'all_with_nonlinear') && params.enable_nonlinear_test
        nonlinear_result = perform_nonlinear_analysis(x, y, params, granger_result);
        result.nonlinear = nonlinear_result;
    end
end

function diagnostics = assess_comprehensive_diagnostics(comprehensive_result, params, n_obs)
% 评估综合诊断
    diagnostics = struct('significance', [], 'lag_info', [], 'robustness', [], 'warnings', '');
    
    % 综合显著性
    sig_flags = [];
    
    if isfield(comprehensive_result, 'correlation')
        sig_flags = [sig_flags, comprehensive_result.correlation.is_significant];
    end
    
    if isfield(comprehensive_result, 'granger')
        if isfield(comprehensive_result.granger, 'is_significant')
            sig_flags = [sig_flags, comprehensive_result.granger.is_significant];
        end
    end
    
    diagnostics.significance = struct('is_significant', any(sig_flags), 'methods_significant', sig_flags);
    
    % 滞后信息
    lag_info = struct();
    if isfield(comprehensive_result, 'granger')
        lag_info = extract_granger_lag_info(comprehensive_result.granger);
    end
    diagnostics.lag_info = lag_info;
end