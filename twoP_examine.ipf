#pragma rtGlobals=3
#pragma IgorVersion = 6.2
#pragma version = 2.0  // Last Modified 2017/08/14 by Jamie Boyd

#include <SaveRestoreWindowCoords>
#include "twoP_ExConstants"
#include "GUIPControls"
#include "GUIPList"
#include "GUIPProtoFuncs"
#include "GUIPbackgrounder"
#include "GUIPSubWinUtils"
#include "GUIPKillDisplayedWave"

// The latest versions of these include files can be found in the "GUIP" folder in the User Procedures folder in the Igor Pro folder



//******************************************************************************************************
// Let's put  function to make the  panel in the macros menu.
// also functions to add and remove examine tabs
Menu "Macros"
	Submenu "twoP"
		"twoP Panel", /Q, NQ_MakeNidaqPanel (1)
		Submenu "Examine"
			"Add a Tab to the Examine TabControl",/Q ,NQ_AddExTab ()
			"Remove a Tab from the Examine TabControl",/Q, NQ_RemoveExTab ()
		end
	end
End

//******************************************************************************************************
// Graph Marquee functions to do useful things on the scan graph
Menu "GraphMarquee"
	Submenu "twoP Examine"
		"Draw Scale Bar",/Q, NQ_DrawScaleBar()
		"Measure Object",/Q, NQ_MeasureMarquee()
	end
end

//******************************************************************************************************
// Makes globals for Examine tab functions of the Nidaq Controls panel
// Last Modified Nov 209 2011 by Jamie Boyd
Function NQ_MakeExamineFolder ()

	if (DataFolderexists ("root:Packages:twoP:examine"))
		return 1
	else
		if (!(DataFolderExists ("root:packages")))
			NewDataFolder root:Packages
		endif
		if (!(DataFolderExists ("root:packages:twoP")))
			NewDataFolder root:Packages:twoP
		endif
	endif
	NewDataFolder root:Packages:twoP:examine
	//String that stores the name of the current scan, and display it in a title box on the Examine Panel
	string/g root:Packages:twoP:examine:curScan = "no current scan"	
	// Variable for scan numbers, when scans are sequentially numbered
	variable/G root:packages:twoP:Examine:curScanNum
	// Wave is used by the ListBox on the Examine Panel to display the experiment note of the currently selected scan.
	make/t/n=0 root:Packages:twoP:examine:NoteListWave	
	// Waves for Histograms
	make/o/n = (2^kNQimageBits) root:Packages:twoP:Examine:HistWaveCh1,root:Packages:twoP:Examine:HistWaveCh2
	WAVE HistWaveCh1 = root:Packages:twoP:Examine:HistWaveCh1
	WAVE HistWaveCh2 = root:Packages:twoP:Examine:HistWaveCh2
	setscale/p x, 0, 1	, "", HistWaveCh1, HistWaveCh2
	// Waves for sliders on the histogram
	make/o root:Packages:twoP:examine:ImRangeLeftxCh1 = {(0.05 * 2^kNQimageBits), (0.05 * 2^kNQimageBits)}
	make/o root:Packages:twoP:examine:ImRangeLeftyCh1 = {1,inf}
	make/o root:Packages:twoP:examine:ImRangeRightxCh1 = {(0.95 * 2^kNQimageBits) ,(0.95 * 2^kNQimageBits)}
	make/o root:Packages:twoP:examine:ImRangeRightyCh1 = {1,inf}
	make/o root:Packages:twoP:examine:ImRangeLeftxCh2 = {(0.05 * 2^kNQimageBits), (0.05 * 2^kNQimageBits)}
	make/o root:Packages:twoP:examine:ImRangeLeftyCh2 = {1,inf}
	make/o root:Packages:twoP:examine:ImRangeRightxCh2 = {(0.95 * 2^kNQimageBits) ,(0.95 * 2^kNQimageBits)}
	make/o root:Packages:twoP:examine:ImRangeRightyCh2 = {1,inf}
	// Values to control which channels to show in the ScanGraph
	variable/G root:packages:twoP:examine:showCh1 = 1
	variable/G root:packages:twoP:examine:showCh2 =0
	variable/G root:packages:twoP:examine:showMerge =0
	variable/G root:packages:twoP:examine:ShowScanGraphAxes
	// Waves to show frames from 3D waves in the scanGraph
	make/w/u/o/n = (512,512) root:packages:twoP:examine:scanGraph_ch1
	make/w/u/o/n = (512,512) root:packages:twoP:examine:scanGraph_ch2
	make/w/u/o/u/n = (512,512,3) root:packages:twoP:examine:scanGraph_mrg
	// Values to control image appearance with look up table
	// First and last colors correspond to max range of a 12 bit digitizer minus one on each end to show floor/ceiling
	// NB: modified 2016/11/08 to use unsigined integers, with some dodgy acquisition tricks
	variable/G root:Packages:twoP:examine:Ch1FirstLUTColor = 1
	variable/G root:Packages:twoP:examine:Ch1LastLUTColor =  (2^kNQimageBits)-2
	variable/G root:Packages:twoP:examine:Ch1CTable = 1 // Grays
	string/G  root:Packages:twoP:examine:Ch1CTableStr ="Grays"
	variable/G root:Packages:twoP:examine:Ch1LUTInvert = 0 //  don't invert
	variable/G root:Packages:twoP:examine:Ch1BeforeMode = 1 // 0 means first color, 1 means selected color, 2 means transparent
	String/G root:Packages:twoP:examine:Ch1BeforeColors = "0,0,65535" // blue
	variable/G root:Packages:twoP:examine:Ch1AfterMode = 1 // 0 means first color, 1 means selected color, 2 means transparent
	String/G root:Packages:twoP:examine:Ch1AfterColors = "65535,0,0" // red
	variable/G root:Packages:twoP:examine:Ch2FirstLUTColor = 1
	variable/G root:Packages:twoP:examine:Ch2LastLUTColor = (2^kNQimageBits)-2
	variable/G root:Packages:twoP:examine:Ch2CTable = 1 // Grays
	string/G  root:Packages:twoP:examine:Ch2CTableStr ="Grays"
	variable/G root:Packages:twoP:examine:Ch2LUTInvert = 0//  don't invert
	variable/G root:Packages:twoP:examine:Ch2BeforeMode = 1 // 0 means first color, 1 means selected color, 2 means transparent
	String/G root:Packages:twoP:examine:Ch2BeforeColors = "0,0,65535" // blue
	variable/G root:Packages:twoP:examine:Ch2AfterMode = 1 // 0 means first color, 1 means selected color, 2 means transparent
	String/G root:Packages:twoP:examine:Ch2AfterColors = "65535,0,0" // red
	variable/G root:packages:twoP:Examine:Ch1LUTAuto =0 // 1 means set LUT to autoscale, 0 means use given first and last values
	variable/G root:packages:twoP:Examine:Ch2LUTAuto =0
	// Window Size/Positions. The default size is set here, and then modified.
	if (!(datafolderexists("root:packages:SavedWins")))
		if (!(datafolderexists ("root:packages")))
			newdatafolder root:packages
		endif
		newdatafolder root:packages:SavedWins
	endif
	string/g root:Packages:savedWins:twoPscanGraph_pos= kNQScanGraphPos//holds the window size and position for the Graph showing the Scan image. So it can be reapplied next time. 
	string/g root:Packages:savedWins:twoP_TracesGraph_pos= kNQTracesGraphPos	//holds the window size and position for the Graph showing the ROI and ePhys Traces. So it can be reapplied next time
	string/G root:Packages:savedWins:twoP_HistGraph_pos=kNQHistGraphPos    // holds the window size and position for the Graph showing image histograms
	// variables used for making the movie run in the background
	variable/g root:Packages:twoP:examine:Numframes	// The number of Frames in the current movie
	variable/g root:Packages:twoP:examine:CurFramePos	// The position of the slider
	variable/g root:packages:twoP:examine:FrameSliderStart // start position when doing a projection
	// Variables for dynamic ROI
	variable/G root:packages:twoP:examine:doDROI = 0
	variable/G root:Packages:twoP:examine:DROIRad = 0 // This variable stores the radius for the dynamic ROI from the examine panel
	variable/G root:packages:twoP:examine:doDROICh1 = 1
	variable/G root:packages:twoP:examine:doDROICh2 = 0
	variable/G root:packages:twoP:examine:doDROIRatio = 0
	variable/G root:packages:twoP:examine:doDROITopChan = 1 //1 for channel 1/ channel 2, 2 for channel 2/channel 1
	// Variables for Nidaq Traces Graph ROI deltaF processing
	variable/g root:Packages:twoP:examine:startffordeltaf =0		//The range of points at in the ROI wave used for determining the  "F"  used for calculating "deltaF" is stored in these two variables
	variable/g root:Packages:twoP:examine:endffordeltaf =5
	variable/g root:Packages:twoP:examine:ffordeltaf		//This variable is used to set baseline fluorescence from the first x points of the wave
end

//******************************************************************************************************
// Makes the main control panel. Also makes sure Global Variables and Folders exist, and does Initializing of Acquire Stuff, if Acquire Procedure is present
// Last Modified 2017/08/08 by Jamie Boyd
Function NQ_MakeNidaqPanel (withAcquire)
	variable withAcquire
	
	
	// If no global variable found, Make Global variables and load default preferences file 
	if (!(dataFolderExists ("root:Packages:twoP:")))
		if (!(dataFolderExists ("root:Packages:twoP:examine")))
			// Make global examine variables
			NQ_MakeExamineFolder ()
		endif
		//ChR_InitMakeGlobals ()
		//Make an Igor Path to ChR folder in User's User procedures Folder so we can search it later for power procedures
		//NewPath/q/O ChRMapper, SpecialDirPath("Igor Pro User Files", 0, 0, 0 ) + "User Procedures:ChRMapper:"
		// Make an Igor Path to the ChR preferences folder, so we can search it for preferences files
		//NewPath/C/Q/O ChrPrefsPath SpecialDirPath("Preferences" , 0, 0, 0) + "WaveMetrics:Igor Pro 6:Packages:ChRMapper"
	endif
	
	// make path to get new tabs for examine tab control
	PathInfo exTabPath
	if (V_Flag == 0)
		string exTabPathStr = SpecialDirPath("Igor Pro User Files", 0, 0, 0 ) + "User Procedures:" + kNQexTabPathStr
		NewPath/o/q/z exTabPath, exTabPathStr
		PathInfo exTabPath
		if (V_Flag == 0)
			NewPath/M="Locate the twoP procedures." exTabPath, exTabPathStr
		endif
	endif
	// if panel is already present, just bring it to front and exit, assuming everything else is done
	DoWindow/F twoP_controls
	if (V_Flag == 1)
		return -1
	endif
	
	// Make folders for scans and ROIs
	if (!(dataFolderExists ("root:twoP_Scans")))
		newDataFolder/o root:twoP_Scans
	endif
	if (!(dataFolderExists ("root:twoP_ROIS")))
		newDataFolder/o root:twoP_ROIS
	endif
	// Make the panel
	NewPanel /K=1 /W=(2,50,346,760) as "Two-Photon Controls"
	DoWindow/C twoP_Controls
	ModifyPanel /W=twoP_Controls, fixedSize= 1
	// Test for the presence of the acquire function to draw controls.
	variable AqPresent = (exists("NQ_AddAcquireControls" ) == 6) 
	// Add AcquireExamineTab tabcontrol and, if acquire proc is loaded, add acquire tab and its controls
	TabControl AcquireExamineTab, win =twoP_Controls, pos={0,1},size={344,709}, proc=GUIPTabProc
	if ((withAcquire) && (aqPresent))
		TabControl AcquireExamineTab, win =twoP_Controls, tabLabel(0)="Acquire", tabLabel (1) = "Examine", value =1
		GUIPTabNewTabCtrl ("twoP_Controls", "AcquireExamineTab", TabList = "Acquire;Examine;", UserFunc = "ExamineTabCtrl_proc", CurTab = 1)
		funcref GUIPprotoFuncV MakeAqFolder = $"NQ_MakeAcquireFolder"
		MakeAqFolder (0)
		funcref GUIPprotoFunc AddAqControlds = $"NQ_AddAcquireControls"
		AddAqControlds ()
	else //just the examine tab
		TabControl AcquireExamineTab, tabLabel(0)="Examine", value =0
		GUIPTabNewTabCtrl ("twoP_Controls", "AcquireExamineTab", TabList = "Examine", UserFunc = "ExamineTabCtrl_proc")
	endif
	// add examine controls
	NQ_AddExamineControls ()
	if (aqPresent)
		Execute/P/Q "GUIPTabClick (\"twoP_Controls\", \"AcquireExamineTab\", \"Acquire\")"
	endif
end

//******************************************************************************************************
// Adds controls for the Examine functions to the Nidaq Controls panel
// Last Modified 2013/10/28 by Jamie Boyd
Function NQ_AddExamineControls ()
	
	variable able =0
	// Current scan info and WaveNote
	SetVariable ScanNumSetVar, win = twoP_Controls,disable=able,pos={4,27},size={34,19},proc=NQ_ScanNumSetVarProc,title=" ", fSize=12
	SetVariable ScanNumSetVar, win = twoP_Controls,value= root:Packages:twoP:examine:curScanNum
	PopupMenu ScansPopMenu, win = twoP_Controls,disable=able, pos={39,26},size={65,21},proc=NQ_ScansPopMenuProc,title="Scan:"
	PopupMenu ScansPopMenu, win = twoP_Controls,mode=0,value= #"NQ_ListScans (\"1,2,3,4,5,\")"
	TitleBox CurScanTitleBox, win = twoP_Controls,disable=able, pos={91,28},size={61,15},fSize=12,frame=0
	TitleBox CurScanTitleBox, win = twoP_Controls,title = "Current Scan", variable = root:Packages:twoP:examine:curScan
	TitleBox ChannnelsTitleBox, win = twoP_Controls,pos={7,54},size={139,12},title="Channels"
	TitleBox ChannnelsTitleBox, win = twoP_Controls,disable=able, fSize=10,frame=0
	TitleBox DateTimeTitleBox, win = twoP_Controls,disable=able, pos={161,54},size={116,12},title="Date and Time"
	TitleBox DateTimeTitleBox, win = twoP_Controls,fSize=10,frame=0
	ListBox WaveNoteListBox, win = twoP_Controls,disable=able, pos={3,74},size={337,66},proc=NQ_editNoteProc
	ListBox WaveNoteListBox, win = twoP_Controls,font="Courier",fSize=12
	ListBox WaveNoteListBox, win = twoP_Controls,listWave=root:Packages:twoP:examine:NoteListWave
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Setvariable ScanNumSetVar 0;Popupmenu ScansPopMenu 0;Titlebox CurScanTitleBox 0;",applyAbleState=1)
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "TitleBox DateTimeTitleBox 0;Titlebox ChannnelsTitleBox 0;Listbox WaveNoteListBox 0;", applyAbleState=1)
	// Histogram
	Button ShowHistButton win = twoP_Controls, disable=able,pos={6,143},size={84,16},proc=NQ_ShowHistogramProc,title="Histogram",fSize=12
	CheckBox HistFrameCheck win = twoP_Controls, disable=able,pos={109,140},size={85,15},proc=NQ_HistCheckProc,title="This Frame"
	CheckBox HistFrameCheck win = twoP_Controls,fSize=12,value= 1,mode=1
	CheckBox HistStackCheck win = twoP_Controls, disable=able,pos={109,158},size={92,15},proc=NQ_HistCheckProc,title="Whole Stack"
	CheckBox HistStackCheck win = twoP_Controls,fSize=12,value= 0,mode=1
	CheckBox HistCH1check win = twoP_Controls, disable=able,pos={218,140},size={76,15},proc=NQ_HistChanCheckProc,title="Channel 1"
	CheckBox HistCH1check win = twoP_Controls,fSize=12,value= 1
	CheckBox HistCH2check  win = twoP_Controls, disable=able, pos={218,158},size={76,15},proc=NQ_HistChanCheckProc,title="Channel 2"
	CheckBox HistCH2check win = twoP_Controls,fSize=12,value= 0
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Button ShowHistButton 0;CheckBox HistFrameCheck 0;CheckBox HistStackCheck 0;", applyAbleState=1)
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "CheckBox HistCH1check 0;CheckBox HistCH2check 0", applyAbleState=1)
	// Image Appearance
	// Channel selectors
	CheckBox LUTChan1Check, win = twoP_Controls, pos={3,197},size={52,14},proc=NQ_ChanForLUTcheckProc,title="Chan 1"
	CheckBox LUTChan1Check, win = twoP_Controls, userdata=  "LUTChan2Check;",fSize=10,value= 1,mode=1
	CheckBox LUTChan2Check, win = twoP_Controls, pos={3,212},size={52,14},proc=NQ_ChanForLUTcheckProc,title="Chan 2"
	CheckBox LUTChan2Check,win = twoP_Controls, userdata=  "LUTChan1Check;",fSize=10,value= 0,mode=1
	// LUT popmenu and inverter
	PopupMenu LUTpopUp  win = twoP_Controls,pos={5,176},size={278,20},proc=NQ_LUTPopMenuProc,title="LUT", fSize=10
	PopupMenu LUTpopUp  win = twoP_Controls,mode=1,bodyWidth= 256,popvalue="",value= #"\"*COLORTABLEPOPNONAMES*\""
	CheckBox LUTInvertCheck  win = twoP_Controls,pos={289,178},size={49,14},proc=NQ_LutInvertCheckProc,title="Invert"
	CheckBox LUTInvertCheck  win = twoP_Controls, fSize=10,variable= root:Packages:twoP:examine:Ch1LUTInvert
	// LUT setvars
	SetVariable LUTFirstValueSetVar  win = twoP_Controls,pos={70,201},size={77,15},proc=NQ_LUTValsSetVarProc,title="First"
	SetVariable LUTFirstValueSetVar  win = twoP_Controls,fSize=9,format="%d"
	SetVariable LUTFirstValueSetVar  win = twoP_Controls,limits={1,(2^kNQimageBits)-2,1},value= root:Packages:twoP:examine:Ch1FirstLUTColor
	SetVariable LUTLastValueSetVar  win = twoP_Controls,pos={158,201},size={72,15},proc=NQ_LUTValsSetVarProc,title="Last"
	SetVariable LUTLastValueSetVar  win = twoP_Controls,fSize=9,format="%d"
	SetVariable LUTLastValueSetVar  win = twoP_Controls,limits={1,(2^kNQimageBits)-2,1},value= root:Packages:twoP:examine:Ch1LastLUTColor
	// adjust first/last to data range
	Button LUTtoDataButton  win = twoP_Controls,pos={240,199},size={42,20},proc=NQ_LUTtoDataProc,title="to Data",fSize=10
	CheckBox LUT96check  win = twoP_Controls,pos={290,202},size={42,14},proc=NQ_LUT96CheckProc,title="96%"
	CheckBox LUT96check  win = twoP_Controls,fSize=10,value= 0
	// LUT Sliders
	Slider LUTFirstValSlider  win = twoP_Controls,pos={5,229},size={277,16},proc=NQ_LUTValSliderProc,fSize=10
	Slider LUTFirstValSlider  win = twoP_Controls,limits={17,(2^kNQimageBits)-2,1},variable= root:Packages:twoP:examine:Ch1FirstLUTColor,vert= 0,ticks= 0,thumbColor= (0,0,52224)
	Slider LUTLastValSlider  win = twoP_Controls,pos={5,225},size={277,16},proc=NQ_LUTValSliderProc,fSize=10
	Slider LUTLastValSlider  win = twoP_Controls,limits={17,(2^kNQimageBits)-2,1},variable= root:Packages:twoP:examine:Ch1LastLUTColor,side= 2,vert= 0,ticks= 0,thumbColor= (65280,0,0)
	// Auto LUT checkbox
	CheckBox LUTautoCheck  win = twoP_Controls,pos={291,226},size={37,14},proc=NQ_LUTAutoCheckProc,title="auto"
	CheckBox LUTautoCheck  win = twoP_Controls,variable= root:Packages:twoP:examine:Ch1LUTAuto
	// Before First color adjustments
	TitleBox LUTBeforeFirstTitle win = twoP_Controls ,pos={4,251},size={83,12},title="Before First Use "
	TitleBox LUTBeforeFirstTitle win = twoP_Controls ,fSize=10,frame=0
	CheckBox LUTBeforeUseFirstCheck win = twoP_Controls ,pos={96,250},size={43,14},proc=NQ_LutBeforeModeCheckProc,title="First"
	CheckBox LUTBeforeUseFirstCheck win = twoP_Controls ,fSize=10,value= 0,mode=1
	CheckBox LUTBeforeUseColorCheck win = twoP_Controls ,pos={154,250},size={16,14},proc=NQ_LutBeforeModeCheckProc,title=""
	CheckBox LUTBeforeUseColorCheck win = twoP_Controls ,fSize=12,value= 1,mode=1
	PopupMenu LUTBeforeColorPopUp win = twoP_Controls ,pos={170,247},size={50,20},proc=NQ_BeforeColorPopMenuProc
	PopupMenu LUTBeforeColorPopUp win = twoP_Controls ,fSize=10
	PopupMenu LUTBeforeColorPopUp win = twoP_Controls ,mode=122,popColor= (0,15872,65280),value= #"\"*COLORPOP*\""
	CheckBox LUTBeforeUseTransCheck win = twoP_Controls ,pos={249,250},size={78,14},proc=NQ_LutBeforeModeCheckProc,title="Transparent"
	CheckBox LUTBeforeUseTransCheck win = twoP_Controls ,fSize=10,value= 0,mode=1
	// After Last color adjustments
	TitleBox LUTAfterLastTitle win = twoP_Controls ,pos={15,273},size={68,12},title="After Last Use"
	TitleBox LUTAfterLastTitle win = twoP_Controls ,fSize=10,frame=0
	CheckBox LUTAfterUseLastCheck win = twoP_Controls ,pos={96,272},size={38,14},proc=NQ_LutAfterModeCheckProc,title="Last"
	CheckBox LUTAfterUseLastCheck win = twoP_Controls ,fSize=10,value= 0,mode=1
	CheckBox LUTAfterUseColorCheck win = twoP_Controls,pos={154,273},size={21,14},proc=NQ_LutAfterModeCheckProc,title=" "
	CheckBox LUTAfterUseColorCheck win = twoP_Controls,value= 0,mode=1
	PopupMenu LUTAfterColorPopUp win = twoP_Controls ,pos={170,269},size={50,20},proc=NQ_AfterColorPopMenuProc,fSize=10
	PopupMenu LUTAfterColorPopUp win = twoP_Controls ,mode=1,popColor= (65535,0,0),value= #"\"*COLORPOP*\""
	CheckBox LUTAfterUseTransCheck win = twoP_Controls ,pos={249,272},size={78,14},proc=NQ_LutAfterModeCheckProc,title="Transparent"
	CheckBox LUTAfterUseTransCheck win = twoP_Controls ,fSize=10,value= 0,mode=1
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Button ShowHistButton 0;Checkbox HistFrameCheck 0;Checkbox HistStackCheck 0;Checkbox HistCH1check 0;",applyAbleState=1)
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Checkbox HistCH2check 0;Popupmenu LUTpopUp 0;Checkbox LUTInvertCheck 0;Checkbox LUTChan1Check 0;",applyAbleState=1)
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Checkbox LUTChan2Check 0;Setvariable LUTFirstValueSetVar 0;Setvariable LUTLastValueSetVar 0;",applyAbleState=1)
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Button LUTtoDataButton 0;Checkbox LUT96check 0;Slider LUTFirstValSlider 0;Slider LUTLastValSlider 0;",applyAbleState=1)
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Titlebox LUTBeforeFirstTitle 0;Checkbox LUTBeforeUseFirstCheck 0;Checkbox LUTBeforeUseColorCheck 0;",applyAbleState=1)
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Popupmenu LUTBeforeColorPopUp 0;Titlebox LUTAfterLastTitle 0;Checkbox LUTBeforeUseTransCheck 0;",applyAbleState=1)
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Checkbox LUTAfterUseLastCheck 0;Checkbox LUTAfterUseColorCheck 0;Popupmenu LUTAfterColorPopUp 0;",applyAbleState=1)
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Checkbox LUTAfterUseTransCheck 0;Checkbox LUTautoCheck 0;",applyAbleState=1)
	// Movie Controls
	Button MovieButton,win = twoP_Controls, disable=able,pos={5,293},size={52,20},proc=NQ_MovieProc,title="movie"
	Slider FramePositionSlider,win = twoP_Controls, disable=able,pos={64,293},size={275,49},proc=NQ_DisplayFramesProc
	Slider FramePositionSlider,win = twoP_Controls, disable=able,limits={0,10,1},variable= root:Packages:twoP:examine:CurFramePos,vert= 0
	Button PrevFrame,win = twoP_Controls, disable=able,pos={5,318},size={23,18},proc=NQ_NextPreviousFrameProc,title="<-"
	Button NextFrame,win = twoP_Controls, disable=able,pos={31,318},size={23,18},proc=NQ_NextPreviousFrameProc,title="->"
	// Dynamic ROI
	CheckBox DROICheck,win = twoP_Controls, disable=able,pos={4,344},size={19,35},title="", proc=NQ_DROICheckProc
	CheckBox DROICheck,win = twoP_Controls, disable=able, variable=root:Packages:twoP:examine:doDROI,picture= ProcGlobal#lightSwitch_small
	SetVariable DROIRadSetVar,win = twoP_Controls, disable=able,pos={30,342},size={214,19},title="Dynamic ROI  Radius (pixels)"
	SetVariable DROIRadSetVar,win = twoP_Controls, fSize=12,  proc=NQ_DroiRadiusSetVarProc
	SetVariable DROIRadSetVar, win = twoP_Controls, limits={0,inf,1},value= root:Packages:twoP:examine:DROIRad
	CheckBox DroiCheckCh1,win = twoP_Controls, disable=able,pos={25,365},size={58,16},title="Chan 1",fSize=12
	CheckBox DroiCheckCh1,win = twoP_Controls, variable = root:Packages:twoP:examine:doDROIch1
	CheckBox DroiCheckCh2,win = twoP_Controls, disable=able,pos={87,365},size={58,16},title="Chan 2",fSize=12
	CheckBox DroiCheckCh2,win = twoP_Controls, variable = root:Packages:twoP:examine:doDROIch2
	CheckBox DroiCheckRatio,win = twoP_Controls, disable=able,pos={150,365},size={47,16},title="Ratio",fSize=12
	CheckBox DroiCheckRatio,win = twoP_Controls, variable= root:Packages:twoP:examine:doDROIRatio
	PopupMenu DROIRatPopUp,win = twoP_Controls, disable=able,pos={203,363},size={80,20},proc=NQ_DROIPopMenuProc
	PopupMenu DROIRatPopUp,win = twoP_Controls, fSize=12
	PopupMenu DROIRatPopUp,win = twoP_Controls, mode=2,popvalue="Ch1/Ch2",value= #"\"Ch1/Ch2;Ch2/Ch1\""
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Button MovieButton 0;Slider FramePositionSlider 0;Button PrevFrame 0;Button NextFrame 0;",applyAbleState=1)
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Checkbox DROICheck 0;Setvariable DROIRadSetVar 0;Checkbox DroiCheckCh1 0;Checkbox DroiCheckCh2 0;",applyAbleState=1)
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Checkbox DroiCheckRatio 0;Popupmenu DROIRatPopUp 0;",applyAbleState=1)
	// Show Other windows
	GroupBox ShowOthersGroupBox,win = twoP_Controls, disable=able,pos={3,664},size={337,40},title="Show Other Windows"
	GroupBox ShowOthersGroupBox,win = twoP_Controls, frame=0
	Button ShowTracesButton,win = twoP_Controls, disable=able,pos={14,682},size={57,17},proc=NQ_showTracesProc,title="Traces"
	Button ShowMiscAnalysisButton,win = twoP_Controls, disable=able,pos={96,680},size={99,20},proc=MakeMiscPanel,title="Misc Analysis"
	Button ShowScansButton,win = twoP_Controls, disable=able,pos={230,681},size={49,17},proc=NQ_ShowScansProc,title="Scans"
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine","GroupBox ShowOthersGroupBox 0;Button ShowTracesButton 0;Button ShowMiscAnalysisButton 0;",applyAbleState=1)
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine","Button ShowScansButton 0;",applyAbleState=1)
	// Examine tabControl
	// Use String for list of tabs on the examine tab control, use it to start a tabcontrol database 
	string tabList = kNQexTabList
	SVAR/Z gTabList = root:packages:TCD:twoP_Controls:ExamineTabControl:tabList
	if (SVAR_EXISTS (gTabList))
		tabList = gTabList
	endif
	variable CurTab =0
	NVAR/Z gCurTab = root:packages:TCD:twoP_Controls:ExamineTabControl:curTab
	if (NVAR_EXISTS (gCurTab))
		curTab = gCurTab
	endif
	TabControl ExamineTabCtrl,win = twoP_Controls, disable=able,pos={3,388},size={337,269},proc=GUIPTabProc
	TabControl ExamineTabCtrl,win = twoP_Controls, font="Times New Roman",fSize=10, value= 0
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Tabcontrol ExamineTabCtrl 0;",applyAbleState=0)
	GUIPTabNewTabCtrl ("twoP_Controls", "ExamineTabCtrl", TabList = tabList, UserFunc = "ExamineTabCtrl_proc", curTab = curTab)
	// add selected tabs to examine tabcontrol
	variable iT, nTabs = itemsinList (tabList)
	string addTab
	//Make sure the tab's procedure file is loaded 
	for (iT =0; iT < nTabs; iT += 1)
		addTab = stringfromList (iT, tabList, ";")
		TabControl ExamineTabCtrl, win = twoP_Controls, tabLabel (iT)= addTab
		Execute/P/Q "INSERTINCLUDE \"twoPex_" + addTab + "\""
	endfor
	Execute/P/Q "COMPILEPROCEDURES "	
	// Call the added tabs' add tab method
	for (iT =0; iT < nTabs; iT += 1)
		addTab = stringfromList (iT, tabList)
		if (iT ==curTab)
			Execute/P/Q "NQex" + addTab + "_add(0)"
		else
			Execute/P/Q "NQex" + addTab + "_add(1)"
		endif
	endfor
