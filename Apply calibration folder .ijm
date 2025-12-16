macro "Calibrar carpeta completa" {

    inputDir = getDirectory("Selecciona la carpeta");


    pixelWidth  = 0.0722;
    pixelHeight = 0.0722;
    voxelDepth  = 0.2000;
    unit = "um";

    list = getFileList(inputDir);

    for (i = 0; i < list.length; i++) {

        if (endsWith(list[i], ".tif") || endsWith(list[i], ".tiff")) {

            open(inputDir + list[i]);

            // ✅ FUNCIÓN CORRECTA
            setVoxelSize(pixelWidth, pixelHeight, voxelDepth, unit);

            saveAs("Tiff", inputDir + list[i]);
            close();
        }
    }

    print("Calibración aplicada correctamente.");
}
