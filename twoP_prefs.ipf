#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#pragma version = 2.1  			// Last Modified: 2025/07/10 by Jamie Boyd.
#pragma IgorVersion = 7

#include "GUIPControls"


Menu "Macros"
	Submenu "twoP" 
		"Edit Acquire Preferences", /Q, twoP_PrefsMakePanel()
	end
end
constant kTwoPPrefsVers = 110 // Preferences structure version number

// **************************************************************************************************************
// for storing imformation about twoP settings
// Last Modified 2025/07/09 by Jamie Boyd
Structure TwoPPrefsStruct
	uint32 version							// Preferences structure version number.
	// imaging
	char imBoardName[32]					// name of the DAQ board used for imaging, as configured with MAX
	uint32 pixFullScale [2]					// default pixel sizes of full scale image [xSIze, ySize]
	float voltsFullScale[4]					// default voltage range of full scale scan [xStart, Xend, ySTart, yEnd]
	float pixTime							// one tick of pixel clock, in seconds
	float dutyCycle							// proportion of galvo scan (0 to 1) linearized for collecting image data
	float flybackProp						// ratio (0 to 1) of flyback time compared to linearized scan time
	float scanHeadDelay						// time (seconds) that galvo position lags control signal
	float minLiveFrameTime					// If frame time is shorter than this, additional frames are collected and averaged 
	uchar numImChans						// number of image channels, 1 to 4 
	struct twoPChanStruct imageChans[4] 	// image channels, as many as 4 
	uchar numObjs							// number of objectives, (1 to 8)
	struct twoPObjStruct objList [8]		// scaling and offset values for microscope objectives
	// Stage
	char stageProc[32]						// name of stage encoder procedure, MS200, e.g.
	char stagePort[32]						// serial port to use with the stage encoder, COM1, e.g.
	// Shutter
	uchar shutterOpenLevel					// logic level (0 or 1) which opens the TTL shutter
	float shutterDelay						// time (seconds) it takes to open shutter
	// ePhys
	char ePhysBoardName[32]					// name of the DAQ board used for electrophysiology, as configured with MAX
	float ePhysSampFreq						// sampling frequency for ePhys (somewhere around 20 to 200 kHz)
	uchar numEphysChans						// number of channels configured for ePhys
	struct twoPChanStruct ePhysChans[8] 	// channel names, gains, offsets, ans scaling for image channels, as many as 8 
	// triggers
	uchar numTriggers						// number of triggers in use, currently only 2 are supported
	struct twoPTrigStruct triggers [4]		// counter number, polarity, and duration					
EndStructure


// **************************************************************************************************************
// each analog input channel is represented by this structure
// Last Modified 2015/04/28 by Jamie Boyd
// aToDtype can be differential, pseudodifferential, referenced single-ended, or non-referenced single-ended
// Differential is typical, USB devices may need referenced single-ended, S-series devices (like pci-6110) require pseudo-differential
// NIDAQtools sets a max and a min Voltage for digitization scaling, but our boards all have symetrical ranges, so one value is enough
// For imaging, acquisition is into unsigned word (16 bit) waves and no scaling or offset is done.
// For ePhys, acquisition is into floating point wave, so scaling and offset make more sense
Structure twoPChanStruct
	char chanName [32]		// name of channel, for wave naming purposes
	char aToDtype[8]		// Analog input mode for the channel, can be Diff, PDIF, RSE, or NRSE 
	float inputScaling		// minimum/maximum expected range of input signals, used for digitization 
	float scaling			// scaling applied AFTER A/D conversion, use to fill 16 bit int wave range, or for floating point, wave, make scaling nice
	float offset			// offset applied AFTER A/D conversion, used to fit data into unsigned waves, e.g.
EndStructure



//**********************************************************************************************************************
// The scaling and offset of each objective is represented by this structure
// Last modified 2015/04/23
Structure twoPObjStruct
	uChar objName [32]
	float xScal
	float yScal
	float xOffset
	float yOffset
EndStructure


// **************************************************************************************************************
// each output trigger is represented by this structure
// Last Modified 2025/07/09 by Jamie Boyd
Structure twoPTrigStruct
	uChar ctrNum		// number of counter, from 0 to max number of counters (2-4)
	uchar polarity		// 0 for low-to-high, 1 for high-to-low
	float duration			// duration in seconds
EndStructure



// **************************************************************************************************************
// Lists NI boards in system, with product type and device category
// Last Modified 2025/07/07 by Jamie Boyd
function/s twoP_PrefsListBoards()
	
	string aBoard, boards=fDAQmx_DeviceNames()
	variable iBoard, nBoards = itemsinList(boards, ";")
	string outStr = ""
	for (iBoard=0;iBoard < nBoards;iBoard +=1)
		aBoard = stringFromList (iBoard, boards,";")
		DAQmx_DeviceInfo /DEV=aBoard
		outStr += aBoard + ": " + S_NIProductType + ": " + S_NIDeviceCategory + ";"
	endfor
	//outStr += ";None"
	return outStr
end


