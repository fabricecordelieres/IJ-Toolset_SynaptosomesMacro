init();

nLabels=getNumber("Number of channels to analyse", 2);
out=getDirectory("Where to save the FCS file ?");

labels=GUI(nLabels);

setBatchMode(true);
normaliseImages(labels, nLabels);
detectSpots(labels, nLabels);
dimensions=overLayAndCutOut(labels, nLabels);
setBatchMode("exit and display");

reviewSynaptosomes(labels[labels.length-7], dimensions);
quantify(labels, nLabels);
generateControlImage(labels, nLabels);
run("Tile");
plotData(labels, nLabels);
exportAsFCS(labels, nLabels, out);


//-----------------------------------------
function init(){
	close("Normalised_*");
	close("Gallery*");
	close("Detection*");
	close("Control*");
	close("Scatter*");
	close("Distribution*");
	roiManager("Reset");
	run("Clear Results");
	run("Tile");
}

//-----------------------------------------
function GUI(nLabels){
	images=getImageList();
	Dialog.create("Colocalisation on synaptosomes");
	Dialog.addMessage("---Images---");
	for(i=1; i<=nLabels; i++){
		Dialog.addChoice("Image_for_label_"+i, images, images[i-1]);
		Dialog.addString("Name_for_label_"+i, "Label_"+i);
	}
	Dialog.addMessage("---Parameters---");
	Dialog.addNumber("Size_of_the_detection_square", 64);
	Dialog.addNumber("Radius_for_spots_filtering", 3);
	Dialog.addNumber("Noise_tolerance_for_spots_detection", 3);
	Dialog.addNumber("Min_size_for_spots", 5);
	Dialog.addNumber("Max_size_for_spots", 100);
	Dialog.addNumber("Size_of_the_quantification_circle_square", 32);
	Dialog.addNumber("Pixel_size_in_microns", 0.103);
	Dialog.show();

	out=newArray(2*nLabels+7);
	for(i=0; i<2*nLabels; i=i+2){
		out[i]=Dialog.getChoice();
		out[i+1]=Dialog.getString();
	}
	for(i=2*nLabels; i<out.length; i++) out[i]=Dialog.getNumber();
	
	return out;
}

//-----------------------------------------
function normaliseSingleImage(){
	run("Select None");
	run("Duplicate...", "title=Normalised_"+getTitle);
	getStatistics(area, mean, min, max, std, histogram);
	run("32-bit");
	run("Subtract...", "value="+mean);
	run("Divide...", "value="+std);
}

//-----------------------------------------
function normaliseImages(labels, nLabels){
	for(i=0; i<2*nLabels; i=i+2){
		selectWindow(labels[i]);
		normaliseSingleImage();
	}
}

//-----------------------------------------
function detectSpots(labels, nLabels){
	size=labels[2*nLabels];
	radius=labels[2*nLabels+1];
	noise=labels[2*nLabels+2];
	min=labels[2*nLabels+3];
	max=labels[2*nLabels+4];

	run("Images to Stack", "method=[Copy (center)] name=Normalised_Channels title=Normalised_ use");
	run("Z Project...", "projection=[Sum Slices]");
	rename("Normalised_Channels_Combined");
	run("Gaussian Blur...", "sigma="+radius);
	run("Median...", "radius="+radius);
	run("Find Maxima...", "noise="+noise+" output=[Point Selection]");
	Roi.getCoordinates(xpoints, ypoints);
	roiManager("Reset");
	index=1;
	for(i=0; i<xpoints.length; i++){
		doWand(xpoints[i], ypoints[i], noise, "Legacy");
		getStatistics(area);
		if(area>min && area<max){
			makeRectangle(xpoints[i]-size/2, ypoints[i]-size/2, size, size);
			Roi.setName("Detection_"+(index++));
			roiManager("Add");
		}
	}
	close("Normalised_Channels*");
}

//-----------------------------------------
function overLayAndCutOut(labels, nLabels){
	arg="";
	for(i=0; i<nLabels; i++) arg+="c"+(i+1)+"=["+labels[2*i]+"] ";
	
	run("Merge Channels...", arg+"create keep");
	rename("Composite");

	for(i=0; i<roiManager("Count"); i++){
		selectWindow("Composite");
		roiManager("Select", i);
		run("Duplicate...", "title=Detection_"+(i+1)+" duplicate");
		if(i==0){
			rename("Detection_Stack");
		}else{
			run("Concatenate...", "  title=[Detection_Stack] image1=Detection_Stack image2=Detection_"+(i+1)+" image3=[-- None --]");
		}
	}

	nCol=floor(sqrt(roiManager("Count")));
	nRows=round(roiManager("Count")/nCol+0.5);
	run("Make Montage...", "columns="+nCol+" rows="+nRows+" scale=1");
	rename("Gallery");

	Stack.getDimensions(width, height, channels, slices, frames);
	for(i=1; i<=channels; i++){
		Stack.setChannel(i);
		run("Enhance Contrast", "saturated=0.35");
	}
	
	close("Composite");
	close("Detection_Stack");

	return newArray(nCol, nRows);
}

