#pragma rtGlobals=3
#pragma IgorVersion = 6.2
#pragma version = 2.1  // Last Modified: 2025/07/23 by Jamie Boyd

#include <SaveRestoreWindowCoords>
#include "twoP_ExConstants"
#include "GUIPControls"
#include "GUIPList"
#include "GUIPProtoFuncs"
#include "GUIPSubWinUtils"
#include "GUIPKillDisplayedWave"

// These include files can be found in the "GUIP" folder in the User Procedures folder in the Igor Pro folder

//******************************************************************************************************
// Let's put  function to make the  panel in the macros menu.
// also functions to add and remove examine tabs
Menu "Macros"
	Submenu "twoP"
		"twoP Panel", /Q, twoP_ExamineMakePanel ()
		Submenu "Examine"
			"Add a Tab to the Examine TabControl",/Q ,twoP_ExamineAddTab ()
			"Remove a Tab from the Examine TabControl",/Q, twoP_ExamineRemoveTab ()
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
// ----------------------------- Making global variables and controls for Examine tab ------------------
//******************************************************************************************************


//******************************************************************************************************
// Makes globals for Examine tab functions of the Nidaq Controls panel
// Last Modified 2025/08/01 by Jamie Boyd
Function twoP_ExamineMakeFolder ()
	if (!(DataFolderexists ("root:Packages:twoP:examine")))
		if (!(DataFolderExists ("root:packages:twoP")))
			if (!(DataFolderExists ("root:packages")))
				NewDataFolder root:Packages
			endif
			NewDataFolder root:Packages:twoP
		endif
		NewDataFolder root:Packages:twoP:examine
	else
		return 0
	endif
	//String that stores the name of the current scan, and display it in a title box on the Examine Panel
	string/g root:Packages:twoP:examine:curScan = "no current scan"	
	// Variable for scan numbers, when scans are sequentially numbered
	variable/G root:packages:twoP:Examine:curScanNum
	// Wave is used by the ListBox on the Examine Panel to display the experiment note of the currently selected scan.
	make/t/n=0 root:Packages:twoP:examine:NoteListWave
	// Wave for Histogram
	String/G root:packages:twoP:examine:HistGraphSelChans = "ch1;"
	make/o/n = (2^kNQimageBits) root:Packages:twoP:Examine:HistWaveCh1
	WAVE HistWaveCh1 = root:Packages:twoP:Examine:HistWaveCh1
	setscale/p x, 0, 1	, "", HistWaveCh1
	// Waves for sliders on the histogram
	make/o root:Packages:twoP:examine:ImRangeLeftxCh1 = {(0.05 * 2^kNQimageBits), (0.05 * 2^kNQimageBits)}
	make/o root:Packages:twoP:examine:ImRangeLeftyCh1 = {1,inf}
	make/o root:Packages:twoP:examine:ImRangeRightxCh1 = {(0.95 * 2^kNQimageBits) ,(0.95 * 2^kNQimageBits)}
	make/o root:Packages:twoP:examine:ImRangeRightyCh1 = {1,inf}
	// Values to control which channels to show in the ScanGraph
	string/G root:packages:twoP:examine:ScanGraphSelChans = "ch1;"
	variable/G root:packages:twoP:examine:ShowScanGraphAxes
	// Waves to show frames from 3D waves in the scanGraph
	make/w/u/o/n = (500,500) root:packages:twoP:examine:scanGraph_ch1
	make/w/u/o/n = (500,500) root:packages:twoP:examine:scanGraph_ch2
	make/b/u/o/n = (500, 500, 3) root:packages:twoP:examine:scanGraph_mrg
	// Values to control image appearance with look up table
	// NB: modified 2016/11/08 to use unsigined integers
	string/G root:Packages:twoP:examine:LUTChan = "ch1" // image channel we are working with, ch1 is a pretty good guess. Others made as needed
	variable/G root:Packages:twoP:examine:Ch1FirstLUTColor = 0
	variable/G root:Packages:twoP:examine:Ch1LastLUTColor =  (2^kNQimageBits)-1
	variable/G root:Packages:twoP:examine:Ch1CTable = 1 // Grays
	string/G  root:Packages:twoP:examine:Ch1CTableStr ="Grays"
	variable/G root:Packages:twoP:examine:Ch1LUTInvert = 0 //  don't invert
	variable/G root:Packages:twoP:examine:Ch1BeforeMode = 1 // 0 means first color, 1 means selected color, 2 means transparent
	String/G root:Packages:twoP:examine:Ch1BeforeColors = "0,0,65535" // blue
	variable/G root:Packages:twoP:examine:Ch1AfterMode = 1 // 0 means first color, 1 means selected color, 2 means transparent
	String/G root:Packages:twoP:examine:Ch1AfterColors = "65535,0,0" // red
	variable/G root:packages:twoP:Examine:Ch1LUTAuto =0 // 0 means use given first and last values, 1 means auto LUT,ignoring 1st and last
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
	
	make/o/t/n=1 root:Packages:twoP:examine:scanListWave
	// Variables for Nidaq Traces Graph ROI deltaF processing
	variable/g root:Packages:twoP:examine:startffordeltaf =0		//The range of points at in the ROI wave used for determining the  "F"  used for calculating "deltaF" is stored in these two variables
	variable/g root:Packages:twoP:examine:endffordeltaf =5
	variable/g root:Packages:twoP:examine:ffordeltaf		//This variable is used to set baseline fluorescence from the first x points of the wave
	// AspectRatio waves for scanGraph main graph
	make/o root:packages:twoP:examine:scanGraphAspX = {0,0,1,1,0}
	make/o root:packages:twoP:examine:scanGraphAspY = {0,1,1,0,0}
end

//******************************************************************************************************
// Makes the main control panel. Also makes sure Global Variables and Folders exist, and calls Initializing of Acquire Stuff, if Acquire Procedure is present
// Last Modified 2017/08/08 by Jamie Boyd
Function twoP_ExamineMakePanel ()
	
	// if panel is already present, just bring it to front and exit, assuming everything else is done
	DoWindow/F twoP_controls
	if (V_Flag == 1)
		return 1
	endif
	// If no global variable found, Make Global variables 
	if (!(dataFolderExists ("root:Packages:twoP:examine")))
		// Make global examine variables
		twoP_ExamineMakeFolder ()
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
	// Add AcquireExamine tabcontrol and, if acquire proc is loaded, add acquire tab and its controls
	TabControl AcquireExamineTab, win =twoP_Controls, pos={0,1},size={344,709}, proc=GUIPTabProc
	if (aqPresent)
		TabControl AcquireExamineTab, win =twoP_Controls, tabLabel(0)="Acquire", tabLabel (1) = "Examine", value = 0
		GUIPTabNewTabCtrl ("twoP_Controls", "AcquireExamineTab", TabList = "Acquire;Examine;", UserFunc = "ExamineTabCtrl_proc", CurTab = 0)
		funcref GUIPprotoFuncV MakeAqFolder = $"NQ_MakeAcquireFolder"
		MakeAqFolder (0)
		funcref GUIPprotoFunc AddAqControlds = $"NQ_AddAcquireControls"
		twoP_ExamineAddControls (1)
		AddAqControlds ()
		Execute/P/Q "GUIPTabClick (\"twoP_Controls\", \"AcquireExamineTab\", \"Acquire\")"
	else //just the examine tab
		TabControl AcquireExamineTab, tabLabel(0)="Examine", value = 0
		GUIPTabNewTabCtrl ("twoP_Controls", "AcquireExamineTab", TabList = "Examine", UserFunc = "ExamineTabCtrl_proc", CurTab = 0)
		twoP_ExamineAddControls (0)
	endif
end

