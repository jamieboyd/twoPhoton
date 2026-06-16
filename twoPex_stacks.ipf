#pragma rtGlobals=3
#pragma IgorVersion = 6.2
#pragma version = 2.0		// modification date: 2024/09/20 by Jamie Boyd

#include "twoP_threeD"
#include "GUIPMath"
//******************************************************************************************************
//------------------------------- Code for The Stacks tab on the 2P Examine TabControl--------------------------------------------
//******************************************************************************************************

// function for adding  the Stacks tab.
Function NQexStacks_add (able)
	variable able
	
	// Globals for Stacks Tab
	string/G root:Packages:twoP:examine:StacksSelChan
	variable/G root:packages:twoP:examine:ProjStartFrame
	variable/G root:packages:twoP:examine:ProjEndFrame
	variable/G root:packages:twoP:examine:ProjMode =0
	string/G root:Packages:twoP:examine:ProjOutName
	String/G root:Packages:twoP:examine:FiltOutName
	string/G root:Packages:twoP:examine:ProjDiff1
	string/G root:Packages:twoP:examine:ProjDiff2
	string/G root:packages:twoP:examine:Top3D
	string/G root:packages:twoP:examine:thisScanAdjustList = "ProjOutName:_proj;filtOutName:_f;"
	// controls for Stacks Tab
	// choose channel
	PopupMenu StackChansPopmenu, win =twoP_Controls,pos={13.00,415.00},size={55.00,20.00},bodyWidth=55,proc=twoP_StacksChansPopMenuProc
	PopupMenu StackChansPopmenu, win =twoP_Controls,title="Chan",fSize=12
	PopupMenu StackChansPopmenu, win =twoP_Controls,disable = able
	PopupMenu StackChansPopmenu, win =twoP_Controls,mode=0,value=#"twoP_ScanListImChans()"
	TitleBox SelStacksChansTitle, win =twoP_Controls,pos={73.00,417.00},size={19.00,15.00},fSize=12,frame=0
	TitleBox SelStacksChansTitle, win =twoP_Controls,variable=root:Packages:twoP:examine:StacksSelChan
	TitleBox SelStacksChansTitle, win =twoP_Controls, disable=able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","PopupMenu StackChansPopmenu 0;TitleBox SelStacksChansTitle 0;",applyAbleState=0)
	// Projections
	GroupBox ProjectionsGroup, win =twoP_Controls, pos={7.00,443.00},size={327.00,100.00},title="Projections",fSize=12,frame=0
	GroupBox ProjectionsGroup, win =twoP_Controls, disable=able
	Button ProjectImageButton, win =twoP_Controls,pos={13.00,463.00},size={51.00,20.00},proc=NQ_ProjectImageProc,title="Proj"
	Button ProjectImageButton, win =twoP_Controls, disable = able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","GroupBox ProjectionsGroup 0;Button ProjectImageButton 0;",applyAbleState=0)
	SetVariable StacksProjStartSetvariable, win =twoP_Controls, pos={75.00,465.00},size={76.00,18.00},proc=NQ_StackPosSetVarProc
	SetVariable StacksProjStartSetvariable, win =twoP_Controls, title="First",fSize=12
	SetVariable StacksProjStartSetvariable, win =twoP_Controls, limits={0,inf,1},value=root:Packages:twoP:examine:ProjStartFrame
	SetVariable StacksProjStartSetvariable, win =twoP_Controls, disable = able
	SetVariable StacksProjEndSetvariable, win =twoP_Controls, pos={157.00,465.00},size={71.00,18.00},proc=NQ_StackPosSetVarProc
	SetVariable StacksProjEndSetvariable, win =twoP_Controls, title="Last",fSize=12
	SetVariable StacksProjEndSetvariable, win =twoP_Controls, limits={1,inf,1},value=root:Packages:twoP:examine:ProjEndFrame
	SetVariable StacksProjEndSetvariable, win =twoP_Controls, disable = able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","SetVariable StacksProjStartSetvariable 0, 0;SetVariable StacksProjEndSetvariable 0;",applyAbleState=0)
	CheckBox StacksAvgCheck, win =twoP_Controls,pos={240.00,466.00},size={38.00,15.00},proc=GUIPRadioButtonProc
	CheckBox StacksAvgCheck, win =twoP_Controls,title="Avg",userdata="StacksAvgCheck;StacksMaxCheck;"
	CheckBox StacksAvgCheck, win =twoP_Controls,userdata(gValue)="root:packages:twoP:examine:ProjMode"
	CheckBox StacksAvgCheck, win =twoP_Controls,fSize=12,value=0,mode=1
	CheckBox StacksAvgCheck, win =twoP_Controls,disable = able
	CheckBox StacksMaxCheck, win =twoP_Controls,pos={287.00,466.00},size={40.00,15.00},proc=GUIPRadioButtonProc
	CheckBox StacksMaxCheck, win =twoP_Controls,title="Max",userdata="StacksAvgCheck;StacksMaxCheck;"
	CheckBox StacksMaxCheck, win =twoP_Controls,userdata(gValue)="root:packages:twoP:examine:ProjMode"
	CheckBox StacksMaxCheck, win =twoP_Controls,fSize=12,value=1,mode=1
	CheckBox StacksMaxCheck, win =twoP_Controls,disable = able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","CheckBox StacksAvgCheck 0;CheckBox StacksMaxCheck 0;",applyAbleState=0)
	SetVariable StacksOutNameSetvar, win =twoP_Controls,pos={11.00,493.00},size={195.00,18.00}
	SetVariable StacksOutNameSetvar, win =twoP_Controls,title="OutPut Name",fSize=12
	SetVariable StacksOutNameSetvar, win =twoP_Controls,value=root:Packages:twoP:examine:ProjOutName
	SetVariable StacksOutNameSetvar, win =twoP_Controls,disable=able
	PopupMenu DisplayProjsPopMenu, win =twoP_Controls,pos={216.00,493.00},size={103.00,20.00},proc=NQ_DisplayProjectImProc
	PopupMenu DisplayProjsPopMenu, win =twoP_Controls,title="Display Proj"
	PopupMenu DisplayProjsPopMenu, win =twoP_Controls,mode=0,value=#"GUIPListWavesbyNoteKey (\"root:twoP_Scans:\" + root:packages:twoP:examine:curScan, \"ProjType\", \"*\", 0,  \"\\\\M1(No Projections\", listSepStr=\"\\r\", keySepStr=\":\")"
	PopupMenu DisplayProjsPopMenu, win =twoP_Controls,disable=able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","PopupMenu DisplayProjsPopMenu 0;SetVariable StacksOutNameSetvar 0;",applyAbleState=0)
	Button AvgDiffButton, win =twoP_Controls,pos={10.00,518.00},size={45.00,20.00},proc=NQ_ProjSubtracter
	Button AvgDiffButton, win =twoP_Controls,title="Diff",fSize=13
	Button AvgDiffButton, win =twoP_Controls, disable=able
	PopupMenu StackDiffPopMenu1, win =twoP_Controls,pos={58.00,518.00},size={20.00,20.00},proc=NQ_StacksSetDiffPopMenuProc
	PopupMenu StackDiffPopMenu1, win =twoP_Controls,mode=0,value=#"GUIPListWavesbyNoteKey (\"root:twoP_Scans:\" + root:packages:twoP:examine:curScan, \"ProjType\", \"*\", 0,  \"\\\\M1(No Projections\", listSepStr=\"\\r\", keySepStr=\":\")"
	PopupMenu StackDiffPopMenu1, win =twoP_Controls, disable=able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","Button AvgDiffButton 0;PopupMenu StackDiffPopMenu1 0;PopupMenu StackDiffPopMenu2 0;",applyAbleState=0)
	SetVariable StacksDiff1Setvar, win =twoP_Controls,pos={80.00,519.00},size={94.00,18.00},title=" "
	SetVariable StacksDiff1Setvar, win =twoP_Controls,fSize=12,frame=0
	SetVariable StacksDiff1Setvar, win =twoP_Controls,value=root:Packages:twoP:examine:ProjDiff1,noedit=1
	SetVariable StacksDiff1Setvar, win =twoP_Controls,disable=able
	PopupMenu StackDiffPopMenu2, win =twoP_Controls,pos={188.00,518.00},size={42.00,20.00},proc=NQ_StacksSetDiffPopMenuProc
	PopupMenu StackDiffPopMenu2, win =twoP_Controls,title="-"
	PopupMenu StackDiffPopMenu2, win =twoP_Controls,mode=0,value=#"GUIPListWavesbyNoteKey (\"root:twoP_Scans:\" + root:packages:twoP:examine:curScan, \"ProjType\", \"*\", 0,  \"\\\\M1(No Projections\", listSepStr=\"\\r\", keySepStr=\":\")"
	PopupMenu StackDiffPopMenu2, win =twoP_Controls,disable=able
	SetVariable StacksDiff2Setvar, win =twoP_Controls,pos={233.00,519.00},size={96.00,18.00},title=" "
	SetVariable StacksDiff2Setvar, win =twoP_Controls,fSize=12,frame=0
	SetVariable StacksDiff2Setvar, win =twoP_Controls,value=root:Packages:twoP:examine:ProjDiff2,noedit=1
	SetVariable StacksDiff2Setvar, win =twoP_Controls,disable=able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","SetVariable StacksDiff1Setvar 0;SetVariable StacksDiff2Setvar 0;",applyAbleState=0)
	// filering
	GroupBox FilterGroup, win =twoP_Controls,pos={7.00,548.00},size={326.00,74.00}
	GroupBox FilterGroup, win =twoP_Controls,title="Spatial Filtering",fSize=12,frame=0
	GroupBox FilterGroup, win =twoP_Controls,disable=able
	Button FilterButton, win =twoP_Controls,pos={12.00,566.00},size={52.00,20.00},proc=NQ_FilterButtonProc
	Button FilterButton, win =twoP_Controls,title="Filter"
	Button FilterButton, win =twoP_Controls,disable=able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","GroupBox FilterGroup 0;Button FilterButton 0;",applyAbleState=0)
	PopupMenu FilterTypePopUp, win =twoP_Controls,pos={72.00,565.00},size={108.00,20.00},title="Type",fSize=12
	PopupMenu FilterTypePopUp, win =twoP_Controls,mode=2,popvalue="Median",value=#"\"Gaus;Median;\""
	PopupMenu FilterTypePopUp, win =twoP_Controls,disable=able
	PopupMenu FilterWidthPopUp, win =twoP_Controls,pos={186.00,564.00},size={80.00,20.00}
	PopupMenu FilterWidthPopUp, win =twoP_Controls,title="Width",fSize=12
	PopupMenu FilterWidthPopUp, win =twoP_Controls,mode=1,popvalue="3",value=#"\"3;5;7;9;11;13;15;\""
	PopupMenu FilterWidthPopUp, win =twoP_Controls,disable=able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","PopupMenu FilterTypePopUp 0;PopupMenu FilterWidthPopUp 0;",applyAbleState=0)
	PopupMenu FilterPassesPopUp, win =twoP_Controls,pos={272.00,565.00},size={53.00,20.00},title="X"
	PopupMenu FilterPassesPopUp, win =twoP_Controls,mode=1,popvalue="1",value=#"\"1;2;3;4;5\"",fSize=12
	PopupMenu FilterPassesPopUp, win =twoP_Controls,disable=able
	CheckBox FIltNewScanCheck, win =twoP_Controls,pos={11.00,593.00},size={74.00,16.00}
	CheckBox FIltNewScanCheck, win =twoP_Controls,title="New Scan"
	CheckBox FIltNewScanCheck, win =twoP_Controls,help={"If checked, a filtered wave will be placed in a new scan folder with the given name, else the original wave will be overwritten"}
	CheckBox FIltNewScanCheck, win =twoP_Controls,fSize=12,value=1
	CheckBox FIltNewScanCheck, disable=able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","PopupMenu FilterPassesPopUp 0;CheckBox FIltNewScanCheck 0;",applyAbleState=0)
	SetVariable StacksfiltOutNameSetvar, win =twoP_Controls,pos={89.00,592.00},size={175.00,18.00}
	SetVariable StacksfiltOutNameSetvar, win =twoP_Controls,value=root:Packages:twoP:examine:FiltOutName
	SetVariable StacksfiltOutNameSetvar, win =twoP_Controls,title="name",fSize=12
	SetVariable StacksfiltOutNameSetvar, win =twoP_Controls,disable=able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","SetVariable StacksfiltOutNameSetvar 0;",applyAbleState=0)
	// 3D slicer
	Button ThreeDSliceButton,win =twoP_Controls,pos={10.00,629.00},size={64.00,20.00},proc=NQ_3DslicerProc
	Button ThreeDSliceButton,win =twoP_Controls,title="3D-Slicer",fSize=12
	Button ThreeDSliceButton,win =twoP_Controls,disable=able
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","Button ThreeDSliceButton 0;",applyAbleState=0)
end



