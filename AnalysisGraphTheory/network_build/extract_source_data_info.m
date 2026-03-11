function source_info = extract_source_data_info(pairwise_results)
% EXTRACT_SOURCE_DATA_INFO 从连通性分析结果中提取源数据信息
%
% 功能: 自动提取用于网络验证的源数据信息
%
% 输入: pairwise_results - 连通性分析结果
% 输出: source_info - 源数据信息结构体

    source_info = struct();
    
    % 检查输入
    if ~isstruct(pairwise_results) || ~isfield(pairwise_results, 'pair_info')
        error('无效的输入: pairwise_results必须包含pair_info字段');
    end
    
    n_pairs = length(pairwise_results.pair_info);
    if n_pairs == 0
        error('pairwise_results.pair_info为空');
    end
    
    % 1. 提取所有唯一变量名
    all_var_names = {};
    for i = 1:n_pairs
        pair_info = pairwise_results.pair_info{i};
        
        if isempty(pair_info) || ~isstruct(pair_info)
            continue;
        end
        
        % 提取收益率变量
        if isfield(pair_info, 'ret_name')
            ret_name = pair_info.ret_name;
            if ischar(ret_name) && ~isempty(ret_name) && ~ismember(ret_name, all_var_names)
                all_var_names{end+1} = ret_name;
            end
        end
        
        % 提取成交量变量
        if isfield(pair_info, 'obv_name')
            obv_name = pair_info.obv_name;
            if ischar(obv_name) && ~isempty(obv_name) && ~ismember(obv_name, all_var_names)
                all_var_names{end+1} = obv_name;
            end
        end
    end
    
    % 2. 去重和排序
    all_var_names = unique(all_var_names);
    
    % 3. 设置源数据信息
    source_info.n_nodes_expected = length(all_var_names);
    source_info.var_names = all_var_names;
    source_info.extraction_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    source_info.n_pairs_processed = n_pairs;
    source_info.n_unique_vars = length(all_var_names);
    
    % 4. 统计信息
    source_info.extraction_stats = struct();
    source_info.extraction_stats.total_pairs = n_pairs;
    source_info.extraction_stats.unique_variables = length(all_var_names);
    
    fprintf('源数据信息提取完成:\n');
    fprintf('  配对数量: %d\n', n_pairs);
    fprintf('  唯一变量数: %d\n', length(all_var_names));
    fprintf('  期望节点数: %d\n', source_info.n_nodes_expected);
    
    % 5. 显示前几个变量
    if length(all_var_names) > 0
        fprintf('  变量示例: %s\n', strjoin(all_var_names(1:min(5, length(all_var_names))), ', '));
        if length(all_var_names) > 5
            fprintf('  ... 还有 %d 个变量\n', length(all_var_names)-5);
        end
    end
end