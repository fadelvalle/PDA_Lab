// Selection dialog

dir = getDirectory("Select folder where crops will be saved");

count = roiManager("Count");
img = getTitle();

for (i = 0; i < count; i ++) {
    selectWindow(img);
    roiManager("Select", i);
    Stack.getPosition(channel, slice, frame);
    run("Straighten...", "title=straight line=41 process");
    
    // get image title
    
			Title = getTitle();
			saveAs("tiff", dir+Title+"_"+img+(i+1)+".tif");
    // Close image
    
    close();
    
}
roiManager("deselect");
roiManager("delete");
    close();
