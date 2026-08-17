#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#pragma version = 2.1  			// Last Modified: 2026/08/13 by Jamie Boyd.
#pragma IgorVersion = 7			//Not sure about this. Perhaps some Igor 9isms have slipped in

#include "twoP_Prefs"
#include "twoP_examine"
#include "twoPex_export"

#include "Stages"

// define for workaround for jamie's development environment without 6110, where /ai and /ao counts disagree by one
#define ENV_IS_DEVELOP

//Defined constants for multiacquisition mode
CONSTANT kMultiUsePeriod = 0
CONSTANT kMultiUseWave = 1
CONSTANT kMultiUseTrigger =2 

//******************************************************************************************************
//************************** Notes on National Instruments Boards ******************************
// One NI Board(referred to as the imageBoard) is used to generate the X and Y rasters that 
// drive the galvos, collect the image data, and open and close the shutter
// An -S or X-series board with at least 1M Samples/second per input channel, 2 output channels that update
// at 1MHz, 2 counter\timers, and at least 1 DIO port
  
// The other, optional, board(referred to as the ePhysBoard) is used to collect the ephys trace(s), 
// output TTL triggers, and output clamp waves. Slower sampling rates are acceptable here, 
// but 2 counter/timers and 2 analog outputs are still expected. E-series boards are fine


//******************************************************************************************************
// Let's put the functions to make the Main Control panel in the macros menu. The code to put the main NidaqScans panel in the 
// macro menu is found in  "NidaqProc_examine.ipf ".
Menu "Macros"
	Submenu "twoP"
		submenu "Acquire"
			"Reset the NI Boards",/Q,  twoP_ReSetBoards()
			"Zero the Galvos", /Q, twoP_ZeroGalvos()
		end
	end
end 


Menu "GraphMarquee"
	Submenu "twoP Acquire"
		"Zoom Scan", /Q,twoP_ImScaleSetMarquee(0)
		"Crop Scan", /Q, twoP_ImScaleSetMarquee(1)
		"Set Line Scan", /Q, twoP_ImScaleSetMarquee(2)
		"Set Live ROI", /Q, twoP_LiveMarqueeSetROI()
	end
End


// ***************************************************************************************************************************************
// **********************************  Initialization Functions  ********************************************************************
// ***************************************************************************************************************************************



// ***************************** twoP_AcquireInit ***********************************************
// Start up stuff for initializing global variables, controls on panel, setting up NI boards
// Last Modified: 2025/08/11 by Jamie Boyd
function twoP_AcquireInit()
	twoP_AcquireMakeFolder()
	twoP_AcquireAddControls()
	twoP_ReSetBoards()
end


//******************************** twoP_AcquireMakeFolder **********************************************************************
// Makes globals for acquire tab functions of the twoPhoton Control panel. 
// Last Modified 2025/08/11 by Jamie Boyd - Preferences loading will make some of the variables
Function twoP_AcquireMakeFolder()
	
	if(!(DataFolderExists("root:packages:twoP:acquire")))
		pathinfo twoPPrefsPath
		if(V_Flag == 0)
			newPath/C/Q/Z twoPPrefsPath SpecialDirPath("Igor Pro User Files" , 0, 0, 0) + "User Procedures:twoPhoton"
			PathInfo twoPPrefsPath
			if(V_flag == 0)
				DoAlert 0, "Igor could not find twoPhoton folder in User Procedures folder."
				return 1
			endif
			if(twoP_PrefsLoad("twoPPrefs_default"))
				return 1
			endif
		endif
	endif
	// image sizes(and backups) for normal images, start at full scale (some are alreadyy made by loading  twoPPrefs)
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
	// We will set these other timing variables with a call to twoP_TimesSetTimes
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
	setformula xImSize "abs(root:Packages:twoP:Acquire:xEndVolts - root:Packages:twoP:Acquire:xStartVolts) * str2num(root:packages:twoP:Acquire:ObjWave [root:packages:twoP:Acquire:curObjNum] [1])"
	setformula xPixSize "root:packages:twoP:Acquire:xImSize/root:Packages:twoP:Acquire:PixWidth"
	setformula yImSize "abs(root:Packages:twoP:Acquire:yEndVolts - root:Packages:twoP:Acquire:yStartVolts) * str2num(root:packages:twoP:Acquire:ObjWave [root:packages:twoP:Acquire:curObjNum] [2])"
	setformula yPixSize "root:packages:twoP:Acquire:yImSize/root:Packages:twoP:Acquire:PixHeight"
	// line scan X size and pixel size
	variable/G root:Packages:twoP:Acquire:LSImSize 
	variable/G root:Packages:twoP:Acquire:LSPixSize
	// Set dependency formulas for LineScan pix size
	NVAR LSImSize = root:Packages:twoP:Acquire:LSImSize
	NVAR LSPixSize = root:Packages:twoP:Acquire:LSPixSize
	setformula LSImSize "abs(root:Packages:twoP:Acquire:LSEndVolts - root:Packages:twoP:Acquire:LSStartVolts) * str2num(root:packages:twoP:Acquire:ObjWave [root:packages:twoP:Acquire:curObjNum] [1])"
	setformula LSPixSize "root:packages:twoP:Acquire:LSImSize/root:Packages:twoP:Acquire:LSWidth"
	// Aspect ratio of image(horizontal pixel size/vertical pixel size) backwards to most definitions, I now realize. Also, doesn't take into account possibility of different votage scaling for X and Y
	variable/G root:Packages:twoP:Acquire:AspectRatio = 1
	// globals for frame/line numbers for acquisition/averaging
	variable/G root:Packages:twoP:Acquire:ScanStopOrAbort = 0	// set by STOP button to stop or abort a scan
	// Live mode
	variable/G root:Packages:twoP:Acquire:LiveNumAvgFrames = 3	// number of frames averaged in scanGraphWave
	variable/G root:Packages:twoP:Acquire:LiveiAvgFrame = 0		// used to count frames being averaged
	variable/G root:Packages:twoP:Acquire:LiveStackAtOnce = 0	// set by setTimes if frameTime < minLiveFrameTime
	// Average
	variable/G root:Packages:twoP:Acquire:AvgDoUpdate = 0
	variable/G root:Packages:twoP:Acquire:AvgNumFrames = 5
	variable/G root:Packages:twoP:Acquire:AvgiFrame=0
	// Line Scan
	string/G root:Packages:twoP:Acquire:LSLinkWaveStr = "Don't Link" 	// Line Scan "link to wave" string
	variable/G root:packages:twoP:acquire:LSChunkSize					// number of lines to scan at a time or to process by background task
	variable/G root:packages:twoP:acquire:LSscanAtOnce = 1 				// if set, the entire line scan is done at once. This is the default
	variable/G root:packages:twoP:acquire:LSnumChunks					// number of chunks to make up acomplete scan
	variable/G root:packages:twoP:acquire:LSiChunk						// used to count chunks while scanning
	// Time series
	variable/G root:Packages:twoP:Acquire:TSeriesNumFrames = 50
	variable/G root:packages:twoP:acquire:tSeriesChunkSize
	variable/G root:packages:twoP:acquire:tSeriesNumChunks
	variable/G root:Packages:twoP:Acquire:TSeriesiChunk = 0
	variable/G root:packages:twoP:acquire:TSeriesScanAtOnce = 1
	// Live ROI, used by Live, Time series, and Line Scan
	variable/G root:Packages:twoP:Acquire:liveROISecs = 30
	variable/G root:Packages:twoP:Acquire:liveHistCheck
	variable/G root:Packages:twoP:Acquire:liveROICheck = 0
	variable/G root:Packages:twoP:Acquire:liveROIRatioCheck = 0
	variable/g root:Packages:twoP:Acquire:LROIL, root:Packages:twoP:Acquire:LROIT // left, Top,  coordinates for the Live ROI
	variable/g root:Packages:twoP:Acquire:LROIB, root:Packages:twoP:Acquire:LROIR // bottom, Right,  coordinates for the Live ROI
	String/G root:Packages:twoP:Acquire:LiveROITopChan
	String/G root:Packages:twoP:Acquire:LiveROIBottomChan
	variable/G root:Packages:twoP:Acquire:liveRawData
	// Z stack
	variable/G root:packages:twoP:acquire:zStepSize=1e-06
	variable/G root:Packages:twoP:Acquire:NumZseriesFrames = 10		// Stores Number of frames to collect in the Z dimension for Z Series Exp.
	variable/G root:Packages:twoP:Acquire:NumZseriesAvg = 3			// Number of frames to average for each z-position, i.e, Kalman averaging
	variable/G root:Packages:twoP:Acquire:ZFirstZ =0
	variable/G root:Packages:twoP:Acquire:ZLastZ =10e-6
	variable/G root:Packages:twoP:Acquire:zAvgStackAtOnce = 1 		// if frames are small, we collect Zavg frames at a time, else one frame at a time
	variable/G root:Packages:twoP:Acquire:ZseriesiFrame				// a global variable for counting z-series frames
	variable/G root:Packages:twoP:Acquire:ZseriesiAvg				// a global variable for counting frames to average for each z-step in a stack, when not avgStackAtOnce
	// ePhys
	variable/G root:Packages:twoP:Acquire:ePhysOnlyTime = 30
	// multiAq
	variable/G root:packages:twoP:acquire:multiModeIsMulti = 0				// set to 1 if mult-aq is in progress ,else 0
	variable/G root:packages:twoP:acquire:multiAqScanMode = kTimeSeries		// which kind of scan is done multliple times
	variable/G root:packages:twoP:acquire:multiAqTimeMode =kMultiUsePeriod	// mode is periodic, from a wave of times, start from a trigger 
	variable/G root:packages:twoP:acquire:multiAqiAq =0						// for counting acquisitions
	variable/G root:packages:twoP:acquire:multiAqnAqs =0
	variable/G root:packages:twoP:acquire:MultiAqStartTime					// when scan was started
	variable/G root:packages:twoP:acquire:MultiPreMakeWaves = 0				// will be set when waves for multiaq are to be pre-made
	string/G root:packages:twoP:acquire:multiAcqScanList = ""				// used to save list of prevetted, maybe pre-made scan names
	String/G root:packages:twoP:acquire:multiAcqScanNote = ""				//used for multiAq scan Note
	String/G root:packages:twoP:acquire:multiAcqScanStructStr = ""			// the non-string fields of a scan struct can be stored in a string
	String/G root:packages:twoP:acquire:multiAcqImScanList = ""				// list of image waves to scan, in NIDAQ format
	String/G root:packages:twoP:acquire:multiAcqEphysScanWaveList = ""      // list ePhys waves to scan, in NIDAQ format
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
	string/G root:packages:twoP:acquire:voltageWave1		// name of wave output from output 1, ao0
	string/G root:packages:twoP:acquire:voltageWave2		// name of wave output from output 2, ao1
	variable/G root:packages:twoP:Acquire:voltagePulseChans = 0		// 1 if output 1 is set, 2 for output 2, 3 for both
	variable/G root:packages:twoP:Acquire:voltagePulseMode=0		// 0 for straight line, 1 for square wave, 2 for sine wave
	variable/G root:packages:twoP:acquire:VoltagePulseFreq = 10		// frequency to add a sine or square wave segment
	variable/G root:packages:twoP:acquire:VoltagePulseHeight = 1	// amplitude to add a straight segment
	variable/G root:packages:twoP:acquire:VoltagePulseX1 = 0		// starting time or frame to add segment
	variable/G root:packages:twoP:acquire:VoltagePulseX2 = 1		// endingtime or frame to add segment
	variable/G root:packages:twoP:acquire:VoltagePulseY1 = 0		// voltage at start of line segment, or baseline for sine or square wave
	variable/G root:packages:twoP:acquire:VoltagePulseY2 = 0		// voltage at end of line segment,not used for sine or square wave
	string/G root:packages:twoP:acquire:VoltagePulseEditWave = ""	// name of wave to edit
	variable/G root:packages:twoP:acquire:VoltageAxis = 0			// set when horizontal axis is in frames
	variable/G root:packages:twoP:acquire:VoltageWaveScaling =0		// saves x scaling of wave when using frames
	// Exporting data after scan
	variable/G root:packages:twoP:acquire:exportAfterScan =0
	// Percent complete variable for scanning
	variable/G root:packages:twoP:Acquire:PercentComplete
	// Wave for fitting the cosine expansion used in outputting the Galvo Signals
	make/o/D root:packages:twoP:acquire:Scan_Coefs = {7.4, .65, .13, 0.015}
	make/o/n=635 root:packages:twoP:acquire:tempCos
	make/o/n=500  root:Packages:twoP:acquire:StraightLine
	// set experiment size
	variable/G root:packages:twoP:acquire:expSize = twoP_ExpSize()
	//threading for background processing during acquisition
	variable/G root:packages:twoP:acquire:gThreadGroupID
	make/o/n=6/WAVE root:packages:twoP:acquire:threadData
	// DIO shutter task and trigger task numbers
	variable/G root:packages:twoP:Acquire:shutterTaskNum
	variable/G root:packages:twoP:Acquire:triggerTaskNum
	return 0
end
		

//******************************** twoP_AcquireAddControls **********************************************************************
// Adds controls for the acquire functions to the twoP Controls panel
// Last Modified 2026/08/06 by Jamie Boyd
Function twoP_AcquireAddControls()
	DoWindow/F twoP_Controls
	if(!(V_Flag))
		return 1
	endif
	// Controls directly on Acquire tab
	// Experiment size,in termsof physical memory usage
	ValDisplay expSizeDisp,pos={5.00,23.00},size={334.00,17.00},title="Mem Use"
	ValDisplay expSizeDisp,help={"Shows Igor's use of physical memory compared to physical memory available to Igor"}
	ValDisplay expSizeDisp,fSize=12,format="%.2fGb",frame=2
	ValDisplay expSizeDisp,limits={0,(numberbykey("PHYSMEM", IgorInfo(0), ":", ";")/2^30),0},barmisc={0,50},highColor=(0,0,0),lowColor=(0,0,0)
	ValDisplay expSizeDisp,value=#"root:packages:twoP:acquire:expSize"
	GUIPTabAddCtrls("twoP_Controls", "AcquireExamineTab", "Acquire", "ValDisplay expSizeDisp 0;")
	// Image size controls
	GroupBox ImageSizeGrpBox,pos={3.00,40.00},size={336.00,107.00}
	GroupBox ImageSizeGrpBox,title="Image Size",frame=0
	GUIPTabAddCtrls("twoP_Controls", "AcquireExamineTab", "Acquire", "GroupBox ImageSizeGrpBox 0;")
	// pixel size
	SetVariable PixWidSetVar,pos={9.00,57.00},size={94.00,18.00},proc=twoP_TimesSetVarProc
	SetVariable PixWidSetVar,title="X pix",fSize=12
	SetVariable PixWidSetVar,limits={2,inf,2},value=root:Packages:twoP:Acquire:PixWidth
	SetVariable PixWidSetVar help={"Width of the image to be acquired, in pxels. Pixel scaling is determined by X galvo voltage range and objective"}
	SetVariable PixHeightSetVar,pos={9.00,76.00},size={94.00,18.00},proc=twoP_TimesSetVarProc
	SetVariable PixHeightSetVar,title="Y Pix",fSize=12
	SetVariable PixHeightSetVar,limits={2,inf,2},value=root:Packages:twoP:Acquire:PixHeight
	SetVariable PixHeightSetVar help={"Height of the image to be acquired, in pxels. Pixel scaling is determined by Y galvo voltage range and objective"}
	GUIPTabAddCtrls("twoP_Controls", "AcquireExamineTab", "Acquire", "Setvariable PixWidSetVar 0;SetVariable PixHeightSetVar 0;")
	// Volts
	NVAR xStartVoltsFS = root:Packages:twoP:Acquire:xStartVoltsFS
	NVAR xEndVoltsFS = root:Packages:twoP:Acquire:xEndVoltsFS
	NVAR yStartVoltsFS = root:Packages:twoP:Acquire:yStartVoltsFS
	NVAR yEndVoltsFS = root:Packages:twoP:Acquire:yEndVoltsFS
	// x stat
	SetVariable XStartSetVar,pos={118.00,57.00},size={105.00,18.00},title="X Start",fSize=12
	SetVariable XStartSetVar,value=root:Packages:twoP:Acquire:xStartVolts
	SetVariable XStartSetVar, help={"Minimum value of X galvo voltage during image acquisition, defines position of left edge of image"}
	GUIPSIsetVarEnable("TwoP_Controls", "XStartSetVar", "twoP_TimesSetVarProc", xStartVoltsFS, xEndVoltsFS, 0.1, 0, 0, 2, "V")
	// xend
	SetVariable XEndSetVar,pos={234.00,57.00},size={99.00,18.00},title="X End",fSize=12
	SetVariable XEndSetVar,value=root:Packages:twoP:Acquire:xEndVolts
	SetVariable XEndSetVar, help={"Maximum value of X galvo voltage during image acquisition, defines position of right edge of image"}
	GUIPSIsetVarEnable("TwoP_Controls", "XEndSetVar", "twoP_TimesSetVarProc", xStartVoltsFS, xEndVoltsFS, 0.1, 0, 0, 2, "V")
	// y start
	SetVariable YStartSetVar,pos={118.00,76.00},size={105.00,18.00},title="Y Start",fSize=12
	SetVariable YStartSetVar,value=root:Packages:twoP:Acquire:yStartVolts
	SetVariable YStartSetVar, help={"Minimum value of Y galvo voltage during image acquisition, defines position of bottom edge of image"}
	GUIPSIsetVarEnable("TwoP_Controls", "YStartSetVar", "twoP_TimesSetVarProc", yStartVoltsFS, yEndVoltsFS, 0.1, 0, 0, 2, "V")
	// y end
	SetVariable YEndSetVar,pos={235.00,76.00},size={98.00,18.00},title="Y End",fSize=12, disable=2
	SetVariable YEndSetVar,value=root:Packages:twoP:Acquire:yEndVolts
	SetVariable YEndSetVar,help={"Maximum value of Y galvo voltage during image acquisition, defines position of top edge of image"}
	GUIPSIsetVarEnable("TwoP_Controls", "YEndSetVar", "twoP_TimesSetVarProc", yStartVoltsFS, yEndVoltsFS, 0.1, 0, 0, 2, "V")
	GUIPTabAddCtrls("twoP_Controls", "AcquireExamineTab", "Acquire", "SetVariable XStartSetVar 0;SetVariable XEndSetVar 0;SetVariable YStartSetVar 0;SetVariable YEndSetVar 2;")
	// Image sizing controls
	Button FullScaleButton,pos={8.00,98.00},size={31.00,16.00},proc=twoP_ImScaleSetFullProc
	Button FullScaleButton,title="Full", help= {"Sets image pixel sizes and galvo scan voltage endpoints to full scale values defined in setings/preferences."}
	Button RevertScaleButton,pos={41.00,98.00},size={50.00,16.00},proc=twoP_ImScaleRevertProc
	Button RevertScaleButton,title="Revert", help={"Sets image pixel sizes and galvo scan voltage endpoints to last used values"}
	PopupMenu RevertScalePopMenu,pos={93.00,96.00},size={64.00,19.00},proc=twoP_ImScaleRevertToScanProc
	PopupMenu RevertScalePopMenu,title="to Scan:"
	PopupMenu RevertScalePopMenu,mode=0,value=#"twoP_ScanListScans(\"0,1,2,3,4,5,\")"
	SetVariable AspRatSetVar,pos={163.00,97.00},size={90.00,18.00},proc=twoP_AspectRatioSetvarProc
	SetVariable AspRatSetVar,title="Aspect",fSize=12,format="%#.3G"
	SetVariable AspRatSetVar,limits={0,inf,0.1},value=root:Packages:twoP:Acquire:AspectRatio
	PopupMenu AspRatPopUp,pos={258.00,96.00},size={77.00,19.00},proc=twoP_AspectRatioPopProc
	PopupMenu AspRatPopUp,fSize=12
	PopupMenu AspRatPopUp,mode=5,popvalue="Vary Y End",value=#"\"Vary X Start;Vary X  End;Vary X Pix;Vary Y Start;Vary Y End;Vary Y Pix;Free\""
	GUIPTabAddCtrls("twoP_Controls", "AcquireExamineTab", "Acquire", "Button FullScaleButton;Button RevertScaleButton;PopupMenu RevertScalePopMenu;SetVariable AspRatSetVar;PopupMenu AspRatPopUp;")
	// Objective Selection
	PopupMenu ObjPopUp,pos={8.00,121.00},size={44.00,19.00},proc=twoP_ObjPopProc
	PopupMenu ObjPopUp,title="Obj:",mode=0,value=#"twoP_ObjList()"
	TitleBox CurObjTitle,pos={57.00,123.00},size={18.00,15.00},fSize=12,frame=0
	TitleBox CurObjTitle,variable=root:Packages:twoP:Acquire:CurObj
	SetVariable xPixSizeSetVar,pos={85.00,122.00},size={152.00,18.00},title=" "
	SetVariable xPixSizeSetVar,fSize=12,format="Pixel Sizes X: %.2W1Pm/pix"
	SetVariable xPixSizeSetVar,frame=0
	SetVariable xPixSizeSetVar,limits={0,inf,0},value=root:Packages:twoP:Acquire:xPixSize,noedit=1
	SetVariable yPixSizeSetVar,pos={237.00,122.00},size={97.00,18.00},title=" "
	SetVariable yPixSizeSetVar,fSize=12,format="Y: %.2W1Pm/pix",frame=0
	SetVariable yPixSizeSetVar,limits={0,inf,0},value=root:Packages:twoP:Acquire:yPixSize,noedit=1
	GUIPTabAddCtrls("twoP_Controls", "AcquireExamineTab", "Acquire", "PopupMenu ObjPopUp;TitleBox CurObjTitle;SetVariable xPixSizeSetVar;SetVariable yPixSizeSetVar")
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
	CheckBox TurboCheck,pos={169.00,516.00},size={116.00,15.00},proc=twoP_TimesTurboCheckProc
	CheckBox TurboCheck,title="Bi-Directional Scan"
	CheckBox TurboCheck,help={"If On, data is collected on both directions of horizontal scan. If alternate lines of image are misaligned using Turbo, adjust  Scan Head Delay."}
	CheckBox TurboCheck,variable=root:Packages:twoP:Acquire:FlyBackMode
	GUIPTabAddCtrls("twoP_Controls", "AcquireExamineTab", "Acquire", "GroupBox TimesGrpBox;SetVariable LineTimeSetVar;SetVariable FrameTimeSetVar;SetVariable expTimeSetvar;CheckBox TurboCheck;")
	// Buttons to Open other windows
	Button aqShowScansButton,pos={7.00,547.00},size={49.00,18.00},proc=twoP_ScanShowScan
	Button aqShowScansButton,title="Scans"
	Button aqShowTracesButton,pos={73.00,547.00},size={57.00,18.00},proc=twoP_showTracesProc
	Button aqShowTracesButton,title="Traces"
	Button ShowScanSettingsButton,pos={142.00,547.00},size={98.00,18.00},proc=twoP_OpenPanelPrefsProc
	Button ShowScanSettingsButton,title="More Settings"
	Button showFocusPanelButton,pos={257.00,547.00},size={57.00,18.00},proc=twoP_OpenPanelFocusProc
	Button showFocusPanelButton,title="Focus"
	GUIPTabAddCtrls("twoP_Controls", "AcquireExamineTab", "Acquire", "Button aqShowScansButton;Button aqShowTracesButton;Button ShowScanSettingsButton;Button showFocusPanelButton;")
	//exp note
	NewNotebook /F=1 /N=ExpNoteBook /W=(1,572,339,636) /HOST=# 
	Notebook kwTopWin, defaultTab=10, autoSave= 0, magnification=1, showRuler=0, rulerUnits=1
	Notebook kwTopWin, newRuler=Normal, justification=0, margins={0,0,231}, spacing={0,0,0}, tabs={}, rulerDefaults={"Arial",11,0,(0,0,0)}
	RenameWindow #,ExpNoteBook
	GUIPTabAddCtrls("twoP_Controls", "AcquireExamineTab", "Acquire", "SubWindow ExpNoteBook;")
	// Scan Name
	SetVariable AqScanNameSetVar,pos={5.00,640.00},size={194.00,22.00},proc=twoP_NewScanNameProc
	SetVariable AqScanNameSetVar,title="New Scan Name"
	SetVariable AqScanNameSetVar,help={"The scan created when you press \"Start Scan\" will have this name."}
	SetVariable AqScanNameSetVar,fSize=14
	SetVariable AqScanNameSetVar,value=root:Packages:twoP:Acquire:NewScanName
	CheckBox AqAutIncCheck,pos={212.00,646.00},size={58.00,15.00},proc=twoP_NewScanNameIncProc
	CheckBox AqAutIncCheck,title="AutoInc"
	CheckBox AqAutIncCheck,help={"If checked, \"New Scan Name\" is given a numeric suffix and automatically incremented with every scan."}
	CheckBox AqAutIncCheck,variable=root:Packages:twoP:Acquire:AutincCheck
	CheckBox AqOverWriteWarnCheck,pos={282.00,645.00},size={44.00,15.00}
	CheckBox AqOverWriteWarnCheck,title="Warn"
	CheckBox AqOverWriteWarnCheck,help={"If checked, you will be warned if \"New Scan Name\" conflicts with an existing scan."}
	CheckBox AqOverWriteWarnCheck,variable=root:Packages:twoP:Acquire:overwriteWarnCheck
	GUIPTabAddCtrls("twoP_Controls", "AcquireExamineTab", "Acquire", "SetVariable AqScanNameSetVar;CheckBox AqAutIncCheck;CheckBox AqOverWriteWarnCheck;")
	// start settings
	PopupMenu AqExportAtScanEndPop,pos={7.00,667},size={150.00,19.00},proc=twoP_ExportAfterScanPopProc
	PopupMenu AqExportAtScanEndPop,title="At Scan end"
	PopupMenu AqExportAtScanEndPop,mode=1,popvalue="Do Nothing",value=#"\"Do Nothing;Save Experiment;Export Scan;Export and Delete Scan;Export Scan and Delete Last Scan;\""
	ValDisplay AqPercentCompleteDisplay,pos={3.00,690.00},size={226.00,17.00}, fsize=12, limits={0,100,0},barmisc={0,0}, value= _NUM:1, mode= 4
	Button AqStartButton,pos={236.00,677.00},size={52.00,29.00},proc=twoP_ScanStartSingleProc
	Button AqStartButton,title="Start ",help={"Starts or Aborts a Scan."}, userData = "Start"
	Button AqStartButton,userdata="START",fSize=16,fStyle=1
	Button AqStartButton,fColor=(0,65280,0)
	CheckBox AqInPutTrigCheck,pos={290.00,677.00},size={51.00,30.00}
	CheckBox AqInPutTrigCheck,title="On\rtrigger"
	CheckBox AqInPutTrigCheck,variable=root:Packages:twoP:Acquire:inputTriggerCheck
	GUIPTabAddCtrls("twoP_Controls", "AcquireExamineTab", "Acquire", "PopupMenu AqExportAtScanEndPop;ValDisplay AqPercentCompleteDisplay;Button AqStartButton;CheckBox AqInPutTrigCheck;")
	// controls on Scan mode tab control
	TabControl SmodeTabControl,pos={3.00,149.00},size={339.00,319.00},proc=GUIPTabProc
	TabControl SmodeTabControl,help={"Selects one of 6 possible type of scans to perform."}
	TabControl SmodeTabControl,fSize=12,tabLabel(0)="Live",tabLabel(1)="Tser"
	TabControl SmodeTabControl,tabLabel(2)="Avg",tabLabel(3)="Lines"
	TabControl SmodeTabControl,tabLabel(4)="Zser",tabLabel(5)="ePhys"
	TabControl SmodeTabControl,tabLabel(6)="Multi",value=0
	GUIPTabAddCtrls("twoP_Controls", "AcquireExamineTab", "Acquire", "TabControl SmodeTabControl;") 
	GUIPTabNewTabCtrl("twoP_Controls", "SmodeTabControl", TabList= "Live;Tser;Avg;Lines;Zser;ePhys;Multi;", UserFunc="twoP_AcquireSModeTabproc")
	// controls present on multiple tabs
	// Live mode im chans - Live;Tser;Avg;Zser;Multi
	PopupMenu ImageChansPopMenu,pos={9.00,176.00},size={91.00,19.00},proc=twoP_ChansProc
	PopupMenu ImageChansPopMenu,title="Image Chans",fSize=12
	PopupMenu ImageChansPopMenu,mode=0,value=#"twoP_ChansListActive(1)"
	TitleBox imChanListTitle,pos={107.00,180.00},size={62.00,15.00},frame=0
	TitleBox imChanListTitle,variable=root:Packages:twoP:Acquire:selImageChanList
	SVAR selImageChans = root:Packages:twoP:Acquire:selImageChanList
	selImageChans = ""
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "PopupMenu ImageChansPopMenu", "Live;Tser;Lines;Avg;Zser;Multi")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "TitleBox imChanListTitle", "Live;Tser;Lines;Avg;Zser;Multi")
	// ephys chans - TSer;Lines;ePhys;Multi
	PopupMenu EphysChansPopUp,pos={9.00,199.00},size={89.00,19.00},proc=twoP_ChansProc
	PopupMenu EphysChansPopUp,title="ePhys Chans"
	PopupMenu EphysChansPopUp,mode=0,value=#"twoP_ChansListActive(2)"
	PopupMenu EphysChansPopUp disable = 1
	TitleBox ePhysChanListTitle,pos={101.00,202.00},size={62.00,15.00},frame=0
	TitleBox ePhysChanListTitle,variable=root:Packages:twoP:Acquire:selEphysChanList
	TitleBox ePhysChanListTitle, disable = 1
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "PopupMenu EphysChansPopUp", "Tser;Lines;ePhys;Multi;")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "TitleBox ePhysChanListTitle", "TSer;Lines;ePhys;Multi;")
	// triggers - TSer;Lines;ePhys
	NVAR frameTime = root:packages:twoP:acquire:frameTime
	// trigger 1
	CheckBox Trig1Check,pos={9.00,335.00},size={44.00,15.00},title="Trig 1"
	CheckBox Trig1Check,fSize=12,variable=root:Packages:twoP:acquire:trig1Check
	CheckBox Trig1Check,disable=1
	SetVariable Trig1SecsSetvar,pos={194.00,333.00},size={82.00,18.00},title=" "
	SetVariable Trig1SecsSetvar,value=root:Packages:twoP:Acquire:DelaySecs1
	GUIPSIsetVarEnable("TwoP_Controls", "Trig1SecsSetvar", "twoP_TriggerSecsProc", 1e-7, 100, frameTime, 1, 0.1e-7, 2, "s")
	SetVariable Trig1SecsSetvar disable=1
	// trigger 2
	CheckBox Trig2Check,pos={9.00,355.00},size={44.00,15.00},title="Trig 2"
	CheckBox Trig2Check,fSize=12,variable=root:Packages:twoP:acquire:trig2Check
	CheckBox Trig2Check, disable=1
	SetVariable Trig2SecsSetvar,pos={194.00,353.00},size={82.00,18.00},title=" ",fSize=12
	SetVariable Trig2SecsSetvar,value=root:Packages:twoP:Acquire:DelaySecs2
	GUIPSIsetVarEnable("TwoP_Controls", "Trig2SecsSetvar", "twoP_TriggerSecsProc", 1e-7, 100, frameTime, 1, 0.1e-7, 2, "s")
	SetVariable Trig2SecsSetvar, disable=1
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "CheckBox Trig1Check", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "CheckBox Trig2Check", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "SetVariable Trig1SecsSetvar", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "SetVariable Trig2SecsSetvar", "TSer;Lines;ePhys")
	//Voltage Pulse waves  TSer;Lines;ePhys
	GroupBox VoltageWaveGrpBox,pos={8.00,376.00},size={331.00,88.00}
	GroupBox VoltageWaveGrpBox,title="Voltage Pulse", disable=1
	CheckBox Voltage1Check,pos={12.00,396.00},size={22.00,15.00},proc=twoP_VoltagePulseCheckProc
	CheckBox Voltage1Check,title="1",value=0, disable=1
	CheckBox Voltage2Check,pos={11.00,418.00},size={22.00,15.00},proc=twoP_VoltagePulseCheckProc
	CheckBox Voltage2Check,title="2",value=0, disable=1
	PopupMenu VoltagePulse1Popup,pos={39.00,394.00},size={96.00,19.00},proc=twoP_VoltagePulseSetWaveProc
	PopupMenu VoltagePulse1Popup,mode=0,value=#"GUIPListObjs((\"root:packages:twoP:acquire:VoltagePulseWaves\") , 1, \"*\", 0, \"\\M1(No Voltage Pulse Waves\")"
	PopupMenu VoltagePulse1Popup,title=" Voltage Wave", disable=1
	PopupMenu VoltagePulse2Popup,pos={39.00,417.00},size={93.00,19.00},proc=twoP_VoltagePulseSetWaveProc
	PopupMenu VoltagePulse2Popup,mode=0,value=#"GUIPListObjs((\"root:packages:twoP:acquire:VoltagePulseWaves\") , 1, \"*\", 0, \"\\M1(No Voltage Pulse Waves\")"
	PopupMenu VoltagePulse2Popup,title="Voltage Wave", disable=1
	TitleBox VoltagePulseWave1Title,pos={139.00,397.00},size={25.00,15.00},frame=0
	TitleBox VoltagePulseWave1Title,variable=root:packages:twoP:acquire:voltageWave1, disable=1
	TitleBox VoltagePulseWave2Title,pos={136.00,420.00},size={25.00,15.00},frame=0
	TitleBox VoltagePulseWave2Title,variable=root:packages:twoP:acquire:voltageWave2, disable=1
	PopupMenu VoltagePulsePopUp,pos={12.00,437.00},size={90.00,19.00},title="Vout"
	PopupMenu VoltagePulsePopUp,fSize=12, disable=1
	PopupMenu VoltagePulsePopUp,mode=1,popvalue="on Start",value=#"\"on Start;on Trig 2;\""
	Button VoltagePulseEditButton,pos={143.00,440.00},size={141.00,20.00},proc=twoP_VoltagePulseEditProc, disable=1
	Button VoltagePulseEditButton,title="Edit Voltage Waves"
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "GroupBox VoltageWaveGrpBox", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "CheckBox Voltage1Check", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "CheckBox Voltage2Check", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "PopupMenu VoltagePulse1Popup", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "PopupMenu VoltagePulse2Popup", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "TitleBox VoltagePulseWave1Title", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "TitleBox VoltagePulseWave2Title", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "Button VoltagePulseEditButton", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "Button VoltagePulseEditButton", "TSer;Lines;ePhys")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "PopupMenu VoltagePulsePopUp","TSer;Lines;ePhys")
	// Live Roi - Live;Tser;Lines"
	CheckBox LiveROICheck,pos={9.00,235.00},size={59.00,15.00},title="Live ROI"
	CheckBox LiveROICheck,fSize=12,variable=root:Packages:twoP:Acquire:liveROICheck
	CheckBox LiveROICheck, help = {"If you have set a live ROI from graph marquee menu, the results of the ROI will be shown in a graph suring Live scanning"}
	SetVariable LiveRoiTimeSetVar,pos={74.00,234.00},size={64.00,18.00},title=" ", fSize=12
	SetVariable LiveRoiTimeSetVar,help={"If doing Live ROIs, this many seconds will be shown in a scrolling graph."}
	SetVariable LiveRoiTimeSetVar,value=root:Packages:twoP:Acquire:liveROISecs
	GUIPSIsetVarEnable("TwoP_Controls", "LiveRoiTimeSetVar", "", 1, 100, 1, 1, 0.1e-3, 1, "s")
	CheckBox LroiRatioCheck,pos={33.00,258.00},size={43.00,15.00},title="Ratio"
	CheckBox LroiRatioCheck,fSize=12
	CheckBox LroiRatioCheck,variable=root:Packages:twoP:Acquire:liveROIRatioCheck
	PopupMenu LiveROIRatioTopPopMenu,pos={84.00,256.00},size={62.00,19.00},proc=twoP_LiveSetROIchanProc
	PopupMenu LiveROIRatioTopPopMenu,title="    Top   ",fSize=12
	PopupMenu LiveROIRatioTopPopMenu,mode=0,value=#"root:packages:twoP:acquire:selImagechanList"
	TitleBox LiveROIRatioTopChanTitle,pos={151.00,258.00},size={28.00,15.00}
	TitleBox LiveROIRatioTopChanTitle,frame=0
	TitleBox LiveROIRatioTopChanTitle,variable=root:Packages:twoP:Acquire:LiveROITopChan
	PopupMenu LiveROIRatioBottomPopMenu,pos={84.00,278.00},size={62.00,19.00},proc=twoP_LiveSetROIchanProc
	PopupMenu LiveROIRatioBottomPopMenu,title="Bottom",fSize=12
	PopupMenu LiveROIRatioBottomPopMenu,mode=0,value=#"root:packages:twoP:acquire:selImagechanList"
	TitleBox LiveROIRatioBottomChanTitle,pos={151.00,280.00},size={28.00,15.00}
	TitleBox LiveROIRatioBottomChanTitle,frame=0
	TitleBox LiveROIRatioBottomChanTitle,variable=root:Packages:twoP:Acquire:LiveROIBottomChan
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "CheckBox LiveROICheck", "Live;Tser;Lines")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "SetVariable LiveRoiTimeSetVar", "Live;Tser;Lines")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "CheckBox LroiRatioCheck", "Live;Tser;Lines")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "SetVariable LiveRoiTimeSetVar", "Live;Tser;Lines")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "CheckBox LroiRatioCheck", "Live;Tser;Lines")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "PopupMenu LiveROIRatioTopPopMenu", "Live;Tser;Lines")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "TitleBox LiveROIRatioTopChanTitle", "Live;Tser;Lines")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "PopupMenu LiveROIRatioBottomPopMenu", "Live;Tser;Lines")
	GUIPTabAddCtrlToTabs("twoP_Controls", "SmodeTabControl", "TitleBox LiveROIRatioBottomChanTitle","Live;Tser;Lines")
	// Live mode specific
	SetVariable LiveAvgFramesSetVar, pos={9.00,205.00},size={163.00,18.00},proc=twoP_TimesSetVarProc
	SetVariable LiveAvgFramesSetVar,title="Average per Frame",fSize=12
	SetVariable LiveAvgFramesSetVar,limits={0,inf,1},value=root:Packages:twoP:Acquire:LiveNumAvgFrames
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
	GUIPTabAddCtrls("twoP_Controls", "SmodeTabControl", "Live", "SetVariable LiveAvgFramesSetVar;CheckBox LiveHistCheck;")
	GUIPTabAddCtrls("twoP_Controls", "SmodeTabControl", "Live", "Button Trig1ManualButton;Button Trig2ManualButton;CheckBox LiveRawDataCheck;")
	// Time series specific
	SetVariable NumTSeriesFramesSetVar,pos={9.00,304.00},size={174.00,22.00},proc=twoP_TimesSetVarProc
	SetVariable NumTSeriesFramesSetVar,title="Time Series Frames",fSize=14
	SetVariable NumTSeriesFramesSetVar,limits={0,inf,1},value=root:Packages:twoP:Acquire:TSeriesNumFrames
	SetVariable NumTSeriesFramesSetVar, disable=1
	SetVariable FramesTrig1SetVar,pos={77.00,333.00},size={110.00,18.00},proc=twoP_TimesSetVarProc
	SetVariable FramesTrig1SetVar,title="on Frame",fSize=12
	SetVariable FramesTrig1SetVar,limits={0,inf,1},value=root:Packages:twoP:Acquire:DelayFrames1
	SetVariable FramesTrig1SetVar, disable=1
	SetVariable FramesTrig2SetVar,pos={77.00,353.00},size={110.00,18.00},proc=twoP_TimesSetVarProc
	SetVariable FramesTrig2SetVar,title="on Frame",fSize=12
	SetVariable FramesTrig2SetVar,limits={0,inf,1},value=root:Packages:twoP:Acquire:DelayFrames2
	SetVariable FramesTrig2SetVar disable=1
	GUIPTabAddCtrls("twoP_Controls", "SmodeTabControl", "Tser", "SetVariable NumTSeriesFramesSetVar;SetVariable FramesTrig1SetVar;SetVariable FramesTrig2SetVar")
	// Avg specific
	SetVariable AvgNumFramesSetVar,pos={9.00,303.00},size={176.00,22.00},proc=twoP_TimesSetVarProc
	SetVariable AvgNumFramesSetVar,title="Frames to Average",fSize=14
	SetVariable AvgNumFramesSetVar,limits={1,inf,1},value=root:Packages:twoP:Acquire:AvgNumFrames
	SetVariable AvgNumFramesSetVar, disable=1
	CheckBox AvgLiveUpdateCheck,pos={9.00,328.00},size={121.00,15.00}
	CheckBox AvgLiveUpdateCheck,title="Update as Collected"
	CheckBox AvgLiveUpdateCheck,help={"If checked, display on ScanGraph is updated with Kalman averaging after each frame is collected."}
	CheckBox AvgLiveUpdateCheck,variable=root:packages:twoP:acquire:AvgDoUpdate
	CheckBox AvgLiveUpdateCheck, disable = 1
	GUIPTabAddCtrls("twoP_Controls", "SmodeTabControl", "Avg", "SetVariable AvgNumFramesSetVar;CheckBox AvgLiveUpdateCheck;")
	// lines specific
	SetVariable LineScanXStartSetVar,pos={216.00,175.00},size={117.00,18.00},title="X Start",fSize=12
	SetVariable LineScanXStartSetVar,value=root:Packages:twoP:Acquire:LSStartVolts, disable =1
	GUIPSIsetVarEnable("TwoP_Controls", "LineScanXStartSetVar", "twoP_TimesSetVarProc", xStartVoltsFS, xEndVoltsFS, 0.1, 0, 0, 2, "V")
	SetVariable LineScanXEndSetVar,pos={217.00,198.00},size={117.00,18.00},title="X End",fSize=12
	SetVariable LineScanXEndSetVar,value=root:Packages:twoP:Acquire:LSEndVolts, disable=1
	GUIPSIsetVarEnable("TwoP_Controls", "LineScanXEndSetVar", "twoP_TimesSetVarProc", xStartVoltsFS, xEndVoltsFS, 0.1, 0, 0, 2, "V")
	SetVariable LineScanYSetVar,pos={217.00,219.00},size={117.00,18.00},title="Y",fSize=12
	SetVariable LineScanYSetVar,value=root:Packages:twoP:Acquire:LSYVolts, disable=1
	GUIPSIsetVarEnable("TwoP_Controls", "LineScanYSetVar", "twoP_TimesSetVarProc", yStartVoltsFS, yEndVoltsFS, 0.1, 0, 0, 2, "V")
	SetVariable LineScanWidthSetVar,title="X Pix",fSize=12,pos={217.00,241.00},size={118.00,18.00},proc=twoP_TimesSetVarProc
	SetVariable LineScanWidthSetVar,limits={2,inf,2},value=root:Packages:twoP:Acquire:LSWidth, disable=1
	SetVariable LineScanPixSizeSetVar,pos={246.00,261.00},size={89.00,18.00}
	SetVariable LineScanPixSizeSetVar,title=" ",fSize=12,format="Size %.1W1Pm/pix"
	SetVariable LineScanPixSizeSetVar,frame=0, disable=1
	SetVariable LineScanPixSizeSetVar,limits={0,inf,0},value=root:Packages:twoP:Acquire:LSPixSize,noedit=1,live=1
	Button LineScanRevertScaleButton,pos={203.00,281.00},size={50.00,20.00},proc=twoP_ImScaleLSRevertProc
	Button LineScanRevertScaleButton,title="Revert", disable=1
	PopupMenu LineScanRevertScalePopMenu, pos={259.00,281.00},size={64.00,19.00},proc=twoP_ImScaleLSrevertToScanProc
	PopupMenu LineScanRevertScalePopMenu,title="to Scan:",fSize=10, disable=1
	PopupMenu LineScanRevertScalePopMenu,mode=0,value=#"twoP_ScanListScans(\"3\")"
	PopupMenu LineScanLinktoPopMenu,pos={201.00,305.00},size={44.00,19.00},proc=twoP_LineScanLinkToProc
	PopupMenu LineScanLinktoPopMenu,title="Link", disable=1
	PopupMenu LineScanLinktoPopMenu,mode=0,value=#"root:packages:twoP:examine:curScan+\";\"+RemoveFromList(root:packages:twoP:examine:curScan,twoP_ScanListScans(\"1,2,4,\"),\";\")+\";Don't Link\""
	TitleBox LineScanLinktoTitleBox,pos={248.00,308.00},size={77.00,15.00},fSize=12
	TitleBox LineScanLinktoTitleBox,frame=0
	TitleBox LineScanLinktoTitleBox,variable=root:Packages:twoP:Acquire:LSLinkWaveStr, disable=1
	SetVariable LineScanHeightSetVar disable =1, pos={9.00,304.00},size={169.00,22.00},proc=twoP_TimesSetVarProc
	SetVariable LineScanHeightSetVar,title="LineScan Lines",fSize=14
	SetVariable LineScanHeightSetVar,limits={2,inf,2},value=root:Packages:twoP:Acquire:LSHeight
	SetVariable LineScanTrig1SetVar disable =1, pos={81.00,333.00},size={110.00,18.00},proc=twoP_TimesSetVarProc
	SetVariable LineScanTrig1SetVar,title="on Line"
	SetVariable LineScanTrig1SetVar,limits={0,inf,1},value=root:Packages:twoP:Acquire:DelayLines1
	SetVariable LineScanTrig2SetVar disable =1,pos={81.00,353.00},size={110.00,18.00},proc=twoP_TimesSetVarProc
	SetVariable LineScanTrig2SetVar,title="on Line"
	SetVariable LineScanTrig2SetVar,limits={0,inf,1},value=root:Packages:twoP:Acquire:DelayLines2
	GUIPTabAddCtrls("twoP_Controls", "SmodeTabControl", "Lines", "SetVariable LineScanWidthSetVar;SetVariable LineScanXStartSetVar;SetVariable LineScanXStartSetVar;setvariable LineScanXEndSetVar")
	GUIPTabAddCtrls("twoP_Controls", "SmodeTabControl", "Lines", "SetVariable LineScanYSetVar;PopupMenu LineScanLinktoPopMenu;TitleBox LineScanLinktoTitleBox;")
	GUIPTabAddCtrls("twoP_Controls", "SmodeTabControl", "Lines", "Button LineScanRevertScaleButton;PopupMenu LineScanRevertScalePopMenu;SetVariable LineScanHeightSetVar")
	GUIPTabAddCtrls("twoP_Controls", "SmodeTabControl", "Lines", "SetVariable LineScanTrig1SetVar;SetVariable LineScanTrig2SetVar;SetVariable LineScanPixSizeSetVar")
	// ePhys specific
	NVAR ePhysSampFreq= root:packages:twoP:acquire:ePhysSampFreq
	SetVariable ePhysOnlyTimeSetVar,pos={9.00,304.00},size={137.00,22.00}
	SetVariable ePhysOnlyTimeSetVar,title="Duration",fSize=14,value=root:Packages:twoP:acquire:ePhysOnlyTime
	GUIPSIsetVarEnable ("twoP_Controls", "ePhysOnlyTimeSetVar", "", 1, (2^kNQePhysCounterSize/ePhysSampFreq), 1, 1, 0.1, 1, "s")
	SetVariable ePhysOnlyTimeSetVar, disable=1
	GUIPTabAddCtrls("twoP_Controls", "SmodeTabControl", "ePhys", "SetVariable ePhysOnlyTimeSetVar;")
	// Z ser specific
	variable minZStepSize, minZ, maxZ
	SVAR stageProc = root:packages:twoP:acquire:StageProc
	WAVE/Z Properties = $"root:packages:" + stageProc + ":properties"
	if (waveExists (Properties))
		minZStepSize = Properties[%res_z]
		minZ = Properties[%min_Z]
		maxZ =  Properties[%max_Z]
	else
		minZStepSize = 1e-6
		minZ = -INF
		maxZ = INF
	endif
	NVAR stepSize = root:Packages:twoP:Acquire:zStepSize
	// first z
	Button FirstZButton,pos={13.00,221.00},size={29.00,18.00}, title="Get", proc=twoP_ZStackfirstLastButtonProc
	Button FirstZButton disable =1
	SetVariable zFirstZSetVar,pos={56.00,222.00},size={115.00,18.00},title="First Z",fSize=12
	SetVariable zFirstZSetVar,value=root:Packages:twoP:Acquire:ZFirstZ
	GUIPSIsetVarEnable("TwoP_Controls", "zFirstZSetVar", "twoP_zStackSetVarProc", minZ, maxZ, minZStepSize, 0, minZStepSize, 2, "m")
	SetVariable zFirstZSetVar,disable =1
	// last Z
	Button LastZButton,pos={11.00,254.00},size={30.00,17.00},proc=twoP_ZStackfirstLastButtonProc, title="Get"
	Button LastZButton,disable =1
	SetVariable ZLastZSetVar,pos={58.00,253.00},size={116.00,18.00},title="Last Z", fSize=12
	SetVariable ZLastZSetVar,value=root:Packages:twoP:Acquire:ZLastZ
	GUIPSIsetVarEnable("TwoP_Controls", "ZLastZSetVar", "twoP_zStackSetVarProc", minZ, maxZ,  minZStepSize, 0, minZStepSize, 2, "m")
	SetVariable ZLastZSetVar, disable =1
	// Z step SIze
	SetVariable zStepSizeSetvar,pos={38.00,280.00},size={132.00,18.00},title="Step Size ",fSize=12
	SetVariable zStepSizeSetvar value=root:Packages:twoP:Acquire:zStepSize
	GUIPSIsetVarEnable("TwoP_Controls", "zStepSizeSetvar", "twoP_zStackSetVarProc", minZStepSize, INF, minZStepSize, 0, minZStepSize, 2, "m")
	SetVariable zStepSizeSetvar, disable =1
	// number of frames 
	SetVariable NumZframesSetvar,pos={9.00,304.00},size={148.00,22.00},proc=twoP_zStackSetVarProc
	SetVariable NumZframesSetvar,title="Z Slices   ",fSize=14
	SetVariable NumZframesSetvar,limits={0,inf,1},value=root:Packages:twoP:Acquire:NumZseriesFrames
	SetVariable NumZframesSetvar, disable = 3
	// num frames to average
	SetVariable zKalmanAvgSetvar,pos={9.00,334.00},size={147.00,18.00},proc=twoP_TimesSetVarProc
	SetVariable zKalmanAvgSetvar,title="Avg. each slice",fSize=12
	SetVariable zKalmanAvgSetvar,limits={1,inf,1},value=root:Packages:twoP:Acquire:NumZseriesAvg
	SetVariable zKalmanAvgSetvar, disable = 1
	PopupMenu ZdjustPopMenu pos={182.00,224.00},size={116.00,19.00},proc=twoP_zStackAdjustPopMenuProc,title="adjust"
	PopupMenu ZdjustPopMenu,mode=1,popvalue="Num Slices",value=#"\"Num Slices;Step Size;First Z;Last Z;\""
	PopupMenu ZdjustPopMenu disable = 1
	GUIPTabAddCtrls("twoP_Controls", "SmodeTabControl", "Zser", "Button FirstZButton;SetVariable zFirstZSetVar;Button LastZButton;SetVariable ZLastZSetVar;SetVariable zStepSizeSetvar;")
	GUIPTabAddCtrls("twoP_Controls", "SmodeTabControl", "Zser", "SetVariable NumZframesSetvar 2;SetVariable zKalmanAvgSetvar;PopupMenu ZdjustPopMenu")
	// Muti specific
	PopupMenu multiAqDataModePopUp,disable =1,pos={10.00,229.00},size={115.00,19.00},proc=twoP_MultiAqDataModePopMenuProc
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
	SetVariable MultAqPeriodPeriodSetVar disable =1,pos={9.00,299.00},size={103.00,18.00},proc=twoP_MultiAqTimeSetVarProc
	SetVariable MultAqPeriodPeriodSetVar,title="Period ",fSize=12
	SetVariable MultAqPeriodPeriodSetVar,limits={0,inf,0.5},value=root:Packages:twoP:Acquire:multiAqPeriodPeriodStr
	SetVariable MultiAqPeriodDelaySetVar,disable =1,pos={9.00,323.00},size={102.00,18.00},proc=twoP_MultiAqTimeSetVarProc
	SetVariable MultiAqPeriodDelaySetVar,title="Delay",fSize=12
	SetVariable MultiAqPeriodDelaySetVar,value=root:Packages:twoP:Acquire:multiAqPeriodDelayStr
	// Wave
	GroupBox MultModeWaveGrp disable =1,pos={114.00,252.00},size={113.00,97.00}
	GroupBox MultModeWaveGrp,title="                        "
	CheckBox MultiWaveCheck,disable =1,pos={147.00,254.00},size={45.00,15.00},proc=GUIPRadioButtonProcSetGlobal
	CheckBox MultiWaveCheck,title="Wave"
	CheckBox MultiWaveCheck,userdata="root:packages:twoP:acquire:multiAqTimeMode=1;MultiPeriodCheck;MultiTriggerCheck;"
	CheckBox MultiWaveCheck,value=0,mode=1
	Button MultiAqWaveEditButton,disable =1,pos={120.00,317.00},size={46.00,18.00},proc=twoP_MultiWaveEditButtonProc
	Button MultiAqWaveEditButton,title="Edit",fSize=10
	Button MultiAqWaveDeleteButton,disable =1,pos={172.00,317.00},size={47.00,18.00},proc=twoP_MultiWaveDeleteButtonProc
	Button MultiAqWaveDeleteButton,title="Delete",fSize=10
	PopupMenu MultiAqWavePopup,disable =1,pos={121.00,276.00},size={94.00,19.00},proc=twoP_MultiWavePopMenuProc
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
	//TitleBox MultiAqTimeToNextTitle,variable=root:Packages:twoP:Acquire:multiAqTimeToNextStr
	TitleBox MultiAqTimeToNextTitle variable=$"",title=""

	ValDisplay multiAqProgressDisplay, disable =1,pos={11.00,382.00},size={321.00,43.00}
	ValDisplay multiAqProgressDisplay,frame=0
	ValDisplay multiAqProgressDisplay,limits={0,10,0},barmisc={10,30},highColor=(0,65280,0),lowColor=(65280,0,0)
	ValDisplay multiAqProgressDisplay,value=#"root:packages:twoP:acquire:multiAqiAq"
	// start
	CheckBox MultiPreMakeCheck, disable=1, pos={11.00,440.00},size={99.00,15.00}
	CheckBox MultiPreMakeCheck,title="PreMake Waves",variable=root:packages:twoP:acquire:MultiPreMakeWaves
	Button MultiPrepButton, disable =1,pos={217.00,433.00},size={113.00,29.00},proc=twoP_MultiPrepProc
	Button MultiPrepButton,title="Prepare Multi", userdata = "PrepareMulti"
	Button MultiPrepButton,help={"Prepares or Aborts a series of multiple scans"}
	Button MultiPrepButton,userdata="Start Multi",fSize=16,fStyle=1
	GUIPTabAddCtrls("twoP_Controls", "SmodeTabControl", "Multi", "PopupMenu multiAqDataModePopUp;GroupBox MultModePeriodGrp;CheckBox MultiPeriodCheck;SetVariable MultiAqPeriodNumSetVar;")
	GUIPTabAddCtrls("twoP_Controls", "SmodeTabControl", "Multi", "SetVariable MultAqPeriodPeriodSetVar;SetVariable MultiAqPeriodDelaySetVar;GroupBox MultModeWaveGrp;CheckBox MultiWaveCheck;")
	GUIPTabAddCtrls("twoP_Controls", "SmodeTabControl", "Multi", "Button MultiAqWaveEditButton;PopupMenu MultiAqWavePopup;TitleBox MultiAqWaveTitleBox;GroupBox MultModeTriggerGrp;")
	GUIPTabAddCtrls("twoP_Controls", "SmodeTabControl", "Multi", "CheckBox MultiTriggerCheck;SetVariable MultiAqTriggerNumSetVar;TitleBox MultiAqTimeToNextTitle;ValDisplay multiAqProgressDisplay;")
	GUIPTabAddCtrls("twoP_Controls", "SmodeTabControl", "Multi", "Button MultiAqWaveDeleteButton;CheckBox MultiPreMakeCheck;Button MultiPrepButton;")
	// set times
	twoP_TimesSetTimes()
end

 
 // ***************************************************************************************************************************************
// **********************************  Acquire Mode Tab Function  ********************************************************************
// ***************************************************************************************************************************************

 //*************************************************************************************************************************************
// Sets the scanMode variable and various options in the control panel when a scan mode tab is selected
// Last Modified 2025/07/13 by Jamie Boyd
Function twoP_AcquireSModeTabProc(tca) : TabControl
	STRUCT WMTabControlAction &tca
	
	if(tca.eventCode != 2)
		return 0
	endif
	
	NVAR ScanMode = root:packages:twoP:Acquire:ScanMode
	NVAR isMulti = root:packages:twoP:acquire:multiModeIsMulti
	ScanMode =  tca.tab
	if(ScanMode == 6) // multiaq - disable scan start button
		isMulti  = 1
		button AqStartButton disable = 2, proc=twoP_ScanStartMultiProc
		// make sure autoincrement is selected
		NVAR autincCheck = root:packages:twoP:acquire:autincCheck
		if(autIncCheck == 0)
			autincCheck =1
		endif
		// make sure export path is set, if exporting after a scan
		NVAR exportafterscan = root:packages:twoP:acquire:exportAfterScan
		if(exportafterscan > 1)
			SVAR PathStr =root:Packages:twoP:examine:ExportPath		// the global string were we store the path
			pathinfo ExportPath
			if((V_Flag ==0) ||(cmpstr(S_path, PathStr) !=0))// path does not exits or is not the same as shown in the string
				NewPath /O/M="Select a Folder in which to store Scan Waves" ExportPath
				if(!V_flag)		// V_flag is set to 0 if newpath is successful
					PathInfo ExportPath
					pathstr =  s_path
				endif
			endif
		endif
	else
		button AqStartButton disable = 0, proc = twoP_ScanStartSingleProc
		isMulti  = 0
	endif
	//Set Times
	twoP_TimesSetTimes()
	return 0
end

 
// ***************************************************************************************************************************************
// **********************************  New Scan Name and Overwriting  ********************************************************************
// ***************************************************************************************************************************************


//******************************************************************************************************
// Function for the New Scan Name Setvariable control.  Makes it a legal name and autoincrements it.
// Last Modified 2014/08/13 by Jamie Boyd
Function twoP_NewScanNameProc(sva) : SetVariableControl
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
			if(autIncCheck)	// then control is checked
				newName = twoP_ScanNameInc(newName, 0)
			endif
			// 3) check for overwriting
			NVAR overwriteWarnCheck = root:packages:twoP:acquire:overwriteWarnCheck
			if(overwriteWarnCheck)	// user wants to be warned about possible overwriting of waves
				if(dataFolderExists("root:twoP_Scans:" + newName))
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
Function twoP_NewScanNameIncProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			if(checked)
				SVAR NewScanName = root:Packages:twoP:Acquire:NewScanName
				// Clean up scan name
				NewScanName = cleanupname(NewScanName, 0)
				// autoincrement scan name  til there is no conflict
				For(NewScanName = twoP_ScanNameInc(NewScanName, 0);DataFolderExists("root:twoP_Scans:" + NewScanName);NewScanName = twoP_ScanNameInc(NewScanName, 1))
				endfor
			endif
			break
	endswitch
	return 0
End



// ***************************************************************************************************************************************
// ************************************************  Export after Scan  *****************************************************
// ***************************************************************************************************************************************


//******************************************************************************************************
// sets global variable for exporting after completing a scan
// 0 = Do Nothing;1=Save Experiment;2=Export Scan;3=Export and Delete Scan;4=Export Scan and Delete Last Scan;\""
// Last modified 2026/08/06 by Jamie Boyd
Function twoP_ExportAfterScanPopProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			NVAR exportAfterScan = root:packages:twoP:acquire:exportAfterScan
			exportAfterScan = pa.popNum -1
			if(!((CmpStr(pa.popStr, "Do Nothing") == 0) || (CmpStr(pa.popStr, "Save Experiment") == 0)))
				// make sure export path is set
				SVAR PathStr = root:Packages:twoP:examine:ExportPath		// the global string were we store the path
				pathinfo ExportPath
				if ((!(V_Flag)) || (cmpstr(S_path, PathStr) !=0))// path does not exits or is not the same as shown in the string
					NewPath /C/O/M="Select a Folder in which to store Scan Waves" ExportPath
					if(!(V_flag))		// V_flag is set to 0 if newpath is successful
						PathInfo ExportPath
						pathstr =  S_Path
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
// Last modified 2026/08/06 by Jamie Boyd
function twoP_ExportAfterScan(toDo)
	variable toDo
	
//	switch (toDo)
//		case 1:		// save experiment
//			SaveExperiment
//			break
//		case 2:		// Export scan using current settings on the Export Tab of Examine
//			
	// options for after scan choice
	if(toDo ==1)
		SaveExperiment
	else // save individual scan using SaveAndOrDeleteButtonProc
		// we use the "all matching scans method", so select it
		STRUCT WMCheckboxAction cba
		cba.checked=1
		cba.eventCode=2
		cba.userdata=  "root:packages:twoP:examine:ExportCurOrAll=1;exportCurScanCheck"
		cba.win = "twoP_Controls"
		cba.ctrlName = "exportAllScansCheck"
		CheckBox exportAllScansCheck win= twoP_Controls, value=1
		GUIPRadioButtonProcSetGlobal(cba)
		SVAR curScan = root:Packages:twoP:examine:CurScan
		SVAR exportMatchStr = root:packages:twoP:examine:exportMatchStr
		// run the save/delete function with chosen options
		STRUCT WMButtonAction ba
		ba.eventCode =2
		switch(toDo)
			case 2: // export scan
				exportMatchStr = curScan
				ba.ctrlname = "SaveButton"
				break
			case 3: //Export and Delete this Scan
				exportMatchStr = curScan
				ba.ctrlname = "SaveKillButton"
				break
			case 4: //Export and Delete Last Scan.
				//NVAR scanMode = root:packages:twoP:Acquire:scanStartMode
				//NVAR iAq = root:packages:twoP:acquire:multiAqiAq
				//NVAR nAqs= root:packages:twoP:acquire:multiAqnAqs
				twoP_ExportAfterScan(2)
				variable scanNum = str2num(stringfromlist(1, curScan, "_"))-1
				sprintf exportMatchStr, "%s_%03d", stringfromlist(0, curScan, "_"), scanNum
				if(!(dataFolderExists("root:twoP_Scans:" + exportMatchStr)))
					if(scanNum > -1)
						printf "The Scan \"%s\" does not exist\r", exportMatchStr
					endif
					return 1
				endif
				ba.ctrlname = "SaveKillButton"
				break
		endSwitch
		twoP_SaveAndOrDeleteButtonProc(ba)
	endif
	return 0
end


function twoP_SaveScan (theScan)
	string theScan
	
	PathInfo  ExportPath
	if (V_Flag == 0)
		doalert 0,"First choose a folder in which to save the data."
		return 1
	endif
end
	string pathStr = S_Path
	controlinfo/W=twoP_Controls exportNewFolderCheck
	variable makeNewFolder = V_Value
	variable Overwrite
	controlinfo /W= twoP_Controls  exportOverWriteCheck
	Overwrite = V_value
	ControlInfo /W=twoP_Controls exportpopup //"Igor binary;PXP;TIFF;TIFF current Frame;QuickTime Movie;Note Only"
	variable saveMode = V_Value 
	// PXPs are exported differently, not scan by scan, so do separately
	if (saveMode ==2) // PXP
		if (expCurOrAll ==0)
			twoP_ExportScan_PXP (expCurOrAll, curScanG, OverWrite, makeNewFolder)
		else
			twoP_ExportScan_PXP (expCurOrAll, exportMatchStr, OverWrite, makeNewFolder)
		endif
	endif
	// get options specific to TIFF save modes
	if ((saveMode ==3) || (saveMode ==4)) // TiFF orTiff Current Frame
		controlinfo/W=twoP_Controls ReScalePopup //"Full Scale;Data Range;Min/Max"
		variable TIFFscaleMode = V_Value
		variable TIFFexpType 
		controlinfo/W=twoP_Controls expDimPopUp //"signed 16;unsigned 16;signed 8;float;"
		switch (V_Value)
			case 1: // signed 16 bit int
				TIFFexpType = 16
				break
			case 2: // unsigned 16 bit int
				TIFFexpType = 80
				break
			case 3: // unsigned 8 bit int
				TIFFexpType =72
				break
			case 4: // float
				TIFFexpType = 2
				break
		endSwitch
		NVAR CurFramePos =  root:packages:twoP:examine:CurFramePos
	endif
endif

// ***************************************************************************************************************************************
// ************************************************  Open Other Control Panels  *****************************************************
// ***************************************************************************************************************************************


//******************************************************************************************************
// Opens the microscope stage and focus panel using the chosen focus procedure
// Last Modified 2009/05/31 by Jamie Boyd
Function twoP_OpenPanelFocusProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR StageProc = root:packages:twoP:Acquire:StageProc
			dowindow/F $StageProc + "_Controls"
			if(V_Flag)
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
Function twoP_OpenPanelPrefsProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Dowindow/F Scan_Settings_Prefs
			if(V_Flag ==1)
				return 1
			else
				twoP_PrefsMakePanel()
			endif
			break
	endswitch
	return 0
End



//******************************************************************************************************
//Makes the panel for displaying and changing additional scan settings
// Last Modified 2026/07/11 by Jamie Boyd  - new preferences panel
Function twoP_OpenPanelTracesProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Dowindow/F Scan_Settings_Prefs
			if(V_Flag ==1)
				return 1
			else
				twoP_PrefsMakePanel()
			endif
			break
	endswitch
	return 0
End



// ***************************************************************************************************************************************
// *******************************************  Memory Usage Display  ********************************************************************
// ***************************************************************************************************************************************


//*************************************************************************************************************************************
// Returns the physical memory usage of Igor,not the same as the experiment size, but proabbly more helpful
// Last Modified 2025/07/22 by Jamie Boyd - divided by 2^30 to return value in  GigaBytes
// Modified 2025/07/15 by Jamie Boyd - use Igor's memory usage from get info
Function twoP_ExpSize()
	
	return numberbykey("USEDPHYSMEM", IgorInfo(0), ":", ";")/2^30
end


//*************************************************************************************************************************************
// Puts updated memory usage in the global variable used for the setvariable on the twoP control panel
// Last Modified 2025/07/22 by Jamie Boyd - divided by 2^30 to return value in  GigaBytes
function twoP_ExpSizeUpdate()
	NVAR expSize= root:packages:twoP:acquire:expSize
	expSize =  numberbykey("USEDPHYSMEM", IgorInfo(0), ":", ";")/2^30
end




// ***************************************************************************************************************************************
// ***********************************  Set Image Size and Scaling  *****************************************************
// ***************************************************************************************************************************************

//*************************************************************************************************************************************
// Sets the global variables for volts, pixels, and distance to full scaling as defined in constants
// Last Modified May 26 2009 by Jamie Boyd
Function twoP_ImScaleSetFullProc(ba) : ButtonControl
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
			NVAR PixHeightBU = root:Packages:twoP:acquire:PixHeightBU
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
			twoP_TimesSetTimes()
	endswitch
	return 0
End

//*************************************************************************************************************************************
// Sets the scaling of the volts and pixels to the backup values saved the last time they were changed, for an image scan
// Last Modified Oct 27 2009 by Jamie Boyd
Function twoP_ImScaleRevertProc(ba) : ButtonControl
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
			twoP_TimesSetTimes()
			break
	endswitch
	return 0
end

//*************************************************************************************************************************************
// Reverts scaling to that of a wave selected from the image scans in the Scans Folder
// Last Modified Oct 11 2009 by Jamie Boyd
Function twoP_ImScaleRevertToScanProc(pa) : PopupMenuControl
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
			twoP_TimesSetTimes()
			break
	endswitch
	return 0
End


//*************************************************************************************************************************************
// Sets the scaling of the volts and pixels to the backup values saved the last time they were changed, for a line scan
// Last Modified 2025/09/29 by Jamie Boyd
Function twoP_ImScaleLSRevertProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// current values
			NVAR LSStartVoltage = root:packages:twoP:Acquire:LSStartVolts
			NVAR LSEndVoltage = root:packages:twoP:Acquire:LSEndVolts
			NVAR LSYVoltage = root:packages:twoP:Acquire:LSYVolts
			NVAR LSWidth = root:packages:twoP:Acquire:LSWidth
			NVAR LSHeight = root:packages:twoP:Acquire:LSHeight
			// back up copies
			NVAR LSStartVoltageBU = root:packages:twoP:Acquire:LSStartVoltsBU
			NVAR LSEndVoltageBU = root:packages:twoP:Acquire:LSEndVoltsBU
			NVAR LSYVoltageBU = root:packages:twoP:Acquire:LSYVoltsBU
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
			twoP_TimesSetTimes()
			break
	endswitch
	return 0
End

//*************************************************************************************************************************************
// Reverts scaling to that of a wave selected from the Line scans in the Scans Folder
// Last Modified 2025/09/29 by Jamie Boyd
Function twoP_ImScaleLSrevertToScanProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			string theScan = pa.popStr
			SVAR scanStr = $"root:twoP_Scans:" + theScan + ":" + theScan + "_info"
			// current values
			NVAR LSStartVoltage = root:packages:twoP:Acquire:LSStartVolts
			NVAR LSEndVoltage = root:packages:twoP:Acquire:LSEndVolts
			NVAR LSYVoltage = root:packages:twoP:Acquire:LSYVolts
			NVAR LSWidth = root:packages:twoP:Acquire:LSWidth
			NVAR LSHeight = root:packages:twoP:Acquire:LSHeight
			// back up copies
			NVAR LSStartVoltageBU = root:packages:twoP:Acquire:LSStartVoltsBU
			NVAR LSEndVoltageBU = root:packages:twoP:Acquire:LSEndVoltsBU
			NVAR LSYVoltageBU = root:packages:twoP:Acquire:LSYVoltsBU
			NVAR LSWidthBU = root:packages:twoP:Acquire:LSWidthBU
			NVAR LSHeightBU = root:Packages:twoP:Acquire:LSHeightBU
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
			twoP_TimesSetTimes()
			break
	endswitch
	return 0
End



//***************************************** twoP_ImScaleSetMarquee *************************************************************
// Graph marquee procedure to define scan voltage and pixel settings based on a graph marquee selection from the image
// type 0 =zoom scan,	keeps pixel number constant, adjusting pixel scaling
// type 1 = Crop scan, keeps pixel scaling constant, adjusting pixel number.
// type 2 = line scan
// Last Modified 2025/09/14 by Jamie Boyd
Function twoP_ImScaleSetMarquee(type)
	variable type // 0 = zoom scan; 1 = crop scan; 2 = line scan
	
	// Current Scan
	SVAR curScan = root:Packages:twoP:examine:CurScan
	// Scan Note
	SVAR scanStr =$"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
	// Globals for Voltage sizes and pixel size
	NVAR xStartVoltsFS = root:Packages:twoP:acquire:xStartVoltsFS
	NVAR xEndVoltsFS = root:Packages:twoP:acquire:xEndVoltsFS
	NVAR yStartVoltsFS = root:Packages:twoP:acquire:yStartVoltsFS
	NVAR yEndVoltsFS = root:Packages:twoP:acquire:yEndVoltsFS

	if(type == 2) // setting values for a line scan
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
	if(type != 2) // image, not line scan
		YEVBU = YEV
		pixHeightBU = pixHeight
	endif
	pixWidthBU = pixWidth
	// Get Marquee coordinates.
	GetMarquee/K left,bottom
	// Note that V_left and V_right and V_top and V_bottom are in scaled dimensions(meters in this case), not pixels
	// Read scaling values from scan string
	variable WaveXSV = NumberByKey("XSV", scanStr, ":", "\r")
	variable WaveXEV = NumberByKey("XEV", scanStr, ":", "\r")
	variable WaveYSV = NumberByKey("YSV", scanStr, ":", "\r")
	variable WaveYEV = NumberByKey("YEV", scanStr, ":", "\r")
	variable WavePixWidth = NumberByKey("PixWidth", scanStr, ":", "\r")
	variable WavePixHeight =NumberByKey("PixHeight", scanStr, ":", "\r")
	variable WaveXOffset = NumberByKey("Xoffset", scanStr, ":", "\r")
	Variable waveYOffset = NumberByKey("Yoffset", scanStr, ":", "\r")
	variable waveXPixSize = NumberByKey("xPixSize", scanStr, ":", "\r")
	variable waveYPixSize = NumberByKey("yPixSize", scanStr, ":", "\r")
	// calculate scaling in m/Volts
	variable WaveXScal =(WavePixWidth * waveXPixSize)/(WaveXEV - WaveXSV)
	variable WaveYScal =(WavePixHeight * waveYPixSize)/(WaveYEV - WaveYSV)
	// calculate appropriate voltages based on scaling
	XSV = max(xStartVoltsFS, WaveXSV +(V_left - waveXOffset)/ WaveXScal)
	XEV= min(xEndVoltsFS, WaveXSV +(V_right - waveXOffset)/ WaveXScal)
	YSV = max(yStartVoltsFS, WaveYSV +(V_bottom - waveYOffset)/WaveYScal)
	YEV= min(yEndVoltsFS, WaveYSV +(V_top - waveYOffset)/WaveYScal)
	// For linescan, set Y to average of starting and ending voltage
	if(type == 2)
		YSV =(YSV +  WaveYSV +(V_top - waveYOffset)/WaveYScal)/2
	endif
	// for crop scan, adjust pixel number to keep scaling constant
	// to keep marquee functions to a minimum, there is no crop for linescans, but holding shift key will work
	variable shifted=(GetKeyState(0) & 4)
	if((type == 1) ||((type == 2) &&(shifted)))
		PixWidth = round(abs(v_Right - v_left) / waveXPixSize)
		if(type == 1)
			PixHeight =  round(abs( V_bottom - V_Top)/ waveyPixSize)
		endif
	endif
	//run set times proc, which may adjust width/height of selected region for aspect ratio(and fix odd number of lines/pixels)
	twoP_TimesSetTimes()
	// draw a rectangle on graph in ADJUSTED location
	V_left =(XSV-WaveXSV) * WaveXScal + waveXOffset
	V_right =(XEV-WaveXSV) * WaveXScal + waveXOffset
	V_bottom = (YSV-WaveYSV) * WaveYScal + waveYOffset
	if(type == 2)
		SetDrawLayer/K ProgFront
		SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0,linefgc=(0,0,0),linethick= 3.00
		DrawLine V_Left,V_Bottom, V_Right, V_Bottom 
		SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0,linefgc=(65280,65280,65280),linethick= 1, dash = 2
		DrawLine V_Left,V_Bottom, V_Right, V_Bottom 
	else
		V_top = (YEV-WaveYSV) * WaveYScal + waveYOffset
		SetDrawLayer/K ProgFront
		SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0,linefgc=(0,0,0),linethick= 3.00
		DrawRect V_Left,V_top,V_right, V_bottom
		SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0,linefgc=(65280,65280,65280),linethick= 1, dash = 2
		DrawRect V_Left,V_top,V_right, V_bottom
		SetDrawLayer UserFront
	endif
end



// ***************************************************************************************************************************************
// ***************************************** Set Image Times *********************************************************
// ***************************************************************************************************************************************


//*************************************************************************************************************************************
// Sets the calculated pixel, line, frame, and experiment times based on the settings in the control panel
// by calling twoP_TimesSetTimes. It is called  by many setvariable controls which  set those things
// Last Modified 2015/04/12 by Jamie Boyd
Function twoP_TimesSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
		
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			twoP_TimesSetTimes()
			break
	endswitch
	return 0
End

//*************************************************************************************************************************************
// This function directly sets the calculated pixel, line, frame, and experiment times based on the settings in the control panel.
// Called in lots of places other than from setvariable controls, so it makes sense to put the code in a dedicated function
// Last Modified 2026/07/31 by Jamie Boyd
Function twoP_TimesSetTimes()
	
	// Globals for scan timing
	variable scanMode
	NVAR scanmodeG =  root:packages:twoP:Acquire:ScanMode
	if(scanmodeG == kMultiAq)
		NVAR multiAqTimeMode = root:packages:twoP:acquire:multiAqScanMode
		scanMode = multiAqTimeMode
	else
		scanMode = scanmodeG
	endif
	if(scanmode == kLineScan)
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
	
	// Need to have even number of lines for symmetrical collection on flyback, if      irectional scanning. 
	// Line scan always needs even number of lines
	if (((FlybackMode == 1) || (scanMode == kLineScan)) && (mod(PixHeight, 2)))
		PixHeight += 1
	endif
	// make sure sizes are adjusted for aspect ratio before calculating times.
	if(scanmode != kLineScan)
		twoP_AspectRatio(0)
	endif
	// Rough initial calculation of frame time before nasty tests for even point numbers
	if(FlybackMode == 0)
		PixWidthTotal = round(Pixwidth/DutyCycle) + round(Pixwidth*FlyBackProp/DutyCycle)
	else
		PixWidthTotal = round(Pixwidth/DutyCycle)
	endif
	// Set line time by multiplying total pixels in a line by pixel time
	LineTime =(PixWidthTotal) * PixTime
	//Set Frame time by multiplying line time by number of lines
	FrameTime =(LineTime * PixHeight)
	// Set number of frames/lines depending on scan type and options
	// Calculate total number of frames before nasty tests for even point numbers based on scan mode
	// Check for minimun times for Z, Live, and avg modes. Time should only be changed slightly by tests for evenness
	// save info about chunk size in globals
	// Check for scan size - max is 2^24 points for a 24 bit counter
	NVAR minHookTime =  root:packages:twoP:acquire:minLiveFrameTime	// minimum allowed time between invocation of a repeated scan hook, regardless of scan mode
	variable NumFrames		// number of frames to scan, after we ar done with any neded adjustments
	variable LiveMinFrames	// a minimum number of frames, either for a complete scan or for a chunk
	Switch(scanMode)
		case kLiveMode:
			// if frame time < minimum hook time, set LiveStackAtOnce global
			// if LiveStackAtOnce, make sure we have enough frames to meet Minimum Hook Time
			NVAR LiveNumAvgFrames = root:Packages:twoP:Acquire:LiveNumAvgFrames			// value displayed in setvariable
			NVAR LiveStackAtOnce = root:Packages:twoP:Acquire:LiveStackAtOnce			// set if doing stack-at-once scanning
			if (FrameTime > minHookTime)
				LiveStackAtOnce = 0
				SetVariable LiveAvgFramesSetVar win=twoP_Controls, limits={1,inf,1}		// set minimum in setvariable to 1 frame
			else
				LiveStackAtOnce = 1
				LiveMinFrames = min(LiveNumAvgFrames, ceil (minHookTime / FrameTime))			// minimum number of frames to meet minHookTime
				LiveNumAvgFrames = max(LiveNumAvgFrames, LiveMinFrames)							// increase LiveNumAvgFrames if needed
				SetVariable LiveAvgFramesSetVar win=twoP_Controls, limits={LiveMinFrames,inf,1}	// set minimum in setvariable to LiveMinFrames
			endif
			numFrames = LiveNumAvgFrames
			break
			
		case ksingleImage:
			// if frame time <  Minimum Hook Time, clear the AvgDoUpdate global as collected. We will do scan-at-once
			// if frame time <  Minimum Hook Time, make sure we have enough frames to meet Minimum Hook Time
			NVAR AvgNumFrames = root:Packages:twoP:acquire:AvgNumFrames
			NVAR AvgDoUpdate=root:packages:twoP:acquire:AvgDoUpdate
			if (FrameTime < minHookTime)
				AvgDoUpdate = 0
				LiveMinFrames = min(AvgNumFrames, ceil (minHookTime / FrameTime))			// minimum number of frames to meet minHookTime
				AvgNumFrames = max(AvgNumFrames, LiveMinFrames)							// increase LiveNumAvgFrames if needed
				setvariable AvgNumFramesSetVar win=twoP_Controls, limits={1,inf,1}				// set minimum in setvariable to LiveMinFrames
			else
				setvariable AvgNumFramesSetVar win=twoP_Controls, limits={LiveMinFrames,inf,1}	// set minimum in setvariable to 1 frame
			endif
			NumFrames = AvgNumFrames
			break
			
		case kLineScan:
			// if frame time <  Minimum Hook Time, we have 1 chunk, chunk size = pixHeight, scan-at-once
			// Else we calulate chunk size to meet Minimum Hook Time and enforce pixHeight to be a multiple of chunk size
			NumFrames = 1
			NVAR LSchunkSize = root:packages:twoP:acquire:LSChunkSize 		// number of lines to scan at a time
			NVAR LSscanAtOnce = root:packages:twoP:acquire:LSscanAtOnce
			NVAR LSnumChunks = root:packages:twoP:acquire:LSnumChunks
			if (frameTime < minHookTime)
				LSchunkSize = pixHeight
				LSnumChunks =1
				LSscanAtOnce = 1
				SetVariable LineScanHeightSetVar win=twoP_Controls,limits={2,inf, 2}
			else
				LSchunkSize = min (pixHeight, ceil (minHookTime / LineTime))
				// Need to have even number of lines
				if (mod(LSchunkSize, 2))
					LSchunkSize += 1
				endif
			endif
			LSnumChunks = round (pixHeight/LSchunkSize)
			pixHeight = LSchunkSize * LSnumChunks
			if (PixWidth * pixHeight >= 2^kNQImageCounterSize)
				LSscanAtOnce = 0		// need to scan chunk by chunk
			else
				LSscanAtOnce = 1
			endif
			SetVariable LineScanHeightSetVar win=twoP_Controls,limits={LSchunkSize,inf, LSchunkSize}
			break
			
		case kTimeSeries:
			// calculate chunk size and make TSnumFrames a multiple of chunk size
			// clear TSscanAtOnce if there are too many points to do scan at once
			NVAR TSnumFrames = root:Packages:twoP:Acquire:tSeriesNumFrames
			NVAR TSchunkSize = root:packages:twoP:acquire:tSeriesChunkSize
			NVAR TSnumChunks = root:packages:twoP:acquire:tSeriesNumChunks
			NVAR TSscanAtOnce = root:packages:twoP:acquire:tSeriesScanAtOnce
			TSchunkSize = ceil (minHookTime/FrameTime)			// use minimum number of frames to meet minHookTime
			TSnumChunks = round (TSnumFrames / TSchunkSize)
			TSnumFrames = TSnumFrames * TSchunkSize
			if(TSnumFrames * PixWidth * pixHeight >= 2^kNQImageCounterSize)
				TSscanAtOnce = 0
			else
				TSscanAtOnce = 1
			endif
			SetVariable NumTSeriesFramesSetVar win = twoP_Controls, limits={TSchunkSize,inf,(TSchunkSize)}
			numFrames = TSnumFrames
			break
			
		case kZseries:
			// check if the size of the stack to be averaged for each Z-step exceeds counter size
			// if so, clear zAvgStackAtOnce. use KalManamNext to average while scanning a single frame at a time
			// if stack at once, make sure enough frames are averaged to meet minimum hook time
			NVAR NumZSeriesAvg = root:Packages:twoP:Acquire:NumZseriesAvg			// number of frames to avg for each z-step		
			NVAR zAvgStackAtOnce =  root:Packages:twoP:Acquire:zAvgStackAtOnce		// set if scanning the stack to average all at once
			if((PixWidth * pixHeight  * NumZSeriesAvg) >= 2^kNQImageCounterSize)	// overflow 24 bit counter with averaging
				zAvgStackAtOnce = 0
				if ((PixWidth * pixHeight) >= 2^kNQImageCounterSize)					// overflow 24 bit counter with a single frame
					doAlert 0,  "Number of points in each image is greater than the 2^24 bit counter for points/channel! Image Size reduced"
					pixHeight =  floor (2^kNQImageCounterSize/PixWidth)
				endif
				setvariable zKalmanAvgSetvar win=twoP_Controls,limits={1, inf, 1}
			else
				zAvgStackAtOnce = 1
				LiveMinFrames =ceil(minHookTime/frametime)
				numZseriesAvg = max(numZseriesAvg, LiveMinFrames)
				setvariable zKalmanAvgSetvar win=twoP_Controls,limits={LiveMinFrames, inf, 1}
			endif
			NumFrames = NumZSeriesAvg
			break
		
	endswitch
	// now do some checks to ensure even point numbers or nasty NIDAQ drivers will fail
	// 1) Need to acquire an even number of data points(pixHeight x pixWidth x number of frames)
	// 2) Need to output an even number of points for galvo waves(pix height x total pixWidth(including turnaround/flyback))
	// 3) If biderectional scanning, need to have even number of lines in each frame for symetrical collection on flyback
	variable galvoPnts=PixWidthTotal * PixHeight

	variable iTries
	// because there is not a 1-1 relationship between adding an input pixel and adding an output galvo point(flyback and turnaround)
	// adding a single point may not be enough. 10 should be more than enough, or else something is wrong 
	for(iTries =0;(iTries < 10 &&((mod(galvoPnts, 2)) ||(mod((pixWidth * PixHeight * NumFrames), 2))));iTries += 1)
		pixWidth += 1
		if(FlybackMode == 0)
			PixWidthTotal = round(Pixwidth/DutyCycle) + round(Pixwidth*FlyBackProp/DutyCycle)
		else
			PixWidthTotal = round(Pixwidth/DutyCycle)
		endif
		galvoPnts = PixWidthTotal * PixHeight
	endfor
	if(iTries == 10)
		doAlert 0, "Was not able to adjust pixel width to satisfy  constraints."
		return 1
	endif
	// Set line time by multiplying pixels in a line by pixel time, as we may have changed number of pixels in a line
	LineTime =(PixWidthTotal) * PixTime
	//Set Frame time by multiplying line time by number of lines
	switch(scanMode)
		case kLiveMode:
			FrameTime =(LineTime * PixHeight)
			RunTime = INF
			break
		case kTimeSeries:
			FrameTime =(LineTime * PixHeight)
			RunTime =(FrameTime * NumFrames)
			setvariable Trig1SecsSetvar win = twoP_Controls, limits = {-inf, inf, FrameTime}
			setvariable Trig2SecsSetvar win = twoP_Controls, limits = {-inf, inf, FrameTime}
			break
		case kZseries:
			NVAR ZFrames = root:Packages:twoP:Acquire:NumZseriesFrames
			FrameTime =(LineTime * PixHeight) * NumZSeriesAvg
			RunTime =(FrameTime * ZFrames)
			break
		case kSingleImage:
			FrameTime =(LineTime * PixHeight)
			NVAR numAvgFrames = root:packages:twoP:Acquire:AvgNumFrames
			RunTime =(FrameTime * numAvgFrames)
			
			break
		case kLineScan:
			RunTime = FrameTime
			setvariable Trig1SecsSetvar win = twoP_Controls, limits = {-inf, inf, LineTime*100}
			setvariable Trig2SecsSetvar win = twoP_Controls,limits = {-inf, inf, LineTime*100}
			break
	endSwitch
	// check ePhys situation
	variable ePhysChans =0
	if((scanMode == kTimeSeries) ||(scanMode == kLineScan)  ||(scanMode == kEphysOnly))
		SVAR selChanList = root:packages:twoP:acquire:selEphysChanList
		if(itemsinlist(selChanList,";") > 0)
			NVAR ePhysFreq = root:Packages:twoP:Acquire:ePhysSampFreq
			variable ePhysRunTime = runTime
			if(scanMode == kEphysOnly)
				NVAR ephysOnlyTime = root:packages:twoP:acquire:ephysOnlyTime
				ePhysRunTime = ephysOnlyTime
			endif
			if(ePhysRunTime *ePhysFreq > 2^kNQePhysCounterSize)
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
	if(scanMode == kTimeSeries)
		DelaySecs1 = DelayFrames1 * FrameTime
		DelaySecs2 = DelayFrames2 * FrameTime
	elseif(ScanMode == kLineScan)
		DelaySecs1 =  DelayLines1 * LineTime
		DelaySecs2 =  DelayLines2 * LineTime
	endif
	// set run time string
	SVAR runTimeStr = root:Packages:twoP:Acquire:RunTimeStr
	if(scanMode ==kLiveMode)
		runTimeSTr = "INF"
	else
//		if(runTime < 60)
//			sprintf runTimeStr, "%.3W1Ps", runTime
//		else
//			runTimeStr =Secs2Time(runTime, 5, 1)
//		endif
	runTimeStr = twoP_MultiFormatSeconds (runTime)
	endif
end



//*************************************************************************************************************************************
// Runs setTimes Procedure when (Bi-directional scanning) Turbo is checked/unchecked. The global variable, root:packages:twoP:acquire:FlybackMode,
// is set automatically by Igor
// Last Modified Jul 24 2011 by Jamie Boyd
Function twoP_TimesTurboCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			if(cba.checked)
				CheckBox TurboCheck win= twoP_Controls, title="Bi-Directional Scan is ON"
			else
				CheckBox TurboCheck win= twoP_Controls, title="Bi-Directional Scan is OFF"
			endif
			twoP_TimesSetTimes()
			break
	endswitch
	return 0
End



// ***************************************************************************************************************************************
// ***************************************** Set Aspect Ratio *********************************************************
// ***************************************************************************************************************************************


//*************************************************************************************************************************************
// disables the control linked to the variable that will be automatically adjusted
// Last Modified 2025/08/26 by Jamie Boyd
Function twoP_AspectRatioPopProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			variable ableState
			ableState = SelectNumber((cmpStr(pa.popStr,  "Vary X Start") == 0) , 0, 2)
			GUIPTabSetAbleState("twoP_Controls", "AcquireExamineTab", "Acquire;Examine", "XStartSetVar", ableState, 1)
			ableState = SelectNumber((cmpStr(pa.popStr,  "Vary X  End") == 0) , 0, 2)
			GUIPTabSetAbleState("twoP_Controls", "AcquireExamineTab", "Acquire;Examine", "XEndSetVar", ableState, 1)
			ableState = SelectNumber((cmpStr(pa.popStr,  "Vary X Pix") == 0) , 0, 2)
			GUIPTabSetAbleState("twoP_Controls", "AcquireExamineTab", "Acquire;Examine", "PixWidSetVar", ableState, 1)
			ableState = SelectNumber((cmpStr(pa.popStr,  "Vary Y Start") == 0) , 0, 2)
			GUIPTabSetAbleState("twoP_Controls", "AcquireExamineTab", "Acquire;Examine", "YStartSetVar", ableState, 1)
			ableState = SelectNumber((cmpStr(pa.popStr,  "Vary Y End") == 0) , 0, 2)
			GUIPTabSetAbleState("twoP_Controls", "AcquireExamineTab", "Acquire;Examine", "YEndSetVar", ableState, 1)
			ableState = SelectNumber((cmpStr(pa.popStr,  "Vary Y Pix") == 0) , 0, 2)
			GUIPTabSetAbleState("twoP_Controls", "AcquireExamineTab", "Acquire;Examine", "PixHeightSetVar", ableState, 1)
			ableState = SelectNumber((cmpStr(pa.popStr,  "Free") == 0) , 0, 2)
			GUIPTabSetAbleState("twoP_Controls", "AcquireExamineTab", "Acquire;Examine", "AspRatSetVar", ableState, 1)
			break
	endswitch
	return 0
End




//*************************************************************************************************************************************
//Changing the aspect ratio involves manipulating either pixel width/height or image extent 
// Last Modified Jul 21 2011 by Jamie
Function twoP_AspectRatioSetvarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			variable self =(cmpStr(sva.ctrlName, "AspRatSetVar") == 0)
			twoP_AspectRatio(self)
	endswitch
	return 0
End


//*************************************************************************************************************************************
//Changing the aspect ratio involves manipulating either pixel width/height or image extent 
// Last Modified Jul 21 2011 by Jamie
Function twoP_AspectRatio(self)
	variable self
	// Dont mess around with setting aspect ratio if using Line Scan Mode, as it would be meaningless
	NVAR ScanModeG = root:packages:twoP:acquire:scanMode
	variable scanMode=abs(scanModeG)
	if(scanMode == kLineScan)
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
	
	// Adjust a value(as chosen in pomenu) to keep aspect ratio constant
	// NOTE: this code has not been updated for possibility that X magnification is different from Y magnification
	ControlInfo/w = twoP_Controls AspRatPopUp
	Switch(V_Value)
		case 1:	//Changing X-volts start
			XSV =  XEV - ((Pixwidth *(YEV - YSV))/(PixHeight * AspectRatio))
			if(XSV < xStartVoltsFS)
				XSV = xStartVoltsFS
				PixWidth = round((AspectRatio * pixheight *(XEV - XSV))/(YEV - YSV))
			endif
			break
		case 2:	// Changing X volts end
			XEV = ((Pixwidth *(YEV - YSV))/(PixHeight * AspectRatio)) + XSV
			if(XEV > xEndVoltsFS)
				XEV = xEndVoltsFS
				PixWidth = round((AspectRatio * pixheight *(XEV - XSV))/(YEV - YSV))
			endif
			break
		case 3:	// CHanging X pixels
			PixWidth = round((AspectRatio * pixheight *(XEV - XSV))/(YEV - YSV))
			break
		case 4:		//Changing Y-volts Start
			YSV =  YEV -((AspectRatio * PixHeight *(XEV - XSV))/PixWidth)
			if(YSV < yStartVoltsFS)
				YSV = yStartVoltsFS
				pixheight = round(((PixWidth *(yev - ysv))/(AspectRatio *(Xev - XSV))))
			endif
			break
		case 5:		// Changing Y volts end
			YEV = ((AspectRatio * PixHeight *(XEV - XSV))/ PixWidth) + YSV
			if(YEV > yEndVoltsFS)
				YEV = yEndVoltsFS
				pixheight = round(((PixWidth *(yev - ysv))/(AspectRatio *(Xev - XSV))))
			endif
			break
		case 6:		//Changing Y-pixels
			pixheight = round(((PixWidth *(yev - ysv))/(AspectRatio *(Xev - XSV))))
			break
		Case 7:		// Don't hold aspect ratio constant - just calculate new Aspect Ratio .  This doesn't make sense  when called by aspect ratio setvar, so test for it
			if(!(self))
				AspectRatio =((YEV - YSV)/PixHeight)	/((XEV-XSV)/PixWidth)
			endif
			break
	endswitch
end



// ***************************************************************************************************************************************
// ******************************************* Microscope Objectives  ********************************************************************
// ***************************************************************************************************************************************


//************************************************** twoP_ObjPopProc ***********************************************************************************
// Sets globals for chosen objective. Changes in Image size and Pixel Size are handled by dependency formula set in AddAcquireControls function
// Last Modified 2016/10/12 by Jamie Boyd
Function twoP_ObjPopProc(pa) : PopupMenuControl
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



//**************************************** twoP_ObjList *********************************************************************************************
// Returns a list of objective names stored in objwave
// Last Modified May 30 2009 by Jamie Boyd
Function/S twoP_ObjList()
	
	WAVE/T ObjWave = root:Packages:twoP:Acquire:ObjWave
	string objList = ""
	variable iObj, nObjs = dimsize(ObjWave,0)
	for(iObj=0;iObj<nObjs;iObj+=1)
		objList += ObjWave [iObj] [0]+ ";"
	endfor
	return objList
end


// ***************************************************************************************************************************************
// *********************************************  Channel Selections  ********************************************************************
// ***************************************************************************************************************************************



//******************************************************************************************************
// Updates list of channels to scan, adding new channel or removing an existing channel for images or ephys
// Last Modified 2026/07/08 by Jamie Boyd - combiened ephys and image channel handling
Function twoP_ChansProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	
	if (cmpStr (pa.ctrlName, "EphysChansPopUp") ==0)
		SVAR selChans = root:packages:twoP:acquire:selEphysChanList
	elseif (cmpStr (pa.ctrlName, "ImageChansPopMenu") ==0)
		SVAR selChans = root:packages:twoP:acquire:selImageChanList
	endif
	switch( pa.eventCode )
		case 2: // mouse up
			if(FindListItem(pa.popStr, selChans, ";") > -1)
				selChans = sortList(removeFromList(pa.popStr, selChans, ";"), ";")
			else
				selChans = sortList(addlistItem(pa.popStr, selChans, ";"), ";")
			endif
			break
	endswitch
	return 0
End


// ***************************************************************************************
// Lists channels that can be selected for scanning, marking already selected ones with checks
// last modified 2025/07/25 by Jamie Boyd
function/S twoP_ChansListActive(type)
	variable type
	switch(type)
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
	variable iChan, nChans = dimsize(chanList, 0)
	for(iChan =0; iChan < nChans; iChan += 1)
		if(chanSelList[iChan][0] == 48) // checked, so active channel
			aChan = chanList [iChan] [1] + ":" +  num2str(iChan)
			if(FindListItem(aChan, selChans, ";") > -1)
				outList += "\\M1!"  +num2char(18)
			endif
			outList += aChan + ";"
		endif
	endfor
	return outList
end

//******************************************************************************************************
// when passed a list of channel names and ao channel numbers, returns a list of just the channel numbers
// Last Modified 2026/07/30 by Jamie Boyd
Function/S twoP_ChansOnlyChans (chansPlusAOlist)
	string chansPlusAOlist
	
	string aChan, onlyChans = ""
	variable iChan,nChans= itemsInlist(chansPlusAOlist, ";")
	for(iChan=nChans-1; iChan >= 0; iChan -=1)
		aChan = stringFromList(0, stringFromList(iChan, chansPlusAOlist, ";"), ":")
		onlyChans = AddListItem(aChan, onlyChans, ",")
	endfor
	return onlyChans
End



// ***************************************************************************************************************************************
// **********************************************  Live Mode Controls  ********************************************************************
// ***************************************************************************************************************************************


// *************************************************************************************************
// sets strings for Top and Botttom channel names used in ratio for live rois
// Last Modified 2025/07/10 by Jamie Boyd - new channel selection method
Function twoP_LiveSetROIchanProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	switch( pa.eventCode )
		case 2: // mouse up
			if(cmpStr(pa.ctrlName, "LiveROIRatioTopPopMenu")==0)
				SVAR chan=root:Packages:twoP:Acquire:LiveROItopChan
			elseif(cmpStr(pa.ctrlName, "LiveROIRatioBottomPopMenu")==0)
				SVAR chan=root:Packages:twoP:Acquire:LiveROIBottomChan
			endif
			chan = stringFromList(0, pa.popStr,":")
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End


//************************************ twoP_LiveMarqueeSetROI ******************************************************************
// Dumps the marquee coordinates to some global variables for use with live ROI graph
// Last Modified Oct 14 2009 by Jamie Boyd
Function twoP_LiveMarqueeSetROI()
	
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
	SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0,linefgc=(0,0,0),linethick= 3.00
	DrawRect Left, top, right, bottom
	SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0,linefgc=(65280,65280,65280),linethick= 1, dash = 2
	DrawRect Left, top, right, bottom
	SetDrawLayer UserFront
end


// ***************************************** twoP_LiveTriggerButtonProc *****************************************************************
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
			if(cmpStr(ba.ctrlName, "Trig1ManualButton") ==0)
				DAQmx_CTR_OutputPulse /DEV=ePhysBoardName/SEC={Trig1Duration, Trig1Duration}/IDLE=(Trig1Polarity) /NPLS=1/STRT=1(0) ; AbortOnRTE
			else
				DAQmx_CTR_OutputPulse /DEV=ePhysBoardName/SEC={Trig2Duration, Trig2Duration}/IDLE=(Trig2Polarity) /NPLS=1/STRT=1(1) ; AbortOnRTE
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End



// ***************************************************************************************************************************************
// *********************************************  Line Scan Controls  ********************************************************************
// ***************************************************************************************************************************************


//*********************************************** twoP_LineScanLinkToProc *******************************************************
// Changes a global string to the name of a wave that a linescan was drawn on (or Don't Link, if no Image Wave was selected).
// The string will be used to make an entry in the wavenote of the LineScan Wave
// Last Modified Jun 01 2009 by Jamie Boyd
Function twoP_LineScanLinkToProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			SVAR LinKWave = root:Packages:twoP:Acquire:LSLinkWaveStr
			LinKWave = pa.popStr
			break
	endswitch
	return 0
End



// ***************************************************************************************************************************************
// **********************************  Z Series Controls ********************************************************************
// ***************************************************************************************************************************************


//**************************************** twoP_zStackAdjustPopMenuProc **************************************************************
// Enables/Disables controls for setting Z variables, based on popmenu selection
// Last Modified 2015/04/15 by Jamie Boyd
Function twoP_zStackAdjustPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			// Disable controls based on selection
			// ZSLices;Step Size;First Z;Last Z
			GUIPTabSetAbleState("twoP_Controls", "SmodeTabControl", "Zser", "NumZframesSetvar;", ((popNum == 1)*2), 1)
			GUIPTabSetAbleState("twoP_Controls", "SmodeTabControl", "Zser", "zStepSizeSetvar;", ((popNum == 2)*2), 1)
			GUIPTabSetAbleState("twoP_Controls", "SmodeTabControl", "Zser", "FirstZButton;", ((popNum == 3)*2), 1)
			GUIPTabSetAbleState("twoP_Controls", "SmodeTabControl", "Zser", "zFirstZSetVar;", ((popNum == 3)*2), 1)
			GUIPTabSetAbleState("twoP_Controls", "SmodeTabControl", "Zser", "LastZButton;", ((popNum == 4)*2), 1)
			GUIPTabSetAbleState("twoP_Controls", "SmodeTabControl", "Zser", "ZLastZSetVar;", ((popNum == 4)*2), 1)
			break
	endswitch
	return 0
End

//*********************************** twoP_zStackSetVarProc *******************************************************************
// Adjusts Z variables, based on selection in ZdjustPopMenu
// Last Modified 2026/01/02 by Jamie Boyd - setting stage increment here
Function twoP_zStackSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		//case 2: // Enter key
		case 3: // Live update
		case 8: //finish edit
			// Globals to the z parameters
			NVAR NumZFrames = root:packages:twoP:Acquire:NumZseriesFrames
			NVAR ZStepSize = root:packages:twoP:Acquire:ZStepSize
			NVAR LastZ = root:packages:twoP:Acquire:ZLastZ
			NVAR FirstZ = root:packages:twoP:Acquire:ZFirstZ
			// What do we modify ?
			controlinfo/w=twoP_Controls ZdjustPopMenu
			variable toMod = V_Value
			switch(toMod)
				case 1: // number of Z SLices
					NumZFrames =  round(((LastZ-FirstZ ) / ZStepSize) + 1)
					// numFrames can not be negative, but stepsize can
					if(NumZFrames < 0)
						ZStepSize *= -1
						NumZFrames *= -1
					endif
					break
				case 2: //Step Size
					SVAR stageProc = root:packages:twoP:Acquire:stageProc
					WAVE Properties = $"root:packages:" + stageProc + ":properties"
					variable ZStepSizeMin = Properties [%res_Z]
					ZStepSize = round(((LastZ - FirstZ)/NumZFrames)/ZStepSizeMin)*ZStepSizeMin
					WAVE Properties = $"root:packages:" + stageProc + ":properties"
					ZStepSize = round(((LastZ - FirstZ)/NumZFrames)/ZStepSizeMin)*ZStepSizeMin
					LastZ =(NumZFrames * ZStepSize) + FirstZ
					break
				case 3: // First Z
					FirstZ = (NumZFrames * ZStepSize) - LastZ
					break
				case 4: //LastZ
					LastZ =(NumZFrames * ZStepSize) + FirstZ
					break
			endswitch
			break
	endswitch
	// Adjust increments for 1st and last z setvariables to stepsize, if stepsize was changed
	if((cmpstr(sva.ctrlname, "zStepSizeSetvar") == 0) ||(toMod == 2))
		NVAR ZStepSize = root:packages:twoP:Acquire:ZStepSize
		setvariable zFirstZSetVar win = twoP_Controls, limits = {-INF, INF, ZStepSize}
		setvariable zLastZSetVar win = twoP_Controls, limits = {-INF, INF, ZStepSize}
	endif
	// Adjust frame time/exp time
	twoP_TimesSetTimes()
	return 0
End


//********************************************** twoP_ZStackfirstLastButtonProc ********************************************************
// Grabs value from stage/focus, puts it into firstZ or lastZ, and adjusts Z variables based on selection in ZdjustPopMenu
// Last Modified 2025/12/21 by Jamie Boyd
Function twoP_ZStackfirstLastButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// Update stage for Z
			SVAR theStageEncoder = root:packages:twoP:Acquire:StageProc
			StageUpdate(theStageEncoder, kZBit, 1)
			variable zS = StageGetAxisPos(theStageEncoder, "Z")
			// Put z-Value in proper global for the button that was clicked
			if(cmpstr(ba.ctrlname, "FirstZButton") == 0)
				NVAR FirstZ = root:packages:twoP:Acquire:ZFirstZ
				FirstZ = zS
			elseif(cmpstr(ba.ctrlname, "LastZButton") == 0)
				NVAR LastZ = root:packages:twoP:Acquire:ZLastZ
				LastZ = zS
			endif
			// Adjust Z values
			STRUCT WMSetVariableAction sva
			sva.eventcode = 1
			twoP_zStackSetVarProc(sva)
			break
	endswitch
	return 0
End

// ***************************************************************************************************************************************
// ***************************************** Trigger Controls  ***************************************************************
// ***************************************************************************************************************************************


//**************************************** twoP_TriggerSecsProc **************************************************************
// Updates global string for selected trigger channels
// Last Modified 2025/07/10 by Jamie Boyd - new channel selection method
Function twoP_TriggerSecsProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	if(sva.eventCode ==8 ||sva.eventCode == 1)
		if(cmpStr(sva.ctrlname, "Trig1SecsSetvar") ==0)
			NVAR delayFrames = root:packages:twoP:acquire:delayFrames1
			NVAR delayLines = root:packages:twoP:acquire:delayLines1
		elseif(cmpStr(sva.ctrlname, "Trig2SecsSetvar") ==0)
			NVAR delayFrames = root:packages:twoP:acquire:delayFrames2
			NVAR delayLines = root:packages:twoP:acquire:delayLines2
		endif
		NVAR scanMode = root:packages:twoP:acquire:scanMode
		if(scanMode ==  kTimeSeries)
			NVAR frameTime = root:packages:twoP:acquire:frameTime
			delayFrames = round(sva.dval/frameTime)
			twoP_TimesSetTimes()
		elseif(scanMode ==  kLineScan)
			NVAR lineTime = root:packages:twoP:acquire:lineTime				
			delayLines = round(sva.dval/lineTime)
			twoP_TimesSetTimes()
		endif
			
	endif
end


// ***************************************************************************************************************************************
// ********************************** Voltage Pulse Controls ***************************************************************
// ***************************************************************************************************************************************


//************************************ twoP_VoltagePulseCheckProc ******************************************************************
// CheckBox procedure for which voltage pulse channels are selected
// Last Modified 2026/07/08 by Jamie Boyd
Function twoP_VoltagePulseCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			NVAR chans= root:packages:twoP:Acquire:voltagePulseChans		// 1 if output 1 is set, 2 for out put 2, 3 for both
			variable chanBit
			if (cmpstr (cba.ctrlName, "Voltage1Check") ==0)
				chanBit = 1
			elseif (cmpstr (cba.ctrlName, "Voltage2Check") ==0)
				chanBit = 2
			endif
			if (cba.checked)
				chans = chans | chanBit
			else
				chans = chans & !chanBit
			endif
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End



//**************************************** twoP_VoltagePulseSetWaveProc **************************************************************
// Sets one of the global strings for voltage pulse waves
// Last Modified 2026/07/08 by Jamie Boyd
Function twoP_VoltagePulseSetWaveProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			if (cmpstr (pa.ctrlName, "VoltagePulse1Popup") ==0)
				SVAR vWave=root:packages:twoP:acquire:voltageWave1
			elseif (cmpstr (pa.ctrlName, "VoltagePulse2Popup") ==0)
				SVAR vWave=root:packages:twoP:acquire:voltageWave2
			endif
			vWave = pa.popStr
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End



//*********************************** twoP_VoltagePulseEditProc *******************************************************************
// Opens a control panel for making and editing waves to be used as voltage outputs
// Last Modified 2026/07/16 by Jamie Boyd
Function twoP_VoltagePulseEditProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up

			DoWindow/F VoltageWavesEditor
			if(V_Flag == 1)
				return -1
			endif
			Display /W=(273.75,40.25,751.5,314.75)/K=1  as "Voltage Waves Editor"
			dowindow/C VoltageWavesEditor
			ControlBar 85
			//Kill Button
			Button KillButton,pos={3.00,4.00},size={50.00,20.00},proc=twoP_VoltagePulseKillProc
			Button KillButton,title="Kill"
			Button KillButton,help={"Kill the voltage pulse wave that is being edited."}
			//popmenu to choose wave to edit
			PopupMenu EditVoltagePulsePopup,pos={57.00,5.00},size={90.00,19.00},proc=twoP_VoltagePulseSelectProc
			PopupMenu EditVoltagePulsePopup,title="Now Editing:"
			PopupMenu EditVoltagePulsePopup,help={"Choose a voltage pulse wave to edit, or make a new one"}
			PopupMenu EditVoltagePulsePopup,mode=0,value=#"twoP_VoltagePulseList()"
			// title box displays name of wave being editited
			TitleBox EditTitle,pos={151.00,7.00},size={25.00,15.00},fSize=12,frame=0
			TitleBox EditTitle,variable=root:packages:twoP:acquire:VoltagePulseEditWave
			TitleBox EditTitle,help={"displays name of voltage pulse wave being edited."}
			// start position of segment, displayed as time or as frames
			SetVariable X1SetVar,pos={3.00,27.00},size={156.00,18.00},proc=twoP_VoltagePulseCsrSetVarProc
			SetVariable X1SetVar,title="Start Time",format="%5.2f Sec"
			SetVariable X1SetVar,limits={0,inf,0.1},value=root:packages:twoP:acquire:VoltagePulseX1,live=1
			SetVariable X1SetVar,help={"displays start time or first frame of segment to be added."}
			// end position of segment, displayed as time or as frames
			SetVariable X2SetVar,pos={3.00,47.00},size={154.00,18.00},proc=twoP_VoltagePulseCsrSetVarProc
			SetVariable X2SetVar,title="End Time ",format="%5.2f Sec"
			SetVariable X2SetVar,limits={0,inf,0.1},value=root:packages:twoP:acquire:VoltagePulseX2,live=1
			SetVariable X2SetVar,help={"displays end time or last frame of segment to be added."}
			//check switch between displaying x position as time or frames
			CheckBox FrameAxisCheck,pos={3.00,67.00},size={124.00,15.00},proc=twoP_VoltagePulseAxisProc
			CheckBox FrameAxisCheck,title="X-axis as FrameTime"
			CheckBox FrameAxisCheck,variable=root:packages:twoP:acquire:VoltageAxis
			CheckBox FrameAxisCheck, help={"display x position as time when unchecked or frames when checked."}
			// radio buttons for selecting which type of segment to make
			// straight
			CheckBox StraightCheck,pos={183.00,27.00},size={57.00,15.00},proc=twoP_VoltagePulseModeCheckProc
			CheckBox StraightCheck,title="Straight"
			CheckBox StraightCheck,help={"make a straight line segment between the two cursors"}
			CheckBox StraightCheck,value=1,mode=1
			// square wave
			CheckBox SquareCheck,pos={184.00,47.00},size={52.00,15.00},proc=twoP_VoltagePulseModeCheckProc
			CheckBox SquareCheck,title="Square"
			CheckBox SquareCheck,help={"make a square wave segment between the two cursors"}
			CheckBox SquareCheck,value=0,mode=1
			CheckBox SineCheck,pos={184.00,64.00},size={38.00,15.00},proc=twoP_VoltagePulseModeCheckProc
			// sine wave
			CheckBox SineCheck,title="Sine"
			CheckBox SineCheck,help={"Make a sine wave segment between the two cursors"}
			CheckBox SineCheck,value=0,mode=1
			// start voltage of straight segment,or offset voltage of a square or sine wave
			SetVariable Y1SetVar,pos={255.00,3.00},size={157.00,18.00},proc=twoP_VoltagePulseCsrSetVarProc
			SetVariable Y1SetVar,title="Start Voltage",format="%5.3f V"
			SetVariable Y1SetVar,limits={-10,10,0.1},value=root:packages:twoP:acquire:VoltagePulseY1,live=1
			SetVariable Y1SetVar, help={"start voltage of a straight line segment,or offset voltage of a square or sine wave segment."}
			// end voltage of a straight line segment
			SetVariable Y2SetVar,pos={255.00,23.00},size={157.00,18.00},proc=twoP_VoltagePulseCsrSetVarProc
			SetVariable Y2SetVar,title="End Voltage ",format="%5.3f V"
			SetVariable Y2SetVar,limits={-10,10,0.1},value=root:packages:twoP:acquire:VoltagePulseY2,live=1
			SetVariable Y2SetVar, help={"End voltage of a straight line segment."}
			// voltage offset for a square or sine wave segment
			SetVariable HeightSetVar,pos={254.00,23.00},size={157.00,18.00}
			SetVariable HeightSetVar,title="Amplitude",format="%5.3f V"
			SetVariable HeightSetVar,limits={-10,10,0.1},value=root:packages:twoP:acquire:VoltagePulseHeight
			SetVariable HeightSetVar, help={"voltage offset for a square or sine wave segment"}, disable=1
			// frequency for a square or sine wave segment
			SetVariable FreqSetVar,pos={254.00,42.00},size={156.00,18.00}
			SetVariable FreqSetVar,title="Frequency",format="%g Hz"
			SetVariable FreqSetVar,limits={0,100,1},value=root:packages:twoP:acquire:VoltagePulseFreq
			SetVariable FreqSetVar, help={"frequency for a square or sine wave segment."}, disable=1
			//button to add the new segment
			Button NewSegmentButton,pos={282.00,62.00},size={87.00,19.00},proc=twoP_VoltagePulseAddProc
			Button NewSegmentButton,title="Add Segment"
			Button NewSegmentButton, help={"add a segment to voltage wave being edited,"}
			//Set voltage wave string to empty string and mode to 0
			SVAR VoltageWaveStr = root:packages:twoP:acquire:VoltagePulseEditWave
			VoltageWaveStr = ""
			NVAR mode =	root:packages:twoP:Acquire:voltagePulseMode
			mode=0
			// Restore any saved window position
			WC_WindowCoordinatesRestore("VoltageWavesEditor")
			// install Hook to save window position
			SetWindow VoltageWavesEditor hook(saveHook)= twoP_UtilSaveWinPosHook, hookevents = 2
			//Install hook function for Cursor updates
			SetWindow kwTopWin, hook (VotagePulseCursorHook) = twoP_VoltagePulseEditHook, hookevents = 4
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End


// ***************************************************************************************************************************************
// ********************************** Voltage Pulse Edit Panel ***************************************************************
// ***************************************************************************************************************************************


//************************************* twoP_VoltagePulseKillProc *****************************************************************
// Kills voltage pulse wave currently being edited
// Last Modified 2026/07/16 by Jamie Boyd 
Function twoP_VoltagePulseKillProc(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR VoltageWaveStr = root:packages:twoP:acquire:VoltagePulseEditWave
	WAVE/Z VoltageWave = $"root:packages:twoP:acquire:VoltagePulseWaves:" + VoltageWaveStr
	if (waveExists (VoltageWave))
		GUIPKilldisplayedWave(VoltageWave)
	endif
	VoltageWaveStr =""
	
End


//************************************* twoP_VoltagePulseList *****************************************************************
// lists waves in voltage pulses folder that are not already on the voltage pulse editing graph
// Last Modified 2026/07/15 by Jamie Boyd 
Function/S twoP_VoltagePulseList()
	string returnStr=""
	string aPulse
	string vPulseList=GUIPListObjs  (("root:packages:twoP:acquire:VoltagePulseWaves") , 1, "*", 0, "")
	string tracesList =  GUIPListWavesFromGraph("VoltageWavesEditor", "*", 1, 0, "")
	variable iPulse, nPulses=itemsinList (vPulseList)
	for (iPulse=0; iPulse < nPulses; iPulse +=1)
		aPulse= stringFromList(iPulse, vPulseList, ";")
		if (WhichListItem(aPulse, tracesList, ";") == -1)
			returnStr = addListItem(aPulse, returnStr, ";")
		endif
	endfor
	if (strlen (returnStr) < 2)
		returnStr =  "\M1(No Voltage Pulse Waves"
	endif
	returnStr = addListItem("New Voltage Wave;\\M1-", returnStr)
	return returnStr
end


//********************************* twoP_VoltagePulseSelectProc *********************************************************************
// selects a wave for editing and displays it on the voltage pulse graph
// Last Modified 2026/07/16 by Jamie Boyd 
Function twoP_VoltagePulseSelectProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			SVAR voltageWaveNameG=root:packages:twoP:acquire:VoltagePulseEditWave
			NVAR voltageScalingG= root:packages:twoP:acquire:VoltageWaveScaling
			NVAR VoltageAxisIsFrames = root:packages:twoP:acquire:VoltageAxis
			NVAR frameTime=root:packages:twoP:acquire:FrameTime
			NVAR timeAsFrames=root:packages:twoP:acquire:VoltageAxis
			string TracesList =  GUIPListWavesFromGraph("VoltageWavesEditor", "*", 1, 0, "")
			variable freq=10e03
			variable length=30
			if((Cmpstr(pa.popStr, "New Voltage Wave")) == 0) // prompt user to make a new wave
				string newname = "Voltage_Wave"
				Prompt newname, "Name for New Voltage Wave" 
				Prompt length, "Length(in seconds) of New Voltage Wave"
				Prompt freq, "Frequency (in Hz) of New Voltage Wave"
				do
					DoPrompt "Make New Voltage wave", newname, length, freq
					if(V_Flag)
						return 0
					endif
				while (waveExists( $"root:Packages:twoP:acquire:VoltagePulseWaves:" +  CleanupName(newname, 0)))
				voltageWaveNameG = CleanupName(newname, 0)
				make/o/n=(length*freq) $"root:Packages:twoP:acquire:VoltagePulseWaves:" + voltageWaveNameG
				WAVE VoltageWave =  $"root:Packages:twoP:acquire:VoltagePulseWaves:" + voltageWaveNameG
				SetScale/P x 0, (1/freq), "seconds", VoltageWave
				SetScale d 0,0, "V", VoltageWave
			else // choosing an existing wave not already on graph
				voltageWaveNameG = pa.popStr
				WAVE VoltageWave =  $"root:Packages:twoP:acquire:VoltagePulseWaves:" + voltageWaveNameG
				freq = 1/DimDelta(VoltageWave, 0)
				length=DimSize (VoltageWave,0)/freq
			endif
			// VoltageWave is either a new wave or an existing wave that is not on the graph
			// append wave to graph
			AppendToGraph VoltageWave
			// remove other trace, make sure x scaling is back to seconds
			variable iTrace, nTraces=itemsinlist (tracesList, ";") // should only be one trace
			string aTrace
			for (iTrace=0;itrace<ntraces;iTrace+=1)
				aTrace=stringfromlist(iTrace, tracesList)
				removeFromGraph $aTrace
				SetScale/P x 0, voltageScalingG, "seconds", $"root:Packages:twoP:acquire:VoltagePulseWaves:" + aTrace
			endfor
			voltageScalingG =1/freq	// save x scaling in global in case displaying time in frames
			
			//if there was no previous trace on graph, do axes
			if((cmpstr(TracesList, "")) == 0)
				setaxis left -10, 10
				ModifyGraph grid=1
				ModifyGraph mirror=2
				Label left "voltage (\\U)"
				Label bottom "time(\\U)"
				ModifyGraph manTick(left)={0,2,0,0},manMinor(left)={1,0}
			endif
			// check for time axis as frames
			STRUCT WMCheckboxAction cba
			cba.eventCode=2
			if (timeAsFrames)
				cba.checked=1
			else
				cba.checked=0
			endif
			twoP_VoltagePulseAxisProc(cba)
			// add free cursors 
			Cursor/P/F A $voltageWaveNameG 0,0.5
			Cursor/P/F B $voltageWaveNameG 1,0.5
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

 
//********************************* twoP_VoltagePulseEditHook *********************************************************************
// hook function that sets times and voltages from  cursor positions 
// Last Modified: 2026/07/16 by Jamie Boyd 
Function twoP_VoltagePulseEditHook(s)
	STRUCT WMWinHookStruct &s
	switch (s.eventCode)
		case 7:		// cursor moved
			NVAR VoltagePulseY1= root:packages:twoP:Acquire:VoltagePulseY1
			NVAR VoltagePulseX1= root:packages:twoP:Acquire:VoltagePulseX1
			NVAR VoltagePulseY2= root:packages:twoP:Acquire:VoltagePulseY2
			NVAR VoltagePulseX2= root:packages:twoP:Acquire:VoltagePulseX2
			SVAR VoltagePulseEditWave=root:packages:twoP:acquire:VoltagePulseEditWave
			NVAR axisIsFrames = root:packages:twoP:acquire:VoltageAxis
			GetAxis/Q left
			variable yPos = round((V_max -  s.yPointNumber *(V_max - V_min)) /0.1)*0.1
			GetAxis/Q bottom
			variable xPos
			if (axisIsFrames)
				xPos= round((V_min + s.PointNumber *(V_max - V_min)))
			else
				xPos = round((V_min + s.PointNumber *(V_max - V_min)) /0.1)*0.1
			endif
			strswitch (s.cursorName)
				case "A":
					VoltagePulseY1 = yPos
					VoltagePulseX1 = Xpos
					// can't move A to the right of B
					if (Xpos > VoltagePulseX2)
						Cursor/P/F B $VoltagePulseEditWave s.pointNumber + 0.05, s.yPointNumber
						VoltagePulseX2 = Xpos
					endif
					break
				case "B":
					VoltagePulseY2 = yPos
					VoltagePulseX2 = Xpos
					// or B to the left of A
					if (Xpos < VoltagePulseX1)
						Cursor/P/F A $VoltagePulseEditWave s.pointNumber - 0.05, s.yPointNumber
						VoltagePulseX1=Xpos
					endif
					break
			endswitch
			break
		case 2:  // kill
			SVAR VoltagePulseEditWave=root:packages:twoP:acquire:VoltagePulseEditWave
			NVAR isFrameTime= root:packages:twoP:acquire:VoltageAxis
			NVAR scaling=  root:packages:twoP:acquire:VoltageWaveScaling
			if (isFrameTime)
				WAVE voltageWave = $"root:Packages:twoP:acquire:VoltagePulseWaves:" + VoltagePulseEditWave
				setscale/P x 0, scaling, "seconds", voltageWave
			endif
	endswitch
	return 0
end

//************************************** twoP_VoltagePulseModeCheckProc ****************************************************************
// changes controls when different mode is selected
// Last Modified: 2026/07/16 by Jamie Boyd 
Function twoP_VoltagePulseModeCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			NVAR mode =	root:packages:twoP:Acquire:voltagePulseMode		// 0 for straight line, 1 for square wave, 2 for sine wave
			StrSwitch(cba.ctrlname)
				case "StraightCheck":
					mode =0
					CheckBox SineCheck value = 0
					CheckBox SquareCheck value = 0
					Setvariable FreqSetVar disable = 1
					Setvariable HeightSetVar disable = 1
					Setvariable Y2SetVar disable =0
					SetVariable Y1SetVar title="Start Voltage"
					break
				case "SquareCheck":
					mode =1
					CheckBox StraightCheck value = 0
					CheckBox SineCheck value = 0
					Setvariable FreqSetVar disable = 0
					Setvariable HeightSetVar disable = 0
					Setvariable Y2SetVar disable =1
					SetVariable Y1SetVar title="Offset Voltage"
					break
				
				case "SineCheck":
					mode=2
					CheckBox StraightCheck value = 0
					CheckBox SquareCheck value = 0
					Setvariable FreqSetVar disable = 0
					Setvariable HeightSetVar disable = 0
					Setvariable Y2SetVar disable =1
					SetVariable Y1SetVar title="Offset Voltage"
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


//**************************************** twoP_VoltagePulseAxisProc **************************************************************
// changes scaling from seconds to frames
// Last Modified: 2026/07/16 by Jamie Boyd  
Function twoP_VoltagePulseAxisProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			NVAR FrameTime = root:packages:twoP:Acquire:FrameTime
			SVAR voltagePulseName =root:packages:twoP:acquire:VoltagePulseEditWave
			NVAR scaling =  root:packages:twoP:acquire:VoltageWaveScaling
			WAVE voltageWave = $"root:packages:twoP:Acquire:VoltagePulseWaves:" + voltagePulseName
			NVAR VoltagePulseX1= root:packages:twoP:Acquire:VoltagePulseX1
			NVAR VoltagePulseX2= root:packages:twoP:Acquire:VoltagePulseX2
			if (cba.checked)	// changing from seconds to frames
				setscale/P x 0, (scaling/FrameTime), "frames", voltageWave
				ModifyGraph manTick(bottom)={0,10,0,0},manMinor(bottom)={9,0}
				SetVariable X1SetVar format="%3.f Frames",limits={0,inf,1}
				SetVariable X2SetVar format="%3.f Frames",limits={0,inf,1}
				VoltagePulseX1 /= FrameTime
				VoltagePulseX2 /= FrameTime
			else // changing from frames to seconds
				setscale/P x 0, scaling, "seconds", voltageWave
				ModifyGraph manTick(bottom)={0,1,0,0},manMinor(bottom)={0,0}
				SetVariable X1SetVar format="%5.2f Sec",limits={0,inf,0.1}
				SetVariable X2SetVar format="%5.2f Sec",limits={0,inf,0.1}
				VoltagePulseX1 *= FrameTime
				VoltagePulseX2 *= FrameTime
			endif
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End


//********************************** twoP_VoltagePulseCsrSetVarProc ********************************************************************
// sets cursors when times and voltage is set from setvariables
// Last Modified: 2026/07/16 by Jamie Boyd  
Function twoP_VoltagePulseCsrSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			SVAR VoltageWaveStr = root:packages:twoP:acquire:VoltagePulseEditWave
			strswitch (sva.ctrlname)
				case "X1SetVar":
					NVAR VoltagePulseY1= root:packages:twoP:Acquire:VoltagePulseY1
					Cursor/F A $VoltageWaveStr sva.dval,VoltagePulseY1
					break
				case  "Y1SetVar":
					NVAR VoltagePulseX1= root:packages:twoP:Acquire:VoltagePulseX1
					Cursor/F A $VoltageWaveStr VoltagePulseX1, sva.dval
					break
				case "X2SetVar":
					NVAR VoltagePulseY2= root:packages:twoP:Acquire:VoltagePulseY2
					Cursor/F B $VoltageWaveStr sva.dval,VoltagePulseY2
					break
				case  "Y2SetVar":
					NVAR VoltagePulseX2= root:packages:twoP:Acquire:VoltagePulseX2
					Cursor/F B $VoltageWaveStr VoltagePulseX2, sva.dval
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


//******************************************* twoP_VoltagePulseAddProc ***********************************************************
// adds a segment to the voltage pulse wave
// Last Modified: 2026/07/20 by Jamie Boyd 
Function twoP_VoltagePulseAddProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			NVAR mode =	root:packages:twoP:Acquire:voltagePulseMode		// 0 for straight line, 1 for square wave, 2 for sine wave
			SVAR VoltageWaveStr = root:packages:twoP:acquire:VoltagePulseEditWave
			WAVE VoltageWave = $"root:packages:twoP:acquire:VoltagePulseWaves:" + VoltageWaveStr
			NVAR VoltagePulseY1= root:packages:twoP:Acquire:VoltagePulseY1
			NVAR VoltagePulseX1= root:packages:twoP:Acquire:VoltagePulseX1
			NVAR VoltagePulseY2= root:packages:twoP:Acquire:VoltagePulseY2
			NVAR VoltagePulseX2= root:packages:twoP:Acquire:VoltagePulseX2
			NVAR VoltagePulseFreq = root:packages:twoP:acquire:VoltagePulseFreq
			NVAR VoltagePulseHeight = root:packages:twoP:acquire:VoltagePulseHeight
			// correction factor so frequency is in seconds if time is in frames
			NVAR timeIsFrames= root:packages:twoP:acquire:VoltageAxis
			NVAR frameTime=root:packages:twoP:acquire:FrameTime
			variable frequency = VoltagePulseFreq
			if (timeIsFrames)
				frequency *= frameTime		// cycles/second * seconds/frame = cycles/frame
			endif
			switch (mode)
				case 0:		//straight line segment from first point to second point y = mx + b
					variable m =(VoltagePulseY2-VoltagePulseY1)/(VoltagePulseX2 - VoltagePulseX1)
					variable b = VoltagePulseY1 -(m * VoltagePulseX1)
					VoltageWave [x2pnt(VoltageWave, VoltagePulseX1), x2pnt(VoltageWave, VoltagePulseX2)] = m*x + b
					break
				case 1:	 //square wave segment
					VoltageWave [x2pnt(VoltageWave, VoltagePulseX1), x2pnt(VoltageWave, VoltagePulseX2)] = VoltagePulseY1 + VoltagePulseHeight *(trunc(1 + 0.5 * sin(frequency*(2*pi) *(x-VoltagePulseX1))) -0.5)
					break
				case 2://sin wave segment
					VoltageWave [x2pnt(VoltageWave, VoltagePulseX1), x2pnt(VoltageWave, VoltagePulseX2)] = VoltagePulseY1 + 0.5*VoltagePulseHeight * sin((frequency*(2*pi)) *(x-VoltagePulseX1))
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

// ***************************************************************************************************************************************
// **********************************  Multiple Acquisition Controls ********************************************************************
// ***************************************************************************************************************************************


//*************************************** twoP_MultiAqDataModePopMenuProc ***************************************************************
// for multiAq scan mode popup menu, Sets scanMode global variable for MultiAcq acquistion mode
// 1 = Time Series, 2=Average, 3=Line Scan, 4=Z series, 5=ePhys Only"
// Last modified 2026/07/03 by Jamie Boyd
Function twoP_MultiAqDataModePopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			NVAR multiAqScanMode = root:packages:twoP:acquire:multiAqScanMode
			multiAqScanMode = pa.popNum
			twoP_TimesSetTimes()
			break
	endswitch
	return 0
End


//******************************************** twoP_MultiWavePopMenuProc **********************************************************
// For multiaq timing wave popup menu, sets string to name of chosen wave or makes a new wave in the datafolder for timing waves
// opens a table to edit the wave, with hook function enabled
// Last Modified 2025/07/11 by Jamie Boyd
Function twoP_MultiWavePopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			SVAR TimingWaveStr = root:packages:twoP:Acquire:multiAqWaveWaveStr
			if(cmpStr(pa.popStr,"New Timing Wave") ==0)
				string newTimingWaveStr = ""
				prompt newTimingWaveStr "New Timimg Wave:"
				doprompt "Name for New Timing Wave", newTimingWaveStr
				if(V_Flag == 1)
					return 1
				endif
				TimingWaveStr = CleanupName(newTimingWaveStr, 0 )
			else // selecting an existing wave
				TimingWaveStr = pa.popStr
			endif
			twoP_MultiWaveEdit(TimingWaveStr)
			break
	endswitch
	return 0
end


//**************************************** twoP_MultiAqTimeSetVarProc **************************************************************
// For multiaq period and delay setvariables, Parses entered strings into hr:sec:minute format
// Last modified 2025/07/11 by Jamie Boyd -  no more pass by reference.  Used sscanf
Function twoP_MultiAqTimeSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			SVAR strinG = $"root:packages:twoP:acquire:" + sva.vname
			strinG = twoP_MultiParseTimeStr(sva.sVal)
			break
	endswitch
	return 0
end

//****************************************** twoP_MultiParseTimeStr ************************************************************
// parses time strings into formatted time strings where minutes and seconds < 60 and only seconds will be fractional
// Last modified 2025/07/23 by Jamie Boyd -  added support for fractional hours, minutes, and seconds
Function/S twoP_MultiParseTimeStr(timeStr)
	string timeStr
	
	variable hours_in = 0, minutes_in= 0, seconds_in = 0
	variable v1, v2, v3
	sscanf timeStr, "%f:%f:%f", v1, v2, v3
	// If no colon, 1 value is read assume all is seconds. 
	// if 1 colon, 2 values are read, assume seconds and minutes.
	// if 2 colons, 3 values are read, hours, minutes, seconds
	switch(V_Flag)
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
			break
		default:
			return ""
			break
	endswitch
	// parse into hours, minutes, seconds in standard format 
	variable total_seconds = hours_in * 3600 + minutes_in * 60 + seconds_in
	variable hours_out = floor(total_seconds / 3600)
	variable seconds_remaining = total_seconds - (hours_out * 3600)
	variable minutes_out = floor (seconds_remaining/60)
	seconds_remaining -= minutes_out*60

	string timeOutStr
	if (hours_out ==0)
		if (minutes_out ==0)
			sprintf timeOutStr "%.01fs" seconds_remaining
		else
			sprintf timeOutStr "%02d:%s%.01f" minutes_out, SelectString (seconds_remaining >= 10, "0", ""), seconds_remaining
		endif
	else
		sprintf timeOutStr "%02d:%02d:%s%.01f" hours_out, minutes_out, SelectString (seconds_remaining >= 10, "0", ""), seconds_remaining
	endif
	return timeOutStr
end
	

//****************************************** twoP_MultiFormatSeconds ************************************************************
// formats time in seconds into formatted time strings where minutes and seconds < 60 and only seconds will be fractional
// Last modified 2026/08/07 by Jamie Boyd
Function/S twoP_MultiFormatSeconds (total_seconds)
	variable total_seconds
	
	variable hours_out = floor(total_seconds / 3600)
	variable seconds_remaining = total_seconds - (hours_out * 3600)
	variable minutes_out = floor (seconds_remaining/60)
	seconds_remaining -= minutes_out*60

	string timeOutStr
	if (hours_out ==0)
		if (minutes_out ==0)
			sprintf timeOutStr "%.01fs" seconds_remaining
		else
			sprintf timeOutStr "%02d:%s%.01f" minutes_out, SelectString (seconds_remaining >= 10, "0", ""), seconds_remaining
		endif
	else
		sprintf timeOutStr "%02d:%02d:%s%.01f" hours_out, minutes_out, SelectString (seconds_remaining >= 10, "0", ""), seconds_remaining
	endif
	return timeOutStr
end


//********************************* twoP_MultiReadTimeStr ***************************************************************
// reads equivalent seconds from a properly parsed time string
// Last modified 2025/07/11 by Jamie Boyd -Made separate function to get seconds from time string
function twoP_MultiReadTimeStr(timeStr)
	string timeStr
	
	variable v1 = str2num(StringFromList(0, timeStr, ":"))
	variable v2 = str2num(StringFromList(1, timeStr, ":"))
	variable v3 = str2num(StringFromList(2, timeStr, ":"))
	if (numtype (v3) ==2)
		if (numtype (v2) ==2)
			return(v1)
		else
			return 60*v1 + v2
		endif
	else
		return(3600 * v1 + 60 *v2 + v3)
	endif
end


//*************************************** twoP_MultiWaveEditButtonProc ***************************************************************
// For multiaq timig wave edit button, puts up a table to edit the selected timing wave by calling twoP_MultiWaveEdit
// Last Modified 2012/04/03 by Jamie Boyd
Function twoP_MultiWaveEditButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR TimingWaveStr = root:packages:twoP:Acquire:multiAqWaveWaveStr
			WAVE/Z timingwave = $"root:packages:twoP:Acquire:multiAqWaves:" + TimingWaveStr
			if (WaveExists (timingwave))
				 twoP_MultiWaveEdit (TimingWaveStr)
			endif
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End


//********************************* twoP_MultiWaveEdit *********************************************************************
// puts up a table to edit the selected timing wave, and installs hook function
// Last Modified 2026/07/24 by Jamie Boyd
function twoP_MultiWaveEdit(EditWaveName)
	string EditWaveName
	
	Wave/Z/T timingWave =  $"root:packages:twoP:Acquire:multiAqWaves:" + EditWaveName
	if (!(WaveExists(timingWave)))
		make/T/n = 0 $"root:packages:twoP:Acquire:multiAqWaves:" + EditWaveName
		Wave/T timingWave =  $"root:packages:twoP:Acquire:multiAqWaves:" + EditWaveName
	endif
	DoWindow/F Timing_Wave_Editor
	if (V_flag ==0)
		edit/K=1/N=Timing_Wave_Editor timingWave as "Timing Wave Editor"
		SetWindow Timing_Wave_Editor, hook(editHook)=twoP_MultiWaveEditHook
	else
		appendToTable/W=Timing_Wave_Editor timingWave
	endif
end


//**************************************** twoP_MultiWaveEditHook **************************************************************
// Window hook function for editing timing waves. After an entry is made, it parses the entry into the
// hours:minutes:seconds format 
// Last Modified 2026/07/24 by Jamie Boyd
Function twoP_MultiWaveEditHook(s)
	STRUCT WMWinHookStruct &s
	switch(s.eventCode)
		case 24:
			string result = TableInfo("", -2)
			string entry = StringByKey("ENTRYTEXT", result, ":", ";")
			string target=stringByKey ("TARGETCELL", result, ":", ";")
			variable row = str2num (StringFromList(0, target, ","))
			variable col = str2num (StringFromList(1, target, ","))
			string result1 = TableInfo("", col)
			WAVE/T editWave= $stringByKey ("WAVE", result1, ":", ";")
			if (row == numpnts (editWave)-1)	// if adding a new row to a wave, ENTRYTEXT is "" so read wave directly. Igor bug?
				entry = editWave[row]
			endif
			editWave [row]=twoP_MultiParseTimeStr(entry)
			break
	endswitch
	return 0	// If non-zero, we handled event and Igor will ignore it.
End


//************************************** twoP_MultiWaveDeleteButtonProc ****************************************************************
// Deletes the selected timing wave
// Last Modified 2012/04/03 by Jamie Boyd
Function twoP_MultiWaveDeleteButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR TimingWaveStr = root:packages:twoP:Acquire:multiAqWaveWaveStr
			WAVE/Z timingwave = $"root:packages:twoP:Acquire:multiAqWaves:" + TimingWaveStr
			if (WaveExists (timingwave))
				GUIPkilldisplayedwave(timingwave)
			endif
			TimingWaveStr= ""
		case -1: // control being killed
			break
	endswitch
	return 0
End


//*************************************** twoP_MultiWaveCheck ***************************************************************
// checks every point in a timing wave for correct formatting by parsing it, and checks monotonicity
// returns 0 if all points could be parsed and every time point is greater than previous time point
// returns 1 if a time point can not be parsed. Returns 2 if times are not monotonically increasing
// Last Modified 2026/07/24 by Jamie Boyd
function twoP_MultiWaveCheck(theWave)
	WAVE/T theWave
	
	variable iw, nw = numpnts (theWave)
	variable thisVal, lastVal
	theWave[0] = twoP_MultiParseTimeStr(theWave[0])	// try to parse first row
	if (cmpStr (theWave[0], "") == 0)
		return 1
	endif
	lastVal = twoP_MultiReadTimeStr(theWave[0])		// make sure first time point is >= 0, save it as last val
	if (lastVal < 0)
		return 2
	endif
	for (iw=1 ; iw < nw ; iw +=1, lastVal = thisVal)
		theWave[iw] = twoP_MultiParseTimeStr(theWave[iw]) // try to parse the row
		if (cmpStr (theWave[iw], "") == 0)
			return 1
		endif
		thisVal = twoP_MultiReadTimeStr(theWave[iw])	// check this time point is > last time point
		if (thisVal <= lastVal)
			return 2
		endif
	endfor
	return 0
end

//************************************** twoP_MultiPrepProc ****************************************************************
// MultiAq Prep button procedure. Prepare Multi prepares all the waves and such needed for a series of scans
// but does not start the timer counting down to start a scan
// The start scan button starts BkgTask that counts the timer down to first and subsequent scans.
// The BkgTask starts the threads and intits the scan
// Last Modified 20026/08/12 by Jamie Boyd
Function twoP_MultiPrepProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			STRUCT twoP_ScanStruct s
			NVAR multiAqScanMode =  root:packages:twoP:acquire:multiAqScanMode	// type of scan - tSeries, avg, lines, z-series, ephys only
			NVAR multiModeG = root:packages:twoP:acquire:multiAqTimeMode			// control of multiaq, Period, wave, or trigger
			variable multiMode = multiModeG
			NVAR nAqs = root:packages:twoP:acquire:multiAqnAqs					// number of aquisitions, to be set depending on multiAqTimeMode
			NVAR iAq = root:packages:twoP:acquire:multiAqiAq					// for iterating through nAqs
			iAq=0
			NVAR preMakeWaves= root:packages:twoP:acquire:MultiPreMakeWaves
			SVAR firstScan = root:packages:twoP:acquire:NewScanName
			//NVAR autInc = root:packages:twoP:acquire:AutincCheck
			//autInc = 1
			NVAR exportafterscan = root:packages:twoP:acquire:exportAfterScan
			try
				if(exportafterscan > 1)	// make sure path is set
					SVAR PathStr =root:Packages:twoP:examine:ExportPath		// the global string were we store the path
					pathinfo ExportPath
					if(!((V_Flag ==1) &&(cmpstr(S_path, PathStr) ==0)))// path does not exits or is not the same as shown in the string
						NewPath /O/M="Select a Folder in which to store Scan Waves" ExportPath
						AbortOnValue (V_Flag), 0 // V_flag is set to 0 if newpath is successful
						PathInfo ExportPath
						pathstr =  s_path
					endif
				endif
				// do initialization of scan number and timing waves for different multi-modes
				switch(multiModeG)
					case kMultiUsePeriod:   // make wave maq_seconds from the periods and we will use Wave method
						NVAR multiAqPeriodNum = root:packages:twoP:acquire:multiAqPeriodNum
						nAqs = multiAqPeriodNum
						SVAR periodStr = root:Packages:twoP:Acquire:multiAqPeriodPeriodStr
						variable period=twoP_MultiReadTimeStr(periodStr)		// period in seconds
						SVAR delayStr =root:packages:twoP:acquire:multiAqPeriodDelayStr
						variable delay =twoP_MultiReadTimeStr(delayStr)			// delay in seconds
						make/o/n=(nAqs) root:packages:twoP:acquire:multiAqWaves:maq_seconds		// time when each scan will start, in seconds from start time
						WAVE maq_seconds = root:packages:twoP:acquire:multiAqWaves:maq_seconds
						maq_seconds [0]=delay
						maq_seconds [1,nAqs -1] = delay +p*period
						multiMode = kMultiUseWave
						break
					case kMultiUseWave:// make a wave maq_seconds where time to start each scan is in seconds
						SVAR multiWaveName = root:packages:twoP:Acquire:multiAqWaveWaveStr
						WAVE/t/z multiWave = $"root:packages:twoP:acquire:multiAqWaves:" + multiWaveName
						abortOnValue(!(waveExists(multiWave))), 1
						abortOnValue (twoP_MultiWaveCheck(multiWave)), 2
						nAqs = numpnts(multiWave)
						make/o/n=(nAqs) root:packages:twoP:acquire:multiAqWaves:maq_Period
						WAVE maq_seconds = root:packages:twoP:acquire:multiAqWaves:maq_seconds
						maq_seconds = twoP_MultiReadTimeStr(multiWave[p])
						break
					case kMultiUseTrigger: // set nAqs and ensure trigger checkbox is on
						NVAR inputTrigger = root:packages:twoP:acquire:inputTriggerCheck
						inputTrigger = 1
						NVAR multiAqTriggerNum = root:packages:twoP:acquire:multiAqTriggerNum
						nAqs =multiAqTriggerNum
						break
				endswitch
				// update stage, need do this for all scan modes, and need to do before loading scan struct, cause it will read stage values from globals
				SVAR stageProc = root:packages:twoP:acquire:stageProc
				if (multiAqScanMode == kzSeries)
					NVAR zFirstZ = root:Packages:twoP:Acquire:ZFirstZ
					NVAR zstepSize = root:Packages:twoP:Acquire:ZStepSize
					StagesSetAbsAxis(stageProc, "Z", zFirstZ, kStagesReturnAfter)
					StageSetIncrement(stageProc, "Z", abs(zStepSize), 1)
				endif
				StageUpdate(stageProc,(kXbit + kYbit + kZbit), 1)
				// load the scan struct with data from constants - other things we will add later
				twoP_ScanLoadStruct(s)
				// check for channel selection according to scan mode
				if (s.scanMode == kEphysOnly)
					AbortOnValue (itemsInList(s.selEphysChanList, ";") ==0), 3
				else
					AbortOnValue (itemsInList(s.selImageChanList, ";") ==0), 4
				endif
				// check for overwriting. check all scans at once, the function saves a list of user-vetted scan names in s.multiScanList
				AbortOnValue twoP_MultiCheckOverWrite (s), 5
				// make laser scan waves
				if (s.scanMode != kePhysOnly)
					twoP_ScanMakeGalvoWaves(s)
				endif
				// set Horizontal galvo to start of X galvo waves
				WAVE HorWave=root:Packages:twoP:acquire:HorWave
				fDAQmx_WriteChan(s.ImageBoard, 0, HorWave [0], -10, 10)
				//  Set Vertical galvo to right Y position for line scan, or to start of Y galvo wave
				if(multiAqScanMode == kLineScan)
					fDAQmx_WriteChan(s.ImageBoard, 1, s.YSV, -10, 10)
				else
					WAVE VerWave=root:Packages:twoP:acquire:VerWave
					fDAQmx_WriteChan(s.ImageBoard, 1, VerWave [0], -10, 10)
				endif
				twoP_MultiCheckOverWrite(s)
				// make Scan waves,if pre-make is set, else we will make the scan waves as we need them
				if (preMakeWaves)
					twoP_MultiMakeScanWaves(s)
				else
					twoP_ScanMakeScanWaves(s)
					string/G $"root:twoP_Scans:" + s.newScanName + ":" + s.newScanName + "_info" = twoP_ScanNoter(s) +  "multiAq_i:0\r"  + "multiAq_N:" + num2str (nAqs) + "\r"
				endif
				//save first scanNote as general scan note we will modify for each succeeding scan
				// only need to change scan name, multiaq number and start time
				SVAR firstScanNote =  $"root:twoP_Scans:" + s.newScanName + ":" + s.newScanName + "_info"
				SVAR multiAcqScanNote= root:packages:twoP:acquire:multiAcqScanNote
				multiAcqScanNote = firstScanNote
				SVAR multiAcqScanList = root:packages:twoP:acquire:multiAcqScanList
				multiAcqScanList = s.multiScanList
				// Select first scan as current scan, with selected channels on scanGraph to match channels being acquired
				if(s.scanMode != kephysOnly)
					SVAR selChans = root:packages:twoP:examine:scanGraphSelChans
					selChans=s.onlyChansImage
				endif
				STRUCT WMPopupAction pa
				pa.eventCode = 2
				pa.popStr = stringfromlist(0, s.multiScanList, ";")
				twoP_ScanPopMenuProc(pa)
				// make Scan helper waves, thread waves and temp 1D waves we scan directly into, and adds wave references in threadData
				if (s.scanMode != kEPhysOnly)
					twoP_ScanMakeHelperWaves(s)
				endif
				//update experiment size after making waves
				twoP_ExpSizeUpdate()
				// adjust multi-aq valDisplay so it will show progress
				ValDisplay multiAqProgressDisplay win = twoP_Controls, limits={0, nAqs, 0}, value=_NUM:0
				if(s.scanmode != kephysOnly)
					// Zero globals for counting line, frames, averages, chunks, as specific to each scan mode
					twoP_ScanZeroGlobals(s)
				endif
				// save scanstruct as string
				SVAR scanStructStr = root:packages:twoP:acquire:multiAcqScanStructStr
				StructPut/S s scanStructStr
				
				// enable start button
				Button AqStartButton win = twoP_Controls, disable=0
			catch
				switch(V_abortCode)
					case 0:
						doAlert 0, "The export path must be set when saving scans during multi-acquisition."
						break
					case 1:
						doAlert 0, "Selected multiple acquisition timing wave does not exist."
						break
					case 2:
						doAlert 0, "Selected multiple acquisition timing wave is not valid."
						break
					case 3:
						doAlert 0, "Select some ePhys channels before starting ePhys scanning."
						break
					case 4:
						doAlert 0, "Select some image channels before scanning."
						break
					case 5:
						doAlert 0, "Multiple acquisition cancelled while configuring scan names."
						break
					case 6:
						doAlert 0, "Multiple acquisition could not pre-make waves for selected scans."
						break
				endSwitch
				return 1
			endTry
			break
	case -1: // control being killed
	break
endswitch

return 0
End


// ***************************************************************************************************************************************
//----------------------------------------- Starting a Scan -----------------------------------------------
// ***************************************************************************************************************************************


//******************************************************************************************************
// A structure to hold all the various globals so  that we can pass them easily between functions.
// Most are set by LoadScanStruct function, some others are added later
// Last Modified:
// 2026/08/16 by Jamie Boyd - put all the string first so they can be ignored when saving struct to a global string
// 2026/07/31 by Jamie Boyd - added fields for scan options like scan-at-once 
// 2026/07/08 by Jamie Boyd - added fields for multple acquisitions
// 2025/08/26 by Jamie Boyd 
// 2016/11/15 by Jamie Boyd - added support for separate back ground tasks for each channel plus merge
Structure twoP_ScanStruct
	string newScanName			// name to be given to new scan
	string scanNote				// note entered by user
	string multiScanList		// semi-colon separated list of scans that will be done
	string selImageChanList		// list of channel name: aiChan number pairs. e.g. "ch1:0,ch2:1,"
	string onlyChansImage		// just the channel names, stripped of ai number. e.g. "ch1,ch2"
	string scanWavePath			// paths to image waves to scan, channels on which to scan them, plus scan options in NIDAQ format "root:twoP_Scans:Scan_000:Scan_000_ch1, 0/DIFF, -5, 5;
	string imageBoard			// name of NIDAQ board, as configured with NI MAX
	string obj					// name of microscope objective used for scan
	string liveRatioTopChan 	// name of top chan for live ratio, or "" if not doing live ratio
	string liveRatioBottomChan	// name of bottom chan for live ratio, or "" if not doing live ratio
	string LSLinkWave			// name of scan that line scan was drawn on
	string ePhysBoard
	string selEphysChanList		//list of channel name: aiChan pairs
	string onlyChansEphys
	string ePhysPath  // string containing paths to ePhys waves to scan and channels on which to scan them, in NIDAQ format
	string stageProc
		string vOutWave1
	string vOutWave2
// general scan/run settings
	variable scanMode			// one of 0=live mode, 1=time series, etc
	
	variable overWriteWarn		// set if overwrite warning checkbox is on
	variable inPutTrigger		// set if input trigger for scanning start is on
	// multi acquisition - note that the struct is saved between acquisitions when multiacqing
	variable isMulti			// set if this scan is part of a multi-acquisition
	variable multTimeMode		// timing for start scans from trigger or from a wave of times
	variable multiAqiAq			// to iterate through multiaq. 
	variable multiAqNaqs		// total number of acquisitions in the multiacq
	variable multiAqPremake		// if set, waves will be made ahead of time for all scans
	variable multiAqTimeMode	// timing, either from trigger or from waves
	// image settings
	variable scanChans			// for compatibility, 1 for "ch1", 2 for "ch2", 3 for both channels. superceded by selImageChanList
	variable numFrames			// number of frames for scanWave, total number of frames to acquire. LiveAvg or NumAvg frames when averaging, 1 for a line scan
	variable pixHeight			// Pixel height and width of scan waves
	variable pixWidth
	variable xSV				// start and end voltages to send to galvos
	variable xEV
	variable YSV
	variable YEV
	variable threadGroupID		// thread group that does processing durning scanning, one thread per channel
	// image scaling
	variable objNum				// row number of objective in objective list wave
	variable xImSize			// image size in scaled dimensions (meters)
	variable yImSize
	variable xPixSize			// pixel sizes in scaled dimensions.
	variable yPixSize
	variable xScalStart			// X and Y offsets in scaled dimensions to start of image. Calulated from stage position
	variable yScalStart
	//  image Timing
	variable pixTime
	variable lineTime
	variable frameTime
	variable RunTime
	// galvo wave settings
	variable dutyCycle
	variable flybackMode
	variable scanHeadDelay
	variable flybackProp
	variable pixWidthTotal
	//live ROI, used for live mode, time series, and line scan
	variable liveROI 			// set if doing roi live during scanning
	variable liveROISecs 		// seconds of ROI to display, or 0 if not doing a live ROI
	variable liveRatio			// set if doing live ratio, one channel / another channel
	variable ratioTopChanNum	// position in threadData wave of wave used for top channel for live ratio
	variable ratioBottomChanNum	// position in threadData wave of wave used for bottom channel for live ratio
	variable LROIleft			// points (not scaled dimensions) for live ROI position
	variable LROItop
	variable LROIright
	variable LROIbottom
	// Live mode specific	number of frames for live avergaing is s.numFrames
	variable LiveStackAtOnce	// scan nLiveAvg frames at once if frame time is shorter than minLiveFrameTime, else scan 1 frame at a time
	variable liveHist			// set if doing live histogram 
	variable liveRaw			// set if showing raw data
	// Average specific			// number of frames to average is s.numFrames
	variable AvgDoUpdate		// set if updating average after every frame, cleared to collect all frames at once, then average
	// LineScan specific  number of frames is 1
	variable LSscanAtOnce		// set if doing the whole scan at once, cleared if scanning chunks at a time
	variable LSChunkSize		// number of lines that are scanned or processed at a time
	variable LSnumChunks		// number of chunks that make up the scan
	// time series
	variable TSscanAtOnce		// set if doing the whole scan at once, cleared if scanning chunks at a time
	variable TSChunkSize		// number of frames to scan at once if repeated scanning
	variable TSnumChunks		// number of chunks in the scan	
	// Z series specific
	variable zStepSize			// step size to move after each frame
	variable NumZseriesAvg		// number of images to average per plane
	variable zAvgStackAtOnce 	// set if scanning stack to average at once
	// ephys
	variable ePhysFreq
	variable ePhysChans
	// stage
	variable xPos
	variable yPos
	variable zPos
	// triggers
	variable trigChans	// old-style bitwise, 1 for ctr 0, 2 for ctr 1, 3 for both
	variable trig1Secs	// seconds to delay, already converted from frames, or lines
	variable trig2Secs
	// voltage waves
	variable vOutChans
	variable vOutStart // "1 = on Scan Start;2=on Trig 1;"
endStructure

//*********************************** twoP_ScanStartSingleProc *******************************************************************
// Function called by the "Start Scan" Button for single Scan acquisition .Makes any needed checks, 
// creates all the needed waves, and then starts the scan.
// Last Modified 2026/08/05 by Jamie - continuing refactoring
// Modified: 2026/07/31 by Jamie Boyd. refactored for multiaq mode - making separation between things done for every scan
// and things done once at start of multiaq

Function  twoP_ScanStartSingleProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			STRUCT twoP_ScanStruct s
			NVAR scanMode = root:packages:twoP:Acquire:ScanMode				// one of the different scan types, but NOT multiAq
			NVAR ScanStartMode = root:packages:twoP:Acquire:ScanStartMode	// set to scan type we are doing, good if tab is changed or for multiAq
			ScanStartMode = scanMode
			// For a Z-stack, move to start of stack and set z step size
			SVAR stageProc = root:packages:twoP:acquire:stageProc
			if (ScanStartMode == kzSeries)
				NVAR zFirstZ = root:Packages:twoP:Acquire:ZFirstZ
				NVAR zstepSize = root:Packages:twoP:Acquire:ZStepSize
				StagesSetAbsAxis(stageProc, "Z", zFirstZ, kStagesReturnAfter)
				StageSetIncrement(stageProc, "Z", abs(zStepSize), 1)
			endif
			// update stage position for all scan modes.
			StageUpdate(stageProc,(kXbit + kYbit + kZbit), 1)
			// Load ScanStruct with settings variables
			twoP_ScanLoadStruct(s)
			try
				// check for channel selection according to scan mode
				if (ScanStartMode == kEphysOnly)
					abortOnValue (itemsInList(s.selEphysChanList, ";") ==0), 0
				else
					AbortOnValue (itemsInList(s.selImageChanList, ";") ==0), 1
				endif
				// check for overwriting
				AbortOnValue (twoP_ScanCheckOverWrite(s)), 2
				// make laser scan waves and set laser to start of galvo waves
				if(ScanStartMode != kePhysOnly)
					AbortOnValue (twoP_ScanMakeGalvoWaves(s)), 3
					// set Horizontal galvo to start of X galvo waves
					WAVE HorWave=root:Packages:twoP:acquire:HorWave
					fDAQmx_WriteChan(s.ImageBoard, 0, HorWave [0], -10, 10)
					//  Set Vertical galvo to right Y position for line scan, or to start of Y galvo wave
					if(ScanStartMode == kLineScan)
						fDAQmx_WriteChan(s.ImageBoard, 1, s.YSV, -10, 10)
					else
						WAVE VerWave=root:Packages:twoP:acquire:VerWave
						fDAQmx_WriteChan(s.ImageBoard, 1, VerWave [0], -10, 10)
					endif
				endif
				// make Scan waves - also makes dataFolder for scan
				AbortOnValue (twoP_ScanMakeScanWaves(s)), 4
				//make scan note in dataFolder that was just made
				string/G $"root:twoP_Scans:" + s.NewScanName + ":" + s.NewScanName + "_info" = twoP_ScanNoter(s)
				// change the controls to show scanning
				// this updates the scan graph which makes 2D waves for display of live, time series, and Z series scaning
				// which are used by the acquisition threads so call it before calling twoP_ScanMakeHelperWaves
				twoP_ScanDoScanControls(s)
				if (s.scanMode != kephysOnly)
					// make Scan helper waves, thread waves and temp 1D waves we scan directly into, and adds wave references in threadData
					AbortOnValue twoP_ScanMakeHelperWaves(s), 5
				endif
				//update experiment size after making waves
				 twoP_ExpSizeUpdate()
				 // live ROI?
				if ((s.liveROI) && ((s.scanMode == kLiveMode) || (s.scanMode == kTimeSeries) || (s.scanMode == kLineScan)))
					twoP_ScanMakeLROIGraph(s)
				endif
				// live Mode Histogram or Raw A/D?
				if (s.scanMode == kLiveMode)
					if (s.liveHist)
						SVAR HistGraphSelChans = root:packages:twoP:examine:HistGraphSelChans
						HistGraphSelChans = s.onlyChansImage
						twoP_HistMakeGraph()		// From twoP_examine, so no scanStruct for you
					endif
					if(s.liveRaw)
						twoP_ScanMakeLiveRawGraph(s)
					endif
				endif
				if(s.scanmode != kephysOnly)
					// Zero globals for counting line, frames, averages, chunks, as specific to each scan mode
					twoP_ScanZeroGlobals(s)
					// start Threads, get threadgroup Id in case we need to release thhreads
					twoP_ScanStartThreads(s)
				endif
				NVAR gThreadGroupID = root:packages:twoP:Acquire:gThreadGroupID
				// Start the scan, does NIDAQmx code and sets up threads and background tasks/Scan hook functions
				AbortOnValue(twoP_InitScan(s)), 6
				// catch any errors
				catch
					switch(V_abortCode)
						case 0:
							doAlert 0, "Select some ePhys channels before starting ePhys scanning."
							break
						case 1:
							doAlert 0,  "Select some Image channels before scanning."
							break
						case 2:
							doAlert 0,"Scanning will be canceled."
							break
						case 3:
							doAlert 0, "Waves for Galvonometer scanning could not be made. See error msg in History."
							break
						case 4:
							doAlert 0, "Waves for Scan data could not be made."
							break
						case 5:
							doAlert 0, "Scan Helper Waves could not be made."
							break
						case 6:
							doAlert 0, "Scanning could not be started."
							twoP_EndScanning ()
							break
					endSwitch
				endtry
			break
	endswitch
	return 0
end

//******************************************************************************************************
// Reads values appropriate for this scan into the scanStructure, s
// Last Modified 2026/08/13 by Jamie Boyd
Function twoP_ScanLoadStruct(s)
	STRUCT twoP_ScanStruct &s
	
	// multiAq stuff
	NVAR isMulti = root:packages:twoP:acquire:multiModeIsMulti
	s.isMulti = isMulti
	if(isMulti)
		s.isMulti = 1
		NVAR multiAqScanMode = root:packages:twoP:acquire:multiAqScanMode
		s.ScanMode = multiAqScanMode
		NVAR preMake= root:packages:twoP:acquire:MultiPreMakeWaves
		s.multiAqPremake = preMake
		NVAR multTimeMode= root:packages:twoP:acquire:multiAqTimeMode
		s.multTimeMode = multTimeMode
		NVAR multiAqNaqs = root:packages:twoP:acquire:multiAqNaqs
		s.multiAqNaqs = multiAqNaqs
		s.multiAqiAq = 0	
	else
		s.isMulti = 0
		NVAR scanMode = root:packages:twoP:Acquire:ScanMode
		s.ScanMode = scanMode
	endif
	// Scan name and general checks for imaging and/or ephys not applicable to live mode
	if(s.scanMode == kLiveMode)
		s.NewScanName = "LiveScan"
	else
		// Scan Name
		SVAR newScanName = root:Packages:twoP:acquire:NewScanName
		s.NewScanName = NewScanName
		NVAR inPutTrigger = root:packages:twoP:acquire:inputTriggerCheck
		s.inPutTrigger= inPutTrigger
		NVAR overWriteWarn = root:packages:twoP:acquire:overwriteWarnCheck
		s.overWriteWarn = overWriteWarn
		notebook twoP_Controls#EXPNOTEBOOK getData=2
		s.scanNote = S_Value
		if(scanMode == kEphysOnly)
			NVAR runTime = root:Packages:twoP:acquire:EphysOnlyTime
		else
			NVAR runTime = root:Packages:twoP:acquire:RunTime
		endif
		s.runTime = runTime
	endif
	// Stage procedue
	SVAR StageProc = root:Packages:twoP:Acquire:StageProc
	s.StageProc = StageProc
	// wave scaling and position - make sure stage is updated before loading scan struct
	WAVE distFromZero = $"root:packages:" + s.StageProc + ":DistanceFromZero"
	s.xPos=distFromZero [%X]
	s.yPos = distFromZero [%Y]
	s.zPos = distFromZero [%Z]
	// objective used for scaling
	WAVE/T objWave = root:packages:twoP:acquire:ObjWave
	SVAR obj = root:Packages:twoP:Acquire:curObj 
	NVAR objNum = root:Packages:twoP:Acquire:curObjNum
	s.obj = obj
	s.ObjNum = objNum
	variable xScaling= str2num(objWave [s.objNum] [1])
	variable yScaling= str2num(objWave [s.objNum] [2])
	variable xOffset = str2num(objWave [s.objNum] [3])
	variable yOffset = str2num(objWave [s.objNum] [4])
	s.xScalStart = s.xPos - xOffset + s.xSV * xScaling
	s.yScalStart = s.yPos - yOffset + s.ySV * yScaling
	// settings for image scan, live mode or otherwise
	SVAR imageBoard = root:packages:twoP:acquire:imageBoard
	variable iChan,nChans
	String baseName
	string ai_chanName, ai,chanName, type, range, scaling, offset	// for building up NIDAQ configuration
	s.imageBoard = imageBoard
	if(s.scanMode != kEPhysOnly)
		SVAR selImageChanList = root:packages:twoP:acquire:selImageChanList
		s.selImageChanList = SelImageChanList
		nChans= itemsInlist(s.selImageChanList, ";")
		WAVE/T chanList = root:packages:twoP:acquire:imChanList		// from preferences, channel names plus scaling, range, offset info
		baseName = "root:twoP_Scans:" + s.newScanName +":" +  s.newScanName + "_"	// everything but channel name
		s.scanWavePath = ""
		for(iChan=0; iChan < nChans; iChan +=1)
		//read info to configure scan
			ai_chanName = stringFromList(iChan, s.selImageChanList,";")	// the name of the channel, plus the number of the analog input used to scan it
			chanName = stringFromList(0, ai_chanName, ":")				// name of the channel, as assigned by user
			ai = stringFromList(1, ai_chanName, ":")					// num of the analog input channel
			type = chanList [str2num(ai)] [2]							// differential, pseudo-differential, referenced single endded, etc
			range =  chanList [str2num(ai)] [3]							// voltage range for A/D
			Scaling = chanList [str2num(ai)] [4]						// scaling applied after acquisition
			Offset = chanList [str2num(ai)] [5]							// offset applied after acquisition
			s.scanWavePath += "root:packages:twoP:acquire:Acq1D_" + chanName +  ", " + ai + "/" + type + ", -" +  range + ", " + range + ", " + scaling + ", " + offset + ";"
		endfor
		// save path as global string
		SVAR ImScanList = root:packages:twoP:acquire:multiAcqImScanList
		ImScanList = s.scanWavePath
		// a string containing channel names but not ai channel numbers
		s.onlyChansImage = twoP_ChansOnlyChans (s.selImageChanList)
		// Reference PixWidth and height, voltage scaling based on scan mode
		if(s.scanMode == kLineScan)
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
		s.pixHeight = pixHeight
		s.XSV = XSV
		s.XEV= XEV
		s.YSV = YSV
		s.xImSize = xImSize
		s.xPixSize = xPixSize
		s.yImSize = yImSize
		s.yPixSize = yPixSize
		if(s.ScanMode != kLineScan)
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
		s.pixTime = pixTime
		s.DutyCycle = DutyCycle
		s.FlybackMode = flybackMode
		s.scanHeadDelay = scanHeadDelay
		s.flybackProp = flybackProp
		s.pixWidthTotal = pixWidthTotal
		s.frameTime = frameTime
		s.lineTime = LineTime
		// Live ROI for live mode or time series
		if((s.scanmode == kLiveMode) ||(s.scanMode == kTimeSeries) ||(s.scanMode == kLineScan))
			NVAR liveROICheck =  root:Packages:twoP:Acquire:liveROICheck
			s.liveROI = liveROICheck
			if(liveROICheck)
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
				if(liveROIRatioCheck)
					SVAR topChan = root:Packages:twoP:Acquire:liveROItopChan
					SVAR bottomChan = root:Packages:twoP:Acquire:liveROIBottomChan
					if((cmpStr(bottomChan, "") ==0) ||(cmpStr(bottomChan, "") ==0)) 
						liveROIRatioCheck = 0
					else
						s.liveRatioTopChan = topChan		// ratioTopChanNum will be filled out when making waves for threads
						s.liveRatioBottomChan = bottomChan	// ratiobottomChanNum will be filled out when making waves for threads
					endif
				endif
				s.liveRatio = liveROIRatioCheck
			endif
		else
			s.liveROI = 0
		endif
	endif
	// board and channels for ePhys, triggers, and voltage waves
	if(((s.scanMode == kTimeSeries) ||(s.scanMode == kLinescan)) ||(s.scanMode == kephysOnly))
		SVAR ephysBoard = root:packages:twoP:acquire:ePhysBoard
		s.ePhysBoard = ephysBoard
		SVAR selePhysChanList = root:packages:twoP:acquire:selePhysChanList
		s.selePhysChanList = selePhysChanList
		nChans= itemsInlist(s.selePhysChanList, ";")
		s.onlyChansePhys = twoP_ChansOnlyChans (s.selePhysChanList)
		NVAR ePhysFreq = root:Packages:twoP:acquire:ePhysSampFreq
		s.ePhysFreq = ePhysFreq
		// scan paths - do this for ePhys but for imaging, it is done when making helper waves
		baseName = "root:twoP_Scans:" + s.newScanName +":" +  s.newScanName + "_"
		WAVE/T chanList = root:packages:twoP:acquire:ePhysChanList	
		s.ePhysPath = ""
		for (iChan=0; iCHan < nChans; iChan +=1)
			ai_chanName = stringFromList(iChan, s.selePhysChanList,";")
			ai = stringFromList(1, ai_chanName, ":")
			chanName = stringFromList(0, ai_chanName, ":")
			type = chanList [str2num(ai)] [2]
			range =  chanList [str2num(ai)] [3]
			Scaling = chanList [str2num(ai)] [4]
			Offset = chanList [str2num(ai)] [5]
			s.ePhysPath += baseName + chanName + ", " + ai + "/" + type + ", -" +  range + ", " + range + ", " + scaling + ", " + offset + ";"
		endfor
		// save paths as global string
		SVAR ePhysScanList = root:packages:twoP:acquire:multiAcqEphysScanWaveList
		ePhysScanList = s.ePhysPath
		// triggers
		NVAR trig1Check = root:Packages:twoP:Acquire:trig1Check
		NVAR trig2Check = root:Packages:twoP:Acquire:trig2Check
		s.trigChans =(trig1Check) + 2*(trig2Check)
		if(trig1Check)
			NVAR DelaySecs = root:Packages:twoP:Acquire:DelaySecs1
			s.trig1Secs = DelaySecs
		endif
		if(trig2Check)
			NVAR DelaySecs = root:Packages:twoP:Acquire:DelaySecs2
			s.trig2Secs = DelaySecs
		endif
		// voltage pulse waves
		NVAR voltagePulseChans = root:packages:twoP:Acquire:voltagePulseChans
		s.vOutChans = voltagePulseChans
		if(voltagePulseChans & 1)
			SVAR Vwave1Name = root:packages:twoP:acquire:voltageWave1
			s.VoutWave1 = Vwave1Name
		endif
		if(voltagePulseChans & 2)
			SVAR Vwave2Name = root:packages:twoP:acquire:voltageWave2
			s.VoutWave2 = Vwave2Name
		endif
		if(voltagePulseChans)
			controlinfo/w=twoP_Controls VoltagePulsePopUp
			s.vOutStart = V_Value
		endif
	endif

	// switch for things specific to one scan mode
	switch(s.scanMode)
		case kLiveMode:	// Live mode specific - average frames and live histogram
			NVAR LiveStackAtOnce = root:packages:twoP:acquire:LiveStackAtOnce
			s.LiveStackAtOnce = LiveStackAtOnce
			NVAR liveHistCheck = root:Packages:twoP:acquire:liveHistCheck
			s.liveHist = liveHistCheck
			NVAR liveRawData =  root:packages:twoP:acquire:liveRawData
			s.liveRaw = liveRawData
			NVAR liveAvgFrames = root:Packages:twoP:Acquire:LiveNumAvgFrames
			s.numFrames =liveAvgFrames
			s.selEphysChanList = ""
			break
		case kTimeSeries:
			NVAR numFrames = root:Packages:twoP:Acquire:tSeriesNumFrames
			s.numFrames = numFrames
			NVAR tChunkSize = root:packages:twoP:acquire:tSeriesChunkSize
			s.TSChunkSize = tChunkSize
			NVAR numChunks = root:Packages:twoP:Acquire:tSeriesNumChunks
			s.TSnumChunks = numChunks
			NVAR scanAtOnce = root:packages:twoP:acquire:tSeriesScanAtOnce
			s.TSscanAtOnce=scanAtOnce
			break
		case kSingleImage:
			NVAR numFrames =  root:Packages:twoP:Acquire:AvgNumFrames
			s.numFrames = numFrames
			NVAR AvgDoUpdate = root:packages:twoP:acquire:AvgDoUpdate
			s.AvgDoUpdate = AvgDoUpdate
			s.selEphysChanList =""
			break
		case kLineScan:
			s.NumFrames = 1
			SVAR LSLinkWaveStr= root:packages:twoP:Acquire:LSLinkWaveStr
			s.LSLinkWave = LSLinkWaveStr
			NVAR lScanChunkSize = root:packages:twoP:acquire:LSchunkSize
			s.LSChunkSize = lScanChunkSize
			NVAR LSnumChunks = root:packages:twoP:acquire:LSnumChunks	
			s.LSnumChunks = LSnumChunks
			NVAR LSscanAtOnce = root:packages:twoP:acquire:LSscanAtOnce
			s.LSscanAtOnce = LSscanAtOnce
			break
		case kZseries:
			NVAR numFrames = root:Packages:twoP:Acquire:NumZseriesFrames
			s.numFrames = numFrames
			NVAR zFirstZ = root:Packages:twoP:Acquire:ZFirstZ 
			NVAR zstepSize = root:Packages:twoP:Acquire:ZStepSize
			NVAR zAvg = root:Packages:twoP:Acquire:NumZseriesAvg
			NVAR zAvgStackAtOnce = root:Packages:twoP:Acquire:zAvgStackAtOnce
			s.zAvgStackAtOnce = zAvgStackAtOnce
			s.zPos = zFirstZ
			s.zStepSize = zStepSize
			s.NumZseriesAvg = zAvg
			s.selEphysChanList = ""
			break
	endswitch

	return 0
end

//******************************************************************************************************
//  if overwrite warning is enabled, checks to see if scan name already exists, and interacts with user to overwrite or increment scan name
// Last Modified 2014/08/13 by Jamie Boyd
Function twoP_ScanCheckOverWrite(s)
	STRUCT twoP_ScanStruct &s
	
	// Check to see if scan wave exists, and if it is o.k. to overwrite it
	if(((s.scanMode != kLiveMode) &&(s.overWriteWarn == 1)) &&(DataFolderExists("root:twoP_Scans:" + s.NewScanName)))// user wants to be warned about possible overwriting of waves
		string alertstr = ""
		DO
			alertStr = "A scan with the name \"" + s.newScanName + "\" already exists. Overwrite it?  Click \"yes\" to overwrite old scan, \"no\" to increment new wave name, or \"cancel\" to cancel scanning."
			doalert 2, alertstr
			if(V_Flag == 2)		// no was clicked, so increment the wavename
				s.newScanName = twoP_ScanNameInc(s.newScanName, 1)
			elseif(V_Flag == 3) // cancel scanning was clicked
				return 1
			endif
			// keep incrementing while No overwriting selected AND the wave exists
		WHILE((dataFolderExists("root:twoP_Scans:" + s.NewScanName)) &&(V_Flag ==2))
		SVAR newScanName = root:packages:twoP:Acquire:newScanName
		newScanName = s.NewScanName
	endif
	return 0
end

//******************************************************************************************************
// returns a formatted string containing useful information about the scan to be made
// Some variables are used in calculations, and need to be accessed later, some are just for maintaining
// a record of settings for the user. The latter can be printed with easier to read but harder to parse %W formatting
// Last Modified 2025/08/08 by Jamie Boyd
Function/S twoP_ScanNoter(s)
	STRUCT twoP_ScanStruct &s
	
	string noteStr = ""
	string tempStr // used for printf and other things
	if(s.scanMode != kLiveMode)
		// Experiment note - sanitize by removing reserved characters
		tempStr = s.scanNote
		variable iChar, nChars = strlen(tempStr)
		For(iChar = 0; iChar < nChars; iChar +=1)
			if (char2num(tempStr [iChar]) == 58)
				tempStr [iChar, iChar]= "="
			elseif(char2num(tempStr [iChar]) == 13)
				tempStr [iChar, iChar]= ";"
			endif
		endfor
		
		NoteStr += "ExpNote:" + tempStr + "\r"
	endif
	// Scan Type - easier for user to read than the scan mode numeric code
	variable scanMode = s.scanMode
	switch(scanMode)
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
	NoteStr += "Mode:" + num2str(s.scanMode) + "\r"
	// Time, in Igor Format, when the scan was started, i.e., now. This value will have to be updated for triggered or for multi-mode
	sprintf tempStr, "ExpTime:%.0f\r",  datetime	// use sprintf to keep enough precision
	NoteStr +=  tempStr
	// image specific stuff
	// image channels, bitwise, 1 for ch1, 2 for ch2, 3 for both channels
	variable imChans=0
	if(scanMode == kEphysOnly)
		NoteStr += "ImChans:0\r"
		// channel descriptions, for forwards compatibility
		NoteStr += "imChanDesc:\r"
	else
		if(WhichListItem("ch1", s.OnlyChansImage,",", 0,0) > -1)
			imChans += 1
		endif
		if(WhichListItem("ch2", s.OnlyChansImage,",", 0,0) > -1)
			imChans += 2
		endif
		NoteStr += "ImChans:" + num2str(imChans) + "\r"
		// channel descriptions, for forwards compatibility
		NoteStr += "imChanDesc:" + s.OnlyChansImage + "\r"
		// image channel descriptions
		// Image size and Pixel scaling
		sprintf tempStr, "Xoffset:%.8f\r", s.xScalStart 
		noteStr += tempStr
		sprintf tempStr, "Yoffset:%.8f\r", s.yScalStart 
		noteStr += tempStr
		noteStr += "PixWidth:" + num2str(s.pixWidth) + "\r"
		noteStr += "XpixSize:" + num2str(s.xPixSize) + "\r"
		noteStr += "PixHeight:" + num2str(s.pixHeight) + "\r"
		noteStr += "YpixSize:" + num2str(s.yPixSize) + "\r"
		noteStr += "NumFrames:" + num2str(s.numFrames) + "\r"
		// z stacks 
		if(scanMode == kZseries)
			noteStr += "Zavg:" + num2str(s.NumZseriesAvg) + "\r"
			noteStr += "ZstepSize:" + num2str(s.zStepSize) + "\r"
		endif
		// Frame Time and line time
		sprintf tempStr, "FrameTime:%.6f\r",s.FrameTime
		noteStr += tempStr
		sprintf tempStr, "LineTime:%.6f\r", s.LineTime
		noteStr +=  tempStr
		// DutyCycle and flyback mode, and flyback proportion, for non-symetric scans
		NoteStr += "DutyCycle:" + num2str(s.DutyCycle) + "\r"
		NoteStr += "FlyBackMode:" + num2str(s.flybackMode) + "\r"
		if(s.flybackMode == 0)
			noteStr += "FlybackProp:" + num2str(s.flybackProp) + "\r"
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
		if(scanMode == kLineScan)
			sprintf tempStr, "YLSV:%.8f\r", s.YSV 
			noteStr += tempStr
			if((cmpstr(s.LSLinkWave, "Don't Link")) == 0)
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
	noteStr += "Xpos:" + num2str(s.xPos) + "\r"
	noteStr += "Ypos:" + num2str(s.yPos) + "\r"
	noteStr += "Zpos:" + num2str(s.zPos) + "\r"
	// was ePhys also collected?
	if((s.scanMode==kTimeSeries) ||(s.ScanMode==kLineScan) ||(s.ScanMode==kEphysOnly))
		variable ePhysChans=0
		if(WhichListItem("ep1", s.onlyChansEphys,",", 0,0) > -1)
			ephysChans += 1
		endif
		if(WhichListItem("ep2", s.onlyChansEphys,",", 0,0) > -1)
			ePhysChans += 2
		endif
		notestr += "ephys:" + num2str(ePhysChans) + "\r"
		NoteStr += "ePhysChanDesc:" + s.onlyChansEphys + "\r"
		NoteStr += "ePhysFreq:" + num2str(s.ePhysFreq) + "\r"
	// Need to add extra info for ePhys?
	endif
	// info about multiple acquisitions
	if (s.isMulti)
		noteStr += "isMultiAq:" + num2str (s.MultiAqiAq + 1) + "\r"
	else
		noteStr += "isMultiAq:0\r"
	endif
	return noteStr
end


//*************************************** twoP_ScanMakeGalvoWaves ***************************************************************
// Makes the X and Y scan waves output to the Galvos by the Analog out channels on the image board for the various scan types
//  returns 1 if an error ocurred, else 0
// Last Modified 2026/08/14 by Jamie Boyd
Function twoP_ScanMakeGalvoWaves(s)
	STRUCT twoP_ScanStruct &s
	
	try
		// Check input for errors
		// scan mode can not be ePhysOnly
		AbortOnValue (s.ScanMode == kEphysOnly), 0
		// PixWidth needs to greater than 2
		AbortOnValue (s.pixWidth < 2), 1
		//PixHeight needs to be 2 or more, unless linescan
		if(s.scanMode == kLineScan)
			AbortOnValue (s.pixHeight < 2), 2
		endif
		//PixHeight needs to be even for turbo mode
		if(s.flybackMode == 1)
			AbortOnValue (mod(s.PixHeight, 2) != 0), 3
		endif
		//dutyCycle needs to be between 0 and 1
		AbortOnValue ((s.dutyCycle < 0) ||(s.dutyCycle > 1)), 4
		//Pixel Time needs to be greater than 1/analog out max frequency (2.5 MHz for S-series boards) , probably a generous maximum is .01 sec
		AbortOnValue ((s.pixTime < 0.4e-06) ||(s.pixTime > 0.1)), 5
		
		WAVE StraightLine =  root:Packages:twoP:acquire:StraightLine	// straight line over portion we want to scan
		WAVE tempCos = root:packages:twoP:acquire:tempCos				// the constrained cosine wave
		WAVE Scan_coefs =  root:packages:twoP:acquire:Scan_Coefs 		//Coeficient wave for cosine curve fitting, will hold the fitted values
		// calculate point numbers
		variable scanPnts = round(s.Pixwidth/s.DutyCycle)	// 50 number of points in data collection half, including turnaround
		variable turnAroundPts = scanPnts - s.Pixwidth		// 10 when the laser is reversing direction, not collecting data
		variable FlyBackPnts =  round(scanPnts * s.FlyBackProp)	// the non-collecting data direction of laser wave, including turnarond
		
		variable cyclePnts 	// full number of points in the hozizontal cycle 2x scan points for bideirectional. scanPnts + turnAroundPts for non-bidirectional
		variable VerCyclePoints
		variable ScanPnts_total // total number of points in wave.  scanPnts * s.PixHeight for biderectional, cyclePnts * s.PixHeight for non-biderectional
		variable galvoRadians = (pi/(scanPnts*s.pixtime)) * s.ScanHeadDelay // translate scan head delay in seconds into radians
		
		// make straight line over data collection portion of scan, in voltage versus radians
		// fitting the cosine from -pi to 0, but the straight line does not include the turnaround portions at the ends
		variable dataXstart = -pi + ((pi* (1-s.DutyCycle))/2) // start of linear scan motion where we collect data
		variable dataXend = 0 - ((pi* (1-s.DutyCycle))/2)
		variable slope =(s.xev-s.xsv)/(dataXend-dataxStart)
		variable intercept = s.xsv - slope * dataxStart
		redimension/n=(s.PixWidth) StraightLine
		SetScale /I x (dataXStart),(dataXend),"rad", StraightLine
		StraightLine =  slope * x + intercept
		// bidirectional scanning
		if(s.flybackMode)
			cyclePnts = 2*scanpnts
			redimension/n=(cyclePnts) tempCos
			// fit Cosine wave with constraints
			Scan_coefs [0] = -(s.XEV - s.XSV)/2		// starting amplitude of H1. Setting it will make curve fitting faster
			Scan_coefs [3] =(s.XEV + s.XSV)/2		// offset. Setting it will make curve fitting faster
			FuncFit/Q/H="0000"/w=2 twoP_ScanCosExpansion Scan_coefs StraightLine
			// setscale so galvo starts on data collection part of scan, plus galvo radians
			Setscale x dataXstart + galvoRadians, dataXend + pi + pi* (1-s.DutyCycle) + galvoRadians, tempCos
			tempCos = twoP_ScanCosExpansion(Scan_coefs,x)
		else // not biderectional
			// Our cosine section is not symetrical around 0, we do each side separately
			cyclePnts = scanpnts + FlyBackPnts
			redimension/n=(cyclePnts) tempCos
			// fit Cosine wave with constraints
			Scan_coefs [0] = -(s.XEV - s.XSV)/2		// starting amplitude of H1. Setting it will make curve fitting faster
			Scan_coefs [3] =(s.XEV + s.XSV)/2		// offset. Setting it will make curve fitting faster
			FuncFit/Q/H="0000"/w=2 twoP_ScanCosExpansion Scan_coefs StraightLine
			// range is NOT -pi to pi, the positive side is scrunched by flyback proportion
			Setscale/I x -pi , (pi*s.flybackProp), "rad", tempCos
			tempCos [0,scanPnts-1]  = twoP_ScanCosExpansion(Scan_coefs,x)
			//the flyback side is done with a regular cosine wave
			// we get vertical scaling and offset from the data collection side
			variable gMin = tempCos[0]
			variable gMax= tempCos [scanPnts-1]
			variable scal =(gMax-gMin)/2
			variable Voffset =(gMax + gMin)/2
			// we divide the x position in the equation by flybackProp
			tempCos [scanPnts, numpnts (tempCos)-1] = cos(x/s.flybackProp) *scal + Voffset
			// rotate wave to data start plus galvo delay
			variable rotateRadians = - galvoRadians - ((pi* (1-s.DutyCycle))/2)
			variable PntsPerRadian = cyclePnts/(pi + (pi*s.flybackProp))
			rotate round(rotateRadians*PntsPerRadian) , tempCos
		endif
		// copy cosine segment into horizontal wave as many times as is needed
		if(s.scanMode == kLineScan)	// Line Scan, only one copy needed. and no vetical wave
			duplicate/o tempCos root:packages:twoP:acquire:HorWave
			WAVE HorWave = root:packages:twoP:acquire:HorWave
			SetScale/p x 0,(s.pixtime) ,"", HorWave		// pix time sets analog out clock, which controls ai and line gate clock
		else //Image
			variable verTurnAroundPts
			if(s.flybackMode)
				VerCyclePoints = scanPnts
				verTurnAroundPts =  turnAroundPts
			else
				VerCyclePoints = scanPnts + flybackPnts
				verTurnAroundPts = flybackPnts + turnAroundPts
			endif
			ScanPnts_total = VerCyclePoints * s.PixHeight
			make/o/n=(Scanpnts_total) root:packages:twoP:acquire:HorWave
			WAVE HorWave = root:packages:twoP:acquire:HorWave
			SetScale/p x 0,(s.pixtime) ,"", HorWave		// pix time sets analog out clock, which controls ai and line gate clock
			HorWave = tempCos [mod(p,(cyclePnts))]
			
			// make vertical wave
			make/o/n =(Scanpnts_total) root:packages:twoP:acquire:VerWave
			WAVE VerWave = root:packages:twoP:acquire:VerWave
			verwave=0
			SetScale/p x 0,(s.pixtime) ,"", verWave
			// make vertical flyback
			if(s.flybackMode)
				verTurnAroundPts = turnAroundPts
				VerCyclePoints = scanPnts
			else
				verTurnAroundPts = flybackPnts + turnAroundPts
				VerCyclePoints = scanPnts + flybackPnts
			endif
			// re-use tempcos for vertical flyback
			redimension/n=(verTurnAroundPts) tempCos
			setscale/I x 0, pi, "rad", tempCos
			scal = (s.yev - s.ysv)/2
			Voffset =(s.yev + s.ysv)/2
			tempCos = cos(x)*scal + Voffset
			// copy tempCos to last points of verWave
			variable startCopy =(Scanpnts_total -verTurnAroundPts)
			VerWave[(Scanpnts_total - verTurnAroundPts), Scanpnts_total-1]= tempCos [p-(Scanpnts_total - verTurnAroundPts)]
			// first data collection pixWidth at starting Voltage, starting level is held for fewer points
			variable voltOut = s.YSV
			VerWave [0, s.pixWidth -1]= voltOut
			variable voltDiv =(s.YEV - s.YSV)/(s.PixHeight-1)  // calculate voltage step size
			// fill in subsequent levels
			variable iPnt
			for(voltOut += voltDiv, iPnt = s.pixWidth ; voltOut < s.YEV ; voltOut += voltDiv, iPnt += VerCyclePoints)
				VerWave [iPnt, iPnt + VerCyclePoints-1]=voltOut
			endfor
		endif
	catch
		switch(V_abortCode)
			case 0:
				print "twoP_ScanMakeGalvoWaves Error: electrophysiology-only scan."
				break
			case 1:
				print "twoP_ScanMakeGalvoWaves Error: PixWidth needs to be 2 or greater."
				break
			case 2:
				print "twoP_ScanMakeGalvoWaves Error: PixHeight needs to be 2 or greater."
				break
			case 3:
				print "twoP_ScanMakeGalvoWaves Error: PixHeight needs to be even for turbo mode."
				break
			case 4:
				print "twoP_ScanMakeGalvoWaves Error: DutyCycle needs to be between 0 and 1."
				break
			case 5:
				print "twoP_ScanMakeGalvoWaves Error: PixTime needs to be between 1 microsecond and 100 milliseconds."
				break
		endswitch
	return V_abortCOde
	endtry
	return 0
end	
			

//******************************************************************************************************
// Fitting function used to make the horizontal scanwave out of a series of cosine components, with phase offset
// Last Modified 2026/08/14 by Jamie Boyd
Function twoP_ScanCosExpansion(w,x) : FitFunc
	Wave w
	Variable x

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(x) = H1 *(cos(x+ph)) + H3 *(cos(3 *(x+ph))) + H5 *(cos(5 *(x+ph))) + offset
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 5
	//CurveFitDialog/ w[0] = H1
	//CurveFitDialog/ w[1] = H3
	//CurveFitDialog/ w[2] = H5
	//CurveFitDialog/ w[3] = offset
	return w[0] *(cos(x)) + w[1] *(cos(3 *( x))) + w[2] *(cos(5 *(x))) + w[3]
End

////******************************************************************************************************
//// Fitting function used to make the horizontal scanwave out of a series of cosine components, with phase offset
//// Last Modified 2025/08/19 by Jamie Boyd
//Function twoP_ScanCosExpansionPh(w,x) : FitFunc
//	Wave w
//	Variable x
//
//	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
//	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
//	//CurveFitDialog/ Equation:
//	//CurveFitDialog/ f(x) = H1 *(cos(x+ph)) + H3 *(cos(3 *(x+ph))) + H5 *(cos(5 *(x+ph))) + offset
//	//CurveFitDialog/ End of Equation
//	//CurveFitDialog/ Independent Variables 1
//	//CurveFitDialog/ x
//	//CurveFitDialog/ Coefficients 5
//	//CurveFitDialog/ w[0] = H1
//	//CurveFitDialog/ w[1] = H3
//	//CurveFitDialog/ w[2] = H5
//	//CurveFitDialog/ w[3] = offset
//	//CurveFitDialog/ w[4] = phase rotation, in radians
//	return w[0] *(cos(x+w[4])) + w[1] *(cos(3 *( x + w[4]))) + w[2] *(cos(5 *(x+w[4]))) + w[3]
//End
//
//
////******************************************************************************************************
//// Makes the X and Y scan waves output to the Galvos by the Analog out channels on the image board for the various scan types
////  returns 1 if an error ocurred, else 0
//// Last Modified 2025/08/25 by Jamie Boyd
//Function twoP_ScanMakeGalvoWaves(s)
//	STRUCT twoP_ScanStruct &s
//
//	variable anError
//	try
//		// Check input for errors
//		// scan mode can not be ePhysOnly - not an error, just exit
//		if(s.ScanMode == kEphysOnly)
//			return 0
//		endif
//		// PixWidth needs to greater than 2
//		anError =(s.pixWidth < 2)
//		AbortOnValue anError, 2
//		//PixHeight needs to be 2 or more, but is not used for linescan
//		if(s.scanMode == kLineScan)
//			anError =(s.pixHeight < 2)
//			AbortOnValue anError, 3
//		endif
//		//PixHeight needs to be even for turbo mode
//		if(s.flybackMode == 1)
//			anError =(mod(s.PixHeight, 2) != 0)
//			AbortOnValue anError, 4
//		endif
//		//dutyCycle needs to be between 0 and 1
//		anError =((s.dutyCycle < 0) ||(s.dutyCycle > 1))
//		AbortOnValue anError, 5
//		//Pixel Time needs to be greater than 1/analog out max frequency(2.5 MHz for S-series boards) , probably a generous maximum is .01 sec
//		anError =((s.pixTime < 0.4e-06) ||(s.pixTime > 0.1))
//		AbortOnValue anError, 7
//		// Make Horizontal wave by fitting a cosine function to data collection region and 1/2 the turnaround
//		// values for fitting curve
//		variable scanpnts = round(s.Pixwidth/s.DutyCycle)						// the collecting data direction of laser wave, with turnaraound
//		variable turnAroundPts = scanpnts-s.Pixwidth							// when the laser is reversing directtion, not collecting data
//		variable FBpnts =  round(s.Pixwidth*s.FlyBackProp/s.DutyCycle)			// for not-bidirectional,the non-collecting data direction of laser wave, with turnarond
//		// fit a cosine function for turnaround and data collection region
//		// cosine function goes from 0 to 1 to 0 over the range -pi/2 to pi/2
//		// for biderectional scanning, both sides will be linearized, starting from 0 on the left side, ending at 0 on the right side
//		// make a straight line to constrain cosine fit to be linear over the scanning region where we collect data
//		// straight line segment x range is based on duty cycle, y range is based on start and end voltages for linear range of scanning
//		variable line_x1=(pi/2) -(pi* s.DutyCycle)/2
//		variable line_x2 =(pi/2) +(pi* s.DutyCycle)/2
//		// formula for line, in voltage versus radians
//		variable slope =(s.xev-s.xsv)/(line_x2-line_x1)
//		variable intercept = s.xsv - slope * line_x1
//		make/o/n =(s.PixWidth) root:Packages:twoP:acquire:StraightLine
//		WAVE StraightLine =  root:Packages:twoP:acquire:StraightLine
//		SetScale /I x(line_x1),(line_x2),"", StraightLine
//		StraightLine =  slope * x + intercept
//		// fit sin wave with constraints
//		WAVE Scan_coefs =  root:packages:twoP:acquire:Scan_Coefs 	//Coeficient wave for Sine curve fitting will hold the fitted values
//		variable cyclePnts											// points in a full cycle of X galvo movement
//		variable ScanPnts_total										// total number of points in X-galvo and Y-galvo waves, for a whole frame
//		variable cos_start											// starting position, in radians, of cosine segment
//		variable cos_End											// ending  position, in radians, of cosine segment
//		variable verTurnAroundPts									// points for vertical turnaround
//		if(s.flybackMode)
//			// if bi-directional, both sides of the cosine segment are linearized
//			cyclePnts = 2*scanPnts
//			ScanPnts_total = scanPnts * s.PixHeight
//			make/o/n=(cyclePnts) root:packages:twoP:acquire:tempCos	// scanPnts includes turnaround points plus linearized points
//			WAVE tempCos = root:packages:twoP:acquire:tempCos			
//			cos_start =(- pi*((1-s.dutyCycle)/2))						// starts the cosine section at start of turnaround
//			setscale/p x cos_start,(pi/scanPnts), "rad", tempCos
//			// translate scan head delay in seconds into radians
//			variable galvoRadians =((pi/((s.pixWidth*s.pixTime)/s.dutyCycle)) * s.ScanHeadDelay)
//			Scan_coefs [0] = -(s.XEV - s.XSV)/2		// starting amplitude of H1. Setting it will make curve fitting faster
//			Scan_coefs [3] =(s.XEV + s.XSV)/2		// offset. Setting it will make curve fitting faster
//			Scan_Coefs [4] =0						// fit with phase held to 0, then add phase 
//			FuncFit/Q/H="00001"/w=2 twoP_ScanCosExpansionPh Scan_coefs StraightLine
//			Scan_Coefs [4] = GalvoRadians			// add the phase for galvo rotation to fitting coeficients
//			tempCos = twoP_ScanCosExpansionPh(Scan_coefs,x)
//		else
//			// not bi-directional, just one side is linearized, other side may have a steeper slope
//			// Our cosine section is not symetrical around 0, we do each side separately
//			cyclePnts = scanpnts + FBpnts
//			ScanPnts_total = cyclePnts * s.PixHeight
//			make/o/n=(cyclePnts) root:packages:twoP:acquire:tempCos
//			WAVE tempCos = root:packages:twoP:acquire:tempCos
//			// we want to end at pi to fit the linear stage 
//			cos_End = pi
//			cos_Start = pi-(scanpnts + FBpnts)*(pi/scanpnts)
//			setscale x cos_Start, cos_End, "rad", tempCos
//			Scan_coefs [0] = -(s.XEV - s.XSV)/2		// starting amplitude of H1. Setting it will make curve fitting faster
//			Scan_coefs [3] =(s.XEV + s.XSV)/2		// offset. Setting it will make curve fitting faster
//			Scan_Coefs [4] =0						// fit with phase held to 0, we add phase with rotation
//			FuncFit/Q/H="00001"/w=2 twoP_ScanCosExpansionPh Scan_coefs StraightLine
//			tempCos = twoP_ScanCosExpansionPh(Scan_coefs,x)
//			// now the un-linearized flyback side - get min from tempCos(0) and max from tempCos(pi)
//			variable gMin = tempCos [scanpnts + FBpnts -1]		// point position of 0
//			variable gMax= tempCos [FBpnts]					// point position of pi
//			variable scal =(gMax-gMin)/2
//			variable offset =(gMax + gMin)/2
//			tempCos[0, FBpnts-1] = cos(x/s.flybackProp) *scal + offset
//			rotate round((turnAroundPts/2) -(s.ScanHeadDelay/s.pixTime)),tempCos // translate scan head delay in seconds into pixels and include
//		endif
//		// copy cosine segment into horizontal wave as many times as is needed
//		if(s.scanMode == kLineScan)	// Line Scan, only one copy needed
//			make/o/n=(cyclePnts) root:packages:twoP:acquire:HorWave
//			WAVE HorWave = root:packages:twoP:acquire:HorWave
//			horwave = tempCos
//		else //Image
//			make/o/n=(Scanpnts_total) root:packages:twoP:acquire:HorWave
//			WAVE HorWave = root:packages:twoP:acquire:HorWave
//			HorWave = tempCos [mod(p,(cyclePnts))]
//		endif
//		SetScale/p x 0,(s.pixtime) ,"", HorWave		// pix time sets analog out clock, which controls ai and line gate clock
//		// Vertical wave not neded for line scan
//		if(s.scanMode != kLineScan)
//			// Make vertical wave, it starts with vertical flyback
//			make/o/n =(Scanpnts_total) root:packages:twoP:acquire:VerWave
//			WAVE VerWave = root:packages:twoP:acquire:VerWave
//			SetScale/p x 0,(s.pixtime) ,"", verWave
//			// do the vertical flyback in one horizontal flyback and turnaround(uni-directional) or one turnaround(bi-directional)
//			if(s.flybackMode)
//				verTurnAroundPts = turnAroundPts
//				cyclePnts = scanPnts
//			else
//				verTurnAroundPts = fbPnts + turnAroundPts
//				cyclePnts = scanPnts + fbPnts
//			endif
//			variable voltOut, voltDiv =(s.YEV - s.YSV)/(s.PixHeight-1)
//			variable iPnt
//			scal = -(s.yev - s.ysv)/2
//			offset =(s.yev + s.ysv)/2
//			VerWave=NaN
//			// re-use tempcos for vertical flyback
//			redimension/n=(verTurnAroundPts) tempCos
//			setscale/I x -pi, 0, "rad", tempCos
//			tempCos = cos(x)*scal + offset
//			// copy tempCos to first points of verWave
//			VerWave[0, verTurnAroundPts-1]=tempCos
//			// finish first cycle with pixWidth, then  do cycle at a time
//			VerWave[verTurnAroundPts,verTurnAroundPts + s.pixWidth-1]=s.YSV
//			for(iPnt = verTurnAroundPts + s.pixWidth, voltOut = s.YSV + voltDiv ; iPnt < Scanpnts_total-verTurnAroundPts ; iPnt += cyclePnts,voltOut += voltDiv)
//				VerWave [iPnt, iPnt + cyclePnts -1]=voltOut
//			endfor
//			SetScale/p x 0,(s.pixtime) ,"", verWave
//		endif
//	catch
//		switch(V_abortCode)
//			case 1:
//				print "twoP_ScanMakeGalvoWaves Error: electrophysiology-only scan."
//				break
//			case 2:
//				print "twoP_ScanMakeGalvoWaves Error: PixWidth needs to be 2 or greater."
//				break
//			case 3:
//				print "twoP_ScanMakeGalvoWaves Error: PixHeight needs to be 2 or greater."
//				break
//			case 4:
//				print "twoP_ScanMakeGalvoWaves Error: PixHeight needs to be even for turbo mode."
//				break
//			case 5:
//				print "twoP_ScanMakeGalvoWaves Error: DutyCycle needs to be between 0 and 1."
//				break
//			case 7:
//				print "twoP_ScanMakeGalvoWaves Error: PixTime needs to be between 1 microsecond and 100 milliseconds."
//				break
//			case 9:
//				print "twoP_ScanMakeGalvoWaves Error: Curve fitting for the sine expansion did not converge properly."
//				make/o/D root:packages:twoP:acquire:Scan_Coefs = {-7.4, -0.65, -0.13, -0.015}
//				break
//			case 8:
//				print "twoP_ScanMakeGalvoWaves Error: Curve fitting for the sine expansion for bi-directional scanning did not converge properly."
//				make/o/D root:packages:twoP:acquire:Scan_Coefs_Sym = {-7.4, -0.65, -0.13, 0.08, 0.17}
//				break
//		endswitch
//		return 1 //failure
//	endtry
//	return 0  //successs
//end
//

//******************************************************************************************************
// Makes the image waves and ePhys Waves for scanning in a new folder, for all the different scan modes
// Last Modified 2026/07/30 by Jamie Boyd
Function twoP_ScanMakeScanWaves(s)
	STRUCT twoP_ScanStruct &s
	
	// make a folder for this scan it may already exist so use /O
	newDataFolder/O $"root:twoP_Scans:" +  s.newScanName
	string baseName = "root:twoP_Scans:" + s.newScanName +":" +  s.newScanName + "_"
	//for imaging
	string ai_chanName, chanName
	variable iChan, nChans
	if (s.scanMode == kePhysOnly)
		nChans=0
	else
		nChans = itemsInList(s.selImageChanList)
	endif
	// for ephys
	variable Enchans = itemsInList (s.selePhysChanList, ";")
	variable ePnts
	if (Enchans > 0)
		ePnts = ceil(s.Runtime * s.EphysFreq)
	endif
	// make a ScanWave for each image channel
	for(iChan=0; iChan < nChans; iChan +=1)
		ai_chanName = stringFromList(iChan, s.selImageChanList,";")
		chanName = stringFromList(0, ai_chanName, ":")
		WAVE/Z scanWave= $baseName + chanName
		Switch(s.Scanmode)
			case kLiveMode:
				// ScanWave is the 2D wave we display - it lives in a regular twoPScans folder named LiveScan and is treated like a regular scan
				// we don't acquire directly into this wave,just copy data into it from 1D acq wave
				if (waveExists(scanWave))
					if (!((dimsize(scanWave, 0) == s.PixWidth) && (dimsize(scanWave, 1) == s.PixHeight)))
						redimension/w/u/n =((s.PixWidth),(s.PixHeight)) scanWave
					endif
				else
					make/w/u/n =((s.PixWidth),(s.PixHeight)) $baseName + chanName
					WAVE/Z scanWave= $baseName + chanName
					if (!(WaveExists (scanWave)))
						return 1
					endif
				endif
				SetScale/P x s.xScalStart, s.XPixSize, "m", scanWave
				SetScale/P Y s.yScalStart, s.YPixSize, "m", scanWave
				fastop scanWave =0
				break
				
			case kSingleImage:
				if(waveExists(scanWave))
					if (!((dimsize(scanWave, 0) == s.PixWidth) && (dimsize(scanWave, 1) == s.PixHeight)))
						redimension/n =((s.PixWidth),(s.PixHeight)) scanWave
					endif
				else
					make/w/u/n =((s.PixWidth),(s.PixHeight)) $baseName + chanName
					WAVE/Z scanWave= $baseName + chanName
					if (!(WaveExists (scanWave)))
						return 1
					endif
				endif
				SetScale/P x s.xScalStart, s.XPixSize, "m", scanWave
				SetScale/P Y s.yScalStart, s.YPixSize, "m", scanWave
				fastop scanWave =0
				break
			
			case kLineScan:
				if(waveExists(scanWave))
					redimension/w/u/n =(s.PixWidth, s.PixHeight) scanWave
				else
					make/w/u/n =(s.PixWidth, s.PixHeight) $baseName + chanName
					WAVE/Z scanWave= $baseName + chanName
					if (!(WaveExists (scanWave)))
						return 1
					endif
				endif
				SetScale/P x(s.xScalStart),(s.XPixSize), "m", scanWave
				SetScale/P Y 0,(s.lineTime), "s", scanWave
				fastop scanWave =0
				break
				
			case kTimeSeries:
				if (waveExists(scanWave))
					if (!((dimsize (scanWave, 0) == s.PixWidth)   && (dimsize (scanWave, 1) == s.PixHeight) && (dimsize (scanWave, 2) ==  s.numFrames)))
						redimension/w/u/n =(s.PixWidth,  s.PixHeight, s.numFrames) scanWave
					endif
				else
					make/w/u/n =(s.PixWidth,  s.PixHeight, s.numFrames) $baseName + chanName
					WAVE/Z scanWave= $baseName + chanName
					if (!(WaveExists (scanWave)))
						return 1
					endif
					SetScale/P x s.xScalStart, s.XPixSize, "m", scanWave
					SetScale/P y s.yScalStart, s.YPixSize, "m", scanWave
					SetScale/P z 0, s.frameTime, "s", scanWave
				endif
				fastop scanWave =0
				break
			
			case kZseries:
				if(waveExists(scanWave))
					redimension/w/u/n =((s.PixWidth),(s.PixHeight),(s.numFrames)) scanWave
				else
					make/w/u/n =((s.PixWidth),(s.PixHeight),(s.numFrames)) $baseName + chanName
					WAVE/Z scanWave= $baseName + chanName
					if (!(WaveExists (scanWave)))
						return 1
					endif
				endif
				SetScale/P X s.xScalStart, s.XPixSize, "m", scanWave
				SetScale/P Y s.yScalStart, s.YPixSize, "m", scanWave
				Setscale/P Z s.zPos, s.zStepSize, "m", scanWave
				fastop scanWave =0
				break
		endswitch
	endfor
	//now for Ephys
	for(iChan=0; iChan < EnChans; iChan +=1)
		ai_chanName = stringFromList(iChan, s.selePhysChanList,";")
		chanName = stringFromList(0, ai_chanName, ":")
		WAVE/Z scanWave= $baseName + chanName
		if(waveExists(scanWave))
			redimension/s/n =(ePnts) scanWave
		else
			make/s/n =(ePnts) $baseName + chanName
			WAVE/Z scanWave= $baseName + chanName
			if (!(WaveExists (scanWave)))
				return 1
			endif
		endif
		SetScale/P x 0,(1/s.EphysFreq), "s", scanWave
		SetScale d, 0, 0, "V", scanWave
		fastop scanWave =0
	endfor
	return 0
end


//*********************************** twoP_ScanDoScanControls *******************************************************************
// updates panel control to show scan is starting. Called by start button
// twoP_ScanPopMenuProc opens the scanGraph, making the scanGraphWaves needed by the threads, 
// so run this before making threadData with twoP_ScanMakeHelperWaves
// Last Modified 2026/08/01 by Jamie
function twoP_ScanDoScanControls(s)
	STRUCT twoP_ScanStruct &s

	// Select our new scan as current scan, with selected channels on scanGraph to match channels being acquired
	if(s.scanMode != kephysOnly)
		SVAR selChans = root:packages:twoP:examine:scanGraphSelChans
		selChans=s.onlyChansImage
	endif
	STRUCT WMPopupAction pa
	pa.eventCode = 2
	pa.popStr = s.NewScanName
	twoP_ScanPopMenuProc(pa)
	// change start button status
	NVAR StopOrAbort = root:Packages:twoP:Acquire:ScanStopOrAbort
	StopOrAbort = 0
	Button AqStartButton, win = twoP_Controls, proc= twoP_ScanAbortProc
	if(s.scanMode== kLiveMode)
		Button AqStartButton, win = twoP_Controls, fColor=(65280,0,0), title = "Stop"
	else
		if(s.inPutTrigger)
			Button AqStartButton, win = twoP_Controls, fColor=(65280,65280,0), title = "Abort"
			DoUpdate/E=1 /W=twoP_Controls	// mark control panel as a progress window, able to get mouse clicks/button presses
		else
			Button AqStartButton, win = twoP_Controls, fColor=(65280,0,0), title = "Abort"
		endif
	endif
	// change setvariable mode to Candy-stripe effect indefinite-style progress bar for live scan
	if (s.scanMode == kLiveMode)
		ValDisplay AqPercentCompleteDisplay win= twoP_Controls, mode=4, value= _NUM:0
	else
		ValDisplay AqPercentCompleteDisplay win= twoP_Controls,  mode=3, value=#"root:packages:twoP:Acquire:PercentComplete"
	endif
end


//******************************************************************************************************
// Makes ancillary waves for scanning, the things that are not the actual data but are used for scanning and displaying
// also adds the paths for scanning to the scan struct
// and puts references to the waves into the thread waves
// needs to run AFTER making the Scan Waves
// Last Modified 2026/08/13 by Jamie Boyd
Function twoP_ScanMakeHelperWaves(s)
	STRUCT twoP_ScanStruct &s
	
	variable nChans = itemsInList(s.selImageChanList)
	// make or resize wave references for thread data according to scan type and options
	variable numThreadWaves, numExtra=0, numPoints
	Switch(s.scanMode)
		case kLiveMode:
			numThreadWaves = 5
			if(s.liveRatio)
				numExtra = 1	// extra wave for live ROI ratio, not done per channel
			endif
			break
			
		case kSingleImage:
			if(s.AvgDoUpdate)
				numThreadWaves = 3
			else
				numThreadWaves = 0
			endif
			break
			
		case kLineScan:
			numThreadWaves = 4
			break
			
		case kTimeSeries:
			numThreadWaves = 5
			if(s.liveRatio)
				numExtra = 1	// extra wave for live ROI ratio, not done per channel
			endif
			break
		
		case kZseries:
			numThreadWaves = 4
			break
	endswitch
	numPoints = numThreadWaves*nChans + numExtra
	WAVE/WAVE/Z threadData = root:packages:twoP:acquire:threadData
	if(WaveExists(threadData))
		redimension/n=(numPoints) threadData
	else
		make/WAVE/n=(numPoints) threadData
		WAVE/WAVE threadData = root:packages:twoP:acquire:threadData
	endif
	
	// calculate points needed for live roi, if needed
	variable lroiPoints, ptScale
	if(s.liveROI)
		if(s.scanMode == kTimeSeries)
			lroiPoints = round(s.liveROISecs/(s.FrameTime * s.TSchunkSize))
			ptScale = -s.FrameTime*s.LSChunkSize
		elseif(s.scanMode == kLiveMode)
			lroiPoints = round(s.liveROISecs/s.FrameTime)
			ptScale = -s.FrameTime
		elseif(s.ScanMode == kLineScan)
			lroiPoints =round(s.liveROISecs/(s.LSChunkSize * s.lineTime))
			ptScale = -s.LSChunkSize * s.lineTime
		endif
		// make live ratio wave
		WAVE/Z LroiWave_ratio =  root:Packages:twoP:acquire:LroiWave_ratio
		if(WaveExists(LroiWave_ratio))
			redimension/n=(lroiPoints) LroiWave_ratio
		else
			make/n=(lroiPoints) root:Packages:twoP:acquire:LroiWave_ratio
			WAVE LroiWave_ratio =  root:Packages:twoP:acquire:LroiWave_ratio
		endif
		setscale /p x 0,(ptScale), "s", LroiWave_ratio
		// add reference to LroiWave_ratio wave to the end of the thread waves
		if(s.liveRatio)
			threadData [numThreadWaves * nChans] = LroiWave_ratio
		endif
	endif
	
	// make/resize temp waves for scanning, done on a per channel basis.
	variable iChan			// iterate through selected channels
	string chanName
	string baseName = "root:twoP_Scans:" + s.newScanName +":" +  s.newScanName + "_"	// everything but channel name
	for(iChan=0; iChan < nChans; iChan +=1)
		chanName = stringFromList(0,  stringFromList(iChan, s.selImageChanList,";"), ":")				// name of the channel
		Switch(s.Scanmode)
			case kLiveMode:
				// 1D wave we aquire into directly, thread data 0
				WAVE/Z Acq1D = $"root:packages:twoP:acquire:Acq1D_" + chanName
				if (s.LiveStackAtOnce) // scanning all frames in the stack-to-average at once
					numPoints = s.PixWidth * s.PixHeight * s.numFrames
				else	// scanning one frame at a time and inserting it the stack-to-average
					numPoints = s.PixWidth * s.PixHeight
				endif
				if(waveExists(acq1D))
					if (!((dimsize (acq1D, 0) == numPoints) && (dimsize (acq1D, 0) == 0)))
						redimension/n=(numPoints) acq1D
					endif
				else
					make/o/w/n=(numPoints) $"root:packages:twoP:acquire:Acq1D_" + chanName
					WAVE/Z Acq1D = $"root:packages:twoP:acquire:Acq1D_" + chanName
					if (!(WaveExists (Acq1D)))
						return 1
					endif
				endif
				setscale/p x 0,(s.pixTime), "s" Acq1D
				fastop Acq1D =0
				threadData[numThreadWaves*iChan] = Acq1D
				
				// 3D wave. we copy linear data into this wave and process it into a 2D frame, thread data 1
				WAVE/Z Acq3D = $"root:packages:twoP:acquire:Acq3D_" + chanName
				if(waveExists(Acq3D))
					if (!((dimsize (Acq3D, 0) == s.PixWidth) && (dimsize (Acq3D, 1) == s.PixHeight) && (dimsize (Acq3D, 2) == s.numFrames)))
						redimension/n=(s.PixWidth, s.PixHeight, s.numFrames) Acq3D
					endif
				else
					make/o/w/u/n=(s.PixWidth, s.PixHeight, s.numFrames) $"root:packages:twoP:acquire:Acq3D_" + chanName
					WAVE/Z Acq3D = $"root:packages:twoP:acquire:Acq3D_" + chanName
					if (!(WaveExists (Acq3D)))
						return 1
					endif
				endif
				fastop Acq3D = 0
				threadData[numThreadWaves*iChan+1] = Acq3D
				
				// The ScanWave, a 2D wave we display on ScanGraph, thread data 2
				// it is already made by twoP_ScanMakeScanWaves, in a folder LiveScan
				WAVE scanWave= $baseName + chanName
				fastop scanWave = 0
				threadData[numThreadWaves*iChan + 2] = scanWave
				
				// HIstogram wave, thread data 3
				if(s.liveHIst)
					WAVE/Z histWave = $"root:Packages:twoP:Examine:HistWave" + chanName
					if(!(WAVEExists(histWave)))
						make/o/n =(2^kNQimageBits) $"root:Packages:twoP:Examine:HistWave" + chanName
						WAVE HistWave = $"root:Packages:twoP:Examine:HistWave" + chanName
						setscale/p x, 0, 1	, "", HistWave
					endif
					threadData[numThreadWaves*iChan + 3] = histWave
				else
					threadData[numThreadWaves*iChan + 3] = $""
				endif
				
				// ROI wave, thread data 4
				if(s.liveROI)
					WAVE/Z LROIWave = $"root:Packages:twoP:acquire:LroiWave_" + chanName
					if(!(WaveExists(LROIWave)))
						make/n=(lroiPoints) $"root:Packages:twoP:acquire:LroiWave_" + chanName
						WAVE LROIWave = $"root:Packages:twoP:acquire:LroiWave_" + chanName
					else
						redimension/n=(lroiPoints) LROIWave
					endif
					SetScale/p x 0,(ptScale), "s", LROIWave
					LROIWave =Nan
					threadData[numThreadWaves*iChan + 4] = LROIWave
					// check if this channel is involved in live ratio
					if(s.liveRatio)
						if(cmpStr(chanName, s.liveRatioTopChan) ==0)
							s.ratioTopChanNum = numThreadWaves*iChan + 4 // number  
						elseif(cmpStr(chanName, s.liveRatioBottomChan) ==0)
							s.ratioBottomChanNum = numThreadWaves*iChan + 4
						endif
					endif
				else
					threadData[numThreadWaves*iChan + 4] = $""
				endif
				break
				
			case kSingleImage:
				// make the 1D wave we acquire directly into
				if (s.AvgDoUpdate)	// doing Kalman averaging between frames
					numPoints = s.PixWidth * s.PixHeight
				else				// doing scan at once - no threads used, all processing done with end of scan hook
					numPoints = s.PixWidth * s.PixHeight * s.numFrames
				endif
				// make the 1D wave that we directly scan into, thread data 0
				WAVE/Z Acq1D = $"root:packages:twoP:acquire:Acq1D_" + chanName
				if(waveExists(acq1D))
					if (!((dimsize (acq1D, 0) == numPoints) && (dimsize (acq1D, 1) ==0)))
						redimension/n=(numPoints) acq1D
					endif
				else
					make/o/w/u/n=(numPoints) $"root:packages:twoP:acquire:Acq1D_" + chanName
					WAVE/Z Acq1D = $"root:packages:twoP:acquire:Acq1D_" + chanName
					if (!(WaveExists (Acq1D)))
						return 1
					endif
				endif
				setscale/p x 0,(s.pixTime), "s" Acq1D
				fastop Acq1D =0
				if (s.AvgDoUpdate)
					threadData[numThreadWaves*iChan] = acq1D
					// make the unsigned 2D image we use for KalmanNext, thread data 1
					WAVE/Z Acq2D = $"root:packages:twoP:acquire:Acq2D_" + chanName
					if(waveExists(acq2D))
						if (!((dimSize(acq2D, 0) == s.PixWidth) && (dimSize(acq2D, 1) == s.PixHeight)))
							redimension/n=(s.PixWidth, s.PixHeight) acq2D
						endif
					else
						make/o/w/u/n=(s.PixWidth, s.PixHeight) $"root:packages:twoP:acquire:Acq2D_" + chanName
						WAVE/Z Acq2D = $"root:packages:twoP:acquire:Acq2D_" + chanName
						if (!(WaveExists (Acq2D)))
						return 1
					endif
					endif
					fastop Acq2D = 0
					threadData[numThreadWaves*iChan + 1] = acq2D
					// 2D scan wave is created by twoP_ScanMakeScanWaves, thread data 2
					WAVE scanWave= $baseName + chanName	// it is already made by twoP_ScanMakeScanWaves
					threadData[numThreadWaves*iChan + 2] = scanWave
				else		// doing scan at once - no threads used, all processing done with end of scan hook
					// make the 3D wave we use for the stack to do Kalman average into ScanWave at end of scan
					WAVE/Z Acq3D = $"root:packages:twoP:acquire:Acq3D_" + chanName
					if(waveExists(Acq3D))
						if (!((dimsize (Acq3D, 0) == s.PixWidth) && (dimsize (Acq3D, 1) == s.PixHeight) && (dimsize (Acq3D, 2) == s.numFrames)))
							redimension/n=(s.PixWidth, s.PixHeight, s.numFrames) Acq3D
						endif
					else
						make/o/w/u/n=(s.PixWidth, s.PixHeight, s.numFrames) $"root:packages:twoP:acquire:Acq3D_" + chanName
						WAVE/Z Acq3D = $"root:packages:twoP:acquire:Acq3D_" + chanName
						if (!(WaveExists (Acq3D)))
							return 1
						endif
					endif
					fastop Acq3D = 0
					// the 2D scan wave is created by twoP_ScanMakeScanWaves, and does not need to be referenced here cause no threads
				endif
				break
			
			case kLineScan:
				// make the 1D wave we acquire into, thread data 0
				// if repeated scan, acq1D is sized for just a small chunk, if all at once acq1D is sized for the whole scan
				variable lScanBuferHeight
				if (s.LSscanAtOnce)
					lScanBuferHeight = s.pixHeight
				else
					lScanBuferHeight = s.LSChunkSize
				endif
				WAVE/Z Acq1D = $"root:packages:twoP:acquire:Acq1D_" + chanName
				if(waveExists(Acq1D))
					if (!((DimSize(Acq1D, 0) == (s.pixWidth * lScanBuferHeight)) && (DimSize(Acq1D, 1) == 0)))
						redimension/n=(s.pixWidth * lScanBuferHeight) Acq1D
					endif
				else
					make/o/w/n=(s.pixWidth * lScanBuferHeight) $"root:packages:twoP:acquire:Acq1D_" + chanName
					WAVE/Z Acq1D = $"root:packages:twoP:acquire:Acq1D_" + chanName
					if (!(WaveExists (Acq1D)))
						return 1
					endif
				endif
				setscale/p x 0, s.pixTime, "s" Acq1D
				fastop Acq1D =0
				threadData[numThreadWaves*iChan] = Acq1D
				// make an unsigned 2D wave for a Chunk to process lines as collected, thread data 1
				// same size used for either repeated scan function (cyclic) or background task (at-once)
				WAVE/Z Acq2D = $"root:packages:twoP:acquire:Acq2D_" + chanName
				if(waveExists(Acq2D))
					if (!((dimsize(Acq2D, 0) == s.pixWidth) && (dimsize(Acq2D, 1) == s.LSChunkSize)))
						redimension/n=(s.pixWidth, s.LSChunkSize) Acq2D
					endif
				else
					make/o/w/u/n=(s.pixWidth, s.LSChunkSize) $"root:packages:twoP:acquire:Acq2D_" + chanName
					WAVE/Z Acq2D = $"root:packages:twoP:acquire:Acq1D_" + chanName
					if (!(WaveExists (Acq2D)))
						return 1
					endif
				endif
				threadData[numThreadWaves*iChan + 1] = acq2D
				
				// The ScanWave, 2D wave we also display on ScanGraph, thread data 2
				// it is already made by twoP_ScanMakeScanWaves
				WAVE scanWave= $baseName + chanName
				threadData[numThreadWaves*iChan + 2] = scanWave
				fastop scanWave = 0
				// ROI wave, used for displaying a live updating ROI, thread data 3
				if(s.liveROI)
					WAVE/Z LROIWave = $"root:Packages:twoP:acquire:LroiWave_" + chanName
					if(WaveExists(LROIWave))
						redimension/n=(lroiPoints) LROIWave
					else
						make/n=(lroiPoints) $"root:Packages:twoP:acquire:LroiWave_" + chanName
						WAVE LROIWave = $"root:Packages:twoP:acquire:LroiWave_" + chanName
					endif
					SetScale/p x 0,(ptScale), "s", LROIWave
					LROIWave = NaN
					threadData[numThreadWaves*iChan + 3] = LROIWave
					// if live ratio, save position of waves for top channel and bottom channel in scan struct for use by threads
					if(s.liveRatio)
						if(cmpStr(chanName, s.liveRatioTopChan) ==0)
							s.ratioTopChanNum = numThreadWaves*iChan + 3
						elseif(cmpStr(chanName, s.liveRatioBottomChan) ==0)
							s.ratioBottomChanNum = numThreadWaves*iChan + 3
						endif
					endif
				else
					threadData[numThreadWaves*iChan + 3] = $""
				endif
				break
				
			case kTimeSeries:
				// make the 1D wave we acquire into, thread data 0
				// if cyclic, acq1D is sized for just a small chunk, if all at one acq1D is sized for the whole scan
				if(s.TSscanAtOnce)
					numPoints = s.PixWidth * s.PixHeight * s.numFrames		// scanning whole stack
				else
					numPoints = s.PixWidth * s.PixHeight * s.TSChunkSize		// scanning chunk at a time
				endif
				WAVE/Z Acq1D = $"root:packages:twoP:acquire:Acq1D_" + chanName
				if(waveExists(Acq1D))
					if (!((DimSize(Acq1D, 0) == numPoints) && (DimSize(Acq1D, 1) == 0)))
						redimension/n=(numPoints) Acq1D
					endif
				else
					make/o/w/n=(numPoints) $"root:packages:twoP:acquire:Acq1D_" + chanName
					WAVE/Z Acq1D = $"root:packages:twoP:acquire:Acq1D_" + chanName
					if (!(WaveExists (Acq1D)))
						return 1
					endif
				endif
				setscale/p x 0, s.pixTime, "s" Acq1D
				fastop Acq1D =0
				threadData[numThreadWaves*iChan] = Acq1D
				// make a 3D wave containing a small chunk of frames to transfer to scanWave
				WAVE/Z Acq3D = $"root:packages:twoP:acquire:Acq3D_" + chanName
				if(waveExists(Acq3D))
					if (!((dimsize(Acq3D, 0) == s.pixWidth) && (dimsize(Acq3D, 1) == s.PixHeight) &&  (dimsize(Acq3D, 2) == s.TSChunkSize)))
						redimension/n=(s.pixWidth, s.PixHeight, s.TSChunkSize) Acq3D
					endif
				else
					make/o/w/u/n=(s.pixWidth, s.PixHeight, s.TSChunkSize) $"root:packages:twoP:acquire:Acq3D_" + chanName
					WAVE/Z Acq3D = $"root:packages:twoP:acquire:Acq3D_" + chanName
					if (!(WaveExists (Acq3D)))
						return 1
					endif
				endif
				threadData[numThreadWaves*iChan + 1] = acq3D
				// the scanWave is already created, thread data 2
				WAVE scanWave= $baseName + chanName
				threadData[numThreadWaves*iChan + 2] = scanWave
				// the 2D scanGraph wave is already created, thread data 3
				WAVE scanGraphChanWave = $"root:packages:twoP:examine:scanGraph_" + chanName
				threadData[numThreadWaves*iChan + 3] = scanGraphChanWave
				fastop scanGraphChanWave = 0
				// ROI wave - pos 4
				if(s.liveROI)
					WAVE/Z LROIWave = $"root:Packages:twoP:acquire:LroiWave_" + chanName
					if(WaveExists(LROIWave))
						redimension/n=(lroiPoints) LROIWave
					else
						make/n=(lroiPoints) $"root:Packages:twoP:acquire:LroiWave_" + chanName
						WAVE LROIWave = $"root:Packages:twoP:acquire:LroiWave_" + chanName
					endif
					SetScale/p x 0,(ptScale), "s", LROIWave
					LROIWave = NaN
					threadData[numThreadWaves*iChan + 4] = LROIWave
					if(s.liveRatio)
						if(cmpStr(chanName, s.liveRatioTopChan) ==0)
							s.ratioTopChanNum = numThreadWaves*iChan + 3
						elseif(cmpStr(chanName, s.liveRatioBottomChan) ==0)
							s.ratioBottomChanNum = numThreadWaves*iChan + 3
						endif
					endif
				else
					threadData[numThreadWaves*iChan + 4] =$""
				endif
				break
		
			case kZseries:
				// make the 1D wave that we directly scan into
				if (s.zAvgStackAtOnce)
					numPoints = s.PixWidth * s.PixHeight * s.NumZseriesAvg
				else
					numPoints = s.PixWidth * s.PixHeight
				endif
				WAVE/Z Acq1D = $"root:packages:twoP:acquire:Acq1D_" + chanName
				if(waveExists(Acq1D))
					if (!((dimSize (Acq1D, 0) == numPoints) && (dimSize (Acq1D, 1) == 0)))
						redimension/n=(numPoints) Acq1D
					endif
				else
					make/o/w/n=(numPoints)  $"root:packages:twoP:acquire:Acq1D_" + chanName
					WAVE/Z Acq1D = $"root:packages:twoP:acquire:Acq1D_" + chanName
					if (!(WaveExists (Acq1D)))
						return 1
					endif
				endif
				setscale/p x 0, s.pixTime, "s" Acq1D
				fastop Acq1D =0
				threadData[numThreadWaves*iChan] = Acq1D
				//make a 3D or 2D wave the same size as Acq1D for kalman averaging
				WAVE/Z Acq3D = $"root:packages:twoP:acquire:Acq3D_" + chanName
				if (s.zAvgStackAtOnce)
					if(waveExists(Acq3D))
						if (!((dimsize(Acq3D, 0) == s.pixWidth) && (dimsize(Acq3D, 1) == s.pixHeight) && (dimsize(Acq3D, 2) == s.NumZseriesAvg)))
							redimension/n=(s.pixWidth, s.pixHeight, s.NumZseriesAvg) Acq3D
						endif
					else
						make/o/w/u/n=(s.pixWidth, s.pixHeight, s.NumZseriesAvg) $"root:packages:twoP:acquire:Acq3D_" + chanName
						WAVE/Z Acq3D = $"root:packages:twoP:acquire:Acq3D_" + chanName
						if (!(WaveExists (Acq3D)))
						return 1
					endif
					endif
					fastop Acq3D =0
					threadData[numThreadWaves*iChan + 1] = Acq3D
				else  // acquiring frame by frame
					WAVE/Z Acq2D = $"root:packages:twoP:acquire:Acq2D_" + chanName
					if(waveExists(Acq2D))
						if (!((dimsize(Acq2D, 0) == s.pixWidth) && (dimsize(Acq2D, 1) == s.pixHeight) && (dimsize(Acq2D, 2) == 0)))
							redimension/n=(s.pixWidth, s.pixHeight) Acq2D
						endif
					else
						make/o/w/u/n=((s.pixWidth),(s.pixHeight)) $"root:packages:twoP:acquire:Acq2D_" + chanName
						WAVE/Z Acq2D = $"root:packages:twoP:acquire:Acq2D_" + chanName
						if (!(WaveExists (Acq2D)))
							return 1
						endif
					endif
					fastop Acq2D =0
					threadData[numThreadWaves*iChan + 1] = Acq2D
				endif
				// scanGraphWave, the 2D wave that is displayed in the scanGraph, is already made
				WAVE scanGraphWave=$"root:packages:twoP:examine:scanGraph_" + chanName
				threadData[numThreadWaves*iChan + 2] = scanGraphWave
				// the scan wave is already made
				WAVE scanWave= $baseName + chanName
				threadData[numThreadWaves*iChan + 3] = scanWave
				break
		endswitch
	endfor
	return 0
end


//******************************************************************************************************
// Makes a new graph for live ROI display. Make sure LROI waves are already made before calling this function
// Last Modified 2025/09/30 by Jamie Boyd 
Function twoP_ScanMakeLROIGraph(s)
	STRUCT twoP_ScanStruct &s
	
	// Kill old lROI graph
	DoWindow/K twoPLROIGraph
	if(s.liveROISecs == 0)
		return 0
	endif
	variable iChan, nChans= itemsInList(s.onlyChansImage, ",")
	string aChan
	string axisStr = ""

	for(ichan= 0; iChan < nChans; iChan +=1)
		aChan = stringFromList(iChan, s.onlyChansImage, ",")
		axisStr = AddListItem(aChan, axisStr, ";")
	endfor
	if(s.liveRatio)
		axisStr = AddListItem("ratio", axisStr, ";")
	endif
	variable nAxes=Itemsinlist(axisStr, ";")
	// Display Graph
	Display/N=twoPLROIGraph/K=1 as "Live ROI Graph: " +s.newScanName
	variable iAxis, axisFrac =(1-.02*(nAxes-1))/nAxes
	string anAxis
	for(iAxis =0; iAxis < nAxes; iAxis += 1)
		anAxis = stringfromlist(iAxis, axisStr) 
		WAVE lROIWave = $"Root:Packages:twoP:acquire:LroiWave_" + anAxis
		appendtoGraph/L=$"L_" + anAxis lROIWave
		ModifyGraph freePos($"L_" + anAxis)=0
		ModifyGraph axisEnab($"L_" +  anAxis)={(iAxis * axisFrac) +(iAxis * .01) ,((iAxis + 1) * axisFrac) +(iAxis* .01)}
		label $"L_" + anAxis "Live ROI " + stringfromlist(iAxis, axisStr)
		ModifyGraph lblPos( $"L_" + anAxis)=60
	endfor
	Label bottom "\\Z12Time(Seconds)"
	ModifyGraph rgb =(0,0,0)
	setaxis/A/R bottom
	// Hook to save window position
	WC_WindowCoordinatesRestore("twoPLROIGraph")
	SetWindow twoPLROIGraph hook(saveHook)= twoP_UtilSaveWinPosHook, hookevents = 2
end

//******************************************************************************************************
// Makes a new graph for live raw A/D value display
// Last Modified 2025/08/11 by Jamie Boyd 
Function twoP_ScanMakeLiveRawGraph(s)
	STRUCT twoP_ScanStruct &s

	// Kill old lROI graph
	DoWindow/K twoPLiveRawGraph
	// check for new graph

	variable iChan, nChans= itemsInList(s.onlyChansImage, ",")
	string aChan
	string axisStr = ""
	for(ichan= 0; iChan < nChans; iChan +=1)
		aChan = stringFromList(iChan, s.onlyChansImage, ",")
		WAVE/Z LiveRaw = $"root:Packages:twoP:acquire:Acq1D_" +aChan
		if(WaveExists(LiveRaw))
		axisStr = AddListItem(aChan, axisStr, ";")
		endif
	endfor
	variable nAxes=Itemsinlist(axisStr, ";")
	// Display Graph
	Display/k=1/N=twoPLiveRawGraph as "Live Raw A/D Graph: " +s.newScanName
	variable iAxis, axisFrac =(1-.04*(nAxes-1))/nAxes
	string anAxis
	for(iAxis =0; iAxis < nAxes; iAxis += 1)
		anAxis = stringfromlist(iAxis, axisStr) 
		WAVE LiveRaw = $"Root:Packages:twoP:acquire:Acq1D_" + anAxis
		appendtoGraph/L=$"L_" + anAxis LiveRaw
		ModifyGraph mode($"Acq1D_" + anAxis)=2,lsize($"Acq1D_" + anAxis)=2, zColorMin($"Acq1D_" + anAxis)=(65280,0,0), zColorMax($"Acq1D_" + anAxis)=(0,0,0)
		ModifyGraph zColor($"Acq1D_" + anAxis)={LiveRaw,0,1,Grays,0}
		ModifyGraph freePos($"L_" + anAxis)={0,bottom}
		ModifyGraph axisEnab($"L_" +  anAxis)={(iAxis * axisFrac) +(iAxis * .02) ,((iAxis + 1) * axisFrac) +(iAxis* .02)}
		label $"L_" + anAxis "Live Raw A/D " + stringfromlist(iAxis, axisStr)
		ModifyGraph lblPos($"L_" + anAxis)=60
		ModifyGraph fSize($"L_" + anAxis)=12
		ModifyGraph btLen($"L_" + anAxis)=4
		SetDrawEnv dash=2, ycoord= $"L_" + anAxis
		DrawLine 0,0,1,0
		Setaxis $"L_" + anAxis -(kNQtoUnsigned), ((2^kNQimageBits)-1)
		
	endfor
	// Don't really have a time scaling on bottom axis because of pause triggerfor flyback
	ModifyGraph nticks(bottom)=0
	ModifyGraph noLabel(bottom)=2
	// Hook to save window position
	WC_WindowCoordinatesRestore("twoPLiveRawGraph")
	ModifyGraph margin(left)=50,margin(bottom)=5,margin(right)=5,margin(top)=5
	SetWindow twoPLiveRawGraph hook(saveHook)= twoP_UtilSaveWinPosHook, hookevents = 2
end


//******************************************************************************************************
// Resets the global values used by Repeated Scan hook function or background tasks to count lines, frames, etc
// Last Modified 2026/08/05 by Jamie Boyd 
function twoP_ScanZeroGlobals(s)
	STRUCT twoP_ScanStruct &s

	switch(s.scanMode)
		case kLiveMode:
			// reset global for counting frames to average, it will also be reset when it overflows   
			NVAR iFrame = root:Packages:twoP:Acquire:LiveiAvgFrame
			iFrame = 0
			break

		case kSingleImage:
			// reset global for counting frames to average
			NVAR iFrame = root:Packages:twoP:Acquire:AvgiFrame
			iFrame = 0
			break

		case KLineScan:
			// reset global for counting lineScan chunks as they scanned/processed
			NVAR LSiChunk = root:packages:twoP:acquire:LSiChunk
			LSiChunk= 0
			break

		case kTimeSeries:
			// reset global for counting time series chunks as they scanned/processed
			NVAR TimeSeriesiChunk = root:Packages:twoP:Acquire:TSeriesiChunk
			TimeSeriesiChunk = 0
			break

		case kZseries:
			// reset globals for counting frames and averages
			NVAR iFrame =  root:Packages:twoP:Acquire:ZseriesiFrame // for counting frames in stack
			iFrame = 0
			NVAR iAvg = root:Packages:twoP:Acquire:ZseriesiAvg		// when averaging with kalman next
			iAvg = 0
			break
		case kePhysOnly:
			break
	endSwitch
end

//**************************************************************************************************
// Starts threads for processing various scan modes
// Last modified 2026/07/29 by Jamie Boyd
Function twoP_ScanStartThreads(s)
	STRUCT twoP_ScanStruct &s
	
	WAVE/WAVE threadData = root:packages:twoP:acquire:threadData
	variable iChan, nChans = ItemsInList(s.selImageChanList, ";")
	NVAR gThreadGroupID =  root:packages:twoP:acquire:gThreadGroupID
	gThreadGroupID = ThreadGroupCreate(nChans)
	s.threadGroupID = gThreadGroupID

	for(iChan=0; iChan < nCHans; iChan +=1)
		switch(s.ScanMode)
			case kLiveMode:
				ThreadStart gThreadGroupID, iChan, twoP_LiveThread(threadData, nChans, s.LiveStackAtOnce, s.numFrames, (s.pixWidth * s.pixHeight), s.flybackMode, s.LiveHist, s.LiveROI, s.LROIleft, s.LROItop, s.LROIright, s.LROIbottom, s.liveRatio, s.ratioTopChanNum, s.ratioBottomChanNum)
				break
				
			case kSingleImage:
				if(s.AvgDoUpdate)
					ThreadStart gThreadGroupID, iChan, twoP_AvgFramesThread(threadData, s.flybackMode)
				endif
				break
			
			case kLineScan:
				if (s.LSscanAtOnce)
					ThreadStart gThreadGroupID, iChan, twoP_lineScanAtOnceThread(threadData, nChans, s.LSChunkSize, s.pixWidth, s.flybackMode, s.LiveROI, ((s.LROIleft -  s.xScalStart)/s.xPixSize), ((s.LROIright - s.xScalStart)/s.xPixSize), s.liveRatio, s.ratioTopChanNum, s.ratioBottomChanNum)
				else
					ThreadStart gThreadGroupID, iChan, twoP_lineScanCyclicThread(threadData, nChans, s.LSChunkSize,  s.pixWidth, s.flybackMode, s.LiveROI, ((s.LROIleft -  s.xScalStart)/s.xPixSize), ((s.LROIright - s.xScalStart)/s.xPixSize), s.liveRatio, s.ratioTopChanNum, s.ratioBottomChanNum)
				endif
				break
				
			case kTimeSeries:
				if (s.TSscanAtOnce)
					ThreadStart gThreadGroupID, iChan, twoP_timeSeriesAtOnceThread(threadData, nChans, s.TSChunkSize, (s.pixWidth *  s.pixHeight), s.flybackMode, s.LiveROI, s.LROIleft, s.LROItop, s.LROIright, s.LROIbottom, s.liveRatio, s.ratioTopChanNum, s.ratioBottomChanNum)
				else
					ThreadStart gThreadGroupID, iChan, twoP_timeSeriesCyclicThread(threadData, nChans, s.TSChunkSize,  (s.pixWidth *  s.pixHeight), s.flybackMode, s.LiveROI, s.LROIleft, s.LROItop, s.LROIright, s.LROIbottom, s.liveRatio, s.ratioTopChanNum, s.ratioBottomChanNum)
				endif
				break
			case kZseries:
				if (s.zAvgStackATOnce)
					ThreadStart gThreadGroupID, iChan, twoP_ZseriesAtOnceThread(threadData, (s.pixWidth *  s.pixHeight), s.NumZseriesAvg, s.flybackMode)
				else
					ThreadStart gThreadGroupID, iChan, twoP_ZseriesKNextThread(threadData,  (s.pixWidth *  s.pixHeight), s.NumZseriesAvg, s.flybackMode)
				endif
				break
		endSwitch
	endfor
end


//**********************************************************************************************************************
// sets a global variable the hook function or background task looks for so it can quit gracefully at the end of a frame
// if shift is held down, we don't mess around, just quit everything right away
// Lat Modified 2025/08/12 by Jamie boyd
function twoP_ScanAbortProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
		NVAR liveStop = root:Packages:twoP:Acquire:ScanStopOrAbort
		if(ba.eventMod & 2)
			twoP_EndScanning()		// stop scanning
			twoP_EndScan (2)		// don't try to save any data
		else
			liveStop = 1			// set a global so scan repeated hook or background can quit gracefully
		endif
		break
	endswitch
end


//**************************************************************************************************
// Scan start for a multi-acquisition scan
// Last modified 2026/08/09 by Jamie Boyd
Function twoP_ScanStartMultiProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Button AqStartButton win=twoP_Controls, title = "Abort", proc = twoP_ScanAbortProc
			NVAR multiTimemode =root:packages:twoP:acquire:multiAqTimeMode
			if (multiTimemode == kMultiUseTrigger)	// load a scanStruct and start the first scan
				Button AqStartButton win=twoP_Controls, fColor=(65280,65280,0)
				TitleBox MultiAqTimeToNextTitle win = twoP_Controls, title="Waiting for Trigger...."
				SVAR infoStructStr = root:packages:twoP:acquire:multiAcqScanStructStr
				STRUCT twoP_ScanStruct s
				StructGet/S s, infoStructStr
				// start Threads
				twoP_ScanStartThreads(s)
				//init the scan
				twoP_InitScan(s)
			else // start the background task
				Button AqStartButton win=twoP_Controls, fColor=(65280,0,0)
				CtrlNamedBackground multiScanBKG, period= 60, Burst = 0, proc=twoP_MultiBkg, Start=1
			endif
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end


//******************************************* twoP_MultiCheckOverWrite***********************************************************
// checks for scan overwriting for the entire range of scans to be made for a multiple acquisition
// returns a string containing list of scan names to be used, or empty string if user cancels
// Last Modified 2026/08/07 by Jamie Boyd
Function twoP_MultiCheckOverWrite(s)
	STRUCT twoP_ScanStruct &s

	string scanName = s.NewScanName
	string scanList=""
	string alertStr
	variable iAq
	variable startNum
	NVAR startScanNumG = root:Packages:twoP:Acquire:NewScanNum
	// check first scan and offer to increment start wave name
	scanName = twoP_ScanNameInc(scanName, 0)
	if((s.overWriteWarn == 1) && (DataFolderExists("root:twoP_Scans:" + scanName)))// user wants to be warned about possible overwriting of waves
		DO
			alertStr = "A scan with the name \"" + scanName + "\" already exists. Overwrite it?  Click \"yes\" to overwrite old scans, \"no\" to increment new wave name, or \"cancel\" to cancel scanning."
			doalert 2, alertstr
			if(V_Flag == 2)		// no was clicked, so increment the scan name
				scanName = twoP_ScanNameInc(scanName, 1)
			elseif(V_Flag == 3) // cancel scanning was clicked
				return 1 // return 1 to cancel
			endif
			// keep incrementing while No overwriting selected AND the wave exists
		WHILE((dataFolderExists("root:twoP_Scans:" + scanName)) &&(V_Flag ==2))
	endif
	startNum = startScanNumG
	scanList = AddListItem(scanName, scanList, ";")
	// check remaining waves, but don't offer to increment, cause that would mess up consecutive naming of multiAq
	for (iAq=1 ; iAq < s.multiAqNaqs ; iAq +=1)
		scanName = twoP_ScanNameInc(scanName, 1)
		if((s.overWriteWarn == 1) && (DataFolderExists("root:twoP_Scans:" + scanName)))// user wants to be warned about possible overwriting of waves
			alertStr = "A scan with the name \"" + scanName + "\" already exists. Overwrite it?  Click \"yes\" to overwrite old scans, \"no\" to cancel scanning."
			doalert 1, alertstr
			if(V_Flag == 2)		// no was clicked, so cancel scanning
				return 1 // return 1 to cancel
			endif
		endif
		scanList = AddListItem(scanName, scanList, ";")
	endfor
	startScanNumG =startNum
	s.multiScanList = SortList(scanList, ";", 16 )
	return 0
end


// ********************************* twoP_MultiMakeScanWaves *********************************************************************************************
// makes all the waves at once for a multiAq, for faster turn-around between scans
// Last Modified 2026/08/07 by Jamie Boyd	
Function twoP_MultiMakeScanWaves(s)
	STRUCT twoP_ScanStruct &s
	
	// s.multiScanList holds list of all scans to make
	// s.newScanName holds name of first scan to make, used by twoP_ScanMakeScanWaves
	string scanNote =  twoP_ScanNoter(s)	// scan note is same for all multiAq waves
	variable iScan
	variable nScans = itemsInList(s.multiScanList)
	for (iScan =0; iScan < nScans; iScan +=1)
		s.newScanName = stringFromList (iScan, s.multiScanList)
		twoP_ScanMakeScanWaves(s)
		// make scan note str in folder already made by twoP_ScanMakeScanWaves, add info on MultiAq number
		string/G $"root:twoP_Scans:" + s.newScanName + ":" + s.newScanName + "_info"= scanNote +  "multiAq_i:" + num2str (iScan) + "\r" + "multiAq_N:" + num2str (nScans) + "\r"
	endfor
	s.newScanName = stringFromList (0, s.multiScanList) // put this back to the starting position
End


// ***************************************************************************************************************************************
//----------------------------------------- Initializing NIDAQmx for Scan -----------------------------------------------
// ***************************************************************************************************************************************


//*********************************** twoP_InitScan *******************************************************************
// After all the prep is done, this function starts the threads running and configures NIDAQmx functionality for a single scan
// Last Modified 2026/07/31 by Jamie
function twoP_InitScan (s)
	STRUCT twoP_ScanStruct &s

	// set up triggers
	if(s.trigChans)
		if(twoP_InitTriggers(s))
			return 1
		endif
	endif

	// set up voltage waves
	if(s.vOutChans)
		if(twoP_InitVoltagePulse(s))
			return 1
		endif
	endif

	// Init NIDAQmx for ePhys. If ePhys only and starts on trigger, waits for trigger on /imageBoard/PFI6
	if(itemsinlist(s.selEphysChanList, ";") > 0)
		if(twoP_InitEphys(s))
			return 1
		endif
	endif

	// init NIDAQmx for image scan and waits for trigger, if triggered
	if(s.scanmode != kephysOnly)
		if(twoP_InitImageScan(s))
			return 1
		endif
	endif
	return 0
end


//******************************************************************************************************
// Sets up triggers, using the ephys board.  returns 1 if an error occurs, else 0
// Last Modified 2025/09/10 by Jamie Boyd
Function twoP_InitTriggers(s)
	STRUCT twoP_ScanStruct &s

	// use no triggers in liveMode or zSeries
	if(s.scanmode == kLiveMode || s.scanmode == kZseries)
		return 0
	endif
	// polarity and duration from preferences
	NVAR Trig1Polarity = root:packages:twoP:acquire:Trig1Polarity
	NVAR Trig2Polarity= root:packages:twoP:acquire:Trig2Polarity
	NVAR Trig1Duration =root:packages:twoP:acquire:Trig1Duration
	NVAR Trig2Duration =root:packages:twoP:acquire:Trig2Duration
	// trigger source
	string trigSrc
	if(itemsinList(s.selEphysChanList, ";") >0)		// we are collecting ePhys, so we have a startTrigger signal on ePhys Board
		trigSrc= "/" +  s.ePhysBoard + "/ai/StartTrigger"
	else
		trigSrc= "/" +  s.imageBoard + "/RTSI6"	// trigger off of line gate on RTSI bus only when no ePhys channelsare used
	endif
	// mater clock src is RTSI 7 if we are doing imaging, else use ephysboard
	string mcSrc
	if(s.scanMode == kEphysOnly)
		mcSrc = "/" + s.ephysBoard + "/20MHzTimeBase"
	else
	 	mcSrc = "/" + s.imageBoard + "/RTSI7"
	 endif
	try

		if(s.trigChans & 1)
			fDAQmx_CTR_Finished(s.ePhysBoard, 0)
			DAQmx_CTR_OutputPulse /DEV=s.ePhysBoard/SEC={Trig1Duration, Trig1Duration} /IDLE=(Trig1Polarity)/DELY=(s.trig1Secs)/NPLS=1/STRT=1 /TRIG= trigSrc /MC={mcSrc, 20e06} 0 ; AbortOnRTE
		endif
		if(s.trigChans & 2)
			fDAQmx_CTR_Finished(s.ePhysBoard, 1)
			DAQmx_CTR_OutputPulse /DEV=s.ePhysBoard/SEC={Trig2Duration, Trig2Duration} /IDLE=(Trig2Polarity)/DELY=(s.trig2Secs)/NPLS=1/STRT=1 /TRIG=trigSrc /MC={mcSrc, 20e06} 1; AbortOnRTE
		endif
	catch
		print  "The \"NQ_doTriggers\" function failed:\r" +  fdaqmx_errorString()
		return 1
	endtry
	return 0	// exit with success
end

//************************************** twoP_InitVoltagePulse ****************************************************************
// Gets the ephys board ready to Output Voltage Waves using waveform generator 0 and waveform generator 1
//  returns 1 if an error ocurred, else 0
// Last Modified 2025/09/10 by Jamie
Function twoP_InitVoltagePulse(s)
	STRUCT twoP_ScanStruct &s
	
	// use no voltage waves in liveMode or zSeries
	if(s.scanmode == kLiveMode || s.scanmode == kZseries)
		return 0
	endif
	// trigger source
	string trigSrc
	if(s.vOutStart == 1) // start voltage output on scan start
		if(itemsinList(s.selEphysChanList, ";") >0)			// we are collecting ePhys, so we have a startTrigger signal on ePhys Board
			trigSrc= "/" +  s.ePhysBoard + "/ai/StartTrigger"
		else
			trigSrc= "/" +  s.imageBoard + "/RTSI6"				//no ai/StartTrigger, so trigger off of line gate on RTSI bus only when no ePhys channels are used
		endif
	else
		trigSrc= "/" + s.ePhysBoard +"/Ctr1/InternalOutput"
	endif
	// mater clock src is RTSI 7 if we are doing imaging, else use ephysboard
	string mcSrc
	if(s.scanMode == kEphysOnly)
		mcSrc = "/" + s.ephysBoard + "/20MHzTimeBase"
	else
	 	mcSrc = "/" + s.imageBoard + "/RTSI7"
	endif
	
	try
		string VoltageWavePath = ""
		// Make VoltageWavePath string ready for NIDAQ command
		if(1 & s.vOutChans) // channel 1 is selected
			VoltageWavePath += "root:packages:twoP:acquire:VoltagePulseWaves:" + s.vOutWave1 + " , 0;"
		endif
		if(2 & s.vOutChans) // channel 2 is selected
			VoltageWavePath +=  "root:packages:twoP:acquire:VoltagePulseWaves:" + s.vOutWave2 + " , 1;"
		endif
		// Configure waveform generator
		DAQmx_WaveformGen /DEV=s.ePhysBoard /MC={mcSrc, 20E06} /NPRD =1 /STRT=1 /TRIG={trigSrc, 1, 1} VoltageWavePath; AbortonRTE
	catch
		printf  "The \"twoP_InitVoltagePulse\" function failed with %d. The Error message was:\r%s\r", V_AbortCode, fDAQMX_errorString()
		return 1
	endtry
	return 0	// exit with success
end

//******************************************************************************************************
// Starts the ephys board ready to scan, waiting for image board, or starts ePhys scan if doing ephys alone
// sets input trigger to waveform generator or, for ePhys alone,  sends scan start to RTSI
//  returns 1 if an error ocurred, else 0
// last Modified:
// 2026/07/08 by Jamie Boyd - moved channel configuration into this function for ease of multiaq programming
// 2025/09/10 by Jamie Boyd-input triggering for ephys with imaging
Function twoP_InitEphys(s)
	STRUCT twoP_ScanStruct &s
	
	
	
	string EOShook = "twoP_EndScanEphysOnly()"
	string errFuncStr

	try
		if(s.ScanMode == kePhysOnly) // no signals from imaging board
			if(s.inPutTrigger)
				DAQmx_Scan /DEV= s.ePhysBoard/STRT=1/TRIG= {"/" + s.imageBoard + "/PFI6",1}/BKG=1/EOSH=EOShook  WAVES= s.ePhysPath;abortonRTE // NO master clock, start on PFI6 input trigger directly
			else
				DAQmx_Scan /DEV= s.ePhysBoard/STRT=1/BKG=1/EOSH=EOShook WAVES= s.ePhysPath;abortonRTE	//no trigger, no master clock, just ephys, start right away
			endif
		else	// if doing imaging, start on line gate on RTSI bus
			fdaqmx_ConnectTerminals("/" + s.imageBoard + "/20MHzTimeBase", "/" + s.imageBoard +"/RTSI7", 0)
			DAQmx_Scan /DEV= s.ePhysBoard/STRT=1/TRIG= {"/" + s.imageBoard + "/RTSI6",1,1}/BKG=1 /MC={"/" + s.imageBoard + "/RTSI7", 20e06} WAVES= s.ePhysPath;abortonRTE
		endif
	catch
		printf  "The \"twoP_InitEphys\" function failed with code %d. The Error message was:\r%s\r", V_AbortCode, fdaqmx_errorString()
		return 1
	endtry

	return 0	// exit with success
end

//******************************************************************************************************
// Starts the image board scanning, or waiting for input trigger
// returns 1 if an error ocurred, else 0
// ues RTSI lines as a bus to connect sources to destinations they may not otherwise connect to without errors. Like old school 2P version
// Last Modified:2026/07/31
Function twoP_InitImageScan(s)
	STRUCT twoP_ScanStruct &s

	// only for image scan, ePhys has its own NI-DAQ init, which should already have run.
	if(s.scanmode== kephysOnly)
		return 0
	endif

	// clear any stored DAQmx error messages
	for(;(cmpstr(fDAQmx_ErrorString(), "") != 0);)
	endfor
		
	string RPTChook
	string EOShook
	string ScanErrhook
	sprintf ScanErrhook, "twoP_EndScanErr(%d)", s.ScanMode
	
	variable pixHz =1/(s.PixTime)
	//global variables for the shutter. Pugged into digital line 0 on the Image Board
	NVAR shutterTaskNum = root:packages:twoP:Acquire:shutterTaskNum
	NVAR triggerTaskNum =  root:packages:twoP:Acquire:triggerTaskNum
	NVAR shutterOpen = root:Packages:twoP:acquire:shutterOpenLevel
	NVAR shutterDelay = root:Packages:twoP:acquire:shutterDelay
	NVAR liveStop = root:Packages:twoP:Acquire:ScanStopOrAbort
	
	try
		// connect start scan output to PFI0 (normal scan start output)
		AbortOnValue fDAQmx_ConnectTerminals("/" + s.ImageBoard + "/ai/startTrigger", "/" + s.ImageBoard + "/PFI0", 0), 1 // rests low, brief low-to-high pulse when scan starts
		//connect imaging board timebase to RTSI7 so it can be used on otherboard
		AbortOnValue fDAQmx_ConnectTerminals("/" + s.ImageBoard + "/20MhzTimeBase", "/" + s.ImageBoard + "/RTSI7", 0), 2
		// connect ao/sample clock and ai/sample clock to PFI pins for use with chunkulator, e.g. You can comment one or both of these out if you don't need them.
		AbortOnValue fDAQmx_ConnectTerminals("/" + s.ImageBoard + "/ao/SampleClock", "/" + s.ImageBoard + "/PFI5", 0), 3// rests high, brief high-to-low low pulses, leads
		AbortOnValue fDAQmx_ConnectTerminals("/" + s.ImageBoard + "/ai/SampleClock", "/" + s.ImageBoard + "/PFI7", 0), 4   // rests low, brief high pulse on low-to-high of ao sample clock
		// connect counter0(line gate) output to normal counter 0 output pin(aka PFI 12) for use with image projector, e.g. 
		AbortOnValue fDAQmx_ConnectTerminals("/" + s.ImageBoard + "/ctr0InternalOutput", "/" + s.ImageBoard + "/ctr0Out", 0), 5   // rests low, brief high pulse on low-to-high of ao sample clock
		
		// mnake lineGate on ctr0, source is RTSI_5, where we will put ao signal of the waveform generator, direct the output to RTSI_6 where it is used to gate analog input
		fDAQmx_CTR_Finished(s.ImageBoard, 0)
		AbortOnValue fDAQmx_ConnectTerminals("/" + s.ImageBoard + "/ctr0InternalOutput", "/" + s.ImageBoard + "/RTSI6", 0), 6
#ifdef ENV_IS_DEVELOP
		DAQmx_CTR_OutputPulse /DEV=s.ImageBoard/TICK={ s.PixWidth, (s.PixWidthTotal - s.PixWidth)} /IDLE=0 /NPLS=0/TBAS="/" + s.ImageBoard + "/RTSI5" /Rate=(pixHz) 0; ABORTONRTE
#else
		DAQmx_CTR_OutputPulse /DEV=s.ImageBoard/TICK={, s.PixWidth -1, (s.PixWidthTotal - s.PixWidth + 1)} /IDLE=0 /NPLS=0/TBAS="/" + s.ImageBoard + "/RTSI5" /Rate=(pixHz) 0; ABORTONRTE
#endif
		// start A/D scanning
		Switch(s.ScanMode)
			variable taskPeriod
			case kLiveMode:		// scan repeats till stopped
				sprintf RPTChook, "twoP_LiveHook(\"%s\", %d, %d, %d, %d)", s.onlyChansImage, itemsInList(s.onlyChansImage, ","), s.numFrames, s.LiveStackAtOnce, s.threadGroupID
				DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/RTSI5",0}/PAUS={ "/" + s.ImageBoard + "/RTSI6", 1,0}/STRT=1 /RPTC/RPTH=RPTChook/ERRH= ScanErrhook WAVES = s.scanWavePath;ABORTONRTE
				break
				
			case kSingleImage:
				if(s.AvgDoUpdate)	// collecting one frame at a time and updating scanWave with a running average with a repeated scan hook that calls a thread
					sprintf RPTChook, "twoP_AvgFramesHook(\"%s\", %d, %d, %d)" s.onlyChansImage, itemsInList(s.onlyChansImage, ","), s.numFrames, s.threadGroupID
					DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/RTSI5", 0}/PAUS={ "/" + s.ImageBoard + "/RTSI6", 1,0}/STRT=1 /RPTC/RPTH=RPTChook/ERRH= ScanErrhook WAVES = s.scanWavePath;ABORTONRTE
				else	// collecting all frames at once and averaging at end with an end-of-scan hook
					sprintf EOShook,  "twoP_AvgFramesEndHook(\"%s\", \"%s\", %d, %d)", s.newScanName, s.onlyChansImage, s.numFrames, s.flybackMode
					DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/RTSI5", 0}/STRT=1/PAUS={ "/" + s.ImageBoard + "/RTSI6", 1,0}/EOSH=EOShook /ERRH= ScanErrhook WAVES = s.scanWavePath;ABORTONRTE
				endif
				break
			
			case kLineScan:
				if (s.LSscanAtOnce) //scan at once, with background task to copy data and update display
					DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/RTSI5", 0}/STRT=1/PAUS={ "/" + s.ImageBoard + "/RTSI6", 1,0}/ERRH= ScanErrhook WAVES = s.scanWavePath;ABORTONRTE
					taskPeriod=ceil(s.LSChunkSize * s.lineTime * 60)
					CtrlNamedBackground LineScanTask, period = taskPeriod, burst = 0, proc= twoP_LineScanBkg, start=(ticks + taskPeriod)
				else // scan repeats till scan Wave is full, doing 1 chunk ata time, repeat hook calls thread
					sprintf RPTChook, "twoP_LineScanHook(\"%s\", %d, %d, %d)", s.onlyChansImage, itemsInList(s.onlyChansImage, ","), s.LSnumChunks, s.threadGroupID
					DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/RTSI5", 0}/PAUS={ "/" + s.ImageBoard + "/RTSI6", 1,0}/STRT=1/RPTC/RPTH=RPTChook/ERRH= ScanErrhook WAVES = s.scanWavePath;ABORTONRTE
				endif
				break
				
			case kTimeSeries:
				if (s.TSscanAtOnce)
					// no repeats, scan at once, with background task to update display and end of task hook to redimension and clean up
					DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/RTSI5", 0}/STRT=1/PAUS={ "/" + s.ImageBoard + "/RTSI6", 1,0} /ERRH= ScanErrhook WAVES = s.scanWavePath;ABORTONRTE
					taskPeriod=ceil(s.TSChunkSize * s.frameTime * 60)
					CtrlNamedBackground tSeriesTask, period =  taskPeriod, burst =0, proc= twoP_timeSeriesBkg, start=(ticks + taskPeriod)
				else // repeated scan with bkg function
					sprintf RPTChook, "twoP_timeSeriesHook(\"%s\", %d, %d, %d, %d)", s.onlyChansImage, itemsInList(s.onlyChansImage, ","), s.TSChunkSize, s.TSnumChunks, s.threadGroupID
					DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/RTSI5", 0}/PAUS={ "/" + s.ImageBoard + "/RTSI6", 1,0}/STRT=0 /RPTC/RPTH=RPTChook/ERRH= ScanErrhook WAVES = s.scanWavePath;ABORTONRTE
				endif
				break

			case kZseries:
				if (s.zAvgStackAtOnce)
					sprintf RPTChook, "twoP_zSeriesAtOnceHook(\"%s\", %d, %d, %d, \"%s\", %d)", s.onlyChansImage, itemsInList(s.onlyChansImage, ","), s.threadGroupID, s.numFrames, s.StageProc, (s.zStepSize > 0 ? 1 : -1)
				else
					sprintf RPTChook "twoP_zSeriesKNextHook((\"%s\", %d,  %d, %d, %d, \"%s\", %d)", s.onlyChansImage, itemsInList(s.onlyChansImage, ","), s.numFrames, s.NumZseriesAvg,  s.StageProc, (s.zStepSize > 0 ? 1 : -1)
				endif
				DAQmx_Scan /DEV=s.ImageBoard/BKG=1/CLK={"/" + s.imageBoard + "/RTSI5", 0}/PAUS={ "/" + s.ImageBoard + "/RTSI6", 1,0}/STRT=1 /RPTC/RPTH=RPTChook/ERRH= ScanErrhook WAVES = s.scanWavePath;ABORTONRTE
				break
		endSwitch		
		// wave form generator, send sample clock output to RTSI_5
		AbortOnValue fDAQmx_ConnectTerminals("/" + s.ImageBoard + "/ao/SampleClock", "/" + s.ImageBoard + "/RTSI5", 0), 7
		string scanWavesList
		If(s.ScanMode == kLineScan)
			scanWavesList = "root:packages:twoP:acquire:HorWave, 0;"
		else
			scanWavesList = "root:packages:twoP:acquire:HorWave, 0;root:packages:twoP:acquire:VerWave, 1;"
		endif
		// if input trigger, setup waveform generator then wait for trigger low-to-high to open shutter and for trigger-high-to low to progress to starting A/D scan
		if((s.inPutTrigger) &&(s.scanMode != kLiveMode))
			DAQmx_WaveformGen /DEV=s.imageBoard /BKG=0/NPRD=0/TRIG={"/" + s.ImageBoard + "/PFI6", 1, 0}/Strt=1  scanWavesList; ABORTONRTE
			// waiting for high
			for(;((fDAQmx_DIO_Read(s.imageBoard, triggerTaskNum) == 0) && (liveStop == 0) && (fDAQmx_ScanGetNextIndex(s.imageBoard) ==0));)
				DoUpdate/W=twoP_Controls
			endfor
			ABORTOnValue (liveStop), 0
			fDAQmx_DIO_Write(s.imageBoard, shutterTaskNum, shutterOpen) // open shutter
			if (s.scanMode == kMultiAq)
				NVAR startTime = root:packages:twoP:acquire:MultiAqStartTime					// when scan was started
				startTime = datetime				// the REAL time this scan started
				NVAR multiAqiAq = root:packages:twoP:acquire:multiAqiAq
				multiAqiAq += 1		// increment scan count because bkg task does not run if threaded
				TitleBox MultiAqTimeToNextTitle win = twoP_Controls, title = "SCANNING"
			endif
			Button AqStartButton, win = twoP_Controls, fColor=(65280,0,0)	// also shows user that trigger has happened
		else // if not triggered, open shutter and wait shutter open time before starting waveform generator
			abortonvalue fDAQmx_DIO_Write(s.ImageBoard, shutterTaskNum,(shutterOpen)), 7
			// wait a few milliseconds while shutter opens before continuing
			if(shutterDelay > 0)
				Sleep/c=-1/S shutterDelay
			endif
			DAQmx_WaveformGen /DEV=s.imageBoard /BKG=0/NPRD=0/Strt=1  scanWavesList; ABORTONRTE
		endif
	catch
		variable err=GetRTError(1)
		if (err)
			printf  "The \"twoP_InitImageScan\" function failed with RTE error %d\r",  err
			printf "The NIDAQ error message is:\r%s\r",  fDAQmx_ErrorString()
		else
			if (V_abortCode == 0)  // 0 was user abort
				liveStop = 0
			else
				printf  "The \"twoP_InitImageScan\" function failed at position %d\r",  V_abortCode
				printf "The NIDAQ error message is:\r%s\r",  fDAQmx_ErrorString()
			endif
		endif
		return 1 // exit with failure
	endtry
	return 0
end


// ************************************************************************************************
// ************************** Live Mode Hook and Thread Functions *********************************
// ************************************************************************************************

//**************************************************************************************************
// Repeated Scan Hook for live mode. Runs after every stack of frames to average is scanned. 
// Last modified 2026/07/28 by Jamie Boyd
Function twoP_LiveHook(selImageChanList, nChans, LiveNframes, stackAtOnce, threadGrpID)
	string selImageChanList
	variable nChans
	variable LiveNframes
	variable stackAtOnce
	variable threadGrpID
	
	// post each channel to the thread group with frame number. iFrame resets below when it reaches LiveNframes
	variable iChan
	NVAR iFrame = root:Packages:twoP:Acquire:LiveiAvgFrame
	for(ichan =0; iChan < nChans; iChan +=1)
		newdatafolder/O :tdata
		variable/G  :tdata:iChanG = iChan
		variable/G :tdata:iFrameG = iFrame
		ThreadGroupPutDF threadGrpID, :tData
	endfor
	
	// post an RGB update request
	NVAR hasRGB = root:Packages:twoP:examine:RGB_hasRGB
	if(hasRGB)
		twoP_PostRGBChans (selImageChanList)
	endif
	
	// update variable for couting frames to average
	iFrame +=1
	if(iFrame == LiveNframes)
		iFrame = 0
	endif
	
	// percent complete Display - just setting it to 1 advances the phase, which is all we want to do for live mode
	// Seems to fail when time between calls to hook function are more than a second or two
	ValDisplay AqPercentCompleteDisplay, value= _NUM:1, win=twoP_Controls
	
	// check if stop has been pressed
	NVAR liveStop = root:Packages:twoP:Acquire:ScanStopOrAbort
	if(liveStop)
		liveStop = 0
		sleep /S 10e-03		// gives some time for threads to grab the last frame of data and display it
		twoP_EndScanning ()		// not an abort, just stop live scanning
		twoP_EndScan (0)
	endif
end


//**************************************************************************************************
// Thread function for live mode. Called after every frame is scanned, or if live averaging is on, runs after every stack of frames to average is scanned
// Last modified 2026/07/28 by Jamie Boyd
ThreadSafe Function twoP_LiveThread(threadfWaves, nChans, stackAtOnce, numFrames, framePoints, flybackMode, LiveHist, LiveROI, LROIleft, LROItop, LROIright, LROIbottom, liveRatio, topChan, bottomChan)
	WAVE/WAVE threadfWaves
	variable nChans
	variable stackAtOnce
	variable numFrames
	variable framePoints
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
	
	variable nThreadWaves = 5
	// live ratio wave is always the same
	if(liveRatio)
		WAVE LROIRatio = threadfWaves [nThreadWaves * nChans]
		WAVE topWave =  threadfWaves [topChan]
		WAVE bottomWave =  threadfWaves [bottomChan]
	endif

	for(;;)
		DFREF dfr = ThreadGroupGetDFR(0,inf)		// wait for a datafolder to be posted
		if (DataFolderRefStatus(dfr) ==0)
 			break
		endif
		NVAR iChan = dfr:iChanG
		WAVE acq1d = threadfWaves [iChan * nThreadWaves]
		WAVE acq3D = threadfWaves [iChan * nThreadWaves + 1]
		WAVE scanWave = threadfWaves [iChan * nThreadWaves + 2]
		NVAR iFrame = dfr:iFrameG	
		// copy freshly scanned data into temp 3d wave. 
		if(stackAtOnce) // If stack-at-once, data for all the frames in the stack are collected at once and copied into the whole stack
			//acq3D = acq1d
			//acq3D = acq3D > 32767 ? 0: acq3D
			fastIntCopy (acq1d, 0, acq3D, 0, 0, 1)
		else	// If isByFrame a single frame's worth at a time is scanned and inserted into a plane
			//acq3D [*] [*] [iFrame] = acq1d [q*pixWidth + p]
			//acq3D [*] [*] [iFrame] = acq3D > 32767 ? 0 :  acq3D
			fastIntCopy (acq1d, 0, acq3D, (iFrame * framePoints), 0, 1)
		endif
		
		// average the temp 3D stack into the 2D scanGraphWave, which is also the scanWave
		KalmanSpecFrames(acq3D, 0,(numFrames -1), scanWave, 0, 8)
		
		// swap even lines in ScanWave for bidirectional scanning. acq3D is always kept un-swapped, so adding and averaging new frames works
		if(flybackMode)
			SwapEven(scanWave)
		endif

		if(liveHist)
			WAVE histWave = threadfWaves [iChan * nThreadWaves + 3]
			Histogram /B=2 acq1d, HistWave
		endif

		if(liveROI)
			WAVE LROIWave = threadfWaves [iChan * nThreadWaves + 4]
			ImageStats/M=1/GS={ LROIleft,LROIright,LROIbottom,  LROItop } scanWave
			Rotate 1, LROIWave
			LROIWave [0] = V_avg
			if((liveRatio) && (iChan == nChans-1))
				Rotate 1, LROIRatio
				LROIRatio [0] = topWave[0]/bottomWave[0]
			endif
		endif
		killdataFolder dfr
	endfor
	return 0
end


// ************************************************************************************************
// ************************* Average Mode Hook and Thread Functions *******************************
// ************************************************************************************************


//**************************************************************************************************
// Repeated scan hook for average frames mode when using KalmanNext to average each frame into the scanWave
// Last modified 2026/07/29 by Jamie Boyd
function twoP_AvgFramesHook(selImageChanList, numChans, numFrames, threadGroupID)
	string selImageChanList
	variable numChans
	variable numFrames
	variable threadGroupID
	
	// post channels to threads
	variable iChan
	// counting frames with global variable
	NVAR iFrame = root:packages:twoP:acquire:AvgiFrame
	for(ichan =0; iChan < numChans; iChan +=1)
		newdatafolder/O :tdata
		variable/G :tdata:iChanG = iChan
		variable/G :tdata:iFrameG = iFrame
		ThreadGroupPutDF threadGroupID, :tdata
	endfor
	// post an RGB update request
	NVAR hasRGB = root:Packages:twoP:examine:RGB_hasRGB
	if(hasRGB)
		twoP_PostRGBChans (selImageChanList)
	endif
	iFrame += 1
	// update progress
	NVAR PercentComplete=root:packages:twoP:Acquire:PercentComplete
	PercentComplete = 100*(iFrame/numFrames)
	// check if scan was aborted with live stop
	NVAR wasAbort = root:Packages:twoP:Acquire:ScanStopOrAbort
	if((iFrame == numFrames) ||(wasAbort))
		wasAbort = 0
		sleep /S 10e-03		// gives some time for threads to grab the last frame of data and display it
		twoP_EndScanning()	// stopping anywhere is fine here, because Kalman to next is used
		twoP_EndScan (0)
	endif
end

	
//**************************************************************************************************
// Thread function for average frames mode, when using KalmAnNext to average each frame into the scanWave
// Last modified 2026/07/30 by Jamie Boyd
threadsafe function twoP_AvgFramesThread(threadWaves, flybackMode)
	WAVE/WAVE threadWaves
	variable flybackMode
	
	variable nThreadWaves = 3

	for(;;)
		DFREF dfr = ThreadGroupGetDFR(0, inf)
		if (DataFolderRefStatus(dfr) ==0)
			break
		endif
		NVAR iChan = dfr:iChanG
		WAVE acq1D = threadWaves [iChan * nThreadWaves]
		WAVE acq2D = threadWaves [iChan * nThreadWaves + 1]
		WAVE scanWave = threadWaves [iChan * nThreadWaves + 2]
		NVAR iFrame = dfr:iFrameG
		//acq2D = acq1d
		//acq2D = acq2D > 32767 ? 0: acq2D
		fastIntCopy (acq1d, 0, acq2D, 0, 0, 1)
		if(flybackMode)
			SwapEven(acq2D)
		endif
		KalmanNext(acq2D, scanWave, iFrame)
		KillDataFolder dfr
	endfor
	return 0
end


//**************************************************************************************************
// End-of-scan Hook function for average frames mode, when averaging all frames at once, at the end of the scan. No threads
// Last modified 2026/07/29 by Jamie Boyd
Function twoP_AvgFramesEndHook(scanName, selImageChanList,  numFrames, flybackMode)
	string scanName
	string selImageChanList
	variable numFrames
	variable flybackMode
	
	twoP_EndScanning()
	variable nChans = itemsInlist(selImageChanList, ",")
	String aChan
	variable iChan
	for(ichan =0; iChan < nChans; iChan +=1)
		aChan = stringFromList(iChan, selImageChanList, ",")
		WAVE acq1D = $"root:packages:twoP:acquire:Acq1D_" + aChan
		WAVE acq3D = $"root:packages:twoP:acquire:Acq3D_" + aChan
		WAVE scanWave =  $"root:twoP_Scans:" + scanName +  ":" + scanName + "_" + aChan
		//acq3D = acq1d
		//acq3D = acq3D > 32767 ? 0: acq3D
		fastIntCopy (acq1d, 0, acq3D, 0, 0, 1)
		KalmanSpecFrames(acq3D, 0, numFrames-1, scanWave, 0, 8)
		if(flybackMode)
			SwapEven(scanWave)
		endif
	endfor
	// post an RGB update request
	NVAR hasRGB = root:Packages:twoP:examine:RGB_hasRGB
	if(hasRGB)
		twoP_PostRGBChans (selImageChanList)
	endif
	twoP_EndScan(0)
end


// ************************************************************************************************
// ************************ Line Scan Hook, Background, and thread Functions ******************************
// ************************************************************************************************


// ************************************************************************************************
// Repeat hook function that runs at end of line scan chunk in repeated scan mode. Calls the threads, shuts down if done
// Last Modified: 2026/08/11 by Jamie Boyd
Function twoP_LineScanHook(selImageChanList, numChans, numChunks, threadGroupID)
	string selImageChanList
	variable numChans
	variable numChunks
	variable threadGroupID

	// request a thread for each channel
	NVAR iChunk =  root:packages:twoP:acquire:LSiChunk
	variable iChan
	for(ichan =0; iChan < numChans; iChan +=1)
		newdatafolder/O :tdata
		variable/G :tdata:iChanG = iChan
		variable/G :tdata:iChunkG = iChunk
		ThreadGroupPutDF threadGroupID, :tdata
	endfor
	// increment chunk counter
	iChunk +=1
	// post an RGB update request
	NVAR hasRGB = root:Packages:twoP:examine:RGB_hasRGB
	if(hasRGB)
		twoP_PostRGBChans (selImageChanList)
	endif
	// update percent complete
	NVAR PercentComplete=root:packages:twoP:Acquire:PercentComplete
	PercentComplete = 100*(iChunk/numChunks)
	// check if stopping because of scan end, or user aborting
	NVAR wasAbort = root:Packages:twoP:Acquire:ScanStopOrAbort
	if((iChunk == numChunks) ||(wasAbort))
		sleep /S 10e-02		// gives some time for threads to grab the last frame of data and insert it
		twoP_EndScanning()
		twoP_EndScan(wasAbort)
		wasAbort = 0
	endif
end

//**************************************************************************************************
// Thread function for repeated line scan, scan is done chunk by chunk, aq2D is completely filled each time
// Last modified 2026/07/29 by Jamie Boyd
ThreadSafe Function twoP_lineScanCyclicThread(threadfWaves, nChans, lScanChunkSize, pixwidth, flybackMode, LiveROI, LROILeftPt, LROIrightPt, liveRatio, topChan, bottomChan)
	WAVE/WAVE threadfWaves
	variable nChans
	variable lScanChunkSize
	variable pixWidth
	variable flybackMode
	variable liveROI
	variable LROIleftPt
	variable LROIrightPt
	variable liveRatio
	variable topChan
	variable bottomChan

	variable nThreadWaves = 4
	variable chunkPoints = pixWidth * lScanChunkSize
	
	if(liveRatio)
		WAVE LROIRatio = threadfWaves [nThreadWaves*nChans]
		WAVE topWave =  threadfWaves [topChan]
		WAVE bottomWave =  threadfWaves [bottomChan]
	endif
		
	for(;;)
		DFREF dfr = ThreadGroupGetDFR(0,inf)
		NVAR iChan = dfr:iChanG
		WAVE acq1D = threadfWaves [nThreadWaves*iChan]
		WAVE acq2D = threadfWaves [nThreadWaves*iChan + 1]
		WAVE scanWave = threadfWaves [nThreadWaves *iChan + 2]
		NVAR iChunk = dfr:iChunkG

		//acq2D = acq1d
		//acq2D = acq2D > 32767 ? 0: acq2D
		fastIntCopy (acq1d, 0, acq2D, 0, 0, 1)
		
		if(flybackMode)
			SwapEven(acq2D)
		endif
		// insert this chunk into ScanWave. lScanChunkSize will fit evenly into line scan size
		//variable startQ = iChunk * lScanChunkSize
		//scanWave [*] [startQ, startQ + lScanChunkSize -1] = acq2D [p] [q-startQ]
		fastIntCopy (acq2D, 0, scanWave, (iChunk * chunkPoints), 0, 0)
		
		// do live ROI
		if(liveROI)
			WAVE LROIWave = threadfWaves [nThreadWaves*iChan + 3]
			ImageStats/M=1/G={LROILeftPt, LROIrightPt, 0,  lScanChunkSize} acq2D
			Rotate 1, LROIWave
			LROIWave [0] = V_avg
			if ((liveRatio) && (iChan == nChans-1))
				Rotate 1, LROIRatio
				LROIRatio [0] = topWave[0]/bottomWave[0]
			endif
		endif
		KillDataFolder dfr
	endfor
end

//*****************************************************************************************************************************
// structure for background function for LineScan scan-at-once mode, calls threads, returns 1 to shut down when done
// Last modified 2027/07/29 by Jamie Boyd
STRUCTURE LineScanBkgStruct
	STRUCT WMBackgroundStruct WMS
	uint32 threadGroupID	// for posting to threds
	uint32 nChans			// number of channels/threads
	uint32 iChunk			// for counting chunks as they are done, init to 0
	uint32 numChunks		// number of chunks, including last chunk which may be only partial
	uint32 chunkSize		// number of points in a chunk
	uint32 chunkPoints		// needed to calulate points acquired
	uint32 taskTicks		// calculated time to scan a chunk
EndStructure


//*****************************************************************************************************************************
// background function for LineScan scan-at-once mode
// Last modified 2026/08/06 by Jamie Boyd
Function twoP_LineScanBkg(s)
	STRUCT LineScanBkgStruct &s

	SVAR selImageChanList=root:Packages:twoP:acquire:selImageChanList
	if(s.WMS.started)
		s.WMS.started = 0
		s.iChunk = 0
		s.nChans = ItemsInList(selImageChanList, ",")
		NVAR gThreadGroupID = root:Packages:twoP:Acquire:gThreadGroupID
		s.threadGroupID = gThreadGroupID
		NVAR lScanChunkSize = root:packages:twoP:acquire:LSChunkSize // number of lines to acquire at once
		s.chunkSize = lScanChunkSize
		NVAR LSnumChunks = root:packages:twoP:acquire:LSnumChunks
		NVAR pixwidth = root:packages:twoP:acquire:LSWidth
		s.chunkPoints = lScanChunkSize * pixWidth
		s.numChunks = LSnumChunks
		NVAR lineTime = root:packages:twoP:acquire:lineTime
		s.taskTicks = ceil(60 * lineTime * lScanChunkSize)
		return 0
	endif

	SVAR imageBoard = root:packages:twoP:Acquire:ImageBoard
	variable nextAvailablePt = fDAQmx_ScanGetNextIndex(imageBoard)
	//print "Next available point =", nextAvailablePt, "iChunk =", s.iChunk
	variable iChan
	if ((((s.iChunk + 1) * s.chunkPoints) < nextAvailablePt) || (numtype (nextAvailablePt) ==2))
		for(ichan =0; iChan < s.nChans; iChan +=1)
			newdatafolder/O :tdata
			variable/G :tdata:iChanG = iChan
			variable/G :tdata:iChunkG = s.iChunk
			ThreadGroupPutDF s.threadGroupID, :tdata
		endfor
		// increment iChunk
		s.iChunk += 1
		// check if background task is falling behind
		if (((s.iChunk * s.chunkSize) < nextAvailablePt) || (numtype (nextAvailablePt) ==2))
			s.WMS.nextRunTicks = ticks + 1
		endif
		// post an RGB update request
		NVAR hasRGB = root:Packages:twoP:examine:RGB_hasRGB
		if(hasRGB)
			twoP_PostRGBChans (selImageChanList)
		endif
		// update % complete
		NVAR PercentComplete=root:packages:twoP:Acquire:PercentComplete
		PercentComplete = 100*(s.iChunk/s.numChunks)
		// check for stopping
		NVAR wasAbort = root:Packages:twoP:Acquire:ScanStopOrAbort
		if ((s.iChunk ==  s.numChunks) || (wasAbort))
			if (wasAbort)
				NVAR iChunkG = root:packages:twoP:acquire:LSiChunk		// save globally so we can use it to resize
				iChunkG = s.iChunk
			endif
			sleep /S 100e-03		// gives 100 ms time for threads to grab the last chunk of data
			twoP_EndScanning()
			twoP_EndScan (wasAbort)
			wasAbort = 0
			return 1		// to stop backgroud task
		endif
	else // background task is called before data was ready
		variable ticksTilNext =((s.chunkSize - mod(nextAvailablePt, s.chunkSize)) / s.chunkSize) * s.taskTicks
		//printf "added ticks = %d\r", ticksTilNext
		s.WMS.nextRunTicks = ticks + ticksTilNext
	endif
	return 0
end

//**************************************************************************************************
// Thread function for lineScan done all at once, acq2D is filled from a chunk of aq1D and copied into correct position of scanWave
// Last modified 2026/08/06 by Jamie Boyd
ThreadSafe Function twoP_lineScanAtOnceThread(threadfWaves, nChans, lScanChunkSize, pixWidth, flybackMode, LiveROI, LROILeftPt, LROIrightPt, liveRatio, topChan, bottomChan)
	WAVE/WAVE threadfWaves
	variable nChans
	variable lScanChunkSize
	variable pixWidth
	variable flybackMode
	variable liveROI
	variable LROIleftPt
	variable LROIrightPt
	variable liveRatio
	variable topChan
	variable bottomChan
	
	variable nThreadWaves = 4
	if(liveRatio)
		WAVE LROIRatio = threadfWaves [nThreadWaves*nChans]
		WAVE topWave =  threadfWaves [topChan]
		WAVE bottomWave =  threadfWaves [bottomChan]
	endif
	
	variable chunkPoints = lScanChunkSize * pixWidth
	variable chunkOffset
	//variable startQ
	for(;;)
		DFREF dfr = ThreadGroupGetDFR(0,inf)
		if (DataFolderRefStatus(dfr) ==0)
			break
		endif
		NVAR iChan = dfr:iChanG
		WAVE acq1D = threadfWaves [nThreadWaves*iChan]
		WAVE acq2D = threadfWaves [nThreadWaves*iChan + 1]
		WAVE scanWave = threadfWaves [nThreadWaves *iChan + 2]
		NVAR iChunk = dfr:iChunkG

		chunkOffset = iChunk * chunkPoints
		//startQ = iChunk * lScanChunkSize
		// acq2D = acq1d [chunkOffset + q*pixWidth + p]
		// acq2D = acq2D > 32767 ? 0: acq2D
		fastintCopy(acq1d, chunkOffset, acq2D, 0, chunkPoints, 1)
		
		if(flybackMode)
			SwapEven(acq2D)
		endif
		// insert this chunk into ScanWave. lScanChunkSize will fit evenly into line scan size
		// startQ = iChunk * lScanChunkSize
		// scanWave [*] [startQ, startQ + lScanChunkSize -1] = acq2D [p] [q-startQ]
		fastintCopy(acq2D, 0, scanWave, chunkOffset, chunkPoints, 0)
		
		// do live ROI
		if(liveROI)
			WAVE LROIWave = threadfWaves [nThreadWaves*iChan + 3]
			ImageStats/M=1/G={LROILeftPt, LROIrightPt, 0,  lScanChunkSize} acq2D
			Rotate 1, LROIWave
			LROIWave [0] = V_avg
			if ((liveRatio) && (iChan == nChans-1))
				Rotate 1, LROIRatio
				LROIRatio [0] = topWave[0]/bottomWave[0]
			endif
		endif
		KillDataFolder dfr
	endfor
	return 0
end


// ************************************************************************************************
// *********************** Time Series Hook, Background, and Thread Functions **********************
// ************************************************************************************************


//**************************************************************************************************
// Repeated Scan Hook used for time series, repeated scan mode
// Last modified 2026/07/31 by Jamie Boyd
Function twoP_timeSeriesHook(selImageChanList, nChans, chunkSize, numChunks, threadGroupID)
	string selImageChanList
	variable nChans
	variable chunkSize		//number of frames scanned/copied at a time
	variable numChunks
	variable threadGroupID
	
	// request a thread for each channel
	NVAR iChunk = root:Packages:twoP:Acquire:TSeriesiChunk	 //to track how many chunks have been done
	variable iChan
	for(ichan =0; iChan < nChans; iChan +=1)
		newdatafolder/O :tdata
		variable/G :tdata:iChanG = iChan
		variable/G :tdata:iChunkG = iChunk
		ThreadGroupPutDF threadGroupID, :tdata
	endfor
	// increment chunk counter
	iChunk +=1
	// post an RGB update request
	NVAR hasRGB = root:Packages:twoP:examine:RGB_hasRGB
	if(hasRGB)
		twoP_PostRGBChans (selImageChanList)
	endif
	// update percent complete
	NVAR PercentComplete=root:packages:twoP:Acquire:PercentComplete
	PercentComplete = 100*(iChunk/numChunks)
	// check if stopping, either because of scan end, or user aborting
	NVAR wasAbort = root:Packages:twoP:Acquire:ScanStopOrAbort
	if((iChunk == numChunks) ||(wasAbort))
		sleep /S 10e-03		// gives some time for threads to grab the last frame of data and insert it
		twoP_EndScanning()
		twoP_EndScan (wasAbort)
		wasAbort = 0
	endif
end

//**************************************************************************************************
// Thread function for time series cyclic mode where a chunk of frames is scanned repeatedly. acq3D is completely filled witheachscan
// Last modified 2025/09/03 by Jamie Boyd
ThreadSafe Function twoP_timeSeriesCyclicThread(threadfWaves, nChans, chunkSize, FramePoints, flybackMode, LiveROI, LROIleft, LROItop, LROIright, LROIbottom, liveRatio, TopChan, BottomChan)
	WAVE/WAVE threadfWaves
	variable nChans
	variable chunkSize
	variable FramePoints
	variable flybackMode
	variable liveROI
	variable LROIleft
	variable LROItop
	variable LROIright
	variable LROIbottom  
	variable liveRatio
	variable topChan
	variable bottomChan
	
	variable nThreadWaves = 5
	if (liveROI && liveRatio)
		WAVE LROIRatio = threadfWaves [nThreadWaves*nChans]
		WAVE topWave =  threadfWaves [topChan]
		WAVE bottomWave =  threadfWaves [bottomChan]
	endif
	
	//variable startPlane
	variable chunkPoints = chunkSize * FramePoints
	
	for(;;)
		DFREF dfr = ThreadGroupGetDFR(0,inf)
		if (DataFolderRefStatus(dfr) ==0)
			break
		endif
		NVAR iChan = dfr:iChanG
		WAVE acq1D = threadfWaves [nThreadWaves*iChan]
		WAVE acq3D = threadfWaves [nThreadWaves*iChan + 1]
		WAVE scanWave = threadfWaves [nThreadWaves *iChan + 2]
		WAVE scanGraphWave = threadfWaves [nThreadWaves *iChan + 3]
		NVAR iChunk = dfr:iChunkG
		
		// copy ALL of scanned wave acq1D into 3D wave and remove negative data
		// acq3D = acq1d
		// acq3D = acq3D > 32767 ? 0: acq3D
		fastintCopy(acq1d, 0, acq3D, 0, chunkPoints, 1)
		
		if(flybackMode)
			SwapEven(acq3D)
		endif
		// copy ALL of 3D wave into appropriate offset of scanWave
		//startPlane = iChunk * chunkSize
		// scanGraphWave [*] [*] [startPlane, startPlane + chunkSize -1] = acq3D [p] [q] [r-startPlane] !@     #
		fastintCopy(acq3D, 0, scanWave, (iChunk * chunkPoints), chunkPoints, 1)
		
		
		// make an average of 3D stack and put in scanGraph wave
		KalmanSpecFrames(acq3D, 0, chunkSize-1, scanGraphWave, 0, 8)

		if(liveROI)
			WAVE LROIWave = threadfWaves [nThreadWaves*iChan + 4]
			ImageStats/M=1/GS={ LROIleft,LROIright,LROIbottom,  LROItop } scanGraphWave
			Rotate 1, LROIWave
			LROIWave [0] = V_avg
			if((liveRatio) &&(iChan == nChans-1))
				Rotate 1, LROIRatio
				LROIRatio [0] = topWave[0]/bottomWave[0]
			endif
		endif

		killdataFolder dfr
	endfor
	return 0
end

//*****************************************************************************************************************************
// structure for background function used for time series scan-at-once mode
// Last modified 2026/07/31 by Jamie Boyd
STRUCTURE timeSeriesBkgStruct
	STRUCT WMBackgroundStruct WMS
	uint32 taskTicks
	uint32 nChans
	uint32 chunkSize
	uint32 chunkPoints
	uint32 nChunks
	uint32 iChunk
	uint32 threadGroupID
EndStructure


//*****************************************************************************************************************************
// background function for time series scan-at-once mode where the whole stack is scanned into a 1D wave at once and a background
// task copies chunks of the 1d wave into a 3D wave for procesing, and then into the ScanWave 
// Last modified 2026/08/06 by Jamie Boyd
Function twoP_timeSeriesBkg(s)
	STRUCT timeSeriesBkgStruct &s
	
	SVAR selImageChanList=root:Packages:twoP:acquire:selImageChanList
	if(s.WMS.started)
		s.WMS.started = 0
		s.iChunk = 0
		s.nChans = ItemsInList(selImageChanList, ",")
		NVAR chunkSize = root:packages:twoP:acquire:tSeriesChunkSize
		s.chunkSize = chunkSize
		NVAR nChunks= root:packages:twoP:acquire:tSeriesNumChunks
		s.nChunks = nChunks
		NVAR pixWidth = root:packages:twoP:acquire:pixWidth
		NVAR pixHeight = root:packages:twoP:acquire:pixHeight
		s.chunkPoints = chunkSize * pixHeight * pixWidth
		NVAR gThreadGroupID = root:Packages:twoP:Acquire:gThreadGroupID
		s.threadGroupID = gThreadGroupID
		NVAR frameTime= root:packages:twoP:acquire:FrameTime
		s.taskTicks =ceil(60*frameTime * chunkSize)
		return 0
	endif
	
	SVAR imageBoard = root:packages:twoP:Acquire:ImageBoard
	variable nextAvailablePt = fDAQmx_ScanGetNextIndex(imageBoard)
	//print "Next available point = ", nextAvailablePt, "next chunk = ", floor (nextAvailablePt/s.chunkPoints), "iChunk =", s.iChunk
	variable iChan
	if ((((s.iChunk + 1) * s.chunkPoints) < nextAvailablePt) || (numType (nextAvailablePt) ==2))
		for(ichan =0; iChan < s.nChans; iChan +=1)
			newdatafolder/O :tdata
			variable/G :tdata:iChanG = iChan
			variable/G :tdata:iChunkG = s.iChunk
			ThreadGroupPutDF s.threadGroupID, :tdata
		endfor
		// increment chunk counter
		s.iChunk +=1
		// check if background task is falling behind 
		if ((((s.iChunk + 1) * s.chunkPoints) < nextAvailablePt) || (numType (nextAvailablePt) ==2))
			s.WMS.nextRunTicks = ticks + 1
		endif
		// post an RGB update request
		NVAR hasRGB = root:Packages:twoP:examine:RGB_hasRGB
		if(hasRGB)
			twoP_PostRGBChans (selImageChanList)
		endif
		// update percent complete
		NVAR PercentComplete=root:packages:twoP:Acquire:PercentComplete
		PercentComplete = 100*(s.iChunk/s.nChunks)
		// check for stopping
		NVAR wasAbort = root:Packages:twoP:Acquire:ScanStopOrAbort
		if ((s.iChunk ==  s.nChunks) || (wasAbort))
			if (wasAbort)
				NVAR iChunkG =root:Packages:twoP:Acquire:TSeriesiChunk		// save globally so we can use it to resize
				iChunkG = s.iChunk
			endif
			sleep /S 10e-03		// gives some time for threads to grab the last chunk of data
			twoP_EndScanning()
			twoP_EndScan (wasAbort)
			wasAbort = 0
			return 1		// to stop backgroud task
		endif
	else // background task is called before data was ready
		variable ticksTilNext =((s.chunkSize - mod(nextAvailablePt, s.chunkSize)) / s.chunkSize) * s.taskTicks
		//printf "added ticks = %d\r", ticksTilNext
		s.WMS.nextRunTicks = ticks + ticksTilNext
	endif
	return 0
end
	
//**************************************************************************************************
// Thread function for time series when all data is scanned at once into acq1D, and a chunk of acq1D at a time is copied into acq3D
// Last modified 2026/08/11 by Jamie Boyd
ThreadSafe Function twoP_timeSeriesAtOnceThread(threadfWaves, nChans, chunkSize, FramePoints, flybackMode, LiveROI, LROIleft, LROItop, LROIright, LROIbottom, liveRatio, TopChan, BottomChan)
	WAVE/WAVE threadfWaves
	variable nChans
	variable chunkSize
	variable FramePoints
	variable flybackMode
	variable liveROI
	variable LROIleft
	variable LROItop
	variable LROIright
	variable LROIbottom  
	variable liveRatio
	variable topChan
	variable bottomChan
	
	variable nThreadWaves = 5
	if (liveROI && liveRatio)
		WAVE LROIRatio = threadfWaves [nThreadWaves*nChans]
		WAVE topWave =  threadfWaves [topChan]
		WAVE bottomWave =  threadfWaves [bottomChan]
	endif
	
	variable chunkPoints = FramePoints * chunkSize
	variable chunkOffset
	
	for(;;)
		DFREF dfr = ThreadGroupGetDFR(0,inf)
		if (DataFolderRefStatus(dfr) ==0)
			break
		endif
		NVAR iChan = dfr:iChanG
		WAVE acq1D = threadfWaves [nThreadWaves*iChan]
		WAVE acq3D = threadfWaves [nThreadWaves*iChan + 1]
		WAVE scanWave = threadfWaves [nThreadWaves *iChan + 2]
		WAVE scanGraphWave = threadfWaves [nThreadWaves *iChan + 3]
		NVAR iChunk = dfr:iChunkG
		
		// copy chunk of scanned 1D wave into all of 3D wave and remove negative data
		chunkOffset = iChunk * chunkPoints
		//print "Thread iCHunk = ", iChunk, "chunk offset = ", chunkOffset
		//acq3D = acq1d [chunkOffset + (r * framePoints) + (q * pixHeight) + p]
		//acq3D = acq3D > 32767 ? 0: acq3D
		fastIntCopy(acq1d, chunkOffset, acq3D, 0, chunkPoints, 1)
		
		if(flybackMode)
			SwapEven(acq3D)
		endif
		// copy all of 3D wave into scanWave
		//startPlane = iChunk * chunkSize
		//scanWave [*] [*] [startPlane, startPlane + chunkSize -1] = acq3D [p] [q] [r-startPlane]
		fastIntCopy (acq3D, 0, scanWave, chunkOffset, 0,0)
		
		// make an average of 3D stack and put in scanGraph wave
		KalmanSpecFrames(acq3D, 0, chunkSize-1, scanGraphWave, 0, 8)

		if(liveROI)
			WAVE LROIWave = threadfWaves [nThreadWaves*iChan + 4]
			ImageStats/M=1/GS={ LROIleft,LROIright,LROIbottom,  LROItop } scanGraphWave
			Rotate 1, LROIWave
			LROIWave [0] = V_avg
			if((liveRatio) &&(iChan == nChans-1))
				Rotate 1, LROIRatio
				LROIRatio [0] = topWave[0]/bottomWave[0]
			endif
		endif

		killdataFolder dfr
	endfor
	return 0
end


// ************************************************************************************************
// ************************** Z Series Hook and Thread Functions *********************************
// ************************************************************************************************


// *************************************** twoP_zSeriesAtOnceHook ***************************************
// Repeated scan hook function when all frames for averaging are scanned at once
// Last modified 2026/07/31 by Jamie Boyd
Function twoP_zSeriesAtOnceHook (selImageChanList, numChans, gThreadGroupID, numFrames, StageProc, upNotDown)
	string selImageChanList
	variable numChans
	variable gThreadGroupID
	variable numFrames
	string StageProc
	variable upNotDown
	
	NVAR iFrame = root:Packages:twoP:Acquire:ZseriesiFrame	// for counting frames in stack
	variable iChan
	// post a folder to threads
	for(ichan =0; iChan < numChans; iChan +=1)
		newdatafolder/O :tdata
		variable/G :tdata:iChanG = iChan
		variable/G :tdata:iFrameG = iFrame
		ThreadGroupPutDF gThreadGroupID, :tdata
	endfor
	// increment frame counter
	iFrame +=1
	// move zAxis increment 
	if (iFrame < numFrames)
		StageStep(StageProc, "Z", upNotDown, 0)
	endif
	// post an RGB update request
	NVAR hasRGB = root:Packages:twoP:examine:RGB_hasRGB
	if(hasRGB)
		twoP_PostRGBChans (selImageChanList)
	endif
	// update percent complete
	NVAR PercentComplete=root:packages:twoP:Acquire:PercentComplete
	PercentComplete = 100*(iFrame/numFrames)
	// check if stopping, either because of scan end, or user aborting
	NVAR wasAbort = root:Packages:twoP:Acquire:ScanStopOrAbort
	if((iFrame == numFrames) ||(wasAbort))
		sleep /S 10e-03		// gives some time for threads to grab the last frame of data and insert it
		twoP_EndScanning()
		twoP_EndScan (wasAbort)
		wasAbort = 0
	endif
End

// *************************************** twoP_ZseriesAtOnceThread ***************************************
// thread function when all frames for averaging are scanned at once
// Last modified 2026/08/11 by Jamie Boyd
// Thread function for z Series with zAvgStackAtOnce.
Threadsafe Function twoP_ZseriesAtOnceThread(threadfWaves, framePoints, zAvgFrames, flybackMode)
	WAVE/WAVE threadfWaves
	variable framePoints
	variable zAvgFrames
	variable flybackMode
	
	variable numThreadWaves = 4
	variable chunkPoints = framePoints * zAvgFrames
	
	for(;;)
		DFREF dfr = ThreadGroupGetDFR(0,inf)
		NVAR iChan = dfr:iChanG
		WAVE acq1D = threadfWaves [iChan*numThreadWaves]
		WAVE acq3D = threadfWaves [iChan*numThreadWaves + 1]
		WAVE scanGraphWave =  threadfWaves [iChan*numThreadWaves + 2]
		WAVE scanWave =  threadfWaves [iChan*numThreadWaves + 3]
		NVAR iFrame = dfr:iFrameG

		// copy ALL of freshly acquired data in acq1D into acq3D.
		//acq3D = acq1D
		//acq3D = acq3D > 32767 ? 0: acq3D
		fastIntCopy (acq1D, 0, acq3D, 0, chunkPoints, 1)
		// average 3D stack into scanGraph
		KalmanSpecFrames (acq3D, 0, zAvgFrames-1, scanGraphWave, 0, 8)
		if (flybackmode)
			SwapEven(scanGraphWave)
		endif
		// copy scanGraph wave into ScanWave
		//scanWave [*] [*] [iFrame] = scanGraphWave [p] [q]
		fastIntCopy(scanGraphWave, 0, scanWave, (iFrame * framePoints), framePoints, 0)
		KillDataFolder dfr
	endfor
end


// *************************************** twoP_zSeriesKNextHook ***************************************
// Repeated scan hook function when frames for averaging are scanned one at a time and averaged with KalManNext
// Last modified 2026/07/31 by Jamie Boyd
Function twoP_zSeriesKNextHook(selImageChanList, numChans, gThreadGroupID, numFrames, zAvg, StageProc, upNotDown)
	string selImageChanList
	variable numChans
	variable gThreadGroupID
	variable numFrames
	variable zAvg
	string StageProc
	variable upNotDown
	
	NVAR iFrame = root:Packages:twoP:Acquire:ZseriesiFrame		// for counting frames in stack
	NVAR iAvg = root:Packages:twoP:Acquire:ZseriesiAvg			// for counting averages per frame (may be 1, for no averaging)
	
	variable iChan
	// post a folder to threads with iFrame and iAvg
	for(ichan =0; iChan < numChans; iChan +=1)
		newdatafolder/O :tdata
		variable/G :tdata:iChanG = iChan 
		variable/G :tdata:iFrameG = iFrame 
		variable/G :tdata:iAvgG = iAvg
		ThreadGroupPutDF gThreadGroupID, :tdata
	endfor
	
	// increment iAverage
	iAvg += 1
	if (iAvg == zAvg)
		iAvg = 0
		// move zAxis increment 
		if (iFrame < numFrames)
			StageStep(StageProc, "Z", upNotDown, 0)
		endif
		// post an RGB update request
		NVAR hasRGB = root:Packages:twoP:examine:RGB_hasRGB
		if(hasRGB)
			twoP_PostRGBChans(selImageChanList)
		endif
		iFrame +=1
		// check for live stop, or end of scan
		NVAR wasAbort = root:Packages:twoP:Acquire:ScanStopOrAbort
		if (wasAbort || (iFrame > numFrames))
			sleep /S 10e-03		// gives some time for threads to grab the last frame of data
			twoP_EndScanning()
			twoP_EndScan (wasAbort)
			wasAbort = 0
		endif
	endif
End

	
// ************************************** twoP_ZseriesKNextThread **********************************************************
// Thread function for z Series when not zAvgStackAtOnce. Every image is acquired separately, and averaged with KalmanNext
// Last modified 2026/08/11 by Jamie Boyd
Threadsafe Function twoP_ZseriesKNextThread(threadfWaves, FramePoints, zAvgFrames, flybackMode)
	WAVE/WAVE threadfWaves
	variable FramePoints
	variable zAvgFrames
	variable flybackMode
	
	variable nThreadWaves= 4
	for(;;)
		DFREF dfr = ThreadGroupGetDFR(0,inf)
		NVAR iChan = dfr:iChanG
		WAVE acq1D = threadfWaves [iChan * nThreadWaves]
		WAVE acq2d = threadfWaves [iChan * nThreadWaves + 1]
		WAVE scanGraphWave = threadfWaves [iChan * nThreadWaves + 2]
		WAVE scanWave = threadfWaves [iChan * nThreadWaves + 3]
		NVAR iFrame = dfr:iFrameG
		NVAR iAvg = dfr:iAvgG

		// copy all of freshly acquired data in acq1D into acq2d
		//acq2d = acq1D
		//acq2d = acq2d > 32767 ? 0: acq2d
		FastIntCopy(acq1D, 0, acq2d, 0, FramePoints, 1)
		if (flybackmode)
			SwapEven(acq2d)
		endif
		// Klaman next into scan Graph wave
		KalmanNext(acq2d, scanGraphWave, iAvg)
		// if end of frame, copy scanGraphWave into ScanWave
		if (iAvg == (zAvgFrames - 1))
			// scanWave [*] [*] [iFrame] = scanGraphWave [p] [q]
			fastIntCopy (scanGraphWave, 0, scanWave, (iFrame * FramePoints), FramePoints, 0)
		endif
		KillDataFolder dfr
	endfor
end


// ************************************************************************************************
// *********************** Functions Called by All Hook Functions **********************
// ************************************************************************************************


//****************************** twoP_PostRGBChans *************************************************
// Posts a request to the thread that copies data into the RGB wave on the ScanGraph
// only requests a color plane for which we have the needed channel in our list of channels
function twoP_PostRGBChans(selImageChanList)
	string selImageChanList

	NVAR rgbThreadGroupID =root:packages:twoP:examine:rgbThreadGroupID
	SVAR redChan = root:packages:twoP:examine:RGB_RedChan
	SVAR greenChan = root:packages:twoP:examine:RGB_GreenChan
	SVAR blueChan = root:packages:twoP:examine:RGB_BlueChan
	variable toDo =0
	if (WhichListItem(redChan, selImageChanList, ",") > -1)
		toDo += 1
	endif
	if (WhichListItem(greenChan, selImageChanList, ",") > -1)
		toDo += 2
	endif
	if (WhichListItem(blueChan, selImageChanList, ",") > -1)
		toDo += 4
	endif
	if (toDo)
		newdatafolder/O :tdata
		variable/G :tdata:toDoG = toDo
		ThreadGroupPutDF rgbThreadGroupID, :tdata
	endif
end


// ************************************************************************************************
// *********************** Functions Called when A Scan Stops **********************
// ************************************************************************************************

// ************************************** twoP_EndScan **********************************************************
// called by the scan hook functions at end of scan. 
// Last Modified 2026/08/13 by Jamie Boyd
function twoP_EndScan (isAbort)
	variable isAbort // 0 if not abort, 1 if aborted after some scanning has ocurred, 2 if aborted wih no data

	NVAR scanMode = root:packages:twoP:acquire:scanMode
	SVAR newScanName=root:packages:twoP:acquire:NewScanName
	NVAR percentComplete=root:packages:twoP:Acquire:PercentComplete

	if (isAbort == 1)  // aborted with some data
		twoP_EndScanResize()
	endif

	// reset percent complete used by setvariable
	percentComplete = 0
	// reset start button
	Button AqStartButton, win = twoP_Controls, title="Start",fColor=(0, 65280, 0)
	if (scanMode == kMultiAq)
		Button AqStartButton, win = twoP_Controls, proc=twoP_ScanStartMultiProc
	else
		Button AqStartButton, win = twoP_Controls,proc= twoP_ScanStartSingleProc
	endif

	//  switch to examine side of things unless no data, or live scanning, or multiaq
	if (!((isAbort == 2) || (scanMode == kLiveMode) || (scanMode == kMultiAq)))
		GUIPTabClick("twoP_Controls", "AcquireExamineTab", "Examine")
		twoP_ScanAdjustExamineControls(newScanName)
	endif
	// things we don't do for live mode
	if (ScanMode != kLiveMode)
		// for triggered scans, or for multAq, startTime in scanINfo needs correcting
		NVAR wasTriggered = root:packages:twoP:acquire:inputTriggerCheck
		if ((scanMode == kMultiAq) || (wasTriggered))
			NVAR startTime = root:packages:twoP:acquire:MultiAqStartTime
			SVAR scanStr = $"root:twoP_Scans:" + newScanName + ":" + newScanName + "_info"
			scanStr = ReplaceNumberByKey("ExpTime", scanStr, startTime , ":", "\r")
		endif
		// save scan?
		NVAR toDo=root:packages:twoP:acquire:exportAfterScan
		if(toDo)
			twoP_ExportAfterScan(toDo)
		endif
		// increment wave name?
		NVAR autincCheck = root:packages:twoP:Acquire:autIncCheck
		if (autIncCheck)
			SVAR NewScanName =  root:packages:twoP:Acquire:NewScanName
			NewScanName = twoP_ScanNameInc(NewScanName, 1)
		endif
	endif

	// if multi, get ready for next scan
	// turnaround for multiAcq
	if (scanMode == kMultiAq)
		if (isAbort)
			// stop background task
			CtrlNamedBackground multiScanBKG, Stop
			Button AqStartButton, win = twoP_Controls, disable =2
		else
			// prepare for next scan
			twoP_EndScanMulti()
		endif
	endif
end


//******************************************************************************************************
// End-of-Scan function when doing ePhys only. This is called when scanning completes 
// last modified 2026/08/13 by Jamie Boyd
function twoP_EndScanEphysOnly()

	twoP_EndScanning()
	twoP_EndScan(0)
end


//******************************************************************************************************
// Does multiAq stuff at end of a scan, making waves for next scan, moving galvos to start positions
// increments counters for scans, 
// for timed modes, does eveything but start the threads and scan init. For threaded mode, does those as well
// last modified 2026/08/13 by Jamie Boyd
function twoP_EndScanMulti()
	
	// Count will be incremented already - so don't increment here
	NVAR multiAqiAq = root:packages:twoP:acquire:multiAqiAq 
	NVAR multiAqnAqs = root:packages:twoP:acquire:multiAqnAqs
	// Update progress display
	ValDisplay multiAqProgressDisplay win = twoP_Controls, value=_NUM:multiAqiAq
	if (multiAqiAq == multiAqnAqs)
	// !@# do something here?
	else	// prepare for next scan
		// Load scan struct
		STRUCT twoP_scanStruct s
		twoP_scanLoadStruct(s)
		// Move to start of stack
		SVAR stageProc = root:packages:twoP:acquire:stageProc
		if (s.scanMode == kzSeries)	// move stage to start of zStack and set step size to slice thickness
			NVAR zFirstZ = root:Packages:twoP:Acquire:ZFirstZ
			StagesSetAbsAxis(stageProc, "Z", zFirstZ, kStagesReturnAfter)
		endif
		// set Horizontal galvo to start of X galvo waves
		WAVE HorWave=root:Packages:twoP:acquire:HorWave
		fDAQmx_WriteChan(s.ImageBoard, 0, HorWave [0], -10, 10)
		//  Set Vertical galvo to right Y position for line scan, or to start of Y galvo wave
		if (s.scanMode != kLineScan)
			// set Horizontal galvo to start of X galvo waves - already in correct place for a line scan
			WAVE VerWave=root:Packages:twoP:acquire:VerWave
			fDAQmx_WriteChan(s.ImageBoard, 1, VerWave [0], -10, 10)
		endif
		// make scan wave, if needed, and set current scan
		SVAR multiAcqScanList = root:packages:twoP:acquire:multiAcqScanList
		s.newScanName = stringFromList (multiAqiAq, multiAcqScanList, ";")
		if (!(s.multiAqPremake))
			twoP_ScanMakeScanWaves(s)
		endif

		// copy and edit scan Note
		SVAR multiAcqScanNote= root:packages:twoP:acquire:multiAcqScanNote
		string/G $"root:twoP_Scans:" + s.newScanName + ":" + s.newScanName + "_info" = multiAcqScanNote
		SVAR noteStr =  $"root:twoP_Scans:" + s.newScanName + ":" + s.newScanName + "_info"
		noteStr = ReplaceNumberByKey("multiAq_i", noteStr, multiAqiAq , ":", "\r")
		// adjust scanGraph
		STRUCT WMPopupAction pa
		pa.eventCode = 2
		pa.popStr = stringfromlist(multiAqiAq, multiAcqScanList, ";")
		twoP_ScanPopMenuProc(pa)
		// Zero globals for counting line, frames, averages, chunks, as specific to each scan mode
		if(s.scanmode != kephysOnly)
			twoP_ScanZeroGlobals(s)
		endif
		if (s.multiAqTimeMode == kMultiUseTrigger)
			twoP_ScanStartThreads(s)
			twoP_InitScan(s)
		endif
	endif
end

// **************************************************************************************************
// resizes scan waves for when a scan is aborted. An aborted scan is still a scan, just shorter
// Last Modified 2026/07/30 by Jamie boyd
function twoP_EndScanResize()
	
	NVAR scanMode = root:packages:twoP:acquire:scanMode
	SVAR scanName = root:Packages:twoP:acquire:NewScanName
	SVAR infoStr= $"root:twoP_Scans:" + scanName +  ":" + scanName + "_info"
	string aChan, chanList = StringByKey("imChanDesc", infoStr, ":", "\r")
	
	variable iChan, numChans=ItemsInList (chanList, ",")
	variable pixWidth = NumberByKey("PixWidth", infoStr, ":", "\r")
	variable pixHeight = NumberByKey("PixHeight", infoStr, ":", "\r")
	variable flyBackMode = NumberByKey("FlyBackMode", infoStr, ":", "\r")
	string ePhysChanList = StringByKey("ePhysChanDesc", infoStr, ":", "\r")
	variable numEphysChans = ItemsInList (ePhysChanList, ",")
	variable ePhysTime, ePhysFreq, ePhysPoints, lastPt, wavePts
	switch (scanMode)
		case kSingleImage:
			NVAR updateAsCollected = root:packages:twoP:acquire:AvgDoUpdate
			if (!(updateAsCollected))	// only neeed resizing if doing scan-at-once.
				// Look for end of non-zero data to get estimate of when we got aborted
				WAVE acq1D = $"root:packages:twoP:acquire:Acq1D_" + stringfromlist(0, chanList, ",")
				wavePts = numpnts (acq1D)
				for (lastPt = wavePts -1 ; acq1D [lastPt] == 0 && lastPt > 0; lastPt -= 1)
				endfor
				variable frameSize = (pixWidth * pixHeight)
				variable lastFrame = floor (lastPt/frameSize)
				if (lastFrame == 0)
					GUIPkillWholeDatafolder("root:twoP_Scans:" + scanName)
				else
					infoStr  = ReplaceNumberByKey("NumFrames", infoStr, lastFrame, ":", "\r")
					for(ichan =0; iChan < numChans; iChan +=1)
						aChan = stringFromList(iChan, chanList, ",")
						WAVE acq1D = $"root:packages:twoP:acquire:Acq1D_" + aChan
						WAVE acq3D = $"root:packages:twoP:acquire:Acq3D_" + aChan
						WAVE scanWave =  $"root:twoP_Scans:" + scanName +  ":" + scanName + "_" + aChan
						redimension/N=(lastFrame * frameSize) acq1D
						redimension/n=((pixWidth), (pixHeight), (lastFrame)) acq3D, scanWave
						acq3D = acq1d
						acq3D = acq3D > 32767 ? 0: acq3D
						KalmanSpecFrames(acq3D, 0, lastFrame-1, scanWave, 0, 8)
						if(flybackMode)
							SwapEven(scanWave)
						endif
					endfor
					// post an RGB update request
					NVAR hasRGB = root:Packages:twoP:examine:RGB_hasRGB
					if(hasRGB)
						twoP_PostRGBChans (chanList)
					endif
				
				endif
			endif
			break
			
		case kLineScan:
			NVAR lastChunk = root:packages:twoP:acquire:LSiChunk				// set by repeat scan hook or bkgTask
			if (lastChunk == 0)
				GUIPkillWholeDatafolder("root:twoP_Scans:" + scanName)
			else
				NVAR lScanChunkSize = root:packages:twoP:acquire:LSChunkSize	// number of lines to acquire at a time
				variable lastLine = lastChunk * lScanChunkSize
				infoStr  = ReplaceNumberByKey ("PixHeight", infoStr, lastLine, ":", "\r")
				for(ichan =0; iChan < numChans; iChan +=1)
					aChan = stringFromList(iChan, chanList, ",")
					WAVE scanWave= $"root:twoP_Scans:" + scanName +  ":" + scanName + "_" + aChan
					redimension/n=((pixWidth), (lastLine)) scanWave
				endfor
				if (numEphysChans > 0)
					NVAR lineTime = root:packages:twoP:acquire:lineTime
					ePhysTime = lastLine * lineTime
					ePhysFreq = numberByKey ("ePhysFreq", infoStr, ":", "\r")
					ePhysPoints = ePhysTime * ePhysFreq
					for(ichan =0; iChan < numEphysChans; iChan +=1)
						aChan = stringFromList(iChan, chanList, ",")
						WAVE scanWave= $"root:twoP_Scans:" + scanName +  ":" + scanName + "_" + aChan
						redimension/n=(ePhysPoints) scanWave
					endfor
				endif
			endif
			break
	
		case kTimeSeries:
			NVAR lastChunk = root:Packages:twoP:Acquire:TSeriesiChunk 			// set by repeat scan hook or bkgTask
			if (lastChunk == 0)
				GUIPkillWholeDatafolder("root:twoP_Scans:" + scanName)
			else
				NVAR scanChunkSize = root:packages:twoP:acquire:tSeriesChunkSize	// number of lines to acquire at a time
				lastFrame = lastChunk * scanChunkSize
				infoStr  = ReplaceNumberByKey ("NumFrames", infoStr, lastFrame, ":", "\r")
				for(ichan =0; iChan < numChans; iChan +=1)
					aChan = stringFromList(iChan, chanList, ",")
					WAVE scanWave= $"root:twoP_Scans:" + scanName +  ":" + scanName + "_" + aChan
					redimension/n=(pixWidth, pixHeight, lastFrame) scanWave
				endfor
				if (numEphysChans > 0)
					NVAR frameTime = root:packages:twoP:acquire:frameTime
					ePhysTime = lastFrame * frameTime
					ePhysFreq = numberByKey ("ePhysFreq", infoStr, ":", "\r")
					ePhysPoints = ePhysTime * ePhysFreq
					for(ichan =0; iChan < numEphysChans; iChan +=1)
						aChan = stringFromList(iChan, chanList, ",")
						WAVE scanWave= $"root:twoP_Scans:" + scanName +  ":" + scanName + "_" + aChan
						redimension/n=(ePhysPoints) scanWave
					endfor
				endif
			endif
			break
			
		case kZSeries:
			NVAR lastZFrame = root:Packages:twoP:Acquire:ZseriesiFrame
			if (lastZFrame ==0)
				GUIPkillWholeDatafolder("root:twoP_Scans:" + scanName)
			else
				infoStr  = ReplaceNumberByKey ("NumFrames", infoStr, lastZFrame, ":", "\r")
				for(ichan =0; iChan < numChans; iChan +=1)
					aChan = stringFromList(iChan, chanList, ",")
					WAVE scanWave= $"root:twoP_Scans:" + scanName +  ":" + scanName + "_" + aChan
					redimension/n=(pixWidth, pixHeight, lastZFrame) scanWave
				endfor
			endif
			break
	endSwitch
End


// **************************************************************************************************
// Closes the shutter and shuts down all the functions on the NIDAQ boards, and releases threads
// Last Modified 2026/08/13 by Jamie boyd
Function twoP_EndScanning()
	// get scan mode
	NVAR scanMode = root:packages:twoP:acquire:scanStartMode
	if(ScanMode != kEphysOnly)
		// close the shutter
		SVAR imageBoard = root:packages:twoP:Acquire:imageBoard
		NVAR shutterTaskNum = root:packages:twoP:Acquire:shutterTaskNum
		NVAR shutterOpenLevel = root:Packages:twoP:acquire:shutterOpenLevel
		fDAQmx_DIO_Write(imageBoard, shutterTaskNum,(!(shutterOpenLevel)))
		// stop scanning
		fDAQmx_ScanStop(imageBoard)
		// Stop the waveform Generator
		fDAQmx_WaveformStop(imageBoard)
		// stop the counters
		fDAQmx_CTR_Finished(imageBoard, 0)
		// release the threads
		NVAR gThreadGroupID = root:packages:twoP:Acquire:gThreadGroupID
		gThreadGroupID = threadgroupRelease(gThreadGroupID)
		// stop background tasks - no error stopping a task that is not currently running, so don't check which are running
		CtrlNamedBackground LineScanTask stop
		CtrlNamedBackground tSeriesTask stop
	endif
	SVAR ePhysBoard = root:packages:twoP:Acquire:ePhysBoard
	if(cmpStr(ePhysBoard, "") != 0)
		fDAQmx_ScanStop(ePhysBoard)
		// Stop the waveform Generator
		fDAQmx_WaveformStop(ePhysBoard)
		// stop the counters
		fDAQmx_CTR_Finished(ePhysBoard, 0)
		fDAQmx_CTR_Finished(ePhysBoard, 1)
	endif
end

// **************************************************************************************************
// Error hook that runs when a scan is aborted by a NIDAQmx function
Function twoP_EndScanErr(scanMode)
	variable scanMode
	
	string errStr =fdaqMx_ErrorString()
	twoP_EndScanning()
	printf "Scanning was aborted because a NIDAQmx error occured. The error message was:\r%s\r",  errStr
end


scanStructStr

STRUCTURE twoP_MultiBkgStruct
	STRUCT WMBackgroundStruct WMS
	uint32 nAcqs 
	uint32 ScanDurationTicks	// time it takes to do a scan
	uint32 NextScanTickCount	// tick count when we do next scan
	uint32 DoScan
	uint32 ScanDone
EndStructure 


//******************************************************************************************************
//background task for multi-acquisition
// default period is 1 sec., to count down time to next scan
// when we are less than 1.5 seconds away from scan start, we set next call to next ticks and start the scan
// on the next call. When we start the scan, we don't start calling the task again till after the scan is over.
// Last Modified 2015/04/13 by Jamie Boyd
Function twoP_MultiBkg(s)
	STRUCT twoP_MultiBkgStruct &s
	
	NVAR iAcq = root:packages:twoP:acquire:multiAqiAq	// will be zeroed at multiAqinit so don't do it here
	if(s.WMS.started)
		s.WMS.started = 0
		// load a scan struct
		//twoP_ScanLoadStruct(s.t)
		// get number of acquisitions
		NVAR nAqs = root:packages:twoP:acquire:multiAqnAqs 
		s.nAcqs = nAqs
		// get nhow long a scan takes in ticks
		NVAR runTime = root:packages:twoP:acquire:runTime
		s.ScanDurationTicks = (runTime * 60) + 30
		// make wave with tick counts in real time ticks
		WAVE maq_seconds =root:packages:twoP:acquire:multiAqWaves:maq_seconds
		duplicate/o maq_seconds  root:packages:twoP:acquire:multiAqWaves:maq_ticks
		WAVE maq_ticks = root:packages:twoP:acquire:multiAqWaves:maq_ticks
		maq_ticks *= 60
		maq_ticks += ticks
		s.NextScanTickCount = maq_ticks [0]
		s.DoScan = 0
		s.ScanDone = 0
		return 0
	endif
	if (s.DoScan)		// time to do a scan
		s.DoScan = 0
		s.ScanDone = 1
		s.WMS.nextRunTicks = ticks + s.ScanDurationTicks
		TitleBox MultiAqTimeToNextTitle win = twoP_Controls, title="Scanning..."
		SVAR imageBoard= root:packages:twoP:acquire:imageBoard
		SVAR ephysBoard = root:packages:twoP:acquire:ePhysBoard
		SVAR selImageChanList = root:packages:twoP:acquire:selImageChanList
		SVAR selEphysCHanList = root:packages:twoP:acquire:selEphysChanList
		SVAR ImScanList = root:packages:twoP:acquire:multiAcqImScanList
		SVAR ePhysScanList = root:packages:twoP:acquire:multiAcqEphysScanWaveList
		// enable start button
		SVAR ScanStructStr = root:packages:twoP:acquire:multiAcqScanStructStr 
		STRUCT twoP_scanStruct t
		StructGet/S t, ScanStructStr
		t.imageBoard = imageBoard
		t.ephysBoard = ephysBoard
		t.selImageChanList = selImageChanList
		t.selEphysChanList = selEphysChanList
		t.scanWavePath = ImScanList
		t.ePhysPath = ePhysScanList
		twoP_ScanStartThreads(t)
		twoP_InitScan(t)
		return 0
	elseif (s.ScanDone)		// first time being invoked after doing a scan
		s.ScanDone = 0
		iAcq += 1
		ValDisplay multiAqProgressDisplay win = twoP_Controls, value=_NUM:iAcq
		if (iAcq == s.nAcqs)
			TitleBox MultiAqTimeToNextTitle win = twoP_Controls, title="Done" // !@# - other adjustments??
			return 1		
		else
			WAVE maq_ticks = root:packages:twoP:acquire:multiAqWaves:maq_ticks
			s.NextScanTickCount = maq_ticks [iAcq]
			TitleBox MultiAqTimeToNextTitle win = twoP_Controls, title="Time to Next Scan: " + twoP_MultiFormatSeconds((s.NextScanTickCount - ticks)/60)
			return 0
		endif
	else				// Is it time to do a scan?
		variable currentTicks = ticks
		variable ticksToNext = (s.NextScanTickCount - currentTicks)
		if (ticksToNext < 90)
			s.DoScan = 1
			if (ticksToNext <= 0)
				s.WMS.nextRunTicks = currentTicks + 1
			else
				s.WMS.nextRunTicks = s.NextScanTickCount
			endif
		endif
		TitleBox MultiAqTimeToNextTitle win = twoP_Controls, title="Time to Next Scan: " + twoP_MultiFormatSeconds( ticksToNext/ 60)
		return 0
	endif
end




// ***********************************************************************
// Does a hardware reset of the NI boards and sets up image board shutter. Sets trigger outputs on ephys board to low state
// Last Modified 2025/08/11 by Jamie boyd
Function twoP_ReSetBoards()
	SVAR ImageBoard = root:packages:twoP:acquire:ImageBoard
	SVAR ephysBoard = root:packages:twoP:acquire:ephysBoard
	NVAR shutterTaskNum = root:packages:twoP:Acquire:shutterTaskNum
	NVAR shutterOpen = root:Packages:twoP:acquire:shutterOpenLevel
	NVAR triggerTaskNum =  root:packages:twoP:Acquire:triggerTaskNum
	NVAR Trig1Polarity = root:packages:twoP:acquire:Trig1Polarity
	NVAR Trig2Polarity = root:packages:twoP:acquire:Trig2Polarity
	
	// clear error message Chunk
	for(;(cmpStr(fdaqmx_errorString(), "") != 0);)
	endfor
	
	try
		AbortOnValue fDAQmx_ResetDevice(ImageBoard), 0
		// configure shutter on port 0/line 0 and set it closed
		DAQmx_DIO_Config /DEV=ImageBoard/Dir=1/LGRP=1  "/" + ImageBoard + "/port0/line0" ;AbortOnRTE
		shutterTaskNum = V_DAQmx_DIO_TaskNumber
		AbortOnValue fDAQmx_DIO_Write(ImageBoard, shutterTaskNum,(!(shutterOpen))), 0
		// configure trigger input task on port 0/line 1
		DAQmx_DIO_Config /DEV=ImageBoard/DIR= 0/LGRP=1  "/" + ImageBoard +"/port0/line1";AbortOnRTE
		triggerTaskNum = V_DAQmx_DIO_TaskNumber
		if(CmpStr(ephysBoard, "") != 0)
			AbortOnValue fDAQmx_ResetDevice(ePhysBoard), 0
			// set an initial dummy counter task just to put outputs in low state
			DAQmx_CTR_OutputPulse /DEV=ephysBoard/SEC={1e-6, 1e-6} /IDLE=(Trig1Polarity) /NPLS=1/STRT=0(0) ; AbortOnRTE
			AbortOnValue fDAQmx_CTR_Finished(ephysBoard, 0), 0
			DAQmx_CTR_OutputPulse /DEV=ephysBoard/SEC={1e-6, 1e-6} /IDLE=(Trig2Polarity) /NPLS=1/STRT=0(1) ; AbortOnRTE
			AbortOnValue fDAQmx_CTR_Finished(ephysBoard, 1), 0
		endif
	catch
		return 1
	endtry
	
	return 0
end


//****************************** twoP_ZeroGalvos *************************************************
// Sets the output voltage on the galvos to 0, used for beam alignment 
function twoP_ZeroGalvos()
	SVAR imageboard = root:Packages:twoP:acquire:imageBoard
	fDAQmx_WriteChan(imageBoard, 0, 0, -10, 10)
	fDAQmx_WriteChan(imageBoard, 1, 0, -10, 10)
end





function scantest(boardName)
	string boardName
	
	
	variable pixHz = 2500		// clock frequency in Hz
	variable pixtime=1/pixHz	// time between scanning individual pixels, in seconds
	// make wave for voltage output, as for output to galvos, but only 8 points used here for testing
	make/o/s/n=8 wout = {-4, -3, -2, -1, 1, 2, 3, 4}
	WAVE wout = wout
	// The scaling here sets the rate of scanning, both galvo output and A/D input
	setscale/p x 0, pixTime, "s",  wout 
	// make input wave, as for A/D from PMT, but only 5 points, we will use pause trigger with 5 high, 3 low
	make/o/s/n=5 win
	WAVE win=win
	// input scaling does not control scanning rate, but it must be "reasonable" or DAQmx_Scan complains 
	setscale/p x 0, pixTime, "s", win 
	// make pause trigger (line clock) for input scanning using counter 0. idles low
	// use RTSI 5 as time base. RTSI5 will be ao/SampleClock. 
	// export pause trigger to RTSI6
	DAQmx_CTR_OutputPulse /DEV=boardName/TICK={5, 3} /IDLE=0 /NPLS=0/TBAS="/" + boardName + "/RTSI5"/Rate=(pixHz) 0
	fDAQmx_ConnectTerminals("/" + boardName + "/ctr0InternalOutput", "/" + boardName + "/RTSI6", 0) 
	// the waveform generator will do repeated output with wave wout on channel 0
	// send the sample clock to RTSI5, where it is used to generate pause trigger (line clock)
	fDAQmx_ConnectTerminals("/" + boardName + "/ao/SampleClock", "/" + boardName + "/RTSI5", 0)
	// start repeated input scanning with RTSI 5 (ao/Sample clock) as input clock and RTSI 6 (line gate) as pause trigger.
	DAQmx_Scan /DEV=boardName/BKG=1/CLK={"/" + boardName + "/RTSI5", 1}/PAUS={ "/" + boardName + "/RTSI6", 1,0} /RPTC WAVES = "win, 3/RSE,-10, 10;"
	DAQmx_WaveformGen /DEV=boardName /BKG=0/NPRD=0/Strt=1   "wout, 0;"
	// optonally, connect ao/Sample clock and ai/SampleClock to output pins for verification
	fDAQmx_ConnectTerminals("/" + boardName + "/ao/SampleClock", "/" + boardName + "/PFI5", 0)  // high-to-lo pulses
	fDAQmx_ConnectTerminals("/" + boardName + "/ai/SampleClock", "/" + boardName + "/PFI7", 0)  //  lo-to-high pulses
end

function scanEnd(boardName)
	string boardName
	fDAQmx_CTR_Finished(boardName, 0)	// stops the line gate counter
	fDAQmx_WaveformStop(boardName)		// stops repeated waveform output
	fDAQmx_ScanStop(boardName)			// stops repeated data acquisition
end
