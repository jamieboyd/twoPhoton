/*	twoPhoton.cpp

A collection of functions designed to work with the 2P-procedures revamped to work with XOP toolkit 6.3.
See the twoPhoton.ihf file for a detailed desription of each function.
Last Modified:
2016/11/19 by Jamie Boyd  updating For Igor 7
*/

#include "twoPhoton.h"

// globals for multithreading
UInt8 gNumProcessors;


/*	RegisterFunction()
Igor calls this at startup time to find the address of the
XFUNCs added by this XOP.
*/
static XOPIORecResult RegisterFunction(){

	int funcIndex = (int)GetXOPItem(0);		// Which function is Igor asking about?
	switch (funcIndex) {
	case 0:
		return((XOPIORecResult)KalmanAllFrames);	// All functions are called using the direct method.
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
	return NIL;
}


/*	XOPEntry()

This is the entry point from the host application to the XOP for all messages after the
INIT message.
*/
#if XOP_TOOLKIT_VERSION < 600
static void
#else
extern "C" void
#endif
	XOPEntry(void)
{
	XOPIORecResult result = 0;

	switch (GetXOPMessage()) {
	case FUNCADDRS:
		result = RegisterFunction();
		break;
	}
	SetXOPResult(result);
}

/*	main(ioRecHandle)

This is the initial entry point at which the host application calls XOP.
The message sent by the host must be INIT.
main() does any necessary initialization and then sets the XOPEntry field of the
ioRecHandle to the address to be called for future messages.
*/
HOST_IMPORT int
#if XOP_TOOLKIT_VERSION < 600
	main(IORecHandle ioRecHandle)
#else
	XOPMain(IORecHandle ioRecHandle)	// The use of XOPMain rather than main means this XOP requires Igor Pro 6.20 or later
#endif
{
	XOPInit(ioRecHandle);	// Do standard XOP initialization.
	SetXOPEntry(XOPEntry);	// Set entry point for future calls.
#if XOP_TOOLKIT_VERSION < 600
	if (igorVersion < 500) {			// Requires Igor Pro 5 or later.
#else
	if (igorVersion < 620) {			// Requires Igor Pro 6.20 or later.
#endif
		SetXOPResult(OLD_IGOR);			// OLD_IGOR is defined in twoPhoton.h and there are corresponding error strings in twoPhoton.r and twoPhotonWinCustom.rc.
		return EXIT_FAILURE;
	}

	gNumProcessors = num_processors();
	SetXOPResult(0L);
	return EXIT_SUCCESS;
}