//******************************************************************************************************
// Adds controls for the Examine functions to the Nidaq Controls panel
// Last Modified 2025/08/01 by Jamie Boyd
Function twoP_ExamineAddControls (able)
	variable able		// controls start out hidden when acquire is present
	// Current scan info and WaveNote
	SetVariable ScanNumSetVar win = twoP_Controls,pos={4.00,27.00},size={49.00,18.00},proc=twoP_ScanNumSetVarProc
	SetVariable ScanNumSetVar win = twoP_Controls,title=" ",fSize=12
	SetVariable ScanNumSetVar win = twoP_Controls,value=root:packages:twoP:examine:curScanNum
	SetVariable ScanNumSetVar win = twoP_Controls, disable = able
	PopupMenu ScansPopMenu win = twoP_Controls,pos={56.00,26.00},size={60.00,20.00},bodyWidth=60,proc=twoP_ScanPopMenuProc
	PopupMenu ScansPopMenu win = twoP_Controls,title="Scan:"
	if (able)
		PopupMenu ScansPopMenu win = twoP_Controls,mode=0,value=#"twoP_ScanListScans (\"1,2,3,4,5,\")"
	else
		PopupMenu ScansPopMenu win = twoP_Controls,mode=0,value=#"twoP_ScanListScans (\"0,1,2,3,4,5,\")"
	endif
	PopupMenu ScansPopMenu win = twoP_Controls, disable = able
	TitleBox CurScanTitleBox win = twoP_Controls,pos={118.00,28.00},size={57.00,15.00},fSize=12
	TitleBox CurScanTitleBox win = twoP_Controls,frame=0,variable=root:packages:twoP:examine:curScan
 	TitleBox CurScanTitleBox win = twoP_Controls, disable = able
	TitleBox ChannnelsTitleBox win = twoP_Controls, variable = root:packages:twoP:examine:DroiDSIcheck //DSI checkbox for dynamic ROI
	TitleBox ChannnelsTitleBox win = twoP_Controls,pos={7,54},size={139,12},title="Channels", fSize=12,frame=0
	TitleBox ChannnelsTitleBox win = twoP_Controls,disable=able
	TitleBox DateTimeTitleBox win = twoP_Controls, pos={215,54},size={116,12},title="Date and Time", fSize=12,frame=0
	TitleBox DateTimeTitleBox win = twoP_Controls,disable=able
	ListBox WaveNoteListBox win = twoP_Controls, pos={3,74},size={337,66},proc=NQ_editNoteProc,font="Courier",fSize=12
	ListBox WaveNoteListBox win = twoP_Controls,listWave=root:Packages:twoP:examine:NoteListWave
	ListBox WaveNoteListBox win = twoP_Controls,disable=able
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Setvariable ScanNumSetVar;Popupmenu ScansPopMenu;Titlebox CurScanTitleBox;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "TitleBox DateTimeTitleBox;Titlebox ChannnelsTitleBox;Listbox WaveNoteListBox;")
	// Histogram
	Button HistButton win = twoP_Controls,pos={6.00,144.00},size={67.00,20.00},proc=twoP_HistButtonProc
	Button HistButton win = twoP_Controls,title="Histogram",fSize=12
	Button HistButton win = twoP_Controls, disable = able
	PopupMenu HistChansPopmenu win = twoP_Controls,pos={77.00,144.00},size={55.00,20.00},bodyWidth=55,proc=twoP_HistGraphChansPopMenuProc
	PopupMenu HistChansPopmenu win = twoP_Controls,title="Chan",fSize=12
	PopupMenu HistChansPopmenu win = twoP_Controls,mode=0,value=#"twoP_HistGraphListChans()"
	PopupMenu HistChansPopmenu win = twoP_Controls, disable = able
	TitleBox SelHistChansTitle win = twoP_Controls,pos={133.00,146.00},size={23.00,15.00},fSize=12,frame=0
	TitleBox SelHistChansTitle win = twoP_Controls,variable=root:packages:twoP:examine:HistGraphSelChans
	TitleBox SelHistChansTitle win = twoP_Controls, disable = able
	CheckBox HistFrameCheck win = twoP_Controls,pos={212.00,145.00},size={53.00,15.00},proc=twoP_HistTypeCheckProc
	CheckBox HistFrameCheck win = twoP_Controls,title="Frame",fSize=12,value=1,mode=1
	CheckBox HistFrameCheck win = twoP_Controls,disable =able
	CheckBox HistStackCheck win = twoP_Controls,pos={272.00,145.00},size={50.00,15.00},proc=twoP_HistTypeCheckProc
	CheckBox HistStackCheck win = twoP_Controls,title="Stack",fSize=12,value=0,mode=1
	CheckBox HistStackCheck win = twoP_Controls, disable = able
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Button HistButton;PopupMenu HistChansPopmenu;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "TitleBox SelHistChansTitle;CheckBox HistFrameCheck;CheckBox HistStackCheck;")
	// Image Appearance
	// Channel selector
	PopupMenu LUTchanMenu win = twoP_Controls, pos={7.00,169.00},size={81.00,20.00},proc=twoP_LUTchanPopMenuProc
	PopupMenu LUTchanMenu win = twoP_Controls, title="LUT",fSize=12
	PopupMenu LUTchanMenu win = twoP_Controls, mode=1,popvalue="ch1",value=#"twoP_ScanListImChans()"
	PopupMenu LUTchanMenu win = twoP_Controls, disable=able
	// LUT popmenu and inverter
	PopupMenu LUTpopUp win = twoP_Controls,pos={105.00,169.00},size={167.00,20.00},bodyWidth=167,proc=twoP_LUTPopMenuProc
	PopupMenu LUTpopUp win = twoP_Controls,fSize=12,mode=1,value=#"\"*COLORTABLEPOPNONAMES*\""
	PopupMenu LUTpopUp win = twoP_Controls,disable=able
	CheckBox LUTInvertCheck win = twoP_Controls,pos={282.00,172.00},size={50.00,16.00},proc=twoP_LUTInvertCheckProc
	CheckBox LUTInvertCheck win = twoP_Controls,title="Invert",fSize=12
	CheckBox LUTInvertCheck win = twoP_Controls,variable=root:Packages:twoP:examine:Ch2LUTInvert
	CheckBox LUTInvertCheck win = twoP_Controls,disable=able
	// Auto LUT checkbox
	CheckBox LUTautoCheck win = twoP_Controls,pos={6.00,198.00},size={40.00,15.00},proc=twoP_LUTAutoCheckProc
	CheckBox LUTautoCheck win = twoP_Controls,title="auto",fSize=12
	CheckBox LUTautoCheck win = twoP_Controls,variable=root:packages:twoP:examine:ch2LUTauto
	CheckBox LUTautoCheck win = twoP_Controls,disable=able
	// LUT slider
	CustomControl LUTslider win = twoP_Controls, pos={3.00,222.00},size={333.00,30.00},proc=MinMaxSlider_thumbFunc
	CustomControl LUTslider win = twoP_Controls,userdata=A"!!<6!!\"&`oz7=Xe,!!N?&5uCTF!\"&]5z!CHlT7=Xe,!!!!$"
	CustomControl LUTslider win = twoP_Controls, userdata(FUNCSTR)="twoP_LUTSliderAction",frame=0, focusRing=0
	CustomControl LUTslider win = twoP_Controls, disable =able
	// LUT first/last setvars
	SetVariable LUTFirstValueSetVar win = twoP_Controls,pos={55.00,197.00},size={86.00,18.00},proc=twoP_LUTValsSetVarProc
	SetVariable LUTFirstValueSetVar win = twoP_Controls,title="First",fSize=12,format="%d"
	SetVariable LUTFirstValueSetVar win = twoP_Controls,limits={1,4094,1},value=root:Packages:twoP:examine:Ch2FirstLUTColor
	SetVariable LUTFirstValueSetVar win = twoP_Controls,disable=able
	SetVariable LUTLastValueSetVar win = twoP_Controls,pos={142.00,197.00},size={84.00,18.00},proc=twoP_LUTValsSetVarProc
	SetVariable LUTLastValueSetVar win = twoP_Controls,title="Last",fSize=12,format="%d"
	SetVariable LUTLastValueSetVar win = twoP_Controls,limits={1,4094,1},value=root:Packages:twoP:examine:Ch2LastLUTColor
	SetVariable LUTLastValueSetVar win = twoP_Controls,disable=able
	// adjust first/last to data range
	Button LUTtoDataButton win = twoP_Controls,pos={229.00,194.00},size={50.00,23.00},proc=twoP_LUTtoDataProc
	Button LUTtoDataButton win = twoP_Controls,title="to Data",fSize=12
	Button LUTtoDataButton win = twoP_Controls,disable = able
	CheckBox LUT96check win = twoP_Controls,disable=able,pos={284.00,198.00},size={52.00,14.00},proc=twoP_LUT96CheckProc
	CheckBox LUT96check win = twoP_Controls,title="96%",fSize=12,value=0
	// Before First color adjustments
	TitleBox LUTBeforeFirstTitle win = twoP_Controls,pos={7.00,259.00},size={94.00,15.00}
	TitleBox LUTBeforeFirstTitle win = twoP_Controls,title="Before First Use ",fSize=12,frame=0
	TitleBox LUTBeforeFirstTitle win = twoP_Controls,disable=able
	CheckBox LUTBeforeUseFirstCheck win = twoP_Controls,pos={106.00,259.00},size={38.00,15.00},proc=twoP_LUTBeforeModeCheckProc
	CheckBox LUTBeforeUseFirstCheck win = twoP_Controls,title="First",fSize=10,value=1,mode=1
	CheckBox LUTBeforeUseFirstCheck win = twoP_Controls,disable=able
	CheckBox LUTBeforeUseColorCheck win = twoP_Controls,pos={156.00,259.00},size={15.00,15.00},proc=twoP_LUTBeforeModeCheckProc
	CheckBox LUTBeforeUseColorCheck win = twoP_Controls,title="",fSize=12,value=0,mode=1
	CheckBox LUTBeforeUseColorCheck win = twoP_Controls,disable=able
	PopupMenu LUTBeforeColorPopUp win = twoP_Controls,pos={171.00,256.00},size={50.00,20.00},proc=twoP_LUTBeforeColorPopMenuProc
	PopupMenu LUTBeforeColorPopUp win = twoP_Controls,fSize=12
	PopupMenu LUTBeforeColorPopUp win = twoP_Controls,mode=122,popColor=(0,0,65535),value=#"\"*COLORPOP*\""
	PopupMenu LUTBeforeColorPopUp win = twoP_Controls,disable=able
	PopupMenu LUTBeforeColorPopUp win = twoP_Controls,pos={171.00,256.00},size={50.00,20.00},proc=twoP_LUTBeforeColorPopMenuProc
	PopupMenu LUTBeforeColorPopUp win = twoP_Controls,fSize=12
	PopupMenu LUTBeforeColorPopUp win = twoP_Controls,mode=122,popColor=(0,0,65535),value=#"\"*COLORPOP*\""
	PopupMenu LUTBeforeColorPopUp win = twoP_Controls, disable = able
	CheckBox LUTBeforeUseTransCheck win = twoP_Controls,pos={232.00,259.00},size={86.00,15.00},proc=twoP_LUTBeforeModeCheckProc
	CheckBox LUTBeforeUseTransCheck win = twoP_Controls,title="Transparent",fSize=12,value=0,mode=1
	CheckBox LUTBeforeUseTransCheck win = twoP_Controls, disable = able
	// After Last color adjustments
	TitleBox LUTAfterLastTitle win = twoP_Controls,pos={7.00,276.00},size={80.00,15.00}
	TitleBox LUTAfterLastTitle win = twoP_Controls,title="After Last Use",fSize=12,frame=0
	TitleBox LUTAfterLastTitle win = twoP_Controls, disable = able
	CheckBox LUTAfterUseLastCheck win = twoP_Controls,pos={106.00,276.00},size={37.00,15.00},proc=twoP_LUTAfterModeCheckProc
	CheckBox LUTAfterUseLastCheck win = twoP_Controls,title="Last",fSize=10,value=1,mode=1
	CheckBox LUTAfterUseLastCheck win = twoP_Controls, disable = able
	CheckBox LUTAfterUseColorCheck win = twoP_Controls,pos={156.00,276.00},size={20.00,15.00},proc=twoP_LUTAfterModeCheckProc
	CheckBox LUTAfterUseColorCheck win = twoP_Controls,title=" ",value=0,mode=1
	CheckBox LUTAfterUseColorCheck win = twoP_Controls, disable =able
	PopupMenu LUTAfterColorPopUp win = twoP_Controls,pos={171.00,273.00},size={50.00,20.00},proc=twoP_LUTAfterColorPopMenuProc
	PopupMenu LUTAfterColorPopUp win = twoP_Controls,fSize=12
	PopupMenu LUTAfterColorPopUp win = twoP_Controls,mode=1,popColor=(65535,0,0),value=#"\"*COLORPOP*\""
	PopupMenu LUTAfterColorPopUp win = twoP_Controls, disable= able
	CheckBox LUTAfterUseTransCheck win = twoP_Controls,pos={232.00,276.00},size={86.00,15.00},proc=twoP_LUTAfterModeCheckProc
	CheckBox LUTAfterUseTransCheck win = twoP_Controls,title="Transparent",fSize=12,value=0,mode=1
	CheckBox LUTAfterUseTransCheck win = twoP_Controls, disable = able
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Checkbox HistFrameCheck;Checkbox HistStackCheck;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Popupmenu LUTpopUp;Checkbox LUTInvertCheck;Popupmenu LUTchanMenu;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", ";Setvariable LUTFirstValueSetVar;Setvariable LUTLastValueSetVar;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Button LUTtoDataButton;Checkbox LUT96check;CustomControl LUTslider")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Titlebox LUTBeforeFirstTitle;Checkbox LUTBeforeUseFirstCheck;Checkbox LUTBeforeUseColorCheck;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Popupmenu LUTBeforeColorPopUp;Titlebox LUTAfterLastTitle;Checkbox LUTBeforeUseTransCheck;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Checkbox LUTAfterUseLastCheck;Checkbox LUTAfterUseColorCheck;Popupmenu LUTAfterColorPopUp;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Checkbox LUTAfterUseTransCheck;Checkbox LUTautoCheck;")
	// Movie Controls
	Button MovieButton win = twoP_Controls, pos={5,293},size={52,20},proc=NQ_MovieProc,title="movie"
	Button MovieButton win = twoP_Controls, disable=able
	Slider FramePositionSlider win = twoP_Controls, pos={64,293},size={275,49},proc=NQ_DisplayFramesProc
	Slider FramePositionSlider win = twoP_Controls,limits={0,10,1},variable= root:Packages:twoP:examine:CurFramePos,vert= 0
	Slider FramePositionSlider win = twoP_Controls, disable = able
	Button PrevFrame win = twoP_Controls, pos={5,318},size={23,18},proc=NQ_NextPreviousFrameProc,title="<-"
	Button PrevFrame win = twoP_Controls, disable=able
	Button NextFrame win = twoP_Controls, pos={31,318},size={23,18},proc=NQ_NextPreviousFrameProc,title="->"
	Button NextFrame win = twoP_Controls, disable=able
	// Dynamic ROI
	CheckBox DROICheck win = twoP_Controls,pos={14,346},size={19,35},title="", proc=NQ_DROICheckProc
	CheckBox DROICheck win = twoP_Controls,variable=root:Packages:twoP:examine:doDROI
	CheckBox DROICheck win = twoP_Controls, disable=able
	SetVariable DROIRadSetVar win = twoP_Controls, pos={30,342},size={214,19},title="Dynamic ROI  Radius (pixels)", fSize=12
	SetVariable DROIRadSetVar win = twoP_Controls, limits={0,inf,1},value= root:Packages:twoP:examine:DROIRad
	SetVariable DROIRadSetVar win = twoP_Controls, disable=able
	CheckBox DroiCheckCh1 win = twoP_Controls, pos={25,365},size={58,16},title="Chan 1",fSize=12
	CheckBox DroiCheckCh1 win = twoP_Controls, variable = root:Packages:twoP:examine:doDROIch1, proc = twoP_DROIchanCheckProc
	CheckBox DroiCheckCh1 win = twoP_Controls, disable=able
	CheckBox DroiCheckCh2 win = twoP_Controls,pos={87,365},size={58,16},title="Chan 2",fSize=12
	CheckBox DroiCheckCh2 win = twoP_Controls, variable = root:Packages:twoP:examine:doDROIch2, proc = twoP_DROIchanCheckProc
	CheckBox DroiCheckRatio,win = twoP_Controls,pos={150,365},size={47,16},title="Ratio",fSize=12
	CheckBox DroiCheckRatio,win = twoP_Controls, variable= root:Packages:twoP:examine:doDROIRatio, proc = twoP_DROIchanCheckProc
	CheckBox DroiCheckRatio,win = twoP_Controls, disable=able
	PopupMenu DROIRatPopUp win = twoP_Controls, pos={203,363},size={80,20},proc=NQ_DROIPopMenuProc, fSize=12
	PopupMenu DROIRatPopUp,win = twoP_Controls, mode=2,popvalue="Ch1/Ch2",value= #"\"Ch1/Ch2;Ch2/Ch1\""
	PopupMenu DROIRatPopUp win = twoP_Controls, disable=able
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Button MovieButton;Slider FramePositionSlider;Button PrevFrame;Button NextFrame;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Checkbox DROICheck;Setvariable DROIRadSetVar;Checkbox DroiCheckCh1;Checkbox DroiCheckCh2;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Checkbox DroiCheckRatio;Popupmenu DROIRatPopUp;")
	// Show Other windows
	GroupBox ShowOthersGroupBox win = twoP_Controls,pos={3,664},size={337,40},title="Show Other Windows", frame=0
	GroupBox ShowOthersGroupBox win = twoP_Controls, disable=able
	Button ShowTracesButton,win = twoP_Controls, pos={14,682},size={57,17},proc=NQ_showTracesProc,title="Traces"
	Button ShowTracesButton,win = twoP_Controls, disable=able
	Button ShowMiscAnalysisButton win = twoP_Controls, pos={96,680},size={99,20},proc=MakeMiscPanel,title="Misc Analysis"
	Button ShowMiscAnalysisButton win = twoP_Controls, disable=able
	Button ShowScansButton win = twoP_Controls, pos={230,681},size={49,17},proc=twoP_ScansShowScanProc,title="Scans"
	Button ShowScansButton win = twoP_Controls, disable=able
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine","GroupBox ShowOthersGroupBox;Button ShowTracesButton;Button ShowMiscAnalysisButton;")
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine","Button ShowScansButton;")
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
	TabControl ExamineTabCtrl win = twoP_Controls,pos={3,388},size={337,269}, fSize=12, value= 0, proc = GUIPTabProc
	TabControl ExamineTabCtrl win = twoP_Controls, disable = able
	GUIPTabNewTabCtrl ("twoP_Controls", "ExamineTabCtrl", TabList = tabList, UserFunc = "ExamineTabCtrl_proc", curTab = curTab)
	GUIPTabAddCtrls ("twoP_Controls", "AcquireExamineTab", "Examine", "Tabcontrol ExamineTabCtrl;")
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
Function twoP_ExamineAddTab ()
	// make sure panel is open
	if ((cmpstr("twoP_Controls", WinList ( "twoP_Controls", "", "WIN:64"))) != 0)
		twoP_ExamineMakePanel()
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
	//put up a dialog to choose a tab to add
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
Function twoP_ExamineRemoveTab ()
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
// -----------------------------code for selecting a new scan for Current Scan ----------------------------
//******************************************************************************************************

