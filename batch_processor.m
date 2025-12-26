function batch_processor(sample_folder, background_folder, roi_info, positions)
    % 批处理所有位置（电压点）
    
    n_positions = length(positions);
    n_rois = size(roi_info, 1);
    
    % 预分配结果数组
    all_peak_wavelengths = zeros(n_rois, n_positions);
    all_fwhm = zeros(n_rois, n_positions);
    all_spectra = cell(n_rois, n_positions);
    
    % 滤波宽度列表（根据您的需求配置）
    width_sam_list = zeros(1, n_positions);
    width_sam_list(1:5) = 0.40;
    width_sam_list(6:10) = 0.35;
    width_sam_list(11:end) = 0.30;
    
    % === 一次性加载所有位置的ROI数据 ===
    save_utils.log_message('开始加载所有位置的ROI数据...', 'level', 'INFO');
    
    % 加载样品所有位置的ROI数据
    sample_intensity_all = data_loader.load_roi_intensity(...
        sample_folder, ...
        positions, ...
        config.STEP_COUNT, ...
        roi_info, ...
        'verbose', true);
    
    % 加载背景所有位置的ROI数据
    background_intensity_all = data_loader.load_roi_intensity(...
        background_folder, ...
        positions, ...
        config.STEP_COUNT, ...
        roi_info, ...
        'verbose', true);
    
    % 检查数据维度
    % sample_intensity_all 维度: [steps, positions, rois]
    
    % 处理每个位置
    for pos_idx = 1:n_positions
        fprintf('处理位置 %d/%d...\n', pos_idx, n_positions);
        
        % 处理每个ROI
        for roi_idx = 1:n_rois
            % 直接从已加载的数据中提取当前ROI和位置的数据
            sample_intensity = squeeze(sample_intensity_all(:, pos_idx, roi_idx));
            background_intensity = squeeze(background_intensity_all(:, pos_idx, roi_idx));
            
            % 滤波（使用动态宽度）
            [filtered_sample, ~] = filtering(...
                sample_intensity, ...
                'filter_width', width_sam_list(pos_idx), ...
                'confirm_before_proceed', false);
            
            [filtered_background, ~] = filtering(...
                background_intensity, ...
                'filter_width', config.DEFAULT_REF_WIDTH, ...
                'confirm_before_proceed', false);
            
            % FFT分析
            [sample_spectrum, wavelength, ~] = fft_analysis(...
                filtered_sample, ...
                'confirm_before_proceed', false);
            
            [background_spectrum, ~, ~] = fft_analysis(...
                filtered_background, ...
                'confirm_before_proceed', false);
            
            % 计算散射光谱
            scattering_spectrum = sample_spectrum ./ background_spectrum;
            all_spectra{roi_idx, pos_idx} = scattering_spectrum;
            
            % 计算峰值和半高宽
            [peak_val, peak_idx] = max(scattering_spectrum);
            all_peak_wavelengths(roi_idx, pos_idx) = wavelength(peak_idx);
            
            % 计算FWHM
            all_fwhm(roi_idx, pos_idx) = calculate_fwhm(wavelength, scattering_spectrum);
        end
    end
    
    % 保存批处理结果
    save_batch_results(positions, all_peak_wavelengths, all_fwhm, all_spectra, wavelength);
    
    % 绘制批处理汇总图
    plot_batch_summary(positions, all_peak_wavelengths, all_fwhm, roi_info);
    
    save_utils.log_message('批处理完成！', 'level', 'INFO');
end

function fwhm = calculate_fwhm(wavelength, spectrum)
    % 计算半高宽
    [peak_val, peak_idx] = max(spectrum);
    half_max = peak_val / 2;
    
    % 找到左半高宽点
    left_idx = find(spectrum(1:peak_idx) <= half_max, 1, 'last');
    if isempty(left_idx)
        left_wl = wavelength(1);
    else
        left_wl = wavelength(left_idx);
    end
    
    % 找到右半高宽点
    right_idx = find(spectrum(peak_idx:end) <= half_max, 1, 'first') + peak_idx - 1;
    if isempty(right_idx)
        right_wl = wavelength(end);
    else
        right_wl = wavelength(right_idx);
    end
    
    fwhm = right_wl - left_wl;
end

