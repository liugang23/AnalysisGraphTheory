function [pair_result, pair_stats] = analyze_single_pair_core_main(...
    current_pair, pair_info, pair_idx, analysis_type, varargin)
% ANALYZE_SINGLE_PAIR_CORE_MAIN - 单配对分析主协调器
% 功能: 协调数据验证和连通性分析
% 输入:
%   current_pair: 配对数据矩阵
%   pair_info: 配对信息结构体
%   pair_idx: 配对索引
%   analysis_type: 分析类型
%   varargin: 其他参数
% 输出:
%   pair_result: 完整分析结果
%   pair_stats: 处理统计信息

    %% 初始化
    pair_result = struct();
    pair_stats = struct('success', 0, 'skipped', 0, 'skip_reason', '');
    
    try
        %% 1. 参数解析
        p = inputParser;
        addParameter(p, 'min_valid_obs', 20, @(x) isnumeric(x) && x >= 10);
        addParameter(p, 'significance_level', 0.05, @(x) x > 0 && x < 0.2);
        addParameter(p, 'max_lag', 5, @(x) x > 0 && x <= 20);
        addParameter(p, 'enable_robustness_check', false, @islogical);
        addParameter(p, 'robustness_method', 'bootstrap_block', @ischar);
        addParameter(p, 'robustness_n_bootstrap', 100, @(x) x >= 50 && x <= 1000);
        addParameter(p, 'enable_nonlinear_test', false, @islogical);
        addParameter(p, 'nonlinear_method', 'local_prediction', @ischar);
        parse(p, varargin{:});
        params = p.Results;
        
        %% 2. 数据提取
        if ~isnumeric(current_pair) || size(current_pair, 2) < 2
            pair_stats.skipped = 1;
            pair_stats.skip_reason = 'data_invalid';
            pair_result.diagnostics.warnings = '数据格式无效';
            return;
        end
        
        x_series = current_pair(:, 1);
        y_series = current_pair(:, 2);
        
        %% 3. 调用数据验证器
        [valid_data, validation_info] = pairing_data_validator(...
            x_series, y_series, params.min_valid_obs);
        
        if ~validation_info.passed
            pair_stats.skipped = 1;
            pair_stats.skip_reason = 'data_quality_failed';
            pair_result.diagnostics.warnings = validation_info.message;
            return;
        end
        
        %% 4. 构建配对基本信息
        pair_result.pair_info = struct(...
            'label', sprintf('%s→%s', pair_info.pairs{pair_idx}{1}, pair_info.pairs{pair_idx}{2}), ...
            'x_name', pair_info.pairs{pair_idx}{1}, ...
            'y_name', pair_info.pairs{pair_idx}{2}, ...
            'pair_description', pair_info.pair_descriptions{pair_idx}, ...
            'pair_type', pair_info.pair_types{pair_idx}, ...
            'x_idx', pair_info.pair_indices(pair_idx, 1), ...
            'y_idx', pair_info.pair_indices(pair_idx, 2), ...
            'n_obs', valid_data.n_obs, ...
            'n_valid', valid_data.n_obs, ...  % 已通过验证，全部有效
            'correlation', valid_data.correlation, ...
            'pair_index', pair_idx, ...
            'validation_info', validation_info);
        
        %% 5. 调用连通性分析调度器
        connectivity_result = connectivity_analysis_dispatcher(...
            valid_data.x, valid_data.y, analysis_type, params);
        
        pair_result.connectivity = connectivity_result;
        
        %% 6. 显著性评估
        pair_result.significance = assess_significance_core(...
            connectivity_result, analysis_type, params.significance_level);
        
        %% 7. 滞后信息提取
        pair_result.lag_info = extract_lag_info_core(...
            connectivity_result, analysis_type);
        
        %% 8. 鲁棒性检查
        if params.enable_robustness_check
            robustness_result = perform_robustness_check_core(...
                valid_data.x, valid_data.y, connectivity_result, params);
            pair_result.robustness = robustness_result;
        end
        
        %% 9. 诊断信息
        pair_result.diagnostics = struct(...
            'processing_time', toc, ...
            'validation_message', validation_info.message, ...
            'warnings', '', ...
            'errors', '', ...
            'algorithm_version', '3.0_modular');
        
        pair_stats.success = 1;
        
    catch ME
        %% 错误处理
        pair_stats.success = 0;
        pair_stats.skipped = 1;
        pair_stats.skip_reason = 'analysis_failed';
        
        if ~isfield(pair_result, 'diagnostics')
            pair_result.diagnostics = struct();
        end
        pair_result.diagnostics.errors = sprintf('分析失败: %s (行: %d)', ...
            ME.message, ME.stack(1).line);
        
        % 确保基本结构存在
        if ~isfield(pair_result, 'connectivity')
            pair_result.connectivity = [];
        end
        if ~isfield(pair_result, 'significance')
            pair_result.significance = struct('is_significant', false);
        end
    end
