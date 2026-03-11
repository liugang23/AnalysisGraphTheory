function [log_content, log_header] = process_network_build(func_filename, data, data_type, stock_name)
% PROCESS_NETWORK_BUILD - 处理网络构建模块的日志记录
% 输入：
%   func_filename - 函数文件名
%   data - 要记录的数据
%   data_type - 数据类型（'input_params', 'calc_process', 'calc_result'）
%   stock_name - 股票名称
% 输出：
%   log_content - 日志内容
%   log_header - 日志头部信息

    % 获取时间戳
    timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
    NEWLINE = get_newline();
    
    % 构建日志头
    log_header = sprintf('【网络构建】%s %s', timestamp, func_filename);
    if ~isempty(stock_name) && ~strcmp(stock_name, 'all_stocks')
        log_header = sprintf('%s 股票:%s', log_header, stock_name);
    end
    
    % 根据数据类型分发处理
    switch data_type
        case 'input_params'
            log_content = format_network_input_complete(data);
            
        case 'calc_process'
            log_content = format_network_process(data, func_filename);
            
        case 'calc_result'
            log_content = format_network_result_complete(data);
            
        otherwise
            log_content = sprintf('未知数据类型: %s%s', data_type, NEWLINE);
            log_content = [log_content, '原始数据: ', jsonencode(data), NEWLINE];
    end
    
    % 确保log_content是行向量
    if ~ischar(log_content)
        log_content = char(log_content);
    end
    if size(log_content, 1) > 1
        log_content = log_content(:)';
    end
end

function content = format_network_input_complete(data)
% FORMAT_NETWORK_INPUT_COMPLETE - 完整格式化网络构建的输入参数
% 修改：完整显示所有数据，不省略任何内容

    NEWLINE = get_newline();
    
    % 1. 初始化：使用 cell 数组来收集每一行的内容
    lines = {}; 
    idx = 1; % 索引计数器
    lines{idx} = ['网络构建输入参数详情:', NEWLINE];
    idx = idx + 1;

    % 检查输入数据是否为结构体
    if ~isstruct(data)
        lines{idx} = sprintf('输入参数格式错误: 预期为结构体，实际为 %s', class(data));
        idx = idx + 1;
        content = strjoin(lines, NEWLINE);
        return;
    end
    
    try
        % 2. 检查 data 是否包含 parameters 字段
        if isfield(data, 'parameters')
            lines{idx} = ['=== 配对分析参数 (来自 pairwise_results.parameters) ===', NEWLINE];
            idx = idx + 1;

            params = data.parameters;
            if isstruct(params)
                % 获取字段含义映射
                field_meaning = get_network_field_meanings('input_params');

                % 获取所有参数字段
                param_fields = fieldnames(params);
                
                for i = 1:length(param_fields)
                    field_name = param_fields{i};
                    chinese_name = get_chinese_name(field_meaning, field_name);
                    field_value = params.(field_name);
                    
                    % 使用新的完整格式化函数
                    field_str = format_single_field_complete(field_name, chinese_name, field_value);
                    if ~isempty(field_str)
                        lines{idx} = field_str;
                        idx = idx + 1;
                    end
                end
            end
        end

        % 3. 处理主结构体的其他关键字段
        lines{idx} = ['=== 配对结果数据结构 ===', NEWLINE];
        idx = idx + 1;

        % 检查主结构体的关键字段
        if isfield(data, 'pair_info')
            n_pairs = length(data.pair_info);
            lines{idx} = format_single_field_complete('n_pairs', '配对数', n_pairs);
            idx = idx + 1;
        end

        % 获取主结构体的所有字段
        all_fields = fieldnames(data);
        for i = 1:length(all_fields)
            field_name = all_fields{i};

            % 跳过已处理的 parameters 字段
            if strcmp(field_name, 'parameters')
                continue;
            end

            % 跳过 pair_info（已单独处理）
            if strcmp(field_name, 'pair_info')
                continue;
            end

            % 获取字段含义
            chinese_name = get_chinese_name(field_meaning, field_name);
            if isempty(chinese_name)
                chinese_name = field_name;
            end

            field_value = data.(field_name);
            
            % 使用新的完整格式化函数
            field_str = format_single_field_complete(field_name, chinese_name, field_value);
            if ~isempty(field_str)
                lines{idx} = field_str;
                idx = idx + 1;
            end
        end

        % 4. 添加统计信息
        lines{idx} = ['=== 数据统计 ===', NEWLINE];
        idx = idx + 1;

        if isfield(data, 'connectivity')
            conn_values = data.connectivity;
            valid_count = 0;
            if ~isempty(conn_values) && iscell(conn_values)
                for k = 1:numel(conn_values)
                    if ~isempty(conn_values{k}) && isnumeric(conn_values{k}) && ~isnan(conn_values{k})
                        valid_count = valid_count + 1;
                    end
                end
            end
            lines{idx} = sprintf(' 有效连接数: %d', valid_count);
            idx = idx + 1;
        end

        if isfield(data, 'significance')
            sig_values = data.significance;
            sig_count = 0;
            if ~isempty(sig_values) && iscell(sig_values)
                for k = 1:numel(sig_values)
                    if ~isempty(sig_values{k}) && sig_values{k} < 0.05
                        sig_count = sig_count + 1;
                    end
                end
            end
            lines{idx} = sprintf(' 显著连接数(p<0.05): %d', sig_count);
            idx = idx + 1;
        end

        content = strjoin(lines);
        
    catch ME
        fprintf('网络构建日志 输入 失败: %s\n', ME.message);
        lines{idx} = sprintf('格式化过程出错: %s', ME.message);
        content = join(lines, NEWLINE);
    end
