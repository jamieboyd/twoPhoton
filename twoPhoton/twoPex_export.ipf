#pragma rtGlobals=3
#pragma IgorVersion =6.2
#pragma version =2.0	// modification date: 2015/04/14 by Jamie Boyd.
#include "GUIPControls"
#include "TIFFwriter" 
#include "GUIPKillDisplayedWave"
//******************************************************************************************************
//------------------------------- Code for The Export tab on the twoP Examine TabControl--------------------------------------------
//******************************************************************************************************

// function for adding  the Export tab.
// Last modified 2015/04/12 by Jamie Boyd
Function NQexExport_add (able)
	variable able
	
	// Globals For Export Tab
	string/G root:Packages:twoP:examine:ExportPath = "no folder selected"	// Contains the path to the folder selected to store saved scans in. Displayed in a titlebox on the examine panel
	string/G root:packages:twoP:examine:ExportMatchStr = "*"
	variable/G root:packages:twoP:examine:ExportCurOrAll = 0
	string/G root:packages:twoP:examine:exportPxp = "no .pxp selected"
	// Export controls
	Button  pathbutton, win =twoP_Controls, disable=able, pos={7,458},size={56,16},proc=NQ_SetExPathProc,title="Set Folder", fSize=10
	TitleBox Expathtitle, win =twoP_Controls ,disable=able,pos={65,458},size={197,20}
	TitleBox Expathtitle, win =twoP_Controls,variable= root:Packages:twoP:examine:ExportPath
	CheckBox exportCurScanCheck, win =twoP_Controls,disable=able,pos={8,482},size={80,14},proc=GUIPRadioButtonProcSetGlobal,title="Current Scan"
	CheckBox exportCurScanCheck, win =twoP_Controls,userdata=  "root:packages:twoP:examine:ExportCurOrAll=0;exportAllScansCheck",fSize=10
	CheckBox exportCurScanCheck, win =twoP_Controls,value= 1,mode=1
	CheckBox exportAllScansCheck, win =twoP_Controls,disable=able,pos={99,483},size={109,14},proc=GUIPRadioButtonProcSetGlobal,title="All Scans matching"
	CheckBox exportAllScansCheck, win =twoP_Controls,userdata=  "root:packages:twoP:examine:ExportCurOrAll=1;exportCurScanCheck",fSize=10
	CheckBox exportAllScansCheck, win =twoP_Controls,value= 0,mode=1
	SetVariable ExportMatchSetVar, win =twoP_Controls,disable=able,pos={211,482},size={68,15},title=" "
	SetVariable ExportMatchSetVar, win =twoP_Controls,help={"This string is wild-card enabled. Use \"*\" to save all scans."}
	SetVariable ExportMatchSetVar, win =twoP_Controls,fSize=10
	SetVariable ExportMatchSetVar, win =twoP_Controls,value= root:Packages:twoP:examine:ExportMatchStr
	CheckBox exportNewFolderCheck, win =twoP_Controls,disable=able,pos={8,501},size={129,14},title="New Folder for Each Scan"
	CheckBox exportNewFolderCheck, win =twoP_Controls,value= 0
	CheckBox exportOverWriteCheck, win =twoP_Controls,disable=able,pos={156,501},size={93,14},title="Auto OverWrite"
	CheckBox exportOverWriteCheck, win =twoP_Controls,fSize=10,value= 0
	PopupMenu exportpopup, win =twoP_Controls,disable=able,pos={8,520},size={80,20},proc=NQ_ExportPopMenuProc,title="Mode"
	PopupMenu exportpopup, win =twoP_Controls,fSize=10
	PopupMenu exportpopup, win =twoP_Controls,mode=3,popvalue="TIFF",value= #"\"Igor binary;PXP;TIFF;TIFF current Frame;QuickTime Movie;Note Only\""
	PopupMenu ReScalePopup, win =twoP_Controls,disable=able,pos={8,546},size={117,20},title="Scaling:"
	PopupMenu ReScalePopup, win =twoP_Controls,mode=1,popvalue="Full Scale",value= #"\"Full Scale;Data Range;Min/Max\""
	PopupMenu expDimPopUp, win =twoP_Controls,disable=able,pos={141,546},size={142,20},title="type"
	PopupMenu expDimPopUp, win =twoP_Controls,mode=2,popvalue="signed 16",value= #"\"signed 16;unsigned 16;unsigned 8;float;\""
	Button SaveButton, win =twoP_Controls,disable=able,pos={8,630},size={96,20},proc=NQ_SaveAndOrDeleteButtonProc,title="Save Scan to Disk",fSize=10
	Button SaveKillButton, win =twoP_Controls,disable=able,pos={107,630},size={135,20},proc=NQ_SaveAndOrDeleteButtonProc,title="Save and Delete  from Exp",fSize=10
	Button KillButton, win =twoP_Controls,disable=able,pos={245,630},size={37,20},proc=NQ_SaveAndOrDeleteButtonProc,title="Delete",fSize=10
	// Add "Export" controls  to database for Examine tabControl
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "export","Button pathbutton 0;Titlebox Expathtitle 0;Checkbox exportCurScanCheck 0;Checkbox exportAllScansCheck 0;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "export","Setvariable ExportMatchSetVar 0;Checkbox exportNewFolderCheck 0;Checkbox exportOverWriteCheck 0;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "export","Popupmenu exportpopup 0;Popupmenu ReScalePopup 0;Popupmenu expDimPopUp 0;Button SaveButton 0;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "export","Button SaveKillButton 0;Button KillButton 0;",applyAbleState=0)
end

