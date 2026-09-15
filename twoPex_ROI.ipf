#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma version = 3  	// Last Modified: 2026/09/11 by Jamie Boyd.
#pragma IgorVersion = 9

// ****************************************** twoPexROI *****************************************************
// ------------------ Part of twoPhoton - Scanning Laser Microscopy with Igor Pro and NI-DAQmx --------------
// ----------------------------------------------------------------------------------------------------------
// ----- Code for the ROI tab on the Examine Tab Control for working with Regions Of Interest (ROIs) --------
//******************************************************************************************************


// ***************************** twoPexROI_add *****************************************************
// adds the controls on the ROI tab
// Last Modified 2025/07/23 by Jamie Boyd
Function twoPexROI_add (able)
	variable able

	// Globals for ROI Tab
	string/G root:packages:twoP:examine:ROIimPath = "no folder selected"
	string/G root:packages:twoP:examine:newROIname
	string/G root:packages:twoP:examine:ROItopChan 
	string/G root:packages:twoP:examine:ROIbottomChan 
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
	// Controls for ROI tab
	// Saving and Loading ROIs to disk
	Button ROILoadButton win =twoP_Controls,pos={9.00,412.00},size={44.00,20.00},proc=twoP_RoiLoadProc
	Button ROILoadButton win =twoP_Controls,title="Load"
	Button ROILoadButton win =twoP_Controls, disable = able
	Button ROISaveButton win =twoP_Controls,pos={56.00,412.00},size={44.00,20.00},proc=twoP_ROISaveProc
	Button ROISaveButton win =twoP_Controls,title="Save"
	Button ROISaveButton win =twoP_Controls, disable = able
	Button ROISetFolderButton win =twoP_Controls,pos={103.00,412.00},size={68.00,20.00},proc=twoP_ROIsetPathProc
	Button ROISetFolderButton win =twoP_Controls,title="Set Path"
	Button ROISetFolderButton win=twoP_Controls, disable = able
	TitleBox ROIImpathtitle win=twoP_Controls,pos={173.00,416.00},size={578.00,15.00},fSize=12
	TitleBox ROIImpathtitle win=twoP_Controls,frame=0,variable=root:packages:twoP:examine:ROIimPath
	TitleBox ROIImpathtitle win=twoP_Controls, disable = able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "ROI","Button ROILoadButton 0;Button ROISaveButton 0;Button ROISetFolderButton 0;Titlebox ROIImpathtitle 0;",applyAbleState=0)
	// List box for displaying existing ROIs
	ListBox ROIListBox win=twoP_Controls,pos={214.00,439.00},size={125.00,100.00},proc=twoP_ROIListBoxProc
	ListBox ROIListBox win=twoP_Controls,fSize=12,listWave=root:packages:twoP:examine:ROIListWave
	ListBox ROIListBox win=twoP_Controls,selWave=root:packages:twoP:examine:ROIListSelWave,mode=4
	ListBox ROIListBox win=twoP_Controls, disable = able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "ROI","ListBox ROIListBox 0;",applyAbleState=0)
	// making a new ROI
	Button RoiNewbutton win=twoP_Controls,pos={8.00,439.00},size={64.00,20.00},proc=twoP_NewRoiButtonProc
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
	Button ROINudgeButton win=twoP_Controls,pos={8.00,488.00},size={50.00,23.00},proc=twoP_RoiNudgeProc
	Button ROINudgeButton win=twoP_Controls,title="Nudge"
	Button ROINudgeButton win=twoP_Controls, disable = able
	PopupMenu ROIonWindowPopup win=twoP_Controls,pos={63.00,491.00},size={147.00,20.00},title="On"
	PopupMenu ROIonWindowPopup win=twoP_Controls,fSize=12
	PopupMenu ROIonWindowPopup win=twoP_Controls,mode=1,popvalue="twoPscanGraph",value=#"WinList(\"*\", \";\", \"WIN:1\" )"
	PopupMenu ROIonWindowPopup win=twoP_Controls,disable=able
	Button ROIDuplButton win=twoP_Controls,pos={8.00,515.00},size={65.00,20.00},proc=twoP_ROIDuplicateButtonProc
	Button ROIDuplButton win=twoP_Controls,title="Duplicate",fSize=12
	Button ROIDuplButton win=twoP_Controls, disable = able
	Button RoiDelbutton win=twoP_Controls,pos={90.00,515.00},size={60.00,20.00},proc=twoP_DelRoiButtonProc
	Button RoiDelbutton win=twoP_Controls,title="Delete",fSize=12
	Button RoiDelbutton win=twoP_Controls, disable = able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "ROI", "Button ROINudgeButton;PopupMenu ROIonWindowPopup;Button ROIDuplButton;Button RoiDelbutton",applyAbleState=0)
	// Do the ROI with options
	Button ROIAvgButton win=twoP_Controls,pos={8.00,547.00},size={57.00,20.00},proc=twoP_ROIRunButtonProc
	Button ROIAvgButton win=twoP_Controls,title="ROI Avg"
	Button ROIAvgButton win=twoP_Controls, disable =able
	// select channel
	PopupMenu ROIchanPopup win=twoP_Controls,pos={69.00,547.00},size={47.00,20.00},proc=twoP_ROISelChan_PopMenuProc
	PopupMenu ROIchanPopup win=twoP_Controls,title="of",mode=0,value=#"twoP_ScanlistImChans()+\";ratio\""
	PopupMenu ROIchanPopup win=twoP_Controls, disable = able
	TitleBox ROIchanTitle win=twoP_Controls,pos={120.00,550.00},size={23.00,15.00},fSize=12,frame=0
	TitleBox ROIchanTitle win=twoP_Controls,variable=root:packages:twoP:examine:ROIselChan
	TitleBox ROIchanTitle win=twoP_Controls, disable = able
	// top and bottom channel for ratio
	PopupMenu ROItopChanPopUp win=twoP_Controls,pos={149.00,547.00},size={45.00,20.00},bodyWidth=45,proc=twoP_ROIPopMenuProc
	PopupMenu ROItopChanPopUp win=twoP_Controls,title="top",fSize=12
	PopupMenu ROItopChanPopUp win=twoP_Controls,mode=0,value=#"twoP_ScanListImChans()"
	PopupMenu ROItopChanPopUp win=twoP_Controls, disable = able
	TitleBox ROItopChanTitle win=twoP_Controls,pos={196.00,549.00},size={19.00,15.00},fSize=12, frame=0
	TitleBox ROItopChanTitle win=twoP_Controls,variable=root:packages:twoP:examine:ROItopChan
	TitleBox ROItopChanTitle win=twoP_Controls, disable = able
	PopupMenu ROIbottomChanPopUp win=twoP_Controls,pos={239.00,547.00},size={45.00,20.00},bodyWidth=45,proc=twoP_ROIPopMenuProc
	PopupMenu ROIbottomChanPopUp win=twoP_Controls,title="bot",fSize=12
	PopupMenu ROIbottomChanPopUp win=twoP_Controls,mode=0,value=#"twoP_ScanListImChans()"
	PopupMenu ROIbottomChanPopUp win=twoP_Controls, disable =able
	TitleBox ROIbottomChanTitle win=twoP_Controls,pos={286.00,549.00},size={19.00,15.00},fSize=12
	TitleBox ROIbottomChanTitle win=twoP_Controls,frame=0
	TitleBox ROIbottomChanTitle win=twoP_Controls,variable=root:packages:twoP:examine:ROIbottomChan
	TitleBox ROIbottomChanTitle win=twoP_Controls,disable = able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "ROI", "Button ROIAvgButton;PopupMenu ROIchanPopup;TitleBox ROIchanTitle;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "ROI", "PopupMenu ROItopChanPopUp 1;TitleBox ROItopChanTitle 1;",applyAbleState=1)
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "ROI", "PopupMenu ROIbottomChanPopUp 1;TitleBox ROIbottomChanTitle 1;", applyAbleState=1)
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
	SetVariable NameMatchSetVar win=twoP_Controls,pos={222.00,616.00},size={110.00,18.00},title=" "
	SetVariable NameMatchSetVar win=twoP_Controls,help={"Selects scans with this key in key=value;pairs in exp note."}
	SetVariable NameMatchSetVar win=twoP_Controls,value=root:packages:twoP:examine:ROIScanMatchStr, fsize=12
	SetVariable NameMatchSetVar win=twoP_Controls,disable=able
	// ROInameMatchCheck
	CheckBox ROInameMatchCheck win=twoP_Controls,pos={113.00,617.00},size={105.00,15.00},proc=GUIPControls#GUIPRadioButtonProc
	CheckBox ROInameMatchCheck win=twoP_Controls,title="Name Matching"
	CheckBox ROInameMatchCheck win=twoP_Controls,userdata="ROICurScanCheck;ROInameMatchCheck;ROInoteMatchCheck"
	CheckBox ROInameMatchCheck win=twoP_Controls,userdata (gValue) = "root:packages:twoP:examine:ROIscanSelMode"
	CheckBox ROInameMatchCheck win=twoP_Controls,fSize=12,value=0,mode=1
	CheckBox ROInameMatchCheck win=twoP_Controls,disable =able
	// ROInoteMatchCheck
	CheckBox ROInoteMatchCheck win=twoP_Controls,pos={14.00,636.00},size={118.00,15.00},proc=GUIPControls#GUIPRadioButtonProc
	CheckBox ROInoteMatchCheck win=twoP_Controls,title="Exp Note Matching"
	CheckBox ROInoteMatchCheck win=twoP_Controls,userdata="ROICurScanCheck;ROInameMatchCheck;ROInoteMatchCheck"
	CheckBox ROInoteMatchCheck win=twoP_Controls,userdata(gValue)="root:packages:twoP:examine:ROIscanSelMode"
	CheckBox ROInoteMatchCheck win=twoP_Controls,fSize=12,value=0,mode=1
	CheckBox ROInoteMatchCheck win=twoP_Controls, disable =able
	// ROIKeySetVar
	SetVariable ROIKeySetVar win=twoP_Controls,pos={142.00,634.00},size={70.00,18.00},title=" Key"
	SetVariable ROIKeySetVar win=twoP_Controls,help={"Selects scans with this key in key=value;pairs in exp note."}
	SetVariable ROIKeySetVar win=twoP_Controls,fSize=12
	SetVariable ROIKeySetVar win=twoP_Controls,value=root:Packages:twoP:examine:ROInoteKeyStr
	SetVariable ROIKeySetVar win=twoP_Controls, disable =able
	// ROInoteValsSetVar
	SetVariable ROInoteValsSetVar win=twoP_Controls,pos={221.00,634.00},size={113.00,18.00}
	SetVariable ROInoteValsSetVar win=twoP_Controls,title="Values"
	SetVariable ROInoteValsSetVar win=twoP_Controls,help={"Selects scans with these values in key=value;pairs in exp note."}
	SetVariable ROInoteValsSetVar win=twoP_Controls,fSize=12
	SetVariable ROInoteValsSetVar win=twoP_Controls,value=root:Packages:twoP:examine:ROInoteValueStr
	SetVariable ROInoteValsSetVar win=twoP_Controls, disable =able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "ROI", "CheckBox ROICurScanCheck;CheckBox ROInameMatchCheck;CheckBox ROInoteMatchCheck;")
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "ROI", "SetVariable ROIKeySetVar;SetVariable ROInoteValsSetVar;setvariable NameMatchSetVar")
end