// **************************************************************************************************************
// sets strings for NI board for imaging or ephys and adjusts number of channels in channel list
// could do similar for trigger list
// Last Modified 2025/07/07 by Jamie Boyd - also sets boardNameClass
Function twoP_PrefsSetBoardName (pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			if (cmpStr (pa.ctrlName, "ImageBoardPopMenu") ==0)
				SVAR boardNameG = root:packages:twoP:acquire:imageBoard
				SVAR boardClassG =  root:packages:twoP:acquire:imageBoardClass
				SVAR gainsG = root:packages:twoP:acquire:imageGains
				WAVE/t chanList = root:packages:twoP:Acquire:imChanList
				WAVE chanSelList =  root:packages:twoP:Acquire:imChanSelList
			elseif (cmpStr (pa.CtrlName, "ePhysBoardPopMenu") ==0)
				SVAR boardNameG =  root:packages:twoP:acquire:ePhysBoard
				SVAR boardClassG =  root:packages:twoP:acquire:ePhysBoardClass
				SVAR gainsG = root:packages:twoP:acquire:ePhysGains
				WAVE/t chanList = root:packages:twoP:Acquire:ePhysChanList
				WAVE chanSelList = root:packages:twoP:Acquire:ePhysChanSelList
			endif
			variable numChans = fdaqmx_NumAnalogInputs(boardNameG)
			boardNameG = stringfromlist (0, pa.popStr, ":")
			boardClassG = trimString (stringfromlist (2, pa.popStr, ":"))
			if (cmpStr (boardNameG, "None") != 0)
				strswitch (boardClassG)
					case "E Series DAQ":
						gainsG = "0.05;0.5;5;10"
						numChans /=2 	// assume differential signals with E-series
						break
					case "S Series DAQ":
						gainsG = "0.2;0.5;1;2;5;10"
						break
					case "X Series DAQ":
						gainsG = "1;2;5;10"
						break
					default:
						gainsG = "10"
						break
				endswitch
			endif
			// readjustchannel list for number of channels on the board
			redimension/n=(numChans, -1) chanList, chanSelList
			chanSelList [*] [0] = 32 // check box for channel number is active
			chanSelList [*] [1] = 2	 // channel name, editable
			chanSelList [*] [2] = 0 // not editable -have to use popMenu for PDIFF,RSE, etc.
			chanSelList [*] [3] = 0 // not editable -have to use popMenu for gains
			chanSelList [*] [4,5] = 0 // scaling and offset not used for images
			chanList [*] [0] = num2str(p) // ai channel numbers
			chanList [*] [4] = num2str (1) // scaling = 1
			chanList [*] [5] = num2str (0) // offset = 0
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End


// **************************************************************************************************************
// manages lists of channels for imaging or ephys
// Last Modified 2025/07/09 by Jamie Boyd - does ePhys channels as well as imaging
Function twoP_PrefsChanListBoxProc(s) : ListboxControl
	STRUCT WMListboxAction &s
	
	if (cmpStr (s.ctrlName, "imChansListBox") ==0)
		SVAR imageGainsG = root:packages:twoP:acquire:imageGains
		SVAR selChanList = root:packages:twoP:acquire:selImageChanList
	elseif (cmpStr (s.ctrlName, "ephysChansListBox") == 0)
		SVAR imageGainsG = root:packages:twoP:acquire:ePhysGains
		SVAR selChanList = root:packages:twoP:acquire:selEphysChanList
	endif 
	switch (s.eventCode)
		case 1:		// mouse down
			if (s.eventMod & 16) // a right-click, show context menu for columns 2, 3, or 4
				string contextMenuStr
				variable doContextMenu
				switch (s.col)
					case 2:  // digitization type
						contextMenuStr =  "Diff;RSE;NRSE;PDIFF"
						doContextMenu =1
						break
					case 3: // Gain
						contextMenuStr = imageGainsG
						doContextMenu =1
						break
					default:
						doContextMenu =0
						break
				endSwitch
				if (doContextMenu)
					PopupContextualMenu contextMenuStr
					if (V_Flag > 0)
						if (s.row ==-1)
							s.listWave [] [s.col] =S_Selection
						else
							s.listWave [s.row] [s.col] =S_Selection
						endif
					endif
				endif
			endif
			break;
		case 6:		// begin edit
			s.SelWave [s.row] [s.col] = s.SelWave [s.row] [s.col] | 1
			break
		case 7:		// finish edit -do sanity checks, write contents to chanStr
			switch (s.col)
				case 1: // Channel name
					s.listWave [s.row] [s.col] = cleanupname (s.listWave [s.row] [s.col], 0)
					break
				case 2:  // type
					if (whichListItem (s.listWave [s.row] [s.col], "Diff;RSE;NRSE;PDIFF", ";") ==-1)
						doAlert 0, "Type has to be one of  \"Diff, RSE, NRSE, or PDIFF\" Try right-clicking for a contextual menu."
						s.listWave [s.row] [s.col] = ""
					endif
					break
				case 3: // scaling
				case 4: // offset
					if (numtype (str2num  (s.listWave [s.row] [s.col])) != 0)
						doAlert 0, "Scaling and Offset need to be numbers."
						s.listWave [s.row] [s.col] = ""
					else
						s.listWave [s.row] [s.col]  = num2str (str2num (s.listWave [s.row] [s.col]))
					endif
					break
			endSwitch
			break
		case 13: // flip a checkbox
			if ((s.SelWave [s.row] [0] & 16) ==0)
				string chanSpec = s.listWave [s.row] [0] + ":" + s.listWave [s.row] [1]
				selChanList = removeFromList (chanSpec, selChanList, ";")
			endif
			break
	endswitch
	return 0           // other return values reserved
End



// **************************************************************************************************************
// adds an objective to list of objectives
// Last Modified 2025/07/07 by Jamie Boyd
Function twoP_prefsAddObjProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			WAVE/T objWave = root:packages:twoP:acquire:objWave 
			WAVE objSelWave = root:packages:twoP:acquire:objSelWave 
			variable nRows=DimSize(objWave, 0)
			redimension/n=((nRows + 1),-1) objWave, objSelWave
			objSelWave = 2
			listbox ObjectivesList selRow = nRows
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End


// **************************************************************************************************************
// Removes an objective from list of objectives
// Last Modified 2025/07/07 by Jamie Boyd
Function twoP_prefsDelObjProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			WAVE/T objWave = root:packages:twoP:acquire:objWave 
			WAVE objSelWave = root:packages:twoP:acquire:objSelWave 
			controlinfo objectiveslist
			deletePoints/M=0 V_Value, 1, objWave, objSelWave
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

// **************************************************************************************************************
// used for polarity of DIO task used to open laser shutter
// Last Modified 2025/07/07 by Jamie Boyd
Function twoP_PrefsSetShutterPolarity(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			NVAR polarity = root:Packages:twoP:Acquire:shutterOpen
			polarity = pa.popNum - 1
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End


// **************************************************************************************************************
// sets a string to the name of the stage procedure chosen from popup
// Last Modified 2025/07/07 by Jamie Boyd
Function twoP_PrefsSetStage(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			SVAR stageProc = root:packages:twoP:acquire:stageProc
			stageProc =  pa.popStr
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


// **************************************************************************************************************
// sets a string to the name of the serial port chosen from popup
// Last Modified 2025/07/07 by Jamie Boyd
Function twoP_PrefsSetStagePort(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			SVAR stagePort = root:Packages:twoP:Acquire:StagePort
			stagePort = pa.popStr
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


// **************************************************************************************************************
// sets polarity of counter ouput for triggers
// Last Modified 2025/07/07 by Jamie Boyd
Function twoP_PrefsSetTrigPolarity(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			if (cmpStr (pa.ctrlname, "Trigger1PolarityPopMenu") == 0)
				NVAR trigPol = root:packages:twoP:acquire:Trig1Polarity
			elseif (cmpStr (pa.ctrlname, "Trigger2PolarityPopMenu") == 0)
				NVAR trigPol = root:packages:twoP:acquire:Trig2Polarity
			endif
			trigPol = pa.popNum -1
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End


// **************************************************************************************************************
//Ensures that the path to saved preferences file is set to the twoPhoton user procedures file. 
// Last modified 2025/07/10 by Jamie Boy
Function twoP_PrefsMakePath ()
	pathinfo twoPPrefsPath
	if (V_Flag == 0)
		newPath/C/Q/Z twoPPrefsPath SpecialDirPath("Igor Pro User Files" , 0, 0, 0) + "User Procedures:twoPhoton"
		PathInfo twoPPrefsPath
		if (V_flag == 0)
			DoAlert 0, "Igor could not find twoPhoton folder in User Procedures folder."
			return 1
		endif
	endif
end

// **************************************************************************************************************
//Makes global variables for preferences in acquire folder. Most of these are directly used by twoP acquire 
// Last modified 2025/07/10 by Jamie Boyd 
Function twoP_PrefsMakeGlobals ()
	// make data folder
	if (!(DataFolderExists ("root:packages:twoP:acquire")))
		if (!(DataFolderExists ("root:packages:twoP")))
			if (!(DataFolderExists ("root:packages")))
				newDataFolder root:packages
			endif
			newDataFolder root:packages:twoP
		endif
		newDataFolder root:packages:twoP:acquire
	endif
	String/G root:packages:twoP:acquire:LoadedPrefsName = ""
	String/G root:Packages:twoP:Acquire:newPrefsName= ""
	Variable/G root:packages:twoP:acquire:pixWidthFS =0
	Variable/G root:packages:twoP:acquire:pixHeightFS =0
	Variable/G root:packages:twoP:acquire:xStartVoltsFS =0
	Variable/G root:packages:twoP:acquire:xEndVoltsFS =0
	Variable/G root:packages:twoP:acquire:yStartVoltsFS =0
	Variable/G root:packages:twoP:acquire:YEndVoltsFS =0
	// timing
	Variable/G root:packages:twoP:acquire:pixTime = 0
	Variable/G root:packages:twoP:acquire:DutyCycle = 0
	Variable/G root:packages:twoP:acquire:ScanHeadDelay = 0
	Variable/G root:packages:twoP:acquire:flybackProp =0
	Variable/G root:packages:twoP:acquire:minLiveFrameTime =0
	//IMage board
	String/G root:packages:twoP:acquire:ImageBoard = ""
	string/G root:packages:twoP:acquire:imageBoardClass =""
	String/G root:packages:twoP:acquire:imageGains = ""
	make/t/o/n = (1, 6)  root:packages:twoP:Acquire:imChanList
	make/o/n = (1, 6)  root:packages:twoP:Acquire:imChanSelList
	WAVE/t chanList = root:packages:twoP:Acquire:imChanList
	WAVE chanSelList =  root:packages:twoP:Acquire:imChanSelList
	SetDimlabel 1,0, ai_chan chanList
	SetDimlabel 1,1, chanName chanList
	SetDimlabel 1,2, Type chanList
	SetDimlabel 1,3, Range chanList
	SetDimlabel 1,4, scal chanList
	SetDimlabel 1,5, offset chanList
	chanSelList [*] [0] = 32 // check box for channel number is active
	chanSelList [*] [1] = 2	 // channel name, editable
	chanSelList [*] [2] = 0 // not editable -have to use popMenu for PDIFF,RSE, etc.
	chanSelList [*] [3] = 0 // not editable -have to use popMenu for gains
	chanSelList [*] [4,5] = 6 // scaling and offset not used for images
	chanList [*] [0] = num2str(p) // ao channel numbers
	chanList [*] [4] = num2str (1) // scaling = 1
	chanList [*] [5] = num2str (0) // offset = 0
	chanList[0] [1] = "CHAN_NAME"
	chanList[0] [2] = "A2D_TYPE"
	chanList[0] [3] = "INPUT_RANGE"
	chanList [0] [4] ="SCALING"
	chanList [0] [5] = "OFFSET"
	String/G root:Packages:twoP:Acquire:selImageChanList = ""
	make/o/t/n = (1, 5)  root:packages:twoP:acquire:objWave
	make/o/n = (1, 5)  root:packages:twoP:acquire:objSelWave
	WAVE/t objWave = root:packages:twoP:acquire:objWave
	WAVE objSelWave =  root:packages:twoP:acquire:objSelWave
	SetDimlabel 1,0, Objective objWave
	SetDimlabel 1,1, X_Scal objWave
	SetDimlabel 1,2, Y_Scal objWave
	SetDimlabel 1,3, X_Offset objWave
	SetDimlabel 1,4, Y_Offset objWave
	objSelWave = 2 // editable
	objWave [0] [0] = "OBJ_NAME"
	objWave [0] [1] =  "X_SCAL"
	objWave [0] [2] ="Y_SCAL"
	objWave [0] [3] = "X_OFFSET"
	objWave [0] [4] = "Y_OFFSET"
	string/G root:Packages:twoP:Acquire:curObj = ""
	variable/G root:packages:twoP:Acquire:CurObjNum =0
	String/G root:packages:twoP:acquire:StageProc =""
	String/G root:packages:twoP:acquire:StagePort = ""
	Variable/G root:Packages:twoP:Acquire:shutterOpenLevel =0
	Variable/G root:Packages:twoP:Acquire:shutterDelay = 0
	Variable/G root:packages:twoP:Acquire:shutterTaskNum = 0
	String/G root:Packages:twoP:Acquire:ePhysBoard = ""
	string/G root:packages:twoP:acquire:ePhysBoardClass =""
	String/G root:packages:twoP:acquire:ePhysGains = ""
	Variable/G root:Packages:twoP:Acquire:ePhysSampFreq =0
	make/t/o/n = (1, 6)  root:packages:twoP:Acquire:EphysChanList
	make/o/n = (1, 6)  root:packages:twoP:Acquire:EphysChanSelList
	WAVE/t chanList = root:packages:twoP:Acquire:EphysChanList
	WAVE chanSelList =  root:packages:twoP:Acquire:EphysChanSelList
	SetDimlabel 1,0, ai_chan chanList
	SetDimlabel 1,1, chanName chanList
	SetDimlabel 1,2, Type chanList
	SetDimlabel 1,3, Range chanList
	SetDimlabel 1,4, scal chanList
	SetDimlabel 1,5, offset chanList
	chanSelList [*] [0] = 32 // check box for channel number is active
	chanSelList [*] [1] = 2	 // channel name, editable
	chanSelList [*] [2] = 0 // not editable -have to use popMenu for PDIFF,RSE, etc.
	chanSelList [*] [3] = 0 // not editable -have to use popMenu for gains
	chanSelList [*] [4,5] = 6 // scaling and offset not used for images
	chanList [*] [0] = num2str(p) // ao channel numbers
	chanList [0] [1] = "CHAN_NAME"
	chanList [0] [2] = "A2D_TYPE"
	chanList [0] [3] = "INPUT_RANGE"
	chanList [0] [4] = "SCALING"
	chanList [0] [5] ="OFFSET"
	String/G root:Packages:twoP:Acquire:selEphysChanList = ""
	Variable/G root:packages:twoP:acquire:Trig1Polarity =0
	Variable/G  root:packages:twoP:acquire:Trig1Duration = 0
	VAriable/G root:packages:twoP:acquire:Trig2Polarity = 0
	Variable/G root:packages:twoP:acquire:Trig2Duration = 0
end


// **************************************************************************************************************
// Calls twoP_PrefsLoad with chosen file
// Last modified 2025/07/09 by Jamie Boyd 
Function twoP_PrefsLoadPopmenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			twoP_PrefsLoad (pa.popStr)
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End


// **************************************************************************************************************
// loads a preferences file and sets global variables for stage procedure
// Last modified 2025/07/09 by Jamie Boyd 
Function twoP_PrefsLoad (prefsFileName)
	string prefsFileName
	// make sure path exists
	twoP_PrefsMakePath ()
	// make sure folder exists
	if (!(DataFolderExists ("root:packages:twoP:acquire")))
		twoP_PrefsMakeGlobals ()
	endif
	SVAR prefsName = root:packages:twoP:acquire:LoadedPrefsName
	prefsName  = prefsFileName
	// make a prefs struct and fill it from chosen prefs file
	Struct twoPPrefsStruct thePrefs
	LoadPackagePreferences /P=twoPPrefsPath "twoPhoton", prefsFileName + ".bin", 0, thePrefs
	if (V_Flag)
		doalert 0, "Preferences were not loaded, error = " + num2str (V_Flag)
		prefsName = "PREFS NOT LOADED"
		return 1
	endif
	if (thePrefs.version != kTwoPPrefsVers)
		print thePrefs.version
		doAlert 0, "this preferences file version, " + num2str (thePrefs.version) + ",  is not right for this copy of the twoPhoton procedures."
		return 1
	endif
	//imaging stuff
	SVAR imboard = root:packages:twoP:acquire:ImageBoard
	imboard = thePrefs.imBoardName
	// image full scale
	NVAR pixWidthFS = root:packages:twoP:acquire:pixWidthFS
	pixWidthFS = thePrefs.pixFullScale[0]
	NVAR pixHeightFS=root:packages:twoP:acquire:pixHeightFS
	pixHeightFS = thePrefs.pixFullScale[1]
	NVAR xStartVoltsFS = root:packages:twoP:acquire:xStartVoltsFS 
	xStartVoltsFS= thePrefs.voltsFullScale [0]
	NVAR xEndVoltsFS = root:packages:twoP:acquire:xEndVoltsFS
	xEndVoltsFS = thePrefs.voltsFullScale [1]
	NVAR yStartVoltsFS= root:packages:twoP:acquire:yStartVoltsFS
	yStartVoltsFS = thePrefs.voltsFullScale [2]
	NVAR yEndVoltsFS =root:packages:twoP:acquire:yEndVoltsFS
	yEndVoltsFS = thePrefs.voltsFullScale [3]
	// Timing
	NVAR pixTime = root:packages:twoP:acquire:pixTime
	pixTime = thePrefs.pixTime
	NVAR dutyCycle = root:packages:twoP:acquire:dutyCycle
	dutyCycle = thePrefs.dutyCycle
	NVAR flybackProp= root:packages:twoP:acquire:flybackProp
	flybackProp =thePrefs.flybackProp
	NVAR scanHeadDelay = root:packages:twoP:acquire:scanHeadDelay
	scanHeadDelay = thePrefs.scanHeadDelay
	NVAR minLiveFrameTime = root:packages:twoP:acquire:minLiveFrameTime
	minLiveFrameTime = thePrefs.minLiveFrameTime
	//image Channels
	variable iChan, numChans = thePrefs.numImChans
	WAVE/t chanList = root:packages:twoP:Acquire:imChanList
	WAVE chanSelList =  root:packages:twoP:Acquire:imChanSelList
	redimension/n=(numChans, 6) chanList, chanSelList
	chanSelList [*] [0] = 32 // check box for channel number is active
	chanSelList [*] [1] = 2	 // channel name, editable
	chanSelList [*] [2] = 0 // not editable -have to use popMenu for PDIFF,RSE, etc.
	chanSelList [*] [3] = 0 // not editable -have to use popMenu for gains
	chanSelList [*] [4,5] = 0 // scaling and offset not used for images
	chanList [*] [0] = num2str(p) // ao channel numbers
	chanList [*] [4] = num2str (1) // scaling = 1
	chanList [*] [5] = num2str (0) // offset = 0
	for (iChan = 0; iChan < numChans; iChan +=1)
		chanList[iChan] [1] = thePrefs.imageChans[iChan].chanName
		chanList[iChan] [2] = thePrefs.imageChans[iChan].aToDtype
		chanList[iChan] [3] = num2str(thePrefs.imageChans[iChan].inputScaling)
		chanList [iChan] [4] = num2str (thePrefs.imageChans[iChan].scaling)
		chanList [iChan] [5] = num2Str (thePrefs.imageChans[iChan].offset)
	endfor
	//Objective scaling
	variable iObj,  numObjs = thePrefs.numObjs
	WAVE/t objWave = root:packages:twoP:acquire:objWave
	WAVE objSelWave =  root:packages:twoP:acquire:objSelWave
	redimension/n = (numObjs, 5) objWave, objSelWave
	objSelWave = 2 // editable
	for (iObj =0; iObj < numObjs; iObj +=1)
		objWave [iObj] [0] = thePrefs.objList[iObj].objName
		objWave [iObj] [1] =  num2str (thePrefs.objList[iObj].xScal)
		objWave [iObj] [2] = num2str(thePrefs.objList[iObj].yScal)
		objWave [iObj] [3] = num2str (thePrefs.objList[iObj].xOffset)
		objWave [iObj] [4] = num2str (thePrefs.objList[iObj].yOffset)
	endfor
	SVAR curObj = root:Packages:twoP:Acquire:curObj
	curObj =ObjWave [0] [0]
	NVAR CurObjNum = root:packages:twoP:Acquire:CurObjNum
	CurObjNum =0
	//Stage
	SVAR StageProc =root:packages:twoP:acquire:StageProc
	StageProc = thePrefs.stageProc
	SVAR StagePort = root:packages:twoP:acquire:StagePort
	StagePort = thePrefs.stagePort
	// shutter
	NVAR shutterOpenLevel = root:Packages:twoP:Acquire:shutterOpenLevel
	shutterOpenLevel = thePrefs.shutterOpenLevel
	NVAR shutterOPenLevel=root:Packages:twoP:Acquire:shutterOpenLevel
	NVAR shutterDelay = root:Packages:twoP:Acquire:shutterDelay
	shutterDelay = thePrefs.shutterDelay
	// ephys
	SVAR ephysBoardName= root:Packages:twoP:Acquire:ePhysBoard
	ephysBoardName = thePrefs.ephysBoardName
	NVAR ePhysSampFreq = root:Packages:twoP:Acquire:ePhysSampFreq
	ePhysSampFreq =thePrefs.ePhysSampFreq
	//ePhys channels
	WAVE/t chanList = root:packages:twoP:Acquire:EphysChanList
	WAVE chanSelList =  root:packages:twoP:Acquire:EphysChanSelList
	numChans = thePrefs.numEphysChans
	redimension/N = (numChans, 6)  chanList, chanSelList
	chanSelList [*] [0] = 32 // check box for channel number is active
	chanSelList [*] [1] = 2	 // channel name, editable
	chanSelList [*] [2] = 0 // not editable -have to use popMenu for PDIFF,RSE, etc.
	chanSelList [*] [3] = 0 // not editable -have to use popMenu for gains
	chanSelList [*] [4,5] = 0 // scaling and offset not used for images
	chanList [*] [0] = num2str(p) // ao channel numbers
	for(iChan =0; iCHan < numChans; iChan +=1)
		chanList [iChan] [1] = thePrefs.ePhysChans[iChan].chanName
		chanList [iChan] [2] = thePrefs.ePhysChans[iChan].aToDtype
		chanList [iChan] [3] = num2str (thePrefs.ePhysChans[iChan].inputScaling)
		chanList [iChan] [4] = num2str (thePrefs.ePhysChans[iChan].scaling)
		chanList [iChan] [5] = num2str (thePrefs.ePhysChans[iChan].offset)
	endfor
	String/G root:Packages:twoP:Acquire:selEphysChanList = ""
	// Triggers
	NVAR Trig1Polarity = root:packages:twoP:acquire:Trig1Polarity
	Trig1Polarity = thePrefs.triggers[0].ctrNum.polarity
	NVAR Trig1Duration = root:packages:twoP:acquire:Trig1Duration
	Trig1Duration = thePrefs.triggers[0].duration
	NVAR Trig2Polarity= root:packages:twoP:acquire:Trig2Polarity
	Trig2Polarity = thePrefs.triggers[1].ctrNum.polarity
	NVAR Trig2Duration =root:packages:twoP:acquire:Trig2Duration
	Trig2Duration =thePrefs.triggers[1].duration
	doWindow/F Scan_Settings_Prefs
	if (V_flag) // window exits
		popUPmenu Trigger1PolarityPopMenu mode = (Trig1Polarity + 1)
		popUPmenu Trigger2PolarityPopMenu mode = (Trig2Polarity + 1)
		popUPmenu ShutterPolarityPopMenu mode = (shutterOpenLevel +1)
	endif
	return 0
end

// **************************************************************************************************************
// calls function to check the vaidity of the loaded preference values
// Last modified 2025/07/13 by Jamie Boyd
Function twoP_PrefsCheckButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			twoP_PrefsTest()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

// **************************************************************************************************************
// checks the vaidity of the loaded preference values by initializing NIDAQ tasks, loading stage procedure
// also sets board gain strings which are not saved in preferences
// Last modified 2025/07/10 by Jamie Boyd
Function twoP_PrefsTest()
	string tempStr
	for (tempStr = fDAQmx_ErrorString (); CmpStr (tempStr, "") != 0;tempStr = fDAQmx_ErrorString ())  // clearNIDAQ error messgs
	endfor
	SVAR imBoard = root:packages:twoP:acquire:ImageBoard
	if (WhichListItem(imBoard, fdaQmx_DeviceNames(), ";") < 0)
		sprintf tempStr, "The specified imaging board, \"%s\", is not present in the system.\r", imBoard
		Doalert 0, tempStr
	else
		fDAQmx_ResetDevice(imBoard)
		DAQmx_DeviceInfo /DEV=imBoard
		string/G root:packages:twoP:acquire:imageBoardClass = S_NIDeviceCategory
		SVAR boardClass = root:packages:twoP:acquire:imageBoardClass
		String/G root:packages:twoP:acquire:imageGains = ""
		SVAR boardGains = root:packages:twoP:acquire:imageGains
		strswitch (boardClass)
			case "E Series DAQ":
				boardGains = "0.05;0.5;5;10"
				break
			case "S Series DAQ":
				boardGains = "0.2;0.5;1;2;5;10"
				break
			case "X Series DAQ":
				boardGains = "1;2;5;10"
				break
			default:
				boardGains = "10"
				break
		endswitch
	endif
	// load stage procedure and start Stage
	SVAR stageProc = root:packages:twoP:acquire:StageProc
	SVAR stagePort = root:packages:twoP:acquire:StagePort
	Execute/P/Q/Z "INSERTINCLUDE \"" + "Stages\""
	Execute/P/Q/Z "INSERTINCLUDE \"" + stageProc + "_Stage\""
	Execute/P/Q/Z "COMPILEPROCEDURES "
	sprintf tempStr, "StageStartStage(\"%s\", thePort = \"%s\") ", stageProc, stagePort
	execute/P/Q/Z tempStr
	// shutter task
	NVAR shutterOPenLevel=root:Packages:twoP:Acquire:shutterOpenLevel
	NVAR shutterDelay = root:Packages:twoP:Acquire:shutterDelay
	NVAR taskNum =  root:packages:twoP:Acquire:shutterTaskNum
	DAQmx_DIO_Config /DEV=imBoard/Dir=1/LGRP=1  "/" + imBoard + "/port0/line0"
	tempStr = fDAQmx_ErrorString ()
	if (cmpStr (tempStr, "") != 0)
		doalert 0, "Digital configuration for shutter task failed" 
		print tempStr
	else
		taskNum = V_DAQmx_DIO_TaskNumber
		if (fDAQmx_DIO_Write(imBoard, V_DAQmx_DIO_TaskNumber, (!shutterOPenLevel)))
			doalert 0, "Digital Out for shutter task failed" 
			print fdaqmx_errorString()
		endif
	endif
	// ephys board
	SVAR ePhysBoard = root:packages:twoP:acquire:ePhysBoard
	if ((cmpStr (ePhysBoard, "None") != 0) && (WhichListItem(ePhysBoard, fdaQmx_DeviceNames(), ";") == -1))
		sprintf tempStr, "The specified ePhys board, \"%s\", is not present in the system.\r", ePhysBoard
		Doalert 0,tempStr
	else
		fDAQmx_ResetDevice(ePhysBoard)
		DAQmx_DeviceInfo /DEV=ePhysBoard
		SVAR BoardClass = root:packages:twoP:acquire:ePhysBoardClass
		BoardClass = S_NIDeviceCategory
		SVAR boardGains = root:packages:twoP:acquire:ePhysGains
		strswitch (boardClass)
			case "E Series DAQ":
				boardGains = "0.05;0.5;5;10"
				break
			case "S Series DAQ":
				boardGains = "0.2;0.5;1;2;5;10"
				break
			case "X Series DAQ":
				boardGains = "1;2;5;10"
				break
			default:
				boardGains = "10"
				break
		endswitch
	endif
	NVAR polarity =  root:packages:twoP:acquire:Trig1Polarity
	NVAR duration = root:packages:twoP:acquire:Trig1Duration
	DAQmx_CTR_OutputPulse /DEV=ePhysBoard /SEC={duration, duration} /IDLE =(!polarity) /NPLS=1 /KEEP=1 /STRT=1/TRIG="/" + imBoard + "/ao/StartTrigger" 0
	tempStr = fDAQmx_ErrorString ()
	if (cmpStr (tempStr, "") != 0)
		DoAlert 0, "COnfiguration for trigger 1 pulse failed"
		print tempStr
	endif
	NVAR polarity =  root:packages:twoP:acquire:Trig2Polarity
	NVAR duration = root:packages:twoP:acquire:Trig2Duration
	DAQmx_CTR_OutputPulse /DEV=ePhysBoard /SEC={duration, duration} /IDLE =(!polarity) /NPLS=1 /KEEP=1 /STRT=1/TRIG="/" + imBoard + "/ao/StartTrigger" 1
	tempStr = fDAQmx_ErrorString ()
	if (cmpStr (tempStr, "") != 0)
		DoAlert 0, "COnfiguration for trigger 1 pulse failed"
		print tempStr
	endif
end


// **************************************************************************************************************
// Saves twoP preferences to a preferences file in twoPhoton folder
// Last Modified 2025/07/09 by Jamie Boyd
Function twoP_PrefsSave(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			twoP_PrefsMakePath ()
			// make and fill a prefs struct
			Struct TwoPPrefsStruct thePrefs
			// version of prefs struct
			thePrefs.version = kTwoPPrefsVers
			//imaging stuff
			SVAR imageBoard = root:packages:twoP:acquire:ImageBoard
			thePrefs.imBoardName =imageBoard
			// image full scale
			NVAR XfullScale = root:packages:twoP:acquire:pixWidthFS
			NVAR YfullScale=  root:packages:twoP:acquire:pixHeightFS
			thePrefs.pixFullScale[0]=XfullScale
			thePrefs.pixFullScale[1]=YfullScale
			NVAR XStart = root:packages:twoP:acquire:xStartVoltsFS
			NVAR XEnd = root:packages:twoP:acquire:xEndVoltsFS
			NVAR YStart = root:packages:twoP:acquire:yStartVoltsFS
			NVAR YEnd = root:packages:twoP:acquire:yEndVoltsFS
			thePrefs.voltsFullScale [0]=XStart
			thePrefs.voltsFullScale [1]=XEnd
			thePrefs.voltsFullScale [2]=YStart
			thePrefs.voltsFullScale [3]=YEnd
			// Timing
			NVAR pixTime = root:packages:twoP:acquire:pixTime
			thePrefs.pixTime = pixTime
			NVAR dutyCycle=root:packages:twoP:acquire:dutyCycle
			thePrefs.dutyCycle=dutyCycle
			NVAR flybackProp =  root:packages:twoP:acquire:flybackProp
			thePrefs.flybackProp = flybackProp
			NVAR scanHeadDelay = root:packages:twoP:acquire:scanHeadDelay
			thePrefs.scanHeadDelay = scanHeadDelay
			NVAR minLiveFrameTime =  root:packages:twoP:acquire:minLiveFrameTime
			thePrefs.minLiveFrameTime = minLiveFrameTime
			// image channels
			WAVE/T imChanList = root:packages:twoP:acquire:imChanList
			variable iChan,  numChans = dimsize (imChanList, 0)
			thePrefs.numImChans = numChans
			for (iChan=0;ichan< numChans;iChan += 1)
				thePrefs.imageChans[iChan].chanName = imChanList[iChan] [1]
				thePrefs.imageChans[iChan].aToDtype = imChanList[iChan] [2]
				thePrefs.imageChans[iChan].inputScaling = str2Num (imChanList[iChan] [3])
				thePrefs.imageChans[iChan].scaling =  str2num (imChanList [iChan] [4])
				thePrefs.imageChans[iChan].offset =  str2num (imChanList [iChan] [5])
			endfor
			//Objective scaling
			wave/t objWave = root:packages:twoP:acquire:objWave
			variable iObj,  numObjs=dimsize (objwave, 0)
			thePrefs.numObjs = numObjs
			for (iObj =0; iObj < numObjs; iObj +=1)
				thePrefs.objList[iObj].objName = objWave [iObj] [0]
				thePrefs.objList[iObj].xScal = str2num (objWave [iObj] [1])
				thePrefs.objList[iObj].yScal = str2num (objWave [iObj] [2])
				thePrefs.objList[iObj].xOffset = str2num (objWave [iObj] [3])
				thePrefs.objList[iObj].yOffset = str2num (objWave [iObj] [4])
			endfor
			//Stage
			SVAR stageProc =  root:packages:twoP:acquire:StageProc
			thePrefs.stageProc = stageProc
			SVAR stagePort = root:packages:twoP:acquire:StagePort
			thePrefs.stagePort = stagePort
			// shutter
			NVAR shutterOpenLevel = root:Packages:twoP:Acquire:shutterOpenLevel
			thePrefs.shutterOpenLevel = shutterOpenLevel
			NVAR shutterDelay = root:Packages:twoP:Acquire:shutterDelay
			thePrefs.shutterDelay = shutterDelay
			// ePhys
			SVAR ephysBoardName = root:Packages:twoP:Acquire:ePhysBoard
			thePrefs.ephysBoardName = ephysBoardName
			NVAR ePhysSampFreq = root:Packages:twoP:Acquire:ePhysSampFreq
			thePrefs.ePhysSampFreq = ePhysSampFreq
			//ePhys channels
			WAVE/T ephysChans = root:packages:twoP:acquire:ePhysChanList
			numChans = dimSize(ephysChans, 0)
			thePrefs.numEphysChans = numChans
			for(iChan =0; iChan < numChans; iChan +=1)
				thePrefs.ePhysChans[iChan].chanName = ephysChans [iChan] [1]
				thePrefs.ePhysChans[iChan].aToDtype = ephysChans [iChan] [2]
				thePrefs.ePhysChans[iChan].inputScaling = str2num(ephysChans [iChan] [3])
				thePrefs.ePhysChans[iChan].scaling = str2num(ephysChans [iChan] [4])
				thePrefs.ePhysChans[iChan].offset = str2num(ephysChans [iChan] [5])
			endfor
			// Triggers
			thePrefs.numTriggers = 2
			NVAR trigPolarity = root:packages:twoP:acquire:Trig1Polarity
			NVAR TrigDuration = root:packages:twoP:acquire:Trig1Duration
			thePrefs.triggers[0].ctrNum =0
			thePrefs.triggers[0].ctrNum.polarity = trigPolarity
			thePrefs.triggers[0].duration =TrigDuration
			NVAR trigPolarity = root:packages:twoP:acquire:Trig2Polarity
			NVAR TrigDuration = root:packages:twoP:acquire:Trig2Duration
			thePrefs.triggers[1].ctrNum =1
			thePrefs.triggers[1].ctrNum.polarity = trigPolarity
			thePrefs.triggers[1].duration =TrigDuration
			// save prefs file
			SVAR newPrefsName = root:packages:twoP:acquire:newPrefsName
			// check for overwriting
			if (CmpStr (GUIPListFiles ("twoPPrefsPath", ".bin", "twoPPrefs_" + newPrefsName + ".bin", 0, ""), "") !=0)
				string prefsName = newPrefsName
				variable overWrite
				Prompt overWrite, "Overwrite Old File?" , popup, "Overwrite;Use New Name"
				Prompt prefsName, "New Name:"
				do
					doPrompt prefsName + " Already Exists", overwrite, prefsName
					if (V_Flag ==1)
						return 1
					endif
				while  ((overwrite != 1) && (CmpStr (GUIPListFiles ("twoPPrefsPath", ".bin", "twoPPrefs_" + prefsName + ".bin", 0, ""), "") !=0))
				newPrefsName = prefsName
			endif
			SavePackagePreferences /P=twoPPrefsPath  /FLSH =1 "twoPhoton", "twoPPrefs_" + newPrefsName + ".bin", 0 , thePrefs
			if (V_Flag)
				doalert 0, "Preferences save errror: " + num2str (V_Flag)
			endif
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End


//******************************************************************************************************
//Makescontrol panel for settings and preferences
// last modified 2025/07/09 by Jamie Boyd
Function twoP_PrefsMakePanel()
	// make sure path exists
	twoP_PrefsMakePath ()
	// make sure folder exists
	if (!(DataFolderExists ("root:packages:twoP:acquire")))
		twoP_PrefsMakeGlobals ()
	endif
	DoWindow/F Scan_Settings_Prefs
	if (V_flag)
		return 0
	endif
	NewPanel /K=1/W=(376,54,692,603) as "Scan Settings and Preferences"
	DoWindow/C Scan_Settings_Prefs
	// Load Prefs
	PopupMenu LoadPrefsPopUp,pos={4.00,4.00},size={112.00,19.00},proc=twoP_PrefsLoadPopmenuProc
	PopupMenu LoadPrefsPopUp,title="Load Preferences"
	PopupMenu LoadPrefsPopUp,help={"Loads a preference file from desk"}
	PopupMenu LoadPrefsPopUp,mode=0,value=#"GUIPListFiles(\"twoPprefsPath\",\".bin\",\"twoPPrefs_*\"+\".bin\",5,\"\")"
	SetVariable LoadedPrefsName,pos={118.00,6.00},size={120.00,18.00},title=" "
	SetVariable LoadedPrefsName,frame=0, noedit=1
	SetVariable LoadedPrefsName,value=root:Packages:twoP:Acquire:loadedPrefsName
	// Save Prefs
	Button SavePrefsButton,pos={12.00,522.00},size={65.00,20.00},proc=twoP_PrefsSave
	Button SavePrefsButton,title="Save Prefs"
	SetVariable savePrefsName,pos={80.00,523.00},size={113.00,18.00},title=" "
	SetVariable savePrefsName,value=root:Packages:twoP:Acquire:newPrefsName
	// Check Prefs
	Button CheckPrefsButton,pos={230.00,522.00},size={77.00,20.00},proc=twoP_PrefsCheckButtonProc
	Button CheckPrefsButton,title="Check Prefs"
	// Tab control
	GUIPTabNewTabCtrl ("Scan_Settings_Prefs", "PrefsTabCtrl", tabList="Image_Scaling;ePhys_Trigs;")
	TabControl PrefsTabCtrl,pos={1.00,25.00},size={314.00,494.00},proc=GUIPTabProc
	TabControl PrefsTabCtrl,tabLabel(0)="Image_Scaling"
	TabControl PrefsTabCtrl,tabLabel(1)="Stage_Shutter_ePhys_Trigs",value=0
	// Imaging Tab
	// Image Board
	PopupMenu ImageBoardPopMenu,pos={6.00,60.00},size={93.00,19.00},proc=twoP_PrefsSetBoardName
	PopupMenu ImageBoardPopMenu,title="Image Device"
	PopupMenu ImageBoardPopMenu,mode=0,value=#"twoP_PrefsListBoards()"
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "PopupMenu ImageBoardPopMenu 0;")
	TitleBox ImageBoardTitle,pos={107.00,64.00},size={42.00,15.00},frame=0
	TitleBox ImageBoardTitle,variable=root:Packages:twoP:Acquire:imageBoard
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "TitleBox ImageBoardTitle 0;")
	// Image Scan full scale
	GroupBox FullScaleGrp,pos={6.00,89.00},size={305.00,66.00}
	GroupBox FullScaleGrp,title="Scan Full Scale"
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "GroupBox FullScaleGrp 0;")
	SetVariable PixWidSetVar,pos={10.00,108.00},size={85.00,15.00},title="X pix"
	SetVariable PixWidSetVar,fSize=10
	SetVariable PixWidSetVar,limits={2,inf,0},value=root:Packages:twoP:Acquire:pixWidthFS
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "SetVariable PixWidSetVar 0;")
	SetVariable XStartSetVar,pos={101.00,108.00},size={95.00,15.00},proc=GUIPSIsetVarProc
	SetVariable XStartSetVar,title="X Start"
	SetVariable XStartSetVar,userdata="ValMin:-10;ValMax:10;AutoIncr:TRUE;MinIncr:1e-3"
	SetVariable XStartSetVar,fSize=10,format="%.3W1PV"
	SetVariable XStartSetVar,limits={-inf,inf,0.1},value=root:Packages:twoP:Acquire:xStartVoltsFS
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "SetVariable XStartSetVar 0;")
	SetVariable XEndSetVar,pos={205.00,108.00},size={95.00,15.00},title="X End"
	SetVariable XEndSetVar,userdata="ValMin:-10;ValMax:10;AutoIncr:TRUE;MinIncr:1e-3"
	SetVariable XEndSetVar,fSize=10,format="%.3W1PV"
	SetVariable XEndSetVar,limits={-inf,inf,0.1},value=root:Packages:twoP:Acquire:xEndVoltsFS
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "SetVariable XEndSetVar 0;")
	SetVariable PixHeightSetVar,pos={10.00,127.00},size={85.00,15.00}
	SetVariable PixHeightSetVar,title="Y Pix",fSize=10
	SetVariable PixHeightSetVar,limits={2,inf,0},value=root:Packages:twoP:Acquire:pixHeightFS
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "SetVariable PixHeightSetVar 0;")
	SetVariable YStartSetVar,pos={101.00,127.00},size={95.00,15.00},proc=GUIPSIsetVarProc
	SetVariable YStartSetVar,title="Y Start"
	SetVariable YStartSetVar,userdata="ValMin:-10;ValMax:10;AutoIncr:TRUE;MinIncr:1e-3"
	SetVariable YStartSetVar,fSize=10,format="%.3W1PV"
	SetVariable YStartSetVar,limits={-inf,inf,0.1},value=root:Packages:twoP:Acquire:yStartVoltsFS
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "SetVariable YStartSetVar 0;")
	SetVariable YEndSetVar,pos={205.00,127.00},size={95.00,15.00},proc=GUIPSIsetVarProc
	SetVariable YEndSetVar,title="Y End"
	SetVariable YEndSetVar,userdata="ValMin:-10;ValMax:10;AutoIncr:TRUE;MinIncr:1e-3"
	SetVariable YEndSetVar,fSize=10,format="%.3W1PV"
	SetVariable YEndSetVar,limits={-inf,inf,0.1},value=root:Packages:twoP:Acquire:yEndVoltsFS
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "SetVariable YEndSetVar 0;")
	// Objectives
	GroupBox ObjectivesGroup,pos={6.00,157.00},size={305.00,116.00}
	GroupBox ObjectivesGroup,title="Objective Scaling"
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "GroupBox ObjectivesGroup 0;")
	ListBox ObjectivesList,pos={10.00,175.00},size={295.00,68.00}
	ListBox ObjectivesList,help={"Scaling is in m/V, offset is in m"}
	ListBox ObjectivesList,listWave=root:Packages:twoP:Acquire:ObjWave
	ListBox ObjectivesList,selWave=root:Packages:twoP:Acquire:ObjSelWave,mode=2
	ListBox ObjectivesList,selRow=0,widths={61,49,57,55,55},userColumnResize=1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "ListBox ObjectivesList 0;")
	Button AddObjButton,pos={32.00,246.00},size={57.00,20.00},proc=twoP_prefsAddObjProc
	Button AddObjButton,title="Add Obj"
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "Button AddObjButton 0;")
	Button DelObjButton,pos={159.00,246.00},size={66.00,20.00},proc=twoP_prefsDelObjProc
	Button DelObjButton,title="Delete Obj"
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "Button DelObjButton 0;")
	// Image Scan Timing
	GroupBox ImageScanGroupBox,pos={6.00,284.00},size={305.00,114.00}
	GroupBox ImageScanGroupBox,title="ImageScan Timing"
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "GroupBox ImageScanGroupBox 0;")
	SetVariable PixTimeSetVar,pos={11.00,302.00},size={180.00,18.00},proc=GUIPSIsetVarProc
	SetVariable PixTimeSetVar,title="Pixel Scan Time"
	SetVariable PixTimeSetVar,help={"Sets the clock rate that determines the time for each pixel"}
	SetVariable PixTimeSetVar,userdata="ValMin:0.4E-6;ValMax:1E-3;AutoIncr:TRUE;MinIncr:1e-7;addFuncStr:NQ_SetTimesProc;"
	SetVariable PixTimeSetVar,format="%.3W1PSec"
	SetVariable PixTimeSetVar,limits={-inf,inf,1e-07},value=root:Packages:twoP:Acquire:PixTime
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "SetVariable PixTimeSetVar 0;")
	SetVariable DutyCycleSetVar,pos={200.00,302.00},size={104.00,18.00}
	SetVariable DutyCycleSetVar,help={"Sets the proportion of the galvo X-scan that is used to collect data, relative to sum of data collection and flyback time "}
	SetVariable DutyCycleSetVar,userdata="ValMin:0;ValMax:1E-3;AutoIncr:TRUE;addFuncStr:NQ_SetTimesProc;"
	SetVariable DutyCycleSetVar,format="%g"
	SetVariable DutyCycleSetVar,limits={0,1,0.05},value=root:Packages:twoP:Acquire:DutyCycle
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "SetVariable DutyCycleSetVar 0;")
	SetVariable FlybackPropSetVar,pos={11.00,324.00},size={219.00,18.00},proc=NQ_SetTimesProc
	SetVariable FlybackPropSetVar,title="Single direction FlyBack Ratio"
	SetVariable FlybackPropSetVar,help={"For single-direction scanning, sets the time used to return to the  X starting voltage, as a proportion of the time used for scanning an image line"}
	SetVariable FlybackPropSetVar,limits={0.25,1,0.05},value=root:Packages:twoP:Acquire:FlybackProp
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "SetVariable FlybackPropSetVar 0;")
	SetVariable RotateSetvar,pos={11.00,345.00},size={219.00,18.00},proc=GUIPSIsetVarProc
	SetVariable RotateSetvar,title="Bi-Directional Scan Delay "
	SetVariable RotateSetvar,help={"Sets the empirically determined period wherby X-Galvo position lags the X-Galvo signal"}
	SetVariable RotateSetvar,userdata="ValMin:0;ValMax:1E-3;AutoIncr:TRUE;addFuncStr:NQ_SetTimesProc;"
	SetVariable RotateSetvar,format="%.2W1PSec"
	SetVariable RotateSetvar,limits={-inf,inf,1e-06},value=root:Packages:twoP:Acquire:ScanHeadDelay
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "SetVariable RotateSetvar 0;")
	SetVariable minLiveFrameTimeSetVar,pos={9.00,370.00},size={215.00,18.00},proc=NQ_SetTimesProc
	SetVariable minLiveFrameTimeSetVar,title="Minimum Live Frame Time"
	SetVariable minLiveFrameTimeSetVar,help={"If frame time is shorter than this, additional frames are collected and averaged "}
	SetVariable minLiveFrameTimeSetVar,format="%.3f Sec"
	SetVariable minLiveFrameTimeSetVar,limits={0.25,1,0.05},value=root:Packages:twoP:Acquire:minLiveFrameTime
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "SetVariable minLiveFrameTimeSetVar 0;")
	// Image Channels
	GroupBox ImageChansGrp,pos={6.00,403.00},size={305.00,112.00}
	GroupBox ImageChansGrp,title="Image Acquisition Channels"
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "GroupBox ImageChansGrp 0;")
	ListBox imChansListBox,pos={10.00,421.00},size={295.00,87.00},proc=twoP_PrefsChanListBoxProc
	ListBox imChansListBox,listWave=root:Packages:twoP:Acquire:imChanList
	ListBox imChansListBox,selWave=root:Packages:twoP:Acquire:imChanSelList,mode=1
	ListBox imChansListBox,selRow=1,widths={80,79,50,88,35,733},userColumnResize=1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "Image_Scaling", "ListBox imChansListBox 0;")
	// Stage Shutter Ephys Trigs tab
	// Stage
	GroupBox StageGroup,pos={6.00,51.00},size={305.00,51.00},title="Stage", disable=1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "GroupBox StageGroup 0;")
	PopupMenu StageProcPopMenu,pos={12.00,72.00},size={54.00,19.00},proc=twoP_PrefsSetStage
	PopupMenu StageProcPopMenu,title="Stage:",mode=0,value=#"StageListEncoders()", disable=1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "PopupMenu StageProcPopMenu 0;")
	TitleBox StageTitle,pos={68.00,74.00},size={41.00,15.00},frame=0
	TitleBox StageTitle,variable=root:Packages:twoP:Acquire:StageProc, disable=1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "TitleBox StageTitle 0;")
	PopupMenu StagePortProcPopMenu,pos={137.00,72.00},size={78.00,19.00},proc=twoP_PrefsSetStagePort
	PopupMenu StagePortProcPopMenu,title="Serial Port:"
	PopupMenu StagePortProcPopMenu,mode=0,value=#"StageListPorts()", disable=1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "PopupMenu StagePortProcPopMenu 0;")
	TitleBox StagePortTitle,pos={219.00,74.00},size={34.00,15.00},frame=0
	TitleBox StagePortTitle,variable=root:Packages:twoP:Acquire:StagePort, disable=1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "TitleBox StagePortTitle 0;")
	// Shutter
	GroupBox ShutterGroup,pos={6.00,108.00},size={305.00,71.00},title="Shutter", disable=1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "GroupBox ShutterGroup 0;")
	NVAR shutterOpenLevel = root:packages:twoP:Acquire:shutterOpenLevel 
	PopupMenu ShutterPolarityPopMenu,pos={10.00,126.00},size={206.00,19.00},proc=twoP_PrefsSetShutterPolarity
	PopupMenu ShutterPolarityPopMenu,title="Shutter Opens when Output is"
	PopupMenu ShutterPolarityPopMenu,value=#"\"Low;High\"", mode = (shutterOpenLevel +1),popvalue=selectString (shutterOpenLevel, "Low", "High"), disable=1	
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "PopupMenu ShutterPolarityPopMenu 0;")
	SetVariable shutterDelaySetVar,pos={12.00,149.00},size={176.00,18.00},proc=GUIPSIsetVarProc
	SetVariable shutterDelaySetVar,title="Shutter Delay Time"
	SetVariable shutterDelaySetVar,userdata="addFuncStr:;ValMin:1e-06;ValMax:0.01;AutoIncr:1;MinIncr:0.0001;"
	SetVariable shutterDelaySetVar,format="%.2W1Ps"
	SetVariable shutterDelaySetVar,limits={-inf,inf,0.0001},value=root:Packages:twoP:Acquire:shutterDelay, disable=1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "SetVariable shutterDelaySetVar 0;")
	// ephys device
	PopupMenu ePhysBoardPopMenu,pos={12.00,187.00},size={91.00,19.00},proc=twoP_PrefsSetBoardName
	PopupMenu ePhysBoardPopMenu,title="ePhys Device"
	PopupMenu ePhysBoardPopMenu,mode=0,value=#"twoP_PrefsListBoards()", disable =1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "PopupMenu ePhysBoardPopMenu 0;")
	TitleBox ePhysBoardTitle,pos={109.00,189.00},size={42.00,15.00},frame=0
	TitleBox ePhysBoardTitle,variable=root:Packages:twoP:Acquire:ePhysBoard, disable=1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "TitleBox ePhysBoardTitle 0;")
	SetVariable ephysFreqSetvar,pos={12.00,210.00},size={196.00,18.00},proc=GUIPSIsetVarProc
	SetVariable ephysFreqSetvar,title="Sampling Frequency"
	SetVariable ephysFreqSetvar,userdata="addFuncStr:;ValMin:100;ValMax:200000;AutoIncr:1;MinIncr:1;"
	SetVariable ephysFreqSetvar,format="%.0W1PHz"
	SetVariable ephysFreqSetvar,limits={-inf,inf,10},value=root:Packages:twoP:Acquire:ePhysSampFreq, disable=1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "SetVariable ephysFreqSetvar 0;")
	// ephys channels
	GroupBox ePhysGroup,pos={6.00,235.00},size={305.00,137.00}
	GroupBox ePhysGroup,title="ePhys Channels", disable=1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "GroupBox ePhysGroup 0;")
	ListBox ephysChansListBox,pos={9.00,256.00},size={293.00,109.00},proc=twoP_PrefsChanListBoxProc
	ListBox ephysChansListBox,listWave=root:Packages:twoP:Acquire:ePhysChanList
	ListBox ephysChansListBox,selWave=root:Packages:twoP:Acquire:ePhysChanSelList
	ListBox ephysChansListBox,mode=1,selRow=1,widths={80,79,50,88,35,733}
	ListBox ephysChansListBox,userColumnResize=1, disable = 1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "ListBox ephysChansListBox 0;")
	// Triggers
	GroupBox TriggersGroup,pos={6.00,380.00},size={305.00,87.00}
	GroupBox TriggersGroup,title="Trigger Pulses (on ePhys Board)", disable=1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "GroupBox TriggersGroup 0;")
	TitleBox TriggerTitle,pos={14.00,397.00},size={257.00,15.00}
	TitleBox TriggerTitle,title="Trigger Num             Polarity                      Duration"
	TitleBox TriggerTitle,frame=0, disable=1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "TitleBox TriggerTitle 0;")
	NVAR Trig1Polarity = root:packages:twoP:acquire:Trig1Polarity
	PopupMenu Trigger1PolarityPopMenu,pos={42.00,413.00},size={142.00,19.00},proc=twoP_PrefsSetTrigPolarity
	PopupMenu Trigger1PolarityPopMenu,title="1              "
	PopupMenu Trigger1PolarityPopMenu,mode=(trig1Polarity + 1),popvalue=selectString (Trig1Polarity, "Low-to-High","High-to-Low")
	PopupMenu Trigger1PolarityPopMenu,value=#"\"Low-to-High;High to Low\"", disable=1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "PopupMenu Trigger1PolarityPopMenu 0;")
	SetVariable Trig1DurationSetVar,pos={202.00,413.00},size={103.00,18.00},proc=GUIPSIsetVarProc
	SetVariable Trig1DurationSetVar,title=" "
	SetVariable Trig1DurationSetVar,userdata=";1e-6;1;autoInc;0;addFuncStr:;ValMin:1e-07;ValMax:0.1;AutoIncr:1;MinIncr:1e-07;"
	SetVariable Trig1DurationSetVar,format="%.2W1Ps"
	SetVariable Trig1DurationSetVar,limits={-inf,inf,0.0001},value=root:Packages:twoP:Acquire:Trig1Duration, disable=1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "SetVariable Trig1DurationSetVar 0;")
	NVAR trig2Polarity = root:packages:twoP:acquire:Trig2Polarity
	PopupMenu Trigger2PolarityPopMenu,pos={42.00,438.00},size={142.00,19.00},proc=twoP_PrefsSetTrigPolarity
	PopupMenu Trigger2PolarityPopMenu,title="2              "
	PopupMenu Trigger2PolarityPopMenu, mode=(trig2Polarity + 1),popvalue=selectString (Trig2Polarity, "Low-to-High","High-to-Low")
	PopupMenu Trigger2PolarityPopMenu,value=#"\"Low-to-High;High to Low\"", disable=1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "PopupMenu Trigger2PolarityPopMenu 0;")
	SetVariable Trig2DurationSetVar,pos={202.00,439.00},size={103.00,18.00},proc=GUIPSIsetVarProc
	SetVariable Trig2DurationSetVar,title=" "
	SetVariable Trig2DurationSetVar,userdata=";1e-6;1;autoInc;0;addFuncStr:;ValMin:1e-07;ValMax:0.1;AutoIncr:1;MinIncr:1e-07;"
	SetVariable Trig2DurationSetVar,format="%.2W1Ps"
	SetVariable Trig2DurationSetVar,limits={-inf,inf,0.0001},value=root:Packages:twoP:Acquire:Trig2Duration, disable=1
	GUIPTabAddCtrls ("Scan_Settings_Prefs", "PrefsTabCtrl",  "ePhys_Trigs", "SetVariable Trig2DurationSetVar 0;")
end


