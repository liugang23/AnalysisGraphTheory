function [result, stats] = analyze_granger_causality(X, Y, varargin)
% analyze_granger_causality - Granger因果检验函数（使用MVGC工具箱）
% 功能: 使用MVGC工具箱进行专业的Granger因果分析
% 支持频域和时域分析
%
% 输入:
%   X, Y: 时间序列向量
%   varargin: 可选参数 (名称-值对)
%     - 'max_lag': 最大滞后阶数 (默认: 5)
%     - 'significance_level': 显著性水平 (默认: 0.05)
%     - 'method': 分析方法 'time'(时域) 或 'frequency'(频域) (默认: 'time')
%     - 'regmode': 回归模式 'OLS', 'LWR', 'LWRR' (默认: 'OLS')
%     - 'verbosity': 输出详细程度 0,1,2 (默认: 0)
%     - 'alpha': 显著性水平 (0<α<1) (默认: 0.05)
%
% 输出:
%   result: 逻辑值，是否存在Granger因果关系
%   stats: 包含详细统计信息
%     - direction: 因果关系方向
%     - causality_strength: 因果强度
%     - p_value_x2y: X→Y的p值
%     - p_value_y2x: Y→X的p值
%     - f_statistic_x2y: X→Y的F统计量
%     - f_statistic_y2x: Y→X的F统计量
%     - optimal_lag: 最优滞后阶数
%     - is_significant: 是否显著
%
% 示例:
%   [h, stats] = analyze_granger_causality(X, Y, 'max_lag', 5, 'alpha', 0.05)
%
% 版本: 3.0 (使用MVGC工具箱)
% 日期: 2024-12-28
% 依赖: MVGC Toolbox (v1.0)

%% 1. 参数解析
p = inputParser;
addRequired(p, 'X', @isvector);
addRequired(p, 'Y', @isvector);
addParameter(p, 'max_lag', 5, @(x) isscalar(x) && x > 0);
addParameter(p, 'significance_level', 0.05, @(x) x>0 && x<1);
addParameter(p, 'alpha', 0.05, @(x) x>0 && x<1);
addParameter(p, 'method', 'time', @(x) ismember(x, {'time', 'frequency'}));
addParameter(p, 'regmode', 'OLS', @ischar);
addParameter(p, 'verbosity', 0, @(x) isscalar(x) && x >= 0);
parse(p, X, Y, varargin{:});

max_lag = p.Results.max_lag;
alpha = p.Results.significance_level;
method = lower(p.Results.method);
regmode = p.Results.regmode;
verbosity = p.Results.verbosity;

%% 2. 输入验证和数据准备
% 转换为列向量
X = X(:);
Y = Y(:);

% 检查数据长度
if length(X) ~= length(Y)
    error('X 和 Y 的长度必须一致: X=%d, Y=%d', length(X), length(Y));
end

n_obs = length(X);
if n_obs < max_lag + 10
    warning('样本量可能不足: n=%d, lags=%d (建议 n >= lags+20)', n_obs, max_lag);
end

% 去除NaN值
valid_idx = ~isnan(X) & ~isnan(Y);
X_clean = X(valid_idx);
Y_clean = Y(valid_idx);
n_valid = length(X_clean);

if n_valid < 20
    error('有效数据点不足: %d (至少需要20个)', n_valid);
end

