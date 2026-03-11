function [paired_data, pair_info] = create_price_volume_pairs(data_matrix, var_names, varargin)
% =========================================================================
% CREATE_PRICE_VOLUME_PAIRS_ENHANCED 增强版 - 创建标准化价量配对数据
% 
% 【功能描述】
% 本函数从包含多周期价格（收益率）和成交量（OBV）指标的原始数据矩阵中，
% 根据用户指定的分析类型，系统性地生成所有有意义的配对关系。生成的配对数据
% 经过标准化处理，确保与下游的连通性分析函数（如 GraphTheory_connectivity_pairwise_module）
% 完全兼容。
%
% 【数据标准化原则】
% 1. 语义方向：由 pair_info 中的字段（pairs, pair_types, descriptions）记录。
%    例如：'ret_5' -> 'OBV_WMA_20' 表示“5天收益率传导至20天OBV”。
% 2. 物理数据顺序：在 paired_data 的每个矩阵中，第一列固定为收益率序列，
%    第二列固定为成交量序列。无论配对的理论方向如何，在统计计算时都按此
%    统一格式提供，避免下游函数混淆。
%
% 【输出结构说明】
% paired_data: 1×M 元胞数组，每个元素是一个 N×2 的 double 矩阵。
%             - 第1列：收益率序列
%             - 第2列：OBV序列
%             - 顺序已根据配对类型自动调整，确保格式统一。
%
% pair_info: 结构体，包含完整的配对元信息，字段如下：
%   - var_names: 原始变量名列表
%   - ret_vars, obv_vars: 分类后的收益率和OBV变量名
%   - ret_periods, obv_periods: 对应的周期（天数）
%   - ret_indices, obv_indices: 在原始数据矩阵中的列索引
%   - pairs: M×1 元胞数组，每个元素为 {source_name, target_name}，记录语义方向
%   - pair_types: M×1 元胞数组，配对关系类型（见下文“配对类型”）
%   - pair_descriptions: M×1 元胞数组，配对的文字描述
%   - pair_indices: M×2 矩阵，[source_idx_in_raw_data, target_idx_in_raw_data]
%   - total_pairs: 配对总数
%   - analysis_type: 用户指定的分析类型
%   - creation_time: 函数执行时间戳
%
% 【配对类型定义】
% 1. 'price_to_volume_sync':      同期价导量 (ret_X -> OBV_WMA_X)
% 2. 'volume_to_price_sync':      同期量导价 (OBV_WMA_X -> ret_X)
% 3. 'price_conduction':          跨期价导价 (ret_短 -> ret_长)
% 4. 'volume_conduction':         跨期量导量 (OBV_短 -> OBV_长)
% 5. 'price_to_volume_conduction': 价导量传导 (ret_短 -> OBV_长)
% 6. 'volume_to_price_conduction': 量导价传导 (OBV_短 -> ret_长)
%
% 输入参数:
%   data_matrix: N×P 数值矩阵，N为样本数，P为变量数
%   var_names: 1×P 字符串元胞数组，变量名称
%   可选参数 (名称-值对):
%       'analysis_type': 分析类型，决定生成哪些配对
%           - 'all' (默认): 生成全部6种关系
%           - 'sync': 只生成同期关系（类型1和2）
%           - 'conduction': 只生成跨期传导关系（类型3-6）
%       'min_period_gap': 整数，传导关系要求的最小周期差（默认0）
%       'verbose': 逻辑值，是否显示处理详情（默认false）
%
% 输出参数:
%   paired_data: 标准化后的配对数据元胞数组
%   pair_info: 配对元信息结构体
%
% 示例:
%   [paired_data, pair_info] = create_price_volume_pairs_enhanced(...
%       data, var_names, 'analysis_type', 'all', 'min_period_gap', 5);
%
% 版本: 2.0
% 作者: Financial Network Analysis Toolbox
% 创建日期: 2024-12-28
% 最后修改: 2024-12-28
% =========================================================================

%% 1. 参数解析与验证
fprintf('========================================\n');
fprintf('  增强版价量配对函数 (标准化输出)\n');
fprintf('========================================\n\n');

