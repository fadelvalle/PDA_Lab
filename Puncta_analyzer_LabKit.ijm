// ==============================
// Initial configuration
// ==============================
run("Set Measurements...", 
    "area mean standard modal min centroid center perimeter bounding fit shape feret's integrated median skewness kurtosis stack area_fraction display redirect=None decimal=3");
close("*");

// ==============================
// Folders
// ==============================
setOption("JFileChooser", true);
dir_results = getDirectory("The folder of the results");
dir = getDirectory("Cell images?");
dir_save = getDirectory("Folder where to save labels");
dir_clasificador = getDirectory("Folder where classifier is stored");
setOption("JFileChooser", false);

// ==============================
// Channel prefix to measure (C2-...)
// ==============================
channelPrefix = "C2-";

// ==============================
// Loop through images
// ==============================
imagenames = getFileList(dir); 
nbimages = lengthOf(imagenames); 

for (image = 0; image < nbimages; image++) { 

    name = imagenames[image];
    totnamelength = lengthOf(name); 
    namelength = totnamelength - 4;
    extension = substring(name, namelength, totnamelength);

    if (extension == ".tif" || extension == ".nd2" || extension == ".czi") { 

        // ------------------------------
        // Open image
        // ------------------------------
        open(dir + File.separator + name);
        run("Enhance Contrast", "saturated=0.35");
        originalTitle = getTitle();

        // ------------------------------
        // Split channels
        // ------------------------------
        run("Split Channels");
        titles = getList("image.titles");
        fluorTitle = "";

        for (t = 0; t < titles.length; t++) {
            if (startsWith(titles[t], channelPrefix)) {
                selectWindow(titles[t]);
                fluorTitle = titles[t];
            } else {
                close(titles[t]);
            }
        }

        if (fluorTitle == "") {
            print("ERROR: No channel starting with " + channelPrefix + " found in " + name);
            close("*");
            continue;
        }

        // ------------------------------
        // Labkit segmentation
        // ------------------------------
        clasificador = dir_clasificador + File.separator + "FISH.classifier";

        if (File.exists(clasificador)) {
            run("Segment Image With Labkit", "input=[" + fluorTitle + "] segmenter_file=" + clasificador + " use_gpu=false");
        } else {
            print("ERROR: Model file not found at " + clasificador);
            close("*");
            continue;
        }

        // ------------------------------
        // Seleccionar imagen segmentada y hacer threshold
        // ------------------------------
        segTitle = "segmentation of " + fluorTitle;
        selectImage(segTitle);

        setAutoThreshold("Default dark no-reset");
        setOption("BlackBackground", true);
        run("Convert to Mask");

        // ------------------------------
        // Analyze Particles y guardar ROIs
        // ------------------------------
        roiManager("Reset");
        run("Analyze Particles...", "size=0-Infinity display clear include add");

        roiCount = roiManager("count");
        if (roiCount > 0) {
            roiManager("Save", dir_results + "ROIs_segmented_" + name + ".zip");
        } else {
            print("WARNING: No ROIs detected in mask for " + name);
        }

        // ------------------------------
        // Guardar CSV de resultados de segmentación
        // ------------------------------
        saveAs("Results", dir_results + "results_segmented_" + name + ".csv");
        close("Results");

        // ------------------------------
        // Guardar TIF de la máscara
        // ------------------------------
        saveAs("Tiff", dir_save + "segmentation_" + name + "_segmented.tif");

        // ------------------------------
        // Analizar intensidad en el canal fluorescente original usando los ROIs
        // ------------------------------
        if (roiCount > 0) {
            selectWindow(fluorTitle);  // Asegurarse que la ventana del canal fluorescente esté activa

            // Medir sobre los ROIs existentes
            run("Set Measurements...", 
                "area mean standard modal min centroid center perimeter bounding fit shape feret's integrated median skewness kurtosis stack area_fraction display redirect=None decimal=3");

            roiManager("Measure");

            // Guardar resultados de intensidad
            saveAs("Results", dir_results + "results_intensity_" + name + ".csv");
            close("Results");
        } else {
            print("WARNING: No ROIs available for intensity measurement for " + name);
        }

        // ------------------------------
        // Cleanup
        // ------------------------------
        close("*");
    }
}
