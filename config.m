%% 全局参数配置
classdef config
    properties (Constant)
        % === 路径配置 ===
        SAMPLE_PATH = 'E:\20251225\AuNR\0.01';
        BACKGROUND_PATH = 'E:\20251225\空白ito\0.01';
        OUTPUT_BASE = '.\output';
        
        % === 数据参数 ===
        IMAGE_SIZE = [2048, 2048];  % 图像尺寸
        STEP_COUNT = 121;            % M计数
        POSITION_COUNT = 10;        % N位置数（电压点数）
        
        % === 处理参数 ===
        X_RANGE = [-0.6, 0.6];      % x轴范围(mm)
        X_RESOLUTION = 0.01;        % x轴分辨率
        WAVELENGTH_RANGE = [500, 950];  % 分析波长范围(nm)
        
        % === 滤波参数 ===
        DEFAULT_SAMPLE_WIDTH = 0.4;  % 样品滤波宽度
        DEFAULT_REF_WIDTH = 0.25;    % 背景滤波宽度
        GAUSSIAN_ORDER = 2;          % 高斯滤波器阶数
        
        % === FFT参数 ===
        FFT_XAXIS_RANGE = [-5, 5];   % FFT扩展的x轴范围
        FFT_XAXIS_RES = 0.01;        % FFT x轴分辨率
        
        % === 可视化参数 ===
        DEFAULT_COLORMAP = 'jet';
        DEFAULT_FONTSIZE = 12;
        FIGURE_DPI = 300;            % 输出图像DPI
    end
    
    methods (Static)
        function init()
            % 初始化全局设置
            set(0, 'DefaultAxesFontName', 'Arial');
            set(0, 'DefaultTextFontName', 'Arial');
            set(0, 'DefaultLegendFontName', 'Arial');
            set(0, 'DefaultAxesFontSize', config.DEFAULT_FONTSIZE);
            set(0, 'DefaultTextFontSize', config.DEFAULT_FONTSIZE);
            set(0, 'DefaultLegendFontSize', config.DEFAULT_FONTSIZE - 2);
            set(0, 'DefaultLineLineWidth', 1.5);
            set(0, 'DefaultAxesLineWidth', 1.2);
            set(0, 'DefaultAxesTickDir', 'in');
            set(0, 'DefaultAxesBox', 'on');
            
            % 创建输出目录
            if ~exist(config.OUTPUT_BASE, 'dir')
                mkdir(config.OUTPUT_BASE);
                mkdir(fullfile(config.OUTPUT_BASE, 'csv'));
                mkdir(fullfile(config.OUTPUT_BASE, 'figures'));
                mkdir(fullfile(config.OUTPUT_BASE, 'logs'));
            end
        end
    end
end