function [pairwise_results, analysis_report] = connectivity_pairwise_analyze_optimized(...
    pair_data, pair_info, analysis_type, varargin)
% CONNECTIVITY_PAIRWISE_ANALYZE_OPTIMIZED - 配对连通性分析主函数
%
% 输入参数:
%   pair_data: 元胞数组，每个元素为N×2的配对数据矩阵
%   pair_info: 结构体，配对元信息
%   analysis_type: 分析类型
%   varargin: 可选参数
%
% 输出参数:
%   pairwise_results: 所有配对的分析结果结构体数组
%   analysis_report: 连通性分析报告

    %% 1. 参数解析和初始化
    fprintf('\n========================================\n');
    fprintf('  连通性分析开始\n');
    fprintf('========================================\n\n');
    
    analysis_start_time = tic;
    
    % 参数验证
    [params, n_pairs] = validate_and_parse_parameters(pair_data, pair_info, analysis_type, varargin{:});
    
    %% 2. 初始化结果结构
    pairwise_results = struct(...
        'pair_info', cell(n_pairs, 1), ...
        'connectivity', cell(n_pairs, 1), ...
        'significance', cell(n_pairs, 1), ...
        'lag_info', cell(n_pairs, 1), ...
        'robustness', cell(n_pairs, 1), ...
        'diagnostics', cell(n_pairs, 1));
    
    %% 3. 逐个配对分析
    fprintf('开始分析 %d 个配对...\n', n_pairs);
    
    % 进度显示
    progress_interval = max(1, floor(n_pairs/20));
    fprintf('进度: 0%%');
    
    for pair_idx = 1:n_pairs
        % 显示进度
        if mod(pair_idx, progress_interval) == 0
            progress_percent = round(pair_idx/n_pairs*100);
            fprintf('\b\b\b\b%3d%%', progress_percent);
        end
        
        % 分析单个配对
        [pairwise_results(pair_idx), pair_stats] = analyze_single_pair_core(...
            pair_data{pair_idx}, pair_info, pair_idx, analysis_type, params);
    end
    
    fprintf('\b\b\b\b100%%\n');
    
    %% 4. 生成连通性分析报告
    fprintf('\n生成分析报告...\n');
    analysis_report = generate_connectivity_report(pairwise_results, analysis_start_time, params);
    
    %% 5. 显示摘要
    fprintf('\n========================================\n');
    fprintf('  连通性分析完成！\n');
    fprintf('  总时间: %.2f 秒\n', analysis_report.performance_metrics.total_time);
    fprintf('========================================\n');
end

%% 内部辅助函数
function [params, n_pairs] = validate_and_parse_parameters(pair_data, pair_info, analysis_type, varargin)
% 参数验证和解析
    
    % 基本验证
    if ~iscell(pair_data) || isempty(pair_data)
        error('pair_data必须是元胞数组且不能为空');
    end
    
    if ~isstruct(pair_info)
        error('pair_info必须是结构体');
    end
    
    % 验证必需字段
    required_fields = {'pairs', 'pair_descriptions', 'pair_types', 'pair_indices'};
    for i = 1:length(required_fields)
        if ~isfield(pair_info, required_fields{i})
            error('pair_info缺少必需字段: %s', required_fields{i});
        end
    end
    
    n_pairs = length(pair_data);
    
    % 创建输入解析器
    p = inputParser;
    
    % 基本参数
    validAnalysisTypes = {'correlation', 'granger', 'all', 'all_with_nonlinear'};
    addRequired(p, 'pair_data', @iscell);
    addRequired(p, 'pair_info', @isstruct);
    addRequired(p, 'analysis_type', @(x) any(validatestring(x, validAnalysisTypes)));
    addParameter(p, 'max_lag', 5, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'significance_level', 0.05, @(x) x > 0 && x < 1);
    addParameter(p, 'verbose', true, @islogical);
    addParameter(p, 'min_valid_obs', 20, @(x) x >= 10);
    
    % 非线性检验参数
    addParameter(p, 'enable_nonlinear_test', false, @islogical);
    addParameter(p, 'nonlinear_method', 'bds_residual', @(x) ismember(x, {'bds_residual', 'local_prediction'}));
    
    % 鲁棒性检查参数
    addParameter(p, 'enable_robustness_check', false, @islogical);
    addParameter(p, 'robustness_method', 'phase_randomization', @(x) ismember(x, {'phase_randomization', 'bootstrap_block'}));
    addParameter(p, 'robustness_n_bootstrap', 200, @(x) x >= 50 && x <= 1000);
    addParameter(p, 'robustness_threshold', 0.7, @(x) x >= 0.5 && x <= 0.9);
    
    % 并行计算参数
    addParameter(p, 'use_parallel', false, @islogical);
    
    parse(p, pair_data, pair_info, analysis_type, varargin{:});
    params = p.Results;
    params.analysis_type = lower(params.analysis_type);
    
    % 显示参数
    if params.verbose
        fprintf('分析参数:\n');
        fprintf('  - 分析类型: %s\n', params.analysis_type);
        fprintf('  - 配对数量: %d\n', n_pairs);
        fprintf('  - 最大滞后: %d\n', params.max_lag);
        fprintf('  - 显著性水平: %.3f\n', params.significance_level);
        
        if params.enable_nonlinear_test
            fprintf('  - 非线性检验: 启用 (%s)\n', params.nonlinear_method);
        end
        
        if params.enable_robustness_check
            fprintf('  - 鲁棒性检查: 启用 (%s)\n', params.robustness_method);
        end
        
        if params.use_parallel
            fprintf('  - 并行计算: 启用\n');
        end
    end
end