end
//******************************************************************************************************
// Adds a tab to the Examine tab control. Each tab  has its own procedure file
// Last Modified 2015/04/14 by Jamie Boyd
Function NQ_addExTab ()
	
	// make sure panel is open
	if ((cmpstr("twoP_Controls", WinList ( "twoP_Controls", "", "WIN:64"))) != 0)
		NQ_MakeNidaqPanel(1)
	endif
	//List of tabs/files already loaded
	string exTabList = GUIPTabGetTabList ("twoP_Controls", "ExamineTabCtrl")
	// make list of procedures that have not been loaded yet
	string AllFileList =  GUIPListFiles ("exTabPath", ".ipf", "twoPex_*",1, "") 
	variable iFile, nFiles = itemsinList (allFileList, ";")
	string procList = "", aproc
	for (iFile =0;iFile < nFiles;iFile+=1)
		aproc =removeending (((stringFromList (iFile, AllFileList, ";"))[7, INF]), ".ipf")
		if  (WhichListItem(aProc, exTabList, ";") == -1)
			procList = AddListItem(aproc, procList , ";")
		endif
	endfor
	// if nothing left to load, say so and exit
	if (cmpstr (procList, "") == 0)
		doalert 0, "There are no available twoP Examine tab procedures to load."
		return -1
	endif
	//put  up a dialog to choose a tab to add
	string AddTab
	Prompt addTab, "Tab to add:" , popup, procList
	doPrompt "Add a Tab to the\"Examine\" tab control", addTab
	if (V_Flag) //cancel was clicked on the dialog, so exit
		return -1
	endif
	/// make sure examine tab is in front
	if (cmpStr (GUIPTabGetCurrentTab ("twoP_Controls", "AcquireExamineTab"), "Examine") != 0)
		GUIPTabClick ("twoP_Controls", "AcquireExamineTab", "Examine")
	endif
	if (GUIPTabAddTab ("twoP_Controls", "ExamineTabCtrl", addTab, 3) == 1) //This eventuality should not even be a possibility
		doAlert 0, "That tab has already been added to the tabcontrol."
		return 1
	endif
	//Make sure the tab's procedure file is loaded and execute the Add tab procedure
	Execute/P/Q "INSERTINCLUDE \"twoPex_" + addTab + "\""
	Execute/P/Q "COMPILEPROCEDURES "
	Execute/P/Q "NQex" + addTab + "_add(0)"
	return 0
end

//******************************************************************************************************
//removes a tab from the Examine tabcontrol of the Two-Photon control panel. Assumes each tab has a procedure "_remove"
// Last Modified 2013/10/28 by Jamie Boyd
Function NQ_RemoveExTab ()
	
	//if thePanel window does not exist, exit with error
	if ((cmpstr("twoP_Controls", WinList ( "twoP_Controls", "", "WIN:64"))) != 0)
		doAlert 0, "The Two-Photon Control Panel is not open."
		return 1
	endif
	//put  up a dialog to choose a tab to remove
	string exTabList =GUIPTabGetTabList ("twoP_Controls", "ExamineTabCtrl")
	// if only 1 tab, exit with error
	if (itemsinlist (exTabList, ";") == 1)
		doalert 0, "You must have at least one tab on the tab control."
		return 0
	endif
	string removeTab
	Prompt removeTab, "Tab to remove:" , popup, exTabList
	doPrompt "Remove a tab from the Examine TabControl", removeTab
	if (V_Flag) //cancel was clicked on the dialog, so exit
		return 1
	endif
	// Try to remove the tab and its controls from the tabcontrol
	if (GUIPTabRemoveTab ("twoP_Controls", "ExamineTabCtrl", removeTab, 3))
		return 1
	endif
	// Call the procedure's remove function , if it exists, to do extra things like kill globals
	if ((Exists ("NQex" + removeTab + "_remove")) == 6) // then the procedure exists
		funcref GUIPprotoFunc RemoveFunc = $"NQex" + removeTab + "_remove"
		removeFunc ()
	endif
	//Add a deleteinclude of the tabs procedure file to the operations que
	Execute/P/Q "DELETEINCLUDE \"twoPex_" + removeTab + "\""
	Execute/P/Q "COMPILEPROCEDURES "
end


//******************************************************************************************************
// Returns a list of scans in the twoP_Scans folder, sorted by scan mode. Pass a comma separated list of scan types
// Last Modified 2012/06/26 by Jamie Boyd
Function/S NQ_ListScans (modeList)
	string modeList // comma separated list of modes to be returned
	
	variable aMode
	variable iFolder, nFolders
	string aFolder
	string TimeSeriesList="", SingleImageList="", zSeriesList ="", lineScanList="",ephysOnlyList=""
	for (iFolder = 0,  nFolders=CountObjects("root:twoP_Scans:", 4) ; iFolder < nFolders; iFolder += 1)
		aFolder = GetIndexedObjName("root:twoP_Scans:", 4, iFolder)
		SVAR/Z scanStr = $"root:twoP_Scans:" + aFolder + ":" + aFolder + "_info"
		if ((SVAR_EXISTS (scanStr)) && (WhichListItem(stringbyKey ("mode", scanStr, ":", "\r"), modeList, ",") > -1))
			aMode = numberbyKey ("mode", scanStr, ":", "\r")
			switch (aMode)
				case kTimeSeries:
					TimeSeriesList += aFolder + ";"
					break
				case kSingleImage:
					SingleImageList +=  aFolder + ";"
					break
				case kzSeries:
					zSeriesList += aFolder + ";"
					break
				case kLineScan:
					lineScanList += aFolder + ";"
					break
				case kePhysOnly:
					ephysOnlyList += aFolder + ";"
					break
			endSwitch
		endif
	endfor
	string outPutList = ""
	if (WhichListItem("1", modeList, ",") > -1)
		outPutList += "\\M1(Time Series;" + TimeSeriesList + "\\M1(-;"
	endif
	if (whichListItem( "2", modeList, ",") > -1)
		outPutList += "\\M1(Averages;" + SingleImageList + "\\M1(-;"
	endif
	if (whichListItem( "4", modeList, ",") > -1)
		outPutList += "\\M1(Z Stacks;" + zSeriesList + "\\M1(-;"
	endif
	if (whichListItem( "3", modeList, ",") > -1)
		outPutList += "\\M1(Line Scans;" + lineScanList + "\\M1(-;"
	endif
	if (whichListItem( "5", modeList, ",") > -1)
		outPutList += "\\M1(ePhys Only;" + ephysOnlyList
	endif
	if (strlen (outPutList) < 2)
		return "\\M1(No Scans"
	else
		return outPutList
	endif
end	

//******************************************************************************************************
// Function for the ScanNum setvar.If your scans are sequentially numbered, you can advance through them one at a time.
// Last modified Mar 18 2012 by Jamie Boyd
Function NQ_ScanNumSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			SVAR curScan = root:Packages:twoP:examine:CurScan
			NVAR scanNum = root:packages:twoP:Examine:curScanNum
			scanNum = sva.dval
			string scanNumStr, newScan
			sprintf scanNumStr, "_%03d", scanNum
			newScan = stringFromList (0, curScan, "_")  + scanNumStr
			if (!(DataFolderExists ("root:twoP_Scans:" + newScan)))
				if (!(sva.eventMod & 2)) // shift-click to advance through missing scans
					printf "No such scan:\"%s\"\r", newScan
					scanNum = str2num (stringfromlist (1, curScan, "_"))
				endif
				return 0
			endif
			STRUCT WMPopupAction pa
			pa.popStr = newScan
			pa.eventcode =2
			NQ_ScansPopMenuProc(pa)
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Function for the Scan popup menu. This allows you to select a scan to display as the current scan in the ScanGraph window.
// Once here, you can view it as a movie, save it to disk, etc
// Last Modified 2016/10/13 by Jamie Boyd
Function NQ_ScansPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			
			SVAR curScan = root:Packages:twoP:examine:CurScan
			curScan = pa.popStr
			NVAR scanNum = root:packages:twoP:Examine:curScanNum
			scanNum = str2num (stringfromlist (1, pa.popStr, "_"))
			// Get some variables from scan note
			if (cmpStr (curScan, "LiveWave") == 0)
				SVAR ScanNote  = root:packages:twoP:Acquire:LiveModeScanStr
			else
				SVAR ScanNote = $"root:twoP_Scans:" + curScan + ":" + curScan+  "_info"
			endif
			variable mode = NumberByKey("mode",ScanNote, ":", "\r")
			variable doephys = NumberByKey("ephys",ScanNote, ":", "\r")
			if (mode == kePhysOnly)
				DoWindow/K twoPscanGraph
				NQ_NewTracesGraph (curScan)
			else
				NQ_NewScanGraph (curScan)
				variable nTraces = 0//doEphys + GUIPCountObjs ("root:twoP_Scans:" + CurScan, 1, "*avg*", 0) + GUIPCountObjs ("root:twoP_Scans:" + CurScan, 1, "*ratio*", 0)
				if (nTraces == 0) 
					DoWindow/K twoP_TracesGraph
				else
					NQ_NewTracesGraph (curScan)
				endif
			endif
				// adjust the movie controls and visibility and change display
				NQ_Adjust_Examine_Controls (curScan)
			break
	endswitch
	return 0
End


//******************************************************************************************************
// This function adjusts the Date and time info and the slider control on the examine scans panel to reflect the time of the current scan.
// It also disables the movie controls if the current scan is not a stack.
// Last modified Mar 19 2012 by Jamie Boyd 
Function NQ_Adjust_Examine_Controls (curScan)
	string curScan
	
	if (cmpStr (curScan, "LiveWave") == 0)
		SVAR/z ScanStr =root:packages:twoP:Acquire:LiveModeScanStr
	else
		SVAR/z ScanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
	endif
	if (!(SVAR_EXISTS (ScanStr)))
		return 1
	endif
	NVAR FrameTime = root:Packages:twoP:examine:FrameTime 
	NVAR NumFrames =root:Packages:twoP:examine:Numframes
	variable mode = numberbykey("mode", ScanStr, ":", "\r")
	// change the title box to reflect the current scan
	TitleBox CurScanTitleBox win = twoP_Controls, title= stringbykey ("Scan Type", ScanStr, ":", "\r") + ":" + curScan
	Controlinfo /w = twoP_Controls AcquireExamineTab
	variable ShowNow = (cmpstr (S_Value, "Examine") == 0) // 0 if acquiring, 1 if examining
	// Change the info displayed about the current scan
	if (cmpStr (curScan, "LiveWave") == 0)
		NQ_ShowNote ("root:packages:twoP:Acquire:LiveModeScanStr")
	else
		NQ_showNote ("root:twoP_Scans:" + curScan + ":" + curScan + "_info")
	endif
	TitleBox DateTimeTitleBox Win=twoP_Controls, title =  secs2date(numberbykey("ExpTime", ScanStr, ":", "\r"),0) + " " + secs2Time(numberbykey("ExpTime",ScanStr, ":", "\r"),1)
	string ChanTitleStr = "" 
	variable scanChans =  numberbykey("ImChans", ScanStr, ":", "\r")
	if (scanChans)
		ChanTitleStr += "Chans: Image:"
		if ((scanChans & 1) && (scanChans & 2))
			ChanTitleStr += "1&2"
		else
			ChanTitleStr += num2str (scanChans)
		endif
		ChanTitleStr += " "
	endif
	variable ePhysChans =  numberbykey("ephys", ScanStr, ":", "\r")
	if (ePhysChans)
		ChanTitleStr += "ePhys:"
		if ((ePhysChans & 1) && (ePhysChans & 2))
			ChanTitleStr += "1&2"
		else
			ChanTitleStr += num2str (ePhysChans)
		endif
	endif
	TitleBox ChannnelsTitleBox Win=twoP_Controls, title = ChanTitleStr
	// adjust movie and average controls
	if ((mode == kTimeSeries) || (mode == kZSeries))
		// reset the slider values
		NVAR CurFramePos = root:Packages:twoP:examine:CurFramePos
		CurFramePos = 0
		FrameTime =  numberbykey("FrameTime", ScanStr, ":", "\r")
		NumFrames = numberbykey("NumFrames", ScanStr, ":", "\r")
		Slider FramePositionSlider, Win =twoP_Controls,limits={0,NumFrames-1,1}, value =0
		variable ableState
		if (ShowNow)
			ableState =0
		else
			ableState =1
		endif
	else		// not a stack, so disable movie controls
		Slider FramePositionSlider, Win =twoP_Controls,limits={0,0,0}, value = 0
		STRUCT WMCheckBoxAction cba
		cba.checked = 0
		cba.eventCode = 2
		NQ_DroiCheckProc (cba)
		if (ShowNow)
			ableState =2
		else
			ableState = 3
		endif
	endif
	GUIPTabSetAbleState ("twoP_Controls", "AcquireExamineTab", "Examine", "FramePositionSlider;MovieButton;PrevFrame;NextFrame;DROICheck", ableState, 1)
	// Adjust examineTabControl stuff for front tab
	controlinfo/w=twoP_controls ExamineTabCtrl
	STRUCT WMTabControlAction tca
	tca.ctrlName = "ExamineTabCtrl"
	tca.win = "twoP_Controls"
	tca.eventCode = 2
	tca.tab = V_Value
	ExamineTabCtrl_proc (tca)
end

//******************************************************************************************************
// -----------------------------code for making and altering scan graph----------------------------------------------
//******************************************************************************************************

