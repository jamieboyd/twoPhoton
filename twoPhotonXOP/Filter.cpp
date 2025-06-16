#include "twoPhoton.h"
/**********************************************************************************************************************
 Code for filtering waves with 2D convolution kernels - arbitrary, symetrical, or median
 Last Modified 2025/06/13 by Jamie Boyd
 *********************************************************************************************************************/

/* Structure to pass data to each ConvolveFrames thread or ConvolveSymFrames thread
 Last Modified 2014/01/20 by Jamie Boyd */
typedef struct ConvolveFramesThreadParams{
	int inPutWaveType;		// WaveMetrics code for waveType
	char* inPutDataPtr; // pointer to start of input wave
	char* outPutDataPtr;// pointer to strat of output wave
	CountInt xSize;			// number of columns in each frame
	CountInt ySize;			// number of rows in each frame
	CountInt zSize;			// number of frames
	UInt8 ti;				// number of this thread, starting from 0
	UInt8 tN;				// total number of threads
	float * kernelDataPtr;	// pointer to start of kernel
    float * kernelTablePtr; // pointer to start of kernel table
	UInt16 kWidth;			// number of columns in kernel
	UInt16 kHeight;			// number of rows in kernel (ignored by convolveSymFrames)
	UInt8 isFloat;			// waveType of outPut wave. 0 for same type as input wave, 1 for floating point wave
} ConvolveFramesThreadParams, *ConvolveFramesThreadParamsPtr;


/******************************************************************************************************
 Function template to convolve a single row in an image.  Doesn't need to explicitly know image Y size/position within Y or Kernel Y size. Just needs to know start-Y and end-Y position in the kernel. So the same function can be called for any Y position in an image.
 Last modified 2014/01/24 by Jamie Boyd */
template <typename TI, typename TO> void ConvolveX (TI *srcWave, TO *&destWave, float *kernel, float *kernelTable, UInt16 nKernelX, UInt16 radKernelX, CountInt nWaveX, UInt16 endKernelY, UInt16 &startKernel, CountInt &startConvo, UInt16 &ikernelTable, UInt16 &toNextKernelX, CountInt &nConvoX, CountInt &toNextConvoX){
    
    CountInt iWaveX;
    CountInt iConvo;
    double outVal;
    UInt16 iKernel;
    UInt16 endKernelX;
    
    // X Loop for LEFT
    for (iWaveX= 0; iWaveX < radKernelX; iWaveX+=1){
        // Y Loop for Covolution
        outVal = 0;
        endKernelX = startKernel + nConvoX;
        for (iKernel = startKernel, iConvo = startConvo; iKernel < endKernelY; iKernel += toNextKernelX, iConvo += toNextConvoX){
            // X Loop for Convolution
            for (; iKernel <  endKernelX; iKernel += 1, iConvo += 1)
                outVal += srcWave [iConvo] * kernel [iKernel];
            endKernelX += nKernelX;
        } // end of Y loop for Convolution
        // set output value
        *destWave = outVal/kernelTable[ikernelTable];
        // get ready for next pixel in this row of TOP LEFT
        startKernel -= 1; // start convo 1  point earlier than for last pixel
        nConvoX +=1; // one more convo point per row than for last pixel
        toNextKernelX -=1;
        toNextConvoX -=1;
        ikernelTable += 1; // move tp next position in convo table
        destWave +=1;
    } // end of X loop for LEFT
    // X Loop for CENTRE
    for (; iWaveX < (nWaveX - radKernelX); iWaveX +=1){
        outVal = 0;
        endKernelX = startKernel + nConvoX;
        for (iKernel = startKernel, iConvo = startConvo; iKernel < endKernelY; iKernel += toNextKernelX, iConvo += toNextConvoX){
            // X Loop for Convolution
            for (; iKernel < endKernelX; iKernel += 1, iConvo += 1)
                outVal += srcWave [iConvo] * kernel [iKernel];
            endKernelX += nKernelX;
        } // end of Y loop for Convolution
        // set output value
        *destWave = outVal/kernelTable[ikernelTable];
        // get ready for next pixel in this row
        destWave +=1;
        startConvo += 1;
    }	// end of X loop for CENTRE
    // X Loop for RIGHT
    ikernelTable += 1; // move to next position in kernel table
    for (; iWaveX < nWaveX; iWaveX +=1){
        // get ready for next pixel in this row of TOP RIGHT
        nConvoX -=1; // one less convo point per row than for last pixel
        toNextKernelX +=1;
        toNextConvoX +=1;
        endKernelX = startKernel + nConvoX;
        outVal = 0;
        // Y loop for convolution
        for (iKernel = startKernel, iConvo = startConvo; iKernel < endKernelY; iKernel += toNextKernelX, iConvo += toNextConvoX){
            // X Loop for Convolution
            for (; iKernel < endKernelX; iKernel += 1, iConvo += 1)
                outVal += srcWave[iConvo] * kernel [iKernel];
            endKernelX += nKernelX;
        } // end of Y loop for Convo
        // set output value
        *destWave = outVal/kernelTable[ikernelTable];
        destWave +=1;
        startConvo += 1;
        ikernelTable += 1; // move to next position in kernel table
    } // End of X Loop for RIGHT
}


/****************************************************************************************************************
 function template for convolving one wave with another and putting results in an output wave.
 Input wave can be 2 or 3D, but each plane is done as a separate 2D image.
 Last Modified 2014/01/24 by Jamie Boyd */
template <typename TI, typename TO> int ConvolveT (TI* srcWave, TO* destWave, CountInt nWaveX, CountInt nWaveY, CountInt nWaveZ, float* kernel, float * kernelTable, UInt16 nKernelX, UInt16 nKernelY){
    
    UInt16 radKernelX = (nKernelX - 1)/2; //radius of the kernel width, not including the central pixel
    UInt16 radKernelY = (nKernelY - 1)/2; //radius of the kernel height, not including the central pixel
    UInt16 nKernel = nKernelX * nKernelY;
    CountInt fSize = (nWaveX * nWaveY);  //frame size
    
    // iterating through kernel and kernel table
    UInt16 ikernelTable; // position in kernelTable
    UInt16 startKernel; // position of kernel at start of convolution of first pixel of the row
    CountInt startFrameKernel = (radKernelY * nKernelX) + radKernelX;
    UInt16 endKernelY; // end point in kernel (determined by starting position and number of rows
    // Convolution variables
    CountInt startConvo; // position in the src wave for the convolution for first pixel in the row to convolve)
    CountInt toNextConvoX = nWaveX - radKernelX -1; // amount to add to iConvo to get to next row for convolution
	UInt16 toNextKernelX= radKernelX; // amount to add to iKernel to get to next row of kernel
	CountInt nConvoX = radKernelX + 1; // number of X to convolve at start of each line
    // Pointers to Push
    TI *srcFramePtr=srcWave; // will point to start of each frame in input image
    TO *destPixPtr; // will point to each pixel in turn in output image
    TI *srcEndPtr = srcWave + fSize * nWaveZ; // end of data to process
    // buffer, if we need one
    UInt8 inPlace = 0;
    TO *buffer;
    if ((TI*)destWave == (TI*)srcWave){
		inPlace = 1;
		//Make a buffer big enough to hold a single frame. Use it for dest wave for each frame
		buffer = (TO*) WMNewPtr (fSize *  sizeof (TO));
		if (buffer == NULL) return NOMEM;
        destPixPtr = buffer;
    }else{
        destPixPtr = destWave;
    }
	// Loop through all frames
    CountInt iWaveY;
    for (;srcFramePtr < srcEndPtr; srcFramePtr += fSize){
        // Y Loop for TOP (first radKernelY rows)
        ikernelTable = 0; // at start of frame, kernel table pos = 0
        startKernel=startFrameKernel;
        endKernelY=nKernel;
        for (iWaveY= 0;  iWaveY < radKernelY; iWaveY+=1){
            startConvo =0;
            ConvolveX (srcFramePtr, destPixPtr, kernel, kernelTable, nKernelX, radKernelX, nWaveX, endKernelY, startKernel, startConvo, ikernelTable, toNextKernelX, nConvoX, toNextConvoX);
            startKernel -= nKernelX -radKernelX;
        }
        // Y Loop for MIDDLE (up to nWaveY - radKernelY rows)
        startConvo =0;
        for (; iWaveY < (nWaveY - radKernelY); iWaveY +=1){
            startKernel = radKernelX;
            ConvolveX (srcFramePtr, destPixPtr, kernel, kernelTable, nKernelX, radKernelX, nWaveX, endKernelY, startKernel, startConvo, ikernelTable, toNextKernelX, nConvoX, toNextConvoX);
            ikernelTable -= nKernelX;
            startConvo += radKernelX;
        }
        // Loop for Y BOTTOM
        ikernelTable += nKernelX;
        for (;iWaveY < nWaveY;iWaveY +=1){
            startKernel = radKernelX;
            endKernelY -= nKernelX;
            ConvolveX (srcFramePtr, destPixPtr, kernel, kernelTable, nKernelX, radKernelX, nWaveX, endKernelY, startKernel, startConvo, ikernelTable, toNextKernelX, nConvoX, toNextConvoX);
            startConvo += radKernelX;
        }
        // at end of frame, copy buffer back on top of src wave if doing in place filtering
        if (inPlace){
            memcpy ((void*)srcFramePtr, (void*)buffer, fSize *  sizeof (TO));
            destPixPtr = buffer; // reset destination pixel to start of buffer
        }
    }
    // dispose of the temporary buffer we made
    if (inPlace)
        WMDisposePtr((Ptr)buffer);
    return 0;
}