function save_batch_results(positions, peak_wavelengths, fwhm_values, spectra, wavelength)
    % 保存批处理结果
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    
    % 保存峰值波长
    header = ['Position', arrayfun(@(x) sprintf('ROI_%d', x), 1:size(peak_wavelengths,1), 'UniformOutput', false)];
    data_matrix = [positions(:), peak_wavelengths'];
    save_utils.save_to_csv(data_matrix, ...
        sprintf('batch_peak_wavelengths_%s', timestamp), ...
        'header', header);
    
    % 保存FWHM
    data_matrix = [positions(:), fwhm_values'];
    save_utils.save_to_csv(data_matrix, ...
        sprintf('batch_fwhm_%s', timestamp), ...
        'header', header);
    
    % 保存所有光谱数据（每个ROI单独文件）
    for roi_idx = 1:size(spectra, 1)
        roi_spectra = zeros(length(wavelength), size(spectra, 2));
        
        for pos_idx = 1:size(spectra, 2)
            roi_spectra(:, pos_idx) = spectra{roi_idx, pos_idx};
        end
        
        data_matrix = [wavelength(:), roi_spectra];
        pos_header = arrayfun(@(x) sprintf('Pos_%d', x), positions, 'UniformOutput', false);
        header = ['Wavelength_nm', pos_header];
        
        save_utils.save_to_csv(data_matrix, ...
            sprintf('batch_spectra_ROI%d_%s', roi_idx, timestamp), ...
            'header', header);
    end
end

function plot_batch_summary(positions, peak_wavelengths, fwhm_values, roi_info)
    % 绘制批处理汇总图
    
    n_rois = size(peak_wavelengths, 1);
    colors = lines(n_rois);
    
    % 图1: 峰值波长 vs 位置
    fig1 = figure('Position', [100, 100, 1000, 800]);
    subplot(2, 2, 1);
    hold on;
    for roi_idx = 1:n_rois
        plot(positions, peak_wavelengths(roi_idx, :), 'o-', ...
            'Color', colors(roi_idx, :), 'LineWidth', 1.5, 'MarkerSize', 6, ...
            'DisplayName', sprintf('ROI %d', roi_idx));
    end
    xlabel('位置/电压');
    ylabel('峰值波长 (nm)');
    title('峰值波长 vs 位置');
    legend('show', 'Location', 'best', 'NumColumns', 2);
    grid on;
    
    % 图2: FWHM vs 位置
    subplot(2, 2, 2);
    hold on;
    for roi_idx = 1:n_rois
        plot(positions, fwhm_values(roi_idx, :), 's--', ...
            'Color', colors(roi_idx, :), 'LineWidth', 1.5, 'MarkerSize', 6, ...
            'DisplayName', sprintf('ROI %d', roi_idx));
    end
    xlabel('位置/电压');
    ylabel('半高宽 (nm)');
    title('半高宽 vs 位置');
    legend('show', 'Location', 'best', 'NumColumns', 2);
    grid on;
    
    % 图3: 相对变化率（波长）
    subplot(2, 2, 3);
    hold on;
    for roi_idx = 1:n_rois
        relative_change = (peak_wavelengths(roi_idx, :) - peak_wavelengths(roi_idx, 1)) ...
            ./ peak_wavelengths(roi_idx, 1) * 100;
        plot(positions, relative_change, 'd-', ...
            'Color', colors(roi_idx, :), 'LineWidth', 1.5, 'MarkerSize', 6, ...
            'DisplayName', sprintf('ROI %d', roi_idx));
    end
    xlabel('位置/电压');
    ylabel('相对变化率 (%)');
    title('波长相对变化率');
    legend('show', 'Location', 'best', 'NumColumns', 2);
    grid on;
    
    % 图4: ROI位置示意图
    subplot(2, 2, 4);
    % 这里可以添加ROI位置示意图
    text(0.5, 0.5, sprintf('共选择了 %d 个ROI区域', n_rois), ...
        'HorizontalAlignment', 'center', 'FontSize', 14);
    axis off;
    title('ROI区域统计');
    
    sgtitle('批处理结果汇总', 'FontSize', 16);
    
    % 保存图像
    save_utils.save_figure(fig1, 'batch_summary', 'format', 'png', 'dpi', 300);
end