//******************************************************************************************************
// Loads ROIs from an Igor text file on disk
// Last Modified Jul 16 2010 by Jamie Boyd
Function twoP_RoiLoadProc (ba) : ButtonControl
	STRUCT WMbuttonAction &ba		
		
	switch( ba.eventCode )
		case 2: // mouse up
			string dfldr = getdatafolder (1)
			setdatafolder $"root:twoP_ROIs:"
			LoadWave/T/P=ROIPath ""
			twoP_ListRois ()
			setdatafolder dfldr
			break
	endSwitch
End



function twoPexROI_Update()
	twoP_ListRois ()
end



Function twoP_ROISelChan_PopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			SVAR selChan = root:packages:twoP:examine:ROIselChan
			selChan = pa.popStr
			variable state
			if (cmpStr(pa.popStr, "ratio") ==0)
				state =0
			else
				state =1
			endif
			PopupMenu ROItopChanPopUp win=twoP_Controls, disable = state
			titleBox ROItopChanTitle win=twoP_Controls, disable = state
			PopupMenu ROIbottomChanPopUp win=twoP_Controls, disable = state
			titleBox ROIbottomChanTitle win=twoP_Controls, disable = state
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End



//******************************************************************************************************
// Appends an ROI average to the Traces graph and the associated ROI to the ScanGraph
// Last Modified 2025/09/15 by Jamie Boyd
Function twoP_AppendROIandAvg (ROIavg, ROIStr, isDeltaFed)
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
	doWindow/F twoPScanGraph
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
		twoP_TracesGraphNew (curScan)
	else
		traceList = TraceNameList("twoP_TracesGraph", ";", 1 )
		variable hasROISpace=0, hasROIaxis=0
		string infoStr, thisAxis, thatAxis
		if (isDeltaFed) // need ROIR axis
				thisAxis = "ROIR"
				thatAxis="ROIL"
				appendtograph /W=twoP_TracesGraph/C=(red, green, blue)/R=$thisAxis/B=Bottom  ROIavg
			else
				thisAxis = "ROIL"
				thatAxis="ROIR"
				appendtograph /W=twoP_TracesGraph/C=(red, green, blue)/L=$thisAxis/B=Bottom  ROIavg
			endif
		variable axStart, axEnd
		
		if (WhichListItem(nameOfwave (roiAvg), traceList , ";") == -1) // ROI avg is not already plotted on TracesGraph
			
			if (WhichListItem(thisAxis,traceList)  > -1) // has needed axis
				hasROIaxis =1
				hasROISpace=1
			else
				if (WhichListItem(thatAxis, traceList) > -1) // has axis on opposite side with same proportions
					hasROISpace =1
				endif
			endif
			if (isDeltaFed) // need ROIR axis
				thisAxis = "ROIR"
				thatAxis="ROIL"
				appendtograph /W=twoP_TracesGraph/C=(red, green, blue)/R=$thisAxis/B=Bottom  ROIavg
			else
				thisAxis = "ROIL"
				thatAxis="ROIR"
				appendtograph /W=twoP_TracesGraph/C=(red, green, blue)/L=$thisAxis/B=Bottom  ROIavg
			endif
		
			if (!(hasROIaxis))
				if (hasROISpace)
					infoStr= stringByKey("axisEnab(x)", axisinfo ("twoP_TracesGraph", thatAxis),"=", ";")
					sscanf infoStr, "{%f,%f}", axStart, axEnd
					ModifyGraph /W=twoP_TracesGraph axisEnab($thisAxis)={axStart,axEnd}
				else
					twoP_TracesGraphShareAxes ()
				endif
				if (cmpStr (thisAxis, "ROIR") ==0)
					ModifyGraph/W=twoP_TracesGraph freePos($thisAxis)={0,kwFraction}, lblPos($thisAxis)=45
					Label $thisAxis "\\Z12Delta F/F"
				else
					Label $thisAxis "\\Z12Raw 12 bit A/D"  
					ModifyGraph /W=twoP_TracesGraph freePos($thisAxis)={0,bottom}, lblPos($thisAxis)=45
				endif
			endif
		endif
	endif
	ModifyGraph /W=twoP_TracesGraph btLen=2
	ModifyGraph /W=twoP_TracesGraph stLen=1
	ModifyGraph /W=twoP_TracesGraph ftLen=2
