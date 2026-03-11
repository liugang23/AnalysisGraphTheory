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
% 格式化 compute_stats 的一个组

    NEWLINE = get_newline();
    
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
        
        field_value = group_data.(field_name);
        
        % 使用通用格式化函数
        field_str = format_single_field_complete(field_name, chinese_name, field_value);
        content = [content, field_str];
    end
end