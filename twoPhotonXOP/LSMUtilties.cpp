#include "twoPhoton.h"
#include "math.h"

/**************************************************************************************************************
Code specialized for Laser Scanning Microscope data acquisition
Last Modified 2025/06/13 by Jamie Boyd */

/**************************************************************************************************************
Structure to pass data to each SwapEvenThread
Last Modified 2013/07/15 by Jamie Boyd */
typedef struct SwapEvenThreadParams{
    int inPutWaveType;
    char* dataStartPtr;
    CountInt numLines;
    CountInt lineLen;
    UInt8 ti; // number of this thread, starting from 0
    UInt8 tN; // total number of threads (255 "should be enough for anyone")
}SwapEvenThreadParams, *SwapEvenThreadParamsPtr;

/**********************************************************************************************************************
Template for SwapEven functions
Last Modified 2013/07/15 by Jamie Boyd*/
template <typename T> void SwapEvenT (T *dataStartPtr, CountInt numLines, CountInt lineLen)
{
    // make Pointer to end of the data
    T* dataEndPtr = dataStartPtr + (numLines * lineLen);
    // make pointers for start and end of each line
    T* lineStartPtr;
    T* lineEndPtr;
    //temporary value for swapping
    T temp;
    // calculate distance to start and end of next line
    UInt16 toNextStart = (2 * lineLen) - (lineLen/2);    //due to rounding of integer math, it doesn't matter if LineLen is even or odd
    UInt16 toNextEnd = (2 * lineLen) + (lineLen/2);
    //iterate through every other line, flipping it around
    for(lineStartPtr = dataStartPtr + lineLen, lineEndPtr = lineStartPtr + lineLen -1; lineEndPtr < dataEndPtr; lineStartPtr += toNextStart,lineEndPtr += toNextEnd) {
        while (lineStartPtr < lineEndPtr){
            SWAP (*lineStartPtr, *lineEndPtr);
            lineStartPtr++;
            lineEndPtr--;
        }
    }
}


/**********************************************************************************************************************
Each thread to swap a range of rows starts with this function
Last Modified 2025/06/13 by Jamie Boyd */
void* SwapEvenThread (void* threadarg){

    struct SwapEvenThreadParams* p;
    p = (struct SwapEvenThreadParams*) threadarg;
    CountInt tLines = (p-> numLines/p->tN);
    if (tLines % 2) tLines--; // make sure number of lines per thread is even
    CountInt startPos = p->ti * tLines * p->lineLen;
    if (p->ti == p->tN - 1) tLines +=  (p->numLines % p->tN); // the last thread gets any left-over lines
    // call the right template function for the wave types
    switch (p->inPutWaveType) {
    case NT_I8:
        SwapEvenT ((char*) p->dataStartPtr + startPos, tLines, p->lineLen);
        break;
    case (NT_I8 | NT_UNSIGNED):
        SwapEvenT ((unsigned char*)p->dataStartPtr + startPos, tLines, p->lineLen);
        break;
    case NT_I16:
        SwapEvenT ((short*)p->dataStartPtr + startPos, tLines, p->lineLen);
        break;
    case (NT_I16 | NT_UNSIGNED):
        SwapEvenT ((unsigned short*)p->dataStartPtr + startPos, tLines, p->lineLen);
        break;
    case NT_I32:
        SwapEvenT ((long*)p->dataStartPtr + startPos, tLines, p->lineLen);
        break;
    case (NT_I32| NT_UNSIGNED):
        SwapEvenT ((unsigned long*)p->dataStartPtr + startPos, tLines, p->lineLen);
        break;
    case NT_FP32:
        SwapEvenT ((float*)p->dataStartPtr + startPos, tLines, p->lineLen);
        break;
    case NT_FP64:
        SwapEvenT ((double*)p->dataStartPtr + startPos, tLines, p->lineLen);
        break;
    default:    // Unknown data type - possible in a future version of Igor.
        throw NT_FNOT_AVAIL;
        break;
    }
    return NULL;
}