/*****************************************************************************************************************
 Makes a table of weights for a 2D kernel
 Last Modified 2014/01/20 by Jamie Boyd */
float* ConvolveMakeKernelTable (float * kernel, int kWidth, int kHeight){
    
    int kRadH = (kHeight -1)/2;
	int kRadW = (kWidth-1)/2;
	int kSize = kWidth * kHeight;
    
    // allocate memory for kernel table
    float * kernelTablePtr =(float*) WMNewPtr (kSize * sizeof (float));
    if (kernelTablePtr == NULL) return NULL;
	int iConvo, convoEnd, convoToNextRow;
	int kx, ky;
	// get value for first point in kernel table
	int iKT =0;
 	kernelTablePtr [iKT] = 0;
	convoToNextRow=kRadW;
	//yLoop
	for (iConvo = kSize -1; iConvo >= (kSize/2); iConvo -= convoToNextRow){
		// xLoop
		for (convoEnd = iConvo - kRadW ; iConvo >= convoEnd; iConvo -=1){
			kernelTablePtr [iKT]  += kernel [iConvo];
        }
    }
    // get values for first column in kernelTable- adding a row to kernel each time
    for (iKT =kWidth; iKT <  (kSize/2) + 1;  iKT +=kWidth, iConvo -= convoToNextRow){
        kernelTablePtr [iKT] = kernelTablePtr [iKT -kWidth];
        // convo X
        for (convoEnd = iConvo - kRadW ; iConvo >= convoEnd; iConvo -=1){
            kernelTablePtr [iKT] += kernel [iConvo];
        }
    }
    // left edge bottom - removing a row from kernel each time
    for (iConvo = kSize -1; iKT < kSize; iKT += kWidth, iConvo -= convoToNextRow){
        kernelTablePtr [iKT] = kernelTablePtr [iKT -kWidth];
        // convo X
        for (convoEnd = iConvo - kRadW ; iConvo >= convoEnd; iConvo -=1){
            kernelTablePtr [iKT] -= kernel [iConvo];
        }
    }
    // Now do each row based on column 0 of that row
    // top
    for (ky =0, iKT =1; ky <= kRadH; ky +=1, iKT +=1){
        // top left - adding a new column at left each time
        for (kx =1; kx <= kRadW; kx +=1, iKT +=1){
            kernelTablePtr [iKT] = kernelTablePtr [iKT - 1];
            for (iConvo = (kRadH - ky)* kWidth + kRadW -kx; iConvo < kSize; iConvo += kWidth){
                kernelTablePtr [iKT] += kernel [iConvo];
            }
        }
        // top right - removing a column at right eadh time
        for (kx-=1; kx > 0; kx -=1, iKT +=1){
            kernelTablePtr [iKT] = kernelTablePtr [iKT - 1];
            for (iConvo =(kRadH - ky)* kWidth + kRadW + kx ; iConvo < kSize; iConvo += kWidth){
                kernelTablePtr [iKT] -= kernel [iConvo];
            }
        }
    }
    // bottom
    for (ky -=1; ky > 0; ky -=1, iKT +=1){
        // bottom left - adding a new column at left each time
        for (kx =1; kx <= kRadW; kx +=1, iKT +=1){
            kernelTablePtr [iKT] = kernelTablePtr [iKT - 1];
            for (iConvo = kRadW -kx, convoEnd = (kRadH + ky) * kWidth ; iConvo < convoEnd; iConvo += kWidth){
                kernelTablePtr [iKT] += kernel [iConvo];
            }
        }
        // bottom right - removing a  column at right each time
        for (kx -=1; kx > 0; kx -=1, iKT +=1){
            kernelTablePtr [iKT] = kernelTablePtr [iKT - 1];
            for (iConvo = kRadW + kx, convoEnd = (kRadH + ky) * kWidth; iConvo < convoEnd; iConvo += kWidth){
                kernelTablePtr [iKT] -= kernel [iConvo];
            }
        }
    }
    return kernelTablePtr;
}


/***********************************************************************************************************************
 Each thread to colvolve a range of frames starts with this function
 Last Modified 2014/01/20 by Jamie Boyd */
