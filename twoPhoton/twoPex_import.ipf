#pragma rtGlobals=1		// Use modern global access method.
#pragma version = 1.71	// modification date: 2015/04/13 by Jamie Boyd. The "Many Small Improvements" version
#pragma IgorVersion = 5.05
#include "GUIPDirectoryLoad"

//******************************************************************************************************
//------------------------------- Code for The Import tab on the 2P Examine TabControl--------------------------------------------
//******************************************************************************************************

// function for adding  the Import tab.
// Last modified  2015/04/14 by Jamie Boyd
Function NQexImport_add (able)
	variable able

	// Globals for Import Tab
	string/g root:Packages:twoP:examine:ImportPath = "no folder selected"	// Contains the path to the folder selected from which to import scansa
	variable/G root:packages:twoP:Examine:ImpScalFromFile =0
	variable/G root:packages:twoP:Examine:ImpZisTimeOrSpace=1
	variable/G root:packages:twoP:Examine:ImpSIngleIsLineScan =0
	variable/G root:packages:twoP:Examine:ImpZScal = 1e-06
	variable/G root:packages:twoP:Examine:ImpYScal = 0.5e-06
	variable/G root:packages:twoP:Examine:ImpXScal = 0.5e-06
	variable/G root:packages:twoP:Examine:ImpZOffset = 0
	variable/G root:packages:twoP:Examine:ImpYOffset =0
	variable/G root:packages:twoP:Examine:ImpXOffset = 0
	make/o/t/n= 0 root:Packages:twoP:examine:ImportFolderListWave	// These waves are for the listbox for importing scans
	make/o/n= 0 root:Packages:twoP:examine:ImportFolderListSelWave
	//  Controls for Import Tab (all data types)
	PopupMenu ImportPopup,win =twoP_Controls, disable =able, pos={6,412},size={135,20},proc=NQ_ImportPopMenuProc,title="Scans from"
	PopupMenu ImportPopup,win =twoP_Controls,fSize=10
	PopupMenu ImportPopup,win =twoP_Controls,mode=4,popvalue="2P-Igor binary",value= #"\"2P-PXP;2P-Igor binary;Igor binary;Info String;TIFF stack\""
	Button SetImPathButton, win =twoP_Controls,disable =able,pos={6,434},size={180,20},proc=NQ_SetImPathProc,title="Set Disk Folder for import"
	TitleBox Impathtitle, win =twoP_Controls,disable =able,pos={6,458},size={86,20}
	TitleBox Impathtitle,win =twoP_Controls,variable= root:packages:twoP:examine:ImportPath
	ListBox importfilesList, win =twoP_Controls,disable =able,pos={6,480},size={276,65}
	ListBox importfilesList,win =twoP_Controls,listWave=root:packages:twoP:examine:ImportFolderListWave
	ListBox importfilesList,win =twoP_Controls,selWave=root:packages:twoP:examine:ImportFolderListSelWave
	ListBox importfilesList,win =twoP_Controls,mode= 4
	Button ImportButton, win =twoP_Controls,disable =able,pos={6,635},size={108,20},proc=NQ_ImportButtonProc,title="Import Selected"
	CheckBox ImpOverwriteCheck, win =twoP_Controls,disable =able,pos={120,637},size={120,14},title="Overwrite Existing Scan"
	CheckBox ImpOverwriteCheck,win =twoP_Controls,value= 1
	// controls for setting scaling, etc.  when data type doesn't dupport it
	PopupMenu ImpModePopup, win =twoP_Controls,disable =able,pos={6,550},size={79,20},proc=NQ_ImportOptPopMenuProc,title=" Options"
	PopupMenu ImpModePopup, win =twoP_Controls,mode=0,value= #"NQ_ImportOptList ()"
	PopupMenu ImpChanPopup, win =twoP_Controls,disable =able,pos={111,550},size={90,20},title=" Channel"
	PopupMenu ImpChanPopup,win =twoP_Controls,mode=1,popvalue="ch1",value= #"\"ch1;ch2;read from file\""
	SetVariable ImpZScalSetvar, win =twoP_Controls,disable =able,pos={6,574},size={150,19},proc=SIformattedSetVarProcAdjustInc,title="Z Scale"
	SetVariable ImpZScalSetvar,win =twoP_Controls,help={"sets the Z scaling for loaded scans"}
	SetVariable ImpZScalSetvar,win =twoP_Controls,userdata= A"Ec5l<3cJM;CLLjeF#m/t9KG74<(pXtATUj\\@;J\"[AM#Yo/2:]k1]"
	SetVariable ImpZScalSetvar,win =twoP_Controls,fSize=12,format="%.1W1Ps"
	SetVariable ImpZScalSetvar,win =twoP_Controls,limits={-inf,inf,0.001},value= root:packages:twoP:Examine:ImpZScal 
	SetVariable ImpZOffsetSetvar, win =twoP_Controls,disable =able,pos={164,574},size={153,19},proc=SIformattedSetVarProc,title="Z Offset"
	SetVariable ImpZOffsetSetvar,win =twoP_Controls,help={"sets the Z offset for loaded scans"}
	SetVariable ImpZOffsetSetvar,win =twoP_Controls,userdata= A"Ec5l<3cJM;CLLjeF#m/t9KG6s0KV*Q",fSize=12
	SetVariable ImpZOffsetSetvar,win =twoP_Controls,format="%.1W1Ps"
	SetVariable ImpZOffsetSetvar,win =twoP_Controls,limits={-inf,inf,0.1},value= root:packages:twoP:Examine:ImpZOffset 
	SetVariable ImpXScalSetvar, win =twoP_Controls,disable =able,pos={6,594},size={150,19},proc=SIformattedSetVarProcAdjustInc,title="X Scale"
	SetVariable ImpXScalSetvar,win =twoP_Controls,help={"sets the X scaling for loaded movies"}
	SetVariable ImpXScalSetvar,win =twoP_Controls,userdata= A"Ec5l<3cJM;CLLjeF#m/t9KG74<(pXtATUj\\@;J\"[AM#Yo/2:]k1]"
	SetVariable ImpXScalSetvar,win =twoP_Controls,fSize=12,format="%.1W1Pm"
	SetVariable ImpXScalSetvar,win =twoP_Controls,limits={-inf,inf,1e-07},value= root:packages:twoP:Examine:ImpXScal 
	SetVariable ImpXOffsetSetvar,win =twoP_Controls, disable =able,pos={164,594},size={154,19},proc=SIformattedSetVarProc,title="X Offset"
	SetVariable ImpXOffsetSetvar,win =twoP_Controls,help={"sets the X offset for loaded movies"}
	SetVariable ImpXOffsetSetvar,win =twoP_Controls,userdata= A"Ec5l<3cJM;CLLjeF#m/t9KG6s/P/],/4iT+"
	SetVariable ImpXOffsetSetvar,win =twoP_Controls,fSize=12,format="%.2W1Pm"
	SetVariable ImpXOffsetSetvar,win =twoP_Controls,limits={-inf,inf,9e-05},value= root:packages:twoP:Examine:ImpXOffset
	SetVariable ImpYScalSetvar, win =twoP_Controls,disable =able,pos={6,615},size={150,19},proc=SIformattedSetVarProcAdjustInc,title="Y Scale"
	SetVariable ImpYScalSetvar,win =twoP_Controls,help={"sets the Y scaling for loaded Scans"}
	SetVariable ImpYScalSetvar,win =twoP_Controls,userdata= A"Ec5l<3cJM;CLLjeF#m/t9KG74<(pXtATUj\\@;J\"[AM#Yo/2:]k1]"
	SetVariable ImpYScalSetvar,win =twoP_Controls,fSize=12,format="%.1W1Pm"
	SetVariable ImpYScalSetvar,win =twoP_Controls,limits={-inf,inf,1e-06},value=root:packages:twoP:Examine:ImpYScal
	SetVariable ImpYOffsetSetvar, win =twoP_Controls,disable =able,pos={164,616},size={153,19},proc=SIformattedSetVarProc,title="Y Offset"
	SetVariable ImpYOffsetSetvar,win =twoP_Controls,help={"sets the Y offset for loaded Scans"}
	SetVariable ImpYOffsetSetvar,win =twoP_Controls,userdata= A"Ec5l<3cJM;CLLjeF#m/t9KG6s/P/],/4iT+"
	SetVariable ImpYOffsetSetvar,win =twoP_Controls,fSize=12,format="%.2W1Pm"
	SetVariable ImpYOffsetSetvar,win =twoP_Controls,limits={-inf,inf,9.00901e-05},value= root:packages:twoP:Examine:ImpYOffset
	// Add "Import" controls to database
	GUIPTabAddCtrls ("twoP_Controls","ExamineTabCtrl",  "import" ,"Popupmenu ImportPopup 0;Button SetImPathButton 0;Titlebox Impathtitle 0;", applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls" , "ExamineTabCtrl",  "import",  "Listbox importfilesList 0;Checkbox ImpOverwriteCheck 0;Popupmenu ImpModePopup 0;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls" , "ExamineTabCtrl",  "import" , "Popupmenu ImpChanPopup 0;Setvariable ImpZScalSetvar 0;Setvariable ImpZOffsetSetvar 0;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl",  "import",  "Setvariable ImpXScalSetvar 0;Setvariable ImpXOffsetSetvar 0;Setvariable ImpYScalSetvar 0;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls",  "ExamineTabCtrl",  "import",  "Setvariable ImpYOffsetSetvar 0;Button ImportButton 0;",applyAbleState=0)
end

//******************************************************************************************************
// generates string for popup menu for listing and setting options for importing images
// Last modified 2015/04/14 by Jamie Boyd
STATIC CONSTANT winCheckChar = 7
function/S NQ_ImportOptList ()
	
	variable checkChar = 18
	if (CmpStr (IgorInfo(2), "WIndows") ==0)
		checkChar = winCheckChar
	endif
	NVAR ScalFromFile= root:packages:twoP:Examine:ImpScalFromFile
	NVAR ZisTimeOrSpace =root:packages:twoP:Examine:ImpZisTimeOrSpace
	NVAR SIngleIsLineScan = root:packages:twoP:Examine:ImpSIngleIsLineScan
	string optStr = ""
	if (ZisTimeOrSpace==0)
		optStr = "\\M1"  +num2char(CheckChar) + " Z is Time;   Z is Depth;"
	else
		optStr =  "   Z is TIme;\\M1"  +num2char(CheckChar) +" Z is Depth;"
	endif
	optStr += "\\M1-;"
	if (SIngleIsLineScan==0)
		optStr += "\\M1"  +num2char(CheckChar) + " Single image is XY;   Single Image is Line Scan;"
	else
		optStr += "   Single image is XY;\\M1"  + num2char(CheckChar) + " Single Image is Line Scan;"
	endif
	optStr += "\\M1-;"
	if (ScalFromFile)
		optStr += "\\M1"  +num2char(CheckChar) + " Image Scaling from File;   Image Scaling from Settings;"
	else
		optStr += "   Image Scaling from File;\\M1" + num2Char (CheckChar) + " Image Scaling from Settings;"
	endif
	return optStr
end

//******************************************************************************************************
// Sets options for importing images 
// Last modified Mar 27 2012 by Jamie Boyd
Function NQ_ImportOptPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	
	NVAR ScalFromFile= root:packages:twoP:Examine:ImpScalFromFile
	NVAR ZisTimeOrSpace =root:packages:twoP:Examine:ImpZisTimeOrSpace
	NVAR SIngleIsLineScan = root:packages:twoP:Examine:ImpSIngleIsLineScan
	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			switch (popNum)
				case 1: // Z is TIme
					ZisTimeOrSpace = 0
					SetVariable ImpZOffsetSetvar  win= twoP_Controls,format="%.1W1Ps"
					SetVariable ImpZScalSetvar  win= twoP_Controls,format="%.1W1Ps"
					break
				case 2: // X is Space
					ZisTimeOrSpace = 1
					SetVariable ImpZOffsetSetvar win= twoP_Controls, format="%.1W1Pm"
					SetVariable ImpZScalSetvar win= twoP_Controls, format="%.1W1Pm"
					break
				case 4:  // SIngle image is XY
					SIngleIsLineScan =0
					break
				case 5:
					SIngleIsLineScan =1 // SIngle image is line Scan
					break
				case 7:
					ScalFromFile=1 // scaling from file (for tiffs, anyway)
					break
				case 8:
					ScalFromFile=0 // scaling from settings panel
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//******************************************************************************************************
//Runs when a new scan is chosen, or the Imp tab is selected. Hides/Shows some controls 
// Last modified Mar 27 2012 by Jamie Boyd
function NQexImport_Update  ()
	
	variable showHide
	controlinfo/w=twoP_Controls ImportPopup
	string datatype = s_Value
	strSwitch (DataType)
		case "2P-PXP":
		case "2P-Igor binary":
		case "Info String":
			showHide =1
			break
		case "Igor binary":
		case "TIFF stack":
			showHide =0
			break
	endSwitch
	NQ_ImportShowHideScaling (showHide)
end

//******************************************************************************************************
// Hides/Shows controls for setting scaling and import optiond when applicaple
// Last modified Mar 27 2012 by Jamie Boyd
Function NQ_ImportShowHideScaling (showHide)
	variable showHide
	
	PopupMenu ImpModePopup, win =twoP_Controls,disable =showHide
	SetVariable ImpZScalSetvar, win =twoP_Controls,disable = showHide
	SetVariable ImpZOffsetSetvar, win =twoP_Controls,disable= showHide
	SetVariable ImpXScalSetvar, win =twoP_Controls,disable = showHide
	SetVariable ImpXOffsetSetvar, win =twoP_Controls,disable= showHide
	SetVariable ImpYScalSetvar, win =twoP_Controls,disable = showHide
	SetVariable ImpYOffsetSetvar, win =twoP_Controls,disable= showHide
	PopupMenu ImpModePopup, win =twoP_Controls,disable =showHide
	PopupMenu ImpChanPopup, win =twoP_Controls,disable =showHide
end

//******************************************************************************************************
// Shows/hides controls depending on choice of import type
//"2P-PXP;2P-Igor binary;Igor binary;Info String;TIFF stack"
Function NQ_ImportPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			String popStr = pa.popStr
			variable showHide
			strswitch (popStr)
				case "2P-PXP":
				case "2P-Igor binary":
				case "Info String":
					showHide =1
					break
				case "Igor binary":
				case "TIFF stack":
					showHide =0
					break
			endSwitch
			NQ_ImportShowHideScaling (showHide)
			PathInfo NQImportPath
			if (V_flag)
				NQ_ImpShowFolder ()
			endif
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//******************************************************************************************************
//  Sets a new Igor symbolic path, by letting the user choose a folder on the disk, and shows the files of currently selected type in that folder
// Last Modified Mar 26 2012 by Jamie Boyd
Function NQ_SetImPathProc(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR importpathStr = root:Packages:twoP:examine:ImportPath
	importpathStr = GUIPDirectorySetImPathProc("NQImportPath", "Scanning Laser Microscope Images")
	if (cmpStr (importpathStr, "") != 0)
		NQ_ImpShowFolder ()
	endif
end

//******************************************************************************************************
//  Shows the files of the currently selected type in the folder pointed to by importPath
// Last Modified Mar 26 2012 by Jamie Boyd
Function NQ_ImpShowFolder ()
	
	WAVE/T FolderListWave = root:Packages:twoP:examine:ImportFolderListWave
	WAVE FolderListSelWave = root:Packages:twoP:examine:ImportFolderListSelWave
	
	controlinfo/w=twoP_Controls ImportPopup
	string impMode = S_Value
	strswitch (impMode)
		case "2P-PXP": // pxp with scans saved in twoP_Scans datafolder
			NQ_ImpBrowsePXPs (FolderListWave, FolderListSelWave)
			break
		case "2P-Igor binary": // saved with new folder for each scan
			GUIPDirectoryShowFiles ("NQImportPath", FolderListWave, FolderListSelWave, "FLDR", "*", 0)
			break
		case "Igor binary": // separate Igor binary waves, need to set scan name, channel
			GUIPDirectoryShowFiles ("NQImportPath", FolderListWave, FolderListSelWave, ".ibw", "*", 0)
			break
		case "Info Str": // loads info strings into folders
			GUIPDirectoryShowFiles ("NQImportPath", FolderListWave, FolderListSelWave, ".txt", "*", 0)
			break
		case  "TIFF stack":
			GUIPDirectoryShowFiles ("NQImportPath", FolderListWave, FolderListSelWave, ".tif", "*", 0)
			break
	endSwitch
End

//******************************************************************************************************
//  lists scans in the twoP_Scans folder within packed experiment files
// last modified Mar 26 2012 by Jamie Boyd
function NQ_ImpBrowsePXPs (FolderListWave, FolderListSelWave)
	wave/T folderListWave
	wave FolderListSelWave
	
	// save current datafolder name
	string savedFolder = getdatafolder (1)
	// make a temp folder and set as current folder
	newDataFolder/o/s root:packages:tempList
	// make a list of .pxp files using CFL_ShowFilesinFolder, though no list box is made from the list
	redimension/n=0 FolderListWave, FolderListSelWave
	make/o/n=0/t FolderListPXPWave
	make/o/n=0 FolderListSelPXPWave
	GUIPDirectoryShowFiles ("NQImportPath", FolderListPXPWave, FolderListSelPXPWave, ".pxp", "*", 0)
	// iterate through each .pxpx, loading the scan info strings in each one
	variable iPXP, nPXPs = numpnts (FolderListPXPWave)
	string aPxp, scanList
	variable iScan, nScans, nTotalScans
	for (iPXP=0, nTotalScans =0; iPXP < nPXPs;iPXP +=1)
		// cleaan out any folders in the temp folder
		GUIPEmptyDatafolder (":", 8)
		// load just the infostrings for the scans of this pxp, but into separate folders for each scan
		aPXP = FolderListPXPWave [iPXP]
		LoadData/Q/L=4/O=1/P=NQimportPath/R/S="twoP_Scans" aPXP
		// iterate through list of scan folders for each .pxp, adding .pxp name/scan name pairs to list wave for the list box
		scanList = GUIPListObjs (":", 4, "*", 2, "")
		nScans = itemsinList (scanList, ";")
		string aScan
		for (iScan =0; iScan < nScans; iScan +=1, nTotalScans +=1)
			aScan =  stringFromList (iScan, scanList, ";")
			insertpoints nTotalScans, 1, FolderListWave, FolderListSelWave
			FolderListWave [nTotalScans] = aPxp + "-" + aScan
			FolderListSelWave [nTotalScans] = 0
		endfor
	endfor
	// sort list of paxp name/scan name pairs
	sort FolderListWave FolderListWave
	// reset current datafolder and delete temp folder
	setdatafolder $savedFolder
	GUIPkillWholeDatafolder("root:packages:tempList")
end

//******************************************************************************************************
// Used for passing info to file loaders
//Last Modified Mar 28 2012 by Jamie Boyd
STRUCTURE NQImpStruct
string ImportPathStr // string containing the description of the path
string fileNameStr // name of the file/folder in the importPath fodler fom which to load data
variable doOverwrite // 1 to automatically overwrite
variable xScal
variable xOffset
variable yScal
variable yOffset
variable zScal
variable zOffset
variable zIsTimeOrDepth
variable singleIsXYorLS
variable imScalFromSetOrFIle
variable chanOrParse // 1 for channel 1, 2 for channel 2, 3 for parse from file name
endstructure

//******************************************************************************************************
// prototype for file loaders
//Last Modified Mar 28 2012 by Jamie Boyd
Function NQImpProtoLoader (s)
	STRUCT NQImpStruct &s
end

//******************************************************************************************************
// Imports scans saved to disk according to chosen mode
// Last Modified 2012/06/13 by Jamie Boyd
Function NQ_ImportButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// save location of current folder
			string savedFolder = getDataFolder (1)
			// User must have set a save to path first
			PathInfo NQImportPath
			if (V_Flag == 0)
				doalert 0,"First choose a folder from which to load the scans."
				return -1
			endif
			// make a load struct (which will be used in a loop in this function, not from CFL_CustomFolderLoad)
			STRUCT NQImpStruct s
			s.ImportPathStr = S_Path
			// save location of current datafolder
			string oldfolder = getdatafolder (1)
			// globals for settings
			NVAR ImpScalFromFile = root:packages:twoP:Examine:ImpScalFromFile
			s.imScalFromSetOrFIle = ImpScalFromFile
			NVAR ImpZisTimeOrSpace = root:packages:twoP:Examine:ImpZisTimeOrSpace
			s.zIsTimeOrDepth = ImpZisTimeOrSpace
			NVAR ImpSIngleIsLineScan =root:packages:twoP:Examine:ImpSIngleIsLineScan
			s.singleIsXYorLS=ImpSIngleIsLineScan
			NVAR ImpZScal = root:packages:twoP:Examine:ImpZScal
			s.zScal = ImpZScal
			NVAR ImpYScal = root:packages:twoP:Examine:ImpYScal
			s.yScal=ImpYScal
			NVAR ImpXScal = root:packages:twoP:Examine:ImpXScal
			s.xScal=ImpXScal
			NVAR ImpZOffset = root:packages:twoP:Examine:ImpZOffset
			s.zOffset = ImpZOffset
			NVAR ImpYOffset =root:packages:twoP:Examine:ImpYOffset
			s.yOffset = ImpYOffset
			NVAR ImpXOffset = root:packages:twoP:Examine:ImpXOffset
			s.xOffset = ImpXOffset
			// check overwrite setting
			controlinfo/w=twoP_Controls ImpOverwriteCheck
			s.doOverwrite= V_Value
			// check channel
			controlinfo/w=twoP_Controls ImpChanPopup
			s.chanOrParse =V_Value
			// check import method
			controlinfo/w=twoP_Controls ImportPopup
			string impMode = S_Value
			strSwitch (impMode)
				case "2P-PXP": // pxp with scans saved in twoP_Scans datafolder
					FUNCREF  NQImpProtoLoader LoadFunc =NQ_Imp2Ppxp
					break
				case "2P-Igor binary": // saved with new folder for each scan
					FUNCREF  NQImpProtoLoader LoadFunc =NQ_Imp2Pibw
					break
				case "Info String":
					FUNCREF  NQImpProtoLoader LoadFunc = NQ_ImpNote
					break
				case "Igor binary":
					FUNCREF  NQImpProtoLoader LoadFunc =NQ_ImpIBW
					break
				case "TIFF stack":
					FUNCREF  NQImpProtoLoader LoadFunc =NQ_ImpTiffStack
					break
				endswitch
			// iterate through list wave, running the correct function for selected files/folders
			WAVE/t FolderListWave =  root:Packages:twoP:examine:ImportFolderListWave
			WAVE FolderListSelWave =  root:Packages:twoP:examine:ImportFolderListSelWave
			variable iFile, nFiles = numpnts (FolderListWave)
			for(iFile = 0; iFile < nFiles; iFile += 1)
				if ((FolderListSelWave [iFile]) == 1)
					s.fileNameStr = FolderListWave [iFile]
					LoadFunc (s)
				endif
			endfor
			// reset current data folder
			setdatafolder $savedFolder
			break
		case -1: // control being killed
			break
	endswitch
end

//******************************************************************************************************
// Imports binary waves from a folder saved from 2P export (images, ePhys, string in a folder named for scan name)
// s.fileName is name of the folder containing all the waves for the scan
//Last Modified Mar 28 2012 by Jamie Boyd
Function NQ_Imp2Pibw (s)
	STRUCT NQImpStruct &s
	
	// make path to the data
	string importPathStr = s.ImportPathStr
	string folderName = s.fileNameStr
	newPath/o ImportPathSubFldr importPathStr + folderName
	// make folder for this scan, and check if scan with same name already exists
	string scanName = NQ_ImpMakeScanFolderWave(folderName, "", s.doOverwrite)
	if (cmpStr (scanName, "") ==0) // user cancelled loading this scan
		return 1
	endif
	variable needRename =0
	if (cmpStr (folderName, ScanName) != 0)
		needRename =1
	endif
	// load all Igor binary files. They will have correct scaling, etc,but may need to be renamed
	variable iFile
	string aFile, loadedWaveName
	for (iFile=0; ; iFile +=1)
		aFile =IndexedFile(ImportPathSubFldr, iFile, ".ibw")
		if (cmpStr (aFIle, "") == 0)
			break
		endif
		LoadWave/H /P=ImportPathSubFldr aFile
		if (needRename)
			loadedWaveName = stringfromlist (0, S_waveNames, ";")
			rename $loadedWaveName, $ReplaceString(folderName, loadedWaveName, scanName) 
		endif
	endfor
	//Now load note
	aFile = folderName + ".txt"
	LoadWave /A/J/K=2/P=ImportPathSubFldr/V={"", "", 0, 0 } aFile 
	WAVE/T wave0
	string/G $"root:twoP_Scans:" + scanName + ":" + scanName + "_info"
	SVAR infoStr = $"root:twoP_Scans:" + scanName + ":" + scanName + "_info"
	variable iLine, nLines = numpnts (wave0) 
	for (iLine =0, infoStr = ""; iLine < nLines; iLine += 1)
		infoStr += wave0 [iLine] + "\r"
	endfor
	killwaves wave0
end

//******************************************************************************************************
// Imports binary waves from a 2P packed experiment (images, ePhys, string in datafolders in Nidaq_Scan)
// s.fileName is actually name of the pxp plus the name of the scan, separated by "-"
//Last Modified Mar 28 2012 by Jamie Boyd
function NQ_Imp2Ppxp (s)
	STRUCT NQImpStruct &s
	
	// parse name of file and name of scan
	string pxpName = stringfromlist (0, s.fileNameStr, "-")
	string scanInName =  stringfromlist (1, s.fileNameStr, "-")
	string scanOutName = NQ_ImpMakeScanFolderWave(scanInName, "", s.doOverwrite)
	if (cmpStr (scanOutName, "") ==0) // user cancelled loading this scan
		return 1
	endif
	variable needRename =0
	if (cmpStr (scanInName, scanOutName) != 0)
		needRename =1
	endif
	// Load the scan
	LoadData/O=1/P=NQimportPath/S="twoP_Scans:" + scanInName pxpName
	if (needRename)
		variable iObj, nObjs = CountObjects(":", 1)
		string anObj
		// waves
		for (iObj =0; iObj < nObjs; iObj +=1)
			anObj = GetIndexedObjName(":", 1, iObj)
			rename $anObj, $ReplaceString(scanInName, anObj, scanOutName) 
		endfor
		// strings
		nObjs = CountObjects(":", 3)
		for (iObj =0; iObj < nObjs; iObj +=1)
			anObj = GetIndexedObjName(":", 3, iObj)
			rename $anObj, $ReplaceString(scanInName, anObj, scanOutName) 
		endfor
	endif
end

//******************************************************************************************************
// Imports waves from a TIFF stack 
// Last modified Mar 29 2012
Function NQ_ImpTiffStack(s)
	STRUCT NQImpStruct &s
	
	string fileName = s.fileNameStr
	string scanInName = removeEnding (removeEnding (removeEnding (fileName, ".tif"), "_ch1"), "_ch2")
	// channel
	string chanStr
	if (s.chanOrParse ==3)
		chanStr = removeEnding (fileName, ".tif")
		chanStr = chanStr [strlen (ChanStr) -4, strlen (chanStr) -1]
	else
		chanStr = "_ch" + num2str (s.ChanOrParse)
	endif
	// make data folder, and get data folder name 
	string ScanOutName = NQ_ImpMakeScanFolderWave(ScanInName, chanStr, s.doOverwrite)
	variable needRename =0
	if (cmpStr (scanInName, scanOutName) != 0)
		needRename =1
	endif
	// Load multiple image TIFF (a stack) into 3D wave, single image into 2D wave
	ImageFileInfo /P=NQImportPath fileName
	variable ImHasZ
	if (V_numimages == 1) // only 1 image
		ImHasZ =0
		ImageLoad/O/RTIO/P=NQImportPath/N=$scanInName + chanStr/T=tiff FileName
		ImageLoad/O/P=NQImportPath/N=$scanInName + chanStr/T=tiff FileName
	else
		ImHasZ =1
		ImageLoad/O/RTIO/P=NQImportPath/N=$scanInName + chanStr/T=tiff/S=0/C=1 FileName
		ImageLoad/O/P=NQImportPath/N=$scanInName + chanStr/T=tiff/C=-1 FileName
	endif
	wave/Z lWave = $stringFromList (0, S_waveNames, ";")
	if (!(waveExists (lWave)))
		return -1
	endif
	// make sure name is correct
	Rename lWave, $ScanOutName + chanStr
	// Adjust scaling and other metadata including scan note
	NQ_ImpScalAndNote (s, lwave, scanOutName, chanStr)
end


//******************************************************************************************************
// Imports a standard Igor binary wave, not in a 2-P exported folder
// Last modified Mar 20 202 by Jamie Boyd
function NQ_ImpIBW  (s)
	STRUCT NQImpStruct &s
	
	string fileName = s.fileNameStr
	string scanInName = removeEnding (removeEnding (removeEnding (fileName, ".ibw"), "_ch1"), "_ch2")
	// channel
	string chanStr
	if (s.chanOrParse ==3)
		chanStr = removeEnding (fileName, ".ibw")
		chanStr = chanStr [strlen (ChanStr) -4, strlen (chanStr) -1]
	else
		chanStr = "_ch" + num2str (s.ChanOrParse)
	endif
	// make data folder, and get data folder name 
	string ScanOutName = NQ_ImpMakeScanFolderWave(ScanInName, chanStr, s.doOverwrite)
	variable needRename =0
	if (cmpStr (scanInName, scanOutName) != 0)
		needRename =1
	endif
	LoadWave/H /P=NQImportPath fileName
	wave/z lWave =  $stringfromlist (0, S_waveNames, ";")
	if (!(waveEXists (lWave)))
		return 1
	endif
	rename lwave, $ScanOutName + chanStr 
	NQ_ImpScalAndNote (s, lwave, scanOutName, chanStr)
end






//******************************************************************************************************
// Imports a 2P info String that was saved as a text wave, assuming it was saved in proper format 
function NQ_ImpNote  (s)
	STRUCT NQImpStruct &s
	
	// make path to the data
	string importPathStr = s.ImportPathStr
	string fileName = removeEnding (s.fileNameStr, ".txt")
	// make folder for this scan, and check if scan with same name already exists
	string scanName = NQ_ImpMakeScanFolderWave(fileName, "_info", s.doOverwrite)
	if (cmpStr (scanName, "") ==0) // user cancelled loading this scan
		return 1
	endif
	//load note
	LoadWave /A/J/K=2/P=NQImportPath/V={"", "", 0, 0 } fileName 
	WAVE/T wave0
	string/G $"root:twoP_Scans:" + scanName + ":" + scanName + "_info"
	SVAR infoStr = $"root:twoP_Scans:" + scanName + ":" + scanName + "_info"
	variable iLine, nLines = numpnts (wave0) 
	for (iLine =0, infoStr = ""; iLine < nLines; iLine += 1)
		infoStr += wave0 [iLine] + "\r"
	endfor
	killwaves wave0
end

//******************************************************************************************************
// Adjust scaling and other metadata for a loaded wave including scan note
// Last Modified Mar 29 2012 by Jamie Boyd
function NQ_ImpScalAndNote (s, lwave, scanOutName, chanStr)
	STRUCT NQImpStruct &s
	WAVE lWave
	string scanOutName
	string chanStr

	// apply XY scaling
	if (s.imScalFromSetOrFIle == 1) // from file
		wave/t tags = :Tag0:T_Tags 
		variable iTag, nTags = dimsize (tags,0)
		variable xRes, yRes, resunit
		string dateStr, aTag
		// look for scaling and datetime
		for (iTag=0;iTag < nTags;iTag += 1)
			aTag = tags [iTag] [1]
			if (cmpStr (aTag, "XRESOLUTION") ==0)
				xRes = str2num ( tags [iTag] [4])
			elseif  (cmpStr (aTag, "YRESOLUTION") ==0)
				yRes = str2num ( tags [iTag] [4])
			elseif (cmpStr (aTag, "RESOLUTIONUNIT") ==0)
				resUnit = str2num ( tags [iTag] [4]) // 2 = pixels/inches, 3 =pixels/cm
			elseif  (cmpStr (aTag, "DATETIME") ==0)
				dateStr = tags [iTag] [4]
			endif
		endfor
		// change res to pixels/m
		if (resUnit == 3)
			xRes *= 100
			yRes *= 100
		elseif (resunit ==2)
			xRes *= 2540
			yRes *= 3540
		endif
		SetScale/P X, (s.xOffset), (1/xRes), "m", lWave
		if (s.singleIsXYorLS ==0)
			SetScale/P Y, (s.yOffset), (1/yRes), "m", lWave
		else
			SetScale/P Y, (s.yOffset), (1/yRes), "s", lWave
		endif
	else
		SetScale/P X, (s.xOffset), (s.xScal), "m", lWave
		if (s.singleIsXYorLS ==0)
			SetScale/P Y, (s.yOffset), (s.yScal), "m", lWave
		else
			SetScale/P Y, (s.yOffset), (s.yScal), "s", lWave
		endif
	endif
	//Apply Z Scaling
	if (dimsize (lWave, 2) > 1)
		if (s.zIsTimeOrDepth ==0) // time
			SetScale/P Z, (s.zOffset), (s.zScal), "s", lWave
		else
			SetScale/P Z, (s.zOffset), (s.zScal), "m", lWave
		endif
	endif
	// wave note, if it does not exist, make one with as much info as we have
	SVAR/Z infoStr = $ScanOutName + "_info"
	if (!(SVAR_EXISTS (infoStr)))
		string/G $ScanOutName + "_info" = ""
		SVAR infoStr = $ScanOutName + "_info"
		infoStr += "ExpNote:Loaded from " + s.fileNameStr + "\r"
		infoStr += "ImChans:" + chanStr [3] + "\r"
		infoStr += "imChanDesc:" + chanStr [1,3] + ";\r"
		variable dateSecs
		if (s.imScalFromSetOrFIle == 1) // parse dattimestr
			variable  year, month, day, hours, mins, secs
			year = str2num (stringFromList (0, dateStr, ":"))
			month = str2num (stringFromList (1, dateStr, ":"))
			day =  str2num (stringFromList (2, dateStr, ":"))
			hours =  str2num (stringFromList (3, dateStr, ":"))
			mins =  str2num (stringFromList (4, dateStr, ":"))
			secs = str2num (stringFromList (5, dateStr, ":"))
			dateSecs = date2secs(year, month, day ) + (hours * 3600) + (mins * 60) + secs
		else
			dateSecs = dateTime // if no time from file, use current time
		endif
		sprintf dateStr, "ExpTime:%.0f\r",  dateSecs	// use sprintf to keep enough precision
		infoStr += "ExpTime:" + dateStr + "\r"
		if (dimsize (lwave, 2) > 1)
			if (s.zIsTimeOrDepth ==0) // z series
				infoStr += "Scan Type:Z Stack\r"
				infoStr +="Mode:4\r"
				infoStr += "ZstepSize:" + num2str (s.zScal) + "\r"
			else // time series
				infoStr += "Scan Type:Time Series\r"
				infoStr +="Mode:1\r"
				infoStr += "FrameTime:" + num2str (s.zScal) + "\r"
			endif
			infoStr += "NumFrames:" +  num2str (dimsize (lWave, 2)) + "\r"
			infoStr += "ZPos:" + num2str (dimdelta (lwave, 2)) + "\r"
		else // 2D IMAGE
			if  (s.singleIsXYorLS ==0) // single image
				infoStr += "Scan Type:Average\r"
				infoStr +="Mode:2\r"
			else		// lineScan
				infoStr += "Scan Type:Line Scan\r"
				infoStr +="Mode:3\r"
			endif
		endif
		infoStr += "Xpos:" + num2str (dimOffset (lWave, 0)) + "\r"
		infoStr += "XpixSize:" + num2str (dimdelta (lwave, 0)) + "\r"
		infoStr += "PixHeight:" + num2str (dimSize (lWave, 0)) + "\r"
		infoStr += "Ypos:" + num2str (dimOffset (lWave, 1)) + "\r"
		infoStr += "YpixSize:" + num2str (dimdelta (lwave, 1)) + "\r"
		infoStr += "PixWidth:" + num2str (dimSize (lWave, 1)) + "\r"
		infoStr += "ephys:0\r"
		infoStr +=  "ePhysChanDesc:\r"
	else // info string exists, just add this channel
		variable thisChan = str2num (chanStr [3])
		variable ImChans = NumberByKey("ImChans", infoStr, ":", "\r")
		if (!(thisChan & ImChans))
			imChans += thisChan
			infoStr = ReplaceNumberByKey("ImChans", infoStr, imChans, ":", "\r")
			string chanDesc = stringbykey ("imChanDesc", infoStr, ":", "\r")
			chanDesc += chanStr [1,3] + ";\r"
			infoStr = ReplaceStringByKey("imChanDesc", infoStr, chanDesc, ":", "\r")
		endif
	endif
end


//******************************************************************************************************
// makes folder for scan, if needed. if scan with same name already exists, finds next free scan number with same base name,
//  and gives user a chance to overwrite the existing scan
// Last Modified Mar 27 2012 by Jamie Boyd
Function/s NQ_ImpMakeScanFolderWave(ScanName, chanStr, doOverwrite)
	string ScanName
	string chanStr // if not empty string, check for a wave with this channel name instead of just for folder
	variable doOverwrite
	
	if (!(dataFolderExists ("root:twoP_Scans:" + ScanName)))
		newDataFolder/s $"root:twoP_Scans:" + ScanName
		return ScanName
	endif
	// data folder exists
	// if channel string, then check for the wave with that channel name
	if (cmpStr (chanStr, "_info") ==0) // just the info string
		SVAR/Z infoStr = $"root:twoP_Scans:" + ScanName + ":" + ScanName + chanStr
		if ((!(SVAR_EXISTS (infoStr))) || (doOverWrite ==1))
			setDataFolder $"root:twoP_Scans:" + ScanName
			return ScanName
		elseif (doOverWrite ==0)
			doAlert 1, "An info string is already loaded for Scan \"" + ScanName + "\" Overwrite it?"
			if (V_Flag ==1) // yes clicked to overwrite
				setDataFolder $"root:twoP_Scans:" + ScanName
				return ScanName
			else
				return ""
			endif
		endif
	elseif (cmpStr (chanStr, "") != 0) // just the wave
		// does the wave exist in the scan folder? Can it be overwritten?
		if ((!(WaveExists ($"root:twoP_Scans:" + ScanName + ":" + ScanName + chanStr))) || (doOverWrite ==1))
			setDataFolder $"root:twoP_Scans:" + ScanName
			return ScanName
		endif
	elseif (doOverWrite ==1) // overwrite whole folder
		GUIPEmptyDatafolder ("root:twoP_Scans:" + ScanName, 15)
		return ScanName
	endif
	// dataFolder exists, not overwriting
	// ask to renane the scan
	// see if scanname ends in an underscore followed by a three digit number
	variable slen = strlen (ScanName)
	variable curnum = str2num (ScanName [slen -3, slen -1])		// try to make a number from last three characters of the wave
	string baseName =  ScanName [0, slen -4]
	if (!(((numtype (curnum)) == 0) && ((cmpstr ("_", ScanName [slen -4])) == 0)))
		// wavename does not end with underscore followed by a three digit number, so probably not a numbered wavename, so append a number to the wavename
		baseName = ScanName
		curNum =-1
	endif
	curNum +=1
	string numStr, NewScanName
	sprintf numStr, "%03d", curNum
	NewScanName = baseName + numStr
	for (;DataFolderExists ("root:twoP_Scans:" + NewScanName);curNum+=1)
		sprintf numStr, "%03d", curNum
		NewScanName = baseName  + numStr
	endfor
	// check with user before making folder
	string NewProposedNameStr = NewScanName
	prompt NewProposedNameStr,  "Next free name is:" 
	do
		doprompt ScanName + chanStr + " already exists" NewProposedNameStr
		if (V_Flag)
			return "" // cancel loading
		endif
		NewProposedNameStr =cleanupname (NewProposedNameStr, 0)
		if (dataFolderExists ("root:twoP_Scans:" + NewProposedNameStr))
			doalert 2, "A scan named \"" + NewProposedNameStr + "\" already exists.  Overwrite it? Press yes to overwrite the old scan, no to rename the new scan, or cancel to abort loading the new scan"
			if (V_Flag == 3)
				return "" // cancel loading
			elseif (V_Flag ==1)// yes was clicked, so delete old scan
				GUIPEmptyDatafolder ("root:twoP_Scans:" + NewProposedNameStr, 15)
				return NewProposedNameStr
			endif
		endif
	while (dataFolderExists ("root:twoP_Scans:" + NewProposedNameStr))
	// make new folder with new proposed name
	newDataFolder/s $"root:twoP_Scans:" + NewProposedNameStr
	return NewProposedNameStr
end