#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#pragma version = 2.1  			// Last Modified: 2025/09/01 by Jamie Boyd.
#pragma IgorVersion = 7			//Not sure about this. Perhaps some Igor 9isms have slipped in

#include "twoP_Prefs"
#include "twoP_examine"
#include "twoPex_export"
#include "Stages"


#define OLD_SCAN_INIT


// Constants that are not (yet) set from peferences
// Size of counters on NI boards. These limit size that can be aquired at one shot. Older boards are 24, mewer boards might be 32
CONSTANT kNQImageCounterSize = 24
CONSTANT kNQePhysCounterSize = 24
// when desired acquisition size is larger than counter size, we use
// continuous acquisition into a buffer and copy the buffer into the scan waves
// the multiplier multplies minimum frame time to set buffer size
STATIC CONSTANT kNQtBufferMult =1

//Defined constants for multiacquisition mode
CONSTANT kMultiUsePeriod = 0
CONSTANT kMultiUseWave = 1
CONSTANT kMultiUseTrigger =2 

//******************************************************************************************************
//************************** Notes on National Instruments Boards ******************************
// One NI Board (referred to as the imageBoard) is used to generate the X and Y rasters that 
// drive the galvos, collect the image data, and open and close the shutter
// An -S or X-series board with at least 1M Samples/second per input channel, 2 output channels that update
// at 1MHz, 2 counter\timers, and at least 1 DIO port
  
// The other, optional, board (referred to as the ePhysBoard) is used to collect the ephys trace(s), 
// output TTL triggers, and output clamp waves. Slower sampling rates are acceptable here, 
// but 2 counter/timers and 2 analog outputs are still expected. E-series boards are fine


//******************************************************************************************************
// Let's put the functions to make the Main Control panel in the macros menu. The code to put the main NidaqScans panel in the 
// macro menu is found in  "NidaqProc_examine.ipf ".
Menu "Macros"
	Submenu "twoP"
		submenu "Acquire"
			"Reset the NI Boards",/Q,  twoP_ResetBoards ()
			"Zero the Galvos", /Q, twoP_ZeroGalvos()
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
// Sets the output voltage on the galvos to 0, used for beam alignment 
function twoP_ZeroGalvos()
	SVAR imageboard = root:Packages:twoP:acquire:imageBoard
	fDAQmx_WriteChan(imageBoard, 0, 0, -10, 10)
	fDAQmx_WriteChan(imageBoard, 1, 0, -10, 10)
end

// ***********************************************************************************************
// Start up stuff for initializiing global variables, controls on panel, setting up NI boards
// Last Modified: 2025/08/11 by Jamie Boyd
function twoP_AcquireInit()
	twoP_AcquireMakeFolder ()
	twoP_AcquireAddControls ()
	twoP_reSetBoards ()
end


//******************************************************************************************************
// Makes globals for acquire tab functions of the Nidaq Controls panel. 
// Last Modified 2025/08/11 by Jamie Boyd - Preferences loading will make some of the variables
Function twoP_AcquireMakeFolder ()
	
	if (!(DataFolderExists ("root:packages:twoP:acquire")))
		pathinfo twoPPrefsPath
		if (V_Flag == 0)
			newPath/C/Q/Z twoPPrefsPath SpecialDirPath("Igor Pro User Files" , 0, 0, 0) + "User Procedures:twoPhoton"
			PathInfo twoPPrefsPath
			if (V_flag == 0)
				DoAlert 0, "Igor could not find twoPhoton folder in User Procedures folder."
				return 1
			endif
			if (twoP_PrefsLoad ("twoPPrefs_default"))
				return 1
			endif
		endif
	endif
	// image sizes (and backups) for normal images, start at full scale (some are alreadyy made by loading  twoPPrefs)
	NVAR xStartVoltsFS = root:Packages:twoP:Acquire:xStartVoltsFS
	variable/G root:Packages:twoP:Acquire:xStartVolts =  xStartVoltsFS
	variable/G root:Packages:twoP:acquire:XStartVoltsBU =xStartVoltsFS
	NVAR xEndVoltsFS = root:Packages:twoP:Acquire:xEndVoltsFS
	variable/G root:Packages:twoP:Acquire:xEndVolts =xEndVoltsFS
	variable/G root:Packages:twoP:acquire:XEndVoltsBU= xEndVoltsFS
	NVAR yStartVoltsFS = root:Packages:twoP:Acquire:yStartVoltsFS
	variable/G root:Packages:twoP:Acquire:yStartVolts=yStartVoltsFS
	variable/G root:Packages:twoP:acquire:YStartVoltsBU=yStartVoltsFS
	NVAR yEndVoltsFS = root:Packages:twoP:Acquire:yEndVoltsFS
	variable/G root:Packages:twoP:Acquire:yEndVolts = yEndVoltsFS
	variable/G root:Packages:twoP:Acquire:yEndVoltsBU = yEndVoltsFS
	// Initialize X and Y Voltages for line scans
	variable/G root:Packages:twoP:Acquire:LSStartVolts =xStartVoltsFS
	variable/G root:Packages:twoP:Acquire:LSStartVoltsBU =xStartVoltsFS
	variable/G root:Packages:twoP:Acquire:LSEndVolts = xEndVoltsFS
	variable/G root:Packages:twoP:Acquire:LSEndVoltsBU= xEndVoltsFS
	variable/G root:packages:twoP:Acquire:LSYVolts = 0
	variable/G root:Packages:twoP:Acquire:LSYVoltsBU = 0
	// Pixel width and height
	NVAR pixWidthFS = root:packages:twoP:acquire:pixWidthFS
	NVAR pixHeightFS =  root:packages:twoP:acquire:pixHeightFS
	variable/G root:Packages:twoP:Acquire:PixWidth = pixWidthFS
	variable/G root:Packages:twoP:Acquire:PixWidthBU =pixWidthFS
	variable/G root:Packages:twoP:Acquire:PixHeight = pixHeightFS
	variable/G root:Packages:twoP:Acquire:PixHeightBU = pixHeightFS	// Backup of the number of lines in the image - the image height for reverting if wanted
	// Pix width and number of lines for a lineScan
	variable/G root:Packages:twoP:Acquire:LSWidth = pixWidthFS
	variable/G root:Packages:twoP:Acquire:LSHeight = pixHeightFS
	variable/G root:Packages:twoP:Acquire:LSWidthBU = pixWidthFS
	variable/G root:Packages:twoP:Acquire:LSHeightBU = pixHeightFS
	// We will set these other timing variables with a call to NQ_SetTimes
	variable/G root:packages:twoP:Acquire:PixWidthTotal // total number of pixel tickes to make a line, including flyback and turnaround
	variable/G root:Packages:twoP:Acquire:LineTime
	variable/G root:Packages:twoP:Acquire:FrameTime
	variable/G root:Packages:twoP:Acquire:RunTime  // The running time of the experiment, in seconds. INF if  live mode
	string/G root:Packages:twoP:Acquire:RunTimeStr // time in minutes and seconds calculated and then displayed on the acquire control panel
	//ScanMode
	variable/G root:packages:twoP:Acquire:ScanMode = kLiveMode // state of control panel
	variable/G root:packages:twoP:Acquire:ScanStartMode = kLiveMode // state of control panel when scan was started, so it cant be changed
	variable/G root:Packages:twoP:Acquire:FlyBackMode =0 // not using bi-directional scanning
	// New Scan Name and Note
	string/G root:Packages:twoP:Acquire:NewScanName = "Scan_000"		// name for new wave to be made by scanning operation
	variable/G root:Packages:twoP:Acquire:NewScanNum = 0
	string/G root:Packages:twoP:Acquire:NewScanNote = "You can enter a note for each scan here and it will be saved with the data."	// experiment note to be saved with each experiment
	// variable for overwrite warnCheck and auto increment check
	variable/G root:packages:twoP:acquire:overwriteWarnCheck = 1
	variable/G root:packages:twoP:acquire:AutIncCheck = 1
	variable/G root:packages:twoP:acquire:inputTriggerCheck = 0
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
	// Aspect ratio of image (horizontal pixel size/vertical pixel size) backwards to most definitions, I now realize. Also, doesn't take into account possibility of different votage scaling for X and Y
	variable/G root:Packages:twoP:Acquire:AspectRatio = 1
	// globals for frame/line numbers for acquisition/averaging
	// Live mode
	string/G root:packages:twoP:Acquire:LiveSavedScanName
	variable/G root:Packages:twoP:Acquire:LiveAvgCheck = 0
	variable/G root:Packages:twoP:Acquire:numLiveAvgFrames = 3
	variable/G root:packages:twoP:Acquire:LiveAvgPos
	variable/G root:Packages:twoP:Acquire:liveROISecs = 30
	variable/G root:Packages:twoP:Acquire:liveHistCheck
	variable/G root:Packages:twoP:Acquire:liveROICheck = 0
	variable/G root:Packages:twoP:Acquire:liveROIRatioCheck = 0
	variable/g root:Packages:twoP:Acquire:LROIL, root:Packages:twoP:Acquire:LROIT // left, Top,  coordinates for the Live ROI
	variable/g root:Packages:twoP:Acquire:LROIB, root:Packages:twoP:Acquire:LROIR // bottom, Right,  coordinates for the Live ROI
	String/G root:Packages:twoP:Acquire:LiveROITopChan
	String/G root:Packages:twoP:Acquire:LiveROIBottomChan
	variable/G root:Packages:twoP:Acquire:liveRawData
	variable/G root:Packages:twoP:Acquire:ScanStopOrAbort = 0
	// Time series
	variable/G root:Packages:twoP:Acquire:TSeriesFrames = 50
	variable/G root:packages:twoP:acquire:tSeriesBufferMult =kNQtBufferMult
	variable/G root:Packages:twoP:Acquire:isCyclic =0
	// Average
	variable/G root:Packages:twoP:Acquire:numAverageFrames = 5
	// Line Scan
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
	// multiAq
	variable/G root:packages:twoP:acquire:multiModeIsMulti = 0
	variable/G root:packages:twoP:acquire:multiAqScanMode = kTimeSeries
	variable/G root:packages:twoP:acquire:multiAqTimeMode =kMultiUsePeriod				// mode is periodic, from a wave of times, start from a trigger 
	variable/G root:packages:twoP:acquire:multiAqiAq =0						// for counting acquisitions
	variable/G root:packages:twoP:acquire:multiAqnAqs =0
	string/G root:packages:twoP:acquire:multiAqTimeToNextStr=""   			// time to next scan,counted down and displayed by background task
	variable/G root:packages:twoP:acquire:MultiAqStartTime				// when scan was started
	variable/G root:packages:twoP:acquire:MultiAqNextTime			// timeof next scan
	// Period mode
	string/G root:packages:twoP:acquire:multiAqPeriodPeriodStr = "0:20"	// User enters period and initial delay in time format hh:mm:ss, where hours are optional
	string/G root:packages:twoP:acquire:multiAqPeriodDelayStr = "0:00"	// initial delay, 0 means start right away
	variable/G root:packages:twoP:acquire:multiAqPeriodNum = 10			// number of scans for  period scanning
	// Wave Mode
	NewDataFolder/o root:packages:twoP:acquire:multiAqWaves
	string/G root:packages:twoP:Acquire:multiAqWaveWaveStr = ""			//contains name of text wave with scan times in it.
	// triggered mode
	variable/G root:packages:twoP:acquire:multiAqTriggerNum = 10	
	// Trigger Timing Values
	variable/G root:packages:twoP:Acquire:trig1Check = 0
	variable/G root:packages:twoP:Acquire:trig2Check = 0
	variable/G root:Packages:twoP:Acquire:DelayFrames1 =0 // When doing a time series, the number of frames to delay before sending trigger stimulus on the ephysBoard counter 0 output pin.
	variable/G root:Packages:twoP:Acquire:DelayFrames2 = 0 // When doing a time series, the number of frames to delay before sending  trigger stimulus on the ephysBoard counter 1 output pin.
	variable/G root:Packages:twoP:Acquire:DelayLines1 =0	// When doing a LineScan, the number of lines to delay before sending  trigger stimulus on the ephysBoard counter 0 output pin.
	variable/G root:Packages:twoP:Acquire:DelayLines2 = 0 // When doing a LineScan, the number of lines to delay before sending  trigger stimulus on the ephysBoard counter 1 output pin.
	variable/G root:Packages:twoP:Acquire:DelaySecs1 =0	//  the number of seconds to delay, corresponding to frames or lines selected above, or just plain seconds for ePhys
	variable/G root:Packages:twoP:Acquire:DelaySecs2 = 0 //the number of seconds to delay, corresponding to frames or lines selected above, or just plain seconds for ePhy
	//VoltagePulse Stuff
	NewDataFolder/o root:packages:twoP:acquire:VoltagePulseWaves
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
	// Wave for fitting the cosine expansion used in outputting the Galvo Signals
	make/o/D root:packages:twoP:acquire:Scan_Coefs = {7.4, .65, .13, 0.015, 0}
	// set experiment size
	variable/G root:packages:twoP:acquire:expSize = NQ_GetExpSize ()
	//threading for background processing during acquisition
	variable/G root:packages:twoP:acquire:gThreadGroupID
	make/o/n=6/WAVE root:packages:twoP:acquire:threadData
	// DIO shutter task and trigger task numbers
	variable/G root:packages:twoP:Acquire:shutterTaskNum
	variable/G root:packages:twoP:Acquire:triggerTaskNum
	return 0
end
		

