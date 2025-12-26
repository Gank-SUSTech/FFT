function [spectrum, wavelength, fft_params] = fft_analysis(filtered_data, varargin)
    % FFT分析获取光谱数据
    % 输入:
    %   filtered_data - 滤波后的干涉强度
    % 输出:
    %   spectrum - 光谱强度
    %   wavelength - 波长轴
    %   fft_params - FFT参数
    
    p = inputParser;
    addParameter(p, 'x_range', config.X_RANGE, @isnumeric);
    addParameter(p, 'x_resolution', config.X_RESOLUTION, @isnumeric);
    addParameter(p, 'fft_method', 'standard', @ischar); % 'standard' 或 'zeropad'
    addParameter(p, 'zeropad_factor', 4, @isnumeric);
    addParameter(p, 'wavelength_range', config.WAVELENGTH_RANGE, @isnumeric);
    addParameter(p, 'calibration_params', struct(), @isstruct);
    addParameter(p, 'confirm_before_proceed', true, @islogical);
    parse(p, varargin{:});
    
    x_range = p.Results.x_range;
    x_resolution = p.Results.x_resolution;
    fft_method = p.Results.fft_method;
    zeropad_factor = p.Results.zeropad_factor;
    wavelength_range = p.Results.wavelength_range;
    calibration = p.Results.calibration_params;
    need_confirm = p.Results.confirm_before_proceed;
    
    % 生成x轴
    x = x_range(1):x_resolution:x_range(2);
    N = length(x);
    
    % 零填充（如果需要）
    if strcmpi(fft_method, 'zeropad') && zeropad_factor > 1
        N_fft = N * zeropad_factor;
        data_padded = [filtered_data; zeros(N_fft - N, 1)];
    else
        N_fft = N;
        data_padded = filtered_data;
    end
    
    % FFT计算
    dx = x_resolution;
    Dsf = 1/dx;
    dsf = Dsf / N_fft;
    
    % 频率轴
    spatialfreq = (-N_fft/2 : N_fft/2-1)' * dsf;
    
    % 频率到波长的校准（使用您的校准公式或提供默认）
    if isempty(fieldnames(calibration))
        % 默认校准（来自您的代码）
        freqx = 0.01494 .* spatialfreq - 2.95e-5 .* spatialfreq.^2 + 0.004467;
    else
        % 使用提供的校准参数
        freqx = calibration.a .* spatialfreq + calibration.b .* spatialfreq.^2 + calibration.c;
    end
    
    % 处理零频
    [~, zero_idx] = min(abs(freqx));
    freqx(zero_idx) = 0;
    
    % 计算波长
    wavelength = 300 ./ freqx;
    
    % FFT变换
    fft_raw = abs(fftshift(fft(ifftshift(data_padded))));
    
    % 波长单位转换
    spectrum = fft_raw .* 300 ./ (wavelength.^2);
    
    % 限制波长范围
    valid_idx = (wavelength >= wavelength_range(1)) & (wavelength <= wavelength_range(2));
    wavelength = wavelength(valid_idx);
    spectrum = spectrum(valid_idx);
    
    % 保存参数
    fft_params.N = N;
    fft_params.N_fft = N_fft;
    fft_params.dx = dx;
    fft_params.spatialfreq = spatialfreq;
    fft_params.freqx = freqx;
    
    % 如果需要确认，显示光谱
    if need_confirm
        plot_spectrum_results(wavelength, spectrum);
        
        response = input('是否继续处理？(y/n): ', 's');
        if ~strcmpi(response, 'y')
            error('用户取消处理');
        end
    end
end

function plot_spectrum_results(wavelength, spectrum)
    % 绘制光谱结果
    fig = figure('Position', [100, 100, 1000, 600]);
    
    % 主图：光谱
    subplot(2, 1, 1);
    plot(wavelength, spectrum, 'b-', 'LineWidth', 2);
    xlabel('波长 (nm)');
    ylabel('强度 (a.u.)');
    title('FFT光谱分析结果');
    grid on;
    xlim([min(wavelength), max(wavelength)]);
    
    % 找到峰值
    [peak_val, peak_idx] = max(spectrum);
    peak_wl = wavelength(peak_idx);
    
    hold on;
    plot(peak_wl, peak_val, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
    text(peak_wl, peak_val*1.05, sprintf('峰值: %.1f nm', peak_wl), ...
        'HorizontalAlignment', 'center', 'FontSize', 12);
    
    % 计算半高宽
    half_max = peak_val / 2;
    left_idx = find(spectrum(1:peak_idx) <= half_max, 1, 'last');
    right_idx = find(spectrum(peak_idx:end) <= half_max, 1, 'first') + peak_idx - 1;
    
    if ~isempty(left_idx) && ~isempty(right_idx)
        fwhm = wavelength(right_idx) - wavelength(left_idx);
        line([wavelength(left_idx), wavelength(right_idx)], [half_max, half_max], ...
            'Color', 'r', 'LineStyle', '--', 'LineWidth', 1.5);
        text(mean([wavelength(left_idx), wavelength(right_idx)]), half_max*0.9, ...
            sprintf('FWHM: %.1f nm', fwhm), 'HorizontalAlignment', 'center', 'FontSize', 12);
    end
    
    % 子图：对数坐标
    subplot(2, 1, 2);
    semilogy(wavelength, spectrum, 'b-', 'LineWidth', 1.5);
    xlabel('波长 (nm)');
    ylabel('强度 (对数)');
    title('对数坐标光谱');
    grid on;
    xlim([min(wavelength), max(wavelength)]);
    
    sgtitle('FFT光谱分析', 'FontSize', 16);
end