// ***********************************************************************************
// sets channel tto project or filter
// Last Modified: 2025/09/20 by Jamie Boyd
Function twoP_StacksChansPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			SVAR theChan = root:Packages:twoP:examine:StacksSelChan
			theChan = pa.popStr
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End


//****************************************************************************************************
// Lists channels for stacks, marking with checkmarks ones already displayed
// Last Modified: 2025/09/20 by Jamie Boyd
function/S twoP_StacksListChans()
	SVAR curScan = root:packages:twoP:examine:curScan
	SVAR/Z scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
	if (SVAR_EXISTS(scanStr))
		string chanList = StringByKey("imChanDesc", scanStr, ":", "\r")
		SVAR selChans = root:packages:twoP:examine:StacksSelChans
		variable iChan, nChans = itemsInList(chanList, ",")
		string aChan, outList = ""
		for (iChan =0; iChan < nChans; iChan += 1)
			aChan = stringfromlist (iChan, chanList, ",")
				if (FindListItem(aChan, selChans, ",") > -1)
					outList += "\\M1!"  +num2char(18)
				endif
				outList += aChan + ";"
		endfor
		return outList
	else
		return ""
	endif
end


//******************************************************************************************************
// Sets the default name for a filtered stack from the name of the current scan + "_f"
// last modified Jul 24 2011 by Jamie Boyd
Function NQexStacks_Update()

	SVAR filtOutName = root:packages:twoP:examine:filtOutName
	SVAR projOutName = root:packages:twoP:examine:ProjOutName
	SVAR curScan =root:packages:twoP:examine:curScan
	filtOutName = curScan
	controlinfo/w=twoP_Controls FIltNewScanCheck
	if (V_Value == 1)
		filtOutName	 +=  "_f"
	endif
	projOutName = curScan + "_proj"