end

function content = format_network_result_complete(data)
% FORMAT_NETWORK_RESULT_COMPLETE - 完整格式化网络构建模块的计算结果
% 修改：完整显示所有数据，不省略任何内容

    NEWLINE = get_newline();
    
    % 获取字段含义映射
    field_meaning = get_network_field_meanings('calc_result');
    
    % 构建内容开头
    content = ['网络构建结果详情:', NEWLINE];
    
    try
        % 1. 基础网络属性
        content = [content, '--- 网络基础属性 ---', NEWLINE];
        basic_fields = {'analysis_type', 'alpha', 'n_nodes', 'n_edges', ...
                        'density', 'clustering_coefficient', 'average_path_length', ...
                        'diameter', 'is_directed', 'is_weighted', 'graph_type'};
        content = format_field_group_complete(data, field_meaning, basic_fields, content);
        
        % 2. 标签信息
        content = [content, '--- 节点标签信息 ---', NEWLINE];
        label_fields = {'node_labels', 'ret_node_labels', 'obv_node_labels'};
        content = format_field_group_complete(data, field_meaning, label_fields, content);
        
        % 3. 核心矩阵信息
        content = [content, '--- 核心矩阵信息 ---', NEWLINE];
        matrix_fields = {'adjacency', 'weights', 'significance', 'directions', 'lags'};
        for i = 1:length(matrix_fields)
            field_name = matrix_fields{i};
            if isfield(data, field_name) && ~isempty(data.(field_name))
                chinese_name = get_chinese_name(field_meaning, field_name);
                matrix_str = format_matrix_field_complete(field_name, chinese_name, data.(field_name), false);
                content = [content, matrix_str, NEWLINE];
            end
        end
        
        % 4. 节点统计信息
        content = [content, '--- 节点统计信息 ---', NEWLINE];
        node_fields = {'node_degrees', 'weighted_degrees', 'degree_centrality', ...
                       'closeness_centrality', 'betweenness_centrality', ...
                       'eigenvector_centrality', 'clustering_coefficients', ...
                       'node_betweenness', 'node_closeness'};
        content = format_field_group_complete(data, field_meaning, node_fields, content);
        
        % 5. 高级网络统计
        content = [content, '--- 高级网络统计 ---', NEWLINE];
        advanced_fields = {'modularity', 'assortativity', 'small_worldness', ...
                           'degree_stats', 'weighted_degree_stats'};
        content = format_field_group_complete(data, field_meaning, advanced_fields, content);
        
        % 6. 边信息
        content = [content, '--- 边信息 ---', NEWLINE];
        edge_fields = {'edge_list', 'n_edges_in_list'};
        content = format_field_group_complete(data, field_meaning, edge_fields, content);
        
        % 7. 元信息
        content = [content, '--- 元信息 ---', NEWLINE];
        meta_fields = {'network_id', 'version', 'creation_time', ...
                       'timestamps', 'validation_summary'};
        content = format_field_group_complete(data, field_meaning, meta_fields, content);
        
        % 8. 处理统计信息
        if isfield(data, 'processing_stats')
            chinese_name = get_chinese_name(field_meaning, 'processing_stats');
            stats_str = format_processing_stats_complete('processing_stats', chinese_name, data.processing_stats);
            content = [content, stats_str, NEWLINE];
        end
        
    catch ME
        fprintf('网络构建日志 结果 失败: %s\n', ME.message);
        content = [content, sprintf('格式化过程出错: %s%s', ME.message, NEWLINE)];
    end
end

