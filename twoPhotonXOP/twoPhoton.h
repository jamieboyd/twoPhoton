/*
	twoP.h -- equates for twoP XOP
*/
#ifndef TWOPHOTON_H_
#define TWOPHOTON_H_

#include "ParseWavePath.h"              // Utility to parse strings into data folder paths and wave names
#include "XOPResources.h"                // Contains definition of XOP_TOOLKIT_VERSION
#include "XOPStandardHeaders.h"            // Include ANSI headers, Mac headers, IgorXOP.h, XOP.h and XOPSupport.h

/* twoP custom error codes */

#define OLD_IGOR 1 + FIRST_XOP_ERR
#define NON_EXISTENT_WAVE 2 + FIRST_XOP_ERR
#define INPUTNEEDS_3D_WAVE 3 + FIRST_XOP_ERR
#define OUTPUTNEEDS_2D3D_WAVE 4 + FIRST_XOP_ERR
#define NOTSAMEWAVETYPE 5 + FIRST_XOP_ERR
#define NOTSAMEDIMSIZE 6 + FIRST_XOP_ERR
#define INVALIDOUTPUTFRAME 7 + FIRST_XOP_ERR
#define INVALIDINPUTFRAME 8 + FIRST_XOP_ERR
#define OUTPUTNEEDS_2D_WAVE 9 + FIRST_XOP_ERR
#define BADKERNEL 10 + FIRST_XOP_ERR
#define INPUTNEEDS_2D3D_WAVE 11 + FIRST_XOP_ERR
#define NO_INPUT_STRING 12 + FIRST_XOP_ERR
#define BADFACTOR 13 + FIRST_XOP_ERR
#define BADDSTYPE 14 + FIRST_XOP_ERR
#define USERABORT 15 + FIRST_XOP_ERR
#define OVERWRITEALERT 16 + FIRST_XOP_ERR
#define NOTEXTWAVES 17 + FIRST_XOP_ERR
#define BADDIMENSION 18 + FIRST_XOP_ERR
#define NOT16OR32 19 + FIRST_XOP_ERR
#define OUTPUTNEEDS_3D_WAVE 20 + FIRST_XOP_ERR
#define BADWAVEINLIST 21 + FIRST_XOP_ERR
#define BADSYMKERNEL 22 + FIRST_XOP_ERR

// mnemonic defines
#define OVERWRITE 1
#define NO_OVERWITE 0
#define SPINCURSOR 1
#define NO_SPINCURSOR 0
#define KILLOUTPUT 1
#define NO_KILLOUTPUT 0

//preprocessor macro to swap 2 values
#define SWAP(a,b) temp=(a);(a)=(b);(b)=temp

// Threading platform-dependent globals,includes, and macros
extern UInt8 gNumProcessors;

// include pThreads library on Windows
#ifdef  _WINDOWS_
// include pThreads library on Windows
#include "pthread.h"
#include "sched.h"
#include "semaphore.h"
static inline int num_processors(){
    SYSTEM_INFO info;
    GetSystemInfo(&info);
    return info.dwNumberOfProcessors;
}
#endif
// include native pThreads library on MacOS
#ifdef __GNUC__
#include <pthread.h>
#include <sys/types.h>
#include <sys/sysctl.h>
static inline int num_processors(){
    int np = 1;
    size_t length = sizeof( np );
    sysctlbyname("hw.ncpu", &np, &length, NULL, 0);
    return np;
}
#endif
// an array of pthread_t for pthreads on Windows or MacOS
extern pthread_t* gThreadsPtr;

// Structure definitions. All structures passed to Igor are two-byte aligned
#pragma pack(2)

//Kalman Averaging
typedef struct KalmanAllFramesParams {
    double overWrite;    //0 to give errors when wave already exists. non-zero to overwrite existing wave without warning.
    double multiplier;    // Multiplier for,e.g., 16 bit waves containing less than 16 bits of data
    Handle outPutPath;    // A handle to a string containing path to output wave we want to make
    waveHndl inPutWaveH;    // handle to a 3D input wave
    double result;
}KalmanAllFramesParams, *KalmanAllFramesParamsPtr;

typedef struct KalmanSpecFramesParams {
    double multiplier;    // Multiplier for 16 bit waves containing less than 16 bits of data
    double outPutLayer;    // layer of output wave to modify
    waveHndl outPutWaveH;//handle to output wave
    double endLayer;    // end of lyaers to average
    double startLayer;    // start of layers to average for input wave
    waveHndl inPutWaveH;// handle to input wave
    double result;
}KalmanSpecFramesParams, *KalmanSpecFramesParamsPtr;

typedef struct KalmanWaveToFrameParams  {
    double multiplier;    // Multiplier for 16 bit waves containing less than 16 bits of data
    waveHndl inPutWaveH;// handle to input wave
    double result;
} KalmanWaveToFrameParams, *KalmanWaveToFrameParamsPtr;

typedef struct KalmanListParams{
    double overwrite;    //0 to give errors when wave already exists. non-zero to overwrite existing wave.
    double multiplier; // Multiplier for 16 bit waves containing less than 16 bits of data
    Handle outPutPath;    // path and wavename of output wave
    Handle inPutList;    //semicolon separated list of input waves, with paths
    double result;
}KalmanListParams, *KalmanListParamsPtr;

