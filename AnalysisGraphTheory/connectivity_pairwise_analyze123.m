function pairwise_results = connectivity_pairwise_analyze(...
    pair_data, pair_info, analysis_type, varargin)
% 配对连通性分析模块
% 功能：专门执行配对连通性分析，不包含网络构建
%
% 输入：
%   pair_data    : 1×M cell，配对数据矩阵，每个元素为 N×2 矩阵
%   pair_info    : 结构体，配对信息，必须包含pairs、pair_descriptions等字段
%   analysis_type: 分析类型，可选：
%                  'correlation' - 相关系数
%                  'granger'     - Granger因果检验
%                  'transfer_entropy' - 转移熵
%                  'cross_correlation' - 互相关系数
%                  'all'        - 所有方法
%
% 可选参数（名称-值对）：
%   'max_lag'    : 最大滞后阶数（默认：5）
%   'significance_level': 显著性水平（默认：0.05）
%   'bootstrap_reps': 自助法重复次数（默认：1000）
%   'verbose'    : 是否显示详细进度（默认：true）
%
% 输出：
%   pairwise_results : 结构体，包含以下字段：
%       - pair_info: 元胞数组，每个配对的详细信息
%       - connectivity: 元胞数组，每个配对的连通性分析结果
%       - significance: 元胞数组，每个配对的显著性判断
%       - lag_info: 元胞数组，每个配对的滞后信息
%       - analysis_type: 分析类型
%       - parameters: 分析参数
%
% 科学逻辑：
%   1. 验证输入参数和数据一致性
%   2. 对每个收益-成交量配对进行连通性分析
%   3. 计算多种连通性指标（根据analysis_type）
%   4. 保存详细的配对信息和分析结果
%

%% ==================== 1. 输入验证和参数解析 ====================
fprintf('\n========================================\n');
fprintf('【模块1】配对连通性分析开始\n');

% 1.1 必需参数验证
if nargin < 3
    error('错误: 至少需要3个输入参数: pair_data, pair_info, analysis_type');
end

% 验证pair_data类型
if ~iscell(pair_data)
    error('错误: pair_data必须是元胞数组，当前类型: %s', class(pair_data));
end

% 验证pair_info结构
if ~isstruct(pair_info)
    error('错误: pair_info必须是结构体，当前类型: %s', class(pair_info));
end

% 验证pair_info必需字段
required_pair_info_fields = {'pairs', 'pair_descriptions', 'pair_types', 'pair_indices'};
missing_fields = {};
for i = 1:length(required_pair_info_fields)
    if ~isfield(pair_info, required_pair_info_fields{i})
        missing_fields{end+1} = required_pair_info_fields{i};
    end
end
if ~isempty(missing_fields)
    error('错误: pair_info缺少以下必需字段: %s', strjoin(missing_fields, ', '));
end

% 1.2 从pair_info中提取pair_labels
if isfield(pair_info, 'pair_descriptions')
    pair_labels = pair_info.pair_descriptions;  % 使用中文描述
elseif isfield(pair_info, 'pairs')
    % 从pairs生成标签
    pair_labels = cell(1, length(pair_info.pairs));
    for i = 1:length(pair_info.pairs)
        pair_labels{i} = sprintf('%s→%s', ...
            pair_info.pairs{i}{1}, pair_info.pairs{i}{2});
    end
else
    error('错误: pair_info必须包含pairs或pair_descriptions字段');
end

% 1.3 参数解析
p = inputParser;
validAnalysisTypes = {'correlation', 'granger', 'transfer_entropy', 'cross_correlation',...
    'all', 'nonlinear_granger', 'all_with_nonlinear'};