function str = format_single_field_complete(field_name, chinese_name, value)
% FORMAT_SINGLE_FIELD_COMPLETE - 完整格式化单个字段
% 修改：不省略任何内容，完整显示所有数据

    NEWLINE = get_newline();
    
    try
        if isempty(value)
            if strcmp(field_name, chinese_name)
                str = sprintf('  %s: 空%s', field_name, NEWLINE);
            else
                str = sprintf('  %s: %s: 空%s', field_name, chinese_name, NEWLINE);
            end
            return;
        end

        % 构建显示前缀 - 修复中文名称显示
        if strcmp(field_name, chinese_name)
            prefix = sprintf('  %s:', field_name);
        else
            prefix = sprintf('  %s: %s:', field_name, chinese_name);
        end

        % 1. 特殊处理：结构体元胞数组 - 完整显示
        if iscell(value) && ~isempty(value) && isstruct(value{1})
            str = [prefix, format_struct_cell_array_complete(value, field_name)];
            return;
        end
        
        % 2. 特殊处理：逻辑元胞数组 - 完整显示
        if iscell(value) && ~isempty(value) && all(cellfun(@(x) islogical(x) || isempty(x), value(:)))
            lines = cell(1, 20);  % 预分配行存储
            line_idx = 1;
            
            [rows, cols] = size(value);
            n_elements = numel(value);
            n_true = 0;
            n_false = 0;
            n_empty = 0;
            
            for i = 1:n_elements
                if isempty(value{i})
                    n_empty = n_empty + 1;
                elseif value{i}
                    n_true = n_true + 1;
                else
                    n_false = n_false + 1;
                end
            end
            
            lines{line_idx} = sprintf('%s %dx%d 逻辑元胞数组，共 %d 个元素 (真=%d, 假=%d, 空=%d)', ...
                          prefix, rows, cols, n_elements, n_true, n_false, n_empty);
            line_idx = line_idx + 1;
            
            lines{line_idx} = '  完整数据:';
            line_idx = line_idx + 1;
            
            for r = 1:rows
                % 1. 初始化一个元胞数组来存这一行的每一列内容
                row_cells = cell(1, cols + 1); % +1 是为了存前面的缩进
                col_idx = 1;
                
                % 先存缩进
                row_cells{col_idx} = '  ';
                col_idx = col_idx + 1;
                
                for c = 1:cols
                    idx = (r-1)*cols + c;
                    if idx <= n_elements
                        if isempty(value{r,c})
                            row_cells{col_idx} = '  N/A';
                        elseif value{r,c}
                            row_cells{col_idx} = '    1';
                        else
                            row_cells{col_idx} = '    0';
                        end
                        col_idx = col_idx + 1;
                    end
                end
                % 2. 一次性拼接成一行字符串
                % 注意：这里使用 strjoin，它比循环拼接快得多，且无警告
                lines{line_idx} = strjoin(row_cells, '');
                line_idx = line_idx + 1;
            end
            
            str = strjoin(lines(1:line_idx-1), NEWLINE);
            str = [str, NEWLINE];  % 添加换行符
            return;
        end
        
        % 3. 特殊处理：字符串元胞数组 - 完整显示
        if (iscellstr(value) || isstring(value))
            lines = cell(1, 100);  % 预分配行存储
            line_idx = 1;
            
            [rows, cols] = size(value);
            n_elements = numel(value);
            
            if isstring(value)
                display_array = cellstr(value);
            else
                display_array = value;
            end
            
            lines{line_idx} = sprintf('%s %dx%d 字符串元胞数组，共 %d 个元素:', prefix, rows, cols, n_elements);
            line_idx = line_idx + 1;
            
            for i = 1:n_elements
                element = display_array{i};
                [r, c] = ind2sub([rows, cols], i);
                if length(element) > 100
                    element = [element(1:97), '...'];
                end
                lines{line_idx} = sprintf('  [%d,%d]: "%s"', r, c, element);
                line_idx = line_idx + 1;
            end
            
            str = strjoin(lines(1:line_idx-1), NEWLINE);
            % 添加换行符
            str = [str, NEWLINE];
            return;
        end
        
        % 4. 特殊处理：数值元胞数组 - 完整显示
        if iscell(value) && ~isempty(value) && all(cellfun(@(x) isnumeric(x) || isempty(x), value(:)))
            lines = cell(1, 100);  % 预分配行存储
            line_idx = 1;
            
            [rows, cols] = size(value);
            n_elements = numel(value);
            
            lines{line_idx} = sprintf('%s %dx%d 数值元胞数组，共 %d 个元素:', prefix, rows, cols, n_elements);
            line_idx = line_idx + 1;
            
            for i = 1:n_elements
                element = value{i};
                [r, c] = ind2sub([rows, cols], i);
                
                if isempty(element)
                    lines{line_idx} = sprintf('  [%d,%d]: 空', r, c);
                elseif isnumeric(element)
                    [m, n] = size(element);
                    if isscalar(element)
                        if mod(element, 1) == 0
                            lines{line_idx} = sprintf('  [%d,%d]: 标量[%d]', r, c, element);
                        else
                            lines{line_idx} = sprintf('  [%d,%d]: 标量[%.6f]', r, c, element);
                        end
                    else
                        if m <= 3 && n <= 3
                            % 小矩阵直接显示
                            matrix_str = mat2str(element, 4);
                            if length(matrix_str) > 50
                                matrix_str = [matrix_str(1:47), '...'];
                            end
                            lines{line_idx} = sprintf('  [%d,%d]: %dx%d 矩阵 %s', r, c, m, n, matrix_str);
                        else
                            lines{line_idx} = sprintf('  [%d,%d]: %dx%d 矩阵 [最小值=%.4f, 最大值=%.4f]', ...
                                                r, c, m, n, min(element(:)), max(element(:)));
                        end
                    end
                end
                line_idx = line_idx + 1;
            end
            
            str = strjoin(lines(1:line_idx-1), NEWLINE);
            str = [str, NEWLINE];  % 添加换行符
            return;
        end
        
        % 5. 特殊处理：普通元胞数组 - 完整显示
        if iscell(value)
            lines = cell(1, 100);  % 预分配行存储
            line_idx = 1;
            
            [rows, cols] = size(value);
            n_elements = numel(value);
            
            lines{line_idx} = sprintf('%s %dx%d 元胞数组，共 %d 个元素，元素类型: %s', ...
                          prefix, rows, cols, n_elements, class(value{1}));
            line_idx = line_idx + 1;
            
            for i = 1:n_elements
                element = value{i};
                [r, c] = ind2sub([rows, cols], i);
                
                if isempty(element)
                    lines{line_idx} = sprintf('  [%d,%d]: 空', r, c);
                elseif ischar(element)
                    if length(element) > 50
                        element = [element(1:47), '...'];
                    end
                    lines{line_idx} = sprintf('  [%d,%d]: 字符串["%s"]', r, c, element);
                elseif isnumeric(element)
                    [m, n] = size(element);
                    if isscalar(element)
                        lines{line_idx} = sprintf('  [%d,%d]: 数值[%.4f]', r, c, element);
                    else
                        lines{line_idx} = sprintf('  [%d,%d]: %dx%d 数值矩阵', r, c, m, n);
                    end
                elseif isstruct(element)
                    fnames = fieldnames(element);
                    lines{line_idx} = sprintf('  [%d,%d]: 结构体[%d个字段]', r, c, length(fnames));
                elseif iscell(element)
                    [m, n] = size(element);
                    lines{line_idx} = sprintf('  [%d,%d]: %dx%d 元胞数组', r, c, m, n);
                elseif islogical(element)
                    if element
                        lines{line_idx} = sprintf('  [%d,%d]: 逻辑真', r, c);
                    else
                        lines{line_idx} = sprintf('  [%d,%d]: 逻辑假', r, c);
                    end
                else
                    lines{line_idx} = sprintf('  [%d,%d]: [%s类型]', r, c, class(element));
                end
                line_idx = line_idx + 1;
            end
            
            str = strjoin(lines(1:line_idx-1), NEWLINE);
            str = [str, NEWLINE];  % 添加换行符
            return;
        end
        
        % 6. 处理基本类型
        if ischar(value)
            str = sprintf('%s %s%s', prefix, value, NEWLINE);
            
        elseif isnumeric(value) && isscalar(value)
            if mod(value, 1) == 0
                str = sprintf('%s %d%s', prefix, value, NEWLINE);
            else
                str = sprintf('%s %.6f%s', prefix, value, NEWLINE);
            end

        elseif islogical(value)
            if value
                str = sprintf('%s 是%s', prefix, NEWLINE);
            else
                str = sprintf('%s 否%s', prefix, NEWLINE);
            end

        elseif isstruct(value)
            % === 修改开始：使用元胞数组处理结构体 ===
            lines = cell(1, 100);  % 预分配100行
            line_idx = 1;
            
            lines{line_idx} = sprintf('%s 结构体', prefix);
            line_idx = line_idx + 1;
            
            % 处理结构体子字段
            field_names = fieldnames(value);
            for i = 1:numel(field_names)
                sub_field = field_names{i};
                sub_value = value.(sub_field);
                
                % 获取子字段的中文名
                sub_chinese_name = get_chinese_name(get_network_field_meanings('input_params'), sub_field);
                if strcmp(sub_field, sub_chinese_name)
                    sub_field_display = sub_field;
                else
                    sub_field_display = sprintf('%s: %s', sub_field, sub_chinese_name);
                end
                
                % 格式化子字段值
                if ischar(sub_value)
                    lines{line_idx} = sprintf('    - %s: %s', sub_field_display, sub_value);
                    
                elseif isnumeric(sub_value) && isscalar(sub_value)
                    if mod(sub_value, 1) == 0
                        lines{line_idx} = sprintf('    - %s: %d', sub_field_display, sub_value);
                    else
                        lines{line_idx} = sprintf('    - %s: %.6f', sub_field_display, sub_value);
                    end
                    
                elseif isnumeric(sub_value) && ~isscalar(sub_value)
                    [m, n] = size(sub_value);
                    if m == 0 || n == 0
                        lines{line_idx} = sprintf('    - %s: %dx%d 空矩阵', sub_field_display, m, n);
                    else
                        lines{line_idx} = sprintf('    - %s: %dx%d 矩阵', sub_field_display, m, n);
                    end
                    
                elseif islogical(sub_value)
                    if sub_value
                        lines{line_idx} = sprintf('    - %s: 是', sub_field_display);
                    else
                        lines{line_idx} = sprintf('    - %s: 否', sub_field_display);
                    end
                    
                elseif isstruct(sub_value)
                    sub_fields = fieldnames(sub_value);
                    lines{line_idx} = sprintf('    - %s: 结构体[%d个字段]', sub_field_display, numel(sub_fields));
                    
                elseif iscell(sub_value)
                    [m, n] = size(sub_value);
                    if isempty(sub_value)
                        lines{line_idx} = sprintf('    - %s: 空元胞数组', sub_field_display);
                    elseif isstruct(sub_value{1})
                        lines{line_idx} = sprintf('    - %s: 结构体元胞数组 %dx%d', sub_field_display, m, n);
                    else
                        lines{line_idx} = sprintf('    - %s: %dx%d 元胞数组', sub_field_display, m, n);
                    end
                    
                else
                    lines{line_idx} = sprintf('    - %s: [%s类型]', sub_field_display, class(sub_value));
                end
                line_idx = line_idx + 1;
            end
            
            % 一次性拼接所有行
            str = strjoin(lines(1:line_idx-1), NEWLINE);
            str = [str, NEWLINE];  % 添加末尾换行符
            % === 修改结束 ===

        elseif isnumeric(value) && ~isscalar(value)
            str = [format_matrix_field_complete(field_name, chinese_name, value, false), NEWLINE];

        else
            if strcmp(field_name, chinese_name)
                str = sprintf('  %s: [%s类型]%s', field_name, class(value), NEWLINE);
            else
                str = sprintf('  %s: %s: [%s类型]%s', field_name, chinese_name, class(value), NEWLINE);
            end
        end
        
    catch ME
        fprintf('网络构建日志 格式化单个字段 失败: %s\n', ME.message);
        if strcmp(field_name, chinese_name)
            str = sprintf('  %s: [格式化错误: %s]%s', field_name, ME.message, NEWLINE);
        else
            str = sprintf('  %s: %s: [格式化错误: %s]%s', field_name, chinese_name, ME.message, NEWLINE);
        end
    end