/*****************************************************************************************************************
SwapEven horizontally swaps every other line in an image or series of images. Used after doing back and forth scanning,
where every other line is scanned from the opposite direction.
typedef struct SwapEvenParams
waveHndl w1; // input wave
Last Modified 2025/06/13 by Jamie Boyd */
extern "C" int SwapEven (SwapEvenParamsPtr p){
    waveHndl wavH = NULL;        // handle to the input wave
    int waveType; //  Wavetypes numeric codes for things like 32 bit floating point, 16 bit int, etc
    int numDimensions;    // number of dimensions in input and output waves
    CountInt dimensionSizes[MAX_DIMENSIONS+1];    // an array used to hold the width, height, layers, and chunk sizes
    IndexInt dataOffset;    //offset in bytes from begnning of handle to a wave to the actual data - size of headers, units, etc.
    CountInt lineLen;    // The length of each line in the image
    CountInt numLines;    // The number of lines in the file
    
    int result;    // The error returned from various Wavemetrics functions
    
    char* dataStartPtr;    // Pointer to start of data in input wave. Need to use char for these to use WM function to get data offset

    try {
        // Get handle to input wave. Make sure it exists.
        wavH = p->w1;
        if (wavH == NULL)
            throw result = NON_EXISTENT_WAVE;
        // Get wave data type.
        waveType = WaveType(wavH);
        // Can't process text waves
        if (waveType == TEXT_WAVE_TYPE)
            throw result = NOTEXTWAVES;
        // Get number of used dimensions in wave.
        if (result = MDGetWaveDimensions(wavH, &numDimensions, dimensionSizes))
            throw result;
        // Check that wave1 is 2D or 3D
        if ((numDimensions == 1) || (numDimensions == 4))
            throw result = INPUTNEEDS_2D3D_WAVE;
        // Get dimension size info and calculate number of lines to process
        lineLen = dimensionSizes[0];
        if (numDimensions == 2){
            numLines = dimensionSizes[1];
        }else{
            numLines = dimensionSizes[1] * dimensionSizes[2];
        }
    }catch (int result){     //catch before locking any handles
        p -> result = result;                // // XFUNC error code
        return (result);
    }try {
        // Get the offsets to the data in the wave
        if (result = MDAccessNumericWaveData(wavH, kMDWaveAccessMode0, &dataOffset))
            throw result;
    }catch (int result){
        p -> result = result;
        return (result);                // XFUNC error code.
    }
    dataStartPtr = (char*)(*wavH) + dataOffset;
    // Multi threading
    UInt8 iThread, nThreads = gNumProcessors;
    SwapEvenThreadParamsPtr paramArrayPtr= (SwapEvenThreadParamsPtr)WMNewPtr(nThreads * sizeof(SwapEvenThreadParams));
    for (iThread = 0; iThread < nThreads; iThread++){
        paramArrayPtr[iThread].inPutWaveType = waveType;
        paramArrayPtr[iThread].dataStartPtr = dataStartPtr;
        paramArrayPtr[iThread].numLines = numLines;
        paramArrayPtr[iThread].lineLen = lineLen;
        paramArrayPtr[iThread].ti=iThread; // number of this thread, starting from 0
        paramArrayPtr[iThread].tN =nThreads; // total number of threads
    }
    // make an array of pthread_t
    pthread_t* threadsPtr =(pthread_t*)WMNewPtr(nThreads * sizeof(pthread_t));
    // create the threads
    for (iThread = 0; iThread < nThreads; iThread++){
        pthread_create (&threadsPtr[iThread], NULL, SwapEvenThread, (void *) &paramArrayPtr[iThread]);
    }
    // Wait till all the threads are finished
    for (iThread = 0; iThread < nThreads; iThread++){
        pthread_join (threadsPtr[iThread], NULL);
    }
    // free memory for pThreads Array
    WMDisposePtr ((Ptr)threadsPtr);
    // Free paramaterArray memory
    WMDisposePtr ((Ptr)paramArrayPtr);
    WaveHandleModified(wavH);            // Inform Igor that we have changed the input wave.
    p -> result = result;                // // XFUNC error code will be 0
    return (result);
}

/********************************************************************************************************************
Template functions for the various DownSample methods
Case 1 Kalman-style averaging.
Last Modified 2013/07/15 by Jamie Boyd */
template <typename T> void DSaverageT (T *dataStartPtr, CountInt points, UInt16 boxFactor)
{
    // make Pointer to the end of the data
    T *dataEndPtr = dataStartPtr + points;
    T *outPutPtr; // output position varies slowly
    T *inPutPtr;  // input position varies quickly
    UInt16 ifactor;
    //iterate through the wave, averaging input range into output value
    for (outPutPtr = inPutPtr = dataStartPtr;inPutPtr < dataEndPtr; outPutPtr++){
        *outPutPtr = *inPutPtr;
        inPutPtr++;
        for (ifactor = 1; ifactor < boxFactor; ifactor++, inPutPtr++){
            *outPutPtr = (*outPutPtr * (ifactor/(ifactor + 1))) + *inPutPtr /(ifactor + 1);
        }
    }
}