//******************************************************************************************************
// Adds controls for the acquire functions to the Nidaq Controls panel
// Last Modified 2025/07/22 by Jamie Boyd
Function twoP_AcquireAddControls ()
	DoWindow/F twoP_Controls
	if (!(V_Flag))
		return 1
	endif
	// Controls directly on Acquire tab
	// Experiment size,in termsof physical memory usage
	ValDisplay expSizeDisp,pos={5.00,23.00},size={334.00,17.00},title="Mem Use"
	ValDisplay expSizeDisp,help={"Shows Igor's use of physical memory compared to physical memory available to Igor"}
	ValDisplay expSizeDisp,fSize=12,format="%.2fGb",frame=2
	ValDisplay expSizeDisp,limits={0,(numberbykey("PHYSMEM", IgorInfo(0), ":", ";")/2^30),0},barmisc={0,50},highColor=(0,0,0),lowColor=(0,0,0)
	ValDisplay expSizeDisp,value=#"root:packages:twoP:acquire:expSize"
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "ValDisplay expSizeDisp 0;")
	// Image size controls
	GroupBox ImageSizeGrpBox,pos={3.00,40.00},size={336.00,107.00}
	GroupBox ImageSizeGrpBox,title="Image Size",frame=0
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "GroupBox ImageSizeGrpBox 0;")
	// pixel size
	SetVariable PixWidSetVar,pos={9.00,57.00},size={94.00,18.00},proc=NQ_SetTimesProc
	SetVariable PixWidSetVar,title="X pix",fSize=12
	SetVariable PixWidSetVar,limits={2,inf,2},value=root:Packages:twoP:Acquire:PixWidth
	SetVariable PixWidSetVar help={"Width of the image to be acquired, in pxels. Pixel scaling is determined by X galvo voltage range and objective"}
	SetVariable PixHeightSetVar,pos={9.00,76.00},size={94.00,18.00},proc=NQ_SetTimesProc
	SetVariable PixHeightSetVar,title="Y Pix",fSize=12
	SetVariable PixHeightSetVar,limits={2,inf,2},value=root:Packages:twoP:Acquire:PixHeight
	SetVariable PixHeightSetVar help={"Height of the image to be acquired, in pxels. Pixel scaling is determined by Y galvo voltage range and objective"}
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Setvariable PixWidSetVar 0;SetVariable PixHeightSetVar 0;")
	// Volts
	NVAR xStartVoltsFS = root:Packages:twoP:Acquire:xStartVoltsFS
	NVAR xEndVoltsFS = root:Packages:twoP:Acquire:xEndVoltsFS
	NVAR yStartVoltsFS = root:Packages:twoP:Acquire:yStartVoltsFS
	NVAR yEndVoltsFS = root:Packages:twoP:Acquire:yEndVoltsFS
	// x stat
	SetVariable XStartSetVar,pos={118.00,57.00},size={105.00,18.00},title="X Start",fSize=12
	SetVariable XStartSetVar,value=root:Packages:twoP:Acquire:xStartVolts
	SetVariable XStartSetVar, help={"Minimum value of X galvo voltage during image acquisition, defines position of left edge of image"}
	GUIPSIsetVarEnable ("TwoP_Controls", "XStartSetVar", "NQ_SetTimesProc", xStartVoltsFS, xEndVoltsFS, 0.1, 0, 0, 2, "V")
	// xend
	SetVariable XEndSetVar,pos={234.00,57.00},size={99.00,18.00},title="X End",fSize=12
	SetVariable XEndSetVar,value=root:Packages:twoP:Acquire:xEndVolts
	SetVariable XEndSetVar, help={"Maximum value of X galvo voltage during image acquisition, defines position of right edge of image"}
	GUIPSIsetVarEnable ("TwoP_Controls", "XEndSetVar", "NQ_SetTimesProc", xStartVoltsFS, xEndVoltsFS, 0.1, 0, 0, 2, "V")
	// y start
	SetVariable YStartSetVar,pos={118.00,76.00},size={105.00,18.00},title="Y Start",fSize=12
	SetVariable YStartSetVar,value=root:Packages:twoP:Acquire:yStartVolts
	SetVariable YStartSetVar, help={"Minimum value of Y galvo voltage during image acquisition, defines position of bottom edge of image"}
	GUIPSIsetVarEnable ("TwoP_Controls", "YStartSetVar", "NQ_SetTimesProc", yStartVoltsFS, yEndVoltsFS, 0.1, 0, 0, 2, "V")
	// y end
	SetVariable YEndSetVar,pos={235.00,76.00},size={98.00,18.00},title="Y End",fSize=12, disable=2
	SetVariable YEndSetVar,value=root:Packages:twoP:Acquire:yEndVolts
	SetVariable YEndSetVar,help={"Maximum value of Y galvo voltage during image acquisition, defines position of top edge of image"}
	GUIPSIsetVarEnable ("TwoP_Controls", "YEndSetVar", "NQ_SetTimesProc", yStartVoltsFS, yEndVoltsFS, 0.1, 0, 0, 2, "V")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "SetVariable XStartSetVar 0;SetVariable XEndSetVar 0;SetVariable YStartSetVar 0;SetVariable YEndSetVar 2;")
	// Image sizing controls
	Button FullScaleButton,pos={8.00,98.00},size={31.00,16.00},proc=NQ_SetFullScaleProc
	Button FullScaleButton,title="Full", help= {"Sets image pixel sizes and galvo scan voltage endpoints to full scale values defined in setings/preferences."}
	Button RevertScaleButton,pos={41.00,98.00},size={50.00,16.00},proc=NQ_RevertScaleProc
	Button RevertScaleButton,title="Revert", help={"Sets image pixel sizes and galvo scan voltage endpoints to last used values"}
	PopupMenu RevertScalePopMenu,pos={93.00,96.00},size={64.00,19.00},proc=RevertSettingstoWaveProc
	PopupMenu RevertScalePopMenu,title="to Scan:"
	PopupMenu RevertScalePopMenu,mode=0,value=#"twoP_ScanListScans (\"0,1,2,3,4,5,\")"
	SetVariable AspRatSetVar,pos={163.00,97.00},size={90.00,18.00},proc=NQ_AspectRatioProc
	SetVariable AspRatSetVar,title="Aspect",fSize=12,format="%#.3G"
	SetVariable AspRatSetVar,limits={0,inf,0.1},value=root:Packages:twoP:Acquire:AspectRatio
	PopupMenu AspRatPopUp,pos={258.00,96.00},size={77.00,19.00},proc=NQ_AspRatPopUpProc
	PopupMenu AspRatPopUp,fSize=12
	PopupMenu AspRatPopUp,mode=5,popvalue="Vary Y End",value=#"\"Vary X Start;Vary X  End;Vary X Pix;Vary Y Start;Vary Y End;Vary Y Pix;Free\""
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Button FullScaleButton;Button RevertScaleButton;PopupMenu RevertScalePopMenu;SetVariable AspRatSetVar;PopupMenu AspRatPopUp;")
	// Objective Selection
	PopupMenu ObjPopUp,pos={8.00,121.00},size={44.00,19.00},proc=NQ_ObjPopProc
	PopupMenu ObjPopUp,title="Obj:",mode=0,value=#"NQ_ListObjs()"
	TitleBox CurObjTitle,pos={57.00,123.00},size={18.00,15.00},fSize=12,frame=0
	TitleBox CurObjTitle,variable=root:Packages:twoP:Acquire:CurObj
	SetVariable xPixSizeSetVar,pos={85.00,122.00},size={152.00,18.00},title=" "
	SetVariable xPixSizeSetVar,fSize=12,format="Pixel Sizes X: %.2W1Pm/pix"
	SetVariable xPixSizeSetVar,frame=0
	SetVariable xPixSizeSetVar,limits={0,inf,0},value=root:Packages:twoP:Acquire:xPixSize,noedit=1
	SetVariable yPixSizeSetVar,pos={237.00,122.00},size={97.00,18.00},title=" "
	SetVariable yPixSizeSetVar,fSize=12,format="Y: %.2W1Pm/pix",frame=0
	SetVariable yPixSizeSetVar,limits={0,inf,0},value=root:Packages:twoP:Acquire:yPixSize,noedit=1
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "PopupMenu ObjPopUp;TitleBox CurObjTitle;SetVariable xPixSizeSetVar;SetVariable yPixSizeSetVar")
	// Scan Times
	GroupBox TimesGrpBox,pos={7.00,468.00},size={334.00,72.00},title="Scan Times"
	GroupBox TimesGrpBox,fSize=12
	SetVariable LineTimeSetVar,pos={11.00,488.00},size={150.00,22.00}
	SetVariable LineTimeSetVar,title="Line   ",fSize=14,format="%.2W1Ps"
	SetVariable LineTimeSetVar,limits={-inf,inf,0},value=root:Packages:twoP:Acquire:LineTime,noedit=1
	SetVariable FrameTimeSetVar,pos={167.00,489.00},size={149.00,22.00}
	SetVariable FrameTimeSetVar,title="Frame",fSize=14,format="%.1W1Ps"
	SetVariable FrameTimeSetVar,limits={-inf,inf,0},value=root:Packages:twoP:Acquire:FrameTime,noedit=1
	SetVariable expTimeSetvar,pos={11.00,514.00},size={149.00,22.00}
	SetVariable expTimeSetvar,title="Total  ",fSize=14
	SetVariable expTimeSetvar,value=root:Packages:twoP:Acquire:RunTimeStr,noedit=1
	CheckBox TurboCheck,pos={169.00,516.00},size={116.00,15.00},proc=NQ_TurboCheckProc
	CheckBox TurboCheck,title="Bi-Directional Scan"
	CheckBox TurboCheck,help={"If On, data is collected on both directions of horizontal scan. If alternate lines of image are misaligned using Turbo, adjust  Scan Head Delay."}
	CheckBox TurboCheck,variable=root:Packages:twoP:Acquire:FlyBackMode
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "GroupBox TimesGrpBox;SetVariable LineTimeSetVar;SetVariable FrameTimeSetVar;SetVariable expTimeSetvar;CheckBox TurboCheck;")
	// Buttons to Open other windows
	Button aqShowScansButton,pos={7.00,547.00},size={49.00,18.00},proc=twoP_ScanShowScan
	Button aqShowScansButton,title="Scans"
	Button aqShowTracesButton,pos={73.00,547.00},size={57.00,18.00},proc=NQ_showTracesProc
	Button aqShowTracesButton,title="Traces"
	Button ShowScanSettingsButton,pos={142.00,547.00},size={98.00,18.00},proc=NQ_OtherScanSettingsProc
	Button ShowScanSettingsButton,title="More Settings"
	Button showFocusPanelButton,pos={257.00,547.00},size={57.00,18.00},proc=NQ_OpenFocusPanel
	Button showFocusPanelButton,title="Focus"
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "Button aqShowScansButton;Button aqShowTracesButton;Button ShowScanSettingsButton;Button showFocusPanelButton;")
	//exp note
	NewNotebook /F=1 /N=ExpNoteBook /W=(1,572,339,636) /HOST=# 
	Notebook kwTopWin, defaultTab=10, autoSave= 0, magnification=1, showRuler=0, rulerUnits=1
	Notebook kwTopWin, newRuler=Normal, justification=0, margins={0,0,231}, spacing={0,0,0}, tabs={}, rulerDefaults={"Arial",11,0,(0,0,0)}
	RenameWindow #,ExpNoteBook
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "SubWindow ExpNoteBook;")
	// Scan Name
	SetVariable AqScanNameSetVar,pos={5.00,640.00},size={194.00,22.00},proc=NQ_ScanNameProc
	SetVariable AqScanNameSetVar,title="New Scan Name"
	SetVariable AqScanNameSetVar,help={"The scan created when you press \"Start Scan\" will have this name."}
	SetVariable AqScanNameSetVar,fSize=14
	SetVariable AqScanNameSetVar,value=root:Packages:twoP:Acquire:NewScanName
	CheckBox AqAutIncCheck,pos={212.00,646.00},size={58.00,15.00},proc=NQ_autincCheckProc
	CheckBox AqAutIncCheck,title="AutoInc"
	CheckBox AqAutIncCheck,help={"If checked, \"New Scan Name\" is given a numeric suffix and automatically incremented with every scan."}
	CheckBox AqAutIncCheck,variable=root:Packages:twoP:Acquire:AutincCheck
	CheckBox AqOverWriteWarnCheck,pos={282.00,645.00},size={44.00,15.00}
	CheckBox AqOverWriteWarnCheck,title="Warn"
	CheckBox AqOverWriteWarnCheck,help={"If checked, you will be warned if \"New Scan Name\" conflicts with an existing scan."}
	CheckBox AqOverWriteWarnCheck,variable=root:Packages:twoP:Acquire:overwriteWarnCheck
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "SetVariable AqScanNameSetVar;CheckBox AqAutIncCheck;CheckBox AqOverWriteWarnCheck;")
	// start settings
	PopupMenu AqExportAtScanEndPop,pos={7.00,667},size={150.00,19.00},proc=NQ_ExportAfterScanPopProc
	PopupMenu AqExportAtScanEndPop,title="At Scan end"
	PopupMenu AqExportAtScanEndPop,mode=1,popvalue="Do Nothing",value=#"\"Do Nothing;Save Experiment;Export Scan;Export and Delete Scan;Export and Delete Last Scan;\""
	
	ValDisplay AqPercentCompleteDisplay,pos={3.00,690.00},size={226.00,17.00}
	ValDisplay AqPercentCompleteDisplay,fSize=12
	ValDisplay AqPercentCompleteDisplay,limits={0,100,0},barmisc={0,0},mode=3
	ValDisplay AqPercentCompleteDisplay,value=#"root:packages:twoP:Acquire:PercentComplete"
	
	Button AqStartButton,pos={236.00,677.00},size={52.00,29.00},proc=NQ_StartScan
	Button AqStartButton,title="Start ",help={"Starts or Aborts a Scan."}
	Button AqStartButton,userdata="START",fSize=16,fStyle=1
	Button AqStartButton,fColor=(0,65280,0)
	CheckBox AqInPutTrigCheck,pos={290.00,677.00},size={51.00,30.00}
	CheckBox AqInPutTrigCheck,title="On\rtrigger"
	CheckBox AqInPutTrigCheck,variable=root:Packages:twoP:Acquire:inputTriggerCheck
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "PopupMenu AqExportAtScanEndPop;ValDisplay AqPercentCompleteDisplay;Button AqStartButton;CheckBox AqInPutTrigCheck;")
	// controls on Scan mode tab control
	TabControl SmodeTabControl,pos={3.00,149.00},size={339.00,319.00},proc=GUIPTabProc
	TabControl SmodeTabControl,help={"Selects one of 6 possible type of scans to perform."}
	TabControl SmodeTabControl,fSize=12,tabLabel(0)="Live",tabLabel(1)="Tser"
	TabControl SmodeTabControl,tabLabel(2)="Avg",tabLabel(3)="Lines"
	TabControl SmodeTabControl,tabLabel(4)="Zser",tabLabel(5)="ePhys"
	TabControl SmodeTabControl,tabLabel(6)="Multi",value=0
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Acquire", "TabControl SmodeTabControl;") 
	GUIPTabNewTabCtrl ("twoP_Controls", "SmodeTabControl", TabList= "Live;Tser;Avg;Lines;Zser;ePhys;Multi;", UserFunc="NQ_SModeTabControlproc")
	// controls present on multiple tabs
	// Live mode im chans - Live;Tser;Avg;Zser;Multi
	PopupMenu ImageChansPopMenu,pos={9.00,176.00},size={91.00,19.00},proc=NQ_ScanChansPopMenuProc
	PopupMenu ImageChansPopMenu,title="Image Chans",fSize=12
	PopupMenu ImageChansPopMenu,mode=0,value=#"twoP_listActiveChans(1)"
	TitleBox imChanListTitle,pos={107.00,180.00},size={62.00,15.00},frame=0
	TitleBox imChanListTitle,variable=root:Packages:twoP:Acquire:selImageChanList
	SVAR selImageChans = root:Packages:twoP:Acquire:selImageChanList
	selImageChans = twoP_listActiveChans(1)
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "PopupMenu ImageChansPopMenu", "Live;Tser;Avg;Zser;Multi")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "TitleBox imChanListTitle", "Live;Tser;Avg;Zser;Multi")
	// ephys chans - TSer;Lines;ePhys;Multi
	PopupMenu EphysChansPopUp,pos={9.00,199.00},size={89.00,19.00},proc=NQ_ephysChansProc
	PopupMenu EphysChansPopUp,title="ePhys Chans"
	PopupMenu EphysChansPopUp,mode=0,value=#"twoP_listActiveChans(2)"
	PopupMenu EphysChansPopUp disable = 1
	TitleBox ePhysChanListTitle,pos={101.00,202.00},size={62.00,15.00},frame=0
	TitleBox ePhysChanListTitle,variable=root:Packages:twoP:Acquire:selEphysChanList
	TitleBox ePhysChanListTitle, disable = 1
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "PopupMenu EphysChansPopUp", "Tser;Lines;ePhys;Multi;")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "TitleBox ePhysChanListTitle", "TSer;Lines;ePhys;Multi;")
	// triggers - TSer;Lines;ePhys
	NVAR frameTime = root:packages:twoP:acquire:frameTime
	// trigger 1
	CheckBox Trig1Check,pos={9.00,335.00},size={44.00,15.00},title="Trig 1"
	CheckBox Trig1Check,fSize=12,variable=root:Packages:twoP:acquire:trig1Check
	CheckBox Trig1Check,disable=1
	SetVariable Trig1SecsSetvar,pos={194.00,333.00},size={82.00,18.00},title=" "
	SetVariable Trig1SecsSetvar,value=root:Packages:twoP:Acquire:DelaySecs1
	GUIPSIsetVarEnable ("TwoP_Controls", "Trig1SecsSetvar", "NQ_TrigSecsProc", 1e-7, 100, frameTime, 1, 0.1e-7, 2, "s")
	SetVariable Trig1SecsSetvar disable=1
	// trigger 2
	CheckBox Trig2Check,pos={9.00,355.00},size={44.00,15.00},title="Trig 2"
	CheckBox Trig2Check,fSize=12,variable=root:Packages:twoP:acquire:trig2Check
	CheckBox Trig2Check, disable=1
	SetVariable Trig2SecsSetvar,pos={194.00,353.00},size={82.00,18.00},title=" ",fSize=12
	SetVariable Trig2SecsSetvar,value=root:Packages:twoP:Acquire:DelaySecs2
	GUIPSIsetVarEnable ("TwoP_Controls", "Trig2SecsSetvar", "NQ_TrigSecsProc", 1e-7, 100, frameTime, 1, 0.1e-7, 2, "s")
	SetVariable Trig2SecsSetvar, disable=1
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "CheckBox Trig1Check", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "CheckBox Trig2Check", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "SetVariable Trig1SecsSetvar", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "SetVariable Trig2SecsSetvar", "TSer;Lines;ePhys")
	//Voltage Pulse waves  TSer;Lines;ePhys
	GroupBox VoltageWaveGrpBox,pos={8.00,376.00},size={331.00,88.00}
	GroupBox VoltageWaveGrpBox,title="Voltage Pulse", disable=1
	CheckBox Voltage1Check,pos={12.00,396.00},size={14.00,14.00},proc=NQ_VoltageCheckProc
	CheckBox Voltage1Check,title="",value=0, disable=1
	PopupMenu VoltagePulse1Popup,pos={28.00,394.00},size={231.00,19.00},proc=NQ_VoltageWavePopMenuProc
	PopupMenu VoltagePulse1Popup,title="1 Voltage Wave", disable=1
	PopupMenu VoltagePulse1Popup,mode=1,popvalue="No Voltage Pulse Waves",value=#"GUIPListObjs ((\"root:packages:twoP:acquire:VoltagePulseWaves\") , 1, \"*\", 0, \"\\M1(No Voltage Pulse Waves\")"
	CheckBox Voltage2Check,pos={11.00,418.00},size={14.00,14.00},proc=NQ_VoltageCheckProc
	CheckBox Voltage2Check,title="",value=0, disable=1
	PopupMenu VoltagePulse2Popup,pos={28.00,415.00},size={231.00,19.00},proc=NQ_VoltageWavePopMenuProc
	PopupMenu VoltagePulse2Popup,title="2 Voltage Wave", disable=1
	PopupMenu VoltagePulse2Popup,mode=1,popvalue="No Voltage Pulse Waves",value=#"GUIPListObjs ((\"root:packages:twoP:acquire:VoltagePulseWaves\") , 1, \"*\", 0, \"\\M1(No Voltage Pulse Waves\")"
	PopupMenu VoltagePulsePopUp,pos={12.00,437.00},size={90.00,19.00},title="Vout"
	PopupMenu VoltagePulsePopUp,fSize=12, disable=1
	PopupMenu VoltagePulsePopUp,mode=1,popvalue="on Start",value=#"\"on Start;on Trig 2;\""
	Button VoltagePulseEditButton,pos={143.00,440.00},size={141.00,20.00},proc=EditVoltageWavesProc, disable=1
	Button VoltagePulseEditButton,title="Edit Voltage Waves"
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "GroupBox VoltageWaveGrpBox", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "CheckBox Voltage1Check", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "PopupMenu VoltagePulse1Popup", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "CheckBox Voltage2Check", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "PopupMenu VoltagePulse2Popup", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "Button VoltagePulseEditButton", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "Button VoltagePulseEditButton", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "PopupMenu VoltagePulsePopUp","TSer;Lines;ePhys")
	// Live Roi - Live;Tser"
	CheckBox LiveROICheck,pos={9.00,235.00},size={59.00,15.00},title="Live ROI"
	CheckBox LiveROICheck,fSize=12,variable=root:Packages:twoP:Acquire:liveROICheck
	CheckBox LiveROICheck, help = {"If you have set a live ROI from graph marquee menu, the results of the ROI will be shown in a graph suring Live scanning"}
	SetVariable LiveRoiTimeSetVar,pos={74.00,234.00},size={64.00,18.00},title=" ", fSize=12
	SetVariable LiveRoiTimeSetVar,help={"If doing Live ROIs, this many seconds will be shown in a scrolling graph."}
	SetVariable LiveRoiTimeSetVar,value=root:Packages:twoP:Acquire:liveROISecs
	GUIPSIsetVarEnable ("TwoP_Controls", "LiveRoiTimeSetVar", "", 1, 100, 1, 1, 0.1e-3, 1, "s")
	CheckBox LroiRatioCheck,pos={33.00,258.00},size={43.00,15.00},title="Ratio"
	CheckBox LroiRatioCheck,fSize=12
	CheckBox LroiRatioCheck,variable=root:Packages:twoP:Acquire:liveROIRatioCheck
	PopupMenu LiveROIRatioTopPopMenu,pos={84.00,256.00},size={62.00,19.00},proc=NQ_SetLiveChansPopMenuProc
	PopupMenu LiveROIRatioTopPopMenu,title="    Top   ",fSize=12
	PopupMenu LiveROIRatioTopPopMenu,mode=0,value=#"root:packages:twoP:acquire:selImagechanList"
	TitleBox LiveROIRatioTopChanTitle,pos={151.00,258.00},size={28.00,15.00}
	TitleBox LiveROIRatioTopChanTitle,frame=0
	TitleBox LiveROIRatioTopChanTitle,variable=root:Packages:twoP:Acquire:LiveROITopChan
	PopupMenu LiveROIRatioBottomPopMenu,pos={84.00,278.00},size={62.00,19.00},proc=NQ_SetLiveChansPopMenuProc
	PopupMenu LiveROIRatioBottomPopMenu,title="Bottom",fSize=12
	PopupMenu LiveROIRatioBottomPopMenu,mode=0,value=#"root:packages:twoP:acquire:selImagechanList"
	TitleBox LiveROIRatioBottomChanTitle,pos={151.00,280.00},size={28.00,15.00}
	TitleBox LiveROIRatioBottomChanTitle,frame=0
	TitleBox LiveROIRatioBottomChanTitle,variable=root:Packages:twoP:Acquire:LiveROIBottomChan
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "CheckBox LiveROICheck", "Live;Tser")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "SetVariable LiveRoiTimeSetVar", "Live;Tser")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "CheckBox LroiRatioCheck", "Live;Tser")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "SetVariable LiveRoiTimeSetVar", "Live;Tser")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "CheckBox LroiRatioCheck", "Live;Tser")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "PopupMenu LiveROIRatioTopPopMenu", "Live;Tser")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "TitleBox LiveROIRatioTopChanTitle", "Live;Tser")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "PopupMenu LiveROIRatioBottomPopMenu", "Live;Tser")
	GUIPTabAddCtrlToTabs ("twoP_Controls", "SmodeTabControl", "TitleBox LiveROIRatioBottomChanTitle","Live;Tser")
	// Live mode sepecific
	SetVariable LiveAvgFramesSetVar, pos={9.00,205.00},size={163.00,18.00},proc=NQ_SetTimesProc
	SetVariable LiveAvgFramesSetVar,title="Average per Frame",fSize=12
	SetVariable LiveAvgFramesSetVar,limits={0,inf,1},value=root:Packages:twoP:Acquire:numLiveAvgFrames
	CheckBox LiveHistCheck,title="Live Histogram",fSize=12
	CheckBox LiveHistCheck,variable=root:Packages:twoP:Acquire:liveHistCheck
	CheckBox LiveRawDataCheck,pos={182.00,234.00},size={89.00,15.00}
	CheckBox LiveRawDataCheck,title="Live Raw Data",fSize=12
	CheckBox LiveRawDataCheck,variable=root:packages:twoP:acquire:liveRawData
	Button Trig1ManualButton,pos={9.00,313.00},size={82.00,20.00}
	Button Trig1ManualButton,title="Fire Trigger 1", proc=twoP_LiveTriggerButtonProc
	Button Trig1ManualButton,help={"If you have a pulse configured for trigger 1, it is fired with no delay"}
	Button Trig2ManualButton,pos={109.00,313.00},size={82.00,20.00}
	Button Trig2ManualButton,title="Fire Trigger 2", proc=twoP_LiveTriggerButtonProc
	Button Trig2ManualButton,help={"If you have a pulse configured for trigger 1, it is fired with no delay"}
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Live", "SetVariable LiveAvgFramesSetVar;CheckBox LiveHistCheck;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Live", "Button Trig1ManualButton;Button Trig2ManualButton;CheckBox LiveRawDataCheck;")
	// Time series specific
	SetVariable NumTSeriesFramesSetVar,pos={9.00,304.00},size={174.00,22.00},proc=NQ_SetTimesProc
	SetVariable NumTSeriesFramesSetVar,title="Time Series Frames",fSize=14
	SetVariable NumTSeriesFramesSetVar,limits={0,inf,1},value=root:Packages:twoP:Acquire:TSeriesFrames
	SetVariable NumTSeriesFramesSetVar, disable=1
	SetVariable FramesTrig1SetVar,pos={77.00,333.00},size={110.00,18.00},proc=NQ_SetTimesProc
	SetVariable FramesTrig1SetVar,title="on Frame",fSize=12
	SetVariable FramesTrig1SetVar,limits={0,inf,1},value=root:Packages:twoP:Acquire:DelayFrames1
	SetVariable FramesTrig1SetVar, disable=1
	SetVariable FramesTrig2SetVar,pos={77.00,353.00},size={110.00,18.00},proc=NQ_SetTimesProc
	SetVariable FramesTrig2SetVar,title="on Frame",fSize=12
	SetVariable FramesTrig2SetVar,limits={0,inf,1},value=root:Packages:twoP:Acquire:DelayFrames2
	SetVariable FramesTrig2SetVar disable=1
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Tser", "SetVariable NumTSeriesFramesSetVar;SetVariable FramesTrig1SetVar;SetVariable FramesTrig2SetVar")
	// Avg specific
	SetVariable AvgNumFramesSetVar,pos={9.00,303.00},size={176.00,22.00},proc=NQ_SetTimesProc
	SetVariable AvgNumFramesSetVar,title="Frames to Average",fSize=14
	SetVariable AvgNumFramesSetVar,limits={0,inf,1},value=root:Packages:twoP:Acquire:numAverageFrames
	SetVariable AvgNumFramesSetVar, disable=1
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Avg", "SetVariable AvgNumFramesSetVar;")
	// lines specific
	SetVariable LineScanWidthSetVar,title="X Pix",fSize=12,pos={8.00,228.00},size={91.00,15.00},proc=NQ_SetTimesProc
	SetVariable LineScanWidthSetVar,limits={2,inf,2},value=root:Packages:twoP:Acquire:LSWidth
	SetVariable LineScanWidthSetVar, disable=1
	SetVariable LineScanXStartSetVar,pos={110.00,228.00},size={98.00,15.00},title="X Start",fSize=12
	SetVariable LineScanXStartSetVar,value=root:Packages:twoP:Acquire:LSStartVolts
	GUIPSIsetVarEnable ("TwoP_Controls", "LineScanXStartSetVar", "NQ_SetTimesProc", xStartVoltsFS, xEndVoltsFS, 0.1, 0, 0, 2, "V")
	SetVariable LineScanXStartSetVar disable=1	
	SetVariable LineScanXEndSetVar,pos={220.00,228.00},size={103.00,15.00},title="X End",fSize=12
	SetVariable LineScanXEndSetVar,value=root:Packages:twoP:Acquire:LSEndVolts
	GUIPSIsetVarEnable ("TwoP_Controls", "LineScanXEndSetVar", "NQ_SetTimesProc", xStartVoltsFS, xEndVoltsFS, 0.1, 0, 0, 2, "V")
	SetVariable LineScanXEndSetVar disable=1
	SetVariable LineScanYSetVar,pos={128.00,248.00},size={80.00,15.00},title="Y",fSize=12
	SetVariable LineScanYSetVar,value=root:Packages:twoP:Acquire:LSYVolts
	GUIPSIsetVarEnable ("TwoP_Controls", "LineScanYSetVar", "NQ_SetTimesProc", yStartVoltsFS, yEndVoltsFS, 0.1, 0, 0, 2, "V")
	SetVariable LineScanYSetVar disable=1
	SetVariable LineScanPixSizeSetVar,pos={5.00,248.00},size={106.00,18.00}
	SetVariable LineScanPixSizeSetVar,title=" ",fSize=12,format="Size %.1W1Pm/pix"
	SetVariable LineScanPixSizeSetVar,frame=0, disable=1
	SetVariable LineScanPixSizeSetVar,limits={0,inf,0},value=root:Packages:twoP:Acquire:LSPixSize,noedit=1,live=1
	SetVariable LineScanPixSizeSetVar disable=1
	PopupMenu LineScanLinktoPopMenu,pos={9.00,272.00},size={44.00,19.00},proc=NQ_LineScanLinkToProc
	PopupMenu LineScanLinktoPopMenu,title="Link", disable=1
	PopupMenu LineScanLinktoPopMenu,mode=0,value=#"NQ_ListScans (\"1,2,4,\") + \";Don't Link\""
	TitleBox LineScanLinktoTitleBox,pos={56.00,274.00},size={54.00,15.00},fSize=12
	TitleBox LineScanLinktoTitleBox,frame=0
	TitleBox LineScanLinktoTitleBox,variable=root:Packages:twoP:Acquire:LSLinkWaveStr, disable=1
	Button LineScanRevertScaleButton,pos={153.00,273.00},size={50.00,17.00},proc=NQ_LSRevertScaleProc
	Button LineScanRevertScaleButton,title="Revert", disable=1
	PopupMenu LineScanRevertScalePopMenu,pos={205.00,272.00},size={64.00,19.00},proc=NQ_RevertSettingstoLineScanProc
	PopupMenu LineScanRevertScalePopMenu,title="to Scan:",fSize=10, disable=1
	PopupMenu LineScanRevertScalePopMenu,mode=0,value=#"NQ_ListScans (\"3\")"
	SetVariable LineScanHeightSetVar disable =1, pos={9.00,304.00},size={169.00,22.00},proc=NQ_SetTimesProc
	SetVariable LineScanHeightSetVar,title="LineScan Lines",fSize=14
	SetVariable LineScanHeightSetVar,limits={2,inf,2},value=root:Packages:twoP:Acquire:LSHeight
	SetVariable LineScanTrig1SetVar disable =1, pos={81.00,333.00},size={110.00,18.00},proc=NQ_SetTimesProc
	SetVariable LineScanTrig1SetVar,title="on Line"
	SetVariable LineScanTrig1SetVar,limits={0,inf,1},value=root:Packages:twoP:Acquire:DelayLines1
	SetVariable LineScanTrig2SetVar disable =1,pos={81.00,353.00},size={110.00,18.00},proc=NQ_SetTimesProc
	SetVariable LineScanTrig2SetVar,title="on Line"
	SetVariable LineScanTrig2SetVar,limits={0,inf,1},value=root:Packages:twoP:Acquire:DelayLines2
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Lines", "SetVariable LineScanWidthSetVar;SetVariable LineScanXStartSetVar;SetVariable LineScanXStartSetVar;setvariable LineScanXEndSetVar")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Lines", "SetVariable LineScanYSetVar;PopupMenu LineScanLinktoPopMenu;TitleBox LineScanLinktoTitleBox;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Lines", "Button LineScanRevertScaleButton;PopupMenu LineScanRevertScalePopMenu;SetVariable LineScanHeightSetVar")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Lines", "SetVariable LineScanTrig1SetVar;SetVariable LineScanTrig2SetVar;SetVariable LineScanPixSizeSetVar")
	// ePhys specific
	SetVariable ePhysOnlyTimeSetVar,pos={9.00,304.00},size={137.00,22.00},proc=GUIPSIsetVarProc
	SetVariable ePhysOnlyTimeSetVar,title="Duration"
	SetVariable ePhysOnlyTimeSetVar,userdata(FUNCSTR)="NQ_SetTimesProc"
	SetVariable ePhysOnlyTimeSetVar,userdata=A"5C`_66q@:X4j;-p!BX=jCe\\>_3]JoT3r"
	SetVariable ePhysOnlyTimeSetVar,fSize=14,format="%.1W1Ps"
	SetVariable ePhysOnlyTimeSetVar,limits={-inf,inf,10},value=root:Packages:twoP:acquire:ePhysOnlyTime
	SetVariable ePhysOnlyTimeSetVar, disable=1
	NVAR ePhysSampFreq= root:packages:twoP:acquire:ePhysSampFreq
	GUIPSISetVarSetMax ("twoP_Controls", "ePhysOnlyTimeSetVar", (kNQePhysCounterSize/ePhysSampFreq))
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "ePhys", "SetVariable ePhysOnlyTimeSetVar;")
	// Z ser specific
	SVAR stageProc = root:packages:twoP:acquire:StageProc
	NVAR/z minZStepSize = $"root:packages:" + stageProc + ":zRes"
	NVAR/z minZ = $"root:packages:" + stageProc + ":zMin"
	NVAR/z maxZ = $"root:packages:" + stageProc + ":zMax"
	NVAR stepSize = root:Packages:twoP:Acquire:zStepSize
	// first z
	Button FirstZButton,pos={13.00,221.00},size={29.00,18.00}, title="Get", proc=NQ_ZfirstLastButtonProc
	Button FirstZButton disable =1
	SetVariable zFirstZSetVar,pos={56.00,222.00},size={115.00,18.00},title="First Z",fSize=12
	SetVariable zFirstZSetVar,value=root:Packages:twoP:Acquire:ZFirstZ
	GUIPSIsetVarEnable ("TwoP_Controls", "zFirstZSetVar", "NQ_zSetVarProc", minZ, maxZ, minZStepSize, 1, minZStepSize, 2, "m")
	SetVariable zFirstZSetVar,disable =1
	// last Z
	Button LastZButton,pos={11.00,254.00},size={30.00,17.00},proc=NQ_ZfirstLastButtonProc, title="Get"
	Button LastZButton,disable =1
	SetVariable ZLastZSetVar,pos={58.00,253.00},size={116.00,18.00},title="Last Z", fSize=12
	SetVariable ZLastZSetVar,value=root:Packages:twoP:Acquire:ZLastZ
	GUIPSIsetVarEnable ("TwoP_Controls", "ZLastZSetVar", "NQ_zSetVarProc", minZ, maxZ, stepSize, 1, minZStepSize, 2, "m")
	SetVariable ZLastZSetVar, disable =1
	// Z step SIze
	SetVariable zStepSizeSetvar,pos={38.00,280.00},size={132.00,18.00},title="Step Size ",fSize=12
	SetVariable zStepSizeSetvar value=root:Packages:twoP:Acquire:zStepSize
	GUIPSIsetVarEnable ("TwoP_Controls", "zStepSizeSetvar", "NQ_zSetVarProc", stepSize, 100e-6, minZStepSize, 1, minZStepSize, 2, "m")
	SetVariable zStepSizeSetvar, disable =1
	// number of frames 
	SetVariable NumZframesSetvar,pos={9.00,304.00},size={148.00,22.00},proc=NQ_zSetVarProc
	SetVariable NumZframesSetvar,title="Z Slices   ",fSize=14
	SetVariable NumZframesSetvar,limits={0,inf,1},value=root:Packages:twoP:Acquire:NumZseriesFrames
	SetVariable NumZframesSetvar,disable =1
	// num frames to average
	SetVariable zKalmanAvgSetvar,pos={9.00,334.00},size={147.00,18.00},proc=NQ_SetTimesProc
	SetVariable zKalmanAvgSetvar,title="Avg. each slice",fSize=12
	SetVariable zKalmanAvgSetvar,limits={1,inf,1},value=root:Packages:twoP:Acquire:NumZseriesAvg
	SetVariable zKalmanAvgSetvar, disable = 1
	PopupMenu ZdjustPopMenu pos={182.00,224.00},size={116.00,19.00},proc=NQ_ZAdjustPopMenuProc,title="adjust"
	PopupMenu ZdjustPopMenu,mode=1,popvalue="Num Slices",value=#"\"Num Slices;Step Size;First Z;Last Z;\""
	PopupMenu ZdjustPopMenu disable = 1
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Zser", "Button FirstZButton;SetVariable zFirstZSetVar;Button LastZButton;SetVariable ZLastZSetVar;SetVariable zStepSizeSetvar;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Zser", "SetVariable NumZframesSetvar;SetVariable zKalmanAvgSetvar;PopupMenu ZdjustPopMenu")
	// Muti specific
	PopupMenu multiAqDataModePopUp,disable =1,pos={10.00,229.00},size={115.00,19.00},proc=NQ_MultiAqDataModePopMenuProc
	PopupMenu multiAqDataModePopUp,title="Mode"
	PopupMenu multiAqDataModePopUp,mode=1,popvalue="Time Series",value=#"\"Time Series;Average;Line Scan;Z series;ePhys Only\""
	// period
	GroupBox MultModePeriodGrp,disable =1,pos={6.00,252.00},size={110.00,97.00}
	GroupBox MultModePeriodGrp,title="                        "
	CheckBox MultiPeriodCheck,disable =1,pos={35.00,257.00},size={50.00,15.00},proc=GUIPRadioButtonProcSetGlobal
	CheckBox MultiPeriodCheck,title="Period"
	CheckBox MultiPeriodCheck,userdata="root:packages:twoP:acquire:multiAqTimeMode=0;MultiWaveCheck;MultiTriggerCheck;"
	CheckBox MultiPeriodCheck,value=1,mode=1
	SetVariable MultiAqPeriodNumSetVar,disable =1,pos={9.00,276.00},size={76.00,18.00}
	SetVariable MultiAqPeriodNumSetVar,title="Num",fSize=12
	SetVariable MultiAqPeriodNumSetVar,limits={2,inf,1},value=root:Packages:twoP:Acquire:multiAqPeriodNum
	SetVariable MultAqPeriodPeriodSetVar disable =1,pos={9.00,299.00},size={103.00,18.00},proc=NQ_MultiAqTimeSetVarProc
	SetVariable MultAqPeriodPeriodSetVar,title="Period ",fSize=12
	SetVariable MultAqPeriodPeriodSetVar,limits={0,inf,0.5},value=root:Packages:twoP:Acquire:multiAqPeriodPeriodStr
	SetVariable MultiAqPeriodDelaySetVar,disable =1,pos={9.00,323.00},size={102.00,18.00},proc=NQ_MultiAqTimeSetVarProc
	SetVariable MultiAqPeriodDelaySetVar,title="Delay",fSize=12
	SetVariable MultiAqPeriodDelaySetVar,value=root:Packages:twoP:Acquire:multiAqPeriodDelayStr
	// Wave
	GroupBox MultModeWaveGrp disable =1,pos={114.00,252.00},size={113.00,97.00}
	GroupBox MultModeWaveGrp,title="                        "
	CheckBox MultiWaveCheck,disable =1,pos={147.00,254.00},size={45.00,15.00},proc=GUIPRadioButtonProcSetGlobal
	CheckBox MultiWaveCheck,title="Wave"
	CheckBox MultiWaveCheck,userdata="root:packages:twoP:acquire:multiAqTimeMode=1;MultiPeriodCheck;MultiTriggerCheck;"
	CheckBox MultiWaveCheck,value=0,mode=1
	Button MultiAqWaveEditButton,disable =1,pos={120.00,317.00},size={46.00,18.00},proc=NQ_MultiWaveEditButtonProc
	Button MultiAqWaveEditButton,title="Edit",fSize=10
	Button MultiAqWaveDeleteButton,disable =1,pos={172.00,317.00},size={47.00,18.00},proc=NQ_MultiWaveDeleteButtonProc
	Button MultiAqWaveDeleteButton,title="Delete",fSize=10
	PopupMenu MultiAqWavePopup,disable =1,pos={121.00,276.00},size={94.00,19.00},proc=NQ_MultiWaveWavePopMenuProc
	PopupMenu MultiAqWavePopup,title="Timing Wave:"
	PopupMenu MultiAqWavePopup,disable =1,mode=0,value=#"GUIPListObjs(\"root:packages:twoP:acquire:multiAqWaves\",1,\"!maq_seconds\",0,\"\\\\M1(no timing waves;\")+\"\\\\M1-);New Timing Wave\""
	TitleBox MultiAqWaveTitleBox,disable =1,pos={122.00,298.00},size={19.00,15.00},frame=0
	TitleBox MultiAqWaveTitleBox,variable=root:Packages:twoP:Acquire:multiAqWaveWaveStr
	// trigger
	GroupBox MultModeTriggerGrp,disable =1,pos={225.00,252.00},size={104.00,97.00}
	GroupBox MultModeTriggerGrp,title="                     "
	CheckBox MultiTriggerCheck,disable =1,pos={252.00,257.00},size={52.00,15.00},proc=GUIPRadioButtonProcSetGlobal
	CheckBox MultiTriggerCheck,title="Trigger"
	CheckBox MultiTriggerCheck,userdata="root:packages:twoP:acquire:multiAqTimeMode=2;MultiPeriodCheck;MultiWaveCheck;"
	CheckBox MultiTriggerCheck,value=0,mode=1
	SetVariable MultiAqTriggerNumSetVar,disable =1, pos={236.00,278.00},size={75.00,15.00}
	SetVariable MultiAqTriggerNumSetVar,title="Num",fSize=10
	SetVariable MultiAqTriggerNumSetVar,limits={2,inf,1},value=root:Packages:twoP:Acquire:multiAqTriggerNum
	// display time
	TitleBox MultiAqTimeToNextTitle, disable =1, pos={10.00,357.00},size={35.00,19.00},fSize=14
	TitleBox MultiAqTimeToNextTitle,frame=0
	TitleBox MultiAqTimeToNextTitle,variable=root:Packages:twoP:Acquire:multiAqTimeToNextStr
	ValDisplay multiAqProgressDisplay, disable =1,pos={11.00,382.00},size={321.00,43.00}
	ValDisplay multiAqProgressDisplay,frame=0
	ValDisplay multiAqProgressDisplay,limits={0,10,0},barmisc={10,30},highColor=(0,65280,0),lowColor=(65280,0,0)
	ValDisplay multiAqProgressDisplay,value=#"root:packages:twoP:acquire:multiAqiAq"
	// start
	Button MultiPreMakeButton, disable =1,pos={22.00,438.00},size={99.00,20.00},proc=NQ_MultiPreMakeProc
	Button MultiPreMakeButton,title="PreMake Waves"
	Button MultiStartButton, disable =1,pos={217.00,433.00},size={113.00,29.00},proc=NQ_MultiStartProc
	Button MultiStartButton,title="Start Multi"
	Button MultiStartButton,help={"Starts or Aborts a series of multiple scans"}
	Button MultiStartButton,userdata="Start Multi",fSize=16,fStyle=1
	Button MultiStartButton,fColor=(0,65280,0)
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Multi", "PopupMenu multiAqDataModePopUp;GroupBox MultModePeriodGrp;CheckBox MultiPeriodCheck;SetVariable MultiAqPeriodNumSetVar;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Multi", "SetVariable MultAqPeriodPeriodSetVar;SetVariable MultiAqPeriodDelaySetVar;GroupBox MultModeWaveGrp;CheckBox MultiWaveCheck;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Multi", "Button MultiAqWaveEditButton;PopupMenu MultiAqWavePopup;TitleBox MultiAqWaveTitleBox;GroupBox MultModeTriggerGrp;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Multi", "CheckBox MultiTriggerCheck;SetVariable MultiAqTriggerNumSetVar;TitleBox MultiAqTimeToNextTitle;ValDisplay multiAqProgressDisplay;")
	GUIPTabAddCtrls ("twoP_Controls", "SmodeTabControl", "Multi", "Button MultiPreMakeButton;Button MultiStartButton;")
	// set times
	NQ_SetTimes ()