end

function str = format_struct_cell_array_complete(cell_array, field_name)
% FORMAT_STRUCT_CELL_ARRAY_COMPLETE - 完整显示结构体元胞数组的所有内容
% 不省略任何元素，不省略任何字段

    NEWLINE = get_newline();
    
    if isempty(cell_array)
        str = '空数组';
        return;
    end
    
    [rows, cols] = size(cell_array);
    n_elements = numel(cell_array);
    
    % 根据字段名决定显示名称
    switch field_name
        case 'connectivity'
            display_name = '连接强度';
        case 'lag_info'
            display_name = '滞后信息';
        case 'robustness'
            display_name = '稳健性测试';
        case 'edge_list'
            display_name = '边列表';
        case 'fingerprint_features'
            display_name = '指纹特征';
        case 'processing_stats'
            display_name = '处理统计';
        case 'timestamps'
            display_name = '时间戳';
        case 'validation_summary'
            display_name = '验证摘要';
        otherwise
            display_name = field_name;
    end
    
    str = sprintf('%s元胞数组: %dx%d 矩阵，共 %d 个元素', display_name, rows, cols, n_elements);
    str = [str, NEWLINE];
    
    % 检查第一个元素是否是结构体
    if ~isstruct(cell_array{1})
        str = [str, sprintf('第一个元素不是结构体，类型: %s', class(cell_array{1}))];
        return;
    end
    
    first_elem = cell_array{1};
    field_names = fieldnames(first_elem);
    n_fields = length(field_names);
    
    str = [str, sprintf('结构体包含 %d 个字段:', n_fields)];
    for i = 1:n_fields
        str = [str, sprintf('%s  [%d] %s', NEWLINE, i, field_names{i})];
    end
    str = [str, NEWLINE, NEWLINE];
    
    % 遍历并显示所有元素
    for elem_idx = 1:n_elements
        element = cell_array{elem_idx};
        [r, c] = ind2sub([rows, cols], elem_idx);
        
        str = [str, sprintf('===== 元素 [%d,%d] (索引 %d) =====', r, c, elem_idx), NEWLINE];
        
        % 显示结构体的所有字段
        for f_idx = 1:n_fields
            fname = field_names{f_idx};
            if isfield(element, fname)
                fvalue = element.(fname);
                value_str = format_value_for_display_complete(fvalue);
                str = [str, sprintf('  %-25s: %s%s', fname, value_str, NEWLINE)];
            else
                str = [str, sprintf('  %-25s: [字段不存在]%s', fname, NEWLINE)];
            end
        end
        
        % 添加元素间的分隔
        if elem_idx < n_elements
            str = [str, NEWLINE];
        end
    end
