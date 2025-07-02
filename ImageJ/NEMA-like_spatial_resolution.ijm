//---------------------------------------------------------
//  ImageJ Macro for NEMA-like Spatial Resolution
//  X direction, this macro is for a single direction
//---------------------------------------------------------

//---------------------Notes------------------------
//  For other directions, please modify/adjust this macro
//  For your specific image, you might need to adjust the numbers
//  You may have a look at NEMA Standards Publication NU 4-2008
// --------------- USER INPUTS ---------------

approxFWHM_pixels = 6; // Rough guess for FWHM in pixels
doFWTM            = true; // Also measure FWTM if desired


// --------------- MAIN EXECUTION ---------------

//Openning an image

//run("Raw...", "open=/path/to/your/image/file image=[32-bit Real] width=100 height=100 number=100 little-endian");

run("NucMed Open", "open=/path/to/your/image/file/metadata(header)");//Use this if you have installed NucMed

imageTitle = getTitle();

if (imageTitle == "") {
    exit("No image open! Please open a 3D image first.");
}

//===================================================================================
// Voxel size info retrieval //Do not use this if the image is opened as Raw -- specify voxel size in mm manually or some other way/
getVoxelSize(pxW, pxH, pxD, unit);
if (pxW == 0 || pxH == 0 || pxD == 0) {
    exit("Voxel size not defined. Use Image > Properties to set voxel dimensions.");
}

print(pxW+", "+pxH+", and "+pxD+", "+unit);

//====================================================================================
//pxW=0.25;

// Get image dimensions - two ways
//First way
getDimensions(width, height, channels, slices, frames);

/*
//2-Second way
width 	= getWidth;
height 	= getHeight;
depth 	= nSlices;
*/
//=======================================================================================

print("Starting NEMA-like resolution measurement in X-direction...");
print("Image: "+imageTitle);
print("Approx FWHM (pixels): " + approxFWHM_pixels);

// 1) Identify the slab in Y,Z directions that contain the center of the hotspot in the middle
//    To do so, First the center slice in Z and center row in Y is specified.
//    Depending on your application, you might pass the coordinates of this center points manually
//    to the algorithm and center your slab on that coordinate.
//    In our case, the middles of Y,Z contain the center.

centerY = floor(height/2); //120
centerZ = floor(slices/2);//70

// Each slab ranges from (centerY - 2*approxFWHM_pixels) to (centerY + 2*approxFWHM_pixels) in Y direction.
slabYmin = maxOf(0, centerY - 2*approxFWHM_pixels);
slabYmax = minOf(height-1, centerY + 2*approxFWHM_pixels);

// Similarly for Z.
slabZmin = maxOf(1, centerZ - 2*approxFWHM_pixels);
slabZmax = minOf(slices, centerZ + 2*approxFWHM_pixels);

// 2) Sum up all lines in X-direction that fall in slabY, slabZ

profileX = newArray(width);
for (z = slabZmin; z <= slabZmax; z++) {
    setSlice(z);
    for (y = slabYmin; y <= slabYmax; y++) {
        for (x = 0; x < width; x++) {
            val = getPixel(x, y);
//	    print("Value at location: "+x+"is: "+val); //Testing
            profileX[x] += val;
        }
    }
}

// 3) Find the peak index in that 1D profile
peakVal = -1;
peakIndex = -1;
for (i = 0; i < width; i++) {
    if (profileX[i] > peakVal) {
        peakVal = profileX[i];
        peakIndex = i;
    }
}

if (peakIndex < 1 || peakIndex >= width-1) {
    exit("Peak found at image boundary or not found. A 3-point parabolic fit is not feasible.");
}

// 4) Parabolic fit around the peak using peakIndex-1, peakIndex, peakIndex+1
//    We solve for a,b,c in p(x)=a*x^2 + b*x + c

X1 = peakIndex - 1;
X2 = peakIndex;
print("The index with the highest intensity: "+X2);//Testing, can be removed
X3 = peakIndex + 1;

Y1 = profileX[X1];
Y2 = profileX[X2];
Y3 = profileX[X3];


// Solve for a,b,c 


den = ((X2*X2 - X1*X1)*(X3 - X1)) -((X3*X3 - X1*X1)*(X2 - X1));

