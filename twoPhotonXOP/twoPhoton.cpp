/*	twoPhoton.cpp

A collection of functions designed to work with the 2P-procedures revamped to work with XOP toolkit 6.3.
See the twoPhoton.ihf file for a detailed desription of each function.
Last Modified:
2016/11/19 by Jamie Boyd  updating For Igor 7
*/

#include "twoPhoton.h"

// globals for multithreading
UInt8 gNumProcessors;
#ifdef __MWERKS__
sTaskDataPtr gTaskData; // pointer to an array of task data structures used to pass info to threads
MPQueueID gNotificationQueue; // notification queue to pass messages to all threads
#else // pthreads on OS X and Windows
// pointer to an array of pthread task data structures
// Not used, as we don't have resident threads for pThreads yet
pthread_t* gThreadsPtr;
#endif

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

	// make some resident threads for processing
	gNumProcessors = num_processors();
#ifdef __MWERKS__
	gTaskData = (sTaskDataPtr)NewPtrClear (gNumProcessors * sizeof(sTaskData));
	MPCreateQueue(&gNotificationQueue);
	for(UInt8 iThread = 0; iThread < gNumProcessors; iThread++ ) {
		MPCreateQueue(&gTaskData[iThread].requestQueue);
		MPCreateQueue(&gTaskData[iThread].resultQueue);
		MPCreateTask(MPthreadCall, &gTaskData[iThread], kMPStackSize, gNotificationQueue, NULL, NULL, kMPTaskOptions, &gTaskData[iThread].TaskID);
	}
#else // pthreads on OS X and Windows
	// haven't got around to making resident threads for pThreads. We make them and join them every time

#endif
	SetXOPResult(0L);
	return EXIT_SUCCESS;
}

/****************************************************************************************************************
Multiprocessing "worker functions". Each thread will be running a copy of one of these functions.
Main thread notifies the worker threads when they have work to do.
Worker functions get a pointer to a structure contining a pointer to their share of the data to process,
and a pointer to the right function to process the data. Worker functions call the processing function,
and notify the main thread when they are done */
#ifdef __MWERKS__
OSStatus MPthreadCall (void *parameter) {
	OSErr theErr = noErr;
	Boolean finished;
	UInt32 message;
	/* Get a pointer to this task's Task data structure, which contains a pointer to a task-specific
	paramaeter struct and a pointer to a task-specific function */
	sTaskDataPtr p = (sTaskDataPtr)parameter;
	finished = false;
	while (!finished) {
		theErr = MPWaitOnQueue(p->requestQueue, (void **)&message, NULL, NULL, kDurationForever);
		if (theErr == noErr ) {
			/* Call task-specific function with the pointer to task-specific struct */
			p->process ((void*) p->params);
			/* Notify queue that this task is finished */
			theErr = noErr;
			MPNotifyQueue( p->resultQueue, (void *) theErr, NULL, NULL);
		}else{
			finished = true;
		}
	}
	/* Task is finished now */
	return (theErr);
}
#endif