// Case 2: Summing. Need different function for different bounds checking for floats, signed ints, and unsigned ints
//Floats: Don't check Max or Min - overflows should automatically go to INF and -INF
template <typename T> void DSsumFloatT (T *dataStartPtr, CountInt points, UInt16 boxFactor)
{
    T *dataEndPtr = dataStartPtr + points;
    T *outPutPtr;
    T *inPutPtr;
    UInt16 ifactor;
    for (outPutPtr = inPutPtr = dataStartPtr;inPutPtr < dataEndPtr; outPutPtr++){
        for (*outPutPtr = *inPutPtr,inPutPtr++, ifactor = 1; ifactor < boxFactor; ifactor++, inPutPtr++)
            *outPutPtr = *outPutPtr + *inPutPtr;
    }
}

// Signed Ints: Check OverFlows at both ends (Max and Min)
template <typename T> void DSsumSignedIntT (T *dataStartPtr, CountInt points, UInt16 boxFactor, T Tmax, T Tmin)
{
    T *dataEndPtr = dataStartPtr + points;
    T *outPutPtr;
    T *inPutPtr;
    UInt16 ifactor;
    for (outPutPtr = inPutPtr = dataStartPtr;inPutPtr < dataEndPtr; outPutPtr++){
        for (*outPutPtr = *inPutPtr,inPutPtr++, ifactor = 1; ifactor < boxFactor; ifactor++, inPutPtr++){
            if ((*outPutPtr + *inPutPtr) > Tmax) //Check Max
                *outPutPtr = Tmax;
            else{
                if ((*outPutPtr + *inPutPtr) < Tmin) //Check Min
                    *outPutPtr = Tmin;
                else
                    *outPutPtr = *outPutPtr + *inPutPtr;
            }
        }
    }
}

// Unsigned integer types: Check OverFlows only for Max
template <typename T> void DSsumUnSignedIntT (T *dataStartPtr, CountInt points, UInt16 boxFactor, T Tmax)
{
    T *dataEndPtr = dataStartPtr + points;
    T *outPutPtr;
    T *inPutPtr;
    UInt16 ifactor;
    for (outPutPtr = inPutPtr = dataStartPtr;inPutPtr < dataEndPtr; outPutPtr++){
        for (*outPutPtr = *inPutPtr,inPutPtr++, ifactor = 1; ifactor < boxFactor; ifactor++, inPutPtr++){
            if ((*outPutPtr + *inPutPtr) > Tmax){  //check Max
                *outPutPtr = Tmax;
                break;    //can move on to the next input point - value can't get any higher
            }
            else
                *outPutPtr = *outPutPtr + *inPutPtr;
        }
    }
}

//Case 3: Take maximum Value
template <typename T> void DSMaxT (T *dataStartPtr, CountInt points, UInt16 boxFactor)
{
    // make Pointer to the end of the data
    T *dataEndPtr = dataStartPtr + points;
    T *outPutPtr;
    T *inPutPtr;
    UInt16 ifactor;

    for (outPutPtr = inPutPtr = dataStartPtr;inPutPtr < dataEndPtr; outPutPtr++){
        *outPutPtr = *inPutPtr;
        inPutPtr++;
        for (ifactor = 1; ifactor < boxFactor; ifactor++, inPutPtr++){
            if (*outPutPtr < *inPutPtr)
                *outPutPtr = *inPutPtr;
        }
    }
}

//case 4: take median value.
template <typename T> void DSMedianT (T *dataStartPtr, CountInt points, UInt16 boxFactor)
{
    // make Pointer to the end of the data
    T *dataEndPtr = dataStartPtr + points;
    T *outPutPtr;
    T *inPutPtr;
    // Median variables
    UInt16 i,right=boxFactor -1,j,left=0,mid;
    UInt16 k = (boxFactor)/2;
    T a,temp;
    for (outPutPtr = inPutPtr = dataStartPtr;inPutPtr < dataEndPtr; outPutPtr++, inPutPtr += boxFactor){
        for (;;) {
            if (right <= left + 1) {
                if (right == left + 1 && *(inPutPtr + right) < *(inPutPtr + left)) {
                    SWAP((*(inPutPtr + left)),(*(inPutPtr + right)));
                }
                *outPutPtr = *(inPutPtr + k);
                break;
            } else {
                mid=(left + right) >> 1;
                SWAP((*(inPutPtr + mid)),(*(inPutPtr + left + 1)));
                if (*(inPutPtr + left) > *(inPutPtr + right)) {
                    SWAP((*(inPutPtr + left)),(*(inPutPtr + right)));
                }
                if (*(inPutPtr + left + 1) > *(inPutPtr + right)) {
                    SWAP((*(inPutPtr + left + 1)), ( *(inPutPtr + right)));
                }
                if (*(inPutPtr + left) > *(inPutPtr + left+1)) {
                    SWAP((*(inPutPtr + left)),(*(inPutPtr + left+1)));
                }
                i=left+1;
                j=right;
                a=*(inPutPtr + left+1);
                for (;;) {
                    do i++; while (*(inPutPtr + i) < a);
                    do j--; while (*(inPutPtr + j) > a);
                    if (j < i) break;
                    SWAP((*(inPutPtr + i)),(*(inPutPtr + j)));
                }
                *(inPutPtr + left + 1) = *(inPutPtr + j);
                *(inPutPtr + j) = a;
                if (j >= k) right = j-1;
                if (j <= k) left=i;
            }
        }
    }
}

