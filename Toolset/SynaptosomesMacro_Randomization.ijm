var LUTs=newArray("Green", "Magenta", "Blue");
var nLabels=2;
var in="";
var out="";
var labels=newArray();
var basename="Analysis";


macro "Single Acquisition Action Tool - C555D31D3eD4eD5aD5eD6aD6eD7aD7eD8aD8eD91D9aD9eDa1Da2Da3DaaDaeDb2Db3DbeDc3DceCeeeD3fD4bD4fD5fD6fD7fD8fD95D9fDa5DafDbbDbfDcfCaaaD22D23D24D25D26D27D28D29D2aD2bD2cD2dD2eD32D33D34D35D36D37D38D39D3aD3bD3cD3dD4aD74Db6Db7Db9DbaDc2Dc4DcdDd3DdeC999D54D55D58D64D65D68D75D78D88D98Da8Dd4Dd5Dd6Dd7Dd8Dd9DdaDdbDdcDddCfffD2fD30D40D42D4dD50D52D5dD60D62D6dD70D72D7dD80D82D84D8dD90D9dDadDb5DbdDdfCcccD21D44D45D46D47D48D49D5bD6bD7bD85D8bD92D93D9bDa4DabDb1Db4Db8Dc5Dc6Dc7Dc8Dc9DcaDcbDccC777D41D51D56D57D59D61D66D67D69D71D76D77D79D81D86D87D89D96D97D99Da6Da7Da9"{
	prepare(true);
	process();
}

macro "Multiple Acquisitions Action Tool - C333D2fD3fD40D4fD50D5fD60D6fD70D7fD80D8fD90D93D94D9fDa0Da3Da4DafDb1Db2Db4DbfDc1Dc2DcdDd2CcccD12D35D36D37D38D39D3aD3bD41D4cD76D83D95Da5DacDb6Db7Db8Db9DbaDbbDbcDbdDbeDc0De2DedC999D23D24D25D26D27D28D29D2aD2bD2cD2dD2eD46D49D56D59D66D69D79D89D99Da2Da7DaaDabDb3Dc4Dd3Dd4Dd5Dd6Dd7Dd8Dd9DdaDdbDdcC777D31D48D4aD58D5aD68D6aD78D7aD88D8aD98D9aDc5Dc6Dc7Dc8Dc9DcaDcbDccDceCeeeD21D33D3cD3eD43D4eD51D53D5eD61D63D6eD71D73D75D7eD81D84D86D8eD91D96D9eDa6DaeDc3DdeCbbbD13D14D15D16D17D18D19D1aD1bD1cD1dD1eD1fD45D55D5cD65D6cD7cD8cD9cDa1Da8Da9Db5Dd1De3De4De5De6De7De8De9DeaDebDecC666D22D30D32D42D47D4bD52D57D5bD62D67D6bD72D77D7bD82D87D8bD92D97D9bDb0DcfDdd"{
	run("Close All");
	prepare(false);

	channel1=getFileNamesContaining(in, labels[0]);

	for(i=0; i<channel1.length; i++){
		hasAllFiles=true;
		oldLabels=Array.copy(labels);
		firstLabel=labels[0];
		
		for(j=0; j<nLabels; j++){
			labels[2*j]=replace(channel1[i], firstLabel, labels[2*j]);
			hasAllFiles=hasAllFiles&&File.exists(in+labels[2*j]);
			if(!hasAllFiles){
				print("Missing file: "+labels[2*j]);
				break;
			}
		}
		
		if(hasAllFiles){
			for(j=0; j<nLabels; j++) open(in+labels[2*j]);
			basename=replace(channel1[i], firstLabel, "_");
			basename=substring(basename, 0, lastIndexOf(basename, "."));
			process();
		}
		labels=Array.copy(oldLabels);
	}

	poolCSVFiles(out, "CytoFile", true);
}

//-----------------------------------------
function init(){
	run("Set Measurements...", "decimal=4");
	close("Normalised_*");
	close("Gallery*");
	close("Detection*");
	close("Control*");
	close("Scatter*");
	close("Distribution*");
	roiManager("Reset");
	run("Clear Results");
	if(nImages!=0) run("Tile");
}

//-----------------------------------------
function prepare(isSingle){
	init();

	nLabels=getNumber("Number of channels to analyse", nLabels);
	if(!isSingle) in=getDirectory("Where are the input files ?");
	out=getDirectory("Where to save the output files ?");

	labels=GUI(nLabels, isSingle);
}