end


//******************************************************************************************************
// Updates the list box of ROIs in the twoP_ROIS folder
// Last Modified Jul 16 2010 by Jamie Boyd
Function twoP_ListRois ()
	
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
// Last Modified 2025/05/15 by Jamie Boyd
Function twoP_ROIPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			if (cmpStr (pa.ctrlName, "ROItopChanPopUp") ==0)
				SVAR Chan = root:packages:twoP:examine:ROItopChan
			elseif (cmpStr (pa.ctrlName, "ROIbottomChanPopUp") ==0)
				SVAR Chan = root:packages:twoP:examine:ROIbottomChan
			endif
			Chan =  pa.popStr
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Deletes selected ROIs in ROI list box
// Last Modified Seo 02 2010 by Jamie Boyd
Function twoP_DelRoiButtonProc (ba) : ButtonControl
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
Function twoP_NewRoiButtonProc(ba) : ButtonControl
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
				Button RoiNewbutton win=twoP_Controls, title = "Done", proc = twoP_DoneNewRoiButtonProc, fColor=(65535,0,0)
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
Function twoP_DoneNewRoiButtonProc(ba) : ButtonControl
	STRUCT WMbuttonAction &ba		
		
	switch( ba.eventCode )
		case 2: // mouse up
			controlinfo/w=twoP_Controls ROIonWindowPopup
			GraphNormal /W=$S_value
			Button RoiNewbutton win=twoP_Controls, title = "New", proc = twoP_NewRoiButtonProc, fColor=(0,0,0)
			break
	endSwitch