%% 3. 调用MVGC工具箱
try
    % 准备数据矩阵 (2×T格式)
    data = [X_clean'; Y_clean'];  % MVGC要求行是变量，列是时间点
    nvars = 2;
    
    % MVGC选项结构
    mvgc_opts = struct();
    mvgc_opts.regmode = regmode;
    mvgc_opts.verbosity = verbosity;
    
    % 选择分析方法
    switch method
        case 'time'
            % 时域Granger因果
            [F, pval] = mvgc(data, 'time', 'lags', 1:max_lag, mvgc_opts);
            
            % 提取双向因果
            F_x2y = F(2,1,:);
            F_y2x = F(1,2,:);
            p_x2y = pval(2,1,:);
            p_y2x = pval(1,2,:);
            
            % 选择最优滞后（基于AIC或其他准则）
            optimal_lag = select_optimal_lag(data, 1:max_lag, regmode);
            
            % 使用最优滞后的结果
            f_stat_x2y = F_x2y(optimal_lag);
            f_stat_y2x = F_y2x(optimal_lag);
            p_val_x2y = p_x2y(optimal_lag);
            p_val_y2x = p_y2x(optimal_lag);
            
        case 'frequency'
            % 频域Granger因果
            [f, pval] = mvgc(data, 'frequency', 'lags', 1:max_lag, mvgc_opts);
            
            % 提取频域结果（使用平均值）
            f_x2y = squeeze(f(2,1,:));
            f_y2x = squeeze(f(1,2,:));
            p_x2y = squeeze(pval(2,1,:));
            p_y2x = squeeze(pval(1,2,:));
            
            % 计算频域平均值
            f_stat_x2y = mean(f_x2y, 'omitnan');
            f_stat_y2x = mean(f_y2x, 'omitnan');
            p_val_x2y = mean(p_x2y, 'omitnan');
            p_val_y2x = mean(p_y2x, 'omitnan');
            
            optimal_lag = 0;  % 频域分析不返回滞后
    end
    
    % 判断显著性
    significant_x2y = (p_val_x2y < alpha);
    significant_y2x = (p_val_y2x < alpha);
    
    % 确定因果关系方向
    if significant_x2y && ~significant_y2x
        direction = 'x_to_y';
        causality_strength = 1;
    elseif ~significant_x2y && significant_y2x
        direction = 'y_to_x';
        causality_strength = -1;
    elseif significant_x2y && significant_y2x
        direction = 'bidirectional';
        causality_strength = 0;  % 双向
    else
        direction = 'no_causality';
        causality_strength = 0;
    end
    
    % 是否存在因果关系
    result = ~strcmp(direction, 'no_causality');
    
    %% 4. 构建统计信息结构
    stats = struct();
    
    % 主要结果
    stats.direction = direction;
    stats.causality_strength = causality_strength;
    stats.p_value_x2y = p_val_x2y;
    stats.p_value_y2x = p_val_y2x;
    stats.f_statistic_x2y = f_stat_x2y;
    stats.f_statistic_y2x = f_stat_y2x;
    stats.optimal_lag = optimal_lag;
    stats.is_significant = result;
    stats.significant_x2y = significant_x2y;
    stats.significant_y2x = significant_y2x;
    
    % 元数据
    stats.method = method;
    stats.significance_level = alpha;
    stats.max_lag = max_lag;
    stats.n_observations = n_valid;
    stats.regmode = regmode;
    stats.toolbox = 'MVGC';
    
    % 添加时间戳
    stats.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    % 显示简要结果
    if verbosity > 0
        fprintf('\nGranger因果检验结果 (MVGC):\n');
        fprintf('  方向: %s\n', direction);
        fprintf('  X→Y: p=%.6f, F=%.4f, 显著: %s\n', ...
            p_val_x2y, f_stat_x2y, bool2str(significant_x2y));
        fprintf('  Y→X: p=%.6f, F=%.4f, 显著: %s\n', ...
            p_val_y2x, f_stat_y2x, bool2str(significant_y2x));
        if optimal_lag > 0
            fprintf('  最优滞后: %d\n', optimal_lag);
        end
        fprintf('  观测值数量: %d\n', n_valid);
    end
    
catch ME
    % MVGC失败时的备用方案
    warning('MVGC分析失败: %s，使用备用方法', ME.message);
    
    % 回退到手写方法
    [result, stats] = analyze_granger_causality_backup(X, Y, varargin{:});
    stats.error_message = ME.message;
    stats.toolbox = 'backup_method';
