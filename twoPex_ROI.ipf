#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma version = 3  	// Last Modified: 2025/08/05 by Jamie Boyd.
#pragma IgorVersion = 9

//******************************************************************************************************
//------------------------------- Code for The ROI tab on the 2P Examine TabControl--------------------------------------------
//******************************************************************************************************

//******************************************************************************************************
// Graph Marquee functions to do useful ROI things on the scan graph
Menu "GraphMarquee"
	submenu "twoP Examine"
		"Set Dark Fluorescence Region",/Q, twoP_Set_Dark_Fluorescence ()
		"Do ROI", /Q,twoP_DoRoi()
	end
end

// Set_Dark_Fluorescence grabs the graph marquee and sets some values a) in the Examine globals folder and B) in the note of the current scan.
// These values will be used to subtract dark fluorescence in the ROI functions. 
// Only left and right are saved for line scan, setting the globals for top and bottom in the examine folder to nan, to prevent using line scan dark
// area for an image scan
// Last Modified 2025/07/24 by Jamie Boyd
Function twoP_Set_Dark_Fluorescence()

	GetMarquee/k left,bottom
	//always set left and right
	variable/G root:packages:twoP:examine:darkL = v_left
	variable/G root:packages:twoP:examine:darkR = v_right
	// set V_top and V_bottom to NaN for linescan
	SVAR curscan = root:Packages:twoP:examine:CurScan
	if (cmpStr (CurScan, "LiveScan") != 0)
		SVAR scanNote = $"root:twoP_Scans:" + curscan  + ":" + curScan +  "_info"
	else
		SVAR scanNote = root:twoP_Scans:LiveScan_info
	endif
	variable scanMode= NumberByKey("mode", scanNote, ":", "\r")
	if (scanMode == kLineScan)
		v_top = Nan
		v_bottom =Nan
	endif
	variable/G root:packages:twoP:examine:darkT = v_top
	variable/G root:packages:twoP:examine:darkB = v_Bottom
	if (scanMode != kLiveMode)
		ScanNote = ReplaceNumberByKey("darkL", ScanNote, V_left, ":", "\r")
		ScanNote = ReplaceNumberByKey("darkR", ScanNote, V_right, ":", "\r")
		if (scanMode != kLineScan)
			ScanNote = ReplaceNumberByKey("darkT", ScanNote, V_top, ":", "\r")
			ScanNote = ReplaceNumberByKey("darkB", ScanNote, V_Bottom, ":", "\r")
		endif
	endif
end

// ********************************************************************************************************************
// function for adding  the ROI tab
// Last Modified 2025/07/23 by Jamie Boyd
Function NQexROI_add (able)
	variable able

	// Globals for ROI Tab
	string/G root:packages:twoP:examine:ROIimPath = "no folder selected"
	string/G root:packages:twoP:examine:newROIname
	variable/G root:packages:twoP:examine:ROITopChan = 1 //1 for channel 1/ channel 2, 2 for channel 2/channel 1
	variable/G root:packages:twoP:examine:ROISubtractBkg = 0
	variable/G root:packages:twoP:examine:ROIdoDetaF= 0
	variable/G root:packages:twoP:examine:ROIBaseStart =0
	variable/G root:packages:twoP:examine:ROIBaseEnd =0.1
	variable/G root:packages:twoP:examine:ROIChan =1
	variable/G root:packages:twoP:examine:ROIDoMatch = 0
	String/G root:packages:twoP:examine:ROIScanMatchStr = "*"
	String/G root:packages:twoP:examine:ROInoteKeyStr = "key"
	String/G root:packages:twoP:examine:ROInoteValueStr = "val1;val2"
	String/G root:packages:twoP:examine:ROIselChan = ""
	Variable/G root:packages:twoP:examine:ROIscanSelMode = 0
	make/o/t/n= 0 root:Packages:twoP:examine:ROIListWave
	make/o/n= 0 root:Packages:twoP:examine:ROIListSelWave
	// Saving and Loading ROIs to disk
	Button ROILoadButton win =twoP_Controls,pos={9.00,412.00},size={44.00,20.00},proc=NQ_RoiLoadProc
	Button ROILoadButton win =twoP_Controls,title="Load"
	Button ROILoadButton win =twoP_Controls, disable = able
	Button ROISaveButton win =twoP_Controls,pos={56.00,412.00},size={44.00,20.00},proc=NQ_ROISaveProc
	Button ROISaveButton win =twoP_Controls,title="Save"
	Button ROISaveButton win =twoP_Controls, disable = able
	Button ROISetFolderButton win =twoP_Controls,pos={103.00,412.00},size={68.00,20.00},proc=NQ_ROIsetPathProc
	Button ROISetFolderButton win =twoP_Controls,title="Set Path"
	Button ROISetFolderButton win=twoP_Controls, disable = able
	TitleBox ROIImpathtitle win=twoP_Controls,pos={173.00,416.00},size={578.00,15.00},fSize=12
	TitleBox ROIImpathtitle win=twoP_Controls,frame=0,variable=root:packages:twoP:examine:ROIimPath
	TitleBox ROIImpathtitle win=twoP_Controls, disable = able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "ROI","Button ROILoadButton 0;Button ROISaveButton 0;Button ROISetFolderButton 0;Titlebox ROIImpathtitle 0;",applyAbleState=0)
	// List box for displaying existing ROIs
	ListBox ROIListBox win=twoP_Controls,pos={214.00,439.00},size={125.00,100.00},proc=NQ_ROIListBoxProc
	ListBox ROIListBox win=twoP_Controls,fSize=12,listWave=root:packages:twoP:examine:ROIListWave
	ListBox ROIListBox win=twoP_Controls,selWave=root:packages:twoP:examine:ROIListSelWave,mode=4
	ListBox ROIListBox win=twoP_Controls, disable = able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "ROI","ListBox ROIListBox 0;",applyAbleState=0)
	// making a new ROI
	Button RoiNewbutton win=twoP_Controls,pos={8.00,439.00},size={64.00,20.00},proc=NQ_NewRoiButtonProc
	Button RoiNewbutton win=twoP_Controls,title="New ROI"
	Button RoiNewbutton win=twoP_Controls, disable = able
	SetVariable RoiNameSetVar win=twoP_Controls,pos={80.00,439.00},size={88.00,18.00},title="Name"
	SetVariable RoiNameSetVar win=twoP_Controls,fSize=12,value=root:packages:twoP:examine:NewRoiName
	SetVariable RoiNameSetVar win=twoP_Controls, disable = able
	PopupMenu ROIDrawPopup win=twoP_Controls,pos={8.00,466.00},size={89.00,20.00}
	PopupMenu ROIDrawPopup win=twoP_Controls,mode=1,popvalue="Freehand",value=#"\"Freehand;Vertices;Marquee\""
	PopupMenu ROIDrawPopup win=twoP_Controls, disable = able
	PopupMenu RoiColorPopup win=twoP_Controls,pos={101.00,466.00},size={83.00,20.00},title="Color"
	PopupMenu RoiColorPopup win=twoP_Controls,fSize=12
	PopupMenu RoiColorPopup win=twoP_Controls,mode=1,popColor=(65535,0,0),value=#"\"*COLORPOP*\""
	PopupMenu RoiColorPopup win=twoP_Controls, disable = able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "ROI", "Button RoiNewbutton;SetVariable RoiNameSetVar;PopupMenu ROIDrawPopup;PopupMenu RoiColorPopup",applyAbleState=0)
	// editing existing ROI
	Button ROINudgeButton win=twoP_Controls,pos={8.00,488.00},size={50.00,23.00},proc=NQ_RoiNudgeProc
	Button ROINudgeButton win=twoP_Controls,title="Nudge"
	Button ROINudgeButton win=twoP_Controls, disable = able
	PopupMenu ROIonWindowPopup win=twoP_Controls,pos={63.00,491.00},size={147.00,20.00},title="On"
	PopupMenu ROIonWindowPopup win=twoP_Controls,fSize=12
	PopupMenu ROIonWindowPopup win=twoP_Controls,mode=1,popvalue="twoPscanGraph",value=#"WinList(\"*\", \";\", \"WIN:1\" )"
	PopupMenu ROIonWindowPopup win=twoP_Controls,disable=able
	Button ROIDuplButton win=twoP_Controls,pos={8.00,515.00},size={65.00,20.00},proc=NQ_ROIDuplicateButtonProc
	Button ROIDuplButton win=twoP_Controls,title="Duplicate",fSize=12
	Button ROIDuplButton win=twoP_Controls, disable = able
	Button RoiDelbutton win=twoP_Controls,pos={90.00,515.00},size={60.00,20.00},proc=NQ_DelRoiButtonProc
	Button RoiDelbutton win=twoP_Controls,title="Delete",fSize=12
	Button RoiDelbutton win=twoP_Controls, disable = able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "ROI", "Button ROINudgeButton;PopupMenu ROIonWindowPopup;Button ROIDuplButton;Button RoiDelbutton",applyAbleState=0)
	// Do the ROI with options
	Button ROIAvgButton win=twoP_Controls,pos={8.00,547.00},size={57.00,20.00},proc=NQ_ROIRunButtonProc
	Button ROIAvgButton win=twoP_Controls,title="ROI Avg"
	Button ROIAvgButton win=twoP_Controls, disable =able
	PopupMenu ROIchansPopup win=twoP_Controls,pos={69.00,547.00},size={47.00,20.00},proc=twoP_ROISelChan_PopMenuProc
	PopupMenu ROIchansPopup win=twoP_Controls,title="of",mode=0,value=#"twoP_listImChans()+\";ratio\""
	PopupMenu ROIchansPopup win=twoP_Controls, disable = able
	TitleBox ROIchansTitle win=twoP_Controls,pos={120.00,550.00},size={23.00,15.00},fSize=12,frame=0
	TitleBox ROIchansTitle win=twoP_Controls,variable=root:packages:twoP:examine:ROIselChan
	TitleBox ROIchansTitle win=twoP_Controls, disable = able
	PopupMenu ROIRatPopUp win=twoP_Controls,pos={166, 547.00},size={84.00,20.00},proc=NQ_ROIPopMenuProc
	PopupMenu ROIRatPopUp win=twoP_Controls,fSize=12
	PopupMenu ROIRatPopUp win=twoP_Controls,mode=1,popvalue="Ch1/Ch2",value=#"\"Ch1/Ch2;Ch2/Ch1\""
	PopupMenu ROIRatPopUp win=twoP_Controls, disable = able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "ROI", "Button ROIAvgButton;PopupMenu ROIchansPopup;TitleBox ROIchansTitle;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "ROI", "PopupMenu ROIRatPopUp;",applyAbleState=0)
	// deltaF/F and background options
	CheckBox ROIDeltaFCheck win=twoP_Controls,pos={14.00,572.00},size={133.00,16.00}
	CheckBox ROIDeltaFCheck win=twoP_Controls,title="ΔF/F    Baseline from",fSize=12,value=1
	CheckBox ROIDeltaFCheck win=twoP_Controls, disable = able
	SetVariable ROIbaseFirstSetvar win=twoP_Controls,pos={155.00,571.00},size={65.00,18.00},proc=GUIPSIsetVarProc
	SetVariable ROIbaseFirstSetvar win=twoP_Controls,title=" ",userdata=";0;INF;.001;",fSize=12
	SetVariable ROIbaseFirstSetvar win=twoP_Controls,format="%.1W1Ps"
	SetVariable ROIbaseFirstSetvar win=twoP_Controls,limits={-inf,inf,0.1},value=root:packages:twoP:examine:ROIBaseStart
	SetVariable ROIbaseFirstSetvar win=twoP_Controls, disable = able
	SetVariable ROIbaseLastSetvar win=twoP_Controls,pos={233.00,571.00},size={88.00,18.00},proc=GUIPSIsetVarProc
	SetVariable ROIbaseLastSetvar win=twoP_Controls,title="to",userdata=";0;INF;.001;",fSize=12
	SetVariable ROIbaseLastSetvar win=twoP_Controls,format="%.1W1Ps"
	SetVariable ROIbaseLastSetvar win=twoP_Controls,limits={-inf,inf,0.1},value=root:packages:twoP:examine:ROIBaseEnd
	SetVariable ROIbaseLastSetvar win=twoP_Controls,disable = able
	CheckBox ROIBackGrdCheck win=twoP_Controls,pos={14.00,593.00},size={113.00,16.00}
	CheckBox ROIBackGrdCheck win=twoP_Controls,title="Subtract BkGrnd",fSize=12,value=1
	CheckBox ROIBackGrdCheck win=twoP_Controls, disable = able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "ROI", "CheckBox ROIDeltaFCheck;SetVariable ROIbaseFirstSetvar;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "ROI", "SetVariable ROIbaseLastSetvar;CheckBox ROIBackGrdCheck;",applyAbleState=0)
	// Seecting multiple scans
	CheckBox ROICurScanCheck win=twoP_Controls,pos={14.00,615.00},size={92.00,15.00},proc=GUIPControls#GUIPRadioButtonProc
	CheckBox ROICurScanCheck win=twoP_Controls,title="Current Scan"
	CheckBox ROICurScanCheck win=twoP_Controls,userdata="ROICurScanCheck;ROInameMatchCheck;ROInoteMatchCheck"
	CheckBox ROICurScanCheck win=twoP_Controls,userdata (gValue) = "root:packages:twoP:examine:ROIscanSelMode"
	CheckBox ROICurScanCheck win=twoP_Controls,fSize=12,value=1,mode=1
	CheckBox ROICurScanCheck win=twoP_Controls,disable = able
	// ROInameMatchCheck
	CheckBox ROInameMatchCheck win=twoP_Controls,pos={113.00,617.00},size={105.00,15.00},proc=GUIPControls#GUIPRadioButtonProc
	CheckBox ROInameMatchCheck win=twoP_Controls,title="Name Matching"
	CheckBox ROInameMatchCheck win=twoP_Controls,userdata="ROICurScanCheck;ROInameMatchCheck;ROInoteMatchCheck"
	CheckBox ROInameMatchCheck win=twoP_Controls,userdata (gValue) = "root:packages:twoP:examine:ROIscanSelMode"
	CheckBox ROInameMatchCheck win=twoP_Controls,fSize=12,value=0,mode=1
	CheckBox ROInameMatchCheck win=twoP_Controls,disable =able
	// ROInoteMatchCheck
	CheckBox ROInoteMatchCheck win=twoP_Controls,pos={14.00,635.00},size={124.00,15.00},proc=GUIPControls#GUIPRadioButtonProc
	CheckBox ROInoteMatchCheck win=twoP_Controls,title="Exp Note Matching"
	CheckBox ROInoteMatchCheck win=twoP_Controls,userdata="ROICurScanCheck;ROInameMatchCheck;ROInoteMatchCheck"
	CheckBox ROInoteMatchCheck win=twoP_Controls,userdata(gValue) = "root:packages:twoP:examine:ROIscanSelMode"
	CheckBox ROInoteMatchCheck win=twoP_Controls,fSize=12,value=0,mode=1
	CheckBox ROInoteMatchCheck win=twoP_Controls, disable =able
	// ROIKeySetVar
	SetVariable ROIKeySetVar win=twoP_Controls,pos={89.00,638.00},size={84.00,18.00},title=" Key"
	SetVariable ROIKeySetVar win=twoP_Controls,help={"Selects scans with this key in key=value;pairs in exp note."}
	SetVariable ROIKeySetVar win=twoP_Controls,fSize=12
	SetVariable ROIKeySetVar win=twoP_Controls,value=root:packages:twoP:examine:ROInoteKeyStr
	SetVariable ROIKeySetVar win=twoP_Controls, disable =able
	// ROInoteValsSetVar
	SetVariable ROInoteValsSetVar win=twoP_Controls,pos={179.00,638.00},size={133.00,18.00}
	SetVariable ROInoteValsSetVar win=twoP_Controls,title="Values",fSize=12
	SetVariable ROInoteValsSetVar win=twoP_Controls,help={"Selects scans with these values in key=value;pairs in exp note."}
	SetVariable ROInoteValsSetVar win=twoP_Controls,value=root:packages:twoP:examine:ROInoteValueStr
	SetVariable ROInoteValsSetVar win=twoP_Controls, disable =able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "ROI", "CheckBox ROICurScanCheck;CheckBox ROInameMatchCheck;CheckBox ROInoteMatchCheck;")
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "ROI", "SetVariable ROInameMatchSetVar;SetVariable ROIKeySetVar;SetVariable ROInoteValsSetVar;")
end


