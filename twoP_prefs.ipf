#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later


constant kTwoPPrefsVers = 101 // Preferences structure version number. 100 means 1.00.


Structure TwoPPrefsStruct
	uint32 version							// Preferences structure version number. 100 means 1.00.
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
	uChar aiChan			// input channel, from 0 to max number of channels (15)
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
// Last Modified 2015/04/24 by Jamie Boyd
Structure twoPTrigStruct
	char trigName [32]	// name of trigger, for user's convenience
	char boardName [32]	// name of NI board generating this trigger
	uChar ctrNum		// number of counter, from 0 to max number of counters (2-4)
	char outPutPin [32]	// name of output pin, /ctr0Out, or PFI12, e.g.
	char startSignal [128] // signal that starts the counter
	uchar polarity		// 0 for low-to-high, 1 for high-to-low
	float duration			// duration in seconds
EndStructure




function/s twoP_PrefsListBoards()
	
	string aBoard, boards=fDAQmx_DeviceNames()
	variable iBoard, nBoards = itemsinList(boards, ";")
	string outStr = ""
	for (iBoard=0;iBoard < nBoards;iBoard +=1)
		aBoard = stringFromList (iBoard, boards,";")
		DAQmx_DeviceInfo /DEV=aBoard
		outStr += aBoard + ": " + S_NIProductType + ": " + S_NIDeviceCategory + ";"
	endfor
	outStr += ";None"
	return outStr
end


Function twoP_PrefsSetBoardName (pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			if (cmpStr (pa.ctrlName, "ImageBoardPopMenu") ==0)
				SVAR boardNameG = root:packages:twoP:acquire:imageBoard
				SVAR boardClassG =  root:packages:twoP:acquire:imageBoardClass
				SVAR gainsG = root:packages:twoP:acquire:imageGains
				NVAR numChansG = root:packages:twoP:acquire:numImageChans
				WAVE/t chanList = root:packages:twoP:Acquire:imChanList
				WAVE chanSelList =  root:packages:twoP:Acquire:imChanSelList
			elseif (cmpStr (pa.CtrlName, "ePhysBoardPopMenu") ==0)
				SVAR boardNameG =  root:packages:twoP:acquire:ePhysBoard
				SVAR boardClassG =  root:packages:twoP:acquire:ePhysBoardClass
				SVAR gainsG = root:packages:twoP:acquire:ePhysGains
				NVAR numChansG = root:packages:twoP:acquire:numEphysChans
				WAVE/t chanList = root:packages:twoP:Acquire:ePhysChanList
				WAVE chanSelList =  root:packages:twoP:Acquire:ePhysChansSelList
			endif
			numChansG = fdaqmx_NumAnalogInputs(boardNameG)
			boardNameG = stringfromlist (0, pa.popStr, ":")
			boardClassG = trimString (stringfromlist (2, pa.popStr, ":"))
			if (cmpStr (boardNameG, "None") != 0)
				strswitch (boardClassG)
					case "E Series DAQ":
						gainsG = "±0.05;±0.5;±5;±10"
						numChansG /=2 	// assume differential signals with E-series
						break
					case "S Series DAQ":
						gainsG = "±0.2;±0.5;±1;±2;±5;±10"
						break
					case "X Series DAQ":
						gainsG = "±1;±2;±5;±10"
						break
					default:
						gainsG = "±10"
						break
				endswitch
			endif
			// readjustchannel list for number of channels on the board
			redimension/n=(numChansG, -1) chanList, chanSelList
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
GroupBox ImageChansGrp,pos={6.00,403.00},size={305.00,112.00}
	GroupBox ImageChansGrp,title="Image Acquisition Channels"
	
	
	ListBox imChansListBox,pos={10.00,421.00},size={295.00,87.00},proc=twoP_prefsChanListBoxProc
	ListBox imChansListBox,listWave=root:Packages:ChR:ChanListWave
	ListBox imChansListBox,selWave=root:Packages:ChR:ChanListSelWave,mode=1
	ListBox imChansListBox,selRow=1,widths={48,80,50,50,66},userColumnResize=1


function imchantest()


		NVAR nChans =root:packages:twoP:acquire:numImageChans
		make/t/o/n = (nChans, 6)  root:packages:twoP:Acquire:imChanList
		make/o/n = (nChans, 6)  root:packages:twoP:Acquire:imChanSelList
		WAVE/t chanList = root:packages:twoP:Acquire:imChanList
		WAVE chanSelList =  root:packages:twoP:Acquire:imChanSelList
		SetDimlabel 1,0, ai_chan chanList
		SetDimlabel 1,1, chanName chanList
		SetDimlabel 1,2, Type chanList
		SetDimlabel 1,3, Gain chanList
		SetDimlabel 1,4, scal chanList
		SetDimlabel 1,5, offset chanList
		chanSelList [*] [0] = 32 // check box for channel number is active
		chanSelList [*] [1] = 2	 // channel name, editable
		chanSelList [*] [2] = 0 // not editable -have to use popMenu for PDIFF,RSE, etc.
		chanSelList [*] [3] = 0 // not editable -have to use popMenu for gains 
		chanSelList [*] [4,5] = 0 // scaling and offset not used for images
		chanList [*] [0] = num2str(p) // ao channel numbers
		chanList [*] [4] = num2str (1) // scaling = 1
		chanList [*] [5] = num2str (0) // offset = 0
	end