end

//******************************************************************************************************
// Lets user choose a folder and saves the path to the folder for subsequent loading and saving of ROIs
// Last Modified Jul 16 2010 by Jamie Boyd
Function twoP_ROIsetPathProc(ba) : ButtonControl
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
Function twoP_ROISaveProc(ba) : ButtonControl
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
// Deletes selected ROIS when delete key is pressed
// sets color in popmenu when ROI is selected
// Last Modified 2025/09/13 by Jamie Boyd
Function twoP_ROIListBoxProc(lba) : ListBoxControl
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
			WAVE/z ROIWAVE=$"root:twoP_ROIS:" +  listWave[row] + "_x"
			variable red = NumberByKey("Red", note (ROIWAVE))
			variable green = NumberByKey("Green", note (ROIWAVE))
			variable blue = NumberByKey("Blue", note (ROIWAVE))
			PopupMenu RoiColorPopup, win=$"twoP_Controls", popColor=(red,green,blue)
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
Function twoP_RoiNudgeProc(ba) : ButtonControl
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
				Button ROINudgeButton win=twoP_Controls, title = "Done", proc = twoP_RoiNudgeDoneButtonProc, fColor=(65535,0,0)
			endif
			break
	endSwitch
end

//******************************************************************************************************
// Translates trace offsets into X/Y offsets on the ROI and resets title and procedure for nudge button
// Last Modified Jul 22 2010 by Jamie Boyd
Function twoP_RoiNudgeDoneButtonProc(ba) : ButtonControl
	STRUCT WMbuttonAction &ba		
		
	switch( ba.eventCode )
		case 2: // mouse up
			Button ROINudgeButton, win=twoP_Controls, title = "Nudge", proc = twoP_RoiNudgeProc, fColor=(0,0,0)
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
Function twoP_ROIDuplicateButtonProc(ba) : ButtonControl
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
Function twoP_ROIRunButtonProc (ba) : ButtonControl
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
				doroiList = twoP_getScansByKeyValue (Key, ValueList)
			endif
			variable iScan, nScans = itemsinList (doroiList)
			string aScan
			for (iScan =0; iScan < nScans; iScan +=1)
				aScan = stringFromList (iScan, doroiList, ";")
				twoP_DoRoiFromList (aScan)
			endfor
			break
	endSwitch