function NQexROI_Update()
	NQ_ListRois ()
end



Function twoP_ROISelChan_PopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			SVAR selChan = root:packages:twoP:examine:ROIselChan
			selChan = pa.popStr
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


//******************************************************************************************************
// Graph marquee function to make a square ROI from the graph marquee coordinates and make an ROI avg from the current scan.
// Last modified Sep 02 2010 by Jamie Boyd
Function twoP_DoRoi()
	
	// Get dark values if shift key is held down
	variable getDark = ((getkeystate(0) & 4) == 4)
	// for linescans, command/ctrl key for boxCar averaging
	variable doBCavg = ((getKeyState (0) & 1) == 1)
	// check for ScanGraph (also sets coordinates to pixel values used for Igor5
	GetMarquee
	if (cmpStr (stringfromlist (0, S_marqueeWin, "#"), "twoPScanGraph") != 0)
		doalert 0, "This function only works with the current scan displayed on twoPhoton Scan Graph."
		return 1
	endif
	// Get current scan; check scan Mode
	SVAR curscan = root:Packages:twoP:examine:CurScan
	if (cmpStr (CurScan, "LiveWave") == 0)
		doalert 0, "This function only works with a time series, a Z- series,  or a Line Scan."
		return 1
	endif
	SVAR ScanNote = $"root:twoP_Scans:" + curscan  + ":" + curScan +  "_info"
	variable scanMode = numberByKey ("Mode", scanNote, ":", "\r")
	if (!(((scanMode == kLineScan) || (scanMode == kTimeSeries)) || (scanMode == kZseries)))
		doalert 0, "This function only works with a time series, a Z- series,  or a Line Scan."
		return 1
	endif
	// which channel, i.e., which subWindow was marquee drawn on
	string chStr
	GetMarquee/K left,bottom
	chStr = "_" + (stringfromlist (1, S_marqueeWin, "#")) [1,3] //^^^
	// if a linescan, check for box car averaging
	variable BCwidth
	if ((scanMode == kLineScan) && (doBCavg))
		BCwidth = round ((V_Top - V_Bottom)/ numberbykey ("LineTime", scanNote, ":", "\r"))
		if (mod (BCWIdth,2) ==0)
			BCWidth += 1
		endif
	else
		BCWidth =0
	endif
	// getDark vlues will be NaN if not doing dark subtraction
	variable darkL =Nan, darkT =Nan, darkR =NaN, darkB =Nan
	if (getDark)
		darkL = numberbykey ("DarkL", scanNote, ":", "\r")
		darkT = numberbykey ("DarkT", scanNote, ":", "\r")
		darkR = numberbykey ("DarkR", scanNote, ":", "\r")
		darkB = numberbykey ("DarkB", scanNote, ":", "\r")
		if (scanMode == kLineScan)
			if ((numtype (DarkL) ==2) || (numtype (DarkR) ==2))
				NVAR/Z darkLG = root:packages:twoP:examine:darkL
				NVAR/Z darkRG = root:packages:twoP:examine:darkR
				if (!(((NVAR_Exists(darkLG)) && (NVAR_Exists(darkRG)))))
					doAlert 0, "No dark region has been set."
					return 1
				endif
				darkL = darkLG
				darkR = darkRG
				ScanNote = ReplaceNumberByKey("darkL", scanNote, darkL, ":", "\r")
				ScanNote = ReplaceNumberByKey("darkR", scanNote, darkR, ":", "\r")
			endif
		else
			if ((((numtype (DarkL) ==2) || (numtype (DarkT) ==2)) || (numtype (DarkR) ==2))|| (numtype (DarkB) ==2))
				NVAR/Z darkLG = root:packages:twoP:examine:darkL
				NVAR/Z darkTG = root:packages:twoP:examine:darkT
				NVAR/Z darkRG = root:packages:twoP:examine:darkR
				NVAR/Z darkBG = root:packages:twoP:examine:darkB
				if (!((((NVAR_Exists(darkLG)) && (NVAR_Exists(darkTG))) && (NVAR_Exists(darkRG))) && (NVAR_Exists(darkBG))))
					doAlert 0, "No dark region has been set."
					return 1
				endif
				darkL = darkLG
				darkT = darkTG
				darkR = darkRG
				darkB = darkBG
				ScanNote = ReplaceNumberByKey("darkL", scanNote, darkL, ":", "\r")
				ScanNote = ReplaceNumberByKey("darkT", scanNote, darkT, ":", "\r")
				ScanNote = ReplaceNumberByKey("darkR", scanNote, darkR, ":", "\r")
				ScanNote = ReplaceNumberByKey("darkB", scanNote, darkB, ":", "\r")
			endif
		endif
	endif
	// reference channel waves
	if (cmpStr (chStr, "_mrg") == 0)
		NVAR topChan = root:packages:twoP:examine:doDROITopChan
		if (topChan == 1)
			Wave topWave = $"root:twoP_Scans:" + curScan + ":" + curScan+ "_ch1"
			Wave bottomWave = $"root:twoP_Scans:" + curScan + ":" + curScan+ "_ch2"
		else
			Wave topWave = $"root:twoP_Scans:" + curScan + ":" + curScan+ "_ch2"
			Wave bottomWave = $"root:twoP_Scans:" + curScan + ":" + curScan+ "_ch1"
		endif
	else
		WAVE chWave = $"root:twoP_Scans:" + curScan + ":" + curScan+chStr
	endif
	//Find the first free name for the ROI and make the ROI wave
	if (!(dataFolderExists ("root:twoP_ROIs")))
		newdatafolder root:twoP_ROIs
	endif
	variable ii
	For (ii=0; WaveExists($"root:twoP_ROIs:"  + curScan +  "_R" + num2str (ii) + "_y") == 1; ii += 1)
	Endfor
	variable ROINum = ii
	String ROIBaseName =  "root:twoP_ROIs:"  + curScan + "_R" + num2str (ROINum)
	variable red, green, blue
	variable NumFrames
	NQ_RGBSetter (ROINum, red, green, blue)	// automatically sets color for the ROI based on ROI number
	make/n= 5 $ ROIBaseName + "_x", $ROIBaseName + "_y"
	WAVE RoiXWave = $ROIBaseName + "_x"
	WAVE RoiYWave = $ROIBaseName + "_y"
	if (scanMode == kLineScan)
		numFrames =  numberbykey ("PixHeight", ScanNote, ":", "\r")
		Note RoiXWave, "WaveType:ROIlinescan;" + "Red:" + num2str (red) + ";Green:" + num2str (green) + ";Blue:" + num2str (blue) + ";"
		variable bottomMost = numberbykey ("yPos", scanNote, ":", "\r")
		variable TopMost = BottomMost + (numberbykey ("PixHeight", scanNote, ":", "\r")-2) * numberbykey ("LineTime", scanNote, ":", "\r")
		ROIxWave [0,1] = V_left
		ROIxWave [2] = Nan
		ROIxWave [3,4] = V_right
		ROIyWave [0] = bottomMost
		ROIyWave [1] = topMost
		ROIyWave [2] = Nan
		ROIYWave [3] = bottomMost
		ROIyWave [4] = topMost
	else
		NumFrames = numberbykey ("NumFrames", ScanNote, ":", "\r")
		Note RoiXWave, "WaveType:ROIsquare;" + "Red:" + num2str (red) + ";Green:" + num2str (green) + ";Blue:" + num2str (blue) + ";"
		ROIxWave [0,1] = V_left
		ROIxWave [2,3] = V_right
		ROIxWave [4] = V_Left
		ROIyWave [0] = v_bottom
		ROIyWave [1,2] = V_Top
		ROIYWave [3,4] = V_Bottom
	endif
	// add ROI to list of ROIS 
	WAVE/t RoiListWave = root:Packages:twoP:examine:RoiListWave
	WAVE RoiListSelWave = root:Packages:twoP:examine:RoiListSelWave
	insertpoints (numpnts (ROIListWave)), 1, RoiListWave, RoiListSelWave
	RoiListWave [numpnts (ROIListWave) -1] = curScan + "_R" + num2str (ROINum)
	//Find the first free name for the ROIavg and make the ROIavg wave
	string ROIAvgBaseName
	if (cmpStr (chStr, "_mrg") ==0)
		ROIAvgBaseName = "root:twoP_Scans:" + curScan + ":" + curScan + "_R" + num2str (ROINum) + "_ratio"
	else
		ROIAvgBaseName = "root:twoP_Scans:" + curScan + ":" +curScan +  "_R" + num2str (ROINum) + chStr + "avg"
	endif
	if (waveExists ($ROIAvgBaseName))
		For (ii =1; WaveExists($ROIAvgBaseName + num2str (ii)) == 1; ii += 1)
		endfor
		make/o/n= (NumFrames)$ROIAvgBaseName + num2str (ii)
		WAVE Roiavg = $ROIAvgBaseName + num2str (ii)
	else
		make/o/n= (NumFrames)$ROIAvgBaseName
		WAVE Roiavg = $ROIAvgBaseName
	endif
	if (scanMode == kTimeSeries)
		setscale/P x 0,(numberbykey ("FrameTime",ScanNote, ":", "\r")),"s", RoiAvg
	elseif (scanMode == kLineScan)
		setscale/P x 0,(numberbykey ("LineTime",ScanNote, ":", "\r")),"s", RoiAvg
	elseif (scanMode == kZseries)
		setscale/P x (numberbykey ("ZPos",ScanNote, ":", "\r")),(numberbykey ("ZstepSize",ScanNote, ":", "\r")),"m", RoiAvg
	endif
	note RoiAvg, "ImWave:" + CurScan + ";ROI:" +stringfromlist (2, ROIBaseName, ":") + ";Red:" + num2str (red) + ";Green:" + num2str (green) + ";Blue:" + num2str (blue) + ";deltafed:0;"
	// do the ROI  2^3=8 different ways: Line Scan vs 3D wave, with Dark Subtraction or not, ROI avg vs ROI ratio
	//variable topAvg, darkAvg, darkAvgTop, darkAvgBottom
	if (scanMode == kLineScan)
		if (cmpStr (chStr, "_mrg") == 0)
			NQ_doSquareROIRatio (topWave, bottomWave,  curScan + "_R" + num2str (ROINum), ROIavg, darkL, darkR, darkT, darkB)
		else
			NQ_doLineScanROIavg (chWave,  curScan + "_R" + num2str (ROINum), ROIavg, darkL, darkR)
		endif
		// boxCar averaging?
		if (BCwidth > 0)
			Smooth/B (BCwidth), RoiAvg
		endif
	else // a 3D scan
		if (cmpStr (chStr, "_mrg") == 0)
			NQ_doSquareROIRatio (topWave, bottomWave, curScan + "_R" + num2str (ROINum), ROIavg, darkL, darkR, darkT, darkB)
		else
			NQ_doSquareROIavg (chWave, curScan + "_R" + num2str (ROINum), ROIavg, darkL, darkR, darkT, darkB)
		endif
	endif
	// apend ROIs and roiAvg to ScanGraph and TracesGraph
	NQ_AppendROIandAvg (ROIavg, curScan + "_R" + num2str (ROINum), 0)
	NQ_TracesGraphShareAxes (curScan)