/*****************************************************************************************************************
Down Sample takes a wave and resizes its X dimension, combining boxfactor points by taking the average/sum/max/median value
Used after "oversampling" during scanning; i.e., taking several A/D conversions per pixel
typedef struct DownSampleParams
double dsType; // 1 = average, 2 = sum, 3 = max, 4 = median
double boxFactor; // number of pixels to be binned
waveHndl w1;  //input wave - wave is overwritten
Last Modified 2025/06/13 by Jamie Boyd */

int DownSample (DownSampleParamsPtr p)
{
    int result = 0;    // The error returned from various Wavemetrics functions
    int waveType; //  Wavetypes numeric codes for things like 32 bit floating point, 16 bit int, etc
    int numDimensions;    // number of dimensions in input  waves
    CountInt dimensionSizes[MAX_DIMENSIONS+1];    // an array used to hold the width, height, layers, and chunk sizes
    BCInt dataOffset;    //offset in bytes from begnning of handle to a wave to the actual data - size of headers, units, etc.
    UInt16 boxFactor;
    CountInt xSize, ySize, zSize, points;
    waveHndl wavH;        // handle to the input wave
    char* dataStartPtr;    // Pointer to start of data in input wave. Need to use char for these to use WM function to get data offset
    UInt8 DSType;
    try{
        // Get handles to input wave. Make sure it exists.
        wavH = p->w1;
        if (wavH == NIL)
            throw result = NON_EXISTENT_WAVE;
        // Get wave data type.
        waveType = WaveType(wavH);
        // Can't process text waves
        if (waveType == TEXT_WAVE_TYPE)
            throw result = NOTEXTWAVES;
        // Get number of used dimensions in wave.
        if (result = MDGetWaveDimensions(wavH, &numDimensions, dimensionSizes))
            throw result;
        // Check that input is 2D or 3D
        if ((numDimensions != 2) && (numDimensions!= 3))
            throw result = INPUTNEEDS_2D3D_WAVE;
        // Check that Down sample type variable is o.k. 1 = average, 2 = sum, 3 = max, 4 = median
        DSType = (UInt8) p -> dsType;
        if ((DSType > 4) || (DSType < 1))
            throw result = BADDSTYPE;
        // Get dimension size info
        xSize = dimensionSizes[0];
        boxFactor = (UInt16) p ->boxFactor;
        if (xSize % boxFactor)
            throw result = BADFACTOR;
        ySize = dimensionSizes [1];
        if (numDimensions == 2){
            points = xSize * ySize;
        }else{
            zSize = dimensionSizes [2];
            points = xSize * ySize * zSize;
        }
    }catch (int result){
        p -> result = result;                // // XFUNC error code
        return (result);
    }try {
        if (result = MDAccessNumericWaveData(wavH, kMDWaveAccessMode0, &dataOffset))
            throw result;
        //make pointer to start of data
        dataStartPtr = (char*)(*wavH) + dataOffset;
        // call appropriate template function for the chosen downsample type for each wave type

        switch (waveType) {
        case NT_FP64:
            switch (DSType){
            case 1:    //average
                DSaverageT ((double*) dataStartPtr, points, boxFactor);
                break;
            case 2: // sum
                DSsumFloatT ((double*)dataStartPtr, points, boxFactor);
                break;
            case 3: //max
                DSMaxT ((double*)dataStartPtr, points, boxFactor);
                break;
            case 4: // median
                DSMedianT ((double*)dataStartPtr, points, boxFactor);
                break;
            }
            break;
        case NT_FP32:
            switch (DSType){
            case 1:    //average
                DSaverageT ((float*) dataStartPtr, points, boxFactor);
                break;
            case 2: // sum
                DSsumFloatT ((float*)dataStartPtr, points, boxFactor);
                break;
            case 3: //max
                DSMaxT ((float*)dataStartPtr, points, boxFactor);
                break;
            case 4: // median
                DSMedianT ((float*)dataStartPtr, points, boxFactor);
                break;
            }
            break;
        case (NT_I32 | NT_UNSIGNED):
            switch (DSType){
            case 1:    //average
                DSaverageT ((unsigned long*) dataStartPtr, points, boxFactor);
                break;
            case 2: // sum
                DSsumUnSignedIntT ((unsigned long*)dataStartPtr, points, boxFactor,(unsigned long)ULONG_MAX);
                break;
            case 3: //max
                DSMaxT ((unsigned long*)dataStartPtr, points, boxFactor);
                break;
            case 4: // median
                DSMedianT ((unsigned long*)dataStartPtr, points, boxFactor);
                break;
            }
            break;
        case NT_I32:
            switch (DSType){
            case 1:    //average
                DSaverageT ((long*) dataStartPtr, points, boxFactor);
                break;
            case 2: // sum
                DSsumSignedIntT ((long*)dataStartPtr, points, boxFactor,(long)LONG_MAX, (long)LONG_MIN);
                break;
            case 3: //max
                DSMaxT ((long*)dataStartPtr, points, boxFactor);
                break;
            case 4: // median
                DSMedianT ((long*)dataStartPtr, points, boxFactor);
                break;
            }
            break;
        case (NT_I16 | NT_UNSIGNED):
            switch (DSType){
            case 1:    //average
                DSaverageT ((unsigned short*) dataStartPtr, points, boxFactor);
                break;
            case 2: // sum
                DSsumUnSignedIntT ((unsigned short*)dataStartPtr, points, boxFactor,(unsigned short)USHRT_MAX);
                break;
            case 3: //max
                DSMaxT ((unsigned short*)dataStartPtr, points, boxFactor);
                break;
            case 4: // median
                DSMedianT ((unsigned short*)dataStartPtr, points, boxFactor);
                break;
            }
            break;
        case NT_I16:
            switch (DSType){
            case 1:    //average
                DSaverageT ((short*) dataStartPtr, points, boxFactor);
                break;
            case 2: // sum
                DSsumSignedIntT ((short*)dataStartPtr, points, boxFactor,(short)SHRT_MAX, (short)SHRT_MIN);
                break;
            case 3: //max
                DSMaxT ((short*)dataStartPtr, points, boxFactor);
                break;
            case 4: // median
                DSMedianT ((short*)dataStartPtr, points, boxFactor);
                break;
            }
            break;
        case (NT_I8 | NT_UNSIGNED):
            switch (DSType){
            case 1:    //average
                DSaverageT ((unsigned char*) dataStartPtr, points, boxFactor);
                break;
            case 2: // sum
                DSsumUnSignedIntT ((unsigned char*)dataStartPtr, points, boxFactor,(unsigned char)UCHAR_MAX);
                break;
            case 3: //max
                DSMaxT ((unsigned char*)dataStartPtr, points, boxFactor);
                break;
            case 4: // median
                DSMedianT ((unsigned char*)dataStartPtr, points, boxFactor);
                break;
            }
            break;
        case NT_I8:
            switch (DSType){
            case 1:    //average
                DSaverageT ((char*) dataStartPtr, points, boxFactor);
                break;
            case 2: // sum
                DSsumSignedIntT ((char*)dataStartPtr, points, boxFactor,(char)SCHAR_MAX, (char)SCHAR_MIN);
                break;
            case 3: //max
                DSMaxT ((char*)dataStartPtr, points, boxFactor);
                break;
            case 4: // median
                DSMedianT ((char*)dataStartPtr, points, boxFactor);
                break;
            }
            break;
        default:    // Unknown data type - possible in a future version of Igor.
            throw result = NT_FNOT_AVAIL;
            break;
        }    // end of switch

        //catch before resetting handle
    }catch (int result){
        p -> result = result;    //XFUNC error code
        return (result);
    }try{
        dimensionSizes [0] = xSize/boxFactor;
        dimensionSizes [1] = ySize;
        dimensionSizes [2] = zSize;
        dimensionSizes [3] = 0;
        if (result = MDChangeWave2 (wavH, -1, dimensionSizes, 1))
            throw result;
        WaveHandleModified (wavH);            // Inform Igor that we have changed the input wave.
        p -> result = result;                //XFUNC error code will be 0
        return (result);
    }
    // Catch block to return any errors that ocurred
    catch (int result){
        p -> result = result;
        return (result);            // XFUNC error code (non-zero).
    }
}

