#pragma rtGlobals=3
#pragma IgorVersion = 6.2
#pragma version = 2.1 // Last modified 2025/07/02 by Jamie Boyd

// This procedure file hold constants/includes that are acquisition settings
// unique to each twoP setup, plus ways to save settings in and load them from a preferences file

//*********************************************************************************************************************************
//**************************************************** Constants***************************************************************
// The following constants will be loaded into global variables if a preferences file is not found and loaded.
// The constants are designed to be modifable by the user. Or you could just save a preferences file......
// Names of NI boards, as set by NI MAX utility
strconstant kNQimageBoard ="PCI6110"
strconstant kNQephysBoard ="PCIe6321"
// Constants for focus connection
strconstant kNQStageProc = "Null"//"MS2000"
strconstant kNQFocusPort = "COM3"
// Constant for shutter direction 1 means shutter is open TTL line is high. \
// 0 means shutter is open when TTL line is low
// Note that  the digital lines will be set high when the computer is turned on
constant kNQshutterOpen = 0
constant kNQshutterDelay = 5e-03
// constants for pixel full size
constant kNQvPix = 500
constant kNQhPix = 500  
// constants for voltage full size, and for inverting scan
constant kNQxVoltStart = -7.5
constant kNQxVoltEnd= 7.5
constant kNQyVoltStart = -7.5
constant kNQyVoltEnd= 7.5
constant kNQxInvert =0
constant kNQyInvert =0
// constants for image scaling; if no objective wave was loaded from a prefs file, these values will be loaded
// into first line of objective wave. Format is:  Objective name, X scaling (metres/volt), Y scaling (metres/Volt), x offset (metres), y Offset (metres)
strconstant kNQObjScal =  "60x;1.2e-05;1.2e-05;0;0;"
// string constant for default image channel - channel name, ai chan#, A/D type, min V, max V, scaling, offset
strconstant kNQImChan =  "ch1;0;PDIFF;-5;5;20;2046;"
// constants for default values for other scan settings - duty cycle, pixel time, scan head delay, Scan and ePhys gains
constant kNQDutyCycle = 0.8 // proportion of horizontal scan that is held linear and over which data is collected
constant kNQpixTime = 1e-06 // time between each galvo position/pixel acquisition
constant kNQflybackProp = 0.5 // when not using bi-derectional scanning, time spent in flyback, as a proportion of the time spent in data collection 
constant kNQscanHeadDelay = 87.5e-6 // delay in seconds between requesting a value in D/A converter, and getting that position on the scanhead. Needed for bi-directional scanning
// Constant for minimum frame time (seconds) for some scanning modes (live and Z)  scanning, to prevent updating errors.
// Extra frames are added to meet minimum time and averaged
constant kNQminLiveFrameTime = 0.3
constant kNQscanGain = 10 // gain on the A/D amplifier for images
constant kNQePhysGain = 1 // gain on ePhys A/D amplifier
constant kNQePhysSampFreq = 5e03 // ePhys sampling frequency
// string constant for default image channel
strconstant kNQePhysChan =  "ch1;0;Diff;-5;5;"
// String constant for default trigger
strconstant kNQtrigStr = "trig1;PCI6036;1;/ctr1out;/PCI6036/wfStart;0;0.1"
constant kNQePhysScalerCh1 = 0.050 // ephys waves for channel 1 will be multiplied by this value after scanning
constant kNQePhysScalerCh2 = 0.050 // ephys waves for channel 2 will be multiplied by this value after scanning
// Constant for trigger outPutPulse width, in seconds
constant kNQtrigWidth = 1e-3 // 1 mSec
// Constants for which pin trigger appears on, will be /ctr0out or /ctr1out for old style boards and /PFI12 or /PFI13 for newer boards
strconstant kNQtrig1Pin = "/ctr0out"
strconstant kNQtrig2Pin = "/ctr1out"

// size of a buffer when acquiring into a buffer for extended number of time series frames
constant kNQtBufferTime = 2
//Trigger Polarity, 0 means low to high, 1 means high to low
constant kNQTrig1Pol =0
constant kNQTrig2Pol =0
// Number of image channels that can be recorded
constant kNQMaxChans = 4

// *********************************************************************************************************************************
//*******************************************Structures for saving/loading preferences*****************************************
constant kTwoPPrefsVers = 100 // Preferences structure version number. 100 means 1.00.

// *********************************************************************************************************************************
// Global preferences. For now, the name of the last preferences file used. Other things?
// last Modified 2015/04/22 by Jamie Boyd
Structure twoPglobalPrefsStruct
	uint32 version
	char lastPrefs [64]
EndStructure

