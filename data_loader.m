classdef data_loader
    methods (Static)
        
        function data = load_images(folder_path, positions, step_count, varargin)
            % 智能加载图像数据，支持流式处理以减少内存占用
            % positions: 位置索引数组
            % step_count: 每个位置的步数
            
            p = inputParser;
            addParameter(p, 'data_type', 'int16', @ischar);
            addParameter(p, 'verbose', true, @islogical);
            addParameter(p, 'load_mode', 'full', @ischar); % 'full', 'preview', 'roi_only'
            addParameter(p, 'step_range', [], @isnumeric); % 指定步数范围，如 [1,50]
            parse(p, varargin{:});

            data_type = p.Results.data_type;
            verbose = p.Results.verbose;
            
            % 获取第一个文件确认尺寸
            test_file = sprintf('TS-%d-1.tif', positions(1));
            test_path = fullfile(folder_path, test_file);
            if ~exist(test_path, 'file')
                error('文件不存在: %s', test_path);
            end
            
            test_img = imread(test_path);
            [h, w] = size(test_img);
            n_positions = length(positions);
            
            % 预分配内存（使用指定类型）
            data = zeros(h, w, step_count, n_positions, data_type);

            % 批量加载
            % 替换原有的批量加载代码（注意保留预分配部分）

            % 确定实际加载的步数范围
            if strcmpi(p.Results.load_mode, 'preview')
                % 预览模式：只加载头尾各10帧和中间1帧
                step_indices = [1:10, round(step_count/2), step_count-9:step_count];
            elseif strcmpi(p.Results.load_mode, 'roi_only')
                % ROI选择模式：只加载中间1帧
                step_indices = round(step_count/2);
            elseif ~isempty(p.Results.step_range)
                % 自定义范围
                step_indices = p.Results.step_range(1):p.Results.step_range(2);
            else
                % 完整模式：加载所有
                step_indices = 1:step_count;
            end

            % 预分配内存（使用实际加载的步数）
            data = zeros(h, w, length(step_indices), n_positions, data_type);

            % 批量加载（修改for循环）
            for pos_idx = 1:n_positions
                pos = positions(pos_idx);
                if verbose
                    fprintf('加载位置 %d/%d (步数: %d)...\n', pos_idx, n_positions, length(step_indices));
                end

                for step_idx = 1:length(step_indices)
                    step = step_indices(step_idx);
                    filename = sprintf('TS-%d-%d.tif', pos, step);
                    filepath = fullfile(folder_path, filename);
                    data(:, :, step_idx, pos_idx) = imread(filepath);
                end
            end

            if verbose
                fprintf('数据加载完成，尺寸: %s\n', mat2str(size(data)));
            end
        end
        
        function avg_data = compute_background_average(background_folder, varargin)
            % 计算背景平均值（可处理多位置平均）
            p = inputParser;
            addParameter(p, 'positions', 1:10, @isnumeric);
            addParameter(p, 'save_path', '', @ischar);
            parse(p, varargin{:});
            
            positions = p.Results.positions;
            save_path = p.Results.save_path;
            
            % 加载所有背景数据
            bg_data = data_loader.load_images(background_folder, positions, ...
                config.STEP_COUNT, 'verbose', false);
            
            % 计算平均值
            avg_data = mean(single(bg_data), 4); % 平均所有位置
            avg_data = int16(avg_data); % 转换回原始类型
            
            % 可选保存
            if ~isempty(save_path)
                save(save_path, 'avg_data');
                fprintf('背景平均值已保存至: %s\n', save_path);
            end
        end
        function roi_intensity = load_roi_intensity(folder_path, positions, step_count, roi_info, varargin)
            % 参数解析...
            % 预分配结果数组（很小！）
            roi_intensity = zeros(step_count, length(positions), size(roi_info, 1));
            
            % 循环读取
            for pos_idx = 1:length(positions)
                for step = 1:step_count
                    % 读取单张图片
                    img = imread(fullfile(folder_path, sprintf('TS-%d-%d.tif', positions(pos_idx), step)));
                    
                    % 提取每个ROI的平均强度
                    for roi_idx = 1:size(roi_info, 1)
                        y_range = roi_info(roi_idx,1):roi_info(roi_idx,2);
                        x_range = roi_info(roi_idx,3):roi_info(roi_idx,4);
                        roi_intensity(step, pos_idx, roi_idx) = mean(img(y_range, x_range), 'all');
                    end
                end
            end
        end
        
    end
end