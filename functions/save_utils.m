% save_utils.m
classdef save_utils
    methods (Static)
        function log_message(message, varargin)
            % 记录日志（静态方法）
            p = inputParser;
            addParameter(p, 'level', 'INFO', @ischar);
            parse(p, varargin{:});
            
            level = p.Results.level;
            
            % 确保配置存在
            if ~exist('config', 'class')
                error('请先运行 config.init() 初始化配置');
            end
            
            log_path = fullfile(config.OUTPUT_BASE, 'logs');
            if ~exist(log_path, 'dir')
                mkdir(log_path);
            end
            
            log_file = fullfile(log_path, ['processing_log_', datestr(now, 'yyyymmdd'), '.txt']);
            
            timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            log_entry = sprintf('[%s] %s: %s\n', timestamp, level, message);
            
            fid = fopen(log_file, 'a');
            fprintf(fid, log_entry);
            fclose(fid);
            
            fprintf('%s', log_entry);
        end
        
        function save_to_csv(data, filename, varargin)
            % 保存到CSV（静态方法）
            p = inputParser;
            addParameter(p, 'folder', 'csv', @ischar);
            addParameter(p, 'header', {}, @iscell);
            addParameter(p, 'append', false, @islogical);
            parse(p, varargin{:});
            
            folder = p.Results.folder;
            header = p.Results.header;
            append_mode = p.Results.append;
            
            output_path = fullfile(config.OUTPUT_BASE, folder);
            if ~exist(output_path, 'dir')
                mkdir(output_path);
            end
            
            full_filename = fullfile(output_path, [filename, '.csv']);
            
            if append_mode && exist(full_filename, 'file')
                dlmwrite(full_filename, data, '-append');
            else
                if ~isempty(header)
                    fid = fopen(full_filename, 'w');
                    fprintf(fid, '%s,', header{1:end-1});
                    fprintf(fid, '%s\n', header{end});
                    fclose(fid);
                    dlmwrite(full_filename, data, '-append');
                else
                    writematrix(data, full_filename);
                end
            end
            
            fprintf('数据已保存: %s\n', full_filename);
        end
        
        function save_figure(fig_handle, filename, varargin)
            % 保存图像（静态方法）
            p = inputParser;
            addParameter(p, 'folder', 'figures', @ischar);
            addParameter(p, 'format', 'png', @ischar);
            addParameter(p, 'dpi', 300, @isnumeric);
            parse(p, varargin{:});
            
            folder = p.Results.folder;
            format = p.Results.format;
            dpi = p.Results.dpi;
            
            output_path = fullfile(config.OUTPUT_BASE, folder);
            if ~exist(output_path, 'dir')
                mkdir(output_path);
            end
            
            full_filename = fullfile(output_path, [filename, '.', format]);
            
            switch format
                case 'png'
                    print(fig_handle, full_filename, '-dpng', sprintf('-r%d', dpi));
                case 'pdf'
                    print(fig_handle, full_filename, '-dpdf', '-bestfit');
                case 'fig'
                    savefig(fig_handle, full_filename);
                otherwise
                    saveas(fig_handle, full_filename);
            end
            
            fprintf('图像已保存: %s\n', full_filename);
        end
    end
end