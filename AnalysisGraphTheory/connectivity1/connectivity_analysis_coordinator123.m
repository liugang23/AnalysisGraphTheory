function [pairwise_results, analysis_summary] = connectivity_analysis_coordinator(...
    pair_data, pair_info, analysis_type, varargin)
% CONNECTIVITY_ANALYSIS_COORDINATOR - 连通性分析主协调器
%
% 【功能描述】
% 作为连通性分析系统的总调度器，负责参数验证、资源分配、流程控制，
% 并协调调用核心分析引擎和后处理模块。这是系统的入口函数。
%
% 【主要职责】
% 1. 参数验证与初始化
% 2. 并行/串行计算设置
% 3. 调度核心分析引擎处理所有配对
% 4. 协调后处理模块生成摘要报告
% 5. 最终结果整合与输出
%
% 输入参数:
%   pair_data: 1×M 元胞数组，每个元素为 N×2 的数值矩阵
%             - 第1列: 时间序列X (如收益率)
%             - 第2列: 时间序列Y (如成交量)
%             - 要求: 等长时间序列，允许缺失值(NaN)
%
%   pair_info: 结构体，包含配对元信息，必需字段:
%             - pairs: M×1 元胞数组，每个元素为 {X_name, Y_name}
%             - pair_descriptions: M×1 元胞数组，配对描述文本
%             - pair_types: M×1 元胞数组，配对关系类型
%             - pair_indices: M×2 矩阵，[X_idx, Y_idx] 在原始数据中的索引
%
%   analysis_type: 字符串，指定分析类型
%                 - 'correlation': 皮尔逊相关系数
%                 - 'granger': 线性Granger因果关系检验
%                 - 'transfer_entropy': 传递熵(非线性因果)
%                 - 'cross_correlation': 互相关分析
%                 - 'all': 综合以上所有方法
%                 - 'nonlinear_granger': 非线性Granger检验
%                 - 'all_with_nonlinear': 综合分析包含非线性检验
%
%   可选参数 (名称-值对，详见 analyze_single_pair_core 函数):
%     - 'max_lag': 整数，最大滞后阶数 (默认: 5)
%     - 'significance_level': 标量，显著性水平 (默认: 0.05)
%     - 'bootstrap_reps': 整数，自助法重复次数 (默认: 1000)
%     - 'enable_robustness_check': 逻辑值，是否启用鲁棒性检查
%     - 'robustness_method': 字符串，鲁棒性检验方法
%     - 'enable_nonlinear_test': 逻辑值，是否启用非线性检验
%     - 'nonlinear_method': 字符串，非线性检验方法
%     - 'use_parallel': 逻辑值，是否使用并行计算
%     - 'data_quality_check': 逻辑值，是否执行数据质量检查
%     - 'verbose': 逻辑值，是否显示详细进度
%
% 输出参数:
%   pairwise_results: 结构体数组，每个元素包含单个配对的完整分析结果
%                     - 结构定义详见 analyze_single_pair_core 函数输出
%
%   analysis_summary: 结构体，整体分析摘要，包含:
%                     - analysis_parameters: 分析参数
%                     - processing_stats: 处理统计
%                     - quality_summary: 数据质量摘要
%                     - significance_summary: 显著性统计
%                     - robustness_summary: 鲁棒性统计(如果启用)
%                     - performance_metrics: 性能指标
%                     - recommendations: 分析建议
%                     - timestamp: 分析时间戳
%                     - version: 系统版本
%
% 示例:
%   [results, summary] = connectivity_analysis_coordinator(...
%       paired_data, pair_info, 'all_with_nonlinear', ...
%       'max_lag', 5, 'significance_level', 0.01, ...
%       'enable_robustness_check', true, ...
%       'use_parallel', true, ...
%       'verbose', true);
%
% 版本: 3.0 (协调器版)
% 作者: Financial Network Analysis Toolbox
% 创建日期: 2024-12-28
% 最后修改: 2024-12-28
% =========================================================================