% 创建输入解析器
p = inputParser;
addRequired(p, 'data_matrix', @(x) validateattributes(x, {'numeric'}, {'2d', 'nonempty'}));
addRequired(p, 'var_names', @(x) validateattributes(x, {'cell'}, {'vector'}));
addParameter(p, 'analysis_type', 'all', @(x) ismember(x, {'all', 'sync', 'conduction'}));
addParameter(p, 'min_period_gap', 0, @(x) validateattributes(x, {'numeric'}, {'scalar', 'integer', 'nonnegative'}));
addParameter(p, 'verbose', false, @(x) validateattributes(x, {'logical'}, {'scalar'}));
parse(p, data_matrix, var_names, varargin{:});

% 提取解析后的参数
data_matrix = p.Results.data_matrix;
var_names = p.Results.var_names;
analysis_type = p.Results.analysis_type;
min_gap = p.Results.min_period_gap;
verbose = p.Results.verbose;

% 基本数据验证
[n_samples, n_vars] = size(data_matrix);
if length(var_names) ~= n_vars
    error('错误: 变量名数量(%d)与数据矩阵列数(%d)不匹配。', length(var_names), n_vars);
end

if verbose
    fprintf('? 输入参数验证通过:\n');
    fprintf('   样本数量: %d\n', n_samples);
    fprintf('   变量数量: %d\n', n_vars);
    fprintf('   分析类型: %s\n', analysis_type);
    if min_gap > 0
        fprintf('   最小周期差: %d\n', min_gap);
    end
    fprintf('\n');
end

%% 2. 变量分类与提取
% 提取所有收益率变量 (以 'ret_' 开头)
[ret_vars, ret_periods, ret_indices] = extract_variables_by_pattern(var_names, 'ret_');
% 提取所有成交量变量 (以 'OBV_WMA_' 开头)
[obv_vars, obv_periods, obv_indices] = extract_variables_by_pattern(var_names, 'OBV_WMA_');

% 检查是否至少找到一种类型的变量
if isempty(ret_vars) || isempty(obv_vars)
    error('错误: 在变量列表中未同时找到收益率(ret_)和成交量(OBV_WMA_)变量。');
end

if verbose
    fprintf('? 变量分类完成:\n');
    fprintf('   收益率变量 (%d个): ', length(ret_vars));
    fprintf('%s(%d天) ', ret_vars{:}, ret_periods);
    fprintf('\n');
    fprintf('   成交量变量 (%d个): ', length(obv_vars));
    fprintf('%s(%d天) ', obv_vars{:}, obv_periods);
    fprintf('\n\n');
end

%% 3. 根据分析类型创建配对列表
% 初始化存储配对信息的容器
all_pairs = {};          % 语义方向: {source, target}
all_pair_types = {};     % 关系类型
all_descriptions = {};   % 文字描述
all_indices = [];        % 原始索引: [source_idx, target_idx]

switch analysis_type
    case 'all'
        if verbose, fprintf('? 生成全部6种关系类型:\n'); end
        % 生成所有6种关系
        [all_pairs, all_pair_types, all_descriptions, all_indices] = ...
            generate_all_relationships(...
                ret_vars, ret_periods, ret_indices, ...
                obv_vars, obv_periods, obv_indices, ...
                min_gap, verbose);
        
    case 'sync'
        if verbose, fprintf('? 生成同期关系 (价→量, 量→价):\n'); end
        % 只生成同期关系
        [all_pairs, all_pair_types, all_descriptions, all_indices] = ...
            generate_sync_relationships(...
                ret_vars, ret_periods, ret_indices, ...
                obv_vars, obv_periods, obv_indices, ...
                verbose);
        
    case 'conduction'
        if verbose, fprintf('? 生成跨期传导关系:\n'); end
        % 只生成跨期传导关系
        [all_pairs, all_pair_types, all_descriptions, all_indices] = ...
            generate_conduction_relationships(...
                ret_vars, ret_periods, ret_indices, ...
                obv_vars, obv_periods, obv_indices, ...
                min_gap, verbose);
end

% 检查是否生成了配对
if isempty(all_pairs)
    error('错误: 根据当前参数未生成任何有效配对。请检查输入参数。');
end

n_pairs = length(all_pairs);
if verbose
    fprintf('\n? 共生成 %d 个配对。\n', n_pairs);
end