end
end

%% 辅助函数：选择最优滞后
function optimal_lag = select_optimal_lag(data, lags, regmode)
% 基于AIC选择最优滞后阶数
    
    nvars = size(data, 1);
    n_obs = size(data, 2);
    n_lags = length(lags);
    
    aic_values = zeros(1, n_lags);
    
    for i = 1:n_lags
        lag = lags(i);
        
        try
            % 拟合VAR模型
            [A,SIG,E] = tsdata_to_var(data, lag, regmode);
            if isempty(A)
                aic_values(i) = Inf;
            else
                % 计算AIC
                aic_values(i) = aic_eval(data, A, SIG);
            end
        catch
            aic_values(i) = Inf;
        end
    end
    
    % 选择最小AIC对应的滞后
    [~, min_idx] = min(aic_values);
    optimal_lag = lags(min_idx);
end

%% 辅助函数：计算AIC
function aic = aic_eval(data, A, SIG)
% 计算Akaike信息准则
    
    nvars = size(data, 1);
    n_obs = size(data, 2);
    n_lags = size(A, 3);
    
    % 计算残差
    resid = var_residuals(data, A);
    
    % 计算对数似然
    loglik = var_loglik(data, A, SIG);
    
    % 参数数量
    n_params = nvars * nvars * n_lags;
    
    % AIC公式
    aic = -2 * loglik + 2 * n_params;
end

%% 辅助函数：备用方法
function [result, stats] = analyze_granger_causality_backup(X, Y, varargin)
% 备用Granger因果检验（当MVGC失败时使用）
    
    p = inputParser;
    addRequired(p, 'X', @isvector);
    addRequired(p, 'Y', @isvector);
    addParameter(p, 'max_lag', 5, @(x) isscalar(x) && x > 0);
    addParameter(p, 'alpha', 0.05, @(x) x>0 && x<1);
    parse(p, X, Y, varargin{:});
    
    max_lag = p.Results.max_lag;
    alpha = p.Results.alpha;
    
    % 手写实现（基于之前的代码）
    X = X(:); Y = Y(:);
    T = length(X);
    
    Y_cur = Y(max_lag+1:end);
    
    % 受限模型
    X_restricted = [];
    for i = 1:max_lag
        X_restricted = [X_restricted, Y(max_lag+1-i:end-i)];
    end
    X_restricted = [ones(size(X_restricted,1),1), X_restricted];
    
    % 无限制模型
    X_unrestricted = X_restricted;
    for i = 1:max_lag
        X_unrestricted = [X_unrestricted, X(max_lag+1-i:end-i)];
    end
    
    % 估计模型
    beta_r = X_restricted \ Y_cur;
    RSS_r = sum((Y_cur - X_restricted * beta_r).^2);
    
    beta_ur = X_unrestricted \ Y_cur;
    RSS_ur = sum((Y_cur - X_unrestricted * beta_ur).^2);
    
    % F检验
    N = length(Y_cur);
    k_r = size(X_restricted, 2);
    k_ur = size(X_unrestricted, 2);
    df_num = k_ur - k_r;
    df_den = N - k_ur;
    
    F_stat = ((RSS_r - RSS_ur) / df_num) / (RSS_ur / df_den);
    pValue = 1 - fcdf(F_stat, df_num, df_den);
    
    result = pValue < alpha;
    
    stats = struct();
    stats.pValue = pValue;
    stats.FStatistic = F_stat;
    stats.CriticalValue = finv(1-alpha, df_num, df_den);
    stats.isCausal = result;
    stats.df_num = df_num;
    stats.df_den = df_den;
    stats.direction = 'x_to_y';  % 简化
    stats.toolbox = 'backup_method';
end

%% 辅助函数：逻辑值转字符串
function str = bool2str(logical_value)
    if logical_value
        str = '是';
    else
        str = '否';
    end
end