//******************************************************************************************************
// Returns a list of scans in the twoP_Scans folder, sorted by scan mode. Pass a comma separated list of scan types
// Last Modified 2025/08/02 by Jamie Boyd - made better method to list scans ina text wave
Function/S twoP_ScanListScans (modeList)
	string modeList // comma separated list of modes to be returned
	
	variable aMode
	variable iFolder, nFolders,i
	string aFolder
	// to list scans, make a FREE wave bigger than we need, and a variable to count number of scans
	make/t/free/n= 10000 tempForScanList
	variable nScans =0
	
	string LiveModeList = "", TimeSeriesList="", SingleImageList="", zSeriesList ="", lineScanList="",ephysOnlyList=""
	for (iFolder = 0,  nFolders=CountObjects("root:twoP_Scans:", 4) ; iFolder < nFolders; iFolder += 1)
		aFolder = GetIndexedObjName("root:twoP_Scans:", 4, iFolder)
		SVAR/Z scanStr = $"root:twoP_Scans:" + aFolder + ":" + aFolder + "_info"
		if ((SVAR_EXISTS (scanStr)) && (WhichListItem(stringbyKey ("mode", scanStr, ":", "\r"), modeList, ",") > -1))
			tempForScanList [nScans] = aFolder
			nScans +=1
			aMode = numberbyKey ("mode", scanStr, ":", "\r")
			switch (aMode)
				case kLiveMode:
					LiveModeList += aFolder + ";"
					break
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
	// now copy free wave into scanlist wave
	if (nScans > 0)
		Wave/T scanListWave = root:Packages:twoP:examine:scanListWave
		Redimension/N=(nScans) scanListWave
		scanListWave = tempForScanList [p]
	endif
	string outPutList = ""
	if (WhichListItem("0", modeList, ",") > -1)
		outPutList += "\\M1(Live;" + LiveModeList + "\\M1(-;"
	endif
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
Function twoP_ScanNumSetVarProc(sva) : SetVariableControl
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
			twoP_ScanPopMenuProc(pa)
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Function for the Scan popup menu. This allows you to select a scan to display as the current scan in the ScanGraph window.
// Once here, you can view it as a movie, save it to disk, etc
// Last Modified 2025/08/04 by Jamie Boyd
Function twoP_ScanPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	switch( pa.eventCode )
		case 2: // mouse up
			SVAR curScan = root:Packages:twoP:examine:CurScan
			SVAR scanNote =$"root:twoP_Scans:" + curScan + ":" + curScan+ "_info"
			curScan = pa.popStr
			// if numeric series, set scan num
			NVAR scanNum = root:packages:twoP:Examine:curScanNum
			scanNum = str2num (stringfromlist (1, pa.popStr, "_"))
			// Get some variables from scan note
			variable mode = NumberByKey("mode",ScanNote, ":", "\r")
			variable doephys = NumberByKey("ephys",ScanNote, ":", "\r")
			if (mode == kePhysOnly)
				DoWindow/K twoPscanGraph
				NQ_NewTracesGraph (curScan)
			else
				twoP_ScanUpdateScanGraph (curScan)
				variable nTraces = GUIPCountObjs ("root:twoP_Scans:" + CurScan, 1, "*avg*", 0) + GUIPCountObjs ("root:twoP_Scans:" + CurScan, 1, "*ratio*", 0)
				if ((doephys ==0) && (nTraces ==0)) 
					DoWindow/K twoP_TracesGraph
				else
					NQ_NewTracesGraph (curScan)
				endif
			endif
				// adjust the movie controls and visibility and change display
				twoP_ScanAdjustExamineControls (curScan)
			break
	endswitch
	return 0
End



// When a new scan is selected, displays new scangraph or updates the subwindows in scanGraph
// Last Modified 2025/07/27 by Jamie Boyd
Function twoP_ScanUpdateScanGraph (curScan)
	string curScan

	// get reference to scan info string
	SVAR/Z ScanInfo = $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_info"
	if (!(SVAR_EXISTS (ScanInfo)))
		printf "The info string for the scan, \"%s\" was not found.\r", CurScan
		return 1
	endif
	// channels existing for this scan - limit selected to these channels, delete if neccesary
	string scanChans = StringByKey("imChanDesc", ScanInfo, ":", "\r")
	// which channels are selected?
	SVAR selChans = root:packages:twoP:examine:ScanGraphSelChans
	// remove what don't belong
	// make sure selected chans are in scan chans
	variable iChan, nChans = itemsInList (selChans, ";")
	string aChan
	for (iChan =nChans -1; iChan >= 0; iChan -=1)
		aChan = stringFromList (iChan, selChans, ";")
		if (WhichListItem(aChan, scanChans, ",", 0, 0) ==-1)
			selChans = RemoveFromList(aChan, selChans, ";")
		endif
	endfor
	// if scangraph exists, bring window to front and change title
	DoWindow/F twoPscanGraph
	if (V_Flag)		// scanGraph alreay exists
		DoWindow/T twoPscanGraph "twoP Scan:" + curScan
		// remove subwindows that are not selected
		string existingSubWins =  RemoveFromList("controlPanel", childwindowList ("twoPscanGraph"), ";", 0)
		nChans = ItemsInList(existingSubWins, ";")
		for (iChan =0; iChan < nChans; iChan +=1)
			aChan = stringFromList(iChan, existingSubWins)
			if (WhichListItem (aChan [1,strlen (aChan)], selChans, ";") == -1)
			//killWindow $"twoPscanGraph" + "#" + aChan
				//existingSubWins = RemoveFromList (aChan, existingSubWins, ";", 0)
				GUIPSubWin_Remove ("twoPscanGraph", aChan)
			endif
		endfor
		// add or replace subwindows
		STRUCT GUIPSubWin_ContentStruct cs
		nChans = itemsInList (selChans, ";")
		for (iChan =0; iChan < nChans; iChan +=1)
			aChan = stringFromList(iChan, selChans)
			twoP_ImScanGraphFillcs (cs, curScan, aChan)
			GUIPSubWin_Add (cs)
		endfor
		//GUIPSubWin_ReapportionSubWins ("twoPscanGraph")
	else // new window from scratch
		twoP_ImScanGraphNew (CurScan)
	endif
	
end
//******************************************************************************************************
// adjusts the Date and time info and the slider control on the examine scans panel to reflect the time of the current scan.
// It also disables the movie controls if the current scan is not a stack.
// Last modified 2025/08/02 by Jamie Boyd 
Function twoP_ScanAdjustExamineControls (curScan)
	string curScan

	SVAR/z ScanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
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
	twoP_ScanShowNote ("root:twoP_Scans:" + curScan + ":" + curScan + "_info")
	TitleBox DateTimeTitleBox Win=twoP_Controls, title =  secs2date(numberbykey("ExpTime", ScanStr, ":", "\r"),0) + " " + secs2Time(numberbykey("ExpTime",ScanStr, ":", "\r"),1)
	string ChanTitleStr = "Chans:" 
	string scanChans = StringByKey("ImChanDesc", scanStr, ":", "\r")
	variable iChan, nChans = ItemsInList(scanChans, ",")
	if (nChans > 0)
		ChanTitleStr += " Image:"
		for (iChan =0; iChan < nChans; iChan +=1)
			ChanTitleStr += stringFromList(iChan, scanChans, ",") + "; "
		endfor
	endif
	string ePhysChans = StringByKey("ePhysChanDesc", scanStr, ":", "\r")
	nChans = ItemsInList(ePhysChans, ",")
	if (nChans > 0)
		ChanTitleStr += " ePhys:"
		for (iChan =0; iChan < nChans; iChan +=1)
			ChanTitleStr += stringFromList(iChan, scanChans, ",") + "; "
		endfor
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
			ableState = 0
		else
			ableState = 1
		endif
	else	// not a stack, so disable movie controls
		Slider FramePositionSlider, Win =twoP_Controls,limits={0,0,0}, value = 0
		// disable dynmic ROI
		STRUCT WMCheckBoxAction cba
		cba.checked = 0
		cba.eventCode = 2
		NQ_DroiCheckProc (cba)
		if (ShowNow)
			ableState  = 2
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
// Shows the ScanGraph, or makes it
Function twoP_ScansShowScanProc(ctrlName) : ButtonControl
	String ctrlName
	
	doWindow/F twoPscanGraph
	if (V_Flag ==0)
		SVAR curScan = root:packages:twoP:examine:curScan
		twoP_ImScanGraphNew(curScan)
	endif
End


//********************************************************************************************
// Lists Image channels in a scan, as strings from imChanDesc. For use in popMenus to select a single channel
// Last Modified: 2025/07/23 by Jamie Boyd
function/S twoP_ScanListImChans()
	string chanlist
	SVAR curScan = root:packages:twoP:examine:curScan
	if (cmpStr (CurScan, "no current scan") ==0)
		DoAlert 0, "There is no scan selected from which to choose a channel!"
		chanlist = ""
	else
		SVAR/Z scanNote = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
		if (!(SVAR_Exists(scanNote)))
			DoAlert 0, "Can't find scan note for current scan!"
			chanlist = ""
		else
			chanlist = replaceString (",", stringbykey ("imChanDesc", scanNote, ":", "\r"), ";")
		endif
	endif
	return chanlist
end


//******************************************************************************************************
// -----------------------------code for making and altering image scan graph----------------------------------------------
//******************************************************************************************************

// *************************************************************************
// Struct for plotting an image channel
// Wave 0 the image, for a 3D stack a wave made to hold a single frame
// variable 0 is for scan Mode
// variable 1 is for show axes check
// variable 2-7  variables are for Live ROI
// variable 2 has Live roi
// variables 3-6: Left, top, right, bottom coordinates of live ROI
// variable 7 = 1 if aqcuire tab showing, 0 for examine
// string 1 is current scan, 
// string 2 is channel name
Function twoP_ImScanGraphFillcs (cs, curScan, aChan)
	STRUCT GUIPSubWin_ContentStruct &cs	//subwin plotting struct
	String curScan
	String aChan
	// info from scan info
	SVAR ScanInfo = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
	variable mode = NumberByKey("mode",ScanInfo, ":", "\r")
	variable xSize = NumberByKey("PixWidth", ScanInfo, ":", "\r") 
	variable ySize = NumberByKey("PixHeight", ScanInfo, ":", "\r")
	variable xPixSize =  NumberByKey("xPixSize", ScanInfo, ":", "\r")
	variable yPixSize =  NumberByKey("yPixSize", ScanInfo, ":", "\r")
	variable xOffset =  NumberByKey("xPos", ScanInfo, ":", "\r")
	variable yOffset =  NumberByKey("yPos", ScanInfo, ":", "\r")
	// some things are done differently when acquiring a new scan
	Controlinfo /w = twoP_Controls AcquireExamineTab
	variable isAcquire = (cmpstr (S_Value, "Acquire") == 0) // 1 if called from acquiring tab, 0 if examining.
	// fill out non-variant parts of cs
	cs.graphName = "twoPscanGraph"
	
	funcref GUIPSubWin_AddProto cs.addContent = twoP_ImScanGraphSubWin
	cs.nUserVariables =7
	// other strings are used for names of any ROIs
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
	cs.userVariables [1] = isAcquire // 1 if acquiring new image, else 0
	// show ROIs?
	string roiStr = GUIPListObjs("root:twoP_Scans:" + CurScan, 1, "*avg*",0, "") + GUIPListObjs("root:twoP_Scans:" + CurScan, 1, "*ratio*",0, "")
	variable iROI, numROIs = itemsinList (roiStr, ";")
	cs.nUserStrings = 2 + numROIs
	for (iROI =0; iROI < numROIs; iROI += 1)
		WAVE anAvg = $"root:twoP_Scans:" + curScan + ":" + stringFromList (iROI, roiStr, ";")
		cs.UserStrings [iROI + 2] = StringByKey("ROI", note (anAvg), ":", ";") 
	endfor
	// add channel info
	// make sure wave for the channel exists. For lineScan, single image, liveScan, this is the scanGraph image
	WAVE/Z channelWave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_" + aChan
	if (!(waveExists (channelWave)))
		doAlert 0, "Channel " + aChan + " does not exist for " + curScan
		return 1
	endif
	if ((mode == kTimeSeries) || (mode == kZSeries))  // make a separate 2D image to display a frame of 3D stack
		// make or redimension 2D waves for scanGraph
		WAVE/Z channelWave = $"root:packages:twoP:examine:scanGraph_" + aChan
		if (WaveExists(channelWave))
			if ((DimSize(channelWave, 0) != xSize) || (DimSize(channelWave, 1) != ySize))
				redimension/n= ((xSize), (ySize)) channelWave
			endif
		else
			make/w/u/n=(xSize, ySize) $"root:packages:twoP:examine:scanGraph_" + aChan
			WAVE channelWave = $"root:packages:twoP:examine:scanGraph_" + aChan
		endif
		SetScale/P X, xOffset, xPixSize, "m", channelWave
		SetScale/P Y yOffset, yPixSize, "m", channelWave
	endif
	WAVE cs.userWaves[0] = channelWave
	cs.UserStrings [0] = aChan
	cs.subWin = "G" + aChan
