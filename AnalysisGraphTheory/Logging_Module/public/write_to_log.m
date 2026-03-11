function write_to_log(log_header, log_content, append_mode)
% WRITE_TO_LOG - 将日志写入文件
%
% 固定使用一个日志文件

    % 固定日志文件路径
    log_path = 'C:\math\QuantStock_3.9\Computer\Quant_Strategy_A_Share\BarDayCount\Logs';
    
    % 确保目录存在
    if ~exist(log_path, 'dir')
        mkdir(log_path);
    end
    
    % 单一日志文件名
    log_filename = fullfile(log_path, 'network_calculation_detail.log');
    
    % 确定写入模式
    if append_mode
        file_mode = 'a';
    else
        file_mode = 'w';
    end
    
    % 写入日志
    try
        fid = fopen(log_filename, file_mode, 'n', 'GBK');  % 使用系统本地编码
        if fid == -1
            error('无法打开日志文件: %s', log_filename);
        end
        
        % 写入日志头
        fprintf(fid, '%s\n', log_header);
        
        % 写入日志内容
        if ~isempty(log_content)
            fprintf(fid, '%s', log_content);
        end
        
        % 添加空行分隔
        fprintf(fid, '\n');
        
        fclose(fid);
        
    catch ME
        fprintf(2, '写入日志文件失败: %s\n', ME.message);
        % 尝试使用备用文件
        backup_log_write(log_header, log_content);
    end
end