end

function str = format_value_for_display_complete(value)
% FORMAT_VALUE_FOR_DISPLAY_COMPLETE - 将任何类型的值完整格式化为可读字符串

    if ischar(value)
        str = sprintf('"%s"', value);
        
    elseif isstring(value)
        if isscalar(value)
            str = sprintf('"%s"', char(value));
        else
            str = sprintf('字符串数组 %s', mat2str(size(value)));
        end
        
    elseif isnumeric(value) && isscalar(value)
        if mod(value, 1) == 0
            str = sprintf('%d', value);
        else
            str = sprintf('%.6f', value);
        end
        
    elseif isnumeric(value) && ~isscalar(value)
        [m, n] = size(value);
        if m == 0 || n == 0
            str = sprintf('%dx%d 空矩阵', m, n);
        elseif m == 1 && n <= 5
            str = '[';
            for i = 1:n
                if mod(value(i), 1) == 0
                    str = [str, sprintf('%d ', value(i))];
                else
                    str = [str, sprintf('%.4f ', value(i))];
                end
            end
            str = [str(1:end-1), ']'];
        elseif m <= 3 && n <= 3
            str = '[';
            for i = 1:m
                for j = 1:n
                    if mod(value(i,j), 1) == 0
                        str = [str, sprintf('%d ', value(i,j))];
                    else
                        str = [str, sprintf('%.4f ', value(i,j))];
                    end
                end
                str = [str(1:end-1)];
                if i < m
                    str = [str, '; '];
                end
            end
            str = [str, ']'];
        else
            if ~isempty(value)
                str = sprintf('%dx%d 矩阵 [最小值=%.4f, 最大值=%.4f, 均值=%.4f, 标准差=%.4f]', ...
                             m, n, min(value(:)), max(value(:)), mean(value(:)), std(value(:)));
            else
                str = sprintf('%dx%d 空矩阵', m, n);
            end
        end
        
    elseif islogical(value)
        if isscalar(value)
            if value
                str = '真';
            else
                str = '假';
            end
        else
            [m, n] = size(value);
            n_true = sum(value(:));
            str = sprintf('%dx%d 逻辑矩阵 (真=%d, 假=%d)', m, n, n_true, m*n-n_true);
        end
        
    elseif isstruct(value)
        fnames = fieldnames(value);
        str = sprintf('结构体 (%d 个字段)', length(fnames));
        
    elseif iscell(value)
        [m, n] = size(value);
        if isempty(value)
            str = sprintf('%dx%d 空元胞数组', m, n);
        elseif isstruct(value{1})
            str = sprintf('%dx%d 结构体元胞数组', m, n);
        else
            str = sprintf('%dx%d 元胞数组 [%s]', m, n, class(value{1}));
        end
        
    else
        str = sprintf('[%s]', class(value));
    end