%% 1. 初始化与参数验证
fprintf('========================================\n');
fprintf('   连通性分析协调器\n');

analysis_start_time = tic;

% 1.1 必需参数验证
if nargin < 3
    error('错误: 至少需要3个输入参数: pair_data, pair_info, analysis_type');
end

% 验证pair_data类型和内容
if ~iscell(pair_data)
    error('错误: pair_data必须是元胞数组，当前类型: %s', class(pair_data));
end
if isempty(pair_data)
    error('错误: pair_data为空');
end

% 验证pair_info结构
if ~isstruct(pair_info)
    error('错误: pair_info必须是结构体，当前类型: %s', class(pair_info));
end

% 验证必需字段
required_fields = {'pairs', 'pair_descriptions', 'pair_types', 'pair_indices'};
missing_fields = setdiff(required_fields, fieldnames(pair_info));
if ~isempty(missing_fields)
    error('错误: pair_info缺少以下必需字段: %s', strjoin(missing_fields, ', '));
end

% 1.2 数据一致性检查
n_pairs = length(pair_data);
if n_pairs ~= length(pair_info.pairs)
    error('错误: pair_data和pair_info.pairs长度不一致: %d != %d', ...
        n_pairs, length(pair_info.pairs));
end

% 1.3 提取和分析参数
% 将所有输入参数传递给核心分析引擎进行解析
params = varargin;
analysis_type = lower(analysis_type);

% 1.4 并行计算设置
% 检查是否有并行计算参数
use_parallel_idx = find(strcmpi('use_parallel', params(1:2:end)));
if ~isempty(use_parallel_idx) && length(params) >= 2*use_parallel_idx
    use_parallel = params{2*use_parallel_idx};
else
    use_parallel = false;
end

if use_parallel
    try
        % 检查并行计算工具箱
        if ~license('test', 'Distrib_Computing_Toolbox')
            warning('Parallel Computing Toolbox未安装，将使用串行计算');
            use_parallel = false;
        else
            % 设置并行池
            parallel_workers_idx = find(strcmpi('parallel_workers', params(1:2:end)));
            if ~isempty(parallel_workers_idx) && length(params) >= 2*parallel_workers_idx
                n_workers = params{2*parallel_workers_idx};
                current_pool = gcp('nocreate');
                if isempty(current_pool)
                    parpool(n_workers);
                elseif current_pool.NumWorkers ~= n_workers
                    delete(current_pool);
                    parpool(n_workers);
                end
            else
                current_pool = gcp('nocreate');
                if isempty(current_pool)
                    parpool;
                end
            end
            fprintf('? 并行计算已启用，工作进程数: %d\n', gcp('nocreate').NumWorkers);
        end
    catch ME
        warning('并行计算设置失败: %s，将使用串行计算', ME.message);
        use_parallel = false;
    end
end

%% 2. 显示分析参数摘要
verbose_idx = find(strcmpi('verbose', params(1:2:end)));
if ~isempty(verbose_idx) && length(params) >= 2*verbose_idx
    verbose = params{2*verbose_idx};
else
    verbose = true;
end

if verbose
    fprintf('\n分析参数配置:\n');
    fprintf('  - 分析类型: %s\n', analysis_type);
    fprintf('  - 配对数量: %d\n', n_pairs);
    
    % 显示其他关键参数
    param_names = params(1:2:end);
    param_values = params(2:2:end);
    
    important_params = {'max_lag', 'significance_level', 'bootstrap_reps', ...
        'enable_robustness_check', 'robustness_method', 'enable_nonlinear_test', ...
        'nonlinear_method', 'data_quality_check'};
    
    for i = 1:length(important_params)
        idx = find(strcmpi(important_params{i}, param_names));
        if ~isempty(idx) && idx <= length(param_values)
            fprintf('  - %s: ', important_params{i});
            if islogical(param_values{idx})
                fprintf('%s\n', bool2str(param_values{idx}));
            elseif isnumeric(param_values{idx}) && isscalar(param_values{idx})
                fprintf('%g\n', param_values{idx});
            elseif ischar(param_values{idx})
                fprintf('%s\n', param_values{idx});
            end
        end
    end
    
    if use_parallel
        fprintf('  - 并行计算: 启用\n');
    end
    fprintf('\n');
