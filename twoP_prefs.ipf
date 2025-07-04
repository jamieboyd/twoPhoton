#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

//constant TwoPPrefsVers = 100


function makeGlobals ()
	newdatafolder/o root:packages:twoP:prefs
	variable/G root:packages:twoP:prefs:defaultPixtime

end


Structure kTwoPPrefsStruct
	char imBoardName[32]	// name of the DAQ board used for imaging, as configured with MAX
	
	
	
	uint32 version		// Preferences structure version number. 100 means 1.00.
	char stageProc[32]	// name of stage encoder procedure, MS200, e.g.
	char stagePort[32]	// serial port to use with the stage encoder, COM1, e.g., or USB device name
	char boardName[32]	// name of the DAQ board used, as configured with MAX
	float sampleRate		// sample rate for incoming data, in Hz
	char Ctr0outPin [32]	// names of the output pins for counter 0 and counter 1, usually Ctr0out and Ctr1out or PFI12 and PFI12
	char Ctr1outPin [32]
	float scanEndSecs	//  time in seconds to wrap up the scan before trying to start another. Faster for PCI bloards than for USB devices
	uchar nChans		// Number of channels used in this setup
	Struct ChRChanStruct Chans [16] // array of channels used for recording
	uchar laserVOut		// number of the analog output channel used to control laser power
	uchar laserPolarity	// 0 means laser TTL is LOW when laser is off, HI when on
	uchar accOutPolarity	// 0 means accessory output is LOW when off, HI when triggered
	char powerProc [32]	// name of procedure used to control laser power
	char powerCal [32]	// name of power calibration file in use
	uchar PositionMode 	// 0 means position using stage, 1 means use galvos
	char gBoardName [32]	// name of NI board used to drive galvos (may be same as boardName)
	float galvoScalX			// metres/Volt scaling on the galvos in X dimension
	float galvoScalY			// meters/Volt sclaing on the galvos in the Y dimension
EndStructure