// *********************************************************************************************************************************
// Main Preferences. Includes settings for image scans, ePhys, triggers, and voltage output 
Structure TwoPPrefsStruct
	uint32 version		// Preferences structure version number. 100 means 1.00.
	// image stuff
	char imageBoard [32] // name of imaging board
	// defining default image
	float xVoltStart
	float yVoltStart
	float xVoltEnd
	float yVoltEnd
	uint32 hPix
	uint32 vPix
	uchar xInvert
	uChar yInvert
	// Scan Timing values
	float pixTime
	float flybackProp
	float dutyCycle
	float scanDelay
	float minLiveFrameTime
	// Objectives
	uchar nObjs	// number of ojectives
	struct twoPObjStruct objList [16] 
	// Image scan channels
	uchar nImageChans
	struct twoPChanStruct imageChans [4]  // 4 should be enough for anybody (?)
	// shutter
	uchar shutterOpen		// 0 means shutter is open when TTL line is low
	float shutterDelay		// delay in seconds from when shutter opens to when scan starts
	// stage
	char stageProc[32]	// name of stage encoder procedure, MS200, e.g.
	char stagePort[32]	// serial port to use with the stage encoder, COM1, e.g.,
	
	// ePhys stuff
	char ePhysBoard [32]	 // name of the DAQ board used, as configured with MAX
	float ePhysSampFreq
	uchar nEphysChans
	struct twoPChanStruct ePhysChans [16]
	uchar nTriggers
	struct twoPTrigStruct triggers [16]
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
// each analog input channel is represented by this structure
// Last Modified 2015/04/28 by Jamie Boyd
Structure twoPChanStruct
	char chanName [32]	// name of channel, for wave naming purposes
	uChar aiChan			// input channel, from 0 to max number of channels (15)
	char aToDtype[8]		// Analog input mode for the channel, can be Diff, PDIF, RSE, or NRSE 
						// (differential, pseudodifferential, referenced single-ended, or non-referenced single-ended)
						// Differential is typical, USB devices may need referenced single-ended, S-series devices (like pci-6110) may require pseudo-differential
	float vMin			// minimum expected value,used for scaling and for pre-digitizing amplification
	float vMax			// maximum expected value, used for scaling and for pre-digitizing amplification
	float scaling				// scaling applied AFTER A/D conversion, use to fill 16 bit int wave range, or for floating point, wave, make scaling nice
	float offset			// offset applied AFTER A/D conversion, used to fit data into unsigned waves, e.g.
EndStructure

// **************************************************************************************************************
// each output trigger is represented by this structure
// lots of flexibility for which device is used, and for configuring the trigger
// Last Modified 2015/04/24 by Jamie Boyd
Structure twoPTrigStruct
	char trigName [32]	// name of trigger, for user's convenience
	char boardName [32]	// name of NI board generating this trigger
	uChar ctrNum		// number of counter, from 0 to max number of counters (2-4)
	char outPutPin [32]	// name of output pin, /ctr0Out, or PFI12, e.g.
	char startSignal [128] // signal tha starts the counter
	uchar polarity		// 0 for low-to-high, 1 for high-to-low
	float duration			// duration in seconds
EndStructure


Structure twoPVoutStruct
	char vOutName [32]	// name of trigger, for wave naming purposes
	char boardName [32]	// name of NI board generating this vOut
	uchar chan			// number of channel , typically 0 or 1
EndStructure

Function NQ_OtherScanSettingsProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
		Dowindow/F Other_Scan_Settings
		if (V_Flag ==1)
			return 1
		endif
		NewPanel /K=1/W=(5,57,323,606) as "Other Scan Settings"
		DoWindow/C Other_Scan_Settings
		// Load and save prefs
		PopupMenu LoadPrefsPopUp win =Other_Scan_Settings,pos={4,3},size={113,21},proc=ChR_PrefsLoadPrefsPopmenuProc,title="Load Preferences"
		PopupMenu LoadPrefsPopUp win =Other_Scan_Settings,mode=0,value= #"GUIPListFiles (\"ChrPrefsPath\", \".bin\", \"*_ChR.bin\", 5, \"\")"
		SetVariable LoadedPrefsName win =Other_Scan_Settings,pos={117,5},size={54,16},title=" ",frame=0
		SetVariable LoadedPrefsName win =Other_Scan_Settings,value= root:Packages:ChR:LoadedPrefsName
		Button SavePrefsButton win =Other_Scan_Settings,pos={176,5},size={65,20},proc=ChR_prefsSavePrefs,title="Save Prefs"
		SetVariable savePrefsName win =Other_Scan_Settings,pos={243,7},size={77,16},title=" "
		SetVariable savePrefsName win =Other_Scan_Settings,value= root:Packages:ChR:newPrefsName
		// Tab control
		TabControl modeTabe win =Other_Scan_Settings, pos={4,25},size={312,521},proc=GUIPTabProc
		TabControl modeTabe win =Other_Scan_Settings ,tabLabel(0)="Image_Scan",tabLabel(1)="ePhys_Trigs",value= 0

		// Image board
			PopupMenu ImageBoardPopMenu,pos={9,49},size={95,21},proc=NQ_PrefsSetBoardName,title="Image Device"
	PopupMenu ImageBoardPopMenu,mode=0,value= #"fDAQmx_DeviceNames()"
	TitleBox ImageBoardTitle,pos={107,53},size={41,13},frame=0
	TitleBox ImageBoardTitle,variable= root:Packages:twoP:Acquire:imageBoard
	// Misc image settings
	SetVariable PixTimeSetVar,pos={169,72},size={141,16},title="Pixel Time"
	SetVariable PixTimeSetVar,format="%.3W1PSec"
	SetVariable PixTimeSetVar,limits={0,0,0},value= root:Packages:twoP:Acquire:PixTIme,noedit= 1
	SetVariable DutyCycleSetVar,pos={46,96},size={112,16},format="%g"
	SetVariable DutyCycleSetVar,limits={0,1,0.05},value= root:Packages:twoP:Acquire:DutyCycle
	SetVariable FlybackPropSetVar,pos={194,95},size={116,16},proc=NQ_SetTimesProc,title="FlyBack Ratio"
	SetVariable FlybackPropSetVar,limits={0.25,1,0.05},value= root:Packages:twoP:Acquire:FlybackProp
	SetVariable RotateSetvar,pos={8,121},size={150,16},proc=GUIPSIsetVarProc,title="Scan Delay "
	SetVariable RotateSetvar,userdata=  ";0;1;;",format="%.2W1PSec"
	SetVariable RotateSetvar,limits={0,inf,2.5e-07},value= root:Packages:twoP:Acquire:ScanHeadDelay
	SetVariable minLiveFrameTimeSetVar,pos={169,120},size={141,16},proc=NQ_SetTimesProc,title="Min Live FrameTime"
	SetVariable minLiveFrameTimeSetVar,limits={0.25,1,0.05},value= root:Packages:twoP:Acquire:FlybackProp