end		

// *************************************************************************
// Last Modified 2025/0804 by Jamie Boyd
Function twoP_ImScanGraphSubWin (cs)
	STRUCT GUIPSubWin_ContentStruct &cs
		
	// append the image
	appendimage cs.userWaves [0]
	ModifyGraph margin=1, fSize=12, axThick=0, mirror = 0, standoff = 0,tlOffset (bottom)=-25, tlOffset (left)=-30
	ModifyGraph alblRGB=(65535,65535,65535), tlblRGB=(65535,65535,65535)
	Label  left "\\U"
	Label bottom "\\U"
	setaxis/A/R
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
	for (iw =2; iw < cs.nUserStrings; iw += 1)
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

// ***********************************************************************
// Makes the scangraph of the current scan, starting from scratch
// Don't call it if scanGraph alreay exists
// Last Modified 2025/08/04 by Jamie Boyd
Function twoP_ImScanGraphNew (curScan)
	string curScan
	
	// If ScanGraph is open, bring it to the front and exit. 
	DoWindow/F twoPscanGraph
	if (V_Flag)
		return 1
	endif
	// some things are done differently when acquiring a new scan
	Controlinfo /w = twoP_Controls AcquireExamineTab
	variable isAcquire = (cmpstr (S_Value, "Acquire") == 0) // 1 if called from acquiring tab, 0 if examining.
	// get reference to scan info string
	SVAR/Z ScanStr = $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_info"
	if (!(SVAR_EXISTS (scanStr)))
		doAlert 0, "The info string for the scan, \"" + CurScan + "\" was not found."
		return 1
	endif
	// Get scan mode
	variable mode = NumberByKey("mode",ScanStr, ":", "\r")
	// which channels exist for this scan?
	string imChanList = stringbykey("imChanDesc", scanStr, ":", "\r")
	// which channels are selected for display
	SVAR selScanChans = root:packages:twoP:examine:ScanGraphSelChans
	// limit selScanChans to imchans
	variable iChan, nChans = itemsInList(selScanChans, ";")
	string aChan
	for (iChan =nChans-1; iChan >= 0; iChan -=1)
		aChan = stringfromList(iChan, selScanChans, ";")
		if (WhichListItem(aChan, imChanList, ",") == -1)
			selScanChans = removeFromList(aChan, selScanChans, ";")
			nChans -=1
		endif
	endfor
	// info on wave size and dimension
	variable xSize = NumberByKey("PixWidth", ScanStr, ":", "\r") 
	variable ySize = NumberByKey("PixHeight", ScanStr, ":", "\r")
	variable xPixSize =  NumberByKey("xPixSize", ScanStr, ":", "\r")
	variable yPixSize =  NumberByKey("yPixSize", ScanStr, ":", "\r")
	variable xOffset =  NumberByKey("xPos", ScanStr, ":", "\r")
	variable yOffset =  NumberByKey("yPos", ScanStr, ":", "\r")
	// subwin plot structures
	STRUCT GUIPSubWin_UtilStruct us
	us.graphName = "twoPscanGraph"
	us.graphTitle = "twoP Scan:" +  curScan
	if (mode == kLineScan)
		us.holdAspect =0
	else
		us.holdAspect =1
	endif
	us.killbehavior = 1
	us.nSubWins = nChans
	us.nCols = nChans
	us.nRows = 1
	us.reSizeByWidth = 1
	us.xStart = xOffset - xPixSize/2
	us.xEnd = xOffset + xSize*xPixSize - xPixSize/2
	us.yStart = yOffset - yPixSize/2
	us.xEnd = yOffset + ySize*xPixSize - yPixSize/2
	// subwin plotting struct
	STRUCT GUIPSubWin_ContentStruct cs
	// add channel info
	for (iChan =0; iChan < nChans ; iChan +=1)
		aChan = stringfromList(iChan, selScanChans, ";")
		twoP_ImScanGraphFillcs (us.contentStructs [iChan], curScan, aChan)
	endfor
	GUIPSubWin_Display (us)
	PopupMenu ScanChansPopmenu win = twoPscanGraph#controlPanel, pos={1.00,2.00},size={78.00,20.00},proc=twoP_ScanGraphChansPopMenuProc
	PopupMenu ScanChansPopmenu win = twoPscanGraph#controlPanel,title="Display",fSize=12
	PopupMenu ScanChansPopmenu win = twoPscanGraph#controlPanel,mode=0,value=#"twoP_ScanGraphListChans()"
	TitleBox SelChansTitle win = twoPscanGraph#controlPanel,pos={81.00,5.00},size={48.00,15.00},fSize=12,frame=0
	TitleBox SelChansTitle win = twoPscanGraph#controlPanel,variable=root:packages:twoP:examine:ScanGraphSelChans
	// Set window hook function
	SetWindow twoPscanGraph hook (traceHook)= NQ_ScanTrace_HookProc, hookevents = 2
	WC_WindowCoordinatesRestore(us.graphName)
end



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
			GUIPSubWin_Add (cs)
		else // retitling and refitting not already done by subwinutil_add
			if (mode == kLineScan)
				//GUIPSubWin_SetAspRat ("twoPscanGraph", 0)
			else
				//GUIPSubWin_SetAspRat ("twoPscanGraph", 1)
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
// Adds or removes a subwindow from scanGraph according to user's choice
// the data waves have to exist before doing anything
// Last modified 2013/08/09 by Jamie Boyd
Function NQ_ScanGraphDisplayCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			SVAR curScan = root:packages:twoP:examine:curScan
			SVAR ScanStr = $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_info"
			if (!(SVAR_EXISTS (scanStr)))
				doAlert 0, "The info string for the scan, \"" + CurScan + "\" was not found."
				return 1
			endif
			// Get scan mode
			variable mode = NumberByKey("mode",ScanStr, ":", "\r")
			
			variable isAcquire =1
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
				if ((mode == kLiveMode) || (mode == kLineScan) || (mode == kSingleImage))
					
					
					// for line scans and single image, just display the scan waves as the scanGraph waves.
					WAVE/z scanGraph_Ch1 = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
					WAVE/z scanGraph_Ch2 = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
					
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
						//if ((isAcquire == 1) && (mode != kLiveMode))
							fastop scanGraph_ch1 =0
						//endif
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
						//if ((isAcquire == 1) && (mode != kLiveMode))
							fastop scanGraph_ch2 =0
						//endif
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
					s.holdAspect =0
				else
					s.holdAspect =1
				endif
				s.killbehavior = 1
				funcref GUIPSubWin_AddProto cs.addContent = twoP_ImScanGraphSubWin
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
				GUIPSubWin_Add (cs)
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
			//else
				s.contentStructs [0] = cs
				//GUIPSubWin_Remove (cs)
				//GUIPSubWin_FitSubWindows ("twoPscanGraph")
		//	endif
			break
	endswitch
	return 0
End


function/S twoP_ScanGraphListChans()
	SVAR curScan = root:packages:twoP:examine:curScan
	SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
	string chanList = StringByKey("imChanDesc", scanStr, ":", "\r")
	SVAR selChans = root:packages:twoP:examine:ScanGraphSelChans
	variable iChan, nChans = itemsInList(chanList, ",")
	string aChan, outList = ""
	for (iChan =0; iChan < nChans; iChan += 1)
		aChan = stringfromlist (iChan, chanList, ",")
			if (FindListItem(aChan, selChans, ";") > -1)
				outList += "\\M1!"  +num2char(18)
			endif
			outList += aChan + ";"
	endfor
	return outList
end


Function twoP_ScanGraphChansPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			SVAR selChans = root:packages:twoP:examine:ScanGraphSelChans
			if (FindListItem(pa.popStr, selChans, ";") > -1)
				selChans = sortList (removeFromList(pa.popStr, selChans, ";"), ";")
				string thegraph = stringfromlist (0, pa.win, "#")
				GUIPSubWin_Remove (thegraph, "G" + pa.popStr)
			else
				selChans = sortList (addlistItem(pa.popStr, selChans, ";"), ";")
				// add graph
				SVAR curScan = root:packages:twoP:examine:CurScan
				STRUCT GUIPSubWin_ContentStruct cs
				twoP_ImScanGraphFillcs (cs, curScan, pa.popStr)
				GUIPSubWin_Add (cs)
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//******************************************************************************************************	
// This hook function  for the scangraph window shows  the value under the mouse pointer when the shift key is held down and the mouse is moved around.
// Also makes sure that info about where the graph was is saved when closing the graph.
// Last modified 2018/01/11 by Jamie Boyd - added a test to limit to image dimensions
Function NQ_ScanTrace_HookProc(s)
	STRUCT WMWinHookStruct &s

	Variable hookResult = 0
	switch(s.eventCode)
		case 0: // Activate
			break
		case 1: // Deactivate
			break
		case 2: // Kill
			WC_WindowCoordinatesSave(s.WinName)
			hookResult = 1
			break
		case 4: // Mouse Moved 
			// if shift-click. show value at position under mouse for any scan
			// if if dynamic ROI is checked, do ROI for area under cursor, for time and z series
			NVAR dodROI = root:packages:twoP:examine:doDROI
			if (!((dodROI) || (s.eventMod == 2)))
				return 0
			endif
			variable xpos = AxisvalFromPixel (s.winName, "bottom", s.mouseLoc.h)
			variable ypos =  AxisvalFromPixel (s.winName, "left", s.mouseLoc.v)
			SVAR curScan = root:Packages:twoP:examine:CurScan
			SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
			variable scanMode = numberbykey ("Mode", scanStr, ":", "\r")
			variable xPixSIze = numberbykey ("xPixSize", scanStr, ":", "\r")
			variable xOffset = numberbykey ("xPos", scanStr, ":", "\r")
			variable xPixPos = round ((xpos - xOffset)/xPixSIze)
			variable yPixSize = numberbykey ("yPixSize", scanStr, ":", "\r")
			variable pixHeight = numberbykey ("PixHeight", scanStr, ":", "\r")
			variable yOffset = numberbykey ("yPos", scanStr, ":", "\r")
			variable yPixPos = round ((yPos - yOffset)/yPixSize)
			variable pixWidth = numberbykey ("PixWidth", scanStr, ":", "\r")
			if (!((((yPixPos > 0) && (yPixPos < PixHeight)) && (xPixPos > 0)) && (xPixPos < PixWidth)))
				return 1
			endif
			string aChan
			SVAR selImChans = root:packages:twoP:examine:scanGraphSelchans
			variable iChan, nChans = itemsInList (selImChans, ";"), chanValue
			variable ImChans = numberbykey ("ImChans", scanStr, ":", "\r")
			string theSubWin, SubWinList = ChildWindowList(stringfromlist (0, s.winName, "#"))
			NVAR DROIrad = root:packages:twoP:examine:dROIRad
			// shift-click  - value under mouse
			if (s.eventMod == 2)
				for (iChan =0; iChan < nChans; iChan +=1)
					aChan = stringfromList (iChan, selImChans, ";")
					if ((scanMode == kTimeSeries) || (ScanMode == kZseries)) // 3D image, only a plane displayed at a time
						WAVE thescanwave  = $"root:Packages:twoP:examine:scanGraph_" + aChan
					else  // for 2D images, scan is scan
						WAVE thescanwave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_" + aChan
					endif
					if (DROIrad== 0)
						chanValue = thescanwave [xPixpos] [yPixpos]
					else
						imagestats/G={xpixpos -DROIrad , xPixpos +  DROIrad, yPixpos -DROIrad, yPixpos +DROIrad}/M =1 thescanwave
						chanValue = V_avg
					endif
					if (WhichListItem("G" + aChan, SubWinList, ";") > -1)
						TextBox/W = $"twoPscanGraph#G" + aChan/C/N=PosText/F=0/A=LT/X=0.00/Y=0.00 aChan + ": " + num2str(chanValue)
					endif
				endfor
			elseif ((scanMode == kTimeSeries) || (ScanMode == kZseries)) // do dynamic ROI for 3D scans only
				NVAR doCh1 = root:Packages:twoP:examine:doDROIch1
				NVAR doCh2 = root:Packages:twoP:examine:doDROIch2
				NVAR doRatio = root:Packages:twoP:examine:doDROIratio
				NVAR TopChan = root:packages:twoP:examine:doDROITopChan
				variable iFrame, nFrames = numberbykey ("numFrames", scanStr, ":", "\r")
				variable chan1Val, chan2Val
				if (!(ImChans & 1))
					doCh1 =0
				endif
				if (!(ImChans & 2))
					doCh2 =0
				endif
				if (!((ImChans & 1) && (ImChans & 2)))
					doRatio = 0
				endif
				if ((doCh1) || (doRatio))
					WAVE theScanwave1 = $"root:twoP_Scans:" + curScan + ":" + curScan + "_Ch1"
					WAVE droiCh1 =  root:Packages:twoP:examine:Droi_ch1
				endif
				if ((doCh2) || (doRatio))
					WAVE theScanwave2 = $"root:twoP_Scans:" + curScan + ":" + curScan + "_Ch2"
					WAVE droiCh2 =  root:Packages:twoP:examine:Droi_ch2
				endif
				if (doRatio)
					NVAR TopChan = root:packages:twoP:examine:doDROITopChan
					WAVE droiRatio =  root:Packages:twoP:examine:Droi_ratio
					if (TopChan ==1)
						WAVE topWave = droiCh1
						WAVE bottomWave = droiCh2
					else
						WAVE topWave = droiCh2
						WAVE bottomWave = droiCh1
					endif
				endif
				if (DROIrad== 0)
					For (iFrame=0; iFrame < nFrames; iFrame+= 1)
						if ((doCh1) || (doRatio))
							droiCh1 [iFrame] = theScanWave1 [xPixPos] [yPixPos] [iFrame]
						endif
						if ((doCh2) || (doRatio))
							droiCh2 [iFrame] = theScanWave2 [xPixPos] [yPixPos] [iFrame]
						endif
						if (doRatio)
							droiRatio [iFrame] = topWave [iFrame]/bottomWave[iFrame]
						endif
					endfor
				else
					For (iFrame=0; iFrame < Nframes; iFrame+= 1)
						if ((doCh1) || (doRatio))
							imagestats/G={xpixpos -DROIrad , xPixpos +  DROIrad, yPixpos -DROIrad, yPixpos +DROIrad}/P=(iFrame)/M=1 theScanwave1
							droiCh1 [iFrame] =V_Avg
						endif
						if ((doCh2) || (doRatio))
							imagestats/G={xpixpos -DROIrad , xPixpos +  DROIrad, yPixpos -DROIrad, yPixpos +DROIrad}/P=(iFrame)/M=1 theScanwave2
							droiCh2 [iFrame] =V_Avg
						endif
						if (doRatio)
							droiRatio [iFrame] = topWave [iFrame]/bottomWave[iFrame]
						endif
					endfor
				endif
			endif
			break
			hookResult =1
		case 5: //mouse up
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

		// Make sure folder for this scan exists and reference scan Note
		if (!(dataFolderExists ("root:twoP_Scans:" + CurScan)))
			doAlert 0, "The datafolder for the scan, \"" + CurScan + "\" was not found."
			return 1
		endif
		SVAR ScanStr = $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_info"
	
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

		SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"

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
STATIC CONSTANT twoPNOTECHARWID = 38	// Must match the width of our listbox, in characters. If your text is spilling past the end of the line, set CharWid smaller

