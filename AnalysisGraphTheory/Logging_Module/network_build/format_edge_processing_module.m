function content = format_edge_processing_module(data, field_meaning, content)
% FORMAT_EDGE_PROCESSING_MODULE - 格式化边处理模块的计算过程信息
% 输入：
%   data - processing_stats结构体，包含完整计算过程数据
%   field_meaning - 字段含义映射
%   content - 已有的日志内容
% 输出：
%   content - 完整的格式化内容

    NEWLINE = get_newline();
    
    try
        % 1. 检查数据结构
        if ~isstruct(data)
            content = [content, sprintf('错误: edge_processing_module 数据不是有效的结构体%s', NEWLINE)];
            return;
        end
        
        % 2. 按数据结构顺序格式化各组数据
        content = format_edge_processing_section('模块元信息', 'module_metadata', data, field_meaning, content);
        content = [content, NEWLINE];
        
        content = format_edge_processing_section('输入参数配置', 'parameters', data, field_meaning, content);
        content = [content, NEWLINE];
        
        % 3. 性能统计
        if isfield(data, 'performance')
            content = [content, '=== 性能统计 ===', NEWLINE];
            performance_data = data.performance;
            
            % 基本性能指标
            if isfield(performance_data, 'total_time')
                content = [content, sprintf('  总处理时间: %.4f 秒%s', performance_data.total_time, NEWLINE)];
            end
            if isfield(performance_data, 'pairs_per_second')
                content = [content, sprintf('  处理速度: %.2f 配对/秒%s', performance_data.pairs_per_second, NEWLINE)];
            end
            if isfield(performance_data, 'edges_per_second')
                content = [content, sprintf('  边添加速度: %.2f 边/秒%s', performance_data.edges_per_second, NEWLINE)];
            end
            % 添加调试信息
            if isfield(performance_data, 'debug_info')
                content = [content, '  调试信息:', NEWLINE];
                debug_info = performance_data.debug_info;
                
                if isfield(debug_info, 'validation_failures')
                    content = [content, sprintf('    验证失败数: %d%s', debug_info.validation_failures, NEWLINE)];
                end
                if isfield(debug_info, 'successful_pairs')
                    content = [content, sprintf('    成功配对: %d%s', debug_info.successful_pairs, NEWLINE)];
                end
            end
        end
        content = [content, NEWLINE];
        
        % 4. 摘要统计
        if isfield(data, 'summary_stats')
            content = [content, '=== 处理摘要统计 ===', NEWLINE];
            content = format_summary_stats_section(data.summary_stats, field_meaning, content);
        end
        content = [content, NEWLINE];
        
        % 5. 详细计算记录（如果有的话）
        if isfield(data, 'detailed_calculation') && ~isempty(data.detailed_calculation)
            content = format_detailed_calculation_section(data.detailed_calculation, field_meaning, content);
        end
        
        % 6. 冲突记录
        content = [content, NEWLINE, '=== 权重冲突记录 ===', NEWLINE];
        
        % 显示冲突统计
        if isfield(data.summary_stats, 'weight_conflicts_recorded')
            content = [content, sprintf('  总冲突数: %d%s', data.summary_stats.weight_conflicts_recorded, NEWLINE)];
        end
        if isfield(data.summary_stats, 'weight_conflicts_resolved')
            content = [content, sprintf('  已解决冲突: %d%s', data.summary_stats.weight_conflicts_resolved, NEWLINE)];
        end
        
        % 显示冲突解决方法
        if isfield(data.summary_stats, 'conflict_resolution_method')
            content = [content, sprintf('  冲突解决方法: %s%s', data.summary_stats.conflict_resolution_method, NEWLINE)];
        end
        
        % 显示冲突解决详情
        if isfield(data.summary_stats, 'conflict_resolution_details')
            content = [content, sprintf('  冲突解决详情: %s%s', data.summary_stats.conflict_resolution_details, NEWLINE)];
        end
        content = [content, NEWLINE];
        
        % 7. 错误信息（如果有的话）
        if isfield(data, 'log_error')
            content = [content, NEWLINE, '=== 错误信息 ===', NEWLINE];
            content = [content, sprintf('  日志处理错误: %s%s', data.log_error, NEWLINE)];
        end
        
    catch ME
        % 错误处理
        error_msg = sprintf('格式化 edge_processing_module 数据出错: %s', ME.message);
        fprintf(error_msg);
        content = [content, error_msg, NEWLINE];
    end