// Makes or reloads the scangraph of the current scan
// Last Modified 2016/11/03 by Jamie Boyd
Function NQ_NewScanGraph (curScan)
	string curScan
	
	// If ScanGraph is open, bring it to the front
	variable isNew =0 // if making graph from scratch, this will be set to 1, 0 for revamping an existing graph
	DoWindow/F twoPscanGraph
	if (!(V_Flag))
		isNew =1
	endif
	// acquiring?
	// If acquiring data, we want to make the available channels to match the requested channels.
	// If in examining mode, we want to limit the requested channels to the available channels
	Controlinfo /w = twoP_Controls AcquireExamineTab
	variable isAcquire = (cmpstr (S_Value, "Acquire") == 0) // 1 if called from acquiring tab, 0 if examining.
	// get reference to scan info string
	if (isAcquire) // use live mode info string (we keep it updated)
		SVAR/Z ScanStr = root:packages:twoP:Acquire:LiveModeScanStr
	else
		SVAR/Z ScanStr = $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_info"
	endif
	if (!(SVAR_EXISTS (scanStr)))
		doAlert 0, "The info string for the scan, \"" + CurScan + "\" was not found."
		return 1
	endif
	// Get scan mode
	variable mode = NumberByKey("mode",ScanStr, ":", "\r")
	// which channels exist for this scan?
	variable scanChans = numberbykey ("ImChans", scanStr, ":", "\r")
	variable hasCh1 = ((scanChans & 1) ==1)
	variable hasCh2 = ((scanChans & 2) ==2)
	// which channels are to be displayed right now, as indicated by variables hooked up to the checkboxes on the scanGraph?
	// Reset showChan variables if the channels are not set in the scan String
	NVAR showCh1 = root:packages:twoP:examine:showCh1
	showCh1 *= hasCh1
	NVAR showCh2 = root:packages:twoP:examine:showCh2
	showCh2 *= hasCh2
	NVAR showMrg = root:packages:twoP:examine:showMerge
	showMrg *= (hasCh1 & hasCh2)
	// get sizes and offsets
	variable xSize = NumberByKey("PixWidth", ScanStr, ":", "\r") 
	variable ySize = NumberByKey("PixHeight", ScanStr, ":", "\r")
	variable xPixSize =  NumberByKey("xPixSize", ScanStr, ":", "\r")
	variable yPixSize =  NumberByKey("yPixSize", ScanStr, ":", "\r")
	variable xOffset =  NumberByKey("xPos", ScanStr, ":", "\r")
	variable yOffset =  NumberByKey("yPos", ScanStr, ":", "\r")
	variable lineTime = NumberByKey("lineTime", ScanStr, ":", "\r")
	variable zSize = NumberByKey("NumFrames", ScanStr, ":", "\r")
	// make 2D waves to display in scanGraph, or a 3D wave if acquiring and averaging
	if ((mode == kLineScan) || (mode == kSingleImage))
		// for line scans and single image, just display the scan waves as the scanGraph waves.
		// This is wasteful for very long linescans if you want to display a merged channel
		WAVE/z scanGraph_Ch1 = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
		WAVE/z scanGraph_Ch2 = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
		if (isAcquire)
			if (!(dataFolderExists ("root:twoP_Scans:" + curScan)))
				newDataFolder/O $"root:twoP_Scans:" + curScan
			endif
			if ((showCh1) || (showMrg))
				WAVE/z scanGraph_Ch1 = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
				if (!(waveExists (scanGraph_Ch1)))
					make/w/u/n = (xsize, ysize)  $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
					WAVE scanGraph_Ch1 = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
					SetScale/P x xOffset , xPixSize,"m", scanGraph_Ch1
					if (mode == kLineScan)
						SetScale/P Y 0, lineTime, "s",  scanGraph_ch1
					else
						SetScale/P Y yOffset, yPixSize, "m", scanGraph_ch1
					endif
				endif
			endif
			if ((showCh2) || (showMrg))
				if (!(waveExists (scanGraph_Ch2)))
					make/w/u/n = (xsize, ysize)  $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
					WAVE scanGraph_Ch2 = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
					SetScale/P x xOffset , xPixSize,"m", scanGraph_Ch2
					if (mode == kLineScan)
						SetScale/P Y 0, lineTime, "s",  scanGraph_ch2
					else
						SetScale/P Y yOffset, yPixSize, "m", scanGraph_ch2
					endif
				endif
			endif
		else // linescan/single image examine mode. Waves should already exist
			if ((showCh1)&&  (!(waveExists (scanGraph_Ch1))))
				doAlert 0, "Wave for channel 1 could not be found for this scan."
				return 1
			endif
			if ((showCh2)&&  (!(waveExists (scanGraph_Ch2))))
				doAlert 0, "Wave for channel 2 could not be found for this scan."
				return 1
			endif	
		endif
	else // mode = zSeries, TimeSeries, or liveMode, and we must redimension scanGraph waves for either acquire or examine
		WAVE scanGraph_Ch1 = root:packages:twoP:examine:scanGraph_Ch1
		WAVE scanGraph_Ch2 = root:packages:twoP:examine:scanGraph_Ch2	
		if ((showCh1) || (showMrg))
			if ((DimSize(scanGraph_ch1, 0) != xSize) || (DimSize(scanGraph_ch1, 1) != ySize))
				redimension/n= ((xSize), (ySize)) scanGraph_ch1
			endif
			// Y scaling is in seconds, not meters for LineScan
			SetScale/P X, xOffset, xPixSize, "m", scanGraph_ch1
			if (mode == kLineScan)
				SetScale/P Y 0, lineTime, "s",  scanGraph_ch1
			else
				SetScale/P Y yOffset, yPixSize, "m", scanGraph_ch1
			endif
			if ((isAcquire == 1) && (mode != kLiveMode))
				fastop scanGraph_ch1 =0
			endif
		endif
		if ((showCh2) || (showMrg))
			if ((DimSize(scanGraph_ch2, 0) != xSize) || (DimSize(scanGraph_ch2, 1) != ySize))
				redimension/n= ((xSize), (ySize)) scanGraph_ch2
			endif
			// Y scaling is in seconds, not meters for LineScan
			SetScale/P X, xOffset, xPixSize, "m", scanGraph_ch2
			if (mode == kLineScan)
				SetScale/P Y 0, lineTime, "s",  scanGraph_ch2
			else
				SetScale/P Y yOffset, yPixSize, "m", scanGraph_ch2
			endif
			if ((isAcquire == 1) && (mode != kLiveMode))
				fastop scanGraph_ch2 =0
			endif
		endif
	endif
	// For either acquiring, or examining, for every scan mode, we must make the merg wave
	if (showMrg)
		WAVE scanGraph_Mrg = root:packages:twoP:examine:scanGraph_mrg
		if ((DimSize(scanGraph_mrg, 0) != xSize) || (DimSize(scanGraph_mrg, 1) != ySize))
			redimension/n= ((xSize), (ySize), 3) scanGraph_mrg
		endif
		// Y scaling is in seconds, not meters for LineScan
		SetScale/P X, xOffset, xPixSize, "m", scanGraph_mrg
		if (mode == kLineScan)
			SetScale/P Y 0, lineTime, "s",  scanGraph_mrg
		else
			SetScale/P Y yOffset, yPixSize, "m", scanGraph_mrg
		endif
		// setformula for mergedWave here?
	endif
	// get ready for displaying created waves in the ScanGraph
	STRUCT GUIPSubWin_UtilStruct s
	STRUCT GUIPSubWin_ContentStruct cs
	string roiStr, WaveStr, subwinlist = ChildWindowList ("twoPscanGraph")
	variable iW, nW, iSubWin=0
	s.graphName = "twoPscanGraph"
	s.graphTitle = "twoP Scan:" +  curScan
	if (mode == kLineScan)
		s.aspectRatio =0
	else
		s.aspectRatio =1
	endif
	s.yokedAxes = 0
	s.killbehavior = 1
	s.marginL=1
	s.marginT=1
	s.marginR=1
	s.marginB=1
	funcref GUIPSubWin_AddProto s.addContent = NQ_MakeScanGraphSubWin
	// fill out non-variant parts of cs
	cs.nUserVariables =10
	// variable 0 is for scan Mode
	// variable 1 is for show axes check
	// variable 2-7  variables are for Live ROI
	// variable 2 has Live roi
	// variables 3-6: Left, top, right, bottom coordinates
	// variable 7 = scan channel bit 0 for channel 1, bit 1 for 2 for channel 2, bit 2 for merged image
	// variable 8 = 0 if aqcuire tab showing, 1 for examine
	// variable 9 = plot image (else just do ROIs)
	// variable 10 = framePos for 3D waves
	// 1st string is current scan, other strings are used for names of any ROIs
	// current scan
	cs.UserStrings [0] = CurScan
	// scan Mode
	cs.userVariables [0] = mode
	// Show Axes?
	NVAR showAxes = root:packages:twoP:examine:ShowScanGraphAxes
	cs.userVariables [1] = showAxes
	// show Live ROI?
	if (((mode == kTimeSeries) || (mode== kLiveMode)) && (isAcquire==1))
		NVAR LiveROI = root:packages:twoP:acquire:liveROIcheck
		if  (liveROI)
			cs.userVariables [2] = 1
			NVAR LroiL = root:packages:twoP:acquire:lROIL
			NVAR LroiT = root:packages:twoP:acquire:lROIT
			NVAR LroiR = root:packages:twoP:acquire:lROIR
			NVAR LroiB = root:packages:twoP:acquire:lROIB
			cs.userVariables [3] = LroiL
			cs.userVariables [4] = LroiT
			cs.userVariables [5] = LroiR
			cs.userVariables [6] = LroiB
		else
			cs.userVariables [2] = 0
		endif
	endif
	// examine or acquire
	cs.userVariables [8] = (!(isAcquire))// 1 if examining, else 0
	// show ROIs?
	waveStr =""
	cs.nUserStrings =1
	if (mode == kLiveMode)
		nW=0
	else
		roiStr = GUIPListObjs("root:twoP_Scans:" + CurScan, 1, "*avg*",0, "")
		if (cmpStr (roiStr [0,3] , "\M1(") !=0)
			waveStr = roiStr
		endif
		roiStr = GUIPListObjs("root:twoP_Scans:" + CurScan, 1, "*ratio*",0, "")
		if (cmpStr (roiStr [0,3] , "\M1(") !=0)
			waveStr += roiStr
		endif
		nW = itemsInList (waveStr, ";")
	endif
	for (iw =0; iW < nW; iW += 1)
		WAVE anAvg = $"root:twoP_Scans:" + curScan + ":" + stringFromList (iw, waveStr, ";")
		cs.UserStrings [iW +1] = StringByKey("ROI", note (anAvg), ":", ";") 
	endfor
	cs.nUserStrings += nW
	// stuff specific for a making a new ScanGraph
	if (isNew)
		s.nSubWins = showCh1 + showCh2 + showMrg
		SVAR scanSizeStr = root:Packages:savedWins:twoPscanGraph_pos
		s.wleft = str2num (stringfromlist (0, scanSizeStr, ","))
		s.wTop = str2num (stringfromlist (1, scanSizeStr, ","))
		s.wRight = str2num (stringfromlist (2, scanSizeStr, ","))
		s.wBottom = str2num (stringfromlist (3, scanSizeStr, ","))
		s.nCols = s.nSubWins
		s.nRows = 1
		s.prefMoreCols =0
		cs.userVariables [9] = 1
		// window size should be allowed to grow to (height - TitleBar) and width
		s.maxWidth = -1
		s.maxHeight = -1
		if (showCh1)
			cs.subWin = "GCH1"
			cs.userVariables [7] =1
			WAVE cs.userWaves [0] = scanGraph_Ch1
			s.contentStructs [iSubWin] = cs
			iSubWin += 1
		endif
		if (showCh2)
			cs.subWin = "GCH2"
			cs.userVariables [7] =2
			WAVE cs.userWaves [0] = scanGraph_Ch2
			s.contentStructs [iSubWin] = cs
			iSubWin += 1
		endif
		if (showMrg)
			cs.subWin = "GMRG"
			cs.userVariables [7] =4
			WAVE cs.userWaves [0] = scanGraph_mrg
			s.contentStructs [iSubWin] = cs
		endif
		GUIPSubWin_Display (s)
		// add some controls
		controlbar/w= twoPscanGraph 40
		CheckBox CH1check,win = twoPscanGraph, pos={1,4},size={75,16},proc=NQ_ScanGraphDisplayCheckProc,title="Channel 1"
		CheckBox CH1check,win = twoPscanGraph, fSize=12,variable= root:Packages:twoP:examine:showCh1
		CheckBox CH2check,win = twoPscanGraph, pos={79,4},size={75,16},proc=NQ_ScanGraphDisplayCheckProc,title="Channel 2"
		CheckBox CH2check,win = twoPscanGraph, fSize=12,variable= root:Packages:twoP:examine:showCh2
		CheckBox MRGcheck,win = twoPscanGraph, pos={161,4},size={60,16},proc=NQ_ScanGraphDisplayCheckProc,title="Merged"
		CheckBox MRGcheck,win = twoPscanGraph, fSize=12,variable= root:Packages:twoP:examine:showMerge
		PopupMenu GUIPSubWin_PopMenu,win = twoPscanGraph, pos={226,2},size={184,20},proc= GUIPSubWin_ArrangePopMenuProc,title="Arrange"
		PopupMenu GUIPSubWin_PopMenu,win = twoPscanGraph, fSize=12, mode=2,popvalue="1 columns x 1 row",value= #"GUIPSubWin_ListArrangments()"
		Button FullSCaleButton,win = twoPscanGraph, pos={94,19},size={67,20}, proc=GUIPSubWin_FullScaleButtonProc,title="Full Scale"
		CheckBox ShowAxesCheck,win = twoPscanGraph, pos={2,22},size={77,16},proc=NQ_ScanGraphShowAxesProc,title="Show Axis"
		CheckBox ShowAxesCheck,win = twoPscanGraph, fSize=12,value= 0,variable=root:packages:twoP:examine:ShowScanGraphAxes
		// Set window hook function
		SetWindow twoPscanGraph hook (scanHook)= NQ_ScanTrace_HookProc, hookevents = 2
	else
		// if revamping ScanGraph, we can use old subwindows as much as possible, so no need for subwin plotting, and no need to add control bar
		// remove subwindows not requested to be shown
		if ((!(showCh1)) && (WhichListItem("GCH1", SubWinList, ";") > -1))
			killWindow twoPscanGraph#GCH1
			SubWinList = RemoveFromList(SubWinList, "GCH1",  ";")
		endif
		if ((!(showCh2)) && (WhichListItem("GCH2", SubWinList, ";") > -1))
			killWindow twoPscanGraph#GCH2
			SubWinList = RemoveFromList(SubWinList, "GCH2",  ";")
		endif
		if ((!(showMrg)) && (WhichListItem("GMRG", SubWinList, ";") > -1))
			killWindow twoPscanGraph#GMRG
			SubWinList = RemoveFromList(SubWinList, "GMRG",  ";")
		endif
		// what subwindows do we have left on graph?
		string subWinImage, traceList
		variable it, nt
		// just add rois
		cs.UserVariables [9] =0
		cs.nUserWaves =0
		// If needed, replace old images in existing subwindows
		// and remove old drawing and ROIs
		if (WhichListItem("GCH1", SubWinList, ";") > -1)
			SubWinImage=  stringFromList (0, ImageNameList("twoPscanGraph#GCH1", ";" ), ";")
			WAVE subWinWave = ImageNameToWaveRef("twoPscanGraph#GCH1", SubWinImage)
			if (!(WaveRefsEqual(subWinWave , scanGraph_Ch1)))
				AppendImage / W=twoPscanGraph#GCH1 scanGraph_Ch1
				RemoveImage/W=twoPscanGraph#GCH1 $SubWinImage
			endif
			// remove any old drawing
			SetDrawLayer /W=twoPscanGraph#GCH1 /K ProgFront
			// remove old ROIs
			traceList =TraceNameList("twoPscanGraph#GCH1", ";", 1)
			nt = itemsinlist (traceList, ";")
			for (it =nt-1; it >= 0; it -= 1)
				removefromgraph/w=twoPscanGraph#GCH1, $stringfromlist (it, traceList)
			endfor
			cs.subWin = "GCH1"
			cs.userVariables [7] =1
			SetActiveSubwindow  twoPscanGraph#GCH1
			NQ_MakeScanGraphSubWin (cs)
		endif
		if (WhichListItem("GCH2", SubWinList, ";") > -1)
			SubWinImage=  stringFromList (0, ImageNameList("twoPscanGraph#GCH2", ";" ), ";")
			WAVE subWinWave = ImageNameToWaveRef("twoPscanGraph#GCH2", SubWinImage)
			if (!(WaveRefsEqual(subWinWave , scanGraph_Ch2)))
				AppendImage  /W=twoPscanGraph#GCH2 scanGraph_Ch2
				RemoveImage /W=twoPscanGraph#GCH2 $SubWinImage
			endif
			// remove any old drawing
			SetDrawLayer /W=twoPscanGraph#GCH2 /K ProgFront
			// Remove old ROIS
			traceList =TraceNameList("twoPscanGraph#GCH2", ";", 1)
			nt = itemsinlist (traceList, ";")
			for (it = nt-1; it >= 0; it -= 1)
				removefromgraph/w=twoPscanGraph#GCH2, $stringfromlist (it, traceList)
			endfor
			cs.subWin = "GCH2"
			cs.userVariables [7] =2
			SetActiveSubwindow  twoPscanGraph#GCH2
			NQ_MakeScanGraphSubWin (cs)
		endif
		if (WhichListItem("GMRG", SubWinList, ";") > -1)
			// remove old ROIs
			traceList =TraceNameList("twoPscanGraph#MRG", ";", 1)
			nt = itemsinlist (traceList, ";")
			for (it =nt-1; it >=0; it -= 1)
				removefromgraph/w=twoPscanGraph#MRG, $stringfromlist (it, traceList)
			endfor
			cs.subWin = "GMRG"
			cs.userVariables [7] =4
			SetActiveSubwindow  twoPscanGraph#GMRG
			NQ_MakeScanGraphSubWin (cs)
		endif
		// append fresh any subwindows not already there
		cs.UserVariables [9] =0
		cs.nUserWaves =0
		iSubWin =0
		if ((showCh1) && (WhichListItem("GCH1", SubWinList, ";") == -1))
			cs.subWin = "GCH1"
			cs.userVariables [7] =1
			s.contentStructs [iSubWin] = cs
			iSubWin +=1
		endif
		if ((showCh2) && (WhichListItem("GCH2", SubWinList, ";") == -1))
			cs.subWin = "GCH2"
			cs.userVariables [7] =2
			s.contentStructs [iSubWin] = cs
			iSubWin +=1
		endif
		if ((showMrg) && (WhichListItem("GMRG", SubWinList, ";") == -1))
			cs.subWin = "GMRG"
			cs.userVariables [7] =4
			s.contentStructs [iSubWin] = cs
			iSubWIn +=1
		endif
		if (iSubWIn > 0)
			s.nSubWins =iSubWin
			GUIPSubWin_Add (s)
		else // retitling and refitting not already done by subwinutil_add
			if (mode == kLineScan)
				GUIPSubWin_SetAspRat ("twoPscanGraph", 0)
			else
				GUIPSubWin_SetAspRat ("twoPscanGraph", 1)
			endif
			//SubWinUtil_ImageFitSubWindows ("twoPscanGraph")
			DoWindow/T twoPscanGraph, s.graphTitle
		endif
	endif
	// stuff to do for new or revamped scangraph
	// do some adjustments of displayed images and text
	string valueStr
	if ((mode == kZSeries) || (mode == kTimeSeries))
		// if acquiring, displayed waves have already been zeroed
		if (!(isAcquire))
			STRUCT WMSliderAction sa
			if (mode == kTimeSeries)
				// make a kalman averge of first 20 frames
				variable/G root:packages:twoP:examine:FrameSliderStart = min (20, numberbykey ("numFrames", scanStr, ":", "\r")) -1
				sa.eventcode = 4
				sa.eventmod = 2
			else
				sa.eventcode = 1
				sa.curval = 0
			endif
			NQ_DisplayFramesProc(sa) // will set text display appropriately
		else // set info display
			if (mode == kZSeries)
				sprintf valueStr "%.2W0Pm",  numberbyKey ("zPos", scanStr, ":", "\r")
			else
				sprintf valueStr "%.2W0Ps", 0
			endif
			if (showCh1)
				TextBox/W = twoPscanGraph#GCH1/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 "ch1: " + valueStr
			endif
			if (showCh2)
				TextBox/W = twoPscanGraph#GCH2/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 "ch2: " + valueStr
			endif
			if (showMrg)
				TextBox/W = twoPscanGraph#GMRG/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 valueStr
			endif
		endif
	else // a 2D image. Blank the info text, except for channel info
		if (showCh1)
			TextBox/W = twoPscanGraph#GCH1/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 "ch1"
		endif
		if (showCh2)
			TextBox/W = twoPscanGraph#GCh2/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 "ch2"
		endif
		if (showMrg)
			TextBox/W = twoPscanGraph#GMRG/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 ""
		endif
	endif
	// apply im settings to update display LUT
	NQ_ApplyImSettings (showCh1 + 2 * showCh2 + 4 * showMrg)
end

//******************************************************************************************************
//Plots data for a single subwindow
	// variable 0 is for scan Mode
	// variable 1 is for show axes check
	// variable 2-7  variables are for Live ROI
	// variable 2 has Live roi
	// variables 3-6: Left, top, right, bottom coordinates
	// variable 7 = scan channel bit 0 for channel 1, bit 1 for 2 for channel 2, bit 2 for merged image
	// variable 8 = 0 if aqcuire tab showing, 1 for examine
	// variable 9 = plot image (else just do ROIs)
	// variable 10 = framePos for 3D waves
	// string 0 is name of scan to plot	// other strings are used for names of any ROIs

// Last Modified 2013/08/07 by Jamie Boyd
Function NQ_MakeScanGraphSubWin (cs)
	STRUCT GUIPSubWin_ContentStruct &cs
		
	// append the image
	if (cs.userVariables [9] == 1)
		appendimage cs.userWaves [0]
		if (cs.UserVariables [0] == kLineScan)
			variable yEnd = max (4, dimOffset (cs.userWaves [0], 1) + dimSize (cs.UserWaves [0], 1) * dimDelta (cs.UserWaves [0], 1))
			setaxis left  0, yEnd
		endif
		ModifyGraph margin=1, fSize=12, axThick=0, mirror = 0, standoff = 0,tlOffset (bottom)=-25, tlOffset (left)=-30
		ModifyGraph alblRGB=(65535,65535,65535), tlblRGB=(65535,65535,65535)
		Label  left "\\U"
		Label bottom "\\U"
		setaxis/A/R
	endif
	//show axes?
	if (cs.userVariables [1] == 1)
		ModifyGraph nticks=5,noLabel=0
	else
		ModifyGraph nticks=0,noLabel=2
	endif
	// Show live ROI position?
	SetDrawLayer/K ProgFront
	if (cs.userVariables [2] == 1)
		SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0,linefgc= (0,0,0),linethick= 3.00
		DrawRect cs.UserVariables [3], cs.UserVariables [4], cs.UserVariables [5], cs.UserVariables [6]
		SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0,linefgc= (65535,65535,65535),linethick= 1, dash = 2
		DrawRect cs.UserVariables [3], cs.UserVariables [4], cs.UserVariables [5], cs.UserVariables [6]
		//SetDrawLayer UserFront
	endif
	// add ROIs, if they exist
	variable red, green, blue
	string ROIbase
	variable iw
	for (iw =1; iw < cs.nUserStrings; iw += 1)
		ROIbase = cs.UserStrings [iW]
		WAVE/Z xWave = $"root:twoP_ROIS:" + RoiBase + "_x"
		WAVE/Z yWave = $"root:twoP_ROIS:" +RoiBase + "_y"
		if ((waveExists (xWave)) && (waveExists (yWave)))
			red= NumberByKey("Red", note (xWave), ":", ";")
			green= NumberByKey("Green", note (xWave), ":", ";")
			blue =  NumberByKey("Blue", note (xWave), ":", ";")
			appendToGraph /C=(red,green,blue) yWave vs xWave 
		endif
	endfor
end