void* ConvolveFramesThread (void* threadarg){
    
	struct ConvolveFramesThreadParams* p;
	p = (struct ConvolveFramesThreadParams*) threadarg;
	CountInt tFrames = p->zSize/p->tN; //frames per thread = number of frames / number of threads, truncated to an integer
	CountInt startPos = p->ti * tFrames; // which frame to start this thread on depends on thread number * frames per thread. ti is 0 based
	if (p->ti == p->tN - 1) tFrames +=  (p->zSize % p->tN); // the last thread gets any left-over frames
	startPos *= (p->xSize * p->ySize); //change start position from frames to data points by multiplying by frame size
	if (p->isFloat){
		switch (p->inPutWaveType) {
            case NT_I8:
                ConvolveT ((char*)p->inPutDataPtr + startPos,(float*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p->kWidth, p->kHeight);
                break;
            case (NT_I8 | NT_UNSIGNED):
                ConvolveT ((unsigned char*)p->inPutDataPtr + startPos,(float*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p->kWidth, p->kHeight);
                break;
            case NT_I16:
                ConvolveT ((short*)p->inPutDataPtr + startPos,(float*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p->kWidth, p->kHeight);
                break;
            case (NT_I16 | NT_UNSIGNED):
                ConvolveT ((unsigned short*)p->inPutDataPtr + startPos,(float*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p->kWidth, p->kHeight);
                break;
            case NT_I32:
                ConvolveT ((long*)p->inPutDataPtr + startPos,(float*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p->kWidth, p->kHeight);
                break;
            case (NT_I32| NT_UNSIGNED):
                ConvolveT ((unsigned long*)p->inPutDataPtr + startPos,(float*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p->kWidth, p->kHeight);
                break;
            case NT_FP32:
                ConvolveT ((float*)p->inPutDataPtr + startPos,(float*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p->kWidth, p->kHeight);
                break;
            case NT_FP64:
                ConvolveT ((double*)p->inPutDataPtr + startPos,(float*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p->kWidth, p->kHeight);
                break;
            default:	// Unknown data type - possible in a future version of Igor.
                throw NT_FNOT_AVAIL;
                break;
		}
	}else {
		switch (p->inPutWaveType) {
            case NT_I8:
                ConvolveT ((char*)p->inPutDataPtr + startPos,(char*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr,p-> kWidth, p->kHeight);
                break;
            case (NT_I8 | NT_UNSIGNED):
                ConvolveT ((unsigned char*)p->inPutDataPtr + startPos,(unsigned char*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p->kWidth, p->kHeight);
                break;
            case NT_I16:
                ConvolveT ((short*)p->inPutDataPtr + startPos,(short*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p->kWidth, p->kHeight);
                break;
            case (NT_I16 | NT_UNSIGNED):
                ConvolveT ((unsigned short*)p->inPutDataPtr + startPos,(unsigned short*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p->kWidth, p->kHeight);
                break;
            case NT_I32:
                ConvolveT ((long*)p->inPutDataPtr + startPos,(long*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p->kWidth, p->kHeight);
                break;
            case (NT_I32| NT_UNSIGNED):
                ConvolveT ((unsigned long*)p->inPutDataPtr + startPos,(unsigned long*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p->kWidth, p->kHeight);
                break;
            case NT_FP32:
                ConvolveT ((float*)p->inPutDataPtr + startPos,(float*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p->kWidth, p->kHeight);
                break;
            case NT_FP64:
                ConvolveT ((double*)p->inPutDataPtr + startPos,(double*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p->kWidth, p->kHeight);
                break;
            default:	// Unknown data type - possible in a future version of Igor.
                throw NT_FNOT_AVAIL;
                break;
		}
	}
	return 0;
}

/****************************************************************************************************************
 Convolves a 2D or 3D wave with a smaller 2D wave (the kernel), and sends the output to an output wave.
 Treats each plane in a 3D wave as a separate image
 Convolves any type of input wave and outputs to either the same type of wave, or to a 32 bit floating point wave
 Last modified 2025/06/13 by Jamie Boyd
 
 typedef struct ConvolveFramesParams{
 double overWrite; // 1 if it is o.k. to overwrite existing waves, 0 to exit with error
 waveHndl kernelH;	// convolution kernel, a 2D wave odd number of pixels high and wide
 double outPutType; // 0 for same type as input wave, non-zero for floating point wave
 Handle outPutPath;	// A handle to a string containing path to output wave we want to make, or empty string to overwrite existing wave
 waveHndl inPutWaveH;//input wave. needs to be 3D wave
 double result;*/

int ConvolveFrames(ConvolveFramesParamsPtr p){
	int result = 0;	// The error returned from various Wavemetrics functions
	waveHndl inPutWaveH, outPutWaveH, kernelH;		// handles to the input and output waves and the kernel
	int inPutWaveType, kernelWaveType; //  Wavetypes numeric codes for things like 32 bit floating point, 16 bit int, etc
    int inPutDimensions, kernelDimensions;	// number of dimensions in input and kernel waves
	CountInt inPutDimensionSizes[MAX_DIMENSIONS+1], kernelDimensionSizes[MAX_DIMENSIONS+1];	// an array used to hold the width, height, layers, and chunk sizes
	CountInt zSize; // we need this separate from array for size calculation
    BCInt inPutOffset, outPutOffset, kernelOffset;	//offset in bytes from begnning of handle to a wave to the actual data - size of headers, units, etc.
	DataFolderHandle inPutDFHandle, outPutDFHandle;	// Handle to the datafolder where we will put the output wave
	DFPATH inPutPath, outPutPath; // strings to hold data folder paths of input and outPut waves
	//char inPutPath [MAXCMDLEN + 1], outPutPath [MAXCMDLEN + 1];
	WVNAME inPutWaveName, outPutWaveName; // C strings to hold names of input and output waves
	UInt8 overWrite = (UInt8)(p->overWrite);	// 0 to not overwrite output wave if it already exists, 1 to overwrite old waves
	UInt8 isFloat = (UInt8)(p-> outPutType); // 0 to use input type for output, non-zero to use make bit floating point output
	UInt8 isOverWriting; // non-zero if output is overwriting input wave
    float *kernelTablePtr; // kernel table (calculated weighting for truncation of convolution at edges)
	UInt16 kSize;
	UInt8 iThread, nThreads = gNumProcessors;
	char *inPutDataStartPtr, *outPutDataStartPtr, *kernelDataStartPtr;
	try{
		// Get handles to input wave and kernel. Make sure both waves exist.
		inPutWaveH = p->inPutWaveH;
		kernelH = p ->kernelH;
		if ((inPutWaveH == NIL)||(kernelH == NIL))
			throw result = NON_EXISTENT_WAVE;
		// Get wave data type
		inPutWaveType = WaveType(inPutWaveH);
		if (inPutWaveType==TEXT_WAVE_TYPE)
			throw result = NOTEXTWAVES;
		// Get number of used dimensions in waves.
		if (result = MDGetWaveDimensions(inPutWaveH, &inPutDimensions, inPutDimensionSizes))
			throw result;
		// Check that inputwave is 2D or 3D
		if ((inPutDimensions == 1) || (inPutDimensions == 4))
			throw result = INPUTNEEDS_2D3D_WAVE;
        // if z size is 0, make it 1 to calculate size
        if (inPutDimensionSizes [2] == 0)
            zSize = 1;
        else
            zSize=inPutDimensionSizes [2];
		//	Check that kernel is 2D, and of odd dimensions
		if (result = MDGetWaveDimensions(kernelH, &kernelDimensions, kernelDimensionSizes))
			throw result;
		if ((((kernelDimensions != 2) || ((kernelDimensionSizes[0] % 2) == 0)) || ((kernelDimensionSizes[1] % 2) == 0)))
			throw result = BADKERNEL;
		// make sure kernel is 32 bit float - change if necessary
		kernelWaveType = WaveType (kernelH);
		if (kernelWaveType !=  (NT_FP32))
			MDChangeWave (kernelH, NT_FP32, kernelDimensionSizes);
		// If outPutPath is empty string, we are overwriting existing wave
		if (WMGetHandleSize (p->outPutPath) == 0){
			if (overWrite == NO_OVERWITE) throw result = OVERWRITEALERT;
			if (isFloat){ //redimension input/output wave to 32bit floating point
				if (result = MDChangeWave(inPutWaveH, NT_FP32, inPutDimensionSizes)) throw result;
			}
			outPutWaveH = inPutWaveH;
			isOverWriting = 1;
		}else{ // Parse outPut path for folder path and wave name
			ParseWavePath (p->outPutPath, outPutPath, outPutWaveName);
			//Check to see if output path is valid
			if (result = GetNamedDataFolder (NULL, outPutPath, &outPutDFHandle))throw result;
			// Test name and data folder for output wave against the input wave to prevent accidental overwriting, if src and dest are the same
			WaveName (inPutWaveH, inPutWaveName);
			GetWavesDataFolder (inPutWaveH, &inPutDFHandle);
			GetDataFolderNameOrPath (inPutDFHandle, 1, inPutPath);
			if ((!(CmpStr (inPutPath,outPutPath))) && (!(CmpStr (inPutWaveName,outPutWaveName)))){	// Then we would overwrite wave
				isOverWriting = 1;
				if (overWrite == NO_OVERWITE) throw result = OVERWRITEALERT;
				if (isFloat){ //redimesnion input wave to 32bit floating point
					if (result = MDChangeWave(inPutWaveH, NT_FP32, inPutDimensionSizes)) throw result;
				}
				outPutWaveH = inPutWaveH;
			}else{
				isOverWriting = 0;
				// make the output wave
				//No liberal wave names for output wave
				CleanupName (0, outPutWaveName, MAX_OBJ_NAME);
				if (isFloat){
					if (result = MDMakeWave (&outPutWaveH, outPutWaveName, outPutDFHandle, inPutDimensionSizes, NT_FP32, overWrite))
						throw result;
				}else{
					if (result = MDMakeWave (&outPutWaveH, outPutWaveName, outPutDFHandle, inPutDimensionSizes, inPutWaveType, overWrite))
						throw result;
				}
			}
		}
	}catch (int result){ // catch before allocating any memory
		p -> result = result;
		return (result);	// XFUNC error code.
	}try{
        //Get data offsets for the 3 waves (2 waves, if overwriting)
		if (result = MDAccessNumericWaveData(inPutWaveH, kMDWaveAccessMode0, &inPutOffset))
			throw result;
		if (isOverWriting){
			outPutOffset = inPutOffset;
		}else{
			if (result = MDAccessNumericWaveData(outPutWaveH, kMDWaveAccessMode0, &outPutOffset))
				throw result;
		}
		if (result = MDAccessNumericWaveData(kernelH, kMDWaveAccessMode0, &kernelOffset))
			throw result;
        inPutDataStartPtr = (char*)(*inPutWaveH) + inPutOffset;
		outPutDataStartPtr =  (char*)(*outPutWaveH) + outPutOffset;
        kernelDataStartPtr = (char*)(*kernelH) + kernelOffset;
        //make kernel table.
		kSize = kernelDimensionSizes[0] * kernelDimensionSizes[1];
		kernelTablePtr =ConvolveMakeKernelTable ((float*)kernelDataStartPtr, (int)kernelDimensionSizes[0], (int) kernelDimensionSizes[1]);
		if (kernelTablePtr == NULL)
			throw result = NOMEM;
    }catch (int (result)) { // catch before allocating any memory
		p -> result = result;				// XFUNC error code
		return (result);
    }
    // multiprocessor initialization
    // make an array of parameter structures
    if (zSize < nThreads) nThreads = zSize;
    ConvolveFramesThreadParamsPtr paramArrayPtr= (ConvolveFramesThreadParamsPtr)WMNewPtr (nThreads * sizeof(ConvolveFramesThreadParams));
    for (iThread = 0; iThread < nThreads; iThread++){
        paramArrayPtr[iThread].inPutWaveType = inPutWaveType;
        paramArrayPtr[iThread].inPutDataPtr = inPutDataStartPtr;
        paramArrayPtr[iThread].outPutDataPtr = outPutDataStartPtr;
        paramArrayPtr[iThread].xSize = inPutDimensionSizes [0];
        paramArrayPtr[iThread].ySize = inPutDimensionSizes [1];
        paramArrayPtr[iThread].zSize = zSize;
        paramArrayPtr[iThread].ti=iThread; // number of this thread, starting from 0
        paramArrayPtr[iThread].tN =nThreads; // total number of threads
        paramArrayPtr[iThread].kernelDataPtr=(float*)kernelDataStartPtr;
        paramArrayPtr[iThread].kernelTablePtr=kernelTablePtr;
        paramArrayPtr[iThread].kWidth = kernelDimensionSizes [0];
        paramArrayPtr[iThread].kHeight= kernelDimensionSizes [1];
        paramArrayPtr[iThread].isFloat = isFloat; // 0 for same type as input wave, non-zero for floating point wave
    }
    // make an array of pthread_t
    pthread_t* threadsPtr =(pthread_t*)WMNewPtr(nThreads * sizeof(pthread_t));
    // create the threads
    for (iThread = 0; iThread < nThreads; iThread++){
        pthread_create (&threadsPtr[iThread], NULL, ConvolveFramesThread, (void *) &paramArrayPtr[iThread]);
    }
    // Wait till all the threads are finished
    for (iThread = 0; iThread < nThreads; iThread++){
        pthread_join (threadsPtr[iThread], NULL);
    }
    // free memory for pThreads Array
    WMDisposePtr ((Ptr)threadsPtr);
    // Free paramaterArray memory
    WMDisposePtr ((Ptr)paramArrayPtr);
    //free kernel table memory
    WMDisposePtr ((Ptr)kernelTablePtr);
    WaveHandleModified(outPutWaveH);			// Inform Igor that we have changed the output wave.
    p -> result = result;				// // XFUNC error code will be 0
    return (result);
}

/*****************************************************************************************************************
 Makes and returns a table of weights for a 1D kernel, first Checking that the kernel is, indeed, symetrical
 returns a null pointer if kernel is not symetrical
 Last Modified 2014/01/21 by Jamie Boyd */
float * SymConvolveMakeKernelTable (float * kernel, UInt16 kWidth){
    
    // kernel has to be odd
    if((kWidth % 2) ==0) return NIL;
    // check symetry
    // Get sum of entire kernel for making kernel table while we are at it
    UInt16 kRadW = (kWidth-1)/2; // radius of kernel, not counting central point
    UInt16 iKT, iConvo;
    float kSum=0;
    for (iKT =0, iConvo = kWidth -1; iKT < kRadW; iKT +=1, iConvo -=1){
        if (kernel [iKT] != kernel [iConvo]) return NIL;
        kSum += kernel [iKT] + kernel [iConvo];
    }
    // If we get to here, kernel is symetrical. Sum of kernel lacks central point
    kSum += kernel [kRadW];
    // make kernel table. It's symetrical, so we only need to make size kRadW + 1
    float *kernelTable =(float*) WMNewPtr ((kRadW + 1) * sizeof (float));
    if (kernelTable == NIL) return NIL;
    // last point = kernel sum
    kernelTable [kRadW] = kSum;
    // each earlier point removes a value from left side
    iKT = kRadW-1;
    for (iConvo = 0; iKT >0; iKT -=1, iConvo +=1)
        kernelTable [iKT] = kernelTable [iKT + 1] - kernel [iConvo];
    kernelTable [iKT] = kernelTable [iKT + 1] - kernel [iConvo];
    return kernelTable;
}


/****************************************************************************************************************
 template function for convolving one wave with a 1D symetrical kernel (e.g., Guassian) and putting results in an output wave.
 Input wave can be 2 or 3D, but each plane is done as a separate 2D image.
 Last Modified 2014/01/21 by Jamie Boyd */
template <typename TI, typename TO> int SymConvolveT (TI* srcWave, TO* destWave, CountInt nWaveX, CountInt nWaveY, CountInt nWaveZ, float* kernel, float * kernelTable, UInt16 kWidth){
    
    // make 1D buffer big enough to hold a single frame
    CountInt frameSize = nWaveX * nWaveY;
    double *buffer = (double *) WMNewPtr (frameSize * sizeof (double));
    if (buffer == NIL) return 1;
    //variables for iterating through waves
    UInt16 kRad = (kWidth-1)/2; // radius of kernel, not including the central point
    //CountInt nWave = frameSize * nWaveZ;
    //Position of pixel in x,y,z
    CountInt iWaveY,  iWaveX;
    //CountInt nEdgeY = kRad * nWaveX;
    // iterating through kernel and convo positions, linear
    CountInt iKernel, iConvo, iKernelTable=0, convoStart, kernelStart, kernelEnd;
    // temporary value to calculate value for each pixel
    double outVal;
    CountInt iOut; // position of output value, in buffer, then in output wave
    TI* srcFramePtr = srcWave;
    TI* srcEndPtr = srcWave + frameSize * nWaveZ;
    TO* destFramePtr = destWave;
    for (; srcFramePtr < srcEndPtr; srcFramePtr += frameSize, destFramePtr += frameSize){
        // Do Y filtering first, sending output to frame buffer. each Y starts at startFrameP + iWaveX
        for (iWaveX =0; iWaveX < nWaveX; iWaveX +=1){
            // TOP of each row.
            iOut = iWaveX;
            convoStart = iWaveX;
            kernelStart = kRad;
            kernelEnd = kWidth;
            for (iWaveY=0; iWaveY < kRad; iWaveY += 1){
                // convolution in Y
                outVal =0;
                for (iKernel =kernelStart, iConvo =convoStart; iKernel < kernelEnd; iKernel +=1, iConvo += nWaveX)
                    outVal += srcFramePtr [iConvo] * kernel [iKernel];
                buffer [iOut] = outVal / kernelTable [iKernelTable];
                kernelStart -=1;
                iKernelTable +=1;
                iOut += nWaveX;
            }
            // Middle of each row
            for (; iWaveY < (nWaveY - kRad); iWaveY += 1){
                outVal =0;
                // convolution in Y
                for (iKernel =kernelStart, iConvo =convoStart; iKernel < kernelEnd; iKernel +=1, iConvo += nWaveX)
                    outVal += srcFramePtr [iConvo] * kernel [iKernel];
                buffer [iOut] = outVal / kernelTable [iKernelTable];
                convoStart += nWaveX;
                iOut += nWaveX;
            }
            // bottom of each row
            for (; iWaveY < nWaveY; iWaveY += 1){
                kernelEnd -=1;
                iKernelTable -=1;
                // convolution in Y
                outVal =0;
                for (iKernel =kernelStart, iConvo =convoStart; iKernel < kernelEnd; iKernel +=1, iConvo += nWaveX)
                    outVal += srcFramePtr [iConvo] * kernel [iKernel];
                buffer [iOut] = outVal / kernelTable [iKernelTable];
                convoStart += nWaveX;
                iOut += nWaveX;
            }
        }
        // Do X filtering second, sending output to output wave.
        iOut =0;
        convoStart = 0;
        for (iWaveY=0; iWaveY < nWaveY; iWaveY +=1){
            kernelStart = kRad;
            kernelEnd = kWidth;
            // left edge
            for (iWaveX =0; iWaveX < kRad; iWaveX +=1){
                // convolution in X
                outVal =0;
                for (iKernel =kernelStart, iConvo =convoStart; iKernel < kernelEnd; iKernel +=1, iConvo += 1)
                    outVal += buffer [iConvo] * kernel [iKernel];
                destFramePtr [iOut] = outVal / kernelTable [iKernelTable];
                kernelStart -=1;
                iKernelTable +=1;
                iOut += 1;
            }
            // Middle
            for (; iWaveX < (nWaveX - kRad); iWaveX+= 1){
                outVal =0;
                // convolution in X
                for (iKernel =kernelStart, iConvo =convoStart; iKernel < kernelEnd; iKernel +=1, iConvo += 1)
                    outVal += buffer [iConvo] * kernel [iKernel];
                destFramePtr [iOut] = outVal / kernelTable [iKernelTable];
                convoStart += 1;
                iOut += 1;
            }
            // right edge
            for (; iWaveX< nWaveX; iWaveX += 1){
                kernelEnd -=1;
                iKernelTable -=1;
                // convolution in X
                outVal =0;
                for (iKernel =kernelStart, iConvo =convoStart; iKernel < kernelEnd; iKernel +=1, iConvo += 1)
                    outVal += buffer [iConvo] * kernel [iKernel];
                destFramePtr [iOut] = outVal/ kernelTable [iKernelTable];
                convoStart += 1;
                iOut += 1;
            }
            convoStart += kRad; // get to next row for x filtering
        }
    }
    WMDisposePtr ((Ptr)buffer);
}

/***********************************************************************************************************************
 Each thread to symetrically convolve a range of frames starts with this function
 Last Modified 2025/06/13 by Jamie Boyd */
void* SymConvolveFramesThread (void* threadarg){
    
    struct ConvolveFramesThreadParams* p;
    p = (struct ConvolveFramesThreadParams*) threadarg;
    CountInt tFrames = p->zSize/p->tN; //frames per thread = number of frames / number of threads, truncated to an integer
    CountInt startPos = p->ti * tFrames; // whaich frame to start this thread on depends on thread number * frames per thread. ti is 0 based
    if (p->ti == p->tN - 1) tFrames +=  (p->zSize % p->tN); // the last thread gets any left-over frames
    startPos *= (p->xSize * p->ySize); //change start position from frames to data points by multiplying by frame size
    if (p->isFloat){
        switch (p->inPutWaveType) {
            case NT_I8:
                SymConvolveT ((char*)p->inPutDataPtr + startPos,(float*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p-> kWidth);
                break;
            case (NT_I8 | NT_UNSIGNED):
                SymConvolveT ((unsigned char*)p->inPutDataPtr + startPos,(float*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p-> kWidth);
                break;
            case NT_I16:
                SymConvolveT ((short*)p->inPutDataPtr + startPos,(float*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p-> kWidth);
                break;
            case (NT_I16 | NT_UNSIGNED):
                SymConvolveT ((unsigned short*)p->inPutDataPtr + startPos,(float*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p-> kWidth);
                break;
            case NT_I32:
                SymConvolveT ((long*)p->inPutDataPtr + startPos,(float*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p-> kWidth);
                break;
            case (NT_I32| NT_UNSIGNED):
                SymConvolveT ((unsigned long*)p->inPutDataPtr + startPos,(float*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p-> kWidth);
                break;
            case NT_FP32:
                SymConvolveT ((float*)p->inPutDataPtr + startPos,(float*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p-> kWidth);
                break;
            case NT_FP64:
                SymConvolveT ((double*)p->inPutDataPtr + startPos,(float*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p-> kWidth);
                break;
            default:	// Unknown data type - possible in a future version of Igor.
                throw NT_FNOT_AVAIL;
                break;
        }
    }else {
        switch (p->inPutWaveType) {
            case NT_I8:
                SymConvolveT ((char*)p->inPutDataPtr + startPos,(char*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p-> kWidth);
                break;
            case (NT_I8 | NT_UNSIGNED):
                SymConvolveT ((unsigned char*)p->inPutDataPtr + startPos,(unsigned char*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p-> kWidth);
                break;
            case NT_I16:
                SymConvolveT ((short*)p->inPutDataPtr + startPos,(short*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p-> kWidth);
                break;
            case (NT_I16 | NT_UNSIGNED):
                SymConvolveT ((unsigned short*)p->inPutDataPtr + startPos,(unsigned short*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p-> kWidth);
                break;
            case NT_I32:
                SymConvolveT ((long*)p->inPutDataPtr + startPos,(long*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p-> kWidth);
                break;
            case (NT_I32| NT_UNSIGNED):
                SymConvolveT ((unsigned long*)p->inPutDataPtr + startPos,(unsigned long*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p-> kWidth);
                break;
            case NT_FP32:
                SymConvolveT ((float*)p->inPutDataPtr + startPos,(float*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p-> kWidth);
                break;
            case NT_FP64:
                SymConvolveT ((double*)p->inPutDataPtr + startPos,(double*)p->outPutDataPtr + startPos, p->xSize, p->ySize, tFrames, p->kernelDataPtr, p->kernelTablePtr, p-> kWidth);
                break;
            default:	// Unknown data type - possible in a future version of Igor.
                throw NT_FNOT_AVAIL;
                break;
        }
    }
    return 0;
}

/****************************************************************************************************************
 Convolves a 2D or 3D wave with a 1D symetrical kernel, and sends the output to an output wave.
 Treats each plane in a 3D wave as a separate image
 Convolves any type of input wave and outputs to either the same type of wave,  or to a 32 bit floating point wave
 Last modified 2025/06/13 by Jamie Boyd
 
 typedef struct ConvolveFramesParams{
 double overWrite; // 1 if it is o.k. to overwrite existing waves, 0 to exit with error if overwriting will occur
 waveHndl kernelH; // convolution kernel, a 2D wave odd number of pixels high and wide, or 1D odd number wave for Sym
 double outPutType; // 0 for same type as input wave, non-zero for floating point wave
 Handle outPutPath;	// A handle to a string containing path to output wave we want to make, or empty string to overwrite existing wave
 waveHndl inPutWaveH; //input wave. needs to be 2D or 3D wave
 double result;
 } ConvolveFramesParams, *ConvolveFramesParamsPtr
 */

int SymConvolveFrames(ConvolveFramesParamsPtr p)
{
    int result = 0;	// The error returned from various Wavemetrics functions
    waveHndl inPutWaveH, outPutWaveH, kernelH;		// handles to the input wave, output wave (we create) and kernel wave
    int inPutWaveType; //  Wavetypes numeric codes for things like 32 bit floating point, 16 bit int, etc
    int inPutDimensions;	// number of dimensions in input wave
    CountInt inPutDimensionSizes[MAX_DIMENSIONS+1];	// an array used to hold the width, height, layers, and chunk sizes
    CountInt zSize;
    int kernelType;
    int kernelDimensions;
    CountInt kernelDimensionSizes[MAX_DIMENSIONS+1];	// an array used to hold the width, height, layers, and chunk sizes
    BCInt inPutOffset, outPutOffset, kernelOffset;	//offset in bytes from begnning of handle to a wave to the actual data - size of headers, units, etc.
    DataFolderHandle inPutDFHandle, outPutDFHandle;	// Handle to the datafolder where we will put the output wave
    DFPATH inPutPath, outPutPath; // strings to hold data folder paths of input and outPut waves
    //char inPutPath [MAXCMDLEN + 1], outPutPath [MAXCMDLEN + 1];
    WVNAME inPutWaveName, outPutWaveName; // C strings to hold names of input and output waves
    //char inPutWaveName[MAX_OBJ_NAME + 1], outPutWaveName[MAX_OBJ_NAME + 1];	// C strings to hold names of input and output waves
    UInt8 overWrite = (UInt8)(p->overWrite);	// 0 to not overwrite output wave if it already exists, 1 to overwrite old waves
    UInt8 isFloat = (UInt8)(p-> outPutType); // 0 to use input type, non-zero to use 32 bit floating point
    UInt8 isOverWriting; // non-zero if output is overwriting input wave
    float *kernelTable;
    float * kPtr;
    float kSum;
    UInt8 iThread, nThreads = gNumProcessors;
    char *inPutDataStartPtr, *outPutDataStartPtr, *kernelDataStartPtr;
    try{
        // Get handles to input wave and kernel.
        inPutWaveH = p->inPutWaveH;
        if (inPutWaveH == NIL)
            throw result = NON_EXISTENT_WAVE;
        // Get wave data type
        inPutWaveType = WaveType(inPutWaveH);
        if (inPutWaveType==TEXT_WAVE_TYPE)
            throw result = NOTEXTWAVES;
        // Get number of used dimensions in waves.
        if (result = MDGetWaveDimensions(inPutWaveH, &inPutDimensions, inPutDimensionSizes))
            throw result;
        // Check that inputwave is 2D or 3D
        if ((inPutDimensions == 1) || (inPutDimensions == 4))
            throw result = INPUTNEEDS_2D3D_WAVE;
        // if z size is 0, make it 1 to calculate size
        if (inPutDimensionSizes [2] == 0)
            zSize = 1;
        else
            zSize=inPutDimensionSizes [2];        //	make sure kernel exists and is 1D and of odd dimensions
        kernelH = p->kernelH;
        if (kernelH == NIL)
            throw result = NON_EXISTENT_WAVE;
        // Get number of used dimensions in kernel.
        if (result = MDGetWaveDimensions(kernelH, &kernelDimensions, kernelDimensionSizes))
            throw result;
        if (kernelDimensions > 1)
            throw result = BADSYMKERNEL;
        if ((kernelDimensionSizes [0] % 2) == 0)
            throw result = BADSYMKERNEL;
        // Get kernel wave data type, and make other numeric types float
        kernelType = WaveType(kernelH);
        if (kernelType==TEXT_WAVE_TYPE)
            throw result = NOTEXTWAVES;
        if (kernelType != NT_FP32)
            MDChangeWave(kernelH, NT_FP32, kernelDimensionSizes);
        // make output wave
        // If outPutPath is empty string, we are overwriting existing wave
        if (WMGetHandleSize (p->outPutPath) == 0){
            if (overWrite == NO_OVERWITE) throw result = OVERWRITEALERT;
            if (isFloat){ //redimension input/output wave to 32bit floating point
                if (result = MDChangeWave(inPutWaveH, NT_FP32, inPutDimensionSizes)) throw result;
            }
            outPutWaveH = inPutWaveH;
            isOverWriting = 1;
        }else{ // Parse outPut path for folder path and wave name
            ParseWavePath (p->outPutPath, outPutPath, outPutWaveName);
            //Check to see if output path is valid
            if (result = GetNamedDataFolder (NULL, outPutPath, &outPutDFHandle))throw result;
            // Test name and data folder for output wave against the input wave to prevent accidental overwriting, if src and dest are the same
            WaveName (inPutWaveH, inPutWaveName);
            GetWavesDataFolder (inPutWaveH, &inPutDFHandle);
            GetDataFolderNameOrPath (inPutDFHandle, 1, inPutPath);
            if ((!(CmpStr (inPutPath,outPutPath))) && (!(CmpStr (inPutWaveName,outPutWaveName)))){	// Then we would overwrite wave
                isOverWriting = 1;
                if (overWrite == NO_OVERWITE) throw result = OVERWRITEALERT;
                if (isFloat){ //redimesnion input wave to 32bit floating point
                    if (result = MDChangeWave(inPutWaveH, NT_FP32, inPutDimensionSizes)) throw result;
                }
                outPutWaveH = inPutWaveH;
            }else{
                isOverWriting = 0;
                // make the output wave
                //No liberal wave names for output wave
                CleanupName (0, outPutWaveName, MAX_OBJ_NAME);
                if (isFloat){
                    if (result = MDMakeWave (&outPutWaveH, outPutWaveName, outPutDFHandle, inPutDimensionSizes, NT_FP32, overWrite))
                        throw result;
                }else{
                    if (result = MDMakeWave (&outPutWaveH, outPutWaveName, outPutDFHandle, inPutDimensionSizes, inPutWaveType, overWrite))
                        throw result;
                }
            }
        }
    }catch (int result){  //catch before locking any handles
        p -> result = result;
        return (result);	// XFUNC error code.
    }try{
        //Get data offsets for the 3 waves (2 waves, if overwriting)
        if (result = MDAccessNumericWaveData(inPutWaveH, kMDWaveAccessMode0, &inPutOffset))
            throw result;
        if (isOverWriting){
            outPutOffset = inPutOffset;
        }else{
            if (result = MDAccessNumericWaveData(outPutWaveH, kMDWaveAccessMode0, &outPutOffset))
                throw result;
        }
        inPutDataStartPtr = (char*)(*inPutWaveH) + inPutOffset;
        outPutDataStartPtr =  (char*)(*outPutWaveH) + outPutOffset;
        if (result = MDAccessNumericWaveData(kernelH, kMDWaveAccessMode0, &kernelOffset))
            throw result;
        kernelDataStartPtr = (char*)(*kernelH) + kernelOffset;
        // make kernel table
        kernelTable = SymConvolveMakeKernelTable ((float*)kernelDataStartPtr, kernelDimensionSizes [0]);
        if (kernelTable ==NULL) throw result = BADSYMKERNEL;
    }catch (int (result)) {
        p -> result = result; // XFUNC error code
        return (result);	// XFUNC error code.
    }
    // multiprocessor initialization
    // make an array of parameter structures
    if (zSize < nThreads) nThreads = zSize;
    ConvolveFramesThreadParamsPtr paramArrayPtr= (ConvolveFramesThreadParamsPtr)WMNewPtr (nThreads * sizeof(ConvolveFramesThreadParams));
    for (iThread = 0; iThread < nThreads; iThread++){
        paramArrayPtr[iThread].inPutWaveType = inPutWaveType;
        paramArrayPtr[iThread].inPutDataPtr = inPutDataStartPtr;
        paramArrayPtr[iThread].outPutDataPtr = outPutDataStartPtr;
        paramArrayPtr[iThread].xSize = inPutDimensionSizes [0];
        paramArrayPtr[iThread].ySize = inPutDimensionSizes [1];
        paramArrayPtr[iThread].zSize =zSize;
        paramArrayPtr[iThread].ti=iThread; // number of this thread, starting from 0
        paramArrayPtr[iThread].tN =nThreads; // total number of threads
        paramArrayPtr[iThread].kernelDataPtr=(float*)kernelDataStartPtr; //pointer to start of kernel
        paramArrayPtr[iThread].kWidth = kernelDimensionSizes[0]; //width of kernel
        paramArrayPtr[iThread].kernelTablePtr =kernelTable; // sum of kernel at start of column or line
        paramArrayPtr[iThread].isFloat = isFloat; // 0 for same type as input wave, non-zero for floating point wave
    }
    // make an array of pthread_t
    pthread_t* threadsPtr =(pthread_t*)WMNewPtr(nThreads * sizeof(pthread_t));
    // create the threads
    for (iThread = 0; iThread < nThreads; iThread++){
        pthread_create (&threadsPtr[iThread], NULL, SymConvolveFramesThread, (void *) &paramArrayPtr[iThread]);
    }
    // Wait till all the threads are finished
    for (iThread = 0; iThread < nThreads; iThread++){
        pthread_join (threadsPtr[iThread], NULL);
    }
    // free memory for pThreads Array
    WMDisposePtr ((Ptr)threadsPtr);
    // Free paramaterArray memory
    WMDisposePtr ((Ptr)paramArrayPtr);
    //free kernel copy memory
    WMDisposePtr ((Ptr)kernelTable);
    WaveHandleModified(outPutWaveH);			// Inform Igor that we have changed the output wave.
    p -> result = result;				// // XFUNC error code will be 0
    return (result);
}

/****************************************************************************************************************
 //template for a stand-alone median function for any data type
 // n = number of data points, dataStrtPtr is pointer to start of data
 Last Modified 2013/07/16 by Jamie Boyd */
template <typename T> T medianT (UInt32 n, T* dataStrtPtr)
{
    UInt32 medianOffset = n/2; // point offset to location of median value when function returns
    UInt32 i,right = n -1,j,left =0, mid; // point offsets used for partitioning
    T a; //
    T temp; // used for SWAP macro
    for (;;) {
        if (right <= left+1) {
            if (right == left+1 && *(dataStrtPtr + right) < *(dataStrtPtr + left)) {
                SWAP((*(dataStrtPtr + left)),(*(dataStrtPtr + right)));
            }
            return *(dataStrtPtr + medianOffset);
        } else {
            mid=(left + right) >> 1;
            SWAP((*(dataStrtPtr + mid)),(*(dataStrtPtr + left + 1)));
            if (*(dataStrtPtr + left) > *(dataStrtPtr + right)) {
                SWAP((*(dataStrtPtr + left)),(*(dataStrtPtr + right)));
            }
            if (*(dataStrtPtr + left + 1) > *(dataStrtPtr + right)) {
                SWAP((*(dataStrtPtr + left + 1)), ( *(dataStrtPtr + right)));
            }
            if (*(dataStrtPtr + left) > *(dataStrtPtr + left+1)) {
                SWAP((*(dataStrtPtr + left)),(*(dataStrtPtr + left+1)));
            }
            i=left+1;
            j=right;
            a=*(dataStrtPtr + left+1);
            for (;;) {
                do i++; while (*(dataStrtPtr + i) < a);
                do j--; while (*(dataStrtPtr + j) > a);
                if (j < i) break;
                SWAP((*(dataStrtPtr + i)),(*(dataStrtPtr + j)));
            }
            *(dataStrtPtr + left + 1) = *(dataStrtPtr + j);
            *(dataStrtPtr + j) = a;
            if (j >= medianOffset) right=j-1;
            if (j <= medianOffset) left=i;
        }
    }
}

/*******************************************************************************************************************************************
 Structure to pass data to each MedianFramesThread
 Last Modified 2013/07/16 by Jamie Boyd */
typedef struct MedianFramesThreadParams{
    int inPutWaveType;
    char* inPutDataStartPtr;
    char* outPutDataStartPtr;
    CountInt xSize;
    CountInt ySize;
    CountInt zSize;
    UInt8 ti; // number of this thread, starting from 0
    UInt8 tN; // total number of threads
    UInt16 kWidth;
}MedianFramesThreadParams, *MedianFramesThreadParamsPtr;

/*****************************************************************************************************************
 template for applying a median filter and putting the results in an output wave.
 Input wave can be 2 or 3D, but each plane is done as a separate 2D image.
 Last Modified 2025/06/13 by Jamie Boyd
 
 double overWrite; // 1 if it is o.k. to overwrite existing waves, 0 to exit with error if overwriting would occur
 double kWidth; //width of the area over which to calculate the median. Must be an odd number
 Handle outPutPath;	// A handle to a string containing path to output wave we want to make, or empty string to overwrite existing wave
 waveHndl inPutWaveH;//input wave. needs to be 2D or 3D wave*/

template <typename TI> int MedianFramesT (TI* srcWave, TI* destWave, CountInt xSize, CountInt ySize, CountInt zSize, UInt16 kWidth){
    CountInt fSize = (xSize * ySize);  //frame size
    CountInt bufferSize = (fSize *  sizeof (TI)); // size of a buffer big enough to hold one frame
    Ptr bufferStartPtr ; // pointer for a frames' worth of buffer, if overwriting the source wave
    UInt32 kSize = (kWidth * kWidth); // number of pixels in the kernel
    TI* kernelCopyStart; // pointer to start of the buffer to store copied data to be medianed in a destructive fashion
    UInt32  kBufferSize = (kSize *  sizeof (TI));
    UInt32 kRadW = (kWidth - 1)/2; //radius of the kernel width, including the central pixel
    UInt8 isOverWriting = 0; // will be set to 1 if overwriting existing wave
    TI* inPutPtr; // Center pixel input pixel. Offsets to kernel input are calculated relative to this. Value progresses monotonically through wave
    TI* convoPtr; // pointer to pixel of the image used when copying data
    TI* outPutPtr; // output pixel to get the calculated median value. Value progresses monotonically through the wave
    TI* kPtr;  // pointer to iterate through the copied data
    CountInt kX, kY, kXend, kYend; // variables for iterating through pieces of kernel
    CountInt wToNextRow; //amount to add to wToFirstRow to get to next row in input wave when iterating through a kernel
    CountInt wX, wY, wZ, wXend, wYend; // to keep track of progress through X and Y in input wave
    
    //if overwriting source, make a buffer to hold a single frame
    if ((TI*)destWave == (TI*)srcWave){
        isOverWriting = 1;
        //Make a buffer big enough to hold a single frame
        if (isOverWriting)
            bufferStartPtr = (char*)WMNewPtr (bufferSize);
        if (bufferStartPtr == NULL) return NOMEM;
    }
    // Make a buffer big enough to hold a "kernel's worth" of pixels
    kernelCopyStart = (TI*) WMNewPtr (kBufferSize);
    if (kernelCopyStart == NULL) return NOMEM;
    // Loop through all frames
    if (zSize == 0) zSize =1; // zSize = 0 means a 2D wave
    for (wZ=0, outPutPtr = destWave, inPutPtr =srcWave; wZ < zSize; wZ++){
        if (isOverWriting){  // copy next frame to buffer and position input pointer at start of buffer
            memcpy ((void*) bufferStartPtr, (void*) outPutPtr, bufferSize);
            inPutPtr = (TI*) bufferStartPtr;
        } // If not copying to a buffer, inputPtr will be left in correct position at end of Z loop
        // Loop for TOP
        for (wY = 0; wY < kRadW; wY++){
            // loop for TOP LEFT
            for (wX =0; wX < kRadW; wX++, inPutPtr++, outPutPtr++){
                convoPtr = inPutPtr - (wY  * xSize) - wX;
                wToNextRow =  (UInt32)(xSize - kRadW - wX - 1);
                kPtr = kernelCopyStart;
                // loop through kernel at each location
                for (kY = kRadW - wY; kY < kWidth; kY++ , convoPtr +=wToNextRow){
                    for (kX = kRadW - wX; kX < kWidth; kX++, kPtr++, convoPtr++) *kPtr = *convoPtr;
                }
                *outPutPtr = medianT ((CountInt)(kPtr - kernelCopyStart), kernelCopyStart);
            } // End of Loop for TOP LEFT
            // Loop for TOP CENTER
            for (wXend =(xSize - kRadW); wX < wXend; wX++, inPutPtr++, outPutPtr++){
                // loop through kernel at each location
                convoPtr = inPutPtr - (wY  * xSize) - kRadW;
                wToNextRow = xSize - kWidth;
                kPtr = kernelCopyStart;
                for (kY = kRadW - wY; kY < kWidth; kY++, convoPtr += wToNextRow){
                    for (kX =0; kX < kWidth; kX++, kPtr++, convoPtr++) *kPtr = *convoPtr;
                }
                *outPutPtr = medianT ((CountInt)(kPtr - kernelCopyStart), kernelCopyStart);
            } // End of Loop for TOP CENTER
            // Loop for TOP RIGHT
            for (;wX < xSize; wX++, inPutPtr++, outPutPtr++){
                // loop through kernel at each location
                convoPtr =  inPutPtr - (wY  * xSize) - kRadW;
                wToNextRow = xSize - kRadW - (xSize - wX);
                kPtr = kernelCopyStart;
                for (kY = kRadW - wY; kY < kWidth; kY++, convoPtr += wToNextRow){
                    for (kX =0, kXend = kRadW + (xSize - wX); kX < kXend; kX++, kPtr++, convoPtr++) *kPtr = *convoPtr;
                }
                *outPutPtr = medianT ((CountInt)(kPtr - kernelCopyStart), kernelCopyStart);
            } // End of Loop for TOP RIGHT
        } // End of Loop for TOP
        // Loop for MIDDLE
        for (wYend =(ySize - kRadW) ; wY < wYend ; wY++){
            // Loop for MIDDLE LEFT
            for (wX =0; wX < kRadW; wX++, inPutPtr++, outPutPtr++){
                convoPtr = inPutPtr - (kRadW  * xSize) - wX;
                wToNextRow =  xSize - kRadW - wX - 1;
                kPtr = kernelCopyStart;
                // loop through kernel at each location
                for (kY = 0; kY < kWidth; kY++, convoPtr +=wToNextRow){
                    for (kX = kRadW - wX; kX < kWidth; kX++, kPtr++, convoPtr++) *kPtr = *convoPtr;
                }
                *outPutPtr = medianT ((CountInt)(kPtr - kernelCopyStart), kernelCopyStart);
            } // End of Loop for MIDDLE LEFT
            // Loop for MIDDLE CENTER
            for (wXend = (xSize - kRadW); wX < wXend ; wX++, inPutPtr++, outPutPtr++){
                convoPtr = inPutPtr - (kRadW  * xSize) - kRadW;
                wToNextRow = xSize - kWidth;
                kPtr = kernelCopyStart;
                // loop through kernel at each location
                for (kY = 0; kY < kWidth; kY++, convoPtr += wToNextRow){
                    for (kX =0; kX < kWidth; kX++, kPtr++, convoPtr++) *kPtr = *convoPtr;
                }
                *outPutPtr = medianT ((CountInt)(kPtr - kernelCopyStart), kernelCopyStart);
            } // End of Loop for MIDDLE CENTER
            // Loop for MIDDLE RIGHT
            for (;wX < xSize; wX++, inPutPtr++, outPutPtr++){
                // loop through kernel at each location
                convoPtr =  inPutPtr - (kRadW  * xSize) - kRadW;
                wToNextRow = xSize - kRadW - (xSize - wX);
                kPtr = kernelCopyStart;
                for (kY = 0; kY < kWidth; kY++, convoPtr += wToNextRow){
                    for (kX = 0, kXend = kRadW + (xSize - wX); kX < kXend; kX++, kPtr++, convoPtr++) *kPtr = *convoPtr;
                }
                *outPutPtr = medianT ((CountInt)(kPtr - kernelCopyStart), kernelCopyStart);
            } // End of Loop for MIDDLE RIGHT
        } // End of Loop for MIDDLE
        // Loop for BOTTOM
        for (; wY < ySize; wY++){
            // Loop for BOTTOM LEFT
            for (wX = 0; wX < kRadW; wX ++, inPutPtr++, outPutPtr++){
                // Loop through kernel at each location
                convoPtr = inPutPtr - (kRadW  * xSize) - wX;
                wToNextRow =  xSize - kRadW - wX - 1;
                kPtr = kernelCopyStart;
                for (kY = 0, kYend = kRadW + (ySize - wY); kY < kYend; kY++, convoPtr += wToNextRow){
                    for (kX =kRadW - wX; kX < kWidth; kX++, kPtr++, convoPtr++) *kPtr = *convoPtr;
                }
                *outPutPtr = medianT ((CountInt)(kPtr - kernelCopyStart), kernelCopyStart);
            } // End ofLoop for BOTTOM LEFT
            // Loop for BOTTOM CENTER
            for (; wX < (xSize - kRadW); wX++, inPutPtr++, outPutPtr++){
                // Loop through kernel at each location
                convoPtr = inPutPtr - (kRadW  * xSize) - kRadW;
                wToNextRow = xSize - kWidth;
                kPtr = kernelCopyStart;
                for (kY = 0, kYend = kRadW + (ySize - wY) ; kY < kYend; kY++, convoPtr += wToNextRow){
                    for (kX =0; kX < kWidth; kX++, convoPtr++, kPtr++) *kPtr = *convoPtr;
                }
                *outPutPtr = medianT ((CountInt)(kPtr - kernelCopyStart), kernelCopyStart);
            } // End of Loop for BOTTOM CENTER
            // Loop for BOTTOM RIGHT
            for (; wX < xSize; wX++, inPutPtr++, outPutPtr++){
                //Loop through kernel at each location
                convoPtr =  inPutPtr - (kRadW * xSize) - kRadW;
                wToNextRow = xSize - kRadW - (xSize - wX);
                kPtr = kernelCopyStart;
                for (kYend = kRadW + (ySize - wY), kY =0; kY < kYend; kY++, convoPtr += wToNextRow){
                    for (kX =0, kXend = kRadW + (xSize -wX); kX < kXend; kX++, convoPtr++, kPtr++) *kPtr = *convoPtr;
                }
                *outPutPtr = medianT ((CountInt)(kPtr - kernelCopyStart), kernelCopyStart);
            } // End of Loop for BOTTOM RIGHT
        } // End of Loop for BOTTOM
    } // End of Loop for Each Frame
    if (isOverWriting)
        WMDisposePtr (bufferStartPtr);
    return 0;
}

/*********************************************************************************************************************************************
 Each thread to median filter a range of frames starts with this function
 Last Modified 2013/07/16 by Jamie Boyd */
void* MedianFramesThread (void* threadarg){
    
    struct MedianFramesThreadParams* p;
    p = (struct MedianFramesThreadParams*) threadarg;
    CountInt tFrames = p->zSize/p->tN; //frames per thread = number of frames / number of threads, truncated to an integer
    CountInt startPos = p->ti * tFrames; // which frame to start this thread on depends on thread number * frames per thread. ti is 0 based
    if (p->ti == p->tN - 1) tFrames +=  (p->zSize % p->tN); // the last thread gets any left-over frames
    startPos *= (p->xSize * p->ySize); //change start position from frames to data points by multiplying by frame size
    // call the right template function for the wave types
    switch (p->inPutWaveType) {
        case NT_I8:
            MedianFramesT ((char*)p->inPutDataStartPtr + startPos, (char*)p->outPutDataStartPtr + startPos, p->xSize, p->ySize, tFrames, p->kWidth);
            break;
        case (NT_I8 | NT_UNSIGNED):
            MedianFramesT ((unsigned char*)p->inPutDataStartPtr + startPos,(unsigned char*)p->outPutDataStartPtr + startPos, p->xSize, p->ySize, tFrames, p->kWidth);
            break;
        case NT_I16:
            MedianFramesT ((short*)p->inPutDataStartPtr + startPos,(short*)p->outPutDataStartPtr + startPos, p->xSize, p->ySize, tFrames, p->kWidth);
            break;
        case (NT_I16 | NT_UNSIGNED):
            MedianFramesT ((unsigned short*)p->inPutDataStartPtr + startPos,(unsigned short*)p->outPutDataStartPtr + startPos, p->xSize, p->ySize, tFrames, p->kWidth);
            break;
        case NT_I32:
            MedianFramesT ((long*)p->inPutDataStartPtr + startPos,(long*)p->outPutDataStartPtr + startPos, p->xSize, p->ySize, tFrames, p->kWidth);
            break;
        case (NT_I32| NT_UNSIGNED):
            MedianFramesT ((unsigned long*)p->inPutDataStartPtr + startPos,(unsigned long*)p->outPutDataStartPtr + startPos, p->xSize, p->ySize, tFrames, p->kWidth);
            break;
        case NT_FP32:
            MedianFramesT ((float*)p->inPutDataStartPtr + startPos,(float*)p->outPutDataStartPtr + startPos, p->xSize, p->ySize, tFrames, p->kWidth);
            break;
        case NT_FP64:
            MedianFramesT ((double*)p->inPutDataStartPtr + startPos,(double*)p->outPutDataStartPtr + startPos, p->xSize, p->ySize, tFrames, p->kWidth);
            break;
        default:	// Unknown data type - possible in a future version of Igor.
            throw NT_FNOT_AVAIL;
            break;
    }
    return 0;
}

/****************************************************************************************************************
 Applies a median filter to a 3D wave, treating each plane as a separate 2D image
 Does multiple frames in a single 3D wave
 Last modified 2013/07/16 by Jamie Boyd
 typedef struct MedianFramesParams{
 double overWrite; // 1 if it is o.k. to overwrite existing waves, 0 to exit with error
 double kWidth; //width of the area over which to calculate the median. Must be an odd number
 Handle outPutPath;	// A handle to a string containing path to output wave we want to make, or empty string to overwrite existing wave
 waveHndl inPutWaveH;//input wave. needs to be 2D or 3D wave
 double result;
 } MedianFramesParams, *MedianFramesParamsPtr;*/

int MedianFrames (MedianFramesParamsPtr p)
{
    int result = 0;	// The error returned from various Wavemetrics functions
    waveHndl inPutWaveH, outPutWaveH;		// handles to the input and output waves
	int inPutWaveType; //  Wavetypes numeric codes for things like 32 bit floating point, 16 bit int, etc
    int inPutDimensions;	// number of dimensions in input wave
    CountInt inPutDimensionSizes[MAX_DIMENSIONS+1];	// an array used to hold the width, height, layers, and chunk sizes
    BCInt inPutOffset, outPutOffset, kernelOffset;	//offset in bytes from begnning of handle to a wave to the actual data - size of headers, units, etc.
    DataFolderHandle inPutDFHandle, outPutDFHandle;	// Handle to the datafolder where we will put the output wave
    DFPATH inPutPath, outPutPath;	// string to hold data folder path of input wave
    WVNAME inPutWaveName, outPutWaveName;	// C strings to hold names of input and output waves
    UInt8 overWrite = (UInt8)(p->overWrite);	// 0 to not overwrite output wave if it already exists, 1 to overwrite old waves
    UInt16 kWidth = (UInt16)(p-> kWidth); // width of the area over which the median will be calculated
    UInt8 isOverWriting; // non-zero if output is overwriting input wave
    char *inPutDataStartPtr, *outPutDataStartPtr;
    try{
        // Check that kWidth is odd
        if ((kWidth % 2) == 0) throw result = BADKERNEL;
        // Get handle to input wave
        inPutWaveH = p->inPutWaveH;
        if (inPutWaveH == NIL)
            throw result = NON_EXISTENT_WAVE;
        // Get wave data type
        inPutWaveType = WaveType(inPutWaveH);
        if (inPutWaveType==TEXT_WAVE_TYPE)
            throw result = NOTEXTWAVES;
        // Get number of used dimensions in wave
        if (result = MDGetWaveDimensions(inPutWaveH, &inPutDimensions, inPutDimensionSizes))
            throw result;
        // Check that inputwave is 2D or 3D
        if ((inPutDimensions == 1) || (inPutDimensions == 4))
            throw result = INPUTNEEDS_2D3D_WAVE;
        // If outPutPath is empty string, we are overwriting existing wave
        if (WMGetHandleSize (p->outPutPath) == 0){
            if (overWrite == NO_OVERWITE) throw result = OVERWRITEALERT;
            outPutWaveH = inPutWaveH;
            isOverWriting = 1;
        }else{ // Parse outPut path
            ParseWavePath (p->outPutPath, outPutPath, outPutWaveName);
            //Check to see if output path is valid
            if (result = GetNamedDataFolder (NULL, outPutPath, &outPutDFHandle))throw result;
            // Test name and data folder for output wave against the input wave to prevent accidental overwriting, if src and dest are the same
            WaveName (inPutWaveH, inPutWaveName);
            GetWavesDataFolder (inPutWaveH, &inPutDFHandle);
            GetDataFolderNameOrPath (inPutDFHandle, 1, inPutPath);
            if ((!(CmpStr (inPutPath,outPutPath))) && (!(CmpStr (inPutWaveName,outPutWaveName)))){	// Then we would overwrite wave
                isOverWriting = 1;
                if (overWrite == NO_OVERWITE) throw result = OVERWRITEALERT;
                outPutWaveH = inPutWaveH;
            }else{
                isOverWriting = 0;
                // make the output wave
                //No liberal wave names for output wave
                CleanupName (0, outPutWaveName, MAX_OBJ_NAME);
                if (result = MDMakeWave (&outPutWaveH, outPutWaveName, outPutDFHandle, inPutDimensionSizes, inPutWaveType, overWrite)) throw result;
            }
        }
    }catch (int result){  //catch before locking any handles
        p -> result = result;
        return (result);	// XFUNC error code.
    }try{
		//Get data offsets for the 3 waves (2 waves, if overwriting)
        if (result = MDAccessNumericWaveData(inPutWaveH, kMDWaveAccessMode0, &inPutOffset))
            throw result;
        if (isOverWriting){
            outPutOffset = inPutOffset;
        }else{
            if (result = MDAccessNumericWaveData(outPutWaveH, kMDWaveAccessMode0, &outPutOffset))
                throw result;
        }
        inPutDataStartPtr = (char*)(*inPutWaveH) + inPutOffset;
        outPutDataStartPtr =  (char*)(*outPutWaveH) + outPutOffset;
    }catch (int result){
		p -> result = result;				// XFUNC error code
        return (result);
    }
    /* multiprocessor init
     fill array of parameter structures */
    int iThread, nThreads = gNumProcessors;
    if (inPutDimensionSizes [2] < nThreads) nThreads = (int)inPutDimensionSizes [2];
    MedianFramesThreadParamsPtr paramArrayPtr= (MedianFramesThreadParamsPtr)WMNewPtr(nThreads * sizeof(MedianFramesThreadParams));
    for (iThread = 0; iThread < nThreads; iThread++){
        paramArrayPtr[iThread].inPutWaveType = inPutWaveType;
        paramArrayPtr[iThread].inPutDataStartPtr = inPutDataStartPtr;
        paramArrayPtr[iThread].outPutDataStartPtr = outPutDataStartPtr;
        paramArrayPtr[iThread].xSize = inPutDimensionSizes [0];
        paramArrayPtr[iThread].ySize = inPutDimensionSizes [1];
        paramArrayPtr[iThread].zSize =inPutDimensionSizes [2];
        paramArrayPtr[iThread].ti=iThread; // number of this thread, starting from 0
        paramArrayPtr[iThread].tN =nThreads; // total number of threads
        paramArrayPtr[iThread].kWidth = (int)kWidth;
    }
	    
    // make an array of pthread_t
    pthread_t* threadsPtr =(pthread_t*)WMNewPtr(nThreads * sizeof(pthread_t));
    // create the threads
    for (iThread = 0; iThread < nThreads; iThread++){
        pthread_create (&threadsPtr[iThread], NULL, MedianFramesThread, (void *) &paramArrayPtr[iThread]);
    }
    // Wait till all the threads are finished
    for (iThread = 0; iThread < nThreads; iThread++){
        pthread_join (threadsPtr[iThread], NULL);
    }
    // free memory for pThreads Array
    WMDisposePtr ((Ptr)threadsPtr);
    // Free paramaterArray memory
    WMDisposePtr ((Ptr)paramArrayPtr);
    WaveHandleModified(outPutWaveH);			// Inform Igor that we have changed the output wave.
    p -> result = result;				// // XFUNC error code will be 0
    return (result);
}