GUIPTabNewTabCtrl ("Other_Scan_Settings", "modeTab", tabList="Image_Scan;ePhys_Trigs;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "Button AddObjectiveButton 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "PopupMenu DelObjPopMenu 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "SetVariable DutyCycleSetVar 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "SetVariable FlybackPropSetVar 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "PopupMenu ImageBoardPopMenu 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "TitleBox ImageBoardTitle 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "TitleBox ImageScalingTitle 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "ListBox imageScanChansListBox 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "TitleBox ImageScanChansTitle 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "Button ImageScansAddChanButton 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "PopupMenu ImageScansDelChanPopMenu 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "ListBox imageSizesListBox 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "ListBox MagSettingsList 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "SetVariable minLiveFrameTimeSetVar 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "TitleBox ObjScalTitle 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "SetVariable PixelWidthSetVar 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "SetVariable PixTimeSetVar 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "SetVariable RotateSetvar 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "SetVariable ShutterDelaySetVar 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "GroupBox ShutterGrp 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "PopupMenu ShutterPopmenu 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "GroupBox StageEncoderGrp 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "PopupMenu StagePopup 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "PopupMenu StagePortPopup 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "TitleBox StagePortTitle 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "Image_Scan", "TitleBox StageTitle 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "ePhys_Trigs", "Button ePhysAddChanButton 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "ePhys_Trigs", "Button ePhysAddTrigButton 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "ePhys_Trigs", "Button ePhysAddVoutButton 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "ePhys_Trigs", "PopupMenu ePhysBoardPopMenu 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "ePhys_Trigs", "TitleBox ePhysBoardTitle 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "ePhys_Trigs", "ListBox ePhysChanListBox 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "ePhys_Trigs", "PopupMenu ePhysDelChanPopMenu 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "ePhys_Trigs", "PopupMenu ePhysDelTrigPopMenu 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "ePhys_Trigs", "PopupMenu ePhysDelVoutPopMenu 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "ePhys_Trigs", "Button ePhysEditVoltagePulseButton 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "ePhys_Trigs", "SetVariable EphysSampFreqSetVar 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "ePhys_Trigs", "TitleBox ePhysScanChansTitle 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "ePhys_Trigs", "ListBox ePhysVoutListBox 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "ePhys_Trigs", "ListBox outPutTriggersListBox 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "ePhys_Trigs", "TitleBox outPutTriggersTitle 0;")
GUIPTabAddCtrls ("Other_Scan_Settings", "modeTab",  "ePhys_Trigs", "TitleBox outPutVoltageWavesTitle 0;")
break
	endswitch
	return 0
End


function/s twoP_ListBoards()

	string aBoard, boards=fDAQmx_DeviceNames()
	variable iBoard, nBoards = itemsinList(boards, ";")
	string outStr = ""
	for (iBoard=0;iBoard < nBoards;iBoard +=1)
		aBoard = stringFromList (iBoard, boards,";")
		DAQmx_DeviceInfo /DEV=aBoard
		outStr += aBoard + ": " + S_NIProductType + ": " + S_NIDeviceCategory + ";"
	endfor
	return outStr
end


Function NQ_PrefsSetBoardName (pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			if (cmpStr (pa.ctrlName, "ImageBoardPopMenu") ==0)
				SVAR boardName = root:packages:twoP:acquire:imageBoard
			elseif (cmpStr (pa.CtrlName, "ePhysBoardPopMenu") ==0)
				SVAR boardName =  root:packages:twoP:acquire:ePhysBoard
			endif
			boardName = stringfromlist (0, pa.popStr, ":")
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

