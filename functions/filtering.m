function [filtered_data, filter_params] = filtering(interference_data, varargin)
    % 高斯滤波处理
    % 输入:
    %   interference_data - 干涉强度数据
    % 输出:
    %   filtered_data - 滤波后的数据
    %   filter_params - 滤波器参数
    
    p = inputParser;
    addParameter(p, 'filter_width', config.DEFAULT_SAMPLE_WIDTH, @isnumeric);
    addParameter(p, 'filter_type', 'gaussian', @ischar);
    addParameter(p, 'x_range', config.X_RANGE, @isnumeric);
    addParameter(p, 'x_resolution', config.X_RESOLUTION, @isnumeric);
    addParameter(p, 'detrend_data', true, @islogical);
    addParameter(p, 'confirm_before_proceed', true, @islogical);
    parse(p, varargin{:});
    
    filter_width = p.Results.filter_width;
    filter_type = p.Results.filter_type;
    x_range = p.Results.x_range;
    x_resolution = p.Results.x_resolution;
    detrend_data = p.Results.detrend_data;
    need_confirm = p.Results.confirm_before_proceed;
    
    % 生成x轴
    x = x_range(1):x_resolution:x_range(2);
    
    % 准备数据
    if detrend_data
        interference_data = detrend(interference_data);
    end
    
    % 扩展x轴用于滤波
    xaxis_extended = config.FFT_XAXIS_RANGE(1):config.FFT_XAXIS_RES:config.FFT_XAXIS_RANGE(2);
    data_extended = zeros(size(xaxis_extended));
    
    % 将数据放到扩展轴上
    idx_start = find(xaxis_extended >= x_range(1), 1);
    idx_end = find(xaxis_extended <= x_range(2), 1, 'last');
    
    if length(interference_data) ~= (idx_end - idx_start + 1)
        % 需要插值
        interference_data_interp = interp1(x, interference_data, ...
            xaxis_extended(idx_start:idx_end), 'linear', 'extrap');
        data_extended(idx_start:idx_end) = interference_data_interp;
    else
        data_extended(idx_start:idx_end) = interference_data;
    end
    
    % 创建滤波器
    [~, maxpos] = max(data_extended);
    x0 = xaxis_extended(maxpos);
    
    % 高斯滤波器函数
    gaussian_filter = @(x, x0, width, n) exp(-log(2)*(2*(x-x0)/width).^(2*abs(floor(n))));
    
    filter_response = gaussian_filter(xaxis_extended, x0, filter_width, config.GAUSSIAN_ORDER);
    
    % 应用滤波器
    filtered_data_extended = filter_response .* detrend(data_extended);
    
    % 裁剪回原始范围
    filtered_data = filtered_data_extended(idx_start:idx_end);
    
    % 保存滤波器参数
    filter_params.x0 = x0;
    filter_params.width = filter_width;
    filter_params.filter_response = filter_response(idx_start:idx_end);
    filter_params.xaxis = xaxis_extended(idx_start:idx_end);
    
    % 如果需要确认，显示滤波结果
    if need_confirm
        plot_filtering_results(x, interference_data, filtered_data, ...
            filter_params.filter_response, filter_width);
        
        response = input('是否继续处理？(y/n): ', 's');
        if ~strcmpi(response, 'y')
            error('用户取消处理');
        end
    end
end

function plot_filtering_results(x, original_data, filtered_data, filter_response, width)
    % 绘制滤波结果
    fig = figure('Position', [100, 100, 1200, 500]);
    
    % 左图：原始和滤波后数据
    subplot(1, 2, 1);
    yyaxis left;
    plot(x, original_data, 'b-', 'LineWidth', 1.5, 'DisplayName', '原始数据');
    hold on;
    plot(x, filtered_data, 'r-', 'LineWidth', 2, 'DisplayName', '滤波后数据');
    ylabel('强度 (a.u.)');
    xlabel('x (mm)');
    legend('show', 'Location', 'best');
    title(sprintf('滤波处理 (宽度=%.2f)', width));
    grid on;
    
    yyaxis right;
    plot(x, filter_response, 'g--', 'LineWidth', 1.5, 'DisplayName', '滤波器');
    ylabel('滤波器响应');
    ylim([-0.1, 1.1]);
    
    % 右图：滤波器形状
    subplot(1, 2, 2);
    plot(x, filter_response, 'g-', 'LineWidth', 2);
    xlabel('x (mm)');
    ylabel('滤波器响应');
    title('高斯滤波器形状');
    grid on;
    ylim([0, 1.1]);
    
    sgtitle('滤波处理结果', 'FontSize', 16);
end