end

//******************************************************************************************************
// Appends an ROI average to the Traces graph and the associated ROI to the ScanGraph 
// Last Modified Jul 26 2010 by Jamie Boyd
Function NQ_AppendROIandAvg (ROIavg, ROIStr, isDeltaFed)
	WAVE ROIavg
	string ROIStr
	variable isDeltaFed
	
	WAVE roiX = $"root:twoP_ROIs:" + ROIStr + "_x"
	WAVE roiY = $"root:twoP_ROIs:" + ROIStr + "_y"
	// Draw ROI on twoP ScanGraph, if not there already
	variable red = NumberByKey("Red", note (roiX), ":", ";")
	variable green = NumberByKey("Green", note (roiX), ":", ";")
	variable blue = NumberByKey("Blue", note (roiX), ":", ";")
	SVAR curScan = root:packages:twoP:examine:curScan
	doWIndow/F twoPScanGraph
	if (V_Flag == 0)
		twoP_ImGraphNew (curScan)
	else
		string childrenList = RemoveFromList ("controlPanel", childWindowList ("twoPScanGraph")), graphNameStr, traceList
		variable ic, nChildren =  itemsinlist (childrenList, ";")
		for (ic =0; iC < nChildren; iC += 1)
			graphNameStr = "twoPScanGraph#" + stringfromlist (ic, childrenList, ";")
			traceList = TraceNameList(graphNameStr, ";", 1 )
			if (WhichListItem(ROIStr + "_y", traceList , ";") == -1)
				appendtograph/W=$graphNameStr/C = (red,green,blue)RoiY vs RoiX
			endif
		endfor
	endif
	// Draw ROI average on the traces graph
	Dowindow/F twoP_tracesGraph
	if (V_Flag == 0)	// window didn't exist
		NQ_NewTracesGraph (curScan)
	else
		traceList = TraceNameList("twoP_TracesGraph", ";", 1 )
		if (WhichListItem(nameOfwave (roiAvg), traceList , ";") == -1)
			if (isDeltaFed)
				appendtograph /W=twoP_TracesGraph/C=(red, green, blue)/R=ROIRAxis/B=Bottom  ROIavg
			else
				appendtograph /W=twoP_TracesGraph/C=(red, green, blue)/L=ROILAxis/B=Bottom  ROIavg
			endif
		endif
	endif
end


//******************************************************************************************************
// Updates the list box of ROIs in the twoP_ROIS folder
// Last Modified Jul 16 2010 by Jamie Boyd
Function NQ_ListRois ()
	
	WAVE/T ROIListWave = root:Packages:twoP:examine:ROIListWave
	WAVE ROIListSelWave = root:Packages:twoP:examine:ROIListSelWave
	string roiList = GUIPListObjs ("root:twoP_ROIs", 1, "*_x", 0,"")
	variable ir, nRs = itemsinlist (roiList, ";")
	redimension/n = (nRs) ROIListWave, ROIListSelWave
	for (ir =0; ir < nRs;ir += 1)
		ROIListWave [ir] = RemoveEnding(stringfromlist (ir, roiList, ";"), "_x" )
	endfor
end


//******************************************************************************************************
// sets ratio top channel for ROI analysis
// Last Modified Jul 16 2010 b y Jamie Boyd
Function NQ_ROIPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			NVAR TopChan = root:packages:twoP:examine:ROITopChan
			TopChan =  pa.popNum
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Deletes selected ROIs in ROI list box
// Last Modified Seo 02 2010 b y Jamie Boyd
Function NQ_DelRoiButtonProc (ba) : ButtonControl
	STRUCT WMbuttonAction &ba		
		
	switch( ba.eventCode )
		case 2: // mouse up
			WAVE/t RoiListWave = root:Packages:twoP:examine:RoiListWave
			WAVE RoiListSelWave = root:Packages:twoP:examine:RoiListSelWave
			variable ii = 0, numRois =dimSize (RoiListWave, 0)
			for (ii = 0 ;ii < numRois;ii += 1)
				if (RoiListSelWave [ii] == 0)
					continue
				endif
				wave/z oldRoiX = $"root:twoP_ROIs:" + RoiListWave [ii] + "_x"
				wave/z oldRoiY = $"root:twoP_ROIs:" + RoiListWave [ii] + "_y"
				if (!((waveExists (oldROIX)) && (waveExists (oldROIY))))
					print  "The selected ROI to be deleted, \"" +  RoiListWave [ii] + "\", no longer exists."
					continue
				endif
				GUIPKillDisplayedWave (oldRoiX)
				GUIPKillDisplayedWave (oldRoiY)
				deletePoints ii,1, RoiListWave, RoiListSelWave
				numRois -=1
			endfor
			break
	endSwitch
End

//******************************************************************************************************
// Makes a new polygonal freehand or vertex-clicked or rectangular from marquee ROI
// Last Modified Jul 16 2010 by Jamie Boyd
Function NQ_NewRoiButtonProc(ba) : ButtonControl
	STRUCT WMbuttonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			// Read variables from globals and  controls
			// ROI name
			SVAR roiName = root:packages:twoP:examine:newROIName
			roiName = cleanUpName (roiName, 0)
			// RGB color variables
			controlinfo/w=twoP_Controls RoiColorPopup
			variable Rcolor = V_Red, GColor = V_Green,  BColor =  V_Blue
			// window to draw on/get Marquee from
			controlinfo/w=twoP_Controls ROIonWindowPopup
			string onWindow = S_Value
			doWindow/F $S_Value
			if (!(V_Flag))
				doalert 0, "The selected graph no longer exists."
				return 1
			endif
			doUpdate
			// draw method
			controlinfo/w=twoP_Controls ROIDrawPopup
			variable drawMethod = V_Value //1=Freehand;2=Vertices;3=Marquee"
			// subwin for twoPScanGraph
			if ((cmpStr (onWindow, "twoPScanGraph") ==0) && (drawMethod != 3))
				SVAR ROIChan = root:packages:twoP:examine:roiSelChan
				onWindow = "G" + ROIChan
				// if selected channel is not displayed, just use first subwindow
				if (WhichListItem(OnWindow, childWindowList ("twoPScanGraph"),  ";")  == -1)
					OnWindow = "twoPScanGraph#" + stringFromList (0, childWindowList ("twoPScanGraph"))
				else
					OnWindow = "twoPScanGraph#" + onWindow
				endif
			endif
			if (drawMethod == 3) // check for Marquee
				if (cmpStr (onWindow, "twoPScanGraph") ==0) // check subwins for twoPScanGraph
					getmarquee
					// which channel, i.e., which subWindow was marquee drawn on
					onWindow = S_marqueeWin
				endif
				// Get Marquee coordinates
				getmarquee/K left,bottom
				if (V_Flag ==0)
					doalert 0, "A marquee is not currently present on the selected graph."
					return 1
				endif
				variable left = V_left
				variable top = V_top
				variable right = V_right
				variable bottom = V_bottom
			endif
			// make the ROI waves
			string savedFOlder = getDataFolder (1)
			setDataFolder root:twoP_ROIs
			variable nPnts =0
			string roiType = "ROIPoly"
			if (drawMethod == 3)
				nPnts =5
				roiType = "ROIsquare"
			endif
			if (waveExists ($roiName + "_y"))
				doAlert 1, "An ROI with the name \"" + roiName + "\" already exists. OverWrite it?"
				if (V_Flag ==2) // no
					return 1
				endif
			endif
			make/o/n=(nPnts) $(roiName + "_y"), $(roiName +"_x")
			WAVE roiY = $(roiName + "_y")
			WAVE roiX = $(roiName + "_x")
			// append the ROI waves to the graph
			appendtograph /W=$onWindow/C=(Rcolor, GColor, BColor) roiY vs roiX
			// Use graph wave draw to let user draw the ROI. There are 2 modes; freehand and click each vertex
			if (drawMethod == 3)
				ROIx[0,1] = left
				ROIx[2,3] = right
				ROIx [4] = Left
				ROIy [0] = bottom
				ROIy [1,2] = Top
				ROIY [3,4] = Bottom
			elseif (drawMethod == 1)
				graphwavedraw/W=$onWindow/F=3/O/L/B $(roiName + "_y"), $(roiName + "_x")
			else
				graphwavedraw/W=$onWindow/O/L/B $(roiName + "_y"), $(roiName + "_x")
			endif
			// edit the wavenote for the X-wave
			Note roiX, "WaveType:" + roiType + ";Red:" + num2str (Rcolor) + ";green:" + num2str (GColor) + ";Blue:" + num2str (BColor) + ";"
			// Change title and procedure of new button
			if (drawMethod != 3)
				Button RoiNewbutton win=twoP_Controls, title = "Done", proc = NQ_DoneNewRoiButtonProc, fColor=(65535,0,0)
			endif
			// Add ROI to the ROI list wave
			//  if it already exits, but don't add the name to the list of ROI's
			WAVE/T ROIListWave = root:Packages:twoP:examine:ROIListWave
			WAVE ROIListSelWave = root:Packages:twoP:examine:ROIListSelWave
			variable ii, nP = (numpnts (RoiListWave))
			for (ii = 0; ((ii < nP)  && (cmpstr (RoiName, ROIListWave [ii]) != 0)); ii += 1)
			endfor
			if (ii == nP)
				InsertPoints nP, 1, RoiListWave, RoiListSelWave
				RoiListWave [nP] = roiName
			endif
			// reset data folder to saved folder
			SetDataFOlder $savedFolder
			break
	endSwitch