//-----------------------------------------
function reviewSynaptosomes(size, dimensions){
	leftButton=16;
	rightButton=4;
	shift=1;
	ctrl=2; 
	alt=8;
	x2=-1;
	y2=-1;
	z2=-1;
	flags2=-1;

	nCol=dimensions[0];
	nRows=dimensions[1];

	generateROIs(roiManager("Count"), size, dimensions);

	
	setTool("rectangle");
	getCursorLoc(x, y, z, modifiers);
	while (!isKeyDown("space")){
		showStatus("Click on the synaptosome to change its status, then press space");
		getCursorLoc(x, y, z, flags);
		if (x!=x2 || y!=y2 || z!=z2 || flags!=flags2) {
			if(flags& leftButton!=0) updateRoiStatus(x, y, size, dimensions);
		}
		x2=x; y2=y; z2=z; flags2=flags;
		wait(100);
	}
	roiManager("Deselect");
}

//-----------------------------------------
function generateROIs(nRois, size, dimensions){
	roiManager("Reset");

	nCol=dimensions[0];
	
	nRows=nRois/nCol;
	index=0;

	for(j=0; j<nRows; j++){
		for(i=0; i<nCol; i++){
			makeOval(i*size, j*size, size, size);
			Roi.setStrokeColor("green");
			Roi.setName("Detection_"+(index+1));
			roiManager("Add");
			index++;
			if(index>nRois-1){
				i=nCol;
				j=nRows;
			}
		}
	}
	roiManager("Show All without labels");
}

//-----------------------------------------
function updateRoiStatus(x, y, boxSize, dimensions){
	x=floor(x/boxSize);
	y=floor(y/boxSize);
	index=x+y*dimensions[0];

	if(index<roiManager("Count")){
		roiManager("Select", index);
		color=Roi.getStrokeColor;

		if(color=="yellow" || color=="red"){
			makeOval(x*boxSize, y*boxSize, boxSize, boxSize);
			Roi.setStrokeColor("green");
			roiManager("Update");
		}

		if(color=="green"){
			x1=x*boxSize;
			x2=(x+1)*boxSize;
			y1=y*boxSize;
			y2=(y+1)*boxSize;

			xCoord=newArray(x1, x2, x2, x1, x1, x2, x1, x2);
			yCoord=newArray(y1, y1, y2, y2, y1, y2, y2, y1);
			makeSelection("polygon", xCoord, yCoord);
			Roi.setStrokeColor("red");
			roiManager("Update");
		}
		run("Select None");
	}
}

//-----------------------------------------
function quantify(labels, nLabels){
	run("Clear Results");
	getDimensions(width, height, channels, slices, frames);
	size=labels[labels.length-2];
	pixelSize=labels[labels.length-1];
	
	for(i=0; i<roiManager("Count"); i++){
		roiManager("Select", i);
		name=Roi.getName;
		
		if(Roi.getStrokeColor=="green"){
			Roi.getBounds(xRoi, yRoi, widthRoi, heightRoi);
			
			lineNb=nResults;
			data=newArray(channels*2);
			index=0;
			
			//Get raw data
			for(j=1; j<=channels; j++){
				Stack.setChannel(j);
				makeOval(xRoi+widthRoi/2-size/2, yRoi+widthRoi/2-size/2, size, size);		

				List.setMeasurements;
				x=List.getValue("XM");
				y=List.getValue("YM");
				intensity=List.getValue("RawIntDen");
				area=List.getValue("Area");

				setResult("Label", lineNb, name);
				setResult("X_"+labels[(j-1)*2+1], lineNb, x);
				setResult("Y_"+labels[(j-1)*2+1], lineNb, y);
				setResult("Intensity_"+labels[(j-1)*2+1], lineNb, intensity);

				data[index++]=x;
				data[index++]=y;

				run("Make Band...", "band="+(widthRoi/2-size/2-1));
				List.setMeasurements;
				intensityBkgd=List.getValue("RawIntDen");
				areaBkgd=List.getValue("Area");
				intensityBkgd=intensityBkgd*area/areaBkgd;
				intensityBkgdCorr=intensity-intensityBkgd;
				
				setResult("Bkgd_Intensity_"+labels[(j-1)*2+1], lineNb, intensityBkgd);
				setResult("Bkgd_Corr_Intensity_"+labels[(j-1)*2+1], lineNb, intensityBkgdCorr);
			}

			for(j=1; j<=channels; j++){
				for(k=1; k<=channels; k++){
					if(k>j){
						x1=data[(j-1)*2];
						y1=data[(j-1)*2+1];
						x2=data[(k-1)*2];
						y2=data[(k-1)*2+1];

						distance=pixelSize*sqrt((x2-x1)*(x2-x1)+(y2-y1)*(y2-y1));
						setResult("Distance_"+labels[(j-1)*2+1]+"-"+labels[(k-1)*2+1]+"_microns", lineNb, distance);
					}
				}
			}
		}
	}
}