%% 4. 提取并标准化配对数据
% 此步骤确保 paired_data 中的每个矩阵均为 [收益率, 成交量] 格式
paired_data = cell(1, n_pairs);
if verbose
    fprintf('? 提取并标准化配对数据 (格式: [收益率, 成交量]):\n');
end

for i = 1:n_pairs
    % 获取原始索引
    source_idx = all_indices(i, 1);
    target_idx = all_indices(i, 2);
    
    % 获取配对类型
    current_type = all_pair_types{i};
    
    % 根据配对类型决定数据顺序
    % 关键逻辑：无论语义方向如何，最终数据矩阵第1列必须是收益率，第2列必须是成交量
    switch current_type
        case {'price_to_volume_sync', 'price_conduction', 'price_to_volume_conduction'}
            % 类型1,3,5: 源是收益率，目标是成交量
            % 数据顺序: [收益率(源), 成交量(目标)]
            ret_data = data_matrix(:, source_idx);
            obv_data = data_matrix(:, target_idx);
            
        case {'volume_to_price_sync', 'volume_conduction', 'volume_to_price_conduction'}
            % 类型2,4,6: 源是成交量，目标是收益率
            % 数据顺序: [收益率(目标), 成交量(源)]
            ret_data = data_matrix(:, target_idx);
            obv_data = data_matrix(:, source_idx);
            
        otherwise
            error('错误: 未知的配对类型 "%s"。', current_type);
    end
    
    % 组合成标准化数据矩阵
    paired_data{i} = [ret_data, obv_data];
    
    % 进度显示
    if verbose && mod(i, 20) == 0
        fprintf('   已处理 %d/%d\n', i, n_pairs);
    end
end

if verbose
    fprintf('   数据标准化完成。\n\n');
end

%% 5. 构建完整的配对信息结构体
pair_info = struct();
% 原始变量信息
pair_info.var_names = var_names;
pair_info.data_dimensions = [n_samples, n_vars];

% 分类变量信息
pair_info.ret_vars = ret_vars;
pair_info.obv_vars = obv_vars;
pair_info.ret_periods = ret_periods;
pair_info.obv_periods = obv_periods;
pair_info.ret_indices = ret_indices;
pair_info.obv_indices = obv_indices;

% 配对信息
pair_info.pairs = all_pairs';
pair_info.pair_types = all_pair_types';
pair_info.pair_descriptions = all_descriptions';
pair_info.pair_indices = all_indices;
pair_info.total_pairs = n_pairs;

% 分析参数
pair_info.analysis_type = analysis_type;
pair_info.min_period_gap = min_gap;
pair_info.creation_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');

% 数据质量统计
missing_data = any(cellfun(@(x) any(isnan(x(:))), paired_data));
pair_info.data_summary.has_missing = missing_data;
if missing_data
    missing_percent = mean(cellfun(@(x) sum(isnan(x(:)))/numel(x), paired_data)) * 100;
    pair_info.data_summary.missing_percentage = missing_percent;
else
    pair_info.data_summary.missing_percentage = 0;
end
pair_info.data_summary.n_samples = n_samples;

%% 6. 显示最终摘要
if verbose
    display_final_summary(pair_info, all_pairs);
end

fprintf('? 价量配对完成！\n');
fprintf('   输出 paired_data: %d×1 元胞数组，每个元素为 %d×2 矩阵\n', ...
    n_pairs, n_samples);
fprintf('   输出 pair_info: 包含 %d 个字段的结构体\n', length(fieldnames(pair_info)));
fprintf('========================================\n\n');

end

%% ==================== 内部辅助函数 ====================

function [vars, periods, indices] = extract_variables_by_pattern(var_names, pattern)
% 从变量名列表中提取匹配指定模式的所有变量
% 输入:
%   var_names: 变量名元胞数组
%   pattern: 要匹配的前缀模式 (如 'ret_')
% 输出:
%   vars: 匹配的变量名列表
%   periods: 从变量名中提取的周期数值
%   indices: 在原始 var_names 中的索引位置
    
    vars = {};
    periods = [];
    indices = [];
    
    for i = 1:length(var_names)
        var_name = var_names{i};
        
        % 检查是否以指定模式开头
        if startsWith(var_name, pattern)
            % 提取模式后的数字部分
            num_str = regexp(var_name, '\d+', 'match');
            
            if ~isempty(num_str)
                % 转换为数值
                period = str2double(num_str{1});
                
                % 存储结果
                vars{end+1} = var_name;
                periods(end+1) = period;
                indices(end+1) = i;
            end
        end
    end
    
    % 按周期从小到大排序
    if ~isempty(periods)
        [periods, sort_idx] = sort(periods);
        vars = vars(sort_idx);
        indices = indices(sort_idx);
    end