end

//******************************************************************************************************
// Resets button and graph  after making a new polygonal freehand or vertex-clicked  ROI
// Last Modified Jul 16 2010 by Jamie Boyd
Function NQ_DoneNewRoiButtonProc(ba) : ButtonControl
	STRUCT WMbuttonAction &ba		
		
	switch( ba.eventCode )
		case 2: // mouse up
			controlinfo/w=twoP_Controls ROIonWindowPopup
			GraphNormal /W=$S_value
			Button RoiNewbutton win=twoP_Controls, title = "New", proc = NQ_NewRoiButtonProc, fColor=(0,0,0)
			break
	endSwitch
end

//******************************************************************************************************
// Lets user choose a folder and saves the path to the folder for subsequent loading and saving of ROIs
// Last Modified Jul 16 2010 by Jamie Boyd
Function NQ_ROIsetPathProc (ba) : ButtonControl
	STRUCT WMbuttonAction &ba		
		
	switch( ba.eventCode )
		case 2: // mouse up
			NewPath/O/M = "Set Folder for loading and saving ROIs."  ROIPath
			if (!(V_Flag))
				SVAR expPathStr = root:packages:twoP:examine:ROIimPath
				PathInfo ROIPath
				expPathStr = S_Path
			endif
			break
	endSwitch
end

//******************************************************************************************************
// Saves selected ROIs as a single text file
// Last Modified Jul 16 2010 by Jamie Boyd
Function NQ_ROISaveProc(ba) : ButtonControl
	STRUCT WMbuttonAction &ba		
		
	switch( ba.eventCode )
		case 2: // mouse up
			string dfldr = getdatafolder (1)
			setdatafolder $"root:twoP_ROIs"
			WAVE/T RoiListWave = root:packages:twoP:examine:RoiListWave
			WAVE RoiListSelWave = root:packages:twoP:examine:RoiListSelWave
			string SaveStr = ""
			variable ii, nP = (numpnts (RoiListWave))
			for (ii =0; ii < nP; ii += 1)
				if ((RoiListSelWave [ii] == 1))	
					savestr += RoiListWave [ii] + "_y;" + RoiListWave [ii] + "_x;"
				endif
			endfor
			string expName = CleanUpName (IgorINfo (1), 0)
			Save/B/T/P=ROIpath SaveStr as expName + "_Rois.itx"
			setdatafolder dfldr
			break
	endSwitch
End

//******************************************************************************************************
// Loads ROIs from an Igor text file on disk
// Last Modified Jul 16 2010 by Jamie Boyd
Function NQ_RoiLoadProc (ba) : ButtonControl
	STRUCT WMbuttonAction &ba		
		
	switch( ba.eventCode )
		case 2: // mouse up
			string dfldr = getdatafolder (1)
			setdatafolder $"root:twoP_ROIs:"
			LoadWave/T/P=ROIPath ""
			NQ_ListRois ()
			setdatafolder dfldr
			break
	endSwitch
End

//******************************************************************************************************
// Deletes selected ROIS when delete key is pressed
// Last Modified Jul 16 2010 by Jamie Boyd
Function NQ_ROIListBoxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 3: // double click
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
		case 12:
			if ((lba.row == 8) || (lba.row) == 127)// character code for delete key
				variable iP,  nP = numpnts ( lba.listWave)
				for (iP =nP-1; iP >= 0; iP-=1)
					if (lba.selWave [iP] == 1)
						WAVE xWave = $"root:twoP_ROIs:" + lba.listWave [ip] + "_x"
						WAVE yWave =$"root:twoP_ROIs:" + lba.listWave [ip] + "_y"
						GUIPKillDisplayedWave (xWave)
						GUIPKillDisplayedWave (yWave)
						DeletePoints iP, 1,  lba.listWave ,  lba.selWave
					endif
				endfor
			endif
			return 1
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Append selected ROIs to selected graph, and sets quickrag options
// Last Modified Jul 22 2010 by Jamie Boyd
Function NQ_RoiNudgeProc(ba) : ButtonControl
	STRUCT WMbuttonAction &ba		
		
	switch( ba.eventCode )
		case 2: // mouse up
			// If shift key was held down, then we are just plotting
			variable justPlot = ((ba.EventMod & 2) == 2)
			SVAR curScan = root:packages:twoP:examine:curScan
			if (cmpStr (curScan, "LiveWave") == 0)
				SVAR scanStr = root:packages:twoP:Acquire:LiveModeScanStr
			else
				SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
			endif
			// window to plot on
			SVAR ROIChan = root:packages:twoP:examine:roiSelChan
			string OnWindow = "G" + ROIChan
			// if selected channel is not displayed, just use first subwindow
			if (WhichListItem(OnWindow, childWindowList ("twoPScanGraph"),  ";")  == -1)
				OnWindow = "twoPScanGraph#" + stringFromList (0, childWindowList ("twoPScanGraph"))
			else
				OnWindow = "twoPScanGraph#" + onWindow
			endif
			doWindow/F twoPScanGraph
			if (!(V_Flag))
				doalert 0, "The selected graph no longer exists."
				return 1
			endif
			// get a list of traces already on the graph, so they are not added 2x
			string tracelist = tracenamelist (onWIndow, ";", 1)
			// find selected ROIs, append them (if not already appended) and set the "drag" option
			// also copy list of drag traces into a global string
			WAVE/T ROIListWave = root:Packages:twoP:examine:ROIListWave
			WAVE ROIListSelWave = root:Packages:twoP:examine:ROIListSelWave
			variable ii, numroi = numpnts (ROIListWave), red, green, blue
			string roiStr
			string/G root:packages:twoP:examine:ROInudgeList =""
			SVAR ROInudgeList = root:packages:twoP:examine:ROInudgeList 
			for (ii =0; ii < numRoi; ii += 1)
				if (ROIListSelWave [ii] == 0)
					continue
				endif
				roiStr = ROIListWave [ii]
				ROInudgeList += roiStr + ";"
				// display ROI if it is not already displayed
				if (WhichListItem(roiStr + "_y", tracelist, ";") == -1)
					WAVE roiXWave = $ "Root:twoP_ROIs:" + roiStr + "_x"
					WAVE roiYWave = $ "Root:twoP_ROIs:" + roiStr + "_y"
					if (!((WaveExists (roiXWave)) && (WaveExists (roiYWave))))
						continue
					endif
					red = numberbykey ("Red", note (roiXWave))
					green = numberbykey ("Green", note (roiXWave))
					blue = numberbykey ("Blue", note (roiXWave))
					appendtograph /W=$onWindow/C=(red, green, blue) RoiYWave vs RoiXwave
				endif
				// set quickDrag for selected rois
				if (!(justPlot))
					modifyGraph/W=$onWindow quickDrag ($roiStr + "_y")=1
					String/G root:packages:twoP:examine:NudgeOnWindow = onWindow
				endif
			endfor
			// if not just plotting, set nudge button to new title and new procedure
			if (!(justPlot))
				Button ROINudgeButton win=twoP_Controls, title = "Done", proc = NQ_RoiNudgeDoneButtonProc, fColor=(65535,0,0)
			endif
			break
	endSwitch
end

//******************************************************************************************************
// Translates trace offsets into X/Y offsets on the ROI and resets title and procedure for nudge button
// Last Modified Jul 22 2010 by Jamie Boyd
Function NQ_RoiNudgeDoneButtonProc(ba) : ButtonControl
	STRUCT WMbuttonAction &ba		
		
	switch( ba.eventCode )
		case 2: // mouse up
			Button ROINudgeButton, win=twoP_Controls, title = "Nudge", proc = NQ_RoiNudgeProc, fColor=(0,0,0)
			SVAR onWindow = root:packages:twoP:examine:nudgeOnWindow
			SVAR ROInudgeList = root:packages:twoP:examine:ROInudgeList 
			string AllTraces = TraceNameList(onWindow, ";", 1)
			string offsetInfo
			variable xoffset, yoffset
			variable ii, numtraces = itemsinlist (ROInudgeList, ";")
			string roiStr
			for (ii =0; ii < numTraces; ii += 1)
				roiStr = stringFromList (ii, ROInudgeList, ";")
				if (WhichListItem(roiStr+ "_y", AllTraces, ";") == -1)
					continue
				endif
				offsetInfo =  stringbykey ("offset(x)",  TraceInfo(OnWindow, roiStr+ "_y", 0 ), "=", ";")
				offsetinfo = offsetinfo [1, strlen (offsetinfo) -2]
				xoffset = str2num (stringfromlist (0, offsetinfo, ","))
				yoffset = str2num (stringfromlist (1, offsetinfo, ","))
				WAVE xwave =  $"root:twoP_ROIs:" + roiStr+ "_x"
				xwave += xOffset
				// Y offset for a line scan has no meaning
				if (cmpStr ("ROIlinescan", StringByKey("WaveType", note (xWave), ":", ";")) != 0)
					WAVE ywave = $"root:twoP_ROIs:" + roiStr+ "_y"
					yWave += yoffset
				endif
				ModifyGraph/W=$onWindow  offset ($ roiStr+ "_y")={0,0}, quickDrag ($ roiStr+ "_y")=0
			endfor
			break
	endSwitch
end

//********************************************************************************************
// Duplicates  the first ROI selected in the ROI list box, giving it the new ROI name from the setvar
// Last Modified Jul 26 2010 by Jamie Boyd
Function NQ_ROIDuplicateButtonProc(ba) : ButtonControl
	STRUCT WMbuttonAction &ba		
		
	switch( ba.eventCode )
		case 2: // mouse up
			SVAR newROIName = root:packages:twoP:examine:newROIname
			wave/z newRoiX = $"root:twoP_ROIs:" + newROIname + "_x"
			wave/z newRoiY = $"root:twoP_ROIs:" + newROIname + "_y"
			if ((waveExists (newROIX)) || (waveExists (newROIY)))
				doAlert 0, "An ROI with the name \"" + newROIName + "\" already exists."
				return 1
			endif
			
			WAVE/t RoiListWave = root:Packages:twoP:examine:RoiListWave
			WAVE RoiListSelWave = root:Packages:twoP:examine:RoiListSelWave
			variable ii = 0, numRois =dimSize (RoiListWave, 0)
			for (ii = 0 ;ii < numRois;ii += 1)
				if (RoiListSelWave [ii] == 0)
					continue
				endif
				wave/z oldRoiX = $"root:twoP_ROIs:" + RoiListWave [ii] + "_x"
				wave/z oldRoiY = $"root:twoP_ROIs:" + RoiListWave [ii] + "_y"
				controlinfo/w=twoP_Controls RoiColorPopup
				variable red = V_Red, green = V_Green,  blue =  V_Blue 
				string temp = note (oldRoiX)
				temp = ReplaceNumberByKey("Red", temp, red, ":", ";") 
				temp = ReplaceNumberByKey("Green", temp, green, ":", ";") 
				temp = ReplaceNumberByKey("Blue", temp, blue, ":", ";") 
				if (!((waveExists (oldROIX)) && (waveExists (oldROIY))))
					doAlert 0, "The selected ROI to be duplicated no longer exists."
					return 1
				endif
				duplicate/o oldRoiX, $"root:twoP_ROIs:" + newROIname + "_x"
				duplicate/o oldRoiY, $"root:twoP_ROIs:" + newROIname + "_y"
				WAVE newROIx = $"root:twoP_ROIs:" + newROIname + "_x"
				note/K newROIx
				note newROIx temp
				insertpoints (numpnts (ROIListWave)), 1, RoiListWave, RoiListSelWave
				RoiListWave [numpnts (ROIListWave) -1] = newROIName
				return 0
			endfor
			break
	endSwitch
