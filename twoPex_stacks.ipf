#pragma rtGlobals=3
#pragma IgorVersion = 6.2
#pragma version = 2.0		// modification date: 2014/09/18 by Jamie Boyd

#include "twoP_threeD"
#include "GUIPMath"
//******************************************************************************************************
//------------------------------- Code for The Stacks tab on the 2P Examine TabControl--------------------------------------------
//******************************************************************************************************

// function for adding  the Stacks tab.
Function NQexStacks_add (able)
	variable able
	
	// Globals for Stacks Tab
	variable/G root:packages:twoP:examine:StackChan=1
	variable/G root:packages:twoP:examine:ProjStartFrame
	variable/G root:packages:twoP:examine:ProjEndFrame
	string/G root:packages:twoP:examine:ProjDiff1
	string/G root:packages:twoP:examine:ProjDiff2
	string/G root:packages:twoP:examine:ProjOutName = ""
	string/G root:packages:twoP:examine:FiltOutName =""
	string/G root:packages:twoP:examine:Top3D
	string/G root:packages:twoP:examine:thisScanAdjustList = "ProjOutName:_proj;filtOutName:_f;"
	// controls for Stacks Tab
	CheckBox StacksCheck1,  win =twoP_Controls, disable =1, pos={11,411},size={58,16},proc=NQ_stacksChanCheckProc,title="Chan 1"
	CheckBox StacksCheck1,win =twoP_Controls,userdata=  "threeDsliceCheck2;threeDsliceCheck3;"
	CheckBox StacksCheck1,win =twoP_Controls,fSize=12,value= 1
	CheckBox StacksCheck2, win =twoP_Controls,disable =1,pos={84,411},size={58,16},proc=NQ_stacksChanCheckProc,title="Chan 2"
	CheckBox StacksCheck2,win =twoP_Controls,userdata=  "threeDsliceCheck1;threeDsliceCheck3;"
	CheckBox StacksCheck2,win =twoP_Controls,fSize=12,value= 0
	CheckBox StacksCheck4, win =twoP_Controls,disable =1,pos={153,411},size={60,16},proc=NQ_stacksChanCheckProc,title="Merged"
	CheckBox StacksCheck4,win =twoP_Controls,userdata=  "threeDsliceCheck1;threeDsliceCheck2;"
	CheckBox StacksCheck4,win =twoP_Controls,fSize=12,value= 0
	// Projections
	GroupBox ProjectionsGroup, win =twoP_Controls,disable =1,pos={7,433},size={276,93},title="Projections"
	GroupBox ProjectionsGroup,win =twoP_Controls,frame=0
	Button ProjectImageButton, win =twoP_Controls,disable =1,pos={13,449},size={30,20},proc=NQ_ProjectImageProc,title="Proj"
	SetVariable StacksProjStartSetvariable, win =twoP_Controls,disable =1,pos={48,452},size={71,15},proc=NQ_StackPosSetVarProc,title="First"
	SetVariable StacksProjStartSetvariable,win =twoP_Controls,limits={0,inf,1},value= root:packages:twoP:examine:ProjStartFrame
	SetVariable StacksProjEndSetvariable, win =twoP_Controls,disable =1,pos={125,452},size={68,15},proc=NQ_StackPosSetVarProc,title="Last"
	SetVariable StacksProjEndSetvariable,win =twoP_Controls,limits={1,inf,1},value= root:packages:twoP:examine:ProjEndFrame
	CheckBox StacksAvgCheck, win =twoP_Controls,disable =1,pos={199,452},size={35,14},proc=GUIPRadioButtonProc,title="Avg"
	CheckBox StacksAvgCheck,win =twoP_Controls,userdata=  "StacksMaxCheck;",value= 1,mode=1
	CheckBox StacksMaxCheck, win =twoP_Controls,disable =1,pos={241,452},size={35,14},proc=GUIPRadioButtonProc,title="Max"
	CheckBox StacksMaxCheck,win =twoP_Controls,userdata=  "StacksAvgCheck;",value= 0,mode=1
	Button AvgDiffButton, win =twoP_Controls,disable =1,pos={13,476},size={30,20},proc=NQ_ProjSubtracter,title="Diff"
	Button AvgDiffButton,win =twoP_Controls,fSize=13
	PopupMenu StackDiffPopMenu1,win =twoP_Controls,disable = 1, pos={47,476},size={21,21},proc=NQ_StacksSetDiffPopMenuProc
	PopupMenu StackDiffPopMenu1,win =twoP_Controls,mode=0,value= #"GUIPListWavesbyNoteKey (\"root:twoP_Scans:\" + root:packages:twoP:examine:curScan, \"ProjType\", \"*\", 0,  \"\\\\M1(No Projections\", listSepStr=\"\\r\", keySepStr=\":\")"
	SetVariable StacksDiff1Setvar, win =twoP_Controls,disable = 1, pos={71,479},size={84,16},title=" "
	SetVariable StacksDiff1Setvar,win =twoP_Controls,value= root:Packages:twoP:examine:ProjDiff1,noedit= 1
	PopupMenu StackDiffPopMenu2,win =twoP_Controls,disable =1,pos={159,476},size={32,21},proc=NQ_StacksSetDiffPopMenuProc,title="-"
	PopupMenu StackDiffPopMenu2,win =twoP_Controls,mode=0,value= #"GUIPListWavesbyNoteKey (\"root:twoP_Scans:\" + root:packages:twoP:examine:curScan, \"ProjType\", \"*\", 0,  \"\\\\M1(No Projections\", listSepStr=\"\\r\", keySepStr=\":\")"
	SetVariable StacksDiff2Setvar, win =twoP_Controls,disable =1,pos={196,479},size={80,15},title=" "
	SetVariable StacksDiff2Setvar,win =twoP_Controls,value= root:packages:twoP:examine:ProjDiff2,noedit= 1
	SetVariable StacksOutNameSetvar, win =twoP_Controls,disable =1,pos={14,505},size={157,15},title="OutPut Name"
	SetVariable StacksOutNameSetvar,win =twoP_Controls,value= root:packages:twoP:examine:ProjOutName
	PopupMenu DisplayProjsPopMenu, win =twoP_Controls,disable =1,pos={181,501},size={96,20},proc=NQ_DisplayProjectImProc,title="Display Proj",mode=0
	PopupMenu DisplayProjsPopMenu,win =twoP_Controls, value= #"GUIPListWavesbyNoteKey (\"root:twoP_Scans:\" + root:packages:twoP:examine:curScan, \"ProjType\", \"*\", 0,  \"\\\\M1(No Projections\", listSepStr=\"\\r\", keySepStr=\":\")"
	// filering
	GroupBox FilterGroup, win =twoP_Controls,disable =1,pos={7,528},size={276,66},title="Spatial Filtering"
	GroupBox FilterGroup,win =twoP_Controls,frame=0
	PopupMenu FilterTypePopUp,win =twoP_Controls, disable =1,pos={8,544},size={94,20},title="Type"
	PopupMenu FilterTypePopUp,win =twoP_Controls,mode=2,popvalue="Median",value= #"\"Gaus;Median;Hybrid Median(5x5)\""
	PopupMenu FilterWidthPopUp, win =twoP_Controls,disable =1,pos={178,545},size={54,20},title="Wid"
	PopupMenu FilterWidthPopUp,win =twoP_Controls,mode=1,popvalue="3",value= #"\"3;5;7;9;11;13;15;\""
	PopupMenu FilterPassesPopUp,win =twoP_Controls, disable =1,pos={237,546},size={43,20},title="X"
	PopupMenu FilterPassesPopUp,win =twoP_Controls,mode=1,popvalue="1",value= #"\"1;2;3;4;5\""
	CheckBox FIltNewScanCheck,win =twoP_Controls, disable =1,pos={9,573},size={60,14},title="New Scan"
	CheckBox FIltNewScanCheck, win =twoP_Controls, help={"If checked, a filtered wave will be placed in a new scan folder with the given name, else the original wave will be overwritten"}
	CheckBox FIltNewScanCheck,win =twoP_Controls,value= 1
	SetVariable StacksfiltOutNameSetvar, win =twoP_Controls,disable =1,pos={80,573},size={115,15},title="name"
	SetVariable StacksfiltOutNameSetvar,win =twoP_Controls,value= root:packages:twoP:examine:FiltOutName
	Button FilterButton,win =twoP_Controls, disable =1,pos={228,571},size={52,18},proc=NQ_FilterButtonProc,title="Filter"
	// 3D slicer
	Button ThreeDSliceButton, win =twoP_Controls,disable =1,pos={9,599},size={64,20},proc=NQ_3DslicerProc,title="3D-Slicer"
	Button ThreeDSliceButton,win =twoP_Controls,fSize=12
	// Add "Stacks" controls to dataBase
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","Checkbox StacksCheck1 0;Checkbox StacksCheck2 0;Checkbox StacksCheck4 0;groupbox ProjectionsGroup 0;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","Button ProjectImageButton 0;Setvariable StacksProjStartSetvariable 0;Setvariable StacksProjEndSetvariable 0;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","Checkbox StacksAvgCheck 0;Checkbox StacksAvgCheck 0;Checkbox StacksMaxCheck 0;Button AvgDiffButton 0;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","Popupmenu StackDiffPopMenu1 0;Setvariable StacksDiff1Setvar 0;Popupmenu StackDiffPopMenu2 0;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","Setvariable StacksDiff2Setvar 0;Setvariable StacksOutNameSetvar 0;Popupmenu DisplayProjsPopMenu 0;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","Groupbox FilterGroup 0;Popupmenu FilterTypePopUp 0;Popupmenu FilterWidthPopUp 0;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","Popupmenu FilterPassesPopUp 0;Checkbox FIltNewScanCheck 0;Setvariable StacksfiltOutNameSetvar 0;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "Stacks","Button FilterButton 0;Button ThreeDSliceButton 0;")
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
//Manages the channel selection radio buttons, setting a global variable to process either channel, or both channels/merged channel as appropriate
// Last Modified Jul 27 2010 by Jamie Boyd
Function NQ_stacksChanCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			string tStr = cba.ctrlName 
			variable chan= str2num (tStr[strlen (tStr)-1])
			NVAR stackChan = root:packages:twoP:examine:StackChan
			if (cba.checked)
				SVAR curScan = root:packages:twoP:examine:curScan
				if (cmpStr (curScan, "LiveWave") == 0)
					SVAR scanStr =root:packages:twoP:Acquire:LiveModeScanStr
				else
					SVAR scanStr = $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_info"
				endif
				variable imChans = numberbykey ("imChans", scanStr, ":", "\r")
				if (((chan ==4) && (imChans < 3)) || ((chan < 4) && ((chan & imChans) == 0)))
					checkBox $cba.ctrlName win=twoP_Controls,  value = 0
				else
					stackChan += chan
				endif
			else
				stackChan -= chan
			endif
			break
	endswitch
	return 0
