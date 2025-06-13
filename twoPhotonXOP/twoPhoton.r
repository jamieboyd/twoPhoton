/*    twoP.r -- resources for twoP XOP
    Last Modified 2025/06/13 by Jamie Boyd
 */
#include "XOPStandardHeaders.r"

resource 'vers' (1) {						/* XOP version info */
	0x01, 0x01, final, 0x00, 0,				/* version bytes and country integer */
	"1.1",
	"1.1, Copyright 2003-2025 Jamie Boyd, all rights reserved."
};

resource 'vers' (2) {						/* Igor version info */
	0x06, 0x20, release, 0x00, 0,			/* version bytes and country integer */
	"6.20",
	"(for Igor 6.20 or later)"
};

resource 'STR#' (1100) {					/* custom error messages */
	{
        /* [1] OLD_IGOR */
        "twoP requires Igor Pro 6.2 or later.",
        /* [2] NON_EXISTENT_WAVE */
        "One of the input waves does not exist.",
        /* [3] INPUTNEEDS_3D_WAVE */
        "The input wave needs to have exactly 3 dimensions.",
        /* [4] OUTPUTNEEDS_2D3D_WAVE */
        "The output wave needs to have 2 or 3 dimensions.",
        /* [5] NOTSAMEWAVETYPE */
        "The data types of the waves need to be the same.",
        /* [6] NOTSAMEDIMSIZE */
        "The dimensions of the waves need to be the same.",
        /* [7] INVALIDOUTPUTFRAME */
        "An invalid frame in the output wave was specified.",
        /* [8] INVALIDINPUTFRAME */
        "An invalid range of input frames was specified.",
        /*[9] OUTPUTNEEDS_2D_WAVE */
        "The output wave needs to have exactly 2 dimensions.",
        /*[10] BADKERNEL */
        "The convolution kernel must be a 2D single precision floating point wave of odd dimensions in X and Y.",
        /*[11] INPUTNEEDS_2D3D_WAVE */
        "The input wave needs to have 2 or 3 dimensions.",
        /*[12] NO_INPUT_STRING */
        "An input string is missing or is invalid.",
        /*[13] BADFACTOR */
        "The scaling factor specified does not divide evenly into the image width.",
        /*[14] BADDSTYPE */
        "The Down Sample Type was not recognized. Allowed types are 1 = average, 2 = sum, 3 = max, 4 = median.",
        /*[15] USERABORT */
        "Procedure Aborted.",
        /*[16] OVERWRITEALERT*/
        "Destination wave already exists and can not be overwritten.",
        /*[17] NOTEXTWAVES */
        "This function does not work for text waves.",
        /*[18] BADDIMENSION */
        "Can not project along the specified dimensions. Allowed dimensions are 0 for X, 1 for Y, and 2 for Z.",
        /*[19] NOT16OR32*/
        "This function only works with 16 bit integers or 32 bit floating points waves.",
        /*[20] OUTPUTNEEDS_3D_WAVE*/
        "The output wave needs to have exactly 3 dimensions.",
        /*[21] BADWAVEINLIST*/
        "One of the waves specified in the input list does not exist.",
        /*[22] BADSYMKERNEL */
        "A symmetric convolution kernel must be a 1D single precision floating point wave of odd length.",
	}
};

/* no menu item */

resource 'XOPI' (1100) {
	XOP_VERSION,							// XOP protocol version.
	DEV_SYS_CODE,							// Code for development system used to make XOP
	XOP_FEATURE_FLAGS,						// Tells Igor about XOP features
	XOPI_RESERVED,							// Reserved - must be zero.
	XOP_TOOLKIT_VERSION,					// XOP Toolkit version.
};