end
 
 
 // ***************************************************************************************
// Lists channels that can be selected for scanning, marking already selected ones with checks
// last modified 2025/07/25 by Jamie Boyd
function/S twoP_listActiveChans (type)
	variable type
	switch (type)
	case 1:  //1 for images
		WAVE chanSelList = root:packages:twoP:acquire:imChanSelList
		WAVE/t chanList = root:packages:twoP:acquire:imChanList
		SVAR selChans = root:packages:twoP:acquire:selImageChanList
		break
	case 2: // 2 for ephys
		WAVE chanSelList = root:packages:twoP:acquire:ePhysChanSelList
		WAVE/t chanList = root:packages:twoP:acquire:ePhyschanList
		SVAR selChans = root:packages:twoP:acquire:selEphysChanList
		break
	endswitch

	string aChan, outList = ""
	variable iChan, nChans = dimsize (chanList, 0)
	for (iChan =0; iChan < nChans; iChan += 1)
		if (chanSelList[iChan][0] == 48) // checked, so active channel
			aChan = chanList [iChan] [1] + ":" +  num2str (iChan)
			if (FindListItem(aChan, selChans, ";") > -1)
				outList += "\\M1!"  +num2char(18)
			endif
			outList += aChan + ";"
		endif
	endfor
	return outList
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
				newName = twoP_autinc (newName, 0)
			endif
			// 3) check for overwriting
			NVAR overwriteWarnCheck = root:packages:twoP:acquire:overwriteWarnCheck
			if (overwriteWarnCheck)	// user wants to be warned about possible overwriting of waves
				if (dataFolderExists ("root:twoP_Scans:" + newName))
					string alertstr = "A scan with the name \"" + newName + "\" already exists.  You will be reminded again when you start the scan."
					doalert 0, alertstr
				endif
			endif
			SVAR NewScanName = root:Packages:twoP:Acquire:NewScanName
			NewScanName = newName
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
				For (NewScanName = twoP_autinc (NewScanName, 0);DataFolderExists("root:twoP_Scans:" + NewScanName);NewScanName = twoP_autinc (NewScanName, 1))
				endfor
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Checks to see if a string is autoincrement compatable and, optionally, increments it.
// Used when the autoincrement  wavenames checkbox is on.
// Last modified 2025/07/25 by Jamie Boyd - use sscanf
Function/s twoP_autinc (NewWaveName, inc)
	string NewWaveName
	variable inc		// if 0, don't increment., just check for compatibility. if 1, increment
	
	// see if wavename ends in an underscore followed by a  number
	string base 
	variable number
	sscanf NewWaveName, "%[A-Za-z,0-9]_%u", base, number
	if ((V_flag ==2) && (inc)) // if V_flag ==1, NewWaveName did not have a number, no need to increment
		number +=1
	endif
	sprintf NewWaveName "%s_%03d", base, number
	NVAR scanNum = root:Packages:twoP:Acquire:NewScanNum
	scanNum = number
	return NewWaveName
end



//******************************************************************************************************
// Updates list of scan channels, adding new channel or removing an existing channel
// Last Modified 2025/08/08 by Jamie Boyd
Function NQ_ScanChansPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			SVAR selChans = root:packages:twoP:acquire:selImageChanList
			if (FindListItem(popStr, selChans, ";") > -1)
				selChans = sortList (removeFromList(popStr, selChans, ";"), ";")
			else
				selChans = sortList (addlistItem(popStr, selChans, ";"), ";")
			endif
			break
	endswitch
	return 0
End

// *************************************************************************************************
// sets strings for Top and Botttom channel names used in ratio for live rois
// Last Modified 2025/07/10 by Jamie Boyd - new channel selection method
Function NQ_SetLiveChansPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	switch( pa.eventCode )
		case 2: // mouse up
			if (cmpStr (pa.ctrlName, "LiveROIRatioTopPopMenu")==0)
				SVAR chan=root:Packages:twoP:Acquire:LiveROItopChan
			elseif (cmpStr (pa.ctrlName, "LiveROIRatioBottomPopMenu")==0)
				SVAR chan=root:Packages:twoP:Acquire:LiveROIBottomChan
			endif
			chan = stringFromList (0, pa.popStr,":")
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End


//******************************************************************************************************
// Updates global string for selected ephys channels
// Last Modified 2025/07/10 by Jamie Boyd - new channel selection method
Function NQ_ephysChansProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			SVAR selChans = root:packages:twoP:acquire:selEphysChanList
			if (FindListItem(pa.popStr, selChans, ";") > -1)
				selChans = sortList (removeFromList(pa.popStr, selChans, ";"), ";")
			else
				selChans = sortList (addlistItem(pa.popStr, selChans, ";"), ";")
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Opens the microscope stage and focus panel using the chosen focus procedure
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
// Last Modified 2025/07/11 by Jamie Boyd  - new preferences panel
Function NQ_OtherScanSettingsProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Dowindow/F Scan_Settings_Prefs
			if (V_Flag ==1)
				return 1
			else
				twoP_PrefsMakePanel()
			endif
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
			GUIPTabSetAbleState ("twoP_Controls", "SmodeTabControl", "Zser", "NumZframesSetvar;",  ((popNum == 1)*2), 1)
			GUIPTabSetAbleState ("twoP_Controls", "SmodeTabControl", "Zser", "zStepSizeSetvar;",  ((popNum == 2)*2), 1)
			GUIPTabSetAbleState ("twoP_Controls", "SmodeTabControl", "Zser", "FirstZButton;",  ((popNum == 3)*2), 1)
			GUIPTabSetAbleState ("twoP_Controls", "SmodeTabControl", "Zser", "zFirstZSetVar;",  ((popNum == 3)*2), 1)
			GUIPTabSetAbleState ("twoP_Controls", "SmodeTabControl", "Zser", "LastZButton;",  ((popNum == 4)*2), 1)
			GUIPTabSetAbleState ("twoP_Controls", "SmodeTabControl", "Zser", "ZLastZSetVar;",  ((popNum == 4)*2), 1)
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Adjusts Z variables, based on selection in ZdjustPopMenu
// Last Modified 2025/07/21 by Jamie Boyd - getting zres from Stage proc folder
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
					SVAR stageProc = root:packages:twoP:Acquire:stageProc
					NVAR/z ZStepSizeMin = $"root:packages:" + stageProc + ":zRes"
					if (!(NVAR_Exists(ZStepSizeMin)))
						ZStepSizeMin = 1e-6
					endif
					ZStepSize = round (((LastZ - FirstZ)/NumZFrames)/ZStepSizeMin)*ZStepSizeMin
					LastZ = (NumZFrames * ZStepSize) + FirstZ
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
// Last Modified 2015/04/22 by Jamie Boyd
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
// Returns the physical memory usage of Igor,not the same as the experiment size, but proabbly more helpful
// Last Modified 2025/07/22 by Jamie Boyd - divided by 2^30 to return value in  GigaBytes
// Last Modified 2025/07/15 by Jamie Boyd - use Igor's memory usage from get info
Function NQ_GetExpSize ()
	
	return numberbykey("USEDPHYSMEM", IgorInfo(0), ":", ";")/2^30
end


//*************************************************************************************************************************************
// Puts updated memory usage in the global variable used for the setvariable on the twoP control panel
// Last Modified 2025/07/22 by Jamie Boyd - divided by 2^30 to return value in  GigaBytes
function NQ_UpdateExpSize ()
	NVAR expSize= root:packages:twoP:acquire:expSize
	expSize =  numberbykey("USEDPHYSMEM", IgorInfo(0), ":", ";")/2^30
end


//*************************************************************************************************************************************
// Sets the scanMode variable and various options in the control panel
// Last Modified 2025/07/13 by Jamie Boyd
Function NQ_SModeTabControlproc (TC_Struct) : TabControl
	STRUCT WMTabControlAction &tc_Struct
	
	if (TC_Struct.eventCode != 2)
		return 0
	endif
	
	string name = tc_Struct.ctrlName
	variable tab = tc_Struct.tab
	string tabWin = tc_Struct.win
	
	NVAR ScanMode = root:packages:twoP:Acquire:ScanMode
	NVAR isMulti = root:packages:twoP:acquire:multiModeIsMulti
	ScanMode = tab
	if (tab== 6) // multiaq - disable scan start button
		isMulti  = 1
		button AqStartButton disable = 2
		// make sure autoincrement is selected and run
		NVAR autincCheck = root:packages:twoP:acquire:autincCheck
		if (autIncCheck == 0)
			autincCheck =1
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
		button AqStartButton disable = 0
		isMulti  = 0
	endif
	//Set Times
	NQ_SetTimes ()
	return 0
end


//*************************************************************************************************************************************
// Sets the calculated pixel, line, frame, and experiment times based on the settings in the control panel
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
// Last Modified 2025/08/08 by Jamie Boyd
Function NQ_SetTimes ()
	
	// Globals for scan timing
	variable scanMode
	NVAR scanmodeG =  root:packages:twoP:Acquire:ScanMode
	if (scanmodeG == kMultiAq)
		NVAR multiAqTimeMode = root:packages:twoP:acquire:multiAqTimeMode
		scanMode = multiAqTimeMode
	else
		scanMode = scanmodeG
	endif
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
	
	// make sure sizes are adjusted for aspect ratio before calculating times.
	if (scanmode != kLineScan)
		NQ_AspectRatio (0)
	endif
	// Rough initial calculation of frame time before nasty tests for even point numbers
	if (FlybackMode == 0)
		PixWidthTotal = round (Pixwidth/DutyCycle) + round (Pixwidth*FlyBackProp/DutyCycle) ///@@@@@
	else
		PixWidthTotal = round (Pixwidth/DutyCycle)
	endif
	// Set line time by multiplying total pixels in a line by pixel time
	LineTime = (PixWidthTotal) * PixTime
	//Set Frame time by multiplying line time by number of lines
	FrameTime = (LineTime * PixHeight)
	// minimum number of frames to acquire at once so scanEndfunction not called too often
	NVAR minLiveFrameTime =  root:packages:twoP:acquire:minLiveFrameTime
	variable minLiveFrames = ceil (minLiveFrameTime/FrameTime)
	// Calculate total number of frames for nasty tests for even point numbers based on scan mode
	// Also check for minimun times for Z, Live, and avg modes. Time should only be changed slightly by tests for evenness
	// Also check for scan size - max is 2^24 points for a 24 bit counter
	variable NumFrames
	Switch (scanMode)
		case kTimeSeries:
			NVAR TFrames = root:Packages:twoP:Acquire:TSeriesFrames
			NVAR isCyclic = root:packages:twoP:Acquire:isCyclic
			if (TFrames * PixWidth * pixHeight > 2^kNQImageCounterSize)
				doAlert 1,  "Number of points is greater than the 2^24 bit counter for points/channel. You are entering the \"Cyclic Zone\". O.K.?"
				if (V_flag == 1) // Yes was clicked
					isCyclic =1
					NVAR bufferMult = root:packages:twoP:acquire:tSeriesBufferMult
					variable tbufferSize = ceil ((minLiveFrameTime * bufferMult)/FrameTime)
					TFrames = round (TFrames / tBufferSize) * tbufferSize
					SetVariable NumTSeriesFramesSetVar win = twoP_Controls, limits={0,inf,(tBufferSize)}
				else
					TFrames = floor (2^kNQImageCounterSize / (pixWidth * pixHeight))
					
				endif
			else
				isCyclic = 0
			endif
			numFrames = TFrames
			SetVariable NumTSeriesFramesSetVar win = twoP_Controls, limits={0,inf,1}
			break
		case kLiveMode:
			NVAR numLiveAvgFrames = root:Packages:twoP:Acquire:numLiveAvgFrames
			numLiveAvgFrames = max (numLiveAvgFrames, minLiveFrames)
			SetVariable LiveAvgFramesSetVar win=twoP_Controls, limits={minLiveFrames,inf,1}
			numFrames = numLiveAvgFrames
			break
		case ksingleImage:
			NVAR averageFrames = root:Packages:twoP:acquire:numAverageFrames
			NumFrames = averageFrames
			break
		case kZseries:
			NVAR NumZSeriesAvg = root:Packages:twoP:Acquire:NumZseriesAvg
			numZseriesAvg = max (numZseriesAvg, ceil (minLiveFrameTime/frametime))
			SetVariable zKalmanAvgSetvar win=twoP_Controls, limits={minLiveFrames,inf,1}
			NumFrames = NumZSeriesAvg
			break
		case kLineScan:
			NumFrames = 1
			NVAR isCyclic = root:packages:twoP:Acquire:isCyclic
			if ( PixWidth * pixHeight > 2^kNQImageCounterSize)
				doAlert 1,  "Number of points is greater than the 2^24 bit counter for points/channel. You are entering the \"Cyclic Zone\". O.K.?"
				if (V_flag == 1) // Yes was clicked
					isCyclic =1
					NVAR bufferSize = root:packages:twoP:acquire:lScanBufferSize
					bufferSize = round (minLiveFrameTime/lineTime)
					pixHeight = round (pixHeight/bufferSize) * bufferSize
					SetVariable LineScanHeightSetVar win= twoP_Controls, limits={2,inf,(bufferSize)}
				else
					pixHeight = floor (2^kNQImageCounterSize / pixWidth)
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
			setvariable Trig1SecsSetvar win = twoP_Controls, limits = {-inf, inf, FrameTime}
			setvariable Trig2SecsSetvar win = twoP_Controls, limits = {-inf, inf, FrameTime}
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
			setvariable Trig1SecsSetvar win = twoP_Controls, limits = {-inf, inf, LineTime*100}
			setvariable Trig2SecsSetvar win = twoP_Controls,limits = {-inf, inf, LineTime*100}
			break
	endSwitch
	// check ePhys situation
	variable ePhysChans =0
	if ((scanMode == kTimeSeries) || (scanMode == kLineScan)  || (scanMode == kEphysOnly))
		SVAR selChanList = root:packages:twoP:acquire:selEphysChanList
		if (itemsinlist (selChanList,";") > 0)
			NVAR ePhysFreq = root:Packages:twoP:Acquire:ePhysSampFreq
			variable ePhysRunTime = runTime
			if (scanMode == kEphysOnly)
				NVAR ephysOnlyTime = root:packages:twoP:acquire:ephysOnlyTime
				ePhysRunTime = ephysOnlyTime
			endif
			if (ePhysRunTime *ePhysFreq > 2^kNQEphysCounterSize)
				doAlert 0, "The selected scan time and ePhys sampling rate exceeds the 24 bit count for ePhys data collection."
				
			endif
		endif
	endif
	//Set times for triggers
	NVAR DelayFrames1 = root:Packages:twoP:Acquire:DelayFrames1
	NVAR DelayFrames2 = root:Packages:twoP:Acquire:DelayFrames2
	NVAR DelayLines1 = root:Packages:twoP:Acquire:DelayLines1
	NVAR DelayLines2 = root:Packages:twoP:Acquire:DelayLines2
	NVAR DelaySecs1 = root:Packages:twoP:Acquire:DelaySecs1
	NVAR DelaySecs2 = root:Packages:twoP:Acquire:DelaySecs2
	if (scanMode == kTimeSeries)
		DelaySecs1 = DelayFrames1 * FrameTime
		DelaySecs2 = DelayFrames2 * FrameTime
	elseif (ScanMode == kLineScan)
		DelaySecs1 =  DelayLines1 * LineTime
		DelaySecs2 =  DelayLines2 * LineTime
	endif
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
end


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
	
	NVAR xStartVoltsFS =root:packages:twoP:acquire:xStartVoltsFS
	NVAR xEndVoltsFS =root:packages:twoP:acquire:xEndVoltsFS
	NVAR yStartVoltsFS =root:packages:twoP:acquire:yStartVoltsFS
	NVAR yEndVoltsFS =root:packages:twoP:acquire:yEndVoltsFS
	
	// Adjust a value (as chosen in pomenu) to keep aspect ratio constant
	// NOTE: this code has not been updated for possibility that X magnification is different from Y magnification
	ControlInfo/w = twoP_Controls AspRatPopUp
	Switch (V_Value)
		case 1:	//Changing X-volts start
			XSV =  XEV -  ((Pixwidth * (YEV - YSV))/(PixHeight * AspectRatio))
			if (XSV < xStartVoltsFS)
				XSV = xStartVoltsFS
				PixWidth = round ((AspectRatio * pixheight * (XEV - XSV))/(YEV - YSV))
			endif
			break
		case 2:	// Changing X volts end
			XEV =  ((Pixwidth * (YEV - YSV))/(PixHeight * AspectRatio)) + XSV
			if (XEV > xEndVoltsFS)
				XEV = xEndVoltsFS
				PixWidth = round ((AspectRatio * pixheight * (XEV - XSV))/(YEV - YSV))
			endif
			break
		case 3:	// CHanging X pixels
			PixWidth = round ((AspectRatio * pixheight * (XEV - XSV))/(YEV - YSV))
			break
		case 4:		//Changing Y-volts Start
			YSV =  YEV - ((AspectRatio * PixHeight * (XEV - XSV))/PixWidth)
			if (YSV < yStartVoltsFS)
				YSV = yStartVoltsFS
				pixheight = round (((PixWidth * (yev - ysv))/(AspectRatio * (Xev - XSV))))
			endif
			break
		case 5:		// Changing Y volts end
			YEV =  ((AspectRatio * PixHeight * (XEV - XSV))/ PixWidth) + YSV
			if (YEV > yEndVoltsFS)
				YEV = yEndVoltsFS
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
// Last Modified 2025/08/26 by Jamie Boyd
Function NQ_AspRatPopUpProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			variable ableState
			ableState = SelectNumber((cmpStr (pa.popStr,  "Vary X Start") == 0) , 0, 2)
			
			GUIPTabSetAbleState ("twoP_Controls", "AcquireExamineTab", "Acquire;Examine", "XStartSetVar", ableState, 1)
			ableState = SelectNumber((cmpStr (pa.popStr,  "Vary X  End") == 0) , 0, 2)
			GUIPTabSetAbleState ("twoP_Controls", "AcquireExamineTab", "Acquire;Examine", "XEndSetVar", ableState, 1)
			ableState = SelectNumber((cmpStr (pa.popStr,  "Vary X Pix") == 0) , 0, 2)
			GUIPTabSetAbleState ("twoP_Controls", "AcquireExamineTab", "Acquire;Examine", "PixWidSetVar", ableState, 1)
			ableState = SelectNumber((cmpStr (pa.popStr,  "Vary Y Start") == 0) , 0, 2)
			GUIPTabSetAbleState ("twoP_Controls", "AcquireExamineTab", "Acquire;Examine", "YStartSetVar", ableState, 1)
			ableState = SelectNumber((cmpStr (pa.popStr,  "Vary Y End") == 0) , 0, 2)
			GUIPTabSetAbleState ("twoP_Controls", "AcquireExamineTab", "Acquire;Examine", "YEndSetVar", ableState, 1)
			ableState = SelectNumber((cmpStr (pa.popStr,  "Vary Y Pix") == 0) , 0, 2)
			GUIPTabSetAbleState ("twoP_Controls", "AcquireExamineTab", "Acquire;Examine", "PixHeightSetVar", ableState, 1)
			ableState = SelectNumber((cmpStr (pa.popStr,  "Free") == 0) , 0, 2)
			GUIPTabSetAbleState ("twoP_Controls", "AcquireExamineTab", "Acquire;Examine", "AspRatSetVar", ableState, 1)
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
			NVAR xStartVoltsFS =root:packages:twoP:acquire:xStartVoltsFS
			NVAR xEndVoltsFS =root:packages:twoP:acquire:xEndVoltsFS
			NVAR yStartVoltsFS =root:packages:twoP:acquire:yStartVoltsFS
			NVAR yEndVoltsFS =root:packages:twoP:acquire:yEndVoltsFS
			NVAR pixWidthFS = root:packages:twoP:acquire:pixWidthFS
			NVAR pixHeightFS = root:packages:twoP:acquire:pixHeightFS
			xStartVoltage = xStartVoltsFS
			xEndVoltage = xEndVoltsFS
			yStartVoltage = yStartVoltsFS
			yEndVoltage = yEndVoltsFS
			PixWidth = pixWidthFS
			PixHeight = pixHeightFS
			// Set Aspect Ratio to 1 and run Set Times
			AspectRatio = 1
			NQ_SetTimes()
	endswitch
	return 0
End

//*************************************************************************************************************************************
// Runs setTimes Procedure when (Bi-directional scanning) Turbo is checked/unchecked. The global variable, root:packages:twoP:acquire:FlybackMode,
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
			SVAR scanStr = $"root:twoP_Scans:" + theScan + ":" + theScan + "_info"
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
			WAVE/T ObjWave = root:packages:twoP:acquire:ObjWave
			curObj = pa.popStr
			NVAR curObjNum = root:packages:twoP:Acquire:CurObjNum
			curObjNum = pa.popNum -1 // -1 for one, not zero based popNum
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
// Functions for voltage waves have not been updated since pre-2009, but they look O.K.
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

// ***************************************************************************************************************************************
//----------------------------------------- functions that run when we start a scan --------------------------------------------------
// ***************************************************************************************************************************************


//******************************************************************************************************
// A structure to hold all the various globals so  that we can pass them easily between functions
// Last Modified:
// 2025/08/26 by Jamie Boyd 
// 2016/11/15 by Jamie Boyd - added support for separate back ground tasks for each channel plus merge

Structure NQ_ScanStruct
// general scan/run settings
	variable scanMode
	string newScanName
	string scanNote
	variable overWriteWarn
	variable inPutTrigger
	variable RunTime
	// image settings
	variable scanChans
	string selImageChanList		// list of channel name: aiChan pairs
	string onlyChansImage			// just ths channel names, stripped of ai number
	variable hasRGB					// if we are displaying RGB wave while acquiring, live mode, zMode, time Series will want to update RGB wave
	string scanWavePath			 // string containing paths to image waves to scan and channels on which to scan them, in NIDAQ format "root:twoP_Scans:Scan_000:Scan_000_ch1, 0/DIFF, -5, 5;
	string imageBoard
	variable numFrames
	variable pixHeight
	variable pixWidth
	variable xSV
	variable xEV
	variable YSV
	variable YEV
	// image scaling
	string obj
	variable objNum
	variable xImSize
	variable yImSize
	variable xPixSize
	variable yPixSize
	variable xScalStart
	variable yScalStart
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
	variable nCycFrames
	// Live mode specific 
	variable minLiveFrameTime
	variable liveHist
	variable liveRaw
	//live but also T-series for live ROI
	variable liveROI // set if doing live roi
	variable liveROISecs  // or 0 if not doing a live ROI
	variable liveRatio	// set if doing live ratio
	string liveRatioTopChan 	// name of top chan for live ratio, or "" if not doing ratio
	string liveRatioBottomChan
	variable ratioTopChanNum
	variable ratioBottomChanNum
	variable LROIleft
	variable LROItop
	variable LROIright
	variable LROIbottom
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
	string selEphysChanList		//list of channel name: aiChan pairs
	string onlyChansEphys
	string ePhysPath  // string containing paths to ePhys waves to scan and channels on which to scan them, in NIDAQ format
	variable ePhysFreq
	variable ePhysChans
	// multiMode
	variable isMulti
	variable multiAqiAq
	variable multiAqNaqs
	// triggers
	variable trigChans	// old-style bitwise, 1 for ctr 0, 2 for ctr 1, 3 for both
	variable trig1Secs	// seconds to delay, already converted from frames, or lines
	variable trig2Secs
	// voltage waves
	variable vOutChans
	string vOutWave1
	string vOutWave2
	variable vOutStart // "1 = on Scan Start;2=on Trig 1;"
endStructure



