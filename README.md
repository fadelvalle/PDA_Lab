# General instructions

Have Z projected or single sliced images in a folder of your choice, open in Fiji in the order of your liking. Also create a classifier on LabKit for the desired segmentation. A useful Lakbit tutorial can be found here https://www.youtube.com/watch?v=S4PpvzpNisk

Create 4 different folders:

- Crops
- Model
- Labels 
- Results

## Multi crop images 

 Open Z projected image (multichannel compatible). You will be prompted to select the folder where you want to save your cropped images (crops folder). Use the selection tool (recommended freehand) and keep adding ROIs with ctr+T .When you're done generating the ROIs, open Multi_crop_lines_PDA.ijm and click RUN and wait until your crops are saved.

## MFI and Shape analysis 

Close all images opened and run MFI_SpatialAnalysis_multi_image_Labkit_PDA.ijm and follow instructions on macros. Remember to write the name of the classifier in its full form "example.classifier". 