/****************************Decumulate Functions***********************************************************/
// The following template is used to handle any one of the different types of wave data
template <typename T> void DecumulateT(T *srcWaveStart, CountInt NumPnts, UInt32 epMax, UInt32 maxCount)
{
    T *srcWavePtr;
    // set srcWavePtr to last point in wave and work backwards
    for (srcWavePtr = srcWaveStart + NumPnts; srcWavePtr > srcWaveStart; srcWavePtr --){
        // if value of current point > value of previous point, subtract value of previous point
        if (*srcWavePtr >= (*(srcWavePtr -1)))
            *srcWavePtr -= *(srcWavePtr -1);
        else{ // counter rollover or missed count.
            if ((*(srcWavePtr -1) > (maxCount - epMax)) && (*srcWavePtr < epMax)) //counter rollover
                *srcWavePtr += (maxCount - (*(srcWavePtr -1)));
            else //missed count. Set to neighboring good count. For now, anyway. maybe later reurn a list of bad count positions?
                *srcWavePtr = *(srcWavePtr + 1);
        }
    }
}


/****************************************************************************************************************
Decumulate. For photon counting, the counter keeps a running total; i.e., it accumulates. To get counts for each pixel,
we need to subtract from the from count at each pixel the count of the pixel before it, i.e., decumulate
Also, the first pixel in each line contains photons from flyback time, so set it to 0
typedef struct DecumulateParams
double expMax;  //expected maximum counts per pixel. Used in seeing if counter has rolled over or other error
double bitSize;   //bitsize of the counter. expected to be either 24 or 32
waveHndl w1;  // input wave - is overwritten
Last Modified 2025/06/13 by Jamie Boyd
****************************************************************************************************************/
int Decumulate (DecumulateParamsPtr p)
{

    int result = 0;    // The error returned from various Wavemetrics functions
    int waveType; //  Wavetypes numeric codes for things like 32 bit floating point, 16 bit int, etc
    int numDimensions;    // number of dimensions in input and output waves
    CountInt dimensionSizes[MAX_DIMENSIONS+1];    // an array used to hold the width, height, layers, and chunk sizes
    BCInt dataOffset;    //offset in bytes from begnning of handle to a wave to the actual data - size of headers, units, etc.
    waveHndl wavH;        // handle to the input wave
    CountInt numPnts;    // number of points in the wave
    char* srcWaveStart;    // Pointer to start of data in input wave. Need to use char for these to use WM function to get data offset
    UInt32 epMax;        // expected maximum counts per pixel
    UInt32 maxCnt;        // maximum value of counter before rollover

    try{
        // Get handle to input wave. Make sure it exists.
        wavH = p->w1;
        if (wavH == NIL)
            throw result = NON_EXISTENT_WAVE;
        //Get data type, no text waves
        waveType = WaveType(p->w1);
        if (waveType==TEXT_WAVE_TYPE)
            throw result = NOTEXTWAVES;
        // Get number of used dimensions in wave.
        if (result = MDGetWaveDimensions(wavH, &numDimensions, dimensionSizes))
            throw int (result);
    }catch (int result){
        p->result = result;        //XFUNC error code
        return result;
    }try{
        // Get the offsets to the start of the data in the wave
        if (result = MDAccessNumericWaveData(wavH, kMDWaveAccessMode0, &dataOffset))
            throw result;
        //make pointer to stat of data
        srcWaveStart = (char*)(*wavH) + dataOffset;
        //Figure out how many points are in the wave
        numPnts =WavePoints(wavH);
        //get expected maximum values per pixel
        epMax = p->expMax;
        maxCnt = pow (2, p->bitSize);
        //Do the decumulating
        switch(waveType){
        case NT_I8:
            DecumulateT((char*)srcWaveStart,numPnts,epMax, maxCnt);
            break;
        case (NT_I8 | NT_UNSIGNED):
            DecumulateT((unsigned char*)srcWaveStart,numPnts,epMax, maxCnt);
            break;
        case NT_I16:
            DecumulateT((short*)srcWaveStart,numPnts,epMax, maxCnt);
            break;
        case (NT_I16 | NT_UNSIGNED):
            DecumulateT((unsigned short*)srcWaveStart,numPnts,epMax, maxCnt);
            break;
        case NT_I32:
            DecumulateT((long*)srcWaveStart,numPnts,epMax, maxCnt);
            break;
        case (NT_I32| NT_UNSIGNED):
            DecumulateT((unsigned long*)srcWaveStart,numPnts,epMax, maxCnt);
            break;
        case NT_FP32:
            DecumulateT((float*)srcWaveStart,numPnts,epMax, maxCnt);
            break;
        case NT_FP64:
            DecumulateT((double*)srcWaveStart, numPnts,epMax, maxCnt);
            break;
        default:    // Unknown data type - possible in a future version of Igor.
            throw result = NT_FNOT_AVAIL;
            break;
        }
        WaveHandleModified(wavH);            // Inform Igor that we have changed the input wave.
        p->result = result;        // return 0 for success
        return result;
    }catch (int result){
        p -> result = result;
        return result;  // XFUNC error code.
    }
}