end

%% 3. 初始化结果结构
pairwise_results = struct(...
    'pair_info', cell(n_pairs, 1), ...
    'connectivity', cell(n_pairs, 1), ...
    'significance', cell(n_pairs, 1), ...
    'lag_info', cell(n_pairs, 1), ...
    'robustness', cell(n_pairs, 1), ...
    'diagnostics', cell(n_pairs, 1));

%% 4. 初始化处理统计
processing_stats = struct(...
    'total_pairs', n_pairs, ...
    'processed_pairs', 0, ...
    'successful_pairs', 0, ...
    'failed_pairs', 0, ...
    'skipped_pairs', 0, ...
    'skipped_reasons', struct(...
        'insufficient_data', 0, ...
        'data_quality_failed', 0, ...
        'analysis_failed', 0, ...
        'other', 0), ...
    'processing_times', zeros(n_pairs, 1), ...
    'start_time', analysis_start_time);

%% 5. 逐个配对分析
fprintf('开始逐个配对分析...\n');

% 进度显示设置
if verbose
    progress_interval = max(1, floor(n_pairs/20));
    fprintf('进度: 0%%');
end

% 主分析循环
if use_parallel
    % 并行循环
    fprintf('? 使用并行计算 (parfor)\n');
    
    % 为parfor准备数据
    pair_data_cell = pair_data;
    pair_info_struct = pair_info;
    analysis_type_str = analysis_type;
    
    % 在parfor中收集结果
    temp_results = cell(n_pairs, 1);
    temp_stats = cell(n_pairs, 1);
    temp_times = zeros(n_pairs, 1);
    
    parfor pair_idx = 1:n_pairs
        pair_start_time = tic;
        
        % 调用核心分析引擎
        [temp_results{pair_idx}, pair_stats] = analyze_single_pair_core(...
            pair_data_cell{pair_idx}, pair_info_struct, pair_idx, ...
            analysis_type_str, params{:});
        
        % 记录处理时间
        temp_times(pair_idx) = toc(pair_start_time);
        
        % 存储处理统计
        temp_stats{pair_idx} = pair_stats;
        
        % 进度显示（在并行循环中简化）
        if verbose && mod(pair_idx, progress_interval) == 0
            fprintf('\b\b\b\b%3d%%', round(pair_idx/n_pairs*100));
        end
    end
    
    % 整合结果
    for pair_idx = 1:n_pairs
        pairwise_results(pair_idx) = temp_results{pair_idx};
        processing_stats.processing_times(pair_idx) = temp_times(pair_idx);
        
        % 更新统计
        if ~isempty(temp_stats{pair_idx})
            processing_stats.processed_pairs = processing_stats.processed_pairs + 1;
            processing_stats.successful_pairs = processing_stats.successful_pairs + temp_stats{pair_idx}.success;
            processing_stats.failed_pairs = processing_stats.failed_pairs + (1 - temp_stats{pair_idx}.success);
            processing_stats.skipped_pairs = processing_stats.skipped_pairs + temp_stats{pair_idx}.skipped;
            
            % 更新跳过原因统计
            if temp_stats{pair_idx}.skipped && isfield(temp_stats{pair_idx}, 'skip_reason')
                switch temp_stats{pair_idx}.skip_reason
                    case 'insufficient_data'
                        processing_stats.skipped_reasons.insufficient_data = ...
                            processing_stats.skipped_reasons.insufficient_data + 1;
                    case 'data_quality_failed'
                        processing_stats.skipped_reasons.data_quality_failed = ...
                            processing_stats.skipped_reasons.data_quality_failed + 1;
                    case 'analysis_failed'
                        processing_stats.skipped_reasons.analysis_failed = ...
                            processing_stats.skipped_reasons.analysis_failed + 1;
                    otherwise
                        processing_stats.skipped_reasons.other = ...
                            processing_stats.skipped_reasons.other + 1;
                end
            end
        end
    end
    