//******************************************************************************************************
// Reads values appropriate for this scan into the scanStructure, s
// Last Modified 2025/08/12 by Jamie Boyd
Function NQ_LoadScanStruct (s)
	STRUCT NQ_ScanStruct &s
	
	// scan mode
	NVAR scanMode = root:packages:twoP:Acquire:ScanMode
	s.ScanMode = scanMode
	// Scan name and general checks for imaging and/or ephys not applicable to live mode
	if (scanMode != kLiveMode)
		// multiAq stuff
		NVAR isMulti = root:packages:twoP:acquire:multiModeIsMulti
		s.isMulti = isMulti
		if (isMulti)
			NVAR multiAqNaqs = root:packages:twoP:acquire:multiAqNaqs
			NVAR multiAqiaq =root:packages:twoP:acquire:multiAqiaq
			s.multiAqiAq = multiAqiaq
			s.multiAqNaqs = multiAqNaqs
		endif
		// Scan Name
		SVAR newScanName = root:Packages:twoP:acquire:NewScanName
		s.NewScanName = NewScanName
		NVAR inPutTrigger = root:packages:twoP:acquire:inputTriggerCheck
		s.inPutTrigger= inPutTrigger
		NVAR overWriteWarn = root:packages:twoP:acquire:overwriteWarnCheck
		s.overWriteWarn = overWriteWarn
		notebook twoP_Controls#EXPNOTEBOOK getData=2
		s.scanNote = S_Value
		if (scanMode == kEphysOnly)
			NVAR runTime = root:Packages:twoP:acquire:EphysOnlyTime
		else
			NVAR runTime = root:Packages:twoP:acquire:RunTime
		endif
		s.runTime = runTime
	endif
	// Stage procedue
	SVAR StageProc = root:Packages:twoP:Acquire:StageProc
	s.StageProc = StageProc
	// settings for image scan, live mode or otherwise
	SVAR imageBoard = root:packages:twoP:acquire:imageBoard
	s.imageBoard = imageBoard
	if (scanMode != kEPhysOnly)
		SVAR selImageChanList = root:packages:twoP:acquire:selImageChanList
		s.selImageChanList = SelImageChanList
		variable iChan,nChans= itemsInlist (s.selImageChanList, ";")
		string aChan
		s.onlyChansImage = ""
		for (iChan=nChans-1; iChan >= 0; iChan -=1)
			aChan = stringFromList (0, stringFromList (iChan, s.selImageChanList, ";"), ":")
			s.onlyChansImage = AddListItem(aChan, s.onlyChansImage, ",")
		endfor
		NVAR hasRGB = root:packages:twoP:examine:RGB_hasRGB
		s.hasRGB = hasRGB
		// objective used for scaling
		SVAR obj = root:Packages:twoP:Acquire:curObj 
		NVAR objNum = root:Packages:twoP:Acquire:curObjNum
		s.obj = obj
		s.ObjNum = objNum
		// Reference PixWidth and height, voltage scaling based on scan mode
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
		s.XSV = XSV
		s.XEV= XEV
		s.YSV = YSV
		s.xImSize = xImSize
		s.xPixSize = xPixSize
		s.yImSize = yImSize
		s.yPixSize = yPixSize
		if (s.ScanMode != kLineScan)
			s.YEV = YEV
		endif
		// Image timing
		NVAR pixTime = root:packages:twoP:acquire:PixTime
		NVAR dutyCycle = root:Packages:twoP:Acquire:DutyCycle
		NVAR flybackMode =root:Packages:twoP:Acquire:FlyBackMode
		NVAR scanHeadDelay = root:packages:twoP:Acquire:ScanHeadDelay
		NVAR flybackProp = root:Packages:twoP:acquire:flybackProp
		NVAR pixWidthTotal = root:Packages:twoP:Acquire:PixWidthTotal
		NVAR frameTime = root:packages:twoP:Acquire:FrameTime
		NVAR lineTime = root:packages:twoP:Acquire:LineTime
		NVAR minLiveFrameTime =  root:packages:twoP:acquire:minLiveFrameTime
		NVAR scanIsCyclic = root:packages:twoP:Acquire:isCyclic
		s.pixTime = pixTime
		s.DutyCycle = DutyCycle
		s.FlybackMode = flybackMode
		s.scanHeadDelay = scanHeadDelay
		s.flybackProp = flybackProp
		s.pixWidthTotal = pixWidthTotal
		s.frameTime = frameTime
		s.lineTime = LineTime
		s.minLiveFrameTime = minLiveFrameTime
		s.scanIsCyclic = scanIsCyclic
		// Live ROI for live mode or time series
		if ((scanmode == kLiveMode) || (scanMode == kTimeSeries))
			NVAR liveROICheck =  root:Packages:twoP:Acquire:liveROICheck
			s.liveROI = liveROICheck
			if (liveROICheck)
				NVAR liveROIsecs = root:Packages:twoP:acquire:LiveROIsecs
				s.liveROISecs = liveROIsecs
				NVAR LROIleft = root:Packages:twoP:acquire:LROIL
				NVAR LROItop = root:Packages:twoP:acquire:LROIT
				NVAR LROIright = root:Packages:twoP:acquire:LROIR
				NVAR LROIbottom = root:Packages:twoP:acquire:LROIB
				s.LROIleft = LROIleft
				s.LROItop = LROItop
				s.LROIright = LROIright
				s.LROIbottom = LROIbottom
				NVAR liveROIRatioCheck = root:Packages:twoP:Acquire:liveROIRatioCheck
				if (liveROIRatioCheck)
					SVAR topChan = root:Packages:twoP:Acquire:liveROItopChan
					SVAR bottomChan = root:Packages:twoP:Acquire:liveROIBottomChan
					if ((cmpStr (bottomChan, "") ==0) || (cmpStr (bottomChan, "") ==0)) 
						liveROIRatioCheck = 0
					else
						s.liveRatioTopChan = topChan
						s.liveRatioBottomChan = bottomChan
					endif
				endif
				s.liveRatio = liveROIRatioCheck
			endif
		endif
	endif
	// board and channels for ePhys, triggers, and voltage waves
	if (((scanMode == kTimeSeries) || (scanMode == kLinescan)) || (scanMode == kephysOnly))
		SVAR ephysBoard = root:packages:twoP:acquire:ePhysBoard
		s.ePhysBoard = ephysBoard
		SVAR selePhysChanList = root:packages:twoP:acquire:selePhysChanList
		s.selePhysChanList = selePhysChanList
		nChans= itemsInlist (s.selePhysChanList, ";")
		s.onlyChansePhys = ""
		for (iChan=nChans-1; iChan >= 0; iChan -=1)
			aChan = stringFromList (0, stringFromList (iChan, s.selePhysChanList, ";"), ":")
			s.onlyChansEphys = AddListItem(aChan, s.onlyChansEphys, ",")
		endfor
		NVAR ePhysFreq = root:Packages:twoP:acquire:ePhysSampFreq
		s.ePhysFreq = ePhysFreq
		// triggers
		NVAR trig1Check = root:Packages:twoP:Acquire:trig1Check
		NVAR trig2Check = root:Packages:twoP:Acquire:trig2Check
		s.trigChans = (trig1Check) + 2*(trig2Check)
		if (trig1Check)
			NVAR DelaySecs = root:Packages:twoP:Acquire:DelaySecs1
			s.trig1Secs = DelaySecs
		endif
		if (trig2Check)
			NVAR DelaySecs = root:Packages:twoP:Acquire:DelaySecs2
			s.trig2Secs = DelaySecs
		endif
		// voltage pulse waves
		NVAR voltagePulseChans = root:packages:twoP:Acquire:voltagePulseChans
		s.vOutChans = voltagePulseChans
		if (voltagePulseChans & 1)
			controlinfo/w=twoP_Controls VoltagePulse1Popup
			s.VoutWave1 = S_Value
		endif
		if (voltagePulseChans & 2)
			controlinfo/w=twoP_Controls VoltagePulse2Popup
			s.VoutWave2 = S_Value
		endif
		if (voltagePulseChans)
			controlinfo/w=twoP_Controls VoltagePulsePopUp
			s.vOutStart = V_Value
		endif
	endif
	// switch for things specific to one scan mode
	switch (scanMode)
		case kLiveMode:	// Live mode specific - average frames and live histogram
			s.NewScanName = "LiveScan"
			NVAR liveHistCheck = root:Packages:twoP:acquire:liveHistCheck
			s.liveHist = liveHistCheck
			NVAR liveRawData =  root:packages:twoP:acquire:liveRawData
			s.liveRaw = liveRawData
			NVAR liveAvgFrames = root:Packages:twoP:acquire:numLiveAvgFrames
			s.numFrames =liveAvgFrames
			s.selEphysChanList = ""
			break
		case kTimeSeries:
			NVAR numFrames = root:Packages:twoP:Acquire:TSeriesFrames
			s.numFrames = numFrames
			break
		case kSingleImage:
			NVAR numFrames =  root:Packages:twoP:Acquire:NumAverageFrames
			s.numFrames = numFrames
			s.selEphysChanList =""
			break
		case kLineScan:
			s.NumFrames = 1
			SVAR LSLinkWaveStr= root:packages:twoP:Acquire:lsLinkWaveStr
			s.LSLinkWave = LSLinkWaveStr
			s.selEphysChanList = ""
			break
		case kZseries:
			NVAR numFrames = root:Packages:twoP:Acquire:NumZseriesFrames
			s.numFrames = numFrames
			NVAR zFirstZ = root:Packages:twoP:Acquire:ZFirstZ 
			NVAR zstepSize = root:Packages:twoP:Acquire:ZStepSize
			NVAR zAvg = root:Packages:twoP:Acquire:NumZseriesAvg
			s.zpos = zFirstZ
			s.zStepSize = zStepSize
			s.zAvg = zAvg
			s.selEphysChanList = ""
			break
	endswitch
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
				s.newScanName = twoP_autinc (s.newScanName, 1)
			elseif (V_Flag == 3) // cancel scanning was clicked
				//doAlert 0, "Scanning will be canceled."
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
// Last Modified 2025/08/08 by Jamie Boyd
Function NQ_ScanNoter (s)
	STRUCT NQ_ScanStruct &s
	
	string/G $"root:twoP_Scans:" + s.newScanName + ":" + s.newScanName + "_info"= ""
	SVAR/Z NoteStr = $"root:twoP_Scans:" + s.newScanName + ":" + s.newScanName + "_info"
	if (!(SVAR_Exists(NoteStr)))
		return 1
	endif
	string tempStr // used for printf and other things
	if (s.scanMode != kLiveMode)
		// Experiment note - sanitize by removing reserved characters
		tempStr = s.scanNote
		variable iChar, nChars = strlen (tempStr)
		For (iChar = 0; iChar < nChars; iChar +=1)
			if  (char2num (tempStr [iChar]) == 58)
				tempStr [iChar, iChar]= "="
			elseif (char2num (tempStr [iChar]) == 13)
				tempStr [iChar, iChar]= ";"
			endif
		endfor
		
		NoteStr += "ExpNote:" + tempStr + "\r"
	endif
	// Scan Type - easier for user to read than the scan mode numeric code
	variable scanMode = s.scanMode
	switch (scanMode)
		case kLiveMode:
			NoteStr += "Scan Type:Live Scanning\r"
			break
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
	// Time, in Igor Format, when the scan was started, i.e., now
	sprintf tempStr, "ExpTime:%.0f\r",  datetime	// use sprintf to keep enough precision
	NoteStr +=  tempStr
	
	// image specific stuff
	// image channels, bitwise, 1 for ch1, 2 for ch2, 3 for both channels
	variable imChans=0
	if (scanMode == kEphysOnly)
		NoteStr += "ImChans:0\r"
		// channel descriptions, for forwards compatibility
		NoteStr += "imChanDesc:\r"
	else
		if (WhichListItem ("ch1", s.OnlyChansImage,";", 0,0) > -1)
			imChans += 1
		endif
		if (WhichListItem ("ch2", s.OnlyChansImage,";", 0,0) > -1)
			imChans += 2
		endif
		NoteStr += "ImChans:" + num2str (imChans) + "\r"
		// channel descriptions, for forwards compatibility
		NoteStr += "imChanDesc:" + s.OnlyChansImage + "\r"
		// image channel descriptions
		// Image size and Pixel scaling
		sprintf tempStr, "Xoffset:%.8f\r", s.xScalStart 
		noteStr += tempStr
		sprintf tempStr, "Yoffset:%.8f\r", s.yScalStart 
		noteStr += tempStr
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
		sprintf tempStr, "XSV:%.8f\r", s.XSV 
		noteStr += tempStr
		sprintf tempStr, "XEV:%.8f\r", s.XEV 
		noteStr += tempStr
		if (scanMode == kLineScan)
			sprintf tempStr, "YLSV:%.8f\r", s.YSV 
			noteStr += tempStr
			if ((cmpstr (s.LSLinkWave, "Don't Link")) == 0)
				NoteStr +=  "linkWave:Not Linked\r"
			else
				NoteStr +=  "linkWave:" + s.LSLinkWave + "\r"
			endif
		else // not a line scan
			sprintf tempStr, "YSV:%.8f\r", s.YSV 
			noteStr += tempStr
			sprintf tempStr, "YEV:%.8f\r", s.YEV 
			noteStr += tempStr
		endif
	endif
	// stage position
	noteStr += "Xpos:" + num2str (s.xPos) + "\r"
	noteStr += "Ypos:" + num2str (s.yPos) + "\r"
	noteStr += "Zpos:" + num2str (s.zPos) + "\r"
	// was ePhys also collected?
	variable ePhysChans=0
	if (WhichListItem ("ch1", s.selEphysChanList,";", 0,0) > -1)
		ephysChans += 1
	endif
	if (WhichListItem ("ch2", s.selEphysChanList,";", 0,0) > -1)
		ePhysChans += 2
	endif
	notestr += "ephys:" + num2str (ePhysChans) + "\r"
	NoteStr += "ePhysChanDesc:" + s.selEphysChanList + "\r"
	// Need to add extra info for ePhys?
	return 0
end



//******************************************************************************************************
// Fitting function used to make the horizontal scanwave out of a series of cosine components, with phase offset
// Last Modified 2025/08/19 by Jamie Boyd
Function CosExpansionPh(w,x) : FitFunc
	Wave w
	Variable x

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(x) = H1 * (cos (x+ph)) + H3 * (cos (3 * (x+ph))) + H5 * (cos (5 * (x+ph))) + offset
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 5
	//CurveFitDialog/ w[0] = H1
	//CurveFitDialog/ w[1] = H3
	//CurveFitDialog/ w[2] = H5
	//CurveFitDialog/ w[3] = offset
	//CurveFitDialog/ w[4] = phase rotation, in radians
	return w[0] * (cos (x+w[4])) + w[1] * (cos (3 *( x + w[4]))) + w[2] * (cos (5 * (x+w[4]))) + w[3]
End


//******************************************************************************************************
// Makes the X and Y scan waves output to the Galvos by the Analog out channels on the image board for the various scan types
//  returns 1 if an error ocurred, else 0
// Last Modified 2025/08/25 by Jamie Boyd
Function NQ_MakeGalvoScanWaves (s)
	STRUCT NQ_ScanStruct &s

	variable anError
	try
		// Check input for errors
		// scan mode can not be ePhysOnly - not an error, just exit
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
		//Pixel Time needs to be greater than 1/analog out max frequency (2.5 MHz for S-series boards) , probably a generous maximum is .01 sec
		anError = ((s.pixTime < 0.4e-06) || (s.pixTime > 0.1))
		AbortOnValue anError, 7
		// Make Horizontal wave by fitting a cosine function to data collection region and 1/2 the turnaround
		// values for fitting curve
		variable scanpnts = round (s.Pixwidth/s.DutyCycle)						// the collecting data direction of laser wave, with turnaraound
		variable turnAroundPts = scanpnts-s.Pixwidth							// when the laser is reversing directtion, not collecting data
		variable FBpnts =  round (s.Pixwidth*s.FlyBackProp/s.DutyCycle)			// for not-bidirectional,the non-collecting data direction of laser wave, with turnarond
		// fit a cosine function for turnaround and data collection region
		// cosine function goes from 0 to 1 to 0 over the range -pi/2 to pi/2
		// for biderectional scanning, both sides will be linearized, starting from 0 on the left side, ending at 0 on the right side
		// make a straight line to constrain cosine fit to be linear over the scanning region where we collect data
		// straight line segment x range is based on duty cycle, y range is based on start and end voltages for linear range of scanning
		variable line_x1= (pi/2) - (pi* s.DutyCycle)/2
		variable line_x2 = (pi/2) + (pi* s.DutyCycle)/2
		// formula for line, in voltage versus radians
		variable slope = (s.xev-s.xsv)/(line_x2-line_x1)
		variable intercept = s.xsv - slope * line_x1
		make/o/n = (s.PixWidth) root:Packages:twoP:acquire:StraightLine
		WAVE StraightLine =  root:Packages:twoP:acquire:StraightLine
		SetScale /I x (line_x1), (line_x2),"", StraightLine
		StraightLine =  slope * x + intercept
		
		
		WAVE Scan_coefs =  root:packages:twoP:acquire:Scan_Coefs 	//Coeficient wave for Sine curve fitting will hold the fitted values
		variable cyclePnts											// points in a full cycle of X galvo movement
		variable ScanPnts_total										// total number of points in X-galvo and Y-galvo waves, for a whole frame
		variable cos_start											// starting position, in radians, of cosine segment
		variable cos_End											// ending  position, in radians, of cosine segment
		variable verTurnAroundPts									// points for vertical turnaround
		if (s.flybackMode)
			// if bi-directional, both sides of the cosine segment are linearized
			cyclePnts = 2*scanPnts
			ScanPnts_total = scanPnts * s.PixHeight
			make/o/n= (cyclePnts) root:packages:twoP:acquire:tempCos	// scanPnts includes turnaround points plus linearized points
			WAVE tempCos = root:packages:twoP:acquire:tempCos			
			cos_start = (- pi* ((1-s.dutyCycle)/2))						// starts the cosine section at start of turnaround
			setscale/p x cos_start, (pi/scanPnts), "rad", tempCos
			// translate scan head delay in seconds into radians
			variable galvoRadians = ((pi/((s.pixWidth*s.pixTime)/s.dutyCycle)) * s.ScanHeadDelay)
			Scan_coefs [0] = -(s.XEV - s.XSV)/2		// starting amplitude of H1. Setting it will make curve fitting faster
			Scan_coefs [3] = (s.XEV + s.XSV)/2		// offset. Setting it will make curve fitting faster
			Scan_Coefs [4] =0						// fit with phase held to 0, then add phase 
			FuncFit/Q/H="00001"/w=2 CosExpansionPh Scan_coefs StraightLine
			Scan_Coefs [4] = GalvoRadians			// add the phase for galvo rotation to fitting coeficients
			tempCos = CosExpansionPh (Scan_coefs,x)
		else
			// not bi-directional, just one side is linearized, other side may have a steeper slope
			// Our cosine section is not symetrical around 0, we do each side separately
			cyclePnts = scanpnts + FBpnts
			ScanPnts_total = cyclePnts * s.PixHeight
			make/o/n= (cyclePnts) root:packages:twoP:acquire:tempCos
			WAVE tempCos = root:packages:twoP:acquire:tempCos
			// we want to end at pi to fit the linear stage 
			cos_End = pi
			cos_Start = pi- (scanpnts + FBpnts)*(pi/scanpnts)
			setscale x cos_Start, cos_End, "rad", tempCos
			Scan_coefs [0] = -(s.XEV - s.XSV)/2		// starting amplitude of H1. Setting it will make curve fitting faster
			Scan_coefs [3] = (s.XEV + s.XSV)/2		// offset. Setting it will make curve fitting faster
			Scan_Coefs [4] =0						// fit with phase held to 0, we add phase with rotation
			FuncFit/Q/H="00001"/w=2 CosExpansionPh Scan_coefs StraightLine
			tempCos = CosExpansionPh (Scan_coefs,x)
			// now the un-linearized flyback side - get min from tempCos (0) and max from tempCos (pi)
			variable gMin = tempCos [scanpnts + FBpnts -1]		// point position of 0
			variable gMax= tempCos [FBpnts]					// point position of pi
			variable scal = (gMax-gMin)/2
			variable offset = (gMax + gMin)/2
			tempCos[0, FBpnts-1] = cos (x/s.flybackProp) *scal + offset
			rotate round((turnAroundPts/2) - (s.ScanHeadDelay/s.pixTime)),tempCos // translate scan head delay in seconds into pixels and include
		endif
		// copy cosine segment into horizontal wave as many times as is needed
		if (s.scanMode == kLineScan)	// Line Scan,onlyone copy needed
			make/o/n= (cyclePnts) root:packages:twoP:acquire:HorWave
			WAVE HorWave = root:packages:twoP:acquire:HorWave
			horwave = tempCos
		else //Image
			make/o/n= (Scanpnts_total) root:packages:twoP:acquire:HorWave
			WAVE HorWave = root:packages:twoP:acquire:HorWave
			HorWave = tempCos [mod (p,(cyclePnts))]
		endif
		SetScale/p x 0, (s.pixtime) ,"", HorWave		// pix time sets analog out clock, which controls ai and line gate clock
		// Vertical wave not neded for line scan
		if (s.scanMode != kLineScan)
			// Make vertical wave, it starts with vertical flyback
			make/o/n = (Scanpnts_total) root:packages:twoP:acquire:VerWave
			WAVE VerWave = root:packages:twoP:acquire:VerWave
			SetScale/p x 0, (s.pixtime) ,"", verWave
			// do the vertical flyback in one horizontal flyback and turnaround (uni-directional) or one turnaround (bi-directional)
			if (s.flybackMode)
				verTurnAroundPts = turnAroundPts
				cyclePnts = scanPnts
			else
				verTurnAroundPts = fbPnts + turnAroundPts
				cyclePnts = scanPnts + fbPnts
			endif
			variable voltOut, voltDiv = (s.YEV - s.YSV)/(s.PixHeight-1)
			variable iPnt
			scal = -(s.yev - s.ysv)/2
			offset = (s.yev + s.ysv)/2
			VerWave=NaN
			// re-use tempcos for vertical flyback
			redimension/n=(verTurnAroundPts) tempCos
			setscale/I x -pi, 0, "rad", tempCos
			tempCos = cos (x)*scal + offset
			// copy tempCos to first points of verWave
			VerWave[0, verTurnAroundPts-1]=tempCos
			// finish first cycle with pixWidth, then  do cycle at a time
			VerWave[verTurnAroundPts,verTurnAroundPts + s.pixWidth-1]=s.YSV
			for (iPnt = verTurnAroundPts + s.pixWidth, voltOut = s.YSV + voltDiv ; iPnt < Scanpnts_total-verTurnAroundPts ; iPnt += cyclePnts,voltOut += voltDiv)
				VerWave [iPnt, iPnt + cyclePnts -1]=voltOut
			endfor
			SetScale/p x 0, (s.pixtime) ,"", verWave
		endif
		return 0  //successs
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
		return 1 //failure
	endtry
end

//******************************************************************************************************
// Makes the image waves for scanning in a new folder, for all the different scan modes.
// Sets string for channels and paths to created waves in s.scanWavePath
// Last Modified 2025/08/29 by Jamie Boyd
Function NQ_MakeImageScanWaves (s)
	STRUCT NQ_ScanStruct &s

	string baseName = "root:twoP_Scans:" + s.newScanName +":" +  s.newScanName + "_"
	s.scanWavePath = ""
	WAVE/T chanList = root:packages:twoP:acquire:imChanList
	string ai_chanName, ai,chanName, type, range, scaling, offset
	variable iChan, nChans = itemsInList(s.selImageChanList)

	// make the RGB wave,
	WAVE/Z RGBWave= root:packages:twoP:examine:RGBwave
	if (waveExists (RGBWave))
		redimension/n = ((s.PixWidth), (s.PixHeight), 3) RGBWave
	else
		make/b/u/n = ((s.PixWidth), (s.PixHeight))  root:packages:twoP:examine:RGBwave
		WAVE RGBWave= root:packages:twoP:examine:RGBwave
	endif
	SetScale/p x s.xScalStart, s.xPixSize, "m", RGBWave
	SetScale/p y s.yScalStart, s.yPixSize, "m", RGBWave

	// make live ROI ratio for livemode or time series
	variable roiPoints =round(s.liveROISecs/s.FrameTime)
	if ((s.liveRatio) && ((s.ScanMode == kLiveMode) || (s.ScanMode== kTImeSeries)))
		WAVE/Z LroiWave_ratio =  root:Packages:twoP:acquire:LroiWave_ratio
		if (WaveExists(LroiWave_ratio))
			redimension/n= (roiPoints) LroiWave_ratio
		else
			make/n= (roiPoints) root:Packages:twoP:acquire:LroiWave_ratio
			WAVE LroiWave_ratio =  root:Packages:twoP:acquire:LroiWave_ratio
		endif
	endif

	// make or resize wave references for thread data according to scan type
	variable numThreadWaves, numExtra=0
	Switch (s.scanMode)
		case kLiveMode:
			numThreadWaves = 5
			break
		case kTimeSeries:
			numThreadWaves = 4
			break
	endswitch

	if (s.liveRatio)
		numExtra = 1	// extra wave for live ROI ratio
	endif

	WAVE/WAVE/Z threadData = root:packages:twoP:acquire:threadData
	if (WaveExists(threadData))
		redimension/n=(numThreadWaves*nChans + 1 + numExtra) threadData
	else
		make/WAVE/n=(numThreadWaves*nChans + 1 + numExtra) threadData
		WAVE/WAVE threadData = root:packages:twoP:acquire:threadData
	endif

	// add extra waves, not done per channel, at the end of the threadData wave
	threadData [numThreadWaves * nChans] = RGBWave		//we don't use this now, but better RGB is on the todo list

	if (s.liveRatio)
		threadData [numThreadWaves * nChans + 1] = LroiWave_ratio
	endif
	
	// adjust sizes for timeSeries
	if (s.scanMode == kTimeSeries)
		NVAR bufferMult = root:packages:twoP:acquire:tSeriesBufferMult
		if (s.scanIsCyclic)
			s.nCycFrames  = ceil ((s.minLiveFrameTime*bufferMult)/s.FrameTime)
		else
			s.nCycFrames  =  ceil (s.minLiveFrameTime/s.FrameTime)
		endif
		s.numFrames = round (s.numFrames / s.nCycFrames) * s.nCycFrames
	endif
	
	// fillout NI-DAQ info for scan command, and make waves according to scan mode
	for (iChan=0; iChan < nChans; iChan +=1)
		ai_chanName = stringFromList(iChan, s.selImageChanList,";")
		ai = stringFromList (1, ai_chanName, ":")
		chanName = stringFromList (0, ai_chanName, ":")
		type = chanList [str2num(ai)] [2]
		range =  chanList [str2num(ai)] [3]
		Scaling = chanList [str2num(ai)] [4]
		Offset = chanList [str2num(ai)] [5]
		
		Switch (s.Scanmode)
			case kLiveMode:
				// make the 1D wave that we directly scan into
				s.scanWavePath += "root:packages:twoP:acquire:Acq1D_" + chanName
				if (s.FrameTime > s.minLiveFrameTime) // collect one frame at a time, to insert into stack
					Variable/G root:packages:twoP:acquire:liveAvg_nFrames = s.numFrames
					Variable/G root:packages:twoP:acquire:liveAvg_iFrame = 0
					WAVE/Z Acq1D = $"root:packages:twoP:acquire:Acq1D_" + chanName
					if (waveExists (acq1D))
						redimension/w/n= (s.PixWidth * s.PixHeight) acq1D
					else
						make/o/w/n=(s.PixWidth * s.PixHeight) $"root:packages:twoP:acquire:Acq1D_" + chanName
						WAVE/Z Acq1D = $"root:packages:twoP:acquire:Acq1D_" + chanName
					endif
					setscale/p x 0, (s.pixTime), "s" Acq1D
					fastop Acq1D =0
				else  // collect data for numFrames frames at a time, assemble into stack and average
					// make the 1D wave that we directly scan into
					WAVE/Z Acq1D = $"root:packages:twoP:acquire:Acq1D_" + chanName
					if (waveExists (acq1D))
						redimension/n= (s.PixWidth * s.PixHeight * s.numFrames) Acq1D
					else
						make/o/w/n=(s.PixWidth * s.PixHeight * s.numFrames) $"root:packages:twoP:acquire:Acq1D_" + chanName
						WAVE/Z Acq1D = $"root:packages:twoP:acquire:Acq1D_" + chanName
					endif
					setscale/p x 0, (s.pixTime), "s" Acq1D
					fastop Acq1D =0
				endif
				threadData[5*iChan] = Acq1D
				// make the 3D wave we copy linear data into and process into the 2D frame we display
				WAVE/Z Acq3D = $"root:packages:twoP:acquire:Acq3D_" + chanName
				if (waveExists (Acq3D))
					redimension/n= (s.PixWidth, s.PixHeight, s.numFrames) Acq3D
				else
					make/o/w/u/n=(s.PixWidth, s.PixHeight, s.numFrames) $"root:packages:twoP:acquire:Acq3D_" + chanName
					WAVE/Z Acq3D = $"root:packages:twoP:acquire:Acq3D_" + chanName
				endif
				fastop Acq3D =0
				threadData[5*iChan+1] = Acq3D
				// make the 2D wave we display - it lives in a regular twoPScans folder named LiveScan. This is what Examine tab sees as a scan
				WAVE/Z scanWave= $baseName + chanName
				if (waveExists (scanWave))
					redimension/w/u/n = ((s.PixWidth), (s.PixHeight)) scanWave
				else
					make/w/u/n = ((s.PixWidth), (s.PixHeight)) $baseName + chanName
					WAVE scanWave= $baseName + chanName
				endif
				SetScale/P x s.xScalStart, s.XPixSize, "m", scanWave
				SetScale/P Y s.yScalStart, s.YPixSize, "m", scanWave
				fastop scanWave =0
				threadData[5*iChan+2] = scanWave
				// HIst wave
				if (s.liveHIst)
					WAVE/Z histWave = $"root:Packages:twoP:Examine:HistWave" + chanName
					if (!(WAVEExists(histWave)))
						make/o/n = (2^kNQimageBits) $"root:Packages:twoP:Examine:HistWave" + chanName
						WAVE HistWave = $"root:Packages:twoP:Examine:HistWave" + chanName
						setscale/p x, 0, 1	, "", HistWave
					endif
					threadData[5*iChan+3] = histWave
				endif
				// ROI wave
				if (s.liveROI)
					WAVE/Z LROIWave = $"root:Packages:twoP:acquire:LroiWave_" + chanName
					if (WaveExists(LROIWave))
						redimension/n= (roiPoints) LROIWave
					else
						make/n= (roiPoints) $"root:Packages:twoP:acquire:LroiWave_" + chanName
						WAVE LROIWave = $"root:Packages:twoP:acquire:LroiWave_" + chanName
					endif
					threadData[5*iChan+4] = LROIWave
					if (s.liveRatio)
						if (cmpStr (chanName, s.liveRatioTopChan) ==0)
							s.ratioTopChanNum = 5*iChan+4
						elseif (cmpStr (chanName, s.liveRatioBottomChan) ==0)
							s.ratioBottomChanNum = 5*iChan+4
						endif
					endif
				endif
				break
			case kTimeSeries:
				// make scan wave. In non-cyclic, we acquire into it directly. In cyclic, we copy into it from repeated scan hook. Make it signed - position 0. 
				WAVE/Z Acq1D= $baseName + chanName
				if (waveExists (Acq1D))
					redimension/w/n = (s.PixWidth * s.PixHeight * s.numFrames) Acq1D
				else
					make/w/n = (s.PixWidth * s.PixHeight * s.numFrames) $baseName + chanName
					WAVE Acq1D= $baseName + chanName
				endif			
				setscale/p x 0, (s.pixTime), "s" Acq1D
				fastop Acq1D =0
				threadData[numThreadWaves*iChan] = Acq1D
				if (s.scanIsCyclic)
					// make small 1D acquisition wave - position 1
					s.scanWavePath += "root:packages:twoP:acquire:Acq1D_" + chanName
					WAVE/Z Acq1D_small = $"root:packages:twoP:acquire:Acq1D_" + chanName
					if (waveExists (Acq1D_small))
						redimension/n=(s.PixWidth * s.PixHeight * s.nCycFrames) Acq1D_small
					else
						make/o/w/n=(s.PixWidth * s.PixHeight * s.nCycFrames) $"root:packages:twoP:acquire:Acq1D_" + chanName
						WAVE/Z Acq1D_small = $"root:packages:twoP:acquire:Acq1D_" + chanName
					endif
					setscale/p x 0, s.pixTime, "s" Acq1D_small
					fastop Acq1D_small =0
					threadData[numThreadWaves*iChan +1] = Acq1D_small
				else
					s.scanWavePath += baseName + chanName // acquire directly into scan wave with non-cyclic
				endif
				
				// make 2D wave for display - same for both cyclic and non-cyclic - pos 2
				WAVE/Z scanGraphChanWave=root:$"root:packages:twoP:examine:scanGraph_" + chanName
				if (waveExists (scanGraphChanWave))
					redimension/w/u/n= (s.PixWidth * s.PixHeight) scanGraphChanWave
				else
					make/o/w/u/n=(s.PixWidth * s.PixHeight) $"root:packages:twoP:examine:scanGraph_" + chanName
					WAVE/Z scanGraphChanWave =$"root:packages:twoP:examine:scanGraph_" + chanName
				endif
				SetScale/P x (s.xScalStart), (s.XPixSize), "m", scanGraphChanWave
				SetScale/P Y (s.yScalStart), (s.YPixSize), "m", scanGraphChanWave
				fastop scanGraphChanWave =0
				threadData[numThreadWaves*iChan + 2] = scanGraphChanWave
				// ROI wave - pos 3
				if (s.liveROI)
					WAVE/Z LROIWave = $"root:Packages:twoP:acquire:LroiWave_" + chanName
					if (WaveExists(LROIWave))
						redimension/n= (roiPoints) LROIWave
					else
						make/n= (roiPoints) $"root:Packages:twoP:acquire:LroiWave_" + chanName
						WAVE LROIWave = $"root:Packages:twoP:acquire:LroiWave_" + chanName
					endif
					threadData[numThreadWaves*iChan + 3] = LROIWave
					if (s.liveRatio)
						if (cmpStr (chanName, s.liveRatioTopChan) ==0)
							s.ratioTopChanNum = numThreadWaves*iChan+3
						elseif (cmpStr (chanName, s.liveRatioBottomChan) ==0)
							s.ratioBottomChanNum = numThreadWaves*iChan+3
						endif
					endif
				endif
				break
			
		endswitch
			
		s.scanWavePath += ", " + ai + "/" + type + ", -" +  range + ", " + range + ", " + scaling + ", " + offset + ";"

	endfor
end



//******************************************************************************************************
//****************Code that does scaning/calls NI functions*********************************
//******************************************************************************************************