function twoP_ScanShowNote (ScanStrName)
	string ScanStrName
	
	SVAR scanStr = $ScanStrName
	WAVE/T notelistwave = root:Packages:twoP:examine:notelistwave
	string theNoteStr = stringbykey ("expnote", scanStr, ":", "\r")
	variable notelen = strlen (theNoteStr)
	variable ii, ie, ni
	Redimension/N=0 NoteListWave
	FOR (ii =0, ni =0, ie = twoPNOTECHARWID; ii < noteLen; ii = ie +1, ie += twoPNOTECHARWID + 1, ni += 1)
		if ((ie < notelen) && (cmpstr (theNoteStr [ii + twoPNOTECHARWID], " ") != 0))
			do
				ie -= 1
				if (((cmpstr (theNoteStr [ie], " ")) == 0) || (cmpstr (theNoteStr [ie], ";") == 0))
					break
				endif
			while (ie > ii)
			if ((ie - ii) < 4)
				ie = ii + twoPNOTECHARWID
			endif
		endif
		insertpoints ni, 1, NoteListWave
		NoteListWave [ni] = theNoteStr [ii, ie]
	ENDFOR
end

//******************************************************************************************************
// Allows you to edit the scan note by double clicking on the wave note textbox in the examine scans list box.
// Last Modified: 2012/06/13 by Jamie Boyd
Function NQ_EditNoteProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba
	
	switch( lba.eventCode )
		case 3:  // double click
			SVAR CurScan = root:Packages:twoP:examine:curScan
			if (cmpStr (CurScan, "LiveScan") == 0)
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
				twoP_ScanShowNote ("root:twoP_Scans:" + CurScan + ":" + curScan +"_info")
				string alertStr
				if ((badChar & 3) ==3)
					AlertStr = "Colons and Returns are used as separator characters "
				elseif (badChar & 1)
					AlertStr = "Colons are used to separate keys and values "
				elseif (badChar & 2)
					AlertStr = "Returns are used to separate key:value pairs "
				endif
				if (badChar)
					doAlert 0, AlertStr + "in the\rkey:value\rkey:value\r map in the scan info string,and are unavailable for use in your experiment notes. key=value;key=value can be used, though."  
				endif
			endif
			break
	endswitch
	return 0            // other return values reserved
End


//******************************************************************************************************
// ---------------------------Functions for image histogram ------------------------------------------
//******************************************************************************************************

// **********************************************************************************
// Makes histogram display and/or adjusts channels displayed on histogram graph
// Last Modified: 2025/08/02 by Jamie Boyd
Function twoP_HistMakeGraph ()
	
	SVAR curScan = root:packages:twoP:examine:CurScan
	doWindow/F twoP_HistGraph
	if (V_Flag) // window already exists
		DoWindow /T twoP_HistGraph,  curScan + " Histogram"
	else
		display/N=twoP_HistGraph/k=1 as curScan + " Histogram"
		WC_WindowCoordinatesRestore("twoP_HistGraph")
	endif
	SVAR ScanInfo = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
	// channels existing for this scan - limit Histograms to these channels, delete if neccesary
	string scanChans = StringByKey("imChanDesc", ScanInfo, ":", "\r")
	// selected channels for histogram
	SVAR selChans = root:packages:twoP:examine:HistGraphSelChans 
	// remove what don't belong
	// make sure selected chans are in scan chans
	variable iChan, nChans = itemsInList (selChans, ";")
	string aChan
	for (iChan =nChans -1; iChan >= 0; iChan -=1)
		aChan = stringFromList (iChan, selChans, ";")
		if (WhichListItem(aChan, scanChans, ",", 0, 0) ==-1)
			selChans = RemoveFromList(aChan, selChans, ";")
		endif
	endfor
	// remove histograms that are not selected
	// Histograms already on the graph 
	string existingHists = guiplistWavesFromGraph("twoP_HistGraph" , "HistWave*", 1, 0, "")
	nChans = itemsInList (existingHists, ";")
	string HistWaveName
	for (iChan =0; iCHan < nChans; iChan +=1)
		HistWaveName = stringFromList (iChan, existingHists, ";")
		sscanf HistWaveName, "HistWave%s", aChan
		if (WhichListItem(aChan, selChans, ";", 0, 0) == -1)
			removefromGraph/W=twoP_HistGraph $HistWaveName, $"ImRangeLefty" + aChan, $"ImRangerighty" + aChan
			existingHists = RemoveFromList(HistWaveName, existingHists, ";", 0)
		endif
	endfor
	// append channels as needed
	string left_yName, right_yName
	nChans = itemsInList (selChans, ";")
	variable axisFrac = (1-.02*(nChans-1))/nChans
	for (iChan =0; iChan < nCHans; iChan +=1)
		aChan = stringFromList (iChan, selChans, ";")
		if (WhichListItem("HistWave" + aChan, existingHists, ";", 0, 0) == -1) // need to append the hist
			WAVE/Z histWave = $"root:Packages:twoP:Examine:HistWave" + aChan // first need to make the hist
			if (!(waveExists(histWave)))
				twoP_LUTmakeChanVars (aChan)
				//WAVE histWave = $"root:Packages:twoP:Examine:HistWave" + aChan
			endif
			twoP_HistAddChannel (aChan)
		endif
		// share axis space
		ModifyGraph/W=twoP_HistGraph axisEnab($"L_" +  aChan)={(iChan * axisFrac) + (iChan * .01) , ((iChan + 1) * axisFrac) + (iChan * .01)}
	endfor
	if (!(V_Flag))
		label bottom "Raw A/D Value"
		controlbar 22
		CheckBox LinearCheck,pos={4,2},size={53,16},proc=twoP_HistAxisCheckProc,title="Linear"
		CheckBox LinearCheck,fSize=12,value= 1,mode=1
		CheckBox LogCheck,pos={67,2},size={40,16},proc=twoP_HistAxisCheckProc,title="Log"
		CheckBox LogCheck,fSize=12,value= 0,mode=1
	endif
end


// **********************************************************************************
// adds a channel to be displayed on histogram display
// Last Modified: 2025/08/02 by Jamie Boyd
Function twoP_HistAddChannel (aChan)
	string aChan
	doWindow/F twoP_HistGraph
	if (!(V_Flag)) // window already exists
		return 1
	endif
	string HistWaveName = "HistWave" + aChan
	WAVE histWave = $"root:Packages:twoP:Examine:" + HistWaveName
	WAVE left_y = $"root:Packages:twoP:examine:ImRangeLefty" + aChan
	string left_yName = "ImRangeLefty" + aChan
	WAVE left_x = $"root:Packages:twoP:examine:ImRangeLeftx" + aChan
	WAVE right_y = $"root:Packages:twoP:examine:ImRangerighty" + aChan
	string right_yName = "ImRangerighty" + aChan
	WAVE right_x = $"root:Packages:twoP:examine:ImRangerightx" + aChan
	NVAR ChFirst = $"root:Packages:twoP:examine:" + aChan + "FirstLUTColor"
	NVAR ChLast = $"root:Packages:twoP:examine:" + aChan + "LastLUTColor"
	left_x = ChFirst
	right_x = ChLast
	appendtograph/W=twoP_HistGraph/L= $"L_" + aChan histWave
	modifygraph/W=twoP_HistGraph rgb ($HistWaveName) = (0,0,0), mode ($HistWaveName) =1
	appendtograph/W=twoP_HistGraph/L= $"L_" + aChan left_y vs left_x
	modifygraph/W=twoP_HistGraph rgb ($left_yName) = (0,0,65535), lsize($left_yName)=2
	appendtograph/W=twoP_HistGraph/L= $"L_" + aChan right_y vs right_x
	modifygraph/W=twoP_HistGraph rgb ($right_yName) = (65535,0,0), lsize($right_yName)=2
	ModifyGraph freePos($"L_" + aChan)={0,bottom}
	label $"L_" + aChan  aChan +  " Number"
	ModifyGraph lblPos($"L_" + aChan)= 55
	return 0
end

// **********************************************************************************
// shares left axis space for all the channels - run after adding or removing a channel
// Last Modified: 2025/08/02 by Jamie Boyd
Function twoP_HistShareAxisSpace ()
	string LeftAxes = removefromlist ("bottom", axisList("twoP_HistGraph"), ";")
	variable iAxis, nAxes = itemsinList (LeftAxes, ";")
	variable axisFrac = (1-.02*(nAxes-1))/nAxes
	string anAixs
	for (iAxis  =0; iAxis < nAxes; iAxis +=1)
		anAixs = stringFromList (iAxis, LeftAxes, ";")
		ModifyGraph axisEnab($anAixs)={(iAxis * axisFrac) + (iAxis * .01) , ((iAxis + 1) * axisFrac) + (iAxis * .01)}
	endfor
end


//****************************************************************************************************
// Lists channels for histogram, marking with checkmarks ones already displayed
// Last Modified: 2025/08/01 by Jamie Boyd
function/S twoP_HistGraphListChans()
	SVAR curScan = root:packages:twoP:examine:curScan
	SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
	string chanList = StringByKey("imChanDesc", scanStr, ":", "\r")
	SVAR selChans = root:packages:twoP:examine:HistGraphSelChans
	variable iChan, nChans = itemsInList(chanList, ",")
	string aChan, outList = ""
	for (iChan =0; iChan < nChans; iChan += 1)
		aChan = stringfromlist (iChan, chanList, ",")
			if (FindListItem(aChan, selChans, ";") > -1)
				outList += "\\M1!"  +num2char(18)
			endif
			outList += aChan + ";"
	endfor
	return outList
end


// ***********************************************************************************
// adds or removes histogram for selected channel
// Last Modified: 2025/08/01 by Jamie Boyd
Function twoP_HistGraphChansPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			SVAR selChans = root:packages:twoP:examine:HistGraphSelChans
			if (FindListItem(pa.popStr, selChans, ";") > -1)  // removing a channel
				selChans = sortList (removeFromList(pa.popStr, selChans, ";"), ";")
				doWindow/F twoP_HistGraph
				if (V_Flag) // window was found
					string histName = "HistWave" + pa.popStr
					string leftName = "ImRangeLefty" + pa.popStr
					string rightName = "ImRangerighty" + pa.popStr
					removefromGraph/W=twoP_HistGraph $histName, $leftName, $rightName
					twoP_HistShareAxisSpace ()
				endif
			else
				selChans = sortList (addlistItem(pa.popStr, selChans, ";"), ";") // adding a channel
				doWindow/F twoP_HistGraph
				// do the histogram
				twoP_HistDoChannel (pa.popStr)
				if (V_Flag) // window was found
					twoP_HistAddChannel (pa.popStr)
					twoP_HistShareAxisSpace ()
				endif
			endif
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End


