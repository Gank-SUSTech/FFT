function main_controller(varargin)
    % 主控制器：协调整个处理流程
    addpath('functions');
    % 初始化配置
    config.init();
    
    % 解析输入参数
    p = inputParser;
    addParameter(p, 'sample_folder', config.SAMPLE_PATH, @ischar);
    addParameter(p, 'background_folder', config.BACKGROUND_PATH, @ischar);
    addParameter(p, 'positions', 1:config.POSITION_COUNT, @isnumeric);
    addParameter(p, 'roi_mode', 'manual', @ischar); % manual, auto, load
    addParameter(p, 'roi_file', '', @ischar);
    addParameter(p, 'skip_preprocess', false, @islogical);
    addParameter(p, 'skip_filtering', false, @islogical);
    addParameter(p, 'skip_fft', false, @islogical);
    addParameter(p, 'batch_mode', false, @islogical);
    parse(p, varargin{:});
    
    % 记录开始
    save_utils.log_message('处理流程开始', 'level', 'INFO');
    
    try
        % === 阶段1: ROI选择 ===
        if ~p.Results.skip_preprocess || p.Results.batch_mode
            save_utils.log_message('开始选择ROI区域...');
            
            % 判断是否已有ROI文件
            if ~isempty(p.Results.roi_file) && exist(p.Results.roi_file, 'file')
                % 加载已有ROI文件
                load(p.Results.roi_file, 'roi_info');
                save_utils.log_message(sprintf('从文件加载ROI: %s', p.Results.roi_file), 'level', 'INFO');
            else
                % === 步骤1: 加载预览图像用于ROI选择 ===
                save_utils.log_message('加载预览图像用于ROI选择...');
                
                % 只加载少量预览图像（如中间1帧）
                preview_step = round(config.STEP_COUNT/2);
                preview_sample = data_loader.load_images(...
                    p.Results.sample_folder, ...
                    p.Results.positions(1), ...  % 只加载第一个位置用于ROI选择
                    1, ...  % 只加载1帧
                    'step_range', [preview_step, preview_step], ...
                    'verbose', true);

                % === 步骤2: 手动选择ROI ===
                [roi_info, preview_image] = preprocess(...
                    preview_sample, ...
                    'existing_roi', load_existing_roi(p.Results.roi_file), ...
                    'reference_frame', 1, ... 
                    'confirm_before_proceed', true);
            end
            
            % 保存ROI信息（可选）
            if ~isempty(p.Results.roi_file) && isempty(dir(p.Results.roi_file))
                save(p.Results.roi_file, 'roi_info');
                save_utils.log_message(sprintf('ROI信息已保存至: %s', p.Results.roi_file), 'level', 'INFO');
            end
        else
            save_utils.log_message('跳过ROI选择步骤');
        end
        
        % === 阶段2: 数据加载与处理 ===
        if ~p.Results.skip_preprocess
            save_utils.log_message('开始加载和处理数据...');
            
            % === 步骤3: 按ROI加载完整数据 ===
            % 样品数据
            sample_intensity = data_loader.load_roi_intensity(...
                p.Results.sample_folder, ...
                p.Results.positions, ...
                config.STEP_COUNT, ...
                roi_info, ...
                'verbose', true);
            
            % 背景数据
            if ~isempty(p.Results.background_folder) && exist(p.Results.background_folder, 'dir')
                background_intensity = data_loader.load_roi_intensity(...
                    p.Results.background_folder, ...
                    p.Results.positions, ...
                    config.STEP_COUNT, ...
                    roi_info, ...
                    'verbose', true);
            else
                save_utils.log_message('未找到背景文件夹，跳过背景处理', 'level', 'WARNING');
                background_intensity = ones(size(sample_intensity)); % 使用单位矩阵作为背景
            end
            
            % 保存干涉强度数据
            if ~p.Results.batch_mode
                save_interference_data(sample_intensity, background_intensity, 'preprocess');
            end
        else
            save_utils.log_message('跳过数据加载和处理步骤');
        end
        
        % === 阶段3: 滤波处理 ===
        if ~p.Results.skip_filtering && ~p.Results.skip_preprocess
            save_utils.log_message('开始滤波处理...');
            
            % 检查数据是否已加载
            if ~exist('sample_intensity', 'var') || ~exist('background_intensity', 'var')
                error('数据未加载，请确保 skip_preprocess 为 false');
            end
            
            % 样品滤波
            [filtered_sample, sample_filter_params] = filtering(...
                sample_intensity, ...
                'filter_width', config.DEFAULT_SAMPLE_WIDTH, ...
                'confirm_before_proceed', true);
            
            % 背景滤波
            [filtered_background, background_filter_params] = filtering(...
                background_intensity, ...
                'filter_width', config.DEFAULT_REF_WIDTH, ...
                'confirm_before_proceed', false);
            
            % 保存滤波后数据
            if ~p.Results.batch_mode
                save_interference_data(filtered_sample, filtered_background, 'filtered');
            end
        else
            save_utils.log_message('跳过滤波步骤');
        end
        
        % === 阶段4: FFT分析 ===
        if ~p.Results.skip_fft && ~p.Results.skip_filtering && ~p.Results.skip_preprocess
            save_utils.log_message('开始FFT分析...');
            
            % 检查数据是否已处理
            if ~exist('filtered_sample', 'var') || ~exist('filtered_background', 'var')
                error('数据未滤波，请确保 skip_filtering 为 false');
            end
            
            % 样品FFT
            [sample_spectrum, wavelength, sample_fft_params] = fft_analysis(...
                filtered_sample, ...
                'confirm_before_proceed', true);
            
            % 背景FFT
            [background_spectrum, ~, background_fft_params] = fft_analysis(...
                filtered_background, ...
                'confirm_before_proceed', false);
            
            % 计算散射光谱（样品/背景）
            scattering_spectrum = sample_spectrum ./ background_spectrum;
            
            % 保存光谱数据
            save_spectrum_data(wavelength, sample_spectrum, background_spectrum, scattering_spectrum);
            
            % 显示最终结果
            plot_final_results(wavelength, sample_spectrum, background_spectrum, scattering_spectrum);
        else
            save_utils.log_message('跳过FFT分析步骤');
        end
        
        % === 批处理模式 ===
        if p.Results.batch_mode
            save_utils.log_message('进入批处理模式...');
            
            % 确保有ROI信息
            if ~exist('roi_info', 'var')
                error('批处理模式需要ROI信息，请确保 skip_preprocess 为 false');
            end
            
            batch_processor(p.Results.sample_folder, p.Results.background_folder, ...
                roi_info, p.Results.positions);
        end
        
        save_utils.log_message('处理流程完成！', 'level', 'INFO');
        
    catch ME
        save_utils.log_message(sprintf('处理失败: %s', ME.message), 'level', 'ERROR');
        rethrow(ME);
    end