end

%% 辅助函数
function content = format_edge_processing_section(section_title, section_name, data, field_meaning, content)
% FORMAT_EDGE_PROCESSING_SECTION - 格式化边处理模块的特定部分
% 输入：
%   section_title - 部分标题
%   section_name - 字段名
%   data - 原始数据
%   field_meaning - 字段映射
%   content - 已有的日志内容
% 输出：
%   content - 更新后的日志内容

    NEWLINE = get_newline();
    
    if isfield(data, section_name)
        section_data = data.(section_name);
        if isstruct(section_data) && ~isempty(fieldnames(section_data))
            content = [content, sprintf('=== %s ===', section_title), NEWLINE];
            
            % 获取该部分的所有字段
            field_names = fieldnames(section_data);
            
            for i = 1:length(field_names)
                field_name = field_names{i};
                field_value = section_data.(field_name);
                
                % 获取中文名称 - 简化逻辑
                chinese_name = get_chinese_name(field_meaning, [section_name, '.', field_name]);
                
                % 如果找不到，使用字段名
                if strcmp(chinese_name, [section_name, '.', field_name])
                    chinese_name = field_name;
                end
                
                % 使用现有的格式化函数
                field_str = format_single_field_complete(field_name, chinese_name, field_value);
                content = [content, field_str];
            end
        end
    end
end