// *************************************************************************
// Does a histogram of the selected channel for the current scan
// Last Modified 2025/08/02 by Jamie Boyd
Function twoP_HistDoChannel (aChan)
	string aChan
	SVAR curScan = root:packages:twoP:examine:curScan
	SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
	variable mode = NumberByKey("mode", scanStr, ":", "\r") 
	variable doframe 	// set to do a single frame from a stack, else doing whole wave
	if ((mode == kLineScan) || (mode == kSingleImage) || (mode == kLiveMode)) 
		doFrame = 0
	else
		controlinfo/w= twoP_Controls HistFrameCheck
		doFrame = V_Value
	endif
	// make sure hist wave exists
	WAVE/Z HistWave = $"root:Packages:twoP:Examine:HistWave" + aChan
	if (!(WaveExists(HistWave)))
		twoP_LUTmakeChanVars(aChan)
		WAVE HistWave = $"root:Packages:twoP:Examine:HistWave" + aChan
	endif
	if (doFrame)
		WAVE chWave = $"root:packages:twoP:examine:scanGraph_" + aChan
		WAVE scanwave =$"root:twoP_Scans:" + curScan + ":" + curScan + "_" + aChan
		NVAR curVal = root:packages:twoP:examine:curFramePos
		ProjectZSlice (scanwave, chWave, curval)
	else // whole stack
		WAVE chWave =$"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
	endif
	Histogram /B=2 chWave, HistWave
End