resource 'XOPF' (1100) {
	{
		"KalmanAllFrames",					/* function name */
		F_WAVE | F_THREADSAFE | F_EXTERNAL,	/* function category */
        NT_FP64,						    /* return value type */
		{
			WAVE_TYPE,
            HSTRING_TYPE,
            NT_FP64,
            NT_FP64,
		},

		"KalmanSpecFrames",			        /* function name */
		F_WAVE | F_THREADSAFE | F_EXTERNAL,	/* function category */
		NT_FP64,							/* return value type */
		{
			WAVE_TYPE,						/* parameter types */
            NT_FP64,                        // Start of layers to average
            NT_FP64,                        // End of layers to average
            WAVE_TYPE,                      // output wave
            NT_FP64,                        // layer of output wave to modify
            NT_FP64,                        // multiplier
		},

		"KalmanWaveToFrame",			/* function name */
        F_WAVE | F_THREADSAFE | F_EXTERNAL,    /* function category */
		NT_FP64,							/* return value type */
		{
			WAVE_TYPE,						/* parameter types */
            NT_FP64,                        // multiplier
		},

		"KalmanList",		                    /* function name */
        F_WAVE | F_THREADSAFE | F_EXTERNAL,    /* function category */
		NT_FP64,							/* return value type */
		{
            HSTRING_TYPE,    // Semicolon separated list of input waves
            HSTRING_TYPE,    // Path and name of output wave
            NT_FP64,        //multiplier
            NT_FP64,        // overwrite output wave
		},

		"KalmanNext",					/* function name */
        F_WAVE | F_THREADSAFE | F_EXTERNAL,    /* function category */
		NT_FP64,							/* return value type */
		{
            WAVE_TYPE,        // Input Wave
             WAVE_TYPE,        // output wave
            NT_FP64,        // how many waves have previously been added
		},
        
        "ProjectAllFrames",
        F_ANLYZWAVES | F_THREADSAFE | F_EXTERNAL,                /* function category */
        NT_FP64,
        {
            WAVE_TYPE,        // Input wave
            HSTRING_TYPE,    //     string with path to output wave
            NT_FP64,        //    Which dimension we want to collapse on, 0 for x, 1 for y, 2 for z
            NT_FP64,        //  overwrite
            NT_FP64,        //     minimum (0) or maximum (1) projection
        },
        "ProjectSpecFrames",

        F_ANLYZWAVES | F_THREADSAFE | F_EXTERNAL,                /* function category */
        NT_FP64,
        {
            WAVE_TYPE,    // Input wave
            NT_FP64,    // start layer
            NT_FP64,    // end layer
            WAVE_TYPE,    // output wave
            NT_FP64,    // output layer
            NT_FP64,    // Which dimension we want to collapse on, 0 for x, 1 for y, 2 for z
            NT_FP64,    // minimum (0), maximum (1), average (2), or median (3) projection
        },
        
        "ProjectXSlice",
        F_ANLYZWAVES | F_THREADSAFE | F_EXTERNAL,                /* function category */
        NT_FP64,
        {
            WAVE_TYPE,    // Input wave
            WAVE_TYPE,    // output wave
            NT_FP64,    // slice to get
        },
        
        "ProjectYSlice",
        F_ANLYZWAVES | F_THREADSAFE | F_EXTERNAL,                /* function category */
        NT_FP64,
        {
            WAVE_TYPE,    // Input wave
            WAVE_TYPE,    // output wave
            NT_FP64,    // slice to get
        },
        
        "ProjectZSlice",
        F_ANLYZWAVES | F_THREADSAFE | F_EXTERNAL,                /* function category */
        NT_FP64,
        {
            WAVE_TYPE,    // Input wave
            WAVE_TYPE,    // output wave
            NT_FP64,    // slice to get
        },
        
        "SwapEven",
        F_ANLYZWAVES | F_THREADSAFE | F_EXTERNAL,                /* function category */
        NT_FP64,
        {
            WAVE_TYPE,        //InPutWave
        },
        
        "DownSample",
        F_ANLYZWAVES | F_THREADSAFE | F_EXTERNAL,                /* function category */
        NT_FP64,
        {
            WAVE_TYPE,    //input wave
            NT_FP64,    // factor bywhich to down sample
            NT_FP64,    // how to down sample, mean, median, max, sum
        },
        
        "Decumulate",
        F_ANLYZWAVES | F_THREADSAFE | F_EXTERNAL,                /* function category */
        NT_FP64,
        {
            WAVE_TYPE,        //InPutWave
            NT_FP64,        // counterbits (24 or 32 are normal)
            NT_FP64,        // expeced max counts per pixels for heuristic
        },
        
        "TransposeFrames",
        F_ANLYZWAVES | F_THREADSAFE | F_EXTERNAL,                /* function category */
        NT_FP64,
        {
            WAVE_TYPE,        //InPutWave
        },
        
        "ConvolveFrames",
        F_ANLYZWAVES | F_THREADSAFE | F_EXTERNAL,                /* function category */
        NT_FP64,
        {
            WAVE_TYPE,    //input wave
            HSTRING_TYPE,    //     string with path to output wave
            NT_FP64,     //   0 for output wave same type as input, 1 to make it float
            WAVE_TYPE,    //kernel wave
            NT_FP64,  // flag to overwrite existing waves.
        },
        
        "SymConvolveFrames",
        F_ANLYZWAVES | F_THREADSAFE | F_EXTERNAL,                /* function category */
        NT_FP64,
        {
            WAVE_TYPE,    //input wave
            HSTRING_TYPE,    //     string with path to output wave
            NT_FP64,     //   0 for output wave same type as input, 1 to make it float
            WAVE_TYPE,    //kernel wave
            NT_FP64,  // flag to overwrite existing waves.
        },
        
        "MedianFrames",
        F_ANLYZWAVES | F_THREADSAFE | F_EXTERNAL,                /* function category */
        NT_FP64,
        {
            WAVE_TYPE,        //input wave
            HSTRING_TYPE,    //     string with path to output wave
            NT_FP64,    // Width over which to apply median
            NT_FP64,  // flag to overwrite existing waves.
        },
    }
};