end


//******************************************************************************************************
// If shift key is pressed, sets the first or last frame for a projection image to the current frame position on the frames slider
// Last Modified Jul 15 2010 by Jamie Boyd
Function NQ_StackPosSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
			if (sva.eventmod & 2)
				NVAR pos = $"root:packages:twoP:examine:" + sva.vName
				NVAR curFramePos = root:packages:twoP:examine:curFramePos
				pos =  curFramePos
				break
			endif
	endswitch

	return 0
End

//******************************************************************************************************
// Makes either a Maximum Intensity Projection or an Average Intensity Projection over a range of Framed for a 3D scan
// Last modified 2016/11/20 by Jamie Boyd
Function NQ_ProjectImageProc(ba) : ButtonControl
	STRUCT wmbuttonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
	
			SVAR CurScan = root:Packages:twoP:examine:curScan
			SVAR infoString = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
			variable scanMode = NumberByKey("Mode", infoString, ":", "\r")
			if (!((scanMode == kTimeSeries) || (scanMode == kZseries)))
				doalert 0, "This function only works with a Time Series or a Z-stack."
				return 1
			endif
			// Check what to do
			SVAR projChan = root:Packages:twoP:examine:StacksSelChan
			if (cmpstr (projChan, "") ==0)
				doAlert 0, "First choose a channel to for which to make the projection."
				return 1
			endif
			NVAR startFrame = root:packages:twoP:examine:ProjStartFrame
			NVAR endFrame = root:packages:twoP:examine:ProjEndFrame
			SVAR outName = root:packages:twoP:examine:ProjOutName
			outName = cleanUpName (outName, 0)
			NVAR isMax = root:packages:twoP:examine:ProjMode // 0 = avg, 1=max

			// Check that first and last frames are within range
			variable numFrames = numberbykey ("NumFrames", infoString, ":", "\r")
			if (endFrame >= numFrames)
				endFrame = numFrames -1
			endif
			if (startFrame < 0)
				startFrame = 0
			endif
			if (startFrame >= EndFrame)
				doAlert 0, "Last Frame must be greater than First Frame."
				return 0
			endif
			string outWaveName = outName + "_" +  num2str(startFrame) + "_" +  num2str (endFrame) + "_" + projChan
			WAVE scanWave = $"root:twoP_Scans:" + curScan + ":" + curScan + "_" + projChan
			// make a 2D image wave to hold results of project image
			make/o/y=(wavetype (scanWave))/n= ((dimsize (scanWave,0)), (dimsize (scanWave, 1))) $"root:twoP_Scans:" + curScan + ":" + outWaveName
			WAVE projWave =$"root:twoP_Scans:" + curScan + ":" + outWaveName
			SetScale/P x (dimOffset (scanWave, 0)), (dimDelta (scanWave, 0)), "m", projWave
			SetScale/P Y (dimOffset (scanWave, 1)), (dimDelta (scanWave, 1)), "m", projWave
			if (isMax)
				ProjectSpecFrames (scanWave, startFrame, endFrame, projwave, 0, 2, 0)
				note projWave "ProjType:Max\rstartFrame:" + num2str (startFrame) + "\r" + "endFrame:" + num2str (endFrame) + "\r"
			else
				KalmanSpecFrames (scanWave, startframe, endframe, projwave, 0,16)
				note projWave "ProjType:Avg\rstartFrame:" + num2str (startFrame) + "\r" + "endFrame:" + num2str (endFrame) + "\r"
			endif

			break
	endSwitch
	return 0
