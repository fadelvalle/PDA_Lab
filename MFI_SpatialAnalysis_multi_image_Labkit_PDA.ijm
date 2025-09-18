// Initial configuration
run("Set Measurements...", 
    "area mean standard modal min centroid center perimeter bounding fit shape feret's integrated median skewness kurtosis stack area_fraction display redirect=None decimal=3");

// Close everything
close("*");

// Folder where to save csv results
setOption("JFileChooser", true);
dir_results = getDirectory("The folder of the results");
setOption("JFileChooser", false);

// Where are your images
setOption("JFileChooser", true);
dir = getDirectory("Cell images?");
setOption("JFileChooser", false);

// Where to save segmented labels 
setOption("JFileChooser", true);
dir_save = getDirectory("Folder where to save labels");
setOption("JFileChooser", false);

// Folder where labkit classifier is
setOption("JFileChooser", true);
dir_clasificador = getDirectory("Folder where classifier is stored");
setOption("JFileChooser", false);

// name of the model. Write the FULL name "example.classifer"
nombre_modelo = "";
Dialog.create("Write full model name");
Dialog.addString(nombre_modelo, "Model name");
Dialog.show();
nombre_modelo = Dialog.getString();

// Channel to measure
Dialog.create("Fluorescence channel to measure");
Dialog.addNumber("Channel number (1, 2, 3...):", 1);
Dialog.show();
fluor_channel = Dialog.getNumber();

// loop step
imagenames = getFileList(dir); 
nbimages = lengthOf(imagenames); 

for (image=0; image<nbimages; image++) { 
    name = imagenames[image];
    totnamelength = lengthOf(name); 
    namelength = totnamelength-4;
    extension = substring(name, namelength, totnamelength);

    if (extension==".tif" || extension==".nd2" || extension==".czi") { 
       
        open(dir+File.separator+name);
        run("Enhance Contrast", "saturated=0.35");
        originalTitle = getTitle(); 

        
        Stack.setChannel(fluor_channel);

      
        clasificador = dir_clasificador + nombre_modelo;
        run("Segment Image With Labkit", "segmenter_file=" + clasificador + " use_gpu=false");

        
        run("Duplicate...", "duplicate");
        setAutoThreshold("Default dark no-reset");
        setOption("BlackBackground", true);
        run("Convert to Mask", "background=Dark black");
        maskTitle = getTitle();

        
        saveAs("Tiff", dir_save + "segmentation_" + name + "_segmented.tif");

        // only Spatial analysis
        run("Set Measurements...", 
            "area mean standard modal min centroid center perimeter bounding fit shape feret's integrated median skewness kurtosis stack area_fraction display redirect=None decimal=3");
        run("Analyze Particles...", "size=0.2-Infinity display clear include composite");
        saveAs("Results", dir_results + "results_shape_" + name + ".csv");
        close("Results");

        // intensity based analysis of selected channel
        run("Set Measurements...", 
            "area mean standard modal min centroid center perimeter bounding fit shape feret's integrated median skewness kurtosis stack area_fraction display redirect=["+originalTitle+"] decimal=3");
        run("Analyze Particles...", "size=0.2-Infinity display clear include composite");
        saveAs("Results", dir_results + "results_intensity_ch" + fluor_channel + "_" + name + ".csv");
        close("Results");

        // Close all before next image
        close("*");
    }
}