//******************************************************************************************************
// Adds or removes a subwindow from scanGraph according to user's choice
// Last modified 2013/08/09 by Jamie Boyd
Function NQ_ScanGraphDisplayCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			// acquiring?
			// If acquiring data, we want to make the available channels to match the requested channels.
			// If in examining mode, we want to limit the requested channels to the available channels
			Controlinfo /w = twoP_Controls AcquireExamineTab
			variable isAcquire = (cmpstr (S_Value, "Acquire") == 0) // 1 if called from acquiring tab, 0 if examining.
			// get reference to scan info string
			SVAR curScan = root:packages:twoP:examine:curScan
			if (isAcquire) // use live mode info string (we keep it updated)
				SVAR/Z ScanStr = root:packages:twoP:Acquire:LiveModeScanStr
			else
				SVAR/Z ScanStr = $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_info"
			endif
			if (!(SVAR_EXISTS (scanStr)))
				doAlert 0, "The info string for the scan, \"" + CurScan + "\" was not found."
				return 1
			endif
			// Get scan mode
			variable mode = NumberByKey("mode",ScanStr, ":", "\r")
			// get channel selected from checkBox name (this will be CH1, CH2, or MRG
			string ChanStr = removeEnding (cba.ctrlname, "check")
			// structures for subwindow plotting/removing
			STRUCT GUIPSubWin_UtilStruct s
			STRUCT GUIPSubWin_ContentStruct cs
			s.graphName = "twoPscanGraph"
			s.graphTitle = ""
			cs.userVariables [0] = mode
			s.nSubWins = 1
			cs.subwin= "G" + chanStr
			cs.userVariables [9] =1
			if (cba.Checked) //  adding a new subwindow
				// which channels exist for this scan?
				string chanList = stringByKey ("imChanDesc", ScanStr, ":", "\r")
				variable scanChans = numberbykey ("ImChans", scanStr, ":", "\r")
				variable showCh1 =0, showCh2 =0, hasCh1 =0, hasCh2 =0, showMrg
				if ((cmpStr (ChanStr, "CH1") == 0) || (cmpStr (ChanStr, "MRG") ==0))
					showCh1 =1
				endif
				if ((cmpStr (ChanStr, "CH2") == 0) || (cmpStr (ChanStr, "MRG") ==0))
					showCh2 =1
				endif
				if (WhichListItem("ch1", chanList , ",", 0, 0) > -1)
					hasCh1 =1
				endif
				if (WhichListItem("ch2", chanList , ",", 0, 0) > -1)
					hasCh2 =1
				endif
				if (cmpStr (ChanStr, "MRG") == 0)
					showMrg =1
				endif
				if ((showCh1 & (!(hasCh1))) || (showCh2  & (!(hasCh2))))
					checkbox $cba.ctrlname win=$cba.win, value=0
					return 1
				endif
				// get sizes and offsets
				variable xSize = NumberByKey("PixWidth", ScanStr, ":", "\r") 
				variable ySize = NumberByKey("PixHeight", ScanStr, ":", "\r")
				variable xPixSize =  NumberByKey("xPixSize", ScanStr, ":", "\r")
				variable yPixSize =  NumberByKey("yPixSize", ScanStr, ":", "\r")
				variable xOffset =  NumberByKey("xPos", ScanStr, ":", "\r")
				variable yOffset =  NumberByKey("yPos", ScanStr, ":", "\r")
				variable lineTime = NumberByKey("lineTime", ScanStr, ":", "\r")
				variable zSize = NumberByKey("NumFrames", ScanStr, ":", "\r")
				// make 2D waves to display in scanGraph, or a 3D wave if acquiring and averaging
				if ((mode == kLineScan) || (mode == kSingleImage))
					// for line scans and single image, just display the scan waves as the scanGraph waves.
					// This is wasteful for very long linescans if you want to display a merged channel
					WAVE/z scanGraph_Ch1 = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
					WAVE/z scanGraph_Ch2 = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
					if (isAcquire)
						if (!(dataFolderExists ("root:twoP_Scans:" + curScan)))
							newDataFolder/O $"root:twoP_Scans:" + curScan
						endif
						if ((showCh1) && (!(waveExists (scanGraph_Ch1))))
							make/w/u/n = (xsize, ysize)  $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
							WAVE scanGraph_Ch1 = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
							SetScale/P x xOffset , xPixSize,"m", scanGraph_Ch1
							if (mode == kLineScan)
								SetScale/P Y 0, lineTime, "s",  scanGraph_ch1
							else
								SetScale/P Y yOffset, yPixSize, "m", scanGraph_ch1
							endif
							if (mode != kLiveMode)
								fastop scanGraph_ch1 =0
							endif
						endif
						if ((showCh2) && (!(waveExists (scanGraph_Ch2))))
							make/w/u/n = (xsize, ysize)  $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
							WAVE scanGraph_Ch2 = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
							SetScale/P x xOffset , xPixSize,"m", scanGraph_ch2
							if (mode == kLineScan)
								SetScale/P Y 0, lineTime, "s",  scanGraph_ch2
							else
								SetScale/P Y yOffset, yPixSize, "m", scanGraph_ch2
							endif
							if (mode != kLiveMode)
								fastop scanGraph_ch2 =0
							endif
						endif
					else // linescan/single image examine mode. Waves should already exist
						if ((showCh1)&&  (!(waveExists (scanGraph_Ch1))))
							doAlert 0, "Wave for channel 1 could not be found for this scan."
							return 1
						endif
						if ((showCh2)&&  (!(waveExists (scanGraph_Ch2))))
							doAlert 0, "Wave for channel 2 could not be found for this scan."
							return 1
						endif	
					endif
				else  // // mode = zSeries, TimeSeries, or liveMode, and we must redimension scanGraph waves for either acquire or examine
					WAVE scanGraph_Ch1 = root:packages:twoP:examine:scanGraph_Ch1
					WAVE scanGraph_Ch2 = root:packages:twoP:examine:scanGraph_Ch2	
					if (showCh1)
						if ((DimSize(scanGraph_ch1, 0) != xSize) || (DimSize(scanGraph_ch1, 1) != ySize))
							redimension/n= ((xSize), (ySize)) scanGraph_ch1
						endif
						// Y scaling is in seconds, not meters for LineScan
						SetScale/P X, xOffset, xPixSize, "m", scanGraph_ch1
						if (mode == kLineScan)
							SetScale/P Y 0, lineTime, "s",  scanGraph_ch1
						else
							SetScale/P Y yOffset, yPixSize, "m", scanGraph_ch1
						endif
						if ((isAcquire == 1) && (mode != kLiveMode))
							fastop scanGraph_ch1 =0
						endif
					endif				
					if (showCh2)
						if ((DimSize(scanGraph_ch2, 0) != xSize) || (DimSize(scanGraph_ch2, 1) != ySize))
							redimension/n= ((xSize), (ySize)) scanGraph_ch2
						endif
						// Y scaling is in seconds, not meters for LineScan
						SetScale/P X, xOffset, xPixSize, "m", scanGraph_ch2
						if (mode == kLineScan)
							SetScale/P Y 0, lineTime, "s",  scanGraph_ch2
						else
							SetScale/P Y yOffset, yPixSize, "m", scanGraph_ch2
						endif
						if ((isAcquire == 1) && (mode != kLiveMode))
							fastop scanGraph_ch2 =0
						endif
					endif
				endif				
				if (showMrg)
					WAVE scanGraph_Mrg = root:packages:twoP:examine:scanGraph_mrg
					if ((DimSize(scanGraph_mrg, 0) != xSize) || (DimSize(scanGraph_mrg, 1) != ySize))
						redimension/n= ((xSize), (ySize), 3) scanGraph_mrg
					endif
					// Y scaling is in seconds, not meters for LineScan
					SetScale/P X, xOffset, xPixSize, "m", scanGraph_mrg
					if (mode == kLineScan)
						SetScale/P Y 0, lineTime, "s",  scanGraph_mrg
					else
						SetScale/P Y yOffset, yPixSize, "m", scanGraph_mrg
					endif
				endif
				// Add subwindow with subwin utility
				if (mode == kLineScan)
					s.aspectRatio =0
				else
					s.aspectRatio =1
				endif
				s.yokedAxes = 1
				s.killbehavior = 1
				s.marginl =1
				s.marginT =1
				s.marginR =1
				s.marginB =1
				funcref GUIPSubWin_AddProto s.addContent = NQ_MakeScanGraphSubWin
				// fill out  cs
				cs.nUserVariables =10
				cs.UserStrings [0] = CurScan
				// scan Mode
				cs.userVariables [0] = mode
				// Show Axes?
				NVAR showAxes = root:packages:twoP:examine:ShowScanGraphAxes
				cs.userVariables [1] = showAxes
				// show Live ROI?
				if (((mode == kTimeSeries) || (mode== kLiveMode)) && (isAcquire==1))
					NVAR LiveROI = root:packages:twoP:acquire:liveROIcheck
					if  (liveROI)
						cs.userVariables [2] = 1
						NVAR LroiL = root:packages:twoP:acquire:lROIL
						NVAR LroiT = root:packages:twoP:acquire:lROIT
						NVAR LroiR = root:packages:twoP:acquire:lROIR
						NVAR LroiB = root:packages:twoP:acquire:lROIB
						cs.userVariables [3] = LroiL
						cs.userVariables [4] = LroiT
						cs.userVariables [5] = LroiR
						cs.userVariables [6] = LroiB
					else
						cs.userVariables [2] = 0
					endif
				endif
				// examine or acquire
				cs.userVariables [8] = (!(isAcquire))// 1 if examining, else 0
				// show ROIs?
				string roiStr, waveStr =""
				variable iW, nW
				cs.nUserStrings =1
				if (mode == kLiveMode)
					nW=0
				else
					roiStr = GUIPListObjs("root:twoP_Scans:" + CurScan, 1, "*avg*",0, "")
					if (cmpStr (roiStr [0,3] , "\M1(") !=0)
						waveStr = roiStr
					endif
					roiStr = GUIPListObjs("root:twoP_Scans:" + CurScan, 1, "*ratio*",0, "")
					if (cmpStr (roiStr [0,3] , "\M1(") !=0)
						waveStr += roiStr
					endif
					nW = itemsInList (waveStr, ";")
				endif
				for (iw =0; iW < nW; iW += 1)
					WAVE anAvg = $"root:twoP_Scans:" + curScan + ":" + stringFromList (iw, waveStr, ";")
					cs.UserStrings [iW +1] = StringByKey("ROI", note (anAvg), ":", ";") 
				endfor
				cs.nUserStrings += nW
				strSwitch (chanStr)
					case "ch1":
						cs.subWin = "GCH1"
						cs.userVariables [7] =1
						WAVE cs.userWaves [0] = scanGraph_Ch1
						break
					case "ch2":
						cs.subWin = "GCH2"
						cs.userVariables [7] = 2
						WAVE cs.userWaves [0] = scanGraph_Ch2
						break
					case "mrg":
						cs.subWin = "GMRG"
						cs.userVariables [7] = 4
						WAVE cs.userWaves [0] = scanGraph_MRG
						break
				endSwitch
				// add the content Struct to the main struct
				s.contentStructs [0] = cs
				// add the subwindow
				GUIPSubWin_Add (s)
				// do some adjustments of displayed images and text
				string valueStr
				if ((mode == kZSeries) || (mode == kTimeSeries))
					// if acquiring, displayed waves have already been zeroed
					if (!(isAcquire))
						STRUCT WMSliderAction sa
						if (mode == kTimeSeries)
							// make a kalman averge of first 20 frames
							variable/G root:packages:twoP:examine:FrameSliderStart = min (20, numberbykey ("numFrames", scanStr, ":", "\r")) -1
							sa.eventcode = 4
							sa.eventmod = 2
						else // just show first frame for z series
							sa.eventcode = 1
							sa.curval = 0
						endif
						NQ_DisplayFramesProc(sa) // will set text display appropriately
					else // set info display
						if (mode == kZSeries)
							sprintf valueStr "%.2W0Pm",  numberbyKey ("zPos", scanStr, ":", "\r")
						else
							sprintf valueStr "%.2W0Ps", 0
						endif
						StrSwitch (ChanStr)
							case "CH1":
								TextBox/W = twoPscanGraph#GCH1/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 "ch1: " +valueStr
								break
							case "CH2":
								TextBox/W = twoPscanGraph#GCH2/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 "ch2: " + valueStr
								break
							case "MRG":
								TextBox/W = twoPscanGraph#GMRG/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 valueStr
								break
						endSwitch
					endif
				else // a 2D image. Blank the info text
					StrSwitch (ChanStr)
						case "CH1":
							TextBox/W = twoPscanGraph#GCH1/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 "ch1: " 
							break
						case "CH2":
							TextBox/W = twoPscanGraph#GCH2/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 "ch2: "
							break
						case "MRG":
							TextBox/W = twoPscanGraph#GMRG/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 ""
							break
					endSwitch
				endif
			else
				s.contentStructs [0] = cs
				GUIPSubWin_Remove (s)
				GUIPSubWin_FitSubWindows ("twoPscanGraph")
			endif
			break
	endswitch
	return 0
End


//******************************************************************************************************	
// This hook function  for the scangraph window shows  the value under the mouse pointer when the shift key is held down and the mouse is moved around.
// Also makes sure that info about where the graph was is saved when closing the graph.
// Last modified Jul 18 2011 by Jamie Boyd
Function NQ_ScanTrace_HookProc(s)
	STRUCT WMWinHookStruct &s

	Variable hookResult = 0
	switch(s.eventCode)
		case 0: // Activate
			break
		case 1: // Deactivate
			break
		case 2: // Kill
			// save window size/position
			WC_WindowCoordinatesSave(s.WinName) //SaveWinPosStr (s.WinName)
			hookResult = 1
			break
		case 4: // Mouse Moved
			NVAR dodROI = root:packages:twoP:examine:doDROI
			if (dodROI) // doing dynamic ROI - should only be activated for Z series and Time series
				variable xpos = AxisvalFromPixel (s.winName, "bottom", s.mouseLoc.h)
				variable ypos =  AxisvalFromPixel (s.winName, "left", s.mouseLoc.v)
				SVAR curScan = root:Packages:twoP:examine:CurScan
				SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
				variable xPixSIze = numberbykey ("xPixSize", scanStr, ":", "\r")
				variable xOffset = numberbykey ("xPos", scanStr, ":", "\r")
				variable xPixPos = round ((xpos - xOffset)/xPixSIze)
				variable yPixSize = numberbykey ("yPixSize", scanStr, ":", "\r")
				variable yOffset = numberbykey ("yPos", scanStr, ":", "\r")
				variable yPixPos = round ((yPos - yOffset)/yPixSize)
				NVAR doCh1 = root:Packages:twoP:examine:doDROIch1
				NVAR doCh2 = root:Packages:twoP:examine:doDROIch2
				NVAR doRatio = root:Packages:twoP:examine:doDROIratio
				NVAR DROIRad = root:packages:twoP:examine:DROIrad
				variable iFrame, nFrames = numberbykey ("numFrames", scanStr, ":", "\r")
				if (DROIrad== 0)
					if ((doCh1) || (doRatio))
						WAVE/Z ch1Wave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
						if (waveExists (ch1Wave))
							WAVE droiCh1 =  root:Packages:twoP:examine:Droi_ch1
							For (iFrame=0; iFrame< nFrames; iFrame+= 1)
								droiCh1 [iFrame] = ch1Wave [xPixPos] [yPixPos] [iFrame]
							endfor
						else
							doCh1 =0
							doRatio =0
						endif
					endif
					if ((doCh2) || (doRatio))
						WAVE/Z ch2Wave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
						if (waveExists (ch2Wave))
							WAVE droiCh2 =  root:Packages:twoP:examine:Droi_ch2
							For (iFrame=0; iFrame< NFrames; iFrame+= 1)
								droiCh2 [iFrame] = ch2Wave [xPixPos] [yPixPos] [iFrame]
							endfor
						else
							doCh2 =0
						endif
					endif
				else // need to calculate avg with ACC wave
					wave ACCwave = root:Packages:twoP:examine:ACCwave
					//display;appendimage ACCwave;doupdate
					NVAR DROIrad =  root:packages:twoP:examine:DROIrad
					if ((doCh1) || (doRatio))
						WAVE/Z ch1Wave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
						if (waveExists (ch1Wave))
							WAVE droiCh1 =  root:Packages:twoP:examine:Droi_ch1
							For (iFrame=0; iFrame< NFrames; iFrame+= 1)
								ACCwave  = ch1Wave [p + xPixPos - dROIRad]  [q + yPixPos - dROIRad] [iFrame]
								droiCh1 [iFrame] = mean (accwave)
							endfor
						else
							doCh1 =0
							doRatio =0
						endif
					endif
					if ((doCh2) || (doRatio))
						WAVE/Z ch2Wave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
						if (waveExists (ch2Wave))
							WAVE droiCh2 =  root:Packages:twoP:examine:Droi_ch2
							For (iFrame=0; iFrame< NFrames; iFrame+= 1)
								ACCwave  = ch2Wave [p + xPixPos - dROIRad]  [q + yPixPos - dROIRad] [iFrame]
								droiCh2 [iFrame] = mean (accwave)
							endfor
						else
							doCh2 =0
							doRatio =0
						endif
					endif
				endif
				// ratio
				if (doRatio)
					NVAR TopChan = root:packages:twoP:examine:doDROITopChan
					WAVE droiRatio =  root:Packages:twoP:examine:Droi_ratio
					if (TopChan == 1)
						droiRatio = droiCh1/ droich2
					elseif (topChan == 2)
						droiRatio = droiCh2/ droich1
					endif
				endif
			else // Not doing dynamic ROI
				// If shift key is pressed, show value, or average of value with DROI width, under mouse
				if (s.eventMod == 2)		//then shiftkey is pressed
					xpos = AxisvalFromPixel (s.winName, "bottom", s.mouseLoc.h)
					ypos =  AxisvalFromPixel (s.winName, "left", s.mouseLoc.v)
					SVAR curScan = root:Packages:twoP:examine:CurScan
					if (cmpstr (curScan, "LiveWave") == 0)
						SVAR scanStr = root:packages:twoP:Acquire:LiveModeScanStr
					else
						SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
					endif
					variable scanmode = numberbykey ("mode", scanStr, ":", "\r")
					xPixSIze = numberbykey ("xPixSize", scanStr, ":", "\r")
					xOffset = numberbykey ("xPos", scanStr, ":", "\r")
					xPixPos = round ((xpos - xOffset)/xPixSIze)
					yPixSize = numberbykey ("yPixSize", scanStr, ":", "\r")
					yOffset = numberbykey ("yPos", scanStr, ":", "\r")
					yOffset = numberbykey ("yPos", scanStr, ":", "\r")
					yPixPos = round ((yPos - yOffset)/yPixSize)
					NVAR DROIrad =  root:packages:twoP:examine:DROIrad
					variable ch1value = Nan, ch2value = Nan, iChan
					string theSubWin, SubWinList = ChildWindowList(stringfromlist (0, s.winName, "#"))
					// Channel 1
					if ((scanMode == kLIneScan) || (ScanMode == kSIngleImage))
						WAVE/z thescanwave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_Ch1"
					else
						WAVE/z thescanwave = root:Packages:twoP:examine:scanGraph_Ch1
					endif
					if ((waveExists (thescanwave)) && ((WhichListItem("GCH1", SubWinList, ";") > -1) || ((WhichListItem("GMRG", SubWinList, ";") > -1)))) 
						if (DROIrad== 0)
							ch1value = thescanwave [xPixpos] [yPixpos]
						else
							imagestats/G={xpixpos -DROIrad , xPixpos +  DROIrad, yPixpos -DROIrad, yPixpos +DROIrad}/M =1 thescanwave
							ch1value = V_avg
						endif
						TextBox/W = twoPscanGraph#GCH1/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 "ch1: " + num2str(ch1value)
					endif
					// Channel 2
					if ((scanMode == kLIneScan) || (ScanMode == kSIngleImage))
						WAVE/z thescanwave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
					else
						WAVE/z thescanwave = root:Packages:twoP:examine:scanGraph_Ch2
					endif
					if ((waveExists (thescanwave)) && ((WhichListItem("GCH2", SubWinList, ";") > -1) || ((WhichListItem("GMRG", SubWinList, ";") > -1)))) 
						if (DROIrad == 0)
							ch2value = thescanwave [xPixpos] [yPixpos]
						else
							imagestats/G={xPixpos - DROIrad , xPixpos + DROIrad, yPixpos - DROIrad, yPixpos +DROIrad}/M =1 thescanwave
							ch2value = V_avg
						endif
						TextBox/W = twoPscanGraph#GCH2/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 "ch2: " + num2str(ch2value)
					endif
					// Ratio
					if (((numType (ch1Value) == 0) && (numtype (ch2Value) == 0)) && (WhichListItem("GMRG", SubWinList, ";") > -1))
						NVAR TopChan = root:packages:twoP:examine:doDROITopChan
						if (topChan == 1)
							TextBox/W = twoPscanGraph#GMRG/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 num2str(Ch1Value/ch2Value)
						elseif (topChan == 2)
							TextBox/W = twoPscanGraph#GMRG/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 num2str(Ch2Value/ch1Value)
						endif
					endif
				endif
			endif
			hookResult = 0
			break
		case 11: // keyboard
			if ((s.keycode ==44) || (s.keycode == 46)) // comma, for z-plane -1, period, for z-plane +1
				STRUCT WMButtonAction ba
				if (s.keycode ==44)
					ba.ctrlname = "PrevFrame"
				else
					ba.ctrlname = "NextFrame"
				endif
				ba.eventCode =2
				NQ_NextPreviousFrameProc (ba)
				hookResult =1
			endif		
			break
	endswitch
	return hookResult		// 0 if nothing done, else 1
End

//******************************************************************************************************
//  Shows/Hides axes for all subwindows
// Last modified Oct 10 2009 by Jamie Boyd
Function NQ_ScanGraphShowAxesProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			string subWinList = ChildWindowList ("twoPscanGraph")
			variable iWin, nWins = itemsinlist (subWinList)
			for (iWin =0; iWin < nWins; iWin +=1)
				if (checked)
					ModifyGraph/w=$"twoPscanGraph#" + stringfromlist (iWin,subWinList) nticks=5,noLabel=0
				else
					ModifyGraph/w=$"twoPscanGraph#" + stringfromlist (iWin,subWinList) nticks=0,noLabel=2
				endif
			endfor
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Shows the ScanGraph, or makes it
Function NQ_ShowScansProc(ctrlName) : ButtonControl
	String ctrlName
	
	doWindow/F twoPscanGraph
	if (V_Flag ==0)
		SVAR curScan = root:packages:twoP:examine:curScan
		NQ_NewScanGraph(curScan)
	endif
End

//******************************************************************************************************
// -----------------------------code for making and altering traces graph----------------------------------------------
//******************************************************************************************************

// Makes the Nidaq traces graph, where ephysiology and ROIs/ Linescan averages are displayed. EPhys is on the left axis, on top
// LIne scans on a separate Y axis, same X axis (cause they have the same time base). When DeltaF/F is applied, the averages are put on a new Y axis on bottom right
// Last Modified Jul 12 2010 by Jamie Boyd
Function NQ_NewTracesGraph (curScan)
	string curScan
	
	variable isNew // if making graph from scratch, this will be set to 1, 0 for revamping an existing graph
	// If ScanGraph is open, we can just bring it to the front
	DoWindow/F twoP_TracesGraph
	if (V_Flag == 1)	// then we don't have to make the graph, it already existed and we just brought it to the front
		isNew =0
	else
		isNew =1
	endif
	// get reference to scan info string
	if (cmpstr (curScan, "LiveWave") == 0)
		SVAR ScanStr = root:packages:twoP:Acquire:LiveModeScanStr
	else
		// Make sure folder for this scan exists and reference scan Note
		if (!(dataFolderExists ("root:twoP_Scans:" + CurScan)))
			doAlert 0, "The datafolder for the scan, \"" + CurScan + "\" was not found."
			return 1
		endif
		SVAR ScanStr = $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_info"
	endif
	if (isNew)
		// Display the graph 
		Display/K=1/N = twoP_TracesGraph as "Nidaq Traces: " + CurScan
	else
		DoWindow /T twoP_TracesGraph,  "Nidaq Traces: " + CurScan
		string traceList = TraceNameList("twoP_TracesGraph", ";", 1)
	endif
	// Add traces
	if (NQ_AddTraces(curScan) ==0)
		doWindow/K twoP_TracesGraph
		return 1
	endif
	if (!(isNew)) // remove old traces
		variable it, nt = itemsinlist (traceList, ";")
		for (it =0; it < nt; it += 1)
			removefromgraph/w=twoP_TracesGraph $stringfromlist (it, traceList)
		endfor
	endif
	if (isNew)
		// Set the margins of the graph
		ModifyGraph /W=twoP_TracesGraph margin(left)=54,margin(bottom)=36,margin(top)=10,margin(right)=54
		// Make backgraounds black
		ModifyGraph/W=twoP_TracesGraph wbRGB=(0,0,0),gbRGB=(0,0,0)
		Label bottom "\\Z12Time (\\U)"
		ModifyGraph/W=twoP_TracesGraph  lblLatPos(bottom)=-15
		// control bar and controls
		ControlBar 36
		SetVariable FSetVar,pos={33,3},size={172,15},title="Set \"F \" from first n points"
		SetVariable FSetVar,limits={1,Inf,1},value= root:packages:twoP:examine:ffordeltaf
		CheckBox CursorCheck,pos={35,19},size={119,14},proc=NQ_cursorCheckProc,title="set \"F\" from cursors"
		CheckBox CursorCheck,value= 0
		PopupMenu ROIPopup,pos={208,3},size={99,20},proc=NQ_DoDeltaFProc,title="Do Delta F/F"
		PopupMenu ROIPopup,mode=0,value= #"NQ_ListROIAvgs(root:packages:twoP:examine:curScan, 1)"
		PopupMenu UnDoROIPopup,pos={310,3},size={113,20},proc=NQ_UnDoDeltaFProc,title="Undo Delta F/F"
		PopupMenu UnDoROIPopup,mode=0,value= #"NQ_ListROIAvgs(root:packages:twoP:examine:curScan, 2)"
		PopupMenu DeleteROIPopMenu,pos={426,3},size={113,20},proc=NQ_DeleteRoiProc,title="Delete ROI Avg"
		PopupMenu DeleteROIPopMenu,mode=0,value= #"NQ_ListROIAvgs(root:packages:twoP:examine:curScan, 3)"
		CheckBox AndROICheck,pos={542,6},size={70,14},title="and its ROI",value= 1
		// Aply saved settings for size, position
		WC_WindowCoordinatesRestore("twoP_TracesGraph")//ApplyWinPosStr ("twoP_TracesGraph")
		// set the hook function to save positions
		//SetWindow twoP_TracesGraph hook (SavePosHook)= SaveWinPosStrHook, hookevents = 0
	endif
	//adjust axes
	NQ_TracesGraphShareAxes (curScan)

	return 0