End

//******************************************************************************************************
// does an ROI avg of each selected ROI on the current scan
// Last Modified 2025/08/05 by Jamie Boyd
Function NQ_ROIRunButtonProc (ba) : ButtonControl
	STRUCT WMbuttonAction &ba		
		
	switch( ba.eventCode )
		case 2: // mouse up
			// get current scan and info string
			string doroiList
			SVAR curScan = root:packages:twoP:examine:curScan
			SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
			NVAR ROIscanSelMode =root:packages:twoP:examine:ROIscanSelMode
			if (ROIscanSelMode == 0) // doing a single scan
				doroiList = curScan + ";"
			elseif (ROIscanSelMode == 1) // chosen by scan name wildcard matching
				SVAR roiMatchStr = root:packages:twoP:examine:ROIScanMatchStr
				doroiList  = GUIPListObjs("root:twoP_Scans", 4, roiMatchStr, 0, "") 
			elseif (ROIscanSelMode == 2) // chosen by waveNote key value pairs
				SVAR key = root:packages:twoP:examine:ROInoteKeyStr
				SVAR ValueList = root:packages:twoP:examine:ROInoteValueStr
				doroiList = ROI_ListScansByNoteKeys (Key, ValueList)
			endif
			variable iScan, nScans = itemsinList (doroiList)
			string aScan
			for (iScan =0; iScan < nScans; iScan +=1)
				aScan = stringFromList (iScan, doroiList, ";")
				NQ_DoRoiFromList (aScan)
			endfor
			break
	endSwitch
end


Function/S ROI_ListScansByNoteKeys (Key, ValueList)
	string Key
	string ValueList
	
	string matchList
	string scanList = GUIPListObjs("root:twoP_Scans", 4, "*", 0, "") 
	variable iScan, nScans = itemsInList(scanList)
	string aScan, expNote, keyVal
	for (iScan =0; iScan < nScans; iScan +=1)
		aScan = StringFromList(iScan, scanList)
		SVAR/Z infoStr = $"root:twoP_Scans:" + aScan + ":" + aScan + "_info"
		expNote = StringByKey("ExpNote", infoStr, ":", "\r")
		keyVal = StringByKey (Key, expNote, "=", ";")
		if (WhichListItem(KeyVal, ValueList, ";", 0,0) >= 0)
			matchList += aScan
		endif
	endfor
	return matchList
end



Function NQ_DoRoiFromList (curScan)
	string curScan
			
	SVAR ScanNote = $"root:twoP_Scans:" + curscan  + ":" + curScan +  "_info"
	variable scanMode = numberByKey ("Mode", scanNote, ":", "\r")
	if (!(((scanMode == kLineScan) || (scanMode == kTimeSeries)) || (scanMode == kZseries)))
		//doalert 0, "This function only works with a time series, a Z- series,  or a Line Scan."
		return 1
	endif
	// read some variables
	controlinfo/W=twoP_Controls ROIBackGrdCheck
	variable getDark = V_Value
	variable darkL =Nan, darkT =Nan, darkR =NaN, darkB =Nan
	if (getDark)
		darkL = numberbykey ("DarkL", scanNote, ":", "\r")
		darkT = numberbykey ("DarkT", scanNote, ":", "\r")
		darkR = numberbykey ("DarkR", scanNote, ":", "\r")
		darkB = numberbykey ("DarkB", scanNote, ":", "\r")
		if (scanMode == kLineScan)
			if ((numtype (DarkL) ==2) || (numtype (DarkR) ==2))
				NVAR/Z darkLG = root:packages:twoP:examine:darkL
				NVAR/Z darkRG = root:packages:twoP:examine:darkR
				if (!(((NVAR_Exists(darkLG)) && (NVAR_Exists(darkRG)))))
					doAlert 0, "No dark region has been set."
					return 1
				endif
				darkL = darkLG
				darkR = darkRG
				ScanNote = ReplaceNumberByKey("darkL", scanNote, darkL, ":", "\r")
				ScanNote = ReplaceNumberByKey("darkR", scanNote, darkR, ":", "\r")
			endif
		else
			if ((((numtype (DarkL) ==2) || (numtype (DarkT) ==2)) || (numtype (DarkR) ==2))|| (numtype (DarkB) ==2))
				NVAR/Z darkLG = root:packages:twoP:examine:darkL
				NVAR/Z darkTG = root:packages:twoP:examine:darkT
				NVAR/Z darkRG = root:packages:twoP:examine:darkR
				NVAR/Z darkBG = root:packages:twoP:examine:darkB
				if (!((((NVAR_Exists(darkLG)) && (NVAR_Exists(darkTG))) && (NVAR_Exists(darkRG))) && (NVAR_Exists(darkBG))))
					doAlert 0, "No dark region has been set."
					return 1
				endif
				darkL = darkLG
				darkT = darkTG
				darkR = darkRG
				darkB = darkBG
				ScanNote = ReplaceNumberByKey("darkL", scanNote, darkL, ":", "\r")
				ScanNote = ReplaceNumberByKey("darkT", scanNote, darkT, ":", "\r")
				ScanNote = ReplaceNumberByKey("darkR", scanNote, darkR, ":", "\r")
				ScanNote = ReplaceNumberByKey("darkB", scanNote, darkB, ":", "\r")
			endif
		endif
	endif	
	controlinfo/W=twoP_Controls ROIDeltaFCheck
	variable doDeltaF = V_Value
	if (doDeltaF)
		NVAR ROIbaseStart = root:packages:twoP:examine:ROIbaseStart
		NVAR ROIBaseEnd = root:packages:twoP:examine:ROIbaseEnd
	endif
	SVAR ROIchan = root:packages:twoP:examine:ROISelChan
	if (cmpStr (ROIChan, "ratio") == 0) // do ROI ratio
		NVAR TopChan =root:packages:twoP:examine:ROITopChan
		if (topChan == 1)
			Wave/z topWave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
			Wave/z bottomWave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
		else
			Wave/z topWave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch2"
			Wave/z bottomWave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_ch1"
		endif
		if (!(waveExists (topWave) && waveExists (bottomWave)))
			doAlert 0, "The selected scan \"" + curScan + "\" does not have both channels, so no ROI ratio for you."
			return 1
		endif
	else
		WAVE/z chWave = $"root:twoP_Scans:" + curScan + ":" + curScan+ "_" + ROIChan
		if (!(WaveExists (chWave)))
			doAlert 0, "The selected scan \"" + curScan + "\" does not have channel " + ROIChan + ", so no ROI avg for you."
			return 1
		endif
	endif
	variable numFrames
	if (scanMode == kLineScan)
		numFrames =  numberbykey ("PixHeight", ScanNote, ":", "\r")
	else
		numFrames = numberbykey ("NumFrames", ScanNote, ":", "\r")
	endif
	// look for selected ROIs
	WAVE/T ROIListWave = root:Packages:twoP:examine:ROIListWave
	WAVE ROIListSelWave = root:Packages:twoP:examine:ROIListSelWave
	variable ii, iROI, nRois = dimsize (ROIListWave, 0), red, green, blue
	string roiType
	for (iROI =0; iROI < nRois; iROI += 1)
		if (ROIListSelWave [iROI] == 0)
			continue
		endif
		WAVE roiX = $"root:twoP_ROIs:" + ROIListWave [iROI] + "_x"
		roiType = StringByKey("WaveType", note (roiX), ":", ";")
		if (scanMode == kLineScan)
			if (cmpStr (roiType, "ROIlinescan") != 0)
				print "The scan, \"" + curScan + "\", is a Line Scan, but the ROI, \"" + ROIListWave [iROI] + "\", is not a Line Scan ROI."
				continue
			endif
		elseif (cmpStr (roiType, "ROIlinescan") == 0)
			print "The scan, \"" + curScan + "\", is not a Line Scan, but the ROI, \"" + ROIListWave [iROI] + "\", is a Line Scan ROI."
			continue
		endif
		red = NumberByKey("Red", note (roix), ":", ";")
		green = NumberByKey("Green", note (roix), ":", ";")
		blue = NumberByKey("Blue", note (roix), ":", ";")
		string ROIAvgBaseName
		if (cmpStr (roiChan, "ratio") == 0)
			ROIAvgBaseName = "root:twoP_Scans:" + curScan + ":" + ROIListWave [iROI] + "_ratio"
		else
			ROIAvgBaseName  = "root:twoP_Scans:" + curScan + ":" + ROIListWave [iROI] + "_" + roiChan + "avg"
		endif
		if (waveExists ($ROIAvgBaseName))
			For (ii =1; WaveExists($ROIAvgBaseName + num2str (ii)) == 1; ii += 1)
			endfor
			make/o/n= (NumFrames)$ROIAvgBaseName + num2str (ii)
			WAVE Roiavg = $ROIAvgBaseName + num2str (ii)
		else
			make/o/n= (NumFrames)$ROIAvgBaseName
			WAVE Roiavg = $ROIAvgBaseName
		endif
		if (scanMode == kTimeSeries)
			setscale/P x 0,(numberbykey ("FrameTime",ScanNote, ":", "\r")),"s", RoiAvg
		elseif (scanMode == kLineScan)
			setscale/P x 0,(numberbykey ("LineTime",ScanNote, ":", "\r")),"s", RoiAvg
		elseif (scanMode == kZseries)
			setscale/P x (numberbykey ("ZPos",ScanNote, ":", "\r")),(numberbykey ("ZstepSize",ScanNote, ":", "\r")),"m", RoiAvg
		endif
		note RoiAvg, "ImWave:" + CurScan + ";ROI:" +ROIListWave [iROI] + ";Red:" + num2str (red) + ";Green:" + num2str (green) + ";Blue:" + num2str (blue) + ";deltafed:0;"
		// do the ROI
		if (scanMode == kLineScan)
			if (cmpStr (roiChan, "ratio") == 0)
				NQ_doSquareROIRatio (topWave, bottomWave, ROIListWave [iROI], ROIavg, darkL, darkR, darkT, darkB)
			else
				NQ_doLineScanROIavg (chWave, ROIListWave [iROI], ROIavg, darkL, darkR)
			endif
		else // a 3D scan
			if (cmpStr (roiType, "ROISquare") == 0)
				if (cmpStr (roiChan, "ratio") == 0)
					NQ_doSquareROIRatio (topWave, bottomWave, ROIListWave [iROI], ROIavg, darkL, darkR, darkT, darkB)
				else
					NQ_doSquareROIavg (chWave, ROIListWave [iROI], ROIavg, darkL, darkR, darkT, darkB)
				endif
			elseif (cmpStr (roiType, "ROIPoly") == 0)
				if (cmpStr (roiChan, "ratio") == 3)
					NQ_doPolyROIRatio (topWave, bottomWave, ROIListWave [iROI], ROIavg, darkL, darkR, darkT, darkB)
				else
					NQ_doPolyROIavg (chWave, ROIListWave [iROI], ROIavg, darkL, darkR, darkT, darkB)
				endif
			endif
		endif
		// Do delta F/F if requested and Append ROI and Avg to ScanGraph
		if (doDeltaF)
			variable baseline = mean(ROIavg,ROIbaseStart, ROIbaseEnd)
			ROIavg = (ROIavg - baseline)/baseline
			string tempstr = ReplaceNumberByKey("deltafed", note (ROIavg), 1 )
			tempstr = ReplaceStringByKey ( "baseline", tempstr, num2str(baseline))
			note/K ROIavg
			note ROIavg, tempstr
			NQ_AppendROIandAvg (ROIavg, ROIListWave [iROI], 1)
		else
			NQ_AppendROIandAvg (ROIavg, ROIListWave [iROI], 0)
		endif
	endfor
	NQ_TracesGraphShareAxes (curScan)
end

