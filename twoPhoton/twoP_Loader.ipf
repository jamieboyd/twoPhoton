#pragma rtGlobals=3		// Use modern global access method.
#pragma IgorVersion=6.2
#pragma version =2
// Last Modified 2016/11/04 by jamie Boyd

//**********************************************************************************************************************************************************
// Light weight loader procedure for twoP code. This can be placed in Igor Procedures folder so it loads every time Igor launches, but
// only loads whole twoP program if user wants it. One-click access to twoP, no baggage.
Menu "Data", dynamic
	Submenu "Packages"
		SelectString((exists("NQ_MakeExamineFolder")== 6) , "Load twoP LSM", ""),/Q, TwoPloader()
		SelectString((exists("NQ_ZeroGalvos")== 6) , "", "UnLoad twoP acquire"),/Q, TwoPloader()
	End
End

//**********************************************************************************************************************************************************
// Inserts include specifications for acquire or examine depending on presence of NIDAQmx functions
// or removes acquire procedure, if acquire functions are loaded
// Last modified:
// 2016/11/04 by Jamie Boyd - added code to remove stage proc as well
// 2016/11/04 by Jamie Boyd - added switch for loading/unloading code
Function TwoPLoader ()
	GetLastUserMenuInfo
	string hasAcquire = "(0)"
	if (CmpStr (S_value, "Load twoP LSM") == 0)
		if (exists("fDAQmx_AI_GetReader")== 3) //Nidaqmx functions are loaded, so load acquire, which includes examine
			Execute/P/Q/Z "INSERTINCLUDE \"twoP_examine\""
			Execute/P/Q/Z "INSERTINCLUDE \"twoP_acquire\""
			hasAcquire =  "(1)"
		else  //Just load  examine
			Execute/P/Q/Z "INSERTINCLUDE \"twoP_examine\""
		endif
	elseif (CmpStr (S_value, "UnLoad twoP acquire") == 0)
		dowindow/K twoP_Controls
		string stageProc = removefromlist ("StageUpdate_Template", FunctionList ("StageUpDate_*", ";", "KIND:2;NPARAMS:4;"), ";")
		stageProc = StringFromList (1, StringFromList(0, stageProc, ";"), "_")
		doWindow/K $StageProc + "_Controls"
		Execute/P/Q/Z "DELETEINCLUDE \"" + stageProc + "_Stage\""
		Execute/P/Q/Z "DELETEINCLUDE \"twoP_acquire\""
		Execute/P/Q/Z "INSERTINCLUDE \"twoP_examine\""
	endif
	Execute/P/Q/Z "COMPILEPROCEDURES "
	Execute/P/Q/Z "NQ_MakeNidaqPanel " + hasAcquire
end