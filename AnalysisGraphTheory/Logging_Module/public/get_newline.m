function newline_char = get_newline()
% GET_NEWLINE - 获取安全的换行符字符
% 返回平台无关的换行符，兼容所有 MATLAB 版本
%
% 用法：
%   newline_char = get_newline();
%   str = ['第一行' newline_char '第二行'];
%   str = sprintf('文本%s更多文本', newline_char);
%
% 优点：
% 1. 兼容所有 MATLAB 版本
% 2. 避免内置函数 'newline' 被覆盖的问题
% 3. 返回字符数组，与 sprintf 等函数兼容
% 4. 统一管理换行符，便于维护

    % 返回 ASCII 换行符
    newline_char = char(10);
    
    % 可选：如果需要在 Windows 上使用 \r\n
    % if ispc
    %     newline_char = [char(13) char(10)];  % \r\n
    % else
    %     newline_char = char(10);  % \n
    % end
end