//********************************************************************************************
// Buton ptocedure makes a histogram for selected channels of the current scan and disaplys them
// Last Modified Jul 14 2010  by Jamie Boyd
Function twoP_HistButtonProc (ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR selChans = root:packages:twoP:examine:HistGraphSelChans
			variable iChan, nChans = itemsInList(selChans, ";")
			string aChan
			for (ichan =0;iChan < nChans ; iChan +=1)
				aChan = stringFromList (iChan, selChans, ";")
				twoP_HistDoChannel (aChan)
			endfor
			twoP_HistMakeGraph ()
			break
	endswitch
	return 0
End

//********************************************************************************************
// Unchecks other radio button and calls histogram button procedure when checked
// last modified 2025/08/02 by Jamie Boyd
Function twoP_HistTypeCheckProc(cba) : CheckBoxControl
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
			break
	endswitch
	return 0
End

//********************************************************************************************
// CheckBox on histGraph sets left axes to log or linear scaling when corresponding checkboxes are activated
// Last Modified 2025/08/02 by Jamie Boyd
Function twoP_HistAxisCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			variable isLog
			if (cmpStr (cba.ctrlName, "LinearCheck") == 0)
				checkbox LogCheck value = 0
				isLog =0
			else
				checkbox LinearCheck value = 0
				isLog =1
			endif
			string axesStr = ListMatch(axislist ("twoP_HistGraph"), "L_*" , ";"), anAxis
			variable iAxis, nAxes = itemsinlist (axesStr, ";")
			for (iAxis =0; iAxis < nAxes; iAxis +=1)
				anAxis = stringFromList (iAxis, axesStr, ";")
				ModifyGraph log ($anAxis) = isLog
			endfor
			break
	endswitch
	return 0
End



// ***********************************************************************************************************************************
// ----------------------------ScanGraph Image LUT Controls on a per channel basis -----------------------------------------------
// ***********************************************************************************************************************************

//*******************************************************************************************
// Creates global variables for LUT control adjustments. Runs when a procedure can't find globals for a channel
//last modified 2025/07/25 by Jamie Boyd
function twoP_LUTmakeChanVars (LUTchan)
	string LUTchan // name of image channel we are working with
	
	Variable/G $"root:packages:twoP:Examine:" + LUTchan + "LUTAuto"
	Variable/G $"root:Packages:twoP:examine:" + LUTChan + "CTable" = 1									// default grey scale
	String/G $"root:Packages:twoP:examine:" + LUTchan + "CTableStr"="Grays"								// name of color table, popmenu proc wants the name
	Variable/G $"root:Packages:twoP:examine:" + LUTchan + "LUTInvert" = 0 								// don't invert the LUT
	Variable/G $"root:Packages:twoP:examine:" + LUTchan + "FirstLUTColor" = 0							// First color for LUT
	Variable/G $"root:Packages:twoP:examine:" + LUTchan + "LastLUTColor" = (2^kNQimageBits)-1		// last color for LUT e.g., 4095 for 12 bit images
	Variable/G $"root:Packages:twoP:examine:" + LUTchan + "BeforeMode" = 1 								// 0 means first color, 1 means selected color, 2 means transparent
	String/G $"root:Packages:twoP:examine:" + LUTchan + "BeforeColors" = "0,0,65535" 					// use blue for image values before  first color with before mode 1
	Variable/G $"root:Packages:twoP:examine:" + LUTchan + "AfterMode" = 1 								// 0 means last color, 1 means selected color, 2 means transparent
	String/G $"root:Packages:twoP:examine:" + LUTchan + "AfterColors" = "65535,0,0" 					// use red for image values greater tan lest color, with after mode 1
	// make waves to display LUT on histogram
	make/o $"root:Packages:twoP:examine:ImRangeLeftx" + LUTchan = {(0.05 * 2^kNQimageBits), (0.05 * 2^kNQimageBits)}
	make/o $"root:Packages:twoP:examine:ImRangeLefty" + LUTchan = {1,inf}
	make/o $"root:Packages:twoP:examine:ImRangeRightx" + LutChan = {(0.95 * 2^kNQimageBits) ,(0.95 * 2^kNQimageBits)}
	make/o $"root:Packages:twoP:examine:ImRangeRighty" + LutChan = {1,inf}
	// make histogram wave as well
	make/o/n = (2^kNQimageBits) $"root:Packages:twoP:Examine:HistWave" + LUTchan
	WAVE HistWave = $"root:Packages:twoP:Examine:HistWave" + LUTchan
	setscale/p x, 0, 1	, "", HistWave
end

//********************************************************************************************
// Applies LUT settings from all the LUT controls to a channel image in the scan graph
// Last Modified: 2025/07/25 by Jamie Boyd
function twoP_LUTApplysettings (LUTchan)
	string LUTchan  //not limited to ch1 or ch2 anymore
	SVAR curScan = root:packages:twoP:examine:curScan
	SVAR ScanStr = $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_info"
	variable scanMode = numberbykey ("mode", curScan, ":", "\r" )
	Switch (scanMode)
		case kLiveMode:
		case kZSeries:
		case kTimeSeries:
			wave scangraphWave = $"root:Packages:twoP:examine:scanGraph_" + LUTchan
			break
			// 2D waves displayed directly in the graph
		case kLineScan:
		case kSingleImage:
			wave scangraphWave =$"root:twoP_Scans:" + curScan + ":" + curScan + LUTchan
			break
	endSwitch
	// Reference needed LUT globals for this channel - make sure they exist
	SVAR/Z CTableStr = $"root:Packages:twoP:examine:" + LUTchan + "CTableStr"
	NVAR/Z inVert =$"root:Packages:twoP:examine:" + LUTchan + "LUTInvert"
	NVAR/Z FirstLUTColor = $"root:Packages:twoP:examine:" + LUTchan + "FirstLUTColor"
	NVAR/Z LastLutColor = $"root:Packages:twoP:examine:" + LUTchan + "LastLUTColor"
	NVAR/Z autoLUT = $"root:packages:twoP:Examine:" + LUTchan + "LUTAuto"
	NVAR/Z beforeMode = $"root:Packages:twoP:examine:" + LutChan + "BeforeMode"
	SVAR/Z beforeColors = $"root:Packages:twoP:examine:" + LUTchan + "BeforeColors"
	NVAR/Z afterMode =  $"root:Packages:twoP:examine:" + LUTchan + "AfterMode"
	SVAR/Z afterColors = $"root:Packages:twoP:examine:" + LUTchan + "AfterColors"
	if (!(SVAR_Exists(CTableStr) && NVAR_Exists(invert) && NVAR_Exists(FirstLUTColor) && \
		NVAR_Exists(LastLUTColor) && 	 NVAR_Exists(autoLut) && NVAR_Exists (beforeMode) && \
		  SVAR_Exists (beforeCOlors)  && NVAR_Exists(afterMode) && SVAR_Exists(afterCOlors)))
		twoP_LUTmakeChanVars (LUTchan)
		SVAR CTableStr = $"root:Packages:twoP:examine:" + LUTchan + "CTableStr"
		NVAR inVert =$"root:Packages:twoP:examine:" + LUTchan + "LUTInvert"
		NVAR FirstLUTColor = $"root:Packages:twoP:examine:" + LUTchan + "FirstLUTColor"
		NVAR LastLutColor = $"root:Packages:twoP:examine:" + LUTchan + "LastLUTColor"
		NVAR autoLUT = $"root:packages:twoP:Examine:" + LUTchan + "LUTAuto"
		NVAR beforeMode = $"root:Packages:twoP:examine:" + LutChan + "BeforeMode"
		SVAR beforeColors = $"root:Packages:twoP:examine:" + LUTchan + "BeforeColors"
		NVAR afterMode =  $"root:Packages:twoP:examine:" + LUTchan + "AfterMode"
		SVAR afterColors = $"root:Packages:twoP:examine:" + LUTchan + "AfterColors"
	endif
	// subwindow on scangraph named for channel
	string subWinStr  = "twoPscanGraph#G" + LUTchan
	variable rColor, gColor, bColor
	if (autoLUT)
		ModifyImage/w=$subWinStr $nameofwave(scangraphWave) ctab= {*,*,$CTableStr,inVert}
	else
		ModifyImage/w=$subWinStr $nameofwave(scangraphWave) ctab= {FirstLUTColor,LastLutColor,$CTableStr,inVert}
		switch (beforeMode) // 0 means first color, 1 means selected color, 2 means transparent
			case 0: // Use first color
				ModifyImage/w=$subWinStr $nameofwave(scangraphWave), minRGB = 0
				break
			case 1: // Use selected color
				rColor = str2num (stringFromlist (0, beforeColors, ","))
				gColor = str2num (stringFromlist (1, beforeColors, ","))
				bColor = str2num (stringFromlist (2, beforeColors, ","))
				ModifyImage/w=$subWinStr $nameofwave(scangraphWave), minRGB = (rColor, gColor, bColor)
				break
			case 2: // transparent
				ModifyImage/w=$subWinStr $nameofwave(scangraphWave), minRGB = NaN
		endswitch
		
		switch (afterMode) // 0 means last color, 1 means selected color, 2 means transparent
			case 0: // Use last color
				ModifyImage/w=$subWinStr $nameofwave(scangraphWave), maxRGB = 0
				break
			case 1: // Use selected color
				rColor = str2num (stringFromlist (0, afterColors, ","))
				gColor = str2num (stringFromlist (1, afterColors, ","))
				bColor = str2num (stringFromlist (2, afterColors, ","))
				ModifyImage/w=$subWinStr $nameofwave(scangraphWave), maxRGB = (rColor, gColor, bColor)
				break
			case 2: // transparent
				ModifyImage/w=$subWinStr $nameofwave(scangraphWave), maxRGB = NaN
		endswitch
	endif
end

//********************************************************************************************
// After choosing a channel to apply LUT  to, adjusts all the controls for LUT to the ones for that channel
// Last Modified: 2025/07/23 by Jamie Boyd
Function twoP_LUTchanPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			// set currently selected channel
			SVAR LUTchan = root:Packages:twoP:examine:LUTChan
			LUTChan = pa.popStr
			// Reference needed LUT globals for this channel - make sure hey exist
			NVAR/Z CTable =  $"root:Packages:twoP:examine:" + LUTchan + "CTable"
			SVAR/Z CTableStr = $"root:Packages:twoP:examine:" + LUTchan + "CTableStr"
			NVAR/Z inVert =$"root:Packages:twoP:examine:" + LUTchan + "LUTInvert"
			NVAR/Z FirstLUTColor = $"root:Packages:twoP:examine:" + LUTchan + "FirstLUTColor"
			NVAR/Z LastLutColor = $"root:Packages:twoP:examine:" + LUTchan + "LastLUTColor"
			NVAR/Z autoLUT = $"root:packages:twoP:Examine:" + LUTchan + "LUTAuto"
			NVAR/Z beforeMode = $"root:Packages:twoP:examine:" + LutChan + "BeforeMode"
			SVAR/Z beforeColors = $"root:Packages:twoP:examine:" + LUTchan + "BeforeColors"
			NVAR/Z afterMode =  $"root:Packages:twoP:examine:" + LUTchan + "AfterMode"
			SVAR/Z afterColors = $"root:Packages:twoP:examine:" + LUTchan + "AfterColors"
			if (!(NVAR_Exists (CTable) && SVAR_Exists(CTableStr) && NVAR_Exists(invert) && NVAR_Exists(FirstLUTColor) && \
				NVAR_Exists(LastLUTColor) && 	 NVAR_Exists(autoLut) && NVAR_Exists (beforeMode) && \
				  SVAR_Exists (beforeCOlors)  && NVAR_Exists(afterMode) && SVAR_Exists(afterCOlors)))
				twoP_LUTmakeChanVars (LUTchan)
				NVAR CTable =  $"root:Packages:twoP:examine:" + LUTchan + "CTable"
				SVAR CTableStr = $"root:Packages:twoP:examine:" + LUTchan + "CTableStr"
				NVAR inVert =$"root:Packages:twoP:examine:" + LUTchan + "LUTInvert"
				NVAR FirstLUTColor = $"root:Packages:twoP:examine:" + LUTchan + "FirstLUTColor"
				NVAR LastLutColor = $"root:Packages:twoP:examine:" + LUTchan + "LastLUTColor"
				NVAR autoLUT = $"root:packages:twoP:Examine:" + LUTchan + "LUTAuto"
				NVAR beforeMode = $"root:Packages:twoP:examine:" + LutChan + "BeforeMode"
				SVAR beforeColors = $"root:Packages:twoP:examine:" + LUTchan + "BeforeColors"
				NVAR afterMode =  $"root:Packages:twoP:examine:" + LUTchan + "AfterMode"
				SVAR afterColors = $"root:Packages:twoP:examine:" + LUTchan + "AfterColors"
			endif
			
			variable rColor, gColor, bColor
			// adjust LUT popmenu
			popupmenu LUTpopUp mode = CTable
			// Adjust invert check
			checkbox LUTInvertCheck win=twoP_Controls, variable =inVert
			// adjust First and Last color SetVariables
			setvariable LUTFirstValueSetVar win=twoP_Controls, variable = FirstLUTColor
			setvariable LUTLastValueSetVar win=twoP_Controls, variable = LastLutColor
			// Adjust MinMax slider
			MinMaxSlider_Manual ("twoP_Controls", "LUTslider", kLeftThumb, FirstLUTColor)
			MinMaxSlider_Manual ("twoP_Controls", "LUTslider", kRightThumb, LastLutColor)
			// Adjust LUT autoCheck
			checkbox LUTautoCheck win=twoP_Controls, variable = $"root:packages:twoP:examine:" + LUTChan + "LUTauto"
			// Adjust first color radio buttons and popmenu
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
				endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


//******************************************************************************************************
// Function for the LUT popup menu. Select a look up table to use for selected channel of the scan and save info in global variables for the channel
// Last Modified 2025/07/25 by Jamie Boyd
Function twoP_LUTPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			SVAR LUTChan = root:Packages:twoP:examine:LUTChan
			// save changed value in appropriate global for selected channel
			NVAR/z CTable = $"root:Packages:twoP:examine:" + LUTchan + "CTable"
			SVAR/z ctableStr = $"root:Packages:twoP:examine:" + LUTchan + "CTableStr"
			if (!(NVAR_Exists(CTable) && SVAR_Exists(cTableStr)))
				 twoP_LUTmakeChanVars (LUTchan)
				NVAR CTable = $"root:Packages:twoP:examine:" + LUTchan + "CTable"
				SVAR ctableStr = $"root:Packages:twoP:examine:" + LUTchan + "CTableStr"
			endif
			CTable = pa.popNum
			cTableStr = pa.popStr
			// Apply Image settings for channel
			if (WhichListItem("G" + LUTChan, childwindowlist ("twoPscanGraph"), ";",0, 0) > -1)
				twoP_LUTApplysettings (LUTChan)
			endif
			break
	endswitch
	return 0
End


//******************************************************************************************************
// Function for the LUTinvert Check.
// Last Modified 2025/07/23 by Jamie Boyd
Function twoP_LUTInvertCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			//Update image settings for selected channel. checkbox is already hooked up to correctvariable for channel
			SVAR LUTChan = root:Packages:twoP:examine:LUTChan
			if (WhichListItem("G" + LUTchan, childwindowlist ("twoPscanGraph"), ";", 0, 0) > -1)
				twoP_LUTApplysettings (LUTChan)
			endif		
			break
	endswitch
	return 0
End

			
//******************************************************************************************************
// Function for the LUT first and last values Setvariables.Calls Apply Image settings procedure for selected channel
// Last Modified 2025/07/25 by Jamie Boyd
Function twoP_LUTValsSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			SVAR LUTchan = root:Packages:twoP:examine:LUTChan 
			// check for global variable for this chan
			NVAR/Z FirstColor = $"root:packages:twoP:examine:" + LUTchan + "FirstLutColor"
			NVAR/Z LastColor = $"root:packages:twoP:examine:" + LUTchan + "LastLutColor"
			WAVE/Z leftWave = $"root:Packages:twoP:examine:ImRangeLeftx" + LUTchan
			WAVE/Z rightWave = $"root:Packages:twoP:examine:ImRangerightx" + LUTchan
			if (!(NVAR_Exists(FirstColor) && NVAR_Exists(LastCOlor) && WAVEExists(LeftWave) && WaveExists(rightWave)))
				twoP_LUTmakeChanVars (LUTchan)
				NVAR FirstColor = $"root:packages:twoP:examine:" + LUTchan + "FirstLutColor"
				NVAR LastColor = $"root:packages:twoP:examine:" + LUTchan + "LastLutColor"
				WAVE leftWave = $"root:Packages:twoP:examine:ImRangeLeftx" + LUTchan
				WAVE rightWave = $"root:Packages:twoP:examine:ImRangerightx" + LUTchan
			endif
			
			if (cmpstr (sva.ctrlname, "LUTFirstValueSetVar") == 0)
				if (sva.dval > LastColor)
					FirstColor = LastColor -1
				endif
				leftWave = FirstColor
			else
				if (sva.dval <  firstColor)
					LastColor = FirstColor + 1
				endif
				rightWave = LastColor
			endif
			MinMaxSlider_Manual ("twoP_Controls", "LUTslider", kLeftThumb, FirstColor)
			MinMaxSlider_Manual ("twoP_Controls", "LUTslider", kRightThumb, LastColor)
			// apply image settings
			string SubWinList = childwindowlist ("twoPscanGraph")
			if (WhichListItem("G"+LUTchan, SubWinList, ";", 0,0) > -1)
				twoP_LUTApplysettings (LUTchan)
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Function for the LUT first and last values Slider.Calls Apply Image settings procedure for selected channel
// Last Modified 2025/07/22 by Jamie Boyd
Function twoP_LUTSliderAction (leftThumb, rightThumb, event, thumb)
	variable leftThumb		// value left thumb is pointing to
	variable rightThumb	// value right thumb is pointing to
	variable event			// type of event (thumb up or thumb moved
	variable thumb			// 1 if a left thumb was just moved or 2 for a right thumb

	rightThumb = round (rightThumb)
	leftThumb = round (leftThumb)
	//check which channel to modify
	SVAR LUTchan = root:Packages:twoP:examine:LUTChan
	NVAR/Z FirstColor = $"root:packages:twoP:examine:" + LUTchan + "FirstLutColor"
	WAVE/Z leftWave = $"root:Packages:twoP:examine:ImRangeLeftx" + LUTchan
	NVAR/Z LastColor = $"root:packages:twoP:examine:" + LUTchan + "LastLutColor"
	WAVE/Z rightWave = $"root:Packages:twoP:examine:ImRangerightx" + LUTchan
	if (!(NVAR_Exists(FirstColor) && WAVEExists(LeftWave) && NVAR_Exists(LastColor) && WAVEExists(rightWave)))
		twoP_LUTmakeChanVars (LUTchan)
		NVAR FirstColor = $"root:packages:twoP:examine:" + LUTchan + "FirstLutColor"
		WAVE leftWave = $"root:Packages:twoP:examine:ImRangeLeftx" + LUTchan
		NVAR LastColor = $"root:packages:twoP:examine:" + LUTchan + "LastLutColor"
		WAVE rightWave = $"root:Packages:twoP:examine:ImRangerightx" + LUTchan
	endif

	if (thumb == kleftThumb)
		FirstColor = leftThumb
		leftWave = leftThumb
		if (firstColor > LastColor -4)
			LastColor = rightThumb
			rightWave = rightThumb
		endif
	else
		LastColor = rightThumb
		rightWave = rightThumb
		if (firstCOlor < lastColor + 4)
			FirstColor = leftThumb
			leftWave = leftThumb
		endif
	endif

	if (event == kCallMouseMoved)
		// Apply image settings
		if (WhichListItem("G" + LUTchan, childwindowlist ("twoPscanGraph"), ";", 0, 0) > -1)
			twoP_LUTApplysettings (LUTChan)
		endif
	endif
	return 0
End


//******************************************************************************************************
// Sets first and last colors to Min/Max of data, then calls Apply Image settings procedure for selected channel
// Last Modified:
//  2025/07/22 by Jamie Boyd - new channel selction mode
Function twoP_LUTtoDataProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR LUTChan = root:Packages:twoP:examine:LUTChan
			NVAR/Z FirstColor = $"root:packages:twoP:examine:" + LUTchan + "FirstLutColor"
			WAVE/Z leftWave = $"root:Packages:twoP:examine:ImRangeLeftx" + LUTchan
			NVAR/Z LastColor = $"root:packages:twoP:examine:" + LUTchan + "LastLutColor"
			WAVE/Z rightWave = $"root:Packages:twoP:examine:ImRangerightx" + LUTchan
			if (!(NVAR_Exists(firstColor) && NVAR_Exists(LastColor) && WAVEExists(leftWave) && WAVEExists(rightWave)))
				twoP_LUTmakeChanVars (LUTchan)
				NVAR FirstColor = $"root:packages:twoP:examine:" + LUTchan + "FirstLutColor"
				WAVE leftWave = $"root:Packages:twoP:examine:ImRangeLeftx" + LUTchan
				NVAR LastColor = $"root:packages:twoP:examine:" + LUTchan + "LastLutColor"
				WAVE rightWave = $"root:Packages:twoP:examine:ImRangerightx" + LUTchan
			endif
			
			SVAR curScan = root:packages:twoP:examine:curScan
			if (cmpstr (curScan, "LiveScan") ==0)
				SVAR/Z ScanStr = root:twoP_Scans:liveScan_info
			else
				SVAR/Z ScanStr = $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_info"
			endif
			variable scanMode = numberbykey ("mode", curScan, ":", "\r" )
			if (scanMode == kLiveMode)
				WAVE scanWave = $"root:twoP_Scans:LiveScan_" + LUTChan
			else
				WAVE scanWave =$"root:twoP_Scans:" + curScan + ":" + curScan + "_" +  LUTChan
			endif
			// check for limiting to 96% - we need a full histogram, else just max and min
			controlinfo/w= twoP_Controls LUT96check
			if (V_Value)
				make/I/U/n=4096/FREE histWave
				setscale x 0, 4095, "", histWave
				histogram/B=2 scanWave, histWave
				variable theSum =  sum (histWave)
				variable ii, runningSum, val2 = theSum * 0.02, val98 = theSum * 0.98
				for (ii =0, runningSum = 0; runningSum < val2; ii += 1, runningSum += histWave [ii])
				endfor
				FirstColor = round (pnt2x (histWave, ii))
				for (ii =4095, runningSum = theSum;  runningSum >val98 ; ii -= 1, runningSum -= histWave [ii])
				endfor
				LastColor = round (pnt2x (histWave, ii))
			else //NOt 96%,just min and max
				WaveStats/M=1/Q scanWave
				FirstColor = V_min
				LastColor = V_max
			endif
			// apply first color and last color to dragger waves
			leftWave = FirstColor
			rightWave = LastColor
			MinMaxSlider_Manual ("twoP_Controls", "LUTslider", kRightThumb, LastColor)
			MinMaxSlider_Manual ("twoP_Controls", "LUTslider", kLeftThumb, FirstColor)
			// Apply image settings
			if (WhichListItem("G" + LUTChan, childwindowlist ("twoPscanGraph"), ";", 0,0) > -1)
				twoP_LUTApplysettings (LUTChan)
			endif
//			
//			string SubWinList = childwindowlist ("twoPscanGraph")
//			variable hasChan, hasMrg = (WhichListItem("GMRG", SubWinList) > -1)
//			if (isChan1)
//				hasChan = (WhichListItem("GCH1", SubWinList) > -1)
//				if (hasChan || hasMrg)
//					NQ_ApplyImSettings (hasChan + 4 * hasMrg)
//				endif
//			else
//				hasChan = (WhichListItem("GCH2", SubWinList) > -1)
//				if (hasChan || hasMrg)
//					NQ_ApplyImSettings (2 * hasChan + 4 * hasMrg)
//				endif
//			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Calls twoP_LUTtoDataProc, so user doesn't have to do it explicitly
// Last Modified July 06 2009 by Jamie
Function twoP_LUT96CheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			STRUCT WMButtonAction ba
			ba.eventCode = 2
			twoP_LUTtoDataProc(ba)
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Manages radio buttons for before first color modes, then calls Apply Image settings procedure for selected channel
// Last Modified 2025/07/22 by Jamie Boyd - new channel selction mode
Function twoP_LUTBeforeModeCheckProc(cba) : CheckBoxControl
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
			SVAR LUTChan = root:Packages:twoP:examine:LUTChan
			NVAR/Z beforeModeG = $"root:Packages:twoP:examine:"  + LUTChan + "BeforeMode"
			if (!(NVAR_Exists(beforeModeG)))
				twoP_LUTmakeChanVars (LUTchan)
				NVAR beforeModeG = $"root:Packages:twoP:examine:"  + LUTChan + "BeforeMode"
			endif
			beforeModeG = beforeMode
			// Apply image settings
			if (WhichListItem("G" + LUTChan, childwindowlist ("twoPscanGraph"), ";", 0,0) > -1)
				twoP_LUTApplysettings (LUTChan)
			endif
	
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Manages color PopMenu for before first color modes, then calls Apply Image settings procedure for selected channel
// Last Modified 2025/07/22 by Jamie Boyd - new channel selction mode
Function twoP_LUTBeforeColorPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			// save changed value in appropriate global for selected channel
			SVAR LUTchan = root:Packages:twoP:examine:LUTChan
			SVAR/Z beforeColors = $"root:Packages:twoP:examine:" + LUTChan + "BeforeColors"
			if (!(SVAR_Exists(beforeCOlors)))
				twoP_LUTmakeChanVars (LUTchan)
				SVAR beforeColors = $"root:Packages:twoP:examine:" + LUTChan + "BeforeColors"
			endif
			// Strip opening and closing braces
			variable bcLen = strlen (popStr)
			beforeColors = popStr [1, bcLen-2]
			// Apply image settings
			if (WhichListItem("G" + LUTChan, childwindowlist ("twoPscanGraph"), ";", 0,0) > -1)
				twoP_LUTApplysettings (LUTChan)
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Manages radio buttons for after last color modes, then calls Apply Image settings procedure for selected channel
// Last Modified 2025/07/22 by Jamie Boyd - new channel selction mode
Function twoP_LUTAfterModeCheckProc(cba) : CheckBoxControl
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
			SVAR LUTchan = root:Packages:twoP:examine:LUTChan
			NVAR/Z afterModeG = $"root:Packages:twoP:examine:" + LUTChan + "AfterMode"
			if (!(NVAR_Exists(afterModeG)))
				twoP_LUTmakeChanVars (LUTchan)
				NVAR afterModeG = $"root:Packages:twoP:examine:" + LUTChan + "AfterMode"
			endif
			afterModeG = afterMode
			if (WhichListItem("G" + LUTChan, childwindowlist ("twoPscanGraph"), ";", 0,0) > -1)
				twoP_LUTApplysettings (LUTChan)
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Manages color PopMenu for after after last color modes, then calls Apply Image settings procedure for selected channel
// Last Modified 2025/07/25 by Jamie Boyd - new channel selction modeany channel you like
Function twoP_LUTAfterColorPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			SVAR LUTchan = root:Packages:twoP:examine:LUTChan
			// save changed value in appropriate global for selected channel
			SVAR/Z AfterColors = $"root:Packages:twoP:examine:" + LUTchan + "AfterColors"
			if (!(SVAR_Exists(AfterColors)))
				twoP_LUTmakeChanVars (LUTchan)
				SVAR AfterColors = $"root:Packages:twoP:examine:" + LUTchan + "AfterColors"
			endif
			// Strip opening and closing braces
			variable acLen = strlen (popStr)
			AfterColors = popStr [1, acLen-2]
			if (WhichListItem("G" + LUTChan, childwindowlist ("twoPscanGraph"), ";", 0,0) > -1)
				twoP_LUTApplysettings (LUTChan)
			endif
			break
	endswitch
	return 0
End


//******************************************************************************************************
// Manages Auto LUT selection checkbox, then calls Apply Image settings procedure for selected channel
// Last Modified 2012/06/13 by Jamie Boyd
Function twoP_LUTAutoCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			SVAR LUTchan = root:Packages:twoP:examine:LUTChan
			twoP_LUTApplysettings (LUTchan)
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
		SVAR/Z ScanStr = root:twoP_Scans:LiveScan_info
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
// last modified 2025/07/21 by Jamie Boyd
Function NQ_DROICheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			if (checked) // turn on DROI
				SVAR CurScan =root:Packages:twoP:examine:curScan
				SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
				variable mode = numberbykey ("mode", scanStr, ":", "\r")
				if (!((mode == kTimeSeries) || (mode == kZseries)))
					NVAR doDroi = root:packages:twoP:examine:doDROI
					doDroi =0
					return 1
				endif
				variable imChans = numberbykey ("imChans", scanStr, ":", "\r")
				string ModeUnits = ""
				variable frameSize, zStart
				if (mode == kTimeSeries)
					modeUnits = "s"
					FrameSize = numberbykey ("FrameTime", scanStr, ":", "\r")
					zStart = 0
				elseif (mode == kZseries)
					modeUnits = "m"
					FrameSize = numberbykey ("zStepSize", scanStr, ":", "\r")
					zStart = numberbykey ("zPos", scanStr, ":", "\r")
				endif
				variable ROIpnts = numberbykey ("NumFrames", scanStr, ":", "\r")
				NVAR doCh1 = root:Packages:twoP:examine:doDROIch1
				NVAR doCh2 = root:Packages:twoP:examine:doDROIch2
				NVAR doRatio = root:Packages:twoP:examine:doDROIratio
				// make waves so they can be appened later, even if not selected now
				if (imChans & 1)
					WAVE data1Wave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
					make/o/n= (ROIpnts) root:Packages:twoP:examine:Droi_ch1
					WAVE Droi_ch1 = root:Packages:twoP:examine:Droi_ch1
					SetScale/p x (zStart),(FrameSize),modeUnits, Droi_ch1
				else
					doCh1 = 0
				endif
				if (imChans & 2)
					WAVE data2Wave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
					make/o/n= (ROIpnts) root:Packages:twoP:examine:Droi_ch2
					WAVE Droi_ch2 = root:Packages:twoP:examine:Droi_ch2
					SetScale/p x (zStart),(FrameSize),modeUnits, Droi_ch2
				else
					doCh2 = 0
				endif
				if ((imChans && 1) && (imChans && 2))
					make/o/n= (ROIpnts) root:Packages:twoP:examine:Droi_ratio
					WAVE Droi_ratio = root:Packages:twoP:examine:Droi_ratio
					SetScale/p x (zStart),(FrameSize),modeUnits, Droi_ratio
				else
					doRatio =0
				endif
				// plot channels selected now
				variable nAxes =0, iAxis
				string axisStr = "", anAxis
				if (doCh1)
					nAxes +=1
					axisStr= AddListItem("ch1", axisStr, ";", INF)
				endif
				if (doCh2)
					nAxes += 1
					axisStr= AddListItem("ch2", axisStr, ";", INF)
				endif
			if (doRatio)
				nAxes += 1
				axisStr= AddListItem("ratio", axisStr, ";", INF)
			endif
			// kill old graph
			doWindow/K NQ_DROI_graph
			// make new graph
			display/k=2/N=NQ_DROIgraph as "Dynamic ROI for " + CurScan
			variable axisFrac = (1-.02*(nAxes-1))/nAxes
			for (iAxis =0; iAxis < nAxes; iAxis += 1)
				anAxis = stringfromlist (iAxis, axisStr, ";")
				WAVE dROIWave = $"root:Packages:twoP:examine:Droi_" + anAxis
				appendtograph /L= $"L_" + anAxis dROIWave
				ModifyGraph freePos($"L_" + anAxis)={zStart,bottom}
				ModifyGraph axisEnab($"L_" +  anAxis)={(iAxis * axisFrac) + (iAxis * .01) , ((iAxis + 1) * axisFrac) + (iAxis* .01)}
				label $"L_" + anAxis "DROI " + stringfromlist (iAxis, axisStr)
				ModifyGraph lblPos( $"L_" + anAxis)=60
			endfor
		else //kill old graph
			DoWindow/k NQ_DROIgraph
		endif
		break
endSwitch
end

//******************************************************************************************************
// allows individual selection of channels for DROI after DROI graph has already been made
// last modified 2025/07/22 by Jamie Boyd
Function twoP_DROIchanCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	switch( cba.eventCode )
		case 2: // mouse up
			string chanName  = cba.ctrlName 
			chanName = chanName [9, strlen (cba.ctrlName)-1]
			SVAR curScan = root:packages:twoP:examine:curScan
			SVAR scanNote = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
			string chanList =stringbykey ("imChanDesc", scanNote, ":", "\r")
			if (cba.checked)
				if (cmpStr (chanName, "ratio") == 0)
					if ((WhichListItem("ch1", chanList, ",", 0,0) == -1) || (WhichListItem("ch2", chanList, ",", 0,0) == -1))
						checkbox $cba.ctrlName value = 0
						return 1
					endif
			 	elseif (WhichListItem(chanName, chanList, ",", 0,0) == -1)
			 		checkbox $cba.ctrlName value = 0
					return 1
				endif
			endif
			// if Checked we are adding a trace, else removing
			NVAR doROI = root:Packages:twoP:examine:doDroi
			if (doROI)
				if (cba.checked ==0)
					removefromGraph/W=NQ_DROIgraph $"Droi_" + chanName
				else
					WAVE dROIWave = $"root:Packages:twoP:examine:Droi_" + chanName
					appendtograph/w=NQ_DROIgraph /L= $"L_" + chanName dROIWave
					ModifyGraph/w=NQ_DROIgraph  freePos($"L_" + chanName)={dimoffset (dROIWave, 0),bottom}
					label/w=NQ_DROIgraph  $"L_" + chanName "DROI " + chanName
					ModifyGraph/w=NQ_DROIgraph  lblPos( $"L_" + chanName)=60
				endif			
				string axesStr = ListMatch(axislist ("NQ_DROIgraph"), "L_*" , ";"), anAxis
				variable iAxis, nAxes = itemsinlist (axesStr, ";")
				variable axisFrac = (1-.02*(nAxes-1))/nAxes
				for (iAxis  =0; iAxis < nAxes; iAxis +=1)
					anAxis = StringFromList(iAxis, axesStr, ";")
					ModifyGraph/w=NQ_DROIgraph axisEnab($anAxis)={(iAxis * axisFrac) + (iAxis * .01) , ((iAxis + 1) * axisFrac) + (iAxis* .01)}
				endfor
			endif
			break
		case -1: // control being killed
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

//*********************************************************************************************************
// Creates Scan ListBox Panel and makes waves for dynamic DSI and displays them in a graph
// Added Oct 11 2017 by Ben Murphy-Baum
Function DroiDSICheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	NVAR DroiDSIcheck = root:Packages:twoP:examine:DroiDSIcheck
	Wave/T scanListWave = root:Packages:twoP:examine:scanListWave
	Make/O/N=(DimSize(scanListWave,0)) root:Packages:twoP:examine:selWave
	Wave selWave = root:Packages:twoP:examine:selWave
	
	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			DroiDSIcheck = checked
			If(checked)
				NewPanel/HOST=twoP_Controls/EXT=0/W=(0,0,0.15,0.4)/K=1/N=ScanListPanel
				ListBox/Z scanListBox win=twoP_Controls#ScanListPanel,size={140,380},pos={5,10},mode=4,selWave=selWave,listWave=scanListWave,proc=ScanListBoxProc
			Else
				KillWindow/Z twoP_Controls#ScanListPanel
			Endif
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End




//******************************************************************************************************
//Reorders a wave with directional information so angles are in linear order 
//Added Oct. 11 2017 by Ben Murphy-Baum

Function ReorderDSTrace(inputWave,numDirections)
	wave inputWave
	variable numDirections
	variable delta,i,j
	
	delta = 360/numDirections
	
	If(DataFolderExists("root:var:") == 0) //data folder doesn't exist
		NewDataFolder root:var 
	Endif
	
	Make/O/N=(numDirections) root:var:temp
	wave temp = root:var:temp
	
	j = 0
	For(i=0;i<numDirections/2;i+=1)
		temp[i] = inputWave[j]
		j+=2
	Endfor
	j = 1
	For(i=numDirections/2;i<numDirections;i+=1)
		temp[i] = inputWave[j]
		j+=2
	Endfor
	inputWave = temp
	SetScale/P x,0,delta,inputWave
	KillWaves temp
End

//BMB edit for DSI mapping button

Function dsiMapButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	NVAR curScanNumber = root:packages:twoP:examine:curScanNum
	switch( ba.eventCode )
		case 2: //mouse up
		
//			qkSpot(1,"Scan",curScanNumber,1)
			break
		case -1: //control being killed
			break
	endswitch
	
	return 0
End



function/S scanNote ()
	SVAR currentScan = root:packages:twoP:examine:curScan
	if (cmpStr (currentScan, "LiveWave") == 0)
		SVAR scanStr =root:packages:twoP:Acquire:LiveModeScanStr
	else
		SVAR scanStr = $"root:twoP_Scans:" + currentScan + ":" + currentScan + "_info"
	endif
	return scanStr
end