//-----------------------------------------
function GUI(nLabels, isSingle){
	availableLUTs=getList("LUTs");

	if(isSingle){
		images=getImageList();
	}else{
		images=newArray("G Ex 470 Em QuadA", "R Ex 550 Em QuadA", "");
	}

	Dialog.create("Colocalisation on synaptosomes");
	Dialog.addMessage("---Images---");
	for(i=1; i<=nLabels; i++){
		if(isSingle){
			Dialog.addChoice("Image_for_label_"+i, images, images[i-1]);
		}else{
			Dialog.addString("FileName_contains", images[i-1]);
		}
		Dialog.addString("Name_for_label_"+i, "Label_"+i);
		Dialog.addChoice("LUT_for_label_"+i, availableLUTs, LUTs[(i-1)%LUTs.length]);
	}
	Dialog.addMessage("---Parameters---");
	Dialog.addNumber("Size_of_the_detection_square", 64);
	Dialog.addNumber("Radius_for_spots_filtering", 3);
	Dialog.addNumber("Noise_tolerance_for_spots_detection", 3);
	Dialog.addNumber("Min_size_for_spots_(pixels)", 5);
	Dialog.addNumber("Max_size_for_spots_(pixels)", 100);
	Dialog.addNumber("Size_of_the_quantification_circle_square", 32);
	Dialog.addNumber("Pixel_size_in_microns", 0.103);
	Dialog.addMessage("---Randomization---");
	Dialog.addNumber("#_monte_carlo_simulations", 10000);
	Dialog.addNumber("distance_max_colocalization_(microns)", 0.217);
	Dialog.show();

	params=newArray(2*nLabels+9);
	for(i=0; i<2*nLabels; i=i+2){
		if(isSingle){
			params[i]=Dialog.getChoice();
		}else{
			params[i]=Dialog.getString();
		}
		params[i+1]=Dialog.getString();
		LUTs[i/2]=Dialog.getChoice();
	}
	for(i=2*nLabels; i<params.length; i++) params[i]=Dialog.getNumber();
	
	return params;
}

//-----------------------------------------
function process(){
	setBatchMode(true);
	imgSize=reduce(labels, nLabels);
	normaliseImages(labels, nLabels);
	detectSpots(labels, nLabels);
	dimensions=overlayAndCutOut(labels, nLabels);
	setBatchMode("exit and display");

	if(dimensions[0]!=0 && dimensions[1]!=0){
		reviewSynaptosomes(labels[labels.length-9], dimensions);
		quantify(labels, nLabels);
		generateControlImage(labels, nLabels);
		run("Tile");
		plotData(labels, nLabels);
		saveAll(out, basename);
		exportAsFCS(labels, nLabels, out, basename);

		saveAs("Results", out+basename+"_Results.csv");

		open(out+basename+"_Results.csv");
		Table.rename("Analysis_Results.csv"); //Standardize the name of the table for the randomization plugin
		selectWindow(basename+"_Results.csv"); //Table.rename duplicates the table: close the original one
		run("Close");
		
		run("RandomizerColocalization ", "image_width_(microns)="+imgSize[0]+" image_height_(microns)="+imgSize[1]+" distance_max_colocalization_(microns)="+labels[2*nLabels+8]+" #_monte_carlo_simulations="+labels[2*nLabels+7]+" name_of_label_1="+labels[1]+" name_of_label_2="+labels[3]);
		
		selectWindow("Randomizer_Results");
		saveAs("Results", out+basename+"_RandomizationResults.csv");

		//Close all results windows
		run("Close");
		selectWindow("Analysis_Results.csv");//Close the duplciated table
		run("Close");

		run("Close All");
		run("Clear Results");
	}else{
		exit("No synapsome found:\nTry adapting detection parameters");
	}
}

//-----------------------------------------
function reduce(labels, nLabels){
	for(i=0; i<2*nLabels; i=i+2){
		selectWindow(labels[i]);
		getDimensions(width, height, channels, slices, frames);
		if(slices>1){
			run("Z Project...", "projection=[Sum Slices]");
			rename("Proj");
			close(labels[i]);
			selectWindow("Proj");
			rename(labels[i]);
		}
	}

	//Returns the image's size in microns
	return newArray(width*labels[labels.length-3], height*labels[labels.length-3]);
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
		getRawStatistics(area);
		
		if(area>min && area<max){
			makeRectangle(xpoints[i]-size/2, ypoints[i]-size/2, size, size);
			Roi.setName("Detection_"+(index++));
			roiManager("Add");
		}
	}
	close("Normalised_Channels*");
}

//-----------------------------------------
function overlayAndCutOut(labels, nLabels){
	arg="";
	for(i=0; i<nLabels; i++) arg+="c"+(i+1)+"=["+labels[2*i]+"] ";
	
	run("Merge Channels...", arg+"create keep");
	rename("Composite");

	applyLUTs();

	nCol=0;
	nRows=0;

	if(roiManager("Count")!=0){
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
	}

	close("Composite");
	close("Detection_Stack");

	return newArray(nCol, nRows);
}