end

function str = format_matrix_field_complete(field_name, chinese_name, matrix_data, show_indices)
% FORMAT_MATRIX_FIELD_COMPLETE - 完整格式化矩阵字段
% 修改：完整显示矩阵内容

    NEWLINE = get_newline();
    
    [rows, cols] = size(matrix_data);
    
    if strcmp(field_name, chinese_name)
        prefix = sprintf('  %s:', field_name);
    else
        prefix = sprintf('  %s: %s:', field_name, chinese_name);
    end
    
    str = sprintf('%s %dx%d 矩阵', prefix, rows, cols);
    
    if rows <= 20 && cols <= 20
        % 小矩阵：完整显示
        str = [str, format_small_matrix_complete(matrix_data)];
    else
        % 大矩阵：显示统计摘要
        str = [str, format_matrix_summary_complete(matrix_data)];
    end
end

function str = format_small_matrix_complete(matrix)
% FORMAT_SMALL_MATRIX_COMPLETE - 完整格式化小矩阵
% 修改：改进数值显示

    NEWLINE = get_newline();
    
    [rows, cols] = size(matrix);
    if rows == 0 || cols == 0
        str = '  [空矩阵]';
        return;
    end
    
    str = NEWLINE;
    
    for r = 1:rows
        row_str = '    ';
        for c = 1:cols
            value = matrix(r,c);
            if isnumeric(value)
                if value == 0
                    row_str = [row_str, sprintf('%8.1f', 0)];
                else
                    if abs(value) >= 1000 || (abs(value) < 0.001 && value ~= 0)
                        row_str = [row_str, sprintf('%8.2e', value)];
                    elseif mod(value, 1) == 0
                        row_str = [row_str, sprintf('%8d', value)];
                    else
                        row_str = [row_str, sprintf('%8.4f', value)];
                    end
                end
            elseif islogical(value)
                if value
                    row_str = [row_str, '    真'];
                else
                    row_str = [row_str, '    假'];
                end
            else
                row_str = [row_str, '   N/A'];
            end
        end
        str = [str, row_str];
        if r < rows
            str = [str, NEWLINE];
        end
    end