end

function [pairs, types, descs, idxs] = generate_all_relationships(...
    ret_vars, ret_periods, ret_idx, obv_vars, obv_periods, obv_idx, min_gap, verbose)
% 生成全部6种关系类型
    
    pairs = {};
    types = {};
    descs = {};
    idxs = [];
    
    % 1. 同期价导量 (ret_X -> OBV_WMA_X)
    if verbose, fprintf('   1. 同期价导量:'); end
    n_added = 0;
    for i = 1:min(length(ret_vars), length(obv_vars))
        pairs{end+1} = {ret_vars{i}, obv_vars{i}};
        types{end+1} = 'price_to_volume_sync';
        descs{end+1} = sprintf('%d天价→%d天量', ret_periods(i), obv_periods(i));
        idxs(end+1, :) = [ret_idx(i), obv_idx(i)];
        n_added = n_added + 1;
    end
    if verbose, fprintf(' %d 个\n', n_added); end
    
    % 2. 同期量导价 (OBV_WMA_X -> ret_X)
    if verbose, fprintf('   2. 同期量导价:'); end
    n_added = 0;
    for i = 1:min(length(obv_vars), length(ret_vars))
        pairs{end+1} = {obv_vars{i}, ret_vars{i}};
        types{end+1} = 'volume_to_price_sync';
        descs{end+1} = sprintf('%d天量→%d天价', obv_periods(i), ret_periods(i));
        idxs(end+1, :) = [obv_idx(i), ret_idx(i)];
        n_added = n_added + 1;
    end
    if verbose, fprintf(' %d 个\n', n_added); end
    
    % 3. 价格传导 (ret_短 -> ret_长)
    if verbose, fprintf('   3. 价格传导:'); end
    n_added = 0;
    for i = 1:length(ret_vars)-1
        for j = i+1:length(ret_vars)
            if ret_periods(j) - ret_periods(i) >= min_gap
                pairs{end+1} = {ret_vars{i}, ret_vars{j}};
                types{end+1} = 'price_conduction';
                descs{end+1} = sprintf('%d天价→%d天价', ret_periods(i), ret_periods(j));
                idxs(end+1, :) = [ret_idx(i), ret_idx(j)];
                n_added = n_added + 1;
            end
        end
    end
    if verbose, fprintf(' %d 个\n', n_added); end
    
    % 4. 成交量传导 (OBV_短 -> OBV_长)
    if verbose, fprintf('   4. 成交量传导:'); end
    n_added = 0;
    for i = 1:length(obv_vars)-1
        for j = i+1:length(obv_vars)
            if obv_periods(j) - obv_periods(i) >= min_gap
                pairs{end+1} = {obv_vars{i}, obv_vars{j}};
                types{end+1} = 'volume_conduction';
                descs{end+1} = sprintf('%d天量→%d天量', obv_periods(i), obv_periods(j));
                idxs(end+1, :) = [obv_idx(i), obv_idx(j)];
                n_added = n_added + 1;
            end
        end
    end
    if verbose, fprintf(' %d 个\n', n_added); end
    
    % 5. 价导量传导 (ret_短 -> OBV_长)
    if verbose, fprintf('   5. 价导量传导:'); end
    n_added = 0;
    for i = 1:length(ret_vars)
        for j = 1:length(obv_vars)
            if obv_periods(j) > ret_periods(i) && (obv_periods(j) - ret_periods(i) >= min_gap)
                pairs{end+1} = {ret_vars{i}, obv_vars{j}};
                types{end+1} = 'price_to_volume_conduction';
                descs{end+1} = sprintf('%d天价→%d天量', ret_periods(i), obv_periods(j));
                idxs(end+1, :) = [ret_idx(i), obv_idx(j)];
                n_added = n_added + 1;
            end
        end
    end
    if verbose, fprintf(' %d 个\n', n_added); end
    
    % 6. 量导价传导 (OBV_短 -> ret_长)
    if verbose, fprintf('   6. 量导价传导:'); end
    n_added = 0;
    for i = 1:length(obv_vars)
        for j = 1:length(ret_vars)
            if ret_periods(j) > obv_periods(i) && (ret_periods(j) - obv_periods(i) >= min_gap)
                pairs{end+1} = {obv_vars{i}, ret_vars{j}};
                types{end+1} = 'volume_to_price_conduction';
                descs{end+1} = sprintf('%d天量→%d天价', obv_periods(i), ret_periods(j));
                idxs(end+1, :) = [obv_idx(i), ret_idx(j)];
                n_added = n_added + 1;
            end
        end
    end
    if verbose, fprintf(' %d 个\n', n_added); end
