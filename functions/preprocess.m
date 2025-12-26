function [roi_info, preview_image] = preprocess(image_data, varargin)
    % 预处理：仅用于ROI选择
    % 输入:
    %   image_data - 图像数据（4D: height×width×step×position）
    % 输出:
    %   roi_info - ROI坐标信息 [y_start, y_end, x_start, x_end]
    %   preview_image - 预览图像（用于显示）
    
    p = inputParser;
    addParameter(p, 'existing_roi', [], @isnumeric); % 已有ROI坐标
    addParameter(p, 'reference_frame', 50, @isnumeric); % 用于显示和选择的帧
    addParameter(p, 'confirm_before_proceed', true, @islogical); % 是否需要确认
    parse(p, varargin{:});
    
    existing_roi = p.Results.existing_roi;
    reference_frame = p.Results.reference_frame;
    need_confirm = p.Results.confirm_before_proceed;
    
    % 如果不需要确认且已有ROI，直接返回
    if ~need_confirm && ~isempty(existing_roi)
        roi_info = existing_roi;
        % 创建简单的预览图像
        if ndims(image_data) == 4
            preview_image = squeeze(image_data(:,:,reference_frame,1));
        else
            preview_image = squeeze(image_data(:,:,reference_frame));
        end
        return;
    end
    
    % 显示图像供ROI选择
    fig = figure('Position', [100, 100, 1200, 800]);
    if ndims(image_data) == 4
        % 使用第一个位置和指定帧
        preview_image = squeeze(image_data(:,:,reference_frame,1));
    else
        preview_image = squeeze(image_data(:,:,reference_frame));
    end
    
    imagesc(preview_image);
    colormap(config.DEFAULT_COLORMAP);
    colorbar;
    axis equal;
    title('选择感兴趣区域 (ROI)', 'FontSize', 14);
    
    % 手动选择ROI
    roi_info = select_roi_manually(fig);
    
    close(fig);
    
    % 如果需要确认，显示选择的ROI位置
    if need_confirm && ~isempty(roi_info)
        confirm_roi_selection(preview_image, roi_info);
        
        response = input('是否继续处理？(y/n): ', 's');
        if ~strcmpi(response, 'y')
            error('用户取消处理');
        end
    end
end

function roi_info = select_roi_manually(fig_handle)
    % 手动选择ROI
    figure(fig_handle);
    
    % 支持多区域选择
    roi_count = 0;
    roi_info = [];
    
    disp('选择ROI区域:');
    disp('1. 点击并拖动创建矩形');
    disp('2. 双击矩形确认选择');
    disp('3. 按ESC结束选择');
    
    while true
        try
            roi = drawrectangle('Color', 'r', 'LineWidth', 2);
            wait(roi);
            
            % 获取ROI坐标
            pos = roi.Position;
            x_start = round(pos(1));
            y_start = round(pos(2));
            width = round(pos(3));
            height = round(pos(4));
            
            roi_info = [roi_info; y_start, y_start+height, x_start, x_start+width];
            roi_count = roi_count + 1;
            
            fprintf('已选择第 %d 个区域: [y:%d-%d, x:%d-%d]\n', ...
                roi_count, y_start, y_start+height, x_start, x_start+width);
            
            % 将矩形颜色改为黄色表示已确认
            roi.Color = 'y';
            
        catch
            break;
        end
    end
    
    if roi_count == 0
        error('未选择任何ROI区域');
    end
end

function confirm_roi_selection(preview_image, roi_info)
    % 显示选择的ROI位置用于确认
    fig = figure('Position', [100, 100, 1000, 500]);
    
    % 左图：原始图像
    subplot(1, 2, 1);
    imagesc(preview_image);
    colormap(config.DEFAULT_COLORMAP);
    colorbar;
    axis equal;
    title('原始图像');
    
    % 右图：带ROI标记的图像
    subplot(1, 2, 2);
    imagesc(preview_image);
    colormap(config.DEFAULT_COLORMAP);
    hold on;
    
    % 绘制所有ROI边界
    for i = 1:size(roi_info, 1)
        y1 = roi_info(i, 1);
        y2 = roi_info(i, 2);
        x1 = roi_info(i, 3);
        x2 = roi_info(i, 4);
        
        % 绘制矩形
        rectangle('Position', [x1, y1, x2-x1, y2-y1], ...
                  'EdgeColor', 'r', 'LineWidth', 2, 'LineStyle', '--');
        % 标记ROI编号
        text(mean([x1, x2]), mean([y1, y2]), sprintf('ROI %d', i), ...
             'Color', 'r', 'FontSize', 12, 'FontWeight', 'bold', ...
             'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
    end
    
    axis equal;
    title(sprintf('选择的ROI区域（共%d个）', size(roi_info, 1)));
    
    % 显示ROI坐标信息
    fprintf('\n选择的ROI区域坐标：\n');
    for i = 1:size(roi_info, 1)
        fprintf('ROI %d: [y:%d-%d, x:%d-%d]\n', ...
                i, roi_info(i,1), roi_info(i,2), roi_info(i,3), roi_info(i,4));
    end
    
    sgtitle('ROI选择确认', 'FontSize', 16);
end