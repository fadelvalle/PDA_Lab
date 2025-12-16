

// 1. Ask the user to select the input directory.
inputDir = getDirectory("Select the folder containing your Bio-Formats images:");

// 2. Create the output path and directory.
outputDir = inputDir + "Split_Channels" + File.separator;
File.makeDirectory(outputDir);

// 3. Get the list of files in the input directory.
fileList = getFileList(inputDir);

// 4. Activate batch mode to suppress unnecessary dialogs.
setBatchMode(true);

// 5. Iterate over each file in the folder.
for (i = 0; i < lengthOf(fileList); i++) {
    
    // Full path of the current file.
    fullPath = inputDir + fileList[i];
    
    // Check that the item is not a directory.
    if (!File.isDirectory(fullPath)) {
        
        // Base name of the original file without extension.
        baseName = File.getNameWithoutExtension(fileList[i]);
        
        // ************************************************
        // ** Bio-Formats Import and Splitting **
        // ************************************************
        
        // Use the Bio-Formats Importer. The 'split_channels' option is key.
        // open: File path
        // color_mode=Default: Uses default color settings/LUTs from file metadata.
        // split_channels: **Crucial for separating channels**
        // view=Hyperstack: Opens as a Hyperstack (recommended).
        
        run("Bio-Formats Importer", "open=["+ fullPath +"] color_mode=Default split_channels view=Hyperstack stack_order=XYCZT");
        
        // Bio-Formats opens each channel as a separate image window.
        
        // ************************************
        // ** Saving the Split Channels **
        // ************************************
        
        // Get the total number of open image windows (number of channels).
        numChannels = nImages; 
        
        // Iterate over each open image (each channel).
        for (c = 1; c <= numChannels; c++) {
            
            selectImage(c); // Select the current channel's image window (c=1, c=2, etc.).
            
            // --- Naming Logic ---
            
            // Create the desired prefix (e.g., "C1-", "C2-", etc.)
            channelPrefix = "C" + c + "-";
            
            // Define the full path to save the TIFF file.
            // Format: C#-OriginalFilename.tif
            savePath = outputDir + channelPrefix + baseName + ".tif";
            
            // Save the current image (channel) in TIFF format.
            saveAs("Tiff", savePath);
        }
        
        // ******************************
        // ** Cleanup **
        // ******************************
        
        // Close all images that were just processed and saved (numChannels windows).
        for (c = 1; c <= numChannels; c++) {
             close();
        }
    }
}

// 6. Disable batch mode and show a completion message.
setBatchMode(false);
showMessage("Processing Complete", "The separated channels have been saved to:\n" + outputDir + "\n\nFiles are named: C#-OriginalFilename.tif");