//******************************************************************************************************
// Processes a LineScan ROI avg, with optional dark subtraction
// Last Modified Jul 23 2010 by Jamie Boyd
function NQ_doLineScanROIavg (chWave, ROI, ROIavg, darkL, darkR)
	WAVE chWave
	string ROI
	wave ROIavg
	variable darkL, darkR
	
	WAVE roix = $"root:twoP_ROIs:" + ROI  + "_x"
	WAVE roiy = $"root:twoP_ROIs:" + ROI  + "_y"
	string scan = nameofWave (chWave) 
	scan = removeEnding (removeEnding (scan, "_ch1"), "_ch2")
	SVAR scanNote = $"root:twoP_Scans:" + scan + ":" + scan + "_info"
	
	variable startP = (roix [0] - numberbykey ("XPos", scanNote, ":", "\r"))/numberbykey ("XpixSize", scanNote, ":", "\r")
	variable endP = (roix [3] - numberbykey ("XPos", scanNote, ":", "\r"))/numberbykey ("XpixSize", scanNote, ":", "\r")
	variable ii, numLines = dimsize (chWave, 1)
	// look at each line in the lineScan
	for (ii=0; ii < numLines; ii += 1)
		imagetransform/G=(ii) getCol chwave
		WAVE W_ExtractedCol
		wavestats/Q/M=1/R=[startP, endP] W_ExtractedCol
		RoiAvg [ii] = V_avg
	endfor
	variable getDark = (!((numtype (darkL) ==2) || (numType (darkR) ==2)))
	if (getDark)  // calculate dark value
		imagestats/GS={darkL ,darkR, roiy [0] ,roiy [1]} chwave
		ROIAvg -= V_avg
	endif
end

//******************************************************************************************************
// Processes a LineScan ROI ratio, with optional dark subtraction
// Last Modified Jul 23 2010 by Jamie Boyd
function NQ_doLineScanROIRatio (topWave, bottomWave, ROI, ROIratio, darkL, darkR)
	WAVE topWave, bottomWave
	string ROI
	wave ROIratio
	variable darkL, darkR
	
	WAVE roix = $"root:twoP_ROIs:" + ROI  + "_x"
	WAVE roiy = $"root:twoP_ROIs:" + ROI  + "_y"
	string scan = nameofWave (topWave) 
	scan = removeEnding (removeEnding (scan, "_ch1"), "_ch2")
	SVAR scanNote = $"root:twoP_Scans:" + scan + ":" + scan + "_info"
	variable startP = (roix [0] - numberbykey ("XPos", scanNote, ":", "\r"))/numberbykey ("XpixSize", scanNote, ":", "\r")
	variable endP = (roix [3] - numberbykey ("XPos", scanNote, ":", "\r"))/numberbykey ("XpixSize", scanNote, ":", "\r")
	// calculate dark values ?
	variable darkAvgTop, darkAvgBottom
	variable getDark = (!((numtype (darkL) ==2) || (numType (darkR) ==2)))
	if (getDark)  // calculate dark value
		imagestats/GS={darkL ,darkR, roiy [0] ,roiy [1]} topWave
		darkAvgTop = V_avg
		imagestats/GS={darkL ,darkR, roiy [0] ,roiy [1]} bottomWave
		darkAvgBottom = V_avg
	else
		darkAvgTop =0
		darkAvgBottom =0
	endif
	// look at each line in the lineScan
	variable ii, numLines = dimsize (topWave, 1), topAVg
	for (ii=0; ii < NumLines; ii += 1)
		imagetransform/G=(ii) getCol topWave
		WAVE W_ExtractedCol
		wavestats/Q/M=1/R=[startP, endP] W_ExtractedCol
		topAvg = V_avg
		imagetransform/G=(ii) getCol bottomWave
		wavestats/Q/M=1/R=[startP, endP] W_ExtractedCol
		ROIratio [ii] = (topAvg - darkAvgTop)/(V_avg - darkAvgBottom)
	endfor	
end

//******************************************************************************************************
// Processes a Square ROI avg, with optional dark subtraction
// Last Modified Jul 23 2010 by Jamie Boyd
Function NQ_doSquareROIavg (chWave, ROI, ROIavg, darkL, darkR, darkT, darkB)
	WAVE chWave
	string ROI
	wave ROIavg
	variable darkL, darkR, darkT, darkB
	
	WAVE roix = $"root:twoP_ROIs:" + ROI  + "_x"
	WAVE roiy = $"root:twoP_ROIs:" + ROI  + "_y"
	variable left = roix [0]
	variable right = roix [2]
	variable top = roiy [1]
	variable bottom = roiy [0]
	// look at each frame in the scan
	variable ii, numFrames = dimsize (chWave, 2)
	FOR (ii=0; ii < NumFrames; ii += 1)
		imagestats/GS={left, right, bottom, top}/P=(ii) chwave
		RoiAvg [ii] = V_avg
	ENDFOR
	// calculate dark values ?
	variable getDark = (!((((numtype (darkL) ==2) || (numType (darkR) ==2)) || (numType (darkT) == 2)) || (numType (darkB) == 2)))
	if (getDark)  // calculate dark value
		variable darkAvg
		for (darkAvg =0, ii=0; ii < NumFrames; ii += 1)
			imagestats/GS={darkL ,darkR, darkB,darkT}/P=(ii) chwave
			darkAvg += V_avg
		endfor
		darkAvg /= NumFrames
		RoiAvg -= darkAvg
	endif
end

//******************************************************************************************************
// Processes a Square ROI ratio, with optional dark subtraction
// Last Modified Jul 23 2010 by Jamie Boyd
Function NQ_doSquareROIRatio(topWave, bottomWave, ROI, ROIratio, darkL, darkR, darkT, darkB)
	WAVE topWave, bottomWave
	string ROI
	wave ROIratio
	variable darkL, darkR, darkT, darkB
	
	WAVE roix = $"root:twoP_ROIs:" + ROI  + "_x"
	WAVE roiy = $"root:twoP_ROIs:" + ROI  + "_y"
	variable left = roix [0]
	variable right = roix [2]
	variable top = roiy [1]
	variable bottom = roiy [0]
	// look at each frame in the scan
	variable ii, numFrames = dimsize (topWave, 2), topAvg
	// calculate dark values ?
	variable darkAvgTop, darkAvgBottom
	variable getDark = (!((((numtype (darkL) ==2) || (numType (darkR) ==2)) || (numType (darkT) == 2)) || (numType (darkB) == 2)))
	if (getDark)  // calculate dark value
		FOR (darkAvgTop =0, darkAvgBottom=0, ii=0; ii < NumFrames; ii += 1)
			imagestats/GS={darkL ,darkR, darkB ,darkT}/P=(ii) topWave
			darkAvgTop += V_avg
			imagestats/GS={darkL ,darkR, darkB ,darkT}/P=(ii) bottomWave
			darkAvgBottom += v_avg
		endfor
		darkAvgTop/=NumFrames
		darkAvgBottom/=NumFrames
	else
		darkAvgTop =0
		darkAvgBottom =0
	endif
	for (ii=0; ii < NumFrames; ii += 1)
		imagestats/GS={left ,right, bottom ,top}/P=(ii) topWave
		topAvg = v_avg
		imagestats/GS={left ,right, bottom ,top}/P=(ii) bottomWave
		ROIratio [ii] = (topAvg - darkAvgTop)/(V_avg - darkAvgBottom)
	endfor
end

//******************************************************************************************************
// Processes a polygonal ROI avg, with optional dark subtraction
// Last Modified Jul 24 2010 by Jamie Boyd
Function NQ_doPolyROIavg (chWave, ROI, ROIavg, darkL, darkR, darkT, darkB)
	WAVE chWave
	string ROI
	wave ROIavg
	variable darkL, darkR, darkT, darkB
	
	WAVE roix = $"root:twoP_ROIs:" + ROI  + "_x"
	WAVE roiy = $"root:twoP_ROIs:" + ROI  + "_y"
	string savedFolder = getDataFolder (1)
	setdatafolder root:packages:twoP:examine
	// make ROI Mask from ROI
	variable xWid, yWid, xCtr, yCtr
	waveStats/q roiX
	//xWId = ((V_max - V_min)/dimdelta (chWave, 0)) + 20
	xCtr = (V_max + V_min)/2
	waveStats/q roiY
	//yWId = ((V_max - V_min)/dimdelta (chWave, 1)) + 20
	yCtr =  (V_max + V_min)/2
	ImageBoundaryToMask ywave=roiY, xwave=roiX,width=(dimsize (chwave, 0)),height=(dimsize (chWave, 1)),scalingwave=chWave,seedx=(dimOffset (chwave, 0) + dimDelta (chWave, 0)),seedy=(dimOffset (chwave, 1) + dimDelta (chWave, 1))
	WAVE ROIMask = M_ROIMask
	// look at each frame in the scan
	variable ii, numFrames = dimsize (chWave, 2), topAvg
	FOR (ii=0; ii < NumFrames; ii += 1)
		imagestats/M=1/p = (ii) /r = ROImask chWave
		ROIavg [ii] = V_avg
	ENDFOR
	// calculate dark values ?
	variable getDark = (!((((numtype (darkL) ==2) || (numType (darkR) ==2)) || (numType (darkT) == 2)) || (numType (darkB) == 2)))
	if (getDark)  // calculate dark value
		variable darkAvg
		for (darkAvg =0, ii=0; ii < NumFrames; ii += 1)
			imagestats/GS={darkL ,darkR, darkB ,darkT}/P=(ii) chwave
			darkAvg += V_avg
		endfor
		darkAvg /= NumFrames
		RoiAvg -= darkAvg
	endif
	setdatafolder $savedFolder
end

//******************************************************************************************************
// Processes a polygonal ROI ratio, with optional dark subtraction
// Last Modified Jul 24 2010 by Jamie Boyd
Function NQ_doPolyROIRatio(topWave, bottomWave, ROI, ROIratio, darkL, darkT, darkR, darkB)
	WAVE topWave, bottomWave
	string ROI
	wave ROIratio
	variable darkL, darkT, darkR, darkB
	
	WAVE roix = $"root:twoP_ROIs:" + ROI  + "_x"
	WAVE roiy = $"root:twoP_ROIs:" + ROI  + "_y"
	// make ROI Mask from ROI
	variable xWid, yWid, xCtr, yCtr
	waveStats/q roiX
	xWId = ((V_max - V_min)/dimdelta (topWave, 0)) + 20
	xCtr = (V_max + V_min)/2
	waveStats/q roiY
	yWId = ((V_max - V_min)/dimdelta (topWave, 1)) + 20
	yCtr =  (V_max + V_min)/2
	ImageBoundaryToMask ywave=roiY, xwave=roix,width=(dimsize (topWave, 0)),height=(dimSize (topWave, 1)),scalingwave=topWave,seedx=(xCtr),seedy=(yCtr)
	WAVE ROIMask = root:twoP_ROIs:M_ROIMask
	// look at each frame in the scan
	variable ii, numFrames = dimsize (topWave, 2), topAvg
	// calculate dark values ?
	variable darkAvgTop, darkAvgBottom
	variable getDark = (!((((numtype (darkL) ==2) || (numType (darkR) ==2)) || (numType (darkT) == 2)) || (numType (darkB) == 2)))
	if (getDark)  // calculate dark value
		for (darkAvgTop =0, darkAvgBottom=0, ii=0; ii < NumFrames; ii += 1)
			imagestats/GS={darkL ,darkR, darkB ,darkT}/P=(ii) topWave
			darkAvgTop += V_avg
			imagestats/GS={darkL ,darkR, darkB ,darkT}/P=(ii) bottomWave
			darkAvgBottom += v_avg
		endfor
		darkAvgTop/=NumFrames
		darkAvgBottom/=NumFrames
	else
		darkAvgTop =0
		darkAvgBottom = 0
	endif
	// calculate ROI values
	for (ii=0; ii < NumFrames; ii += 1)
		imagestats/M=1/p = (ii) /r = ROImask topWave
		TopAvg = V_avg
		imagestats/M=1/p = (ii) /r = ROImask bottomWave
		ROIratio [ii] = (topAvg - darkAvgTop)/(V_avg - darkAvgBottom)
	endfor
end