end



			// also make a red green merge
			if (stackChan & 4) 
				outWaveName = outName +  "_mrg" 
				make/o/w/u/n= ((dimsize (scanWave,0)), (dimsize (scanWave, 1)), 3) $"root:twoP_Scans:" + curScan + ":" + outWaveName
				WAVE projWave =$"root:twoP_Scans:" + curScan + ":" + outWaveName
				projWave [] [] [2] = 0
				SetScale/P x (dimOffset (ScanWave, 0)), (dimDelta (ScanWave, 0)), "m", projWave
				SetScale/P Y (dimOffset (scanWave, 1)), (dimDelta (scanWave, 1)), "m", projWave
				if (isMax)
					note projWave "ProjType:Max\rstartFrame:" + num2str (startFrame) + "\r" + "endFrame:" + num2str (endFrame) + "\r"
				else
					note projWave "ProjType:Avg\rstartFrame:" + num2str (startFrame) + "\r" + "endFrame:" + num2str (endFrame) + "\r"
				endif
				ChanStr =  "_ch" + num2str (kNQRedChan) 
				outWaveName = outName + chanStr
				WAVE redWave =  $"root:twoP_Scans:" + curScan + ":" + outWaveName 
				ChanStr =  "_ch" + num2str (kNQGreenChan) 
				outWaveName = outName + chanStr
				WAVE greenWave =  $"root:twoP_Scans:" + curScan + ":" + outWaveName 
				NVAR FirstColor = $"root:packages:twoP:examine:CH" + num2str (kNQRedChan) + "FirstLutColor"
				NVAR LastColor = $"root:packages:twoP:examine:CH" +  num2str (kNQRedChan)  + "LastLutColor"
				variable range = lastColor - firstColor + 1
				projWave [] [] [0]  = redWave [p] [q] < FirstColor ? 0 : (redWave [p] [q]  > lastColor ? lastColor : (redWave [p] [q] - FirstColor) *  65536 /range)
				NVAR FirstColor = $"root:packages:twoP:examine:CH" + num2str (kNQGreenChan) + "FirstLutColor"
				NVAR LastColor = $"root:packages:twoP:examine:CH" +  num2str (kNQGreenChan)  + "LastLutColor"
				range = lastColor - firstColor
				projWave [] [] [1]  = greenWave[p] [q]  < FirstColor ? 0 : (greenWave[p] [q] > lastColor ? lastColor : (greenWave[p] [q]  - FirstColor) *  65536 /range)
				pa.popStr = nameofwave (projWave)
				NQ_DisplayProjectImProc (pa) 
			endif
			break
	endSwitch
	return 0