end

//******************************************************************************************************
// Adds ephy and ROI average traces for the current scan to the traces graph
// Last modified Jul 14 2010 by Jamie Boyd
Function NQ_AddTraces (curScan)
	string curScan
	
	variable hasTraces =0
	if (cmpStr (curScan, "LiveWave") == 0)
		SVAR scanStr = root:packages:twoP:Acquire:LiveModeScanStr
	else
		SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
	endif
	//Put up the ephys stuff
	variable ePhysChans = numberbykey ("ePhys", scanStr, ":", "\r")
	variable scanmode = numberbykey ("mode", scanStr, ":", "\r")
	if (ePhysChans&1)
		hasTraces +=1
		WAVE eDataWave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ep1"
		appendtograph /W=twoP_TracesGraph/C=(65535,0,0)/L=Left/B=Bottom eDataWave
		Label left "\\Z12ePhys Chan 1 (\\U)"
		ModifyGraph /W=twoP_TracesGraph lblPos(left)=49
	endif
	if (ePhysChans&2)
		hasTraces +=1
		WAVE eDataWave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ep2"
		appendtograph /W=twoP_TracesGraph/C=(0,0,65535)/R=Right/B=Bottom eDataWave
		label right "\\Z12ePhys Chan 2 (\\U)"
		ModifyGraph /W=twoP_TracesGraph lblPos(right)=49
	endif
	// Now put up ROI avgs
	variable red, green, blue
	string WaveTypeStr, roiStr1, roiStr2, waveStr
	roiStr1 = GUIPListObjs("root:twoP_Scans:" + CurScan, 1, "*avg*",0, "") 
	variable numwaves
	if ((cmpstr (roiStr1 [0,3], "\M1(")) == 0)
		roiStr1 = ""
	endif
	roiStr2 = GUIPListObjs("root:twoP_Scans:" + CurScan, 1, "*ratio*",0, "")
	if (cmpstr (roiStr2 [0,3], "\M1(") == 0)
		roiStr2 = ""
	endif
	waveStr = roiStr1 + roiStr2
	numwaves = itemsinlist (WaveStr, ";")
	hasTraces +=numWaves
	variable ii, iii = 0
	FOR (ii = 0; ii < numwaves; ii += 1)
		WAVE thewave = $"root:twoP_Scans:" + CurScan + ":" + StringFromList(ii, WaveStr, ";")
		if (WaveExists (theWave))
			red = numberbykey ("Red", note (thewave))
			green = numberbykey ("Green", note (thewave))
			blue = numberbykey ("Blue", note (thewave))
			if ((numberbykey ("deltafed", note (thewave))) == 0)
				appendtograph /W=twoP_TracesGraph/C=((red), (green), (blue))/L=ROILAxis/B=Bottom theWave
			else
				appendtograph /W=twoP_TracesGraph/C=((red), (green), (blue))/R=ROIRAxis/B=Bottom theWave
			endif
		endif
	endfor
	return hasTraces
end

//******************************************************************************************************
// Adjust the axes on the Nidaq Traces Graph to share axis space, if necessary
/// ePhys traces are  on left and right axes, get top half of graph if sharing
// rois avgs on  2 custom axes, ROILAxis for non-deltaF/F and ROIRAxis for traces that have been deltaF/F, on bottom half of graph, if sharing 
// Last modified 2012/06/13 by Jamie Boyd
Function NQ_TracesGraphShareAxes (curScan)
	string curScan
	
	// set colors
	ModifyGraph/W=twoP_TracesGraph axRGB=(65535,65535,65535), tlblRGB=(65535,65535,65535), alblRGB=(65535,65535,65535)
	// Set tick lengths
	ModifyGraph /W=twoP_TracesGraph btLen=2
	ModifyGraph /W=twoP_TracesGraph stLen=1
	ModifyGraph /W=twoP_TracesGraph ftLen=2
	if (cmpStr (curScan, "LiveWave") == 0)
		SVAR scanStr = root:packages:twoP:Acquire:LiveModeScanStr
	else
		SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
	endif
	variable scanmode = numberbykey ("mode", scanStr, ":", "\r")
	variable ePhysChans = numberbykey ("ePhys", scanStr, ":", "\r")
	// if only ephys, no need to share - no possibility of ROIS
	if (Scanmode == kEPhysOnly)
		if (ePhysChans&1)
			ModifyGraph axisEnab(left)={0, 1}
		endif
		if (ePhysChans&2)
			ModifyGraph axisEnab(right)={0, 1}
		endif
		return 0
	endif
	// Have ROIs?
	string waveStr =GUIPListObjs("root:twoP_Scans:" + CurScan, 1, "*avg*",0, "") + GUIPListObjs("root:twoP_Scans:" + CurScan, 1, "*ratio*",0, "")
	variable numWaves = itemsinList (WaveStr, ";")
	if (numWaves == 0)
		// If no ePhys and no ROIS, kill the Traces Graph
		if (ePhysChans ==0)
			doWindow/K twoP_tracesGraph
			return 1
		else
			if (ePhysChans&1)
				ModifyGraph axisEnab(left)={0, 1}
			endif
			if (ePhysChans&2)
				ModifyGraph axisEnab(right)={0, 1}
			endif
			return 0
		endif
	endif
	// have ROIs
	// ePhys gets top half of graph
	if (ePhysChans&1)
		ModifyGraph axisEnab(left)={0.52, 1}
	endif
	if (ePhysChans&2)
		ModifyGraph axisEnab(right)={0.52, 1}
	endif
	// rois get bottom half of graph, if sharing
	if ((cmpstr (AxisInfo("twoP_TracesGraph", "ROILAXIS"), "")) != 0)	// then we have ROIS on Roileft axis
		if (ePhysChans > 0)
			ModifyGraph /W=twoP_TracesGraph axisEnab(ROILAxis)={0,0.48}
		else
			ModifyGraph /W=twoP_TracesGraph axisEnab(ROILAxis)={0,1}
		endif
		Label ROILAxis "\\Z12Raw 12 bit A/D"
		ModifyGraph /W=twoP_TracesGraph freePos(ROILAxis)={0,kwFraction},  lblPos(ROILAxis)=45
	endif
	if ((cmpstr (AxisInfo("twoP_TracesGraph", "ROIRAXIS"), "")) != 0)	// then we have ROIS on RoiRight axis
		if (ePhysChans > 0)
			ModifyGraph /W=twoP_TracesGraph axisEnab(ROIRAxis)={0,0.48}
		else
			ModifyGraph /W=twoP_TracesGraph axisEnab(ROIRAxis)={0,1}
		endif
		Label ROIRAxis "\\Z12Delta F/F"
		ModifyGraph /W=twoP_TracesGraph freePos(ROIRAxis)={0,kwFraction}, lblPos(ROIRAxis)=40
	endif
end