/***************************************************************************************************************
template for TransposeFrames functions with frames that are not square
Last Modified 2013/07/15 by Jamie Boyd */
template <typename T> int TransposeFramesT (T *dataStartPtr, CountInt xSize, CountInt ySize, CountInt zSize)
{
    //reserve some memory to copy each frame into by turn
    CountInt frameSize = (xSize * ySize);
    BCInt frameBytes = (frameSize * sizeof(T));
    T* frameCopyStart = (T*)WMNewPtr (frameBytes);
    if (frameCopyStart == NULL)
        return NOMEM;
    // make Pointer to end of the data
    T* dataEndPtr = dataStartPtr + (frameSize * zSize);
    // make pointer for progressing through the given data
    T *dataWavePtr;
    //pointers for iterating through x and y
    T *frameCopyPtr, *frameXend, *frameYend;
    CountInt toNextX = frameSize-1;
    for (dataWavePtr= dataStartPtr; dataWavePtr < dataEndPtr;){
        //make a copy of the current frame using the frame copy pointer
        frameCopyStart = (T*) memcpy (frameCopyStart, dataWavePtr, frameBytes);
        //iterate through x
        for (frameCopyPtr = frameCopyStart, frameXend = frameCopyStart + xSize;frameCopyPtr < frameXend;frameCopyPtr -= toNextX){
            // iterate through y
            for (frameYend = frameCopyPtr + frameSize; frameCopyPtr < frameYend ;frameCopyPtr += xSize, dataWavePtr+=1){
                *dataWavePtr = *frameCopyPtr;
            }
        }
    }
    //free memory for frame copy
    WMDisposePtr ((Ptr)frameCopyStart);
    return 0;
}

