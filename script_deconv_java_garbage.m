%% SCRIPT DE DECONVOLUCIÓN - COMPATIBLE MULTIPLATAFORMA (MAC/LINUX/WIN)
% Optimizado para 34GB RAM y grandes dimensiones
clear; clc; close all;

%% 1. ⚙️ CONFIGURACIÓN
INPUT_DIR = select_directory('Selecciona carpeta de imágenes');
if isempty(INPUT_DIR), return; end

PSF_DIR = select_directory('Selecciona carpeta de PSFs');
if isempty(PSF_DIR), return; end

try
    [NUM_CHANNELS, PSF_NAMES_MAP] = get_macro_parameters_matlab();
catch, return; end

OUTPUT_DIR = fullfile(INPUT_DIR, 'Deconvolved_RL_MATLAB');
if ~exist(OUTPUT_DIR, 'dir'), mkdir(OUTPUT_DIR); end

ITERATIONS = 5; 

%% 2. 🔬 BUCLE DE PROCESAMIENTO
for c = 1:NUM_CHANNELS
    psf_file_name = PSF_NAMES_MAP(c);
    channel_prefix = ['C' num2str(c) '-'];
    
    psf_path = fullfile(PSF_DIR, psf_file_name);
    if ~exist(psf_path, 'file'), continue; end
    
    % Carga PSF original
    psf_img_original = double(tiffreadVolume(psf_path));
    
    image_list = dir(fullfile(INPUT_DIR, [channel_prefix '*.tif']));
    total_images = length(image_list);
    
    for i = 1:total_images
        fprintf('\n--- [%d/%d] Canal %d | Procesando... ---\n', i, total_images, c);
        
        filename = image_list(i).name;
        img_path = fullfile(INPUT_DIR, filename);
        
        try
            % 1. CARGA Y CONVERSIÓN INMEDIATA
            temp_vol = tiffreadVolume(img_path);
            info_input = imfinfo(img_path);
            original_class = class(temp_vol);
            original_bit_depth = info_input(1).BitDepth;
            
            [H_img, W_img, Z_img] = size(temp_vol);
            input_img = double(temp_vol); 
            clear temp_vol; % Liberar memoria uint16
            
            % 2. AJUSTE DE PSF (Recorte para evitar errores de dimensión)
            [H_psf, W_psf, Z_psf] = size(psf_img_original);
            current_psf = psf_img_original;
            
            if H_psf >= H_img || W_psf >= W_img || Z_psf >= Z_img
                target_H = max(1, min(H_psf, H_img - 2));
                target_W = max(1, min(W_psf, W_img - 2));
                target_Z = max(1, min(Z_psf, Z_img - 2));
                
                % Dimensiones impares para Richardson-Lucy
                target_H = target_H - mod(target_H + 1, 2);
                target_W = target_W - mod(target_W + 1, 2);
                target_Z = target_Z - mod(target_Z + 1, 2);
                
                current_psf = imcrop3(psf_img_original, [ ...
                    max(1, floor((W_psf - target_W)/2) + 1), ...
                    max(1, floor((H_psf - target_H)/2) + 1), ...
                    max(1, floor((Z_psf - target_Z)/2) + 1), ...
                    target_W-1, target_H-1, target_Z-1]);
            end

            % 3. DECONVOLUCIÓN ( Richardson-Lucy )
            fprintf('Ejecutando Richardson-Lucy en %s...\n', filename);
            input_img = deconvlucy(input_img, current_psf, ITERATIONS);
            clear current_psf;
            
            % 4. ESCALADO Y CONVERSIÓN "IN-PLACE"
            max_val = double(intmax(original_class));
            input_img = cast(rescale(input_img, 0, max_val), original_class);
            
            % 5. GUARDADO
            save_tiff_4d(fullfile(OUTPUT_DIR, ['DVC_' filename]), input_img, original_bit_depth);
            
            % 6. 🧹 LIMPIEZA AGRESIVA (Clave para evitar el cierre)
            clear input_img; 
            drawnow;             % Libera recursos de la interfaz
            java.lang.System.gc; % Forzar recolector de basura de Java
            
        catch ME
            fprintf('❌ Error en %s: %s\n', filename, ME.message);
        end
    end
    clear psf_img_original;
end

disp('--- ✅ PROCESO FINALIZADO CON ÉXITO ---');

%% --- FUNCIONES AUXILIARES ---

function dir_path = select_directory(p)
    dir_path = uigetdir('', p);
    if isequal(dir_path, 0), dir_path = ''; end
end

function [n, m] = get_macro_parameters_matlab()
    ans = inputdlg({'Número de canales (1-4):'}, 'Configuración', 1, {'1'});
    if isempty(ans), error('Cancelado por el usuario'); end
    n = str2double(ans{1});
    m = containers.Map('KeyType', 'double', 'ValueType', 'char');
    for c = 1:n
        a = inputdlg({sprintf('Nombre PSF Canal C%d (ej: PSF_C%d.tif):', c, c)}, 'Configurar PSF', 1, {''});
        if isempty(a), error('Configuración incompleta'); end
        m(c) = a{1};
    end
end

function save_tiff_4d(fp, v, bd)
    % Asegurar que el volumen sea tratado como 4D para el bucle
    if ndims(v) < 4, v = reshape(v, [size(v,1), size(v,2), size(v,3), 1]); end
    [H, W, Z, C] = size(v);
    t = Tiff(fp, 'w');
    for c = 1:C
        for z = 1:Z
            t.setTag('ImageLength', H);
            t.setTag('ImageWidth', W);
            t.setTag('Photometric', Tiff.Photometric.MinIsBlack);
            t.setTag('BitsPerSample', bd);
            t.setTag('SamplesPerPixel', 1);
            t.setTag('PlanarConfiguration', Tiff.PlanarConfiguration.Chunky);
            t.write(v(:,:,z,c));
            if z < Z || c < C, t.writeDirectory(); end
        end
    end
    t.close();
end