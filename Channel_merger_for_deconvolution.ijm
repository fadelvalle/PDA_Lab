// =========================================================
// --- FUNCIÓN DE FUSIÓN DE CANALES (Channel Merging) ---
// =========================================================

// Autonomous Merging Method (using string replacement)
// Los archivos deben tener el formato: DVC_C1-nombre.tif, DVC_C2-nombre.tif, etc.
function merge_deconvolved_channels_by_replacement(deconvolved_output_dir, num_channels) {
    
    dvc_list = getFileList(deconvolved_output_dir);
    
    // Crea una subcarpeta para guardar los archivos fusionados
    dir_merged = deconvolved_output_dir + "Merged_DVC" + File.separator;
    File.makeDirectory(dir_merged);

    print("\\Clear");
    print("--- Starting DVC Channel Merging via Name Replacement ---");
    
    // 1. Itera solo sobre los archivos C1 para definir muestras únicas
    for (i = 0; i < lengthOf(dvc_list); i++) {
        c1_filename = dvc_list[i];

        // Solo procesa archivos que empiecen con DVC_C1- y terminen en .tif
        if (startsWith(c1_filename, "DVC_C1-") && endsWith(c1_filename, ".tif")) {
            
            // --- A. Recopilar nombres de archivos y verificar existencia ---
            channel_filenames = newArray(num_channels);
            channel_paths = newArray(num_channels);
            all_files_exist = true;
            
            for (c = 1; c <= num_channels; c++) {
                channel_prefix = "C" + c + "-"; 
                
                // Si es C1, usa el nombre base. De lo contrario, reemplaza "C1-" por el nuevo prefijo.
                if (c == 1) {
                    current_filename = c1_filename;
                } else {
                    current_filename = replace(c1_filename, "C1-", channel_prefix);
                }
                
                channel_filenames[c-1] = current_filename;
                channel_paths[c-1] = deconvolved_output_dir + current_filename;

                if (!File.exists(channel_paths[c-1])) {
                    print("WARNING: Channel C" + c + " (" + current_filename + ") is missing for sample. Skipping merge.");
                    all_files_exist = false;
                    break; 
                }
            }
            
            if (!all_files_exist) continue; 
            
            // --- B. Fusión y Guardado ---
            
            // Abrir archivos y obtener títulos
            channel_titles = newArray(num_channels);
            merge_params = "";

            for (c = 1; c <= num_channels; c++) {
                open(channel_paths[c-1]); 
                channel_titles[c-1] = getTitle();
                // Construir la cadena de parámetros: c1=[T1] c2=[T2]...
                merge_params += " c" + c + "=[" + channel_titles[c-1] + "]";
            }
            
            print("-> Merging base sample: " + c1_filename);
            
            // Ejecutar Merge Channels con el número dinámico de canales
            run("Merge Channels...", merge_params + " create keep");

            // Guardar la imagen Composite
            selectWindow("Composite");
            
            // Nombre de salida: MERGED-UniqueID.tif
            merged_filename = replace(c1_filename, "DVC_C1-", "MERGED-");
            saveAs("Tiff", dir_merged + merged_filename);
            
            // Cerrar todas las ventanas abiertas
            close(); 
            for (c = 0; c < num_channels; c++) {
                selectWindow(channel_titles[c]); close();
            }
            
            run("Collect Garbage"); 
        }
    }
    
    print("--- Channel Merging Finished ---");
}

// =========================================================
// --- INICIO DE EJECUCIÓN DEL MACRO: CONFIGURACIÓN Y LLAMADA ---
// =========================================================

// Paso 1: Configuración de Rutas y Diálogo
dir_output = getDirectory("Select the folder containing the DECONVOLVED image files (DVC_C1-, DVC_C2-, etc.)");

Dialog.create("Channel Merging Configuration");
Dialog.addNumber("Number of channels processed (1-4):", 3);
Dialog.show();

// Paso 2: Lectura de Opciones y Validación
num_channels = Dialog.getNumber();
if (num_channels < 2 || num_channels > 4) {
    exit("Error: The number of channels must be between 2 and 4 to merge.");
}

// Paso 3: Ejecución de la Fusión
merge_deconvolved_channels_by_replacement(dir_output, num_channels);

print("=========================================================");
print("--- PROCESS COMPLETE! Merged images saved in 'Merged_DVC' folder. ---");
print("=========================================================");