//******************************************************************************************************
// This function is used to set the red, green, and blue values for ROI Waves.
// We use pass by reference (note the "&") for the colors, because there are three of them and IGOR only lets us
// return a single number to the calling function. You can change the colours for the numbered ROI's
// by editing the RGB values in the code below
// Last Modified Jul 15 2010 by Jamie Boyd
Function NQ_RGBSetter (ROINum, red, green, blue)
	variable RoiNum, &red, &green, &blue

	SWITCH (ROINum)
		case 0:		// red
			red = 65535
			blue = 0
			green = 0
			break
		case 1:		//blue
			red =0
			blue = 65535
			green = 0
			break
		case 2:		//green
			red = 0
			blue = 0
			green =65535
			break
		case 3:		// orange
			red = 65535
			blue = 0
			green = 43690
			break
		case 4:		// cyan
			red = 0
			blue = 65535
			green = 65535
			break
		case 5:		//lavender
			red = 36873
			blue = 58982
			green = 14755
			break
		case 6:		//puce (or so my wife says)
			red = 65535
			blue = 26214
			green = 0
			break
		case 7:		// yellow
			red = 52425
			blue = 0
			green = 52425
			break
		case 8: // any further ROIS will be white
			red = 655535
			blue = 65535
			green = 65535
			break
	EndSwitch
end