end

function str = format_matrix_summary_complete(matrix)
% FORMAT_MATRIX_SUMMARY_COMPLETE - 完整格式化大矩阵的统计摘要

    NEWLINE = get_newline();
    
    [rows, cols] = size(matrix);
    non_zero = nnz(matrix);
    total_elements = rows * cols;
    
    str = sprintf('%s    总元素: %d', NEWLINE, total_elements);
    str = [str, sprintf('%s    非零元素: %d (%.1f%%)', NEWLINE, non_zero, 100*non_zero/total_elements)];
    
    if isnumeric(matrix)
        str = [str, sprintf('%s    最小值: %.6f', NEWLINE, min(matrix(:)))];
        str = [str, sprintf('%s    最大值: %.6f', NEWLINE, max(matrix(:)))];
        str = [str, sprintf('%s    平均值: %.6f', NEWLINE, mean(matrix(:)))];
        str = [str, sprintf('%s    标准差: %.6f', NEWLINE, std(matrix(:)))];
    end
end

function str = format_processing_stats_complete(field_name, chinese_name, stats)
% FORMAT_PROCESSING_STATS_COMPLETE - 完整格式化处理统计结构体
% 修改：显示所有字段

    NEWLINE = get_newline();
    
    if strcmp(field_name, chinese_name)
        prefix = sprintf('  %s:', field_name);
    else
        prefix = sprintf('  %s: %s:', field_name, chinese_name);
    end
    
    str = sprintf('%s 处理统计', prefix);
    
    if ~isstruct(stats)
        str = [str, sprintf('%s    [非结构体类型: %s]', NEWLINE, class(stats))];
        return;
    end
    
    % 获取所有字段
    field_names = fieldnames(stats);
    for i = 1:length(field_names)
        sub_field = field_names{i};
        sub_value = stats.(sub_field);
        
        if isnumeric(sub_value) && isscalar(sub_value)
            if mod(sub_value, 1) == 0
                val_str = sprintf('%d', sub_value);
            else
                val_str = sprintf('%.6f', sub_value);
            end
            str = [str, sprintf('%s    - %s: %s', NEWLINE, sub_field, val_str)];
        elseif ischar(sub_value)
            str = [str, sprintf('%s    - %s: %s', NEWLINE, sub_field, sub_value)];
        elseif isstruct(sub_value)
            sub_fields = fieldnames(sub_value);
            str = [str, sprintf('%s    - %s: 结构体[%d个字段]', NEWLINE, sub_field, numel(sub_fields))];
        elseif iscell(sub_value)
            [m, n] = size(sub_value);
            str = [str, sprintf('%s    - %s: %dx%d 元胞数组', NEWLINE, sub_field, m, n)];
        else
            str = [str, sprintf('%s    - %s: [%s]', NEWLINE, sub_field, class(sub_value))];
        end
    end
end

function content = format_field_group_complete(data, field_meaning, field_list, content)
% FORMAT_FIELD_GROUP_COMPLETE - 完整格式化一组字段
% 修改：使用完整格式化函数
    
    NEWLINE = get_newline();
    for i = 1:length(field_list)
        field_name = field_list{i};
        if isfield(data, field_name)
            chinese_name = get_chinese_name(field_meaning, field_name);
            field_value = data.(field_name);
            field_str = format_single_field_complete(field_name, chinese_name, field_value);
            content = [content, field_str, NEWLINE];
        end
    end
end

% ====================== 原有函数保留，但更新了部分调用 ======================

function content = format_network_process(data, func_filename)
% FORMAT_NETWORK_PROCESS - 格式化计算过程信息
% 修改：使用新的完整格式化函数

    NEWLINE = get_newline();
    % 1. 构建日志头
    content = [['计算过程 - ', func_filename], NEWLINE];
    
    % 获取字段含义映射
    field_meaning = get_network_field_meanings('calc_process', func_filename);
    
    switch func_filename
        case 'network_construction_core'
            content = format_network_construction_core_stats(data, field_meaning, content);
            
        case 'edge_processing_module'
            content = format_edge_processing_module(data, field_meaning, content);
            
        case 'network_statistics_calculator'
            content = format_network_statistics(data, field_meaning, content);
            
        otherwise
            % 通用的计算过程处理
            if isstruct(data)
                field_names = fieldnames(data);
                for i = 1:length(field_names)
                    field_name = field_names{i};
                    chinese_name = get_chinese_name(field_meaning, field_name);
                    field_value = data.(field_name);
                    content = [content, format_single_field_complete(field_name, chinese_name, field_value)];
                end
            end
    end
