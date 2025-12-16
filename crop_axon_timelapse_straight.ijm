// Diálogo de selección de carpeta

dir = getDirectory("Seleccione la carpeta para guardar las imágenes");

count = roiManager("Count");
img = getTitle();

for (i = 0; i < count; i ++) {
    selectWindow(img);
    roiManager("Select", i);
    Stack.getPosition(channel, slice, frame);
    run("Straighten...", "title=straight line=41 process");
    
    // Obtener el título de la imagen duplicada
    
			Title = getTitle();
			saveAs("tiff", dir+Title+"_"+img+(i+1)+".tif");
    // Cerrar la imagen duplicada
    
    close();
    
}
roiManager("deselect");
roiManager("delete");
    close();