//-----------------------------------------
function generateControlImage(labels, nLabels){
	getDimensions(width, height, channels, slices, frames);
	newImage("Control", "16-bit composite-mode", width, height, channels, slices, frames);
	setColor("white");
	size=labels[2*nLabels+1];

	for(i=0; i<nLabels; i++){
		Stack.setChannel(i+1);
		x=getColumnResults("X_"+labels[i*2+1]);
		y=getColumnResults("Y_"+labels[i*2+1]);
		for(j=0; j<x.length; j++) drawOval(x[j]-size/2, y[j]-size/2, size, size);
	}
	roiManager("Show All");
}

//-----------------------------------------
function plotData(labels, nLabels){
	for(i=0; i<nLabels; i++){
		for(j=0; j<nLabels; j++){
			if(j>i){
				xIntensity=getColumnResults("Intensity_"+labels[i*2+1]);
				yIntensity=getColumnResults("Intensity_"+labels[j*2+1]);
				Plot.create("Scatter Plot Raw Intensities "+labels[i*2+1]+" vs "+labels[j*2+1], "Intensity_"+labels[i*2+1], "Intensity_"+labels[j*2+1]);
				Plot.add("circles", xIntensity, yIntensity);
				Plot.show();

				xIntensity=getColumnResults("Bkgd_Corr_Intensity_"+labels[i*2+1]);
				yIntensity=getColumnResults("Bkgd_Corr_Intensity_"+labels[j*2+1]);
				Plot.create("Scatter Plot Bkgd corrected Intensities "+labels[i*2+1]+" vs "+labels[j*2+1], "Intensity_"+labels[i*2+1], "Intensity_"+labels[j*2+1]);
				Plot.add("circles", xIntensity, yIntensity);
				Plot.show();

				distances=getColumnResults("Distance_"+labels[i*2+1]+"-"+labels[j*2+1]+"_microns");
				xDistances=getHistogramX(distances, 128);
				yDistances=getHistogramY(distances, 128);
				Plot.create("Distribution distances "+labels[i*2+1]+" vs "+labels[j*2+1], "Distance", "Frequency", xDistances, yDistances);
				Plot.show();
			}
		}
	}
}



//-----------------------------------------
function getColumnResults(title){
	out=newArray(nResults);
	for(i=0; i<nResults; i++) out[i]=getResult(title, i);

	return out;
}

//-----------------------------------------
function getHistogramX(data, nBins){
	Array.getStatistics(data, min, max, mean, stdDev);
	out=newArray(nBins+1);
	for(i=0; i<out.length; i++) out[i]=min+i*(max-min)/(nBins-1);

	return out;
}

//-----------------------------------------
function getHistogramY(data, nBins){
	Array.getStatistics(data, min, max, mean, stdDev);
	out=newArray(nBins+1);
	for(i=0; i<data.length; i++){
		position=(data[i]-min)/((max-min)/(nBins-1));
		out[position]++;
	}

	return out;
}

//-----------------------------------------
function exportAsFCS(labels, nLabels, out){
	f=File.open(out+"CytoFile.txt");

	line="Label";
	for(j=0; j<nLabels; j++){
		line+=", Intensity_"+labels[j*2+1];
		line+=", Bkgd_Intensity_"+labels[j*2+1];
		line+=", Bkgd_Corr_Intensity_"+labels[j*2+1];
	}
	
	print(f, line);

	for(i=0; i<nResults; i++){
		line=getResultString("Label", i);
		for(j=0; j<nLabels; j++){
			line+=", "+round(getResult("Intensity_"+labels[j*2+1], i));
			line+=", "+round(getResult("Bkgd_Intensity_"+labels[j*2+1], i));
			line+=", "+round(getResult("Bkgd_Corr_Intensity_"+labels[j*2+1], i));
		}
		print(f, line);
	}
	File.close(f);
	result=File.rename(out+"CytoFile.txt", out+"CytoFile.csv");
}


//-----------------------------------------
function getImageList(){
	images=newArray(nImages);
	for(i=0; i<nImages; i++){
		selectImage(i+1);
		images[i]=getTitle();
	}
	return images;
}