function content = format_summary_stats_section(summary_stats, field_meaning, content)
% FORMAT_SUMMARY_STATS_SECTION - 格式化摘要统计部分
% 输入：
%   summary_stats - 摘要统计结构体
%   field_meaning - 字段映射
%   content - 已有的日志内容
% 输出：
%   content - 更新后的日志内容

    NEWLINE = get_newline();
    
    if ~isstruct(summary_stats) || isempty(fieldnames(summary_stats))
        content = [content, '  摘要统计为空或无效', NEWLINE];
        return;
    end
    
    % 1. 配对处理统计
    content = [content, '  配对处理:', NEWLINE];
    
    if isfield(summary_stats, 'total_pairs')
        content = [content, sprintf('    总配对数: %d', summary_stats.total_pairs)];
    end
    if isfield(summary_stats, 'processed_pairs')
        content = [content, sprintf(', 已处理: %d', summary_stats.processed_pairs)];
    end
    if isfield(summary_stats, 'skipped_pairs')
        content = [content, sprintf(', 跳过: %d', summary_stats.skipped_pairs)];
    end
    content = [content, NEWLINE];
    
    % 2. 跳过原因统计
    total_skipped = 0;
    if isfield(summary_stats, 'no_connectivity_results')
        total_skipped = total_skipped + summary_stats.no_connectivity_results;
    end
    if isfield(summary_stats, 'invalid_pair_info')
        total_skipped = total_skipped + summary_stats.invalid_pair_info;
    end
    if isfield(summary_stats, 'nodes_not_found')
        total_skipped = total_skipped + summary_stats.nodes_not_found;
    end
    
    if total_skipped > 0
        content = [content, '  跳过原因分析:', NEWLINE];
        
        if isfield(summary_stats, 'no_connectivity_results') && summary_stats.no_connectivity_results > 0
            content = [content, sprintf('    - 无连通性结果: %d', summary_stats.no_connectivity_results), NEWLINE];
        end
        if isfield(summary_stats, 'invalid_pair_info') && summary_stats.invalid_pair_info > 0
            content = [content, sprintf('    - 无效配对信息: %d', summary_stats.invalid_pair_info), NEWLINE];
        end
        if isfield(summary_stats, 'nodes_not_found') && summary_stats.nodes_not_found > 0
            content = [content, sprintf('    - 节点未找到: %d', summary_stats.nodes_not_found), NEWLINE];
        end
    else
        content = [content, '  跳过原因分析: 无跳过配对', NEWLINE];
    end
    
    % 3. 边添加统计
    content = [content, '  边添加统计:', NEWLINE];
    
    if isfield(summary_stats, 'added_edges')
        content = [content, sprintf('    总添加边数: %d', summary_stats.added_edges)];
    end
    if isfield(summary_stats, 'correlation_edges')
        content = [content, sprintf(', 相关性边: %d', summary_stats.correlation_edges)];
    end
    if isfield(summary_stats, 'granger_edges')
        content = [content, sprintf(', Granger边: %d', summary_stats.granger_edges)];
    end
    content = [content, NEWLINE];
    
    % 4. Granger边方向统计
    if isfield(summary_stats, 'bidirectional_edges') || isfield(summary_stats, 'unidirectional_edges')
        content = [content, '  Granger边方向统计:', NEWLINE];
        
        if isfield(summary_stats, 'bidirectional_edges')
            content = [content, sprintf('    - 双向边: %d', summary_stats.bidirectional_edges)];
        end
        if isfield(summary_stats, 'unidirectional_edges')
            content = [content, sprintf('    - 单向边: %d', summary_stats.unidirectional_edges)];
        end
        content = [content, NEWLINE];
    end
    
    % 5. 权重覆盖统计
    if isfield(summary_stats, 'weight_overrides') && summary_stats.weight_overrides > 0
        content = [content, '  权重覆盖统计:', NEWLINE];
        
        content = [content, sprintf('    - 权重覆盖次数: %d', summary_stats.weight_overrides)];
        
        if isfield(summary_stats, 'weight_conflicts_recorded')
            content = [content, sprintf('    - 记录冲突数: %d', summary_stats.weight_conflicts_recorded)];
        end
        if isfield(summary_stats, 'weight_conflicts_resolved')
            content = [content, sprintf('    - 已解决冲突: %d', summary_stats.weight_conflicts_resolved)];
        end
        content = [content, NEWLINE];
    end
    
    % 6. 网络密度变化
    if isfield(summary_stats, 'density_before') || isfield(summary_stats, 'density_after')
        content = [content, '  网络密度变化:', NEWLINE];
        
        if isfield(summary_stats, 'density_before')
            content = [content, sprintf('    - 处理前: %.6f', summary_stats.density_before)];
        end
        if isfield(summary_stats, 'density_after')
            content = [content, sprintf('    - 处理后: %.6f', summary_stats.density_after)];
        end
        content = [content, NEWLINE];
    end
    
    % 7. 计算记录统计
    if isfield(summary_stats, 'calc_records_created') || ...
       isfield(summary_stats, 'calc_records_saved') || ...
       isfield(summary_stats, 'calc_records_processed')
        content = [content, '  计算记录统计:', NEWLINE];
        
        if isfield(summary_stats, 'calc_records_created')
            content = [content, sprintf('    - 创建记录: %d', summary_stats.calc_records_created)];
        end
        if isfield(summary_stats, 'calc_records_saved')
            content = [content, sprintf('    - 保存记录: %d', summary_stats.calc_records_saved)];
        end
        if isfield(summary_stats, 'calc_records_processed')
            content = [content, sprintf('    - 处理记录: %d', summary_stats.calc_records_processed)];
        end
        content = [content, NEWLINE];
    end
    
    % 8. 日志配置
    if isfield(summary_stats, 'log_enabled')
        content = [content, '  日志配置:', NEWLINE];
        
        if summary_stats.log_enabled
            log_status = '启用';
        else
            log_status = '禁用';
        end
        
        content = [content, sprintf('    - 日志状态: %s', log_status)];
        
        if isfield(summary_stats, 'log_level')
            content = [content, sprintf('    - 日志级别: %s', summary_stats.log_level)];
        end
        
        content = [content, NEWLINE];
    end