// ***********************************************************************
// Does a hardware reset of the NI boards and sets up image board shutter. Sets trigger outputs on ephys board to low state
// Last Modified 2025/08/11 by Jamie boyd
Function twoP_reSetBoards ()
	SVAR ImageBoard = root:packages:twoP:acquire:ImageBoard
	SVAR ephysBoard = root:packages:twoP:acquire:ephysBoard
	NVAR shutterTaskNum = root:packages:twoP:Acquire:shutterTaskNum
	NVAR shutterOpen = root:Packages:twoP:acquire:shutterOpenLevel
	NVAR triggerTaskNum =  root:packages:twoP:Acquire:triggerTaskNum
	NVAR Trig1Polarity = root:packages:twoP:acquire:Trig1Polarity
	NVAR Trig2Polarity = root:packages:twoP:acquire:Trig2Polarity
	
	// clear error message buffer
	for (;(cmpStr (fdaqmx_errorString(), "") != 0);)
	endfor
	
	try
		AbortOnValue fDAQmx_ResetDevice(ImageBoard), 0
		// configure shutter on port 0/line 0 and set it closed
		DAQmx_DIO_Config /DEV=ImageBoard/Dir=1/LGRP=1  "/" + ImageBoard + "/port0/line0" ;AbortOnRTE
		shutterTaskNum = V_DAQmx_DIO_TaskNumber
		AbortOnValue fDAQmx_DIO_Write(ImageBoard, shutterTaskNum, (!(shutterOpen))), 0
		// configure trigger input task on port 0/line 1
		DAQmx_DIO_Config /DEV=ImageBoard/DIR= 0/LGRP=1  "/" + ImageBoard +"/port0/line1";AbortOnRTE
		triggerTaskNum = V_DAQmx_DIO_TaskNumber
		if (CmpStr (ephysBoard, "") == 0)
			AbortOnValue fDAQmx_ResetDevice(ePhysBoard), 0
			// set an initial dummy counter task just to put outputs in low state
			DAQmx_CTR_OutputPulse /DEV=ephysBoard/SEC={1e-6, 1e-6} /IDLE=(Trig1Polarity) /NPLS=1/STRT=0 (0) ; AbortOnRTE
			AbortOnValue fDAQmx_CTR_Finished(ephysBoard, 0), 0
			DAQmx_CTR_OutputPulse /DEV=ephysBoard/SEC={1e-6, 1e-6} /IDLE=(Trig2Polarity) /NPLS=1/STRT=0 (1) ; AbortOnRTE
			AbortOnValue fDAQmx_CTR_Finished(ephysBoard, 1), 0
		endif
	catch
		Print "Error resetting shutter on image board or triggers on ephys board:" +  fDAQmx_ErrorString()
		return 1
	endtry
end






		
//		case kSingleImage:	// Averaging Frames (time series with averaging at the end)
//			case kTimeSeries:	// time series
//				
//				
//					redimension/n = ((s.PixWidth), (s.PixHeight))root:packages:twoP:examine:scanGraph_ch1,root:packages:twoP:examine:scanGraph_ch2
//					SetScale/P x s.xPos, s.XPixSize, "m", root:packages:twoP:examine:scanGraph_ch1, root:packages:twoP:examine:scanGraph_ch2
//					SetScale/P x s.yPos, s.YPixSize, "m", root:packages:twoP:examine:scanGraph_ch1, root:packages:twoP:examine:scanGraph_ch2
//					//SetScale/P x 0, 1e-06, "", root:packages:twoP:examine:scanGraph_ch2
//					if (s.scanIsCyclic)
//						NVAR bufferSize = root:packages:twoP:acquire:tSeriesBufferSize
//						s.numFrames = ceil (s.numFrames / bufferSize) * bufferSize
//					endif
//					For (theChannel = 0; theChannel < nChannels; theChannel +=1)
//						if (1)//(s.ScanChans) & (2^theChannel))	// Then the current channel is selected
//							// don't kill this wave
//							dontKill +=  s.NewScanName + "_ch" + num2str (theChannel + 1) + ";"
//							//Make WaveName
//							theWaveName = "root:twoP_Scans:" +  s.NewScanName + ":" + s.NewScanName + "_ch" + num2str (theChannel +1)
//							// Make the wave
//							WAVE/Z theWave = $theWaveName
//							if (s.scanIsCyclic)
//								if (WaveExists (theWave))
//									redimension/n= ((s.PixWidth), (s.PixHeight), (s.numFrames))  $theWaveName
//								else
//									make/w/u/o/n= ((s.PixWidth), (s.PixHeight), (s.numFrames))  $theWaveName
//								endif
//							else
//								if (WaveExists (theWave)) // acquire directly into the wave so make sure it is 1 dimensional
//									redimension /n= (s.PixWidth * s.PixHeight * s.numFrames)  $theWaveName
//								else
//									make/w/u/o/n= (s.PixWidth * s.PixHeight * s.numFrames)  $theWaveName
//								endif
//							endif
//
//							// check that the wave was made
//							err = GetRTError(0)
//							abortonvalue err, 1
//							// Set scaling
//							WAVE DataWave = $theWaveName
//							if (s.scanIsCyclic)
//								SetScale/P x s.xPos, s.XPixSize, "m", Datawave
//								SetScale/P y  s.yPos, s.YPixSize,"m", Datawave
//								SetScale/P z  0, s.frameTime ,"s", Datawave
//							else
//								SetScale/P x 0 , 1e-06,"m", Datawave
//							endif
//							SetScale d, 0, 2e12-1, "raw A/D", DataWave 
//							if (s.scanIsCyclic)
//								// Make a tempWave to acquire into directly
//								string tempWaveName = "root:packages:twoP:acquire:TempZWave" + "_ch" + num2str (theChannel + 1)
//								WAVE/Z tempWave = $tempWaveName
//								if (WaveExists (tempWave))
//									redimension/n= (s.PixWidth * s.PixHeight * bufferSize) $tempWaveName
//								else
//									make/w/u/o/n= (s.PixWidth * s.PixHeight * bufferSize) $tempWaveName
//								endif
//								// Add path info for tempWave
//								DataWave_Path  +=  tempWaveName + ", " + num2str (theChannel) + ", -5, 5;"
//							else
//								// Add path info for data wave
//								DataWave_Path  +=  thewavename + ", " + num2str (theChannel) + ", -5, 5;"
//							endif
//							// 0 the wave
//							fastop DataWave = 0
//							SetScale d, 0, 2e12-1, "raw A/D", DataWave 
//						endif
//					endfor
//				break
//			case kLineScan:
//				For (theChannel = 1; theChannel < 3; theChannel +=1)
//					if(1)// ((s.ScanChans) & theChannel)	// Then the current channel is selected
//						// don't kill this wave
//						dontKill +=  s.NewScanName + "_ch" + num2str (theChannel + 1) + ";"
//						//Make WaveName
//						theWaveName =  "root:twoP_Scans:" +  s.NewScanName + ":" + s.NewScanName + "_ch" + num2str (theChannel +1)
//						// Make the wave
//						wave/Z theWave = $theWaveName
//						if (waveExists (theWave))
//							redimension/n = ((s.PixWidth), (s.pixHeight)) theWave
//						else
//							make/w/u/o/n= ((s.PixWidth), (s.PixHeight))  $theWaveName
//						endif
//						// check that the wave was made
//						err = GetRTError(0)
//						abortonvalue err, 1
//						// Set scaling
//						WAVE DataWave = $theWaveName
//						SetScale/P x 0,1e-06,"s", Datawave
//						//SetScale/P x (s.xPos) , (s.xPixSize),"m", Datawave
//						//SetScale/P y  0 , (s.lineTime),"s", Datawave
//						SetScale d, -2e-11, 2e11-1, "raw A/D", DataWave
//						if (s.scanIsCyclic)
//							tempWaveName1 = "root:packages:twoP:acquire:TempL1Wave" + "_ch" + num2str (theChannel)
//							tempWaveName2 = "root:packages:twoP:acquire:TempL2Wave" + "_ch" + num2str (theChannel)
//							NVAR bufferSize = root:packages:twoP:acquire:lScanBufferSize
//							WAVE/z tempWave1 = $tempWaveName1
//							if (!(waveExists (tempWave1)))
//								make/w/u/o/n= ((s.PixWidth), (bufferSize)) $tempWaveName1
//							elseif ((dimSize (tempWave1, 0) != s.PixWidth) || (dimSize (tempWave1, 1) != bufferSize))
//								redimension/n= ((s.PixWidth), (bufferSize)) $tempWaveName1
//							endif
//							WAVE/z tempWave2 = $tempWaveName2
//							if (!(waveExists (tempWave2)))
//								make/w/u/o/n= ((s.PixWidth), (bufferSize)) $tempWaveName2
//							elseif ((dimSize (tempWave2, 0) != s.PixWidth) || (dimSize (tempWave2, 1) != bufferSize))
//								redimension/n= ((s.PixWidth), (bufferSize)) $tempWaveName2
//							endif
//							// Add path info to first tempWave
//							DataWave_Path  +=  tempWaveName1 + ", " + num2str (theChannel-1) + ", -5, 5;"
//						else
//							// Add path info for data wave
//							DataWave_Path  +=  thewavename + ", " + num2str (theChannel-1) + ", -5, 5;"
//						endif
//					endif
//				endfor
//				break
//			case kzSeries:
//				// Do we need multiple frames for timing issues
//				//NVAR frameTime = root:packages:twoP:acquire:frametime
//				NVAR minLiveFrameTime = root:packages:twoP:acquire:minLiveFrameTime
//				if (s.frameTime < minLiveFrameTime)
//					s.zAvgStackAtOnce =1
//					s.zAvg = ceil (minLiveFrameTime/s.frameTime)
//				else
//					s.zAvgStackAtOnce =0
//				endif
//				variable/G root:packages:twoP:acquire:zAvgStackAtOnce = s.zAvgStackAtOnce
//				For (theChannel = 0; theChannel < nCHannels; theChannel +=1)
//					if (1) //(s.ScanChans) & (2^theChannel))	// Then the current channel is selected
//						// don't kill this wave
//						dontKill +=  s.NewScanName + "_ch" + num2str (theChannel + 1) + ";"
//						//Make WaveName
//						theWaveName = "root:twoP_Scans:" +  s.NewScanName + ":" + s.NewScanName + "_ch" + num2str (theChannel +1)
//						// Make the wave
//						WAVE/Z theWave = $theWaveName
//						if (!(waveExists (theWave)))
//							make/w/u/o/n= ((s.PixWidth), (s.PixHeight), (s.numFrames))  $theWaveName
//							// 0 the wave
//							wave theWave = $theWaveName
//							fastop theWave = 0	
//						else
//							redimension/n= ((s.PixWidth), (s.PixHeight), (s.numFrames))  theWave
//							// 0 the wave
//							wave theWave =  $theWaveName
//							fastop theWave = 0	
//						endif
//						// check that the wave was made
//						err = GetRTError(0)
//						abortonvalue err, 1
//						// Set scaling
//						WAVE theWave = $theWaveName
//						SetScale/P x (s.xPos) , (s.xPixSize),"m", theWave
//						SetScale/P y  (s.yPos) , (s.yPixSize),"m", theWave
//						SetScale/P z  (s.Zpos), (s.zStepSize),"m", theWave
//						SetScale d, -2e-11, 2e11-1, "raw A/D", theWave
//						// Also make a tempWave to acquire into directly, and transfer to 3D wave as acquired
//						tempWaveName = "root:packages:twoP:acquire:TempZWave" + "_ch" + num2str (theChannel +1)
//						wave/Z tempWave = $tempWaveName
//						if (s.zAvgStackAtOnce)
//							if (!(waveExists (tempWave)))
//								make/w/u/o/n= (s.PixWidth * s.PixHeight * s.zAvg)$tempWaveName
//								wave/Z tempWave = $tempWaveName
//							else
//								redimension/n= (s.PixWidth * s.PixHeight  * s.zAvg)tempWave
//							endif
//						else  // just a 2D wave
//							if (!(waveExists (tempWave)))
//								make/w/u/o/n= (s.PixWidth * s.PixHeight)$tempWaveName
//							else
//								redimension/n= (s.PixWidth * s.PixHeight) tempWave
//							endif
//						endif
//						wave tempWave = $tempWaveName
//						SetScale/P x 0, 1e-06, "s", tempWave
//						DataWave_Path  +=  tempWaveName + ", " + num2str (theChannel) + ", -5, 5;"
//					endif
//				endfor
//				break
//		endSwitch
//	
//	
//	// Also make a string for wave Note -  contains info about scan settings for this scan
//	if (s.ScanMode == kLiveMode)
//		NQ_ScanNoter (s, "root:packages:twoP:Acquire:LiveModeScanStr")
//	else
//		newDataFolder/O $"root:twoP_Scans:" + s.newScanName
//		NQ_ScanNoter (s, "root:twoP_Scans:" + s.newScanName + ":" +  s.newScanName + "_info")
//	endif
//	// Iterate through the channels, making waves as appropriate for the scanMode
//	variable theChannel, nChannels = 2, err
//	string theWaveName, DataWave_Path = "",  tempWaveName1, tempWaveName2
//	string dontKill = ""
//	try
//		Switch (s.Scanmode) 
//			case kLiveMode: 
//				// Do we need multiple frames for timing issues
//				NVAR nLiveFrames = root:packages:twoP:acquire:nLiveFrames
//				For (theChannel =0 ; theChannel < nChannels; theChannel +=1)
//					if (1)//s.ScanChans & (2^theChannel))	// Then the current channel is selected
//						// Make the wave we will acquire into directly, but not display. The waves
//						// we acquire into directly need to be kept 1-Dimensional thanks to a nidattoolsmx update
//						theWaveName = "root:packages:twoP:acquire:LiveAcq_ch" + num2str (theChannel + 1)
//						// same as image size x 2 for double-buffering x nLiveFrames
//						variable nLivePnts = s.PixWidth * s.PixHeight * nLiveFrames
//						WAVE/z theWave = $theWaveName
//						if (WaveExists (theWave))
//							if (numPnts (theWave) != nLivePnts)
//								redimension/n = (nLivePnts) theWave
//							endif
//						else // need to make the wave
//							make/w/u/o/n = (nLivePnts) $theWaveName
//							setscale/p x 0, 1e-06, "s" $theWaveName
//						endif
//						WAVE tempWave = $theWaveName
//						// setscaling so Igor doesn't complain
//						//SetScale/P x 0, 1e-06, "", tempWave
//						fastop tempWave =0  
//						// add path info @@@ gain set to -5,5 for now, need to add per-channel gain settabilitty 
//						DataWave_Path  +=  thewavename + ", " + num2str (theChannel) + ", -5,5;"
//					endif
//				endfor 
//				break
//			case kSingleImage:	// Averaging Frames (time series with averaging at the end)
//			case kTimeSeries:	// time series
//				if (!(dataFolderExists ("root:twoP_Scans:" + s.newScanName)))
//					newDataFolder/O $"root:twoP_Scans:" + s.newScanName
//				endif
//				
//					redimension/n = ((s.PixWidth), (s.PixHeight))root:packages:twoP:examine:scanGraph_ch1,root:packages:twoP:examine:scanGraph_ch2
//					SetScale/P x s.xPos, s.XPixSize, "m", root:packages:twoP:examine:scanGraph_ch1, root:packages:twoP:examine:scanGraph_ch2
//					SetScale/P x s.yPos, s.YPixSize, "m", root:packages:twoP:examine:scanGraph_ch1, root:packages:twoP:examine:scanGraph_ch2
//					//SetScale/P x 0, 1e-06, "", root:packages:twoP:examine:scanGraph_ch2
//					if (s.scanIsCyclic)
//						NVAR bufferSize = root:packages:twoP:acquire:tSeriesBufferSize
//						s.numFrames = ceil (s.numFrames / bufferSize) * bufferSize
//					endif
//					For (theChannel = 0; theChannel < nChannels; theChannel +=1)
//						if (1)//(s.ScanChans) & (2^theChannel))	// Then the current channel is selected
//							// don't kill this wave
//							dontKill +=  s.NewScanName + "_ch" + num2str (theChannel + 1) + ";"
//							//Make WaveName
//							theWaveName = "root:twoP_Scans:" +  s.NewScanName + ":" + s.NewScanName + "_ch" + num2str (theChannel +1)
//							// Make the wave
//							WAVE/Z theWave = $theWaveName
//							if (s.scanIsCyclic)
//								if (WaveExists (theWave))
//									redimension/n= ((s.PixWidth), (s.PixHeight), (s.numFrames))  $theWaveName
//								else
//									make/w/u/o/n= ((s.PixWidth), (s.PixHeight), (s.numFrames))  $theWaveName
//								endif
//							else
//								if (WaveExists (theWave)) // acquire directly into the wave so make sure it is 1 dimensional
//									redimension /n= (s.PixWidth * s.PixHeight * s.numFrames)  $theWaveName
//								else
//									make/w/u/o/n= (s.PixWidth * s.PixHeight * s.numFrames)  $theWaveName
//								endif
//							endif
//
//							// check that the wave was made
//							err = GetRTError(0)
//							abortonvalue err, 1
//							// Set scaling
//							WAVE DataWave = $theWaveName
//							if (s.scanIsCyclic)
//								SetScale/P x s.xPos, s.XPixSize, "m", Datawave
//								SetScale/P y  s.yPos, s.YPixSize,"m", Datawave
//								SetScale/P z  0, s.frameTime ,"s", Datawave
//							else
//								SetScale/P x 0 , 1e-06,"m", Datawave
//							endif
//							SetScale d, 0, 2e12-1, "raw A/D", DataWave 
//							if (s.scanIsCyclic)
//								// Make a tempWave to acquire into directly
//								string tempWaveName = "root:packages:twoP:acquire:TempZWave" + "_ch" + num2str (theChannel + 1)
//								WAVE/Z tempWave = $tempWaveName
//								if (WaveExists (tempWave))
//									redimension/n= (s.PixWidth * s.PixHeight * bufferSize) $tempWaveName
//								else
//									make/w/u/o/n= (s.PixWidth * s.PixHeight * bufferSize) $tempWaveName
//								endif
//								// Add path info for tempWave
//								DataWave_Path  +=  tempWaveName + ", " + num2str (theChannel) + ", -5, 5;"
//							else
//								// Add path info for data wave
//								DataWave_Path  +=  thewavename + ", " + num2str (theChannel) + ", -5, 5;"
//							endif
//							// 0 the wave
//							fastop DataWave = 0
//							SetScale d, 0, 2e12-1, "raw A/D", DataWave 
//						endif
//					endfor
//				break
//			case kLineScan:
//				For (theChannel = 1; theChannel < 3; theChannel +=1)
//					if(1)// ((s.ScanChans) & theChannel)	// Then the current channel is selected
//						// don't kill this wave
//						dontKill +=  s.NewScanName + "_ch" + num2str (theChannel + 1) + ";"
//						//Make WaveName
//						theWaveName =  "root:twoP_Scans:" +  s.NewScanName + ":" + s.NewScanName + "_ch" + num2str (theChannel +1)
//						// Make the wave
//						wave/Z theWave = $theWaveName
//						if (waveExists (theWave))
//							redimension/n = ((s.PixWidth), (s.pixHeight)) theWave
//						else
//							make/w/u/o/n= ((s.PixWidth), (s.PixHeight))  $theWaveName
//						endif
//						// check that the wave was made
//						err = GetRTError(0)
//						abortonvalue err, 1
//						// Set scaling
//						WAVE DataWave = $theWaveName
//						SetScale/P x 0,1e-06,"s", Datawave
//						//SetScale/P x (s.xPos) , (s.xPixSize),"m", Datawave
//						//SetScale/P y  0 , (s.lineTime),"s", Datawave
//						SetScale d, -2e-11, 2e11-1, "raw A/D", DataWave
//						if (s.scanIsCyclic)
//							tempWaveName1 = "root:packages:twoP:acquire:TempL1Wave" + "_ch" + num2str (theChannel)
//							tempWaveName2 = "root:packages:twoP:acquire:TempL2Wave" + "_ch" + num2str (theChannel)
//							NVAR bufferSize = root:packages:twoP:acquire:lScanBufferSize
//							WAVE/z tempWave1 = $tempWaveName1
//							if (!(waveExists (tempWave1)))
//								make/w/u/o/n= ((s.PixWidth), (bufferSize)) $tempWaveName1
//							elseif ((dimSize (tempWave1, 0) != s.PixWidth) || (dimSize (tempWave1, 1) != bufferSize))
//								redimension/n= ((s.PixWidth), (bufferSize)) $tempWaveName1
//							endif
//							WAVE/z tempWave2 = $tempWaveName2
//							if (!(waveExists (tempWave2)))
//								make/w/u/o/n= ((s.PixWidth), (bufferSize)) $tempWaveName2
//							elseif ((dimSize (tempWave2, 0) != s.PixWidth) || (dimSize (tempWave2, 1) != bufferSize))
//								redimension/n= ((s.PixWidth), (bufferSize)) $tempWaveName2
//							endif
//							// Add path info to first tempWave
//							DataWave_Path  +=  tempWaveName1 + ", " + num2str (theChannel-1) + ", -5, 5;"
//						else
//							// Add path info for data wave
//							DataWave_Path  +=  thewavename + ", " + num2str (theChannel-1) + ", -5, 5;"
//						endif
//					endif
//				endfor
//				break
//			case kzSeries:
//				// Do we need multiple frames for timing issues
//				//NVAR frameTime = root:packages:twoP:acquire:frametime
//				NVAR minLiveFrameTime = root:packages:twoP:acquire:minLiveFrameTime
//				if (s.frameTime < minLiveFrameTime)
//					s.zAvgStackAtOnce =1
//					s.zAvg = ceil (minLiveFrameTime/s.frameTime)
//				else
//					s.zAvgStackAtOnce =0
//				endif
//				variable/G root:packages:twoP:acquire:zAvgStackAtOnce = s.zAvgStackAtOnce
//				For (theChannel = 0; theChannel < nCHannels; theChannel +=1)
//					if (1) //(s.ScanChans) & (2^theChannel))	// Then the current channel is selected
//						// don't kill this wave
//						dontKill +=  s.NewScanName + "_ch" + num2str (theChannel + 1) + ";"
//						//Make WaveName
//						theWaveName = "root:twoP_Scans:" +  s.NewScanName + ":" + s.NewScanName + "_ch" + num2str (theChannel +1)
//						// Make the wave
//						WAVE/Z theWave = $theWaveName
//						if (!(waveExists (theWave)))
//							make/w/u/o/n= ((s.PixWidth), (s.PixHeight), (s.numFrames))  $theWaveName
//							// 0 the wave
//							wave theWave = $theWaveName
//							fastop theWave = 0	
//						else
//							redimension/n= ((s.PixWidth), (s.PixHeight), (s.numFrames))  theWave
//							// 0 the wave
//							wave theWave =  $theWaveName
//							fastop theWave = 0	
//						endif
//						// check that the wave was made
//						err = GetRTError(0)
//						abortonvalue err, 1
//						// Set scaling
//						WAVE theWave = $theWaveName
//						SetScale/P x (s.xPos) , (s.xPixSize),"m", theWave
//						SetScale/P y  (s.yPos) , (s.yPixSize),"m", theWave
//						SetScale/P z  (s.Zpos), (s.zStepSize),"m", theWave
//						SetScale d, -2e-11, 2e11-1, "raw A/D", theWave
//						// Also make a tempWave to acquire into directly, and transfer to 3D wave as acquired
//						tempWaveName = "root:packages:twoP:acquire:TempZWave" + "_ch" + num2str (theChannel +1)
//						wave/Z tempWave = $tempWaveName
//						if (s.zAvgStackAtOnce)
//							if (!(waveExists (tempWave)))
//								make/w/u/o/n= (s.PixWidth * s.PixHeight * s.zAvg)$tempWaveName
//								wave/Z tempWave = $tempWaveName
//							else
//								redimension/n= (s.PixWidth * s.PixHeight  * s.zAvg)tempWave
//							endif
//						else  // just a 2D wave
//							if (!(waveExists (tempWave)))
//								make/w/u/o/n= (s.PixWidth * s.PixHeight)$tempWaveName
//							else
//								redimension/n= (s.PixWidth * s.PixHeight) tempWave
//							endif
//						endif
//						wave tempWave = $tempWaveName
//						SetScale/P x 0, 1e-06, "s", tempWave
//						DataWave_Path  +=  tempWaveName + ", " + num2str (theChannel) + ", -5, 5;"
//					endif
//				endfor
//				break
//		endSwitch
//	catch
//		doalert 0, "Scan waves could not be created: " + GetRTErrMessage()
//		err = GetRTError(1)
//		return 1
//	endtry
//	// kill remaining waves left on graph from last scan, if any
//	// check ephys waves as well
//	For (theChannel = 1; theChannel < 3; theChannel +=1)
//		if (s.ePhysChans & theChannel)
//			dontKill += s.NewScanName + "_ep" + num2str (theChannel)
//		endif
//	endfor
//	NQ_KillNotInList (s, dontKill)
//	NVAR expSize = root:packages:twoP:acquire:expSize
//	expSize = NQ_GetExpSize ()
//	s.scanWavePath = DataWave_Path
//	doupdate
//	return 0
//end

//******************************************************************************************************
// makes waves for ePhys
// Last Modified 2025/09/04 by Jamie Boyd 
Function NQ_MakeEphysWaves (s) 
	STRUCT NQ_ScanStruct &s
	
	variable ePnts = ceil(s.Runtime * s.EphysFreq) 
	string baseName = "root:twoP_Scans:" + s.newScanName +":" +  s.newScanName + "_"
	s.ePhysPath = ""
	WAVE/T chanList = root:packages:twoP:acquire:ePhysChanList
	string ai_chanName, ai,chanName, type, range, scaling, offset
	variable iChan, nChans = itemsInList(s.selePhysChanList)

	// fillout NI-DAQ info for scan command, and make the ephys waves
	for (iChan=0; iChan < nChans; iChan +=1)
		ai_chanName = stringFromList(iChan, s.selePhysChanList,";")
		ai = stringFromList (1, ai_chanName, ":")
		chanName = stringFromList (0, ai_chanName, ":")
		type = chanList [str2num(ai)] [2]
		range =  chanList [str2num(ai)] [3]
		Scaling = chanList [str2num(ai)] [4]
		Offset = chanList [str2num(ai)] [5]
		s.ePhysPath += baseName + chanName + ", " + ai + "/" + type + ", -" +  range + ", " + range + ", " + scaling + ", " + offset + ";"
		WAVE/Z scanWave= $baseName + chanName
		if (waveExists (scanWave))
			redimension/s/n = (ePnts) scanWave
		else
			make/s/n = (ePnts) $baseName + chanName
			WAVE scanWave= $baseName + chanName
		endif
		SetScale/P x 0, (1/s.EphysFreq), "s", scanWave
		SetScale d, 0, 0, "V", scanWave
		fastop scanWave =0
	endfor
end	


//******************************************************************************************************
// Sets up triggers, using the ephys board.  returns 1 if an error occurs, else 0
// Last Modified 2025/08/11 by Jamie Boyd
Function twoP_doTriggers (s)
	STRUCT NQ_ScanStruct &s
	
	NVAR Trig1Polarity = root:packages:twoP:acquire:Trig1Polarity
	NVAR Trig2Polarity= root:packages:twoP:acquire:Trig2Polarity
	NVAR Trig1Duration =root:packages:twoP:acquire:Trig1Duration
	NVAR Trig2Duration =root:packages:twoP:acquire:Trig2Duration
	
	try
		if (!(s.scanmode == kLiveMode || s.scanmode == kZseries))
			if (s.trigChans & 1)
				DAQmx_CTR_OutputPulse /DEV=s.ePhysBoard/SEC={Trig1Duration, Trig1Duration} /IDLE=(Trig1Polarity)/DELY=(s.trig1Secs)/NPLS=1/STRT=1/TRIG="/" + s.ephysBoard + "/ai/SampleClock"/MC={"/" + s.imageBoard + "/20MHzTimebase", 20e06} 0 ; AbortOnRTE
			endif
			if (s.trigChans & 2)
				DAQmx_CTR_OutputPulse /DEV=s.ePhysBoard/SEC={Trig2Duration, Trig2Duration} /IDLE=(Trig2Polarity)/DELY=(s.trig2Secs)/NPLS=1/STRT=1/TRIG="/" + s.imageBoard + "/ai/StartTrigger" /MC={"/" + s.imageBoard + "/20MHzTimebase", 20e06} 1; AbortOnRTE
			endif
		endif
	catch
		print  "The \"NQ_doTriggers\" function failed:\r" +  fdaqmx_errorString()
		return 1
	endtry
	return 0	// exit with success
end


// **********************************************************************************************************
// Fires the trigger when the button is pressed with no waiting
// Last Modified 2025/08/11 by Jamie Boyd
Function twoP_LiveTriggerButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	SVAR ePhysBoardName =root:packages:twoP:acquire:ePhysBoard
	NVAR Trig1Polarity = root:packages:twoP:acquire:Trig1Polarity
	NVAR Trig2Polarity= root:packages:twoP:acquire:Trig2Polarity
	NVAR Trig1Duration =root:packages:twoP:acquire:Trig1Duration
	NVAR Trig2Duration =root:packages:twoP:acquire:Trig2Duration
	switch( ba.eventCode )
		case 2: // mouse up
			if (cmpStr(ba.ctrlName, "Trig1ManualButton") ==0)
				DAQmx_CTR_OutputPulse /DEV=ePhysBoardName/SEC={Trig1Duration, Trig1Duration}/IDLE=(Trig1Polarity) /NPLS=1/STRT=1 (0) ; AbortOnRTE
			else
				DAQmx_CTR_OutputPulse /DEV=ePhysBoardName/SEC={Trig2Duration, Trig2Duration}/IDLE=(Trig2Polarity) /NPLS=1/STRT=1 (1) ; AbortOnRTE
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


