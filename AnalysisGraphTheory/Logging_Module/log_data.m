function log_data(module_name, func_filename, data, data_type, varargin)
% LOG_DATA - 通用日志记录主函数
%
% 功能：记录计算过程的详细信息，自动分模块分类别处理
%
% 输入参数：
%   module_name   : 模块名称（如："network_build", "edge_processing"）
%   func_filename : 函数文件名（如："edge_processing_module.m" 或 "build_pair_network_complete"）
%   data         : 要记录的数据（结构体、数值、字符串、数组等）
%   data_type    : 数据类型，必须是以下之一：
%                 'input_params'    - 输入参数
%                 'calc_process'    - 计算过程
%                 'calc_result'     - 计算结果
%   varargin     : 可选参数
%                 'stock_name'      : 股票名称（可选）
%                 'step_desc'       : 步骤描述（可选，用于计算过程细分）
%                 'level'           : 日志级别（可选，'DETAIL', 'INFO', 'WARN', 'ERROR'）
%                 'append'          : 是否追加到日志文件（可选，默认true）
%
% 示例：
%   1. 记录输入参数
%   log_data('network_build', 'build_pair_network_complete', input_struct, 'input_params', ...
%            'stock_name', 'all_stocks');
%   
%   2. 记录计算过程
%   log_data('edge_processing', 'edge_processing_module', process_data, 'calc_process', ...
%            'stock_name', '000001.SZ', 'step_desc', '配对验证');
%
%   3. 记录计算结果
%   log_data('edge_processing', 'edge_processing_module', result_data, 'calc_result', ...
%            'stock_name', 'all_stocks');

    %% 参数验证
    % 必选参数验证
    if nargin < 4
        error('LOG_DATA: 至少需要4个输入参数：module_name, func_filename, data, data_type');
    end

    % 验证模块名称
    valid_modules = {'connectivity_pairwise_analyze_modular', 'build_pair_network_complete', 'analyze_network_cycles', ...
        'evaluate_constructed_network_main', 'build_network_time_series', 'analyze_network_markov_basic'};
    if ~ismember(module_name, valid_modules)
        warning('LOG_DATA: 未知模块名称 "%s"，将使用默认处理', module_name);
    end
    
    % 验证数据类型
    valid_data_types = {'input_params', 'calc_process', 'calc_result'};
    if ~ismember(data_type, valid_data_types)
        error('LOG_DATA: 数据类型必须是: %s', strjoin(valid_data_types, ', '));
    end
    
    % 解析可选参数
    p = inputParser;
    addParameter(p, 'stock_name', '', @ischar);
    addParameter(p, 'level', 'DETAIL', @(x) ismember(x, {'DETAIL', 'INFO', 'WARN', 'ERROR'}));
    addParameter(p, 'append', true, @islogical);
    parse(p, varargin{:});
    
    stock_name = p.Results.stock_name;
    level = p.Results.level;
    append_mode = p.Results.append;
    
    %% 调用分类处理器
    try
        % 根据模块名、函数名、数据类型进行分类处理
        [log_header, log_content] = classify_and_process(...
            module_name, func_filename, data, data_type, stock_name, level);
        
        % 写入日志文件
        write_to_log(log_header, log_content, append_mode);
        
        % 输出到控制台（仅ERROR和WARN级别）
        if ismember(level, {'ERROR', 'WARN'})
            fprintf('[%s] %s\n', level, log_header);
        end
        
    catch ME
        % 记录日志函数自身的错误
        fprintf(2, '日志记录失败: %s\n', ME.message);
        
        % 尝试记录错误到独立错误日志
        backup_log_error(module_name, func_filename, data_type, ME);
    end
end

function [log_header, log_content] = classify_and_process(...
    module_name, func_filename, data, data_type, stock_name, level)
% CLASSIFY_AND_PROCESS - 分类处理不同模块和类型的数据
%
% 根据模块名、函数名、数据类型进行分类，调用相应的处理函数

    %% 1. 构建基本日志头信息
    timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
    
    % 模块名称映射为中文
    module_map = struct(...
        'connectivity_pairwise_analyze_modular', '连通性分析', ...
        'build_pair_network_complete', '网络构建', ...
        'evaluate_constructed_network_main', '网络拓扑分析', ...
        'analyze_network_cycles', '环结构分析', ...
        'build_network_time_series', '构建时间序列', ...
        'analyze_network_markov_basic', '马尔科夫分析' ...
    );
    
    if isfield(module_map, module_name)
        module_cn = module_map.(module_name);
    else
        module_cn = module_name;  % 未知模块使用原名称
    end
    
    % 数据类型映射为中文
    data_type_map = struct(...
        'input_params', '输入参数', ...
        'calc_process', '计算过程', ...
        'calc_result', '计算结果' ...
    );
    
    if isfield(data_type_map, data_type)
        data_type_cn = data_type_map.(data_type);
    else
        data_type_cn = data_type;
    end
    
    % 从函数文件名中提取函数名（去除.m扩展名）
    [~, func_name, ~] = fileparts(func_filename);
    
    %% 2. 构建日志头
    log_header = sprintf('%s 【%s】%s', ...
            timestamp, module_cn, func_name);
    
    % 添加股票名称（如果提供）
    if ~isempty(stock_name)
        log_header = sprintf('%s 股票:%s', log_header, stock_name);
    end
    
    % 添加数据类型
    log_header = sprintf('%s\n%s', log_header, data_type_cn);
    
%        'build_network_time_series', '构建时间序列', ...
    
    %% 3. 根据模块和数据类型调用不同的处理器
    switch module_name
        case 'build_pair_network_complete'                % 网络构建
            [log_content, ~] = process_network_build(func_name, data, data_type, stock_name);
            
        case 'edge_processing'
            [log_content, ~] = process_edge_processing(func_name, data, data_type, stock_name);
            
        case 'connectivity_pairwise_analyze_modular'      % 连通性分析
            [log_content, ~] = process_connectivity_analysis(func_name, data, data_type, stock_name);
            
        case 'evaluate_constructed_network_main'          % 网络拓扑分析
            [log_content, ~] = process_topology_analysis(func_name, data, data_type, stock_name);
             
        case 'analyze_network_cycles'                     % 环结构分析
            [log_content, ~] = process_cycle_analysis(func_name, data, data_type, stock_name);
            
        case 'analyze_network_markov_basic'               % 马尔科夫分析
            [log_content, ~] = process_markov_analysis(func_name, data, data_type, stock_name);
            
        otherwise
            % 默认处理器
            [log_content, ~] = process_default(func_name, data, data_type, stock_name);
    end
    
    %% 4. 添加日志级别标识
    if ~strcmp(level, 'DETAIL')
        log_header = sprintf('[%s] %s', level, log_header);
    end
end