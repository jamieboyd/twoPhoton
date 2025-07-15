#pragma rtGlobals=3		// Use modern global access method.
#pragma IgorVersion=6.2
#pragma version =2
// Last Modified 2025/07/09 by Jamie Boyd added checks for XOPs

//**********************************************************************************************************************************************************
// Light weight loader procedure for twoP code. This can be placed in Igor Procedures folder so it loads every time Igor launches, but
// only loads whole twoP program if user wants it. One-click access to twoP, no baggage.
Menu "Data", dynamic
	Submenu "Packages"
		SelectString ((exists("NQ_MakeExamineFolder") == 0), "",  "Load twoP LSM"),/Q, TwoPloader(hasXOPs())
		SelectString((exists("NQ_ZeroGalvos")== 6) , "", "Unload twoP acquire"),/Q, TwoPAqUnloader()
	End
End

Function hasXOPs ()
	string XOPlist =  IgorINfo (10)
	variable hasNidaq = ((WhichListItem("NIDAQmx64",XOPlist) > -1) || (WhichListItem("NIDAQmx", XOPlist) > -1))
	variable hasTwoPhoton = ((WhichListItem("twoPhoton64", XOPlist) > -1) || (WhichListItem("twoPhotonx86", XOPlist) > -1))
	variable hasVDT = ((WhichListItem("VDT2-64", XOPlist) > -1) || (WhichListItem("VDT2", XOPList) > -1))
	return (hasNidaq && hasTwoPhoton && hasVDT)
end



Function TwoPAqUnloader()
	dowindow/K twoP_Controls
	string stageProc = removefromlist ("StageUpdate_Template", FunctionList ("StageUpDate_*", ";", "KIND:2;NPARAMS:4;"), ";")
	stageProc = StringFromList (1, StringFromList(0, stageProc, ";"), "_")
	doWindow/K $StageProc + "_Controls"
	Execute/P/Q/Z "DELETEINCLUDE \"" + stageProc + "_Stage\""
	Execute/P/Q/Z "DELETEINCLUDE \"twoP_acquire\""
	Execute/P/Q/Z "INSERTINCLUDE \"twoP_examine\""
	Execute/P/Q/Z "COMPILEPROCEDURES "
	Execute/P/Q/Z "NQ_MakeNidaqPanel (0) "
end


end
//**********************************************************************************************************************************************************
// Inserts include specifications for acquire or examine depending on presence of NIDAQmx functions
// or removes acquire procedure, if acquire functions are loaded
// Last modified:
// 2016/11/04 by Jamie Boyd - added code to include stage proc as well
// 2016/11/04 by Jamie Boyd - added switch for loading/unloading code
Function TwoPLoader (hasXOPs)
	variable hasXOPs
	
	if (hasXOPs)
		Execute/P/Q/Z "INSERTINCLUDE \"twoP_Prefs\""
		Execute/P/Q/Z "INSERTINCLUDE \"twoP_acquire\""
		Execute/P/Q/Z "COMPILEPROCEDURES "
		newPath/O/Q twoPPrefsPath SpecialDirPath("Igor Pro User Files" , 0, 0, 0) + "User Procedures:twoPhoton"
		Execute/P/Q/Z "twoP_PrefsLoad (\"twoPPrefs_default\") "
		Execute/P/Q/Z "twoP_PrefsTest()"
		Execute/P/Q/Z "NQ_MakeNidaqPanel (1)"
	else  //Just load  examine
		Execute/P/Q/Z "INSERTINCLUDE \"twoP_examine\""
		Execute/P/Q/Z "COMPILEPROCEDURES "
		Execute/P/Q/Z "NQ_MakeNidaqPanel (0) "
	endif
end