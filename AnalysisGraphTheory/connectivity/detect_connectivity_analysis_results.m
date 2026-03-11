function [detection_results, is_passed] = detect_connectivity_analysis_results(pairwise_results, varargin)
% DETECT_CONNECTIVITY_ANALYSIS_RESULTS 连通性分析结果完整性检测函数
% 
% 【功能描述】
% 对连通性分析(pairwise_results)的结果结构体进行全面的完整性、一致性和有效性检测。
% 支持多级检测，从基本结构验证到详细的统计质量评估。
%
% 【输入参数】
%   pairwise_results: 连通性分析结果结构体
%   varargin: 可选参数名称-值对：
%       'detection_level': 检测级别 (默认: 'standard')
%           - 'basic': 仅进行基本结构验证
%           - 'standard': 基本验证 + 一致性检查 (默认)
%           - 'comprehensive': 标准验证 + 数据质量检查
%           - 'full': 全面验证，包括统计有效性检查
%       'verbose': 是否显示详细检测报告 (默认: true)
%       'max_sample_check': 详细检查的样本数量 (默认: 5)
%       'significance_level': 显著性水平阈值 (默认: 0.05)
%
% 【输出参数】
%   detection_results: 结构体，包含详细的检测结果：
%       - is_valid: 整体验证结果
%       - validation_message: 验证消息
%       - field_status: 各字段存在状态
%       - consistency_checks: 一致性检查结果
%       - data_quality: 数据质量统计
%       - sample_inspection: 样本抽查结果
%       - timestamp: 检测时间戳
%   is_passed: 布尔值，检测是否通过
%
% 【检测内容】
% 1. 基本结构验证: 检查必需字段是否存在
% 2. 数据一致性验证: 检查各字段长度匹配
% 3. 数据质量评估: 检查缺失值、有效结果比例
% 4. 统计有效性验证: 检查显著性结果、滞后信息合理性
% 5. 样本详细检查: 随机抽查部分配对的详细结果
%
% 【调用示例】
%   % 基本检测
%   [detect_result, passed] = detect_connectivity_analysis_results(pairwise_results);
%   
%   % 全面检测，不显示详细报告
%   [detect_result, passed] = detect_connectivity_analysis_results(...
%       pairwise_results, 'detection_level', 'full', 'verbose', false);
%   
%   % 仅检查结构
%   [detect_result, passed] = detect_connectivity_analysis_results(...
%       pairwise_results, 'detection_level', 'basic');

%% 1. 参数解析
p = inputParser;
addRequired(p, 'pairwise_results', @(x) isstruct(x) || isempty(x));
addParameter(p, 'detection_level', 'standard', ...
    @(x) ismember(x, {'basic', 'standard', 'comprehensive', 'full'}));