//******************************************************************************************************
// Starts the ephys board ready to scan, waiting for image board, or starts ePhys scan if doing ephys alone
// sets input trigger to waveform generator or, for ePhys alone,  sends scan start to RTSI
//  returns 1 if an error ocurred, else 0
// last Modified:
// 2017/08/31 by Jamie Boyd-input triggering for ephys with imaging
Function NQ_doEphysInit (s)
	STRUCT NQ_ScanStruct &s
	
	variable NidaqError
	string endFuncStr
	string errFuncStr
	//sprintf errFuncStr, "NQ_ScanEnd(3, %s)",  s.ScanMode
	//sprintf endFuncStr, "NQ_ScanEnd(0, %s)",  s.ScanMode
	print s.ePhysPath
	try
		if (s.ScanMode == kePhysOnly)
			if (s.inPutTrigger)
				DAQmx_Scan /DEV= s.ePhysBoard/STRT=1/TRIG= {"/" + s.imageBoard + "/PFI6",1}/BKG=1 WAVES= s.ePhysPath;abortonRTE
			else
				DAQmx_Scan /DEV= s.ePhysBoard/STRT=1/BKG=1 WAVES= s.ePhysPath;abortonRTE
			endif
		else
			DAQmx_Scan /DEV= s.ePhysBoard/STRT=1/TRIG= {"/" + s.imageBoard + "/ai/StartTrigger",1,0,0,0}/BKG=1 WAVES= s.ePhysPath;abortonRTE
		endif
	catch
		printf  "The \"NQ_doEphysInit\" function failed with %d. The Error message was:\r%s\r", V_AbortCode, fdaqmx_errorString ()
		return 1
	endtry

	return 0	// exit with success
end



//******************************************************************************************************
// Gets the ephys board ready to Output Voltage Waves using waveform generator 0 and waveform generator 1
//  returns 1 if an error ocurred, else 0
// Last Modified 2025/08/11 by Jamie
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
		if (s.vOutStart == 1) // start voltage output on scan start
			DAQmx_WaveformGen /DEV=s.ePhysBoard /MC={"/" + s.imageBoard +"/20MHzTimebase", 20E06} /NPRD =1 /STRT=1 /TRIG={"/" + s.ePhysBoard + "/ai/StartTrigger"} VoltageWavePath
		elseif (s.vOutStart == 2) // start on output of trig 2 - this also uses trigger 1 - we could try shuttling to a RTSI line
			DAQmx_WaveformGen /DEV=s.ePhysBoard /MC={"/" + s.imageBoard +"/20MHzTimebase", 20E06} /NPRD =1 /STRT=1 /TRIG={"/" + s.ePhysBoard +"/Ctr1/InternalOutput"} VoltageWavePath
		endif	
			
		
	catch
		printf  "The \"NQ_doVoltagePulseWaves\" function failed at position %d. The Error message was:\r%s\r", V_AbortCode, "" //NQGetErrorString (NidaqError)
		return 1
	endtry
	return 0	// exit with success
end



