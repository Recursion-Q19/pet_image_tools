/*

EVALUATE AND COMPARE IMAGE QUALITY PARAMETERS
 in ImageJ. 
This macro is designed to get two images and computes uniformity, RC, and SOR values (according to NEMA NU 4- 2008 standard) for one of them (the second one here).

This macro will be updated and this the first draft
Full Description can be found in readme file. (will be added)

*/

run("Raw...", "open=/Path/to/the/direcotry/containing/the/image(binary)/something.img OR something.v image=[32-bit Real] width=200 height=200 number=150 little-endian"); //loaded image, change the path to the image here.
CASToR_imageTitle = getTitle();
Dialog.create("Upload Raw Image"); 
Dialog.addMessage("Choose an image please");
Dialog.show();
path = File.openDialog("Select a File");  
run("Raw...", "open=path image=[32-bit Real] width=200 height=200 number=150 little-endian");			
STIR_imageTitle = getTitle();

//image dimensions are known from (CASToR/STIR) generated log file

PIXEL_PER_mm_Taxial = 4; 
PIXEL_PER_mm_Axial = 2; 
img_width  = 200;                     
img_height = 200;
img_length = 150;//SM

macro NEMA_compare
	{	
		plotProfiles(CASToR_imageTitle, STIR_imageTitle);
		
		un = Uniformity(STIR_imageTitle);  
		RCvalues(un, STIR_imageTitle);  
		SORvalues(un, STIR_imageTitle);

		CloseWindow(CASToR_imageTitle);
		CloseWindow(STIR_imageTitle);		
//--------------------------------------------------------------------------------------------MAJOR FUNCTIONS---------------------------------------------------------------------------------------------
/*
1. takes two image titles as inputs image1, image2 
2. image1 -> Standard image title, image2 -> Test image title
3. Creates a dialog box for user-inputs to choose three regions along the z-axis in volume image
4. Then obtains an average image using Get_Z_Projection_AVG()
5. Draws a line profile and stores the intensities in an array using getProfile function
6. Uses those arrays to find Mean Square Error and Reduced Chi-Square values using calculateMSE, calculateChisqr functions
7. Finally displays a montage of comparison plot windows and average images generated.
*/

function plotProfiles(image1, image2)
	{
		n_Regions = 3; 	 //decided to look into three regions
		norm_factor = 1/100;  //normalized data for chisquare calculation.	
		Dialog.create("Choose Frame Settings ");
		Dialog.addNumber(" Region-1", 12); // 33, 57, 81 will appear by default for now chosen arbitrarily, user can enter a different number too
		Dialog.addNumber(" Region-2", 32);		
		Dialog.addNumber(" Region-3", 55);	
		Dialog.addNumber("Number of frames", 15);  //by default only 10 frames - user can change it in dialog box
		Dialog.show();		
		frame_initial_1  = Dialog.getNumber();
		frame_initial_2  = Dialog.getNumber();
		frame_initial_3  = Dialog.getNumber();
		n_frames = Dialog.getNumber();			
		frame_final_1 = frame_initial_1 + n_frames;
		frame_final_2 = frame_initial_2 + n_frames;
		frame_final_3 = frame_initial_3 + n_frames;		
		
		print("Figure of merits for estimating variance in a uniform region\n");

		// RMSE in uniform region 
		RMSE_Results(image1, image2, frame_initial_2, frame_final_2, 90, 90, 60, 60);  //  X,Y,W,H may change
		//percentage sd along large diameter rod 3 x 3 region over 30 slices
		Rod_Uniformity(image1);
		Rod_Uniformity(image2);
	
		// Mean Square Error and Reduced ChiSquared using user selected averaged regions
		
		AVG1 = Get_Z_Projection_AVG(image1, frame_initial_1 , frame_final_1); //returns the title of average image 
		AVG2 = Get_Z_Projection_AVG(image1, frame_initial_2 , frame_final_2); 
		AVG3 = Get_Z_Projection_AVG(image1, frame_initial_3 , frame_final_3); 
		//CloseWindow(image1);
		value1 = GetProfile(AVG1);  //returns an array of intenstity values to be plotted
		value2 = GetProfile(AVG2); 
		value3 = GetProfile(AVG3);
		test_AVG_1 = Get_Z_Projection_AVG(image2, frame_initial_1 , frame_final_1); //(test image region-1)
		test_AVG_2 = Get_Z_Projection_AVG(image2, frame_initial_2 , frame_final_2);	
		test_AVG_3 = Get_Z_Projection_AVG(image2, frame_initial_3 , frame_final_3); 	
		Inten_value1 = GetProfile(test_AVG_1);
		Inten_value2 = GetProfile(test_AVG_2);
		Inten_value3 = GetProfile(test_AVG_3);
	//exit();
		Out1 = calculateChisqrMSE(1,value1,Inten_value1);	// out1 is an array of size 2 containting mse and chiSqr values
		Out2 = calculateChisqrMSE(2,value2,Inten_value2);	// region 2
		Out3 = calculateChisqrMSE(3,value3,Inten_value3);	// region 3
		 	
		multiplot(1,value1,Inten_value1,Out1[0],Out1[1]); //creates a plot window comparing standard versus test image profiles, (these single windows are not being displayed )
		multiplot(2,value2,Inten_value2,Out2[0],Out2[1]); 
		multiplot(3,value3,Inten_value3,Out3[0],Out3[1]);

		selectWindow(AVG1); run("Duplicate...", "title=AVG1_copy");
		selectWindow(AVG2); run("Duplicate...", "title=AVG2_copy");
		selectWindow(AVG3); run("Duplicate...", "title=AVG3_copy");
	
		run("Images to Stack", "method=[Copy (center)] name=Stack1 title=[AVG] use"); //creates a stack (named "Stack1") of all 6 Average image windows which were open

selectWindow("Stack1"); //Added By Seyyed
run("Enhance Contrast...", "saturated=0.35 normalize process_all"); //Added By Seyyed

		run("Make Montage...", "columns=3 rows=2 scale=1");	 // makes a montage from Stacks window to display them in a single window
		rename("Average image comparison for selected regions");
	    setLocation(100, 340, 2500, 800);  // (x ,y ,width, height) adjusts the location of open window on screen (can be changed as per screen size)
		
		fontSize = 14;
   		setColor("white"); 
   		setFont("SansSerif", fontSize);  //font style, font size
	    	Overlay.drawString("CASToR", 10,20);  // draws string at specified location in active image at 5, 20
	    	Overlay.show;
	    	Overlay.drawString("STIR", 10,260);
	    	Overlay.show;   
		CloseWindow("Stack1");	
		run("Images to Stack", "method=[Copy (center)] name=Stack2 title=[Region] use"); //creates a stack (named "Stack2") of three plot windows 
selectWindow("Stack2"); //Added By Seyyed
run("Enhance Contrast...", "saturated=0.35 normalize equalize process_all"); //Added By Seyyed

		run("Make Montage...", "columns=3 rows=1 scale=1");	
		rename("Plot Profiles for Three Regions");
		setLocation(0, 0, 1600, 1200);  // (x ,y ,width, height)
		CloseWindow("Stack2");
		CloseWindow("Results");
		
	}	
	
	
	
	// ========================================NEMA SPECIFICATIONS ARE FOLLOWED FROM HERE=========================================================
	
           // ---------------------------------------------UNIFORMITY------------------------------------------------------------------------//         
           
function Uniformity(image)
	{
		nofFrames =  PIXEL_PER_mm_Axial*10;  
		diameter = 22.5*PIXEL_PER_mm_Taxial; //specified in NEMA publication
		startFrame =  32; //floor(22.5*PIXEL_PER_mm) central 10mm uniform region which is 2.5mm below and above the hot and cold regions respectively.
		stopFrame = nofFrames+startFrame;
		selectWindow(image);   
	
//--------------The maximum and minimum in the VOI is obtained here. It also returns a ROI mean per slice to obtain % S.D. -------------------------------------------
/*
Takes a region in the background region of diameter 22.5 mm and length 10 mm.
Draws a circle on each slice and return the mean, max, min IntIten etc and then create and save a summary using run("summarize). The %STD is gotten from those values
*/
		x_center = (img_width-diameter)/2;      //NOTE: defined the x and y for the top left coordinate of gliding rect
		y_center = (img_height-diameter)/2;
		Arr_Mean = newArray(nofFrames);
		Arr_Min = newArray(nofFrames);
		Arr_Max = newArray(nofFrames);

		run("Clear Results");

		for(currentslice = startFrame; currentslice != stopFrame; currentslice++)
			{                     
				setSlice(currentslice);
				makeOval(x_center, y_center, diameter, diameter); 
				run("Measure");
			}
        	//run("Summarize");           
   		
		for (i=0; i < nofFrames ; i++)
			{
				Arr_Mean[i] = getResult("Mean",i);      // getResult("Column name", Row_number) 
				Arr_Min[i] = getResult("Min",i);
   				//  Results table has the uniform region intensity values
				Arr_Max[i] = getResult("Max",i);					
			}
			
		CloseWindow("Results");   // mean, min, max, std and summarized results for uniform region 

 		run("Clear Results");
			
		Array.getStatistics(Arr_Mean, min_mean, max_mean, mean_mean, stdDev_mean); 
		print(" \n Mean_Intensity in Uniform region  is "+mean_mean);

		Array.getStatistics(Arr_Max, min_max, max_max, mean_max, stdDev_max);
		print(" \n Max_Intensity in Uniform region  is "+max_max);

		Array.getStatistics(Arr_Min, min_min, max_min, mean_min, stdDev_min);                   
		print(" \n Min_Intensity in Uniform region  is "+min_min);

		percentSD =  (stdDev_mean/mean_mean)*100;
		print("% S.D. "+percentSD);
		array_out = newArray(mean_mean, stdDev_mean);
		return array_out;
	}
 				 //------------------------------------------------------------------Recovery Coefficients------------------------------------------------------------------------//

/*
 *Creates an average image in five rods region
 *Draws 5 regions of interest within the rods diameter 
 *Obtains coordinates of max-intensity with selected ROIs
 *Creates new ROIs by doing the makeoval around max-intensity co-ordinates and adds them to ROI manager window 
 * Run multi measure-  for all the updated regions in ROI manager, the mean, std, min, max, along the z-direction in a Results table
 * create 5 arrays to store mean intensities from z-profiles of each of 5 rods obtained from Results window after multimeasure
 * Calculates Mean and %age SD along 5 rods
 */
function RCvalues(input_arr, image)	
	{
		nofFrames =  PIXEL_PER_mm_Axial*10;	
		startFrame= 59;  
		stopFrame = nofFrames+startFrame;


		//Arr_tmp = newArray(nofFrames);
	run("Clear Results");
		AVG_Image_RC = Get_Z_Projection_AVG(image, startFrame , stopFrame-1);  
	run("Clear Results");
		Five_ROI(AVG_Image_RC);     //create five ROIs 
	run("Clear Results");

		xy_coordinates = Get_Pixel_Coordinates_MaxInten(AVG_Image_RC); //Gets pixel location of the maximum coordinates 

		CloseWindow(AVG_Image_RC); //commented by SM  
		run("Clear Results");

		CloseWindow("Results");
		

 	// draw z-profile at that point
		for (i=0; i<5; i++){
			x = xy_coordinates[2*i];
	     	 	y = xy_coordinates[2*i+1];
			
			selectWindow(image); 
			makePoint(x,y);    			         
			roiManager("Add");
		}	
			
		roiManager("Select", newArray(10,11));
		roiManager("Select", newArray(10,11,12));
		roiManager("Select", newArray(10,11,12,13));
		roiManager("Select", newArray(10,11,12,13,14));//I think this line is enough

		run("Clear Results");

		roiManager("Multi Measure");
		print("\n5-Rod Regions Results : \n ");
		for(i = 1; i < 6; i++){
			Array_name	 = newArray(nofFrames);//newArray(rcRodend-rcRodstart+1);
			coord = newArray(0,0);
			coord[0] = getResult("X"+i, 0);
 			// column names for X,Y co-ordinates in Results table 
			coord[1] = getResult("Y"+i, 0);

			for( j=0; j < Array_name.length; j++){
				Array_name[j]= getResult("Mean"+i, j + startFrame);
				//print("slices: "+j+startFrame);	
			}
//exit();
			//Array.getStatistics(Array_name, min, max, mean, std); 
			Array.getStatistics(Array_name, min, max, mean, stdDev);
			print("Mean Intensity in hot region ("+coord[0]+","+coord[1]+")  is "+mean);  
			print("S.D. is  "+stdDev);  
			ReCoeff = mean/input_arr[0];
			print("RC"+i+" is "+ReCoeff);
			perc_sd =  (pow ( ( pow( (input_arr[1]/input_arr[0]), 2) +  pow((stdDev/mean), 2)), 0.5 ))*100;			
			print("%SD "+perc_sd+"\n" );
		}					
		CloseWindow("Results");   // this table has mean values of all 5 rods obtained from multi measure ROI manager command (skip closing if trying to verify what's in there)
	}
	
	//------------------------------------------------------------------SPILL OVER RATIO---------------------------------------------------------------------------------//
	
function SORvalues(input_arr,image) 
	{
		/*
		Details are in sec 6.4.3
		Create an average image over the segment containing the hot and cold region and extract profiles. Using regions defined by hand,
		 around the hot and cold regions, the mean, max and min and extracted and the spill over ratio SOR is calculated. 		
		Variables:
		nofFrames: Specifies the number of frames covering the center 7.5 mm of the region (specified in the NEMA doc).
		startFrame: Is the start frame for "startFrame" decided by observing the regions
		*/

		nofFrames = PIXEL_PER_mm_Axial*7.5;  // PIXEL_PER_mm*7.5 central 7.5 mm in length 
		startFrame = 13; // chosen by just looking at frames
        	stopFrame =  nofFrames+startFrame;
//print("StopFrame"+stopFrame);	
		//gets the z-projection of an image
		ImageSOR = Get_Z_Projection_AVG(image, startFrame , stopFrame);
		
		//CloseWindow(image);//Commented by SM
		
		//-ROI over the hot and cold region (get table of mean and std for selected regions)
                     
		Two_SOR_ROI(ImageSOR,input_arr);
	}

function Two_SOR_ROI(ImageSOR,input_arr)// inputs-> an average image to create ROIs, output_arr-> (has mean, std from Uniformity function) to calculate SOR, %STD  	
	{
	//ROI over the hot and cold region are created and added to the existing  ROI with name "Cold1" and "Cold2" (air filled and water filled regions)
		selectWindow(ImageSOR); 
		makeOval(82, 112, 16, 16);  //4 mm diameter,  half of the actual rod diameter
		roiManager("Add");
		makeOval(142, 112, 16, 16);
		roiManager("Add");
		run("Clear Results");
		preg = newArray("Cold1","Cold2"); 
		n = roiManager("count");

		run("Clear Results");
		CloseWindow("Results");
		
		for (i=n-2; i<n; i++)	
			{  //rename the newly created ROIs to Hot and Cold
		     	roiManager("select", i);
		     	roiManager("rename", preg[n-1-i]);
		     	run("Measure");
			}				
		//CloseWindow("ROI Manager");//remove comment if you want to cross verify the ROI manager regions
		CloseWindow(ImageSOR);				
		Mean_cold1 = getResult("Mean", 0);  // Row indeices start from 0 
		Mean_cold2 = getResult("Mean", 1);		
		std_cold1 = getResult("StdDev", 0);// make sure that StdDev is calculated -- in ImageJ menu go to  Analyze>>Set Measurements and tick (select) standard deviation
		std_cold2 = getResult("StdDev", 1);
			
		CloseWindow("Results");

		SOR1 = Mean_cold1 /input_arr[0];
		SOR2 = Mean_cold2 /input_arr[0];

		perc_sd1 = (pow (( pow((input_arr[1]/input_arr[0]), 2)  +  pow( (std_cold1/Mean_cold1) , 2) ), 0.5))*100;
		perc_sd2 = (pow (( pow((input_arr[1]/input_arr[0]), 2)  +  pow( (std_cold2/Mean_cold2) , 2) ), 0.5))*100;
		print("\nSOR Cold Region Results: \n");	
		print("SOR1 : "+SOR1+"   %SD1 : "+perc_sd1);
		print("SOR2 : "+SOR2+"   %SD2 : "+perc_sd2);

		run("Clear Results");
	}
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//==============================================================================================================================//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//Function --- Calculates ChiSQuare values for normalized Intensity values

function calculateChisqrMSE(region, array1, array2)		
	{
		diff_array = newArray(0);
		Array.getStatistics(array1, min1, max1, mean1, std1);
		Array.getStatistics(array2, min2, max2, mean2, std2);
		for(i=0; i<array1.length; i++)
			 {
				diff_array = Array.concat(diff_array, ((array1[i]-array2[i])*(array1[i]-array2[i]))/(array1[i]));
			 }
		NDF = diff_array.length;
		sum = 0;	
		for (i=0;i<diff_array.length; i++)		
			{
				sum = sum+ diff_array[i];
			}
			
		Rchi_square = sum/NDF;
		mse = calculateMSE(array1,array2);
		print("\nREGION"+region+" : Mean Square Error = "+mse+" Chisquared/"+NDF+" = "+Rchi_square);// Number of intensity values are used as degrees of freedom i.e.  Reduced Chi-Square value	
		temp = newArray(2);
		temp[0] = mse;
		temp[1] = Rchi_square;
		return temp; 
	}

//Function --- Calculates Mean Squared Error for normalized Intensity values------

function calculateMSE(array1,array2)
    	
	 {
		Array.getStatistics(array1, min1, max1, mean1, std1);
		Array.getStatistics(array2, min2, max2, mean2, std2);

		diff_array = newArray(0);  //initialize an array of size zero
		for(i=0; i<array1.length; i++)

		 	{
			 	diff_array = Array.concat(diff_array, (array1[i]-array2[i])*(array1[i]-array2[i]));
			}

		sum = 0;
		for (i=0;i<diff_array.length; i++)

			{
				sum = sum+ diff_array[i];
			}

		mse = sum/(diff_array.length);	
		return mse;
	}

//Function --- Gets you an average image

function Get_Z_Projection_AVG(img_name, start_frame , stop_frame)
	{
		/*	
		Takes in title of image stack, the start and stop frame. 
		Creates an average image (also known as a z-projection) from a stack input. 
		Parameters:
		 It takes three arguments. 
		img_name: The name of the stack that will be used to create the projected image
		start_frame: The left boundary of the average 
		stop_frame: The right boundary
		*/	
		selectWindow(img_name); 
		//run("Flip Horizontally", "stack");
		//run("Flip Z");
		run("Z Project...", "start="+start_frame+" stop="+stop_frame+" projection=[Average Intensity]"); //Create average image
		run("Gaussian Blur...", "sigma=2"); //Section 6.4.2 := The image slices covering the central 10 mm length of the rods shall be averaged to obtain a single image slice of lower noise. Gaussian because of lower noise probably
		return getTitle();
	}

//Function--- plot a selected profile

// create line selection using makeline function (co-ordinates were gotton from command recorder) Returns an array which is normalized here before being used to plot

function GetProfile(window) 
	{
		selectWindow(window);
		//makeLine(58, 61, 89, 101);	
//makeLine(55, 97, 100, 97);
makeLine(88, 90, 136, 155);
		Arr = getProfile();  //ARRAY OF INTENSITY VALUES
		Array.getStatistics(Arr, min, max, mean, stdDev);		
		Normalize(Arr, max);			
		Normalize(Arr, norm_factor); 							    
		return Arr;			
	}

// Function ----Creates five ROIs in an average image

function Five_ROI(img_AVG)	
	{
		/*
		Takes one argument, img_AVG, which is the title of the average image.
		Delete all existing ROIs at the start: Should be edited if intended to add on existing. Five ROIs are then created. These newly created
		ROIs corresponding to each of the circles and its rename to "RC_j" where j is the size of the hole
.
		The numbers used to create the region of interest were pre-determined parameters. They were extracted from images generated 
		via castor-recon with the VOI 106,106,122. So these numbers might change if the dimensions are changed.
		
		*/
		roiManager("reset");
		selectImage(img_AVG); 
		makeOval(145, 116, 8, 8); // 5,10,15,20,25 corresponds to 2 mm,4mm,6mm,8mm,10mm -which is twice the actual radius of the rods as specied by NEMA - 5 pixels = Pixel_per_mm_Taxial*2
		roiManager("add");
		makeOval(121, 139, 16, 16);
		roiManager("add");
		makeOval(86, 126, 24, 24);
		roiManager("add");
		makeOval(82, 87, 32, 32);
		roiManager("add");
		makeOval(110, 74, 40, 40);
		roiManager("add");		
	// goes through the ROI and rename them.....can refer to ROI manager functions.
		n = roiManager("count");
		for (i=0; i<n; i++)
			{
		   		 roiManager("select", i);
		 	 	 roiManager("rename","RC_"+i+1);
	 	  	 }
	
	}
//------------------------------------------------------------------------------

// Function --returns the coordinates of maximum intensity within 5 ROIs from Five_ROI function, to modify those ROIs considering those as centres

function Get_Pixel_Coordinates_MaxInten(AVG_img)
	{
		/*
		Loop through the various ROIs (five of them) and get the statistic which include max, mean etc. Using the pixel coordinates of the maximum, 
		a point is drawn and it's boundaries return. These boundaries are used to retrieve the x and y coordinates. The coordinates are then used
		to update the ROIs and an array containing them is returned.
		Parameters: 
		AVG_img: is the average image from on which the ROIs are created and whose maximum is obtained and used to update the ROI
		*/			
		XY_Coodinate = newArray(0,0,0,0,0,0,0,0,0,0);	
		n = roiManager("count");
		for (i=0; i<n; i++)
			{
				
				selectImage(AVG_img);  //selectImage(id)Activates the image with the specified ID (a negative number)
		
				roiManager("select", i);

				getStatistics(nPixels, mean, min, max);
				run("Find Maxima...", "noise="+0.0000001+" output=[Point Selection]");  

				getSelectionBounds(x, y, w, h); // retrieves the x and y coordinates of the max
							
				// Store coordinates of the maximum for each of the rods
 				setResult("X-coordinate", i, x);
 				setResult("Y-coordinate", i, y);
 				setResult("Maximum", i, getPixel(x,y)); 
			
 				XY_Coodinate[2*i] = x;
				XY_Coodinate[2*i+1] = y;

				d= 8*i+8; // 8,16,24,32,40
 				makeOval(x-d/2, y-d/2, d, d);//circle around the highest intensity - maxima in the middle
 				roiManager("add");	
     		} 
		updateResults();
		IJ.renameResults("Rod Coordinates"); //why rename and then close it?
		CloseWindow("Rod Coordinates");
		//print("works here 3");
		//Renaming the created ROIs
		Rename_ROI_RC();
		return XY_Coodinate;
	}

//---Function 

function Rename_ROI_RC()
	{
		/*
		Rename the created ROIs according to the dimension of the holes with RC_k_updated where k is the dimension of the hole.
		Because there are five existing ROIs, it will rename the last five.
		*/
		n = roiManager("count");
  // Starting from the end counting down
		for (i=n-1; i>n-6; i--)
			{   
			     roiManager("select", i);
			     roiManager("rename", "RC_"+i-4+"_updated");
			}
	}
	
//----Function--- Takes the x,y the coordinate of the maximum and make a plot along the z-axis of the whole image. Display the result

function Plot_Z_Profile(x,y,img_name)
	{
	   selectWindow(img_name); 
	   makePoint(x,y);        //Creates a point selection at location x,y
	   run("Plot Z-axis Profile");
	}

//----Function 

function multiplot(region, std_arr, test_arr, MSE, RCS)
			{	
				DF = std_arr.length;		
				Plot.create("Region-"+region , "Pixels", "Intensity", test_arr);				
				Plot.setColor("green");
				Plot.add("line",std_arr);
				Plot.setLimits(0, 82, 0, 105); // Plot.setLimits xMin, xMax, yMin, yMax
				Plot.addLegend("stir \n castor");
				Plot.addText("MSE:\n"+MSE+"\n"+"ChiSquared/"+DF+":\n"+RCS, 0.5, 0.8);
				Plot.show();					
			}

//---Function 	

function CloseWindow(title)
	{
		if (isOpen(title))
			{
         		selectWindow(title);
         		run("Close");
   			 }
	}		

//....Function

function Normalize(Arr, factor) 
	{
		for(i=0; i<Arr.length; i++)
			{
				Arr[i]= Arr[i]/factor;	
			}

		return Arr;
	}	
		
function RMSE_Results(original, test, frame_initial, frame_final, x, y, w, h)
	{
		Sum_Proj = Get_Z_Projection_SUM(original, frame_initial, frame_final);	
		ROI_values = GetImageResults(Sum_Proj, x, y, w, h);//Obtains Intensity values for an ROI
		CloseWindow(Sum_Proj);
		Array.getStatistics(ROI_values, min, max, mean, stdDev);	
		Normalize(ROI_values,max);	
		test_Sum_Proj = Get_Z_Projection_SUM(test, frame_initial , frame_final); // Uniform activity region in test image
		test_ROI_values = GetImageResults(test_Sum_Proj, x, y, w, h);
		CloseWindow(test_Sum_Proj);
		Array.getStatistics(test_ROI_values, min, max, mean, stdDev);	
		Normalize(test_ROI_values,max);			
		RMSE = calculateRMSE(ROI_values, test_ROI_values);
		print("Root mean square Error in Uniform Region = "+RMSE);	
					
	}

function Get_Z_Projection_SUM(img_name, start_frame , stop_frame)
	{
		/*	
		Takes in title of image stack, the start and stop frame. 
		Creates a SUM image (also known as a z-projection) from a stack input. 
		Parameters:
		 It takes three arguments. 
		img_name: The name of the stack that will be used to create the projected image
		start_frame: The left boundary of the average 
		stop_frame: The right boundary
		*/
		selectWindow(img_name); 
		run("Z Project...", "start="+start_frame+" stop="+stop_frame+" projection=[Sum Slices]"); //Create sum image
		//run("Gaussian Blur...", "sigma=2");
		return getTitle();
	}

function Rod_Uniformity(image)
	{
		size = 25;  //number of slices to obtain an average chosen arbitrarity within the hot rods length
		slice_number = 55;
		selectWindow(image);
		setSlice(slice_number);
		makeRectangle(125, 90, 8, 8);  // X,Y,W,H may change for 3 by 3 pixels region around the centre
		roiManager("Add");
		roiManager("Select", 0);
		roiManager("Multi Measure");
		selectWindow("Results");
		array = newArray(size);
		diffSqr_array =  newArray(size); 
		for (i = 0 ; i< size; i++)
		{
			array[i] = getResult("Mean1", i+slice_number );  // 70 TO 100	
		}
	
		Array.getStatistics(array, min, max, mean, stdDev);
	
		
		for (i = 0 ; i< size; i++)
			{
				diffSqr_array[i] = pow((array[i]-mean), 2);  // 70 TO 100	
			}
			sum = 0;
		for (i=0;i<diffSqr_array.length; i++)
			
				{
					sum = sum+ diffSqr_array[i];
				}
	
			//print(sum);
			RMSE_rod = (pow(sum/(size-1),0.5)/mean)*100 ;
			
		print("% age Standard Deviation for "+image+" = "+RMSE_rod);
		CloseWindow("Results");
		//roiManager("reset");
		//Selecting and delete the first ROI
		roiManager("Select", 0); 
		roiManager("Delete");
		CloseWindow("ROI Manager");
	}

	 
//Function --- Obtains Intensity values for an ROI -----
function GetImageResults(AVG,x,y,w,h)
		{
			selectWindow(AVG);
			makeOval(x,y,w,h);
			run("Image to Results");
		
			test_array = newArray(h);
			blank_array = newArray(0);
	
			for(k = 0; k < w; k++)
				{
					test_array = newArray(h);
					for(i = 0; i < test_array.length; i++)
						{
							test_array[i] = getResult("X"+x+k,i);
						}
			blank_array = append(blank_array, test_array);
				}		
			
			//Array.print(blank_array);
			//print(blank_array.length);
			CloseWindow("Results");
			
			return blank_array;
		} 
	 
function append(arr1, arr2)
	{
     //array = newArray(arr.length+4);
     	for (i=0; i<arr2.length; i++)
     		{
        		arr1 = Array.concat(arr1, arr2[i]);
     		}
     	return arr1;
  	}

function calculateRMSE(array1, array2)
    	
	 {
		Array.getStatistics(array1, min1, max1, mean1, std1);
		Array.getStatistics(array2, min2, max2, mean2, std2);

		diff_array = newArray(0);  //initialize an array of size zero
		for(i=0; i<array1.length; i++)

		 	{
			 	diff_array = Array.concat(diff_array, (array1[i]-array2[i])*(array1[i]-array2[i]));
			}

		sum = 0;
		for (i=0;i<diff_array.length; i++)

			{
				sum = sum+ diff_array[i];
			}

		rmse = sum/(diff_array.length);
		rmse = pow(rmse,0.5);
		return rmse;
	 }
	 	
}
 
//reached end












