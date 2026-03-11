function [fig_handles, summary_stats] = plot_network_topology_analysis_main(analysis_results, pair_network, varargin)
% PLOT_NETWORK_TOPOLOGY_ANALYSIS_MAIN - 网络结构分析可视化主入口
% 
% 【功能描述】
% 主入口函数，协调调用三个子画布函数，生成完整的网络分析可视化结果。
%
% 【输入参数】
%   analysis_results: 网络分析结果结构体（包含9个模块的分析结果）
%   pair_network: 原始网络结构体（包含adjacency, node_labels等）
%   varargin: 可选参数
%       'VisualizationMode': 可视化模式
%           - 'complete' (默认): 生成所有3个画布
%           - 'macro_only': 只生成宏观统计画布
%           - 'micro_only': 只生成微观拓扑画布
%           - 'dynamic_only': 只生成动态演化画布
%           - 'quick': 快速模式，只生成核心子图
%       'FigureQuality': 图形质量 ('high'(默认), 'medium', 'low')
%       'SaveFigures': 是否保存图形 (默认: false)
%       'OutputDir': 保存目录 (默认: 'network_visualization/')
%       'FigureFormat': 保存格式 ('png'(默认), 'pdf', 'svg')
%       'ShowTitles': 是否显示子图标题 (默认: true)
%       'Verbose': 是否显示处理信息 (默认: true)
%
% 【输出参数】
%   fig_handles: 图形句柄结构体
%       .macro_fig: 宏观统计画布句柄
%       .micro_fig: 微观拓扑画布句柄
%       .dynamic_fig: 动态演化画布句柄
%   summary_stats: 可视化统计摘要
%
% 【调用示例】
%   % 生成完整的可视化
%   [figs, stats] = plot_network_topology_analysis_main(analysis_results, pair_network);
%   
%   % 只生成微观拓扑图
%   [figs, stats] = plot_network_topology_analysis_main(analysis_results, pair_network, ...
%       'VisualizationMode', 'micro_only');
%   
%   % 保存为PDF格式
%   [figs, stats] = plot_network_topology_analysis_main(analysis_results, pair_network, ...
%       'SaveFigures', true, ...
%       'FigureFormat', 'pdf', ...
%       'OutputDir', 'my_network_plots/');
% 调用方式：
%   % 生成所有3个画布
%   [figs, stats] = plot_network_topology_analysis_main(analysis_results, pair_network);
%
%   % 只生成微观拓扑画布
%    [figs, stats] = plot_network_topology_analysis_main(...
%        analysis_results, pair_network, ...
%        'VisualizationMode', 'micro_only', ...
%        'FigureQuality', 'high', ...
%        'SaveFigures', true, ...
%        'OutputDir', 'my_network_plots/', ...
%        'FigureFormat', 'pdf', ...
%        'Verbose', true);

    %% 1. 参数解析
    start_time = tic;
    
    p = inputParser;
    addRequired(p, 'analysis_results', @isstruct);
    addRequired(p, 'pair_network', @isstruct);
    
    % 可视化控制参数
    addParameter(p, 'VisualizationMode', 'complete', ...
        @(x) ismember(x, {'complete', 'macro_only', 'micro_only', 'dynamic_only', 'quick'}));
    addParameter(p, 'FigureQuality', 'high', ...
        @(x) ismember(x, {'high', 'medium', 'low'}));
    addParameter(p, 'SaveFigures', false, @islogical);
    addParameter(p, 'OutputDir', 'network_visualization/', @ischar);
    addParameter(p, 'FigureFormat', 'png', ...
        @(x) ismember(x, {'png', 'pdf', 'svg', 'fig', 'jpg'}));
    addParameter(p, 'ShowTitles', true, @islogical);
    addParameter(p, 'Verbose', true, @islogical);
    
    p.parse(analysis_results, pair_network, varargin{:});
    opts = p.Results;
    
    %% 2. 初始化输出
    fig_handles = struct();
    summary_stats = struct();
    summary_stats.visualization_mode = opts.VisualizationMode;
    summary_stats.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    if opts.Verbose
        fprintf('\n========================================\n');
        fprintf('网络结构分析可视化系统\n');
        fprintf('========================================\n');
        fprintf('可视化模式: %s\n', opts.VisualizationMode);
        fprintf('图形质量: %s\n', opts.FigureQuality);
        fprintf('保存图形: %s\n', bool2str(opts.SaveFigures));
        if opts.SaveFigures
            fprintf('输出目录: %s\n', opts.OutputDir);
            fprintf('保存格式: %s\n', opts.FigureFormat);
        end
        fprintf('\n');
    end
    
    %% 3. 准备保存目录
    if opts.SaveFigures && ~exist(opts.OutputDir, 'dir')
        mkdir(opts.OutputDir);
        if opts.Verbose
            fprintf('创建输出目录: %s\n', opts.OutputDir);
        end
    end
    
    %% 4. 根据模式调用子画布函数
    mode = opts.VisualizationMode;
    n_figs_generated = 0;
    
    % 4.1 宏观统计画布
    if any(strcmp(mode, {'complete', 'macro_only', 'quick'}))
        if opts.Verbose
            fprintf('生成画布1: 宏观统计与健康度...\n');
        end
        
        fig_handles.macro_fig = visualize_macro_statistics(...
            analysis_results, pair_network, opts);
        n_figs_generated = n_figs_generated + 1;
        
        % 保存图形
        if opts.SaveFigures
            save_figure(fig_handles.macro_fig, opts.OutputDir, ...
                'macro_statistics', opts.FigureFormat, opts.Verbose);
        end
    end
    
    % 4.2 微观拓扑画布
    if any(strcmp(mode, {'complete', 'micro_only'}))
        if opts.Verbose
            fprintf('生成画布2: 微观结构与拓扑...\n');
        end
        
        fig_handles.micro_fig = visualize_micro_structure(...
            analysis_results, pair_network, opts);
        n_figs_generated = n_figs_generated + 1;
        
        % 保存图形
        if opts.SaveFigures
            save_figure(fig_handles.micro_fig, opts.OutputDir, ...
                'micro_structure', opts.FigureFormat, opts.Verbose);
        end
    end
    
    % 4.3 动态演化画布
    if any(strcmp(mode, {'complete', 'dynamic_only'}))
        if opts.Verbose
            fprintf('生成画布3: 动态演化与鲁棒性...\n');
        end
        
        fig_handles.dynamic_fig = visualize_dynamic_robustness(...
            analysis_results, pair_network, opts);
        n_figs_generated = n_figs_generated + 1;
        
        % 保存图形
        if opts.SaveFigures
            save_figure(fig_handles.dynamic_fig, opts.OutputDir, ...
                'dynamic_robustness', opts.FigureFormat, opts.Verbose);
        end
    end
    
    %% 5. 生成统计摘要
    summary_stats.n_figs_generated = n_figs_generated;
    summary_stats.generation_time = toc(start_time);
    
    %% 6. 完成
    if opts.Verbose
        fprintf('\n========================================\n');
        fprintf('可视化生成完成\n');
        fprintf('生成图形数量: %d\n', n_figs_generated);
        fprintf('总耗时: %.2f 秒\n', summary_stats.generation_time);
        fprintf('========================================\n\n');
    end
end

function str = bool2str(bool_val)
    if bool_val
        str = '是';
    else
        str = '否';
    end
end