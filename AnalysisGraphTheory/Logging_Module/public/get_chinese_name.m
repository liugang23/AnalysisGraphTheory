function chinese_name = get_chinese_name(field_meaning, field_name)
% GET_CHINESE_NAME - 获取字段的中文名称
% 如果映射表中没有该字段，返回英文名称

    % 首先尝试直接查找（保持现有功能）
    if isfield(field_meaning, field_name)
        chinese_name = field_meaning.(field_name);
        return;
    end
    
    % 如果是嵌套字段名（包含点号），尝试转换
    if contains(field_name, '.')
        % 将点号转换为下划线
        flat_name = strrep(field_name, '.', '_');
        if isfield(field_meaning, flat_name)
            chinese_name = field_meaning.(flat_name);
            return;
        end
        
        % 尝试只取最后一部分
        parts = strsplit(field_name, '.');
        last_part = parts{end};
        if isfield(field_meaning, last_part)
            chinese_name = field_meaning.(last_part);
            return;
        end
    end
    
    % 都找不到，返回原字段名
    chinese_name = field_name;

%    if isfield(field_meaning, field_name)
%        chinese_name = field_meaning.(field_name);
%    else
%        chinese_name = field_name;
%    end
end