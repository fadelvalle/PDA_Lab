
% NOTA: Se asume que tiffreadVolume está disponible y que save_tiff_4d maneja la escritura.
%% 0. Funciones Auxiliares para Interacción y Manejo de TIFF
function dir_path = select_directory(title_prompt)
    % Abre un cuadro de diálogo para seleccionar una carpeta.
    dir_path = uigetdir('', title_prompt);
    if isequal(dir_path, 0)
        dir_path = ''; % Indica cancelación
    end
end
function [num_channels, psf_names] = get_macro_parameters_matlab()
    % Configura los canales y los nombres de los archivos PSF.
    
    prompt = {'Número de canales a procesar (1-4):'};
    dlg_title = 'Configuración de Deconvolución';
    num_lines = 1;
    default_answer = {'1'};
    
    answer = inputdlg(prompt, dlg_title, num_lines, default_answer);
    
    if isempty(answer)
        error('Configuración cancelada por el usuario.'); 
    end
    
    num_channels = str2double(answer{1});
    if isnan(num_channels) || num_channels < 1 || num_channels > 4
        error('Número de canales no válido. Debe ser un entero entre 1 y 4.');
    end
    
    psf_names = containers.Map('KeyType', 'double', 'ValueType', 'char');
    
    for c = 1:num_channels
        prompt = {sprintf('PSF para Canal C%d (ej., PSF_DAPI.tif):', c)};
        dlg_title = 'Configuración de PSF';
        default_answer = {''};
        
        answer = inputdlg(prompt, dlg_title, num_lines, default_answer);
        
        if isempty(answer) || isempty(answer{1})
            error('Error: El nombre del PSF para el Canal C%d es obligatorio.', c);
        end
        
        psf_names(c) = answer{1};
    end
end
function save_tiff_4d(file_path, volume_4D, original_bit_depth)
    % Guarda un volumen 4D (YxXxZxC) o 3D (YxXxZ) apilando los planos en el archivo TIFF.
    
    if ndims(volume_4D) < 4
        % Si es 3D, lo tratamos como un volumen 4D con 1 canal para el bucle de guardado.
        volume_4D = reshape(volume_4D, [size(volume_4D), 1]);
    end
    [H, W, Z, C] = size(volume_4D);
    
    % Usa la clase Tiff nativa para escribir el volumen multi-plano.
    t = Tiff(file_path, 'w');
    
    for c_idx = 1:C
        for z_idx = 1:Z
            plane = volume_4D(:, :, z_idx, c_idx);
            
            % Configuración de etiquetas TIFF
            t.setTag('ImageLength', H);
            t.setTag('ImageWidth', W);
            t.setTag('Photometric', Tiff.Photometric.MinIsBlack);
            t.setTag('BitsPerSample', original_bit_depth); 
            t.setTag('SamplesPerPixel', 1); 
            t.setTag('RowsPerStrip', 16);
            t.setTag('PlanarConfiguration', Tiff.PlanarConfiguration.Chunky);
            
            t.write(plane);
            
            % Escribir un nuevo directorio TIFF para el siguiente plano
            if z_idx < Z || c_idx < C
                t.writeDirectory();
            end
        end
    end
    t.close();
end
%% 1. ⚙️ CONFIGURACIÓN Y PREPARACIÓN DE RUTAS
disp('--- ⚙️ CONFIGURACIÓN Y PREPARACIÓN DE RUTAS ⚙️ ---');
% Paso 1: Selección Interactiva de Rutas
disp('1. Esperando la selección interactiva de carpetas...');
INPUT_DIR = select_directory('Selecciona la carpeta que contiene los archivos de imagen (C1-*, C2-*, etc.)');
if isempty(INPUT_DIR)
    error('Selección de carpeta de entrada cancelada. Proceso detenido.');
end
PSF_DIR = select_directory('Selecciona la carpeta que contiene los archivos PSF.');
if isempty(PSF_DIR)
    error('Selección de carpeta PSF cancelada. Proceso detenido.');