end

%% ==================== 辅助函数 ====================
function significance_result = assess_significance_core(connectivity_result, analysis_type, alpha)
% 显著性评估函数
    significance_result = struct('is_significant', false, 'p_values', []);
    
    if isempty(connectivity_result)
        return;
    end
    
    switch lower(analysis_type)
        case 'correlation'
            if isfield(connectivity_result, 'p_value')
                significance_result.is_significant = connectivity_result.p_value < alpha;
                significance_result.p_values = connectivity_result.p_value;
            end
            
        case 'granger'
            p_vals = [];
            if isfield(connectivity_result, 'p_value_x2y')
                p_vals = [p_vals, connectivity_result.p_value_x2y];
            end
            if isfield(connectivity_result, 'p_value_y2x')
                p_vals = [p_vals, connectivity_result.p_value_y2x];
            end
            
            significance_result.p_values = p_vals;
            significance_result.is_significant = any(p_vals < alpha);
            
        case {'all', 'all_with_nonlinear'}
            % 综合评估
            p_vals = [];
            if isfield(connectivity_result, 'correlation') && isfield(connectivity_result.correlation, 'p_value')
                p_vals = [p_vals, connectivity_result.correlation.p_value];
            end
            if isfield(connectivity_result, 'granger')
                if isfield(connectivity_result.granger, 'p_value_x2y')
                    p_vals = [p_vals, connectivity_result.granger.p_value_x2y];
                end
                if isfield(connectivity_result.granger, 'p_value_y2x')
                    p_vals = [p_vals, connectivity_result.granger.p_value_y2x];
                end
            end
            
            significance_result.p_values = p_vals;
            significance_result.is_significant = any(p_vals < alpha);
    end
end

function lag_info = extract_lag_info_core(connectivity_result, analysis_type)
% 滞后信息提取函数
    lag_info = struct('optimal_lags', [], 'dominant_lag', NaN);
    
    if isempty(connectivity_result)
        return;
    end
    
    switch lower(analysis_type)
        case 'granger'
            lags = [];
            if isfield(connectivity_result, 'optimal_lag_x2y')
                lags = [lags, connectivity_result.optimal_lag_x2y];
            end
            if isfield(connectivity_result, 'optimal_lag_y2x')
                lags = [lags, connectivity_result.optimal_lag_y2x];
            end
            
            if ~isempty(lags)
                lag_info.optimal_lags = lags;
                lag_info.dominant_lag = mode(lags);
            end
            
        case 'cross_correlation'
            if isfield(connectivity_result, 'optimal_lag')
                lag_info.optimal_lags = connectivity_result.optimal_lag;
                lag_info.dominant_lag = connectivity_result.optimal_lag;
            end
    end
end

function robustness_result = perform_robustness_check_core(x, y, original_result, params)
% 鲁棒性检查调度函数
    robustness_result = struct('is_robust', false, 'robustness_score', 0);
    
    if ~isfield(params, 'robustness_method')
        return;
    end
    
    try
        switch params.robustness_method
            case 'bootstrap_block'
                robustness_result = robustness_bootstrap_block_core(x, y, original_result, params);
            case 'phase_randomization'
                robustness_result = robustness_phase_randomization_core(x, y, original_result, params);
        end
    catch ME
        robustness_result.error = ME.message;
    end
end