end

function roi = load_existing_roi(roi_file)
    % 加载已有ROI
    if ~isempty(roi_file) && exist(roi_file, 'file')
        load(roi_file, 'roi');
    else
        roi = [];
    end
end

function save_interference_data(sample_data, background_data, suffix)
    % 保存干涉强度数据
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    
    % 样品数据
    if ndims(sample_data) == 2
        header = {'Step', 'Intensity'};
        data_to_save = [(1:size(sample_data,1))', sample_data];
    else
        % 多维数据
        data_to_save = sample_data;
        header = {};
    end
    
    save_utils.save_to_csv(data_to_save, ...
        sprintf('sample_interference_%s_%s', suffix, timestamp), ...
        'header', header);
    
    % 背景数据
    if ndims(background_data) == 2
        data_to_save = [(1:size(background_data,1))', background_data];
    else
        data_to_save = background_data;
    end
    
    save_utils.save_to_csv(data_to_save, ...
        sprintf('background_interference_%s_%s', suffix, timestamp), ...
        'header', header);
end

function save_spectrum_data(wavelength, sample_spectrum, background_spectrum, scattering_spectrum)
    % 保存光谱数据
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    
    data_matrix = [wavelength(:), sample_spectrum(:), background_spectrum(:), scattering_spectrum(:)];
    header = {'Wavelength_nm', 'Sample_Spectrum', 'Background_Spectrum', 'Scattering_Spectrum'};
    
    save_utils.save_to_csv(data_matrix, ...
        sprintf('spectrum_data_%s', timestamp), ...
        'header', header);
end

function plot_final_results(wavelength, sample_spectrum, background_spectrum, scattering_spectrum)
    % 绘制最终结果
    fig = figure('Position', [100, 100, 1200, 800]);
    
    % 子图1: 原始光谱
    subplot(2, 2, 1);
    plot(wavelength, sample_spectrum, 'b-', 'LineWidth', 2, 'DisplayName', '样品');
    hold on;
    plot(wavelength, background_spectrum, 'r-', 'LineWidth', 2, 'DisplayName', '背景');
    xlabel('波长 (nm)');
    ylabel('强度 (a.u.)');
    title('原始光谱');
    legend('show', 'Location', 'best');
    grid on;
    xlim([min(wavelength), max(wavelength)]);
    
    % 子图2: 散射光谱
    subplot(2, 2, 2);
    plot(wavelength, scattering_spectrum, 'g-', 'LineWidth', 2);
    xlabel('波长 (nm)');
    ylabel('散射强度 (样品/背景)');
    title('散射光谱');
    grid on;
    xlim([min(wavelength), max(wavelength)]);
    
    % 子图3: 归一化光谱
    subplot(2, 2, 3);
    sample_norm = sample_spectrum / max(sample_spectrum);
    background_norm = background_spectrum / max(background_spectrum);
    scattering_norm = scattering_spectrum / max(scattering_spectrum);
    
    plot(wavelength, sample_norm, 'b-', 'LineWidth', 1.5, 'DisplayName', '样品(归一化)');
    hold on;
    plot(wavelength, background_norm, 'r-', 'LineWidth', 1.5, 'DisplayName', '背景(归一化)');
    plot(wavelength, scattering_norm, 'g-', 'LineWidth', 2, 'DisplayName', '散射(归一化)');
    xlabel('波长 (nm)');
    ylabel('归一化强度');
    title('归一化光谱');
    legend('show', 'Location', 'best');
    grid on;
    xlim([min(wavelength), max(wavelength)]);
    ylim([0, 1.2]);
    
    % 子图4: 峰值统计
    subplot(2, 2, 4);
    [~, sample_peak_idx] = max(sample_spectrum);
    sample_peak_wl = wavelength(sample_peak_idx);
    
    [~, scattering_peak_idx] = max(scattering_spectrum);
    scattering_peak_wl = wavelength(scattering_peak_idx);
    
    bar_data = [sample_peak_wl, scattering_peak_wl];
    bar(1:2, bar_data);
    ylabel('峰值波长 (nm)');
    set(gca, 'XTickLabel', {'样品峰值', '散射峰值'});
    title('峰值波长统计');
    grid on;
    
    % 添加数值标签
    text(1, bar_data(1), sprintf('%.1f nm', bar_data(1)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 12);
    text(2, bar_data(2), sprintf('%.1f nm', bar_data(2)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 12);
    
    sgtitle('最终分析结果', 'FontSize', 16);
    
    % 保存图像
    save_utils.save_figure(fig, 'final_results', 'format', 'png', 'dpi', 300);
end