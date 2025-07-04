#pragma rtGlobals=3
#pragma version = 2  	// Last Modified: 2017/08/14 by Jamie Boyd.
#pragma IgorVersion = 6.2

#include "twoP_AqConstants"
#include "twoP_examine"
#include "twoPex_export"
#include "Stages"
	
STATIC CONSTANT kImageFifoSize = 1e05
STATIC CONSTANT kImageFifoTransfer = 1e04
//******************************************************************************************************
//************************** Notes on National Instruments Boards ******************************
// One NI Board (referred to as the imageBoard) is used to generate the X and Y rasters that 
// drive the galvos, collect the image data, and open and close the shutter
// An E or X series board with at least 1M Samples/second per input channel, 2 output channels that update
// at 1MHz, 2 counter\timers, and at least1 DIO port

// The other, optional, board (referred to as the ePhysBoard) is used to collect the ephys trace(s), 
// output TTL triggers, and output clamp waves. Slower sampling rates are acceptable here, 
// but 2 counter/timers and 2 analog outputs are still expected.

//Defined constants for multiacquisition mode
constant kMultiUsePeriod = 0
constant kMultiUseWave = 1
constant kMultiUseTrigger =2 


//******************************************************************************************************
// Let's put the functions to make the Main Control panel in the macros menu. The code to put the main NidaqScans panel in the 
// macro menu is found in  "NidaqProc_examine.ipf ".
Menu "Macros"
	Submenu "twoP"
		submenu "Acquire"
			"Reset the NI Boards",/Q,  NQ_ResetBoards (1)
			"Reset Acquire Globals",/Q, NQ_ResetAcquire ()
			"Zero the Galvos", /Q, NQ_ZeroGalvos()
		end
	end
end 

Menu "GraphMarquee"
	Submenu "twoP Acquire"
		"Zoom Scan", /Q,NQ_SetScanSize(0)
		"Crop Scan", /Q, NQ_SetScanSize(1)
		"Set Line Scan", /Q, NQ_SetScanSize(2)
		"Set Live ROI", /Q, NQ_SetLiveROI ()
	end
End

//******************************************************************************************************
// Sets the output voltage on the galvos to 0
// Last Modified 2014/08/07 by Jamie Boyd
function NQ_ZeroGalvos()	
	SVAR imageboard = root:Packages:twoPhoton:acquire:imageBoard
	fDAQmx_WriteChan(imageBoard, 0, 0, -10, 10)
	fDAQmx_WriteChan(imageBoard, 1, 0, -10, 10)
end

//******************************************************************************************************
//*********************Code that handles the User Interface **************************************
//******************************************************************************************************
Function NQ_ResetAcquire ()
	
	doWindow/K twoP_Controls
	NQ_MakeAcquireFolder (1)
	NQ_MakeNidaqPanel (1)
end

//******************************************************************************************************
// Makes globals for acquire tab functions of the Nidaq Controls panel
// Last Modified 2016/10/12 by Jamie Boyd
Function NQ_MakeAcquireFolder (overWrite)
	variable overWrite
	
	variable AqFolderExists =1
	if (!(DataFolderExists ("root:Packages:twoP:Acquire")))
		AqFolderExists =0
		if (!(DataFolderexists ("root:Packages:twoP")))
			if (!(Datafolderexists ("root:Packages")))
				NewDataFolder root:packages
			endif
			NewDataFolder root:packages:twoP
		endif
		NewDataFolder root:Packages:twoP:Acquire
	endif
	if ((!AqFolderExists) || (overWrite))
		// make path to preferences and look for global prefs file with name of last loaded preferences
		variable hasPrefs =0 // set this to 1 if we find last used prefs
		NewPath/C/Q/O twoPprefsPath SpecialDirPath("Packages" , 0, 0, 0) + "twoP"
		if (cmpStr (GUIPListFiles ("twoPprefsPath", ".bin", "GlobalPrefs.bin", 4, ""), "GlobalPrefs;") == 0)
			// found global preferences, with name of last used prefs file. load name of last used preferences file
			Struct twoPGlobalPrefsStruct Gprefs
			LoadPackagePreferences "twoP", "GlobalPrefs.bin", 0, Gprefs
			string prefsFileName = Gprefs.lastPrefs
			// if the preferences file exists, load it
			if (cmpStr (GUIPListFiles("twoPprefsPath", ".bin", prefsFileName +  ".bin" ,4, ""), prefsFileName + ";") == 0)
				// make a prefs struct and fil it from chosen prefs file
				Struct twoPprefsStruct thePrefs
				LoadPackagePreferences "twoP", prefsFileName + ".bin", 0, thePrefs
				// Check version number
				if (ktwoPprefsVers != thePrefs.version)
					printf "Last used preferences file,\"%s\", is not the right version number for this copy of the twoP procedures.\r", prefsFileName
				else
					hasPrefs = 1
				endif
			endif
		endif
		if (hasPrefs)
			printf "Loading acquisition settings from prefs file %s\r.", prefsFileName
		else
			print "Loading acquisitions settings from constants in twoP_aqSettings"
		endif
		// Image device
		// Check device names of the imaging and ePhys boards (from NI-MAX configuration tool)
		string deviceList =  fDAQmx_DeviceNames(), alertStr
		string/G root:packages:twoP:acquire:ImageBoard = SelectString (hasPrefs, kNQimageBoard, thePrefs.imageBoard)
		SVAR imageBoard = root:packages:twoP:acquire:ImageBoard
		if ((CmpStr (imageBoard, "") != 0) && (WhichListItem(imageBoard, deviceList, ";", 0,0) == -1))
			sprintf AlertStr, "The specified imaging board, \"%s\", is not present in the system.\r", imageBoard
			Doalert 0,AlertStr
		endif
		// X and Y voltages and backups for reverting- set based on constants defining full scale
		
		
		•variable/G root:Packages:twoP:Acquire:xStartVoltsFS
•variable/G root:Packages:twoP:Acquire:yStartVoltsFS
•variable/G root:Packages:twoP:Acquire:xEndVoltsFS
•variable/G root:Packages:twoP:Acquire:yEndVoltsFS
•variable/G root:Packages:twoP:Acquire:pixWidthFS
•variable/G root:Packages:twoP:Acquire:pixHeightFS
		
		
		
		variable/G root:Packages:twoP:Acquire:xStartVoltsFS
		variable/G root:Packages:twoP:Acquire:xStartVolts =SelectNumber (hasPrefs, kNQxVoltStart, thePrefs.xVoltStart)
		NVAR xStartVolts = root:Packages:twoP:Acquire:xStartVolts
		variable/G root:Packages:twoP:Acquire:xStartVoltsBU =xStartVolts
		variable/G root:Packages:twoP:Acquire:yStartVolts=SelectNumber (hasPrefs, kNQyVoltStart,  thePrefs.yVoltStart)
		NVAR yStartVolts =  root:Packages:twoP:Acquire:yStartVolts
		variable/G root:Packages:twoP:Acquire:yStartVoltsBU=yStartVolts
		variable/G root:Packages:twoP:Acquire:xEndVolts = SelectNumber (hasPrefs, kNQxVoltEnd, thePrefs.xVoltEnd)
		NVAR xEndVolts = root:Packages:twoP:Acquire:xEndVolts
		variable/G root:Packages:twoP:Acquire:xEndVoltsBU= xEndVolts
		variable/G root:Packages:twoP:Acquire:yEndVolts = SelectNumber (hasPrefs, kNQyVoltEnd, thePrefs.yVoltEnd)
		NVAR endYVolts =  root:Packages:twoP:Acquire:yEndVolts
		variable/G root:Packages:twoP:Acquire:yEndVoltsBU = endYVolts
		// Initialize X and Y Voltages for line scans
		variable/G root:Packages:twoP:Acquire:LSStartVolts =xStartVolts
		variable/G root:Packages:twoP:Acquire:LSStartVoltsBU =xStartVolts
		variable/G root:Packages:twoP:Acquire:LSEndVolts = xEndVolts
		variable/G root:Packages:twoP:Acquire:LSEndVoltsBU= xEndVolts
		variable/G root:packages:twoP:Acquire:LSYVolts = 0
		variable/G root:Packages:twoP:Acquire:LSYVoltsBU = 0
		// Pixel width and height - set to constants defining full scale
		variable/G root:Packages:twoP:Acquire:PixWidth =SelectNumber (hasPrefs, kNQhPix, thePrefs.hPix)
		NVAR pixWidth =  root:Packages:twoP:Acquire:PixWidth
		variable/G root:Packages:twoP:Acquire:PixWidthBU =pixWidth	// Backup of the width in pixels of the image to be made
		variable/G root:Packages:twoP:Acquire:PixHeight =SelectNumber (hasPrefs, kNQvPix, thePrefs.vPix) // The number of lines in the image - the image height
		NVAR pixHeight = root:Packages:twoP:Acquire:PixHeight
		variable/G root:Packages:twoP:Acquire:PixHeightBU =pixHeight	// Backup of the number of lines in the image - the image height for reverting if wanted
		// Pix width and number of lines for a lineScan
		variable/G root:Packages:twoP:Acquire:LSWidth = pixWidth
		variable/G root:Packages:twoP:Acquire:LSHeight = pixHeight
		variable/G root:Packages:twoP:Acquire:LSWidthBU = pixWidth
		variable/G root:Packages:twoP:Acquire:LSHeightBU = pixHeight
		// Scan Timing Values
		variable/G root:Packages:twoP:Acquire:PixTime = SelectNumber (hasPrefs, kNQpixTime, thePrefs.pixTime)	// Width of each tick of the pixel clock, in ticks of the 20 MHz system clock
		variable/G root:Packages:twoP:Acquire:FlybackProp = SelectNumber (hasPrefs, kNQflybackProp, thePrefs.flybackProp)
		variable/G root:Packages:twoP:Acquire:DutyCycle = SelectNumber (hasPrefs, kNQDutyCycle, thePrefs.dutyCycle)
		variable/G root:packages:twoP:Acquire:ScanHeadDelay =SelectNumber (hasPrefs, kNQScanHeadDelay, thePrefs.scanDelay)
		variable/G root:packages:twoP:Acquire:minLiveFrameTime = SelectNumber (hasPrefs, kNQminLiveFrameTime, thePrefs.minLiveFrameTime)
		// We will set these other timing variables with a call to NQ_SetTimes
		variable/G root:packages:twoP:Acquire:PixTime
		variable/G root:packages:twoP:Acquire:PixWidthTotal // total number of pixel tickes to make a line, including flyback and turnaround
		variable/G root:Packages:twoP:Acquire:LineTime
		variable/G root:Packages:twoP:Acquire:FrameTime
		variable/G root:Packages:twoP:Acquire:RunTime  // The running time of the experiment, in seconds. INF if  live mode
		string/G root:Packages:twoP:Acquire:RunTimeStr // time in minutes and seconds calculated and then displayed on the acquire control panel
		// X and Y galvos calibrations for scanning with the objective selected  Objective scaling is in meters/volt
		variable iObj, nObjs
		nObjs = SelectNumber (hasPrefs, 1, thePrefs.nObjs)
		make/t/o/n = ((nObjs), 5)  root:packages:twoP:Acquire:ObjWave
		make/o/n = (nObjs, 5)  root:packages:twoP:Acquire:ObjWaveSel
		WAVE/t objWave = root:packages:twoP:Acquire:ObjWave
		WAVE objWaveSel =  root:packages:twoP:Acquire:ObjWaveSel
		objWaveSel = 6 // editable with a double click
		setdimlabel 1,0, Objective ObjWave // name of objective
		setdimlabel 1,1, X_Scal ObjWave	// X scaling, in meters/Volt
		setdimlabel 1,2, Y_Scal ObjWave 	// Y scaling, in meters/Volt
		setdimlabel 1,3, X_Offset ObjWave	// X relative offset, in meters, from center of image for this lens to center of image for first lens in the list of images
		setdimlabel 1,4, Y_Offset ObjWave	// Y relative offset, in meters, from center of image for this lens to center of image for first lens in the list of images
		if (hasPrefs)
			for (iObj = 0; iObj < nObjs; iObj +=1)
				objWave [iObj] [0] = thePrefs.objList [iObj].objName
				objWave [iObj] [1] = num2str (thePrefs.objList [iObj].xScal)
				objWave [iObj] [2] = num2str (thePrefs.objList [iObj].yScal)
				objWave [iObj] [3] = num2str (thePrefs.objList [iObj].xOffset)
				objWave [iObj] [4] = num2str (thePrefs.objList [iObj].yOffset)
			endfor
		else
			ObjWave [0] [0] = stringfromlist (0, kNQobjScal)
			ObjWave [0] [1] = stringfromlist (1, kNQobjScal)
			ObjWave [0] [2] = stringfromlist (2, kNQobjScal)
			ObjWave [0] [3] = stringfromlist (3, kNQobjScal)
			ObjWave [0] [4] = stringfromlist (4, kNQobjScal)
		endif
		string/G root:Packages:twoP:Acquire:curObj =ObjWave [0] [0]
		variable/G root:packages:twoP:Acquire:CurObjNum =0
		// Image channel specifications
		variable iChan, nChans
		nChans = SelectNumber (hasPrefs, 1, thePrefs.nImageChans)
		make/t/o/n = ((nChans), 7)  root:packages:twoP:Acquire:imChansList
		make/o/n = (nChans, 7)  root:packages:twoP:Acquire:imChansListSel
		WAVE/t chanList = root:packages:twoP:Acquire:imChansList
		WAVE chanListSel =  root:packages:twoP:Acquire:imChansListSel
		chanListSel = 6 // editable with a double click
		chanListSel [*] [2] = 0 // not editable -have to use popMenu for PDIFF,RSE, etc.
		SetDimlabel 1,0, chanName chanList
		SetDimlabel 1,1, ai_chan chanList
		SetDimlabel 1,2, Type chanList
		SetDimlabel 1,3, minV chanList
		SetDimlabel 1,4, maxV chanList
		SetDimlabel 1,5, scal chanList
		SetDimlabel 1,6, offset chanList
		if (hasPrefs)
			for (iChan = 0; iChan < nChans; iChan +=1)
				chanList [iChan] [0] = thePrefs.imageChans [iChan].chanName
				chanList [iChan] [1] = num2str (thePrefs.imageChans [iChan].aiChan)
				chanList [iChan] [2] = thePrefs.imageChans [iChan].aToDtype
				chanList [iChan] [3] = num2str ( thePrefs.imageChans [iChan].vMin)
				chanList [iChan] [4] = num2str ( thePrefs.imageChans [iChan].vMax)
				chanList [iChan] [5] = num2str ( thePrefs.imageChans [iChan].scaling)
				chanList [iChan] [6] = num2str ( thePrefs.imageChans [iChan].offset)
			endfor
		else
			chanList [0] [0,6] =  stringfromlist (q, kNQImChan, ";")
		endif
		// image scan default sizes
		Make/o/n= (2, 5)/T root:packages:twoP:acquire:ScanSizeDefaults
		Make/o/n= (2, 5) root:packages:twoP:acquire:ScanSizeDefaultsSel
		Wave/T ScanSizeDefaults =  root:packages:twoP:acquire:ScanSizeDefaults
		setdimlabel 1,0, Axis ScanSizeDefaults
		setDimLabel 1,1, PixelNum ScanSizeDefaults
		setdimlabel 1,2, startV ScanSizeDefaults
		setDimLabel 1,3, endV ScanSizeDefaults
		setDimLabel 1,4, Inversion ScanSizeDefaults
		ScanSizeDefaults [0] [0] = "X"
		ScanSizeDefaults [1] [0] = "Y"
		ScanSizeDefaults [0,1] [4] = "Invert"
		WAVE ScanSizeDefaultsSel =  root:packages:twoP:acquire:ScanSizeDefaultsSel
		ScanSizeDefaultsSel [0,1] [0] = 0
		ScanSizeDefaultsSel [0,1] [1,3] = 6
		ScanSizeDefaultsSel [0,1] [4] = 32
		ScanSizeDefaults [0] [1] = num2str (SelectNumber (hasPrefs, kNQxVoltStart, thePrefs.xVoltStart))
		ScanSizeDefaults [0] [2] = num2Str (SelectNumber (hasPrefs, kNQxVoltEnd, thePrefs.xVoltEnd))
		ScanSizeDefaults [0] [3] = num2Str (SelectNumber (hasPrefs, kNQhPix, thePrefs.hPix))
		ScanSizeDefaultsSel [0] [4] = ScanSizeDefaultsSel [0] [4] |  (8 * SelectNumber (hasPrefs, kNQxInvert, thePrefs.xInvert))
		ScanSizeDefaults [1] [1] = num2str (SelectNumber (hasPrefs, kNQyVoltStart, thePrefs.yVoltStart))
		ScanSizeDefaults [1] [2] = num2Str (SelectNumber (hasPrefs, kNQyVoltEnd, thePrefs.yVoltEnd))
		ScanSizeDefaults [0] [3] = num2Str (SelectNumber (hasPrefs, kNQvPix, thePrefs.vPix))
		ScanSizeDefaultsSel [1] [4] = ScanSizeDefaultsSel [0] [4] | (8 * SelectNumber (hasPrefs, kNQyInvert, thePrefs.xInvert))
		// Focus - make global string for focus procedure and initialize focus panel with correct procedure and port from constants
		String/G root:Packages:twoP:Acquire:StageProc =selectString (hasPrefs, kNQStageProc, thePrefs.stageProc)
		String/G root:Packages:twoP:Acquire:StagePort = selectString (hasPrefs, kNQFocusPort, thePrefs.stagePort)
		SVAR Stage = root:Packages:twoP:Acquire:StageProc
		SVAR focusPort =  root:Packages:twoP:Acquire:StagePort
		// add StageStartStage to execution queue
		if ((CmpStr (Stage, "") != 0) && (CmpStr (FocusPort, "") != 0))
			Execute/P/Q/Z "StageStartStage (\"" + Stage + "\", thePort = \"" + focusPort + "\")"
		endif
		// Shutter
		Variable/G root:Packages:twoP:Acquire:shutterOpen = SelectNumber (hasPrefs, kNQshutterOpen, thePrefs.shutterOpen)
		Variable/G root:Packages:twoP:Acquire:shutterDelay = SelectNumber (hasPrefs, kNQshutterOpen, thePrefs.shutterDelay)
		// ephys 
		string/G root:packages:twoP:acquire:ePhysBoard =SelectString (hasPrefs, kNQephysBoard, thePrefs.ePhysBoard)
		SVAR ephysBoard =  root:packages:twoP:acquire:ePhysBoard
		if ((CmpStr (ephysBoard, "") != 0) && (WhichListItem(ephysBoard, deviceList, ";", 0,0) == -1))
			sprintf AlertStr, "The specified ePhys board, \"%s\", is not present in the system.\r", imageBoard
			Doalert 0,AlertStr
		endif
		variable/G root:packages:twoP:acquire:ePhysSampFreq= SelectNumber (hasPrefs, kNQePhysSampFreq, thePrefs.ePhysSampFreq)
		nChans = SelectNumber (hasPrefs, 1, thePrefs.nEphysChans)
		make/t/o/n = ((nChans), 5)  root:packages:twoP:Acquire:ePhysChansList
		make/o/n = (nChans, 5)  root:packages:twoP:Acquire:ePhysChansListSel
		WAVE/t chanList = root:packages:twoP:Acquire:ePhysChansList
		WAVE chanListSel =  root:packages:twoP:Acquire:ePhysChansListSel
		chanListSel = 6 // editable with a double click
		chanListSel [*] [2] = 0 // not editable -have to use popMenu for PDIFF,RSE, etc.
		SetDimlabel 1,0, chanName chanList
		SetDimlabel 1,1, ai_chan chanList
		SetDimlabel 1,2, Type chanList
		SetDimlabel 1,3, minV chanList
		SetDimlabel 1,4, maxV chanList
		if (hasPrefs)
			for (iChan = 0; iChan < nChans; iChan +=1)
				chanList [iChan] [0] = thePrefs.ePhysChans [iChan].chanName
				chanList [iChan] [1] = num2str (thePrefs.ePhysChans [iChan].aiChan)
				chanList [iChan] [2] = thePrefs.ePhysChans [iChan].aToDtype
				chanList [iChan] [3] = num2str ( thePrefs.ePhysChans [iChan].vMin)
				chanList [iChan] [4] = num2str ( thePrefs.ePhysChans [iChan].vMax)
			endfor
		else
			chanList [0] [0,4] =  stringfromlist (q, kNQePhysChan, ";")
		endif
		// Triggers
		nChans = SelectNumber (hasPrefs, 1, thePrefs.nTriggers)
		make/o/t/n = (nChans, 7) root:packages:twoP:Acquire:trigggersList
		make/o/n = (nChans, 7) root:packages:twoP:Acquire:trigggersListSel
		WAVE trigList =  root:packages:twoP:Acquire:trigggersList
		WAVE trigListSel =  root:packages:twoP:Acquire:trigggersListSel
		SetDimLabel 1,0, trigName, trigList
		SetDimLabel 1,1, Board, trigList
		SetDimLabel 1,2, ctrNum, trigList
		SetDimLabel 1,3, outPutPin, trigList
		SetDimLabel 1,4, startSignal, triglist
		SetDimLabel 1,5, Polarity, trigList
		SetDimLabel 1,6, Durarion, trigList
		// Wave for background thread ids
		 make/n=2 root:packages:twoP:acquire:bkgThreadIDs
		if (hasPrefs)
			for (iChan = 0; iChan < nChans; iChan +=1)
			
			endfor
		endif
				NewDataFolder/o root:Packages:twoP:Acquire:VoltagePulseWaves

		

		
		
		
		
		
		
		// copy focus step size to acquire globals
		NVAR zStepSizeG = $"root:packages:" + kNQStageProc + ":" + "zStepSize"
		variable/G root:packages:twoP:acquire:zStepSizeMin = 1e-07
		
		SVAR StageProc = root:Packages:twoP:Acquire:StageProc
		//ScanMode
		variable/G root:packages:twoP:Acquire:ScanMode = kLiveMode // state of control panel
		variable/G root:packages:twoP:Acquire:ScanStartMode = kLiveMode // state of control panel when scan was started
		variable/G root:Packages:twoP:Acquire:FlyBackMode =0 // not using bi-directional scanning

		variable/G root:packages:twoP:Acquire:isCyclic = 0 // we need to set up a circular buffer scan because the # of points is greater than 2^24
		variable/G root:packages:twoP:acquire:tSeriesBufferSize = 0
		variable/G root:packages:twoP:Acquire:ePhysisCyclic = 0
		variable/G root:packages:twoP:acquire:lScanBufferSize = 0
		variable/G root:packages:twoP:acquire:ePhysBufferSize
		// Scan and ePhys Gains
		variable/G root:Packages:twoP:Acquire:ScanGain = kNQScanGain
		variable/G root:Packages:twoP:Acquire:ePhysGain = kNQePhysGain
		// Scan and ePhys channel Selection (in each case, 1 = chan 0, 2 =chan 1, 3=both channels. easily expanable for multiple channels
		variable/G root:Packages:twoP:Acquire:ScanChans =1
		// Errorhandler variable - 0 if user chose to continue following an error. 1 if user chose to halt execution
		variable/G root:packages:twoP:Acquire:ErrVar
		// New Scan Name and Note
		string/G root:Packages:twoP:Acquire:NewScanName = "Scan_000"		// name for new wave to be made by scanning operation
		variable/G root:Packages:twoP:Acquire:NewScanNum = 0
		string/G root:Packages:twoP:Acquire:NewScanNote = "You can enter a note for each scan here and it will be saved with the data."	// experiment note to be saved with each experiment
		// variable for overwrite warnCheck and auto increment check
		variable/G root:packages:twoP:acquire:overwriteWarnCheck = 1
		variable/G root:packages:twoP:acquire:AutIncCheck = 1
		variable/G root:packages:twoP:acquire:inputTriggerCheck = 0

		// variable for Shutter task
		variable/G root:packages:twoP:Acquire:shutterTaskNum = -1
		
		// Image Size and pixel size, in meters, for X and Y
		variable/G root:Packages:twoP:Acquire:xImSize
		variable/G root:Packages:twoP:Acquire:yImSize
		variable/G root:Packages:twoP:Acquire:xPixSize
		variable/G root:Packages:twoP:Acquire:yPixSize
		// set dependency formulas for the global variables for image and pixel size based on chosen objective's scaling
		NVAR xImSize=root:Packages:twoP:Acquire:xImSize
		NVAR yImSize = root:Packages:twoP:Acquire:yImSize
		NVAR xPixSize = root:Packages:twoP:Acquire:xPixSize
		NVAR yPixSize = root:Packages:twoP:Acquire:yPixSize
		setformula xImSize "abs(root:Packages:twoP:Acquire:xEndVolts - root:Packages:twoP:Acquire:xStartVolts) * str2num (root:packages:twoP:Acquire:ObjWave [root:packages:twoP:Acquire:curObjNum] [1])"
		setformula xPixSize "root:packages:twoP:Acquire:xImSize/root:Packages:twoP:Acquire:PixWidth"
		setformula yImSize "abs(root:Packages:twoP:Acquire:yEndVolts - root:Packages:twoP:Acquire:yStartVolts) * str2num (root:packages:twoP:Acquire:ObjWave [root:packages:twoP:Acquire:curObjNum] [2])"
		setformula yPixSize "root:packages:twoP:Acquire:yImSize/root:Packages:twoP:Acquire:PixHeight"
		// line scan X size and pixel size
		variable/G root:Packages:twoP:Acquire:LSImSize
		variable/G root:Packages:twoP:Acquire:LSPixSize
		// Set dependency formulas for LineScan pix size
		NVAR LSImSize = root:Packages:twoP:Acquire:LSImSize
		NVAR LSPixSize = root:Packages:twoP:Acquire:LSPixSize
		setformula LSImSize "abs(root:Packages:twoP:Acquire:LSEndVolts - root:Packages:twoP:Acquire:LSStartVolts) * str2num (root:packages:twoP:Acquire:ObjWave [root:packages:twoP:Acquire:curObjNum] [1])"
		setformula LSPixSize "root:packages:twoP:Acquire:LSImSize/root:Packages:twoP:Acquire:LSWidth"
		// Aspect ratio of image (horizontal pixel size/vertical pixel size) backwards to most definitions, I now realize. Also, doesn't take into account possibility of diiferent votage scaling for X and Y
		variable/G root:Packages:twoP:Acquire:AspectRatio = 1
		// globals for frame/line numbers for acquisition/averaging
		// Live
		string/G root:packages:twoP:Acquire:LiveModeScanStr
		variable/G root:packages:twoP:acquire:nLiveFrames =1 // more than one frame acquired at once if frame time is too short, compared to constant at top of file
		variable/G root:Packages:twoP:Acquire:LiveAvgCheck = 0
		variable/G root:Packages:twoP:Acquire:numLiveAvgFrames = 3
		variable/G root:packages:twoP:Acquire:LiveAvgPos
		variable/G root:Packages:twoP:Acquire:liveROISecs = 30
		variable/G root:Packages:twoP:Acquire:liveHistCheck
		variable/G root:Packages:twoP:Acquire:liveROICheck = 0
		variable/G root:Packages:twoP:Acquire:liveROIRatioCheck = 0
		make/o/N= 0 root:Packages:twoP:Acquire:LroiWave_ch1	// some waves for doing Live ROIs
		make/o/N= 0 root:Packages:twoP:Acquire:LroiWave_ch2
		make/o/N= 0 root:Packages:twoP:Acquire:LroiWave_ratio
		make/o/N=0 root:packages:twoP:acquire:LroiXwave
		// left, Top, width, height coordinates for the Live ROI
		variable/g root:Packages:twoP:Acquire:LROIL, root:Packages:twoP:Acquire:LROIT
		variable/g root:Packages:twoP:Acquire:LROIB, root:Packages:twoP:Acquire:LROIR
		// Time series
		variable/G root:Packages:twoP:Acquire:TSeriesFrames = 50
		variable/G root:Packages:twoP:Acquire:ePhysAdjChans =0 // value for ephys chans to use when doing ePhys along with image scanning
		variable/G root:Packages:twoP:Acquire:scanToDisk =0
		string/G root:Packages:twoP:Acquire:scanToDiskDir = ""
		variable/G root:Packages:twoP:Acquire:scanToDiskFileRefNum
		variable/G root:Packages:twoP:Acquire:ePhysToDiskFileRefNum
		// Average
		variable/G root:Packages:twoP:Acquire:numAverageFrames = 5
		// Line Scan
		variable/G root:Packages:twoP:Acquire:LSStartVoltage = kNQxVoltStart
		variable/G root:Packages:twoP:Acquire:LSEndVoltage = kNQxVoltEnd	
		variable/G root:Packages:twoP:Acquire:LSYVoltage	= 0
		variable/G root:Packages:twoP:Acquire:LSStartVoltageBU = kNQxVoltStart
		variable/G root:Packages:twoP:Acquire:LSEndVoltageBU=kNQxVoltEnd
		variable/G root:Packages:twoP:Acquire:LSYVoltageBU = 0	
		string/G root:Packages:twoP:Acquire:LSLinkWaveStr = "Don't Link" 	// Line Scan "link to wave" string
		// Z stack
		variable/G root:packages:twoP:acquire:zStepSize=1e-06
		variable/G root:Packages:twoP:Acquire:NumZseriesFrames = 10		// Stores Number of frames to collect in the Z dimension for Z Series Exp.
		variable/G root:Packages:twoP:Acquire:NumZseriesAvg = 3			// Number of frames to average for each z-position, i.e, Kalman averaging
		variable/g root:Packages:twoP:Acquire:ZFirstZ =0
		variable/g root:Packages:twoP:Acquire:ZLastZ =10e-6
		variable/g root:Packages:twoP:Acquire:iiZseriesFrames// a global variable for counting z-series frames
		// ePhys
		variable/G root:Packages:twoP:Acquire:ePhysOnlyTime = 30
		variable/G root:Packages:twoP:Acquire:EphysFreq = kNQePhysSampFreq	 // the scanning frequency in Hz for the ePhys trace
		variable/G root:Packages:twoP:Acquire:ePhysChans =1
		// multiAq
		variable/G root:packages:twoP:acquire:multiAqTimeMode =0
		variable/G root:packages:twoP:acquire:multiAqPeriodNum = 10
		string/G root:packages:twoP:acquire:multiAqPeriodPeriodStr = "0:20"
		string/G root:packages:twoP:acquire:multiAqPeriodDelayStr = "0:00"
		variable/G root:packages:twoP:acquire:multiAqPeriodPeriod=20 // 5 * 60
		variable/G root:packages:twoP:acquire:multiAqPeriodDelay= 0 // 30 * 60
		string/G root:packages:twoP:acquire:multiAqTimeToNextStr=""
		variable/G root:packages:twoP:acquire:multiAqTimeToNext=20
		variable/G root:packages:twoP:acquire:multiAqiAq =0
		variable/G root:packages:twoP:acquire:multiAqnAqs =0
		string/G root:packages:twoP:Acquire:multiAqWaveWaveStr = ""
		NewDataFolder/o root:packages:twoP:acquire:multiAqWaves
		variable/G root:packages:twoP:acquire:multiAqTriggerNum = 10
		// Trigger Timing Values
		variable/G root:packages:twoP:Acquire:trig1Check = 0
		variable/G root:packages:twoP:Acquire:trig2Check = 0
		variable/G root:Packages:twoP:Acquire:DelayFrames1 =0 // When doing a time series, the number of frames to delay before sending trigger stimulus on the ephysBoard counter 0 output pin.
		variable/G root:Packages:twoP:Acquire:DelayFrames2 = 0 // When doing a time series, the number of frames to delay before sending  trigger stimulus on the ephysBoard counter 1 output pin.
		variable/G root:Packages:twoP:Acquire:DelayFramesSec1 =0 // DelayFrames1 translated into seconds
		variable/G root:Packages:twoP:Acquire:DelayFramesSec2 =0 // DelayFrames2 translated into seconds
		variable/G root:Packages:twoP:Acquire:DelayLines1 =0	// When doing a LineScan, the number of lines to delay before sending  trigger stimulus on the ephysBoard counter 0 output pin.
		variable/G root:Packages:twoP:Acquire:DelayLines2 = 0 // When doing a LineScan, the number of lines to delay before sending  trigger stimulus on the ephysBoard counter 1 output pin.
		variable/G root:Packages:twoP:Acquire:DelayLinesSec1 = 0 // DelayLines1 translated into seconds
		variable/G root:Packages:twoP:Acquire:DelayLinesSec2 = 0 // DelayLines2 translated into seconds
		variable/G root:Packages:twoP:Acquire:DelaySecs1 =0	// When doing ePhys Only, the number of seconds to delay before sending  trigger stimulus on the ephysBoard counter 0 output pin.
		variable/G root:Packages:twoP:Acquire:DelaySecs2 = 0 // When doing ePhys Only, the number of seconds to delay before sending  trigger stimulus on the ephysBoard counter 1 output pin.
		//VoltagePulse Stuff
		variable/G root:packages:twoP:Acquire:voltagePulseChans = 0
		variable/G root:packages:twoP:acquire:VoltagePulseFreq = 10
		variable/G root:packages:twoP:acquire:VoltagePulseHeight = 1
		variable/G root:packages:twoP:acquire:VoltagePulseX1 = 0
		variable/G root:packages:twoP:acquire:VoltagePulseX2 = 5
		variable/G root:packages:twoP:acquire:VoltagePulseY1 = 0
		variable/G root:packages:twoP:acquire:VoltagePulseY2 = 0
		string/G root:packages:twoP:acquire:VoltagePulseEditWave = ""
		variable/G root:packages:twoP:acquire:VoltageAxis = 0
		variable/G root:packages:twoP:acquire:VoltagelastCursor
		variable/G root:packages:twoP:Acquire:VoltagePulseF1 =0
		variable/G root:packages:twoP:Acquire:VoltagePulseF2 =1
		make/o/n= 2 root:packages:twoP:Acquire:VoltagePulseDummyWave
		// Exporting data after scan
		variable/G root:packages:twoP:acquire:exportAfterScan =0
		// Percent complete variable for scanning
		variable/G root:packages:twoP:Acquire:PercentComplete
		// Waves for fitting the sin expansion used in outputting the Galvo Signals
		make/o/D root:packages:twoP:acquire:Scan_Coefs = {-7.4, -.65, -.13, -0.015}
		make/o/D root:packages:twoP:acquire:Scan_Coefs_Sym = {-7.4, -0.65, -0.13, 0.08, 0.17}
		// Get experiment size
		variable/G root:packages:twoP:acquire:expSize = NQ_GetExpSize ("root:")
		
		
		NQ_ResetBoards (0)
	endif
	return 0
end

//******************************************************************************************************
// Adds controls for the acquire functions to the Nidaq Controls panel
// Last Modified 2015/04/16 by Jamie Boyd
Function NQ_AddAcquireControls ()
	
	// Experiment size
	ValDisplay expSizeDisp, win = twoP_Controls, disable =1, pos={4,23},size={334,14},title="Exp size",fSize=10
	ValDisplay expSizeDisp, win = twoP_Controls, format="%.2W1PB",frame=2
	ValDisplay expSizeDisp, win = twoP_Controls, limits={0,1e+09,0},barmisc={0,62},highColor= (0,0,0),lowColor= (0,0,0)
	ValDisplay expSizeDisp, win = twoP_Controls, value= #"root:packages:twoP:acquire:expSize"
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "ValDisplay expSizeDisp 0;")
	// Image Size controls
	// group box
	GroupBox ImageSizeGrpBox win = twoP_Controls, disable =1, pos={3,39},size={336,124},title="Image Size",frame=0
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "GroupBox ImageSizeGrpBox 0;")
	// X pix and volts
	SetVariable PixWidSetVar win = twoP_Controls, disable =1, pos={8,55},size={94,15},proc=NQ_SetTimesProc,title="X pix",fSize=10
	SetVariable PixWidSetVar win = twoP_Controls, limits={2,INF,2},value= root:Packages:twoP:Acquire:PixWidth
	SetVariable XStartSetVar win = twoP_Controls, disable =1 ,pos={117,55},size={105,15},proc=GUIPSIsetVarProc,title="X Start"
	SetVariable XStartSetVar win = twoP_Controls,userdata=  "NQ_SetTimesProc;-10;10;autoInc;;",fSize=10, format="%.3W1PV"
	SetVariable XStartSetVar win = twoP_Controls,limits={-INF,INF,0.1},value= root:Packages:twoP:Acquire:xStartVolts
	SetVariable XEndSetVar win = twoP_Controls, disable =1, pos={233,55},size={99,15},proc=GUIPSIsetVarProc,title="X End"
	SetVariable XEndSetVar win = twoP_Controls,userdata= "NQ_SetTimesProc;-10;10;autoInc;;",fSize=10,format="%.3W1PV"
	SetVariable XEndSetVar win = twoP_Controls,limits={-INF,INF,0.1},value= root:Packages:twoP:Acquire:xEndVolts
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Setvariable PixWidSetVar 0;SetVariable XStartSetVar 0;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "SetVariable XEndSetVar 0;")
	// Y Pix and volts
	SetVariable YStartSetVar win = twoP_Controls, disable =1, pos={117,74},size={105,15},proc=GUIPSIsetVarProc,title="Y Start"
	SetVariable YStartSetVar, win = twoP_Controls,userdata=  "NQ_SetTimesProc;-10;10;autoInc;;",fSize=10,format="%.3W1PV"
	SetVariable YStartSetVar win = twoP_Controls,limits={-INF,INF,0.1},value= root:Packages:twoP:Acquire:yStartVolts
	SetVariable YEndSetVar win = twoP_Controls, disable =1, pos={234,74},size={98,15},proc=GUIPSIsetVarProc,title="Y End"
	SetVariable YEndSetVar win = twoP_Controls,userdata=  "NQ_SetTimesProc;-10;10;aoutoInc;;",fSize=10,format="%.3W1PV"
	SetVariable YEndSetVar win = twoP_Controls,limits={-INF,INF,0.1},value= root:Packages:twoP:Acquire:yEndVolts
	SetVariable PixHeightSetVar win = twoP_Controls, disable =1, pos={8,74},size={94,15},proc=NQ_SetTimesProc,title="Y Pix", fSize=10
	SetVariable PixHeightSetVar win = twoP_Controls,limits={2,inf,2},value= root:Packages:twoP:Acquire:PixHeight
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Setvariable PixHeightSetVar 0;Setvariable YStartSetVar 0;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Setvariable YEndSetVar 0;")
	// X and Y pix size Display
	SetVariable xImSizeSetVar win = twoP_Controls, disable =1, pos={4,94},size={79,18},title=" ",fSize=12, format="X %.1W1Pm",frame=0
	SetVariable xImSizeSetVar win = twoP_Controls,limits={0,inf,0},value= root:Packages:twoP:Acquire:xImSize,noedit= 1
	SetVariable xPixSizeSetVar win = twoP_Controls, disable =1, pos={80,94},size={90,18},title=" ",fSize=12
	SetVariable xPixSizeSetVar win = twoP_Controls,format="%.1W1Pm/pix",frame=0
	SetVariable xPixSizeSetVar win = twoP_Controls,limits={0,inf,0},value= root:Packages:twoP:Acquire:xPixSize,noedit= 1
	SetVariable YimSizeSetVar win = twoP_Controls, disable =1, pos={168,94},size={79,18},title=" ",fSize=12
	SetVariable YimSizeSetVar win = twoP_Controls,format="Y %.1W1Pm",frame=0
	SetVariable YimSizeSetVar win = twoP_Controls,limits={0,inf,0},value= root:Packages:twoP:Acquire:yImSize,noedit= 1
	SetVariable yPixSizeSetVar win = twoP_Controls, disable =1, pos={245,94},size={89,18},title=" ",fSize=12
	SetVariable yPixSizeSetVar win = twoP_Controls,format="%.1W1Pm/pix",frame=0
	SetVariable yPixSizeSetVar win = twoP_Controls,limits={0,inf,0},value= root:Packages:twoP:Acquire:yPixSize,noedit= 1
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "SetVariable xImSizeSetVar 0;SetVariable xPixSizeSetVar 0;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "SetVariable YimSizeSetVar 0;SetVariable yPixSizeSetVar 0;")
	// Full scale and revert scale
	Button FullScaleButton win = twoP_Controls, disable =1, pos={6,115},size={31,16},proc=NQ_SetFullScaleProc,title="Full"
	Button RevertScaleButton win = twoP_Controls, disable =1, pos={39,115},size={50,16},proc=NQ_RevertScaleProc,title="Revert"
	PopupMenu RevertScalePopMenu win = twoP_Controls, disable =1, pos={91,113},size={76,20},proc=RevertSettingstoWaveProc,title="to Scan:"
	PopupMenu RevertScalePopMenu win = twoP_Controls,mode=0,value= #"\"LiveWave;\\\\M1(-;\" + NQ_ListScans (\"1,2,4,\")"
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Button FullScaleButton 0;Button RevertScaleButton 0;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Popupmenu RevertScalePopMenu 0;")
	// Aspect Ratio
	SetVariable AspRatSetVar win = twoP_Controls, disable =1, pos={5,140},size={104,18},proc=NQ_AspectRatioProc,title="Aspect"
	SetVariable AspRatSetVar win = twoP_Controls,fSize=12,format="%#.3G"
	SetVariable AspRatSetVar, win = twoP_Controls, limits={0,inf,0.1},value= root:Packages:twoP:Acquire:AspectRatio
	PopupMenu AspRatPopUp win = twoP_Controls, disable =1, pos={113,139},size={88,20},proc=NQ_AspRatPopUpProc,fSize=12
	PopupMenu AspRatPopUp win = twoP_Controls,mode=6,popvalue="Vary Y Pix",value= #"\"Vary X Start;Vary X  End;Vary X Pix;Vary Y Start;Vary Y End;Vary Y Pix;Free\""
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "SetVariable AspRatSetVar 0;PopupMenu AspRatPopUp 0;")
	// Objectives and channels
	PopupMenu ObjPopUp win = twoP_Controls, disable =1, pos={224,113},size={50,20},proc=NQ_ObjPopProc,title="Obj:"
	PopupMenu ObjPopUp win = twoP_Controls,mode=0,value= #"NQ_ListObjs()"
	TitleBox CurObjTitle win = twoP_Controls, disable =1, pos={279,116},size={23,15},fSize=12,frame=0
	TitleBox CurObjTitle win = twoP_Controls,variable= root:Packages:twoP:Acquire:CurObj
	PopupMenu SelectPMTPopMenu win = twoP_Controls, disable =1, pos={223,139},size={66,20},proc=NQ_ScanChansPopMenuProc,title="Chan",fSize=12
	PopupMenu SelectPMTPopMenu win = twoP_Controls, disable =1, mode=3,popvalue="1",value= #"\"1;2;1 & 2\""
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "PopupMenu ObjPopUp 0;TitleBox CurObjTitle 0;PopupMenu SelectPMTPopMenu 0;")
	// Image appearance and scanMode tabControl
	// Commands to make these controls appear in twoP_examine, as controls are shown on both tabs
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "PopUpMenu LUTpopUp 0;CheckBox LUTInvertCheck 0;Checkbox LUTChan1Check 0;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Checkbox LUTChan2Check 0;Setvariable LUTFirstValueSetVar 0;Checkbox LUTautoCheck 0;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Setvariable LUTLastValueSetVar 0;Button LUTtoDataButton 0;Checkbox LUT96check 0;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Slider LUTLastValSlider 0;Slider LUTFirstValSlider 0;Titlebox LUTBeforeFirstTitle 0;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Popupmenu LUTBeforeColorPopUp 0;Checkbox LUTBeforeUseFirstCheck 0;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Checkbox LUTBeforeUseColorCheck 0;Checkbox LUTBeforeUseTransCheck 0;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Titlebox LUTAfterLastTitle 0;Checkbox LUTAfterUseLastCheck 0;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Checkbox LUTAfterUseColorCheck 0;Popupmenu LUTAfterColorPopUp 0;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Checkbox LUTAfterUseTransCheck 0;")
	// ScanMode tab Control (controls that are on the tabcontrol are listed below) 
	TabControl SmodeTabControl win = twoP_Controls, disable =1, pos={3,294},size={337,149},proc=GUIPTabProc
	TabControl SmodeTabControl win = twoP_Controls,help={"Selects one of 6 possible type of scans to perform."}
	TabControl SmodeTabControl win = twoP_Controls,fSize=9,tabLabel(0)="Live",tabLabel(1)="T_Ser"
	TabControl SmodeTabControl win = twoP_Controls,tabLabel(2)="Avg",tabLabel(3)="Lines"
	TabControl SmodeTabControl win = twoP_Controls,tabLabel(4)="Z_ser",tabLabel(5)="ePhys"
	TabControl SmodeTabControl win = twoP_Controls,tabLabel(6)="MultiAq",value= 0
	GUIPTabNewTabCtrl ("twoP_Controls", "SmodeTabControl", TabList= "Live;T_Ser;Avg;Lines;Z_ser;ePhys;MultiAq;", UserFunc="NQ_SModeTabControlproc")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "TabControl SmodeTabControl 0;")
	// Voltage pulse
	GroupBox VoltageWaveGrpBox win = twoP_Controls, disable =1, pos={3,444},size={337,84},title="Voltage Pulse"
	CheckBox Voltage1Check win = twoP_Controls, disable =1, pos={10,461},size={16,14},proc=NQ_VoltageCheckProc,title="", value= 0
	PopupMenu VoltagePulse1Popup win = twoP_Controls, disable =1, pos={26,458},size={249,20},proc=NQ_VoltageWavePopMenuProc,title="1 Voltage Wave"
	PopupMenu VoltagePulse1Popup win = twoP_Controls,mode=1,popvalue="No Voltage Pulse Waves",value= #"GUIPListObjs ((\"root:packages:twoP:acquire:VoltagePulseWaves\") , 1, \"*\", 0, \"\\M1(No Voltage Pulse Waves\")"
	CheckBox Voltage2Check win = twoP_Controls, disable =1, pos={9,482},size={16,14},proc=NQ_VoltageCheckProc,title="",value= 0
	PopupMenu VoltagePulse2Popup  win = twoP_Controls, disable =1, pos={26,479},size={249,20},proc=NQ_VoltageWavePopMenuProc,title="2 Voltage Wave"
	PopupMenu VoltagePulse2Popup win = twoP_Controls, mode=1,popvalue="No Voltage Pulse Waves",value= #"GUIPListObjs ((\"root:packages:twoP:acquire:VoltagePulseWaves\") , 1, \"*\", 0, \"\\M1(No Voltage Pulse Waves\")"
	PopupMenu VoltagePulsePopUp win = twoP_Controls, disable =1, pos={10,501},size={109,20},title="Vout",fSize=12
	PopupMenu VoltagePulsePopUp win = twoP_Controls, mode=1,popvalue="on Start",value= #"\"on Start;on Trig 1;\""
	Button EditVoltagePulseButton win = twoP_Controls, disable =1, pos={141,504},size={141,20},proc=EditVoltageWavesProc,title="Edit Voltage Waves"
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Groupbox VoltageWaveGrpBox 0;Checkbox Voltage1Check 0;Popupmenu VoltagePulse1Popup 0;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Checkbox Voltage2Check 0;Popupmenu VoltagePulse2Popup 0;Popupmenu VoltagePulsePopUp 0;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Button EditVoltagePulseButton 0;")
	// Times
	GroupBox TimesGrpBox  win = twoP_Controls, disable =1, pos={3,525},size={337,60},title="Times",fSize=9
	SetVariable expTimeSetvar  win = twoP_Controls, disable =1, pos={8,543},size={137,15},title="Total",fSize=10
	SetVariable expTimeSetvar  win = twoP_Controls, value= root:Packages:twoP:Acquire:RunTimeStr,noedit= 1
	SetVariable FrameTimeSetVar  win = twoP_Controls, disable =1, pos={178,543},size={131,15},title="Frame",fSize=10
	SetVariable FrameTimeSetVar  win = twoP_Controls,format="%.1W1Ps"
	SetVariable FrameTimeSetVar  win = twoP_Controls,limits={-inf,inf,0},value= root:Packages:twoP:Acquire:FrameTime,noedit= 1
	SetVariable LineTimeSetVar  win = twoP_Controls, disable =1, pos={11,562},size={134,15},title="Line",fSize=10
	SetVariable LineTimeSetVar  win = twoP_Controls,format="%.2W1Ps"
	SetVariable LineTimeSetVar  win = twoP_Controls,limits={-inf,inf,0},value= root:Packages:twoP:Acquire:LineTime,noedit= 1
	CheckBox TurboCheck win = twoP_Controls, disable =1, pos={175,558},size={138,35},proc=NQ_TurboCheckProc,title="Bi-Directional Scan is OFF"
	CheckBox TurboCheck win = twoP_Controls,help={"If On, data is collected on both directions of horizontal scan. If alternate lines of image are misaligned using Turbo, adjust  Scan Head Delay."}
	CheckBox TurboCheck win = twoP_Controls,variable= root:Packages:twoP:Acquire:FlyBackMode,picture= ProcGlobal#lightSwitch_small
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Groupbox TimesGrpBox 0;Setvariable expTimeSetvar 0;Setvariable FrameTimeSetVar 0;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Setvariable LineTimeSetVar 0;Checkbox TurboCheck 0;")
	// buttons to show other panels
	Button aqShowScansButton win = twoP_Controls, disable =1, pos={4,591},size={49,18},proc=NQ_ShowScansProc,title="Scans"
	Button aqShowTracesButton win = twoP_Controls, disable =1, pos={70,591},size={57,18},proc=NQ_showTracesProc,title="Traces"
	Button ShowScanSettingsButton win = twoP_Controls, disable =1, pos={139,591},size={98,18},proc=NQ_OtherScanSettingsProc,title="More Settings"
	Button showFocusPanelButton win = twoP_Controls, disable =1, pos={254,591},size={57,18},proc=NQ_OpenFocusPanel,title="Focus"
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire",  "Button aqShowScansButton 0;Button aqShowTracesButton 0;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Button ShowScanSettingsButton 0;Button ShowFocusPanelButton 0")
	// Scan Name and Note
	GroupBox ScanSettingsGrp win = twoP_Controls, disable =1, pos={3,612},size={337,48},title="Scan Name & Note Settings" ,frame=0
	SetVariable AqScanNameSetVar win = twoP_Controls, disable =1, pos={7,625},size={186,15},proc=NQ_ScanNameProc,title="New Scan Name"
	SetVariable AqScanNameSetVar win = twoP_Controls,help={"The scan created when you press \"Start Scan\" will have this name."}
	SetVariable AqScanNameSetVar win = twoP_Controls,value= root:Packages:twoP:Acquire:NewScanName
	CheckBox AqAutIncCheck win = twoP_Controls, disable =1, pos={217,625},size={52,14},proc=NQ_autincCheckProc,title="AutoInc"
	CheckBox AqAutIncCheck win = twoP_Controls,help={"If checked, \"New Scan Name\" is given a numeric suffix and automatically incremented with every scan."}
	CheckBox AqAutIncCheck win = twoP_Controls,variable= root:Packages:twoP:Acquire:AutincCheck
	CheckBox AqOverWriteWarnCheck win = twoP_Controls, disable =1, pos={287,625},size={41,14},title="Warn"
	CheckBox AqOverWriteWarnCheck win = twoP_Controls,help={"If checked, you will be warned if \"New Scan Name\" conflicts with an existing scan."}
	CheckBox AqOverWriteWarnCheck win = twoP_Controls,variable= root:Packages:twoP:Acquire:overwriteWarnCheck
	SetVariable ExpNoteSetVar win = twoP_Controls, disable =1, pos={7,643},size={328,15},proc=NQ_ExpNoteProc,title="Scan Note"
	SetVariable ExpNoteSetVar win = twoP_Controls,value= root:Packages:twoP:Acquire:NewScanNote
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Groupbox ScanSettingsGrp 0;Setvariable aqScanNameSetVar 0;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Checkbox AqAutIncCheck 0;Checkbox AqOverWriteWarnCheck 0;Setvariable ExpNoteSetVar 0;")
	// Start and scan end controls
	PopupMenu AqExportAtScanEndPop win = twoP_Controls, disable =1, pos={7,661},size={151,20},proc=NQ_ExportAfterScanPopProc,title="At Scan end"
	PopupMenu AqExportAtScanEndPop win = twoP_Controls, mode=1,popvalue="Do Nothing",value= #"\"Do Nothing;Save Experiment;Export Scan;Export and Delete Scan;Export and Delete Last Scan;\""
	ValDisplay AqPercentCompleteDisplay win = twoP_Controls, disable =1, pos={4,683},size={227,25},fSize=12,frame=0
	ValDisplay AqPercentCompleteDisplay win = twoP_Controls,  limits={0,100,0},barmisc={0,0},mode= 3
	ValDisplay AqPercentCompleteDisplay win = twoP_Controls,value= #"root:packages:twoP:Acquire:PercentComplete"
	CheckBox AqInPutTrigCheck win = twoP_Controls, disable =1, pos={232,682},size={50,24},title="Input\rtrigger"
	CheckBox AqInPutTrigCheck win = twoP_Controls,variable= root:Packages:twoP:Acquire:inputTriggerCheck
	Button AqStartButton win = twoP_Controls, disable =1, pos={287,684},size={51,24},proc=NQ_StartScan,title="Start "
	Button AqStartButton win = twoP_Controls,help={"Starts or Aborts a Scan."},userdata=  "Start"
	Button AqStartButton win = twoP_Controls,fSize=16,fStyle=1,fColor=(0,65535,0)
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Popupmenu AqExportAtScanEndPop 0;Valdisplay AqPercentCompleteDisplay 0;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Checkbox AqInPutTrigCheck 0;Button AqStartButton 0;")
	// Controls on ScanMode TabControl
	// Live Tab
	CheckBox LiveAvgCheck win = twoP_Controls, disable =1, pos={7,334},size={95,14},title="Average Frames"
	CheckBox LiveAvgCheck win = twoP_Controls,help={"if checked, the selected number of frames will be averaged during live scanning."}, fSize=10
	CheckBox LiveAvgCheck win = twoP_Controls,variable= root:Packages:twoP:Acquire:LiveAvgCheck
	SetVariable NumLiveAvgFramesSetVar win =  twoP_Controls, disable =1,pos={110,332},size={43,18},title=" "
	SetVariable NumLiveAvgFramesSetVar win = twoP_Controls,fSize=12
	SetVariable NumLiveAvgFramesSetVar win = twoP_Controls,limits={0,inf,1},value= root:Packages:twoP:Acquire:numLiveAvgFrames
	CheckBox LiveROICheck win = twoP_Controls, disable =1 ,pos={6,356},size={59,14},title="Live ROI",fSize=10
	CheckBox LiveROICheck win = twoP_Controls,variable= root:Packages:twoP:Acquire:liveROICheck
	CheckBox LroiCheckRatio win = twoP_Controls, disable =1, pos={71,356},size={16,14},title="",fSize=12
	CheckBox LroiCheckRatio win = twoP_Controls,variable= root:Packages:twoP:Acquire:liveROIRatioCheck
	PopupMenu LROIRatPopUp win = twoP_Controls, disable =1, pos={88,353},size={105,20},proc=NQ_DROIPopMenuProc,title="Ratio"
	PopupMenu LROIRatPopUp win = twoP_Controls,fSize=10
	PopupMenu LROIRatPopUp win = twoP_Controls,mode=1,popvalue="Ch1/Ch2",value= #"\"Ch1/Ch2;Ch2/Ch1\""
	SetVariable LiveRoiTimeSetVar win = twoP_Controls, disable=1, pos={199,356},size={64,16},proc=GUIPSIsetVarProc,title=" "
	SetVariable LiveRoiTimeSetVar win = twoP_Controls,help={"If doing Live ROIs, this many seconds will be shown in the scrolling graph below."}
	SetVariable LiveRoiTimeSetVar win = twoP_Controls,userdata=  ";0;30;;",fSize=10,format="%.0W1PSec"
	SetVariable LiveRoiTimeSetVar win = twoP_Controls,limits={0,inf,1},value= root:Packages:twoP:Acquire:liveROISecs
	CheckBox LiveHistCheck win = twoP_Controls, disable =1, pos={6,378},size={92,14},proc=NQ_LiveHistCheckProc,title="Live Histogram",fSize=10
	CheckBox LiveHistCheck win = twoP_Controls,variable= root:Packages:twoP:Acquire:liveHistCheck
	CheckBox FramesTrig1CheckLive win = twoP_Controls, disable =1, pos={6,401},size={16,14},title="",fSize=10, value= 0
	SetVariable FramesTrig1SetVar win = twoP_Controls, disable =1, pos={24,401},size={128,15},proc=NQ_SetTimesProc,title="Trig1 on Frame"
	SetVariable FramesTrig1SetVar win = twoP_Controls,userdata=  "NQ_TrigSecsFrameProc",fSize=10
	SetVariable FramesTrig1SetVar win = twoP_Controls,limits={0,inf,1},value= root:Packages:twoP:Acquire:DelayFrames1
	SetVariable FramesTrig1SecsSetvar win = twoP_Controls, disable =1, pos={156,401},size={65,15},proc=GUIPSIsetVarProc,title=" "
	SetVariable FramesTrig1SecsSetvar win = twoP_Controls,userdata=  "NQ_TrigSecsProc;",fSize=10,format="%.2W0Ps"
	SetVariable FramesTrig1SecsSetvar win = twoP_Controls, limits={0,inf,0},value= root:Packages:twoP:Acquire:DelayFramesSec1
	CheckBox FramesTrig2CheckLive win = twoP_Controls, disable =1, pos={6,420},size={16,14},title="",fSize=10, value= 0
	SetVariable FramesTrig2SetVar win = twoP_Controls, disable =1, pos={24,420},size={128,15},proc=NQ_SetTimesProc,title="Trig2 on Frame"
	SetVariable FramesTrig2SetVar win = twoP_Controls,userdata=  "NQ_TrigSecsFrameProc",fSize=10
	SetVariable FramesTrig2SetVar win = twoP_Controls,limits={0,inf,1},value= root:Packages:twoP:Acquire:DelayFrames2
	SetVariable FramesTrig2SecsSetvar win = twoP_Controls, disable =1, pos={156,420},size={65,15},proc=GUIPSIsetVarProc,title=" "
	SetVariable FramesTrig2SecsSetvar win = twoP_Controls,userdata=  "NQ_TrigSecsProc",fSize=10
	SetVariable FramesTrig2SecsSetvar win = twoP_Controls,format="%.2W0Ps"
	SetVariable FramesTrig2SecsSetvar win = twoP_Controls,limits={0,inf,0},value= root:Packages:twoP:Acquire:DelayFramesSec2
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Live", "Checkbox LiveAvgCheck 0;Setvariable NumLiveAvgFramesSetVar 0;Checkbox LiveROICheck 0;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Live", "Setvariable LiveRoiTimeSetVar 0;Checkbox LroiCheckRatio 0;Popupmenu LROIRatPopUp 0;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Live", "Checkbox LiveHistCheck 0;Checkbox FramesTrig1CheckLive 0;Setvariable FramesTrig1SetVar 0")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Live", "Setvariable FramesTrig1SecsSetvar 0;Checkbox FramesTrig2CheckLive 0;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Live", "Setvariable FramesTrig2SetVar 0;Setvariable FramesTrig2SecsSetvar 0;")
	//  Time Series 
	// num frames
	SetVariable NumTSeriesFramesSetVar, win = twoP_Controls, disable=1, pos={6,334},size={184,18},proc=NQ_SetTimesProc,title="Time Series Frames", disable =1
	SetVariable NumTSeriesFramesSetVar, win = twoP_Controls, fSize=10,limits={0,inf,1},value=root:packages:twoP:Acquire:TSeriesFrames
	// Scan to disk (not ready for prime-time just yet)
//	CheckBox FIFOcheck win = twoP_Controls, disable=1,pos={195,335},size={79,14},title="Scan to Disk"
//	CheckBox FIFOcheck win = twoP_Controls, variable= root:packages:twoP:Acquire:scanToDisk,proc=NQ_ScanToDiskCheckProc
//	SetVariable FIFODirSetvar win = twoP_Controls, disable=1,pos={194,353},size={143,16},title="Directory", proc=NQ_FifoDirSetVarProc
//	SetVariable FIFODirSetvar win = twoP_Controls,value= root:Packages:twoP:Acquire:scanToDiskDir
	// trig 1
	CheckBox FramesTrig1Check, win = twoP_Controls, disable =1, pos={6,401},size={16,14},title="",fSize=10,value= 0
	SetVariable FramesTrig1SetVar, win = twoP_Controls, disable =1,pos={24,401},size={128,16},proc=NQ_SetTimesProc,title="Trig1 on Frame"
	SetVariable FramesTrig1SetVar, win = twoP_Controls, userdata=  "NQ_TrigSecsFrameProc",fSize=10
	SetVariable FramesTrig1SetVar, win = twoP_Controls, limits={0,inf,1},value= root:Packages:twoP:Acquire:DelayFrames1
	SetVariable FramesTrig1SecsSetvar, win = twoP_Controls, disable=1,pos={156,401},size={65,15},proc=GUIPSIsetVarProc,title=" "
	SetVariable FramesTrig1SecsSetvar, win = twoP_Controls, userdata=  "NQ_TrigSecsProc",fSize=10, format="%.2W0Ps"
	SetVariable FramesTrig1SecsSetvar, win = twoP_Controls, limits={0,inf,0},value= root:Packages:twoP:Acquire:DelayFramesSec1
	// trig 2
	CheckBox FramesTrig2Check, win = twoP_Controls, disable=1, pos={6,420},size={16,14},title="",fSize=10,value= 0
	SetVariable FramesTrig2SetVar, win = twoP_Controls, disable=1, pos={24,420},size={128,16},proc=NQ_SetTimesProc,title="Trig2 on Frame"
	SetVariable FramesTrig2SetVar, win = twoP_Controls, userdata=  "NQ_TrigSecsFrameProc",fSize=10
	SetVariable FramesTrig2SetVar, win = twoP_Controls, limits={0,inf,1},value= root:Packages:twoP:Acquire:DelayFrames2
	SetVariable FramesTrig2SecsSetvar, win = twoP_Controls, disable=1, pos={156,420},size={65,15},proc=GUIPSIsetVarProc,title=" "
	SetVariable FramesTrig2SecsSetvar, win = twoP_Controls, userdata=  "NQ_TrigSecsProc",fSize=10, format="%.2W0Ps"
	SetVariable FramesTrig2SecsSetvar, win = twoP_Controls, limits={0,inf,0},value= root:Packages:twoP:Acquire:DelayFramesSec2
	// ephys popmenu
	PopupMenu ePhysPopup, win = twoP_Controls, disable=1,pos={229,398},size={103,20},proc=NQ_ephysAdjChansProc,title="Electrophys"
	PopupMenu ePhysPopup, win = twoP_Controls, mode=1,popvalue="OFF",value= #"\"OFF;1;2;1 & 2\""
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "T_Ser", "Checkbox LiveROICheck 0;Checkbox LroiCheckRatio 0;Popupmenu LROIRatPopUp 0;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "T_Ser", "Setvariable NumTSeriesFramesSetVar 0;Checkbox FramesTrig1Check 0;Setvariable FramesTrig1SetVar 0;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "T_Ser", "Setvariable FramesTrig1SecsSetvar 0;Checkbox FramesTrig2Check 0;Setvariable FramesTrig2SetVar 0;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "T_Ser", "Setvariable FramesTrig2SecsSetvar 0;Popupmenu ePhysPopup 0;")
//	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "T_Ser", "Checkbox FIFOcheck 0;Setvariable FIFODirSetvar 0;")
	// "Average Frames" controls
	SetVariable NumAvgSeriesFramesSetVar, win = twoP_Controls, disable =1,pos={7,336},size={193,18},proc=NQ_SetTimesProc,title="Frames to Average"
	SetVariable NumAvgSeriesFramesSetVar, win = twoP_Controls, fSize=12,limits={0,inf,1},value= root:Packages:twoP:Acquire:numAverageFrames
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Avg", "Setvariable NumAvgSeriesFramesSetVar 0;")
	// Line Scan Controls
	SetVariable LineScanWidthSetVar win = twoP_Controls, disable =1,pos={8,315},size={91,15},proc=NQ_SetTimesProc,title="X Pix",fSize=10
	SetVariable LineScanWidthSetVar win = twoP_Controls,limits={2,inf,2},value= root:Packages:twoP:Acquire:LSWidth
	SetVariable LineScanXStartSetVar win = twoP_Controls, disable =1,pos={110,316},size={98,15},proc=GUIPSIsetVarProc,title="X Strt"
	SetVariable LineScanXStartSetVar win = twoP_Controls,fSize=10,format="%.2W1PV"
	SetVariable LineScanXStartSetVar win = twoP_Controls,limits={-7.5,7.5,0.1},value= root:Packages:twoP:Acquire:LSStartVolts
	SetVariable LineScanXEndSetVar win = twoP_Controls, disable=1,pos={237,315},size={95,15},proc=GUIPSIsetVarProc,title="X End"
	SetVariable LineScanXEndSetVar win = twoP_Controls, fSize=10,format="%.2W1PV"
	SetVariable LineScanXEndSetVar win = twoP_Controls ,limits={-7.5,7.5,0.1},value= root:Packages:twoP:Acquire:LSEndVolts
	SetVariable LineScanHeightSetVar win = twoP_Controls, disable=1, pos={8,335},size={90,15},proc=NQ_SetTimesProc,title="Lines", fSize=10
	SetVariable LineScanHeightSetVar win = twoP_Controls,limits={2,inf,2},value= root:Packages:twoP:Acquire:LSHeight
	SetVariable LineScanYSetVar win = twoP_Controls, disable =1, pos={133,335},size={75,15},title="Y",fSize=10,format="%.2W1PV"
	SetVariable LineScanYSetVar win = twoP_Controls,limits={-7.5,7.5,0.1},value= root:Packages:twoP:Acquire:LSYVolts
	SetVariable LSsizeSetVar win = twoP_Controls, disable=1,pos={12,352},size={69,18},title=" ",fSize=12, format="%.1W1PM",frame=0
	SetVariable LSsizeSetVar win = twoP_Controls,limits={0,inf,0},value= root:Packages:twoP:Acquire:LSImSize,noedit= 1
	SetVariable LSpixSizeSetVar win = twoP_Controls, disable=1,pos={79,352},size={97,18},title=" ",fSize=12
	SetVariable LSpixSizeSetVar  win = twoP_Controls,format="%.1W1Pm/pix",frame=0
	SetVariable LSpixSizeSetVar win = twoP_Controls,limits={0,inf,0},value= root:Packages:twoP:Acquire:LSPixSize,noedit= 1,live= 1
	Button LineScanRevertScaleButton win = twoP_Controls, disable=1,pos={207,354},size={50,17},proc=NQ_LSRevertScaleProc,title="Revert"
	PopupMenu LineScanRevertScalePopMenu win = twoP_Controls, disable=1,pos={259,352},size={76,20},proc=NQ_RevertSettingstoLineScanProc,title="to Scan:"
	PopupMenu LineScanRevertScalePopMenu win = twoP_Controls,mode=0,value= #"NQ_ListScans (\"3\")",fSize=10
	Button LineScanRevertScaleButton win = twoP_Controls,pos={207,354},size={50,17},proc=NQ_LSRevertScaleProc,title="Revert"
	PopupMenu LineScanRevertScalePopMenu win = twoP_Controls, disable=1,pos={259,352},size={76,20},proc=NQ_RevertSettingstoLineScanProc,title="to Scan:"
	PopupMenu LineScanRevertScalePopMenu win = twoP_Controls,mode=0,value= #"NQ_ListScans (\"3\")",fSize=10
	PopupMenu LineScanLinktoPopMenu win = twoP_Controls, disable=1,pos={8,373},size={52,20},proc=NQ_LineScanLinkToProc,title="Link"
	PopupMenu LineScanLinktoPopMenu win = twoP_Controls, mode=0,value= #"NQ_ListScans (\"1,2,4,\") + \";Don't Link\""
	TitleBox LineScanLinktoTitleBox win = twoP_Controls, disable=1,pos={65,373},size={58,20},fSize=10
	TitleBox LineScanLinktoTitleBox win = twoP_Controls,variable= root:Packages:twoP:Acquire:LSLinkWaveStr
	CheckBox LinesTrig1Check win = twoP_Controls, disable=1,pos={5,401},size={16,14},title="",value= 0
	SetVariable LinesTrig1SetVar win = twoP_Controls, disable=1,pos={23,401},size={128,15},proc=NQ_SetTimesProc,title="Trig1 on Line"
	SetVariable LinesTrig1SetVar win = twoP_Controls,limits={0,inf,1},value= root:Packages:twoP:Acquire:DelayLines1
	SetVariable LinesTrig1SecsSetVar win = twoP_Controls, disable=1,pos={154,401},size={57,15},proc=GUIPSIsetVarProc,title=" "
	SetVariable LinesTrig1SecsSetVar win = twoP_Controls,userdata=  "NQ_TrigSecsLinesProc", format="%.2W0Ps"
	SetVariable LinesTrig1SecsSetVar win = twoP_Controls,limits={0,inf,0},value= root:Packages:twoP:Acquire:DelayLinesSec1
	CheckBox LinesTrig2Check win = twoP_Controls,disable=1,pos={5,420},size={16,14},title="",value= 0
	SetVariable LinesTrig2SetVar win = twoP_Controls,disable=1,pos={24,420},size={128,15},proc=NQ_SetTimesProc,title="Trig2 on Line"
	SetVariable LinesTrig2SetVar win = twoP_Controls,limits={0,inf,1},value= root:Packages:twoP:Acquire:DelayLines2
	SetVariable LinesTrig2SecsSetVar win = twoP_Controls, disable =1, pos={155,420},size={57,15},proc=GUIPSIsetVarProc,title=" "
	SetVariable LinesTrig2SecsSetVar win = twoP_Controls,userdata=  "NQ_TrigSecsLinesProc", format="%.2W0Ps"
	SetVariable LinesTrig2SecsSetVar win = twoP_Controls,limits={0,inf,0},value= root:Packages:twoP:Acquire:DelayLinesSec2
	PopupMenu ePhysPopup win = twoP_Controls,disable=1,pos={229,398},size={103,20},proc=NQ_ephysAdjChansProc,title="Electrophys"
	PopupMenu ePhysPopup win = twoP_Controls,mode=1,popvalue="OFF",value= #"\"OFF;1;2;1 & 2\""
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Lines", "Setvariable LineScanHeightSetVar 0;Setvariable LineScanXStartSetVar 0;Setvariable LineScanXEndSetVar 0;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Lines", "Setvariable LineScanWidthSetVar 0;Setvariable LineScanYSetVar 0;Setvariable LSsizeSetVar 0;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Lines", "Setvariable LSpixSizeSetVar 0;Button LineScanRevertScaleButton 0;Popupmenu LineScanRevertScalePopMenu 0")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Lines", "Popupmenu LineScanLinktoPopMenu 0;Titlebox LineScanLinktoTitleBox 0;Checkbox LinesTrig1Check 0;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Lines", "Setvariable LinesTrig1SetVar 0;Setvariable LinesTrig1SecsSetVar 0;Checkbox LinesTrig2Check 0;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Lines", "Setvariable LinesTrig2SetVar 0;Setvariable LinesTrig2SecsSetVar 0;Titlebox ePhysTitle 0;Popupmenu ePhysPopup 0;")
	// Add "Z_Series" controls
	SetVariable  NumZframesSetvar win = twoP_Controls, disable =3,pos={7,312},size={148,18},proc=NQ_zSetVarProc,title="Z Slices   ", fSize=12
	SetVariable NumZframesSetvar win = twoP_Controls ,limits={0,inf,1},value= root:Packages:twoP:Acquire:NumZseriesFrames
	SetVariable zStepSizeSetvar win = twoP_Controls, disable =1, pos={7.00,339.00},size={148.00,18.00},proc=GUIPSIsetVarProc,title="Step Size "
	SetVariable zStepSizeSetvar win = twoP_Controls,userdata= A":/PAE;e:&O@<,1bDdtj\\0ed/j0K)!I0P)gi2ENu^0kDpj2Z"
	SetVariable zStepSizeSetvar win = twoP_Controls,fSize=12,format="%.3W1Pm"
	SetVariable zStepSizeSetvar win = twoP_Controls,limits={-inf,inf,1e-007},value= root:Packages:twoP:Acquire:ZStepSize
	Button FirstZButton win = twoP_Controls, disable=1,pos={7,366},size={29,18},title="Get", proc=NQ_ZfirstLastButtonProc
	SetVariable zFirstZSetVar win = twoP_Controls,disable=1,pos={40.00,366.00},size={115.00,18.00},proc=GUIPSIsetVarProc,title="First Z"
	SetVariable zFirstZSetVar win = twoP_Controls,userdata= A":/PAE;e:&O@<,1bDdtj\\0kDpm4#(:u1HRZ[0kDpj2Z"
	SetVariable zFirstZSetVar win = twoP_Controls,fSize=12,format="%.3W1Pm"
	SetVariable zFirstZSetVar win = twoP_Controls,limits={-inf,inf,1e-006},value= root:Packages:twoP:Acquire:ZFirstZ
	Button LastZButton, win = twoP_Controls, disable=1, pos={7,394},size={30,17},proc=NQ_ZfirstLastButtonProc,title="Get"
	SetVariable ZLastZSetVar win = twoP_Controls, disable=1, pos={39.00,393.00},size={116.00,18.00},proc=GUIPSIsetVarProc,title="Last Z"
	SetVariable ZLastZSetVar win = twoP_Controls,userdata= A":/PAE;e:&O@<,1bDdtj\\0kDpm4#(:u1HRZ[0kDpj2Z"
	SetVariable ZLastZSetVar win = twoP_Controls,fSize=12,format="%.3W1Pm"
	SetVariable ZLastZSetVar win = twoP_Controls,limits={-inf,inf,1e-006},value= root:Packages:twoP:Acquire:ZLastZ
	SetVariable zKalmanAvgSetvar win = twoP_Controls, disable=1,pos={7,421},size={147,18},proc=NQ_SetTimesProc,title="Avg. each slice"
	SetVariable zKalmanAvgSetvar win = twoP_Controls,limits={1,inf,1},value= root:Packages:twoP:Acquire:NumZseriesAvg,fSize=12
	PopupMenu ZdjustPopMenu, win = twoP_Controls, disable =1,pos={162,312},size={100,21},proc=NQ_ZAdjustPopMenuProc,title="adjust"
	PopupMenu ZdjustPopMenu, win = twoP_Controls, mode=1,popvalue="Num Slices",value= #"\"Num Slices;Step Size;First Z;Last Z;\""
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Z_ser", "Setvariable NumZframesSetvar 2;Setvariable zStepSizeSetvar 0;Setvariable zFirstZSetVar 0;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Z_ser", "Setvariable ZLastZSetVar 0;Setvariable zKalmanAvgSetvar 0;Setvariable ZdjustPopMenu 0;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Z_ser", "Button FirstZButton 0;Button LastZButton 0;PopupMenu ZdjustPopMenu 0")
	// "ePhys_Only" controls
	PopupMenu EphysOnlyChansPopUp, win = twoP_Controls, disable =1,pos={7,336},size={191,23},title="ElectroPhys Channels:"
	PopupMenu EphysOnlyChansPopUp, win = twoP_Controls, mode=3,popvalue="1 & 2",value= #"\"1;2;1 & 2\"", proc = NQ_ephysChansProc
	SetVariable EphysExpTimeSetVar, win = twoP_Controls, disable = 1, pos={7,360},size={180,16},proc=GUIPSIsetVarProc,title="ElectroPhys Scan Time"
	SetVariable EphysExpTimeSetVar, win = twoP_Controls, userdata=  ";0;INF;",format="%.1W1Ps"
	SetVariable EphysExpTimeSetVar, win = twoP_Controls, limits={-inf,inf,0.1},value= root:Packages:twoP:Acquire:ePhysOnlyTime
	SetVariable EphysExpTimeSetVar, win = twoP_Controls, limits={0,inf,0.1},value= root:Packages:twoP:Acquire:ePhysOnlyTime
	CheckBox ePhysTrig1Check, win = twoP_Controls, disable =1,pos={6,401},size={16,14},title="",value= 0
	SetVariable ePhysTrig1SetVar, win = twoP_Controls, disable =1,pos={24,401},size={156,18},proc=GUIPSIsetVarProc,title="Trig1 at Time"
	SetVariable ePhysTrig1SetVar, win = twoP_Controls, format="%.2W1Ps"
	SetVariable ePhysTrig1SetVar, win = twoP_Controls, limits={0,inf,1},value= root:Packages:twoP:Acquire:DelaySecs1
	CheckBox ePhysTrig2Check, win = twoP_Controls, disable =1,pos={6,420},size={16,14},title="",value= 0
	SetVariable ePhysTrig2SetVar, win = twoP_Controls, disable =1,pos={24,420},size={156,18},proc=GUIPSIsetVarProc,title="Trig2 on Line"
	SetVariable ePhysTrig2SetVar, win = twoP_Controls, format="%.1W1Ps"
	SetVariable ePhysTrig2SetVar, win = twoP_Controls, limits={0,inf,1},value= root:Packages:twoP:Acquire:DelaySecs2
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "ePhys", "Setvariable EphysExpTimeSetVar 0;Popupmenu EphysOnlyChansPopUp 0;Checkbox ePhysTrig1Check 0;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "ePhys", "Setvariable ePhysTrig1SetVar 0;Checkbox ePhysTrig2Check 0;Setvariable ePhysTrig2SetVar 0;")
//	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "ePhys", "Checkbox FIFOcheck 0;Setvariable FIFODirSetvar 0;")
	// MultiAq Controls
	// Period settings
	CheckBox MultiPeriodCheck win = twoP_Controls, disable =1,pos={8,315},size={47,14},proc=GUIPRadioButtonProcSetGlobal,title="Period",value= 1,mode=1
	CheckBox MultiPeriodCheck win = twoP_Controls, userdata= A"Ec5l<3cJM;CLLjeF#lo[?VY<G@<\">:@rZX*Eb.:KF_l/66#fk<D.QF[A7[nX4&'j6FD4fbG%F$SARfL;9m(8oBiK+eB4kdr6YL%@CHD"
	SetVariable MultiAqPeriodNumSetVar  win = twoP_Controls, disable =1, pos={61,315},size={76,15},title="Num"
	SetVariable MultiAqPeriodNumSetVar win = twoP_Controls ,fSize=10,limits={2,inf,1},value= root:Packages:twoP:Acquire:multiAqPeriodNum
	SetVariable MultAqPeriodPeriodSetVar win = twoP_Controls, disable =1,pos={142,315},size={100,15},proc=NQ_MultiAqTimeSetVarProc,title="Acq Period "
	SetVariable MultAqPeriodPeriodSetVar win = twoP_Controls,fSize=10,limits={0,inf,0.5},value= root:Packages:twoP:Acquire:multiAqPeriodPeriodStr
	SetVariable MultiAqPeriodDelaySetVar win = twoP_Controls, disable =1, pos={248,315},size={82,15},proc=NQ_MultiAqTimeSetVarProc,title="Delay"
	SetVariable MultiAqPeriodDelaySetVar  win = twoP_Controls,fSize=10, value= root:Packages:twoP:Acquire:multiAqPeriodDelayStr
	// wave settings
	CheckBox MultiWaveCheck win = twoP_Controls, disable =1,pos={8,339},size={42,14},proc=GUIPRadioButtonProcSetGlobal,title="Wave",value= 0,mode=1
	CheckBox MultiWaveCheck win = twoP_Controls,userdata= A"Ec5l<3cJM;CLLjeF#lo[?VY<G@<\">:@rZX*Eb.:KF_l/66#fk<D.QF[A7[nY4&'j6FD4Q_EbTH&6YL%@CHG75CijAjEbT0!ATC.OARfL;"
	PopupMenu MultiAqWavePopup win = twoP_Controls, disable=1, pos={59,336},size={110,20},proc=NQ_MultiWaveWavePopMenuProc,title="Timing Wave:"
	PopupMenu MultiAqWavePopup win = twoP_Controls,mode=0,value= #"GUIPListObjs(\"root:packages:twoP:acquire:multiAqWaves\",1, \"*\" , 0, \"\\\\M1(no timing waves;\") + \"\\\\M1-);New Timing Wave\""
	TitleBox MultiAqWaveTitleBox win = twoP_Controls,disable=1,pos={174,340},size={18,12},frame=0
	TitleBox MultiAqWaveTitleBox win = twoP_Controls,variable= root:Packages:twoP:Acquire:multiAqWaveWaveStr
	Button MultiAqWaveEditButton win = twoP_Controls, disable=1,pos={232,337},size={50,18},proc=NQ_MultiWaveEditButtonProc,title="Edit", fSize=10
	Button MultiAqWaveDeleteButton win = twoP_Controls, disable=1, pos={285,337},size={50,18},proc=NQ_MultiWaveDeleteButtonProc,title="Delete", fSize=10
	// trigger settings
	CheckBox MultiTriggerCheck win = twoP_Controls, disable =1,pos={8,363},size={52,14},proc=GUIPRadioButtonProcSetGlobal,title="Trigger",value= 0,mode=1
	CheckBox MultiTriggerCheck win = twoP_Controls, disable =1,userdata= A"Ec5l<3cJM;CLLjeF#lo[?VY<G@<\">:@rZX*Eb.:KF_l/66#fk<D.QF[A7[nZ4&'j6FD4Q_EbTH&6YL%@CHG75CijAm@<Q3LBOt[h3r"
	SetVariable MultiAqTriggerNumSetVar  win = twoP_Controls, disable=1, pos={65,363},size={75,15},title="Num", fSize=10, limits={2,inf,1},value= root:Packages:twoP:Acquire:multiAqTriggerNum
	//Data mode popup  - datamodes are normal single scan modes
	PopupMenu multiAqDataModePopUp win = twoP_Controls, disable =1,pos={225,379},size={126,20},proc=NQ_MultiAqDataModePopMenuProc,title="mode"
	PopupMenu multiAqDataModePopUp win = twoP_Controls, mode=1,popvalue="Time Series",value= #"\"Time Series;Average;Line Scan;Z series;ePhys Only\""
	// Pre-Make button
	Button MultiPreMakeButton win = twoP_Controls, disable =1, pos={232,357},size={50,20},proc=NQ_MultiPreMakeProc,title="PreMake"
	//Progress display , tme to next
	ValDisplay multiAqProgressDisplay win = twoP_Controls, disable =1,pos={7,394},size={200,42},frame=0
	ValDisplay multiAqProgressDisplay win = twoP_Controls,limits={0,0,0},barmisc={10,30},value= #"root:packages:twoP:acquire:multiAqiAq"
	TitleBox MultiAqTimeToNextTitle win = twoP_Controls, disable =1,pos={210,397},size={86,17},title="Next Scan In" ,fSize=14,frame=0
	SetVariable MultiAqTimeToNextSetVar win = twoP_Controls, disable =1,pos={211,415},size={74,20},title=" ",fSize=14,frame=0
	SetVariable MultiAqTimeToNextSetVar win = twoP_Controls,value= root:Packages:twoP:Acquire:multiAqTimeToNextStr
	// multi start Button
	Button MultiAqStartButton win = twoP_Controls, disable=1, pos={288,413},size={51,24},proc=NQ_StartScan,title="Start"
	Button MultiAqStartButton  win = twoP_Controls,userdata=  "Start Multi",fSize=16,fColor=(0,65535,0)
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "MultiAq", "CheckBox MultiPeriodCheck 0;SetVariable MultiAqPeriodNumSetVar 0;SetVariable MultAqPeriodPeriodSetVar 0;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "MultiAq", "SetVariable MultiAqPeriodDelaySetVar 0;CheckBox MultiWaveCheck 0;PopupMenu MultiAqWavePopup 0;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "MultiAq", "TitleBox MultiAqWaveTitleBox 0;Button MultiAqWaveEditButton 0;Button MultiAqWaveDeleteButton 0;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "MultiAq", "CheckBox MultiTriggerCheck 0;SetVariable MultiAqTriggerNumSetVar 0;PopupMenu multiAqDataModePopUp 0;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "MultiAq", "Button MultiPreMakeButton 0;ValDisplay multiAqProgressDisplay 0;TitleBox MultiAqTimeToNextTitle 0;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "MultiAq", "SetVariable MultiAqTimeToNextSetVar 0;Button MultiAqStartButton 0;")
	// Call SetTimes Procedure to set the above times to the defaults from the constants
	Execute/P/Q/Z "NQ_SetTimes ()"
	// Init livemode ScanStr, without getting stage, because stage probably hasn't loaded yet
	STRUCT NQ_ScanStruct s
	NQ_LoadScanStruct (s, 0)
	NQ_ScanNoter (s, "root:packages:twoP:Acquire:LiveModeScanStr")
end
 
//******************************************************************************************************
// Function for the New Scan Name Setvariable control.  Makes it a legal name and autoincrements it.
// Last Modified 2014/08/13 by Jamie Boyd
Function NQ_ScanNameProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			//1) make wavename a legal IGOR name
			string newName = sva.sval
			newName = CleanupName(newName, 0 )
			//2) if autoincrement check is on, check for autoincrement compliance and correct if neccesary
			NVAR autIncCheck = root:packages:twoP:acquire:AutIncCheck
			variable slen, curnum
			if (autIncCheck)	// then control is checked
				newName = NQ_autinc (newName, 0)
			endif
			NVAR overwriteWarnCheck = root:packages:twoP:acquire:overwriteWarnCheck
			if (overwriteWarnCheck)	// user wants to be warned about possible overwriting of waves
				if (dataFolderExists ("root:twoP_Scans:" + newName))
					string alertstr = "A scan with the name \"" + newName + "\" already exists.  You will be reminded again when you start the scan."
					doalert 0, alertstr
				endif
			endif
			SVAR NewScanName = root:Packages:twoP:Acquire:NewScanName
			NewScanName = newName
			NVAR scanNum = root:Packages:twoP:Acquire:NewScanNum
			// see if wavename ends in an underscore followed by a  number
			slen = strlen (NewScanName)
			variable uScorePos = strsearch(NewScanName, "_", sLen-1,1)
			if (uScorePos ==-1)
				scanNum =Nan
			else
				scanNum = str2num (NewScanName [uScorePos + 1, slen -1])		// try to make a number from last underscore forward
			endif
			break
	endswitch
	return 0
end

//******************************************************************************************************
// Function for the checkbox to autoincrement wavenames.  It runs when you first check the box and calls cleanupName and
// NQ_autinc on whatever is already in the New Wave Name setvariable
// Last Modified 2014/08/13 by Jamie Boyd
Function NQ_autincCheckProc (cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			if (checked)
				SVAR NewScanName = root:Packages:twoP:Acquire:NewScanName
				// Clean up scan name
				NewScanName = cleanupname(NewScanName, 0)
				// autoincrement scan name  til there is no conflict
				For (NewScanName = NQ_autinc (NewScanName, 0);DataFolderExists("root:twoP_Scans:" + NewScanName);NewScanName = NQ_autinc (NewScanName, 1))
				endfor
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Checks to see if a string is autoincrement compatable and, optionally, increments it.
// Used when the autoincrement  wavenames checkbox is on.
// Last modified 2012/04/02 by Jamie Boyd
Function/s NQ_autinc (NewWaveName, inc)
	string NewWaveName
	variable inc		// if 0, don't increment., just check for compatibility. if 1, increment
	// see if wavename ends in an underscore followed by a  number
	variable slen = strlen (NewWaveName), curNum
	variable uScorePos = strsearch(NewWaveName, "_", sLen-1,1)
	if (uScorePos ==-1)
		curNum =Nan
		uScorePos = sLen
	else
		curnum = str2num (NewWaveName [uScorePos + 1, slen -1])		// try to make a number from last underscore forward
	endif
	if (numtype (curnum) == 0)
		sprintf NewWaveName, "%s_%03d", NewWaveName [0, uScorePos - 1], curNum + inc
	else // wavename does not end with underscore followed by a number, so probably not a numbered wavename, so append a number to the wavename
		NewWaveName += "_000"
	endif
	NVAR scanNum = root:Packages:twoP:Acquire:NewScanNum
	scanNum = curNum + inc
	return NewWaveName
end


//******************************************************************************************************
// Function for the experiment note setvariable. All it does is ensure that no colons or returns are used in the note, as they would mess up
// using number-by-key and string-by-key routines used to extract info from a wavenote. Colons are replaced by equals.
// Last Modified 2012/06/13 by Jamie Boyd
Function NQ_ExpNoteProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
		
			string varStr = sva.sval
			variable ii
			variable namestrlen = strlen (varStr)
			variable badChar =0
			// check for semicolons with char2num
			For (ii = 0; ii < nameStrLen; ii +=1)
				if  (char2num (varStr [ii]) == 58)
					varStr [ii,ii]= "="
					badChar= 1
				endif
			endfor
			SVAR NewWaveNote = root:Packages:twoP:Acquire:NewScanNote
			NewWaveNote = varStr
			if (badChar)
				doAlert 0, "Colons are used as separator characters in the\rkey:value\rkey:value\r map in the scan info string, and are unavailble for use in your experiment notes. key=value;key=value; can be used, though."  
			endif
			break
	endswitch
End

//******************************************************************************************************
// Updates global variable for scan channels
// Last Modified 2013/08/09 by Jamie Boyd
Function NQ_ScanChansPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			NVAR scanChans = root:Packages:twoP:Acquire:ScanChans
			scanChans = popNum
			// update LiveMode scan String 
			SVAR scanStr = root:packages:twoP:Acquire:LiveModeScanStr
			scanStr = ReplaceNumberByKey("ImChans", scanStr, scanChans, ":", "\r")
			string imchanDesc = ""
			variable ii
			for (ii =1; ii<3; ii+=1)
				if (ii & scanChans)
					imchanDesc += "ch" + num2str (ii) + ","
				endif
			endfor
			scanStr = ReplaceStringByKey("imchanDesc", scanStr, imchanDesc, ":", "\r")
			//Remove channels on ScanGraph not present in current config
			NVAR showCh1 = root:packages:twoP:examine:showCh1
			NVAR showCh2 = root:packages:twoP:examine:showCh2
			NVAR showMerge = root:packages:twoP:examine:showMerge
			showCh1 *= (scanChans & 1)
			showCh2 *=  (scanChans & 2)
			showMerge *= ((scanChans & 1) && (scanChans & 2))
			string removeList="", subWinList = ChildWindowList("twoPscanGraph")
			variable iRem, nRems
			if ((!(showCh1)) && (WhichListItem("GCH1", subWInList, ";", 0,0) > -1))
				removeList += "GCH1;"
			endif
			if ((!(showCh2)) && (WhichListItem("GCH2", subWInList, ";", 0,0) > -1))
				removeList += "GCH2;"
			endif
			if ((!(showMerge)) && (WhichListItem("GMRG", subWInList, ";", 0,0) > -1))
				removeList += "GMRG;"
			endif
			nRems = itemsinlist (removeList, ";")
			if (nRems > 0)
				STRUCT GUIPSubWin_UtilStruct s
				s.graphName = "twoPScanGraph"
				s.nSubWIns = nRems
				STRUCT GUIPSubWin_ContentStruct cs
				for (iRem =0; iRem < nRems; iRem += 1)
					cs.subWin = StringFromList(iRem, removeList, ";")
					s.contentStructs [iRem] = cs
				endfor
				GUIPSubWin_Remove (s)
				GUIPSubWin_FitSubWindows ("twoPScanGraph" )
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Updates global variable for ephys channels when used along with image scanning
// Last Modified 2009/06/01 by Jamie
Function NQ_ephysAdjChansProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			NVAR ePhysChans =  root:Packages:twoP:Acquire:ePhysAdjChans
			ePhysChans = popNum-1
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Updates global variable for ephys channels when doing an ePhys only scan
// Last Modified 2009/06/01 by Jamie Boyd
Function NQ_ephysChansProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			NVAR ePhysChans =  root:Packages:twoP:Acquire:ePhysChans
			ePhysChans = popNum
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Opens the focus panel using the chosen focus procedure
// Last Modified2009/05/31 by Jamie Boyd
Function NQ_OpenFocusPanel (ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR StageProc = root:packages:twoP:Acquire:StageProc
			dowindow/F $StageProc + "_Controls"
			if (V_Flag)
				return 0
			else
				SVAR StagePort = root:Packages:twoP:Acquire:StagePort
				StageStartStage(StageProc, thePort = StagePort)
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
//Makes the panel for displaying and changing additional scan settings
// Last Modified Jun 04 2009 by Jamie Boyd
//Function NQ_OtherScanSettingsProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Dowindow/F Other_Scan_Settings
			if (V_Flag ==1)
				return 1
			endif
			NewPanel /K=1/W=(2,49,181,412) as "Other Scan Settings"
			DoWindow/C Other_Scan_Settings
			
			TabControl modeTabe win = Other_Scan_Settings,pos={4.00,26.00},size={311.00,520.00},proc=GUIPTabProc
			TabControl modeTabe win = Other_Scan_Settings, tabLabel(0)="Image_Scan",tabLabel(1)="ePhys_Trigs", value=0

			PopupMenu ImageBoardPopMenu win = Other_Scan_Settings,pos={10.00,49.00},size={93.00,19.00},proc=NQ_PrefsSetBoardName,title="Image Device"
			PopupMenu ImageBoardPopMenu win = Other_Scan_Settings,mode=0,value= #"fDAQmx_DeviceNames()"
			TitleBox ImageBoardTitle win = Other_Scan_Settings,pos={108.00,53.00},size={42.00,15.00},frame=0
			TitleBox ImageBoardTitle win = Other_Scan_Settings,variable= root:Packages:twoP:Acquire:imageBoard

			
			
			// image scan settings
			GroupBox imageGrp,pos={1,2},size={177,289},title="Image Scanning"
			SetVariable PixTimeSetVar,pos={9,37},size={141,16},title="Pixel Time"
			SetVariable PixTimeSetVar,format="%.3W1PSec"
			SetVariable PixTimeSetVar,limits={0,0,0},value= root:Packages:twoP:Acquire:PixTIme,noedit= 1
			SetVariable DutyCycleSetVar,pos={9,57},size={123,16},format="%g"
			SetVariable DutyCycleSetVar,limits={0,1,0.05},value= root:Packages:twoP:Acquire:DutyCycle
			SetVariable FlybackPropSetVar,pos={9,96},size={139,16},proc=NQ_SetTimesProc,title="FlyBack Ratio"
			SetVariable FlybackPropSetVar,limits={0.25,1,0.05},value= root:Packages:twoP:Acquire:FlybackProp
			SetVariable RotateSetvar,pos={9,116},size={165,16},proc=GUIPSIsetVarProc,title="ScanHead Delay "
			SetVariable RotateSetvar,format="%.2W1PSec", UserData = ";0;1;;"
			SetVariable RotateSetvar,limits={0,inf,2.5e-07},value= root:Packages:twoP:Acquire:ScanHeadDelay
			PopupMenu ImageGainPopup,pos={9,135},size={90,21},proc=NQ_ScanGainPopMenuProc,title="Scan Gain:"
			PopupMenu ImageGainPopup,mode=0,value= #"\"0.2: (+/- 50v);0.5: (+/- 20v);1: (+/- 10v);2: (+/- 5v);5: (+/- 2v);10: (+/- 1v);20: (+/- 0.5v);50: (+/- 0.2v)\""
			// set titleBox for gain to be equal to gain in global variable
			NVAR ScanGain = root:Packages:twoP:Acquire:ScanGain
			string GainStr
			sprintf GainStr, "%.1f: (+/- %.1f V)",ScanGain, (10/ScanGain)
			TitleBox ScanGainTitle,pos={102,139},size={44,13},title=GainStr,frame=0
			// Objectives list
			TitleBox ObjScalTitle,pos={20,164},size={123,13},title="Objective Scaling (m/Volt)"
			TitleBox ObjScalTitle,fSize=12,frame=0
			ListBox MagSettingsList,pos={8,180},size={165,86}
			ListBox MagSettingsList,listWave=root:Packages:twoP:Acquire:ObjWave
			ListBox MagSettingsList,selWave=root:Packages:twoP:Acquire:ObjSelWave
			ListBox MagSettingsList,mode= 1,selRow= 0
			Button AddObjectiveButton,pos={16,269},size={62,16},proc=NQ_AddObjProc,title="Add Obj."
			Button DeleteObjectiveButton,pos={81,269},size={74,16},proc=NQ_DeleteObjectiveProc,title="Delete Obj."
			// ePhys settings
			GroupBox ePhysGrp,pos={3,296},size={176,66},title="Electrophysiology"
			SetVariable EphysSampFreq,pos={10,315},size={137,16},proc=GUIPSIsetVarProc,title="Sampling Freq"
			SetVariable EphysSampFreq,format="%.2W1PHz"
			SetVariable EphysSampFreq,limits={0,inf,100},value= root:Packages:twoP:Acquire:EphysFreq
			PopupMenu EPhysGainPopup,pos={8,334},size={94,21},proc=NQ_ePhysGainPopMenuProc,title="ePhys Gain:"
			PopupMenu EPhysGainPopup,mode=0,value= #"\"0.5: (+/- 20v);1: (+/- 10v);10: (+/- 1v);100: (+/- 0.1v)\""
			// set titlebox for ePhysGain to correct value
			NVAR ePhysGain = root:Packages:twoP:Acquire:ePhysGain
			sprintf GainStr, "%.1f: (+/- %.1f V)",ePhysGain, (10/ePhysGain)
			TitleBox ePhysGainTitle,pos={104,338},size={67,13},frame =0, title=GainStr
			break
	endswitch
	return 0
End
 
//******************************************************************************************************
// Updates the global variable and title box for scan gain when the popmenu is called
// Last Modified 2009/06/01 by Jamie
Function NQ_ScanGainPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			String popStr = pa.popStr
			NVAR ScanGain = root:Packages:twoP:Acquire:ScanGain
			ScanGain =  str2num (stringfromlist (0, popStr, ":"))
			TitleBox ScanGainTitle,win=Other_Scan_Settings, title=popStr
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Updates the global variable and titlebox for ePhys gain when the popmenu is called
// Last Modified 2009/06/01 by Jamie Boyd
Function NQ_ePhysGainPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			String popStr = pa.popStr
			NVAR ScanGain = root:Packages:twoP:Acquire:ePhysGain
			ScanGain =  str2num (stringfromlist (0, popStr, ":"))
			TitleBox ePhysGainTitle, win=Other_Scan_Settings, title=popStr
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Enables/Disables controls for setting Z variables, based on popmenu selection
// Last Modified 2015/04/15 by Jamie Boyd
Function NQ_ZAdjustPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			// DIsable controls based on selection
			// ZSLices;Step Size;First Z;Last Z
			GUIPTabSetAbleState ("twoP_Controls", "SmodeTabControl", "Z_ser", "NumZframesSetvar;",  ((popNum == 1)*2), 1)
			GUIPTabSetAbleState ("twoP_Controls", "SmodeTabControl", "Z_ser", "zStepSizeSetvar;",  ((popNum == 2)*2), 1)
			GUIPTabSetAbleState ("twoP_Controls", "SmodeTabControl", "Z_ser", "FirstZButton;",  ((popNum == 3)*2), 1)
			GUIPTabSetAbleState ("twoP_Controls", "SmodeTabControl", "Z_ser", "zFirstZSetVar;",  ((popNum == 3)*2), 1)
			GUIPTabSetAbleState ("twoP_Controls", "SmodeTabControl", "Z_ser", "LastZButton;",  ((popNum == 4)*2), 1)
			GUIPTabSetAbleState ("twoP_Controls", "SmodeTabControl", "Z_ser", "ZLastZSetVar;",  ((popNum == 4)*2), 1)
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Adjusts Z variables, based on selection in ZdjustPopMenu
// Last Modified Aug 03 2010 by Jamie Boyd
Function NQ_zSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		//case 2: // Enter key
		case 3: // Live update
		case 8: //finish edit
			Variable dval = sva.dval
			String sval = sva.sval
			// Globals to the z parameters
			NVAR NumZFrames = root:packages:twoP:Acquire:NumZseriesFrames
			NVAR ZStepSize = root:packages:twoP:Acquire:ZStepSize
			NVAR LastZ = root:packages:twoP:Acquire:ZLastZ
			NVAR FirstZ = root:packages:twoP:Acquire:ZFirstZ
			// What do we modify ?
			controlinfo/w=twoP_Controls ZdjustPopMenu
			variable toMod = V_Value
			switch (toMod)
				case 1: // Z SLices
					NumZFrames =  round(((LastZ-FirstZ ) / ZStepSize) + 1)
					// numFrames can not be negative, but stepsize can
					if (NumZFrames < 0)
						ZStepSize *= -1
						NumZFrames *= -1
					endif
					break
				case 2: //Step Size
					NVAR ZStepSizeMin = root:packages:twoP:Acquire:ZStepSizeMin
					ZStepSize = round (((LastZ - FirstZ)/NumZFrames)/ZStepSizeMin)*ZStepSizeMin
					//LastZ = (NumZFrames * ZStepSize) + FirstZ
					break
				case 3: // First Z
					FirstZ =  (NumZFrames * ZStepSize) - LastZ
					break
				case 4: //LastZ
					LastZ = (NumZFrames * ZStepSize) + FirstZ
					break
			endswitch
			break
	endswitch
	// Adjust increments for 1st and last z setvariables to stepsize, if stepsize was changed
	if ((cmpstr (sva.ctrlname, "zStepSizeSetvar") == 0) || (toMod == 2))
		NVAR ZStepSize = root:packages:twoP:Acquire:ZStepSize
		setvariable zFirstZSetVar win = twoP_Controls, limits = {-INF, INF, ZStepSize}
		setvariable zLastZSetVar win = twoP_Controls, limits = {-INF, INF, ZStepSize}
	endif
	// Adjust frame time/exp time
	NQ_SetTimes ()
	return 0
End

//******************************************************************************************************
// Grabs value from stage/focus, puts it into firstZ or lastZ, and adjusts Z variables based on selection in ZdjustPopMenu
// Last Modified 2009/06/01 by Jamie Boyd
Function NQ_ZfirstLastButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// Update stage for Z
			variable xS=0, yS=0, zS=1, axS=0
			SVAR StageProc = root:packages:twoP:Acquire:StageProc
			SVAR thePort = root:packages:twoP:acquire:StagePort
			funcref  StageUpdate_Template UpdateStage=$"StageUpDate_" + StageProc
			UpdateStage (xS, yS, zS, axS) 
			// Put z-Value in proper global for the button that was clicked
			if (cmpstr (ba.ctrlname, "FirstZButton") == 0)
				NVAR FirstZ = root:packages:twoP:Acquire:ZFirstZ
				FirstZ = zS
			elseif (cmpstr (ba.ctrlname, "LastZButton") == 0)
				NVAR LastZ = root:packages:twoP:Acquire:ZLastZ
				LastZ = zS
			endif
			// Adjust Z values
			STRUCT WMSetVariableAction sva
			sva.eventcode = 1
			NQ_zSetVarProc (sva)
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Lists names of objectives from the listbox wave
// Last Modified 2015/04/22 by Jamie B	oyd
Function/S NQ_Obj_ListObjs ()
	
	WAVE/T objWave =root:packages:twoP:acquire:objWave
	variable iObj, nObjs = dimsize (objWave, 0)
	string objList =""
	for (iObj =0; iObj < nObjs; iObj +=1)
		objList += objWave [iObj] [0] + ";"
	endfor
	return objList
end

//******************************************************************************************************
// Adds a row to the list of objectives
// Last Modified Jun 01 2009  by Jamie Boyd
Function NQ_AddObjProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			WAVE/T ObjWave = root:packages:twoP:acquire:ObjWave
			WAVE ObjSelWave = root:packages:twoP:acquire:ObjSelWave
			variable LastMag = dimsize (ObjWave,0) -1
			insertpoints /M= 0 LastMag + 1, 1, ObjWave, ObjSelWave
			ObjSelWave [LastMag + 1] [] = 6 // editable, with a double-click
			break
	endswitch
	return 0
End
 
//******************************************************************************************************
// Deletes selected row from the list of objectives
// Last Modified 2015/04/22  by Jamie Boyd
Function NQ_DelObjPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			WAVE/T objWave = root:packages:twoP:acquire:objWave
			WAVE selWave = root:packages:twoP:acquire:objSelWave
			if (dimSize (objWave, 0) > 1)
				deletePoints/M=0 pa.popNum, 1, objWave, selWave
			else
				objWave [0] [*] = ""
			endif
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//*************************************************************************************************************************************
// Calculates the experiment size and puts it in a global variable
// Last Modified 2012/07/09 by Jamie Boyd
Function NQ_GetExpSize (dataFolder)
	string dataFolder
	
	variable expSize
	// this folder
	variable iObj, nObjs = CountObjects(dataFolder, 1), aWaveType
	for (iObj =0; iObj < nObjs; iObj +=1, expSize += 320)
		WAVE aWave = $dataFolder + GetIndexedObjName(dataFolder, 1, iObj )
		aWaveType = WaveType (aWave)
		if ((aWaveType & 0x2) || (aWaveType & 0x20)) // 32 bit int or 32 bit float
			expSize += 4 * NumPnts (aWave) * SelectNumber((aWaveType & 0x1) , 1,2)
		elseif  (aWaveType & 0x4) // 64 bit float
			expSize += 8 * NumPnts (aWave) * SelectNumber((aWaveType & 0x1) , 1,2)
		elseif (aWaveType & 0x8) // 8 bit int
			expSize += NumPnts (aWave) * SelectNumber((aWaveType & 0x1) ,  1,2)
		elseif (aWaveType & 0x10) // 16 bit int
			expSize += 2 * NumPnts (aWave) * SelectNumber((aWaveType & 0x1) ,1,2)
		endif
	endfor
	// subfolders
	nObjs = CountObjects(dataFolder, 4)
	for (iObj =0; iObj < nObjs; iObj += 1)
		expSize += NQ_GetExpSize ( dataFolder + GetIndexedObjName (dataFolder, 4, iObj) +  ":")
	endfor
	return expSize
end
 
//*************************************************************************************************************************************
// Sets the scanMode variable and various options in the control panel
// Last Modified 2013/08/09 by Jamie Boyd
Function NQ_SModeTabControlproc (TC_Struct) : TabControl
	STRUCT WMTabControlAction &tc_Struct
	
	
	if (TC_Struct.eventCode ==-1)
		return 0
	endif
	string name = tc_Struct.ctrlName
	variable tab = tc_Struct.tab
	string tabWin = tc_Struct.win
	
	NVAR ScanMode = root:packages:twoP:Acquire:ScanMode
	if (tab== 6) // multiaq
		// set scan mode as negative of selected mode in multiAqDataMode popup
		controlinfo/w=twoP_Controls multiAqDataModePopUp
		ScanMode = -V_Value
		// button struct for running button functions
		STRUCT WMCheckboxAction cba
		cba.eventCode = 2
		// make sure autoincrement is selected and run
		NVAR autincCheck = root:packages:twoP:acquire:autincCheck
		if (autIncCheck == 0)
			autincCheck =1
			NQ_autincCheckProc (cba)
			checkbox AqAutIncCheck win = twoP_Controls, value=1
		endif
		// make sure export path is set, if exporting after a scan
		NVAR exportafterscan = root:packages:twoP:acquire:exportAfterScan
		if (exportafterscan > 1)
			SVAR PathStr =root:Packages:twoP:examine:ExportPath		// the global string were we store the path
			pathinfo ExportPath
			if ((V_Flag ==0) || (cmpstr (S_path, PathStr) !=0))// path does not exits or is not the same as shown in the string
				NewPath /O/M="Select a Folder in which to store Scan Waves" ExportPath
				if (!V_flag)		// V_flag is set to 0 if newpath is successful
					PathInfo ExportPath
					pathstr =  s_path
				endif
			endif
		endif
	else
		ScanMode = tab
	endif
	//Set Times
	struct WMSetVariableAction sva
	sva.eventCode = 2
	NQ_SetTimes ()
	return 0
end

//*************************************************************************************************************************************
// Makes sure a proper directory is chosen when selecting scan to disk, and that timing globals are set correctly
// Last Modified 2013/07/30 by Jamie Boyd
//Function NQ_ScanToDiskCheckProc(cba) : CheckBoxControl
//	STRUCT WMCheckboxAction &cba
//
//	switch( cba.eventCode )
//		case 2: // mouse up
//			if (cba.checked)
//				SVAR dirStr = root:packages:twoP:acquire:scanToDiskDir
//				STRUCT WMSetVariableAction sva
//				sva.eventcode =2
//				sva.sval = dirStr
//				NQ_FifoDirSetVarProc(sva)
//			endif
//			NQ_SetTimes()
//			break
//		case -1: // control being killed
//			break
//	endswitch
//
//	return 0
//End

//*************************************************************************************************************************************
// Checks the directory chosen for scan to disk. GIves user a chance to set it if it doesn't exist
// Last Modified 2013/07/25 by Jamie Boyd
//Function NQ_FifoDirSetVarProc(sva) : SetVariableControl
//	STRUCT WMSetVariableAction &sva
//
//	switch( sva.eventCode )
//		case 1: // mouse up
//		case 2: // Enter key
//		case 3: // Live update
//			String sval = sva.sval
//			SVAR dirStr = root:packages:twoP:acquire:scanToDiskDir
//			// check if directory exists, or select/make a new directory
//			GetFileFolderInfo/Q/Z=2/D sval
//			if (V_Flag == -1) // user cancelled
//				dirStr = ""
//				return 1
//			else
//				dirStr = S_Path
//			endif
//			break
//		case -1: // control being killed
//			break
//	endswitch
//
//	return 0
//End


//*************************************************************************************************************************************
// This function sets the calculated pixel, line, frame, and experiment times based on the settings in the control panel
// by calling NQ_SetTimes. It is called  by many setvariable controls which  set those things
// Last Modified 2015/04/12 by Jamie Boyd
Function NQ_SetTimesProc (sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
		
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			NQ_SetTimes ()
			break
	endswitch
	return 0
End

//*************************************************************************************************************************************
// This function directly sets the calculated pixel, line, frame, and experiment times based on the settings in the control panel.
// Called in lots of places other than from setvariable controls, so it makes sense to put the code in a dedicated function
// Last Modified 2016/10/25 by Jamie Boyd
Function NQ_SetTimes ()
	
	// Globals for scan timing
	NVAR scanmodeG = root:Packages:twoP:Acquire:ScanMode
	variable scanMode = abs (scanModeG)
	if (scanmode == kLineScan)
		NVAR PixWidth = root:Packages:twoP:acquire:LSWidth
		NVAR PixHeight = root:Packages:twoP:acquire:LSHeight
	else
		NVAR PixWidth = root:Packages:twoP:acquire:PixWidth
		NVAR PixHeight = root:Packages:twoP:acquire:PixHeight
	endif
	NVAR PixTime = root:Packages:twoP:acquire:PixTIme
	NVAR LineTime = root:Packages:twoP:acquire:LineTime
	NVAR FrameTime = root:Packages:twoP:acquire:FrameTime
	NVAR RunTime = root:Packages:twoP:acquire:RunTime
	NVAR PixWidthTotal = root:packages:twoP:Acquire:PixWidthTotal
	NVAR DutyCycle = root:Packages:twoP:Acquire:DutyCycle
	NVAR FlybackProp = root:Packages:twoP:Acquire:FlybackProp
	NVAR FlybackMode = root:Packages:twoP:Acquire:FlyBackMode
	NVAR nLiveFrames = root:packages:twoP:acquire:nLiveFrames
	// make sure sizes are adjusted for aspect ratio before calculating times.
	if (scanmode != kLineScan)
		NQ_AspectRatio (0)
	endif
	// Rough initial calculation of frame time before nasty tests for even point numbers
	if (FlybackMode == 0)
		PixWidthTotal = round (Pixwidth/DutyCycle) + round (Pixwidth*FlyBackProp/DutyCycle)
	else
		PixWidthTotal = round (Pixwidth/DutyCycle)
	endif
	// Set line time by multiplying total pixels in a line by pixel time
	LineTime = (PixWidthTotal) * PixTime
	//Set Frame time by multiplying line time by number of lines
	FrameTime = (LineTime * PixHeight)
	// nLiveFrames is minimum number of frames to acquire at once so scanEndfunction not called to often
	nLiveFrames = ceil (kNQminLiveFrameTime/frametime)
	// Calculate total number of frames for nasty tests for even point numbers based on scan mode
	// Also check for minimun times for Z, Live, and avg modes. Time should only be changed slightly by tests for evenness
	// Also check for scan size - max is 2^24 points
	variable NumFrames
	Switch (scanMode)
		case kTimeSeries:
			NVAR TFrames = root:Packages:twoP:Acquire:TSeriesFrames
			NVAR isCyclic = root:packages:twoP:Acquire:isCyclic
			NVAR scanToDisk = root:packages:twoP:acquire:scanToDisk
			if (scanToDisk)
				isCyclic = 0
			elseif (TFrames * PixWidth * pixHeight > 2^24)
				isCyclic =1
				NVAR bufferSize = root:packages:twoP:acquire:tSeriesBufferSize
				bufferSize = round (kNQtBufferTime/FrameTime)
				TFrames = round (TFrames / bufferSize) * bufferSize
				SetVariable NumTSeriesFramesSetVar win = twoP_Controls, limits={0,inf,(bufferSize)}
			else
				isCyclic = 0
			endif
			numFrames = TFrames
			SetVariable NumTSeriesFramesSetVar win = twoP_Controls, limits={0,inf,1}
			break
		case ksingleImage:
		case kLiveMode:
			NumFrames =nLiveFrames
			break
		case kZseries:
			NVAR NumZSeriesAvg = root:Packages:twoP:Acquire:NumZseriesAvg
			numZseriesAvg = max (numZseriesAvg, ceil (kNQminLiveFrameTime/frametime))
			NumFrames = NumZSeriesAvg
			break
		case kLineScan:
			NumFrames = 1
			NVAR isCyclic = root:packages:twoP:Acquire:isCyclic
			if ( PixWidth * pixHeight > 2^24)
				doAlert 1,  "Number of points is greater than the 2^24 bit buffer for points/channel. You are entering the \"Cyclic Zone\". O.K.?"
				if (V_flag == 1) // Yes was clicked
					isCyclic =1
					NVAR bufferSize = root:packages:twoP:acquire:lScanBufferSize
					bufferSize = round (kNQtBufferTime/lineTime)
					pixHeight = round (pixHeight/bufferSize) * bufferSize
					SetVariable LineScanHeightSetVar win= twoP_Controls, limits={2,inf,(bufferSize)}
				else
					pixHeight = round (2^24 / pixWidth) -5
					print "Number of lines has been adjusted to accomodate the 2^24 bit limit on points/channel."
					SetVariable LineScanHeightSetVar win= twoP_Controls, limits={2,inf,2}
				endif
			else
				isCyclic = 0
				SetVariable LineScanHeightSetVar  win= twoP_Controls,limits={2,inf,2}
			endif
			break
	endswitch
	// now do some checks to ensure even point numbers or nasty NIDAQ drivers will fail
	// 1) Need to acquire an even number of data points (pixHeight x pixWidth x number of frames)
	// 2) Need to output an even number of points for galvo waves (pix height x total pixWidth (including turnaround/flyback))
	// 3) If biderectional scanning, need to have even number of lines in each frame for symetrical collection on flyback
	variable galvoPnts=PixWidthTotal * PixHeight
	// Need to have even number of lines for symetrical collection on flyback, if bidirectional scanning
	if (FlybackMode == 1)
		if (mod (PixHeight, 2))
			PixHeight += 1
		endif
	endif
	variable iTries
	// because there is not a 1-1 relationship between adding an input pixel and adding an output galvo point (flyback and turnaround)
	// adding a single point may not be enough. 10 should be more than enough, or else something is wrong 
	for (iTries =0;(iTries < 10 && ((mod (galvoPnts, 2)) || (mod ((pixWidth * PixHeight * NumFrames), 2))));iTries += 1)
		pixWidth += 1
		if (FlybackMode == 0)
			PixWidthTotal = round (Pixwidth/DutyCycle) + round (Pixwidth*FlyBackProp/DutyCycle)
		else
			PixWidthTotal = round (Pixwidth/DutyCycle)
		endif
		galvoPnts = PixWidthTotal * PixHeight
	endfor
	if (iTries == 10)
		doAlert 0, "Was not able to adjust pixel width to satisfy  constraints."
		return 1
	endif
	// Set line time by multiplying pixels in a line by pixel time, as we may have changed number of pixels in a line
	LineTime = (PixWidthTotal) * PixTime
	//Set Frame time by multiplying line time by number of lines
	switch (scanMode)
		case kLiveMode:
			FrameTime = (LineTime * PixHeight)
			RunTime = INF
			break
		case kTimeSeries:
			FrameTime = (LineTime * PixHeight)
			RunTime = (FrameTime * NumFrames)
			break
		case kZseries:
			NVAR ZFrames = root:Packages:twoP:Acquire:NumZseriesFrames
			FrameTime = (LineTime * PixHeight) * NumZSeriesAvg
			RunTime = (FrameTime * ZFrames)
			break
		case kSingleImage:
			FrameTime = (LineTime * PixHeight)
			NVAR numAvgFrames = root:packages:twoP:Acquire:NumAverageFrames
			RunTime = (FrameTime * numAvgFrames)
			break
		case kLineScan:
			RunTime = FrameTime
			break
	endSwitch
	// check ePhys situation
	NVAR ePhysChans =  root:Packages:twoP:Acquire:ePhysAdjChans
	if (ePhysChans > 0)
		NVAR ePhysIsCyclic = root:packages:twoP:Acquire:ePhysisCyclic
		NVAR ePhysFreq = root:Packages:twoP:Acquire:ePhysFreq
		if (runTime *ePhysFreq > 2^24)
			ePhysIsCyclic = 1
			NVAR ePhysBufferSize = root:packages:twoP:acquire:ePhysBufferSize
			variable nTransfers = round ((runTime *ePhysFreq)/ePhysBufferSize)
			ePhysBufferSize = (runTime *ePhysFreq)/nTransfers
			if (mod(ePhysBufferSize, 2))
				ePhysBufferSize += 1
			endif
		else
			ePhysIsCyclic = 0
		endif
	endif
	//Set times for triggers
	NVAR DelayFrames1 = root:Packages:twoP:Acquire:DelayFrames1
	NVAR DelayFrames2 = root:Packages:twoP:Acquire:DelayFrames2
	NVAR DelayFramesSecs1 = root:Packages:twoP:Acquire:DelayFramesSec1
	NVAR DelayFramesSecs2 = root:Packages:twoP:Acquire:DelayFramesSec2
	NVAR DelayLines1 = root:Packages:twoP:Acquire:DelayLines1
	NVAR DelayLines2 = root:Packages:twoP:Acquire:DelayLines2
	NVAR  DelayLinesSecs1 = root:Packages:twoP:Acquire:DelayLinesSec1
	NVAR DelayLinesSecs2 = root:Packages:twoP:Acquire:DelayLinesSec2
	DelayFramesSecs1 = DelayFrames1 * FrameTime
	DelayFramesSecs2 = DelayFrames2 * FrameTime
	DelayLinesSecs1 =  DelayLines1 * LineTime
	DelayLinesSecs2 =  DelayLines2 * LineTime
	// set run time string
	SVAR runTimeStr = root:Packages:twoP:Acquire:RunTimeStr
	if (scanMode ==kLiveMode)
		runTimeSTr = "INF"
	else
		if (runTime < 60)
			sprintf runTimeStr, "%.3W1Ps", runTime
		else
			runTimeStr =Secs2Time(runTime, 5, 1)
		endif
	endif
	// update Live scan str, without calling stage procedure
	STRUCT NQ_ScanStruct s
	NQ_LoadScanStruct (s, 0)
	NQ_ScanNoter (s, "root:packages:twoP:Acquire:LiveModeScanStr")
end

//*************************************************************************************************************************************
// converts trigger seconds to frames
Function NQ_TrigSecsFrameProc (sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
 
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			//Set number of frames for given seconds for triggers
			NVAR FrameTime = root:Packages:twoP:acquire:FrameTime
			NVAR DelayFrames1 = root:Packages:twoP:Acquire:DelayFrames1
			NVAR DelayFrames2 = root:Packages:twoP:Acquire:DelayFrames2
			NVAR DelayFramesSecs1 = root:Packages:twoP:Acquire:DelayFramesSec1
			NVAR DelayFramesSecs2 = root:Packages:twoP:Acquire:DelayFramesSec2
			DelayFrames1 = DelayFramesSecs1/FrameTime
			DelayFrames2 = DelayFramesSecs2/FrameTime
			break
	endswitch
	return 0
End

//*************************************************************************************************************************************
// converts trigger seconds to number of lines for a l inescan
Function NQ_TrigSecsLinesProc (sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
 
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			//Set number of frames for given seconds for triggers
			NVAR LineTime = root:Packages:twoP:acquire:LineTime
			NVAR DelayLines1 = root:Packages:twoP:Acquire:DelayLines1
			NVAR DelayLines2 = root:Packages:twoP:Acquire:DelayLines2
			NVAR  DelayLinesSecs1 = root:Packages:twoP:Acquire:DelayLinesSec1
			NVAR DelayLinesSecs2 = root:Packages:twoP:Acquire:DelayLinesSec2
			DelayLines1 = DelayLinesSecs1/LineTime
			DelayLines2= DelayLinesSecs2/LineTime	
			break
	endswitch
	return 0
End

//*************************************************************************************************************************************
// looks at times for an ephys scan to see if there are more than 2^24 points and calculates size of  buffer if needed
// Last Modified Nov 22 2010 by Jamie Boyd
Function NQ_ePhysTimeProc (sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
 
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			NVAR isCyclic = root:packages:twoP:Acquire:ePhysisCyclic
			NVAR ePhysFreq = root:Packages:twoP:Acquire:ePhysFreq
			NVAR ePhysOnlyTime = root:Packages:twoP:Acquire:ePhysOnlyTime
			
			if (sva.dval *ePhysFreq > 2^24)
				doAlert 1,  "Number of points requested is greater than the 2^24 bit buffer for points/channel. You are entering the \"Cyclic Zone\". O.K.?"
				if (V_flag == 1) // Yes was clicked
					isCyclic =1
					NVAR ePhysBufferSize = root:packages:twoP:acquire:ePhysBufferSize
					ePhysBufferSize = round (ePhysFreq*(ePhysOnlyTime/kNQtBufferTime))
					if (mod (ePhysBufferSize,2))
						ePhysBufferSize += 1
					endif
					ePhysOnlyTime = round (ePhysOnlyTime * ePhysFreq/ePhysBufferSize) * ePhysBufferSize / ePhysFreq
				else
					isCyclic = 0
					print  "Number of points has been adjusted to accomodate the 2^24 bit limit on points/channel."
					ePhysOnlyTime = round (2^24/ePhysFreq)-2
				endif
			endif
			break
	endswitch
	return 0
End

//*************************************************************************************************************************************
//Changing the aspect ratio involves manipulating either pixel width/height or image extent 
// Last Modified Jul 21 2011 by Jamie
Function NQ_AspectRatioProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			variable self = (cmpStr (sva.ctrlName, "AspRatSetVar") == 0)
			NQ_AspectRatio (self)
	endswitch
	return 0
End

Function NQ_AspectRatio (self)
	variable self
	// Dont mess around with setting aspect ratio if using Line Scan Mode, as it would be meaningless
	NVAR ScanModeG = root:packages:twoP:acquire:scanMode
	variable scanMode=abs (scanModeG)
	if (scanMode == kLineScan)
		return 0
	endif
	// Global variables
	NVAR AspectRatio = root:Packages:twoP:acquire:AspectRatio
	NVAR PixWidth = root:Packages:twoP:acquire:PixWidth
	NVAR PixHeight = root:Packages:twoP:acquire:PixHeight
	NVAR XSV = root:Packages:twoP:acquire:XStartVolts
	NVAR XEV = root:Packages:twoP:acquire:XEndVolts
	NVAR YSV = root:Packages:twoP:acquire:YStartVolts
	NVAR YEV =root:Packages:twoP:acquire:YEndVolts
	// Adjust a value (as chosen in pomenu) to keep aspect ratio constant
	// NOTE: this code has not been updated for possibility that X magnification is different from Y magnification, which would be rare, I admit
	ControlInfo/w = twoP_Controls AspRatPopUp
	Switch (V_Value)
		case 1:	//Changing X-volts start
			XSV =  XEV -  ((Pixwidth * (YEV - YSV))/(PixHeight * AspectRatio))
			if (XSV < kNQxVoltStart)
				XSV = kNQxVoltStart
				PixWidth = round ((AspectRatio * pixheight * (XEV - XSV))/(YEV - YSV))
			endif
			break
		case 2:	// Changing X volts end
			XEV =  ((Pixwidth * (YEV - YSV))/(PixHeight * AspectRatio)) + XSV
			if (XEV > kNQxVoltEnd)
				XEV = kNQxVoltEnd
				PixWidth = round ((AspectRatio * pixheight * (XEV - XSV))/(YEV - YSV))
			endif
			break
		case 3:	// CHanging X pixels
			PixWidth = round ((AspectRatio * pixheight * (XEV - XSV))/(YEV - YSV))
			break
		case 4:		//Changing Y-volts Start
			YSV =  YEV - ((AspectRatio * PixHeight * (XEV - XSV))/PixWidth)
			if (YSV < kNQyVoltStart)
				YSV = kNQyVoltStart
				pixheight = round (((PixWidth * (yev - ysv))/(AspectRatio * (Xev - XSV))))
			endif
			break
		case 5:		// Changing Y volts end
			YEV =  ((AspectRatio * PixHeight * (XEV - XSV))/ PixWidth) + YSV
			if (YEV > kNQyVoltEnd)
				YEV = kNQyVoltEnd
				pixheight = round (((PixWidth * (yev - ysv))/(AspectRatio * (Xev - XSV))))
			endif
			break
		case 6:		//Changing Y-pixels
			pixheight = round (((PixWidth * (yev - ysv))/(AspectRatio * (Xev - XSV))))
			break
		Case 7:		// Don't hold aspect ratio constant - just calculate new Aspect Ratio .  This doesn't make sense  when called by aspect ratio setvar, so test for it
			if (!(self))
				AspectRatio = ((YEV - YSV)/PixHeight)	/ ((XEV-XSV)/PixWidth)
			endif
			break
	endswitch
end

//*************************************************************************************************************************************
// disables the control linked to the variable that will be automatically adjusted
// Last Modified 2015/04/15 by Jamie Boyd
Function NQ_AspRatPopUpProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			setvariable XStartSetVar win = twoP_Controls, disable = SelectNumber((cmpStr (pa.popStr,  "Vary X Start") == 0) , 0, 2)
			setvariable XEndSetVar win = twoP_Controls, disable = SelectNumber((cmpStr (pa.popStr,  "Vary X  End") == 0) , 0, 2)
			setvariable PixWidSetVar win = twoP_Controls, disable = SelectNumber((cmpStr (pa.popStr,  "Vary X Pix") == 0) , 0, 2)
			setvariable YStartSetVar win = twoP_Controls, disable = SelectNumber((cmpStr (pa.popStr,  "Vary Y Start") == 0) , 0, 2)
			setvariable YEndSetVar win = twoP_Controls, disable = SelectNumber((cmpStr (pa.popStr,  "Vary Y End") == 0) , 0, 2)
			setvariable PixHeightSetVar win = twoP_Controls, disable = SelectNumber((cmpStr (pa.popStr,  "Vary Y Pix") == 0) , 0, 2)
			setvariable AspRatSetVar win = twoP_Controls, disable =  SelectNumber((cmpStr (pa.popStr,  "Free") == 0) , 0, 2)
			break
	endswitch
	return 0
End

//*************************************************************************************************************************************
// Sets the global variables for volts, pixels, and distance to full scalaing as defined in constants
// Last Modified May 26 2009 by Jamie Boyd
Function NQ_SetFullScaleProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// Global variables
			NVAR XStartVoltage = root:Packages:twoP:acquire:XStartVolts
			NVAR XEndVoltage = root:Packages:twoP:acquire:XEndVolts
			NVAR YStartVoltage = root:Packages:twoP:acquire:YStartVolts
			NVAR YEndVoltage =root:Packages:twoP:acquire:YEndVolts
			NVAR PixWidth = root:Packages:twoP:acquire:PixWidth
			NVAR PixHeight = root:Packages:twoP:acquire:PixHeight
			NVAR AspectRatio = root:Packages:twoP:acquire:AspectRatio
			// Global variables for backup copies for reverting
			NVAR XStartVoltageBU = root:Packages:twoP:acquire:XStartVoltsBU
			NVAR XEndVoltageBU = root:Packages:twoP:acquire:XEndVoltsBU
			NVAR YStartVoltageBU = root:Packages:twoP:acquire:YStartVoltsBU
			NVAR YEndVoltageBU =root:Packages:twoP:acquire:YEndVoltsBU
			NVAR PixWidthBU = root:Packages:twoP:acquire:PixWidthBU
			NVAR PixHeightBU = root:Packages:twoP:PixHeightBU
			// First save current values in backup copies
			XStartVoltageBU = xStartVoltage
			XEndVoltageBU = XEndVoltage
			YStartVoltageBU = yStartVoltage
			yEndVoltageBU = yEndVoltage
			PixWidthBU = pixWidth
			pixHeightBU = pixHeight
			// Set current values to constants
			xStartVoltage = kNQxVoltStart
			xEndVoltage = kNQxVoltEnd
			yStartVoltage = kNQyVoltStart
			yEndVoltage = kNQyVoltEnd
			PixWidth = kNQhPix
			PixHeight = kNQvPix
			// Set Aspect Ratio to 1 and run Set Times
			AspectRatio = 1
			NQ_SetTimes()
	endswitch
	return 0
End

//*************************************************************************************************************************************
// Runs setTimes Procedure when (Bi-directional scanning)Turbo is checked/unchecked. The global variable, root:packages:twoP:acquire:FlybackMode,
// is set automatically by Igor
// Last Modified Jul 24 2011 by Jamie Boyd
Function NQ_TurboCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			if (cba.checked)
				CheckBox TurboCheck win= twoP_Controls, title="Bi-Directional Scan is ON"
			else
				CheckBox TurboCheck win= twoP_Controls, title="Bi-Directional Scan is OFF"
			endif
			NQ_SetTimes()
			break
	endswitch

	return 0
End

//*************************************************************************************************************************************
// Sets the scaling of the volts and pixels to the backup values saved the last time they were changed, for an image scan
// Last Modified Oct 27 2009 by Jamie Boyd
Function NQ_RevertScaleProc (ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// Global variables for current values
			NVAR XStartVoltage = root:Packages:twoP:acquire:XStartVolts
			NVAR XEndVoltage = root:Packages:twoP:acquire:XEndVolts
			NVAR YStartVoltage = root:Packages:twoP:acquire:YStartVolts
			NVAR YEndVoltage =root:Packages:twoP:acquire:YEndVolts
			NVAR PixWidth = root:Packages:twoP:acquire:PixWidth
			NVAR PixHeight = root:Packages:twoP:acquire:PixHeight
			NVAR AspectRatio = root:Packages:twoP:acquire:AspectRatio
			// Backup copies
			NVAR XStartVoltageBU = root:Packages:twoP:acquire:XStartVoltsBU
			NVAR XEndVoltageBU = root:Packages:twoP:acquire:XEndVoltsBU
			NVAR YStartVoltageBU = root:Packages:twoP:acquire:YStartVoltsBU
			NVAR YEndVoltageBU =root:Packages:twoP:acquire:YEndVoltsBU
			NVAR PixWidthBU = root:Packages:twoP:acquire:PixWidthBU
			NVAR PixHeightBU = root:Packages:twoP:acquire:PixHeightBU
			// Local variables for swapping current values with backups
			variable XStartVoltageTemp, XEndVoltageTemp, YStartVoltageTemp, YEndVoltageTemp, PixWidthTemp, PixHeightTemp
			// Put current values in temp values
			XStartVoltageTemp = XStartVoltage
			XEndVoltageTemp = XEndVoltage
			YStartVoltageTemp = YStartVoltage
			YEndVoltageTemp = YEndVoltage
			PixWidthTemp = PixWidth
			PixHeightTemp = PixHeight
			// Replace backup values with current values
			XStartVoltage = XStartVoltageBU
			YStartVoltage = YStartVoltageBU
			XEndVoltage = XEndVoltageBU
			YEndVoltage = YEndVoltageBU
			PixWidth = PixWidthBU
			PixHeight = PixHeightBU
			// Save previous backup values from temp
			XStartVoltageBU = XStartVoltageTemp
			YStartVoltageBU = YStartVoltageTemp
			XEndVoltageBU = XEndVoltageTemp
			YEndVoltageBU = YEndVoltageTemp
			PixWidthBU = PixWidthTemp
			PixHeightBU = PixHeightTemp
			// Set Aspect ratio to width/height and Run Set Times Proc
			AspectRatio = PixWidth/PixHeight
			NQ_SetTimes()
			break
	endswitch
	return 0
end

//*************************************************************************************************************************************
// Reverts scaling to that of a wave selected from the image scans in the Scans Folder
// Last Modified Oct 11 2009 by Jamie Boyd
Function RevertSettingstoWaveProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String theScan = pa.popStr
			if (cmpStr (theScan, "LiveWave") == 0)
				SVAR scanStr = root:packages:twoP:Acquire:LiveModeScanStr
			else
				SVAR scanStr = $"root:twoP_Scans:" + theScan + ":" + theScan + "_info"
			endif
			// Globals to reset		
			NVAR PixWidth = root:Packages:twoP:acquire:PixWidth
			NVAR PixHeight = root:Packages:twoP:acquire:PixHeight
			NVAR XSV = root:Packages:twoP:acquire:XStartVolts
			NVAR YSV = root:Packages:twoP:acquire:YStartVolts
			NVAR XEV = root:Packages:twoP:acquire:XEndVolts
			NVAR YEV =root:Packages:twoP:acquire:YEndVolts
			NVAR AspectRatio = root:Packages:twoP:acquire:AspectRatio
			// BAckup copies to allow user to revert
			NVAR PixWidthBU = root:Packages:twoP:acquire:PixWidthBU
			NVAR PixHeightBU = root:Packages:twoP:acquire:PixHeightBU
			NVAR XSVBU = root:Packages:twoP:acquire:XStartVoltsBU
			NVAR XEVBU = root:Packages:twoP:acquire:XEndVoltsBU
			NVAR YSVBU = root:Packages:twoP:acquire:YStartVoltsBU
			NVAR YEVBU =root:Packages:twoP:acquire:YEndVoltsBU
			// Set Backup values to current values
			PixWidthBU = PixWidth
			PixHeightBU = PixHeight
			XSVBU = XSV
			XEVBU = XEV
			YSVBU = YSV
			YEVBU = YEV
			// Set current values to those read from wave and from waveNote
			XSV = NumberByKey("XSV", scanStr, ":", "\r")
			XEV = NumberByKey("XEV", scanStr, ":", "\r")
			YSV = NumberByKey("YSV", scanStr, ":", "\r")
			YEV = NumberByKey("YEV", scanStr, ":", "\r")
			pixHeight =  NumberByKey("pixHeight", scanStr, ":", "\r")
			pixWidth = NumberByKey("pixWidth", scanStr, ":", "\r")
			// Set Aspect ratio to width/height and Run Set Times Proc
			AspectRatio =  NumberByKey("xPixSize", scanStr, ":", "\r")/ NumberByKey("yPixSize", scanStr, ":", "\r")
			NQ_SetTimes()
			break
	endswitch
	return 0
End


//*************************************************************************************************************************************
// Sets globals for chosen objective. Changes in Image size and Pixel Size are handled by dependency formula set in AddAcquireControls function
// Last Modified 2016/10/12 by Jamie Boyd
Function NQ_ObjPopProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			// set globals for chosen objective
			SVAR curObj = root:packages:twoP:acquire:CurObj
			NVAR curXscal = root:packages:twoP:curObjXscal
			NVAR curXOffset = root:packages:twoP:curObjXOffset
			NVAR curYscal = root:packages:twoP:curObjYscal
			NVAR curYOffset = root:packages:twoP:curObjYOffset
			WAVE/T ObjWave = root:packages:twoP:acquire:ObjWave
			curObj = pa.popStr
			NVAR curObjNum = root:packages:twoP:Acquire:CurObjNum
			curObjNum = pa.popNum -1 // -1 for one, not zero based popNum
			curXscal = str2num (ObjWave[pa.popNum-1] [1])
			curYscal = str2num (ObjWave[pa.popNum-1] [2])
			curXOffset = str2num (ObjWave[pa.popNum-1] [3])
			curYOffset = str2num (ObjWave[pa.popNum-1] [4])
			
			break
	endswitch
	return 0
End

//*************************************************************************************************************************************
// Returns a list of objective names stored in objwave
// Last Modified May 30 2009 by Jamie Boyd
Function/S NQ_ListObjs()
	
	WAVE/T ObjWave = root:Packages:twoP:Acquire:ObjWave
	string objList = ""
	variable iObj, nObjs = dimsize (ObjWave,0)
	for (iObj=0;iObj<nObjs;iObj+=1)
		objList += ObjWave [iObj] [0]+ ";"
	endfor
	return objList
end

//*************************************************************************************************************************************
// Sets the scaling of the volts and pixels to the backup values saved the last time they were changed, for a line scan
// Last Modified Oct 27 2009 by Jamie Boyd
Function NQ_LSRevertScaleProc (ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// current values
			NVAR LSStartVoltage = root:packages:twoP:Acquire:LSStartVoltage
			NVAR LSEndVoltage = root:packages:twoP:Acquire:LSEndVoltage
			NVAR LSYVoltage = root:packages:twoP:Acquire:LSYVoltage
			NVAR LSWidth = root:packages:twoP:Acquire:LSWidth
			NVAR LSHeight = root:packages:twoP:Acquire:LSHeight
			// back up copies
			NVAR LSStartVoltageBU = root:packages:twoP:Acquire:LSStartVoltageBU
			NVAR LSEndVoltageBU = root:packages:twoP:Acquire:LSEndVoltageBU
			NVAR LSYVoltageBU = root:packages:twoP:Acquire:LSYVoltageBU
			NVAR LSWidthBU = root:packages:twoP:Acquire:LSWidthBU
			NVAR LSHeightBU = root:Packages:twoP:Acquire:LSHeightBU
			// need temp variables to swap values between current and backup
			variable LSStartVoltagetemp, LSEndVoltagetemp, LSYVoltagetemp, LSWidthtemp, LSHeighttemp
			// save current values in temp variables
			LSStartVoltagetemp = LSStartVoltage
			LSEndVoltagetemp = LSEndVoltage
			LSYVoltagetemp = LSYVoltage
			LSWidthtemp = LSWidth
			LSHeighttemp = LSHeight
			// set current values to backed up values
			LSStartVoltage = LSStartVoltageBU
			LSEndVoltage = LSEndVoltageBU
			LSYVoltage = LSYVoltageBU
			LSWidth = LSWidthBU
			LSHeight = LSHeightBU
			// set backed up values to current values saved in temp variables
			LSStartVoltageBU = LSStartVoltagetemp
			LSEndVoltageBU = LSEndVoltagetemp
			LSYVoltageBU = LSYVoltagetemp
			LSWidthBU = LSWidthtemp
			LSHEightBU = LSHeighttemp
			// run set Times proc
			NQ_SetTimes()
			break
	endswitch
	return 0
End

//*************************************************************************************************************************************
// Reverts scaling to that of a wave selected from the Line scans in the Scans Folder
// Last Modified Oct 27 2009 by Jamie Boyd
Function NQ_RevertSettingstoLineScanProc (pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			string theScan = pa.popStr
			SVAR scanStr = $"root:twoP_Scans:" + theScan + ":" + theScan + "_info"
			// Current Values
			NVAR LSStartVoltage = root:packages:twoP:Acquire:LSStartVoltage
			NVAR LSEndVoltage = root:packages:twoP:Acquire:LSEndVoltage
			NVAR LSYVoltage = root:packages:twoP:Acquire:LSYVoltage
			NVAR LSWidth = root:packages:twoP:Acquire:LSWidth
			NVAR LSHeight = root:packages:twoP:Acquire:LSHeight
			// Backed up values
			NVAR LSStartVoltageBU = root:packages:twoP:Acquire:LSStartVoltageBU
			NVAR LSEndVoltageBU = root:packages:twoP:Acquire:LSEndVoltageBU
			NVAR LSYVoltageBU = root:packages:twoP:Acquire:LSYVoltageBU
			NVAR LSWidthBU = root:packages:twoP:Acquire:LSWidthBu
			NVAR LSHeightBU = root:packages:twoP:Acquire:LSHeightBU
			// Set Backup values to current values
			LSWidthBU = LSWidth
			LSHeightBU = LSHeight
			LSStartVoltageBU = LSStartVoltage
			LSEndVoltageBU = LSEndVoltage
			LSYVoltageBU = LSYVoltageBU
			// Set current values to those read from wave and from waveNote
			LSStartVoltage = NumberByKey("XSV", scanStr, ":", "\r")
			LSEndVoltage = NumberByKey("XEV", scanStr, ":", "\r")
			LSYVoltage = NumberByKey("YSV", scanStr, ":", "\r")
			LSHeight =  NumberByKey("pixHeight", scanStr, ":", "\r")
			LSWidth = NumberByKey("pixWidth", scanStr, ":", "\r")
			// Run Set Times Proc
			NQ_SetTimes()
			break
	endswitch
	return 0
End


//******************************************************************************************************
// Changes a global string to the name of a wave that a linescan was drawn on (or Don't Link, if no Image Wave was selected).
// The string will be used to make an entry in the wavenote of the LineScan Wave
// Last Modified Jun 01 2009 by Jamie Boyd
Function NQ_LineScanLinkToProc (pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			SVAR LinKWave = root:Packages:twoP:Acquire:LSLinkWaveStr
			LinKWave = pa.popStr
			break
	endswitch
	return 0
End

//******************************************************************************************************
// CheckBox procedure for which voltage pulse channels are selected
// Last Modified Jun 09 2009 by Jamie Boyd
Function NQ_VoltageCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			NQ_SetVoltagePulseChans ()
	endswitch

	return 0
End

//******************************************************************************************************
// PopMenu procedure for which voltage pulse channels are selected
// Last Modified Jun 09 2009 by Jamie Boyd
Function NQ_VoltageWavePopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			NQ_SetVoltagePulseChans ()
			break
	endswitch

	return 0
End

//******************************************************************************************************
// Sets a global variable for which voltage pulse channels are selected for the upcoming scan
// Last Modified Jun 09 2009 by Jamie Boyd
Function NQ_SetVoltagePulseChans ()
	
	NVAR voltagePulseChans = root:packages:twoP:Acquire:voltagePulseChans
	voltagePulseChans = 0
	// channel 1
	controlinfo/w=twoP_Controls Voltage1Check
	// it's checked, but do we have a wave?
	if (V_Value)
		controlinfo/w=twoP_Controls VoltagePulse1Popup
		wave/Z theWave = $"root:Packages:twoP:Acquire:VoltagePulseWaves:" + S_Value
		if (waveExists (theWave))
			voltagePulseChans = 1
		endif
	endif
	// channel 2
	controlinfo/w=twoP_Controls Voltage2Check
	// it's checked, but do we have a wave?
	if (V_Value)
		controlinfo/w=twoP_Controls VoltagePulse2Popup
		wave/Z theWave = $"root:Packages:twoP:Acquire:VoltagePulseWaves:" + S_Value
		if (waveExists (theWave))
			voltagePulseChans += 2
		endif
	endif
end

//******************************************************************************************************
// Functins for voltage waves have not been updated since pre-2009, but they look O.K.
Function EditVoltageWavesProc(ctrlName) : ButtonControl
	String ctrlName
	
	DoWindow/F VoltageWavesEditor
	if (V_Flag == 1)
		return -1
	endif
	display/k=1/W=(69,110,610,415) as "VoltageWavesEditor"
	dowindow/C VoltageWavesEditor
	ControlBar 85
	Button NewSegmentButton,pos={150,30},size={96,19},proc=VoltageAddSegmentProc,title="Add Segment"
	CheckBox StraightCheck,pos={260,3},size={55,14},proc=VoltageModeCheckProc,title="Straight"
	CheckBox StraightCheck,value= 1,mode=1
	CheckBox SquareCheck,pos={260,19},size={49,14},proc=VoltageModeCheckProc,title="Square"
	CheckBox SquareCheck,value= 0,mode=1
	CheckBox SineCheck,pos={260,34},size={37,14},proc=VoltageModeCheckProc,title="Sine"
	CheckBox SineCheck,value= 0,mode=1
	PopupMenu EditVoltagePulsePopup,pos={15,4},size={99,20},proc=EditVoltageWaveProc,title="Now Editing:"
	PopupMenu EditVoltagePulsePopup,mode=0,value= #"\"New Voltage Wave;\\\\M1-;\" + GUIPListObjs ((\"root:packages:twoP:acquire:VoltagePulseWaves\") , 1, \"*\", 0, \"\\M1(No Voltage Pulse Waves\")"
	SetVariable FreqSetVar,pos={310,36},size={112,15},title="Frequency"
	SetVariable FreqSetVar,format="%g Hz"
	SetVariable FreqSetVar,limits={0,100,1},value= root:packages:twoP:Acquire:VoltagePulseFreq
	SetVariable HeightSetVar,pos={328,18},size={94,15},title="Height",format="%5.3f V"
	SetVariable HeightSetVar,limits={-10,10,0.1},value= root:packages:twoP:Acquire:VoltagePulseHeight
	TitleBox EditTitle,pos={116,5},size={32,20}
	TitleBox EditTitle,variable= root:packages:twoP:Acquire:VoltagePulseEditWave
	SetVariable X1SetVar,pos={9,59},size={95,15},title="Time 1",format="%5.3f Sec",proc=VoltageWaveCsrSetVarProc, live = 1
	SetVariable X1SetVar,limits={0,inf,0.1},value= root:packages:twoP:Acquire:VoltagePulseX1
	SetVariable X2SetVar,pos={111,59},size={95,15},title="Time 2",format="%5.3f Sec",proc=VoltageWaveCsrSetVarProc, live = 1
	SetVariable F1SetVar,pos={8,59},size={95,15},proc=VoltageFramesSetVarProc,title="Frames 1"
	SetVariable F1SetVar,limits={0,inf,1},value= root:packages:twoP:Acquire:VoltagePulseF1,live= 1, disable =1
	SetVariable F2SetVar,pos={111,59},size={95,15},proc=VoltageFramesSetVarProc,title="Frames 1"
	SetVariable F2SetVar,limits={0,inf,1},value= root:packages:twoP:Acquire:VoltagePulseF2,live= 1, disable =1
	SetVariable X2SetVar,limits={0,inf,0.1},value= root:packages:twoP:Acquire:VoltagePulseX2
	SetVariable Y1SetVar,pos={214,59},size={96,15},title="Voltage 1",format="%5.3f V",proc=VoltageWaveCsrSetVarProc, live = 1
	SetVariable Y1SetVar,limits={-10,10,0.1},value= root:packages:twoP:Acquire:VoltagePulseY1
	SetVariable Y2SetVar,pos={318,58},size={105,15},title="Voltage 2",format="%5.3f V",proc=VoltageWaveCsrSetVarProc, live = 1
	SetVariable Y2SetVar,limits={-10,10,0.1},value= root:packages:twoP:Acquire:VoltagePulseY2
	Button KillButton,pos={81,28},size={50,20},proc=VoltageKillProc,title="Kill"
	Button RemoveButton,pos={15,28},size={64,20},proc=VoltageRemoveProc,title="Remove"
	CheckBox FrameAxisCheck,pos={323,1},size={114,14},proc=VoltageAxisProc,title="X-axis as FrameTime",value= 0
	//Set voltage wavestring to empty string
	SVAR VoltageWaveStr = root:packages:twoP:acquire:VoltagePulseEditWave
	VoltageWaveStr = ""
	//Install hook function for Cursor updates
	SetWindow kwTopWin, hook = VoltageEditHook, hookevents = 5
End

//******************************************************************************************************
Function VoltageWaveCsrSetVarProc(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	SVAR VoltageWaveStr = root:packages:twoP:acquire:VoltagePulseEditWave
	if (((cmpstr (ctrlname,  "X1SetVar" ))==0) || ((cmpstr (ctrlname,  "Y1SetVar")) ==0))
		NVAR VoltagePulseY1= root:packages:twoP:Acquire:VoltagePulseY1
		NVAR VoltagePulseX1= root:packages:twoP:Acquire:VoltagePulseX1
		Cursor/F/H=1 A $VoltageWaveStr VoltagePulseX1,VoltagePulseY1
	else
		NVAR VoltagePulseY2= root:packages:twoP:Acquire:VoltagePulseY2
		NVAR VoltagePulseX2= root:packages:twoP:Acquire:VoltagePulseX2
		Cursor/F/H=1 B $VoltageWaveStr VoltagePulseX2,VoltagePulseY2
	endif
End

//******************************************************************************************************
Function VoltageFramesSetVarProc(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
		
	
	SVAR VoltageWaveStr = root:packages:twoP:acquire:VoltagePulseEditWave
	NVAR FrameTime = root:packages:twoP:Acquire:FrameTime
	if (((cmpstr (ctrlname,  "F1SetVar" ))==0) || ((cmpstr (ctrlname,  "Y1SetVar")) ==0))
		NVAR VoltagePulseY1= root:packages:twoP:Acquire:VoltagePulseY1
		NVAR VoltagePulseX1= root:packages:twoP:Acquire:VoltagePulseX1
		NVAR VoltagePulseF1 = root:packages:twoP:Acquire:VoltagePulseF1
		VoltagePulseX1 = VoltagePulseF1 * FrameTime
		Cursor/F/H=1 A $VoltageWaveStr VoltagePulseX1,VoltagePulseY1
	else
		NVAR VoltagePulseY2= root:packages:twoP:Acquire:VoltagePulseY2
		NVAR VoltagePulseX2= root:packages:twoP:Acquire:VoltagePulseX2
		NVAR VoltagePulseF2 = root:packages:twoP:Acquire:VoltagePulseF2
		VoltagePulseX2 = VoltagePulseF2 * FrameTime
		Cursor/F/H=1 B $VoltageWaveStr VoltagePulseX2,VoltagePulseY2
	endif
End

//******************************************************************************************************
Function EditVoltageWaveProc(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	
	if ((Cmpstr (popstr, "New Voltage Wave")) == 0)
		//make a new wave
		string newname = "Wave Name"
		variable length = 30
		variable scaling = .001
		Prompt newname, "Name for New Voltage Wave" 
		Prompt length, "Length (in seconds) of New Voltage Wave"
		Prompt scaling, "Point Scalng (in seconds) of New Voltage Wave"
		DoPrompt "Make New Voltage wave", newname, length, scaling
		if (V_Flag)
			return 0
		endif
		newname =  CleanupName(newname, 0 )
		make/o/n= (length/scaling) $"root:Packages:twoP:acquire:VoltagePulseWaves:" + newName
		WAVE theWave =  $"root:Packages:twoP:acquire:VoltagePulseWaves:" + newName
		SetScale/P x 0,(scaling),"", theWave
		popStr = newname
	endif
	SVAR EditWave=root:packages:twoP:acquire:VoltagePulseEditWave
	EditWave = PopStr
	wave theWave = $"root:packages:twoP:acquire:VoltagePulseWaves:" + EditWave
	//appendwave to graph if not appended already
	string TracesList =  GUIPListWavesFromGraph ("", "*", 0, 1, "")
	if (WhichListItem(EditWave,TracesList) == -1)
		AppendToGraph theWave
		//if there were no traces on graph, do axes
		if ((cmpstr (TracesList, "\\M1(No Waves")) == 0)
			setaxis left -10, 10
			ModifyGraph grid=1
			ModifyGraph mirror=2
			ModifyGraph nticks(left)=10,nticks(bottom)=30
			Label left "Volts"
			Label bottom "Seconds"
		endif
	endif
	Cursor/F/H=1 A $EditWave 0,0
	Cursor/F/H=1 B $EditWave 0,1
	setaxis bottom 0, (rightx(thewave))
End

//******************************************************************************************************
Function VoltageModeCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	StrSwitch (ctrlname)
		case "StraightCheck":
			CheckBox SineCheck value = 0
			CheckBox SquareCheck value = 0
			Setvariable FreqSetVar disable = 1
			Setvariable HeightSetVar disable = 1
			break
		case "SquareCheck":
			CheckBox StraightCheck value = 0
			CheckBox SineCheck value = 0
			Setvariable FreqSetVar disable = 0
			Setvariable HeightSetVar disable = 0
			break
		
		case "SineCheck":
			CheckBox StraightCheck value = 0
			CheckBox SquareCheck value = 0
			Setvariable FreqSetVar disable = 0
			Setvariable HeightSetVar disable = 0
			break
	endswitch
End

//******************************************************************************************************
Function VoltageAxisProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	if (Checked)
		//put up the dummy wave jut so we can have an axis to play with
		NVAR FrameTime = root:packages:twoP:Acquire:FrameTime
		SVAR voltagePulseEditWaveSTr = root:packages:twoP:acquire:Voltagepulseeditwave
		WAVE EditWave = $"root:packages:twoP:Acquire:VoltagePulseWaves:" + voltagePulseEditWaveSTr
		WAVE DummyWave = root:packages:twoP:Acquire:VoltagePulseDummyWave
		//		if ((stringmatch (ListWavesFromGraph ("VoltageWavesEditor", 0, 1), "*VoltagePulseDummyWave*")) == 0)
		//			AppendToGraph/T DummyWave
		//			ModifyGraph lsize(VoltagePulseDummyWave)=0
		//		endif
		ModifyGraph grid(bottom)=0
		ModifyGraph grid(top)=1, nticks (top) = 30
		setaxis top , 0, (rightx(editwave)/FrameTime)
		label top "Frames"
		SetVariable X1SetVar disable =1
		SetVariable X2SetVar disable = 1
		SetVariable F1SetVar disable =0
		SetVariable F2SetVar disable = 0
		//SetWindow kwTopWin, hook = VoltageEditFrameHook, hookevents = 5
		//Cursor/F/H=1 A VoltagePulseDummyWave 0,0
		//Cursor/F/H=1 B VoltagePulseDummyWave 0,1
	else
		ModifyGraph grid(bottom)=1
		//		if ((stringmatch (ListWavesFromGraph ("VoltageWavesEditor", 0, 1), "*VoltagePulseDummyWave*")) == 1)
		//			RemoveFromGraph VoltagePulseDummyWave
		//		endif
		SetVariable X1SetVar disable =0
		SetVariable X2SetVar disable = 0
		SetVariable F1SetVar disable =1
		SetVariable F2SetVar disable = 1
		//SetWindow kwTopWin, hook = VoltageEditHook, hookevents = 5
		//Cursor/F/H=1 A $voltagePulseEditWaveSTr 0,0
		//Cursor/F/H=1 B $voltagePulseEditWaveSTr 0,1
	endif
End

//******************************************************************************************************
Function VoltageAddSegmentProc(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR VoltageWaveStr = root:packages:twoP:acquire:VoltagePulseEditWave
	WAVE VoltageWave = $"root:packages:twoP:acquire:VoltagePulseWaves:" + VoltageWaveStr
	NVAR VoltagePulseY1= root:packages:twoP:Acquire:VoltagePulseY1
	NVAR VoltagePulseX1= root:packages:twoP:Acquire:VoltagePulseX1
	NVAR VoltagePulseY2= root:packages:twoP:Acquire:VoltagePulseY2
	NVAR VoltagePulseX2= root:packages:twoP:Acquire:VoltagePulseX2
	
	if (VoltagePulseX1 > VoltagePulseX2)
		NVAR VoltagePulseY1= root:packages:twoP:Acquire:VoltagePulseY2
		NVAR VoltagePulseX1= root:packages:twoP:Acquire:VoltagePulseX2
		NVAR VoltagePulseY2= root:packages:twoP:Acquire:VoltagePulseY1
		NVAR VoltagePulseX2= root:packages:twoP:Acquire:VoltagePulseX1
	endif
	
	controlinfo StraightCheck
	if (V_Value == 1)	//straightline segment from first point to second point y = mx + b
		variable m = (VoltagePulseY2-VoltagePulseY1)/(VoltagePulseX2 - VoltagePulseX1)
		variable b = VoltagePulseY1 - (m * VoltagePulseX1)
		VoltageWave [x2pnt (VoltageWave, VoltagePulseX1), x2pnt (VoltageWave, VoltagePulseX2)] = m*x + b
	else
		NVAR VoltagePulseFreq = root:packages:twoP:acquire:VoltagePulseFreq
		NVAR VoltagePulseHeight = root:packages:twoP:acquire:VoltagePulseHeight
		controlinfo SquareCheck
		if (V_Value == 1)  //squareWave segment
			VoltageWave [x2pnt (VoltageWave, VoltagePulseX1), x2pnt (VoltageWave, VoltagePulseX2)] = VoltagePulseY1 + VoltagePulseHeight *(trunc (1 + 0.5 * sin (VoltagePulseFreq*(2*pi) *(x-VoltagePulseX1))) -0.5)
		else  //sinwave segment
			VoltageWave [x2pnt (VoltageWave, VoltagePulseX1), x2pnt (VoltageWave, VoltagePulseX2)] = VoltagePulseY1 + VoltagePulseHeight * sin ((VoltagePulseFreq*(2*pi)) * (x-VoltagePulseX1))
		endif
	endif
	
End

//******************************************************************************************************
Function VoltageKillProc(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR VoltageWaveStr = root:packages:twoP:acquire:VoltagePulseEditWave
	WAVE VoltageWave = $"root:packages:twoP:acquire:VoltagePulseWaves:" + VoltageWaveStr
	GUIPKilldisplayedWave (VoltageWave)
	
End

//******************************************************************************************************
Function VoltageRemoveProc(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR VoltageWaveStr = root:packages:twoP:acquire:VoltagePulseEditWave
	removefromgraph $VoltageWaveStr
	VoltageWaveStr = ""
End


//******************************************************************************************************
Function VoltageEditHook (infoStr)
	String infoStr
	
	if ((cmpstr (stringbykey ("EVENT", infoStr), "cursormoved")) ==0)
		NVAR lastCursor =  root:packages:twoP:acquire:VoltagelastCursor
		variable xProp =  numberbykey ("POINT", infostr)
		variable yProp = 1-numberbykey ("YPOINT", infostr)
		if ((cmpstr (stringbykey ("CURSOR", infoStr), "A")) ==0)
			NVAR VoltagePulseY= root:packages:twoP:Acquire:VoltagePulseY1
			NVAR VoltagePulseX= root:packages:twoP:Acquire:VoltagePulseX1
			NVAR VoltagePulseF= root:packages:twoP:Acquire:VoltagePulseF1
			lastCursor = 0
		else
			NVAR VoltagePulseY= root:packages:twoP:Acquire:VoltagePulseY2
			NVAR VoltagePulseX= root:packages:twoP:Acquire:VoltagePulseX2
			NVAR VoltagePulseF= root:packages:twoP:Acquire:VoltagePulseF2
			lastCursor = 1
		endif
		
		NVAR FrameTime = root:packages:twoP:Acquire:Frametime
		SVAR VoltageWaveStr = root:packages:twoP:acquire:VoltagePulseEditWave
		WAVE VoltageWave = $"root:packages:twoP:Acquire:VoltagePulseWaves:" + VoltageWaveStr
		variable xscal = deltax(VoltageWave)
		
		GetAxis/Q left
		VoltagePulsey = round ((V_min + yProp * (V_max - V_min)) /0.1)*0.1
		controlinfo/W = VoltageWavesEditor FrameAxisCheck
		if (V_Value == 0)
			GetAxis /Q bottom
			VoltagePulseX = round ((V_min + xProp * (V_max - V_min))/xscal)*xscal
		else
			GetAxis/Q Top
			VoltagePulseF = round ((V_min +xProp * (V_max - V_min)))
			VoltagePulseX = VoltagePulseF * FrameTime
		endif
		doUpdate
	elseif ((cmpstr (stringbykey ("EVENT", infoStr), "mouseup")) == 0)
		NVAR lastCursor =  root:packages:twoP:acquire:VoltagelastCursor
		GetAxis /Q bottom
		variable xMin = V_min
		variable xmax= V_max
		GetAxis/Q Left
		variable ymin = V_min
		variable ymax = V_max
		SVAR VoltageWaveStr = root:packages:twoP:acquire:VoltagePulseEditWave
		if ((cmpstr (VoltageWaveStr, "") == 0) ||  (WhichListItem(VoltageWaveStr, TraceNameList("VoltageWavesEditor", ";", 1 )) == -1))
			return 0
		endif
		if (lastCursor == 0)
			NVAR VoltagePulseY= root:packages:twoP:Acquire:VoltagePulseY1
			NVAR VoltagePulseX= root:packages:twoP:Acquire:VoltagePulseX1
			Cursor/F/H=1 A $VoltageWaveStr VoltagePulseX,VoltagePulsey
		else
			NVAR VoltagePulseY= root:packages:twoP:Acquire:VoltagePulseY2
			NVAR VoltagePulseX= root:packages:twoP:Acquire:VoltagePulseX2
			Cursor/F/H=1 B $VoltageWaveStr VoltagePulseX,VoltagePulsey
		endif
	endif
	return 0
End


//******************************************************************************************************
//****************Code that does scaning and calls NI functions*********************************
//******************************************************************************************************

//******************************************************************************************************
// Resets the imaging and ePhys boards and sets a few things, or just sets a few things, if fullReset = 0
// Reserves a line for shutter Port 0/0
// Sets Counters used for triggers to low state. The default state, inexplicably, is high
// It's worth noting that every time the boards are reset, a  pulse will be sent on the output pins of the counters
// Last Modified:
// 2017/09/06 by Jamie Boyd added threadgroup release for threads
// 2015/04/13 by Jamie Boyd for Nidaqmx
Function NQ_ResetBoards (FullReset)
	variable fullReset
	
	SVAR ImageBoard = root:packages:twoP:acquire:ImageBoard
	SVAR ephysBoard = root:packages:twoP:acquire:ephysBoard
	NVAR shutterTaskNum = root:packages:twoP:Acquire:shutterTaskNum
	variable err, errPos
	try
		if (CmpStr (ImageBoard, "") != 0)
			if (fullReset)
				fDAQmx_ResetDevice(ImageBoard)
				shutterTaskNum = -1
			endif
			// configure shutter on port 0/line0 and set it closed
			errPos=0
			if (shutterTaskNum >= 0)
				err = fDAQmx_DIO_Finished (ImageBoard, shutterTaskNum) ;AbortOnValue (err), errPos
				shutterTaskNum = -1
			endif
			errPos = 1
			DAQmx_DIO_Config /DEV=ImageBoard/Dir=1/LGRP=1  "/" + ImageBoard + "/port0/line0" ;AbortOnRTE
			shutterTaskNum = V_DAQmx_DIO_TaskNumber
			errPos = 2
			err=fDAQmx_DIO_Write(ImageBoard, shutterTaskNum, (!(kNQshutterOpen)));AbortOnValue (err), errPos
			// set digital triggers low if we are using extra counter/timers on image board
			if ((CmpStr (ImageBoard, ephysBoard) == 0) && (fDAQmx_NumCounters(ImageBoard) >= 4))
				errPos=3
				DAQmx_CTR_OutputPulse /DEV=ImageBoard/SEC={1e-07, 1e-07} /IDLE=0 /NPLS=1/STRT=0  0; ABORTONRTE
				errPos= 4
				DAQmx_CTR_OutputPulse /DEV=ImageBoard/SEC={1e-07, 1e-07} /IDLE=0 /NPLS=1/STRT=0  1; ABORTONRTE
			endif
		endif
		if ((CmpStr (ephysBoard, "") != 0) && (CmpStr (ImageBoard, ephysBoard) != 0))
			if (fullReset)
				fDAQmx_ResetDevice(ePhysBoard)
			endif
			errPos=4
			DAQmx_CTR_OutputPulse /DEV=ephysBoard/KEEP=1 /SEC={1e-07, 1e-07} /IDLE=0 /NPLS=1/STRT=0/OUT="/" + ephysBoard + kNQtrig1Pin  0; ABORTONRTE
			errPos= 5
			DAQmx_CTR_OutputPulse /DEV=ephysBoard/KEEP=1 /SEC={1e-07, 1e-07} /IDLE=0 /NPLS=1/STRT=0/OUT="/" + ephysBoard + kNQtrig2Pin  1; ABORTONRTE
		endif
	catch
		err= GetRTError (1)
		string errMsg = GetErrMessage(err, 3)
		string ProcName = "NQ_ResetBoards"
		if (StringMatch (errMsg, "*NI-DAQmx*"))
			Printf "Nidaq Error from %s at position %d\r", ProcName, errPos
			execute "print fDAQmx_ErrorString()"
		else
			Printf "Error from %s at position %d\r%s\r" ProcName, errPos, errMsg
		endif		
		return 1
	endtry
	// Killthreads
	WAVE threads= root:packages:twoP:acquire:bkgThreadIDs
	variable iThread,nThreads = numpnts (threads), result
	for (iThread = 0; iThread < nthreads; iThread +=1)
		if (numType (threads [iThread]) ==0)
			result=ThreadGroupRelease(threads[iThread])
			threads [iThread] = NaN
			if (result ==-2)
				print "Had to force-quit a thread"
			endif
		endif
	endFor
	return 0
end

//******************************************************************************************************
// A structure to hold all the various globals so  that we can pass them easily between functions
// Last Modified:
// 2016/11/15 by Jamie Boyd - added support for separate back ground tasks for each channel plus merge
Structure NQ_ScanStruct
// general scan/run settings
variable scanMode
variable isMulti
string newScanName
string scanNote
variable overWriteWarn
variable inPutTrigger
variable RunTime
// image settings 
string scanWavePath // string containing paths to image waves to scan and channels on which to scan them, in NIDAQ format
string imageBoard
variable scanChans
variable scanGain
variable numFrames
variable pixHeight
variable pixWidth
variable xSV
variable xEV
variable YSV
variable YEV
// image scaling
string obj
variable xImSize
variable yImSize
variable xPixSize
variable yPixSize
//  image Timing
variable pixTime
variable dutyCycle
variable flybackMode
variable scanHeadDelay
variable flybackProp
variable pixWidthTotal
variable frameTime
variable lineTime
variable scanIsCyclic
// TimeSeries Specific
variable scanToDisk
string FIFODir
// Live mode specific
variable liveAvgFrames
variable liveROISecs
variable liveHist
// LineScan specific
string LSLinkWave
// stage 
string stageProc
string stagePort
variable xPos
variable yPos
variable zPos
// Z series specific
variable zStepSize
variable zAvg
variable zAvgStackAtOnce
// ephys
string ePhysBoard
variable ePhysChans
variable ePhysFreq
variable ePhysGain
string ePhysPath  // string containing paths to ePhys waves to scan and channels on which to scan them, in NIDAQ format
variable ePhysIsCyclic
// triggers
variable trigChans
variable trig1Pos
variable trig2Pos
// voltage waves
variable vOutChans
string vOutWave1
string vOutWave2
variable vOutStart // "1 = on Scan Start;2=on Trig 1;"
// Background task ids - a separate backGround task for each image channel, maybe extend this for ephys?
variable imageBkgTaskIDs [4]
variable ephysBkgTaskIDs [16]
endStructure

//******************************************************************************************************
// Reads values appropriate for this scan into the scanStructure, s
// Last Modified 2015/04/16 by Jamie Boyd
Function NQ_LoadScanStruct (s, doStage)
	STRUCT NQ_ScanStruct &s
	variable doStage // set if you wish to update stage positions.
	
	// general scan/run settings
	NVAR scanModeG = root:packages:twoP:Acquire:ScanMode
	SVAR newScanName = root:Packages:twoP:acquire:NewScanName
	SVAR ScanNote = root:packages:twoP:acquire:newScanNote
	NVAR overWriteWarn = root:packages:twoP:acquire:overwriteWarnCheck
	NVAR inPutTrigger = root:packages:twoP:acquire:inputTriggerCheck
	NVAR trig1Check = root:Packages:twoP:Acquire:trig1Check
	NVAR trig2Check = root:Packages:twoP:Acquire:trig2Check
	s.ScanMode = abs (scanModeG)
	s.isMulti = (scanModeG <  0)
	// run time
	if (s.ScanMode == kePhysOnly)
		NVAR runTime = root:Packages:twoP:acquire:EphysOnlyTime
	else
		NVAR runTime = root:Packages:twoP:acquire:RunTime
	endif
	// scan name/note
	s.runTime = runTime
	if (s.ScanMode == kLiveMode)
		s.NewScanName = "LiveWave"
	else
		s.NewScanName = NewScanName
	endif
	s.scanNote = scanNote
	s.overWriteWarn = overWriteWarn
	s.inPutTrigger= inPutTrigger
	s.runTime = runTime
	// Image settings
	SVAR imageBoard = root:packages:twoP:acquire:imageBoard
	s.imageBoard = imageBoard
	if (s.ScanMode != kePhysOnly)
		NVAR scanChans = root:Packages:twoP:Acquire:ScanChans
		NVAR ScanGain = root:Packages:twoP:Acquire:ScanGain
		s.ScanChans = scanChans
		s.scanGain = scanGain
		// Image timing
		NVAR pixTime = root:packages:twoP:acquire:PixTime
		NVAR dutyCycle = root:Packages:twoP:Acquire:DutyCycle
		NVAR flybackMode =root:Packages:twoP:Acquire:FlyBackMode
		NVAR scanHeadDelay = root:packages:twoP:Acquire:ScanHeadDelay
		NVAR flybackProp = root:Packages:twoP:acquire:flybackProp
		NVAR pixWidthTotal = root:Packages:twoP:Acquire:PixWidthTotal
		NVAR frameTime = root:packages:twoP:Acquire:FrameTime
		NVAR lineTime = root:packages:twoP:Acquire:LineTime
		NVAR scanIsCyclic = root:packages:twoP:Acquire:isCyclic
		s.scanIsCyclic = scanIsCyclic
		s.pixTime = pixTime
		s.DutyCycle = DutyCycle
		s.FlybackMode = flybackMode
		s.scanHeadDelay = scanHeadDelay
		s.flybackProp = flybackProp
		s.pixWidthTotal = pixWidthTotal
		s.frameTime = frameTime
		s.lineTime = LineTime
		// reference number of frames based on scan mode options
		if ((s.ScanMode == kLiveMode) || (s.ScanMode == kLineScan))
			s.NumFrames = 1
		else
			Switch (s.ScanMode)
				case kTimeSeries:
					NVAR numFrames = root:Packages:twoP:Acquire:TSeriesFrames
					break
				case ksingleImage:
					NVAR numFrames =  root:Packages:twoP:Acquire:NumAverageFrames
					break
				case kZseries:
					NVAR numFrames = root:Packages:twoP:Acquire:NumZseriesFrames
					break
			endswitch
			s.numFrames = numFrames
		endif
		// Reference PixWidth and height, scaling based on scan mode
		SVAR obj = root:Packages:twoP:Acquire:curObj 
		s.obj = obj
		if (s.ScanMode == kLineScan)
			NVAR PixWidth =root:Packages:twoP:Acquire:LSWidth
			NVAR PixHeight =root:Packages:twoP:Acquire:LSHeight
			NVAR XSV =  root:Packages:twoP:Acquire:LSStartVolts
			NVAR XEV = root:Packages:twoP:Acquire:LSEndVolts
			NVAR YSV = root:Packages:twoP:Acquire:LSYVolts
			NVAR xImSize = root:Packages:twoP:Acquire:LSImSize
			NVAR xPixSize = root:Packages:twoP:Acquire:LSpixSize
			NVAR yPixSIze = root:packages:twoP:Acquire:LineTime
		else
			NVAR PixWidth = root:Packages:twoP:acquire:PixWidth
			NVAR PixHeight = root:Packages:twoP:acquire:PixHeight
			NVAR XSV = root:Packages:twoP:acquire:XStartVolts
			NVAR XEV = root:Packages:twoP:acquire:XEndVolts
			NVAR YSV = root:Packages:twoP:acquire:YStartVolts
			NVAR YEV = root:Packages:twoP:acquire:YEndVolts
			NVAR xImSize= root:Packages:twoP:acquire:xImSize
			NVAR yImSize = root:Packages:twoP:acquire:yImSize
			NVAR xPixSize = root:Packages:twoP:acquire:xPixSize
			NVAR yPixSIze = root:Packages:twoP:acquire:yPixSize
		endif
		s.pixWidth = pixWidth
		s.pixHeight=pixHeight
		if (kNQxInvert)
			s.XSV = -XSV
			s.XEV=-XEV
		else
			s.XSV = XSV
			s.XEV= XEV
		endif
		if (kNQyInvert)
			s.YSV = -YSV
		else
			s.YSV = YSV
		endif
		s.xImSize = xImSize
		s.xPixSize = xPixSize
		s.yImSize = yImSize
		s.yPixSize = yPixSize
		if (s.ScanMode != kLineScan)
			if (kNQyInvert)
				s.YEV = -YEV
			else
				s.YEV = YEV
			endif
		endif
		// Time series specific
		if (s.ScanMode == kTimeSeries)
			controlinfo/w=twoP_Controls LiveROICheck
			if (V_Value == 0)
				s.liveROISecs = 0
			else
				s.liveROISecs = 1
			endif
		endif
		NVAR scanToDisk = root:packages:twoP:acquire:ScanToDisk
		SVAR fifoDir = root:packages:twoP:acquire:ScanToDiskDir
		s.scanToDisk = scanToDisk
		if (scanToDisk)
			s.FIFODir = fifoDir
		else
			s.FIFODir = ""
		endif
		// Live mode specific
		if (s.ScanMode == kLiveMode)
			controlinfo/w= twoP_Controls LiveAvgCheck
			if (V_Value == 0)
				s.liveAvgFrames = 0
			else
				NVAR liveAvgFrames = root:Packages:twoP:acquire:numLiveAvgFrames
				s.liveAvgFrames = liveAvgFrames
			endif
			controlinfo/w=twoP_Controls LiveROICheck
			if (V_Value == 0)
				s.liveROISecs = 0
			else
				NVAR liveROIsecs = root:Packages:twoP:acquire:LiveROIsecs
				s.liveROISecs = liveROIsecs
				NVAR liveROIRatioCheck = root:Packages:twoP:Acquire:liveROIRatioCheck
				if ((scanChans & 3) != 3)
					liveROIRatioCheck = 0
				endif
			endif
			controlinfo/w=twoP_Controls LiveHistCheck
			s.liveHist = V_Value
		endif
		// line scan specific
		if (s.ScanMode == kLineScan)
			SVAR LSLinkWaveStr= root:packages:twoP:Acquire:lsLinkWaveStr
			s.LSLinkWave = LSLinkWaveStr
		endif
		// Z specific stuff
		if (s.ScanMode == kzSeries)
			NVAR zFirstZ = root:Packages:twoP:Acquire:ZFirstZ 
			NVAR zstepSize = root:Packages:twoP:Acquire:ZStepSize
			NVAR zAvg = root:Packages:twoP:Acquire:NumZseriesAvg
			s.zpos = zFirstZ
			s.zStepSize = zStepSize
			s.zAvg = zAvg
		endif
	endif // end of image specific
	if (doStage)
		// Stage - Call stage doUpdate function so we get accurate values for positions
		// X and Y position will be the position of the start of the image.
		// Relative zero (i.e., 0 offset from the current reading of the stage values) is halfway between
		// min and max of  voltage full size defined in the constants kNQxVoltStart etc. plus the offset for 
		// the objective being used.
		// Thus, for a full scale wave (kNQxVoltStart to kNQxVoltEnd), xPos should be (kNQxVoltEnd - kNQxVoltStart)/2  * Xscaling
		WAVE/t ObjWave = root:Packages:twoP:Acquire:ObjWave
		NVAR curObjNum = root:packages:twoP:Acquire:CurObjNum
		SVAR StageProc = root:Packages:twoP:Acquire:StageProc
		SVAR stagePort = root:Packages:twoP:Acquire:StagePort
		s.stageProc = StageProc
		s.stagePort = stagePort
		variable xS=1, yS=1, zS=1, axS=NaN
		funcref  StageUpdate_Template UpdateStage=$"StageUpDate_" + StageProc
		UpdateStage (xS, yS, zS, axS)
		variable xCenterV = (kNQxVoltStart + kNQxVoltEnd)/2
		variable yCenterV = (kNQyVoltStart + kNQyVoltEnd)/2
		s.xPos = xS + ((s.XSV - xCenterV) * str2num (ObjWave [curObjNum] [1])) +  str2num (ObjWave [curObjNum] [3])
		s.yPos = yS + ((s.YSV - yCenterV) * str2num (ObjWave [curObjNum] [2])) +  str2num (ObjWave [curObjNum] [4])	// if a Zstack, z pos will be start of stack, which is set above, and may not be current z pos
		if (s.ScanMode != kzSeries)
			s.zPos=zS
		endif
		// if reading stage fails, set values to 0
		if (((numtype (s.xPos) != 0) ||  (numtype (s.yPos) != 0)) ||(numtype (s.zPos) != 0))
			s.xPos = 0
			s.yPos =0
			s.zPos =0
			print "Stage reading failed; XYZ positions for " + newScanName + " set arbitrarily to 0"
		endif
	else
		s.xPos = 0
		s.yPos =0
		s.zPos =0
	endif
	// for live mode, save relative offsets in global variables for use in adjusting position
	if (s.ScanMode == kLiveMode)
		variable/G root:packages:twoP:acquire:xRelOffset = s.xPos -xS  //((s.XSV - (kNQxVoltStart + (kNQxVoltEnd - kNQxVoltStart)/2)) * str2num (ObjWave [curObjNum] [1]))  + str2num (ObjWave [curObjNum] [3]) 
		variable/G root:packages:twoP:acquire:yRelOffset=  s.yPos - yS  //((s.YSV - (kNQyVoltStart  + (kNQyVoltEnd - kNQyVoltStart)/2)) * str2num (ObjWave [curObjNum] [2]))  + str2num (ObjWave [curObjNum] [4]) 
	endif
	// ephys, either alone or with imaging
	SVAR ePhysBoard = root:packages:twoP:acquire:ePhysBoard
	s.ePhysBoard= ePhysBoard
	if ((((s.ScanMode == kLiveMode)) || (s.ScanMode == kZSeries)) || (s.ScanMode == kSingleImage))
		s.ePhysChans = 0
	else
		if (s.ScanMode == kePhysOnly)
			NVAR ephysChans =  root:packages:twoP:Acquire:EphysChans
		else
			NVAR ephysChans = root:Packages:twoP:Acquire:ePhysAdjChans
		endif
		NVAR ePhysFreq = root:Packages:twoP:acquire:ePhysFreq
		NVAR ePhysGain = root:Packages:twoP:Acquire:ePhysGain
		s.ePhysBoard= ePhysBoard
		s.ePhysChans = ephysChans
		s.ePhysFreq = ePhysFreq
		s.ePhysGain = ePhysGain
		NVAR ePhysIsCyclic =  root:packages:twoP:Acquire:ePhysisCyclic
		s.ePhysIsCyclic = ePhysIsCyclic
	endif
	// triggers for live mode, time series and ePhysOnly, delay time saved as number of ticks of 100 kHz clock
	variable trigChans
	Switch (s.ScanMode)
		case kLiveMode:
		case kTimeSeries:
			controlinfo/w=twoP_Controls FramesTrig1Check
			s.trigChans = V_Value
			if (V_Value == 1)
				NVAR DelaySecs = root:Packages:twoP:Acquire:DelayFramesSec1
				s.trig1Pos = DelaySecs
			endif
			controlinfo/w=twoP_Controls FramesTrig2Check
			s.trigChans += V_Value*2
			if (V_Value == 1)
				NVAR DelaySecs = root:packages:twoP:Acquire:DelayFramesSec2
				s.trig2Pos = DelaySecs
			endif
			break
		case kLineScan:
			controlinfo/w=twoP_Controls LinesTrig1Check
			s.trigChans = V_Value
			if (V_Value == 1)
				NVAR DelaySecs = root:Packages:twoP:Acquire:DelayLinesSec1
				s.trig1Pos = DelaySecs
			endif
			controlinfo/w=twoP_Controls LinesTrig2Check
			s.trigChans += V_Value*2
			if (V_Value == 1)
				NVAR DelaySecs = root:Packages:twoP:Acquire:DelayLinesSec2
				s.trig2Pos = DelaySecs
			endif
			break
		case kEphysOnly:
			controlinfo/w=twoP_Controls ePhysTrig1Check
			s.trigChans = V_Value
			if (V_Value == 1)
				NVAR DelaySecs = root:packages:twoP:Acquire:DelaySecs1
				s.trig1Pos = DelaySecs
			endif
			controlinfo/w=twoP_Controls ePhysTrig2Check
			s.trigChans += V_Value*2
			if (V_Value == 1)
				NVAR DelaySecs = root:packages:twoP:Acquire:DelaySecs2
				s.trig2Pos = DelaySecs
			endif
			break
	endswitch
	// voltage waves
	if (((s.ScanMode == kLiveMode) || (s.ScanMode == kTimeSeries)) || (s.ScanMode == kephysOnly))
		controlinfo/w=twoP_Controls Voltage1Check
		s.vOutChans = V_Value
		if (V_Value)
			controlinfo/w=twoP_Controls VoltagePulse1Popup
			s.VoutWave1 = S_Value
		endif
		controlinfo/w=twoP_Controls Voltage2Check
		s.vOutChans+= V_Value*2
		if (V_Value)
			controlinfo/w=twoP_Controls VoltagePulse2Popup
			s.VoutWave2 = S_Value
		endif
		if (S.VoutChans)
			controlinfo/w=twoP_Controls VoltagePulsePopUp
			s.vOutStart = V_Value
		endif
	endif
	return 0
end

//******************************************************************************************************
//  if overwrite warning is enabled, checks to see if scan name already exists, and interacts with user to overwrite or increment scan name
// Last Modified 2014/08/13 by Jamie Boyd
Function NQ_CheckOverWrite (s)
	STRUCT NQ_ScanStruct &s
	
	// Check to see if scan wave exists, and if it is o.k. to overwrite it
	if (((s.scanMode != kLiveMode) && (s.overWriteWarn == 1)) && (DataFolderExists ("root:twoP_Scans:" + s.NewScanName)))// user wants to be warned about possible overwriting of waves
		string alertstr = ""
		DO
			alertStr = "A scan with the name \"" + s.newScanName + "\" already exists. Overwrite it?  Click \"yes\" to overwrite old scan, \"no\" to increment new wave name, or \"cancel\" to cancel scanning."
			doalert 2, alertstr
			if (V_Flag == 2)		// no was clicked, so increment the wavename
				s.newScanName = NQ_autinc (s.newScanName, 1)
			elseif (V_Flag == 3) // cancel scanning was clicked
				doAlert 0, "Scanning will be canceled."
				return 1
			endif
			// keep incrementing while No overwriting selected AND the wave exists
		WHILE ((dataFolderExists ("root:twoP_Scans:" + s.NewScanName)) && (V_Flag ==2))
		SVAR newScanName = root:packages:twoP:Acquire:newScanName
		newScanName = s.NewScanName
	endif
	return 0
end

//******************************************************************************************************
// Makes a formatted string containing useful information about the scan and puts it in the provided global str
// Some variables are used in calculations, and need to be accessed later, some are just for maintaining
// a record of settings for the user. The latter can be printed with easier to read but harder to parse %W formatting
// Last Modified 2014/09/18 by Jamie Boyd
Function NQ_ScanNoter (s, gStrName)
	STRUCT NQ_ScanStruct &s
	string gStrName
	
	try
		SVAR/Z NoteStr = $gStrName
		if (!(SVAR_EXISTS (NoteStr)))
			String/G  $gStrName ;ABORTONRTE
			SVAR NoteStr = $gStrName
		endif
	catch
		variable err= GetRTError (1)
		string errMsg = GetErrMessage(err, 3)
		printf "%s\rNQ_ScanNoter could not make the global string, \"%s\".\r", errMsg, gStrName
		return 1
	endtry
	string tempStr // used for printF
	// Experiment note
	NoteStr = "ExpNote:" + s.scanNote + "\r"
	// Scan Type - easier for user to read than the scan mode numeric code
	variable scanMode = s.scanMode
	switch (scanMode)
		case kTimeSeries:
			NoteStr += "Scan Type:Time Series\r"
			break
		case kSingleImage:
			NoteStr += "Scan Type:Average\r"
			break
		case kzSeries:
			NoteStr += "Scan Type:Z Stack\r"
			break
		case kLineScan:
			NoteStr += "Scan Type:Line Scan\r"
			break
		case kePhysOnly:
			NoteStr += "Scan Type:ePhys Only\r"
			break
	endSwitch
	// Scan Mode - easier for a function to parse than the string
	NoteStr += "Mode:" + num2str (s.scanMode) + "\r"
	// Time, in Igor Format, when the scan was started
	sprintf tempStr, "ExpTime:%.0f\r",  datetime	// use sprintf to keep enough precision
	NoteStr +=  tempStr
	// image specific stuff
	// image channels, bitwise
	NoteStr += "ImChans:" + num2str (s.scanChans) + "\r"
	// channel descriptions, for forwards compatibility
	NoteStr += "imChanDesc:"
	variable ii
	for (ii =1; ii<3; ii+=1)
		if (ii & s.scanChans)
			NoteStr += "ch" + num2str (ii) + ","
		endif
	endfor
	NoteStr += "\r"
	// stage positions
	noteStr += "Xpos:" + num2str (s.xPos) + "\r"
	noteStr += "Ypos:" + num2str (s.yPos) + "\r"
	noteStr += "Zpos:" + num2str (s.zPos) + "\r"
	// image channel descriptions
	if (scanMode != kePhysOnly)
		// Image size and Pixel scaling
		noteStr += "PixWidth:" + num2str (s.pixWidth) + "\r"
		noteStr += "XpixSize:" + num2str (s.xPixSize) + "\r"
		noteStr += "PixHeight:" + num2str (s.pixHeight) + "\r"
		noteStr += "YpixSize:" + num2str (s.yPixSize) + "\r"
		noteStr += "NumFrames:" + num2str (s.numFrames) + "\r"
		// z averaging 
		if (scanMode == kZseries)
			noteStr += "Zavg:" + num2str (s.zAvg) + "\r"
			noteStr += "ZstepSize:" + num2str (s.zStepSize) + "\r"
		endif
		// Frame Time and linetime
		sprintf tempStr, "FrameTime:%.6f\r",s.FrameTime
		noteStr += tempStr
		sprintf tempStr, "LineTime:%.6f\r", s.LineTime
		noteStr +=  tempStr
		// DutyCycle and flyback mode, and flyback proportion, for non-symetric scans
		NoteStr += "DutyCycle:" + num2str (s.DutyCycle) + "\r"
		NoteStr += "FlyBackMode:" + num2str (s.flybackMode) + "\r"
		if (s.flybackMode == 0)
			noteStr += "FlybackProp:" + num2str (s.flybackProp) + "\r"
		endif
		sprintf tempStr, "ScanHeadDelay:%.2W1Ps\r", s.scanHeadDelay
		noteStr += tempStr
		// objective
		noteStr += "Obj:" + s.obj + "\r"
		// Voltage ranges and positions - with a little extra precision
		if (kNQxInvert)
			sprintf tempStr, "XSV:%.8f\r", s.XEV 
			noteStr += tempStr
			sprintf tempStr, "XEV:%.8f\r", s.XSV 
			noteStr += tempStr
		else
			sprintf tempStr, "XSV:%.8f\r", s.XSV 
			noteStr += tempStr
			sprintf tempStr, "XEV:%.8f\r", s.XEV 
			noteStr += tempStr
		endif
		if (scanMode == kLineScan)
			sprintf tempStr, "YLSV:%.8f\r", s.YSV 
			noteStr += tempStr
			if ((cmpstr (s.LSLinkWave, "Don't Link")) == 0)
				NoteStr +=  "linkWave:Not Linked\r"
			else
				NoteStr +=  "linkWave:" + s.LSLinkWave + "\r"
			endif
		else // not a line scan
			if (kNQYinvert)
				sprintf tempStr, "YSV:%.8f\r", s.YEV 
				noteStr += tempStr
				sprintf tempStr, "YEV:%.8f\r", s.YSV 
				noteStr += tempStr
			else
				sprintf tempStr, "YSV:%.8f\r", s.YSV 
				noteStr += tempStr
				sprintf tempStr, "YEV:%.8f\r", s.YEV 
				noteStr += tempStr
			endif
		endif
	endif
	// was ePhys also collected?
	notestr += "ephys:" + num2str (s.ePhysChans) + "\r"
	NoteStr += "ePhysChanDesc:"
	for (ii =1; ii<3; ii+=1)
		if (ii & s.ePhysChans)
			NoteStr += "ep" + num2str (ii) + ","
		endif
	endfor
	NoteStr += "\r"
	// Need to add extra info for ePhys?
	// info for FIFO scanning
	NoteStr += "ScanToDisk:"
	if (s.scanToDisk)
		NoteStr += "1\r"
	else
		NoteStr += "0\r"
	endif
	return 0
end

//******************************************************************************************************
// Makes the image waves for scanning in a new folder, for all the different scan modes. 
// Sets NIDAQ string for channels and paths to created waves in s.scanWavePath
// Makes waveNote in folder for new scan
// Last Modified 2017/08/12 by Jamie Boyd @@@@
Function NQ_MakeImageScanWaves (s)
	STRUCT NQ_ScanStruct &s
	
	// if not live mode, make a folder for this scan
	// Also make a string for wave Note -  contains info about scan settings for this scan
	if (s.ScanMode == kLiveMode)
		NQ_ScanNoter (s, "root:packages:twoP:Acquire:LiveModeScanStr")
	else
		newDataFolder/O $"root:twoP_Scans:" + s.newScanName
		NQ_ScanNoter (s, "root:twoP_Scans:" + s.newScanName + ":" +  s.newScanName + "_info")
	endif
	// Iterate through the channels, making waves as appropriate for the scanMode
	variable theChannel, nChannels = 2, err
	string theWaveName, DataWave_Path = "",  tempWaveName1, tempWaveName2
	string dontKill = ""
	try
		Switch (s.Scanmode) 
			case kLiveMode: 
				// Do we need multiple frames for timing issues
				NVAR nLiveFrames = root:packages:twoP:acquire:nLiveFrames
				For (theChannel =0 ; theChannel < nChannels; theChannel +=1)
					if (s.ScanChans & (2^theChannel))	// Then the current channel is selected
						// Make the wave we will acquire into directly, but not display. The waves
						// we acquire into directly need to be kept 1-Dimensional thanks to a nidattoolsmx update
						theWaveName = "root:packages:twoP:acquire:LiveAcq_ch" + num2str (theChannel + 1)
						// same as image size x 2 for double-buffering x nLiveFrames
						variable nLivePnts = s.PixWidth * s.PixHeight * nLiveFrames
						WAVE/z theWave = $theWaveName
						if (WaveExists (theWave))
							if (numPnts (theWave) != nLivePnts)
								redimension/n = (nLivePnts) theWave
							endif
						else // need to make the wave
							make/w/u/o/n = (nLivePnts) $theWaveName
							setscale/p x 0, 1e-06, "s" $theWaveName
						endif
						WAVE tempWave = $theWaveName
						// setscaling so Igor doesn't complain
						//SetScale/P x 0, 1e-06, "", tempWave
						fastop tempWave =0  
						// add path info @@@ gain set to -5,5 for now, need to add per-channel gain settabilitty 
						DataWave_Path  +=  thewavename + ", " + num2str (theChannel) + ", -5,5;"
					endif
				endfor 
				break
			case kSingleImage:	// Averaging Frames (time series with averaging at the end)
			case kTimeSeries:	// time series
				if (!(dataFolderExists ("root:twoP_Scans:" + s.newScanName)))
					newDataFolder/O $"root:twoP_Scans:" + s.newScanName
				endif
				if (s.ScanToDisk)
					// FIFO time. Make the FIFO. Remake it everytime, in case selection of channels has changed
					FIFOStatus /Q NIDAQImageFifo
					if (V_flag) // already exists
						KillFIFO NIDAQImageFifo
					endif
					NewFifo NIDAQImageFifo 
					// add channels
					DataWave_Path = "NIDAQImageFifo;"
					For (theChannel = 1; theChannel < 3; theChannel +=1)
						if ((s.ScanChans) & theChannel)	// Then the current channel is selected
							NewFIFOChan/W/u NIDAQImageFifo, $"ch" + num2str (theChannel), 0, 0.00241,-10,10,""
							DataWave_Path +=  num2str (theChannel) + ","
						endif
					endfor
					//DataWave_Path = removeending (DataWave_Path, ",")
					// set sampling rate to something reasonable, although we will be controlling it by counter
					CtrlFIFO NIDAQImageFifo, deltaT =1e-01
					// set FIFO size
					CtrlFIFO NIDAQImageFifo, size= kImageFifoSize
					// make a file on disk to connect to FIFO
					string newFolderName = s.FIFODir + s.newScanName
					NewPath /C/O NIDAQFifoPath, newFolderName
					NVAR FileRefNum = root:Packages:twoP:Acquire:scanToDiskFileRefNum
					string newFifoFileName = s.newScanName + ".bin"
					Open/P=NidaqFIFOPath FileRefNum as newFifoFileName
					CtrlFIFO NIDAQImageFifo, file=FileRefNum
					CtrlFIFO NIDAQImageFifo start
					// ^^^^^ this needs testing
					//NewPanel/w=(50,50,550,550) as "fifopanel"
					//Chart MyChart, fifo=NIDAQImageFifo, chans ={0,1},size={500,500}, umode=1, omode=0, smode = 0, ppstrip = 1
					//chart MyChart color(0)=(65535,0,0 ), color (1) = (0,0,65535)
				else
					redimension/n = ((s.PixWidth), (s.PixHeight))root:packages:twoP:examine:scanGraph_ch1,root:packages:twoP:examine:scanGraph_ch2
					SetScale/P x s.xPos, s.XPixSize, "m", root:packages:twoP:examine:scanGraph_ch1, root:packages:twoP:examine:scanGraph_ch2
					SetScale/P x s.yPos, s.YPixSize, "m", root:packages:twoP:examine:scanGraph_ch1, root:packages:twoP:examine:scanGraph_ch2
					//SetScale/P x 0, 1e-06, "", root:packages:twoP:examine:scanGraph_ch2
					if (s.scanIsCyclic)
						NVAR bufferSize = root:packages:twoP:acquire:tSeriesBufferSize
						s.numFrames = ceil (s.numFrames / bufferSize) * bufferSize
					endif
					For (theChannel = 0; theChannel < nChannels; theChannel +=1)
						if ((s.ScanChans) & (2^theChannel))	// Then the current channel is selected
							// don't kill this wave
							dontKill +=  s.NewScanName + "_ch" + num2str (theChannel + 1) + ";"
							//Make WaveName
							theWaveName = "root:twoP_Scans:" +  s.NewScanName + ":" + s.NewScanName + "_ch" + num2str (theChannel +1)
							// Make the wave
							WAVE/Z theWave = $theWaveName
							if (s.scanIsCyclic)
								if (WaveExists (theWave))
									redimension/n= ((s.PixWidth), (s.PixHeight), (s.numFrames))  $theWaveName
								else
									make/w/u/o/n= ((s.PixWidth), (s.PixHeight), (s.numFrames))  $theWaveName
								endif
							else
								if (WaveExists (theWave)) // acquire directly into the wave so make sure it is 1 dimensional
									redimension /n= (s.PixWidth * s.PixHeight * s.numFrames)  $theWaveName
								else
									make/w/u/o/n= (s.PixWidth * s.PixHeight * s.numFrames)  $theWaveName
								endif
							endif

							// check that the wave was made
							err = GetRTError(0)
							abortonvalue err, 1
							// Set scaling
							WAVE DataWave = $theWaveName
							if (s.scanIsCyclic)
								SetScale/P x s.xPos, s.XPixSize, "m", Datawave
								SetScale/P y  s.yPos, s.YPixSize,"m", Datawave
								SetScale/P z  0, s.frameTime ,"s", Datawave
							else
								SetScale/P x 0 , 1e-06,"m", Datawave
							endif
							SetScale d, 0, 2e12-1, "raw A/D", DataWave 
							if (s.scanIsCyclic)
								// Make a tempWave to acquire into directly
								string tempWaveName = "root:packages:twoP:acquire:TempZWave" + "_ch" + num2str (theChannel + 1)
								WAVE/Z tempWave = $tempWaveName
								if (WaveExists (tempWave))
									redimension/n= (s.PixWidth * s.PixHeight * bufferSize) $tempWaveName
								else
									make/w/u/o/n= (s.PixWidth * s.PixHeight * bufferSize) $tempWaveName
								endif
								// Add path info for tempWave
								DataWave_Path  +=  tempWaveName + ", " + num2str (theChannel) + ", -5, 5;"
							else
								// Add path info for data wave
								DataWave_Path  +=  thewavename + ", " + num2str (theChannel) + ", -5, 5;"
							endif
							// 0 the wave
							fastop DataWave = 0
							SetScale d, 0, 2e12-1, "raw A/D", DataWave 
						endif
					endfor
				endif
				break
			case kLineScan:
				For (theChannel = 1; theChannel < 3; theChannel +=1)
					if ((s.ScanChans) & theChannel)	// Then the current channel is selected
						// don't kill this wave
						dontKill +=  s.NewScanName + "_ch" + num2str (theChannel + 1) + ";"
						//Make WaveName
						theWaveName =  "root:twoP_Scans:" +  s.NewScanName + ":" + s.NewScanName + "_ch" + num2str (theChannel +1)
						// Make the wave
						wave/Z theWave = $theWaveName
						if (waveExists (theWave))
							redimension/n = ((s.PixWidth), (s.pixHeight)) theWave
						else
							make/w/u/o/n= ((s.PixWidth), (s.PixHeight))  $theWaveName
						endif
						// check that the wave was made
						err = GetRTError(0)
						abortonvalue err, 1
						// Set scaling
						WAVE DataWave = $theWaveName
						SetScale/P x 0,1e-06,"s", Datawave
						//SetScale/P x (s.xPos) , (s.xPixSize),"m", Datawave
						//SetScale/P y  0 , (s.lineTime),"s", Datawave
						SetScale d, -2e-11, 2e11-1, "raw A/D", DataWave
						if (s.scanIsCyclic)
							tempWaveName1 = "root:packages:twoP:acquire:TempL1Wave" + "_ch" + num2str (theChannel)
							tempWaveName2 = "root:packages:twoP:acquire:TempL2Wave" + "_ch" + num2str (theChannel)
							NVAR bufferSize = root:packages:twoP:acquire:lScanBufferSize
							WAVE/z tempWave1 = $tempWaveName1
							if (!(waveExists (tempWave1)))
								make/w/u/o/n= ((s.PixWidth), (bufferSize)) $tempWaveName1
							elseif ((dimSize (tempWave1, 0) != s.PixWidth) || (dimSize (tempWave1, 1) != bufferSize))
								redimension/n= ((s.PixWidth), (bufferSize)) $tempWaveName1
							endif
							WAVE/z tempWave2 = $tempWaveName2
							if (!(waveExists (tempWave2)))
								make/w/u/o/n= ((s.PixWidth), (bufferSize)) $tempWaveName2
							elseif ((dimSize (tempWave2, 0) != s.PixWidth) || (dimSize (tempWave2, 1) != bufferSize))
								redimension/n= ((s.PixWidth), (bufferSize)) $tempWaveName2
							endif
							// Add path info to first tempWave
							DataWave_Path  +=  tempWaveName1 + ", " + num2str (theChannel-1) + ", -5, 5;"
						else
							// Add path info for data wave
							DataWave_Path  +=  thewavename + ", " + num2str (theChannel-1) + ", -5, 5;"
						endif
					endif
				endfor
				break
			case kzSeries:
				// Do we need multiple frames for timing issues
				//NVAR frameTime = root:packages:twoP:acquire:frametime
				if (s.frameTime < kNQminLiveFrameTime)
					s.zAvgStackAtOnce =1
					s.zAvg = ceil (kNQminLiveFrameTime/s.frameTime)
				else
					s.zAvgStackAtOnce =0
				endif
				variable/G root:packages:twoP:acquire:zAvgStackAtOnce = s.zAvgStackAtOnce
				For (theChannel = 0; theChannel < nCHannels; theChannel +=1)
					if ((s.ScanChans) & (2^theChannel))	// Then the current channel is selected
						// don't kill this wave
						dontKill +=  s.NewScanName + "_ch" + num2str (theChannel + 1) + ";"
						//Make WaveName
						theWaveName = "root:twoP_Scans:" +  s.NewScanName + ":" + s.NewScanName + "_ch" + num2str (theChannel +1)
						// Make the wave
						WAVE/Z theWave = $theWaveName
						if (!(waveExists (theWave)))
							make/w/u/o/n= ((s.PixWidth), (s.PixHeight), (s.numFrames))  $theWaveName
							// 0 the wave
							wave theWave = $theWaveName
							fastop theWave = 0	
						else
							redimension/n= ((s.PixWidth), (s.PixHeight), (s.numFrames))  theWave
							// 0 the wave
							wave theWave =  $theWaveName
							fastop theWave = 0	
						endif
						// check that the wave was made
						err = GetRTError(0)
						abortonvalue err, 1
						// Set scaling
						WAVE theWave = $theWaveName
						SetScale/P x (s.xPos) , (s.xPixSize),"m", theWave
						SetScale/P y  (s.yPos) , (s.yPixSize),"m", theWave
						SetScale/P z  (s.Zpos), (s.zStepSize),"m", theWave
						SetScale d, -2e-11, 2e11-1, "raw A/D", theWave
						// Also make a tempWave to acquire into directly, and transfer to 3D wave as acquired
						tempWaveName = "root:packages:twoP:acquire:TempZWave" + "_ch" + num2str (theChannel +1)
						wave/Z tempWave = $tempWaveName
						if (s.zAvgStackAtOnce)
							if (!(waveExists (tempWave)))
								make/w/u/o/n= (s.PixWidth * s.PixHeight * s.zAvg)$tempWaveName
								wave/Z tempWave = $tempWaveName
							else
								redimension/n= (s.PixWidth * s.PixHeight  * s.zAvg)tempWave
							endif
						else  // just a 2D wave
							if (!(waveExists (tempWave)))
								make/w/u/o/n= (s.PixWidth * s.PixHeight)$tempWaveName
							else
								redimension/n= (s.PixWidth * s.PixHeight) tempWave
							endif
						endif
						wave tempWave = $tempWaveName
						SetScale/P x 0, 1e-06, "s", tempWave
						DataWave_Path  +=  tempWaveName + ", " + num2str (theChannel) + ", -5, 5;"
					endif
				endfor
				break
		endSwitch
	catch
		doalert 0, "Scan waves could not be created: " + GetRTErrMessage()
		err = GetRTError(1)
		return 1
	endtry
	// kill remaining waves left on graph from last scan, if any
	// check ephys waves as well
	For (theChannel = 1; theChannel < 3; theChannel +=1)
		if (s.ePhysChans & theChannel)
			dontKill += s.NewScanName + "_ep" + num2str (theChannel)
		endif
	endfor
	NQ_KillNotInList (s, dontKill)
	NVAR expSize = root:packages:twoP:acquire:expSize
	expSize = NQ_GetExpSize ("root:")
	s.scanWavePath = DataWave_Path
	doupdate
	return 0
end

//******************************************************************************************************
// Makes the waves to scan ephys. Returns path and channel info in ePhysPath field of the scanStruct
// Last Modified 2013/07/24 by Jamie Boyd 
Function NQ_MakeEPhysWaves (s) 
	STRUCT NQ_ScanStruct &s
	
	string eDataWave_Path = ""
	variable theChannel, bufferSize, err
	string theWaveName, tempWaveName
	if (s.ScanMode ==kEphysOnly)
		string dontKill = ""
	endif
	try
		variable ePnts = (s.Runtime * s.EphysFreq) 
		if (s.ScanToDisk)
			// FIFO time. Make the FIFO
			FIFOStatus /Q NIDAQePhysFifo
			if (V_flag) // already exists
				KillFIFO NIDAQePhysFifo
			endif
			NewFifo NIDAQePhysFifo 
			eDataWave_Path = "NIDAQePhysFifo;"
			// add channels
			For (theChannel = 1; theChannel < 3; theChannel +=1)
				if ((s.ePhysChans) & theChannel)	// Then the current channel is selected
					NewFIFOChan/W/u NIDAQePhysFifo, $"ep" + num2str (theChannel), 0, 0.00241,-10,10,"V"
					eDataWave_Path += "ep" + num2str (theChannel) + ","
				endif
			endfor
			// set sampling rate
			CtrlFIFO NIDAQePhysFifo, deltaT =  (1/s.EphysFreq)
			// set size for fifo for 5 seconds 
			CtrlFIFO NIDAQePhysFifo size = (5 * s.EphysFreq) 
			// make a file on disk to connect to FIFO
			if (s.ScanMode == kEPhysOnly)
				string newFolderName = s.FIFODir + s.newScanName
				NewPath /C/O NIDAQFifoPath, newFolderName
			endif
			NVAR FileRefNum = root:Packages:twoP:Acquire:ePhysToDiskFileRefNum
			string newFifoFileName = s.newScanName + "_ephys.bin"
			Open/P=NidaqFIFOPath FileRefNum as newFifoFileName
			CtrlFIFO NIDAQePhysFifo, file=FileRefNum
			CtrlFIFO NIDAQePhysFifo start
			//display ePhys data
			NewPanel
			Chart MyChart, fifo=NIDAQePhysFifo, size={200,100}
		else
			For (theChannel = 1; theChannel < 3; theChannel +=1)
				if (s.ePhysChans & theChannel)	// Then the current channel is selected
					//Make WaveName
					theWaveName ="root:twoP_Scans:" + s.NewScanName + ":" + s.NewScanName + "_ep" + num2str (theChannel)
					if (s.ScanMode ==kEphysOnly)
						dontKill += s.NewScanName + "_ep" + num2str (theChannel) + ";"
					endif
					// Make the wave
					wave/Z theWave = $theWaveName
					if (!((WaveExists (theWave)) && (numPnts (theWave) == ePnts)))
						make/o/n= (ePnts) $theWaveName
						// check that the wave was made
						err = GetRTError(0)
						abortOnValue err, 1
					endif
					// Set scaling
					WAVE DataWave = $theWaveName
					SetScale/P x 0,(1/s.EphysFreq),"s",  Datawave
					SetScale d, 0, 0, "V", DataWave
					// 0 the wave
					fastop DataWave = 0
					if (s.ephysIsCyclic)
						// Also make a temp Wave to acquire into directly, and transfer to data wave as acquired
						tempWaveName = "root:packages:twoP:acquire:TempePhysWave" + "_ep" + num2str (theChannel)
						if (s.ScanMode==kePhysOnly)
							bufferSize = kNQtBufferTime * s.EphysFreq
						else
							bufferSize = ceil ((0.9 * kNQtBufferTime * s.EphysFreq)/s.frameTime)
						endif
						make/w/u/o/n= ((s.PixWidth), (s.PixHeight), (bufferSize)) $tempWaveName
						// Add path info to first tempWave
						eDataWave_Path  +=  tempWaveName + ", " + num2str (theChannel-1) + ";"
					else
						// Add path info for data wave
						eDataWave_Path  +=  thewavename + "," + num2str (theChannel -1)  + ";"
					endif
				endif
			endfor
		endif
	catch
		doAlert 0, " Could not make the ePhys Wave: " + GetRTErrMessage()
		err = GetRTError(1)						// Clear error state
		return 1
	endTry
	s.ePhysPath = eDataWave_Path
	if (s.ScanMode ==kEphysOnly)
		NQ_KillNotInList (s, dontKill)
		NVAR expSize = root:packages:twoP:acquire:expSize
		expSize = NQ_GetExpSize ("root:")
		newDataFolder/O $"root:twoP_Scans:" + s.newScanName
		//string/G $"root:twoP_Scans:" + s.newScanName + ":" +  s.newScanName + "_info"
		NQ_ScanNoter (s, "root:twoP_Scans:" + s.newScanName + ":" +  s.newScanName + "_info")
	endif
	doupdate
	return 0
end

//******************************************************************************************************
// Kills waves in new scan folder, except those in the dontKill list
// Last Modified May 11 2012 by Jamie Boyd 
Function NQ_KillNotInList (s, dontKill)
	STRUCT NQ_ScanStruct &s
	string dontKill
	
	string aWaveName
	string folder = "root:twoP_Scans:" +  s.NewScanName + ":"
	variable iWave, nWaves = CountObjects(folder, 1)
	// count backwards from nWaves-1 to 0, so deleted waves don't mess up the count
	for (iWave =nWaves-1; iWave >-1 ; iWave -=1)
		aWaveName = GetIndexedObjName(folder, 1, iWave)
		if (WhichListItem(aWaveName, dontKill, ";") == -1)
			GUIPKillDisplayedWave ($folder  + aWaveName)
		endif
	endfor
end

//******************************************************************************************************
// Sets up triggers, using the ephys board.  returns 1 if an error occurs, else 0
// Trigger delay timing is done with the 100 kHz clock.
// the width of the pulse we will output from the triggers is loaded from a constant at top of procedure file.
// The pulse is always low-to-high, but that could easily be loaded  from a constant or a global variable as well
// Last Modified 2015/04/12 by Jamie Boyd
Function NQ_doTriggers (s)
	STRUCT NQ_ScanStruct &s
	
	//variable trigWidth = kNQtrigWidth *1e5 // translate to ticks of 100 kHz clock
	variable theTrig, counterConst, outPutPinConst, trigDelay, NidaqError
		if (s.scanmode == kLIvemode)
			return 0
		endif
		try
			For (thetrig = 1; thetrig < 3; thetrig += 1)
				if (s.trigChans&theTrig)
					trigDelay =SelectNumber(thetrig -1,  s.trig1Pos, s.trig2Pos)
					DAQmx_CTR_OutputPulse /DEV=s.ePhysBoard/SEC={kNQtrigWidth, kNQtrigWidth} /IDLE=0/DELY=(trigDelay) /NPLS=1/STRT=1/TRIG="/" + s.imageBoard + "/ao/StartTrigger" (thetrig -1) ; AbortOnRTE
//				
//				// Select NIDAQ constants for counter 0 or 1 and corresponding output pins
//				counterConst = SelectNumber(thetrig -1, ND_COUNTER_0, ND_COUNTER_1)
//				outPutPinConst =  SelectNumber(thetrig -1, ND_GPCTR0_OUTPUT, ND_GPCTR1_OUTPUT)
//				// select trigger delay for counter 0 or 1
//				trigDelay =SelectNumber(thetrig -1,  s.trig1Pos, s.trig2Pos)
//				// reset the counter
//				NidaqError = ftwoP_GPCTR_Control(s.ePhysBoardslot, counterConst, ND_RESET)
//				abortonvalue NidaqError, 0 
//				//set  application to triggered pulse generation
//				NidaqError = ftwoP_GPCTR_Set_Application(s.ePhysBoardslot, counterConst, ND_SINGLE_TRIG_PULSE_GNR)
//				abortonvalue NidaqError, 1
//				// set source of the counter to 100 kHz internal clock
//				NidaqError = ftwoP_GPCTR_Change_Parameter(s.ePhysBoardslot, counterConst, ND_SOURCE, ND_INTERNAL_100_KHZ)
//				abortonvalue NidaqError, 2
//				// set gate (pulse trigger) to be  RTSI 2.  RTSI 2 is the Line Gate signal or, if doing ephys only, it is the the ePhys convert signal 
//				NidaqError = ftwoP_GPCTR_Change_Parameter(s.ePhysBoardslot, counterConst, ND_GATE, ND_RTSI_2)
//				abortonvalue NidaqError, 3
//				// set time to delay before pulse.
//				NidaqError = ftwoP_GPCTR_Change_Parameter(s.ePhysBoardslot, counterConst, ND_COUNT_1, (TrigDelay))
//				abortonvalue NidaqError, 4
//				// set width of pulse
//				NidaqError = ftwoP_GPCTR_Change_Parameter(s.ePhysBoardslot,counterConst, ND_COUNT_2, (TrigWidth))
//				abortonvalue NidaqError, 5
//				//prepare and arm the counter
//				NidaqError = ftwoP_GPCTR_Control(s.ePhysBoardslot, counterConst, ND_PREPARE)
//				abortonvalue NidaqError, 6
//				NidaqError = ftwoP_GPCTR_Control(s.ePhysBoardslot,  counterConst, ND_ARM)
//				abortonvalue NidaqError, 7
			endif
		endFor
	catch
		string errMsg = fdaqmx_errorString()
		printf  "The \"NQ_doTriggers\" function failed at position %d. The Error message was:\r%s\r", V_AbortCode, errMsg
		return 1
	endtry
	return 0	// exit with success
end

//******************************************************************************************************
// Starts the ephys board ready to scan, waiting for image board, or starts ePhys scan if doing ephys alone
// sets input trigger to waveform generator or, for ePhys alone,  sends scan start to RTSI
//  returns 1 if an error ocurred, else 0
// Last Modified 2013/07/29 by Jamie Boyd
Function NQ_doEphysInit (s)
	STRUCT NQ_ScanStruct &s
	
	variable NidaqError
	string endFuncStr
	string errFuncStr
	//sprintf errFuncStr, "NQ_ScanEnd(3, %s)",  s.ScanMode
	//sprintf endFuncStr, "NQ_ScanEnd(0, %s)",  s.ScanMode

	try
		if (s.ScanMode == kePhysOnly)
			if (s.inPutTrigger)
				DAQmx_Scan /DEV= s.ePhysBoard/STRT=1/TRIG= {"/" + s.imageBoard + "/PFI6",1}/BKG=1 WAVES= s.ePhysPath;abortonRTE
			else
				DAQmx_Scan /DEV= s.ePhysBoard/STRT=1/BKG=1 WAVES= s.ePhysPath;abortonRTE
			endif
		else
			DAQmx_Scan /DEV= s.ePhysBoard/STRT=1/TRIG= {"/" + s.imageBoard + "/ao/StartTrigger",1,0,0,0}/BKG=1 WAVES= s.ePhysPath;abortonRTE
		endif
	catch
		printf  "The \"NQ_doEphysInit\" function failed at position %d. The Error message was:\r%s\r", V_AbortCode, fdaqmx_errorString ()
		return 1
	endtry
	//	try 
	//		if (s.ScanMode == kePhysOnly)
				// Export Convert signal to RTSI 2 - where it can be used to start timers for triggers, etc.,  If not doing ephys alone, we'll have a signal from other board to start stuff
	//			fDAQmx_ConnectTerminals(SourceTerminal, DestTerminal, Invert)
	//			NidaqError = ftwoP_Select_Signal(s.ePhysBoardslot, ND_RTSI_2, ND_IN_Convert, ND_HIGH_TO_LOW)
	//			AbortOnValue NidaqError, 1
	//			// wait for trigger
	//			if (s.inPutTrigger)
	//				NidaqError = ftwoP_Select_Signal(s.ePhysBoardslot, ND_OUT_START_TRIGGER, ND_PFI_6, ND_LOW_TO_HIGH)
	//				AbortOnValue NidaqError, 2
	//			else
	//				NidaqError = ftwoP_Select_Signal(s.ePhysBoardslot, ND_OUT_START_TRIGGER, ND_AUTOMATIC, ND_LOW_TO_HIGH)
	//				abortOnValue NidaqError, 3
	//			endif
	//			if (s.ScanToDisk)
	//				NidaqError =ftwoP_ScanFIFO (s.EphysBoardSlot, s.ePhysGain, s.ePhysPath, (0.5 * s.EphysFreq) , 0, errFuncStr, "")
	//				AbortOnValue NidaqError, 4
	//			else
	//				NidaqError = ftwoP_ScanAsyncStart (s.EphysBoardSlot, s.ePhysGain, s.ePhysPath, 0, endFuncStr, errFuncStr, "")
	//				AbortOnValue NidaqError, 5
	//			endif
	//		else
	//			// if not doing ephys alone, select trigger signal for Scan starting to be RTSI 1, the signal output by counter 0 from board 1. E-Phys trace will start on the fisrst pixel of the first frame of first image
	//			NidaqError =ftwoP_Select_Signal(s.ePhysBoardslot, ND_IN_START_TRIGGER, ND_RTSI_1,  ND_LOW_TO_HIGH)
	//			AbortOnValue NidaqError, 6
	//			// start ePhys waiting on galvo start
	//			if (s.ScanToDisk)
	//				NidaqError =ftwoP_ScanFIFO (s.EphysBoardSlot, s.ePhysGain, s.ePhysPath, (0.5 * s.EphysFreq) , 257, errFuncStr, "")
	//				AbortOnValue NidaqError, 7
	//			else
	//				NidaqError = ftwoP_ScanAsyncStart (s.EphysBoardSlot, s.ePhysGain, s.ePhysPath, 1, endFuncStr, errFuncStr, "")
	//				AbortOnValue NidaqError, 8
	//			endif
	//		endif
	//	catch
	//		printf  "The \"NQ_doEphysInit\" function failed at position %d. The Error message was:\r%s\r", V_AbortCode, "" //NQGetErrorString (NidaqError)
	//		return 1
	//	endtry
	return 0	// exit with success
end



//******************************************************************************************************
// Gets the ephys board ready to Output Voltage Waves using waveform generator 0 and waveform generator 1
//  returns 1 if an error ocurred, else 0
// Last Modified May 30 2012 by Jamie
Function NQ_DoVoltagePulseWaves (s)
	STRUCT NQ_ScanStruct &s
	
	try
		variable NidaqError
		string VoltageWavePath = ""
		// Make VoltageWavePath string ready for NIDAQ command
		if (1 & s.vOutChans) // channel 1 is selected
			VoltageWavePath += "root:packages:twoP:acquire:VoltagePulseWaves:" + s.vOutWave1 + " , 0;"
		endif
		if (2 & s.vOutChans) // channel 2 is selected
			VoltageWavePath +=  "root:packages:twoP:acquire:VoltagePulseWaves:" + s.vOutWave2 + " , 1;"
		endif
		// Configure triggers
		if (s.vOutStart == 1) // start voltage output on Line Gate - which is always output to RTSI 2 
			//NidaqError = ftwoP_Select_Signal(s.ephysBoardSlot,ND_OUT_START_TRIGGER, ND_RTSI_2, ND_LOW_TO_HIGH)
			abortonvalue NidaqError, 0
		else // Starting on trigger 1
			if ((s.trigChans&1) == 0) // Trigger 1 is not in use
				print "trigger 1 is not selected, so no voltage waves will be output"
				return 0
			endif
			// Route ePhys board counter 0 output to RTSI 3, where we can use it as a start signal
			//NidaqError = ftwoP_Select_Signal (s.ephysBoardSlot,  ND_RTSI_3, ND_GPCTR0_OUTPUT, ND_LOW_TO_HIGH)
			abortonvalue NidaqError, 1
			// Select RTSI line 3 as start signal 
			//NidaqError =ftwoP_Select_Signal(s.ephysBoardSlot,ND_OUT_START_TRIGGER, ND_RTSI_3, ND_LOW_TO_HIGH)
		endif
		// Start waveform generator
		abortonvalue NidaqError, 2
		//NidaqError = ftwoP_WaveformGen(s.ephysBoardSlot, VoltageWavePath, 32)
		abortonvalue NidaqError, 3
	catch
		printf  "The \"NQ_doVoltagePulseWaves\" function failed at position %d. The Error message was:\r%s\r", V_AbortCode, "" //NQGetErrorString (NidaqError)
		return 1
	endtry
	return 0	// exit with success
end

//******************************************************************************************************
// Makes the X and Y scan waves output to the Galvos by the Analog out channels on the image board for the various scan types
//  returns 1 if an error ocurred, else 0
// Last Modified 2014/10/02 by Jamie Boyd
Function NQ_MakeGalvoScanWaves (s)
	STRUCT NQ_ScanStruct &s
	
	variable anError
	try
		// Check input for errors
		// scan mode can not be ePhysOnly
		if (s.ScanMode == kEphysOnly)
			return 0
		endif
		// PixWidth needs to greater than 2
		anError = (s.pixWidth < 2)
		AbortOnValue anError, 2
		//PixHeight needs to be 2 or more, but is not used for linescan
		if (s.scanMode == kLineScan)
			anError = (s.pixHeight < 2)
			AbortOnValue anError, 3
		endif
		//PixHeight needs to be even for turbo mode
		if (s.flybackMode == 1)
			anError = (mod (s.PixHeight, 2) != 0)
			AbortOnValue anError, 4
		endif
		//dutyCycle needs to be between 0 and 1
		anError = ((s.dutyCycle < 0) || (s.dutyCycle > 1))
		AbortOnValue anError, 5
		//Pixel Time needs to be greater than about a microsecond, probably a generous maximum is .01 sec
		anError = ((s.pixTime < 0.5e-06) || (s.pixTime > 0.1))
		AbortOnValue anError, 7
		// scanpnts = linear scaning plus the scan half of turnaround
		// FBpnts = flyback points, including the turnaround points. FBpnts is 0 if using bidirectional scanning
		variable  scanpnts = round (s.Pixwidth/s.DutyCycle)
		variable FBpnts =  s.flybackMode == 0 ? round (s.Pixwidth*s.FlyBackProp/s.DutyCycle) : 0
		variable Slope =  (s.xEV - s.xSV)/(pi * s.DutyCycle) //for the straight line
		variable FitTolerance = (abs(s.xEV - s.xSV)/2) * 0.1
		variable intercept=(s.xEV + s.xSV)/2
		variable OutPutMode = (abs(s.ScanMode) == kLineScan) + (s.FlybackMode==1)*2 
		Variable V_fitOptions=4
		//Make a wave (ScanTemp) corresponding to one horizontal line constraining sin expansion to a straight line over the data collection range
		make/o/n= (scanpnts) root:packages:twoP:acquire:ScanTemp
		WAVE ScanTemp = root:packages:twoP:acquire:ScanTemp
		make/o/n = (s.PixWidth) root:Packages:twoP:acquire:StraightLine// A straight line to constrain sine fit over the scanning region
		WAVE StraightLine = root:Packages:twoP:acquire:StraightLine
		SetScale x (-pi* s.DutyCycle/2), (pi* s.DutyCycle/2),"", StraightLine
		StraightLine = intercept + ( Slope * x)
		//acount for scanhead delay in the phase fitting parameter We already know 1) pixel time in seconds and 2) pixel scaling in radians 
		variable galvoRadians = ((pi/((s.pixWidth*s.pixTime)/s.dutyCycle)) * s.ScanHeadDelay)
		if (outPutMode&2)
			//Use the fitting function with phase term. Move straight line and ScanTemp so phase starts at beginning of flyback
			SetScale x ((-pi* s.DutyCycle/2) + (1-s.DutyCycle)/2*pi), ((pi* s.DutyCycle/2) + (1-s.DutyCycle)/2*pi),"", StraightLine
			WAVE Scan_coefs =  root:packages:twoP:acquire:Scan_Coefs_sym //Coeficient wave for Sine curve fitting will hold the fitted values
			//We know what scaling parameter should be based on voltages. Setting it ahead of time speeds up fit
			Scan_coefs [3] = ((s.XEV + s.XSV)/2)
			FuncFit/Q/w=0 SinExpansionPh Scan_coefs StraightLine
			anError = ((Scan_Coefs [3] < ((s.XEV + s.xSV)/2) -FitTolerance)  ||  (Scan_Coefs [3] > ((s.XEV + s.XSV)/2) + FitTolerance))
			AbortOnValue anError, 8
			Scanpnts *= 2
			redimension/n = (Scanpnts) ScanTemp //doing both sides of scan symetrically, so rescale 
			SetScale x (-pi/2),(1.5*pi),"", ScanTemp
			//account for galvo delay
			Scan_Coefs [4] += GalvoRadians
			ScanTemp = SinExpansionPh (Scan_coefs,x)
		else
			SetScale x (-pi/2), (pi/2), "", ScanTemp
			WAVE Scan_coefs =  root:packages:twoP:acquire:Scan_Coefs //Coeficient wave for Sine curve fitting will hold the fitted values
			Scan_coefs [3] = ( s.XEV + s.XSV)/2
			FuncFit/Q/w=0 SinExpansion Scan_coefs StraightLine
			anError = ((Scan_Coefs [3] < ((s.XEV + s.XSV)/2) -FitTolerance)  ||  (Scan_Coefs [3] > ((s.XEV + S.XSV)/2) + FitTolerance))
			AbortOnValue anError, 8
			ScanTemp = SinExpansion (Scan_coefs,x)
			make/o/n = (FBPnts) root:packages:twoP:acquire:ScanTemp1
			WAVE ScanTemp1 = root:packages:twoP:acquire:ScanTemp1
			//make flyback portion of the line with a simple unconstrained sin wave that matches the maximum and minimum
			//voltages of the data collection part of the scan
			variable FBScal= (Scantemp [Scanpnts-1] - Scantemp [0])/2
			variable toRotate = -(BinarySearch(ScanTemp, s.XEV))	//need to rotate to get start of turnaround at beginning of wave
			make/o/n= (FBPnts) ScanTemp1
			SetScale/I x (pi/2), (-pi/2),"", ScanTemp1
			ScanTemp1 =  FBScal * (sin (x)) + intercept
			redimension/n=(scanpnts + FBPnts) ScanTemp
			ScanTemp [ScanPnts, Scanpnts + FBPnts -1] = ScanTemp1 [p-ScanPnts]
			rotate (toRotate), ScanTemp
			//rotate for scanhead delay
			toRotate = -s.ScanHeadDelay/s.pixtime
			rotate (toRotate), ScanTemp
			SCanPnts += FBPnts
		endif
		//Make the horizontal output wave and fill it with multiple copies of ScanTemp, or just one copy for linescan mode
		if (OutPutMode&1)	// Line Scan
			make/o/n= (scanpnts) root:packages:twoP:acquire:HorWave
			WAVE HorWave = root:packages:twoP:acquire:HorWave
			horwave = ScanTemp
		else //Image
			variable ii, Scanpnts_total
			if (OutPutMode&2) // Turbo
				Scanpnts_total = ScanPnts * s.PixHeight/2
			else
				Scanpnts_total = scanpnts * s.PixHeight
			endif
			make/o/n= (Scanpnts_total) root:packages:twoP:acquire:HorWave
			WAVE HorWave = root:packages:twoP:acquire:HorWave
			for (ii =0; ii < Scanpnts_total; ii += scanpnts)
				Horwave [ii, ii + scanpnts-1] = ScanTemp [p-ii]
			endfor
		endif
		SetScale/p x 0, (s.PixTime) ,"", HorWave //just to make it nice if displaying horwave for testing purposes
		//Make the vertical wave
		if (!(OutPutMode&1)) // Only images, not line scans, need vertical waves
			//Make vertical wave It has only one flyback. It keeps the same value for duration of a line, followed by a single jump to the next value
			make/o/n = (Scanpnts_total)root:packages:twoP:acquire:VerWave
			WAVE VerWave = root:packages:twoP:acquire:VerWave
			variable VerFbPnts
			variable volts, voltdiv = (s.YEV - s.YSV)/(s.PixHeight -1)
			//First  the flyback
			if (OutPutMode&2)
				VerFbPnts = round(s.PixWidth/s.DutyCycle) -s.PixWidth
				ScanPnts/=2
			else
				VerFBPnts = round(s.PixWidth/s.DutyCycle + FBPnts) -s.PixWidth
			endif
			redimension/N = (VerFbPnts) ScanTemp	// reuse this temp wave to make the chunk of sine wave
			SetScale x (-pi/2), (pi/2),"", ScanTemp
			FBScal = (s.YEV - s.YSV)/2
			intercept = (s.YEV + s.YSV)/2
			ScanTemp =  intercept -FBScal * (sin (x))
			VerWave [0, VerFbPnts-1] = ScanTemp [p]
			//Set the voltage level for the first scanline
			VerWave [VerFBPnts, (VerFBPnts + s.pixWidth -1)] = s.YSV
			//make the jumps at each new line for the number of lines in the image
			For (ii = 0, volts = s.YSV + VoltDiv; ii < s.PixHeight-1; ii += 1,volts += voltdiv )
				VerWave [(ii * Scanpnts + VerFBPnts + s.PixWidth), ((ii + 1)* Scanpnts + VerFBPnts + s.PixWidth)-1] = volts
			Endfor
			if (OutPutMode&2) //Turbo
				rotate (-galvoRadians/((2*pi)/scanpnts)), VerWave //rotate wave to match horizontal wave
			endif
			SetScale/p x 0,(s.PixTime) ,"", VerWave
			killwaves/z ScanTemp, ScanTemp1, straightLine
			return 0  //successs
		endif
	catch
		switch (V_abortCode)
			case 1:
				print "NQ_MakeGalvoScanWaves Error: electrophysiology-only scan."
				break
			case 2:
				print "NQ_MakeGalvoScanWaves Error: PixWidth needs to be 2 or greater."
				break
			case 3:
				print "NQ_MakeGalvoScanWaves Error: PixHeight needs to be 2 or greater."
				break
			case 4:
				print "NQ_MakeGalvoScanWaves Error: PixHeight needs to be even for turbo mode."
				break
			case 5:
				print "NQ_MakeGalvoScanWaves Error: DutyCycle needs to be between 0 and 1."
				break
			case 7:
				print "NQ_MakeGalvoScanWaves Error: PixTime needs to be between 1 microsecond and 100 milliseconds."
				break
			case 9:
				print "NQ_MakeGalvoScanWaves Error: Curve fitting for the sine expansion did not converge properly."
				make/o/D root:packages:twoP:acquire:Scan_Coefs = {-7.4, -0.65, -0.13, -0.015}
				break
			case 8:
				print "NQ_MakeGalvoScanWaves Error: Curve fitting for the sine expansion for bi-directional scanning did not converge properly."
				make/o/D root:packages:twoP:acquire:Scan_Coefs_Sym = {-7.4, -0.65, -0.13, 0.08, 0.17}
				break
		endswitch
		//killwaves/z ScanTemp, ScanTemp1, straightLine
		return 1 //failure
	endtry
end

//******************************************************************************************************
// Fitting function used to make the horizontal scanwave out of a series of sin components
Function SinExpansion(w,x) : FitFunc
	Wave w
	Variable x

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(x) = H * (sin (x)) - H3 * (sin (3 * x)) + H5 * (sin (5 * x)) + offset
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 4
	//CurveFitDialog/ w[0] = H
	//CurveFitDialog/ w[1] = H3
	//CurveFitDialog/ w[2] = H5
	//CurveFitDialog/ w[3] = offset
	return w[0] * (sin (x)) - w[1] * (sin (3 * x)) + w[2] * (sin (5 * x)) + w[3]
End

//******************************************************************************************************
// Fitting function used to make the horizontal scanwave out of a series of sin components, now with phase offset
Function SinExpansionPh(w,x) : FitFunc
	Wave w
	Variable x

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(x) = H * (sin (x+ph)) - H3 * (sin (3 * (x+ph))) + H5 * (sin (5 * (x+ph))) + offset
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 5
	//CurveFitDialog/ w[0] = H
	//CurveFitDialog/ w[1] = H3
	//CurveFitDialog/ w[2] = H5
	//CurveFitDialog/ w[3] = offset
	//CurveFitDialog/ w[4] = phase rotation, in radians
	return w[0] * (sin (x+w[4])) - w[1] * (sin (3 *( x + w[4]))) + w[2] * (sin (5 * (x+w[4]))) + w[3]
End


//******************************************************************************************************
// Function called by the "Start Scan" Button.
// Last Modified:
// 2017/08/14  by Jamie Boyd - started adding ePhys stuff back in
Function NQ_StartScan (ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			string Status = ba.userData
			variable err =0, errPos
			NVAR percentComplete =root:packages:twoP:Acquire:PercentComplete
			SVAR stageProc = root:Packages:twoP:Acquire:StageProc
			SVAR stagePort = root:packages:twoP:acquire:StagePort
			NVAR scanMode = root:packages:twoP:Acquire:ScanMode
			NVAR ScanStartMode = root:packages:twoP:Acquire:ScanStartMode
			strswitch (Status)
				case "Abort Multi":
					NQ_MultiAqReset ()
					if (percentComplete == 0) // not during a scan, else no break and execution continues in next case
						break
					endif
				case  "Abort": // User aborting a running scan, or stopping live scanning
					NQ_ScanEnd (ScanStartMode, 1)
					break
				case "Start Multi":
					return NQ_MultiAqInit ()
					break
				case "Start": // starting a new scan; including multiAcq
					// save scan mode in case user flips tabcontrol before stopping scan
					ScanStartMode = scanMode
					// Change Start button color to yellow to show we are show initializing a scan, and update userData to "abort"
					Button AqStartButton, win = twoP_Controls, fColor=(65280,65280,0), title = "Init", userData ="Abort"; doUpdate
					// set percent complete to > 0, so if we abort, we know to shut down
					percentComplete = 0.01
					try
						STRUCT NQ_ScanStruct s
						NQ_LoadScanStruct (s, 1)
						// Set current scan global
						SVAR CurScan= root:packages:twoP:Examine:CurScan
						CurScan = s.NewScanName
						// Check for overwriting of new scan 
						errPos=0
						err = NQ_CheckOverWrite (s);AbortOnValue (err), errPos 
						// set galvos to start of X and Y images
						fDAQmx_WriteChan(s.ImageBoard, 0, s.xsv, -10, 10)
						fDAQmx_WriteChan(s.ImageBoard, 1, s.xsv, -10, 10)
						// make scan waves
						errPos=1
						err = NQ_MakeImageScanWaves (s);AbortOnValue (err), errPos //^^11
						// Check to see if ephys is requested and make wave(s) if so.
						if (s.ephysChans)
							errPos=2
							err = NQ_MakeEphysWaves (s);AbortOnValue (err), errPos 
						endif
						if (S.ScanToDisk ==0)
							if (s.ScanMode == kePhysOnly)
								NQ_NewTracesGraph (s.NewScanName)
							else
								NQ_NewScanGraph (s.NewScanName)
								if (s.ephysChans != 0)
									NQ_NewTracesGraph (s.NewScanName)
								endif
								if ((s.ScanMode == kLiveMode) || (s.ScanMode) == kTimeSeries)
									if (s.liveROISecs > 0)
										NQ_MakeLROIGraph (s)
									endif
									if (s.ScanMode == kLiveMode)
										// live histogram graph
										if (s.liveHist == 1)
											NQ_MakeHistGraph (s.scanChans, "LiveWave")
										endif
										// zero liveFrame pos for avergaing
										if (s.LiveAvgFrames)
											NVAR LiveAvgPos = root:packages:twoP:Acquire:LiveAvgPos
											LiveAvgPos = 0
										endif
									endif
								endif
							endif
							// if doing Z, move focus  to correct location
							if (s.ScanMode == kZSeries) 
								// set the focus to the first Z
								variable xS=NaN, yS=NaN, zS=s.zPos, axS =NaN
								funcref StageMove_Template stageMove = $"StageMove_" + s.stageProc
								stageMove (0, 0, xS, yS, zS, axS)
								// Set focus increment to zStepsize
								funcref StageSetInc_Template SetInc= $"StageSetInc_" + s.stageProc
								SetInc (zVal=s.zStepSize)
							endif
							// Lock stage for all but live mode
							if (s.ScanMode != kLiveMode)
								funcref StageSetManual_Template setManual = $"StageSetManual_" +  s.stageProc
								setManual (1)
							endif
							// Only have to make galvo waves once when doiing multiAq
							NVAR iAq = root:packages:twoP:acquire:multiAqiAq
							if (((s.isMulti) && (iAq ==0)) || (!(s.isMulti)))
								// Make the X and Y Galvo  waves
								errPos=3
								err = NQ_MakeGalvoScanWaves (s);AbortOnValue (err), errPos 
							endif
						endif
						// Start some threads
						NQ_StartBKGThreads (s)
					catch // reset start button and make sure stage is unlocked. No need to reset Nidaq, and functions that would
						// return errors gave their own alerts
						if (s.isMulti)
							NQ_MultiAqReset ()
						endif
						Button AqStartButton, win = twoP_Controls, fColor=(0,65280,0), title = "Start", userData = "Start"
						NVAR percentComplete = root:packages:twoP:Acquire:percentComplete
						percentComplete = 0
						//print s.stageProc
						funcref StageSetManual_Template setManual = $"StageSetManual_" + s.stageProc
						setManual (0)
						return 1
					endtry
					// Now set up Nidaq stuff
					try
						// Check for digital output triggers. These are done on counter 0 and counter 1 of ephys board.  These can used to trigger a stimulator, e.g. 
						if (s.ScanMode != kZseries)
							if (s.trigChans > 0)
								errPos =4
								err =NQ_DoTriggers (s);AbortOnValue (err), errPos 
							endif
							// Check for voltage Pulse outputs, done on Analog out chan 0 and 1 on ephys board
							if (s.VoutChans > 0)
								errPos =5
								err= NQ_DoVoltagePulseWaves (s);AbortOnValue (err), errPos 
							endif
						endif
						if (s.ScanMode == kePhysOnly)
							errPos=6
							err = NQ_doEphysInit (s);AbortOnValue (err), errPos 
						else // an image scan
							// Check for ePhys
							if (s.ePhysChans > 0)
								errPos=9
								err = NQ_doEphysInit (s) ;AbortOnValue (err), errPos 
							endif
							// Start image scanning and waveform outputting
							errPos=10
							err = NQ_ScanInit (s);AbortOnValue (err), errPos 
						endif
						// Show User that we are scanning
						String bkgTaskName
						if (s.Scanmode == kLiveMode) // no back ground task needed; do it all from a 
							Button AqStartButton, win = twoP_Controls,title="Stop", fColor=(65280,0,0)
						elseif (s.inPutTrigger)
							Button AqStartButton  win = twoP_Controls,title="Abort", fColor=(65280,65280,0)
							CtrlNamedBackground trigCheck, period=10, proc=NQ_triggerCheckerBkg, start  // first replacement of GIPbkg with Igor 6 named background. Not tested
						else
							Button AqStartButton  win = twoP_Controls,title="Abort", fColor=(65280,0,0)
							variable/g root:packages:twoP:acquire:tSeriesStart = ticks
							if ((s.ScanMode == kTimeSeries) && (s.scanIsCyclic ==0))
								//CtrlNamedBackground Tseries_Bkg proc = NQ_Tseries_Bkg, period=max (30,  floor (s.frameTime * 60)), start = ticks + 2 + floor (s.frameTime * 60)
							elseif (s.ScanMode == kLineScan)
								CtrlNamedBackground LineScan_Bkg proc = NQ_LineScan_Bkg, period=30, start = ticks + 30
							elseif ((s.ScanMode == kSingleImage) && (s.NumFrames > 1))
								GUIPbkg_AddTask("NQ_SingleImage_Bkg",max (2,  1/s.frameTime),  1, funcParamList="\"+ s.NewScanName + \"")
							endif
						endif
						// And we are done
					catch // Nidaq error
						// reset multiAq, if needed
						if (s.isMulti)
							NQ_MultiAqReset ()
						endif
						// reset start button and percent complete
						Button AqStartButton, win = twoP_Controls, fColor=(0,65280,0), title = "Start", userData = "Start"
						NVAR percentComplete = root:packages:twoP:Acquire:percentComplete
						percentComplete = 0
						// UnLock the stage
						funcref StageSetManual_Template setManual = $"StageSetManual_" + s.stageProc
						setManual (0)
						// alert user
						string funcStr = "NQ_StartScan"
						switch (V_AbortCode)
							case 1: 
								funcStr ="NQ_DoTriggers"
								break
							case 2:
								funcStr = "NQ_DoVoltagePulseWaves"
								break
							case 3:
							case 5:
								funcStr = "NQ_doEphysInit"
								break
							case 4:
								funcStr = "NQ_setupScanCountersandGates"
								break
							case 6:
								funcStr = "NQ_ScanInit"
								break
						endSwitch
						doAlert 1, "The " + funcStr + " function failed with a NIDAQ error, which has been printed in the history. Do you wish to reset the NI boards?"
						if (V_Flag == 1)
							NQ_ResetBoards (1)
						endif
						
						return 1
					endtry
					break
			endswitch // status code switch
			break
	endSwitch  // button even switch
	return 0
end	


//******************************************************************************************************
// Starts the image board scanning, or waiting for input trigger
//  returns 1 if an error ocurred, else 0
// Last Modified:
// 2017/08/21 by Jamie Boyd - adding support for input trigger
// 2016/11/15 by Jamie Boyd - adding support for background task per channel
Function NQ_ScanInit (s)
	STRUCT NQ_ScanStruct &s
	
	if (s.scanmode== kephysOnly)
		return 0
	endif
	// Make strings for repeatHook function and error function
	// continuous repeat hook function that signals threads
	string RPTCstr
	sprintf RPTCstr, "NQ_RepeatHook(%d)", s.ScanMode
	// function that runs at end of scanning
	string ScanEndStr
	sprintf ScanEndStr, "NQ_ScanEnd (%d, 0)", s.ScanMode   // 0 for not aborting, regular scan end
	// function that runs in case of error, same function, different params
	string ScanErrStr
	sprintf ScanErrStr, "NQ_ScanEnd (%d, 1)", s.ScanMode  // 1 for image board error
	//set up NI stuff
	variable NidaqError, errPos
	try
		// Set counter 1  to make the LineGate - it is low during data collection portion of the line, high during turnaround/flyback
		
			errPos=1
			DAQmx_CTR_OutputPulse /DEV=s.ImageBoard/TICK={s.PixWidth-1, (s.PixWidthTotal - (s.PixWidth-1))} /IDLE=1 /NPLS=0/TBAS="/" + s.ImageBoard + "/ao/SampleClock" /Rate=1e06 1; ABORTONRTE
			// output the line gate to the normal counter1 output pin
			errPos=2
			NidaqError = fDAQmx_ConnectTerminals("/" + s.ImageBoard + "/Ctr1InternalOutput", "/" + s.ImageBoard + "/ctr1Out", 0); AbortOnValue NidaqError,errPos
			// while we are connecting signals, may as well ouput scan clock and input sample clock for use with chunkulator, e.g.
			errPos =3
			NidaqError = fDAQmx_ConnectTerminals("/" + s.ImageBoard + "/ao/SampleClock", "/" + s.ImageBoard + "/PFI5", 0); AbortOnValue NidaqError,errPos
			errPos =4
			NidaqError = fDAQmx_ConnectTerminals("/" + s.ImageBoard + "/ai/SampleClock", "/" + s.ImageBoard + "/PFI7", 0); AbortOnValue NidaqError,errPos
		
		Switch (s.ScanMode)
			case kTimeSeries:				
				if (s.ScanToDisk)
					errPos =5
					//NidaqError =ftwoP_ScanFIFO (s.ImageBoardSlot, s.scanGain, s.scanWavePath, kImageFifoTransfer, 392 ,ScanErrStr, "") // maybe add 256?
					//AbortOnValue NidaqError,0
				else
					if (s.scanIsCyclic)
						errPos =6
						DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/ao/SampleClock", 1}/PAUS={"/" + s.imageBoard + "/Ctr1InternalOutput", 1, 0, 0}/RPTC/RPTH=RPTCstr/ERRH= ScanErrStr WAVES = s.scanWavePath;ABORTONRTE
						AbortOnValue NidaqError,1
					else
						errPos=7
						DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/ao/SampleClock", 1}/PAUS={"/" + s.imageBoard + "/Ctr1InternalOutput", 1, 0, 0}/ERRH= ScanErrStr/EOSH=ScanEndStr WAVES = s.scanWavePath;ABORTONRTE
					endif
				endif
				break
			case kLineScan:
				if (s.scanIsCyclic)
					errPos=8
					//NidaqError =  ftwoP_ScanWavesRepeat(s.ImageBoardSlot, s.scangain, s.scanWavePath, 128, "NQ_LineScanCyclicEnd ()", ScanErrStr, "")
					AbortOnValue NidaqError, 3
				else
					//NidaqError = ftwoP_ScanAsyncStart(s.ImageBoardSlot, s.scangain, s.scanWavePath, 128, ScanEndStr, ScanErrStr, "")
					errPos=9
					DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/ao/SampleClock", 1}/PAUS={"/" + s.imageBoard + "/Ctr1InternalOutput", 1, 0, 0}/ERRH= ScanEndStr WAVES = s.scanWavePath;ABORTONRTE
				endif
				break
			case kSingleImage:
				errPos=10
					//NidaqError = ftwoP_ScanAsyncStart(s.ImageBoardSlot, s.scangain, s.scanWavePath, 128, ScanEndStr, ScanErrStr, "")
					AbortOnValue NidaqError, 5
				errPos=9
				DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/ao/SampleClock", 1}/PAUS={"/" + s.imageBoard + "/Ctr1InternalOutput", 1, 0,0}/ERRH= ScanEndStr WAVES = s.scanWavePath;ABORTONRTE

				break
			case kZSeries:
				//print s.scanWavePath
				errPos =10
				DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/ao/SampleClock", 1}/PAUS={"/" + s.imageBoard + "/Ctr1InternalOutput", 1, 0, 0}/RPTC/RPTH=RPTCstr/ERRH= ScanErrStr WAVES = s.scanWavePath;ABORTONRTE
				break
			case kLiveMode:
				errPos = 11				
				DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/ao/SampleClock", 1}/PAUS={"/" + s.imageBoard + "/Ctr1InternalOutput", 1, 0, 0}/RPTC/RPTH=RPTCstr/ERRH= ScanErrStr WAVES = s.scanWavePath;ABORTONRTE
				break
			default:
				doalert 0,  "Function \"NQ_ScanInit\" was not expecting a scan Mode of \"" + num2str (s.ScanMode) + "\"."
				abortonvalue 1, 12
		Endswitch				
		// If  not waiting for trigger, open the shutter and select trigger for wave form gen start
		if (s.inPutTrigger == 0)
			// Open up the shutter. Pugged into digital line 0 on the Image Board
			NVAR shutterTaskNum = root:packages:twoP:Acquire:shutterTaskNum
			NidaqError =fDAQmx_DIO_Write (s.ImageBoard, shutterTaskNum, (kNQshutterOpen))
			abortonvalue NidaqError, 9 
			// wait a few milliseconds while shutter opens before continuing
			if (kNQshutterDelay > 0)
				Sleep/c=-1/S kNQshutterDelay
			endif
		endif
		// Start up the waveform generator that actually starts everything going
		string scanWavesList
		If (s.ScanMode == kLineScan)
			scanWavesList = "root:packages:twoP:acquire:HorWave, 0;"
		else
			scanWavesList = "root:packages:twoP:acquire:HorWave, 0;root:packages:twoP:acquire:VerWave, 1;"
		endif
		if (s.inputTrigger)
			//NidaqError = fDAQmx_ConnectTerminals("/" + s.imageBoard + "/PFI6", "/" + s.imageBoard + "/ao/StartTrigger", 0)
			//abortonvalue NidaqError, 10
			DAQmx_WaveformGen /DEV=s.imageBoard /BKG=0/NPRD=0/Strt=1 /TRIG={"/" + s.imageBoard + "/PFI6", 1} scanWavesList; abortOnRTE
		else
			DAQmx_WaveformGen /DEV=s.imageBoard /BKG=0/NPRD=0/Strt=1 scanWavesList;abortOnRTE
		endif
		
	catch
		printf  "The \"NQ_ScanInit\" function failed at position %d. The Error message was:\r%s\r", errPos, fDAQmx_ErrorString()
		return NidaqError // exit with failure
	endtry
	return 0
end

//******************************************************************************************************
// Igor 6 style Named Background task that checks for the input trigger and then
// opens the shutter and then starts the appropriate background-update task
// Last Modified 2015/04/12 by Jamie Boyd
Function NQ_triggerCheckerBkg(s)		// This is the function that will be called periodically
	STRUCT WMBackgroundStruct &s
	
	string imageBoard = stringFromList (1, s.name, "_")
	variable PntsDone = fDAQmx_ScanGetNextIndex(imageBoard)
	if (numtype (PntsDone) ==0 )
		NVAR shutterTaskNum = root:packages:twoP:Acquire:shutterTaskNum
		fDAQmx_DIO_Write(imageBoard, shutterTaskNum,  kNQshutterOpen)
		Button AqStartButton  win = twoP_Controls,title="Abort", fColor=(65280, 0, 0)
		SVAR curScan = root:packages:twoP:examine:curScan
		SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
		variable scanmode = numberbykey ("mode", scanStr, ":", "\r")
		variable/g root:packages:twoP:acquire:tSeriesStart = ticks
		if (scanmode== kTimeSeries)
			//GUIPbkg_AddTask("NQ_Tseries_Bkg", max (2,  1/(numberbykey ("frameTime", scanStr, ":", "\r"))), 1, funcParamList="")
		elseif (ScanMode == kLineScan)
			//GUIPbkg_AddTask("NQ_LineScan_Bkg", 2, 1, funcParamList="")
		elseif ((ScanMode == kSingleImage) && ((numberbykey ("NumFrames", scanStr, ":", "\r")) > 1))
			//GUIPbkg_AddTask("NQ_SingleImage_Bkg",max (2,  1/(numberbykey ("frameTime", scanStr, ":", "\r"))),  1, funcParamList="\"+ s.NewScanName + \"")
		endif
		return 1 // to stop the backgound task
	else
		return 0	// Continue background task
	endif
End

//******************************************************************************************************
// Back ground task to show user occasional frames during a time series scan 
// Last modified 2015/04/12 by Jamie Boyd
Function NQ_Tseries_Bkg(s)
	STRUCT WMBackgroundStruct &s
	
	NVAR startTime = root:packages:twoP:acquire:tSeriesStart
	NVAR PercentComplete = root:packages:twoP:Acquire:PercentComplete
	SVAR curScan = root:packages:twoP:examine:curScan
	SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
	variable chanVar = numberbykey ("ImChans", scanStr, ":", "\r")
	variable numFrames = numberbykey ("numFrames", scanStr, ":", "\r")
	variable frameTime = numberbykey ("frameTime", scanStr, ":", "\r")
	variable flybackMode = numberbykey ("flybackMode", scanStr, ":", "\r")
	variable CurFramePos = min (numFrames-1, max (0,  floor(((ticks-startTime)/60)/frameTime)-1))
	NVAR LiveRoiCheck = root:packages:twoP:acquire:LiveRoiCheck
	NVAR scanToDisk = root:packages:twoP:acquire:scanToDisk
	
	PercentComplete = 100 * (curFramePos + 2)/numFrames
	if (PercentComplete >= 100)
		if (scanToDisk)
			//NQ_ScanEnd (kTimeSeries, 0)
		endif
		return 1
	else
		if (LiveROICheck)
			NVAR left = root:Packages:twoP:Acquire:LROIL
			NVAR top = root:Packages:twoP:Acquire:LROIT
			NVAR right = root:Packages:twoP:Acquire:LROIR
			NVAR bottom = root:Packages:twoP:Acquire:LROIB
			WAVE LroiXwave = root:packages:twoP:acquire:LroiXwave
			variable lastPnt = numpnts (LroiXwave)
			insertpoints lastPnt, 1, LroiXwave
			LroiXwave [lastPnt]  =  CurFramePos * frameTime
		endif
		if (curFramePos < 0)
			return 0
		endif
		// grab theFrame for selected channels 
		string SubWinList = childwindowlist ("twoPScanGraph")
		WAVE/z ch1 = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
		WAVE/z ch2 = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
		variable hasMrg =  (waveExists (ch1))  * (waveExists (ch2))  * (WhichListItem("Gmrg", SubWinList) > -1)
		string valueStr
		sprintf valueStr, "%.1W1Ps", curFramePos * frameTime
		if ((waveExists (ch1)) && ((WhichListItem("GCH1", SubWinList) > -1) || (hasMrg)))
			WAVE scanGraph_Ch1 = root:packages:twoP:examine:scanGraph_Ch1
			ProjectZSlice (ch1, scanGraph_Ch1, CurFramePos)
			if (flybackMode == 1)
				swapeven (scanGraph_Ch1)
			endif
			if (WhichListItem("GCH1", SubWinList) > -1)
				TextBox/W = twoPScanGraph#GCH1/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 valueStr
			endif
			if (LiveRoiCheck)
				WAVE scanGraphCh1 = root:packages:twoP:examine:scanGraph_ch1
				WAVE LROIWave1 = root:Packages:twoP:acquire:LROIWAVE_ch1
				ImageStats/Q/M=1/G={left, right, bottom, top} scanGraphCh1
				insertpoints lastPnt, 1, LROIWave1
				LROIWave1 [lastPnt] = V_avg
			endif
		endif
		if ((waveExists (ch2)) && ((WhichListItem("GCH2", SubWinList) > -1) || (hasMrg)))
			WAVE scanGraph_Ch2 = root:packages:twoP:examine:scanGraph_Ch2
			ProjectZSlice (ch2, scanGraph_Ch2, CurFramePos)
			if (flybackMode == 1)
				swapeven (scanGraph_Ch2)
			endif
			if (WhichListItem("GCH2", SubWinList) > -1)
				TextBox/W = twoPScanGraph#GCH2/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 valueStr
			endif
			if (LiveRoiCheck)
				WAVE scanGraphCh2 = root:packages:twoP:examine:scanGraph_ch2
				WAVE LROIWave2 = root:Packages:twoP:acquire:LROIWAVE_ch2
				ImageStats/Q/M=1/G={left, right, bottom, top} scanGraphCh2
				insertpoints lastPnt, 1, LROIWave2
				LROIWave2 [lastPnt] = V_avg
			endif
		endif
		if (hasMrg)
			NQ_ApplyImSettings (4)
			TextBox/W = twoPScanGraph#gmrg/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 valueStr
			if (LiveROIcheck)
				NVAR RatioCheck = root:Packages:twoP:Acquire:LiveROiRatioCheck
				if (RatioCheck == 1)
					WAVE LROIWaveRat = root:Packages:twoP:acquire:LROIWAVE_ratio
					NVAR TopChan = root:packages:twoP:examine:doDROITopChan
					insertpoints lastPnt,1, LROIWaveRat
					if (TopChan == 1)
						LROIWaveRat [lastPnt] = LROIWave1 [lastPnt]/LROIWave2 [lastPnt]
					else
						LROIWaveRat [lastPnt] =  LROIWave2 [lastPnt]/LROIWave1 [lastPnt]
					endif
				endif
			endif
		endif
	endif
	return 0
end

//******************************************************************************************************
// Back ground task to update percent done during a linescan 
// Last modified 2015/04/14 by Jamie Boyd
//Function NQ_LineScan_Bkg(s)
	STRUCT WMBackgroundStruct &s
	
	NVAR startTime = root:packages:twoP:acquire:tSeriesStart
	NVAR PercentComplete = root:packages:twoP:Acquire:PercentComplete
	NVAR RunTime = root:Packages:twoP:Acquire:RunTime
	variable elapsedTime = (ticks - startTime)/60
	PercentComplete = 100 *elapsedTime/runTime
	NVAR scanChans = root:Packages:twoP:Acquire:ScanChans
	variable yStart = max (0, min ((4 * round ((elapsedTime - 2)/4)), runTime -4))
	variable yEnd = max (4, min ((4 * round ((elapsedTime + 2)/4)), RunTime))
	if (scanChans & 1)
		SetAxis/W=twoPscanGraph#GCH1 left , yStart, yEnd
	endif
	if (scanChans & 2)
		SetAxis/W=twoPscanGraph#GCH2 left , yStart, yEnd
	endif
	return 0
end

//******************************************************************************************************
// Back ground task to update percent done during single image scan with averaging 
// Last modified 2013/08/08 by Jamie Boyd
Function NQ_SingleImage_Bkg(scanName)
	string scanName
	

	NVAR startTime = root:packages:twoP:acquire:tSeriesStart
	NVAR PercentComplete = root:packages:twoP:Acquire:PercentComplete
	SVAR scanStr = $"root:twoP_Scans:" + scanName + ":" + scanName + "_info"
	variable chanVar = numberbykey ("ImChans", scanStr, ":", "\r")
	variable numFrames = numberbykey ("numFrames", scanStr, ":", "\r")
	variable frameTime = numberbykey ("frameTime", scanStr, ":", "\r")
	variable CurFramePos = min (numFrames-1, max (0,  floor(((ticks-startTime)/60)/frameTime)-1))
	PercentComplete = 100 * (curFramePos + 2)/numFrames
	NVAR showCh1 = root:packages:twoP:Examine:showCH1
	NVAR showCh2 = root:packages:twoP:Examine:showCH2
	if ((chanVar & 1) && (showCH1))
		ModifyImage /W=twoPScanGraph#GCH1 $scanName + "_ch1" plane = CurFramePos
	endif
	if ((chanVar & 2) && (showCH2))
		ModifyImage /W=twoPScanGraph#GCH2 $scanName + "_ch2" plane = CurFramePos
	endif
end





	// reference waves and globals
	WAVE/z scanGraph_ch1 = root:packages:twoP:examine:scanGraph_ch1
	WAVE/z scanGraph_ch2 = root:packages:twoP:examine:scanGraph_ch2
	NVAR showMerge = root:packages:twoP:examine:showMerge
	NVAR scanChans = root:Packages:twoP:Acquire:ScanChans
	NVAR flybackmode = root:packages:twoP:Acquire:flybackMode
	NVAR liveHistCheck = root:packages:twoP:Acquire:LiveHistCheck
	NVAR liveAvgCheck =  root:packages:twoP:Acquire:LiveAvgCheck
	NVAR LiveRoiCheck = root:packages:twoP:Acquire:LiveROICheck
	NVAR nLiveFrames =  root:packages:twoP:acquire:nLiveFrames
	WAVE tempWave1 = root:packages:twoP:acquire:LiveAcq_Ch1
	WAVE tempWave2 = root:packages:twoP:acquire:LiveAcq_Ch2
	// Globals to update the wave offsets to reflect current stage position
	SVAR StageProc = root:packages:twoP:acquire:StageProc
	NVAR xDistFromZero = $"root:packages:" + StageProc + ":xDistanceFromZero"
	NVAR yDistFromZero =  $"root:packages:" + StageProc + ":yDistanceFromZero"
	NVAR xRelOffset = root:packages:twoP:acquire:xRelOffset
	NVAR yRelOffset = root:packages:twoP:acquire:yRelOffset
	variable newXoffset, newYoffset, xDelta, yDelta
	// Live average - subtract oldest frame, then add new frame
	if (liveAvgCheck)
		NVAR LiveAvgPos = root:packages:twoP:Acquire:LiveAvgPos
		NVAR numLiveAvgFrames =  root:Packages:twoP:Acquire:numLiveAvgFrames
		string thisWaveStr
		if (scanChans & 1)
			WAVE thisWave = $"root:packages:twoP:acquire:LiveAcq_Ch1" + num2str (LiveAvgPos)
			if (nLiveFrames > 1) // Flatten this frame, if needed, and copy to correct averaging frame position
				KalmanSpecFrames (tempWave1, 0, (nLiveFrames-1),thisWave , 0, 16)
				thisWave /= numLiveAvgFrames
			else
				fastop thisWave =  (1/numLiveAvgFrames) * tempWave1
			endif
			// swap even, if needed
			if (flybackmode == 1)
				swapeven (thisWave)
			endif
			// add this frame to wave displayed in the scan graph and subtract oldest frame
			if (LiveAvgPos < (numLiveAvgFrames - 1))
				fastop scanGraph_ch1 = scanGraph_ch1 + thisWave - $"root:packages:twoP:acquire:LiveAcq_Ch1" + num2str (LiveAvgPos + 1)
				LiveAvgPos += 1
			else
				fastop scanGraph_ch1 =  scanGraph_ch1 + thisWave -root:packages:twoP:acquire:LiveAcq_Ch10
				LiveAvgPos =0
			endif
		endif // end channel 1
		if (scanChans & 2)
			WAVE thisWave = $ "root:packages:twoP:acquire:LiveAcq_Ch2" + num2str (LiveAvgPos)
			if (nLiveFrames > 1) // Flatten this frame, if needed, and copy to correct averaging frame position
				KalmanSpecFrames (tempWave2, 0, (nLiveFrames-1),thisWave , 0, 16)
				thisWave /= numLiveAvgFrames
			else
				fastop thisWave =  (1/numLiveAvgFrames) * tempWave2
			endif
			// swap even, if needed
			if (flybackmode == 1)
				swapeven (thisWave)
			endif
			// add this frame and subtract oldest frame
			if (LiveAvgPos < (numLiveAvgFrames - 1))
				fastop scanGraph_ch2 = scanGraph_ch2 + thisWave - $"root:packages:twoP:acquire:LiveAcq_Ch2" + num2str (LiveAvgPos + 1)
				if (!((scanChans & 1))) // omly update count if it wasn't updated in channel 1 section. 
					LiveAvgPos += 1
				endif
			else
				fastop scanGraph_ch2 =  scanGraph_ch2 + thisWave -$"root:packages:twoP:acquire:LiveAcq_Ch2"
				if (!((scanChans & 1)))
					LiveAvgPos =0
				endif
			endif
		endif // end channel 2
	else // No live averging
		if (scanChans & 1)
			if (flybackmode == 1)
				swapeven (tempwave1)
			endif
			if (nLiveFrames > 1) // Flatten this frame, if needed, and copy to ScanGraph Wave
				KalmanSpecFrames (tempWave1, 0, (nLiveFrames-1),scanGraph_ch1, 0, 16)
			else
				fastop scanGraph_ch1 =tempWave1
			endif
		endif
		if (scanChans & 2)
			if (flybackmode == 1)
				swapeven (tempwave2)
			endif
			if (nLiveFrames > 1) // Flatten this frame, if needed, and copy to LiveWave
				KalmanSpecFrames (tempWave2, 0, (nLiveFrames-1), scanGraph_ch2, 0, 16)
			else
				fastop scanGraph_ch2 =tempWave2
			endif
		endif
	endif 
	// Possibly show merged
	if ((showMerge) && (ScanChans == 3))
		NVAR first1 = root:packages:twoP:examine:CH1FirstLutColor
		NVAR Last1 = root:packages:twoP:examine:CH1LastLutColor
		NVAR first2 = root:packages:twoP:examine:CH2FirstLutColor
		NVAR Last2 = root:packages:twoP:examine:CH2LastLutColor
		wave scanGraphMrg =  root:packages:twoP:examine:scanGraph_mrg
		// red plane ch1
		variable rangevar = 65536/(last1 - first1)
		scanGraphMrg [] [] [0] =  min (65535, max (0,(scangraph_ch1 [p] [q] - first1)) * rangevar)
		// green is channel 2
		rangevar = 65536/(last2 - first2)
		scanGraphMrg [] [] [1] =   min (65535, max (0,(scangraph_ch2 [p] [q] - first2)) * rangevar)
	endif
	// do live hist - this is done on data AFTER averaging
	if (livehistCheck)
		if (scanChans & 1)
			WAVE HistWave = root:Packages:twoP:Examine:HistWaveCh1
			Histogram /B=2 scanGraph_ch1, HistWave
		endif
		if (scanChans & 2)
			WAVE HistWave = root:Packages:twoP:Examine:HistWaveCh2
			Histogram /B=2 scanGraph_ch2, HistWave
		endif
	endif
	//Live ROI
	if (LiveRoiCheck)
		NVAR left = root:Packages:twoP:Acquire:LROIL
		NVAR top = root:Packages:twoP:Acquire:LROIT
		NVAR right = root:Packages:twoP:Acquire:LROIR
		NVAR bottom = root:Packages:twoP:Acquire:LROIB
		variable Ch1Avg
		if (scanChans & 1)
			WAVE scanGraphCh1 = root:packages:twoP:examine:scanGraph_ch1
			WAVE LROIWave1 = root:Packages:twoP:acquire:LROIWAVE_ch1
			ImageStats/Q/M=1/GS={left, right, bottom, top} scanGraphCh1
			LROIWave1 [0] = V_avg
			Ch1Avg = V_avg
			Rotate -1, LROIWAVE1
		endif
		if (scanChans & 2)
			WAVE scanGraphCh2 = root:packages:twoP:examine:scanGraph_ch2
			WAVE LROIWave2 = root:Packages:twoP:acquire:LROIWAVE_ch2
			ImageStats/Q/M=1/GS={left, right, bottom, top} scanGraphCh2
			LROIWave2 [0] = V_avg
			Rotate -1, LROIWAVE2
		endif
		NVAR RatioCheck = root:Packages:twoP:Acquire:LiveROiRatioCheck
		if (RatioCheck == 1)
			WAVE LROIWaveRat = root:Packages:twoP:acquire:LROIWAVE_ratio
			NVAR TopChan = root:packages:twoP:examine:doDROITopChan
			if (TopChan == 1)
				LROIWaveRat [0] = Ch1Avg/V_avg
			else
				LROIWaveRat [0] = V_avg/Ch1Avg
			endif
			Rotate -1, LROIWaveRat
		endif
	endif
	// Possibly update wave offsets, in case position has moved
	WAVE/Z scanGraphCh1  = root:packages:twoP:examine:scanGraph_ch1
	WAVE/Z scanGraphCh2 = root:packages:twoP:examine:scanGraph_ch2
	if (waveExists (scanGraphCh1))
		WAVE aScanWave = root:packages:twoP:examine:scanGraph_ch1
	else
		WAVE aScanWave = root:packages:twoP:examine:scanGraph_ch2
	endif
	newXoffset = xDistFromZero + xRelOffset
	newYoffset =yDistFromZero  + yRelOffset
	if (newXoffset != dimOffset (aScanWave, 0))
		xDelta = dimDelta (aScanWave, 0)
		if (scanChans & 1)
			SetScale /P X, (newXoffset), (xDelta), "m", scanGraphCh1
		endif
		if (scanChans & 2)
			SetScale /P X, (newXoffset), (xDelta), "m", scanGraphCh2
		endif
		if ((showMerge) && (ScanChans == 3))
			SetScale /P X, (newXoffset), (xDelta), "m", scanGraphMrg
		endif
	endif
	if (newYoffset != dimOffset (aScanWave, 1))
		yDelta = dimDelta (aScanWave, 1)
		if (scanChans & 1)
			SetScale /P Y, (newYoffset), (yDelta), "m", scanGraphCh1
		endif
		if (scanChans & 2)
			SetScale /P Y, (newYoffset), (yDelta), "m", scanGraphCh2
		endif
		if ((showMerge) && (ScanChans == 3))
			SetScale /P Y, (newYoffset), (yDelta), "m", scanGraphMrg
		endif
	endif
end


//******************************************************************************************************
// Makes graph for live ROI display, or just brings it to the front if it already exists
// Last Modified Jul 06 2010 by Jamie Boyd 
Function NQ_MakeLROIGraph (s)
	STRUCT NQ_ScanStruct &s
	
	// Kill old lROI graph
	DoWindow/K LROIGraph
	// check for new graph
	if (s.liveROISecs == 0)
		return 0
	endif
	variable nAxes = 0
	string axisStr = ""
	if (s.ScanChans & 1)
		WAVE LROIWave1 = Root:Packages:twoP:acquire:LroiWave_ch1
		if (s.ScanMode == kLiveMode)
			redimension/n= (s.liveROISecs/s.FrameTime) LROIWave1
			SetScale /p x, (-s.liveROISecs), (s.FrameTime),  "",  LROIWave1
			LROIWave1 = Nan
		else
			redimension/n= 0 LROIWave1
		endif
		axisStr [0]= "ch1;"
		nAxes += 1
	endif
	if (s.scanChans & 2)
		WAVE LROIWave2 = Root:Packages:twoP:acquire:LroiWave_ch2
		if (s.ScanMode == kLiveMode)
			redimension/n= (s.liveROISecs/s.FrameTime) LROIWave2
			LROIWave2 = Nan
			SetScale /p x, (-s.liveROISecs), (s.FrameTime),  "",  LROIWave2
		else
			redimension/n= 0 LROIWave2
		endif
		axisStr [0]= "ch2;"
		nAxes += 1
	endif
	NVAR ratioCheck = root:Packages:twoP:Acquire:liveROIRatioCheck
	if (ratioCheck)
		WAVE LroiWave_ratio = Root:Packages:twoP:acquire:LroiWave_ratio
		if (s.ScanMode == kLiveMode)
			redimension/n= (s.liveROISecs/s.FrameTime) LroiWave_ratio
			LroiWave_ratio = Nan
			SetScale /p x, (-s.liveROISecs), (s.FrameTime),  "",  LroiWave_ratio
		else
			redimension/n=0 LroiWave_ratio
		endif
		nAxes += 1
		axisStr [0] = "ratio;"
	endif
	if (s.ScanMode == kTimeSeries)
		WAVE LroiXwave = root:packages:twoP:acquire:LroiXwave
		redimension/n = 0 LroiXwave
	endif
	// Display Graph
	Display/N=twoPLROIGraph as "Live ROI Graph"
	//ApplyWinPosStr ("twoPLROIGraph")
	variable iAxis, axisFrac = (1-.02*(nAxes-1))/nAxes
	string anAxis
	for (iAxis =0; iAxis < nAxes; iAxis += 1)
		anAxis = stringfromlist (iAxis, axisStr) 
		WAVE lROIWave = $"Root:Packages:twoP:acquire:LroiWave_" + anAxis
		if  (s.ScanMode == kLiveMode)
			appendtoGraph/L=$"L_" + anAxis lROIWave
		else
			appendtoGraph/L=$"L_" + anAxis lROIWave vs LroiXwave
		endif
		ModifyGraph freePos($"L_" + anAxis)={0,bottom}
		ModifyGraph axisEnab($"L_" +  anAxis)={(iAxis * axisFrac) + (iAxis * .01) , ((iAxis + 1) * axisFrac) + (iAxis* .01)}
		label $"L_" + anAxis "LROI " + stringfromlist (iAxis, axisStr)
		ModifyGraph lblPos( $"L_" + anAxis)=60
	endfor
	Label bottom "\\Z12Time (Seconds)"
	ModifyGraph rgb =(0,0,0)
	if  (s.ScanMode == kTimeSeries)
		ModifyGraph mode=4,marker=19
		setaxis bottom 0, s.RunTime
	endif
	// Hook to save window position
	SetWindow twoPLROIGraph hook (saveHook)= SaveWinPosStrHook, hookevents = 2
end


"NQ_ScanEnd (%d, \"%s\", 0)", s.ScanMode, BKGtaskStr 


//******************************************************************************************************
// This is the function that runs at the end of a scan to clean things up
// Last Modified:
// 2016/11/15 by Jamie Boyd - suppot for background/channel
// 2016/11/07 by Jamie Boyd - made this function be for only normal image scan ends and user aborts, not for ephys  NIDAQmx-generated errors
Function  NQ_ScanEnd (scanMode, ScanIsAbort)
	variable scanMode // scanmode variable
	variable ScanIsAbort 	// isAbort is 0 for normal end-of-scan finishing, 1 for user clicking abort button (or stopping a live scan) 
	// 2 for error from image scan board, 3 for error from ephys board 
	string errStr
	variable err, errPos
	NVAR PercentComplete = root:packages:twoP:Acquire:PercentComplete
	PercentComplete = 0
	if (ScanIsAbort > 1)
		errStr =fdaqMx_ErrorString()
		printf "Scanning was aborted and NI boards reset because an error occured. The error message was:\r%s\r",  errStr
		NQ_ResetBoards (1)
	else
		try
			// shutDown the image hardware, if an image scan
			if (abs (scanMode) != kEphysOnly)
				// close the shutter
				SVAR imageBoard = root:packages:twoP:Acquire:imageBoard
				NVAR shutterTaskNum = root:packages:twoP:Acquire:shutterTaskNum
				errPos = 0
				err = fDAQmx_DIO_Write(imageBoard, shutterTaskNum, (!(kNQshutterOpen)));ABORTONVALUE (err), errPos
				// Stop the waveform Generator on the Imaging Board
				errPos =1
				err = fDAQmx_WaveformStop(imageBoard);ABORTONVALUE (err), errPos
				// stop the counters on the Imaging Board
				errPos = 2
				//err = fDAQmx_CTR_Finished(imageBoard, 0);ABORTONVALUE (err), errPos
				//errPos = 3
				err = fDAQmx_CTR_Finished(imageBoard, 1);ABORTONVALUE (err), errPos
				// stop the fifo if using a FIFO
				NVAR scanToDisk = root:packages:twoP:acquire:scanToDisk
				//				NVAR fileRefNum = root:Packages:twoP:Acquire:scanToDiskFileRefNum
				//				if (scanToDisk)
				//					CtrlFIFO NIDAQImageFifo, flush
				//					CtrlFIFO NIDAQImageFifo, stop
				//					killfifo NIDAQImageFifo
				//				endif
				// Stop the scan manually if an abort/live mode end, a zSeries end with repeated scanning, or a fifof
				NVAR isCyclic =  root:packages:twoP:acquire:isCyclic
				if ((((ScanIsAbort) || (scanToDisk)) || (scanMode == kzSeries)) || (ScanMode == kTimeSeries && (isCyclic)))
					errPos = 7
					err=fDAQmx_ScanStop(ImageBoard);ABORTONVALUE (err), errPos
				endif
				//Park the scan mirrors at 0,0  - Good for purposes of beam alignment
				errPos = 8
				err= fDAQmx_WriteChan(ImageBoard, 0, 0, -10, 10 );ABORTONVALUE (err), errPos
				errPos = 9
				err= fDAQmx_WriteChan(ImageBoard, 1, 0, -10, 10 );ABORTONVALUE (err), errPos
			endif
			// shut down the ephys board, if doing ephys
			SVAR ephysBoard = root:packages:twoP:Acquire:ePhysBoard
			if (scanMode == kEphysOnly)
				NVAR ePhysChans = root:packages:twoP:Acquire:ePhysChans
			else
				NVAR ePhysChans =  root:Packages:twoP:Acquire:ePhysAdjChans
			endif
			NVAR voltagePulseChans = root:packages:twoP:Acquire:voltagePulseChans
			NVAR trig1check = root:packages:twoP:Acquire:trig1Check
			NVAR trig2check = root:packages:twoP:Acquire:trig2Check
			if (ePhysChans)
				//				// stop the fifo if using a FIFO
				//				NVAR scanToDisk = root:packages:twoP:acquire:scanToDisk
				//				NVAR fileRefNUm = root:Packages:twoP:Acquire:ePhysToDiskFileRefNum
				//				if (scanToDisk)
				//					fNidaq_ScanFIFOStop(EphysBoardSlot)
				//					killfifo NIDAQePhysFifo
				//				endif
				//				if (ScanIsAbort)
				//					fNIDAQ_ResetScan(EPhysBoardSlot)
				//				endif
				//			// Stop the voltage pulse waveform generator
				//			if (voltagePulseChans)
				//			NidaqError = fNIDAQ_WFReset(EphysBoardSlot)
				//			AbortOnValue NidaqError, 10
				//			//			endif
				//			//Disarm the counters for the triggers
				//			if (trig1check)
				//				//NidaqError = ftwoP_GPCTR_Control(ephysboardSlot, ND_COUNTER_0, ND_RESET)
				//				AbortOnValue NidaqError, 11
				//			endif
				//			if (trig2check)
				//				//NidaqError = ftwoP_GPCTR_Control(ephysboardSlot, ND_COUNTER_1, ND_RESET)
				//				AbortOnValue NidaqError, 12
				//			endif
			endif
		catch
			printf "NQ_ScanEnd had an error shutting at position %d. The NIDAQ error message was was:\r%s\r", errPos, fDAQmx_ErrorString()
		endtry
		// clean up controls and post-processing
		variable scanModeAbs = abs (scanMode)
		// Reset start button
		Button AqStartButton, win = twoP_Controls, fColor=(0,65280,0), title = "Start", userData = "Start"
		// reset %complete
		NVAR percentComplete = root:packages:twoP:acquire:percentComplete
		percentComplete = 0
		// UnLock the stage
		SVAR stageProc = root:Packages:twoP:Acquire:StageProc
		SVAR stagePort = root:packages:twoP:acquire:StagePort
		funcref StageSetManual_Template setManual = $"StageSetManual_" + stageProc
		setManual (0)
		// Post-scan processing of data
		NVAR flybackMode = root:packages:twoP:Acquire:flybackMode
		NVAR scanChans = root:packages:twoP:Acquire:ScanChans
		SVAR curScan = root:packages:twoP:examine:curScan
		NVAR isCyclic =  root:packages:twoP:acquire:isCyclic
		if (cmpStr (curScan, "LiveWave") == 0)
			SVAR scanStr = root:packages:twoP:Acquire:LiveModeScanStr
		else
			SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
		endif
		// turn off threads
		WAVE bkgThreadIDs= root:packages:twoP:acquire:bkgThreadIDs
		variable iChan, nChans = 2, releaseCode
		for (iChan =0; iChan < nChans; iChan +=1)
			if (numType (bkgThreadIDs [iChan]) == 0)
				if (!((scanModeAbs == kTimeSeries) && (isCyclic == 0)))
					newdatafolder/o root:packages:twoP:acquire:bkgFldr
					variable/G root:packages:twoP:acquire:bkgFldr:newFrame =0
					ThreadGroupPutDF bkgThreadIDs [iChan], root:packages:twoP:acquire:bkgFldr
				endif
				if (ThreadGroupWait(bkgThreadIDs [iChan], 1e03) !=0)
					printf "Thread %d for channel %d was not finished\r", bkgThreadIDs [iChan], ichan
				endif
				releaseCode =ThreadGroupRelease(bkgThreadIDs [iChan])
				if (releaseCode == -1)
					printf "Thread %f for channel %d was invalid\r", bkgThreadIDs [iChan], ichan
				elseif (releaseCode ==-2)
					string AlertStr
					sprintf AlertStr, "Thread %f for channel %d could not be released. Save exp and restart Igor.", ichan, bkgThreadIDs [iChan]
					doAlert 0, AlertStr
					return 1
				endif
			endif
		endfor
		if (abs(scanMode) != kEPhysOnly)
				variable pixWidth = NumberByKey("PixWidth", scanStr, ":", "\r")
				variable pixHeight = NumberByKey("PixHeight", scanStr, ":", "\r")
				variable NumFrames = NumberByKey("NumFrames", scanStr, ":", "\r")
				variable xPos= NumberByKey("Xpos", scanStr, ":", "\r") 
				variable xPixSize =  NumberByKey("XpixSize", scanStr, ":", "\r") 
				variable yPos = NumberByKey("Ypos", scanStr, ":", "\r") 
				variable yPixSize =  NumberByKey("YpixSize", scanStr, ":", "\r") 
				variable zPos = NumberByKey("Zpos", scanStr, ":", "\r") 
				variable frameTime = NumberByKey("FrameTime", scanStr, ":", "\r")
				
		endif
		switch (scanModeAbs)
			case kTimeSeries:
			
				
				if (scanToDisk ==0)
					if (!(isCyclic))
						if (scanChans & 1)
							WAVE dataWave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
							redimension/n = ((pixWidth), (pixHeight), (NumFrames)) dataWave
							fastop dataWave =  dataWave + (kNQtoUnsigned)
							if (flybackMode == 1) 
								swapEven (dataWave)
							endif
							setscale/p x XPos, xPixSize, "m", dataWave
							setscale/p y YPos, YPixSize, "m", dataWave
							setscale/p z zPos, frameTime, "s", dataWave
						endif
						if (scanChans & 2)
							WAVE dataWave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
							redimension/n = ((pixWidth), (pixHeight), (NumFrames)) dataWave
							fastop dataWave =  dataWave + (kNQtoUnsigned)
							if (flybackMode == 1)
								swapEven (dataWave)
							endif
							setscale/p x XPos, xPixSize, "m", dataWave
							setscale/p y YPos, YPixSize, "m", dataWave
							setscale/p z zPos, frameTime, "s", dataWave
						endif
					endif
				endif
				break
			case kSingleImage: // do Kalman averaging
				// stop background task
				GUIPbkg_RemoveTask ("NQ_SingleImage_Bkg(*)")
				if (scanChans & 1)
					WAVE dataWave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
					KalmanWaveToFrame (dataWave, 16)
					if (flybackMode == 1)
						swapEven (dataWave)
					endif
				endif
				if (scanChans & 2)
					WAVE dataWave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
					KalmanWaveToFrame (dataWave, 16)
					if (flybackMode == 1)
						swapEven (dataWave)
					endif
				endif
				break
			case kZSeries:
				// Position stage back to start of stack
				NVAR zSeriesStart = root:packages:twoP:acquire:zFirstZ
				variable xS=Nan, yS=Nan, zS =zSeriesStart, axS=Nan
				SVAR stageProc =root:Packages:twoP:Acquire:StageProc
				SVAR stagePort = root:packages:twoP:acquire:StagePort
				funcref StageMove_Template stageMove = $"StageMove_" + stageProc
				stageMove (0, 0, xS, yS, zS, axS)
				
				break
			case kLineScan:
				if (!(isCyclic))
					CtrlNamedBackground LineScan_Bkg Stop =1
					if (scanChans & 1)
						WAVE dataWave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
						KalmanWaveToFrame (dataWave, 16)
						if (flybackMode == 1)
							WAVE dataWave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
							swapEven (dataWave)
						endif
					endif
					if (scanChans & 2)
						WAVE dataWave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
						KalmanWaveToFrame (dataWave, 16)
						if (flybackMode == 1)
							WAVE dataWave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
							swapEven (dataWave)
						endif
					endif
				endif
					break


			endSwitch

		
		// massage ePhys data, if needed
		if (ePhysChans & 1)
			WAVE eDataWave = $"root:twoP_Scans:" + curScan +":" +  curScan + "_ep1"
			if (Waveexists (eDataWave))
				edatawave *= kNQePhysScalerCh1
			endif
		endif
		if (ePhysChans & 2)
			WAVE eDataWave = $"root:twoP_Scans:" + curScan +":" +  curScan + "_ep2"
			if (Waveexists (eDataWave))
				edatawave *= kNQePhysScalerCh2
			endif
		endif
		// possibly save/delete scan ^&*
		if (scanMode != 0)
			NVAR exportafterscan =  root:packages:twoP:acquire:exportAfterScan
			if (exportafterscan)
				NQ_ExportAfterScan (exportafterscan)
			endif
			// increment iAq and do multi shutdown, if we are at end of milti-aqs
			if (scanMode < 0)
				NVAR iAq = root:packages:twoP:acquire:multiAqiAq
				NVAR nAqs= root:packages:twoP:acquire:multiAqnAqs
				iAq +=1
				if (iAq == nAqs)
					NQ_MultiAqReset ()
				endif
			endif
			//increment wavename, if requested
			NVAR autincCheck = root:packages:twoP:Acquire:autIncCheck
			if (autIncCheck)
				SVAR NewScanName =  root:packages:twoP:Acquire:NewScanName
				NewScanName = NQ_autinc (NewScanName, 1)
			endif
		endif
		// Make sure controls will be set properly when user switches to examine side of things
		NQ_Adjust_Examine_Controls (curScan)
		NVAR PercentComplete = root:packages:twoP:Acquire:PercentComplete
		PercentComplete = 0
		doupdate
	endif
end


//******************************************************************************************************
// This is the function that runs between cycles in a cycling time series. It copies data from the temp wave to the time series stack. It calls scan end the last time it goes through
// Last Modified 2013/07/31 by Jamie Boyd
//Function NQ_tSeriesCyclicPRTH()
	
	NVAR scanChans = root:packages:twoP:Acquire:ScanChans
	NVAR showMerge = root:packages:twoP:examine:showMerge
	// Quickly copy the data from tempwave 1 into the tempwave 2
	if (scanChans & 1)
		WAVE temp1Wave_ch1 =  root:Packages:twoP:acquire:TempZ1Wave_ch1
		WAVE Temp2Wave_ch1 = root:Packages:twoP:acquire:TempZ2Wave_ch1
		fastop Temp2Wave_ch1 = temp1Wave_ch1
	endif
	if (scanChans & 2)
		WAVE temp1Wave_ch2 =  root:Packages:twoP:acquire:TempZ1Wave_ch2
		WAVE Temp2Wave_ch2 = root:Packages:twoP:acquire:TempZ2Wave_ch2
		fastop Temp2Wave_ch2 = temp1Wave_ch2
	endif
	
	// While the next round of scanning happens in the background, we can deal with the last bunch of data
	SVAR CurScan = root:Packages:twoP:examine:curScan
	NVAR iiZSeriesFrames = root:Packages:twoP:acquire:iiZSeriesFrames
	NVAR tSeriesBufferSize = root:packages:twoP:acquire:tSeriesBufferSize
	NVAR flybackMode = root:packages:twoP:Acquire:flyBackMode
	if (scanChans & 1)
		WAVE DataWave = $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_ch1"
		if (flybackMode == 1)
			SwapEven (Temp2Wave_ch1)
		endif
		DataWave [] [] [iiZSeriesFrames, iiZseriesFrames + tSeriesBufferSize] =  Temp2Wave_ch1 [p] [q] [r - iiZSeriesFrames]
		NVAR showCh1 = root:packages:twoP:examine:showCh1
		if ((showCh1) || ((showMerge) && (ScanChans == 3)))
			WAVE scanGraph_ch1 = root:packages:twoP:examine:scanGraph_ch1
			ProjectZSlice (DataWave, scanGraph_Ch1, iiZSeriesFrames)
		endif
	endif
	if (scanChans & 2)
		WAVE DataWave = $"root:twoP_Scans:" + CurScan + ":" + curScan + "_ch2"
		if (flybackMode == 1)
			SwapEven (Temp2Wave_ch2)
		endif
		DataWave [] [] [iiZSeriesFrames, iiZseriesFrames + tSeriesBufferSize] =  Temp2Wave_ch2 [p] [q] [r- iiZSeriesFrames]
		// Update the twoPScanGraph for Ch2
		NVAR showCh2 = root:packages:twoP:examine:showCh2
		if ((showCh2)|| ((showMerge) && (ScanChans == 3)))
			WAVE scanGraph_ch2 = root:packages:twoP:examine:scanGraph_ch2
			ProjectZSlice (DataWave, scanGraph_Ch2, iiZSeriesFrames)
		endif
	endif
	// if both chans, and merg, update merg
	if ((showMerge) && (ScanChans == 3))
		NVAR first1 = root:packages:twoP:examine:CH1FirstLutColor
		NVAR Last1 = root:packages:twoP:examine:CH1LastLutColor
		NVAR first2 = root:packages:twoP:examine:CH2FirstLutColor
		NVAR Last2 = root:packages:twoP:examine:CH2LastLutColor
		variable rangevar
		wave outWave =  root:packages:twoP:examine:scanGraph_mrg
		if (kNQRedChan == 1)
			// ch1 is red plane and  ch2 is green
			rangevar = 65536/(last1 - first1)
			outwave [] [] [0] =  min (65535, max (0,(scangraph_ch1 [p] [q] - first1)) * rangevar)
			rangevar = 65536/(last2 - first2)
			outwave [] [] [1] =   min (65535, max (0,(scangraph_ch2 [p] [q] - first2)) * rangevar)
		else
			rangevar = 65536/(last1 - first1)
			outwave [] [] [1] =  min (65535, max (0,(scangraph_ch1 [p] [q] - first1)) * rangevar)
			rangevar = 65536/(last2 - first2)
			outwave [] [] [0] =   min (65535, max (0,(scangraph_ch2 [p] [q] - first2)) * rangevar)
		endif
	endif	
	// increment Z series counter. Are we done yet?
	iiZSeriesFrames += tSeriesBufferSize
	NVAR tFrames = root:packages:twoP:Acquire:TseriesFrames
	NVAR percentComplete = root:packages:twoP:Acquire:percentComplete
	percentComplete =100 * iiZSeriesFrames/tFrames
	doUpdate
	if (!(iiZSeriesFrames < tFrames))		// Done Scanning. 
		NQ_ScanEnd (kTimeSeries, 0)
	endif
	return 0
end

//******************************************************************************************************
// end for cyclic line scan acquisition (not well tested yet)
// Last modfied 2012/07/29 by Jamie Boyd
//function NQ_LineScanCyclicEnd ()
	
	NVAR scanChans = root:packages:twoP:Acquire:ScanChans
	NVAR showMerge = root:packages:twoP:examine:showMerge
	// Quickly copy the data from tempwave 1 into the tempwave 2
	if (scanChans & 1)
		WAVE temp1Wave_ch1 =  root:Packages:twoP:acquire:TempL1Wave_ch1
		WAVE Temp2Wave_ch1 = root:Packages:twoP:acquire:TempL2Wave_ch1
		fastop Temp2Wave_ch1 = temp1Wave_ch1
	endif
	if (scanChans & 2)
		WAVE temp1Wave_ch2 =  root:Packages:twoP:acquire:TempL1Wave_ch2
		WAVE Temp2Wave_ch2 = root:Packages:twoP:acquire:TempL2Wave_ch2
		fastop Temp2Wave_ch2 = temp1Wave_ch2
	endif
	
	// While the next round of scanning happens in the background, we can deal with the last bunch of data
	SVAR CurScan = root:Packages:twoP:examine:curScan
	NVAR iiZSeriesFrames = root:Packages:twoP:acquire:iiZSeriesFrames
	NVAR bufferSize =  root:packages:twoP:acquire:lScanBufferSize
	NVAR flybackMode = root:packages:twoP:Acquire:flyBackMode
	NVAR lineTime = root:packages:twoP:acquire:lineTime
	if (scanChans & 1)
		WAVE DataWave = $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_ch1"
		if (flybackMode == 1)
			SwapEven (Temp2Wave_ch1)
		endif
		DataWave [] [iiZSeriesFrames, iiZseriesFrames + bufferSize] =  Temp2Wave_ch1 [p] [q - iiZSeriesFrames]
		SetAxis /W=twoPScanGraph#GCH1 left (iiZSeriesFrames  * lineTime), ((iiZSeriesFrames + bufferSize)   * lineTime)
	endif
	if (scanChans & 2)
		WAVE DataWave = $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_ch2"
		if (flybackMode == 1)
			SwapEven (Temp2Wave_ch2)
		endif
		DataWave [] [iiZSeriesFrames, iiZseriesFrames + bufferSize] =  Temp2Wave_ch1 [p] [q - iiZSeriesFrames]
		SetAxis /W=twoPScanGraph#GCH2 left (iiZSeriesFrames  * lineTime), ((iiZSeriesFrames + bufferSize) * lineTime)
	endif
	// increment Z series counter. Are we done yet?
	iiZSeriesFrames += bufferSize
	NVAR nLines = root:packages:twoP:acquire:LSHeight
	NVAR percentComplete = root:packages:twoP:Acquire:percentComplete
	percentComplete =100 * iiZSeriesFrames/nLines
	doUpdate
	if (!(iiZSeriesFrames < nLines))		// Done Scanning. 
		NQ_ScanEnd (kLineScan, 0)
	endif
	return 0
end


//******************************************************************************************************
// Graph marquee procedure to define scan voltage and pixel settings based on a graph marquee selection from the image
// type 0 =zoom scan,	keeps pixel number constant, adjusting pixel scaling
// type 1 = Crop scan, keeps pixel scaling constant, adjusting pixel number.
// type 2 = line scan
// Last Modified Oct 25 2010 by Jamie Boyd
Function NQ_SetScanSize(type)
	variable type // 0 = zoom scan; 1 = crop scan; 2 = line scan
	
	// Current Scan
	SVAR curScan = root:Packages:twoP:examine:CurScan
	// Scan Note
	if (cmpStr (curScan, "LiveWave") == 0)
		SVAR scanStr = root:packages:twoP:Acquire:LiveModeScanStr
	else
		SVAR scanStr =$"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
	endif
	// Globals for Voltage sizes and pixel size
	if (type == 2) // setting values for a line scan
		NVAR XSV = root:Packages:twoP:acquire:LSStartVolts
		NVAR XEV = root:Packages:twoP:acquire:LSEndVolts
		NVAR YSV = root:Packages:twoP:acquire:LSYVolts
		NVAR pixHeight = root:Packages:twoP:acquire:LSHeight
		NVAR pixWidth= root:Packages:twoP:acquire:LSWidth
		NVAR XSVBU = root:Packages:twoP:acquire:LSStartVoltsBU
		NVAR XEVBU = root:Packages:twoP:acquire:LSEndVoltsBU
		NVAR YSVBU = root:Packages:twoP:acquire:LSYVoltsBU
		NVAR pixHeightBU = root:Packages:twoP:acquire:LSHeightBU
		NVAR pixWidthBU= root:Packages:twoP:acquire:LSWidthBU
		SVAR linkWaveStr = root:packages:twoP:Acquire:LSlinkWaveStr
		linkWaveStr = curScan
	else // setting values for an image scan
		NVAR XSV = root:Packages:twoP:acquire:XStartVolts
		NVAR XEV = root:Packages:twoP:acquire:XEndVolts
		NVAR YSV = root:Packages:twoP:acquire:YStartVolts
		NVAR YEV =root:Packages:twoP:acquire:YEndVolts
		NVAR pixHeight = root:Packages:twoP:acquire:pixHeight
		NVAR pixWidth= root:Packages:twoP:acquire:pixWidth
		NVAR XSVBU = root:Packages:twoP:acquire:XStartVoltsBU
		NVAR XEVBU = root:Packages:twoP:acquire:XEndVoltsBU
		NVAR YSVBU = root:Packages:twoP:acquire:YStartVoltsBU
		NVAR YEVBU =root:Packages:twoP:acquire:YEndVoltsBU	
		NVAR pixHeightBU = root:Packages:twoP:acquire:pixHeightBU
		NVAR pixWidthBU= root:Packages:twoP:acquire:pixWidthBU
	endif
	// Save the old values in back up copies so we can revert if desired
	XSVBU = XSV
	XEVBU = XEV
	YSVBU = YSV
	if (type != 2) // image, not line scan
		YEVBU = YEV
		pixHeightBU = pixHeight
	endif
	pixWidthBU = pixWidth
	// Get Marquee coordinates.
	GetMarquee/K left,bottom
	// Note that V_left and V_right and V_top and V_bottom are in scaled dimensions (meters in this case), not pixels
	// Read scaling values from scan string
	variable WaveXSV = NumberByKey("XSV", scanStr, ":", "\r")
	variable WaveXEV = NumberByKey("XEV", scanStr, ":", "\r")
	variable WaveYSV = NumberByKey("YSV", scanStr, ":", "\r")
	variable WaveYEV = NumberByKey("YEV", scanStr, ":", "\r")
	variable WavePixWidth = NumberByKey("PixWidth", scanStr, ":", "\r")
	variable WavePixHeight =NumberByKey("PixHeight", scanStr, ":", "\r")
	variable WaveXPos = NumberByKey("xPos", scanStr, ":", "\r")
	Variable waveYpos = NumberByKey("yPos", scanStr, ":", "\r")
	variable waveXPixSize = NumberByKey("xPixSize", scanStr, ":", "\r")
	variable waveYPixSize = NumberByKey("yPixSize", scanStr, ":", "\r")
	// calculate scaling in m/Volts
	variable WaveXScal = (WavePixWidth *waveXPixSize)/(WaveXEV - WaveXSV)
	variable WaveYScal =(WavePixHeight *waveYPixSize)/ (WaveYEV - WaveYSV)
	// calculate appropriate voltages based on scaling
	XSV = max (kNQxVoltStart, WaveXSV + (V_left - WaveXPos)/ WaveXScal)
	XEV= min (kNQxVoltEnd, WaveXSV + (V_right - WaveXPos)/ WaveXScal)
	YSV = max (kNQyVoltStart, WaveYSV + (V_bottom - WaveYPos)/WaveYScal)
	YEV= min (kNQyVoltEnd, WaveYSV + (V_top - WaveYPos)/WaveYScal)
	// For linescan, set Y to average of starting and ending voltage
	if (type == 2)
		YSV = (YSV +  WaveYSV + (V_top - WaveYPos)/WaveYScal)/2
	endif
	// for crop scan, adjust pixel number to keep scaling constant
	// to keep marquee functions to a minimum, there is no crop for linescans, but holding shift key will work
	variable shifted= (GetKeyState(0) & 4)
	if ((type == 1) || ((type == 2) && (shifted)))
		PixWidth = round(abs(v_Right - v_left) / waveXPixSize)
		if (type == 1)
			PixHeight =  round (abs( V_bottom - V_Top)/ waveyPixSize)
		endif
	endif
	//run set times proc, which may adjust width/height of selected region for aspect ratio (and fix odd number of lines/pixels)
	NQ_SetTimes()
	// draw a rectangle on graph in ADJUSTED location
	V_left = (XSV-WaveXSV) * WaveXScal + WaveXPos
	V_right = (XEV-WaveXSV) * WaveXScal + WaveXPos
	V_bottom =  (YSV-WaveYSV) * WaveYScal + WaveYPos
	if (type == 2)
		SetDrawLayer/K ProgFront
		SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0,linefgc= (0,0,0),linethick= 3.00
		DrawLine V_Left,V_Bottom, V_Right, V_Bottom 
		SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0,linefgc= (65535,65535,65535),linethick= 1, dash = 2
		DrawLine V_Left,V_Bottom, V_Right, V_Bottom 
	else
		V_top =  (YEV-WaveYSV) * WaveYScal + WaveYPos
		SetDrawLayer/K ProgFront
		SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0,linefgc= (0,0,0),linethick= 3.00
		DrawRect V_Left,V_top,V_right, V_bottom
		SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0,linefgc= (65535,65535,65535),linethick= 1, dash = 2
		DrawRect V_Left,V_top,V_right, V_bottom
		SetDrawLayer UserFront
	endif
end

//********************************************************************************************
// Calls make histogram graph procedure when checked
// last modified Jul 29 2011 by Jamie Boyd
Function NQ_LiveHistCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			if (cba.checked)
				NVAR scanChans = root:Packages:twoP:Acquire:ScanChans
				NQ_MakeHistGraph (scanChans, "LiveWave")
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//******************************************************************************************************
// sets global variable for exporting after completing a scan
// Last modified May 07 2012 by Jamie Boyd
// 0 = do Nothing, 1 = save experiment, 2 =Export scan, 3=export and delete scan, 4 = export and delete previous scan
Function NQ_ExportAfterScanPopProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			NVAR exportafterscan = root:packages:twoP:acquire:exportAfterScan
			exportafterscan = pa.popNum -1
			if ((CmpStr (pa.popStr, "Do Nothing") != 0)  && (CmpStr (pa.popStr, "Save Experiment") != 0))
				// make sure export path is set
				SVAR PathStr =root:Packages:twoP:examine:ExportPath		// the global string were we store the path
				pathinfo ExportPath
				if (!((V_Flag ==1) && (cmpstr (S_path, PathStr) ==0)))// path does not exits or is not the same as shown in the string
					NewPath /O/M="Select a Folder in which to store Scan Waves" ExportPath
					if (!V_flag)		// V_flag is set to 0 if newpath is successful
						PathInfo ExportPath
						pathstr =  s_path
					endif
				endif
			endif			
			break
	endswitch
	return 0
End


//******************************************************************************************************
// runs after a scan to save current scan or previous scan, possibly deleting it
// 1= save experiment, 2 =Export scan, 3=export and delete scan, 4 = export and delete previous scan
// Last modified 2013/10/28 by Jamie Boyd
function NQ_ExportAfterScan (toDo)
	variable toDo
	
	// options for afterscan choice
	if (toDo ==1)
		SaveExperiment
	else // save individual scan using NQ_SaveAndOrDeleteButtonProc
		// we use the "all matching scans method", so select it
		STRUCT WMCheckboxAction cba
		cba.checked=1
		cba.eventCode=2
		cba.userdata=  "root:packages:twoP:examine:ExportCurOrAll=1;exportCurScanCheck"
		cba.win = "twoP_Controls"
		cba.ctrlName = "exportAllScansCheck"
		CheckBox exportAllScansCheck win= twoP_Controls, value=1
		GUIPRadioButtonProcSetGlobal (cba)
		SVAR curScan = root:Packages:twoP:examine:CurScan
		SVAR exportMatchStr = root:packages:twoP:examine:exportMatchStr
		// run the save/delete function with chosen options
		STRUCT WMButtonAction ba
		ba.eventCode =2
		switch (toDo)
			case 2: // export scan
				exportMatchStr = curScan
				ba.ctrlname = "SaveButton"
				break
			case 3: //Export and Delete Scan
				exportMatchStr = curScan
				ba.ctrlname = "SaveKillButton"
				break
			case 4: //Export and Delete Last Scan. If in multi mode, export current scan (but don't delete it)
				NVAR scanMode = root:packages:twoP:Acquire:scanStartMode
				NVAR iAq = root:packages:twoP:acquire:multiAqiAq
				NVAR nAqs= root:packages:twoP:acquire:multiAqnAqs
				if ((scanMode < 0) && (iAq ==  (nAqs - 1)))
					NQ_ExportAfterScan (2)
				endif
				variable scanNum = str2num (stringfromlist (1, curScan, "_"))-1
				sprintf exportMatchStr, "%s_%03d", stringfromlist (0, curScan, "_"), scanNum
				if (!(dataFolderExists ("root:twoP_Scans:" + exportMatchStr)))
					if (scanNum > -1)
						printf "The Scan \"%s\" does not exist\r", exportMatchStr
					endif
					return 1
				endif
				ba.ctrlname = "SaveKillButton"
				break
		endSwitch
		NQ_SaveAndOrDeleteButtonProc(ba)
	endif
	return 0
end


//******************************************************************************************************
//Dumps the marquee coordinates to some global variables and makes the wave to hold averages
// Last Modified Oct 14 2009 by Jamie Boyd
Function NQ_SetLiveROI ()
	
	// Variables to hold coordinates of Live ROI, which will be in scaled image positions
	NVAR left = root:packages:twoP:acquire:LROIL
	NVAR Top = root:packages:twoP:acquire:LROIT
	NVAR right = root:packages:twoP:acquire:LROIR
	NVAR bottom = root:packages:twoP:acquire:LROIB	
	GetMarquee/k left,bottom
	left = V_left
	right = V_right
	top = V_top
	bottom = V_bottom
	SetDrawLayer/K ProgFront
	SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0,linefgc= (0,0,0),linethick= 3.00
	DrawRect Left, top, right, bottom
	SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0,linefgc= (65535,65535,65535),linethick= 1, dash = 2
	DrawRect Left, top, right, bottom
	SetDrawLayer UserFront
end

//******************************************************************************************************
// Code for MultiAcquisition

//******************************************************************************************************
// removes background task for multi-aq and resets start button and other controls
// last modified 2013/08/06 by Jamie Boyd
Function NQ_MultiAqReset ()

	// stop background procedure
	NVAR multiMode =root:packages:twoP:acquire:multiAqTimeMode
	NVAR startScanNum = root:packages:twoP:acquire:StartScanNum
	NVAR newScanNum =root:Packages:twoP:Acquire:NewScanNum
	startScanNum = newScanNum
	variable nAqs
	switch (multiMode)
		case kMultiUsePeriod:
			CtrlNamedBackground multAqBk kill
			NVAR periodNum = root:packages:twoP:acquire:multiAqPeriodNum
			nAqs = periodNum
			break
		case kMultiUseWave:
			GUIPbkg_RemoveTask("NQ_MultiBkg_Wave(*)")
			SVAR WaveStr = root:packages:twoP:Acquire:multiAqWaveWaveStr
			WAVE/z maqWave = $"root:packages:twoP:acquire:multiAqWaves:" + WaveStr
			if (WaveExists (maqWave))
				nAqs = numPnts (maqWave)
			else
				nAqs = 0
			endif
			break
		case kMultiUseTrigger:
			GUIPbkg_RemoveTask("NQ_MultiBkg_Trigger(*)")
			NVAR trigNum =root:packages:twoP:acquire:multiAqTriggerNum
			nAqs = trigNum
			break
	endswitch
	// reset start button
	Button MultiAqStartButton win = twoP_Controls, title="Start",  fColor=(0,65535,0), userdata = "Start Multi"
	// reset counts for multiAq
	NVAR iAq = root:packages:twoP:acquire:multiAqiAq
	iAq = 0
	// reset countdown
	SVAR timeStrG =root:packages:twoP:acquire:multiAqTimeToNextStr 
	timeStrG = ""
	// reset setvariable for display
	ValDisplay multiAqProgressDisplay win = twoP_Controls, limits={startScanNum,startScanNum + nAqs -1, startScanNum }
end


//******************************************************************************************************
// Sets scanMode to negative value of chosen mode to indicate a multiple acquisition
// Last modified Apr 02 2012 by Jamie Boyd
Function NQ_MultiAqDataModePopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			NVAR scanMode=root:packages:twoP:Acquire:ScanMode
			scanMode = -pa.popNum
			//Set Times
			NQ_SetTimes ()
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Sets times for periodic acquisition, namely, initial delay and perioid
// Last modified Apr 02 2012 by Jamie Boyd
Function NQ_MultiAqTimeSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			string timeStr = sva.sVal
			variable microSecs
			NQ_MultiParseTimeStr (timeStr, microSecs)
			if (cmpStr (sva.ctrlName, "MultiAqPeriodDelaySetVar") ==0)
				SVAR timeStrG = root:packages:twoP:acquire:multiAqPeriodDelayStr
				NVAR microSecsG = root:packages:twoP:acquire:multiAqPeriodDelay
			elseif (cmpStr (sva.ctrlName, "MultAqPeriodPeriodSetVar") ==0)
				SVAR timeStrG = root:packages:twoP:acquire:multiAqPeriodPeriodStr
				NVAR microSecsG=root:packages:twoP:acquire:multiAqPeriodPeriod
			endif
			timeStrG = timeStr
			microSecsG = microSecs
			break
	endswitch
	return 0
end

//******************************************************************************************************
// sets string to name of chosen wave or makes a new wave in the datafolder for timing waves
// Last modified Apr 03 2012 by Jamie Boyd
Function NQ_MultiWaveWavePopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			SVAR TimingWaveStr = root:packages:twoP:Acquire:multiAqWaveWaveStr
			string newTimingWaveStr = pa.popStr
			if (cmpStr (newTimingWaveStr,"New Timing Wave") ==0)
				newTimingWaveStr = ""
				prompt newTimingWaveStr "New Timimg Wave:"
				doprompt "Name for New Timing Wave", newTimingWaveStr
				if (V_Flag == 1)
					return 1
				endif
				newTimingWaveStr = CleanupName(newTimingWaveStr, 0 )
				make/T/n = 0 $"root:packages:twoP:Acquire:multiAqWaves:" + newTimingWaveStr
				WAVE newtimingwave = $"root:packages:twoP:Acquire:multiAqWaves:" + newTimingWaveStr
				edit/k=1 newTimingWave as "Edit Timing Wave:" + newTimingWaveStr
				Dowindow/C NewTimingWaveTable
			endif
			TimingWaveStr = newTimingWaveStr
			break
	endswitch
	return 0
end

//******************************************************************************************************
//puts up a table to edit the selected timing wave
// Last Modified Apr 03 2012 by Jamie Boyd
Function NQ_MultiWaveEditButtonProc(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR TimingWaveStr = root:packages:twoP:Acquire:multiAqWaveWaveStr
	WAVE newtimingwave = $"root:packages:twoP:Acquire:multiAqWaves:" + TimingWaveStr
	edit/k=1 newTimingWave as "Edit Timing Wave:" + TimingWaveStr
	Dowindow/C NewTimingWaveTable
End

//******************************************************************************************************
//Deletes the selected timing wave
// Last Modified Apr 03 2012 by Jamie Boyd
Function NQ_MultiWaveDeleteButtonProc(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR TimingWaveStr = root:packages:twoP:Acquire:multiAqWaveWaveStr
	WAVE newtimingwave = $"root:packages:twoP:Acquire:multiAqWaves:" + TimingWaveStr
	GUIPkilldisplayedwave (newtimingwave)
	TimingWaveStr= stringfromlist (0, GUIPListObjs("root:packages:twoP:acquire:multiAqWaves",1, "*" , 0, ""), ";")
End
	
//******************************************************************************************************
// parses time strings into variables passed by reference
// If no colon, assume all is seconds. if 1 colon, assume seconds and minutes.
// if 2 colons, hours, minutes, seconds
// Last modified Apr 02 2012 by Jamie Boyd
Function NQ_MultiParseTimeStr (timeStr, microSecs)
	string &timeStr
	variable &microSecs
	
	variable timeStrLen = strlen (timeStr)
	variable secs=0, AllSecs =0, mins=0, AllMins =0, hrs=0
	variable colonPosMins, colonPosSecs = strsearch(timeStr, ":", timeStrLen-1, 1)
	if (colonPosSecs == -1) // all seconds
		AllSecs = str2num (timeStr)
	else
		AllSecs = str2num (timeStr [colonPosSecs +1, timeStrLen-1])
		colonPosMins = strsearch(timeStr, ":", ColonPosSecs-1, 1)
		if (colonPosMins == -1) // the remainder is minutes
			AllMins = str2num (timeStr [0, ColonPosSecs-1])
		else // hours as well
			AllMins = str2num ( timeStr[colonPosMins +1, ColonPosSecs-1])
			hrs = str2num (timeStr [0, ColonPosMins-1])
		endif
	endif
	secs = mod (Allsecs, 60)
	Allmins += floor (Allsecs/60)
	mins = mod (AllMins, 60)
	hrs += floor (AllMins/60)
	microSecs = 1e06 * (3600 * hrs + 60 *mins + secs)
	if (hrs > 0)
		sprintf timeStr "%02d:%02d:%02d" hrs, mins, secs
	else
		sprintf timeStr "%02d:%02d" , mins, secs
	endif
end

//******************************************************************************************************
// Converts microseconds into a string representation hrs:secs:mins
// Last Modified Apr 02 2012 by Jamie Boyd
Function/s NQ_MultiMSecs2Str (microSecs)
	variable microSecs
	
	if (microSecs ==0)
		return "SCANNING"
	endif
	variable AllSecs = microSecs/1e06,  secs=0, mins=0, AllMins =0, hrs=0
	secs = mod (Allsecs, 60)
	mins = floor (Allsecs/60)
	mins = mod (Mins, 60)
	hrs = floor (Mins/60)
	string TimeStr
	if (hrs)
		sprintf timeStr "%02d:%02d:%02.1f", hrs, mins, secs
	else
		sprintf timeStr "%02d:%02.1f", mins, secs
	endif
	return timeStr
end

//******************************************************************************************************
// Makes a series of waves in advance of doing the scanning, for increased speed
// Last Modified 2012/07/09 by Jamie Boyd
Function NQ_MultiPreMakeProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			NVAR multiMode =root:packages:twoP:acquire:multiAqTimeMode
			variable nAqs
			switch (multiMode)
				case kMultiUsePeriod:
					NVAR multiAqPeriodNum = root:packages:twoP:acquire:multiAqPeriodNum
					nAqs = multiAqPeriodNum
					break
				case kMultiUseWave:
					// check that timing wave exists
					SVAR multiWaveName = root:packages:twoP:Acquire:multiAqWaveWaveStr 
					WAVE/t/z multiWave = $"root:packages:twoP:acquire:multiAqWaves:" + multiWaveName
					if (!(waveExists (multiWave)))
						doAlert 0, "The selected multi-acquisition wave, \"" +  multiWaveName + "\", does not exist."
						return 0
					endif
					nAqs = numpnts (multiWave)
					break
				case kMultiUseTrigger:
					NVAR multiAqTriggerNum = root:packages:twoP:acquire:multiAqTriggerNum
					nAqs =multiAqTriggerNum
					break
			endswitch
			variable iAq
			// load the scan struct with values for next scan
			STRUCT NQ_ScanStruct s
			NQ_LoadScanStruct (s, 1)
			for (iAq=0; iAq < nAqs; iAq +=1)
				if (s.scanChans)
					NQ_MakeImageScanWaves (s)
				endif
				if (s.ePhysChans)
					NQ_MakeEPhysWaves (s) 
				endif
				// adjust scan Name
				s.NewScanName =  NQ_autinc (s.NewScanName, 1)
			endfor
	endswitch
	return 0
End

//******************************************************************************************************
//Initializes multiAq variables when stating a series of acquisitions
// Last Modified 2013/09/06 by Jamie Boyd
function NQ_MultiAqInit ()
	
	variable errVar
	try
		// make sure autoincrement is selected 
		NVAR autincCheck = root:packages:twoP:acquire:autincCheck
		abortOnValue (autIncCheck == 0), 0
		// make sure export path is set, if exporting after each scan
		NVAR exportafterscan = root:packages:twoP:acquire:exportAfterScan
		if (exportafterscan > 1)
			SVAR PathStr =root:Packages:twoP:examine:ExportPath		// the global string were we store the path
			pathinfo ExportPath
			AbortOnValue ((V_Flag ==0) || (cmpstr (S_path, PathStr) !=0)), 1// path does not exits or is not the same as shown in the string
		endif
		//add the background task for each mode and updates timing globals
		NVAR multiMode =root:packages:twoP:acquire:multiAqTimeMode
		NVAR iAq = root:packages:twoP:acquire:multiAqiAq
		iAq =0
		NVAR nAqs= root:packages:twoP:acquire:multiAqnAqs
		NVAR timeToNext = root:packages:twoP:acquire:multiAqTimeToNext
		SVAR timetoNextStr = root:Packages:twoP:Acquire:multiAqTimeToNextStr
		string theTask
		switch (multiMode)
			case kMultiUsePeriod:
				NVAR multiAqNum = root:packages:twoP:acquire:multiAqPeriodNum
				nAqs = multiAqNum
				NVAR period= root:packages:twoP:acquire:multiAqPeriodPeriod
				NVAR delay = root:packages:twoP:acquire:multiAqPeriodDelay
				timeToNext = delay
				CtrlNamedBackground multAqBkg , period = round(period * 1e-06 * 60), start = round (ticks + delay * 1e-06 * 60), proc=NQ_MultiBkg_Period 
				// set dependency for time str
				SetFormula timeToNextStr, "NQ_MultiMSecs2Str (root:packages:twoP:acquire:multiAqTimeToNext)"
				break
			case kMultiUseWave:
				// check that timing wave exists
				SVAR multiWaveName = root:packages:twoP:Acquire:multiAqWaveWaveStr 
				WAVE/t/z multiWave = $"root:packages:twoP:acquire:multiAqWaves:" + multiWaveName
				abortOnValue (!(waveExists (multiWave))), 3
				// set initial time to next from first point
				variable waveMS
				string waveDelayStr = multiWave [0]
				NQ_MultiParseTimeStr (waveDelayStr, waveMS)
				timeToNext = waveMS
				multiWave [0]= waveDelayStr
				nAqs = numpnts (multiWave)
				// add task to backgrounder
				//sprintf theTask "NQ_MultiBkg_Wave(%d, \"%s\")", stopMSTimer (-2), multiWaveName
				// BackGrounder_AddTask(theTask, 1) @@@
				// set dependency for time str
				SetFormula timeToNextStr, "NQ_MultiMSecs2Str ( root:packages:twoP:acquire:multiAqTimeToNext)"
				break
			case kMultiUseTrigger:
				NVAR inputTrigger = root:packages:twoP:acquire:inputTriggerCheck
				abortOnValue (inputTrigger != 1), 2
				NVAR imageBoardSlot = root:packages:twoP:acquire:imageBoardSlot
				NVAR multiAqTriggerNum = root:packages:twoP:acquire:multiAqTriggerNum
				nAqs =multiAqTriggerNum
				sprintf theTask, "NQ_MultiBkg_Trigger(%d)", imageBoardSlot
				//BackGrounder_AddTask(theTask, 1) @@@
				timeToNextStr = "WAITING"
				break
		endswitch
		// adjust multi-aq controls
		NVAR curNum = root:Packages:twoP:Acquire:NewScanNum
		variable/G root:packages:twoP:acquire:StartScanNum = curNum
		ValDisplay multiAqProgressDisplay win = twoP_Controls, limits={(curNum),(curNum + nAqs -1),(curNum)}
		ValDisplay multiAqProgressDisplay value=#"root:packages:twoP:acquire:multiAqiAq + root:packages:twoP:acquire:StartScanNum"
		Button MultiAqStartButton, win = twoP_Controls, fColor=(65280,65280,0), title = "Abort", userdata = "Abort Multi"
	catch
		switch (V_abortCode)
			case 0:
				doAlert 0,  "Autoincrementing must be enabled for multi-acquisition."
				break
			case 1:
				doAlert 0, "The export path must be set when saving scans during multi-acquisition."
				break
			case 2:
				doAlert 0, "Input trugger must be selected for multi-aquisition with input trigger."
				break
			case 3:
				doAlert 0, "Selected multiple acquisition timing wave does not exist."
				break
		endSwitch
		return 1
	endTry
	return 0
end

//******************************************************************************************************
//Background task for periodic acquisition
// Last Modified 2015/04/13 by Jamie Boyd
Function NQ_MultiBkg_Period (s)
	STRUCT WMBackgroundStruct &s
	
	NVAR percentComplete = root:packages:twoP:Acquire:PercentComplete
	if (percentComplete !=0) // currently scanning. Check again in a 10th of a second
		s.nextRunTicks = ticks + 6
	else // ready to go
		STRUCT WMButtonAction ba
		ba.eventcode = 2
		ba.UserData = "Start"
		NQ_StartScan (ba)
		NVAR iAq = root:packages:twoP:acquire:multiAqiAq
		NVAR nAqs = root:packages:twoP:acquire:multiAqnAqs
		iAq += 1
		if (iAq == nAqs)
			SVAR timeStrG =root:packages:twoP:acquire:multiAqTimeToNextStr 
			Setformula timeStrG ""
			timeStrG = "Final Scan"
			NQ_MultiAqReset ()
			return 1
		endif 
	endif
	return 0
end

//******************************************************************************************************
//background task for acquisition from a list of times
// Last Modified 2015/04/13 by Jamie Boyd
Function NQ_MultiBkg_Wave( s)
	STRUCT WMBackgroundStruct &s
	
	NVAR percentComplete = root:packages:twoP:Acquire:PercentComplete
	if (percentComplete !=0) // currently scanning
		s.nextRunTicks = ticks + 6
	else // ready to go
	
	
	NVAR iAq = root:packages:twoP:acquire:multiAqiAq
	SVAR waveStr = root:packages:twoP:acquire:multiAqWaveWaveStr
	WAVE/T theWave = $"root:packages:twoP:Acquire:multiAqWaves:" + WaveStr
	NVAR timeToNext =  root:Packages:twoP:Acquire:multiAqTimeToNext
	// not currently scanning
		STRUCT WMButtonAction ba
		ba.eventcode = 2
		ba.UserData = "Start"
		NQ_StartScan (ba)
		NVAR nAqs= root:packages:twoP:acquire:multiAqnAqs
		if (iAq + 1 == nAqs)
			SVAR timeStrG =root:packages:twoP:acquire:multiAqTimeToNextStr 
			Setformula timeStrG ""
			timeStrG = "Final Scan"
		endif
	endif
	string timeStr = theWave [iAq] // time to next scan
	variable microSecs // will get microseconds to next scan 
	NQ_MultiParseTimeStr (timeStr, microSecs)
	theWave [iAq] = timeStr
	//timeToNext = max (0, (startTime + microSecs) -stopMSTimer (-2))
	
	return 0
end

//******************************************************************************************************
//background task for triggered acquisition
// Last Modified May 30 2012 by Jamie Boyd
Function NQ_MultiBkg_Trigger(imageboardSlot)
	variable imageboardSlot
	
	NVAR iAq = root:packages:twoP:acquire:multiAqiAq
	SVAR TimeToNextStr=root:packages:twoP:acquire:multiAqTimeToNextStr
	NVAR percentComplete = root:packages:twoP:Acquire:PercentComplete
	if (percentComplete ==0) // not acquiring, so start an acquisition waiting for trigger
		STRUCT WMButtonAction ba
		ba.eventcode = 2
		ba.UserData = "Start"
		NQ_StartScan (ba)
		TimeToNextStr = "Waiting"
	elseIf (percentComplete >  0.01) // acquiring data 
		NVAR nAqs = root:packages:twoP:acquire:multiAqnAqs
		if (iAq + 1 == nAqs)
			SVAR timeStrG =root:packages:twoP:acquire:multiAqTimeToNextStr 
			timeStrG = "Final Scan"
		else
			TimeToNextStr = "Acquiring"
		endif
	endif
	return 0
end


// ***********************************************************************************************
// Background thread functions for image acquisition
// The idea is to use the scan end hook function to signal a preemptive background thread,
// which does the heavy lifting of copying data and so forth
//******************************************************************************************************
// scan hook function that runs between repeated acquisitions
// last modified 2017/02/02 by Jamie Boyd for thread per channel
function NQ_RepeatHook (scanMode)
	variable scanMode
	
	WAVE bkgThreadIDs = root:Packages:twoP:Acquire:bkgthreadIDs
	NVAR PercentComplete = root:packages:twoP:Acquire:PercentComplete
	variable iChan, nChans = 2
	NVAR showMerge =root:packages:twoP:examine:showMerge
	scanMode= abs (scanMode)
	Switch (scanMode)
		case kZseries:
			
			NVAR iZFrame = root:packages:twoP:acquire:iZFrame
			iZFrame +=1
			NVAR numFrames = root:packages:twoP:acquire:numZseriesFrames
			NVAR numZseriesAvg = root:packages:twoP:acquire:numZseriesAvg
			//printf "iZFrame = %d,numFrames = %d,  numZseriesAvg = %d\r", iZFrame,numFrames, numZseriesAvg
			NVAR zAvgStackAtOnce = root:packages:twoP:acquire:zAvgStackAtOnce
			if (((zAvgStackAtOnce) && (iZFrame == numFrames)) || (iZFrame == (numFrames * numZseriesAvg)))
				NQ_ScanEnd (kZSeries, 0)
				return 0
			else
				for (iChan =0; iChan < nCHans; iChan +=1)
					if (numtype (bkgThreadIDs [iChan]) ==0)
						newdatafolder/o root:packages:twoP:acquire:bkgFldr
						variable/G root:packages:twoP:acquire:bkgFldr:newFrame
						NVAR newFrame =  root:packages:twoP:acquire:bkgFldr:newFrame
						newFrame= 1
						if (showMerge)
							NVAR firstColorG = $"root:packages:twoP:examine:Ch" + num2Str (iChan + 1) + "FirstLutColor"
							NVAR LastColorG = $"root:packages:twoP:examine:Ch" + num2Str (iChan + 1) + "LastLutColor"
							variable/G root:packages:twoP:acquire:bkgFldr:firstColor = firstColorG
							variable/G root:packages:twoP:acquire:bkgFldr:lastColor = lastColorG
						endif
						ThreadGroupPutDF bkgThreadIDs [iChan], root:packages:twoP:acquire:bkgFldr
					endif
				endFor
				if ((zAvgStackAtOnce) || (mod(iZFrame, numZseriesAvg) == 0))
					// move the focus motor one step
					NVAR ZstepSize = root:packages:twoP:acquire:zstepsize
					SVAR FocusProc = root:packages:twoP:Acquire:StageProc
					SVAR stagePort = root:packages:twoP:acquire:StagePort
					NVAR zDist = $"root:packages:" + FocusProc + ":zdistancefromZero"
					variable xS=NaN, yS=NaN, zS=zDist + zStepSize, axS=NaN
					funcref StageMove_Template stageMove = $"StageMove_" + FocusProc
					stageMove (kStagesIsAbs, kStagesReturnNow, xS, yS, zS, axS)
					string valueStr
					sprintf valueStr, "%.1W1Pm",zS
					TextBox/W =twoPScanGraph/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 valueStr
				endif
				if (zAvgStackAtOnce)
					PercentComplete = (100 * iZFrame/numFrames)
				else
					PercentComplete = (100 * iZFrame/(numFrames * numZseriesAvg))
				endif
			endif
			break
		case kLiveMode:
			for (iChan =0; iChan < nCHans; iChan +=1)
					if (numtype (bkgThreadIDs [iChan]) ==0)
						newdatafolder/o root:packages:twoP:acquire:bkgFldr
						variable/G root:packages:twoP:acquire:bkgFldr:newFrame
						NVAR newFrame =  root:packages:twoP:acquire:bkgFldr:newFrame
						newFrame= 1
						if (showMerge)
							NVAR firstColorG = $"root:packages:twoP:examine:Ch" + num2Str (iChan + 1) + "FirstLutColor"
							NVAR LastColorG = $"root:packages:twoP:examine:Ch" + num2Str (iChan + 1) + "LastLutColor"
							variable/G root:packages:twoP:acquire:bkgFldr:firstColor = firstColorG
							variable/G root:packages:twoP:acquire:bkgFldr:lastColor = lastColorG
						endif
						ThreadGroupPutDF bkgThreadIDs [iChan], root:packages:twoP:acquire:bkgFldr
					endif
				endFor
			break
		case kTimeSeries: // repeat hook is used for cyclic acquisition only
			NVAR itFrame = root:packages:twoP:acquire:iTFrame
			NVAR nTFrames = root:packages:twoP:acquire:nTFrames
			PercentComplete = (100 * itFrame/nTFrames)
			if (iTFrame == nTFrames)
				NQ_ScanEnd (kTimeSeries, 0)
				return 0
			else
				for (iChan =0; iChan < nCHans; iChan +=1)
					if (numtype (bkgThreadIDs [iChan]) ==0)
						newdatafolder/o root:packages:twoP:acquire:bkgFldr
						variable/G root:packages:twoP:acquire:bkgFldr:newFrame
						NVAR newFrame =  root:packages:twoP:acquire:bkgFldr:newFrame
						newFrame= 1
						if (showMerge)
							NVAR firstColorG = $"root:packages:twoP:examine:Ch" + num2Str (iChan + 1) + "FirstLutColor"
							NVAR LastColorG = $"root:packages:twoP:examine:Ch" + num2Str (iChan + 1) + "LastLutColor"
							variable/G root:packages:twoP:acquire:bkgFldr:firstColor = firstColorG
							variable/G root:packages:twoP:acquire:bkgFldr:lastColor = lastColorG
						endif
						ThreadGroupPutDF bkgThreadIDs [iChan], root:packages:twoP:acquire:bkgFldr
					endif
				endFor
				itFrame +=1
			endif
			break
	endSwitch

	return 0
end

//******************************************************************************************************
// Starts each thread, and posts an initial data folder initialized with global variables needed by thread
// Last modified:
// 2017/08/12 by Jamie Boyd netter background threads and task based on fDAQmx_ScanGetNextIndex
// 2017/02/01 by Jamie Boyd  still working on thread per channel
// 20116/11/17 by Jamie Boyd new thread for each channel
// 2016/10/25 by Jamie Boyd initial version
function NQ_StartBKGThreads (s)
	STRUCT NQ_ScanStruct &s
	
	DFREF saveDFR = GetDataFolderDFR()	
	NVAR showMergeG = root:packages:twoP:examine:showMerge
	WAVE mergeWave =$""
	if (showMergeG)
		WAVE mergeWave =  root:packages:twoP:examine:scanGraph_mrg
		variable/G root:packages:twoP:examine:tempChanVar
		NVAR tempChanVar = root:packages:twoP:examine:tempChanVar
	endif
	Switch (s.scanMode)
		case kLiveMode:
			NVAR nLiveFramesG = root:Packages:twoP:Acquire:nLiveFrames
			NVAR liveHistCheckG = root:packages:twoP:acquire:liveHistCheck
			NVAR LiveAvgCheckG =  root:packages:twoP:acquire:LiveAvgCheck
			if (LiveAvgCheckG)
				NVAR numLiveAvgFramesG = root:packages:twoP:acquire:numLiveAvgFrames
			endif
			break
		case kTimeSeries:
			variable/G root:packages:twoP:acquire:nTFrames
			NVAR nTFrames = root:packages:twoP:acquire:nTFrames
			NVAR bufferSize = root:packages:twoP:acquire:tSeriesBufferSize
			nTFrames =  floor (s.numFrames/bufferSize)
			if (s.scanIsCyclic)
				variable/G root:packages:twoP:acquire:iTFrame =0
			else
				NVAR numFrames = root:packages:twoP:acquire:TseriesFrames
			endif
			break
		case kZSeries:
			variable/G root:packages:twoP:acquire:iZFrame =0
			
			break
	endSwitch
	// make a global wave to hold threadGroup ids, one per channel
	// each threadGroup has one thread and processes one channel
	// the thread function and data passed to it must be channel agnostic
	WAVE bkgThreadIDs = root:packages:twoP:acquire:bkgThreadIDs
	// make threads, one per channel
	variable iChan, nChans=2
	for (iChan =0; iChan < nChans; iChan +=1)
		if (s.scanChans & (2^iChan))
			bkgThreadIDs [iChan] = ThreadGroupCreate(1)
			// make a new data folder, copy over needed global variables
			newdatafolder/o/s root:packages:twoP:acquire:bkgStartFldr
			variable/G :flybackMode =s.flybackMode
			variable/G :frameTime = s.frameTime
			NVAR showChanG = $"root:packages:twoP:examine:showCh" + num2str (iChan + 1)
			variable/G :showChan = showChanG
			WAVE scanGraphWave = $""
			if (showChanG)
				WAVE scanGraphWave =$"root:packages:twoP:examine:scanGraph_ch" + num2str (iChan + 1)
			endif
			variable/G :showMerge = showMergeG
			if (showMergeG)
				tempChanVar = iChan + 1
				execute "root:packages:twoP:examine:tempChanVar=$\"kNQChan\" + num2str (root:packages:twoP:examine:tempChanVar) + \"layer\""
				variable/G :mergeLayer = tempChanVar
				//printf "MergeLayer = %d\r", tempChanVar
			endif

			Switch (s.scanMode)
				case kLiveMode:
					variable/G :nLiveFrames = nLiveFramesG
					variable/G :LiveAvgCheck =LiveAvgCheckG
					if (LiveAvgCheckG)
						variable/G :numLiveAvgFrames = numLiveAvgFramesG
					endif
					variable/G :liveHistCheck = liveHistCheckG
					wave histWave = $""
					if (liveHistCheckG)
						WAVE histWave = $"root:packages:twoP:examine:histwavech" + num2str (iChan + 1)
						duplicate histWave :histwave_cp
					endif
					WAVE acqWave = $"root:Packages:twoP:Acquire:LiveACQ_ch" + num2str (iChan + 1)
					ThreadStart bkgThreadIDs [iChan], 0, NQ_LiveChanThread (acqWave, scanGraphWave, mergeWave, histWave)
					break
				case kZseries:
					variable/G :numZframes = s.numFrames
					variable/G :zAvgFrames = s.zAvg
					WAVE scanWave = $"root:twoP_Scans:" +  s.NewScanName + ":" + s.NewScanName + "_ch" + num2str(iChan + 1)
					WAVE acqWave = $"root:packages:twoP:acquire:TempZWave_ch" + num2str (iChan + 1)
					setscale/p x 0, 1e-06, acqWave
					variable/G :avgStackAtOnce = s.zAvgStackAtOnce // acqWave is 3D if this variable is set, else 2D
					ThreadStart bkgThreadIDs [iChan], 0, NQ_zSeriesChanThread (scanWave, acqWave, scanGraphWave, mergeWave)
					break
				case kTimeSeries:
					WAVE scanWave = $"root:twoP_Scans:" +  s.NewScanName + ":" + s.NewScanName + "_ch" + num2str(iChan + 1)
					WAVE acqWave = $""
					
					if (s.scanIsCyclic)
						variable/G :tBufferSize = bufferSize
						variable/G :numFrames = nTFrames
						WAVE acqWave = $"root:packages:twoP:acquire:TempZWave_ch" + num2str (iChan + 1)
						setscale/p x 0, 1e-06, acqWave
						ThreadStart bkgThreadIDs [iChan], 0, NQ_tSeriesCyclicChanThread (scanWave, acqWave, scanGraphWave, mergeWave)
					else
						NVAR firstColorG = $"root:packages:twoP:examine:Ch" + num2Str (iChan + 1) + "FirstLutColor"
						NVAR LastColorG = $"root:packages:twoP:examine:Ch" + num2Str (iChan + 1) + "LastLutColor"
						variable/G :firstColor = firstColorG
						variable/G :lastColor = lastColorG
						variable/G :numFrames = numFrames
						ThreadStart bkgThreadIDs [iChan], 0, NQ_tSeriesChanThread (scanWave, scanGraphWave, mergeWave)
					endif
						
			endSwitch
			// post first datafolder for this channel
			ThreadGroupPutDF bkgThreadIDs [iChan], root:packages:twoP:acquire:bkgStartFldr
		else
			bkgThreadIDs [iChan] = NaN
		endif
	endfor
	setdatafolder saveDFR
end


ThreadSafe Function NQ_tSeriesChanThread (scanWave, scanGraphWave, mergeWave)
	WAVE scanWave, scanGraphWave, mergeWave
	// first (only) dfref (dfrInit) contains initiailization variables
	DFREF dfrInit = ThreadGroupGetDFR(0,inf)
	NVAR flybackMode =dfrInit:flyBackMode
	NVAR showChan =dfrInit:showChan
	NVAR showMerge = dfrInit:showMerge
	NVAR mergeLayer = dfrInit:mergeLayer
	NVAR numFrames = dfrInit:numFrames
	NVAR frameTime = dfrInit:frameTime
	
	variable xSize = dimsize (scanGraphWave, 0)
	variable ySize = dimsize (scanGraphWave, 1)
	variable frameSize = (xSize * ySize)
	variable sleepTicks = ceil (60 * frameTime) //&&&&
	variable nextTicks = ticks + 2 * sleepTicks
	variable iFrame, scanWavePos
	for (iFrame = 0;  iFrame < numFrames ; iFrame +=1, nextTicks += sleepTicks)
		//printf "Sleeping for %d seconds\r", (nextTicks-ticks)/60
		sleep/T (nextTicks-ticks)
		if (showChan || showMerge)
			scanGraphWave = scanWave[(iFrame * frameSize) + (q * xSize) + p] + (kNQtoUnsigned)
			//acqWave_temp3D = scanWave [p] [q] [r + iFrame] + (kNQtoUnsigned)
			if (flybackMode == 1)
				SwapEven (scanGraphWave)
			endif
			if (showMerge)
				NVAR firstColor = dfrInit:firstColor
				NVAR lastColor = dfrInit:lastColor
				variable rangevar= 65536/(lastColor - firstColor)
				//printf "mergeLayer = %d, firstcolor = %d, lastcolor = %d, rangeVar = %f\r", mergeLayer, firstColor, lastColor, rangevar
				mergeWave [*] [*] [mergeLayer] =  min (65535, max (0,(scanGraphWave [p] [q] - firstColor)) * rangevar)
			endif
		endif
	endfor
	killdatafolder dfrInit
	return 0
end

			
ThreadSafe Function NQ_tSeriesCyclicChanThread (scanWave, acqWave, scanGraphWave, mergeWave)
	WAVE scanWave, acqWave, scanGraphWave, mergeWave
	
	// first dfref (dfrInit) contains initiailization variables
	DFREF dfrInit = ThreadGroupGetDFR(0,inf)
	NVAR flybackMode =dfrInit:flyBackMode
	NVAR showChan =dfrInit:showChan
	NVAR showMerge = dfrInit:showMerge
	NVAR mergeLayer = dfrInit:mergeLayer
	NVAR tBufferSize = dfrInit:tBufferSize
	NVAR numFrames = dfrInit:numFrames
	//printf "NumFrames = %d\r", numFrames
	//	make 3D temp waves for processing
	variable xSize = dimsize (scanGraphWave, 0)
	variable ySize = dimsize (scanGraphWave, 1)
	variable frameSize= xSize * ySize
	//make/w/u/o/n = ((xSize), (ySize)) dfrInit:acqWave2D_temp
	//WAVE acqWave_temp2D = dfrInit:acqWave_temp
	make/w/u/o/n = ((xSize), (ySize), (tBufferSize)) dfrInit:acqWave3D_temp
	WAVE acqWave_temp3D = dfrInit:acqWave3D_temp
	// go through the frames
	variable iFrame, scanWavePos
	for (iFrame =0, scanWavePos =0; iFrame < numFrames; iFrame +=1, scanWavePos += tBufferSize)
		//printf "iFrame = %d\r", iFrame
		DFREF dfr = ThreadGroupGetDFR(0,inf)
		NVAR newFrameG = dfr:newFrame
		if (newFrameG == 0)
			killdatafolder dfr
			break // break out of loop so we can return, user cancelled
		else
			acqWave_temp3D = AcqWave [r * frameSize + q * xSize  + p] +  (kNQtoUnsigned)
			if (flybackMode == 1)
				SwapEven (acqWave_temp3D)
			endif
			scanWave [*] [*] [scanWavePos, scanWavePos + tBufferSize -1] = acqWave_temp3D [p] [q] [r - scanWavePos]
			if (showChan || showMerge)
				ProjectSpecFrames(acqWave_temp3D, 0, (tBufferSize -1), scanGraphWave, 0, 2, 2)
				if (showMerge)
					NVAR firstColor = dfr:firstColor
					NVAR lastColor = dfr:lastColor
					variable rangevar= 65536/(lastColor - firstColor)
					//printf "mergeLayer = %d, firstcolor = %d, lastcolor = %d, rangeVar = %f\r", mergeLayer, firstColor, lastColor, rangevar
					mergeWave [*] [*] [mergeLayer] =  min (65535, max (0,(scanGraphWave [p] [q] - firstColor)) * rangevar)
				endif
			endif
			killdatafolder dfr
		endif
	endfor
	killdatafolder dfrInit
	return 0
end
			

ThreadSafe Function NQ_zSeriesChanThread (scanWave, acqWave, scanGraphWave, mergeWave)
	WAVE scanWave, acqWave, scanGraphWave, mergeWave
	
	// first dfref (dfrInit) contains initiailization variables
	DFREF dfrInit = ThreadGroupGetDFR(0,inf)
	NVAR flybackMode =dfrInit:flyBackMode
	NVAR frameTime =dfrInit:frameTime
	NVAR showChan =dfrInit:showChan
	NVAR showMerge = dfrInit:showMerge
	NVAR mergeLayer = dfrInit:mergeLayer
	NVAR numZframes = dfrInit:numZframes
	NVAR zAvgFrames = dfrInit:zAvgFrames
	NVAR avgStackAtOnce = dfrInit:avgStackAtOnce
	// variables and waves we make at init
	//	make 2D temp wave for processing
	variable xSize = dimsize (scanGraphWave, 0)
	variable ySize = dimsize (scanGraphWave, 1)
	make/w/u/o/n = ((xSize), (ySize)) dfrInit:acqWave_temp
	WAVE acqWave_temp = dfrInit:acqWave_temp
	make/w/u/o/n = ((xSize), (ySize), (zAvgFrames)) dfrInit:acqWave_zAvgTemp
	WAVE acqWave_zAvgTemp = dfrInit:acqWave_zAvgTemp
	variable nFrameCalls, zAvgFramePos
	if (avgStackAtOnce)
		nFrameCalls = numZframes
		zAvgFramePos = zAvgFrames -1
	else
		nFrameCalls = numZframes * zAvgFrames
	endif
	// go through the frames
	variable iFrame, scanWavePos
	for (iFrame =1; iFrame < nFrameCalls; iFrame +=1)
		DFREF dfr = ThreadGroupGetDFR(0,inf)
		NVAR newFrameG = dfr:newFrame
		if (newFrameG == 0)
			killdatafolder dfr
			break // break out of loop so we can return, user cancelled
		else
			if (avgStackAtOnce) // acqWave is 3D wave ready to be medianed
				fastop acqWave_zAvgTemp = AcqWave + (kNQtoUnsigned)
				ProjectSpecFrames(acqWave_zAvgTemp, 0, (zAvgFrames -1), acqWave_temp, 0, 2, 3)
				scanWavePos = iFrame
			else
				zAvgFramePos = mod (iFrame, zAvgFrames)
				acqWave_zAvgTemp [*] [*] [zAvgFramePos] = AcqWave [(q * xSize) + p] + (kNQtoUnsigned)
				if (zAvgFramePos == zAvgFrames -1)
					ProjectSpecFrames(acqWave_zAvgTemp, 0, (zAvgFrames -1), acqWave_temp, 0, 2, 3)
					scanWavePos = (iFrame/zAvgFrames)-1
				endif
			endif
			if (zAvgFramePos == zAvgFrames -1)
				if (flybackMode == 1)
					SwapEven (acqWave_temp)
				endif
				scanWave [*] [*] [scanWavePos] = acqWave_temp [p] [q]
				if (showChan || showMerge)
					fastop scanGraphWave = acqWave_temp
				endif
				if (showMerge)
					NVAR firstColor = dfr:firstColor
					NVAR lastColor = dfr:lastColor
					variable rangevar= 65536/(lastColor - firstColor)
					//printf "mergeLayer = %d, firstcolor = %d, lastcolor = %d, rangeVar = %f\r", mergeLayer, firstColor, lastColor, rangevar
					mergeWave [*] [*] [mergeLayer] =  min (65535, max (0,(scanGraphWave [p] [q] - firstColor)) * rangevar)
				endif
			endif
			killdatafolder dfr
		endif
	endfor
	killdatafolder dfrInit
	return 0
end


//******************************************************************************************************
// preemptive thread that does the heavy lifting of copying data and so forth for live mode
// acquire wave and display waves passed directly to thread;
// other paramaters put in a datafolder and posted first
// last modified 2017/08/12 by Jamie Boyd
ThreadSafe Function NQ_LiveChanThread (AcqWave, displayWave, mergeWave, histWave)
	WAVE AcqWave, displayWave, mergeWave, histWave
	
	// first dfref (dfrInit) contains initialization variables
	// so do it before main loop
	DFREF dfrInit = ThreadGroupGetDFR(0,inf)
	//	make 2D temp wave for processing
	variable xSize = dimsize (displayWave, 0)
	variable ySize = dimsize (displayWave, 1)
	make/w/u/o/n = ((xSize), (ySize)) dfrInit:acqWave_temp
	WAVE acqWave_temp = dfrInit:acqWave_temp
	NVAR flybackMode =dfrInit:flyBackMode
	NVAR liveHistCheck = dfrInit:liveHistCheck
	NVAR liveAvgCheck = dfrInit:liveAvgCheck
	NVAR nLiveAvgFrames = dfrInit:numLiveAvgFrames
	NVAR showMerge = dfrInit:showMerge
	NVAR mergeLayer =  dfrInit:mergeLayer
	if (liveAvgCheck)
		make/w/u/o/n = ((dimsize (displayWave, 0)), (dimsize (displayWave, 1)), (nLiveAvgFrames))  dfrInit:LiveAvg
		WAVE liveAvg = dfrInit:LiveAvg
		fastop liveAvg =0
		variable liveFramePos
		displayWave =0
	endif
	NVAR nLiveFrames = dfrInit:nLiveFrames
	if (nLiveFrames > 1)
		make/w/u/o/n = ((dimsize (displayWave, 0)), (dimsize (displayWave, 1)), (nLiveFrames)) dfrInit:acqWave_nLiveTemp
		WAVE acqWave_nLiveTemp = dfrInit:acqWave_nLiveTemp
	endif
	// this loop is called at end of every new acquisition, or when a stop is requested
	variable iFrame
	for (iFrame=0;;iFrame +=1)
		DFREF dfr = ThreadGroupGetDFR(0,inf)
		NVAR newFrameG = dfr:newFrame
		if (newFrameG == 0)
			killdatafolder dfr
			break // break out of loop so we can return
		else // we have completed another acquisition
			// copy from signed data into unsigned data,in 3D for nLiveFrames > 1
			// if nLiveFrames > 1, project 3D data into 2D wave acqWave_temp
			if (nLiveFrames ==1) 
				fastop acqWave_temp = AcqWave + (kNQtoUnsigned) // [frameOffset + q * ySize + p]
			else
				fastop acqWave_nLiveTemp = AcqWave + (kNQtoUnsigned)
				ProjectSpecFrames(acqWave_nLiveTemp, 0, (nLiveFrames -1), acqWave_temp, 0, 2, 3)
			endif
			if (flybackMode == 1)
				SwapEven (acqWave_temp)
			endif
			if (liveAvgCheck)
				liveFramePos = mod (iFrame, nLiveAvgFrames)
				displayWave += (acqWave_temp [p] [q] - liveAvg [p] [q] [liveFramePos])/nLiveAvgFrames
				liveAvg [*] [*] [liveFramePos] = acqWave_temp [p] [q]
			else
				fastOp displayWave = AcqWave_temp
			endif
			if (liveHistCheck)
				if (nLiveFrames ==1)
					WAVE histMe= AcqWave_temp
				else
					WAVE histMe = acqWave_nLiveTemp
				endif
				WAVE histwave_cp = dfrInit:histwave_cp
				Histogram/B=2 histMe, histwave_cp
				histWave = histwave_cp
			endif
			if (showMerge)
				NVAR firstColor = dfr:firstColor
				NVAR lastColor = dfr:lastColor
				variable rangevar= 65536/(lastColor - firstColor)
				//printf "mergeLayer = %d, firstcolor = %d, lastcolor = %d, rangeVar = %f\r", mergeLayer, firstColor, lastColor, rangevar
				mergeWave [*] [*] [mergeLayer] =  min (65535, max (0,(displayWave [p] [q] - firstColor)) * rangevar)
			endif
		endif
	endfor
	killdatafolder dfrInit
	return 0
end