end

function content = format_network_construction_core_stats(compute_stats, field_meaning, content)
% FORMAT_NETWORK_CONSTRUCTION_CORE_STATS - 专门格式化 network_construction_core 的 compute_stats
% 输入：
%   compute_stats - 计算统计结构体
%   field_meaning - 字段含义映射
%   content - 已有的日志内容
% 输出：
%   content - 完整的格式化内容

    NEWLINE = get_newline();
    
    % 检查是否是 compute_stats 结构体
    if ~isstruct(compute_stats)
        content = [content, sprintf('错误: 输入数据不是有效的 compute_stats 结构体%s', NEWLINE)];
        return;
    end
    
    try
        % 定义 compute_stats 的结构分组
        groups = {
            'module_info',      '模块信息';
            'timings',          '计时统计';
            'validation',       '输入验证';
            'extraction',       '节点提取';
            'processing',       '节点处理';
            'mapping',          '节点映射';
            'matrix_init',      '矩阵初始化';
            'performance',      '性能统计';
            'summary',          '总体统计';
        };
        
        % 遍历所有分组
        for g_idx = 1:size(groups, 1)
            group_name = groups{g_idx, 1};
            group_label = groups{g_idx, 2};
            
            if isfield(compute_stats, group_name)
                % 添加分组标题
                content = [content, NEWLINE, '=== ', group_label, ' ===', NEWLINE];
                
                group_data = compute_stats.(group_name);
                
                if isstruct(group_data)
                    % 处理结构体组
                    content = format_compute_stats_group(group_data, group_name, field_meaning, content);
                elseif iscell(group_data)
                    % 处理元胞数组
                    [rows, cols] = size(group_data);
                    content = [content, sprintf('  %s: %dx%d 元胞数组%s', group_name, rows, cols, NEWLINE)];
                elseif isnumeric(group_data)
                    % 处理数值
                    if isscalar(group_data)
                        if mod(group_data, 1) == 0
                            content = [content, sprintf('  %s: %d%s', group_name, group_data, NEWLINE)];
                        else
                            content = [content, sprintf('  %s: %.6f%s', group_name, group_data, NEWLINE)];
                        end
                    else
                        [m, n] = size(group_data);
                        content = [content, sprintf('  %s: %dx%d 矩阵%s', group_name, m, n, NEWLINE)];
                    end
                elseif ischar(group_data)
                    % 处理字符串
                    content = [content, sprintf('  %s: %s%s', group_name, group_data, NEWLINE)];
                else
                    % 其他类型
                    content = [content, sprintf('  %s: [%s类型]%s', group_name, class(group_data), NEWLINE)];
                end
            end
        end
        
        % 添加未分组的其他字段
        all_fields = fieldnames(compute_stats);
        for i = 1:length(all_fields)
            field_name = all_fields{i};
            
            % 跳过已处理的分组
            is_grouped = false;
            for g_idx = 1:size(groups, 1)
                if strcmp(field_name, groups{g_idx, 1})
                    is_grouped = true;
                    break;
                end
            end
            
            if ~is_grouped
                % 处理未分组的字段
                chinese_name = get_chinese_name(field_meaning, field_name);
                field_value = compute_stats.(field_name);
                field_str = format_single_field_complete(field_name, chinese_name, field_value);
                content = [content, field_str, NEWLINE];
            end
        end
        
    catch ME
        content = [content, sprintf('格式化 compute_stats 出错: %s%s', ME.message, NEWLINE)];
    end
end

function content = format_compute_stats_group(group_data, group_prefix, field_meaning, content)
    NEWLINE = get_newline();
    
    % 检查 group_data 是否为空
    if isempty(group_data)
        content = [content, sprintf('  %s: 空结构体数组，无数据%s', group_prefix, NEWLINE)];
        return;
    end
    
    field_names = fieldnames(group_data);
    for i = 1:length(field_names)
        field_name = field_names{i};
        
        % 构建完整的字段名用于查找映射
        full_field_name = [group_prefix '_' field_name];
        
        % 获取中文描述
        chinese_name = get_chinese_name(field_meaning, field_name);
        if strcmp(chinese_name, field_name)
            % 如果找不到直接映射，尝试使用完整字段名
            chinese_name = get_chinese_name(field_meaning, full_field_name);
        end
        
        % 检查 group_data 是否为空
        if ~isempty(group_data)
            field_value = group_data.(field_name);
        else
            field_value = [];
        end
        
        % 使用通用格式化函数
        field_str = format_single_field_complete(field_name, chinese_name, field_value);
        content = [content, field_str];
    end
end