end

function content = format_detailed_calculation_section(detailed_calculation, field_meaning, content)
% FORMAT_DETAILED_CALCULATION_SECTION - 格式化详细计算记录部分
% 输入：
%   detailed_calculation - 详细计算记录
%   field_meaning - 字段映射
%   content - 已有的日志内容
% 输出：
%   content - 更新后的日志内容

    NEWLINE = get_newline();
    
    if isempty(detailed_calculation)
        content = [content, '=== 详细计算记录 ===', NEWLINE];
        content = [content, '  详细计算记录为空 (日志功能可能被禁用)', NEWLINE, NEWLINE];
        return;
    end
    
    content = [content, '=== 详细计算记录 ===', NEWLINE];
   
    % 检查是否存在配对记录
    if isfield(detailed_calculation, 'pair_records')
        pair_records = detailed_calculation.pair_records;
        
        if iscell(pair_records) && ~isempty(pair_records)
            % 统计有效记录数
            valid_records = 0;
            for i = 1:length(pair_records)
                if ~isempty(pair_records{i})
                    valid_records = valid_records + 1;
                end
            end
            
            content = [content, sprintf('  共有 %d 个配对的详细记录 (总数: %d)', valid_records, length(pair_records)), NEWLINE];
            content = [content, NEWLINE];
            
            % 显示前几个配对的摘要（避免日志过大）
            max_display = min(30, length(pair_records));
            display_count = 0;
            
            for i = 1:length(pair_records)
                if ~isempty(pair_records{i})
                    record = pair_records{i};
                    
                    % 只显示前几个记录
                    if display_count < max_display
                        content = format_single_pair_record(record, i, field_meaning, content);
                        display_count = display_count + 1;
                    end
                end
            end
            
            if valid_records > max_display
                content = [content, sprintf('  ... 还有 %d 个配对记录未显示 ...%s', ...
                    valid_records - max_display, NEWLINE)];
            end
        else
            content = [content, '  无详细配对记录', NEWLINE, NEWLINE];
        end
    else
        content = [content, '  detailed_calculation 中无 pair_records 字段', NEWLINE, NEWLINE];
    end
    content = [content, NEWLINE];
end