end

function [pairs, types, descs, idxs] = generate_sync_relationships(...
    ret_vars, ret_periods, ret_idx, obv_vars, obv_periods, obv_idx, verbose)
% 只生成同期关系
    
    pairs = {};
    types = {};
    descs = {};
    idxs = [];
    
    n_pairs = min(length(ret_vars), length(obv_vars));
    
    % 1. 同期价导量
    if verbose, fprintf('   1. 同期价导量:'); end
    for i = 1:n_pairs
        pairs{end+1} = {ret_vars{i}, obv_vars{i}};
        types{end+1} = 'price_to_volume_sync';
        descs{end+1} = sprintf('%d天价→%d天量', ret_periods(i), obv_periods(i));
        idxs(end+1, :) = [ret_idx(i), obv_idx(i)];
    end
    if verbose, fprintf(' %d 个\n', length(pairs)); end
    
    % 2. 同期量导价
    if verbose, fprintf('   2. 同期量导价:'); end
    start_idx = length(pairs) + 1;
    for i = 1:n_pairs
        pairs{end+1} = {obv_vars{i}, ret_vars{i}};
        types{end+1} = 'volume_to_price_sync';
        descs{end+1} = sprintf('%d天量→%d天价', obv_periods(i), ret_periods(i));
        idxs(end+1, :) = [obv_idx(i), ret_idx(i)];
    end
    if verbose, fprintf(' %d 个\n', length(pairs)-start_idx+1); end
end

function [pairs, types, descs, idxs] = generate_conduction_relationships(...
    ret_vars, ret_periods, ret_idx, obv_vars, obv_periods, obv_idx, min_gap, verbose)
% 只生成跨期传导关系
    
    pairs = {};
    types = {};
    descs = {};
    idxs = [];
    
    % 3. 价格传导
    if verbose, fprintf('   1. 价格传导:'); end
    n_added = 0;
    for i = 1:length(ret_vars)-1
        for j = i+1:length(ret_vars)
            if ret_periods(j) - ret_periods(i) >= min_gap
                pairs{end+1} = {ret_vars{i}, ret_vars{j}};
                types{end+1} = 'price_conduction';
                descs{end+1} = sprintf('%d天价→%d天价', ret_periods(i), ret_periods(j));
                idxs(end+1, :) = [ret_idx(i), ret_idx(j)];
                n_added = n_added + 1;
            end
        end
    end
    if verbose, fprintf(' %d 个\n', n_added); end
    
    % 4. 成交量传导
    if verbose, fprintf('   2. 成交量传导:'); end
    n_added = 0;
    for i = 1:length(obv_vars)-1
        for j = i+1:length(obv_vars)
            if obv_periods(j) - obv_periods(i) >= min_gap
                pairs{end+1} = {obv_vars{i}, obv_vars{j}};
                types{end+1} = 'volume_conduction';
                descs{end+1} = sprintf('%d天量→%d天量', obv_periods(i), obv_periods(j));
                idxs(end+1, :) = [obv_idx(i), obv_idx(j)];
                n_added = n_added + 1;
            end
        end
    end
    if verbose, fprintf(' %d 个\n', n_added); end
    
    % 5. 价导量传导
    if verbose, fprintf('   3. 价导量传导:'); end
    n_added = 0;
    for i = 1:length(ret_vars)
        for j = 1:length(obv_vars)
            if obv_periods(j) > ret_periods(i) && (obv_periods(j) - ret_periods(i) >= min_gap)
                pairs{end+1} = {ret_vars{i}, obv_vars{j}};
                types{end+1} = 'price_to_volume_conduction';
                descs{end+1} = sprintf('%d天价→%d天量', ret_periods(i), obv_periods(j));
                idxs(end+1, :) = [ret_idx(i), obv_idx(j)];
                n_added = n_added + 1;
            end
        end
    end
    if verbose, fprintf(' %d 个\n', n_added); end
    
    % 6. 量导价传导
    if verbose, fprintf('   4. 量导价传导:'); end
    n_added = 0;
    for i = 1:length(obv_vars)
        for j = 1:length(ret_vars)
            if ret_periods(j) > obv_periods(i) && (ret_periods(j) - obv_periods(i) >= min_gap)
                pairs{end+1} = {obv_vars{i}, ret_vars{j}};
                types{end+1} = 'volume_to_price_conduction';
                descs{end+1} = sprintf('%d天量→%d天价', obv_periods(i), ret_periods(j));
                idxs(end+1, :) = [obv_idx(i), ret_idx(j)];
                n_added = n_added + 1;
            end
        end
    end
    if verbose, fprintf(' %d 个\n', n_added); end