a = ( ( (X3 - X1)*(Y2 - Y1) ) - ( (X2 - X1)*(Y3 - Y1) ) ) / den;
b = ( ( (X2*X2 - X1*X1)*(Y3 - Y1) ) - ( (X3*X3 - X1*X1)*(Y2 - Y1) ) ) / den;
c = Y1 - (a*X1*X1 + b*X1);

// The peak of p(x)=a*x^2+b*x+c is at x = -b/(2a) (if a != 0).
// The "interpolated" peak x-position:
peakX_intrplt = -b / (2.0*a);

peakX_intrplt_mm = (peakX_intrplt * pxW);  

// The maximum value at that refined position:
peakVal_intrplt = a*peakX_intrplt*peakX_intrplt + b*peakX_intrplt + c;

// 5) Now find FWHM and FWTM by linear interpolation

halfVal  = 0.5 * peakVal_intrplt;
tenthVal = 0.1 * peakVal_intrplt;

// Defining a function to find left/right crossing for a given threshold
function findCrossings(profile, threshold) {
    size = lengthOf(profile);
    leftX = NaN;  rightX = NaN;
    
    // Find left crossing
    for (j = peakIndex; j > 0; j--) {
        if (profile[j] >= threshold && profile[j-1] < threshold) {
            // interpolate between j-1 and j
            frac = (threshold - profile[j-1]) / (profile[j] - profile[j-1]);
            leftX = (j-1) + frac; // in pixel indices
            break;
        }
    }
    // Find right crossing
    for (j = peakIndex; j < size; j++) {
        if (profile[j] >= threshold && profile[j+1] < threshold) {
            frac = (threshold - profile[j+1]) / (profile[j] - profile[j+1]);
            rightX = (j+1) - frac;
            break;
        }
    }
    return newArray(leftX, rightX);
}

crossHalf  = findCrossings(profileX, halfVal);
leftX_HF   = crossHalf[0];
rightX_HF  = crossHalf[1];

if (isNaN(leftX_HF) || isNaN(rightX_HF)) {
    exit("Could not find FWHM crossing points. Check data or use better initial guess!");
}
fwhm_pixels = rightX_HF - leftX_HF;

// FWTM
if (doFWTM) {
    crossTenth = findCrossings(profileX, tenthVal);
    leftX_T   = crossTenth[0];
    rightX_T  = crossTenth[1];
    if (isNaN(leftX_T) || isNaN(rightX_T)) {
        print("could not find FWTM crossing points.");
        fwtm_pixels = NaN;
    } else {
        fwtm_pixels = rightX_T - leftX_T;
    }
}

// 6) Convert to mm. Multiplying by pxW (assuming pxW is in mm).
fwhm_mm = fwhm_pixels * pxW;
fwhm_mm_rounded = toFixed(fwhm_mm, 2);

if (doFWTM && !isNaN(fwtm_pixels)) {
    fwtm_mm = fwtm_pixels * pxW;
    fwtm_mm_rounded = toFixed(fwtm_mm, 2);
}

// Print results
print("----------------------------------------------------");
print(" NEMA-like Spatial Resolution (X-direction)");
print(" Using slabY: "+slabYmin+".."+slabYmax+", slabZ: "+slabZmin+".."+slabZmax);
print(" Parabolic peak location in pixel= " + peakX_intrplt);
print(" Parabolic peak location in mm = " + peakX_intrplt_mm - 30);
print(" Parabolic peak value    = " + peakVal_intrplt);
print(" FWHM (pixels)           = " + fwhm_pixels);
print(" FWHM (mm)               = " + fwhm_mm_rounded);// + " " + unitStr);
if (doFWTM && !isNaN(fwtm_pixels)) {
    print(" FWTM (pixels)           = " + fwtm_pixels);
    print(" FWTM (mm)               = " + fwtm_mm_rounded);// + " " + unitStr);
}
print("----------------------------------------------------");

// Helper function - round a float to N decimal places
function toFixed(num, dPlaces) {
    factor = pow(10, dPlaces);
    return round(num*factor)/factor;
}
//Here is another choice to round a float number to N Decimal places
// https://stackoverflow.com/questions/2808535/round-a-double-to-2-decimal-places

/*
public static double round(double value, int places) {
    if (places < 0) throw new IllegalArgumentException();

    BigDecimal bd = BigDecimal.valueOf(value);
    bd = bd.setScale(places, RoundingMode.HALF_UP);
    return bd.doubleValue();
}
*/