function content = format_single_pair_record(record, record_idx, field_meaning, content)
% FORMAT_SINGLE_PAIR_RECORD - 格式化单个配对记录
% 输入：
%   record - 单个配对记录
%   record_idx - 记录索引
%   field_meaning - 字段映射
%   content - 已有的日志内容
% 输出：
%   content - 更新后的日志内容

    NEWLINE = get_newline();
    
    if ~isstruct(record)
        return;
    end
    
    % 配对基本信息
    if isfield(record, 'pair_idx')
        pair_idx = record.pair_idx;
    else
        pair_idx = record_idx;
    end
    
    content = [content, sprintf('  ----- 配对 #%d -----%s', pair_idx, NEWLINE)];
    
    % 基本信息
    if isfield(record, 'start_time')
        content = [content, sprintf('    开始时间: %s%s', record.start_time, NEWLINE)];
    end
    if isfield(record, 'end_time')
        content = [content, sprintf('    结束时间: %s%s', record.end_time, NEWLINE)];
    end
    if isfield(record, 'total_processing_time')
        content = [content, sprintf('    处理耗时: %.6f 秒%s', record.total_processing_time, NEWLINE)];
    end
    if isfield(record, 'final_status')
        content = [content, sprintf('    最终状态: %s', record.final_status)];
        
        if isfield(record, 'final_reason')
            content = [content, sprintf(' (%s)', record.final_reason)];
        end
        content = [content, NEWLINE];
    end
    
    % 处理各阶段信息
    if isfield(record, 'stages')
        stages = record.stages;
        
        % 验证阶段
        if isfield(stages, 'validation')
            validation = stages.validation;
            if isfield(validation, 'passed')
                if validation.passed
                    status_str = '通过';
                else
                    status_str = '失败';
                end
                
                content = [content, sprintf('    验证: %s', status_str)];
                
                if isfield(validation, 'reason') && ~isempty(validation.reason)
                    content = [content, sprintf(' (%s)', validation.reason)];
                end
                content = [content, NEWLINE];
                
                % 验证详情
                if isfield(validation, 'ret_name') && isfield(validation, 'obv_name')
                    content = [content, sprintf('      节点: %s → %s', ...
                        validation.ret_name, validation.obv_name), NEWLINE];
                end
            end
        end
        
        % 提取阶段
        if isfield(stages, 'extraction')
            extraction = stages.extraction;
            if isfield(extraction, 'analysis_type')
                content = [content, sprintf('    提取: %s 分析', extraction.analysis_type)];
                
                if isfield(extraction, 'extraction_time')
                    content = [content, sprintf(' (%.6f 秒)', extraction.extraction_time)];
                end
                content = [content, NEWLINE];
            end
        end
        
        % 决策阶段
        if isfield(stages, 'decision')
            decision = stages.decision;
            if isfield(decision, 'edge_added')
                if decision.edge_added
                    action_str = '添加边';
                else
                    action_str = '不添加边';
                end
                
                content = [content, sprintf('    决策: %s', action_str)];
                
                if isfield(decision, 'decision_time')
                    content = [content, sprintf(' (%.6f 秒)', decision.decision_time)];
                end
                content = [content, NEWLINE];
                
                % 决策详情
                if isfield(decision, 'weight_override')
                    if decision.weight_override
                        override_str = '是';
                    else
                        override_str = '否';
                    end
                    content = [content, sprintf('      权重覆盖: %s', override_str)];
                    
                    if isfield(decision, 'decision_rule')
                        content = [content, sprintf(' (规则: %s)', decision.decision_rule)];
                    end
                    content = [content, NEWLINE];
                end
            end
        end
        
        % 更新阶段
        if isfield(stages, 'update')
            update = stages.update;
            if isfield(update, 'update_time')
                content = [content, sprintf('    更新: %.6f 秒%s', update.update_time, NEWLINE)];
            end
        end
        
        % 错误信息
        if isfield(stages, 'error')
            error_info = stages.error;
            if isfield(error_info, 'error_occurred') && error_info.error_occurred
                content = [content, sprintf('    错误: 发生处理错误%s', NEWLINE)];
                
                if isfield(error_info, 'error_message')
                    content = [content, sprintf('      错误信息: %s%s', error_info.error_message, NEWLINE)];
                end
            end
        end
    end
    
    % 边信息
    if isfield(record, 'edge_info')
        edge_info = record.edge_info;
        if isstruct(edge_info)
            content = [content, '    边信息:', NEWLINE];
            
            if isfield(edge_info, 'from_node') && isfield(edge_info, 'to_node')
                content = [content, sprintf('      连接: %s → %s', ...
                    edge_info.from_node, edge_info.to_node)];
                
                if isfield(edge_info, 'direction')
                    content = [content, sprintf(' (%s)', edge_info.direction)];
                end
                content = [content, NEWLINE];
            end
            
            if isfield(edge_info, 'weight')
                content = [content, sprintf('      权重: %.6f', edge_info.weight)];
            end
            if isfield(edge_info, 'p_value')
                content = [content, sprintf(', P值: %.6e', edge_info.p_value)];
            end
            if isfield(edge_info, 'is_significant')
                if edge_info.is_significant
                    sig_str = '显著';
                else
                    sig_str = '不显著';
                end
                content = [content, sprintf(', 显著性: %s', sig_str)];
            end
            content = [content, NEWLINE];
        end
    end
    
    content = [content, NEWLINE];
end