end

function display_final_summary(pair_info, all_pairs)
% 显示最终汇总信息
    
    fprintf('\n----------------------------------------\n');
    fprintf('? 配对生成摘要\n');
    fprintf('----------------------------------------\n');
    fprintf('总配对数量: %d\n\n', pair_info.total_pairs);
    
    % 统计各类型数量
    unique_types = unique(pair_info.pair_types);
    type_counts = zeros(length(unique_types), 1);
    for i = 1:length(unique_types)
        type_counts(i) = sum(strcmp(pair_info.pair_types, unique_types{i}));
    end
    
    fprintf('各类型配对统计:\n');
    for i = 1:length(unique_types)
        fprintf('  %-25s: %d 个\n', unique_types{i}, type_counts(i));
    end
    fprintf('  %-25s: %d 个\n', '总计', pair_info.total_pairs);
    fprintf('\n');
    
    % 显示前几个配对的示例
    fprintf('配对示例 (前%d个):\n', min(5, length(all_pairs)));
    for i = 1:min(5, length(all_pairs))
        fprintf('  %3d. %s → %s (%s)\n', i, ...
            all_pairs{i}{1}, all_pairs{i}{2}, pair_info.pair_types{i});
    end
    if length(all_pairs) > 5
        fprintf('  ... 还有 %d 个配对\n', length(all_pairs)-5);
    end
    
    fprintf('\n数据信息:\n');
    fprintf('  样本数量: %d\n', pair_info.data_summary.n_samples);
    fprintf('  缺失数据: %s', bool2str(pair_info.data_summary.has_missing));
    if pair_info.data_summary.has_missing
        fprintf(' (%.2f%%)\n', pair_info.data_summary.missing_percentage);
    else
        fprintf('\n');
    end
    fprintf('  创建时间: %s\n', pair_info.creation_time);
    fprintf('----------------------------------------\n\n');
end

function str = bool2str(bool_val)
% 逻辑值转字符串
    if bool_val
        str = '是';
    else
        str = '否';
    end
end

function label_clean = clean_node_label(label)
% 清理单个节点标签
% 移除非ASCII字符、控制字符、乱码

    if isempty(label) || ~ischar(label)
        label_clean = label;
        return;
    end
    
    % 移除非ASCII字符 (ASCII 32-126 是可打印字符)
    label_clean = regexprep(label, '[^\x20-\x7E]', '');
    
    % 移除控制字符
    label_clean = regexprep(label_clean, '[\x00-\x1F\x7F]', '');
    
    % 移除多余空格
    label_clean = strtrim(label_clean);
    
    % 如果清理后为空，返回原始标签
    if isempty(label_clean)
        label_clean = label;
    end
end

function labels_clean = clean_node_labels(labels)
% 清理节点标签数组
% 输入: labels - 字符串元胞数组
% 输出: labels_clean - 清理后的标签数组

    if isempty(labels)
        labels_clean = labels;
        return;
    end
    
    if ischar(labels)
        % 如果是单个字符串
        labels_clean = {clean_node_label(labels)};
    else
        % 如果是元胞数组
        labels_clean = cell(size(labels));
        for i = 1:length(labels)
            if ischar(labels{i})
                labels_clean{i} = clean_node_label(labels{i});
            else
                labels_clean{i} = labels{i};
            end
        end
    end
end