//-----------------------------------------
function applyLUTs(){
	for(i=0; i<nLabels; i++){
		Stack.setChannel(i+1);
		run(LUTs[i]);
	}
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
	size=labels[labels.length-4];
	pixelSize=labels[labels.length-3];
	
	for(i=0; i<roiManager("Count"); i++){
		roiManager("Select", i);
		name=Roi.getName;
		
		if(Roi.getStrokeColor=="green"){
			Roi.getBounds(xRoi, yRoi, widthRoi, heightRoi);
			
			lineNb=nResults;
			data=newArray(channels*2);
			index=0;
			
			getPixelSize(unit, pixelWidth, pixelHeight);

			//Get raw data
			for(j=1; j<=channels; j++){
				Stack.setChannel(j);
				makeOval(xRoi+widthRoi/2-size/2, yRoi+widthRoi/2-size/2, size, size);		

				List.setMeasurements;
				x=List.getValue("XM");
				y=List.getValue("YM");
				intensity=List.getValue("RawIntDen");
				area=List.getValue("Area");

				setResult("Label", lineNb, replace(name, "Detection_", ""));
				setResult("X_"+labels[(j-1)*2+1]+"_microns", lineNb, x); //In units
				setResult("Y_"+labels[(j-1)*2+1]+"_microns", lineNb, y); //In units
				setResult("Intensity_"+labels[(j-1)*2+1], lineNb, intensity);

				data[index++]=x;
				data[index++]=y;

				run("Make Band...", "band="+(widthRoi/2-size/2-1)*pixelWidth);
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

						distance=sqrt((x2-x1)*(x2-x1)+(y2-y1)*(y2-y1)); //No need to calibrate as the coordinates are calibrated
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
	applyLUTs();
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
	col=newArray(nResults);
	for(i=0; i<nResults; i++) col[i]=getResult(title, i);

	return col;
}

//-----------------------------------------
function getHistogramX(data, nBins){
	Array.getStatistics(data, min, max, mean, stdDev);
	histo=newArray(nBins+1);
	for(i=0; i<histo.length; i++) histo[i]=min+i*(max-min)/(nBins-1);

	return histo;
}

//-----------------------------------------
function getHistogramY(data, nBins){
	Array.getStatistics(data, min, max, mean, stdDev);
	histo=newArray(nBins+1);
	for(i=0; i<data.length; i++){
		position=(data[i]-min)/((max-min)/(nBins-1));
		histo[position]++;
	}

	return histo;
}

//-----------------------------------------
function exportAsFCS(labels, nLabels, out, basename){
	f=File.open(out+basename+"_CytoFile.txt");

	line="Label";
	for(j=0; j<nLabels; j++){
		line+=",Intensity_"+labels[j*2+1];
		line+=",Bkgd_Intensity_"+labels[j*2+1];
		line+=",Bkgd_Corr_Intensity_"+labels[j*2+1];
	}

	for(j=0; j<nLabels; j++){
		for(k=0; k<nLabels; k++){
			if(k>j) line+=",Distance_"+labels[j*2+1]+"-"+labels[k*2+1]+"_microns";
		}
	}
	
	print(f, line);

	for(i=0; i<nResults; i++){
		line=getResultString("Label", i);
		for(j=0; j<nLabels; j++){
			line+=","+round(getResult("Intensity_"+labels[j*2+1], i));
			line+=","+round(getResult("Bkgd_Intensity_"+labels[j*2+1], i));
			line+=","+round(getResult("Bkgd_Corr_Intensity_"+labels[j*2+1], i));
		}

		for(j=0; j<nLabels; j++){
			for(k=0; k<nLabels; k++){
				if(k>j) line+=","+getResult("Distance_"+labels[j*2+1]+"-"+labels[k*2+1]+"_microns");
			}
		}
		print(f, line);
	}
	File.close(f);
	result=File.rename(out+basename+"_CytoFile.txt", out+basename+"_CytoFile.csv");
}

//-----------------------------------------
function saveAll(dir, basename){
	format="ZIP";
	
	for(i=3; i<nImages; i++){
		selectImage(i);
		if(i>4) format="JPEG";
		saveAs(format, dir+basename+"_"+getTitle());
	}

	if(roiManager("Count")>0) roiManager("Save", dir+basename+"_RoiSet.zip");
}

//-----------------------------------------
function poolCSVFiles(dir, nameElement, hasHeader){
	csv=getFileNamesContaining(dir, nameElement);
	if(csv.length>0){
		content=File.openAsString(dir+csv[0]);
		for(i=1; i<csv.length; i++){
			toPush=File.openAsString(dir+csv[i]);
			if(hasHeader) toPush=substring(toPush, indexOf(toPush, "\n"));
			content+=toPush;
		}
		content=replace(content, "\n\n", "\n"); //To remove extra double carriage returns
		result=File.saveString(content, dir+"_Pooled_"+nameElement+".csv");
	}
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

//-----------------------------------------
function getFileNamesContaining(dir, part){
	tmp=getFileList(dir);
	filesList=newArray(0);

	for(i=0; i<tmp.length; i++) if(indexOf(tmp[i], part)!=-1) filesList=Array.concat(filesList, tmp[i]);

	return filesList;
}