//*******************************************************************************
//Sets a new Igor symbolic path, by letting the user choose a folder on the disk
// Last Modified 2010/08/03 by Jamie Boyd
Function NQ_SetExPathProc(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR PathStr =root:Packages:twoP:examine:ExportPath		// the global string were we store the path
	NewPath /O/M="Select a Folder in which to store Scan Waves" ExportPath
	if (!V_flag)		// V_flag is set to 0 if newpath is successful
		PathInfo ExportPath
		pathstr =  s_path
	endif
End

//******************************************************************************************************
//Shows or hides some controls depending on the export method chosen
// Last Modified 2015/04/14 by Jamie Boyd
Function NQ_ExportPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum  //"Igor binary;PXP;TIFF;TIFF current Frame;QuickTime Movie;Note Only"
			if ((popNum == 4) || (popNum == 5))
				checkbox exportCurScanCheck win=twoP_Controls, value = 1
				checkbox exportAllScansCheck win=twoP_Controls, value = 0
			endif
			variable ableState= ((popNum == 4) || (popNum == 5))
			GUIPTabSetAbleState ("twoP_Controls", "ExamineTabCtrl", "export", "exportCurScanCheck;exportAllScansCheck;ExportMatchSetVar;", ableState, 1)
			ableState= ((popNum >= 4) && (popNum <= 6))
			GUIPTabSetAbleState ("twoP_Controls", "ExamineTabCtrl", "export", "SaveKillButton;", ableState, 1)
			ableState=(!((popNum == 3) || (popNum == 4)))
			GUIPTabSetAbleState ("twoP_Controls", "ExamineTabCtrl", "export", "ReScalePopup;expDimPopUp", ableState, 1)
			break
	endswitch
	return 0
End

//******************************************************************************************************
//Saves to disk and/or deletes selected scans. including all waves in the folder
// Last Modified 2015/04/12 by Jamie Boyd
Function NQ_SaveAndOrDeleteButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// Current or multiple scans?
			string scanList
			variable iScan, nScans
			NVAR expCurOrAll = root:packages:twoP:examine:ExportCurOrAll 
			if (expCurOrAll==1)
				SVAR exportMatchStr = root:packages:twoP:examine:exportMatchStr
				scanList = GUIPListObjs("root:twoP_Scans", 4, exportMatchStr, 0, "") 
				nScans = itemsinList (scanList)
			else
				SVAR curScanG = root:packages:twoP:examine:curScan
				scanList = curScanG + ";"
				nScans = 1
			endif
			// saving, deleting variable bit 0 for saving, bit 1 for deleting
			variable saveDelete
			strSwitch (ba.ctrlname)
				case "SaveButton":
					saveDelete = 1
					break
				case "KillButton":
					saveDelete = 2
					break
				case "SaveKillButton":
					saveDelete = 3
					break
			endSwitch
			// User must have set a save to path first
			if (saveDelete & 1)
				PathInfo  ExportPath
				if (V_Flag == 0)
					doalert 0,"First choose a folder in which to save the data."
					return 1
				endif
				string pathStr = S_Path
				// check some options
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
						NQ_ExportScan_PXP (expCurOrAll, curScanG, OverWrite, makeNewFolder)
					else
						NQ_ExportScan_PXP (expCurOrAll, exportMatchStr, OverWrite, makeNewFolder)
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
			// Iterate through list of scans to save/delete
			string curScan
			variable errVal =0
			for (iScan = 0; iScan < nScans && errVal == 0; iScan += 1)
				curScan = stringFromList (iScan, scanList)
				if  ((saveMode != 2) && (makeNewFolder))
					NewPath /C/O/Q exPortPathSubFolder , pathStr + curScan + ":"
				endif
				//Now save the wave (.pxp mode will already have been exported, so is not shown in switch)
				SWITCH (saveMode)
					case 1://igor binary
						errVal = NQ_ExportScan_ibw (curScan, OverWrite, makeNewFolder)
						break
					Case 3: //TIFF
						errVal =NQ_ExportScan_tif (curScan, overWrite, makeNewFolder,TiffScaleMode, tiffExpType)
						break
					Case 4: // TIFF Current Frame only
						errVal =NQ_ExportScan_tifCurFrame (curScan, overWrite, makeNewFolder,TiffScaleMode, tiffExpType, CurFramePos)
						break
					case 5: //QT movie
						errval =NQ_ExportScan_QTMovie (curScan, overWrite, makeNewFolder)
						break
					case 6: // note only
						errval = NQ_ExportScan_Note (curScan, OverWrite, makeNewFolder)
				endswitch
				SVAR curScanG = root:packages:twoP:examine:curScan
				if (saveDelete & 2)
					if (cmpStr (curScan, "") != 0)
						GUIPkillWholeDatafolder("root:twoP_Scans:" + curScan)
					endif
					if ((cmpStr (curScan, curScanG) ==0) && (iScan == nScans -1))
						NVAR scanNum = root:packages:twoP:Examine:curScanNum
						string scanNumStr, newScan
						sprintf scanNumStr, "_%03d", scanNum + 1
						newScan = stringFromList (0, curScan, "_")  + scanNumStr
						if (!(DataFolderExists ("root:twoP_Scans:" + newScan)))
							sprintf scanNumStr, "_%03d", scanNum - 1
							newScan = stringFromList (0, curScan, "_")  + scanNumStr
						endif
						if (DataFolderExists ("root:twoP_Scans:" + newScan))
							STRUCT WMPopupAction pa
							pa.popStr = newScan
							pa.eventcode =2
							NQ_ScansPopMenuProc(pa)
						else
							doWindow/K twoPscanGraph
							doWindow/K twoP_TracesGraph
							curScanG = ""
						endif
					endif
				endif
			endfor
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Checks name of file to be saved against a list of saved files
// gives user chance to rename file, if conflict
// adds name of added file to list
// returns 0 if no conflict, 1 if overwrite, 2 if renamed, 3 to cancel this file, 4 to cancel all files
// Last Modified 2015/04/14 by Jamie Boyd
Function NQ_ExportCheckRename (fileName, fileList)
	string &fileName
	string &fileList
	
	variable alertChoice = 0
	string alertStr
	string promptNameStr=filename
	if (WhichListItem(fileName, fileList) == -1)
		fileList = AddListItem(fileName, fileList, ";")
	else
		do
			sprintf alertStr, "A file named \"%s\" already exists in the chosen directory.", promptNameStr
			Prompt alertChoice, alertStr, popup, "OverWrite old file;Rename new file;skip this file;cancel saving all files"
			doPrompt/Help="I am trying to save a file in a directory on disk, selected by you as the export path, and a file with the same name already exists there. This is where you tell me what do do. Clicking \"Cancel\" is the same as selecting \"Cancel saving all files\"." "FIle OverWrite Alert", alertChoice
			if (V_flag ==1)
				alertChoice = 3 // cancel saving all files
			elseif (alertChoice ==2) // Rename new file. Prompt for  a new name
				promptNameStr = fileName
				prompt promptNameStr, "New File Name:"
				doprompt/Help="You selected the rename option. This is where you suggest a new name for the file, which I will check again for conflict with files already in the chosen directory. Clicking \"Cancel\" here will cancel saving all files." "Rename the wave " + fileName, promptNameStr
				if (V_Flag ==1) // cancel was clicked. Cancel loading all files
					alertChoice =3
				else // do prompt succeeded
					fileName =promptNameStr
				endif
			endif
		while ((WhichListItem(fileName, fileList) > -1) && (alertChoice == 2))
		if (alertChoice ==2)
			fileList = AddListItem(fileName, fileList, ";")
		endif
	endif
	return alertChoice
end

//******************************************************************************************************
// Saves to a .pxp file of the current scan or a range of scans
// Last Modified 2015/04/14 by Jamie Boyd
function NQ_ExportScan_PXP (expCurOrMatch, curScanOrMatch, doOverWrite, makeNewFile)
	variable expCurOrMatch  //0 for current scan, 1 to match a range of scans
	string curScanOrMatch // either name of current scan, or wild-card enabled string to match a list of scans
	variable doOverwrite // 1 to overwrite existing pxp without asking for permission
	variable makeNewFile //1 to make a new .pxp file for each scan (if doing a list of scans)
	
	string expName = igorinfo (1)
	if (cmpStr (expName, "untitled") ==0)
		expName = "Scans"
	endif
	string savedFolder = getdatafolder (1)
	string saveList, scanList, aScan, fileNameStr
	variable iScan, nScans, nSaves
	if (expCurOrMatch)
		saveList = GUIPListObjs("root:twoP_Scans", 4, curScanOrMatch, 0, "")
	else
		saveList = curScanOrMatch + ";"
	endif
	nSaves = itemsInList (saveList, ";")
	// look for other pxp files in export path, if overwriting is not set
	variable owCode
	string pxpsAlready
	if (!(doOverWrite))
		pxpsAlready=GUIPListFiles ("ExportPath",  ".pxp", "*", 0, "")
	endif
	// move unselected scans to a temporary folder
	newDataFolder/o root:packages:tempScans
	setdatafolder root:twoP_Scans:
	if (makeNewFile)// each selected scans will go in its own .pxp file, named for the scan
		// move all scans into temp folder
		scanList = GUIPListObjs("root:twoP_Scans:" , 4, "*", 2, "")
		nScans = itemsInList (scanList, ";")
		for (iScan =0; iScan < nScans;iScan +=1)
			aScan = stringFromList (iScan, scanList, ";")
			MoveDataFolder $aScan, root:packages:tempScans:
		endfor
		// process each scan by moving it into twoP_Scans folder, saving data, and moving it back out
		for (iScan =0; iScan < nSaves; iScan +=1)
			aScan = stringFromList (iScan, saveList, ";")
			fileNameStr = expName + "_" + aScan + ".pxp"
			if (!(doOverWrite))
				owCode = NQ_ExportCheckRename (fileNameStr, pxpsAlready)
				if (owCode == 3)
					continue
				elseif (owCode ==4)
					break
				endif
			endif
			MoveDataFolder $"root:packages:tempScans:" + aScan, root:twoP_Scans:
			SaveData/O/R/P=ExportPath/T fileNameStr
			MoveDataFolder $aScan, root:packages:tempScans:
		endfor
		// move all scans back into twoP_Scans
		setDataFolder root:packages:tempScans:
		for (iScan =0; iScan < nScans;iScan +=1)
			aScan =stringFromList (iScan, scanList, ";")
			MoveDataFolder $aScan, root:twoP_Scans:
		endfor
	else // all scans in a single .pxp
		fileNameStr = expName + "_" + curScanOrMatch + ".pxp"
		if (!(doOverWrite))
			owCode = NQ_ExportCheckRename (fileNameStr, pxpsAlready)
			if (owCode >= 3)
				return 1
			endif
		endif
		// remove all but selected scans into tempfolder
		scanList = GUIPListObjs("root:twoP_Scans:" , 4, "*", 0, "")
		scanList =RemoveFromList(saveList, scanList , ";")
		nScans = itemsInList (scanList, ";")
		for (iScan =0; iScan < nScans;iScan +=1)
			aScan =stringFromList (iScan, scanList, ";")
			MoveDataFolder $aScan, root:packages:tempScans:
		endfor
		// save selected scans
		SaveData/O/R/P=ExportPath/T fileNameStr
		// move all scans back into twoP_Scans
		setDataFolder root:packages:tempScans:
		for (iScan =0; iScan < nScans;iScan +=1)
			aScan = stringFromList (iScan, scanList, ";")
			MoveDataFolder $aScan, root:twoP_Scans:
		endfor
	endif
	setdatafolder $savedFolder
	return 0
end

//******************************************************************************************************
// Saves to disk all waves from the given scan as Igor Binary waves
// Last Modified 2015/04/14 by Jamie Boyd
Function NQ_ExportScan_ibw (theScan, doOverWrite,inSubFolder)
	string theScan
	variable doOverWrite
	variable inSubFolder
	
	string ExportPathStr
	if (inSubFolder)
		ExportPathStr = "ExportPathSubFolder"
	else
		ExportPathStr = "ExportPath"
	endif
	string fileNameStr, FolderList = GUIPListObjs("root:twoP_Scans:" + theScan, 1, "*", 0, "") 
	variable iWave, nWaves = itemsinlist (FolderList, ";")
	// look for other ibw files in export path, if overwriting is not set
	variable owCode
	string ibwsAlready
	if (!(doOverWrite))
		ibwsAlready=GUIPListFiles ("ExportPath",  ".ibw", "*", 0, "")
	endif
	for (iWave =0; iWave < nWaves; iWave += 1)
		wave dataWave = $"root:twoP_Scans:" + theScan + ":" + stringFromList (iWave, FolderList)
			FileNameStr = stringFromList (iWave, FolderList) + ".ibw"
			if (!(doOverWrite))
				owCode = NQ_ExportCheckRename (fileNameStr, ibwsAlready)
				if (owCode == 3)
					continue
				elseif (owCode ==4)
					break
				endif
			endif
			Save /C/O/P=$ExportPathStr datawave as FileNameStr
	endfor
	// save note
	NQ_ExportScan_Note (theScan, doOverWrite,inSubFolder)
	return 0
end

//******************************************************************************************************
// Saves to disk all waves from the given scan as tiff images
// Last Modified 2015/04/12 by Jamie Boyd
Function NQ_ExportScan_tif (curScan, doOverWrite, inSubFolder,  tiffScaleMode, tiffExpType)
	string curScan
	variable doOverWrite
	variable inSubFolder
	variable tiffScaleMode
	variable tiffExpType
	
	string ExportPathStr
	if (inSubFolder)
		ExportPathStr = "ExportPathSubFolder"
	else
		ExportPathStr = "ExportPath"
	endif
	// set datafolder to current scan
	string savedFolder = getdatafolder (1)
	setdatafolder $"root:twoP_scans:" + curScan
	// get scan note and experiment time
	SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
	variable timeinSecs = numberbykey ("ExpTime", scanStr, ":", "\r")
	// get list of 2D and 2D waves in the folder for channel 1
	string fileNameStr
	variable iWave, nWaves
	string ch1List = WaveList("*_ch1", ";", "DIMS:2" ) + WaveList("*_ch1", ";", "DIMS:3" )
	nWaves = itemsinlist (ch1List, ";")
	// look for other tiff files in export path, if overwriting is not set
	variable owCode
	string tifsAlready, ibwsAlready
	if (!(doOverWrite))
		tifsAlready=GUIPListFiles ("ExportPath",  ".tif", "*", 0, "")
		ibwsAlready=GUIPListFiles ("ExportPath",  ".ibw", "*", 0, "")
	endif
	NVAR minVal = root:packages:twoP:examine:ch1firstlutcolor
	NVAR maxVal=root:packages:twoP:examine:ch1Lastlutcolor
	for (iWave =0; iWave < nWaves; iWave += 1)
		wave dataWave = $"root:twoP_Scans:" + curScan + ":"  + stringFromList (iWave, ch1List)
		FileNameStr = stringFromList (iWave, ch1List) + ".tif"
		if (!(doOverWrite))
			owCode = NQ_ExportCheckRename (fileNameStr, tifsAlready)
			if (owCode == 3)
				continue
			elseif (owCode ==4)
				break
			endif
		endif
		ExportGreyScaleTIFF (datawave,ExportPathStr,TIFFexpType, TIFFscaleMode, minVal = minVal, maxVal = maxVal, timeInSecs = timeinSecs)
	endfor
	string ch2List = WaveList("*_ch2", ";", "DIMS:2" ) + WaveList("*_ch2", ";", "DIMS:3" )
	nWaves = itemsinlist (ch2List, ";")
	NVAR minVal = root:packages:twoP:examine:ch2firstlutcolor
	NVAR maxVal=root:packages:twoP:examine:ch2Lastlutcolor
	for (iWave =0; iWave < nWaves; iWave += 1)
		wave dataWave = $"root:twoP_Scans:" + curScan + ":"  + stringFromList (iWave, ch2List)
		FileNameStr = stringFromList (iWave, ch2List) + ".ibw"
		if (!(doOverWrite))
			owCode = NQ_ExportCheckRename (fileNameStr, tifsAlready)
			if (owCode == 3)
				continue
			elseif (owCode ==4)
				break
			endif
		endif
		ExportGreyScaleTIFF (datawave, ExportPathStr,TIFFexpType, TIFFscaleMode, minVal = minVal, maxVal = maxVal, timeInSecs = timeinSecs)
	endfor
	// get list of all 1D waves in the folder
	string folderList =  WaveList("*", ";", "DIMS:1" )
	nWaves = itemsinlist (folderList, ";")
	for (iWave =0; iWave < nWaves; iWave += 1)
		wave dataWave = $"root:twoP_Scans:" + curScan + ":"  + stringFromList (iWave, folderList)
		FileNameStr = stringFromList (iWave, folderList) + ".ibw"
		if (!(doOverWrite))
			owCode = NQ_ExportCheckRename (fileNameStr, ibwsAlready)
			if (owCode == 3)
				continue
			elseif (owCode ==4)
				break
			endif
		endif
		Save /C/O/P=$ExportPathStr datawave as FileNameStr
	endfor
	// save note
	NQ_ExportScan_Note (curScan, doOverWrite,inSubFolder)
	setDataFolder $savedFolder
	return 0
end


//******************************************************************************************************
// Saves as a 2D tiff whatever image is displayed in the scan Graph, usually the current frame of a 3D wave
// Last Modified 2015/04/12 by Jamie Boyd
Function NQ_ExportScan_tifCurFrame (curScan, doOverWrite, inSubFolder,TiffScaleMode, tiffExpType, CurFramePos)
	string curScan
	variable doOverwrite
	variable inSubFolder
	variable tiffScaleMode
	variable tiffExpType
	variable CurFramePos
	
	// get scan note and experiment time
	SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
	variable timeinSecs = numberbykey ("ExpTime", scanStr, ":", "\r")
	string ExportPathStr
	if (inSubFolder)
		ExportPathStr = "ExportPathSubFolder"
	else
		ExportPathStr = "ExportPath"
	endif
	// look for other tiff files in export path, if overwriting is not set
	variable owCode
	string tifsAlready
	if (!(doOverWrite))
		tifsAlready=GUIPListFiles ("ExportPath",  ".tif", "*", 0, "")
	endif
	// process images displayed in the 3 possible subwindows of the scanGraph
	// The ugly imagenametowaveref is used because 2D waves - lineScans and Avgs - are displayed directly in the scangraph
	string fileNameStr
	WAVE/Z ch1Wave = imageNameToWaveRef ("twoPscanGraph#GCH1", stringfromlist (0,  ImageNameList("twoPscanGraph#GCH1", ";"), ";"))
	if (waveExists (ch1Wave))
		NVAR minVal = root:packages:twoP:examine:ch1firstlutcolor
		NVAR maxVal=root:packages:twoP:examine:ch1Lastlutcolor
		FileNameStr = curScan + "_ch1_f" + num2str (curFramePos) + ".tif"
		if (!(doOverWrite))
			owCode = NQ_ExportCheckRename (fileNameStr, tifsAlready)
			if ((owCode == 3) || (owCode ==4))
				return 1
			endif
		endif
		ExportGreyScaleTIFF (ch1Wave, ExportPathStr, tiffExpType, TiffScaleMode, minVal = minVal, maxVal=maxVal, TimeInSecs = timeinSecs, FileNameStr = FileNameStr)
	endif
	WAVE/Z ch2Wave = imageNameToWaveRef ("twoPscanGraph#GCH2", stringfromlist (0,  ImageNameList("twoPscanGraph#GCH2", ";"), ";"))
	if (waveExists (ch2Wave))
		NVAR minVal = root:packages:twoP:examine:ch2firstlutcolor
		NVAR maxVal=root:packages:twoP:examine:ch2Lastlutcolor
		FileNameStr = curScan + "_ch2_f" + num2str (curFramePos) + ".tif"
		if (!(doOverWrite))
			owCode = NQ_ExportCheckRename (fileNameStr, tifsAlready)
			if ((owCode == 3) || (owCode ==4))
				return 1
			endif
		endif
		ExportGreyScaleTIFF (ch2Wave, ExportPathStr, tiffExpType, TiffScaleMode, minVal = minVal, maxVal=maxVal, TimeInSecs = timeinSecs, FileNameStr = FileNameStr)
	endif
	// mrg wave is alwyas mrg wave, but still need to check if subwindow is diplayed
	WAVE/Z mrgWave = imageNameToWaveRef ("twoPscanGraph#GMRG", stringfromlist (0,  ImageNameList("twoPscanGraph#GMRG", ";"), ";"))
	if (waveExists (mrgWave))
		FileNameStr = curScan + "_mrg_f" + num2str (curFramePos) + ".tif"
		if (!(doOverWrite))
			owCode = NQ_ExportCheckRename (fileNameStr, tifsAlready)
			if ((owCode == 3) || (owCode ==4))
				return 1
			endif
		endif
		ExportRGBcolorTIFF (ExportPathStr, 1, fileNameStr, dataWaveRGB = mrgWave, timeInSecs =timeInSecs)
	endif
end


//******************************************************************************************************
//Exports a quicktime movie, only applicable for 3D images
// Last Modified Aug 03 2010 by Jamie Boyd
Function NQ_ExportScan_QTMovie (curScan, doOverWrite, inSubFolder)
	string CurScan
	variable  doOverWrite, inSubFolder
		
	// get scan note and experiment time
	SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
	variable mode = numberbykey ("mode", scanStr, ":", "\r")
	if ((mode == kLineScan) || (mode == kSingleImage))
		print  "Sorry, but " + curScan + " is not an image stack, and you need an image stack to make a movie."
		return 1
	endif
	variable ii, numFrames = numberbykey ("numFrames", scanStr, ":", "\r")
	// Bring ScanGraph to the front
	NQ_NewScanGraph(curScan)
	// set export path
	string ExportPathStr
	if (inSubFolder)
		ExportPathStr = "ExportPathSubFolder"
	else
		ExportPathStr = "ExportPath"
	endif
	string fileNameStr = curScan + ".MOV"
	//	if (!(doOverWrite))
	//		FileNameStr = CheckFileOnDisk (ExportPathStr, fileNameStr)
	//		if (cmpStr (FileNameStr, "") == 0)
	//			return 1
	//		endif
	//	endif
	NewMovie/I/L/O/Z/P=$exportpathStr as FileNameStr
	if (V_Flag != 0)
		return 1
	endif
	// call NQ_DisplayFramesProc to display all the frames
	STRUCT WMSliderAction sa
	sa.eventCode = 1
	for (ii= 0; ii < numFrames; ii += 1)
		sa.curval = ii
		NQ_DisplayFramesProc(sa)
		doUpdate
		AddMovieFrame
	endfor
	closeMovie
	PlayMovie /P=$exportpathStr as FileNameStr
	
end

//******************************************************************************************************
//Exports the info note for the given scan as a text file
// Last Modified Aug 03 2010 by Jamie Boyd
Function NQ_ExportScan_Note (theScan, doOverWrite,inSubFolder)
	string theScan
	variable doOverwrite
	variable inSubFolder
	
	// Make export path string
	string ExportPathStr
	if (inSubFolder)
		ExportPathStr = "ExportPathSubFolder"
	else
		ExportPathStr = "ExportPath"
	endif
	// Reference the Scan Note
	SVAR scanNote = $"root:twoP_Scans:" + theScan + ":" + theScan + "_info"
		string fileNameStr = theScan + ".txt"
		//		if (!(doOverWrite))
		//			FileNameStr = CheckFileOnDisk (ExportPathStr, fileNameStr)
		//			if (cmpStr (FileNameStr, "") == 0)
		//				return 1
		//			endif
		//		endif
		variable theRefNum
		Open /P=$ExportPathStr theRefNum  as fileNameStr
		fbinwrite theRefNum, scanNote
		close therefNum
	return 0
end
