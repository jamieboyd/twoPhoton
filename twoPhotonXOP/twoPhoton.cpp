/*	twoP.c
A collection of functions designed to work with the twoP procedures revamped to work with XOP toolkit 7
See the twoPhotonXOP.ihf file for a detailed desription of each function.
Last Modified:
2025/06/13 by Jamie Boyd  updating For XOP toolkit 7
*/

#include "twoPhoton.h"

// Global Variable for number of processors for threading
UInt8 gNumProcessors;

/*	RegisterFunction()
	
	Igor calls this at startup time to find the address of the
	XFUNCs added by this XOP. See XOP manual regarding "Direct XFUNCs".
*/
static XOPIORecResult RegisterFunction() {
	int funcIndex;

	funcIndex = (int)GetXOPItem(0);		// Which function is Igor asking about?
	switch (funcIndex) {
        case 0:
            return((XOPIORecResult)KalmanAllFrames);    // All functions are called using the direct method.
            break;
        case 1:
            return ((XOPIORecResult) KalmanSpecFrames);
            break;
        case 2:
            return ((XOPIORecResult) KalmanWaveToFrame);
            break;
        case 3:
            return ((XOPIORecResult) KalmanList);
            break;
        case 4:
            return ((XOPIORecResult) KalmanNext);
            break;
        case 5:
            return ((XOPIORecResult) ProjectAllFrames);
            break;
        case 6:
            return ((XOPIORecResult) ProjectSpecFrames);
            break;
        case 7:
            return ((XOPIORecResult) ProjectXSlice);
            break;
        case 8:
            return ((XOPIORecResult) ProjectYSlice);
            break;
        case 9:
            return ((XOPIORecResult) ProjectZSlice);
            break;
        case 10:
            return ((XOPIORecResult) SwapEven);
            break;
        case 11:
            return ((XOPIORecResult) DownSample);
            break;
        case 12:
            return ((XOPIORecResult) Decumulate);
            break;
        case 13:
            return ((XOPIORecResult) TransposeFrames);
            break;
        case 14:
            return ((XOPIORecResult) ConvolveFrames);
            break;
        case 15:
            return ((XOPIORecResult) SymConvolveFrames);
            break;
        case 16:
            return ((XOPIORecResult) MedianFrames);
            break;
	}
	return 0;
}

/*	XOPEntry()
	This is the entry point from the host application to the XOP for all messages after the
	INIT message.
*/
extern "C" void XOPEntry(void) {
	XOPIORecResult result = 0;
	switch (GetXOPMessage()) {
		case FUNCADDRS:
			result = RegisterFunction();
			break;
	}
	SetXOPResult(result);
}

/*	XOPMain(ioRecHandle)

	This is the initial entry point at which the host application calls XOP.
	The message sent by the host must be INIT.
	
	XOPMain does any necessary initialization and then sets the XOPEntry field of the
	ioRecHandle to the address to be called for future messages.
*/
HOST_IMPORT int XOPMain(IORecHandle ioRecHandle){		// The use of XOPMain rather than main requires Igor Pro 6.20 or later
	XOPInit(ioRecHandle);				// Do standard XOP initialization.
	SetXOPEntry(XOPEntry);				// Set entry point for future calls.
	if (igorVersion < 620) {			// Requires Igor Pro 6.20 or later.
		SetXOPResult(OLD_IGOR);			// OLD_IGOR is defined in twoP.h and there are corresponding error strings in twoP.r and twoPWinCustom.rc.
		return EXIT_FAILURE;
	}
    gNumProcessors = num_processors();
	SetXOPResult(0L);
	return EXIT_SUCCESS;
}