else
    % 串行循环
    fprintf('? 使用串行计算 (for)\n');
    
    for pair_idx = 1:n_pairs
        pair_start_time = tic;
        
        % 更新进度显示
        if verbose && mod(pair_idx, progress_interval) == 0
            progress_percent = round(pair_idx/n_pairs*100);
            fprintf('\b\b\b\b%3d%%', progress_percent);
        end
        
        % 调用核心分析引擎
        [pairwise_results(pair_idx), pair_stats] = analyze_single_pair_core(...
            pair_data{pair_idx}, pair_info, pair_idx, analysis_type, params{:});
        
        % 更新处理统计
        processing_stats.processed_pairs = processing_stats.processed_pairs + 1;
        processing_stats.successful_pairs = processing_stats.successful_pairs + pair_stats.success;
        processing_stats.failed_pairs = processing_stats.failed_pairs + (1 - pair_stats.success);
        processing_stats.skipped_pairs = processing_stats.skipped_pairs + pair_stats.skipped;
        
        % 更新跳过原因统计
        if pair_stats.skipped
            switch pair_stats.skip_reason
                case 'insufficient_data'
                    processing_stats.skipped_reasons.insufficient_data = ...
                        processing_stats.skipped_reasons.insufficient_data + 1;
                case 'data_quality_failed'
                    processing_stats.skipped_reasons.data_quality_failed = ...
                        processing_stats.skipped_reasons.data_quality_failed + 1;
                case 'analysis_failed'
                    processing_stats.skipped_reasons.analysis_failed = ...
                        processing_stats.skipped_reasons.analysis_failed + 1;
                otherwise
                    processing_stats.skipped_reasons.other = ...
                        processing_stats.skipped_reasons.other + 1;
            end
        end
        
        % 记录处理时间
        processing_stats.processing_times(pair_idx) = toc(pair_start_time);
    end
end

if verbose
    fprintf('\b\b\b\b100%%\n');
end

%% 6. 调用后处理模块
fprintf('\n执行后处理与摘要生成...\n');

% 收集所有分析参数传递给后处理模块
all_params = struct();
all_params.analysis_type = analysis_type;
all_params.use_parallel = use_parallel;
all_params.verbose = verbose;

% 从输入参数中提取其他参数
param_names = params(1:2:end);
param_values = params(2:2:end);
for i = 1:min(length(param_names), length(param_values))
    all_params.(param_names{i}) = param_values{i};
end

% 调用后处理模块
analysis_summary = post_processing_and_summary(...
    pairwise_results, processing_stats, all_params, analysis_start_time);

%% 7. 清理和最终输出
% 7.1 移除完全失败或跳过的配对
valid_indices = ~cellfun(@isempty, {pairwise_results.connectivity});
if any(~valid_indices)
    if verbose
        fprintf('清理无效配对结果: 保留 %d/%d 个配对\n', ...
            sum(valid_indices), n_pairs);
    end
    pairwise_results = pairwise_results(valid_indices);
end

% 7.2 添加协调器元数据
for i = 1:length(pairwise_results)
    if ~isempty(pairwise_results(i).diagnostics)
        pairwise_results(i).diagnostics.coordinator_version = '3.0';
        pairwise_results(i).diagnostics.processed_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    end
end

% 7.3 显示最终摘要
if verbose
    fprintf('\n========================================\n');
    fprintf('   分析完成！\n');
    fprintf('   总时间: %.2f 秒\n', analysis_summary.performance_metrics.total_time);
    fprintf('========================================\n');
end

fprintf('\n分析协调器执行完毕。\n');

end

%% 辅助函数
function str = bool2str(logical_value)
% BOOL2STR - 逻辑值转字符串
    if logical_value
        str = '是';
    else
        str = '否';
    end
end