addRequired(p, 'pair_data', @iscell);
addRequired(p, 'pair_labels', @iscell);
addRequired(p, 'analysis_type', @(x) any(validatestring(x, validAnalysisTypes)));
addParameter(p, 'max_lag', 5, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'significance_level', 0.05, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
addParameter(p, 'bootstrap_reps', 1000, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'verbose', true, @islogical);

% ===== 鲁棒性相关参数 =====
addParameter(p, 'enable_robustness_check', false, @islogical);  % 是否启用鲁棒性检查
addParameter(p, 'robustness_n_bootstrap', 200, @(x) isnumeric(x) && isscalar(x) && x >= 50);  % 鲁棒性自助法次数
addParameter(p, 'robustness_noise_level', 0.01, @(x) isnumeric(x) && isscalar(x) && x > 0);  % 噪声水平
addParameter(p, 'robustness_threshold', 0.7, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 1);  % 鲁棒性评分阈值

% ===== 新增非线性检测参数 =====
addParameter(p, 'enable_nonlinear_test', false, @islogical);  % 是否启用非线性检验
addParameter(p, 'bds_m', 2:5, @(x) isnumeric(x) && isvector(x));  % BDS嵌入维度
addParameter(p, 'bds_epsilon', [], @(x) isempty(x) || (isnumeric(x) && isvector(x)));  % BDS epsilon参数

parse(p, pair_data, pair_labels, analysis_type, varargin{:});

% 提取参数
max_lag = p.Results.max_lag;
alpha = p.Results.significance_level;
n_bootstrap = p.Results.bootstrap_reps;
verbose = p.Results.verbose;
analysis_type = lower(p.Results.analysis_type);

% ===== 提取鲁棒性参数 =====
enable_robustness = p.Results.enable_robustness_check;
robustness_n_bootstrap = p.Results.robustness_n_bootstrap;
robustness_noise_level = p.Results.robustness_noise_level;
robustness_threshold = p.Results.robustness_threshold;

% ===== 非线性参数 =====
enable_nonlinear_test = p.Results.enable_nonlinear_test;
bds_m = p.Results.bds_m;
bds_epsilon = p.Results.bds_epsilon;
if isempty(bds_epsilon)
    bds_epsilon = 0.5:0.5:1.5;  % 默认值
end

% 1.4 数据一致性检查
n_pairs = length(pair_data);
if n_pairs == 0
    error('错误: pair_data为空');
end
if n_pairs ~= length(pair_labels)
    error('错误: pair_data和pair_labels长度不一致: %d != %d', ...
        n_pairs, length(pair_labels));
end
if n_pairs ~= length(pair_info.pairs)
    error('错误: pair_data和pair_info.pairs长度不一致: %d != %d', ...
        n_pairs, length(pair_info.pairs));
end

% 1.5 显示分析参数
if verbose
    fprintf('\n分析参数:\n');
    fprintf('  分析类型: %s\n', upper(analysis_type));
    fprintf('  配对数量: %d\n', n_pairs);
    fprintf('  最大滞后阶数: %d\n', max_lag);
    fprintf('  显著性水平: α = %.3f\n', alpha);
    if n_bootstrap > 0
        fprintf('  自助法重复次数: %d\n', n_bootstrap);
    end
    
    % ===== 显示鲁棒性参数 =====
    if enable_robustness
        fprintf('  鲁棒性检查: 启用\n');
        fprintf('  鲁棒性自助法次数: %d\n', robustness_n_bootstrap);
        fprintf('  噪声水平: %.3f\n', robustness_noise_level);
        fprintf('  鲁棒性阈值: %.2f\n', robustness_threshold);
    else
        fprintf('  鲁棒性检查: 禁用\n');
    end
    
    % === 显示非线性参数 ===
    if enable_nonlinear_test
        fprintf('  非线性检测: 启用\n');
        fprintf('  BDS嵌入维度: %s\n', mat2str(bds_m));
        fprintf('  BDS epsilon: %s\n', mat2str(bds_epsilon));
    end
    fprintf('\n');
end

%% ==================== 2. 初始化结果结构 ====================
pairwise_results = struct();
pairwise_results.pair_info = cell(n_pairs, 1);
pairwise_results.connectivity = cell(n_pairs, 1);
pairwise_results.significance = cell(n_pairs, 1);
pairwise_results.lag_info = cell(n_pairs, 1);

% ===== 添加鲁棒性结果字段 =====
if enable_robustness
    pairwise_results.robustness = cell(n_pairs, 1);
    pairwise_results.robustness_score = cell(n_pairs, 1);
    pairwise_results.is_robust = cell(n_pairs, 1);
end

% 记录处理统计
processing_stats = struct(...
    'total_pairs', n_pairs, ...
    'processed_pairs', 0, ...
    'skipped_pairs', 0, ...
    'successful_pairs', 0, ...
    'failed_pairs', 0, ...
    'start_time', tic);

%% ==================== 3. 逐个配对分析 ====================
    if verbose
        fprintf('开始逐个配对分析:\n');
        fprintf('\n========================================\n');
    end

    progress_interval = max(1, floor(n_pairs/20));

    for i = 1:n_pairs
        processing_stats.processed_pairs = processing_stats.processed_pairs + 1;

        % 显示进度
        if verbose && mod(i, progress_interval) == 0
            progress_percent = round(i/n_pairs*100);
            fprintf('处理进度: %3d%% (%d/%d)\n', progress_percent, i, n_pairs);
        end

        % 3.1 提取当前配对数据
        current_pair = pair_data{i};

        % 验证数据格式
        if ~isnumeric(current_pair) || size(current_pair, 2) < 2
            warning('配对 %d: 数据格式无效，跳过', i);
            processing_stats.skipped_pairs = processing_stats.skipped_pairs + 1;
            continue;
        end

        ret_series = current_pair(:, 1);  % 第一列：收益率
        obv_series = current_pair(:, 2);  % 第二列：成交量

        % 3.2 数据清理
        valid_idx = ~isnan(ret_series) & ~isnan(obv_series);
        n_valid = sum(valid_idx);

        if n_valid < 20
            if verbose
                fprintf('配对 %2d/%2d: %s - 跳过 (有效观测值不足: %d < 20)\n', ...
                    i, n_pairs, pair_labels{i}, n_valid);
            end
            processing_stats.skipped_pairs = processing_stats.skipped_pairs + 1;
            continue;
        end

        ret_clean = ret_series(valid_idx);
        obv_clean = obv_series(valid_idx);
        n_obs = length(ret_clean);

        % 3.3 计算基础相关系数
        if n_obs >= 2
            try
                corr_matrix = corrcoef(ret_clean, obv_clean, 'Rows', 'complete');
                corr_value = corr_matrix(1, 2);
            catch
                corr_value = NaN;
            end
        else
            corr_value = NaN;
        end

        % 3.4 保存配对信息
        pairwise_results.pair_info{i} = struct(...
            'label', pair_labels{i}, ...
            'ret_name', pair_info.pairs{i}{1}, ...
            'obv_name', pair_info.pairs{i}{2}, ...
            'pair_description', pair_info.pair_descriptions{i}, ...
            'pair_type', pair_info.pair_types{i}, ...
            'ret_idx', pair_info.pair_indices(i, 1), ...
            'obv_idx', pair_info.pair_indices(i, 2), ...
            'n_obs', n_obs, ...
            'n_valid', n_valid, ...
            'correlation', corr_value, ...
            'pair_index', i);

        % 3.5 执行连通性分析
        try
            switch analysis_type
                case 'correlation'
                    result = analyze_correlation(ret_clean, obv_clean, alpha, n_bootstrap);

                case 'granger'
                    % 基本Granger分析
                    result = analyze_granger_causality_complete(ret_clean, obv_clean, max_lag, alpha);
                    
                    % 启用了非线性检测
                    if enable_nonlinear_test
                        fprintf('  [配对 %d] 执行非线性Granger检测...\n', i);
                        % 调用您的非线性检测函数
                        nonlinear_result = check_nonlinear_granger(...
                            ret_clean, obv_clean, max_lag, alpha, bds_m, bds_epsilon);
                        result.nonlinear = nonlinear_result;  % 合并结果
                    end
                case 'transfer_entropy'
                    result = analyze_transfer_entropy(ret_clean, obv_clean, max_lag);

                case 'cross_correlation'
                    result = analyze_cross_correlation(ret_clean, obv_clean, max_lag, alpha);
                    
                case 'nonlinear_granger'
                    % 专门进行非线性Granger检测
                    result = check_nonlinear_granger(...
                        ret_clean, obv_clean, max_lag, alpha, bds_m, bds_epsilon);

                case 'all_with_nonlinear'
                    % 完整的综合分析（必包含非线性）
                    result_all = struct();
                    result_all.correlation = analyze_correlation(ret_clean, obv_clean, alpha, n_bootstrap);
                    result_all.granger = analyze_granger_causality_complete(ret_clean, obv_clean, max_lag, alpha);
                    result_all.cross_correlation = analyze_cross_correlation(ret_clean, obv_clean, max_lag, alpha);
                    result_all.nonlinear_granger = check_nonlinear_granger(...
                        ret_clean, obv_clean, max_lag, alpha, bds_m, bds_epsilon);
                    result = result_all;

                case 'all'
                    result_all = struct();
                    result_all.correlation = analyze_correlation(ret_clean, obv_clean, alpha, n_bootstrap);
                    result_all.granger = analyze_granger_causality(ret_clean, obv_clean, max_lag, alpha);
                    result_all.cross_correlation = analyze_cross_correlation(ret_clean, obv_clean, max_lag, alpha);
                    % 启用了非线性检测，包含非线性结果
                    if enable_nonlinear
                        nonlinear_result = check_nonlinear_granger(...
                            ret_clean, obv_clean, max_lag, alpha, bds_m, bds_epsilon);
                        result_all.nonlinear_granger = nonlinear_result;
                    end
                    result = result_all;

                otherwise
                    error('不支持的analysis_type: %s', analysis_type);
            end
            
            % ===== 鲁棒性检查 =====
            if enable_robustness && (strcmp(analysis_type, 'granger') || strcmp(analysis_type, 'all') || strcmp(analysis_type, 'all_with_nonlinear'))
                % 准备鲁棒性检查参数
                robustness_params = struct();
                robustness_params.n_bootstrap = robustness_n_bootstrap;
                robustness_params.noise_level = robustness_noise_level;
                robustness_params.significance_level = alpha;
                robustness_params.robustness_threshold = robustness_threshold;

                fprintf('  [配对 %d] 执行鲁棒性检查...\n', i);

                % 根据不同的分析类型处理
                switch analysis_type
                    case 'granger'
                        % 检查是否启用了非线性检测
                        if enable_nonlinear_test && isfield(result, 'nonlinear')
                            fprintf('    包含非线性鲁棒性检查...\n');

                            % 对线性部分进行鲁棒性检查
                            linear_robustness = check_granger_robustness(...
                                ret_clean, obv_clean, result, robustness_params);

                            % 对非线性部分进行鲁棒性检查
                            nonlinear_robustness = check_nonlinear_robustness(...
                                ret_clean, obv_clean, result.nonlinear, robustness_params);

                            % 合并结果
                            robustness_result = struct();
                            robustness_result.linear = linear_robustness;
                            robustness_result.nonlinear = nonlinear_robustness;
                            robustness_result.is_robust = linear_robustness.is_robust && nonlinear_robustness.is_robust;
                            robustness_result.robustness_score = (linear_robustness.robustness_score + nonlinear_robustness.robustness_score) / 2;

                            % 在原有结果中标记
                            result.is_robust = robustness_result.is_robust;
                            result.robustness_score = robustness_result.robustness_score;
                            result.linear_robustness_score = linear_robustness.robustness_score;
                            result.nonlinear_robustness_score = nonlinear_robustness.robustness_score;

                        else
                            % 只对线性Granger进行鲁棒性检查
                            robustness_result = check_granger_robustness(...
                                ret_clean, obv_clean, result, robustness_params);

                            % 在原有结果中标记
                            result.is_robust = robustness_result.is_robust;
                            result.robustness_score = robustness_result.robustness_score;
                        end

                    case {'all', 'all_with_nonlinear'}
                        % 对综合分析，检查Granger部分
                        original_granger_result = result.granger;

                        % 检查是否需要包含非线性
                        if enable_nonlinear_test && isfield(result, 'nonlinear_granger')
                            fprintf('    包含非线性鲁棒性检查...\n');

                            % 对线性Granger进行鲁棒性检查
                            linear_robustness = check_granger_robustness(...
                                ret_clean, obv_clean, original_granger_result, robustness_params);

                            % 对非线性Granger进行鲁棒性检查
                            nonlinear_robustness = check_nonlinear_robustness(...
                                ret_clean, obv_clean, result.nonlinear_granger, robustness_params);

                            % 合并结果
                            robustness_result = struct();
                            robustness_result.linear = linear_robustness;
                            robustness_result.nonlinear = nonlinear_robustness;
                            robustness_result.is_robust = linear_robustness.is_robust && nonlinear_robustness.is_robust;
                            robustness_result.robustness_score = (linear_robustness.robustness_score + nonlinear_robustness.robustness_score) / 2;

                            % 在原有结果中标记
                            result.granger.is_robust = linear_robustness.is_robust;
                            result.granger.robustness_score = linear_robustness.robustness_score;
                            result.nonlinear_granger.is_robust = nonlinear_robustness.is_robust;
                            result.nonlinear_granger.robustness_score = nonlinear_robustness.robustness_score;

                        else
                            % 只对线性Granger进行鲁棒性检查
                            robustness_result = check_granger_robustness(...
                                ret_clean, obv_clean, original_granger_result, robustness_params);

                            % 在原有结果中标记
                            result.granger.is_robust = robustness_result.is_robust;
                            result.granger.robustness_score = robustness_result.robustness_score;
                        end

                    otherwise
                        % 其他分析类型暂不支持鲁棒性检查
                        robustness_result = struct();
                        robustness_result.is_robust = false;
                        robustness_result.robustness_score = 0;
                        robustness_result.message = sprintf('鲁棒性检查不支持 %s 分析类型', analysis_type);
                end

                % 保存鲁棒性结果
                pairwise_results.robustness{i} = robustness_result;
                pairwise_results.robustness_score{i} = robustness_result.robustness_score;
                pairwise_results.is_robust{i} = robustness_result.is_robust;
            end

            % 3.6 保存连通性结果
            pairwise_results.connectivity{i} = result;

            % 3.7 计算显著性
            pairwise_results.significance{i} = calculate_significance(result, analysis_type, alpha);

            % 3.8 提取滞后信息
            pairwise_results.lag_info{i} = extract_lag_info(result, analysis_type);

            processing_stats.successful_pairs = processing_stats.successful_pairs + 1;

            % 3.9 显示简要结果
            if verbose
                % 獲取魯棒性信息
                robustness_info = '';
                if enable_robustness && isfield(pairwise_results, 'is_robust') && ~isempty(pairwise_results.is_robust{i})
                    if pairwise_results.is_robust{i}
                        robustness_info = ' [鲁棒]';
                    else
                        robustness_info = ' [脆弱]';
                    end
                end
                display_pair_result(i, [pair_labels{i} robustness_info], result, analysis_type);
            end

        catch ME
            processing_stats.failed_pairs = processing_stats.failed_pairs + 1;
            fprintf('配对 %s 分析失败: %s\n', pair_labels{i}, ME.message);
            if verbose
                fprintf('3.5 执行连通性分析 配对 %2d/%2d: %s - 失败: %s\n', ...
                    i, n_pairs, pair_labels{i}, ME.message);
            end
        end
    end

%% ==================== 4. 最终结果整合 ====================
    % 4.1 添加元数据
    pairwise_results.analysis_type = analysis_type;
    pairwise_results.parameters = struct(...
    'max_lag', max_lag, ...
    'significance_level', alpha, ...
    'bootstrap_reps', n_bootstrap, ...
    'verbose', verbose, ...
    'enable_robustness_check', enable_robustness, ...       % 新增
    'robustness_n_bootstrap', robustness_n_bootstrap, ...   % 新增
    'robustness_noise_level', robustness_noise_level, ...   % 新增
    'robustness_threshold', robustness_threshold);          % 新增

    % 4.2 添加处理统计
    processing_stats.computation_time = toc(processing_stats.start_time);
    pairwise_results.processing_stats = processing_stats;
    pairwise_results.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    pairwise_results.version = '1.0';

    % 4.3 清理空元素
    empty_indices = cellfun(@isempty, pairwise_results.connectivity);
    % 找出非空的索引
    if any(empty_indices)
        non_empty_idx = find(~empty_indices);

        % 只保留非空元素
        pairwise_results.pair_info = pairwise_results.pair_info(non_empty_idx);
        pairwise_results.connectivity = pairwise_results.connectivity(non_empty_idx);
        pairwise_results.significance = pairwise_results.significance(non_empty_idx);
        pairwise_results.lag_info = pairwise_results.lag_info(non_empty_idx);

        % 清理鲁棒性相关字段
        if isfield(pairwise_results, 'robustness')
            pairwise_results.robustness = pairwise_results.robustness(non_empty_idx);
        end
        if isfield(pairwise_results, 'robustness_score')
            pairwise_results.robustness_score = pairwise_results.robustness_score(non_empty_idx);
        end
        if isfield(pairwise_results, 'is_robust')
            pairwise_results.is_robust = pairwise_results.is_robust(non_empty_idx);
        end
    end

    % 4.4 显示摘要
    if verbose
        fprintf('\n========================================\n');
        fprintf('【模块1】配对连通性分析完成\n');
        fprintf('\n处理摘要:\n');
        fprintf('  总配对数量: %d\n', processing_stats.total_pairs);
        fprintf('  处理配对数量: %d\n', processing_stats.processed_pairs);
        fprintf('  成功配对数量: %d\n', processing_stats.successful_pairs);
        fprintf('  跳过配对数量: %d\n', processing_stats.skipped_pairs);
        fprintf('  失败配对数量: %d\n', processing_stats.failed_pairs);
        fprintf('  计算时间: %.2f 秒\n', processing_stats.computation_time);

        if ~isempty(pairwise_results.connectivity)
            fprintf('\n结果结构验证:\n');
            fprintf('  有效结果数量: %d\n', length(pairwise_results.connectivity));
            fprintf('  分析类型: %s\n', pairwise_results.analysis_type);

            % 显示第一个配对的结果摘要
            fprintf('\n示例配对结果 (第一个配对):\n');
            if isfield(pairwise_results.connectivity{1}, 'direction')
                fprintf('  方向: %s\n', pairwise_results.connectivity{1}.direction);
            end
            if isfield(pairwise_results.connectivity{1}, 'correlation')
                fprintf('  相关系数: %.3f\n', pairwise_results.connectivity{1}.correlation);
            end
        end
        % 4.4 显示摘要中的鲁棒性统计部分
        if enable_robustness && isfield(pairwise_results, 'robustness_score')
            % 确保有非空元素
            valid_robustness_idx = ~cellfun(@isempty, pairwise_results.robustness_score);
            if any(valid_robustness_idx)
                robustness_scores = [pairwise_results.robustness_score{valid_robustness_idx}];
                robust_count = sum([pairwise_results.is_robust{valid_robustness_idx}]);

                fprintf('鲁棒性统计摘要:\n');
                fprintf('  鲁棒连接数: %d / %d\n', robust_count, length(robustness_scores));
                fprintf('  平均鲁棒性评分: %.3f\n', mean(robustness_scores));
                fprintf('  鲁棒性评分标准差: %.3f\n', std(robustness_scores));
                fprintf('  鲁棒性评分范围: [%.3f, %.3f]\n', min(robustness_scores), max(robustness_scores));
            else
                fprintf('鲁棒性统计摘要: 无有效鲁棒性数据\n');
            end
        else
            fprintf('鲁棒性统计摘要: 未启用鲁棒性检查\n');
        end
    end

end

%% ==================== 辅助函数 ====================

function display_pair_result(pair_idx, pair_label, result, analysis_type)
% 显示配对分析结果
    fprintf('  配对 %2d: %-20s ', pair_idx, pair_label);
    
    switch analysis_type
        case 'correlation'
            if isfield(result, 'correlation') && isfield(result, 'p_value')
                fprintf('r=%.3f(p=%.4f)', result.correlation, result.p_value);
                if result.p_value < 0.001
                    fprintf(' ***');
                elseif result.p_value < 0.01
                    fprintf(' **');
                elseif result.p_value < 0.05
                    fprintf(' *');
                end
            end
            
        case 'nonlinear_granger'
            if isfield(result, 'connection_type')
                fprintf('非线性类型: %s ', result.connection_type);
            end
            if isfield(result, 'has_nonlinear_x2y')
                fprintf('X→Y:线性=%d/非线性=%d ', ...
                    result.has_linear_granger_x2y, result.has_nonlinear_x2y);
            end
            if isfield(result, 'has_nonlinear_y2x')
                fprintf('Y→X:线性=%d/非线性=%d', ...
                    result.has_linear_granger_y2x, result.has_nonlinear_y2x);
            end
            
        case 'all_with_nonlinear'
            fprintf('综合分析(含非线性): ');
            if isfield(result, 'correlation')
                fprintf('corr=%.3f ', result.correlation.correlation);
            end
            if isfield(result, 'granger')
                fprintf('granger=%s ', result.granger.direction);
            end
            if isfield(result, 'nonlinear_granger')
                fprintf('nonlin:%s ', result.nonlinear_granger.connection_type);
            end   
            
        case 'granger'
            if isfield(result, 'direction')
                fprintf('%s ', result.direction);
                if isfield(result, 'p_value_x2y') && isfield(result, 'p_value_y2x')
                    fprintf('X→Y: p=%.4f(lag=%d), ', ...
                        result.p_value_x2y, result.optimal_lag_x2y);
                    fprintf('Y→X: p=%.4f(lag=%d)', ...
                        result.p_value_y2x, result.optimal_lag_y2x);
                end
            end
            
        case 'cross_correlation'
            if isfield(result, 'max_cross_corr') && isfield(result, 'optimal_lag')
                fprintf('max_ccf=%.3f(lag=%d)', ...
                    result.max_cross_corr, result.optimal_lag);
            end
            
        case 'all'
            fprintf('多方法: ');
            if isfield(result, 'correlation')
                fprintf('corr=%.3f ', result.correlation.correlation);
            end
            if isfield(result, 'granger')
                fprintf('granger=%s ', result.granger.direction);
            end
            if isfield(result, 'cross_correlation')
                fprintf('ccf=%.3f ', result.cross_correlation.max_cross_corr);
            end
    end
    fprintf('\n');
end

function [significance_result, lag_info] = calculate_significance(connectivity_result, analysis_type, alpha)
% CALCULATE_SIGNIFICANCE - 计算配对连通性结果的显著性
%
% 输入:
%   connectivity_result: 连通性分析结果结构体
%   analysis_type: 分析类型 ('correlation', 'granger', 'all' 等)
%   alpha: 显著性水平
%
% 输出:
%   significance_result: 显著性判断结果
%   lag_info: 滞后信息结构体

    % 初始化输出
    significance_result = false;
    lag_info = struct();

    % 检查输入
    if isempty(connectivity_result)
        warning('连通性结果为空');
        return;
    end

    if ~isstruct(connectivity_result)
        warning('连通性结果不是结构体');
        return;
    end

    % 根据分析类型处理
    switch lower(analysis_type)
        case 'correlation'
            % 相关系数显著性检验
            if isfield(connectivity_result, 'correlation')
                if isfield(connectivity_result.correlation, 'p_value')
                    p_val = connectivity_result.correlation.p_value;
                    significance_result = (p_val < alpha) && ~isnan(p_val);

                    % 提取滞后信息
                    lag_info.optimal_lag = 0;  % 相关分析无滞后
                    if isfield(connectivity_result.correlation, 'max_corr_lag')
                        lag_info.max_corr_lag = connectivity_result.correlation.max_corr_lag;
                    end
                    lag_info.method = 'correlation';
                end
            end

        case 'granger'
            % Granger因果检验显著性判断
            if isfield(connectivity_result, 'direction')
                % 检查是否有p值字段
                if isfield(connectivity_result, 'p_value_x2y') && isfield(connectivity_result, 'p_value_y2x')
                    p_x2y = connectivity_result.p_value_x2y;
                    p_y2x = connectivity_result.p_value_y2x;

                    % 检查p值有效性
                    if ~isnan(p_x2y) && ~isnan(p_y2x)
                        significance_x2y = (p_x2y < alpha);
                        significance_y2x = (p_y2x < alpha);

                        % 只要有一个方向显著，就认为是显著连接
                        significance_result = significance_x2y || significance_y2x;

                        % 提取滞后信息
                        if isfield(connectivity_result, 'optimal_lag_x2y')
                            lag_info.optimal_lag_x2y = connectivity_result.optimal_lag_x2y;
                        end
                        if isfield(connectivity_result, 'optimal_lag_y2x')
                            lag_info.optimal_lag_y2x = connectivity_result.optimal_lag_y2x;
                        end
                        lag_info.direction = connectivity_result.direction;
                        lag_info.method = 'granger';
                    end
                end
            end

        case 'all'
            % 综合分析 - 只要任一方法显著就认为是显著
            sig_flags = [];

            if isfield(connectivity_result, 'correlation')
                if isfield(connectivity_result.correlation, 'p_value')
                    sig_flags = [sig_flags, connectivity_result.correlation.p_value < alpha];
                end
            end

            if isfield(connectivity_result, 'granger')
                if isfield(connectivity_result.granger, 'p_value_x2y')
                    p_x2y = connectivity_result.granger.p_value_x2y;
                    p_y2x = connectivity_result.granger.p_value_y2x;
                    sig_flags = [sig_flags, p_x2y < alpha, p_y2x < alpha];
                end
            end

            if isfield(connectivity_result, 'cross_correlation')
                if isfield(connectivity_result.cross_correlation, 'p_value')
                    sig_flags = [sig_flags, connectivity_result.cross_correlation.p_value < alpha];
                end
            end

            significance_result = any(sig_flags);

            % 提取综合滞后信息
            lag_info = struct();
            if isfield(connectivity_result, 'granger')
                if isfield(connectivity_result.granger, 'optimal_lag_x2y')
                    lag_info.granger_lag_x2y = connectivity_result.granger.optimal_lag_x2y;
                end
                if isfield(connectivity_result.granger, 'optimal_lag_y2x')
                    lag_info.granger_lag_y2x = connectivity_result.granger.optimal_lag_y2x;
                end
            end
            if isfield(connectivity_result, 'cross_correlation')
                if isfield(connectivity_result.cross_correlation, 'optimal_lag')
                    lag_info.ccf_lag = connectivity_result.cross_correlation.optimal_lag;
                end
            end

        otherwise
            warning('不支持的analysis_type: %s', analysis_type);
            significance_result = false;
    end

    % 添加元信息
    lag_info.analysis_type = analysis_type;
    lag_info.significance_level = alpha;
    lag_info.is_significant = significance_result;

end

function lag_info_struct = extract_lag_info(result, analysis_type)
% 从分析结果中提取滞后信息
%
% 输入：
%   result: 分析结果结构体
%   analysis_type: 分析类型
%
% 输出：
%   lag_info_struct: 滞后信息结构体
%

    lag_info_struct = struct();

    switch analysis_type
        case 'correlation'
            % 相关分析无滞后，但可能有最大相关滞后
            if isfield(result, 'max_corr_lag')
                lag_info_struct.optimal_lag = result.max_corr_lag;
            else
                lag_info_struct.optimal_lag = 0;
            end
            lag_info_struct.lag_type = 'correlation';

        case 'granger'
            % Granger因果检验滞后信息
            lag_info_struct.optimal_lag_x2y = result.optimal_lag_x2y;
            lag_info_struct.optimal_lag_y2x = result.optimal_lag_y2x;
            lag_info_struct.lag_type = 'granger';

            % 确定主导滞后
            if result.f_statistic_x2y > result.f_statistic_y2x
                lag_info_struct.dominant_lag = result.optimal_lag_x2y;
                lag_info_struct.dominant_direction = 'x_to_y';
            else
                lag_info_struct.dominant_lag = result.optimal_lag_y2x;
                lag_info_struct.dominant_direction = 'y_to_x';
            end

        case 'cross_correlation'
            % 互相关系数滞后信息
            lag_info_struct.optimal_lag = result.optimal_lag;
            lag_info_struct.max_cross_corr = result.max_cross_corr;
            lag_info_struct.lag_type = 'cross_correlation';
            lag_info_struct.significant_lags = result.significant_lags;

        case 'all'
            % 综合分析的滞后信息
            lag_info_struct = struct();

            if isfield(result, 'correlation')
                if isfield(result.correlation, 'max_corr_lag')
                    lag_info_struct.corr_lag = result.correlation.max_corr_lag;
                else
                    lag_info_struct.corr_lag = 0;
                end
            end

            if isfield(result, 'granger')
                lag_info_struct.granger_lag_x2y = result.granger.optimal_lag_x2y;
                lag_info_struct.granger_lag_y2x = result.granger.optimal_lag_y2x;

                % 判断主导滞后
                if result.granger.f_statistic_x2y > result.granger.f_statistic_y2x
                    lag_info_struct.dominant_granger_lag = result.granger.optimal_lag_x2y;
                    lag_info_struct.dominant_granger_direction = 'x_to_y';
                else
                    lag_info_struct.dominant_granger_lag = result.granger.optimal_lag_y2x;
                    lag_info_struct.dominant_granger_direction = 'y_to_x';
                end
            end

            if isfield(result, 'cross_correlation')
                lag_info_struct.ccf_lag = result.cross_correlation.optimal_lag;
                lag_info_struct.max_ccf = result.cross_correlation.max_cross_corr;
            end

            % 确定最终滞后（优先使用Granger滞后，如果可用）
            if isfield(lag_info_struct, 'dominant_granger_lag')
                lag_info_struct.final_lag = lag_info_struct.dominant_granger_lag;
                lag_info_struct.final_method = 'granger';
            elseif isfield(lag_info_struct, 'ccf_lag')
                lag_info_struct.final_lag = lag_info_struct.ccf_lag;
                lag_info_struct.final_method = 'cross_correlation';
            else
                lag_info_struct.final_lag = lag_info_struct.corr_lag;
                lag_info_struct.final_method = 'correlation';
            end

        otherwise
            warning('不支持的analysis_type: %s', analysis_type);
            lag_info_struct.optimal_lag = NaN;
            lag_info_struct.lag_type = 'unknown';
    end
end

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
    original_F = original_granger_result.f_statistic_x2y;
    original_p = original_granger_result.p_value_x2y;
    original_significant = original_granger_result.significant_x2y; % 是否显著
    optimal_lag = original_granger_result.optimal_lag_x2y; % 使用原始检验确定的最优滞后
    
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
        try
            % 注意：这里需要调用正确的Granger测试函数
            result_temp = analyze_granger_causality_complete(X_perturbed, Y_perturbed, optimal_lag, params.significance_level);
            
            % 提取结果
            bootstrap_F_stats(b) = result_temp.f_statistic_x2y;
            bootstrap_p_values(b) = result_temp.p_value_x2y;
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
        proportion_consistent = 0;
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

function nonlinear_result = check_nonlinear_granger(data_x, data_y, max_lag, alpha_level, bds_m, bds_epsilon)
% 非线性Granger因果关系检测（基于BDS检验）
% 核心思想：如果线性Granger不显著但残差非IID，则可能存在纯粹的非线性因果关系
%
% 输入参数：
%   data_x, data_y: 输入时间序列（列向量，已标准化）
%   max_lag: 最大滞后阶数（可选，默认5）
%   alpha_level: 显著性水平（可选，默认0.05）
%   bds_m: BDS检验的嵌入维度（可选，默认[2,3,4,5]）
%   bds_epsilon: BDS检验的epsilon参数（可选，默认0.5-1.5倍标准差）
%
% 输出结构：
%   nonlinear_result: 包含以下字段的结构体
%     .is_significant: 布尔值，是否存在非线性因果关系
%     .bds_statistics: BDS检验统计量数组
%     .bds_pvalues: BDS检验p值数组
%     .bds_critical_values: BDS临界值数组
%     .embedding_dimensions: 使用的嵌入维度
%     .epsilon_values: 使用的epsilon值
%     .var_lag: 使用的VAR模型滞后阶数
%     .residual_x: X模型的残差
%     .residual_y: Y模型的残差
%     .has_linear_granger: 是否存在线性Granger因果关系
%     .connection_type: 关系类型 ('linear_only', 'nonlinear_only', 'both', 'none')
%     .test_time: 测试时间戳
%
% 算法步骤：
%   1. 首先进行线性Granger检验
%   2. 用最优滞后拟合双变量VAR模型
%   3. 提取残差进行BDS检验
%   4. 根据线性/非线性结果判断关系类型
%
% 示例：
%   data_x = randn(100,1);
%   data_y = randn(100,1);
%   result = check_nonlinear_granger(data_x, data_y, 5, 0.05);

    % 检查输入参数
    if nargin < 3 || isempty(max_lag)
        max_lag = 5;  % 默认最大滞后
    end
    if nargin < 4 || isempty(alpha_level)
        alpha_level = 0.05;  % 默认显著性水平
    end
    if nargin < 5 || isempty(bds_m)
        bds_m = 2:5;  % 默认嵌入维度
    end
    if nargin < 6 || isempty(bds_epsilon)
        % 默认epsilon为0.5-1.5倍标准差
        epsilon_range = 0.5:0.5:1.5;
        bds_epsilon = epsilon_range * std([data_x; data_y]);
    end

    % 初始化输出结构
    nonlinear_result = struct();
    nonlinear_result.input_parameters = struct(...
        'max_lag', max_lag, ...
        'alpha_level', alpha_level, ...
        'bds_m', bds_m, ...
        'bds_epsilon', bds_epsilon);

    % 记录测试开始时间
    test_start_time = datetime('now');

% ------------------------------------------------------------------
% 步骤1：进行标准线性Granger因果关系检验
% ------------------------------------------------------------------
    fprintf('非线性检测步骤1/3：执行线性Granger检验...\n');
    linear_granger = check_pairwise_granger_causality(data_x, data_y, max_lag, alpha_level);

    % 保存线性检验结果
    nonlinear_result.linear_granger = linear_granger;
    nonlinear_result.has_linear_granger_x2y = linear_granger.is_significant_x2y;
    nonlinear_result.has_linear_granger_y2x = linear_granger.is_significant_y2x;
    nonlinear_result.optimal_lag = linear_granger.optimal_lag;

% ------------------------------------------------------------------
% 步骤2：拟合双变量VAR模型并提取残差
% ------------------------------------------------------------------
    fprintf('非线性检测步骤2/3：拟合VAR模型并提取残差...\n');
    try
        % 创建VAR模型
        var_lag = linear_granger.optimal_lag;
        if var_lag < 1
            var_lag = 1;  % 确保至少1阶滞后
        end

        % 调用fit_bivariate_var函数
        var_result = fit_bivariate_var(data_x, data_y, var_lag);

        % 提取残差
        residual_x = var_result.residual_x;
        residual_y = var_result.residual_y;

        % 检查残差是否平稳
        adf_x = adftest(residual_x);
        adf_y = adftest(residual_y);

        fprintf('  VAR滞后阶数: %d\n', var_lag);
        fprintf('  R? - X方程: %.3f, Y方程: %.3f\n', var_result.r2_x, var_result.r2_y);
        fprintf('  AIC: %.2f, BIC: %.2f\n', var_result.aic, var_result.bic);
        fprintf('  残差ADF检验 - X: %d, Y: %d (1=平稳)\n', adf_x, adf_y);

        % 保存VAR模型信息
        nonlinear_result.var_result = var_result;
        nonlinear_result.residual_x = residual_x;
        nonlinear_result.residual_y = residual_y;
        nonlinear_result.residual_adf_x = adf_x;
        nonlinear_result.residual_adf_y = adf_y;

    catch ME
        fprintf('VAR模型拟合失败: %s\n', ME.message);
        % 设置默认值
        residual_x = [];
        residual_y = [];
        nonlinear_result.residual_x = [];
        nonlinear_result.residual_y = [];
        nonlinear_result.residual_adf_x = false;
        nonlinear_result.residual_adf_y = false;
        nonlinear_result.var_result = [];

        % 跳过BDS检验
        nonlinear_result.is_significant_x2y = false;
        nonlinear_result.is_significant_y2x = false;
        nonlinear_result.x2y_nonlinear = false;
        nonlinear_result.y2x_nonlinear = false;
        nonlinear_result.connection_type = 'error';
        nonlinear_result.test_time = datetime('now') - test_start_time;
        nonlinear_result.test_completed = false;
        return;
    end

% ------------------------------------------------------------------
% 步骤3：对残差进行BDS检验
% ------------------------------------------------------------------
    fprintf('非线性检测步骤3/3：执行BDS检验...\n');
    
    % 使用输入参数中的bds_m和bds_epsilon
    fprintf('  BDS参数: 维度%s, epsilon%s\n', ...
        mat2str(bds_m), mat2str(bds_epsilon));
    
    try
        % 对X→Y方向：检验X的残差
        if ~isempty(residual_x)
            [bds_stats_x2y, bds_pvals_x2y, bds_crit_x2y, is_sig_x2y] = ...
                perform_bds_test_single(residual_x, bds_m, bds_epsilon, alpha_level);

            % 存储到结果结构体
            nonlinear_result.bds_stats_x2y = bds_stats_x2y;
            nonlinear_result.bds_pvals_x2y = bds_pvals_x2y;
            nonlinear_result.bds_crit_x2y = bds_crit_x2y;
            nonlinear_result.is_significant_x2y = is_sig_x2y;

            % 计算综合显著性
            if is_sig_x2y
                nonlinear_result.x2y_nonlinear = true;
            else
                nonlinear_result.x2y_nonlinear = false;
            end
            
            % 显示BDS结果
            display_bds_results(bds_stats_x2y, bds_pvals_x2y, bds_crit_x2y, ...
                is_sig_x2y, 'X→Y方向', bds_m, bds_epsilon);
        end
    catch ME
        fprintf('X→Y方向BDS检验失败: %s\n', ME.message);
        nonlinear_result.is_significant_x2y = false;
        nonlinear_result.x2y_nonlinear = false;
    end
    
    try
        % 对Y→X方向：检验Y的残差
        if ~isempty(residual_y)
            [bds_stats_y2x, bds_pvals_y2x, bds_crit_y2x, is_sig_y2x] = ...
                perform_bds_test_single(residual_y, bds_m, bds_epsilon, alpha_level);

            nonlinear_result.bds_stats_y2x = bds_stats_y2x;
            nonlinear_result.bds_pvals_y2x = bds_pvals_y2x;
            nonlinear_result.bds_crit_y2x = bds_crit_y2x;
            nonlinear_result.is_significant_y2x = is_sig_y2x;

            if is_sig_y2x
                nonlinear_result.y2x_nonlinear = true;
            else
                nonlinear_result.y2x_nonlinear = false;
            end
            
            % 显示BDS结果
            display_bds_results(bds_stats_y2x, bds_pvals_y2x, bds_crit_y2x, ...
                is_sig_y2x, 'Y→X方向', bds_m, bds_epsilon);
        end
    catch ME
        fprintf('Y→X方向BDS检验失败: %s\n', ME.message);
        nonlinear_result.is_significant_y2x = false;
        nonlinear_result.y2x_nonlinear = false;
    end

% ------------------------------------------------------------------
% 步骤4：判断关系类型
% ------------------------------------------------------------------
% 逻辑判断表：
% 线性显著 | 非线性显著 | 关系类型
%   是    |    是     |   both (线性+非线性混合)
%   是    |    否     |   linear_only (纯粹线性)
%   否    |    是     |   nonlinear_only (纯粹非线性)
%   否    |    否     |   none (无关系)

    has_linear_x2y = linear_granger.is_significant_x2y;
    has_linear_y2x = linear_granger.is_significant_y2x;
    has_nonlinear_x2y = nonlinear_result.is_significant_x2y;
    has_nonlinear_y2x = nonlinear_result.is_significant_y2x;

    % 确定关系类型
    if has_linear_x2y && has_nonlinear_x2y
        connection_type_x2y = 'both';
    elseif has_linear_x2y && ~has_nonlinear_x2y
        connection_type_x2y = 'linear_only';
    elseif ~has_linear_x2y && has_nonlinear_x2y
        connection_type_x2y = 'nonlinear_only';
    else
        connection_type_x2y = 'none';
    end

    if has_linear_y2x && has_nonlinear_y2x
        connection_type_y2x = 'both';
    elseif has_linear_y2x && ~has_nonlinear_y2x
        connection_type_y2x = 'linear_only';
    elseif ~has_linear_y2x && has_nonlinear_y2x
        connection_type_y2x = 'nonlinear_only';
    else
        connection_type_y2x = 'none';
    end

    % 保存结果
    nonlinear_result.has_linear_granger_x2y = has_linear_x2y;
    nonlinear_result.has_linear_granger_y2x = has_linear_y2x;
    nonlinear_result.has_nonlinear_x2y = has_nonlinear_x2y;
    nonlinear_result.has_nonlinear_y2x = has_nonlinear_y2x;
    nonlinear_result.connection_type_x2y = connection_type_x2y;
    nonlinear_result.connection_type_y2x = connection_type_y2x;
    nonlinear_result.connection_type = sprintf('%s_to_%s', connection_type_x2y, connection_type_y2x);

    % 计算测试时间
    nonlinear_result.test_time = datetime('now') - test_start_time;
    nonlinear_result.test_completed = true;

    fprintf('\n--- 非线性检测完成 ---\n');
    fprintf('测试耗时: %.2f秒\n', seconds(nonlinear_result.test_time));
    fprintf('最优滞后阶数: %d\n', nonlinear_result.optimal_lag);
    fprintf('关系类型: X→Y: %s, Y→X: %s\n', connection_type_x2y, connection_type_y2x);
    fprintf('整体关系类型: %s\n', nonlinear_result.connection_type);
    fprintf('===============================\n\n');
end

%% 辅助函数：执行单变量BDS检验
function [bds_stats_matrix, bds_pvals_matrix, bds_crit_matrix, is_significant] = ...
    perform_bds_test_single(series, m_values, epsilon_values, alpha_level)
% 对单个时间序列执行BDS检验
%
% 输入：
%   series: 时间序列（列向量）
%   m_values: 嵌入维度数组
%   epsilon_values: epsilon值数组
%   alpha_level: 显著性水平
%
% 输出：
%   bds_stats_matrix
%   bds_pvals_matrix
%   bds_crit_matrix
%   is_significant

% 检查BDS函数是否可用
    if ~exist('bds_updated', 'file')
        error('BDS检验函数bds_updated.m不存在。请确保该函数在MATLAB路径中。');
    end

    % 确保series是列向量
    if isrow(series)
        series = series';
    end

    % 初始化
    n_m = length(m_values);
    n_epsilon = length(epsilon_values);
    bds_stats_matrix = zeros(n_m, n_epsilon);
    bds_pvals_matrix = zeros(n_m, n_epsilon);
    bds_crit_matrix = zeros(n_m, n_epsilon, 3);  % 3个显著性水平

    is_significant = false;
    % 获取最大维度
    max_m = max(m_values);
    
	for j = 1:n_epsilon
        epsilon = epsilon_values(j);

        try
            % 步骤1：调用 BDS 一次调用获取所有维度的结果
            % 注意：第二个参数是最大维度maxdim
            [bds_all_stats, bds_all_pvals, bds_all_crit] = bds_updated(series, max_m, epsilon, 0, 1000);

            % 步骤2：提取并存储每个维度的结果
            for i = 1:n_m
                m = m_values(i);
                % 计算在结果数组中的索引
                % bds_updated返回维度2:max_m的结果
                % 所以维度m对应的索引是m-1
                idx = m - 1;

                if idx <= length(bds_all_stats)
                    % 提取对应维度的结果
                    bds_stat = bds_all_stats(idx);
                    p_value = bds_all_pvals(idx);

                    % 存储统计量和p值
                    bds_stats_matrix(i, j) = bds_stat;
                    bds_pvals_matrix(i, j) = p_value;
                    % === bds_all_crit 是向量，不是矩阵 ===
                    if length(bds_all_crit) >= 3
                        % 直接使用整个临界值向量
                        bds_crit_matrix(i, j, :) = bds_all_crit(1:3);
                    else
                        % 如果临界值不足3个，填充NaN
                        bds_crit_matrix(i, j, :) = [NaN, NaN, NaN];
                    end
                    
                    % 检查显著性
                    if p_value < alpha_level
                        is_significant = true;
                    end
                else
                    % 如果索引越界，存储NaN
                    bds_stats_matrix(i, j) = NaN;
                    bds_pvals_matrix(i, j) = NaN;
                    bds_crit_matrix(i, j, :) = [NaN, NaN, NaN];
                end
            end

        catch ME
            fprintf('BDS检验失败 (epsilon=%.2f): %s\n', epsilon, ME.message);
            
            % 存储NaN
            for i = 1:n_m
                bds_stats_matrix(i, j) = NaN;
                bds_pvals_matrix(i, j) = NaN;
                bds_crit_matrix(i, j, :) = [NaN, NaN, NaN];
            end
        end
	end

    % 构建结果结构
    bds_result = struct();
    bds_result.statistics = bds_stats_matrix;
    bds_result.pvalues = bds_pvals_matrix;
    bds_result.critical_values = bds_crit_matrix;
    bds_result.embedding_dimensions = m_values;
    bds_result.epsilon_values = epsilon_values;
    bds_result.alpha_level = alpha_level;
    bds_result.is_significant = is_significant;

    % 找到最显著的参数组合
    if any(~isnan(bds_pvals_matrix(:)))
        [min_pval, min_idx] = min(bds_pvals_matrix(:));
        [min_i, min_j] = ind2sub(size(bds_pvals_matrix), min_idx);

        bds_result.best_m = m_values(min_i);
        bds_result.best_epsilon = epsilon_values(min_j);
        bds_result.min_pvalue = min_pval;
        bds_result.best_statistic = bds_stats_matrix(min_i, min_j);
    else
        bds_result.best_m = NaN;
        bds_result.best_epsilon = NaN;
        bds_result.min_pvalue = NaN;
        bds_result.best_statistic = NaN;
    end
end

function var_result = fit_bivariate_var(data_x, data_y, lag_order)
% 拟合双变量VAR模型
%
% 输入：
%   data_x, data_y: 输入时间序列（列向量）
%   lag_order: VAR模型滞后阶数
%
% 输出：
%   var_result: 结构体，包含：
%     .beta_x: X方程的系数
%     .beta_y: Y方程的系数
%     .residual_x: X方程的残差
%     .residual_y: Y方程的残差
%     .fitted_x: X的拟合值
%     .fitted_y: Y的拟合值
%     .r2_x: X方程的R?
%     .r2_y: Y方程的R?
%     .aic: AIC信息准则
%     .bic: BIC信息准则

    % 确保输入是列向量
    if isrow(data_x)
        data_x = data_x';
    end
    if isrow(data_y)
        data_y = data_y';
    end

    % 检查数据长度
    T = length(data_x);
    if length(data_y) ~= T
        error('数据X和Y必须具有相同长度');
    end

    % 检查滞后阶数
    if lag_order < 1
        error('滞后阶数必须至少为1');
    end

    % 创建滞后矩阵
    n_lags = lag_order;
    n_obs = T - n_lags;

    % 初始化滞后数据矩阵
    X_lags = zeros(n_obs, 2 * n_lags);

    for lag = 1:n_lags
        X_lags(:, (lag-1)*2+1) = data_x(n_lags+1-lag:T-lag);
        X_lags(:, (lag-1)*2+2) = data_y(n_lags+1-lag:T-lag);
    end

    % 响应变量
    y_x = data_x(n_lags+1:end);
    y_y = data_y(n_lags+1:end);

    % 添加常数项
    X = [ones(n_obs, 1), X_lags];

    % 使用OLS估计
    beta_x = (X' * X) \ (X' * y_x);
    beta_y = (X' * X) \ (X' * y_y);

    % 计算拟合值和残差
    fitted_x = X * beta_x;
    fitted_y = X * beta_y;
    residual_x = y_x - fitted_x;
    residual_y = y_y - fitted_y;

    % 计算R?
    ssr_x = sum(residual_x.^2);
    sst_x = sum((y_x - mean(y_x)).^2);
    r2_x = 1 - ssr_x / sst_x;

    ssr_y = sum(residual_y.^2);
    sst_y = sum((y_y - mean(y_y)).^2);
    r2_y = 1 - ssr_y / sst_y;

    % 计算信息准则
    k = 2 * n_lags + 1;  % 参数数量（包括常数项）
    log_likelihood_x = -n_obs/2 * (1 + log(2*pi) + log(ssr_x/n_obs));
    log_likelihood_y = -n_obs/2 * (1 + log(2*pi) + log(ssr_y/n_obs));
    log_likelihood = log_likelihood_x + log_likelihood_y;

    aic = 2*k - 2*log_likelihood;
    bic = k*log(n_obs) - 2*log_likelihood;

    % 构建输出结构
    var_result = struct();
    var_result.beta_x = beta_x;
    var_result.beta_y = beta_y;
    var_result.residual_x = residual_x;
    var_result.residual_y = residual_y;
    var_result.fitted_x = fitted_x;
    var_result.fitted_y = fitted_y;
    var_result.r2_x = r2_x;
    var_result.r2_y = r2_y;
    var_result.aic = aic;
    var_result.bic = bic;
    var_result.lag_order = lag_order;
    var_result.n_obs = n_obs;
    var_result.n_params = k;

    % 计算标准误差
    sigma2_x = ssr_x / (n_obs - k);
    sigma2_y = ssr_y / (n_obs - k);
    var_cov_x = sigma2_x * inv(X' * X);
    var_cov_y = sigma2_y * inv(X' * X);

    var_result.se_x = sqrt(diag(var_cov_x));
    var_result.se_y = sqrt(diag(var_cov_y));
    var_result.tstat_x = beta_x ./ var_result.se_x;
    var_result.tstat_y = beta_y ./ var_result.se_y;
    var_result.pvalue_x = 2 * (1 - tcdf(abs(var_result.tstat_x), n_obs - k));
    var_result.pvalue_y = 2 * (1 - tcdf(abs(var_result.tstat_y), n_obs - k));
end

function robust_result = check_nonlinear_robustness(X, Y, nonlinear_result, params)
% 非线性Granger检验的鲁棒性检查
    
    % 设置默认参数
    if ~isfield(params, 'n_bootstrap')
        params.n_bootstrap = 200;
    end
    if ~isfield(params, 'noise_level')
        params.noise_level = 0.01;
    end
    if ~isfield(params, 'robustness_threshold')
        params.robustness_threshold = 0.7;
    end
    
    % 提取原始非线性检测结果
    original_x2y_linear = nonlinear_result.has_linear_granger_x2y;
    original_x2y_nonlinear = nonlinear_result.has_nonlinear_x2y;
    original_y2x_linear = nonlinear_result.has_linear_granger_y2x;
    original_y2x_nonlinear = nonlinear_result.has_nonlinear_y2x;
    
    % 自助法验证
    n_bootstrap = min(params.n_bootstrap, 100);  % 限制次数以提高速度
    bootstrap_results = zeros(n_bootstrap, 4);  % 存储4个指标
    
    for b = 1:n_bootstrap
        try
            % 相位随机化生成替代数据
            X_surrogate = surrogate_phase_randomization(X);
            Y_surrogate = surrogate_phase_randomization(Y);
            
            % 添加微小噪声
            X_perturbed = X_surrogate + params.noise_level * std(X_surrogate) * randn(size(X_surrogate));
            Y_perturbed = Y_surrogate + params.noise_level * std(Y_surrogate) * randn(size(Y_surrogate));
            
            % 重新进行非线性检测
            temp_result = check_nonlinear_granger(...
                X_perturbed, Y_perturbed, ...
                nonlinear_result.optimal_lag, ...
                nonlinear_result.alpha_level, ...
                nonlinear_result.bds_m, ...
                nonlinear_result.bds_epsilon);
            
            bootstrap_results(b, :) = [...
                temp_result.has_linear_granger_x2y, ...
                temp_result.has_nonlinear_x2y, ...
                temp_result.has_linear_granger_y2x, ...
                temp_result.has_nonlinear_y2x];
                
        catch ME
            warning('非线性鲁棒性检查第%d次迭代失败: %s', b, ME.message);
            bootstrap_results(b, :) = [...
                original_x2y_linear, original_x2y_nonlinear, ...
                original_y2x_linear, original_y2x_nonlinear];
        end
    end
    
    % 计算一致性评分
    consistency_linear_x2y = mean(bootstrap_results(:,1) == original_x2y_linear);
    consistency_nonlinear_x2y = mean(bootstrap_results(:,2) == original_x2y_nonlinear);
    consistency_linear_y2x = mean(bootstrap_results(:,3) == original_y2x_linear);
    consistency_nonlinear_y2x = mean(bootstrap_results(:,4) == original_y2x_nonlinear);
    
    % 综合鲁棒性评分
    robustness_score = mean([consistency_linear_x2y, consistency_nonlinear_x2y, ...
                            consistency_linear_y2x, consistency_nonlinear_y2x]);
    
    % 判断是否鲁棒
    is_robust = robustness_score > params.robustness_threshold;
    
    % 构建结果
    robust_result = struct();
    robust_result.robustness_score = robustness_score;
    robust_result.is_robust = is_robust;
    robust_result.consistency_linear_x2y = consistency_linear_x2y;
    robust_result.consistency_nonlinear_x2y = consistency_nonlinear_x2y;
    robust_result.consistency_linear_y2x = consistency_linear_y2x;
    robust_result.consistency_nonlinear_y2x = consistency_nonlinear_y2x;
    robust_result.bootstrap_results = bootstrap_results;
    robust_result.original_result = nonlinear_result;
end

function result = check_pairwise_granger_causality(X, Y, max_lag, alpha)
% 执行成对变量间的Granger因果检验
%
% 输入：
%   X: 第一个时间序列（n×1向量）
%   Y: 第二个时间序列（n×1向量）
%   max_lag: 最大滞后阶数
%   alpha: 显著性水平
%
% 输出：
%   result: 包含检验结果的结构体
%     .optimal_lag: 最优滞后阶数
%     .f_stat_x2y: X->Y的F统计量
%     .f_stat_y2x: Y->X的F统计量
%     .p_value_x2y: X->Y的p值
%     .p_value_y2x: Y->X的p值
%     .is_significant_x2y: X是否Granger导致Y
%     .is_significant_y2x: Y是否Granger导致X
%     .aic: AIC值（向量，每个滞后阶数）
%     .bic: BIC值（向量，每个滞后阶数）

    % 确保输入为列向量
    if isrow(X)
        X = X';
    end
    if isrow(Y)
        Y = Y';
    end
    
    % 检查数据长度
    T = length(X);
    if length(Y) ~= T
        error('X和Y的长度必须相同');
    end
    
    % 初始化结果
    result = struct();
    result.max_lag = max_lag;
    result.alpha = alpha;
    result.n_obs = T;
    
    % 信息准则矩阵
    aic_values = zeros(max_lag, 1);
    bic_values = zeros(max_lag, 1);
    
    % 测试每个滞后阶数
    for lag = 1:max_lag
        % 拟合受限模型（无Granger因果关系）
        [rss_r_x2y, rss_u_x2y, n_x2y] = fit_var_models(X, Y, lag, 'X2Y');
        [rss_r_y2x, rss_u_y2x, n_y2x] = fit_var_models(Y, X, lag, 'Y2X');
        
        % 计算F统计量
        if lag == 1
            result.f_stat_x2y(lag) = nan;
            result.f_stat_y2x(lag) = nan;
            result.p_value_x2y(lag) = nan;
            result.p_value_y2x(lag) = nan;
        else
            % X->Y的F检验
            f_x2y = ((rss_r_x2y - rss_u_x2y) / lag) / (rss_u_x2y / (n_x2y - 2*lag - 1));
            result.f_stat_x2y(lag) = f_x2y;
            result.p_value_x2y(lag) = 1 - fcdf(f_x2y, lag, n_x2y - 2*lag - 1);
            
            % Y->X的F检验
            f_y2x = ((rss_r_y2x - rss_u_y2x) / lag) / (rss_u_y2x / (n_y2x - 2*lag - 1));
            result.f_stat_y2x(lag) = f_y2x;
            result.p_value_y2x(lag) = 1 - fcdf(f_y2x, lag, n_y2x - 2*lag - 1);
        end
        
        % 计算AIC和BIC
        [aic, bic] = calculate_information_criteria([X, Y], lag);
        aic_values(lag) = aic;
        bic_values(lag) = bic;
    end
    
    % 找到最优滞后（基于BIC）
    [~, optimal_lag_idx] = min(bic_values);
    result.optimal_lag = optimal_lag_idx;
    result.aic_values = aic_values;
    result.bic_values = bic_values;
    
    % 使用最优滞后的结果
    result.f_stat_x2y_optimal = result.f_stat_x2y(optimal_lag_idx);
    result.f_stat_y2x_optimal = result.f_stat_y2x(optimal_lag_idx);
    result.p_value_x2y_optimal = result.p_value_x2y(optimal_lag_idx);
    result.p_value_y2x_optimal = result.p_value_y2x(optimal_lag_idx);
    
    % 判断显著性
    result.is_significant_x2y = result.p_value_x2y_optimal < alpha;
    result.is_significant_y2x = result.p_value_y2x_optimal < alpha;
    
    % 判断方向
    if result.is_significant_x2y && result.is_significant_y2x
        result.direction = 'bidirectional';
    elseif result.is_significant_x2y
        result.direction = 'X_to_Y';
    elseif result.is_significant_y2x
        result.direction = 'Y_to_X';
    else
        result.direction = 'none';
    end
    
    result.test_time = datetime('now');
end

%% 辅助函数：拟合VAR模型
function [rss_r, rss_u, n_obs] = fit_var_models(Y, X, lag, direction)
% 拟合受限和非受限VAR模型
% Y: 响应变量
% X: 可能的预测变量
% direction: 'X2Y' 或 'Y2X'
    
    T = length(Y);
    n_obs = T - lag;
    
    % 创建滞后矩阵
    Y_lags = zeros(n_obs, lag);
    X_lags = zeros(n_obs, lag);
    
    for l = 1:lag
        Y_lags(:, l) = Y(lag+1-l:end-l);
        X_lags(:, l) = X(lag+1-l:end-l);
    end
    
    % 响应变量
    Y_response = Y(lag+1:end);
    
    % 非受限模型：包含Y和X的滞后
    X_unrestricted = [ones(n_obs, 1), Y_lags, X_lags];
    beta_u = (X_unrestricted' * X_unrestricted) \ (X_unrestricted' * Y_response);
    res_u = Y_response - X_unrestricted * beta_u;
    rss_u = sum(res_u.^2);
    
    % 受限模型：只包含Y的滞后
    X_restricted = [ones(n_obs, 1), Y_lags];
    beta_r = (X_restricted' * X_restricted) \ (X_restricted' * Y_response);
    res_r = Y_response - X_restricted * beta_r;
    rss_r = sum(res_r.^2);
end

%% 辅助函数：计算信息准则
function [aic, bic] = calculate_information_criteria(data, lag)
% 计算AIC和BIC
    
    [T, n_var] = size(data);
    n_obs = T - lag;
    
    % 拟合VAR模型
    X_lags = [];
    for l = 1:lag
        X_lags = [X_lags, data(lag+1-l:end-l, :)];
    end
    X = [ones(n_obs, 1), X_lags];
    
    Y = data(lag+1:end, :);
    beta = (X' * X) \ (X' * Y);
    residuals = Y - X * beta;
    
    % 计算对数似然
    sigma = (residuals' * residuals) / n_obs;
    log_likelihood = -n_obs/2 * (n_var * (1 + log(2*pi)) + log(det(sigma)));
    
    % 参数数量
    k = n_var * (n_var * lag + 1);
    
    % 信息准则
    aic = 2*k - 2*log_likelihood;
    bic = k*log(n_obs) - 2*log_likelihood;
end

% ------------------------------------------------------------------
% 辅助函数：显示BDS检验结果
% ------------------------------------------------------------------
function display_bds_results(bds_stats, bds_pvals, bds_crit, is_sig, direction_label, bds_m, bds_epsilon)
    
    fprintf('\n===== BDS非线性检验结果 (%s) =====\n', direction_label);
    fprintf('是否显著: %s\n', mat2str(is_sig));
    fprintf('维度\\epsilon');
    
    [n_m, n_eps] = size(bds_stats);
    
    % 打印表头
    for j = 1:n_eps
        if j <= length(bds_epsilon)
            fprintf('\tε=%.2f', bds_epsilon(j));
        else
            fprintf('\tε=%d', j);
        end
    end
    fprintf('\n');
    
    % 打印统计量
    for i = 1:n_m
        if i <= length(bds_m)
            fprintf('m=%d', bds_m(i));
        else
            fprintf('m=%d', i+1);
        end
        
        for j = 1:n_eps
            bds_stat = bds_stats(i, j);
            
            if ~isnan(bds_stat)
                fprintf('\t%7.3f', bds_stat);
            else
                fprintf('\t   NaN');
            end
        end
        fprintf('\n');
    end
    
    fprintf('\np值:\n');
    % 打印p值
    for i = 1:n_m
        if i <= length(bds_m)
            fprintf('m=%d', bds_m(i));
        else
            fprintf('m=%d', i+1);
        end
        
        for j = 1:n_eps
            p_val = bds_pvals(i, j);
            
            if ~isnan(p_val)
                if p_val < 0.01
                    fprintf('\t<0.01**');
                elseif p_val < 0.05
                    fprintf('\t<0.05* ');
                elseif p_val < 0.10
                    fprintf('\t<0.10? ');
                else
                    fprintf('\t%.3f  ', p_val);
                end
            else
                fprintf('\t  NaN ');
            end
        end
        fprintf('\n');
    end
    
    fprintf('\n----------------------------------------\n');
    fprintf('显著性标记: **p<0.01, *p<0.05, ?p<0.10\n');
    fprintf('========================================\n\n');
end