//******************************************************************************************************
// SHows the trces graph, or makes it
Function NQ_showTracesProc(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR curScan = root:packages:twoP:examine:curScan
	NQ_NewTracesGraph (curScan)
End

//******************************************************************************************************
// Takes the wavenote of the current scan and puts it into the notelist wave, so it will fit nicely in the scrolling textbox on the
// examine scans panel. The character width is important here depending on your platform. So change it as necessary. Inelegant, but it's the best you get right now
// Last Modified:
// 2016/11/24 by Jamie Boyd
STATIC CONSTANT NQNOTECHARWID = 44	// Must match the width of our listbox, in characters. If your text is spilling past the end of the line, set CharWid smaller

function NQ_showNote (ScanStrName)
	string ScanStrName
	
	SVAR scanStr = $ScanStrName
	WAVE/T notelistwave = root:Packages:twoP:examine:notelistwave
	string theNoteStr = stringbykey ("expnote", scanStr, ":", "\r")
	variable notelen = strlen (theNoteStr)
	variable ii, ie, ni
	Redimension/N=0 NoteListWave
	FOR (ii =0, ni =0, ie = NQNOTECHARWID; ii < noteLen; ii = ie +1, ie += NQNOTECHARWID + 1, ni += 1)
		if ((ie < notelen) && (cmpstr (theNoteStr [ii + NQNOTECHARWID], " ") != 0))
			do
				ie -= 1
				if (((cmpstr (theNoteStr [ie], " ")) == 0) || (cmpstr (theNoteStr [ie], ";") == 0))
					break
				endif
			while (ie > ii)
			if ((ie - ii) < 4)
				ie = ii + NQNOTECHARWID
			endif
		endif
		insertpoints ni, 1, NoteListWave
		NoteListWave [ni] = theNoteStr [ii, ie]
	ENDFOR
end

//******************************************************************************************************
// Allows you to edit the wavenote by double clicking on the wave note textbox in the examine scans list box.
// Last Modified: 2012/06/13 by Jamie Boyd
Function NQ_EditNoteProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba
	
	switch( lba.eventCode )
		case 3:  // double click
			SVAR CurScan = root:Packages:twoP:examine:curScan
			if (cmpStr (CurScan, "LiveWave") == 0)
				doAlert 0, "You can't edit a note for Live Scanning - it won't be saved anywhere."
				return 1
			endif
			SVAR scanStr = $"root:twoP_Scans:" + CurScan + ":" + curScan +"_info"
			string ExpNoteStr  = stringbykey ("ExpNote",scanStr, ":", "\r")
			Prompt ExpNoteStr, "Experiment Note For " + CurScan + ":"
			DoPrompt "Edit the Experiment Note", ExpNoteStr
			if (V_Flag)
				return 1
			else
				// check for semicolons with char2num
				variable badChar =0, iChar, nChars = strlen (ExpNoteStr)
				For (iChar = 0; iChar < nChars; iChar +=1)
					if  (char2num (ExpNoteStr [iChar]) == 58)
						ExpNoteStr [iChar, iChar]= "="
						badChar= (1 | badChar)
					elseif (char2num (ExpNoteStr [iChar]) == 13)
						ExpNoteStr [iChar, iChar]= ";"
						badChar= (2 | badChar)
					endif
				endfor
				scanStr = ReplaceStringByKey("ExpNote", scanStr, ExpNoteStr, ":", "\r")
				NQ_showNote ("root:twoP_Scans:" + CurScan + ":" + curScan +"_info")
				string alertStr
				if ((badChar & 3) ==3)
					AlertStr = "Colons and Returns are used as separator characters "
				elseif (badChar & 1)
					AlertStr = "Colons are used to separate keys and values "
				elseif (badChar & 2)
					AlertStr = "Returns are used to separate key:value pairs "
				endif
				if (badChar)
					doAlert 0, AlertStr + "in the\rkey:value\rkey:value\r map in the scan info string, and are unavailble for use in your experiment notes. key=value;key=value can be used, though."  
				endif
			endif
			break
	endswitch
	return 0            // other return values reserved
End


//******************************************************************************************************
// ---------Functions for image histogram and for managing LUT and image display-------------
//******************************************************************************************************

// Makes graph for histogram display, or just brings it to the front if it already exists
// Last Modified Jul 06 2010 by Jamie Boyd
Function NQ_MakeHistGraph (scanChans, curScan)
	variable scanChans
	string curScan
	
	doWindow/F twoP_HistGraph
	if (V_Flag)
		DoWindow /T twoP_HistGraph,  curScan + " Histogram"
	else
		WAVE HistWaveCh1 = root:Packages:twoP:Examine:HistWaveCh1
		WAVE HistWaveCh2 =  root:Packages:twoP:Examine:HistWaveCh2
		display/N=twoP_HistGraph/k=1 as curScan + " Histogram"
		WC_WindowCoordinatesRestore("twoP_HistGraph")// ApplyWinPosStr ("twoP_HistGraph")
		appendtograph HistWaveCh1
		appendtograph/R HistWaveCh2
		ModifyGraph axThick(left)=0,axThick(right)=0
		ModifyGraph mode=1
		ModifyGraph rgb=(0,0,0)
		// sliders
		WAVE leftyCh1 = root:Packages:twoP:examine:ImRangeLeftyCh1
		WAVE leftxCh1 = root:Packages:twoP:examine:ImRangeLeftxCh1
		WAVE leftyCh2 = root:Packages:twoP:examine:ImRangeLeftyCh2
		WAVE leftxCh2 = root:Packages:twoP:examine:ImRangeLeftxCh2
		WAVE rightyCh1 = root:Packages:twoP:examine:ImRangerightyCh1
		WAVE rightxCh1 = root:Packages:twoP:examine:ImRangerightxCh1
		WAVE rightyCh2 = root:Packages:twoP:examine:ImRangerightyCh2
		WAVE rightxCh2 = root:Packages:twoP:examine:ImRangerightxCh2
		NVAR Ch1First = root:Packages:twoP:examine:Ch1FirstLUTColor
		NVAR Ch1Last = root:Packages:twoP:examine:Ch1LastLUTColor
		NVAR Ch2First = root:Packages:twoP:examine:Ch2FirstLUTColor
		NVAR Ch2Last = root:Packages:twoP:examine:Ch2LastLUTColor
		leftxCh1 = Ch1First
		rightxCh1 = Ch1Last
		leftxCh2 = Ch2First
		rightxCh2 = Ch2Last
		appendtograph/W=twoP_HistGraph leftyCh1 vs leftxCh1
		appendtograph/W=twoP_HistGraph/r leftyCh2 vs leftxCh2
		modifygraph/W=twoP_HistGraph rgb (ImRangeLeftyCh1) = (0,0,65535), lsize(ImRangeLeftyCh1)=2,quickdrag(ImRangeLeftyCh1)=1, live (ImRangeLeftyCh1)=1
		modifygraph/W=twoP_HistGraph rgb (ImRangeLeftyCh2) = (0,0,65535), lsize(ImRangeLeftyCh2)=2,quickdrag(ImRangeLeftyCh2)=1, live (ImRangeLeftyCh2)=1
		appendtograph/W=twoP_HistGraph rightyCh1 vs rightxCh1
		appendtograph/W=twoP_HistGraph/r rightyCh2 vs rightxCh2
		modifygraph/W=twoP_HistGraph rgb (ImRangerightyCh1) = (65535,0,0), lsize(ImRangerightyCh1)=2,quickdrag(ImRangerightyCh1)=1
		modifygraph/W=twoP_HistGraph rgb (ImRangerightyCh2) = (65535,0,0), lsize(ImRangerightyCh2)=2,quickdrag(ImRangerightyCh2)=1
		label bottom "Raw A/D Value"
		setwindow twoP_HistGraph hook(winHook) = NQ_HistGraph_Hook, hookevents = 3
		controlbar 22
		CheckBox LinearCheck,pos={4,2},size={53,16},proc=NQ_HistAxisCheckProc,title="Linear"
		CheckBox LinearCheck,fSize=12,value= 1,mode=1
		CheckBox LogCheck,pos={67,2},size={40,16},proc=NQ_HistAxisCheckProc,title="Log"
		CheckBox LogCheck,fSize=12,value= 0,mode=1
	endif
	switch (scanchans)
		case 0:
			doWindow/K twoP_HistGraph
			break
		case 1:
			ModifyGraph/W=twoP_HistGraph axisEnab(left)={0, 0.995}
			ModifyGraph/W=twoP_HistGraph axisEnab(right)={0.995,1}
			label/W=twoP_HistGraph right ""
			label/W=twoP_HistGraph left "Channel 1 Number"
			ModifyGraph/W=twoP_HistGraph nticks(right)=0
			ModifyGraph/W=twoP_HistGraph nticks(left)=5
			ModifyGraph/W=twoP_HistGraph hideTrace(HistWaveCh2)=1
			ModifyGraph/W=twoP_HistGraph hideTrace(HistWaveCh1)=0
			break
		case 2:
			ModifyGraph/W=twoP_HistGraph axisEnab(left)={0, 0.005}
			ModifyGraph/W=twoP_HistGraph axisEnab(right)={0.005, 1}
			label/W=twoP_HistGraph left ""
			label/W=twoP_HistGraph right "Channel 2 Number"
			ModifyGraph/W=twoP_HistGraph nticks(left)=0
			ModifyGraph/W=twoP_HistGraph nticks(right)=5
			ModifyGraph/W=twoP_HistGraph hideTrace(HistWaveCh2)=0
			ModifyGraph/W=twoP_HistGraph hideTrace(HistWaveCh1)=1

			break
		case 3:
			ModifyGraph/W=twoP_HistGraph axisEnab(left)={0.49,1}
			ModifyGraph/W=twoP_HistGraph axisEnab(right)={0,0.48}
			label/W=twoP_HistGraph left "Channel 1 Number"
			label/W=twoP_HistGraph right "Channel 2 Number"
			ModifyGraph/W=twoP_HistGraph nticks(left)=5
			ModifyGraph/W=twoP_HistGraph nticks(right)=5
			ModifyGraph/W=twoP_HistGraph hideTrace(HistWaveCh2)=0
			ModifyGraph/W=twoP_HistGraph hideTrace(HistWaveCh1)=0
	endswitch
end

//********************************************************************************************
// Sets left axes to log or linear scaling when corresponding checkboxes are activated
// Last Modified Sep 06 2009 by Jamie Boyd
Function NQ_HistAxisCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			if (cmpStr (cba.ctrlName, "LinearCheck") == 0)
				checkbox LogCheck value = 0
				ModifyGraph log (left) =0
				ModifyGraph log (right) = 0
			else
				checkbox LinearCheck value = 0
				ModifyGraph log (left) =1
				ModifyGraph log (right) = 1
			endif
			break
	endswitch
	return 0
End

//********************************************************************************************
// makes a histogram from the current scan
// if shift key (eventMod bit 1) held down, skip updating channel 2
// if command/ctrl (eventMod bit 3) key held down, skip updating of channel 1
// Last Modified Jul 14 2010  by Jamie Boyd
Function NQ_ShowHistogramProc (ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR  curScan = root:packages:twoP:examine:curScan
			if (cmpStr (curScan, "LiveWave") == 0)
				SVAR scanStr =root:packages:twoP:Acquire:LiveModeScanStr
			else
				SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
			endif
			variable mode = NumberByKey("mode", scanStr, ":", "\r") 
			variable imChans =  NumberByKey("imChans", scanStr, ":", "\r") 
			if(! (imChans & 1))
				checkbox HistCH1check, win = twoP_Controls, value = 0
			endif
			if(! (imChans & 2))
				checkbox HistCH2check, win = twoP_Controls, value = 0
			endif
			controlinfo /w = twoP_Controls HistCH1check
			variable scanChans = V_Value * (imChans & 1) 
			variable doChans = scanChans  *  ((ba.eventMod & 8) != 8)
			controlinfo /w = twoP_Controls HistCH2check
			scanChans += 2*(V_Value * ((imChans & 2) ==2))
			doChans += 2*(V_Value * ((imChans & 2) ==2) * ((ba.eventMod & 2) != 2))
			if (scanChans == 0)
				doWindow/K twoP_HistGraph
				return 1
			endif
			NQ_MakeHistGraph (scanChans, curScan)
			variable doframe 
			if ((mode == kLineScan) || (mode == (kSingleImage)))  // these modes are displayed 
				doFrame = 0
			elseif (mode == kLiveMode)
				doFrame = 1
			else
				controlinfo/w= twoP_Controls HistFrameCheck
				doFrame = V_Value
			endif
			string subWinList = childWindowList ("twoPscanGraph")
			WAVE HistWave = root:Packages:twoP:Examine:HistWaveCh1
			if (doChans & 1)
				if (doFrame)
					WAVE/z chWave = root:packages:twoP:examine:scanGraph_ch1
					// if not displayed, chWave will not be correct
					if ((WhichListItem("GCH1", SubWinList) == -1)&& (WhichListItem("GMRG", SubWinList) == -1))
						WAVE scanwave =$"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
						NVAR curVal = root:packages:twoP:examine:curFramePos
						ProjectZSlice (scanwave, chWave, curval)
					endif
				else // whole stack
					WAVE/Z chWave =$"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
				endif
				Histogram /B=2 chWave, HistWave
			endif
			WAVE HistWave = root:Packages:twoP:Examine:HistWaveCh2
			if (doChans & 2)
				if (doFrame)
					WAVE/z chWave = root:packages:twoP:examine:scanGraph_ch2
					if ((WhichListItem("GCH2", SubWinList) == -1) && (WhichListItem("GMRG", SubWinList) == -1))
						WAVE scanwave =$"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
						NVAR curVal = root:packages:twoP:examine:curFramePos
						ProjectZSlice (scanwave, chWave, curval)
					endif
				else // whole stack
					WAVE/Z chWave =$"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
				endif
				Histogram /B=2 chWave, HistWave
			endif
			break
	endswitch
	return 0
End

//********************************************************************************************
// Unchecks other radio button and calls histogram button procedure when checked
// last modified Sep 06 2009 by Jamie Boyd
Function NQ_HistCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			if (cmpStr (cba.ctrlname, "HistFrameCheck") == 0)
				checkbox HistStackCheck, win = twoP_Controls, value = 0
			else
				checkbox HistFrameCheck, win = twoP_Controls, value = 0
			endif
			STRUCT WMButtonAction ba
			ba.eventCode = 2
			NQ_ShowHistogramProc (ba)
			break
	endswitch
	return 0
End


//********************************************************************************************
// Calls histogram button procedure when checked/uncheked
// last modified Jul 14 2010 by Jamie Boyd
Function NQ_HistChanCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			SVAR  curScan = root:packages:twoP:examine:curScan
			if (cmpStr (curScan, "LiveWave") == 0)
				SVAR scanStr =root:packages:twoP:Acquire:LiveModeScanStr
			else
				SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
			endif
			variable imChans =  NumberByKey("imChans", scanStr, ":", "\r") 
			STRUCT WMButtonAction ba
			ba.eventCode = 2
			if (cmpStr (cba.ctrlName, "HistCH1check") == 0)
				if (cba.checked)
					if (!(imChans & 1))
						checkBox HistCH1check, win = twoP_Controls , value = 0
						return 1
					endif
				endif
				ba.eventMod =2 // shift key for don't do channel 2
			elseif (cmpStr (cba.ctrlName, "HistCH2check") == 0)
				if (!(imChans & 2))
					checkBox HistCH2check, win = twoP_Controls , value = 0
					return 1
				endif
				ba.eventMod =8 // command/ctrl key for don't do channel 1
			endif
			NQ_ShowHistogramProc (ba)
			break
	endswitch

	return 0
End

//********************************************************************************************
// A hook function that saves window size/position on quit and runs the left and right offset draggers on the histogram
// last modified AUg 31 2011 by Jamie Boyd
Function NQ_HistGraph_Hook (s)
	STRUCT WMWinHookStruct &s

	Variable hookResult = 0
	Switch (s.eventCode)
		case 2: // kill
			// save window size
			WC_WindowCoordinatesSave(s.winName)//SaveWinPosStr (s.winName)
			hookResult = 1
			break
		case 4:
		case 5: //mouseup
			NVAR Ch1First = root:Packages:twoP:examine:Ch1FirstLUTColor
			NVAR Ch1Last = root:Packages:twoP:examine:Ch1LastLUTColor
			NVAR Ch2First = root:Packages:twoP:examine:Ch2FirstLUTColor
			NVAR Ch2Last = root:Packages:twoP:examine:Ch2LastLUTColor
			WAVE leftyCh1 = root:Packages:twoP:examine:ImRangeLeftyCh1
			WAVE leftxCh1 = root:Packages:twoP:examine:ImRangeLeftxCh1
			WAVE leftyCh2 = root:Packages:twoP:examine:ImRangeLeftyCh2
			WAVE leftxCh2 = root:Packages:twoP:examine:ImRangeLeftxCh2
			WAVE rightyCh1 = root:Packages:twoP:examine:ImRangerightyCh1
			WAVE rightxCh1 = root:Packages:twoP:examine:ImRangerightxCh1
			WAVE rightyCh2 = root:Packages:twoP:examine:ImRangerightyCh2
			WAVE rightxCh2 = root:Packages:twoP:examine:ImRangerightxCh2
			variable needUpdate = 0
			string traces = TraceNameList("twoP_HistGraph", ";", 1)
			if (WhichListItem("ImRangeLeftyCh1", traces, ";") > -1)
				string tempstr = stringbykey ( "offset(x)", TraceInfo("twoP_HistGraph", "ImRangeLeftyCh1", 0 ),"=", ";")
				variable ep = strsearch(tempstr, ",", 0 )
				variable offset = str2num(tempstr [1, ep])
				if (offset != 0)
					needUpdate = 1
					leftxCh1 += offset
					Ch1First = max (1, leftxCh1 [0])
					leftxCh1 =Ch1First
					ModifyGraph offset(ImRangeLeftyCh1)={0,0}
				endif
				tempstr = stringbykey ( "offset(x)", TraceInfo("twoP_HistGraph", "ImRangeRightyCh1", 0 ),"=", ";")
				ep = strsearch(tempstr, ",", 0 )
				Offset = str2num(tempstr [1, ep])
				if (offset != 0)
					needUpdate = 1
					rightxCh1 += offset
					Ch1Last = min ((2^kNQimageBits)-2, rightxCh1 [0])
					rightxCh1 = ch1Last
					ModifyGraph offset(ImRangeRightyCh1)={0,0}
				endif
			endif
			if (WhichListItem("ImRangeLeftyCh2", traces, ";") > -1)
				tempstr = stringbykey ( "offset(x)", TraceInfo("twoP_HistGraph", "ImRangeLeftyCh2", 0 ),"=", ";")
				ep = strsearch(tempstr, ",", 0 )
				offset = str2num(tempstr [1, ep])
				if (offset != 0)
					needUpdate = 2
					leftxCh2 += offset
					Ch2First = max (1, leftxCh2 [0])
					leftxCh2 = Ch2First
					ModifyGraph offset(ImRangeLeftyCh2)={0,0}
				endif
				tempstr = stringbykey ( "offset(x)", TraceInfo("twoP_HistGraph", "ImRangeRightyCh2", 0 ),"=", ";")
				ep = strsearch(tempstr, ",", 0 )
				offset = str2num(tempstr [1, ep])
				if (offset != 0)
					needUpdate = 2
					rightxCh2  += offset
					Ch2Last = min ((2^kNQimageBits)-2, rightxCh2 [0])
					rightxCh2 = Ch2Last
					ModifyGraph offset(ImRangeRightyCh2)={0,0}
				endif
			endif
			if (needUpdate)
				NVAR showMerge = root:packages:twoP:examine:showMerge
				NQ_ApplyImSettings (needUpdate + showMerge * 4)
				hookResult = 1
			endif
			break
		default:
			// 0 if nothing done, else 1 or 2
	endswitch
	return hookResult
End

//********************************************************************************************
// Function for the Channel radio buttons. When a channel is selected, it loads appropriate 
// global variables for that channel and adjusts controls to show/edit LUT settings for that channel 
// Last Modified May 27 2009 by Jamie
Function NQ_ChanForLUTcheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			variable rColor, gColor, bColor
			if (cmpStr (cba.ctrlName, "LUTChan1Check") == 0)
				// Uncheck channel 2 checkbox
				checkBox LUTChan2Check  win=twoP_Controls, value = 0
				// adjust LUT popmenu
				NVAR CTable = root:Packages:twoP:examine:Ch1CTable
				popupmenu LUTpopUp mode = CTable
				// Adjust invert check
				checkbox LUTInvertCheck win=twoP_Controls, variable =root:Packages:twoP:examine:Ch1LUTInvert
				// adjust First and Last color SetVariables
				setvariable LUTFirstValueSetVar win=twoP_Controls, variable =root:Packages:twoP:examine:Ch1FirstLUTColor
				setvariable LUTLastValueSetVar win=twoP_Controls, variable =root:Packages:twoP:examine:Ch1LastLUTColor
				// Adjust First and last sliders
				Slider LUTFirstValSlider win=twoP_Controls, variable= root:Packages:twoP:examine:Ch1FirstLUTColor
				Slider LUTLastValSlider win=twoP_Controls, variable= root:Packages:twoP:examine:Ch1LastLUTColor
				// Adjust LUT autoCheck
				checkbox LUTautoCheck win=twoP_Controls, variable = root:packages:twoP:examine:ch1LUTauto
				// Adjust first color radio buttons and popmenu
				NVAR beforeMode = root:Packages:twoP:examine:Ch1BeforeMode
				switch (beforeMode) // 0 means first color, 1 means selected color, 2 means transparent
					case 0: // Use first color
						checkbox LUTBeforeUseFirstCheck win=twoP_Controls, value = 1
						checkbox LUTBeforeUseColorCheck win=twoP_Controls, value = 0
						checkBox LUTBeforeUseTransCheck  win=twoP_Controls, value = 0
						break
					case 1: // Use selected color
						checkbox LUTBeforeUseFirstCheck win=twoP_Controls, value = 0
						checkbox LUTBeforeUseColorCheck win=twoP_Controls, value = 1
						checkBox LUTBeforeUseTransCheck  win=twoP_Controls, value = 0
						SVAR beforeColors = root:Packages:twoP:examine:Ch1BeforeColors
						rColor = str2num (stringFromlist (0, beforeColors, ","))
						gColor = str2num (stringFromlist (1, beforeColors, ","))
						bColor = str2num (stringFromlist (2, beforeColors, ","))
						popupmenu LUTBeforeColorPopUp win=twoP_Controls, popcolor = (rColor,gColor,bColor)
						break
					case 2: // Use transparent
						checkbox LUTBeforeUseFirstCheck win=twoP_Controls, value = 0
						checkbox LUTBeforeUseColorCheck win=twoP_Controls, value = 0
						checkBox LUTBeforeUseTransCheck  win=twoP_Controls, value = 1
						break
				endSwitch
				// Adjust Last color radio buttons and popmenu
				NVAR afterMode = root:Packages:twoP:examine:Ch1AfterMode
				switch (afterMode) // 0 means last color, 1 means selected color, 2 means transparent
					case 0: // Use last color
						checkbox LUTAfterUseLastCheck win=twoP_Controls, value = 1
						checkbox LUTAfterUseColorCheck win=twoP_Controls, value = 0
						checkBox LUTAfterUseTransCheck  win=twoP_Controls, value = 0
						break
					case 1: // Use selected color
						checkbox LUTAfterUseLastCheck win=twoP_Controls, value = 0
						checkbox LUTAfterUseColorCheck win=twoP_Controls, value = 1
						checkBox LUTAfterUseTransCheck  win=twoP_Controls, value = 0
						SVAR afterColors = root:Packages:twoP:examine:Ch1AfterColors
						rColor = str2num (stringFromlist (0, afterColors, ","))
						gColor = str2num (stringFromlist (1, afterColors, ","))
						bColor = str2num (stringFromlist (2, afterColors, ","))
						popupmenu LUTAfterColorPopUp win=twoP_Controls, popcolor = (rColor,gColor,bColor)
						break
					case 2: // Use transparent
						checkbox LUTAfterUseLastCheck win=twoP_Controls, value = 0
						checkbox LUTAfterUseColorCheck win=twoP_Controls, value = 0
						checkBox LUTAfterUseTransCheck  win=twoP_Controls, value = 1
						break
				endSwitch
			else // Channel 2 selected
				// Uncheck channel 1 checkbox
				checkBox LUTChan1Check  win=twoP_Controls, value = 0
				// adjust LUT popmenu
				NVAR CTable = root:Packages:twoP:examine:Ch2CTable
				popupmenu LUTpopUp mode = CTable
				// Adjust invert check
				checkbox LUTInvertCheck win=twoP_Controls, variable =root:Packages:twoP:examine:Ch2LUTInvert
				// adjust First and Last color SetVariables
				setvariable LUTFirstValueSetVar win=twoP_Controls, variable =root:Packages:twoP:examine:Ch2FirstLUTColor
				setvariable LUTLastValueSetVar win=twoP_Controls, variable =root:Packages:twoP:examine:Ch2LastLUTColor
				// Adjust First and last sliders
				Slider LUTFirstValSlider win=twoP_Controls, variable= root:Packages:twoP:examine:Ch2FirstLUTColor
				Slider LUTLastValSlider win=twoP_Controls, variable= root:Packages:twoP:examine:Ch2LastLUTColor
				// Adjust LUT autoCheck
				checkbox LUTautoCheck win=twoP_Controls, variable = root:packages:twoP:examine:ch2LUTauto
				// Adjust first color radio buttons and popmenu
				NVAR beforeMode = root:Packages:twoP:examine:Ch2BeforeMode
				switch (beforeMode) // 0 means first color, 1 means selected color, 2 means transparent
					case 0: // Use first color
						checkbox LUTBeforeUseFirstCheck win=twoP_Controls, value = 1
						checkbox LUTBeforeUseColorCheck win=twoP_Controls, value = 0
						checkBox LUTBeforeUseTransCheck  win=twoP_Controls, value = 0
						break
					case 1: // Use selected color
						checkbox LUTBeforeUseFirstCheck win=twoP_Controls, value = 0
						checkbox LUTBeforeUseColorCheck win=twoP_Controls, value = 1
						checkBox LUTBeforeUseTransCheck  win=twoP_Controls, value = 0
						SVAR beforeColors = root:Packages:twoP:examine:Ch2BeforeColors
						rColor = str2num (stringFromlist (0, beforeColors, ","))
						gColor = str2num (stringFromlist (1, beforeColors, ","))
						bColor = str2num (stringFromlist (2, beforeColors, ","))
						popupmenu LUTBeforeColorPopUp win=twoP_Controls, popcolor = (rColor,gColor,bColor)
						break
					case 2: // Use transparent
						checkbox LUTBeforeUseFirstCheck win=twoP_Controls, value = 0
						checkbox LUTBeforeUseColorCheck win=twoP_Controls, value = 0
						checkBox LUTBeforeUseTransCheck  win=twoP_Controls, value = 1
						break
				endSwitch
				// Adjust Last color radio buttons and popmenu
				NVAR afterMode = root:Packages:twoP:examine:Ch2AfterMode
				switch (afterMode) // 0 means last color, 1 means selected color, 2 means transparent
					case 0: // Use last color
						checkbox LUTAfterUseLastCheck win=twoP_Controls, value = 1
						checkbox LUTAfterUseColorCheck win=twoP_Controls, value = 0
						checkBox LUTAfterUseTransCheck  win=twoP_Controls, value = 0
						break
					case 1: // Use selected color
						checkbox LUTAfterUseLastCheck win=twoP_Controls, value = 0
						checkbox LUTAfterUseColorCheck win=twoP_Controls, value = 1
						checkBox LUTAfterUseTransCheck  win=twoP_Controls, value = 0
						SVAR afterColors = root:Packages:twoP:examine:Ch2AfterColors
						rColor = str2num (stringFromlist (0, afterColors, ","))
						gColor = str2num (stringFromlist (1, afterColors, ","))
						bColor = str2num (stringFromlist (2, afterColors, ","))
						popupmenu LUTAfterColorPopUp win=twoP_Controls, popcolor = (rColor,gColor,bColor)
						break
					case 2: // Use transparent
						checkbox LUTAfterUseLastCheck win=twoP_Controls, value = 0
						checkbox LUTAfterUseColorCheck win=twoP_Controls, value = 0
						checkBox LUTAfterUseTransCheck  win=twoP_Controls, value = 1
						break
				endSwitch
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Function for the LUT popup menu. Allows you to select a look up table to use for selected channel of the scan
// Last Modified Sep 03 2009 by Jamie Boyd
Function NQ_LUTPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			// save changed value in appropriate global for selected channel
			controlinfo/w= twoP_Controls LUTChan1Check
			if (V_Value== 1) // Channel 1 checked
				NVAR CTable = root:Packages:twoP:examine:Ch1CTable
				SVAR ctableStr = root:Packages:twoP:examine:Ch1CTableStr
				CTable = pa.popNum
				cTableStr = popStr
				// Apply Image settings for channel 1
				if (WhichListItem("GCH1", childwindowlist ("twoPscanGraph")) > -1)
					NQ_ApplyImSettings (1)
				endif
			else // chan 2
				NVAR CTable = root:Packages:twoP:examine:Ch2CTable
				SVAR ctableStr = root:Packages:twoP:examine:Ch2CTableStr
				CTable = pa.popNum
				cTableStr = popStr
				// Apply Image settings for channel 2
				if (WhichListItem("GCH2", childwindowlist ("twoPscanGraph")) > -1)
					NQ_ApplyImSettings (2)
				endif
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Function for the LUTinvert Check. This allows you to invert the LUT for selected channel of the scan
// Last Modified Sep 03 2009 by Jamie Boyd
Function NQ_LutInvertCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			//Update image settings for selected channel
			controlinfo/w= twoP_Controls LUTChan1Check
			if (V_Value== 1) // Channel 1 checked
				if (WhichListItem("GCH1", childwindowlist ("twoPscanGraph")) > -1)
					NQ_ApplyImSettings (1)
				endif
			else // channel 2 selected
				if (WhichListItem("GCH2", childwindowlist ("twoPscanGraph")) > -1)
					NQ_ApplyImSettings (2)
				endif
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Function for the LUT first and last values Setvariables.Calls Apply Image settings procedure for selected channel
// Last Modified Jun 01 2009 by Jamie
Function NQ_LUTValsSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			controlinfo/w= twoP_Controls LUTChan1Check
			// Keep first color and last color on right side of each other
			if (V_Value== 1) // Channel 1 checked
				NVAR FirstColor = root:packages:twoP:examine:CH1FirstLutColor
				NVAR LastColor = root:packages:twoP:examine:CH1LastLutColor
				WAVE leftWave = root:Packages:twoP:examine:ImRangeLeftxCh1
				WAVE rightWave = root:Packages:twoP:examine:ImRangerightxCh1
			else // channel 2 selected
				NVAR FirstColor = root:packages:twoP:examine:CH2FirstLutColor
				NVAR LastColor = root:packages:twoP:examine:CH2LastLutColor
				WAVE leftWave = root:Packages:twoP:examine:ImRangeLeftxCh2
				WAVE rightWave = root:Packages:twoP:examine:ImRangerightxCh2
			endif
			if (cmpstr (sva.ctrlname, "LUTFirstValueSetVar") == 0)
				if (dval > LastColor)
					FirstColor = LastColor -1
				endif
				leftWave = FirstColor
			else
				if (dval <  firstColor)
					LastColor = FirstColor + 1
				endif
				rightWave = LastColor
			endif
			// apply image settings
			string SubWinList = childwindowlist ("twoPscanGraph")
			variable hasChan, hasMrg = (WhichListItem("GMRG", SubWinList) > -1)
			if (V_Value== 1) // Channel 1 checked
				hasChan = (WhichListItem("GCH1", SubWinList) > -1)
				if (hasChan || hasMrg)
					NQ_ApplyImSettings (hasChan + 4 * hasMrg)
				endif
			else // channel 2 selected
				hasChan = (WhichListItem("GCH2", SubWinList) > -1)
				if (hasChan || hasMrg)
					NQ_ApplyImSettings (2 * hasChan + 4 * hasMrg)
				endif
			endif
			break
	endswitch
	return 0
End
				
//******************************************************************************************************
// Function for the LUT first and last values Sliders.Calls Apply Image settings procedure for selected channel
// Last Modified Seo 03 2009 by Jamie
Function NQ_LUTValSliderProc(sa) : SliderControl
	STRUCT WMSliderAction &sa

	switch( sa.eventCode )
		case -1: // kill
			break
		default:
			if( sa.eventCode & 1 ) // value set
				Variable curval = sa.curval
				// Keep first color and last color on right side of each other
				controlinfo/w= twoP_Controls LUTChan1Check
				if (V_Value== 1) // Channel 1 checked
					NVAR FirstColor = root:packages:twoP:examine:CH1FirstLutColor
					NVAR LastColor = root:packages:twoP:examine:CH1LastLutColor
					WAVE leftWave = root:Packages:twoP:examine:ImRangeLeftxCh1
					WAVE rightWave = root:Packages:twoP:examine:ImRangerightxCh1
				else // channel 2 selected
					NVAR FirstColor = root:packages:twoP:examine:CH2FirstLutColor
					NVAR LastColor = root:packages:twoP:examine:CH2LastLutColor
					WAVE leftWave = root:Packages:twoP:examine:ImRangeLeftxCh2
					WAVE rightWave = root:Packages:twoP:examine:ImRangerightxCh2
				endif
				if (cmpstr (sa.ctrlname, "LUTFirstValSlider") == 0)
					if (curval >= LastColor)
						LastColor = FirstColor  + 1
					endif
					leftWave = FirstColor
				else
					if (curval <=  firstColor)
						FirstColor = LastColor - 1
					endif
					rightWave = LastColor
				endif
				// Apply image settings
				string SubWinList = childwindowlist ("twoPscanGraph")
				variable hasChan, hasMrg = (WhichListItem("GMRG", SubWinList) > -1)
				if (V_Value== 1) // Channel 1 checked
					hasChan = (WhichListItem("GCH1", SubWinList) > -1)
					if (hasChan || hasMrg)
						NQ_ApplyImSettings (hasChan + 4 * hasMrg)
					endif
				else //channel 2
					hasChan = (WhichListItem("GCH2", SubWinList) > -1)
					if (hasChan || hasMrg)
						NQ_ApplyImSettings (2 * hasChan + 4 * hasMrg)
					endif
				endif
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Sets first and last colors to Min/Max of data, then calls Apply Image settings procedure for selected channel
// Last Modified:
//  2017/09/07 by Jamie Boyd - modified for unsigned data, and generally cleaned up
Function NQ_LUTtoDataProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR curScanStr = root:packages:twoP:examine:curScan
			// check which channel is selected
			controlinfo/w= twoP_Controls LUTChan1Check
			variable isChan1 = V_Value
			if (isChan1)
				NVAR FirstColor = root:packages:twoP:examine:CH1FirstLutColor
				NVAR LastColor = root:packages:twoP:examine:CH1LastLutColor
				WAVE leftWave = root:Packages:twoP:examine:ImRangeLeftxCh1
				WAVE rightWave = root:Packages:twoP:examine:ImRangerightxCh1
			else
				NVAR FirstColor = root:packages:twoP:examine:CH2FirstLutColor
				NVAR LastColor = root:packages:twoP:examine:CH2LastLutColor
				WAVE leftWave = root:Packages:twoP:examine:ImRangeLeftxCh2
				WAVE rightWave = root:Packages:twoP:examine:ImRangerightxCh2
			endif
			// check for live wave, need to find temp scan waves, else just normal scans
			variable isLiveWave
			if (cmpStr (curScanStr, "LiveWave") == 0)
				isLiveWave =1
				if (isChan1) // Channel 1 checked
					WAVE/z curScanG = root:packages:twoP:acquire:LiveAcq_ch1
				else // channel 2
					WAVE/z curScanG = root:packages:twoP:acquire:LiveAcq_ch2
				endif
				if (!(waveExists (curScanG)))
					return 1
				endif
				NVAR pixWidth= root:Packages:twoP:Acquire:pixWidth
				NVAR pixHeight=  root:Packages:twoP:Acquire:pixHeight
				Duplicate/FREE curScanG curScan
				fastop curScan= curScan + (kNQtoUnsigned)
				redimension/n = (pixWidth, pixHeight)curScan
			else // an existing scan
				isLiveWave =0
				if (isChan1) // Channel 1 checked
					WAVE/z curScan = $"root:twoP_Scans:" + curScanStr + ":" + curScanStr + "_ch1"
				else // channel 2
					WAVE/z curScan = $"root:twoP_Scans:" + curScanStr + ":" + curScanStr + "_ch2"
				endif
				if (!(waveExists (curScan)))
					return 1
				endif
			endif
			// curframepos when needed
			variable is3D = ((isLiveWave ==0) && (WaveDims(curScan) ==3))
			if (is3D)
				NVAR curFramePos = root:Packages:twoP:examine:CurFramePos
			endif
			// check for limiting to 96% - we need a full histogram, else just max and min
			controlinfo/w= twoP_Controls LUT96check
			variable is96 = V_Value
			if (is96)
				if(is3D)
					ImageHistogram/I/P=(curFramePos) curScan
				else
					ImageHistogram/I curScan
				endif
				WAVE W_imagehist
				variable nPnts = numpnts (W_imagehist)
				variable theSum =  sum (W_imagehist)
				variable ii, runningSum, val2 = theSum * 0.02, val98 = theSum * 0.98
				for (ii =0, runningSum = 0; runningSum < val2; ii += 1, runningSum += W_imagehist [ii])
				endfor
				FirstColor = round (pnt2x (W_imagehist, ii))
				for (ii =nPnts-1, runningSum = theSum;  runningSum >val98 ; ii -= 1, runningSum -= W_imagehist [ii])
				endfor
				LastColor = round (pnt2x (W_imagehist, ii))
			else //NOt 96%,just min and max
				if (is3D)
					ImageStats/m=1/P=(curFramePos) curScan
				else
					ImageStats/m=1 curScan
				endif
				FirstColor = V_min
				LastColor = V_max
			endif
			// apply first color and last color to dragger waves
			leftWave = FirstColor
			rightWave = LastColor
			// Apply image settings
			string SubWinList = childwindowlist ("twoPscanGraph")
			variable hasChan, hasMrg = (WhichListItem("GMRG", SubWinList) > -1)
			if (isChan1)
				hasChan = (WhichListItem("GCH1", SubWinList) > -1)
				if (hasChan || hasMrg)
					NQ_ApplyImSettings (hasChan + 4 * hasMrg)
				endif
			else
				hasChan = (WhichListItem("GCH2", SubWinList) > -1)
				if (hasChan || hasMrg)
					NQ_ApplyImSettings (2 * hasChan + 4 * hasMrg)
				endif
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Calls NQ_LUTtoDataProc, so user doesn't have to do it explicitly
// Last Modified July 06 2009 by Jamie
Function NQ_LUT96CheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			STRUCT WMButtonAction ba
			ba.eventCode = 2
			NQ_LUTtoDataProc(ba)
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Manages radio buttons for before first color modes, then calls Apply Image settings procedure for selected channel
// Last Modified Sep 03 2009 by Jamie Boyd
Function NQ_LutBeforeModeCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			string theCheckBox = cba.ctrlName
			variable beforeMode
			strSwitch (theCheckBox)
				case "LUTBeforeUseFirstCheck":
					checkbox LUTBeforeUseColorCheck win=twoP_Controls, value = 0
					checkBox LUTBeforeUseTransCheck  win=twoP_Controls, value = 0
					beforeMode = 0
					break
				case "LUTBeforeUseColorCheck":
					checkbox LUTBeforeUseFirstCheck win=twoP_Controls, value = 0
					checkBox LUTBeforeUseTransCheck  win=twoP_Controls, value = 0
					beforeMode = 1
					break
				case "LUTBeforeUseTransCheck":
					checkbox LUTBeforeUseFirstCheck win=twoP_Controls, value = 0
					checkbox LUTBeforeUseColorCheck win=twoP_Controls, value = 0
					beforeMode = 2
					break
			endSwitch
			string SubWinList = childwindowlist ("twoPscanGraph")
			variable hasChan
			controlinfo/w= twoP_Controls LUTChan1Check
			if (V_Value== 1) // Channel 1 checked
				NVAR beforeModeG = root:Packages:twoP:examine:Ch1BeforeMode
				beforeModeG = beforeMode
				if (WhichListItem ("GCH1", childwindowlist ("twoPscanGraph")) > -1)
					NQ_ApplyImSettings (1)
				endif
			else // channel 2 selected
				NVAR beforeModeG = root:Packages:twoP:examine:Ch2BeforeMode
				beforeModeG = beforeMode
				if (WhichListItem ("GCH2", childwindowlist ("twoPscanGraph")) > -1)
					NQ_ApplyImSettings (2)
				endif
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Manages color PopMenu for before first color modes, then calls Apply Image settings procedure for selected channel
// Last Modified Seo 03 2009 by Jamie
Function NQ_BeforeColorPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			// save changed value in appropriate global for selected channel
			controlinfo/w= twoP_Controls LUTChan1Check
			if (V_Value== 1) // Channel 1 checked
				SVAR beforeColors = root:Packages:twoP:examine:Ch1BeforeColors
			else // Channel 2 checked
				SVAR beforeColors = root:Packages:twoP:examine:Ch2BeforeColors
			endif
			// Strip opening and closing braces
			variable bcLen = strlen (popStr)
			beforeColors = popStr [1, bcLen-2]
			// Apply image settings
			if (V_Value== 1) // Channel 1 checked
				if (WhichListItem ("GCH1", childwindowlist ("twoPscanGraph")) > -1)
					NQ_ApplyImSettings (1)
				endif
			else
				if (WhichListItem ("GCH2", childwindowlist ("twoPscanGraph")) > -1)
					NQ_ApplyImSettings (2)
				endif
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Manages radio buttons for after last color modes, then calls Apply Image settings procedure for selected channel
// Last Modified Seo 03 2009 by Jamie Boyd
Function NQ_LutAfterModeCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			string theCheckBox = cba.ctrlName
			variable afterMode
			strSwitch (theCheckBox)
				case "LUTAfterUseLastCheck":
					checkbox LUTAfterUseColorCheck win=twoP_Controls, value = 0
					checkBox LUTAfterUseTransCheck  win=twoP_Controls, value = 0
					afterMode = 0
					break
				case "LUTAfterUseColorCheck":
					checkbox LUTAfterUseLastCheck win=twoP_Controls, value = 0
					checkBox LUTAfterUseTransCheck  win=twoP_Controls, value = 0
					afterMode = 1
					break
				case "LUTAfterUseTransCheck":
					checkbox LUTAfterUseLastCheck win=twoP_Controls, value = 0
					checkbox LUTAfterUseColorCheck win=twoP_Controls, value = 0
					afterMode = 2
					break
			endSwitch
			controlinfo/w= twoP_Controls LUTChan1Check
			if (V_Value== 1) // Channel 1 checked
				NVAR afterModeG = root:Packages:twoP:examine:Ch1AfterMode
				afterModeG = afterMode
				if (WhichListItem ("GCH1", childwindowlist ("twoPscanGraph")) > -1)
					NQ_ApplyImSettings (1)
				endif
			else // channel 2 selected
				NVAR afterModeG = root:Packages:twoP:examine:Ch2afterMode
				afterModeG = afterMode
				if (WhichListItem ("GCH2", childwindowlist ("twoPscanGraph")) > -1)
					NQ_ApplyImSettings (2)
				endif
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Manages color PopMenu for after after last color modes, then calls Apply Image settings procedure for selected channel
// Last Modified Sep 03 2009 by Jamie Boyd
Function NQ_AfterColorPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			// save changed value in appropriate global for selected channel
			controlinfo/w= twoP_Controls LUTChan1Check
			if (V_Value== 1) // Channel 1 checked
				SVAR AfterColors = root:Packages:twoP:examine:Ch1AfterColors
			else // Channel 2 checked
				SVAR AfterColors = root:Packages:twoP:examine:Ch2AfterColors
			endif
			// Strip opening and closing braces
			variable acLen = strlen (popStr)
			AfterColors = popStr [1, acLen-2]
			// Apply image settings
			if (V_Value== 1) // Channel 1 checked
				if (WhichListItem ("GCH1", childwindowlist ("twoPscanGraph")) > -1)
					NQ_ApplyImSettings (1)
				endif
			else
				if (WhichListItem ("GCH2", childwindowlist ("twoPscanGraph")) > -1)
					NQ_ApplyImSettings (2)
				endif
			endif
			break
	endswitch
	return 0
End


//******************************************************************************************************
// Manages Auto LUT selection checkbox, then calls Apply Image settings procedure for selected channel
// Last Modified 2012/06/13 by Jamie Boyd
Function NQ_LUTAutoCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			controlinfo/w= twoP_Controls LUTChan1Check
			if (V_Value== 1) // Channel 1 checked
				NQ_ApplyImSettings (1)
			else
				NQ_ApplyImSettings (2)
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//******************************************************************************************************
// Applies image settings saved in global variables and strings to the current scan wave(s).
// Channels 1 and 2 are done separately with own copies of global variables
// Last Modified 2013/08/08 by Jamie Boyd
Function NQ_ApplyImSettings (channel)
	variable channel // bit 0 for channel 1, bit 1 for 2 for channel 2, bit 2 for merged image
	
	variable mode
	SVAR curScan = root:packages:twoP:examine:curScan
	// acquiring?
	Controlinfo /w = twoP_Controls AcquireExamineTab
	variable isAcquire = (cmpstr (S_Value, "Acquire") == 0) // 1 if called from acquiring tab, 0 if examining.
	// get reference to scan info string
	if (isAcquire) // use live mode info
		SVAR/Z ScanStr = root:packages:twoP:Acquire:LiveModeScanStr
	else
		SVAR/Z ScanStr = $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_info"
	endif
	if (!(SVAR_EXISTS (scanStr)))
		doAlert 0, "The info string for the scan, \"" + CurScan + "\" was not found."
		return 1
	endif
	mode = numberbykey ("mode", scanStr, ":", "\r")
	// bitwise variable for which channels are available
	variable imChans = NumberByKey("ImChans", scanStr, ":", "\r" )
	// reference waves displayed in the graph
	Switch (mode)
		case kLiveMode:
		case kZSeries:
		case kTimeSeries:
			if  (channel & 5)
				wave scangraph_ch1 = root:Packages:twoP:examine:scanGraph_ch1
			endif
			if (channel & 6)
				wave scangraph_ch2 = root:Packages:twoP:examine:scanGraph_ch2
			endif
			break
			// 2D waves displayed directly in the graph
		case kLineScan:
		case kSingleImage:
			if  (channel & 5)
				WAVE scangraph_ch1 =  $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
			endif
			if (channel & 6)
				WAVE scangraph_ch2 = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
			endif
			break
	endSwitch
	// mrg is always the same
	if (channel & 4)
		wave scangraph_mrg = root:Packages:twoP:examine:scanGraph_mrg
	endif
	variable rColor, gColor, bColor
	string ChGraphs = ChildWindowList ("twoPscanGraph")
	// Do Channel 1, if requested and available
	if ((Channel & 1) && (WhichListItem("GCH1", ChGraphs) > -1))
		// Globals
		SVAR CTableStr = root:Packages:twoP:examine:Ch1CTableStr
		NVAR inVert =root:Packages:twoP:examine:Ch1LUTInvert
		NVAR FirstLUTColor = root:Packages:twoP:examine:Ch1FirstLUTColor
		NVAR LastLutColor = root:Packages:twoP:examine:Ch1LastLUTColor
		NVAR autoLUT = root:packages:twoP:Examine:Ch1LUTAuto
		if (autoLUT)
			ModifyImage/w=twoPscanGraph#GCH1 $nameofwave(scangraph_ch1) ctab= {*,*,$CTableStr,inVert}
		else
			ModifyImage/w=twoPscanGraph#GCH1 $nameofwave(scangraph_ch1) ctab= {FirstLUTColor,LastLutColor,$CTableStr,inVert}
			NVAR beforeMode = root:Packages:twoP:examine:Ch1BeforeMode
			switch (beforeMode) // 0 means first color, 1 means selected color, 2 means transparent
				case 0: // Use first color
					ModifyImage/w=twoPscanGraph#GCH1 $nameofwave(scangraph_ch1), minRGB = 0
					break
				case 1: // Use selected color
					SVAR beforeColors = root:Packages:twoP:examine:Ch1BeforeColors
					rColor = str2num (stringFromlist (0, beforeColors, ","))
					gColor = str2num (stringFromlist (1, beforeColors, ","))
					bColor = str2num (stringFromlist (2, beforeColors, ","))
					ModifyImage/w=twoPscanGraph#GCH1 $nameofwave(scangraph_ch1), minRGB = (rColor, gColor, bColor)
					break
				case 2: // transparent
					ModifyImage/w=twoPscanGraph#GCH1 $nameofwave(scangraph_ch1), minRGB = NaN
			endswitch
			NVAR afterMode =  root:Packages:twoP:examine:Ch1AfterMode
			switch (afterMode) // 0 means last color, 1 means selected color, 2 means transparent
				case 0: // Use last color
					ModifyImage/w=twoPscanGraph#GCH1 $nameofwave(scangraph_ch1), maxRGB = 0
					break
				case 1: // Use selected color
					SVAR afterColors = root:Packages:twoP:examine:Ch1AfterColors
					rColor = str2num (stringFromlist (0, afterColors, ","))
					gColor = str2num (stringFromlist (1, afterColors, ","))
					bColor = str2num (stringFromlist (2, afterColors, ","))
					ModifyImage/w=twoPscanGraph#GCH1 $nameofwave(scangraph_ch1), maxRGB = (rColor, gColor, bColor)
					break
				case 2: // transparent
					ModifyImage/w=twoPscanGraph#GCH1 $nameofwave(scangraph_ch1), maxRGB = NaN
			endswitch
		endif
	endif
	// Do Channel 2, if requested
	if ((channel & 2) && (WhichListItem("GCH2", ChGraphs) > -1))
		// Globals
		SVAR CTableStr = root:Packages:twoP:examine:Ch2CTableStr
		NVAR inVert =root:Packages:twoP:examine:Ch2LUTInvert
		NVAR FirstLUTColor = root:Packages:twoP:examine:Ch2FirstLUTColor
		NVAR LastLutColor = root:Packages:twoP:examine:Ch2LastLUTColor
		NVAR autoLUT = root:packages:twoP:Examine:Ch2LUTAuto
		if (autoLUT)
			ModifyImage/w=twoPscanGraph#GCH2 $nameofwave(scangraph_ch2) ctab= {*,*,$CTableStr,inVert}
		else
			ModifyImage/w=twoPscanGraph#GCH2 $nameofwave(scangraph_ch2) ctab= {FirstLUTColor,LastLutColor,$CTableStr,inVert}
			NVAR beforeMode = root:Packages:twoP:examine:Ch2BeforeMode
			switch (beforeMode) // 0 means first color, 1 means selected color, 2 means transparent
				case 0: // Use first color
					ModifyImage/w=twoPscanGraph#GCH2 $nameofwave(scangraph_ch2), minRGB = 0
					break
				case 1: // Use selected color
					SVAR beforeColors = root:Packages:twoP:examine:Ch2BeforeColors
					rColor = str2num (stringFromlist (0, beforeColors, ","))
					gColor = str2num (stringFromlist (1, beforeColors, ","))
					bColor = str2num (stringFromlist (2, beforeColors, ","))
					ModifyImage/w=twoPscanGraph#GCH2 $nameofwave(scangraph_ch2), minRGB = (rColor, gColor, bColor)
					break
				case 2: // transparent
					ModifyImage/w=twoPscanGraph#GCH2 $nameofwave(scangraph_ch2), minRGB = NaN
			endswitch
			NVAR afterMode =  root:Packages:twoP:examine:Ch2AfterMode
			switch (afterMode) // 0 means last color, 1 means selected color, 2 means transparent
				case 0: // Use last color
					ModifyImage/w=twoPscanGraph#GCH2 $nameofwave(scangraph_ch2), maxRGB = 0
					break
				case 1: // Use selected color
					SVAR afterColors = root:Packages:twoP:examine:Ch2AfterColors
					rColor = str2num (stringFromlist (0, afterColors, ","))
					gColor = str2num (stringFromlist (1, afterColors, ","))
					bColor = str2num (stringFromlist (2, afterColors, ","))
					ModifyImage/w=twoPscanGraph#GCH2 $nameofwave(scangraph_ch2), maxRGB = (rColor, gColor, bColor)
					break
				case 2: // transparent
					ModifyImage/w=twoPscanGraph#GCH2 $nameofwave(scangraph_ch2), maxRGB = NaN
			endswitch
		endif
	endif
	// Merged channels
	if ((channel & 4) && (WhichListItem("GMRG", ChGraphs) > -1))
		NVAR percentComplete = root:packages:twoP:Acquire:percentComplete
		if ((NVAR_EXISTS (percentComplete) ==0) || (percentComplete == 0))
		wave outWave =  root:packages:twoP:examine:scanGraph_mrg
		variable rangevarR, rangeVarG
		if (kNQRedChan == 1)
			// red plane is layer 0  is ch1, green plane is layer 1 is channel 2
			NVAR firstR = root:packages:twoP:examine:CH1FirstLutColor
			NVAR LastR = root:packages:twoP:examine:CH1LastLutColor
			NVAR firstG = root:packages:twoP:examine:CH2FirstLutColor
			NVAR LastG = root:packages:twoP:examine:CH2LastLutColor
			WAVE redWave = scangraph_ch1
			WAVE greenWave =scangraph_ch2
		else
			NVAR firstR = root:packages:twoP:examine:CH2FirstLutColor
			NVAR LastR = root:packages:twoP:examine:CH2LastLutColor
			NVAR firstG = root:packages:twoP:examine:CH1FirstLutColor
			NVAR LastG = root:packages:twoP:examine:CH1LastLutColor
			WAVE redWave = scangraph_ch2
			WAVE greenWave = scangraph_ch1
		endif
		rangevarR = 65536/(lastR - firstR)
		rangeVarG =  65536/(lastG - firstG)
		scangraph_mrg [] [] [0] =  min (65535, max (0,(redWave [p] [q] - firstR) * rangevarR))
		scangraph_mrg [] [] [1] =   min (65535, max (0,(greenWave [p] [q]  - firstG) * rangeVarG))
	endif
	endif
end


//******************************************************************************************************
// Makes waves for dynamic ROI and displays them in a graph
// last modified Sep 09 2009 by Jamie Boyd
Function NQ_DROICheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			if (checked) // turn on DROI
				SVAR CurScan =root:Packages:twoP:examine:curScan
				SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
				variable mode = numberbykey ("mode", scanStr, ":", "\r")
				variable zSTart
				variable frameSize
				string ModeUnits = ""
				if (mode == kTimeSeries)
					modeUnits = "s"
					FrameSize = numberbykey ("FrameTime", scanStr, ":", "\r")
					zStart = 0
				elseif (mode == kZseries)
					modeUnits = "m"
					FrameSize = numberbykey ("zStepSize", scanStr, ":", "\r")
					zStart = numberbykey ("zPos", scanStr, ":", "\r")
				endif
				NVAR doCh1 = root:Packages:twoP:examine:doDROIch1
				NVAR doCh2 = root:Packages:twoP:examine:doDROIch2
				NVAR doRatio = root:Packages:twoP:examine:doDROIratio
				variable ROIpnts
				variable nAxes =0, iAxis
				string axisStr = "", anAxis
				if ((doCh1) || (doRatio))
					WAVE/Z data1Wave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
					if (waveExists (data1Wave))
						ROIpnts = dimsize (data1wave, 2)
						make/o/n= (ROIpnts) root:Packages:twoP:examine:Droi_ch1
						WAVE Droi_ch1 = root:Packages:twoP:examine:Droi_ch1
						SetScale/p x (zStart),(FrameSize),modeUnits, Droi_ch1
						if (doCh1)
							axisStr [0]= "ch1;"
							nAxes += 1
						endif
					else
						doCh1 =0
						doRatio =0
					endif
				endif
				if ((doCh2) || (doRatio))
					WAVE/Z data2Wave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
					if (waveExists (data2Wave))
						ROIpnts = dimsize (data2wave, 2)
						make/o/n= (ROIpnts) root:Packages:twoP:examine:Droi_ch2
						WAVE Droi_ch2 = root:Packages:twoP:examine:Droi_ch2
						SetScale/p x (zStart),(FrameSize),modeUnits, Droi_ch2
						if (doCh2)
							nAxes += 1
							axisStr [0]= "ch2;"
						endif
					else
						doCh2 =0
						doRatio =0
					endif
				endif
				if (doRatio)
					if ((waveExists (data1Wave)) && (waveExists (data2Wave)))
						make/o/n= (ROIpnts) root:Packages:twoP:examine:Droi_ratio
						WAVE Droi_ratio = root:Packages:twoP:examine:Droi_ratio
						SetScale/p x (zStart),(FrameSize),modeUnits, Droi_ratio
						nAxes += 1
						axisStr [0] = "ratio;"
					else
						doRatio =0
					endif
				endif
				// kill old graph
				doWindow/K NQ_DROI_graph
				// make new graph
				display/k=2/N=NQ_DROIgraph as "Dynamic ROI for " + CurScan
				variable axisFrac = (1-.02*(nAxes-1))/nAxes
				for (iAxis =0; iAxis < nAxes; iAxis += 1)
					anAxis = stringfromlist (iAxis, axisStr) 
					WAVE dROIWave = $"root:Packages:twoP:examine:Droi_" + anAxis
					appendtoGraph/L=$"L_" + anAxis dROIWave
					ModifyGraph freePos($"L_" + anAxis)={zStart,bottom}
					ModifyGraph axisEnab($"L_" +  anAxis)={(iAxis * axisFrac) + (iAxis * .01) , ((iAxis + 1) * axisFrac) + (iAxis* .01)}
					label $"L_" + anAxis "DROI " + stringfromlist (iAxis, axisStr)
					ModifyGraph lblPos( $"L_" + anAxis)=60
				endfor
				// make Accumulator wave to calculate DROI over a radius
				NVAR dROIRad= root:packages:twoP:examine:DROIRad
				if (dRoiRad > 0)
					make/o/n= ((2 * DROIrad+ 1), (2 * DROIrad + 1))  root:Packages:twoP:examine:ACCwave
				endif
			else //kill old graph
				DoWindow/k NQ_DROIgraph
				WAVE Droi_wave = root:Packages:twoP:examine:Droi_wave
				killwaves DROI_wave
			endif
			break
	endSwitch
end

//******************************************************************************************************
// Resizes the accumulator wave for doing dynamic ROIs
// Last modified Sep 08 2009 by Jamie
Function NQ_DroiRadiusSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			if (sva.dval > 0)
				make/o/n= (( sva.dval * 2 + 1), ( sva.dval * 2 + 1))  root:Packages:twoP:examine:ACCwave
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Sets the global variable for which channel is the numerator in the ratio to be calculated from the 2 channels
// Last modified JUl 16 2010 by Jamie
Function NQ_DROIPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			if (cmpStr (pa.ctrlName, "DROIRatPopUp") == 0)
				NVAR TopChan = root:packages:twoP:examine:doDROITopChan
			elseif (cmpStr (pa.ctrlName, "ROIRatPopUp") == 0)
				NVAR TopChan =root:packages:twoP:examine:ROITopChan
			endif
			TopChan =  pa.popNum
			break
	endswitch
	return 0
End


//******************************************************************************************************
// This procedure shows the different layers of the image, one after the other, in a movie, by starting a background task
// Last modified Sep 04 2009 by Jamie Boyd - used named background task
STATIC CONSTANT NQMOVIEFRAMERATE = 20
Function NQ_MovieProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			if (cmpstr(WinList("twoPscanGraph", "", "WIN:1"), "twoPscanGraph") != 0)
				return 1
			endif			
			//Movie on or off? 
			controlinfo /w = twoP_Controls MovieButton
			string title =  StringByKey("title", S_recreation , "=" , ",")
			if ((cmpstr (title, "\"movie\"\r")) == 0)
				Button MovieButton  win = twoP_Controls,title="Stop"
				CtrlNamedBackground DoMovie_Bkg, period=(60/NQMOVIEFRAMERATE), proc=NQ_DoMovie_Bkg
				CtrlNamedBackground DoMovie_Bkg, start
			else
				Button MovieButton  win = twoP_Controls,title="movie"
				CtrlNamedBackground DoMovie_Bkg, stop
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// background task to show movie
// Last modified:
// 2016/11/24 by Jamie Boyd
Function NQ_DoMovie_Bkg(s)		// This is the function that will be called periodically
	STRUCT WMBackgroundStruct &s
	
	if (cmpstr(WinList("twoPscanGraph", "", "WIN:1"), "twoPscanGraph") != 0)
		return 1
	endif		
	NVAR NumFrames =root:Packages:twoP:examine:Numframes
	NVAR CurFramePos = root:Packages:twoP:examine:CurFramePos
	// adjust frame position
	if (CurFramePos < NumFrames -1)
		CurFramePos += 1
	else
		CurFramePos = 0
	endif
	// call NQ_DisplayFramesProc to display selected frame
	STRUCT WMSliderAction sa
	sa.eventCode = 1
	sa.curval = CurFramePos
	NQ_DisplayFramesProc(sa)
	return 0	// Continue background task
End


//******************************************************************************************************
// moves frame position back/forward with each click of the corresponding button
// Last modified Sep 03 2009 by Jamie Boyd
Function NQ_NextPreviousFrameProc (ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			if ((cmpstr(stringfromlist (0, WinList("twoPscanGraph", ";", "WIN:1" )), "twoPscanGraph")) != 0)
				return 1
			endif
			NVAR NumFrames =root:Packages:twoP:examine:Numframes
			NVAR CurFramePos = root:Packages:twoP:examine:CurFramePos
			SVAR curScan = root:Packages:twoP:examine:CurScan
			string scanPath, scanWaveName
			variable iChan
			if (cmpStr (ba.ctrlname, "PrevFrame") == 0)
				if (CurFramePos > 0)
					CurFramePos -= 1
				else
					CurFramePos = NumFrames -1
				endif
			else
				if (CurFramePos < NumFrames -1)
					CurFramePos += 1
				else
					CurFramePos = 0
				endif
			endif
			// call NQ_DisplayFramesProc to display selected frame
			STRUCT WMSliderAction sa
			sa.eventCode = 1
			sa.curval = CurFramePos
			NQ_DisplayFramesProc(sa)
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Control for the frame position slider. Dragging the slider sets the image plane of the current scan in the scangraph window
// shift-dragging selects a range of frames over which to do an average  (Time series) or a Maximum projection (Z series)
// Last modified 2013/08/09 by Jamie Boyd 
Function NQ_DisplayFramesProc(sa) : SliderControl
	STRUCT WMSliderAction &sa

	switch( sa.eventCode )
		case -1: // kill
			break
		default:
			if ((cmpstr(stringfromlist (0, WinList("twoPscanGraph", ";", "WIN:1" )), "twoPscanGraph")) != 0)
				return 1 
			endif
			Variable curval = sa.curval
			SVAR curScan = root:Packages:twoP:examine:CurScan
			SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
			WAVE/z ch1 = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
			WAVE/z ch2 = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
			WAVE scanGraph_Ch1 = root:packages:twoP:examine:scanGraph_Ch1
			WAVE scanGraph_Ch2 = root:packages:twoP:examine:scanGraph_Ch2
			string SubWinList = childwindowlist ("twoPscanGraph")
			variable hasCh1 = ((waveExists (ch1)) && (WhichListItem("GCH1", SubWinList) > -1))
			variable hasCh2 = ((waveExists (ch2)) && (WhichListItem("GCH2", SubWinList) > -1))
			variable hasMerg =  (waveExists (ch1))  * (waveExists (ch2))  * (WhichListItem("GMRG", SubWinList) > -1)
			string valueStr
			if(sa.eventCode & 1 ) // value set
				if (NumberByKey("mode", scanStr , ":", "\r") == kTimeSeries)
					sprintf valueStr "%.2W0Ps", curval* numberbyKey ("frameTime", scanStr, ":", "\r")
				else
					sprintf valueStr "%.2W0Pm",  numberbyKey ("zPos", scanStr, ":", "\r") + curval* numberbyKey ("zStepSize", scanStr, ":", "\r")
				endif
				if ((hasCh1) || (hasMerg))
					ProjectZSlice (ch1, scanGraph_Ch1, curval)
					if (hasCh1)
						TextBox/W = twoPscanGraph#GCH1/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 "ch1: " + ValueStr
					endif
				endif
				if ((hasCh2) || (hasMerg))
					ProjectZSlice (ch2, scanGraph_Ch2, curval)
					if (hasCh2)
						TextBox/W = twoPscanGraph#GCH2/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 "ch2: " + valueStr
					endif
				endif
				if (hasMerg)
					NQ_ApplyImSettings (4)
					TextBox/W = twoPscanGraph#GMRG/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 valueStr
				endif
			elseif ((sa.eventCode & 2) && (sa.eventMod & 2))
				// On mouse down AND shift key held, set global variable for start position of Kalman or Projection
				variable/G root:packages:twoP:examine:FrameSliderStart = sa.curval
				// if mouse up AND shift is held, do an Average (T series) or a Max Projection (zSeries) over the range from mouse down to mouse up
			elseif ((sa.eventCode & 4) && (sa.eventMod & 2))
				NVAR FrameSliderStart = root:packages:twoP:examine:FrameSliderStart
				SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
				variable mode = NumberByKey("mode", scanStr , ":", "\r")
				if (mode == kZSeries)
					variable stepSize = numberbyKey ("zStepSize", scanStr, ":", "\r")
					variable zOffset =  numberbyKey ("zPos", scanStr, ":", "\r")
					variable startz, endz
					if (FrameSliderStart < curval)
						startZ = zOffset + FrameSliderStart * stepSize
						endZ = zOffset + curval*stepSize
					else
						startZ = zOffset +  curVal * stepSize
						endZ = zOffset + FrameSliderStart * stepSize
					endif
					sprintf valueStr "%.2W0Pm to %.2W0Pm", startZ, endZ
					if ((waveExists (ch1)) && ((WhichListItem("GCH1", SubWinList) > -1) || (hasMerg)))
						ProjectSpecFrames (ch1, min (FrameSliderStart, sa.curval), max (FrameSliderStart, sa.curval), scanGraph_Ch1, 0,2, 1)//^^
						if (WhichListItem("GCH1", SubWinList) > -1)
							TextBox/W = twoPscanGraph#GCH1/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 "ch1: " + valueStr
						endif
					endif
					if ((waveExists (ch2)) && ((WhichListItem("GCH2", SubWinList) > -1) || (hasMerg)))
						ProjectSpecFrames (ch2, min (FrameSliderStart, sa.curval), max (FrameSliderStart, sa.curval), scanGraph_Ch2, 0,2, 1)//^^
						if (WhichListItem("GCH2", SubWinList) > -1)
							TextBox/W = twoPscanGraph#GCH2/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 "ch2: " + valueStr
						endif
					endif
				else // mode = time series
					variable frameTime = numberbyKey ("FrameTime", scanStr, ":", "\r")
					if (FrameSliderStart < curVal)
						startZ = FrameSliderStart * frameTime
						endZ =  curval*frameTime
					else
						startZ = curVal * frameTime
						endZ =  FrameSliderStart * frameTime
					endif
					sprintf valueStr "%.2W0Ps to %.2W0Ps", startZ ,endZ
					if ((waveExists (ch1)) && ((WhichListItem("GCH1", SubWinList) > -1) || (hasMerg)))
						KalmanSpecFrames (ch1, min (FrameSliderStart, sa.curval), max (FrameSliderStart, sa.curval), scanGraph_Ch1, 0,16)
						if (WhichListItem("GCH1", SubWinList) > -1)
							TextBox/W = twoPscanGraph#GCH1/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 "ch1: " + valueStr
						endif
					endif
					if ((waveExists (ch2)) && ((WhichListItem("GCH2", SubWinList) > -1) || (hasMerg)))
						KalmanSpecFrames (ch2, min (FrameSliderStart, sa.curval), max (FrameSliderStart, sa.curval), scanGraph_Ch2, 0,16)
						if (WhichListItem("GCH2", SubWinList) > -1)
							TextBox/W = twoPscanGraph#GCH2/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 "ch2: " + valueStr
						endif
					endif
				endif
				if (hasMerg)
					NQ_ApplyImSettings (4)
					TextBox/W = twoPscanGraph#GMRG/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 valueStr
				endif
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
//------------------------------- Code for The Examine TabControl Tabs--------------------------------------------
//******************************************************************************************************

// This function runs whenever a tab on the examine tabControl is selected, or when a new scan is selected.
// It runs whatever update function is provided by the procedure for the current tab
// All the hiding and showing of controls is done by the tabControl utilities procedure
// Last Modified 2014/08/13 by Jamie Boyd
Function ExamineTabCtrl_proc (tca): TabControl
	STRUCT WMTabControlAction &tca 

	if (tca.eventCode == 2)
		String tabList = GUIPTabGetTabList ("twoP_Controls", "ExamineTabCtrl")
		string theTab = StringFromList (tca.tab, tabList)
		funcref GUIPprotofunc tabFunc = $"NQex" + theTab + "_Update"
		tabFunc ()
	endif
end

//******************************************************************************************************
// Adds info from exp note to shared waves results structure
// assumes numeric values shoyld be in 32 bit floating point waves, string values should be in text waves
// Last Modified Nov 03  2011 by Jamie Boyd
//Function NQ_ParseNoteKeys (expNote, s)
//	string expNote
//	STRUCT SharedWavesStruct &s
//	
//	variable sp, ep // start and end positions of keyname
//	// first key might be first thing in note, or may be separated from non-key/value pairs by a ";"
//	ep = strsearch(expNote, "=", 0)
//	if (ep ==-1)
//		return 0
//	endif
//	sp = strsearch(expNote, ";", 0)
//	if ((sp == -1) || (sp > ep))
//		sp = -1
//	endif
//	NQ_AddANoteKey (expNote, sp, ep, s)
//	do
//		sp = strsearch(expNote, ";", ep)
//		if (sp ==-1)
//			return 0
//		endif
//		ep = strsearch(expNote, "=", sp)
//		if (ep ==-1)
//			return 0
//		else
//			NQ_AddANoteKey (expNote, sp, ep, s)
//		endif
//	while (1)
//end

//******************************************************************************************************
// Adds info for a single key to shared waves results structure
// assumes numeric values shoyld be in 32 bit floating point waves, string values should be in text waves, no dimension units are set
// Last Modified Nov 03  2011 by Jamie Boyd
//Function NQ_AddANoteKey (expNote, sp, ep, s)
//	string expNote
//	variable sp, ep
//	STRUCT SharedWavesStruct &s
//	
//	string aKey = expNote [sp +1, ep-1]
//	s.resultWaveNames [s.nResults] = aKey
//	string aStrVal = StringByKey(aKey, expNote, "=", ";")
//	variable aNumVal = NumberByKey(aKey, expNote, "=", ";") 
//	if (numtype (aNumVal) == 0)
//		 s.resultVariables [s.nResults] = aNumVal
//		s.resultWaveTypes [s.nResults] = 2 // 32 bit float
//	else
//		 s.resultStrings [s.nResults] = aStrVal
//		s.resultWaveTypes [s.nResults] = 0 // text
//	endif
//	s.resultWaveUnits [s.nResults] = ""
//	s.nResults +=1
//end


//******************************************************************************************************
// ------------Utility functions useful for working  with twoP data-----------------------------------------------
//******************************************************************************************************


// This little function returns the full path to the current scan for channel 1
Function/S sc1 ()
	SVAR curScan = root:packages:twoP:examine:curScan
	return "root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
end

//******************************************************************************************************
// This little function returns the full path to the current scan for channel 2
Function/S sc2 ()
	SVAR curScan = root:packages:twoP:examine:curScan
	return "root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
end

//******************************************************************************************************
// this little function returns the note for the current scan
Function/S sInfo ()
	SVAR curScan = root:packages:twoP:examine:curScan
	SVAR curScanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
	return curScanStr
end

//******************************************************************************************************
//Draws a nice scale-bar on an image using scaling of bottom axis
// Last modified Aug 31 2011 by Jamie Boyd
Function NQ_DrawScaleBar()
	
	//Get the marquee coordinates and calculate xsize as distance between left and right
	string vAxis = "left", hAxis = "bottom"
	string axes = axislist ("")
	if ((whichlistItem ("left", axes, ";")) == -1)
		if ((whichlistItem ("right", axes, ";")) == -1)
			doAlert 0, "Neither left nor right vertical axes were found."
		else
			vAxis = "right"
		endif
	endif
	if ((whichlistItem ("bottom", axes, ";")) == -1)
		if ((whichlistItem ("top", axes, ";")) == -1)
			doAlert 0, "Neither top nor bottom horizontal axes were found."
		else
			hAxis = "top"
		endif
	endif
	string leftAxisUnits = stringByKey ("UNITS", AxisInfo("", vAxis), ":", ";")
	string bottomAxisUnits = stringByKey ("UNITS", AxisInfo("", hAxis), ":", ";")
	//Get the marquee coordinates and calculate xsize as distance between left and right
	GetMarquee/K $vAxis, $hAxis
	variable xSize = abs ((V_right - V_left))
	//Chop xSize to a nice round number to draw a scalebar
	if ((xSize < 2e06) && (xSize > 1e06))
		xSize = 1e06
	elseif (xSize > 5e05)
		xSize = 5e05
	elseif (xSize > 2e05)
		xSize = 2e05
	elseif (xSize > 1e05)
		xSize = 1e05
	elseif (xSize > 5e04)
		xSize = 5e04
	elseif (xSize > 2e04)
		xSize = 2e04
	elseif (xSize > 1e04)
		xSize = 1e04
	elseif (xSize > 5e03)
		xSize = 5e03
	elseif (xSize > 2e03)
		xSize = 2e03
	elseif (xSize > 1e03)
		xSize = 1e03
	elseif (xSize > 5e02)
		xSize = 5e02
	elseif (xSize > 2e02)
		xSize = 2e02
	elseif (xSize > 1e02)
		xSize = 1e02
	elseif (xSize > 5e01)
		xSize = 5e01
	elseif (xSize > 2e01)
		xSize = 2e01
	elseif (xSize > 1e01)
		xSize = 1e01
	elseif (xSize > 5)
		xSize = 5
	elseif (xSize > 2)
		xSize = 2
	elseif (xSize > 1)
		xSize = 1
	elseif (xSize > 5e-01)
		xSize = 5e-01
	elseif (xSize > 2e-01)
		xSize = 2e-01
	elseif (xSize > 1e-01)
		xSize = 1e-01
	elseif (xSize > 5e-02)
		xSize = 5e-02
	elseif (xSize > 2e-02)
		xSize = 2e-02
	elseif (xSize > 1e-02)
		xSize = 1e-02
	elseif (xSize > 5e-03)
		xSize = 5e-03
	elseif (xSize > 2e-03)
		xSize = 2e-03
	elseif (xSize > 1e-03)
		xSize = 1e-03
	elseif (xSize > 5e-04)
		xSize = 5e-04
	elseif (xSize > 2e-04)
		xSize = 2e-01
	elseif (xSize > 1e-04)
		xSize = 1e-04
	elseif (xSize > 5e-05)
		xSize = 5e-05
	elseif (xSize > 2e-05)
		xSize = 2e-05
	elseif (xSize > 1e-05)
		xSize = 1e-05
	elseif (xSize > 5e-06)
		xSize = 5e-06
	elseif (xSize > 2e-06)
		xSize = 2e-06
	elseif (xSize > 1e-06)
		xSize = 1e-06
	elseif (xSize > 5e-07)
		xSize = 5e-06
	elseif (xSize > 2e-07)
		xSize = 2e-06
	elseif (xSize > 1e-07)
		xSize = 1e-07
	elseif (xSize > 5e-08)
		xSize = 5e-08
	elseif (xSize > 2e-08)
		xSize = 2e-08
	elseif (xSize > 1e-08)
		xSize = 1e-08
	elseif (xSize > 5e-09)
		xSize = 5e-09
	elseif (xSize > 2e-09)
		xSize = 2e-09
	elseif (xSize > 1e-09)
		xSize = 1e-09
	elseif (xSize > 5e-10)
		xSize = 5e-10
	elseif (xSize > 2e-10)
		xSize = 2e-10
	elseif (xSize > 1e-10)
		xSize = 1e-10
	endif
	//The average y-position of the selected area will be horizontal position of scalebar
	variable yPos = (V_bottom + V_top)/2
	//Draw the scalebar
	if (getkeyState (0) & 4)
		SetDrawLayer/K ProgFront // using /K kills any old drawing (like previous scalebar) that might be lying around
	else
		SetDrawLayer ProgFront 
	endif
	SetDrawEnv xcoord=$hAxis, ycoord=$Vaxis // need to use graph axis coordinates 
	SetDrawEnv linethick=5
	SetDrawEnv linefgc= (65535,65535,65535) // color = white
	DrawLine  V_left, yPos, (V_left + xSize), yPos
	// print scalebar length a little bit above the scale bar, so add a return on the end and middle align text for Y
	// center adjust text for X to position in center of scale bar
	string valueStr
	sprintf valueStr "%.0W1P%s\r", xSize, bottomAxisUnits
	SetDrawEnv textrgb= (65535,65535,65535),textxjust = 1, textyjust=1, xcoord=$hAxis, ycoord=$vAxis,fstyle=1
	DrawText V_left + (xSize/2),yPos,valueStr
	// If left and bottom axes are in different units, draw a scalebar for left axis as well
	if (cmpStr (leftAxisUnits, bottomAxisUnits) != 0)
		variable ySize = abs ((V_bottom - V_top))
		variable xPos = (V_left + V_right)/2
		//Chop ySize to a nice round number to draw a scalebar
		if ((ySize < 2e06) && (ySize > 1e06))
			ySize = 1e06
		elseif (ySize > 5e05)
			ySize = 5e05
		elseif (ySize > 2e05)
			ySize = 2e05
		elseif (ySize > 1e05)
			ySize = 1e05
		elseif (ySize > 5e04)
			ySize = 5e04
		elseif (ySize > 2e04)
			ySize = 2e04
		elseif (ySize > 1e04)
			ySize = 1e04
		elseif (ySize > 5e03)
			ySize = 5e03
		elseif (ySize > 2e03)
			ySize = 2e03
		elseif (ySize > 1e03)
			ySize = 1e03
		elseif (ySize > 5e02)
			ySize = 5e02
		elseif (ySize > 2e02)
			ySize = 2e02
		elseif (ySize > 1e02)
			ySize = 1e02
		elseif (ySize > 5e01)
			ySize = 5e01
		elseif (ySize > 2e01)
			ySize = 2e01
		elseif (ySize > 1e01)
			ySize = 1e01
		elseif (ySize > 5)
			ySize = 5
		elseif (ySize > 2)
			ySize = 2
		elseif (ySize > 1)
			ySize = 1
		elseif (ySize > 5e-01)
			ySize = 5e-01
		elseif (ySize > 2e-01)
			ySize = 2e-01
		elseif (ySize > 1e-01)
			ySize = 1e-01
		elseif (ySize > 5e-02)
			ySize = 5e-02
		elseif (ySize > 2e-02)
			ySize = 2e-02
		elseif (ySize > 1e-02)
			ySize = 1e-02
		elseif (ySize > 5e-03)
			ySize = 5e-03
		elseif (ySize > 2e-03)
			ySize = 2e-03
		elseif (ySize > 1e-03)
			ySize = 1e-03
		elseif (ySize > 5e-04)
			ySize = 5e-04
		elseif (ySize > 2e-04)
			ySize = 2e-01
		elseif (ySize > 1e-04)
			ySize = 1e-04
		elseif (ySize > 5e-05)
			ySize = 5e-05
		elseif (ySize > 2e-05)
			ySize = 2e-05
		elseif (ySize > 1e-05)
			ySize = 1e-05
		elseif (ySize > 5e-06)
			ySize = 5e-06
		elseif (ySize > 2e-06)
			ySize = 2e-06
		elseif (ySize > 1e-06)
			ySize = 1e-06
		elseif (ySize > 5e-07)
			ySize = 5e-06
		elseif (ySize > 2e-07)
			ySize = 2e-06
		elseif (ySize > 1e-07)
			ySize = 1e-07
		elseif (ySize > 5e-08)
			ySize = 5e-08
		elseif (ySize > 2e-08)
			ySize = 2e-08
		elseif (ySize > 1e-08)
			ySize = 1e-08
		elseif (ySize > 5e-09)
			ySize = 5e-09
		elseif (ySize > 2e-09)
			ySize = 2e-09
		elseif (ySize > 1e-09)
			ySize = 1e-09
		elseif (ySize > 5e-10)
			ySize = 5e-10
		elseif (ySize > 2e-10)
			ySize = 2e-10
		elseif (ySize > 1e-10)
			ySize = 1e-10
		endif
		//Draw the scalebar
		SetDrawLayer ProgFront
		SetDrawEnv xcoord=$hAxis, ycoord=$vAxis // need to use graph axis coordinates (this will fail if data are plotted on other axes than bottom and left)
		SetDrawEnv linethick=5
		SetDrawEnv linefgc= (65535,65535,65535) // color = white
		DrawLine  V_left, yPos, V_left, (yPos + ySize)
		
		sprintf valueStr "%.0W1P%s\r", ySize, leftAxisUnits
		SetDrawEnv textrgb= (65535,65535,65535),textxjust = 1, textyjust=1, textrot=90, xcoord=$hAxis, ycoord=$vAxis,fstyle=1
		DrawText V_left ,yPos + (ySize/2),valueStr
		SetDrawLayer UserFront
	endif
end

//******************************************************************************************************
// Measures distances from the Maqrquee using left and bottom axes scaling
// Last Modified May 25 2010 by Jamie Boyd
Function NQ_MeasureMarquee()
	string vAxis = "left", hAxis = "bottom"
	string axes = axislist ("")
	if ((whichlistItem ("left", axes, ";")) == -1)
		if ((whichlistItem ("right", axes, ";")) == -1)
			doAlert 0, "Neither left nor right vertical axes were found."
			return 1
		else
			vAxis = "right"
		endif
	endif
	if ((whichlistItem ("bottom", axes, ";")) == -1)
		if ((whichlistItem ("top", axes, ";")) == -1)
			doAlert 0, "Neither top nor bottom horizontal axes were found."
			return 1
		else
			hAxis = "top"
		endif
	endif
	//Get the marquee coordinates and calculate xsize as distance between left and right
	GetMarquee/K $vAxis, $hAxis
	string leftAxisUnits = stringByKey ("UNITS", AxisInfo("", vAxis), ":", ";")
	string bottomAxisUnits = stringByKey ("UNITS", AxisInfo("", hAxis), ":", ";")
	variable xSize = abs ((V_right - V_left))
	variable ySize = abs ((V_bottom - V_top))
	printf  "The meaured X distance was %.2W1P%s\r", xSize, bottomAxisUnits
	printf  "The meaured Y distance was %.2W1P%s\r", ySize, leftAxisUnits
	if (cmpStr (leftAxisUnits, bottomAxisUnits) == 0)
		printf "The diagonal distance was %.2W1P%s\r", sqrt (xSize^2 + ySize^2), leftAxisUnits
	else
		printf "Velocity (rise/run) = %.2W1P%s/%s\r", xSize/ysize, bottomAxisUnits, leftAxisUnits
	endif
end


function NQ_UpdateOldData ()
	if (DataFolderExists("root:Nidaq_Scans"))
		RenameDataFolder root:Nidaq_Scans, twoP_Scans
	endif
	string scans = GUIPListObjs ("root:twoP_Scans:", 4, "*", 0, "")
	variable iScan,nScans= itemsinList (scans, ";")
	string scan, chans, chanStr
	variable iChan, nChans
	variable startX, xScal, startY, yScal, startZ, zScal
	for (iscan=0;iScan < nScans; iScan +=1)
		scan = StringFromList(iScan,scans,";")
		SVAR infoStr = $"root:twoP_Scans:" + scan + ":" + scan + "_info"
		startx= NumberByKey("Xpos",infoStr, ":","\r")
		startY =  NumberByKey("Ypos",infoStr, ":","\r")
		xScal = NumberByKey("XpixSize",infoStr, ":","\r")
		yScal = NumberByKey("YpixSize",infoStr, ":","\r")
		chans = StringByKey("imChanDesc", infoStr, ":", "\r")
		for (iChan=0, nChans = (itemsinlist (chans, ",")); iChan < nChans;iChan +=1)
			chanStr = stringFromList (iChan, chans,",")
			WAVE chanWave =  $"root:twoP_Scans:" + scan + ":" + scan + "_" + chanStr
			Setscale/P x startX, xScal, "m", chanWave
			Setscale/P y starty, yScal, "m", chanWave
			if (!(wavetype (chanWave) & 0x40))
				chanWave += 2^11
				redimension/w/u chanwave
			endif
		endfor
	endfor
end