End

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
			if (cmpStr (curScan, "LiveWave") == 0)
				doalert 0, "This function only works with a Time Series or a Z-stack."
				return 1
			endif
			SVAR scanStr = $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_info"
			variable mode = numberbykey ("Mode", scanStr, ":", "\r")
			if (!((mode == kZSeries) || (mode == kTimeSeries)))
				doalert 0, "This function only works with a Time Series or a Z-stack."
				return 1
			endif
			// Check what to do
			NVAR stackChan = root:packages:twoP:examine:StackChan
			NVAR startFrame = root:packages:twoP:examine:ProjStartFrame
			NVAR endFrame = root:packages:twoP:examine:ProjEndFrame
			SVAR outName = root:packages:twoP:examine:ProjOutName
			outName = cleanUpName (outName, 0)
			variable isMax
			controlinfo /w=twoP_Controls StacksMaxCheck
			if (V_Value ==1)
				isMax = 1
			else
				controlinfo /w=twoP_Controls StacksAvgCheck
				if (V_Value ==1)
					isMax =0
				else
					doAlert 0, "Neither Average nor Maximum selected for projection."
					return 1
				endif
			endif
			// Check that first and last frames are within range
			variable numFrames = numberbykey ("NumFrames", scanStr, ":", "\r")
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
			// do the projection channel by channel
			STRUCT WMPopupAction pa
			pa.eventCode = 2
			variable ichan, ii
			string chanStr, outWaveName
			for (iChan =1; iChan < 3; iChan += 1)
				if (((stackChan & iChan) == 0) && ((stackChan & 4) == 0))
					continue
				endif
				chanStr =  "_ch" + num2str (iChan)
				WAVE scanWave = $"root:twoP_Scans:" + curScan + ":" + curScan + chanStr
				// make a 2D image wave to hold results of project image
				outWaveName =  outName + chanStr
				if (waveExists ( $"root:twoP_Scans:" + CurScan + ":" + outWaveName))
					for (ii =1; waveExists ( $"root:twoP_Scans:" + CurScan + ":" + outWaveName + num2str (ii)); ii+=1)
					endfor
					outWaveName +=num2str (ii)
				endif
				make/o/y=(wavetype (scanWave))/n= ((dimsize (scanWave,0)), (dimsize (scanWave, 1))) $"root:twoP_Scans:" + curScan + ":" + outWaveName
				WAVE projWave =$"root:twoP_Scans:" + curScan + ":" + outWaveName
				SetScale/P x (dimOffset (scanWave, 0)), (dimDelta (scanWave, 0)), "m", projWave
				SetScale/P Y (dimOffset (scanWave, 1)), (dimDelta (scanWave, 1)), "m", projWave
				if (isMax)
					ProjectSpecFrames (scanWave, startFrame, endFrame, projwave, 0, 2, 0)//^^
					note projWave "ProjType:Max\rstartFrame:" + num2str (startFrame) + "\r" + "endFrame:" + num2str (endFrame) + "\r"
				else
					KalmanSpecFrames (scanWave, startframe, endframe, projwave, 0,16)
					note projWave "ProjType:Avg\rstartFrame:" + num2str (startFrame) + "\r" + "endFrame:" + num2str (endFrame) + "\r"
				endif
				pa.popStr = nameofwave (projWave)
				NQ_DisplayProjectImProc (pa) 
			endfor
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
			proj1 -= (kNQtoUnsigned)
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


