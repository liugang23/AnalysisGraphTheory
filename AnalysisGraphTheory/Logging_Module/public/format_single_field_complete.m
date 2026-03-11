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