% 这个脚本只识别，不翻译
function all_field_info = identify_fields_only(pairwise_results)
    fprintf('=== 字段识别报告 ===\n\n');
    
    data_fields = fieldnames(pairwise_results);
    all_field_info = struct();
    
    for i = 1:length(data_fields)
        field_name = data_fields{i};
        field_value = pairwise_results.(field_name);
        
        fprintf('【主字段 %d】%s\n', i, field_name);
        fprintf('   类型: %s\n', class(field_value));
        
        if iscell(field_value) && ~isempty(field_value) && isstruct(field_value{1})
            % 这是您关心的结构体元胞数组
            sample_struct = field_value{1};
            sub_fields = fieldnames(sample_struct);
            
            fprintf('   包含子字段数: %d\n', length(sub_fields));
            fprintf('   子字段名: ');
            for j = 1:length(sub_fields)
                fprintf('%s', sub_fields{j});
                if j < length(sub_fields)
                    fprintf(', ');
                end
            end
            fprintf('\n');
            
            % 记录详细信息
            all_field_info.(field_name).type = '结构体元胞数组';
            all_field_info.(field_name).sample_subfields = sub_fields;
            all_field_info.(field_name).total_elements = numel(field_value);
        end
    end
    
    fprintf('\n=== 识别完成，请检查以上字段列表 ===\n');
end