/***************************************************************************************************************
Template for TransposeFrames functions with frames that are square, as they often are. A little faster
Last Modified 2013/07/15 by Jamie Boyd */
template <typename T> int TransposeSquareFramesT (T *dataStartPtr, CountInt xSize, CountInt zSize)
{
    CountInt frameSize = xSize * xSize;
    // make Pointer to end of the data
    T* dataEndPtr = dataStartPtr + ((frameSize * zSize) - xSize);
    // make pointers for progressing through the data
    T *xPtr, *yPtr;
    // variables to point to the ends of the current line. x and y both the same, so we only need count X
    T *xEndLinePtr;
    // variable to count lines
    CountInt lines;
    // frames - 1, just because it's easier to read this way
    CountInt frameSizeMinus1 = frameSize - 1;
    // temp variable for SWAP macro
    T temp;
    //frames
    for (xPtr = dataStartPtr + 1, yPtr = dataStartPtr + xSize; xPtr < dataEndPtr; xPtr += 1,yPtr += 1){
        //columns/rows
        for (lines = 1; lines < xSize; lines += 1, xPtr += lines, yPtr -= (frameSizeMinus1 - lines*xSize)){
            // points in individual column/row
            for (xEndLinePtr = xPtr + (xSize - lines); xPtr < xEndLinePtr; xPtr += 1,yPtr += xSize){
                SWAP (*xPtr, *yPtr);
            }
        }
    }
    return 0;
}