end



Function twoP_DoRoiFromList (curScan)
	string curScan

	SVAR ScanNote = $"root:twoP_Scans:" + curscan  + ":" + curScan +  "_info"
	variable scanMode = numberByKey ("Mode", scanNote, "=", "\r")
	if (!(((scanMode == kLineScan) || (scanMode == kTimeSeries)) || (scanMode == kZseries)))
		doalert 0, "This function only works with a time series, a Z- series,  or a Line Scan."
		return 1
	endif
	// read some variables
	controlinfo/W=twoP_Controls ROIBackGrdCheck
	variable getDark = V_Value
	// check dark fluorescence, first check scan info and then check global variables
	STRUCT RectF darkRect
	darkRect.top = Nan
	darkRect.left = Nan
	darkRect.bottom = Nan
	darkRect.right = Nan
	if (getDark)
		darkRect.left = numberbykey ("DarkL", scanNote, "=", "\r")
		darkRect.right = numberbykey ("DarkR", scanNote, "=", "\r")
		if (scanMode != kLineScan)
			darkRect.top = numberbykey ("DarkT", scanNote, "=", "\r")
			darkRect.bottom = numberbykey ("DarkB", scanNote, "=", "\r")
		endif
		if (((numtype (darkRect.bottom) ==2) || (numtype (darkRect.top) ==2)) || ((scanMode != kLineScan) && ((numtype (darkRect.left) ==2) || (numtype (darkRect.right) ==2))))  // dark not set for this scan, so set it from globals
			NVAR/Z darkLG = root:packages:twoP:examine:darkL
			NVAR/Z darkRG = root:packages:twoP:examine:darkR
			if (scanMode != kLineScan)
				NVAR/Z darkBG = root:packages:twoP:examine:darkB
				NVAR/Z darkTG = root:packages:twoP:examine:darkT
			endif
			if	((!NVAR_Exists(darkTG)) || (!NVAR_Exists(darkBG)) || ((scanMode != kLineScan) && ((!NVAR_Exists(darkLG)) || (!NVAR_Exists(darkRG)))))
				doAlert 0, "No dark region has been set."
				return 1
			endif
			darkRect.bottom = darkBG
			darkRect.top = darkTG
			ScanNote = ReplaceNumberByKey("darkB", scanNote, darkRect.bottom, "=", "\r")
			ScanNote = ReplaceNumberByKey("darkT", scanNote, darkRect.top, "=", "\r")
			if (scanMode != kLineScan)
				darkRect.left = darkLG
				darkRect.right = darkRG
				ScanNote = ReplaceNumberByKey("darkL", scanNote, darkRect.left, "=", "\r")
				ScanNote = ReplaceNumberByKey("darkR", scanNote, darkRect.right, "=", "\r")
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
		SVAR TopChan = root:packages:twoP:examine:ROItopChan
		SVAR BottomChan = root:packages:twoP:examine:ROIbottomChan
		Wave/z topWave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_" + TopChan
		Wave/z bottomWave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_" + BottomChan
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
		numFrames =  numberbykey ("PixHeight", ScanNote, "=", "\r")
	else
		numFrames = numberbykey ("NumFrames", ScanNote, "=", "\r")
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
			setscale/P x 0,(numberbykey ("FrameTime",ScanNote, "=", "\r")),"s", RoiAvg
		elseif (scanMode == kLineScan)
			setscale/P x 0,(numberbykey ("LineTime",ScanNote, "=", "\r")),"s", RoiAvg
		elseif (scanMode == kZseries)
			setscale/P x (numberbykey ("ZPos",ScanNote, "=", "\r")),(numberbykey ("ZstepSize",ScanNote, "=", "\r")),"m", RoiAvg
		endif
		note RoiAvg, "ImWave:" + CurScan + ";ROI:" +ROIListWave [iROI] + ";Red:" + num2str (red) + ";Green:" + num2str (green) + ";Blue:" + num2str (blue) + ";deltafed:0;"
		// do the ROI
		if (scanMode == kLineScan)
			if (cmpStr (roiChan, "ratio") == 0)
				if (getDark)
					twoP_ROIdoSquareRatio(topWave, bottomWave, ROIListWave [iROI], ROIavg, darkRect=darkRect)
				else
					twoP_ROIdoSquareRatio(topWave, bottomWave, ROIListWave [iROI], ROIavg)
				endif
			else
				if (getDark)
					twoP_ROIdoLineScanAvg (chWave, ROIListWave [iROI], ROIavg, darkRect=darkRect)
				endif
			endif
		else // a 3D scan
			if (cmpStr (roiType, "ROISquare") == 0)
				if (cmpStr (roiChan, "ratio") == 0)
					if (getDark)
						twoP_ROIdoSquareRatio(topWave, bottomWave, ROIListWave [iROI], ROIavg, darkRect=darkRect)
					else
						twoP_ROIdoSquareRatio(topWave, bottomWave, ROIListWave [iROI], ROIavg)
					endif
				else
					if (getDark)
						twoP_ROIdoSquareAvg(chWave, ROIListWave [iROI], ROIavg, darkRect = darkRect)
					else
						twoP_ROIdoSquareAvg(chWave, ROIListWave [iROI], ROIavg)
					endif
				endif
			elseif (cmpStr (roiType, "ROIPoly") == 0)
				if (cmpStr (roiChan, "ratio") == 3)
					if (getDark)
						twoP_ROIdoPolyRatio(topWave, bottomWave, ROIListWave [iROI], ROIavg, darkRect=darkRect)
					else
						twoP_ROIdoPolyRatio(topWave, bottomWave, ROIListWave [iROI], ROIavg)
					endif
				else
					if (getDark)
						twoP_ROIdoPolyAvg(chWave, ROIListWave [iROI], ROIavg, darkRect=darkRect)
					else
						twoP_ROIdoPolyAvg(chWave, ROIListWave [iROI], ROIavg)
					endif
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
			twoP_AppendROIandAvg (ROIavg, ROIListWave [iROI], 1)
		else
			twoP_AppendROIandAvg (ROIavg, ROIListWave [iROI], 0)
		endif
	endfor
	//twoP_TracesGraphShareAxes ()
