function [analysis_results, optional_report] = evaluate_constructed_network_main(pair_network, varargin)
% EVALUATE_CONSTRUCTED_NETWORK_MAIN - 网络分析系统主函数（协调器）
% 
% 【功能定位】
% 协调网络拓扑分析和报告生成两个独立模块。
% 可选择只进行分析，或同时生成报告。
%
% 【输入参数】
%   pair_network: 网络结构体
%   varargin: 可选参数
%       'AnalysisOnly': 是否只进行分析，不生成报告 (默认: false)
%       'ReportLevel': 报告详细程度
%       'SaveReport': 是否保存报告
%       'TopK': 分析参数
%       'Verbose': 是否显示进度
%
% 【输出参数】
%   analysis_results: 网络拓扑分析结果
%   optional_report: 可选的报告结果（如果生成报告）



    %% 1. 参数解析（包含两个模块的参数）
    p = inputParser;
    addRequired(p, 'pair_network', @isstruct);
    
    % 分析模块参数
    addParameter(p, 'TopK', 5, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'Verbose', true, @islogical);
    
    % 报告模块参数
    addParameter(p, 'AnalysisOnly', false, @islogical);
    addParameter(p, 'ReportLevel', 'standard', ...
        @(x) ismember(x, {'brief', 'standard', 'detailed'}));
    addParameter(p, 'SaveReport', false, @islogical);
    addParameter(p, 'ReportFileName', '', @ischar);
    
    p.parse(pair_network, varargin{:});
    opts = p.Results;
    
    %% 2. 执行网络拓扑分析（计算模块）
    fprintf('\n========================================\n');
    fprintf('网络分析系统启动\n');
    fprintf('========================================\n\n');
    
    [analysis_results, integrated_results] = analyze_network_topology(...
        pair_network, ...
        'TopK', opts.TopK, ...
        'Verbose', opts.Verbose);
    
    %% 3. 可选：生成网络分析报告（报告模块）
    optional_report = [];
    if ~opts.AnalysisOnly
        fprintf('\n========================================\n');
        fprintf('网络报告生成启动\n');
        fprintf('========================================\n\n');
        
        [formatted_report, overall_assessment] = generate_network_report(...
            analysis_results, integrated_results, ...
            'ReportLevel', opts.ReportLevel, ...
            'SaveReport', opts.SaveReport, ...
            'ReportFileName', opts.ReportFileName);
        
        optional_report = struct();
        optional_report.formatted_report = formatted_report;
        optional_report.overall_assessment = overall_assessment;
        optional_report.report_timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    end
    
    fprintf('\n========================================\n');
    fprintf('网络分析系统完成\n');
    fprintf('========================================\n\n');
end

function save_figure(fig_handle, output_dir, filename_prefix, format, verbose)
% 保存图形到文件
    if ~ishandle(fig_handle)
        return;
    end
    
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    filename = sprintf('%s_%s.%s', filename_prefix, timestamp, format);
    filepath = fullfile(output_dir, filename);
    
    try
        saveas(fig_handle, filepath, format);
        if verbose
            fprintf('  保存图形: %s\n', filename);
        end
    catch ME
        if verbose
            fprintf('  警告: 保存图形失败: %s\n', ME.message);
        end
    end
end