addParameter(p, 'verbose', true, @islogical);
addParameter(p, 'max_sample_check', 5, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'significance_level', 0.05, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
parse(p, pairwise_results, varargin{:});

% 提取参数
detection_level = p.Results.detection_level;
verbose = p.Results.verbose;
max_sample_check = p.Results.max_sample_check;
alpha = p.Results.significance_level;

%% 2. 初始化检测结果结构
detection_results = struct();
detection_results.detection_level = detection_level;
detection_results.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
detection_results.parameters = p.Results;

% 记录开始时间
start_time = tic;

%% 3. 基本结构验证
if verbose
    fprintf('\n========================================\n');
    fprintf('连通性分析结果完整性检测\n');
    fprintf('检测级别: %s\n', upper(detection_level));
    fprintf('========================================\n\n');
end

% 3.1 检查输入是否为结构体
if ~isstruct(pairwise_results)
    detection_results.is_valid = false;
    detection_results.validation_message = '输入必须是结构体';
    detection_results.detection_time = toc(start_time);
    is_passed = false;
    
    if verbose
        fprintf('? 检测失败: %s\n', detection_results.validation_message);
    end
    return;
end

% 3.2 定义必需字段（按层级）
required_fields = {
    'pair_info', ...        % Level 1: 核心配对信息
    'connectivity', ...     % Level 1: 连通性结果
    'analysis_type', ...    % Level 1: 分析类型
    'parameters'            % Level 1: 分析参数
};

% 根据检测级别添加额外字段
if ~strcmp(detection_level, 'basic')
    required_fields = [required_fields; {
        'significance', ... % Level 2: 显著性结果
        'lag_info'          % Level 2: 滞后信息
    }];
end

if strcmp(detection_level, 'full')
    % 在full级别添加所有可能字段
    optional_fields = {
        'robustness', ...
        'robustness_score', ...
        'is_robust', ...
        'fingerprint_features', ...
        'processing_stats', ...
        'timestamp', ...
        'version'
    };
    required_fields = [required_fields; optional_fields(:)];
end

% 3.3 检查必需字段是否存在
detection_results.field_status = struct();
missing_fields = {};
existing_fields = {};

for i = 1:length(required_fields)
    field_name = required_fields{i};
    if isfield(pairwise_results, field_name)
        detection_results.field_status.(field_name) = true;
        existing_fields{end+1} = field_name;
    else
        detection_results.field_status.(field_name) = false;
        missing_fields{end+1} = field_name;
    end
end

% 3.4 如果有缺失字段，根据检测级别处理
if ~isempty(missing_fields)
    if any(strcmp(detection_level, {'full'}))
        % 在full级别，所有字段都必须存在
        detection_results.is_valid = false;
        detection_results.validation_message = sprintf('缺少必需字段: %s', strjoin(missing_fields, ', '));
        detection_results.detection_time = toc(start_time);
        is_passed = false;
        
        if verbose
            fprintf('? 检测失败: %s\n', detection_results.validation_message);
        end
        return;
    else
        % 在其他级别，记录警告但不失败
        detection_results.missing_fields = missing_fields;
        if verbose && ~isempty(missing_fields)
            fprintf('??  警告: 以下字段缺失: %s\n', strjoin(missing_fields, ', '));
        end
    end
end

%% 4. 数据一致性验证
detection_results.consistency_checks = struct();
detection_results.consistency_checks.passed = true;
consistency_messages = {};

% 4.1 检查pair_info字段
if isfield(pairwise_results, 'pair_info')
    n_pairs_from_info = length(pairwise_results.pair_info);
    detection_results.consistency_checks.n_pairs_from_info = n_pairs_from_info;
else
    n_pairs_from_info = 0;
end

% 4.2 检查connectivity字段
if isfield(pairwise_results, 'connectivity')
    n_pairs_from_conn = length(pairwise_results.connectivity);
    detection_results.consistency_checks.n_pairs_from_conn = n_pairs_from_conn;
    
    % 比较长度一致性
    if n_pairs_from_info > 0 && n_pairs_from_conn > 0
        if n_pairs_from_info ~= n_pairs_from_conn
            detection_results.consistency_checks.passed = false;
            msg = sprintf('配对数量不一致: pair_info=%d, connectivity=%d', ...
                n_pairs_from_info, n_pairs_from_conn);
            consistency_messages{end+1} = msg;
        end
    end
end

% 4.3 检查significance字段
if isfield(pairwise_results, 'significance')
    n_pairs_from_sig = length(pairwise_results.significance);
    detection_results.consistency_checks.n_pairs_from_sig = n_pairs_from_sig;
    
    if n_pairs_from_info > 0 && n_pairs_from_sig > 0
        if n_pairs_from_info ~= n_pairs_from_sig
            detection_results.consistency_checks.passed = false;
            msg = sprintf('配对数量不一致: pair_info=%d, significance=%d', ...
                n_pairs_from_info, n_pairs_from_sig);
            consistency_messages{end+1} = msg;
        end
    end
end

% 4.4 检查lag_info字段
if isfield(pairwise_results, 'lag_info')
    n_pairs_from_lag = length(pairwise_results.lag_info);
    detection_results.consistency_checks.n_pairs_from_lag = n_pairs_from_lag;
    
    if n_pairs_from_info > 0 && n_pairs_from_lag > 0
        if n_pairs_from_info ~= n_pairs_from_lag
            detection_results.consistency_checks.passed = false;
            msg = sprintf('配对数量不一致: pair_info=%d, lag_info=%d', ...
                n_pairs_from_info, n_pairs_from_lag);
            consistency_messages{end+1} = msg;
        end
    end
end

%% 5. 数据质量评估
detection_results.data_quality = struct();
detection_results.data_quality.passed = true;
quality_messages = {};

if isfield(pairwise_results, 'connectivity') && ~isempty(pairwise_results.connectivity)
    % 5.1 统计有效结果数量
    valid_results = ~cellfun(@isempty, pairwise_results.connectivity);
    n_valid = sum(valid_results);
    n_total = length(pairwise_results.connectivity);
    
    detection_results.data_quality.n_total = n_total;
    detection_results.data_quality.n_valid = n_valid;
    detection_results.data_quality.valid_ratio = n_valid / n_total;
    
    % 5.2 检查有效结果比例
    if n_total > 0
        if n_valid / n_total < 0.5
            detection_results.data_quality.passed = false;
            quality_messages{end+1} = sprintf('有效结果比例过低: %.1f%%', (n_valid/n_total)*100);
        end
    end
    
    % 5.3 检查是否有NaN值
    if n_valid > 0
        nan_count = 0;
        for i = 1:n_total
            if valid_results(i)
                result = pairwise_results.connectivity{i};
                if isstruct(result)
                    % 检查主要统计量是否为NaN
                    fields_to_check = {'direction', 'f_statistic_x2y', 'f_statistic_y2x', ...
                        'p_value_x2y', 'p_value_y2x'};
                    for j = 1:length(fields_to_check)
                        if isfield(result, fields_to_check{j})
                            value = result.(fields_to_check{j});
                            if isnumeric(value) && any(isnan(value))
                                nan_count = nan_count + 1;
                                break;
                            end
                        end
                    end
                end
            end
        end
        
        detection_results.data_quality.nan_count = nan_count;
        detection_results.data_quality.nan_ratio = nan_count / n_valid;
        
        if nan_count / n_valid > 0.3
            detection_results.data_quality.passed = false;
            quality_messages{end+1} = sprintf('NaN值比例过高: %.1f%%', (nan_count/n_valid)*100);
        end
    end
end

%% 6. 统计有效性验证（仅限comprehensive和full级别）
if any(strcmp(detection_level, {'comprehensive', 'full'}))
    detection_results.statistical_validity = struct();
    detection_results.statistical_validity.passed = true;
    stat_messages = {};
    
    if isfield(pairwise_results, 'connectivity') && ~isempty(pairwise_results.connectivity)
        % 6.1 统计显著性结果
        significant_x2y = 0;
        significant_y2x = 0;
        significant_both = 0;
        significant_none = 0;
        
        valid_results = ~cellfun(@isempty, pairwise_results.connectivity);
        for i = 1:length(valid_results)
            if valid_results(i)
                result = pairwise_results.connectivity{i};
                
                if isstruct(result)
                    % 检查X→Y方向显著性
                    sig_x2y = false;
                    if isfield(result, 'p_value_x2y')
                        sig_x2y = result.p_value_x2y < alpha;
                    end
                    
                    % 检查Y→X方向显著性
                    sig_y2x = false;
                    if isfield(result, 'p_value_y2x')
                        sig_y2x = result.p_value_y2x < alpha;
                    end
                    
                    % 统计
                    if sig_x2y && sig_y2x
                        significant_both = significant_both + 1;
                    elseif sig_x2y
                        significant_x2y = significant_x2y + 1;
                    elseif sig_y2x
                        significant_y2x = significant_y2x + 1;
                    else
                        significant_none = significant_none + 1;
                    end
                end
            end
        end
        
        detection_results.statistical_validity.significant_x2y = significant_x2y;
        detection_results.statistical_validity.significant_y2x = significant_y2x;
        detection_results.statistical_validity.significant_both = significant_both;
        detection_results.statistical_validity.significant_none = significant_none;
        
        n_valid_checked = sum(valid_results);
        if n_valid_checked > 0
            detection_results.statistical_validity.significant_ratio = ...
                (significant_x2y + significant_y2x + significant_both) / n_valid_checked;
            
            % 6.2 检查显著性结果分布是否合理
            if detection_results.statistical_validity.significant_ratio > 0.9
                stat_messages{end+1} = '显著性比例异常高，可能存在过度拟合';
                detection_results.statistical_validity.passed = false;
            elseif detection_results.statistical_validity.significant_ratio < 0.05
                stat_messages{end+1} = '显著性比例异常低，可能存在模型设定问题';
                detection_results.statistical_validity.passed = false;
            end
        end
        
        % 6.3 检查滞后信息合理性
        if isfield(pairwise_results, 'lag_info')
            lag_values = [];
            for i = 1:min(length(pairwise_results.lag_info), 100)  % 检查前100个
                if ~isempty(pairwise_results.lag_info{i})
                    lag_info = pairwise_results.lag_info{i};
                    if isfield(lag_info, 'optimal_lag_x2y')
                        lag_values(end+1) = lag_info.optimal_lag_x2y;
                    end
                    if isfield(lag_info, 'optimal_lag_y2x')
                        lag_values(end+1) = lag_info.optimal_lag_y2x;
                    end
                end
            end
            
            if ~isempty(lag_values)
                detection_results.statistical_validity.mean_lag = mean(lag_values);
                detection_results.statistical_validity.std_lag = std(lag_values);
                detection_results.statistical_validity.max_lag = max(abs(lag_values));
                
                % 检查滞后值是否异常
                if detection_results.statistical_validity.max_lag > 20
                    stat_messages{end+1} = sprintf('发现异常滞后值: %d', detection_results.statistical_validity.max_lag);
                    detection_results.statistical_validity.passed = false;
                end
            end
        end
    end
    
    detection_results.statistical_validity.messages = stat_messages;
end

%% 7. 样本详细检查
detection_results.sample_inspection = struct();

if isfield(pairwise_results, 'connectivity') && ~isempty(pairwise_results.connectivity)
    % 7.1 确定要检查的样本索引
    valid_indices = find(~cellfun(@isempty, pairwise_results.connectivity));
    n_valid = length(valid_indices);
    
    if n_valid > 0
        n_to_check = min(max_sample_check, n_valid);
        
        % 均匀抽样
        if n_valid <= max_sample_check
            sample_indices = valid_indices;
        else
            step = floor(n_valid / n_to_check);
            sample_indices = valid_indices(1:step:end);
            sample_indices = sample_indices(1:min(n_to_check, length(sample_indices)));
        end
        
        detection_results.sample_inspection.n_samples_checked = length(sample_indices);
        detection_results.sample_inspection.sample_indices = sample_indices;
        detection_results.sample_inspection.sample_details = cell(length(sample_indices), 1);
        
        % 7.2 详细检查每个样本
        for k = 1:length(sample_indices)
            i = sample_indices(k);
            sample_detail = struct();
            sample_detail.index = i;
            
            result = pairwise_results.connectivity{i};
            
            if isstruct(result)
                % 记录基本信息
                if isfield(result, 'direction')
                    sample_detail.direction = result.direction;
                end
                
                if isfield(result, 'p_value_x2y')
                    sample_detail.p_value_x2y = result.p_value_x2y;
                    sample_detail.significant_x2y = result.p_value_x2y < alpha;
                end
                
                if isfield(result, 'p_value_y2x')
                    sample_detail.p_value_y2x = result.p_value_y2x;
                    sample_detail.significant_y2x = result.p_value_y2x < alpha;
                end
                
                if isfield(result, 'optimal_lag_x2y')
                    sample_detail.lag_x2y = result.optimal_lag_x2y;
                end
                
                if isfield(result, 'optimal_lag_y2x')
                    sample_detail.lag_y2x = result.optimal_lag_y2x;
                end
            end
            
            detection_results.sample_inspection.sample_details{k} = sample_detail;
        end
    end
end

%% 8. 生成最终检测结论
% 8.1 汇总所有检查结果
all_checks_passed = true;
failure_messages = {};

% 检查一致性
if isfield(detection_results, 'consistency_checks')
    if ~detection_results.consistency_checks.passed
        all_checks_passed = false;
        failure_messages = [failure_messages; consistency_messages];
    end
end

% 检查数据质量
if isfield(detection_results, 'data_quality')
    if ~detection_results.data_quality.passed
        all_checks_passed = false;
        failure_messages = [failure_messages; quality_messages];
    end
end

% 检查统计有效性
if isfield(detection_results, 'statistical_validity')
    if ~detection_results.statistical_validity.passed
        all_checks_passed = false;
        if isfield(detection_results.statistical_validity, 'messages')
            failure_messages = [failure_messages; detection_results.statistical_validity.messages];
        end
    end
end

% 8.2 设置最终检测结果
detection_results.is_valid = all_checks_passed;
is_passed = all_checks_passed;

if all_checks_passed
    detection_results.validation_message = '检测通过';
    if verbose
        fprintf('? 检测通过\n');
    end
else
    detection_results.validation_message = sprintf('检测失败: %s', strjoin(failure_messages, '; '));
    if verbose
        fprintf('? 检测失败: %s\n', detection_results.validation_message);
    end
end

% 记录检测时间
detection_results.detection_time = toc(start_time);

%% 9. 生成详细报告
if verbose
    fprintf('\n----------------------------------------\n');
    fprintf('详细检测报告\n');
    fprintf('----------------------------------------\n');
    
    % 9.1 字段状态
    if isfield(detection_results, 'field_status')
        fprintf('字段状态:\n');
        fields = fieldnames(detection_results.field_status);
        for i = 1:length(fields)
            field = fields{i};
            status = detection_results.field_status.(field);
            if status
                fprintf('  ? %s\n', field);
            else
                fprintf('  ? %s (缺失)\n', field);
            end
        end
    end
    
    % 9.2 配对信息
    if isfield(pairwise_results, 'pair_info')
        fprintf('\n配对信息:\n');
        fprintf('  配对总数: %d\n', length(pairwise_results.pair_info));
    end
    
    % 9.3 有效结果统计
    if isfield(detection_results, 'data_quality')
        fprintf('\n数据质量统计:\n');
        fprintf('  有效结果数: %d/%d (%.1f%%)\n', ...
            detection_results.data_quality.n_valid, ...
            detection_results.data_quality.n_total, ...
            detection_results.data_quality.valid_ratio * 100);
        
        if isfield(detection_results.data_quality, 'nan_count')
            fprintf('  NaN结果数: %d (%.1f%%)\n', ...
                detection_results.data_quality.nan_count, ...
                detection_results.data_quality.nan_ratio * 100);
        end
    end
    
    % 9.4 显著性统计
    if isfield(detection_results, 'statistical_validity')
        fprintf('\n统计显著性:\n');
        fprintf('  X→Y显著: %d\n', detection_results.statistical_validity.significant_x2y);
        fprintf('  Y→X显著: %d\n', detection_results.statistical_validity.significant_y2x);
        fprintf('  双向显著: %d\n', detection_results.statistical_validity.significant_both);
        fprintf('  无显著: %d\n', detection_results.statistical_validity.significant_none);
        
        if isfield(detection_results.statistical_validity, 'significant_ratio')
            fprintf('  显著比例: %.1f%%\n', detection_results.statistical_validity.significant_ratio * 100);
        end
    end
    
    % 9.5 样本检查结果
    if isfield(detection_results, 'sample_inspection')
        fprintf('\n样本检查 (前%d个):\n', detection_results.sample_inspection.n_samples_checked);
        
        for k = 1:min(3, detection_results.sample_inspection.n_samples_checked)
            detail = detection_results.sample_inspection.sample_details{k};
            fprintf('\n  配对 %d:\n', detail.index);
            
            if isfield(detail, 'direction')
                fprintf('    方向: %s\n', detail.direction);
            end
            
            if isfield(detail, 'p_value_x2y')
                fprintf('    X→Y: p=%.4f, 显著: %s\n', ...
                    detail.p_value_x2y, bool2str(detail.significant_x2y));
            end
            
            if isfield(detail, 'p_value_y2x')
                fprintf('    Y→X: p=%.4f, 显著: %s\n', ...
                    detail.p_value_y2x, bool2str(detail.significant_y2x));
            end
            
            if isfield(detail, 'lag_x2y')
                fprintf('    滞后(X→Y): %d\n', detail.lag_x2y);
            end
            
            if isfield(detail, 'lag_y2x')
                fprintf('    滞后(Y→X): %d\n', detail.lag_y2x);
            end
        end
    end
    
    fprintf('\n----------------------------------------\n');
    fprintf('检测时间: %.2f 秒\n', detection_results.detection_time);
    fprintf('----------------------------------------\n\n');
end

end