end
% Paso 2: Configuración Interactiva de Canales y PSFs
disp('2. Esperando la configuración de canales y PSFs...');
try
    [NUM_CHANNELS, PSF_NAMES_MAP] = get_macro_parameters_matlab();
catch ME
    disp(ME.message);
    return;
end
% Paso 3: Limpieza y Creación de la Carpeta de Salida
OUTPUT_DIR = fullfile(INPUT_DIR, 'Deconvolved_RL_MATLAB');
if exist(OUTPUT_DIR, 'dir')
    disp(['Advertencia: La carpeta de salida ' OUTPUT_DIR ' ya existe. Eliminando y recreando...']);
    try
        rmdir(OUTPUT_DIR, 's'); % Eliminar recursivamente
    catch ME
        disp(['Error al intentar eliminar la carpeta: ' ME.message]);
        error('No se pudo limpiar la carpeta de salida. Proceso detenido.');
    end
end
mkdir(OUTPUT_DIR);
% Parámetros Fijos de RL
ITERATIONS = 20; % Puedes ajustar este valor si lo deseas.
disp(sprintf('\n--- Resumen de Configuración ---'));
disp('ALGORITMO: Richardson-Lucy (RL) simple');
disp(['Número de Canales: ' num2str(NUM_CHANNELS)]);
disp(['Iteraciones RL: ' num2str(ITERATIONS)]);
disp(['Carpeta de Entrada: ' INPUT_DIR]);
disp(['Carpeta de PSF: ' PSF_DIR]);
disp('PSFs configurados:');
disp(PSF_NAMES_MAP);
disp('---------------------------------');
%% 2. 🔬 DECONVOLUCIÓN RICHARDSON-LUCY (Z-STACKS)
for c = 1:NUM_CHANNELS
    psf_file_name = PSF_NAMES_MAP(c);
    channel_prefix = ['C' num2str(c) '-'];
    
    disp(sprintf('\n--- Procesando CANAL %d (%s) con PSF: %s (Volumen 3D) ---', c, channel_prefix, psf_file_name));
    % 1. Cargar el PSF
    psf_path = fullfile(PSF_DIR, psf_file_name);
    if ~exist(psf_path, 'file')
        disp(['ERROR: PSF no encontrado en ' psf_path '. Saltando canal.']);
        continue;
    end
    
    try
        psf_img_original = double(tiffreadVolume(psf_path)); % Guardamos el original
        psf_img = psf_img_original;
    catch ME
        disp(['ERROR: No se pudo cargar el PSF con tiffreadVolume. ' ME.message '. Saltando canal.']);
        continue;
    end
    
    % 2. Buscar imágenes de este canal
    file_pattern = [channel_prefix '*.tif'];
    image_list = dir(fullfile(INPUT_DIR, file_pattern));
    total_images = length(image_list);
    if total_images == 0
        disp(['Advertencia: No se encontraron imágenes con prefijo ' channel_prefix]);
        continue;
    end
    % 3. Iteración por lotes y deconvolución
    for i = 1:total_images
        filename = image_list(i).name;
        img_path = fullfile(INPUT_DIR, filename);
        
        current_image = i;
        percentage = (current_image / total_images) * 100;
        disp(sprintf('-> 🔄 %s %d/%d (%.1f%%) | Deconvolviendo: %s', channel_prefix, current_image, total_images, percentage, filename));
        
        % Carga de la Imagen de Entrada como volumen 3D
        try
            input_volume = tiffreadVolume(img_path);
            
            % Obtener información de clase para guardar
            info_input = imfinfo(img_path);
            original_class = class(input_volume);
            original_bit_depth = info_input(1).BitDepth;
            input_img = double(input_volume); % Convertir a double para RL
        catch ME
            disp(['WARNING: No se pudo cargar el volumen de entrada ' filename '. ' ME.message '. Saltando.']);
            continue;
        end
        
        % ====================================================================
        % 💥 BLOQUE DE RECORTE AUTOMÁTICO DE PSF (SOLUCIÓN ROBUSTA) 💥
        % ====================================================================
        
        % Recargamos el PSF original para cada imagen en caso de que el recorte anterior lo haya modificado
        psf_img = psf_img_original; 
        
        [H_img, W_img, Z_img] = size(input_img);
        [H_psf, W_psf, Z_psf] = size(psf_img);
        % Bandera para indicar si se necesita recorte.
        needs_crop = H_psf >= H_img || W_psf >= W_img || Z_psf >= Z_img;
        if needs_crop
            
            % Calculamos el límite estricto: debe ser al menos 2 unidades menor que la imagen.
            limit_H = H_img - 2; 
            limit_W = W_img - 2;
            limit_Z = Z_img - 2; 
            
            % Definimos los tamaños de recorte, forzando el límite estricto.
            target_H = min(H_psf, limit_H);
            target_W = min(W_psf, limit_W);
            target_Z = min(Z_psf, limit_Z);
            
            % Aseguramos que las dimensiones sean positivas y ajustamos a impar (o 1)
            target_H = max(1, target_H - mod(target_H + 1, 2)); 
            target_W = max(1, target_W - mod(target_W + 1, 2)); 
            target_Z = max(1, target_Z - mod(target_Z + 1, 2)); 
            
            % VALIDACIÓN CRÍTICA: Verificamos si la imagen es lo suficientemente grande.
            if target_H >= H_img || target_W >= W_img || target_Z >= Z_img || target_H <= 0 || target_W <= 0 || target_Z <= 0
                 disp(sprintf('ERROR FATAL: El PSF %s requiere un recorte imposible porque la imagen de entrada es demasiado pequeña (%dx%dx%d). Recorte manualmente el PSF.', psf_file_name, H_img, W_img, Z_img));
                 continue; % Salta esta imagen.
            end
            % --- CÁLCULO DE COORDENADAS DE INICIO SEGURO ---
            % Garantizamos que el punto de inicio sea >= 1.
            x_start = max(1, floor((W_psf - target_W)/2) + 1);
            y_start = max(1, floor((H_psf - target_H)/2) + 1);
            z_start = max(1, floor((Z_psf - target_Z)/2) + 1);
            % Recortamos con las coordenadas de inicio seguras.
            psf_img_cropped = imcrop3(psf_img, [
                x_start, ...      % X start >= 1
                y_start, ...      % Y start >= 1
                z_start, ...      % Z start >= 1
                target_W - 1, ... % X width (imcrop3 usa width/height)
                target_H - 1, ... 
                target_Z - 1  ... 
            ]);
            
            % Asignar el PSF recortado
            psf_img = psf_img_cropped;
            disp(sprintf('-> ✅ PSF ajustado de (%d,%d,%d) a (%d,%d,%d) para RL 3D.', H_psf, W_psf, Z_psf, size(psf_img,1), size(psf_img,2), size(psf_img,3)));
        end
        
        % ====================================================================
        % ----------------- FIN DEL BLOQUE DE RECORTE ------------------------
        % ====================================================================
        % Ejecución de Richardson-Lucy (trabaja en el VOLUMEN 3D)
        img_decon = deconvlucy(input_img, psf_img, ITERATIONS);
        % Escalar y convertir el resultado (double) de nuevo al tipo de dato original
        max_val_target = double(intmax(original_class));
        img_scaled = rescale(img_decon, 0, max_val_target);
        img_to_save = cast(img_scaled, original_class); 
        
        % Guardar el resultado con el prefijo DVC_
        deconv_filename = ['DVC_' filename];
        deconv_path = fullfile(OUTPUT_DIR, deconv_filename);
        
        % 🚨 CORRECCIÓN: Usar save_tiff_4d en lugar de tiffwriteVolume
        save_tiff_4d(deconv_path, img_to_save, original_bit_depth); 
    end
    
    disp(sprintf('\n✅ Procesamiento de Canal %d finalizado (%d volúmenes).', c, total_images));
end
%% 3. FINALIZACIÓN
disp(sprintf('\n========================================================='));
disp(['--- PROCESO COMPLETO! RL simple finalizado en ' num2str(ITERATIONS) ' iteraciones ---']);
disp(['Los resultados deconvolucionados (DVC_*.tif) se guardaron en: ' OUTPUT_DIR]);
disp('=========================================================');