//******************************************************************************************************
// Last modified Jul 02 2010 by Jamie Boyd
Function NQ_DoDeltaFProc (pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up

			string RoiList	// Will contain a list of ROIs, if select all is chosen. Otherwise, contains the name of the chosen ROI
			SVAR curscan = root:Packages:twoP:examine:curscan
			variable bstart, bend, baseline
			ControlInfo /W=twoP_TracesGraph CursorCheck
			if (V_Value == 1) // then taking baseline from between cursors
				bstart = min ((pcsr(A  , "twoP_tracesGraph" )), (pcsr(B  , "twoP_tracesGraph" )))
				bend = max ((pcsr(A  , "twoP_tracesGraph" )), (pcsr(B  , "twoP_tracesGraph" )))
			else		// taking baseline from first xpoints
				NVAR ffordeltaf = root:Packages:twoP:examine:ffordeltaf
				bstart = 0
				bend = ffordeltaf -1
			endif
	
			if ((cmpstr (pa.popStr, "All Roi Avgs"))==0)
				RoiList = NQ_ListROIAvgs (curScan, 1)
			else
				RoiList = pa.popStr
			endif
	
			variable ii, iii, numRecLines, startp
			string aRecLine
			variable numRois = itemsinList (RoiList)
			string tempstr
	
			variable hasRLOI
			if ((cmpstr (AxisInfo("twoP_TracesGraph", "ROIRAxis"), "")) == 0)
				hasRLOI =0
			else
				hasRLOI =1
			endif
	
			FOR (ii =0; ii < numRois; ii+=1)
				WAVE roiwave = $"root:twoP_Scans:" + curscan + ":" + stringfromlist (ii, RoiList)
				if (waveExists (roiwave))
					baseline = mean(roiwave, pnt2x(roiwave,bstart), pnt2x(roiwave,bend))
					roiwave = (roiwave - baseline)/baseline
			
					string RecStr = TraceInfo("twoP_TracesGraph", nameofwave (roiwave), 0)
					removefromgraph  /W=twoP_TracesGraph $nameofwave (roiwave)
					appendtograph /W=twoP_TracesGraph/R=ROIRAxis/B=Bottom roiwave

					startp = strsearch (RecStr, "RECREATION", 0)
					RecStr = RecStr [startp + 11, strlen (recStr) -1]
					numRecLines = itemsinlist (RecStr)
			
					FOR (iii = 0; iii < numRecLines; iii += 1)
						aRecLine = stringfromlist (iii, RecStr)
						startp = strsearch (aRecline, "(x)", 0)
						aRecline = "modifyGraph/W=twoP_TracesGraph " + aRecline [0, startp] + nameofwave (roiwave) + aRecLine [startp + 2, strlen (arecline) -1]
						execute arecline
					ENDFOR
		
					tempstr = ReplaceNumberByKey("deltafed", note (roiwave), 1 )
					tempstr = ReplaceStringByKey ( "baseline", tempstr, num2str(baseline))
					note/K roiwave
					note Roiwave, tempstr
				endif
			endfor
			NQ_TracesGraphShareAxes (curScan)
			break
	endSwitch
	return 0
end

//******************************************************************************************************
// Undo the delta F /F transformation,using the baseline value stored in the ROI's wavenote. Also take ROI off of right axis on traces graph and put it on left axis
// Last modified Jul 14 2010 by Jamie Boyd
Function NQ_UnDoDeltaFProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
	
			string RoiList	// Will contain a list of ROIs, if select all is chosen. Otherwise, contains the name of the chosen ROI
			SVAR curscan = root:Packages:twoP:examine:curscan
			variable  baseline
		
			if ((cmpstr (pa.popStr, "All Roi Avgs"))==0)
				RoiList = NQ_ListROIAvgs (curScan, 2)
			else
				RoiList = pa.popStr
			endif
	
			variable ii, iii, numRecLines, startp
			string aRecLine
			variable numRois = itemsinList (RoiList)
			string tempstr
	
			variable hasRLOI
			if ((cmpstr (AxisInfo("twoP_TracesGraph", "ROILAxis"), "")) == 0)
				hasRLOI =0
			else
				hasRLOI =1
			endif
	
			FOR (ii =0; ii < numRois; ii+=1)
				WAVE roiwave = $"root:twoP_Scans:" + curscan + ":" + stringfromlist (ii, RoiList)
				if (waveExists (roiwave))
					baseline = numberbykey ("baseline", note (roiwave))
					roiwave = (roiwave * baseline) + baseline
			
					string RecStr = TraceInfo("twoP_TracesGraph", nameofwave (roiwave), 0)
					removefromgraph  /W=twoP_TracesGraph $nameofwave (roiwave)
					appendtograph /W=twoP_TracesGraph/L=ROILAxis/B=Bottom roiwave

					startp = strsearch (RecStr, "RECREATION", 0)
					RecStr = RecStr [startp + 11, strlen (recStr) -1]
					numRecLines = itemsinlist (RecStr)
			
					FOR (iii = 0; iii < numRecLines; iii += 1)
						aRecLine = stringfromlist (iii, RecStr)
						startp = strsearch (aRecline, "(x)", 0)
						aRecline = "modifyGraph/W=twoP_TracesGraph " + aRecline [0, startp] + nameofwave (roiwave) + aRecLine [startp + 2, strlen (arecline) -1]
						execute arecline
					ENDFOR
			
					tempstr = ReplaceNumberByKey("deltafed", note (roiwave), 0) + "baseline:" + num2str (baseline) + ";"
					tempstr = RemoveByKey("baseline", tempstr)
					note/K roiwave
					note Roiwave, tempstr
				endif
			endfor
			NQ_TracesGraphShareAxes (curScan)
			break
	endSwitch
	return 0
end

//******************************************************************************************************
// Lists ROI avgs for the current scan. List can be limited to ROI avgs that have been deltaF/F processed or unprocessed. If all ROI avgs are listed, list includes ROI ratios
// Last modified 2012/06/13 by Jamie Boyd
Function/s NQ_ListROIAvgs (ScanName, deltaFed)
	string ScanName
	variable deltaFed	// 1 if listing waves that have NOT been detlafed, 2 if listing waves that have been deltafed, 3 if listing all ROIs
	
	string BaseFolder = "root:twoP_Scans:"
	string AvgList = GUIPListObjs("root:twoP_Scans:" + ScanName , 1, "*avg*",0, "")
	variable ii, numAvgs = itemsinlist (AvgList, ";")
	string outlist = ""
	variable beenDeltafed
	if ((cmpstr (AvgList [0,3], "\M1(")) == 0)
		return AvgList
	endif
	for (ii =0; ii < numAvgs; ii+=1)
		Wave theAvg = $"root:twoP_Scans:" + ScanName + ":"  + stringfromlist (ii, AvgList)
		beenDeltafed = numberbykey ("DeltaFed", note  (theAvg))
		if (deltafed&1)
			if (beenDeltafed == 0)
				outlist += nameofwave (theAvg) + ";"
			endif
		endif
		if (deltafed&2)
			if (beenDeltafed == 1)
				outlist += nameofwave (theAvg) + ";"
			endif
		endif
	endfor
	// if listing all ROIs avgs, also list 2-channel ratios
	if (deltaFed == 3)
		AvgList= GUIPListObjs("root:twoP_Scans:" + ScanName , 1, "*ratio*", 0, "")
		if (cmpstr (AvgList [0,3], "\M1(") != 0)
			numAvgs = itemsinlist (AvgList, ";")
			for (ii=0; ii<numAvgs; ii+=1)
				WAVE theAvg= $"root:twoP_Scans:" + ScanName + ":" + stringfromlist (ii, AvgList)
				outlist += nameofwave (theAvg) + ";"
			endfor
		endif
	endif
	if (strlen (outlist) > 2)
		outlist +=  "All ROI Avgs"
	else
		outlist = "\\M1(No ROI Avgs"
	endif
	
	return outlist
end

//******************************************************************************************************
// Deletes an ROIavg and optionally its associated ROIwave(s)
// Last modified Jul 26 2010 by Jamie Boyd
Function NQ_DeleteRoiProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
	
			WAVE/t RoiListWave = root:Packages:twoP:examine:RoiListWave
			WAVE RoiListSelWave = root:Packages:twoP:examine:RoiListSelWave
			string RoiList	// Will contain a list of ROIs, if select all is chosen. Otherwise, contains the name of the chosen ROI
			SVAR curscan = root:Packages:twoP:examine:curscan
			variable DelROI
			controlinfo /W=twoP_TracesGraph AndROICheck
			DelRoi = V_Value
			if ((cmpstr (pa.popStr, "All Roi Avgs"))==0)
				RoiList = NQ_ListROIAvgs (curScan, 3)
			else
				RoiList = pa.popStr
			endif
			variable ii, numRois = itemsinList (RoiList)
			variable iR, nR = dimsize (RoiListWave, 0), foundROI
			string ROIBase
			FOR (ii =0; ii < numRois; ii+=1)
				WAVE roiAvgwave = $"root:twoP_Scans:" + curscan + ":" + stringfromlist (ii, RoiList)
				if (waveExists (roiAvgwave))	
					// remove average from traces graph
					removefromgraph /W=twoP_TracesGraph/Z $nameofwave (roiAvgwave)
					// Get ROI from wave note before killing wave
					ROIBase = stringbykey ("ROI", note (roiAvgwave))
					GUIPKillDisplayedWave (roiAvgwave)
					// Delete ROI if requested by user
					if (DelRoi)
						WAVE ROIYWave = $"root:twoP_ROIs:" + ROIBase + "_y"
						WAVE ROIXWave = $"root:twoP_ROIs:" + ROIBase + "_x"
						RemoveFromGraph /W=twoPScanGraph /Z $nameofwave (ROIYWave)
						GUIPKillDisplayedWave (ROIYWave)
						GUIPKillDisplayedWave (ROIXWave)
						// remove ROI from list
						for (foundROI =0, iR =0; iR < nR && foundROI ==0; iR += 1)
							if (cmpStr (ROIBase,  RoiListWave [iR]) == 0)
								deletepoints (iR), 1, RoiListWave, RoiListSelWave
								foundROI =1
							endif
						endfor
					endif
				endif
			endfor
			NQ_TracesGraphShareAxes (curScan)
			break
	endSwitch
End

//******************************************************************************************************
// Puts cursors on the first ROI avg in the twoP Traces Graph, for the purpose of defining a baseline value
// Last modified Jul 16 2010 by Jamie Boyd
Function NQ_cursorCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			if (cba.checked)
				showinfo
				string firstTrace = stringFromList (0, TraceNameList("twoP_TracesGraph", ";", 1 ), ";")
				Cursor/P/W= twoP_TracesGraph A, $firstTrace,  0
				Cursor/P/W= twoP_TracesGraph B, $firstTrace, 5
			else
				hideinfo
				cursor/K A
				cursor/K B
			endif
			break
	endSwitch
End


//******************************************************************************************************
// needed to get the subwindow a marquee is drawn on, as the host window is returned in Igor 5 in S_marqueeWin while the
// full host#subwindow name is given in Igor 6
// last modified Jul 14 2010 by Jamie Boyd
Function/S  NQ_GetMarqueeSubWinFor5 (graphName, V_left, V_bottom)
	string graphName
	variable V_left, V_Bottom
	
	string subWins = childwindowlist ("twoPScanGraph")
	variable iw, nW = itemsinlist (subWins, ";")
	variable leftAxVal, bottomAxVal
	string subGraph 
	for (iw=0; iw< nW; iw += 1)
		subGraph =  stringFromList (iw, subWins,";")
		leftAxVal = AxisValFromPixel(graphName + "#" + subGraph  , "bottom", V_left)
		GetAxis/Q/w = $(graphName + "#" + subGraph)  bottom
		if ((V_min < leftAxVal) && (V_max > leftAxVal))
			bottomAxVal =  AxisValFromPixel(graphName + "#" + subGraph  , "left", V_bottom)
			GetAxis/Q/w = $(graphName + "#" + subgraph) left
			if ((V_min < bottomAxVal) && (V_max > bottomAxVal))
				return subGraph
			endif
		endif
	endfor
	return ""
end	


Function ROI_Ratio_Multi (): GraphMarquee

	GetMarquee/k left,bottom
	SVAR curscan = root:Packages:twoP:examine:CurScan
	variable BaseNameLen = strlen (curScan)
	string BaseName = curscan [0, BaseNameLen - 5]
	string ToDoList = sortlist (GUIPListObjs("root:twoP_Scans", 1, BaseName + "*_ch1", 0, ""), ";", 16)
	
	variable numWaves = itemsinList (ToDoList, ";"), ii
	WAVE thescanwave = $"root:twoP_Scans:" + stringfromlist (0, ToDoList)
	string tempStr
	Variable FrameTime =  numberbykey("LineTime", note (thescanwave)) * (dimsize (thescanwave, 1))
	variable NumFrames = dimsize (thescanwave, 2)
	
	//Find the first free name for the ROI and make the ROI wave
	variable in
	For (in=0; (exists("root:twoP_MultiROIs:" +  curscan + "_MR" + num2str (in) )) == 1; in += 1)
	Endfor

	String ROINameStr= "root:twoP_MultiROIs:" +  curscan + "_MR" + num2str (in)
	make/o/n = ((NumFrames), (numWaves)) $ROINameStr
	WAVE outputWave = $ROINameStr
		

	variable lpix = round(V_left)
	variable rpix =  round(V_right)
	variable tpix =  round(V_bottom)
	variable bpix =  round(V_top)
	variable accwid = rpix - lpix
	variable accheight = tpix - bpix
	
	make/n= 5 $ROINameStr + "_x", $ROINameStr + "_y"
	WAVE RoiXWave = $ROINameStr + "_x"
	WAVE RoiYWave = $ROINameStr + "_y"
	//Note RoiXWave, "WaveType:ROIsquare;" + "Red:" + num2str (red) + ";Green:" + num2str (green) + ";Blue:" + num2str (blue) + ";"
	ROIxWave [0,1] = lpix
	ROIxWave [2,3] = rpix
	ROIxWave [4] = lpix
	ROIyWave [0] = BPix
	ROIyWave [1,2] = Tpix
	ROIYWave [3,4] = Bpix
	

	make/o/ n= (accwid, accheight)root:Packages:twoP:examine:AccWave
	WAVE ACCWave = root:Packages:twoP:examine:AccWave
	
	variable ch1bk =0 , ch2bk=0
	prompt ch1bk, "channel 1 bkgd"
	prompt ch2bk, " channel 2  bkgd"
	doprompt "Enter backgrounds or 0 for no backgrounds (or use background ROI)" ,ch1bk, ch2bk
	if (V_Flag == 1)
		return 1
	endif

	// Draw ROI on the top graph
	appendtograph RoiYWave vs RoiXWave
	TextBox/F=0/G=(65000,65000,65000)/b=1/A=LB/X=(100*lpix/dimsize (thescanwave,0))/Y=(100-(100*tpix /dimsize (thescanwave, 1))) num2str (in)
	
	variable iw
	For (iw =0; iw < numWaves;iw += 1)
		tempStr = stringfromlist (iw, ToDoList)
		WAVE theScanWave = $"root:twoP_Scans:" + tempStr
		Wave theScanBkgWave =$("root:twoP_Scans:" + tempStr[0, strlen (tempstr)-2] + "2")
		
		make/o/ n= (accwid, accheight)root:Packages:twoP:examine:AccBkgWave
		WAVE ACCBkgWave = root:Packages:twoP:examine:AccBkgWave
		
		// do we have background fluorescence?
		string tempnote = note (theScanWave)
		variable DarkL = numberbykey ("darkL", tempnote)
		if ((numtype (DarkL)) == 2)// don'thave background
			FOR (ii=0; ii < NumFrames; ii += 1)
				ACCwave  = theScanWave [p + lpix] [q + bpix] [ii]
				ACCBkgWave = theScanBkgWave [p + lpix] [q + bpix] [ii]
				outputWave[ii] [iw] = (mean (accwave, -inf, inf)-ch1bk)/(mean (ACCBkgWave, -inf, inf)-ch1bk)
				
			ENDFOR
		else			// we do have background
			variable DarkT = numberbykey ("darkT", tempnote)
			variable DarkR = numberbykey ("darkR", tempnote)
			variable DarkB = numberbykey ("darkB", tempnote)
			make/o/ n= ((DarkR - DarkL + 1), (DarkT - DarkB + 1)) root:Packages:twoP:examine:DarkWave
			WAVE DarkWave = root:Packages:twoP:examine:DarkWave
			make/o/ n= ((DarkR - DarkL + 1), (DarkT - DarkB + 1)) root:Packages:twoP:examine:DarkBkgWave
			WAVE DarkBkgWave = root:Packages:twoP:examine:DarkBkgWave
			FOR (ii=0; ii < NumFrames; ii += 1)
				DarkWave =  theScanWave [p + DarkL] [q + DarkB] [ii]
				ACCwave  = theScanWave [p + lpix] [q + bpix] [ii]
				DarkBkgWave =  theScanBkgWave [p + DarkL] [q + DarkB] [ii]
				ACCBkgwave  = theScanBkgWave [p + lpix] [q + bpix] [ii]
				outputWave[ii] [iw] = (mean (accwave, -inf, inf) - mean (DarkWave,  -inf, inf))/(mean (accBkgwave, -inf, inf) - mean (DarkBkgWave,  -inf, inf))
			ENDFOR
		endif
	endfor
	
	newWaterfall outputwave
	ModifyWaterfall angle=90, axlen= 0.9, hidden= 0
	duplicate/o outputwave $"root:twoP_MultiROIs:" +  curscan + "_CW" + num2str (in)
	WAVE colorwave = $"root:twoP_MultiROIs:" +  curscan + "_CW" + num2str (in)
	colorwave = q
	ModifyGraph zColor [0]={colorwave,*,*,Rainbow}
end

Function ROI_Multi (): GraphMarquee

	GetMarquee/k left,bottom
	SVAR curscan = root:Packages:twoP:examine:CurScan
	variable BaseNameLen = strlen (curScan)
	string BaseName = curscan [0, BaseNameLen - 5]
	string ToDoList = sortlist (GUIPListObjs("root:twoP_Scans", 1, BaseName + "*_ch1", 0, "")  , ";", 16)
	
	variable numWaves = itemsinList (ToDoList, ";"), ii
	WAVE thescanwave = $"root:twoP_Scans:" + stringfromlist (0, ToDoList)
	string tempStr
	Variable FrameTime =  numberbykey("LineTime", note (thescanwave)) * (dimsize (thescanwave, 1))
	variable NumFrames = dimsize (thescanwave, 2)
	
	//Find the first free name for the ROI and make the ROI wave
	variable in
	For (in=0; (exists("root:twoP_MultiROIs:" +  curscan + "_MR" + num2str (in) )) == 1; in += 1)
	Endfor

	String ROINameStr= "root:twoP_MultiROIs:" +  curscan + "_MR" + num2str (in)
	make/o/n = ((NumFrames), (numWaves)) $ROINameStr
	WAVE outputWave = $ROINameStr
		

	variable lpix = round(V_left)
	variable rpix =  round(V_right)
	variable tpix =  round(V_bottom)
	variable bpix =  round(V_top)
	variable accwid = rpix - lpix
	variable accheight = tpix - bpix
	
	make/n= 5 $ROINameStr + "_x", $ROINameStr + "_y"
	WAVE RoiXWave = $ROINameStr + "_x"
	WAVE RoiYWave = $ROINameStr + "_y"
	//Note RoiXWave, "WaveType:ROIsquare;" + "Red:" + num2str (red) + ";Green:" + num2str (green) + ";Blue:" + num2str (blue) + ";"
	ROIxWave [0,1] = lpix
	ROIxWave [2,3] = rpix
	ROIxWave [4] = lpix
	ROIyWave [0] = BPix
	ROIyWave [1,2] = Tpix
	ROIYWave [3,4] = Bpix
	

	make/o/ n= (accwid, accheight)root:Packages:twoP:examine:AccWave
	WAVE ACCWave = root:Packages:twoP:examine:AccWave
	
	variable ch1bk =0
	prompt ch1bk, "bkgd"
	doprompt "Enter background or 0 for no background (or use background ROI)" ,ch1bk
	if (V_Flag == 1)
		return 1
	endif

	// Draw ROI on the top graph
	appendtograph RoiYWave vs RoiXWave
	TextBox/F=0/G=(65000,65000,65000)/b=1/A=LB/X=(100*lpix/dimsize (thescanwave,0))/Y=(100-(100*tpix /dimsize (thescanwave, 1))) num2str (in)
	
	variable iw
	For (iw =0; iw < numWaves;iw += 1)
		tempStr = stringfromlist (iw, ToDoList)
		WAVE theScanWave = $"root:twoP_Scans:" + tempStr
		Wave theScanBkgWave =$("root:twoP_Scans:" + tempStr[0, strlen (tempstr)-2] + "2")

		// do we have background fluorescence?
		string tempnote = note (theScanWave)
		variable DarkL = numberbykey ("darkL", tempnote)
		if ((numtype (DarkL)) == 2)// don'thave background
			FOR (ii=0; ii < NumFrames; ii += 1)
				ACCwave  = theScanWave [p + lpix] [q + bpix] [ii]
				outputWave[ii] [iw] = (mean (accwave, -inf, inf)-ch1bk)
				
			ENDFOR
		else			// we do have background
			variable DarkT = numberbykey ("darkT", tempnote)
			variable DarkR = numberbykey ("darkR", tempnote)
			variable DarkB = numberbykey ("darkB", tempnote)
			make/o/ n= ((DarkR - DarkL + 1), (DarkT - DarkB + 1)) root:Packages:twoP:examine:DarkWave
			WAVE DarkWave = root:Packages:twoP:examine:DarkWave

			FOR (ii=0; ii < NumFrames; ii += 1)
				DarkWave =  theScanWave [p + DarkL] [q + DarkB] [ii]
				ACCwave  = theScanWave [p + lpix] [q + bpix] [ii]

				outputWave[ii] [iw] = (mean (accwave, -inf, inf) - mean (DarkWave,  -inf, inf))
			ENDFOR
		endif
	endfor
	
	newWaterfall outputwave
	ModifyWaterfall angle=90, axlen= 0.9, hidden= 0
	duplicate/o outputwave $"root:twoP_MultiROIs:" +  curscan + "_CW" + num2str (in)
	WAVE colorwave = $"root:twoP_MultiROIs:" +  curscan + "_CW" + num2str (in)
	colorwave = q
	ModifyGraph zColor [0]={colorwave,*,*,Rainbow}
end

//***********************************************************************************
//Button procedure for executing NMultiROI function - DSI image plot.
//Added Oct 11 017 by Ben Murphy-Baum

Function NMultiROIButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
//			NMultiROI()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