//******************************************************************************************************
// Function called by the "Start Scan" Button.
// Last Modified: 2025/09/03 by Jamie Boyd
Function  NQ_StartScan (ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
		// scan mode
		NVAR scanMode = root:packages:twoP:Acquire:ScanMode
		// grab scan mode and save in case user flips to a different tab in scanmode tabcontrol
		NVAR ScanStartMode = root:packages:twoP:Acquire:ScanStartMode
		ScanStartMode=scanMode
		// Load ScanStruct with settings variables
		STRUCT NQ_ScanStruct s
		NQ_LoadScanStruct (s)
		// check for overwriting 
		if (NQ_CheckOverWrite (s))
			return 1
		endif
		// check for channel selection according to scan mode
		if (s.scanMode == kEphysOnly)
			if (itemsInList (s.selEphysChanList, ";") ==0)
				doAlert 0, "Select some ePhys channels before starting ePhys scanning."
				return 1
			endif
		else
			if (itemsInList (s.selImageChanList, ";") ==0)
				doAlert 0, "Select some image channels before scanning."
				return 1
			endif
		endif
		variable xS=1, yS=1, zS=1, axS=NaN
		// if Z-stack, move to start of stack
		if (s.ScanMode == kzSeries)
			xS=NaN; yS=NaN; zS=s.zPos; axS =NaN
			funcref StageMove_Template stageMove = $"StageMove_" + s.stageProc
			stageMove (0, 1, xS, yS, zS, axS)
			// Set focus increment to zStepsize
			funcref StageSetInc_Template SetInc= $"StageSetInc_" + s.stageProc
			SetInc (zVal=s.zStepSize)
		endif
		// Update stage and X,Y position unless repeated multiAq
		if (!(s.isMulti && (s.multiAqiAq > 0)))
			funcref  StageUpdate_Template UpdateStage=$"StageUpDate_" + s.StageProc
			UpdateStage (xS, yS, zS, axS)
			// if reading stage fails, set stage values to 0
			if (((numtype (xS) != 0) ||  (numtype (yS) != 0)) ||(numtype (zS) != 0))
				s.xPos = 0
				s.yPos =0
				s.zPos =0
				print "Stage reading failed; XYZ positions for " + s.newScanName + " set arbitrarily to 0"
			else
				s.xPos=xS
				s.yPos = yS
				s.zPos =zS
			endif
			WAVE/T objWave = root:packages:twoP:acquire:ObjWave
			variable xScaling= str2num (objWave [s.objNum] [1])
			variable yScaling= str2num (objWave [s.objNum] [2])
			variable xOffset = str2num (objWave [s.objNum] [3])
			variable yOffset = str2num (objWave [s.objNum] [4])
			s.xScalStart = s.xPos - xOffset + s.xSV * xScaling
			s.yScalStart = s.yPos - yOffset + s.ySV * yScaling
		endif
		// make a folder for this scan
		newDataFolder/O $"root:twoP_Scans:" + s.newScanName
		// Make info string 
		if (NQ_ScanNoter (s))
			doAlert 0,"Scan not created"
			return 0
		endif
		// make waves for imaging - laser scan waves and imaging data
		if (s.scanMode != kePhysOnly)
			if (!(s.isMulti && (s.multiAqiAq > 0)))	// only need to make galvo waves once for multiaq
				NQ_MakeGalvoScanWaves (s)
			endif
			// set galvos to start of X and Y galvo waves
			WAVE HorWave=root:Packages:twoP:acquire:HorWave
			WAVE VerWave=root:Packages:twoP:acquire:VerWave
			fDAQmx_WriteChan(s.ImageBoard, 0, HorWave [0], -10, 10)
			fDAQmx_WriteChan(s.ImageBoard, 1, VerWave [0], -10, 10)
			NQ_MakeImageScanWaves(s) // also fills out paths and channels in s.scanWavePath entry in scanStruct for NI-DAQ
		endif
		// make waves for ePhys
		if (itemsInList (s.selEphysChanList, ";") > 0)
			NQ_MakeEphysWaves (s)
		endif
		// set up triggers
		if (s.trigChans)
			twoP_doTriggers(s)
		endif
		// make waves for voltage pulses
		if (s.vOutChans)
			NQ_DoVoltagePulseWaves (s)
		endif

		// Select our new scan as current scan, with selected channels on scanGraph to match channels being acquired
		if (s.scanMode != kephysOnly)
			SVAR selChans = root:packages:twoP:examine:scanGraphSelChans
			selChans=s.onlyChansImage
		endif
		STRUCT WMPopupAction pa
		pa.eventCode = 2
		pa.popStr =  s.NewScanName
		twoP_ScanPopMenuProc(pa)
		// change start button status
		NVAR StopOrAbort = root:Packages:twoP:Acquire:ScanStopOrAbort
		StopOrAbort = 0
		Button AqStartButton, win = twoP_Controls, proc= twoP_StopOrAbort
		if (s.scanMode== kLiveMode)
			Button AqStartButton, win = twoP_Controls, fColor=(65280,0,0), title = "Stop"
		else
			if (s.inPutTrigger)
				Button AqStartButton, win = twoP_Controls, fColor=(65280,65280,0), title = "Wait"
			else
				Button AqStartButton, win = twoP_Controls, fColor=(65280,0,0), title = "Abort"
			endif
		endif
		DoUpdate /W=twoP_Controls /E=1	// mark control panel as a progress window
		// do things specific to scan mode
		switch (ScanStartMode)
			case kLiveMode:
				ValDisplay AqPercentCompleteDisplay win= twoP_Controls, mode=4
				// live histogram?
				if (s.liveHist)
					SVAR HistGraphSelChans = root:packages:twoP:examine:HistGraphSelChans
					HistGraphSelChans = s.onlyChansImage
					twoP_HistMakeGraph ()
				endif
				// live ROI?
				if (s.liveROI)
					twoP_MakeLROIGraph (s)
				endif
				//live Raw A/D ?
				if (s.liveRaw)
					twoP_MakeLiveRawGraph(s)
				endif
				variable/G root:packages:twoP:acquire:LiveiFrame = 0
				variable/G root:packages:twoP:acquire:LiveNchannels = ItemsInList(s.selImageChanList,";")
				break
			case kTimeSeries:
				// live ROI?
				if (s.liveROI)
					twoP_MakeLROIGraph (s)
				endif
				break
			case kSingleImage:
			
				break
			case kZseries:
				
				break
			case KlineScan:
				break
				
			case kePhysOnly:
				break
				
		endSwitch
		
		// start Threads
		if (s.scanmode != kephysOnly)
			twoP_AcquireStartThreads(s)
		endif
		

		// Init NI-DAQ for ePhys. If ePhys only and triggered, waits for trigger
		if (itemsinlist (s.selEphysChanList, ";") > 0)
			NQ_doEphysInit (s)
		endif
		wave horwave=root:packages:twoP:acquire:horwave
		wave verwave=root:packages:twoP:acquire:verwave
		//horwave [0]=3
		//verwave [0] = 3

		// inits image scan and waits for trigger, if triggered
		if (s.scanmode != kephysOnly)
			if (NQ_ScanInit (s))
				print fdaqmx_errorString()
				twoP_reSetBoards ()
				NVAR gThreadGroupID = root:packages:twoP:Acquire:gThreadGroupID
				variable released = threadgroupRelease(gThreadGroupID)
				Button AqStartButton, win = twoP_Controls, title="Start",fColor=(0, 65280, 0), proc= NQ_StartScan
			endif
		endif
		break
endswitch
end



#ifdef OLD_SCAN_INIT

//******************************************************************************************************
// Starts the image board scanning, or waiting for input trigger
// returns 1 if an error ocurred, else 0
// ues RTSI lines as a bus to connect sources to destinations they may not otherwise connect to without errors
// Last Modified:2025/09/09
Function NQ_ScanInit (s)
	STRUCT NQ_ScanStruct &s

	// only for image scan, ePhys has its own NI-DAQ init, which should already have run
	if (s.scanmode== kephysOnly)
		return 0
	endif

	// clear any stored DAQmx error messages
	for (;(cmpstr (fDAQmx_ErrorString(), "") != 0);)
	endfor

	string RPTChook
	string EOShook
	string ScanErrhook
	sprintf ScanErrhook, "twoP_ScanErr(%d)", s.ScanMode
	
	variable pixHz =1/(s.PixTime)
	//global variables for the shutter. Pugged into digital line 0 on the Image Board
	NVAR shutterTaskNum = root:packages:twoP:Acquire:shutterTaskNum
	NVAR triggerTaskNum =  root:packages:twoP:Acquire:triggerTaskNum
	NVAR shutterOpen = root:Packages:twoP:acquire:shutterOpenLevel
	NVAR shutterDelay = root:Packages:twoP:acquire:shutterDelay
	try
		// connect ao/sample clock and ai/sample clock to PFI pins for use with chunkulator, e.g. You can comment one or both of these out if you don't need them.
		AbortOnValue fDAQmx_ConnectTerminals("/" + s.ImageBoard + "/ao/SampleClock", "/" + s.ImageBoard + "/PFI5", 0), 1	// rests high, brief high-to-low low pulses, leads
		AbortOnValue fDAQmx_ConnectTerminals("/" + s.ImageBoard + "/ai/SampleClock", "/" + s.ImageBoard + "/PFI7", 0), 2   // rests low, brief high pulse on low-to-high of ao sample clock
		// connect counter0 (line gate) output to normal counter 0 output pin (aka PFI 12) for use with image projector, e.g. 
		AbortOnValue fDAQmx_ConnectTerminals("/" + s.ImageBoard + "/ctr0InternalOutput", "/" + s.ImageBoard + "/ctr0Out", 0), 3   // rests low, brief high pulse on low-to-high of ao sample clock
		
		// mnake lineGate on ctr0, source is RTSI_5, where we will put ao  signal of the waveform generator, direct the output to RTSI_6 where it is used to gate analog input
		fDAQmx_CTR_Finished(s.ImageBoard, 0)
		AbortOnValue fDAQmx_ConnectTerminals("/" + s.ImageBoard + "/ctr0InternalOutput", "/" + s.ImageBoard + "/RTSI6", 0), 4
		DAQmx_CTR_OutputPulse /DEV=s.ImageBoard/TICK={(s.PixWidthTotal - s.PixWidth), s.PixWidth} /IDLE=0 /NPLS=0/TBAS="/" + s.ImageBoard + "/RTSI5" /Rate=(pixHz) 0; ABORTONRTE

		// A/D scanning, we set it all up but don't start it till after waveform generator has started. This ensures we are in the high phase of the linegate when we start
		Switch (s.ScanMode)
			case kLiveMode:		// scan repeats till stopped
				sprintf RPTChook "twoP_LiveHook(\"%s\", %d)", s.onlyChansImage, itemsInList(s.onlyChansImage, ",")
				DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/RTSI5",1}/PAUS={ "/" + s.ImageBoard + "/RTSI6", 1,1}/STRT=0 /RPTC/RPTH=RPTChook/ERRH= ScanErrhook WAVES = s.scanWavePath;ABORTONRTE
				break
			case kTimeSeries:
				if (s.ScanIsCyclic) // scan repeats till scan Wave is full
					sprintf RPTChook, "twoP_timeCyclicHook (\"%s\", %d, %d, %d, %d, %d, %d)", s.onlyChansImage, itemsInList(s.onlyChansImage, ","), s.nCycFrames, s.PixWidth, s.PixHeight, s.numFrames, s.flyBackMode
					variable/G root:packages:twoP:acquire:tSeriesFrame =0	//to track how many frames have been done
					DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/RTSI5", 1}/PAUS={ "/" + s.ImageBoard + "/RTSI6", 1,1}/STRT=0 /RPTC/RPTH=RPTChook/ERRH= ScanErrhook WAVES = s.scanWavePath;ABORTONRTE
				else // no repeats, scan at once, with background task to update display and end of task hook to redimension and clean up
					sprintf EOShook,  "twoP_timeSeriesEndHook(\"%s\", \"%s\", %d, %d, %d, %d)", s.newScanName, s.onlyChansImage, s.pixWidth, s.pixHeight, s.numFrames, s.flybackMode
					DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/RTSI5", 1}/STRT=0/PAUS={ "/" + s.ImageBoard + "/RTSI6", 1,1}/EOSH=EOShook /ERRH= ScanErrhook WAVES = s.scanWavePath;ABORTONRTE
					variable/G root:packages:twoP:acquire:nBKGFrames=s.nCycFrames
					variable taskPeriod=ceil(s.nCycFrames * s.frameTime * 60)
					CtrlNamedBackground tSeriesTask, period =  taskPeriod, burst =0, proc= twoP_tSeriesBkg, start=(ticks + taskPeriod)
				endif
				break
		endSwitch		
		
		// wave form generator, send sample clock output to RTSI_5
		AbortOnValue fDAQmx_ConnectTerminals("/" + s.ImageBoard + "/ao/SampleClock", "/" + s.ImageBoard + "/RTSI5", 0), 5
		string scanWavesList
		If (s.ScanMode == kLineScan)
			scanWavesList = "root:packages:twoP:acquire:HorWave, 0;"
		else
			scanWavesList = "root:packages:twoP:acquire:HorWave, 0;root:packages:twoP:acquire:VerWave, 1;"
		endif
		// if input trigger, setup waveform generator then wait for trigger low-to-high to open dhutter and for trigger-high-to low to progress to starting A/D scan
		if ((s.inPutTrigger) && (s.scanMode != kLiveMode))
			//CtrlNamedBackground shutterTask, period = 1, burst =0, proc= twoP_WaitForShutter, start
			DAQmx_WaveformGen /DEV=s.imageBoard /BKG=0/NPRD=0/TRIG={"/" + s.ImageBoard + "/PFI6", 1, 0}/Strt=1  scanWavesList; ABORTONRTE
			variable shutterIsOpen=0
			for (;;)
				if (!(shutterIsOpen))
					if (fDAQmx_DIO_Read(s.imageBoard, triggerTaskNum))
						fDAQmx_DIO_Write(s.imageBoard, shutterTaskNum, shutterOpen)
						shutterIsOpen = 1//;print "SHutter open"
					endif
				else
					if (!(fDAQmx_DIO_Read(s.imageBoard, triggerTaskNum)))
						// start the A/D scan which is all setup to go
						fDAQmx_ScanStart(s.imageBoard,1)
						Button AqStartButton, win = twoP_Controls, fColor=(65280,0,0), title = "Abort"
						break
					endif
				endif
			endfor
		else // if not triggered, open shutter and wait shutter open time before starting waveform generator
			abortonvalue fDAQmx_DIO_Write (s.ImageBoard, shutterTaskNum, (shutterOpen)), 6
			// wait a few milliseconds while shutter opens before continuing
			if (shutterDelay > 0)
				Sleep/c=-1/S shutterDelay
			endif
			DAQmx_WaveformGen /DEV=s.imageBoard /BKG=0/NPRD=0/Strt=1  scanWavesList; ABORTONRTE
			fDAQmx_ScanStart(s.imageBoard,1)
		endif
	catch
		variable err=GetRTError(1)
		printf  "The \"NQ_ScanInit\" function failed at %d:\r%s\r",   err,  fDAQmx_ErrorString()
		return 1 // exit with failure
	endtry
	return 0
end

#else
// waveform generator clock is set by scaling of galvo waves to be pixelTime
// ctr0 pixel clock is made independently using 20Mhz source to be same as waveform clock, 50% duty cycle
// ctr1 line gate is made independently using 20Mhz source (ON and OFF times set by pixels  * pixelTime * 20Mhz clock ticks
// pixel clock is gated by line gate
// analog input uses ctr0 output as scanClock

//******************************************************************************************************
// Starts the image board scanning, or waiting for input trigger
//  returns 1 if an error ocurred, else 0
// Last Modified:
// 20235/09/04 by Jamie Boyd
// 2025/08/26 by Jamie Boyd - two counters, with trigger
// 2017/08/21 by Jamie Boyd - adding support for input trigger
// 2016/11/15 by Jamie Boyd - adding support for background task per channel
Function NQ_ScanInit (s)
	STRUCT NQ_ScanStruct &s

	// only for image scan, ePhys has its own NI-DAQ init, which should already have run
	if (s.scanmode== kephysOnly)
		return 0
	endif

	// clear any stored error messages
	for (;(cmpstr (fDAQmx_ErrorString(), "") != 0);)
	endfor
			
	string RPTChook
	string EOShook
	string ScanErrhook
	sprintf ScanErrhook, "twoP_ScanErr(%d)", s.ScanMode
	try
		// ouput scan clock and input sample clock for use with chunkulator, e.g.
		AbortOnValue fDAQmx_ConnectTerminals("/" + s.ImageBoard + "/ao/SampleClock", "/" + s.ImageBoard + "/PFI5", 0), 1	// rests high, brief high-to-low low pulses, leads
		AbortOnValue fDAQmx_ConnectTerminals("/" + s.ImageBoard + "/ai/SampleClock", "/" + s.ImageBoard + "/PFI7", 0), 2   // rests low, brief high pulse on low-to-high of ao sample clock
		// start analog input 
		Switch (s.ScanMode)
			case kLiveMode:		// scan repeats till stopped
				sprintf RPTChook "twoP_LiveHook(\"%s\", %d)", s.onlyChansImage, itemsInList(s.onlyChansImage, ",")
				DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/ctr0InternalOutput", 0}/TRIG={"/" + s.imageBoard + "/ctr0Gate", 1, 1} /RPTC/RPTH=RPTChook/ERRH= ScanErrhook WAVES = s.scanWavePath;ABORTONRTE
				break
			case kTimeSeries:
				if (s.ScanIsCyclic)	
					sprintf RPTChook, "twoP_timeCyclicHook (\"%s\", %d, %d, %d, %d, %d, %d)", s.onlyChansImage, itemsInList(s.onlyChansImage, ","), s.nCycFrames, s.PixWidth, s.PixHeight, s.numFrames, s.flyBackMode
					// scan repeats till scan Wave is full
					variable/G root:packages:twoP:acquire:tSeriesFrame =0	//to track how many frames have been done
					DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/ctr0InternalOutput", 0}/TRIG={"/" + s.imageBoard + "/ctr0Gate", 1, 1} /RPTC/RPTH=RPTChook/ERRH= ScanErrhook WAVES = s.scanWavePath;ABORTONRTE
				else
					sprintf EOShook,  "twoP_timeSeriesEndHook(\"%s\", \"%s\", %d, %d, %d, %d)", s.newScanName, s.onlyChansImage, s.pixWidth, s.pixHeight, s.numFrames, s.flybackMode
					// no repeats, scan at once, with background task to update display and end of task hook to redimension and clean up
					DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/ctr0InternalOutput", 0}/TRIG={"/" + s.imageBoard + "/ctr0Gate", 1, 1}/EOSH=EOShook /ERRH= ScanErrhook WAVES = s.scanWavePath;ABORTONRTE
					variable/G root:packages:twoP:acquire:nBKGFrames=s.nCycFrames
					variable taskPeriod=ceil(s.nCycFrames * s.frameTime * 60)
					CtrlNamedBackground tSeriesTask, period =  taskPeriod, burst =0, proc= twoP_tSeriesBkg, start=(ticks + taskPeriod)
				endif
				break
		endSwitch

		// Start the waveform generator
		string scanWavesList
		If (s.ScanMode == kLineScan)
			scanWavesList = "root:packages:twoP:acquire:HorWave, 0;"
		else
			scanWavesList = "root:packages:twoP:acquire:HorWave, 0;root:packages:twoP:acquire:VerWave, 1;"
		endif
		DAQmx_WaveformGen /DEV=s.imageBoard /BKG=0/NPRD=0/Strt=1 /TRIG={"/" + s.imageBoard + "/ctr0Gate", 1, 0} scanWavesList;abortOnRTE
		// make analog input pixel clock on ctr 0, gated with output of ctr1. NOTE: start of ctr0 is not synched to ctr1
		variable pixTix = round (s.pixTime*20e06)
		variable pixOn=floor (pixTix/2)
		variable pixOff= pixTix - pixON
		// if triggered, start a background task that waits for the trigger
		NVAR shutterTaskNum = root:packages:twoP:Acquire:shutterTaskNum
		NVAR triggerTaskNum = root:packages:twoP:Acquire:triggerTaskNum
		NVAR shutterOpen = root:Packages:twoP:acquire:shutterOpenLevel
		NVAR shutterDelay = root:Packages:twoP:acquire:shutterDelay
		if (s.inPutTrigger)
			// lineGate on ctr 1 WITH TRIGGER
			DAQmx_CTR_OutputPulse /DEV=s.ImageBoard/TICK={pixOn, pixOff}/STRT=1 /IDLE=0 /NPLS=0/TBAS="/" + s.ImageBoard + "/20MhzTimeBase" /Rate=(20e06)/PAUS={"/" + s.imageBoard + "/ctr1InternalOutput", 1, 1}  0; ABORTONRTE
			DAQmx_CTR_OutputPulse /DEV=s.ImageBoard/TICK={(s.PixWidthTotal - s.PixWidth)*pixTix, s.PixWidth*pixTix}/STRT=1 /IDLE=0 /NPLS=0/TBAS="/" + s.ImageBoard + "/20MhzTimeBase" /Rate=(20e06)/TRIG={"/" + s.imageBoard + "/PFI6", 1,0} 1; ABORTONRTE
			CtrlNamedBackground shutterTask, period = 1, burst =0, proc= twoP_WaitForShutter, start
		else // if not triggered, open shutter and wait shutter open time
			// Open up the shutter. Pugged into digital line 0 on the Image Board
			abortonvalue fDAQmx_DIO_Write (s.ImageBoard, shutterTaskNum, (shutterOpen)), 0
			// wait a few milliseconds while shutter opens before continuing
			if (shutterDelay > 0)
				Sleep/c=-1/S shutterDelay
			endif
			// lineGate on ctr 1 WITH NO TRIGGER
			DAQmx_CTR_OutputPulse /DEV=s.ImageBoard/TICK={(s.PixWidthTotal - s.PixWidth)*pixTix, s.PixWidth*pixTix} /IDLE=0 /NPLS=0/TBAS="/" + s.ImageBoard + "/20MhzTimeBase" /Rate=(20e06) 1; ABORTONRTE
			DAQmx_CTR_OutputPulse /DEV=s.ImageBoard/TICK={pixOn, pixOff} /IDLE=0 /NPLS=0/TBAS="/" + s.ImageBoard + "/20MhzTimeBase" /Rate=(20e06)/PAUS={"/" + s.imageBoard + "/ctr1InternalOutput", 1, 1}  0; ABORTONRTE
		endif
	catch
		variable err=GetRTError(1)
		printf  "The \"NQ_ScanInit\" function failed:\r%s\r", fDAQmx_ErrorString()
		return 1 // exit with failure
	endtry
	return 0
end
		
#endif


//*****************************************************************************************************************************
// structure for background function for shutter/trigger
// Last modified 2025/09/03 by Jamie Boyd
STRUCTURE shutterBkgStruct
	STRUCT WMBackgroundStruct WMS
	uint32 shutterIsOpen
	uint32 shutterTaskNum
	uint32 triggerTaskNum
	uint32 shutterOpenLevel
EndStructure


//*****************************************************************************************************************************
// background function for shutter/trigger-opens the shutter when trigger line goes high. Scan starts on high-to-low, 
// so width of pulse determines how long we wait for shutter to open, give or take the 16.7 ms period of the bkg task.
// Last modified 2025/09/03 by Jamie Boyd
Function twoP_WaitForShutter (s)
	STRUCT shutterBkgStruct &s 
	
	if (s.WMS.started)
		s.WMS.started = 0
		NVAR shutterTaskNum = root:packages:twoP:Acquire:shutterTaskNum
		NVAR shutterOpenLevel = root:Packages:twoP:acquire:shutterOpenLevel
		NVAR triggerTaskNum =  root:packages:twoP:Acquire:triggerTaskNum
		s.shutterTaskNum =shutterTaskNum
		s.triggerTaskNum = triggerTaskNum
		s.shutterOpenLevel = shutterOpenLevel
		s.shutterIsOpen =0
	else
		SVAR imageBoard =  root:packages:twoP:Acquire:ImageBoard
		if (!(s.shutterIsOpen))
			if ((fDAQmx_DIO_Read(imageBoard, s.triggerTaskNum)) ||(fDAQmx_ScanGetNextIndex(imageBoard) > 0))
				fDAQmx_DIO_Write(imageBoard, s.shutterTaskNum, s.shutterOpenLevel)
				s.shutterIsOpen = 1
				print "Shutter open"
			endif	
		else
			if (fDAQmx_ScanGetNextIndex(imageBoard) > 0)
				Button AqStartButton  win = twoP_Controls,title="Abort", fColor=(65280,0,0)
				return 1
			endif
		endif
	endif
	return 0
end

// **************************************************************************************************
// Generic stuff done whenever a live scan is stopped, or a scan finishes, or is aborted
// Other specific things will have to be done depending on scan mode
// Last Modified 2025/08/29 by Jamie boyd
Function twoP_scanStop()
	// release threads
	NVAR gThreadGroupID = root:packages:twoP:Acquire:gThreadGroupID
	variable released = threadgroupRelease(gThreadGroupID)
	// close the shutter
	SVAR imageBoard = root:packages:twoP:Acquire:imageBoard
	NVAR shutterTaskNum = root:packages:twoP:Acquire:shutterTaskNum
	NVAR shutterOpenLevel = root:Packages:twoP:acquire:shutterOpenLevel
	fDAQmx_DIO_Write(imageBoard, shutterTaskNum, (!(shutterOpenLevel)))
	// stop scanning
	fDAQmx_ScanStop(imageBoard)
	// Stop the waveform Generator
	fDAQmx_WaveformStop(imageBoard)
	// stop the counters
	fDAQmx_CTR_Finished(imageBoard, 1)
	fDAQmx_CTR_Finished(imageBoard, 0)
	// stop background tasks - no error stopping a task that is not currently running
	CtrlNamedBackground tSeriesTask stop
	CtrlNamedBackground shutterTask stop 
	// reset start button and percent complete display
	Button AqStartButton, win = twoP_Controls, title="Start",fColor=(0, 65280, 0), proc= NQ_StartScan
	ValDisplay AqPercentCompleteDisplay win= twoP_Controls, mode=3
	NVAR percentComplete=root:packages:twoP:Acquire:PercentComplete
	percentComplete = 0
end


//**********************************************************************************************************************
// sets a global variable the hook function or background task looks for so it can quit gracefully at the end of a frame
// if shift is held down, we don't mess around, just quit the threads
// Lat Modified 2025/08/12 by Jamie boyd
function twoP_StopOrAbort  (ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
		NVAR liveStop = root:Packages:twoP:Acquire:ScanStopOrAbort
		if (ba.eventMod & 2)
			twoP_scanStop()
			liveStop=0
		else
			liveStop = 1
		endif
		break
	endswitch
end


//**************************************************************************************************
// Starts threads for processing various scan modes
// Last modified 2025/08/26 by Jamie Boyd
Function twoP_AcquireStartThreads(s)
	STRUCT NQ_ScanStruct &s
	WAVE/WAVE threadData = root:packages:twoP:acquire:threadData
	variable iChan, nChans = ItemsInList (s.selImageChanList, ";")
	NVAR gThreadGroupID =  root:packages:twoP:acquire:gThreadGroupID
	gThreadGroupID = ThreadGroupCreate(nChans)

	switch (s.ScanMode)
		case kLiveMode:
			NVAR minLiveFrameTme =root:packages:twoP:acquire:minLiveFrameTime
			variable isByFrame= (s.frameTime > minLiveFrameTme)
			break
	endSwitch


	for (iChan=0; iChan < nCHans; iChan +=1)
		switch (s.ScanMode)
			case kLiveMode:
				ThreadStart gThreadGroupID, iChan, twoP_LiveThread(threadData, nChans, gThreadGroupID, isByFrame, s.numFrames, s.pixWidth, s.pixHeight, s.flybackMode, s.LiveHist, s.LiveROI, s.LROIleft, s.LROItop, s.LROIright, s.LROIbottom, s.liveRatio, s.ratioTopChanNum, s.ratioBottomChanNum)
				break
			case kTimeSeries:
				if (s.scanIsCyclic)
					ThreadStart gThreadGroupID, iChan, twoP_timeCyclicThread(threadData, nChans, gThreadGroupID, s.nCycFrames, s.pixWidth, s.pixHeight, s.flybackMode, s.LiveROI, s.LROIleft, s.LROItop, s.LROIright, s.LROIbottom, s.liveRatio, s.ratioTopChanNum, s.ratioBottomChanNum)
				else
					ThreadStart gThreadGroupID, iChan, twoP_timeSeriesThread(threadData, nChans, gThreadGroupID, s.pixWidth, s.pixHeight, s.flybackMode, s.LiveROI, s.LROIleft, s.LROItop, s.LROIright, s.LROIbottom, s.liveRatio, s.ratioTopChanNum, s.ratioBottomChanNum)
				endif
				break
		endSwitch
	endfor
end

//**************************************************************************************************
// Hook for live mode
// Last modified 2025/08/26 by Jamie Boyd
Function twoP_LiveHook(selImageChanList, numChans)
	string selImageChanList
	variable numChans
	
	NVAR liveStop = root:Packages:twoP:Acquire:ScanStopOrAbort
	NVAR gThreadGroupID =  root:Packages:twoP:Acquire:gThreadGroupID
	
	NVAR LiveiFrame = root:packages:twoP:acquire:LiveiFrame
	NVAR LiveNframes =  root:packages:twoP:acquire:numLiveAvgFrames
	
	String aChan
	variable iChan
	
	for (ichan =0; iChan < numChans; iChan +=1)
		newdatafolder/s :tdata
		variable/G iFrameG = LiveiFrame
		variable/G iChanG = iChan
		string/G aChanG = stringFromList(iChan, selImageChanList, ",")
		ThreadGroupPutDF gThreadGroupID, :
	endfor
	
	// to update the RGB wave dependency formula, one of the waves has to be modified outside the thread
	// TODO: update RGB wave directly from thread
	NVAR hasRGB = root:Packages:twoP:examine:RGB_hasRGB
	if (hasRGB)
		wave touchMe = $"root:twoP_scans:LiveScan:liveScan_" +stringFromList (0, stringFromList(0, selImageChanList,";"),":")
		touchMe [0] [0] +=1
	endif
	
	LiveiFrame +=1
	if (LiveiFrame == LiveNframes)
		LiveiFrame =0
	endif
	
	// percent complete - just setting it to 1 advances the phase
	NVAR percentComplete = root:packages:twoP:Acquire:percentComplete
	percentComplete=1
	
	
	if (liveStop)
		sleep /S 10e-03		// gives some time for threads to grab the last frame of data and display it
		twoP_scanStop()
		liveStop=0
	endif
end


//**************************************************************************************************
// Thread function for live mode
// Last modified 2025/08/15 by Jamie Boyd
ThreadSafe Function twoP_LiveThread(threadfWaves, nChans,threadGroupID, isByFrame, numFrames, pixWidth, pixHeight, flybackMode, LiveHist, LiveROI, LROIleft, LROItop, LROIright, LROIbottom, liveRatio, topChan,bottomChan)
	WAVE/WAVE threadfWaves
	variable nChans
	variable threadGroupID
	variable isByFrame
	variable numFrames
	variable pixWidth
	variable pixHeight
	variable flybackMode
	variable LiveHist
	variable liveROI
	variable LROIleft
	variable LROItop
	variable LROIright
	variable LROIbottom
	variable liveRatio
	variable topChan
	variable bottomChan


	if (liveRatio)
		WAVE LROIRatio = threadfWaves [5*nChans + 1]
		WAVE topWave =  threadfWaves [topChan]
		WAVE bottomWave =  threadfWaves [bottomChan]
	endif

	for (;;)
		DFREF dfr = ThreadGroupGetDFR(threadGroupID,inf)
		NVAR iPlane=dfr:iFrameG
		NVAR iChan = dfr:iChanG
		SVAR aChan = dfr:aChanG
		WAVE acq1d = threadfWaves [iChan *5]
		WAVE acq3D = threadfWaves [iChan *5 +1]
		WAVE acq2D = threadfWaves [iChan *5 + 2]
		

		if (isByFrame)
			acq3D [] [] [iPlane] = acq1d [q*pixWidth + p]
			acq3D [] [] [iPlane] = acq3D > 32767 ? 0 :  acq3D
		else
			acq3D = acq1d
			acq3D = acq3D > 32767 ? 0: acq3D
		endif

		KalmanSpecFrames(acq3D, 0, (numFrames -1), acq2D, 0, 16)
		if (flybackMode)
			SwapEven (acq2D)
		endif

		if (liveHist)
			WAVE/Z histWave = threadfWaves [iChan*5 +3]
			Histogram /B=2 acq1d, HistWave
		endif

		if (liveROI)
			WAVE LROIWave = threadfWaves [iChan*5 + 4]
			ImageStats/M=1/GS={ LROIleft,LROIright,LROIbottom,  LROItop } acq2D
			Rotate 1, LROIWave
			LROIWave [0] = V_avg
			if ((liveRatio) && (iChan == nChans-1))
				Rotate 1, LROIRatio
				LROIRatio [0] = topWave[0]/bottomWave[0]
			endif
		endif

		killdataFolder dfr
	endfor
	return 0
end

//**************************************************************************************************
// Hook for time series cyclic mode
// Last modified 2025/09/03 by Jamie Boyd
Function twoP_timeCyclicHook(imageChans, numChans, nCycleFrames, pixWidth, pixHeight, numFrames, flybackMode)
	string imageChans
	variable numChans
	variable nCycleFrames
	variable pixWidth, pixHeight, numFrames, flybackMode
	
	String aChan
	variable iChan
	
	NVAR gThreadGroupID =  root:Packages:twoP:Acquire:gThreadGroupID
	NVAR tSeriesFrame = root:packages:twoP:acquire:tSeriesFrame

	for (ichan =0; iChan < numChans; iChan +=1)
		newdatafolder/s :tdata
		variable/G tSeriesFrameG = tSeriesFrame
		variable/G iChanG = iChan
		string/G aChanG = stringFromList(iChan, imageChans, ",")
		ThreadGroupPutDF gThreadGroupID, :
	endfor

	tSeriesFrame += nCycleFrames
	NVAR PercentComplete=root:packages:twoP:Acquire:PercentComplete
	PercentComplete = 100*(tSeriesFrame/numFrames)
	NVAR liveStop = root:Packages:twoP:Acquire:ScanStopOrAbort
	if ((tSeriesFrame >= numFrames -1) || (liveStop))
		sleep /S 10e-03		// gives some time for threads to grab the last frame of data and display it
		twoP_scanStop()
		SVAR scanName = root:Packages:twoP:acquire:NewScanName
		SVAR infoStr= $"root:twoP_Scans:" + scanName +  ":" + scanName + "_info"
		variable xOffset = NumberByKey("Xoffset", infoStr, ":", "\r")
		variable yOffset = NumberByKey("Yoffset", infoStr, ":", "\r")
		variable xScal= NumberByKey("XPixSize", infoStr, ":", "\r")
		variable yScal= NumberByKey("YPixSize", infoStr, ":", "\r")
		variable zScal= NumberByKey("FrameTime", infoStr, ":", "\r")
		for (ichan =0; iChan < numChans; iChan +=1)
			WAVE scanWave= $"root:twoP_Scans:" + scanName +  ":" + scanName + "_" +  stringFromList(iChan, imageChans, ",")
			if (liveStop)
				redimension/w/u/n=(pixWidth, pixHeight, tSeriesFrame) scanWave
			else
				redimension/w/u/n=(pixWidth, pixHeight, numFrames) scanWave
			endif
			if (flybackMode)
				SwapEven (scanWave)
			endif
			setscale/p x xOffset, xScal, "m", scanWave
			setscale/p y yOffset, yScal, "m", scanWave
			setscale/p z 0, zScal, "s", scanWave
		endfor
			
		if (liveStop)
			infoStr= ReplaceNumberByKey("numFrames", infoStr, tSeriesFrame, ":", "\r")
			liveStop  =0
			// even though it was cut short, it is still a scan
			// Make sure controls will be set properly when user switches to examine side of things
			GUIPTabClick ("twoP_Controls", "AcquireExamineTab", "Examine")
			SVAR NewScanName =  root:packages:twoP:Acquire:NewScanName
			twoP_ScanAdjustExamineControls (NewScanName)
			NVAR autincCheck = root:packages:twoP:Acquire:autIncCheck
			if (autIncCheck)
				NewScanName = twoP_autinc (NewScanName, 1)
			endif
			NVAR toDo=root:packages:twoP:acquire:exportAfterScan
			if (toDo)
				NQ_ExportAfterScan(toDo)
			endif
		endif
	endif
end

//**************************************************************************************************
// Thread function fortime series cyclic mode
// Last modified 2025/09/03 by Jamie Boyd
ThreadSafe Function twoP_timeCyclicThread(threadfWaves, nChans, threadGroupID, nCycFrames, pixWidth, pixHeight, flybackMode, LiveROI, LROIleft, LROItop, LROIright, LROIbottom, liveRatio, topChan, bottomChan)
	WAVE/WAVE threadfWaves
	variable nChans
	variable threadGroupID
	variable nCycFrames
	variable pixWidth
	variable pixHeight
	variable flybackMode
	variable liveROI
	variable LROIleft
	variable LROItop
	variable LROIright
	variable LROIbottom
	variable liveRatio
	variable topChan
	variable bottomChan

	variable frameSize= pixWidth *pixHeight
	variable chunkSize =  nCycFrames * frameSize

	if (liveRatio)
		WAVE LROIRatio = threadfWaves [4*nChans + 1]
		WAVE topWave =  threadfWaves [topChan]
		WAVE bottomWave =  threadfWaves [bottomChan]
	endif
		
	variable startP
	
	for (;;)
		DFREF dfr = ThreadGroupGetDFR(threadGroupID,inf)
		NVAR tseriesFrame = dfr:tSeriesFrameG
		NVAR iChan = dfr:iChanG
		SVAR aChan = dfr:aChanG
		WAVE scanWave = threadfWaves [iChan *4]
		WAVE acq1D = threadfWaves [iChan *4 + 1]
		WAVE acq2D = threadfWaves [iChan *4 + 2]
		startP = tseriesFrame * frameSize
		scanWave [startP, startP  + chunkSize -1] = acq1d [p - startP]
		// for display
		acq2D = acq1d
		acq2D = acq2D > 32767 ? 0: acq2D
		if (flybackMode)
			SwapEven (acq2D)
		endif
		if (liveROI)
			WAVE LROIWave = threadfWaves [iChan*4 + 3]
			ImageStats/M=1/GS={ LROIleft,LROIright,LROIbottom,  LROItop } acq2D
			Rotate 1, LROIWave
			LROIWave [0] = V_avg
			if ((liveRatio) && (iChan == nChans-1))
				Rotate 1, LROIRatio
				LROIRatio [0] = topWave[0]/bottomWave[0]
			endif
		endif
	endfor
end




//*****************************************************************************************************************************
// structure for background function for time series non-cyclic mode
// Last modified 2025/09/03 by Jamie Boyd
STRUCTURE tSeriesBkgStruct
	STRUCT WMBackgroundStruct WMS
	uint32 pixWidth
	uint32 pixHeight
	uint32 numFrames
	uint32 frameSize
	float frameTime
	uint32 nChans
	uint32 flybackMode
	uint32 nBKGFrames
	uint32 chunkSize
	uint32 taskTicks
	int32 lastChunk
EndStructure


//*****************************************************************************************************************************
// background function for time series - non cyclical- displays a frame and does live ROI
// Last modified 2025/09/03 by Jamie Boyd
Function twoP_tSeriesBkg  (s)
	STRUCT tSeriesBkgStruct &s
	
	if (s.WMS.started)
		s.WMS.started = 0
		s.lastChunk = -1
		NVAR PixWidth= root:Packages:twoP:acquire:PixWidth
		NVAR PixHeight=root:Packages:twoP:acquire:PixHeight
		NVAR numFrames= root:Packages:twoP:acquire:TSeriesFrames
		NVAR FrameTime = root:Packages:twoP:acquire:FrameTime
		NVAR nBKGFrames = root:packages:twoP:acquire:nBKGFrames
		NVAR flybackMode=root:Packages:twoP:acquire:FlyBackMode
		SVAR chanList=root:Packages:twoP:acquire:selImageChanList
		s.PixWidth= PixWidth
		s.PixHeight=PixHeight
		s.numFrames = numFrames
		s.frameSize=PixWidth*PixHeight
		s.frameTime=FrameTime
		s.nBKGFrames = nBKGFrames
		s.nChans=itemsInList (chanList, ";")
		s.flybackMode = flybackMode
		s.taskTicks =ceil (60*FrameTime * nBKGFrames)
		s.chunkSize=s.frameSize*s.nBKGFrames
	endif
	
	SVAR chanList=root:Packages:twoP:acquire:selImageChanList
	variable iChan
	string aChan
	SVAR imageBoard =  root:packages:twoP:Acquire:ImageBoard
	variable nextPt = fDAQmx_ScanGetNextIndex(imageBoard)
	variable readyFrame
	variable readyChunk = floor (nextPt/(s.chunkSize)) - 1
	variable ticksTilNext
	//printf "Next point=%d,readyChunk=%d\r", nextPt, readyChunk
	if (readyChunk > s.lastChunk)
		s.lastChunk = readyChunk
		readyFrame = readyChunk * s.nBKGFrames
		//printf "Displaying frame %d\r", readyFrame
		NVAR gThreadGroupID =  root:Packages:twoP:Acquire:gThreadGroupID
		for (ichan =0; iChan < s.nChans; iChan +=1)
			newdatafolder/s :tdata
			variable/G iFrameG = readyFrame
			variable/G iChanG = iChan
			string/G aChanG = stringFromList (0, stringFromList(iChan, chanList,";"),":")
			ThreadGroupPutDF gThreadGroupID, :
		endfor
	else
		ticksTilNext = ((s.chunkSize - mod (nextPt, s.chunkSize)) / s.chunkSize)* s.taskTicks
		//printf "added ticks = %d\r", ticksTilNext
		s.WMS.nextRunTicks = ticks + ticksTilNext
		return 0
	endif
	
	NVAR liveStop = root:Packages:twoP:Acquire:ScanStopOrAbort
	if (liveStop)
		sleep /S 10e-03		// gives some time for threads to grab the last frame of data and display it
		twoP_scanStop()
		liveStop =0
		SVAR scanName = root:Packages:twoP:acquire:NewScanName
		SVAR infoStr= $"root:twoP_Scans:" + scanName +  ":" + scanName + "_info"
		variable xOffset = NumberByKey("Xoffset", infoStr, ":", "\r")
		variable yOffset = NumberByKey("Yoffset", infoStr, ":", "\r")
		variable xScal= NumberByKey("XPixSize", infoStr, ":", "\r")
		variable yScal= NumberByKey("YPixSize", infoStr, ":", "\r")
		variable zScal= NumberByKey("FrameTime", infoStr, ":", "\r")
		for (ichan =0; iChan < s.nChans; iChan +=1)
			WAVE scanWave= $"root:twoP_Scans:" + scanName +  ":" + scanName + "_" +  stringFromList (0, stringFromList(iChan, chanList, ";"), ":")
			redimension/w/u/n=(s.pixWidth, s.pixHeight, readyFrame) scanWave
			if (s.flybackMode)
				SwapEven (scanWave)
			endif
			setscale/p x xOffset, xScal, "m", scanWave
			setscale/p y yOffset, yScal, "m", scanWave
			setscale/p z 0, zScal, "s", scanWave
		endfor
		// even though it was cut short, it is still a scan
		// Make sure controls will be set properly when user switches to examine side of things
		GUIPTabClick ("twoP_Controls", "AcquireExamineTab", "Examine")
		SVAR NewScanName =  root:packages:twoP:Acquire:NewScanName
		twoP_ScanAdjustExamineControls (NewScanName)
		NVAR autincCheck = root:packages:twoP:Acquire:autIncCheck
		if (autIncCheck)
			NewScanName = twoP_autinc (NewScanName, 1)
		endif
		NVAR toDo =root:packages:twoP:acquire:exportAfterScan
		if (toDo)
			NQ_ExportAfterScan(toDo)
		endif
		return 1
	else
		NVAR PercentComplete=root:packages:twoP:Acquire:PercentComplete
		PercentComplete = 100*(readyFrame/s.numFrames)
		return 0
	endif
end

//**************************************************************************************************
// Thread function fortime series non-cyclic mode - is calledby background function
// Last modified 2025/09/03 by Jamie Boyd
ThreadSafe Function twoP_timeSeriesThread(threadfWaves, nChans, threadGroupID, pixWidth, pixHeight, flybackMode, LiveROI, LROIleft, LROItop, LROIright, LROIbottom, liveRatio, TopChan, BottomChan)
	WAVE/WAVE threadfWaves
	variable nChans
	variable threadGroupID
	variable pixWidth
	variable pixHeight
	variable flybackMode
	variable liveROI
	variable LROIleft
	variable LROItop
	variable LROIright
	variable LROIbottom  
	variable liveRatio
	variable topChan
	variable bottomChan

	variable frameSize=pixWIdth*pixHeight

	if (liveRatio)
		WAVE LROIRatio = threadfWaves [4*nChans + 1]
		WAVE topWave =  threadfWaves [topChan]
		WAVE bottomWave =  threadfWaves [bottomChan]
	endif

	for (;;)
		DFREF dfr = ThreadGroupGetDFR(threadGroupID,inf)
		NVAR iChan = dfr:iChanG
		SVAR aChan = dfr:aChanG
		NVAR iFrame= dfr:iFrameG
		WAVE ScanWave = threadfWaves [iChan *4]
		WAVE acq2D = threadfWaves [iChan * 4 + 2]
		acq2D = ScanWave [q*pixWidth + p + (iFrame * frameSize)]
		acq2D =acq2D > 32767 ? 0 : acq2D
		if (flybackMode)
			SwapEven (acq2D)
		endif
		if (liveROI)
			WAVE LROIWave = threadfWaves [iChan*4 + 3]
			ImageStats/M=1/GS={ LROIleft,LROIright,LROIbottom,  LROItop } acq2D
			Rotate 1, LROIWave
			LROIWave [0] = V_avg
			if ((liveRatio) && (iChan == nChans-1))
				Rotate 1, LROIRatio
				LROIRatio [0] = topWave[0]/bottomWave[0]
			endif
		endif

		killdataFolder dfr
	endfor
	return 0
end


//**************************************************************************************************
// End Hook function for time series non-cyclic mode - redimensions 1D waves to 3D and shuts down scanning
// Last modified 2025/08/29 by Jamie Boyd 
function twoP_timeSeriesEndHook(scanName, chanList, pixWidth, pixHeight, numFrames, flybackMode)
	string scanName
	string chanList
	variable pixWidth
	variable pixHeight
	variable numFrames
	variable flybackMode

	twoP_scanStop()
	NVAR liveStop = root:packages:twoP:acquire:scanStopOrAbort
	liveStop = 1
	CtrlNamedBackground tSeriesTask stop
	//redimension the waves
	SVAR infoStr= $"root:twoP_Scans:" + scanName +  ":" + scanName + "_info"
	variable xOffset = NumberByKey("Xoffset", infoStr, ":", "\r")
	variable yOffset = NumberByKey("Yoffset", infoStr, ":", "\r")
	variable xScal= NumberByKey("XPixSize", infoStr, ":", "\r")
	variable yScal= NumberByKey("YPixSize", infoStr, ":", "\r")
	variable zScal= NumberByKey("FrameTime", infoStr, ":", "\r")
	variable nChans = itemsInlist (chanList, ",")
	String aChan
	variable iChan
	for (ichan =0; iChan < nChans; iChan +=1)
		aChan = stringFromList (iChan, chanList, ",")
		WAVE chanWave = $"root:twoP_Scans:" + scanName + ":" + scanName + "_" + aChan
		redimension/w/u/n=(pixWidth, pixHeight, numFrames) chanWave
		chanWave = chanWave > 32767 ? 0: chanWave
		if (flybackMode)
			SwapEven (chanWave)
		endif
		setscale/p x xOffset, xScal, "m", chanWave
		setscale/p y yOffset, yScal, "m", chanWave
		setscale/p z 0, zScal, "s", chanWave
	endfor
	// Make sure controls will be set properly when user switches to examine side of things
	GUIPTabClick ("twoP_Controls", "AcquireExamineTab", "Examine")
	SVAR NewScanName =  root:packages:twoP:Acquire:NewScanName
	twoP_ScanAdjustExamineControls (NewScanName)
	NVAR autincCheck = root:packages:twoP:Acquire:autIncCheck
	if (autIncCheck)
		NewScanName = twoP_autinc (NewScanName, 1)
	endif
	NVAR toDo =root:packages:twoP:acquire:exportAfterScan
	if (toDo)
		NQ_ExportAfterScan(toDo)
	endif
end


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
				case "Start": // starting a new scan
					
					// save scan mode in case user flips tabcontrol before stopping scan, or just disable
					ScanStartMode = scanMode
					TabControl SmodeTabControl disable=2
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
						// set galvos to end of X and Y images
						fDAQmx_WriteChan(s.ImageBoard, 0, s.xev, -10, 10)
						fDAQmx_WriteChan(s.ImageBoard, 1, s.xev, -10, 10)
						// make scan waves
						errPos=1
						err = NQ_MakeImageScanWaves (s);AbortOnValue (err), errPos //^^11
						// Check to see if ephys is requested and make wave(s) if so.
						if (s.ephysChans)
							errPos=2
							err = NQ_MakeEphysWaves (s);AbortOnValue (err), errPos 
						endif
							if (s.ScanMode == kePhysOnly)
								NQ_NewTracesGraph (s.NewScanName)
							else
								NQ_NewScanGraph (s.NewScanName)
								if (s.ephysChans != 0)
									NQ_NewTracesGraph (s.NewScanName)
								endif
								if ((s.ScanMode == kLiveMode) || (s.ScanMode) == kTimeSeries)
									if (s.liveROISecs > 0)
										twoP_MakeLROIGraph (s)
									endif
									if (s.ScanMode == kLiveMode)
										// live histogram graph
										
										// zero liveFrame pos for avergaing
										if (s.LiveAvgFrames)
											NVAR LiveAvgPos = root:packages:twoP:Acquire:LiveAvgPos
											LiveAvgPos = 0
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
							twoP_ResetBoards (1)
						endif
						
						return 1
					endtry
					break
			endswitch // status code switch
			break
	endSwitch  // button even switch
	return 0
end	


	

	
		// Set counter 1  to make the LineGate - it is low during data collection portion of the line, high during turnaround/flyback
		
			errPos=1
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
				
				
					if (s.scanIsCyclic)
						errPos =6
						DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/ao/SampleClock", 1}/PAUS={"/" + s.imageBoard + "/Ctr1InternalOutput", 1, 0, 0}/RPTC/RPTH=RPTCstr/ERRH= ScanErrStr WAVES = s.scanWavePath;ABORTONRTE
						AbortOnValue NidaqError,1
					else
						errPos=7
						DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/ao/SampleClock", 1}/PAUS={"/" + s.imageBoard + "/Ctr1InternalOutput", 1, 0, 0}/ERRH= ScanErrStr/EOSH=ScanEndStr WAVES = s.scanWavePath;ABORTONRTE
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
	
		// Start up the waveform generator that actually starts everything going
		string scanWavesList
		If (s.ScanMode == kLineScan)
			scanWavesList = "root:packages:twoP:acquire:HorWave, 0;"
		else
			scanWavesList = "root:packages:twoP:acquire:HorWave, 0;root:packages:twoP:acquire:VerWave, 1;"
		endif
		if (s.inputTrigger)
			//abortonvalue NidaqError, 10
			DAQmx_WaveformGen /DEV=s.imageBoard /BKG=0/NPRD=0/Strt=1 /TRIG={"/" + s.imageBoard + "/PFI6", 1} scanWavesList; abortOnRTE
		else
			DAQmx_WaveformGen /DEV=s.imageBoard /BKG=0/NPRD=0/Strt=1 scanWavesList;abortOnRTE
		endif

		
	catch
		printf  "The \"NQ_ScanInit\" function failed:\r%s\r", errPos, fDAQmx_ErrorString()
		GetRTError(1)
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
		NVAR shutterOpenLevel = root:Packages:twoP:acquire:shutterOpenLevel
		fDAQmx_DIO_Write(imageBoard, shutterTaskNum,  shutterOpenLevel)
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
	
	PercentComplete = 100 * (curFramePos + 2)/numFrames
	if (PercentComplete >= 100)

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
			//NQ_ApplyImSettings (4)
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
		scanGraphMrg [] [] [0] =  min (65280, max (0,(scangraph_ch1 [p] [q] - first1)) * rangevar)
		// green is channel 2
		rangevar = 65536/(last2 - first2)
		scanGraphMrg [] [] [1] =   min (65280, max (0,(scangraph_ch2 [p] [q] - first2)) * rangevar)
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
// Makes a new graph for live ROI display
// Last Modified 2025/08/08 by Jamie Boyd 
Function twoP_MakeLROIGraph (s)
	STRUCT NQ_ScanStruct &s
	
	// Kill old lROI graph
	DoWindow/K twoPLROIGraph
	// check for new graph
	if (s.liveROISecs == 0)
		return 0
	endif
	variable iChan, nChans= itemsInList (s.onlyChansImage, ",")
	string aChan
	string axisStr = ""
	variable lroiPoints, ptScale
	if (s.scanMode == kTimeSeries)
		lroiPoints = round(s.liveROISecs/(s.FrameTime * s.nCycFrames))
		ptScale = (-s.FrameTime*s.nCycFrames)
	elseif (s.scanMode == kLiveMode)
		lroiPoints = round(s.liveROISecs/s.FrameTime)
		ptScale = (-s.FrameTime)
	endif
	for (ichan= 0; iChan < nChans; iChan +=1)
		aChan = stringFromList(iChan, s.onlyChansImage, ",")
		WAVE/Z LROIWave = $"root:Packages:twoP:acquire:LroiWave_" +aChan
		if (!(WaveExists(LROIWave)))
			make/n= (lroiPoints) $"root:Packages:twoP:acquire:LroiWave_" +aChan
			WAVE LROIWave = $"root:Packages:twoP:acquire:LroiWave_" +aChan
		else
			redimension/n= (lroiPoints) LROIWave
		endif
		LROIWave = NaN
		SetScale /p x, 0, (ptScale),  "s",  LROIWave
		axisStr = AddListItem(aChan, axisStr, ";")
	endfor
	if (s.liveRatio)
		WAVE/Z LroiWave_ratio =  root:Packages:twoP:acquire:LroiWave_ratio
		if (WaveExists(LroiWave_ratio))
			redimension/n= (lroiPoints) LroiWave_ratio
		else
			make/n= (lroiPoints) root:Packages:twoP:acquire:LroiWave_ratio
			WAVE LroiWave_ratio =  root:Packages:twoP:acquire:LroiWave_ratio
		endif
		SetScale /p x, 0, (ptScale),  "",  LroiWave_ratio
		LroiWave_ratio = NaN
		axisStr = AddListItem("ratio", axisStr, ";")
	endif
	variable nAxes=Itemsinlist(axisStr, ";")
	// Display Graph
	Display/N=twoPLROIGraph/K=1 as "Live ROI Graph: " +s.newScanName
	variable iAxis, axisFrac = (1-.02*(nAxes-1))/nAxes
	string anAxis
	for (iAxis =0; iAxis < nAxes; iAxis += 1)
		anAxis = stringfromlist (iAxis, axisStr) 
		WAVE lROIWave = $"Root:Packages:twoP:acquire:LroiWave_" + anAxis
		appendtoGraph/L=$"L_" + anAxis lROIWave
		ModifyGraph freePos($"L_" + anAxis)=0
		ModifyGraph axisEnab($"L_" +  anAxis)={(iAxis * axisFrac) + (iAxis * .01) , ((iAxis + 1) * axisFrac) + (iAxis* .01)}
		label $"L_" + anAxis "Live ROI " + stringfromlist (iAxis, axisStr)
		ModifyGraph lblPos( $"L_" + anAxis)=60
	endfor
	Label bottom "\\Z12Time (Seconds)"
	ModifyGraph rgb =(0,0,0)
	setaxis/A/R bottom
	// Hook to save window position
	WC_WindowCoordinatesRestore("twoPLROIGraph")
	SetWindow twoPLROIGraph hook (saveHook)= twoP_UtilSaveWinPosHook, hookevents = 2
	return lroiPoints
end


//******************************************************************************************************
// Makes a new graph for live raw A/D value display
// Last Modified 2025/08/11 by Jamie Boyd 
Function twoP_MakeLiveRawGraph (s)
	STRUCT NQ_ScanStruct &s

	// Kill old lROI graph
	DoWindow/K twoPLiveRawGraph
	// check for new graph

	variable iChan, nChans= itemsInList (s.onlyChansImage, ",")
	string aChan
	string axisStr = ""
	for (ichan= 0; iChan < nChans; iChan +=1)
		aChan = stringFromList(iChan, s.onlyChansImage, ",")
		WAVE/Z LiveRaw = $"root:Packages:twoP:acquire:Acq1D_" +aChan
		if (WaveExists(LiveRaw))
		axisStr = AddListItem(aChan, axisStr, ";")
		endif
	endfor
	variable nAxes=Itemsinlist(axisStr, ";")
	// Display Graph
	Display/N=twoPLiveRawGraph as "Live Raw A/D Graph: " +s.newScanName
	variable iAxis, axisFrac = (1-.04*(nAxes-1))/nAxes
	string anAxis
	for (iAxis =0; iAxis < nAxes; iAxis += 1)
		anAxis = stringfromlist (iAxis, axisStr) 
		WAVE LiveRaw = $"Root:Packages:twoP:acquire:Acq1D_" + anAxis
		appendtoGraph/L=$"L_" + anAxis LiveRaw
		ModifyGraph mode($"Acq1D_" + anAxis)=2,lsize($"Acq1D_" + anAxis)=2, zColorMin($"Acq1D_" + anAxis)=(65280,0,0), zColorMax($"Acq1D_" + anAxis)=(0,0,0)
		ModifyGraph zColor($"Acq1D_" + anAxis)={LiveRaw,0,1,Grays,0}
		ModifyGraph freePos($"L_" + anAxis)={0,bottom}
		ModifyGraph axisEnab($"L_" +  anAxis)={(iAxis * axisFrac) + (iAxis * .02) , ((iAxis + 1) * axisFrac) + (iAxis* .02)}
		label $"L_" + anAxis "Live Raw A/D " + stringfromlist (iAxis, axisStr)
		ModifyGraph lblPos($"L_" + anAxis)=60
		ModifyGraph fSize($"L_" + anAxis)=12
		ModifyGraph btLen($"L_" + anAxis)=4
		SetDrawEnv dash=2, ycoord= $"L_" + anAxis
		DrawLine 0,0,1,0
		Setaxis $"L_" + anAxis -2048, 4095
		
	endfor
	// Don't really have a time scaling on bottom axis because of pause triggerfor flyback
	ModifyGraph nticks(bottom)=0
	ModifyGraph noLabel(bottom)=2
	// Hook to save window position
	WC_WindowCoordinatesRestore("twoPLiveRawGraph")
	ModifyGraph margin(left)=50,margin(bottom)=5,margin(right)=5,margin(top)=5
	SetWindow twoPLiveRawGraph hook (saveHook)= twoP_UtilSaveWinPosHook, hookevents = 2
end



"NQ_ScanEnd (%d, \"%s\", 0)", s.ScanMode, BKGtaskStr 



Function twoP_ScanErr(scanMode)
	variable scanMode
	
	string errStr =fdaqMx_ErrorString()
	
	
	
	printf "Scanning was aborted and NI boards reset because an error occured. The error message was:\r%s\r",  errStr
end

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
		twoP_ResetBoards ()
	else
		try
			// shutDown the image hardware, if an image scan
			if (abs (scanMode) != kEphysOnly)
				// close the shutter
				SVAR imageBoard = root:packages:twoP:Acquire:imageBoard
				NVAR shutterTaskNum = root:packages:twoP:Acquire:shutterTaskNum
				NVAR shutterOpenLevel = root:Packages:twoP:acquire:shutterOpenLevel
				errPos = 0
				err = fDAQmx_DIO_Write(imageBoard, shutterTaskNum, (!(shutterOpenLevel)));ABORTONVALUE (err), errPos
				// Stop the waveform Generator on the Imaging Board
				errPos =1
				err = fDAQmx_WaveformStop(imageBoard);ABORTONVALUE (err), errPos
				// stop the counters on the Imaging Board
				errPos = 2
				//err = fDAQmx_CTR_Finished(imageBoard, 0);ABORTONVALUE (err), errPos
				//errPos = 3
				err = fDAQmx_CTR_Finished(imageBoard, 1);ABORTONVALUE (err), errPos

				// Stop the scan manually if an abort/live mode end, a zSeries end with repeated scanning,
				NVAR isCyclic =  root:packages:twoP:acquire:isCyclic
				if (((ScanIsAbort)  || (scanMode == kzSeries)) || (ScanMode == kTimeSeries && (isCyclic)))
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
		if (cmpStr (curScan, "LiveScan") == 0)
			SVAR scanStr = root:twoP_Scans:LiveScanStr
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
				break
			case kSingleImage: // do Kalman averaging
				// stop background task
				//GUIPbkg_RemoveTask ("NQ_SingleImage_Bkg(*)")
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
				//edatawave *= kNQePhysScalerCh1
			endif
		endif
		if (ePhysChans & 2)
			WAVE eDataWave = $"root:twoP_Scans:" + curScan +":" +  curScan + "_ep2"
			if (Waveexists (eDataWave))
				//edatawave *= kNQePhysScalerCh2
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
				NewScanName = twoP_autinc (NewScanName, 1)
			endif
		endif
		// Make sure controls will be set properly when user switches to examine side of things
		if (scanMode > 0)
			GUIPTabClick ("twoP_Controls", "AcquireExamineTab", "Examine")
		endif
		twoP_ScanAdjustExamineControls (curScan)
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
			outwave [] [] [0] =  min (65280, max (0,(scangraph_ch1 [p] [q] - first1)) * rangevar)
			rangevar = 65536/(last2 - first2)
			outwave [] [] [1] =   min (65280, max (0,(scangraph_ch2 [p] [q] - first2)) * rangevar)
		else
			rangevar = 65536/(last1 - first1)
			outwave [] [] [1] =  min (65280, max (0,(scangraph_ch1 [p] [q] - first1)) * rangevar)
			rangevar = 65536/(last2 - first2)
			outwave [] [] [0] =   min (65280, max (0,(scangraph_ch2 [p] [q] - first2)) * rangevar)
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
	SVAR scanStr =$"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
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
		NVAR xStartVoltsFS = root:Packages:twoP:acquire:xStartVoltsFS
		NVAR xEndVoltsFS = root:Packages:twoP:acquire:xEndVoltsFS
		NVAR yStartVoltsFS = root:Packages:twoP:acquire:yStartVoltsFS
		NVAR yEndVoltsFS = root:Packages:twoP:acquire:yEndVoltsFS
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
	XSV = max (xStartVoltsFS, WaveXSV + (V_left - WaveXPos)/ WaveXScal)
	XEV= min (xEndVoltsFS, WaveXSV + (V_right - WaveXPos)/ WaveXScal)
	YSV = max (yStartVoltsFS, WaveYSV + (V_bottom - WaveYPos)/WaveYScal)
	YEV= min (yEndVoltsFS, WaveYSV + (V_top - WaveYPos)/WaveYScal)
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
		SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0,linefgc= (65280,65280,65280),linethick= 1, dash = 2
		DrawLine V_Left,V_Bottom, V_Right, V_Bottom 
	else
		V_top =  (YEV-WaveYSV) * WaveYScal + WaveYPos
		SetDrawLayer/K ProgFront
		SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0,linefgc= (0,0,0),linethick= 3.00
		DrawRect V_Left,V_top,V_right, V_bottom
		SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0,linefgc= (65280,65280,65280),linethick= 1, dash = 2
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
				//NVAR scanChans = root:Packages:twoP:Acquire:ScanChans
				//NQ_MakeHistGraph (scanChans, "LiveScan")
				twoP_HistMakeGraph()
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
	SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0,linefgc= (65280,65280,65280),linethick= 1, dash = 2
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
			//GUIPbkg_RemoveTask("NQ_MultiBkg_Wave(*)")
			SVAR WaveStr = root:packages:twoP:Acquire:multiAqWaveWaveStr
			WAVE/z maqWave = $"root:packages:twoP:acquire:multiAqWaves:" + WaveStr
			if (WaveExists (maqWave))
				nAqs = numPnts (maqWave)
			else
				nAqs = 0
			endif
			break
		case kMultiUseTrigger:
			//GUIPbkg_RemoveTask("NQ_MultiBkg_Trigger(*)")
			NVAR trigNum =root:packages:twoP:acquire:multiAqTriggerNum
			nAqs = trigNum
			break
	endswitch
	// reset start button
	Button MultiAqStartButton win = twoP_Controls, title="Start",  fColor=(0,65280,0), userdata = "Start Multi"
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
			NVAR multiAqScanMode =  root:packages:twoP:acquire:multiAqScanMode
			multiAqScanMode = pa.popNum
			//Set Times
			NQ_SetTimes ()
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Sets times for periodic acquisition, namely, initial delay and perioid
// Last modified Apr 02 2012 by Jamie Boyd

//******************************************************************************************************
// sets string to name of chosen wave or makes a new wave in the datafolder for timing waves
// Last modified Apr 03 2012 by Jamie Boyd

//******************************************************************************************************
//puts up a table to edit the selected timing wave
// Last Modified Apr 03 2012 by Jamie Boyd
Function NQ_MultiWaveEditButtonProc(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR TimingWaveStr = root:packages:twoP:Acquire:multiAqWaveWaveStr
	WAVE newtimingwave = $"root:packages:twoP:Acquire:multiAqWaves:" + TimingWaveStr
	edit/k=1 newTimingWave as "Edit Timing Wave:" + TimingWaveStr
End

//******************************************************************************************************
//Deletes the selected timing wave
// Last Modified Apr 03 2012 by Jamie Boyd
Function NQ_MultiWaveDeleteButtonProc(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR TimingWaveStr = root:packages:twoP:Acquire:multiAqWaveWaveStr
	WAVE newtimingwave = $"root:packages:twoP:Acquire:multiAqWaves:" + TimingWaveStr
	GUIPkilldisplayedwave (newtimingwave)
	TimingWaveStr= ""
End
	
//******************************************************************************************************
// parses time strings into nicer time strings
// If no colon, assume all is seconds. if 1 colon, assume seconds and minutes.
// if 2 colons, hours, minutes, seconds
// Last modified 2025/07/11 by Jamie Boyd -  no more pass by reference.  Used sscanf
Function/S NQ_MultiParseTimeStr (timeStr)
	string timeStr
	
	variable hours_in = 0, minutes_in= 0, seconds_in = 0
	variable v1, v2, v3
	sscanf timeStr, "%d:%d:%d", v1, v2, v3
	switch (V_FLag)
		case 0:
			return ""
			break
		case 1:
			seconds_in = v1
			break
		case 2:
			minutes_in=V1
			seconds_in = v2
			break
		case 3:
			hours_in =v1
			minutes_in=v2
			seconds_in=v3
		default:
			return ""
			break
	endswitch
	
	variable secs_out = mod (seconds_in, 60)
	variable mins_out = mod ((minutes_in + floor (seconds_in/60)), 60)
	variable hours_out = hours_in + floor (minutes_in/60)
	string timeOutStr
	sprintf timeOutStr "%02d:%02d:%02d" hours_out, mins_out, secs_out
	return timeOutStr
end
	

//************************************************************************************************
// reads equivalent seconds from a properly parsed time string
// Last modified 2025/07/11 by Jamie Boyd -Made separate function to get seconds from time string
function NQ_MultiReadTimeStr(timeStr)
	string timeStr
	
	variable hrs = str2num(StringFromList(0, timeStr, ":"))
	variable mins = str2num(StringFromList(1, timeStr, ":"))
	variable secs = str2num(StringFromList(2, timeStr, ":"))
	return (3600 * hrs + 60 *mins + secs)
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
			NQ_LoadScanStruct (s)
			for (iAq=0; iAq < nAqs; iAq +=1)
				if (1) // @@@ s.scanChans)
					NQ_MakeImageScanWaves (s)
				endif
				//if (s.ePhysChans)
					//NQ_MakeEPhysWaves (s) 
				//endif
				// adjust scan Name
				s.NewScanName =  twoP_autinc (s.NewScanName, 1)
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
				//waveMS = NQ_MultiParseTimeStr (waveDelayStr)
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
//background task for multi-acquisition
// Last Modified 2015/04/13 by Jamie Boyd
Function NQ_MultiBkg( s)
	STRUCT WMBackgroundStruct &s
	
	string tempStr
	NVAR multiMode = root:packages:twoP:acquire:multiAqTimeMode
	SVAR timeStrG =root:packages:twoP:acquire:multiAqTimeToNextStr 
	
	NVAR iAq = root:packages:twoP:acquire:multiAqiAq
	NVAR nAqs= root:packages:twoP:acquire:multiAqnAqs
	// check if a scan is in progres
	NVAR percentComplete = root:packages:twoP:Acquire:PercentComplete
	if (percentComplete !=0) // currently scanning a wave.could also check start button 
		sprintf tempStr,"SCANNING %d of %d", (iAq + 1), nAqs  // +1 for one based counting
		timeStrG = tempStr
		return 0
	endif
	if (iAq == nAqs)	// the scan end function will increment iAq, dont do it here
		sprintf tempStr,"ALL %d SCANS DONE", nAqs
		// clean up code here
		return 0
	endif
	// For times from a wave, update count down, and maybe start a scan
	if ((multiMode == kMultiUsePeriod) || (multiMode == kMultiUseWave))
		NVAR MultiAqStartTime = root:packages:twoP:acquire:MultiAqStartTime				// when scan was started
		NVAR MultiAqNextTime = root:packages:twoP:acquire:MultiAqNextTime			// timeof next scan
		variable rSecs = MultiAqNextTime -  datetime
		if (rSecs > 0)
			sprintf tempStr, "SCAN %d NEXT in %s.", iAq, NQ_MultiParseTimeStr (num2str (rSecs))
		else
			sprintf tempStr,"STARTING %d of %d", (iAq + 1), nAqs
			WAVE maq_seconds= root:packages:twoP:acquire:multiAqWaves:maq_seconds
			MultiAqNextTime = MultiAqStartTime + maq_seconds [iAq + 1]
			STRUCT WMButtonAction ba
			ba.eventcode = 2
			ba.UserData = "Start"
			NQ_StartScan (ba)
		endif
	elseif (multiMode ==kMultiUseTrigger)
		   sprintf tempStr,"WAITING FOR TRIGGER %d of %d", iAq, nAqs
	endif
	timeStrG = tempStr

	
end
	NVAR nextTime = root:packages:twoPhoton:acquire:MultiAqNextTime
	if (dateTime > nextTime)
		NVAR nAqs= root:packages:twoP:acquire:multiAqnAqs
		if (iAq == nAqs)
		NVAR startTime = root:packages:twoP:acquire:MultiAqStartTime
		//nextTime = 
		if (iAq + 1 == nAqs)
			SVAR timeStrG =root:packages:twoP:acquire:multiAqTimeToNextStr 
			Setformula timeStrG ""
			timeStrG = "Final Scan"
		endif
		
		
				STRUCT WMButtonAction ba
		ba.eventcode = 2
		ba.UserData = "Start"
		NQ_StartScan (ba)
	endif
	
		WAVE maq_Period = root:packages:twoP:acquire:multiAqWaves:maq_Period
		
		NVAR startSecs = root:packages:twoPhoton:acquire:MultiAqStartTime
	
		
	SVAR waveStr = root:packages:twoP:acquire:multiAqWaveWaveStr
	WAVE/T theWave = $"root:packages:twoP:Acquire:multiAqWaves:" + WaveStr
	NVAR timeToNext =  root:Packages:twoP:Acquire:multiAqTimeToNext
	// not currently scanning
		
	string timeStr = theWave [iAq] // time to next scan
	variable microSecs // will get microseconds to next scan 
	//NQ_MultiParseTimeStr (timeStr, microSecs)
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
	
	Switch (s.scanMode)
		case kLiveMode:
			
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
		//if (1) // @@@ s.scanChans & (2^iChan))
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
			//variable/G :showMerge = showMergeG
			//if (showMergeG)
				//tempChanVar = iChan + 1
				//execute "root:packages:twoP:examine:tempChanVar=$\"kNQChan\" + num2str (root:packages:twoP:examine:tempChanVar) + \"layer\""
				//variable/G :mergeLayer = tempChanVar
				//printf "MergeLayer = %d\r", tempChanVar
			//endif

			Switch (s.scanMode)
				case kLiveMode:
//					variable/G :nLiveFrames = nLiveFrames
//					variable/G :LiveAvgCheck =LiveAvgCheckG
//					if (LiveAvgCheckG)
//						variable/G :numLiveAvgFrames = numLiveAvgFramesG
//					endif
//					variable/G :liveHistCheck = liveHistCheckG
//					wave histWave = $""
//					if (liveHistCheckG)
//						WAVE histWave = $"root:packages:twoP:examine:histwavech" + num2str (iChan + 1)
//						duplicate histWave :histwave_cp
//					endif
//					WAVE acqWave = $"root:Packages:twoP:Acquire:LiveACQ_ch" + num2str (iChan + 1)
//					ThreadStart bkgThreadIDs [iChan], 0, NQ_LiveChanThread (acqWave, scanGraphWave, mergeWave, histWave)
					break
				case kZseries:
					variable/G :numZframes = s.numFrames
					variable/G :zAvgFrames = s.zAvg
					WAVE scanWave = $"root:twoP_Scans:" +  s.NewScanName + ":" + s.NewScanName + "_ch" + num2str(iChan + 1)
					WAVE acqWave = $"root:packages:twoP:acquire:TempZWave_ch" + num2str (iChan + 1)
					setscale/p x 0, 1e-03, acqWave
					variable/G :avgStackAtOnce = s.zAvgStackAtOnce // acqWave is 3D if this variable is set, else 2D
					//ThreadStart bkgThreadIDs [iChan], 0, NQ_zSeriesChanThread (scanWave, acqWave, scanGraphWave, mergeWave)
					break
				case kTimeSeries:
					WAVE scanWave = $"root:twoP_Scans:" +  s.NewScanName + ":" + s.NewScanName + "_ch" + num2str(iChan + 1)
					WAVE acqWave = $""
					
					if (s.scanIsCyclic)
						variable/G :tBufferSize = bufferSize
						variable/G :numFrames = nTFrames
						WAVE acqWave = $"root:packages:twoP:acquire:TempZWave_ch" + num2str (iChan + 1)
						setscale/p x 0, 1e-03, acqWave
						//ThreadStart bkgThreadIDs [iChan], 0, NQ_tSeriesCyclicChanThread (scanWave, acqWave, scanGraphWave, mergeWave)
					else
						NVAR firstColorG = $"root:packages:twoP:examine:Ch" + num2Str (iChan + 1) + "FirstLutColor"
						NVAR LastColorG = $"root:packages:twoP:examine:Ch" + num2Str (iChan + 1) + "LastLutColor"
						variable/G :firstColor = firstColorG
						variable/G :lastColor = lastColorG
						variable/G :numFrames = numFrames
						//ThreadStart bkgThreadIDs [iChan], 0, NQ_tSeriesChanThread (scanWave, scanGraphWave, mergeWave)
					endif
						
			endSwitch
			// post first datafolder for this channel
			//ThreadGroupPutDF bkgThreadIDs [iChan], root:packages:twoP:acquire:bkgStartFldr
		//else
		//	bkgThreadIDs [iChan] = NaN
		//endif
	endfor
	//setdatafolder saveDFR
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
				mergeWave [*] [*] [mergeLayer] =  min (65280, max (0,(scanGraphWave [p] [q] - firstColor)) * rangevar)
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
					mergeWave [*] [*] [mergeLayer] =  min (65280, max (0,(scanGraphWave [p] [q] - firstColor)) * rangevar)
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
					mergeWave [*] [*] [mergeLayer] =  min (65280, max (0,(scanGraphWave [p] [q] - firstColor)) * rangevar)
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
				mergeWave [*] [*] [mergeLayer] =  min (65280, max (0,(displayWave [p] [q] - firstColor)) * rangevar)
			endif
		endif
	endfor
	killdatafolder dfrInit
	return 0
end

Function setGalvoByCursor()
	String info
	Variable xPoint,yPoint,dX,dY,pixPerVolt
	
	info = CsrInfo(A,"twoPscanGraph#GCH1")
	xPoint = str2num(StringByKey("YPOINT",info,":",";")) // columns
	yPoint = str2num(StringByKey("POINT",info,":",";"))  //rows
	
	NVAR xStartVolts = root:Packages:twoP:Acquire:xStartVolts
	NVAR xEndVolts = root:Packages:twoP:Acquire:xEndVolts
	NVAR yStartVolts = root:Packages:twoP:Acquire:yStartVolts
	NVAR yEndVolts = root:Packages:twoP:Acquire:yEndVolts
	
	pixPerVolt = 500/3
	NVAR ppmXcrop = root:Packages:twoP:Acquire:xPixSize
	NVAR ppmYcrop = root:Packages:twoP:Acquire:yPixSize
	
	//closer to 200 nm/pixel is probably more accurate with a 100 micron field of view 
	variable ppmX = 200e-9 // nm/pixel  this needs o be empirically measured
	variable ppmY = 200e-9
	
	dX = round((xStartVolts - (-1.5))*pixPerVolt + xPoint)
	dY = round((yStartVolts - (-1.5))*pixPerVolt + yPoint)
	
		
	NVAR xStepSize = root:Packages:MS2000:xStepSize
	NVAR yStepSize = root:Packages:MS2000:yStepSize
	
	xStepSize = dX*ppmXcrop - 250*ppmX
	yStepSize = dY*ppmYcrop - 250*ppmY
	print xStepSize,yStepSize
End Function



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
			else // selecting an existing wave
				// need some validation here!
				WAVE/T timingWave = $"root:packages:twoP:Acquire:multiAqWaves:" + pa.popStr
				timingWave =  NQ_MultiParseTimeStr (timingWave)
				variable iPnt,nPnts = numpnts (timingWave)
				variable thisSecs, lastSecs = NQ_MultiReadTimeStr(timingWave [0])
				for (iPnt =1; iPnt <  nPnts; iPnt +=1, lastSecs= thisSecs)
					thisSecs = NQ_MultiReadTimeStr(timingWave [iPnt])
					if (numtype (thisSecs) != 0)
						doalert 0 , "The time wave is not of the right format."
						TimingWaveStr = ""
						return 0
					endif
					if (thisSecs < lastSecs)
						doalert 0, "Time waves need to contain elapsed times from start, not interscan periods."
						TimingWaveStr = ""
						return 0
					endif
				endfor
			endif
			TimingWaveStr = newTimingWaveStr
			break
	endswitch
	return 0
end

Function NQ_MultiAqTimeSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			SVAR strinG = $"root:packages:twoP:acquire:" + sva.vname
			strinG = NQ_MultiParseTimeStr (sva.sVal)
			break
	endswitch
	return 0
end




Function NQ_TrigSecsProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	if (sva.eventCode ==8 ||sva.eventCode == 1)
		if (cmpStr (sva.ctrlname, "Trig1SecsSetvar") ==0)
			NVAR delayFrames = root:packages:twoP:acquire:delayFrames1
			NVAR delayLines = root:packages:twoP:acquire:delayLines1
		elseif (cmpStr (sva.ctrlname, "Trig2SecsSetvar") ==0)
			NVAR delayFrames = root:packages:twoP:acquire:delayFrames2
			NVAR delayLines = root:packages:twoP:acquire:delayLines2
		endif
		NVAR scanMode = root:packages:twoP:acquire:scanMode
		if (scanMode ==  kTimeSeries)
			NVAR frameTime = root:packages:twoP:acquire:frameTime
			delayFrames = round (sva.dval/frameTime)
			NQ_SetTimes()
		elseif (scanMode ==  kLineScan)
			NVAR lineTime = root:packages:twoP:acquire:lineTime				
			delayLines = round (sva.dval/lineTime)
			NQ_SetTimes()
		endif
			
	endif
end





Function NQ_MultiStartProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
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
				// Set scan mode to chosen multi mode
				NVAR scanMode = root:packages:twoP:acquire:scanMode
				NVAR multiAqScanMode =  root:packages:twoP:acquire:multiAqScanMode
				scanMode = multiAqScanMode
				// update multiAq timing globals
				NVAR iAq = root:packages:twoP:acquire:multiAqiAq
				NVAR nAqs = root:packages:twoP:acquire:multiAqnAqs
				iAq =0
				NVAR multiMode = root:packages:twoP:acquire:multiAqTimeMode
				string theTask
				switch (multiMode)
					case kMultiUsePeriod:   // make a wave from the periods and use Wave method
						NVAR multiAqPeriodNum = root:packages:twoP:acquire:multiAqPeriodNum
						nAqs = multiAqPeriodNum
						SVAR periodStr = root:Packages:twoP:Acquire:multiAqPeriodPeriodStr
						variable period=NQ_MultiReadTimeStr(periodStr) 
						SVAR delayStr =root:packages:twoP:acquire:multiAqPeriodDelayStr
						variable delay =NQ_MultiReadTimeStr(delayStr)
						make/o/n= (nAqs) root:packages:twoP:acquire:multiAqWaves:maq_seconds
						WAVE maq_seconds = root:packages:twoP:acquire:multiAqWaves:maq_seconds
						maq_seconds [0]=delay
						maq_seconds [1,nAqs -1] = delay +p*period
						// no break
					case kMultiUseWave:
						if (multiMode == kMultiUseWave)
							SVAR multiWaveName = root:packages:twoP:Acquire:multiAqWaveWaveStr
							WAVE/t/z multiWave = $"root:packages:twoP:acquire:multiAqWaves:" + multiWaveName
							abortOnValue (!(waveExists (multiWave))), 3
							nAqs = numpnts(multiWave)
							make/o/n= (nAqs) root:packages:twoP:acquire:multiAqWaves:maq_Period
							WAVE maq_seconds = root:packages:twoP:acquire:multiAqWaves:maq_seconds
							maq_seconds = NQ_MultiReadTimeStr (multiWave[p])
						endif
						NVAR MultiAqStartTime = root:packages:twoP:acquire:MultiAqStartTime				// when scan was started
						NVAR MultiAqNextTime = root:packages:twoP:acquire:MultiAqNextTime
						MultiAqStartTime = dateTime
						MultiAqNextTime = MultiAqStartTime + maq_seconds [0]
						break
					case kMultiUseTrigger:
						NVAR inputTrigger = root:packages:twoP:acquire:inputTriggerCheck
						abortOnValue (inputTrigger != 1), 2
						NVAR multiAqTriggerNum = root:packages:twoP:acquire:multiAqTriggerNum
						nAqs =multiAqTriggerNum
						break
				endswitch
				// adjust multi-aq controls
				NVAR curNum = root:Packages:twoP:Acquire:NewScanNum
				variable/G root:packages:twoP:acquire:StartScanNum = curNum
				ValDisplay multiAqProgressDisplay win = twoP_Controls, limits={(curNum),(curNum + nAqs -1),(curNum)}
				ValDisplay multiAqProgressDisplay value=#"root:packages:twoP:acquire:multiAqiAq + root:packages:twoP:acquire:StartScanNum"
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
			TabControl SmodeTabControl disable=2
			Button AqStartButton disable=2
			CtrlNamedBackground multAqBKG, period=20, proc=NQ_MultiBkg, start
			Button MultiStartButton, win = twoP_Controls_new, fColor=(65280,65280,0), title = "Abort Multi", proc = NQ_Muli_AbortProc

			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function NQ_Muli_AbortProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			TabControl SmodeTabControl disable=0
			Button MultiStartButton, win = twoP_Controls_new, fColor=(65280,65280,0), title = "Start Multi", proc = NQ_Muli_StartProc
			// cleanup code here
		break
		case -1: // control being killed
			break
	endswitch

	return 0
end


•redimension/w/n = (200*200*2) root:twoP_Scans:Scan_000:Scan_000_ch1;DAQmx_Scan /DEV="PCI6023"/BKG WAVES ="root:twoP_Scans:Scan_000:Scan_000_ch1, 0/DIFF, -10, 10, 1, 100"