/*****************************************************************************************************************
TransposeFrames. Transposes each frame in a 3D wave (equivalent to a horizontal flip and a 90 degree counter-clockwise
rotation). Needed because microscope may have an extra mirror in the light path, thanks to A. Goroshkov.
typedef struct TransposeFramesParams
waveHndl w1 // input wave is modifed
Last Modified 2025/06/13 by Jamie Boyd
*****************************************************************************************************************/
int TransposeFrames (TransposeFramesParamsPtr p)
{

    int result = 0;    // The error returned from various Wavemetrics functions
    int waveType; //  Wavetypes numeric codes for things like 32 bit floating point, 16 bit int, etc
    int numDimensions;    // number of dimensions in input and output waves
    CountInt dimensionSizes[MAX_DIMENSIONS+1];    // an array used to hold the width, height, layers, and chunk sizes
    BCInt dataOffset;    //offset in bytes from begnning of handle to a wave to the actual data - size of headers, units, etc.
    CountInt xSize;    // The length of each line in each frame
    CountInt ySize; // number of lines in each frame
    CountInt zSize; // number of frames in the stack
    UInt8 is3D; // need to know 2D from 3D when redimensioning
    waveHndl wavH;        // handle to the input wave
    char* dataStartPtr;    // Pointer to start of data in input wave. Need to use char for these to use WM function to get data offset
    //First try block is for setting stuff up, before wave handle is locked
    try {
        // Get handle to input wave. Make sure it exists.
        wavH = p->w1;
        if (wavH == NIL)
            throw result = NON_EXISTENT_WAVE;
        // Get wave data type.
        waveType = WaveType(wavH);
        // Can't process text waves
        if (waveType == TEXT_WAVE_TYPE)
            throw result = NOTEXTWAVES;
        // Get number of used dimensions in wave.
        if (result = MDGetWaveDimensions(wavH, &numDimensions, dimensionSizes))
            throw result;
        // Check that wave is 2D or 3D
        if ((numDimensions == 1) || (numDimensions == 4))
            throw result = INPUTNEEDS_2D3D_WAVE;
        // Get dimension sizes info and do special case when number of frames is 1
        xSize = dimensionSizes[0];
        ySize = dimensionSizes[1];
        if (numDimensions == 2){
            zSize = 1;
            is3D = 0;
        }else{
            zSize = dimensionSizes[2];
            is3D = 1;
        }
    }catch (int result){
        p -> result = result;
        return result;  // XFUNC error code.
    }try {
        // Get the offsets to the data in the wave
        if (result = MDAccessNumericWaveData(wavH, kMDWaveAccessMode0, &dataOffset))
            throw result;
        dataStartPtr = (char*)(*wavH) + dataOffset;
        if (xSize == ySize){
            switch (waveType) {
            case NT_FP64:
                if (result = TransposeSquareFramesT ((double*) dataStartPtr, xSize, zSize))
                    throw result;
                break;
            case NT_FP32:
                if (result =TransposeSquareFramesT ((float*) dataStartPtr, xSize, zSize))
                    throw result;
                break;
            case (NT_I32 | NT_UNSIGNED):
                if (result =TransposeSquareFramesT ((unsigned long*) dataStartPtr, xSize, zSize))
                    throw result;
                break;
            case NT_I32:
                if (result =TransposeSquareFramesT ((long*) dataStartPtr, xSize, zSize))
                    throw result;
                break;
            case (NT_I16 | NT_UNSIGNED):
                if (result =TransposeSquareFramesT ((unsigned short*) dataStartPtr, xSize,zSize))
                    throw result;
                break;
            case NT_I16:
                if (result = TransposeSquareFramesT ((short*) dataStartPtr, xSize, zSize))
                    throw result;
                break;
            case (NT_I8 | NT_UNSIGNED):
                if (result =TransposeSquareFramesT ((unsigned char*) dataStartPtr, xSize, zSize))
                    throw result;
                break;
            case NT_I8:
                if (result = TransposeSquareFramesT ((char*) dataStartPtr, xSize, zSize))
                    throw result;
                break;
            default:    // Unknown data type - possible in a future version of Igor.
                throw result = NT_FNOT_AVAIL;
                break;
            }    // end of switch
        }else{
            switch (waveType) {
            case NT_FP64:
                if (result = TransposeFramesT ((double*) dataStartPtr, xSize, ySize, zSize))
                    throw result;
                break;
            case NT_FP32:
                if (result =TransposeFramesT ((float*) dataStartPtr, xSize, ySize, zSize))
                    throw result;
                break;
            case (NT_I32 | NT_UNSIGNED):
                if (result =TransposeFramesT ((unsigned long*) dataStartPtr, xSize, ySize, zSize))
                    throw result;
                break;
            case NT_I32:
                if (result =TransposeFramesT ((long*) dataStartPtr, xSize, ySize, zSize))
                    throw result;
                break;
            case (NT_I16 | NT_UNSIGNED):
                if (result =TransposeFramesT ((unsigned short*) dataStartPtr, xSize, ySize, zSize))
                    throw result;
                break;
            case NT_I16:
                if (result = TransposeFramesT ((short*) dataStartPtr, xSize, ySize, zSize))
                    throw result;
                break;
            case (NT_I8 | NT_UNSIGNED):
                if (result =TransposeFramesT ((unsigned char*) dataStartPtr, xSize, ySize, zSize))
                    throw result;
                break;
            case NT_I8:
                if (result = TransposeFramesT ((char*) dataStartPtr, xSize, ySize, zSize))
                    throw result;
                break;
            default:    // Unknown data type - possible in a future version of Igor.
                throw result = NT_FNOT_AVAIL;
                break;
            }
        }
    }catch (int result){
        p -> result = result;
        return (result);                            // XFUNC error code.
    }try{
        if (xSize != ySize){
            // redimension, swapping X and Ys
            MemClear(dimensionSizes, sizeof(dimensionSizes));
            dimensionSizes [0] = ySize;
            dimensionSizes [1] = xSize;
            if (is3D)
                dimensionSizes [2] =0;
            else{
                dimensionSizes [2] = zSize;
                dimensionSizes [3] =0;
            }
            if (result = MDChangeWave2 (wavH, -1, dimensionSizes, 1))
                throw result;
        }
        WaveHandleModified(wavH);            // Inform Igor that we have changed the input wave.
        p -> result = result;                //XFUNC error code will be 0
        return (result);
    }
    // catch and return any errors that ocurred - handle is already reset
    catch (int result){
        p -> result = result;
        return (result);                            // XFUNC error code.
    }
}