typedef struct KalmanNextParams{
    double iKal; //which number of wave are we adding
    waveHndl outPutWaveH;//handle to output wave
    waveHndl inPutWaveH; // handle to output wave
    double result;
}KalmanNextParams, *KalmanNextParamsPtr;

// Project Image
typedef struct ProjectAllFramesParams {
    double projMode;        // variable for kind of projection, 0 is minimum intensity, 1 is maximum intensity
    double overwrite;    //0 to give errors when wave already exists. non-zero to cheerfully overwrite existing wave.
    double flatDimension;    //Which dimension we want to collapse on, 0 for x, 1 for y, 2 for z
    Handle outPutPath;    // A handle to a string containing path to output wave we want to make
    waveHndl inPutWaveH; //handle to the input wave
    double result;
} ProjectAllFramesParams, *ProjectAllFramesParamsPtr;

typedef struct ProjectSpecFramesParams {
    double projMode;             // 0 if minimum intensity projection, 1 for maximum intensity projection
    double flatDimension;    // the dimension that we are projecting along
    double outPutLayer;        //the layer in the output wave that receives the projection
    waveHndl outPutWaveH;    // A handle to output wave
    double inPutEndLayer;    //end of range of layers to project
    double inPutStartLayer;    //start of range of layers to project
    waveHndl inPutWaveH;    //handle to the input wave
    double result;
} ProjectSpecFramesParams, *ProjectSpecFramesParamsPtr;

typedef struct ProjectSliceParams{
    double slice;    // X, Y  or Z slice to get
    waveHndl outPutWaveH;    //handle to the output wave
    waveHndl inPutWaveH;//handle to the input wave
    double result;
}ProjectSliceParams, *ProjectSliceParamsPtr;

// LSM Utilities
typedef struct SwapEvenParams {
    waveHndl w1;
    double result;
}SwapEvenParams, *SwapEvenParamsPtr;

typedef struct DownSampleParams {
    double dsType;
    double boxFactor;
    waveHndl w1;
    double result;
} DownSampleParams, *DownSampleParamsPtr;

typedef struct DecumulateParams {
    double expMax;  //expected maximum counts per pixel. Used in seeing if counter has rolled over or other error
    double bitSize;   //bitsize of the counter. either 24 or 32
    waveHndl w1;
    double result;
} DecumulateParams, *DecumulateParamsPtr;

typedef struct TransposeFramesParams {
    waveHndl w1;
    double result;
}TransposeFramesParams, *TransposeFramesParamsPtr;

// Filter
typedef struct ConvolveFramesParams{
    double overWrite; // 1 if it is o.k. to overwrite existing waves, 0 to exit with error if overwriting will occur
    waveHndl kernelH; // convolution kernel, a 2D wave odd number of pixels high and wide, or 1D odd number wave for Sym
    double outPutType; // 0 for same type as input wave, non-zero for floating point wave
    Handle outPutPath;    // A handle to a string containing path to output wave we want to make, or empty string to overwrite existing wave
    waveHndl inPutWaveH; //input wave. needs to be 2D or 3D wave
    double result;
} ConvolveFramesParams, *ConvolveFramesParamsPtr;

typedef struct MedianFramesParams{
    double overWrite; // 1 if it is o.k. to overwrite existing waves, 0 to exit with error
    double kWidth; //width of the area over which to calculate the median. Must be an odd number
    Handle outPutPath;    // A handle to a string containing path to output wave we want to make, or empty string to overwrite existing wave
    waveHndl inPutWaveH;//input wave. needs to be 2D or 3D wave
    double result;
} MedianFramesParams, *MedianFramesParamsPtr;
// Return to default structure packing
#pragma pack()

/* Prototypes */
HOST_IMPORT int XOPMain(IORecHandle ioRecHandle);
//LSM Utilities
extern "C" int SwapEven (SwapEvenParamsPtr p);
int DownSample (DownSampleParamsPtr p);
int Decumulate (DecumulateParamsPtr p);
int TransposeFrames (TransposeFramesParamsPtr p);
// Kalman Averaging
int KalmanAllFrames(KalmanAllFramesParamsPtr);
int KalmanSpecFrames (KalmanSpecFramesParamsPtr);
int KalmanWaveToFrame (KalmanWaveToFrameParamsPtr);
int KalmanList (KalmanListParamsPtr p);
int KalmanNext (KalmanNextParamsPtr p);
// Project Image
int ProjectAllFrames (ProjectAllFramesParamsPtr p);
int ProjectSpecFrames (ProjectSpecFramesParamsPtr p);
int ProjectXSlice (ProjectSliceParamsPtr p);
int ProjectYSlice (ProjectSliceParamsPtr p);
int ProjectZSlice (ProjectSliceParamsPtr p);
//Filter frames
int ConvolveFrames (ConvolveFramesParamsPtr p);
int SymConvolveFrames (ConvolveFramesParamsPtr p);
int MedianFrames (MedianFramesParamsPtr p);
template <typename T> T medianT (UInt32 n, T* dataStrtPtr);
#endif
