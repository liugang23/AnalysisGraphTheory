function [valid_data, validation_info] = pairing_data_validator(x_series, y_series, min_valid_obs)
% PAIRING_DATA_VALIDATOR - 精简版配对数据验证器
% 功能: 对配对数据进行最基本的必要验证
% 输入:
%   x_series: 时间序列X
%   y_series: 时间序列Y
%   min_valid_obs: 最小有效观测数
% 输出:
%   valid_data: 结构体，包含验证后的数据
%   validation_info: 验证信息结构体

    % 初始化输出
    validation_info = struct('passed', false, 'message', '', 'n_valid', 0);
    valid_data = struct('x', [], 'y', [], 'n_obs', 0);
    
    %% 1. 基本格式验证
    if ~isnumeric(x_series) || ~isnumeric(y_series)
        validation_info.message = '数据格式无效';
        return;
    end
    
    %% 2. 移除缺失值
    valid_idx = ~isnan(x_series) & ~isnan(y_series);
    x_clean = x_series(valid_idx);
    y_clean = y_series(valid_idx);
    n_valid = length(x_clean);
    
    validation_info.n_valid = n_valid;
    
    %% 3. 检查样本数
    if n_valid < min_valid_obs
        validation_info.message = sprintf('有效观测数不足: %d < %d', n_valid, min_valid_obs);
        return;
    end
    
    %% 4. 检查常数序列
    if std(x_clean) < 1e-10
        validation_info.message = 'X序列为常数';
        return;
    end
    
    if std(y_clean) < 1e-10
        validation_info.message = 'Y序列为常数';
        return;
    end
    
    %% 5. 通过检查
    validation_info.passed = true;
    validation_info.message = sprintf('通过验证，有效观测: %d', n_valid);
    
    valid_data.x = x_clean;
    valid_data.y = y_clean;
    valid_data.n_obs = n_valid;
    
    %% 6. 计算基本统计量
    try
        corr_matrix = corrcoef(x_clean, y_clean, 'Rows', 'complete');
        valid_data.correlation = corr_matrix(1, 2);
    catch
        valid_data.correlation = NaN;
    end
    
    valid_data.std_x = std(x_clean);
    valid_data.std_y = std(y_clean);
    valid_data.mean_x = mean(x_clean);
    valid_data.mean_y = mean(y_clean);
end