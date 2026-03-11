function [formatted_report, overall_assessment] = generate_network_topology_report(analysis_results, integrated_results, varargin)
% GENERATE_NETWORK_REPORT - 独立的网络分析报告生成函数
% 
% 【功能定位】
% 专注生成格式化报告，不进行任何计算。
% 这是纯粹的"报告模块"，输入是analysis_results，输出是报告。
%
% 【输入参数】
%   analysis_results: 网络拓扑分析结果（来自analyze_network_topology）
%   integrated_results: 整合后的分析结果
%   varargin: 可选参数
%       'ReportLevel': 报告详细程度 ('brief', 'standard'(默认), 'detailed')
%       'SaveReport': 是否保存报告文件 (默认: false)
%       'ReportFileName': 保存文件名
%
% 【输出参数】
%   formatted_report: 格式化文本报告
%   overall_assessment: 综合评估结果
%
% 【调用示例】
%   % 先生成分析结果
%   [analysis_results, integrated] = analyze_network_topology(pair_network);
%   
%   % 再生成报告
%   [report, assessment] = generate_network_report(analysis_results, integrated, ...
%       'ReportLevel', 'detailed', 'SaveReport', true);

    fprintf('【网络分析报告】开始生成...\n');
    start_time = tic;
    
    %% 1. 参数解析（只保留报告相关参数）
    p = inputParser;
    addRequired(p, 'analysis_results', @isstruct);
    addRequired(p, 'integrated_results', @isstruct);
    addParameter(p, 'ReportLevel', 'standard', ...
        @(x) ismember(x, {'brief', 'standard', 'detailed'}));
    addParameter(p, 'SaveReport', false, @islogical);
    addParameter(p, 'ReportFileName', '', @ischar);
    p.parse(analysis_results, integrated_results, varargin{:});
    opts = p.Results;
    
    % 设置默认文件名
    if isempty(opts.ReportFileName)
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        opts.ReportFileName = sprintf('Network_Analysis_Report_%s.txt', timestamp);
    end
    
    %% 2. 生成综合评估（从原主函数迁移）
    fprintf('步骤1: 生成综合评估...\n');
    overall_assessment = generate_overall_assessment(integrated_results);
    
    %% 3. 生成格式化报告（从原主函数迁移）
    fprintf('步骤2: 生成格式化报告...\n');
    formatted_report = generate_formatted_report(...
        integrated_results, overall_assessment, opts.ReportLevel);
    
    %% 4. 保存报告文件（从原主函数迁移）
    if opts.SaveReport
        fprintf('步骤3: 保存报告文件...\n');
        save_report_to_file(formatted_report, opts.ReportFileName);
    end
    
    %% 5. 完成
    report_time = toc(start_time);
    fprintf('\n【网络分析报告生成完成】\n');
    fprintf('报告详细程度: %s\n', opts.ReportLevel);
    fprintf('生成时间: %.2f 秒\n', report_time);
    if opts.SaveReport
        fprintf('报告已保存: %s\n', opts.ReportFileName);
    end
end