end



//******************************************************************************************************
// Processes a polygonal ROI avg, with optional dark subtraction
// Last Modified 2026/09/13 by Jamie Boyd
Function twoP_ROIdoPolyAvg(chWave, ROI, ROIavg, [darkRect])
	WAVE chWave
	string ROI
	wave ROIavg
	Struct rectF &darkRect
	
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
	if (!(paramIsDefault (darkRect)))  // calculate dark value
		variable darkAvg
		for (darkAvg =0, ii=0; ii < NumFrames; ii += 1)
			imagestats/GS={darkRect.left, darkRect.right, darkRect.bottom, darkRect.top}/P=(ii) chwave
			darkAvg += V_avg
		endfor
		darkAvg /= NumFrames
		RoiAvg -= darkAvg
	endif
	setdatafolder $savedFolder
end

//******************************************************************************************************
// Processes a polygonal ROI ratio, with optional dark subtraction
// Last Modified 2026/09/13 by Jamie Boyd
Function twoP_ROIdoPolyRatio(topWave, bottomWave, ROI, ROIratio, [darkRect])
	WAVE topWave, bottomWave
	string ROI
	wave ROIratio
	Struct rectF &darkRect
	
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
	variable darkAvgTop = 0, darkAvgBottom = 0
	if (!(paramIsDefault (darkRect)))  // calculate dark value
		for (darkAvgTop =0, darkAvgBottom=0, ii=0; ii < NumFrames; ii += 1)
			imagestats/GS={darkRect.left, darkRect.right, darkRect.bottom, darkRect.top}/P=(ii) topWave
			darkAvgTop += V_avg
			imagestats/GS={darkRect.left, darkRect.right, darkRect.bottom, darkRect.top}/P=(ii) bottomWave
			darkAvgBottom += v_avg
		endfor
		darkAvgTop/=NumFrames
		darkAvgBottom/=NumFrames
	endif
	// calculate ROI values
	for (ii=0; ii < NumFrames; ii += 1)
		imagestats/M=1/p = (ii) /r = ROImask topWave
		TopAvg = V_avg
		imagestats/M=1/p = (ii) /r = ROImask bottomWave
		ROIratio [ii] = (topAvg - darkAvgTop)/(V_avg - darkAvgBottom)
	endfor
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
