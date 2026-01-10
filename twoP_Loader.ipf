#pragma rtGlobals=3		// Use modern global access method.
#pragma IgorVersion=6.2
#pragma version =2
// Last Modified 2025/07/09 by Jamie Boyd added checks for XOPs

//**********************************************************************************************************************************************************
// Light weight loader procedure for twoP code. This can be placed in Igor Procedures folder so it loads every time Igor launches, but
// only loads whole twoP program if user wants it. One-click access to twoP, no baggage.
Menu "Data", dynamic
	Submenu "Packages"
		SelectString ((exists("twoP_MakeExamineFolder") == 0), "",  "Load twoP LSM"),/Q, TwoPloader(hasXOPs())
		SelectString((exists("twoP_ZeroGalvos")== 6) , "", "Unload twoP acquire"),/Q, TwoPAqUnloader()
	End
End

//**********************************************************************************************************************************************************
// Checks for Igor XOPs and returns 1 if system has necessary XOPs to run twoPhoton, else 0
Function hasXOPs ()
	string XOPlist =  IgorInfo (10)
	variable hasNidaq = ((WhichListItem("NIDAQmx64",XOPlist) > -1) || (WhichListItem("NIDAQmx", XOPlist) > -1))
	variable hasTwoPhoton = ((WhichListItem("twoPhoton64", XOPlist) > -1) || (WhichListItem("twoPhotonx86", XOPlist) > -1))
	variable hasVDT = ((WhichListItem("VDT2-64", XOPlist) > -1) || (WhichListItem("VDT2", XOPList) > -1))
	return (hasNidaq && hasTwoPhoton && hasVDT)
end


//**********************************************************************************************************************************************************
// unloads twoP_acuire procedures, keeping the examine proceudres
Function TwoPAqUnloader()
	dowindow/K twoP_Controls
	string stageProc = removefromlist ("StageUpdate_Template", FunctionList ("StageUpDate_*", ";", "KIND:2;NPARAMS:4;"), ";")
	stageProc = StringFromList (1, StringFromList(0, stageProc, ";"), "_")
	doWindow/K $StageProc + "_Controls"
	Execute/P/Q/Z "DELETEINCLUDE \"" + stageProc + "_Stage\""
	Execute/P/Q/Z "DELETEINCLUDE \"twoP_acquire\""
	Execute/P/Q/Z "INSERTINCLUDE \"twoP_examine\""
	Execute/P/Q/Z "COMPILEPROCEDURES "
	Execute/P/Q/Z "twoP_ExamineMakePanel() "
end


//**********************************************************************************************************************************************************
// Inserts or deletes include specifications for acquire or examine depending on presence of needed XOPs
// Last modified:
// 2026/01/07 by Jamie Boyd - removed lines for make panel when hasXOPs and moved it to twoP_PrefsTest
// 2016/11/04 by Jamie Boyd - added code to include stage proc as well
// 2016/11/04 by Jamie Boyd - added switch for loading/unloading code
Function TwoPLoader (hasXOPs)
	variable hasXOPs
	
	if (hasXOPs)
		Execute/P/Q/Z "INSERTINCLUDE \"twoP_Prefs\""
		//Execute/P/Q/Z "INSERTINCLUDE \"twoP_acquire\""
		Execute/P/Q/Z "COMPILEPROCEDURES "
		newPath/O/Q twoPPrefsPath SpecialDirPath("Igor Pro User Files" , 0, 0, 0) + "User Procedures:twoPhoton"
		Execute/P/Q/Z "twoP_PrefsLoad (\"twoPPrefs_default\") "
		Execute/P/Q/Z "twoP_PrefsTest(1)"
		//Execute/P/Q/Z "twoP_ExamineMakePanel ()"
	else  //Just load  examine
		Execute/P/Q/Z "INSERTINCLUDE \"twoP_examine\""
		Execute/P/Q/Z "COMPILEPROCEDURES "
		Execute/P/Q/Z "twoP_ExamineMakePanel () "
	endif
end