end

//******************************************************************************************************
// Displays a projection Image from the current scan
// Last modified Jul 15 2010 by Jamie Boyd
Function NQ_DisplayProjectImProc (pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			SVAR curScan = root:Packages:twoP:examine:curScan
			WAVE Projwave = $"root:twoP_Scans:" + curScan + ":" + pa.popstr
			display/N=$pa.popstr as pa.popStr; appendimage Projwave
			ModifyGraph nticks=0,noLabel=2,  margin=1, height={Plan,1,left,bottom}
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Sets a projection Image from the current scan for subtracting, or being subtracted from
// Last modified Jul 15 2010 by Jamie Boyd
Function NQ_StacksSetDiffPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			string tstr = pa.ctrlname
			string diff = tstr [strlen (tstr)-1]
			SVAR diffStr = $"root:packages:twoP:examine:ProjDiff" + diff
			diffStr = pa.popStr
			break
	endswitch

	return 0
End

//******************************************************************************************************
// Subtracts one projection from another. Useful for seeing changes over time.
// Last Modified Jul 15 by Jamie Boyd
Function NQ_ProjSubtracter (ba) : ButtonControl
	STRUCT wmbuttonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
		
			SVAR curScan = root:packages:twoP:examine:curScan
			SVAR ProjDiff1 = root:packages:twoP:examine:ProjDiff1
			WAVE/z Proj1 = $"root:twoP_Scans:" + curScan + ":" + ProjDiff1
			SVAR ProjDiff2= root:packages:twoP:examine:ProjDiff2
			WAVE/z Proj2 = $"root:twoP_Scans:" + curScan + ":" + ProjDiff2
			if (!((waveExists (proj1)) && (waveExists (proj2))))
				doAlert 0, "Waves for making a difference image could not be found."
				return 1
			endif
			Proj1 -= Proj2
			redimension/w proj1
			//proj1 -= (kNQtoUnsigned)
			string temp = note (proj1)
			temp = ReplaceStringByKey("ProjType", temp, "Subtr", ":" , "\r")
			variable subStart = NumberByKey("startFrame", note (proj2) , ":" , "\r") 
			variable subEnd =  NumberByKey("endFrame", note (proj2) , ":" , "\r") 
			temp =ReplaceNumberByKey("subStartFrame", temp, subStart, ":" , "\r")
			temp =ReplaceNumberByKey("subEndFrame", temp, subEnd, ":" , "\r")
			note/K Proj1
			note Proj1, temp
			STRUCT WMPopupAction pa
			pa.eventCode = 2
			pa.popStr = nameofwave (Proj1)
			NQ_DisplayProjectImProc (pa) 
			break
	endswitch
	return 0
End

// makes a 2D Gaussian kernel un
function/wave NQ_make2DKernel (width)
	variable width
	if (mod (width, 2) ==0)
		width +=1
	endif
	make/FREE/o/s/n= (width, width) gWave
	setscale/I x -pi,pi, "m" gWave
	setscale/I y -pi, pi, "m" gWave
	gWave = Gauss (x, 0, 1, y, 0, 1)
	variable sumVal =  sum (gwave)
	gwave /= sumVal
	return gwave
end

// makes a 1D Gaussian kernel 
function/wave NQ_makeSymkernel (width)
	variable width
	if (mod (width, 2) ==0)
		width +=1
	endif
	make/FREE/o/s/n= (width) gWave
	setscale/I x -pi,pi, "m" gWave
	gWave = Gauss (x, 0, 1)
	variable sumVal =  sum (gwave)
	gwave /= sumVal
	return gwave
end

//******************************************************************************************************
//Filters each frame in a 3D image, or filters a single 2D image
// Last Modified 2016/10/28 by Jamie Boyd
Function NQ_FilterButtonProc(ba) : ButtonControl
	STRUCT WMbuttonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up

			SVAR curScan = root:packages:twoP:examine:curScan
			SVAR infoStr = $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_info"
			//variable mode = NumberByKey("Mode", infoStr, ":", "\r")
			SVAR selChan = root:Packages:twoP:examine:StacksSelChan
			WAVE Scanwave =  $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_" + selChan
			// read controls
			controlinfo /W= twoP_Controls FilterWidthPopUp
			variable width = str2num (S_value)
			controlinfo /W= twoP_Controls FilterPassesPopUp
			variable passes = str2num (s_value)
			controlinfo /W= twoP_Controls FilterTypePopUp
			string filterType = S_Value
			string outputpath
			controlinfo/w=twoP_Controls FIltNewScanCheck
			string copyName
			variable isNewScan = V_Value
			if (isNewScan)
				SVAR outputFolder = root:packages:twoP:examine:filtOutName
				outPutFolder = CleanupName(outPutFolder, 0)
				outputpath = "root:twoP_Scans:" + outputFolder + ":" + outputFolder + "_" + selChan
				DFREF tofolderRef = $"root:twoP_Scans:" + outputFolder
				DFREF fromfolderRef = $"root:twoP_Scans:" + curScan
				if (!(DataFolderRefStatus(tofolderRef)))
					newdatafolder/o $"root:twoP_scans:" + outputFolder
					DFREF tofolderRef = root:twoP_scans:$outputFolder
					String/G $"root:twoP_Scans:" + outputFolder + ":" + outputFolder + "_info" = infoStr
					variable iWave, nWaves = CountObjectsDFR(fromfolderRef, 1 )
					for (iWave =0; iWave < nWaves; iWave +=1)
						copyName =GetIndexedObjNameDFR(fromfolderRef, 1, iWave)
						WAVE aWave = $"root:twoP_scans:" + curScan + ":" + copyName
						if (!(WaveRefsEqual(aWave , Scanwave)))
							copyName=replacestring (curScan,copyName, outPutFolder)
							duplicate/o aWave $"root:twoP_scans:" + outputFolder + ":" + copyName
						endif
					endfor
				else
					WAVE toWave=$outputpath
					if (waveexists (toWave))
						fastop toWave = Scanwave
						WAVE Scanwave = toWave
					endif
				endif
			else
				outputpath = "root:twoP_Scans:" + curScan + ":" + curScan + "_" + selChan
			endif

			strswitch (filterType)
				case "Gaus":
					NQ_GausConvolve (Scanwave, passes, width, outputpath)
					break
				case "Median":
					NQ_Median (Scanwave, passes, width, outputPath)
					break
			endswitch
			WAVE outWave = $outputpath
			SetScale/P x,  (dimOffset(Scanwave, 0)), (dimDelta (Scanwave, 0)), "m", outwave
			SetScale/P y,  (dimOffset(Scanwave, 1)), (dimDelta (Scanwave, 1)), "m", outwave
			SetScale/P z,  (dimOffset(Scanwave, 2)), (dimDelta (Scanwave, 2)), "m", outwave
			Note outwave note (Scanwave)
			break
	endswitch
end

//******************************************************************************************************
//Gaussian filters each frame in a 3D image, or filters a single 2D image
// Last Modified:
// 2016/11/21 by Jamie Boyd added passes paramater
Function NQ_GausConvolve (theWave, passes, width, outputPath)
	WAVE thewave
	variable passes
	variable width
	string outputPath
	
	SymConvolveFrames (theWave, outputPath, 0, NQ_makeSymkernel (width), 1)
	if (passes > 1)
		variable iPass
		WAVE outWave = $outputPath
		for (iPass =1; iPass < passes; iPass +=1)
			SymConvolveFrames (outWave, outputPath, 0, NQ_makeSymkernel (width), 1) 
		endfor
	endif
end


//******************************************************************************************************
//Hybrid-median filters each frame in a 3D image, or filters a single 2D image
// Last Modified Jul 15 by Jamie Boyd
Function NQ_HybridMedian (theWave, passes, outWave)
	Wave thewave
	variable passes
	wave outwave
	
	if (waveDims (theWave)== 3)
		variable ii, zsize =  dimsize (thewave, 2)
		for (ii =0; ii < zsize; ii += 1)
			ImageTransform/o /P = (ii) getPlane theWave
			WAVE M_ImagePlane
			ImageFilter  /P=(passes) hybridmedian  M_ImagePlane
			WAVE M_HybridMedian
			ImageTransform/P= (ii)/D = M_HybridMedian setPlane outwave
		endfor
	elseif (WaveDims (theWave) ==2)
		if (cmpStr (getwavesdatafolder(theWave,2), getwavesdatafolder(outWave,2)) ==0)
			ImageFilter/o/P=(passes) hybridmedian theWave
		else
			outWave = theWave
			ImageFilter/o/P=(passes) hybridmedian  outwave
		endif
	endif
end

//******************************************************************************************************
//Median filters each frame in a 3D image, or filters a single 2D image
// Last Modified:
// 2016/11/21 by Jamie Boyd added passes paramater
//******************************************************************************************************
//Median filters each frame in a 3D image, or filters a single 2D image
// Last Modified Jul 15 by Jamie Boyd
Function NQ_Median (theWave, passes, width, outPutPath)
	WAVE thewave
	variable passes
	variable width
	string  outPutPath
	
	MedianFrames (theWave, outPutPath, width, 1) 
	if (passes > 1)
		variable iPass
		WAVE outWave = $outputPath
		for (iPass =1; iPass < passes; iPass +=1)
			MedianFrames (outWave, outputPath, width, 1) 
		endfor
	endif
end