//******************************************************************************************************
//Filters each frame in a 3D image, or filters a single 2D image
// Last Modified 2016/10/28 by Jamie Boyd
Function NQ_FilterButtonProc(ba) : ButtonControl
	STRUCT WMbuttonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
	
			SVAR curScan = root:packages:twoP:examine:curScan
			if (cmpStr (curScan, "LiveWave") == 0)
				SVAR infoStr =root:packages:twoP:Acquire:LiveModeScanStr
			else
				SVAR infoStr = $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_info"
			endif
			variable mode = NumberByKey("Mode", infoStr, ":", "\r")
			NVAR stackChan = root:packages:twoP:examine:StackChan
			variable imChans = numberbykey ("imChans", infoStr, ":", "\r")
			SVAR outputFolderG = root:packages:twoP:examine:filtOutName
			string outPutFolder
			controlinfo/w=twoP_Controls FIltNewScanCheck
			variable isNewScan = V_Value
			if (isNewScan)
				outPutFolderG = CleanupName(outPutFolderG, 0 )
				outPutFolder = outPutFolderG
				if (dataFolderExists ("root:twoP_Scans:" + outputFolder))
					doAlert 1, "A scan with the name \"" + outputFolder + "\"  already exists. Overwrite it?"
					if (V_Flag == 2) // No was clicked
						return 1
					endif
				endif
				newdatafolder/o $"root:twoP_scans:" + outputFolder
				String/G $"root:twoP_Scans:" + outputFolder + ":" + outputFolder + "_info" = infoStr
				SVAR newInfoStr = $"root:twoP_Scans:" + outputFolder + ":" + outputFolder + "_info"
			else
				outPutFolder = curScan
			endif
			// read controls
			controlinfo /W= twoP_Controls FilterWidthPopUp
			variable width = str2num (S_value)
			controlinfo /W= twoP_Controls FilterPassesPopUp
			variable passes = str2num (s_value)
			controlinfo /W= twoP_Controls FilterTypePopUp
			string filterType = S_Value
			variable ii, newImChans =0
			string outputpath
			for (ii=1; ii < 3; ii +=1)
				if ((imChans & ii) && (stackChan & ii))
					WAVE thewave =  $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_ch" + num2str (ii)
					if (isNewScan ==0)
						outputpath = GetWavesDataFolder(theWave, 2)
						
					else
						outputpath = "root:twoP_Scans:" + outputFolder + ":" + outputFolder + "_ch" + num2str (ii)
						newImChans += ii
					endif
					strswitch (filterType)
						case "Gaus":
							NQ_GausConvolve (theWave, passes, width, outputpath)
							break
						case "Median":
							NQ_Median (theWave, passes, width, outputPath)
							break
						case "Hybrid Median (5x5)":
							if (isNewScan ==0)
								WAVE outWave = thewave
							else
								make/o/y= (wavetype (thewave))/n = (dimsize (thewave, 0), dimsize (thewave, 1), dimsize (thewave, 2)) $outputpath
								WAVE outWave = $outputpath
							endif
							NQ_HybridMedian (theWave, passes, outWave)
							break
					endswitch
					WAVE outWave = $outputpath
					SetScale/P x,  (dimOffset(theWave, 0)), (dimDelta (theWave, 0)), "m", outwave
					SetScale/P y,  (dimOffset(theWave, 1)), (dimDelta (theWave, 1)), "m", outwave
					SetScale/P z,  (dimOffset(theWave, 2)), (dimDelta (theWave, 1)), "m", outwave
					Note outwave note (theWave)
				endif
			endfor
			// show user what we did
			if (isNewScan)
				STRUCT WMPopupAction pa
				pa.eventCode = 2
				pa.popStr = outputFolder
				NQ_ScansPopMenuProc (pa)
				// also correct imchan, if needed
				newInfoStr = ReplaceNumberByKey("imChans", newInfoStr, newImChans, ":", "\r") 
				// copy ePhys
				variable ephysChans = NumberByKey("ephys", newInfoStr, ":", "\r" )
				for (ii =1; ii < 3; ii += 1)
					if (ePhysChans & ii)
						WAVE ePhysWave  =   $"root:twoP_Scans:" + CurScan + ":" + CurScan + "_ep" + num2str (ii)
						duplicate/o ePhysWave  $"root:twoP_Scans:" + outputFolder + ":" + outputFolder + "_ep" + num2str (ii)
					endif
				endfor
			elseif ((mode == kZSeries) || (mode == kTimeSeries)) // call movie procedure for 3D scans
				NVAR curFramePos = root:packages:twoP:examine:curFramePos
				STRUCT WMSliderAction sa
				sa.eventcode =1
				sa.curVal = curFramePos
				NQ_DisplayFramesProc(sa)				
			endif
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
	
	WAVE gk = GUIPGaussianLine2 (width, 2)
	SymConvolveFrames (theWave, outputPath, 0, gk, 1)
	if (passes > 1)
		variable iPass
		WAVE outWave = $outputPath
		for (iPass =1; iPass < passes; iPass +=1)
			SymConvolveFrames (outWave, outputPath, 0, gk, 1) 
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

