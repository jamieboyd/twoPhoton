#pragma rtGlobals=1		// Use modern global access method.

//******************************************************************************************************
//------------------------------- Code for The Stacks tab on the 2P Examine TabControl--------------------------------------------
//******************************************************************************************************

// function for adding  the Stacks tab.
Function NQexTseries_add (able)
	variable able
	
	string/G root:packages:jb_nidaq:examine:tSeriesbaseName
	string/G root:packages:jb_nidaq:examine:tSeriesoutputname
	variable/G root:packages:jb_nidaq:examine:tSeriesstartStack
	variable/G root:packages:jb_nidaq:examine:tSeriesendStack
	variable/G root:packages:jb_nidaq:examine:tSeriesstartFrame
	variable/G root:packages:jb_nidaq:examine:tSeriesendFrame
	variable/G root:packages:jb_nidaq:examine:tSeriesCenterFrame
	
	SetVariable tSeriesbaseNameSetVar win = Nidaq_Controls, disable =able,pos={10,412},size={123,18},title="Base Name"
	SetVariable tSeriesbaseNameSetVar win = Nidaq_Controls, value= root:Packages:JB_NIDAQ:examine:tSeriesbaseName
	SetVariable tSeriesOutPutNameSetVar win = Nidaq_Controls, disable =able,pos={145,412},size={132,18},title="Out Name"
	SetVariable tSeriesOutPutNameSetVar win = Nidaq_Controls, value= root:Packages:JB_NIDAQ:examine:tSeriesoutputname
	SetVariable tSeriesStartStackSetVar win = Nidaq_Controls, disable =able,pos={10,437},size={98,18},title="Start Stack"
	SetVariable tSeriesStartStackSetVar win = Nidaq_Controls, value= root:Packages:JB_NIDAQ:examine:tSeriesstartStack
	SetVariable tSeriesEndStackSetVar win = Nidaq_Controls, disable =able,pos={117,437},size={96,18},title="End Stack"
	SetVariable tSeriesEndStackSetVar win = Nidaq_Controls, value= root:Packages:JB_NIDAQ:examine:tSeriesendStack
	Button tSeriesallStacksButton win = Nidaq_Controls, disable =able,pos={220,436},size={57,20},proc=NQ_tSeriesallStacksProc,title="All Stacks"
	SetVariable tSeriesStartFrameSetVar win = Nidaq_Controls, disable =able,pos={8,460},size={98,18},title="Start Frame"
	SetVariable tSeriesStartFrameSetVar win = Nidaq_Controls,value= root:Packages:JB_NIDAQ:examine:tSeriesstartFrame
	SetVariable tSeriesEndFrameSetVar win = Nidaq_Controls, disable =able,pos={116,460},size={95,18},title="End Frame"
	SetVariable tSeriesEndFrameSetVar win = Nidaq_Controls, value= root:Packages:JB_NIDAQ:examine:tSeriesendFrame
	Button tSeriesallFramesButton win = Nidaq_Controls, disable =able,pos={222,458},size={57,20},proc=NQ_tSeriesallFramesProc,title="All Frames"
	CheckBox tseriesCheckChan1 win = Nidaq_Controls, disable =able,pos={15,486},size={58,15},title="Chan 1",value= 0
	CheckBox tseriesCheckChan2 win = Nidaq_Controls, disable =able,pos={95,486},size={58,15},title="Chan 2",value= 0
	Button tSeriesAvgStackButton win = Nidaq_Controls, disable =able,pos={225,491},size={63,20},proc=NQtSeriesAvgButtonProc,title="Avg Trials"
	
	GUIPTabAddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "tSeries", "Setvariable tSeriesbaseNameSetVar 0", applyAbleState=0)
	GUIPTabAddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "tSeries","Setvariable tSeriesOutPutNameSetVar 0", applyAbleState=0)
	GUIPTabAddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "tSeries","SetVariable tSeriesStartStackSetVar 0", applyAbleState=0)
	GUIPTabAddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "tSeries","SetVariable tSeriesEndStackSetVar 0", applyAbleState=0)
	GUIPTabAddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "tSeries","Button tSeriesallStacksButton 0", applyAbleState=0)
	GUIPTabAddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "tSeries","SetVariable tSeriesStartFrameSetVar 0", applyAbleState=0)
	GUIPTabAddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "tSeries", "SetVariable tSeriesEndFrameSetVar 0", applyAbleState=0)
	GUIPTabAddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "tSeries", "Button tSeriesallFramesButton 0", applyAbleState=0)
	GUIPTabAddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "tSeries", "Button tSeriesAvgStackButton 0", applyAbleState=0)
	GUIPTabAddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "tSeries","CheckBox tseriesCheckChan1 0", applyAbleState=0)
	GUIPTabAddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "tSeries","CheckBox tseriesCheckChan2 0", applyAbleState=0)
end

//******************************************************************************************************
// kills global variables for this tab
Function NQexTseries_remove()
	
end

Function NQ_tSeriesallStacksProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR baseName = root:packages:jb_nidaq:examine:tSeriesbaseName
			NVAR startStack = root:packages:jb_nidaq:examine:tSeriesstartStack
			NVAR endStack = root:packages:jb_nidaq:examine:tSeriesendStack
			string StackStr
			variable iStack=0
			// find first stack - it may not be 0
			do
				sprintf StackStr, "root:Nidaq_Scans:%s_%03d", baseName, iStack
				if  (dataFolderExists (StackStr))
					break
				endif
				iStack +=1
			while (1)
			startStack = iStack
			// find last stack in this series
			do
				sprintf StackStr, "root:Nidaq_Scans:%s_%03d", baseName, iStack +1
				if (!(dataFolderExists (StackStr)))
					break
				endif
				iStack +=1
			while (1)
			endStack = iStack
			break
		case -1: // control being killed
			break
	endswitch
	
	return 0
End

Function NQ_tSeriesallFramesProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR baseName = root:packages:jb_nidaq:examine:tSeriesbaseName
			NVAR startFrame = root:packages:jb_nidaq:examine:tSeriesstartFrame
			NVAR endFrame = root:packages:jb_nidaq:examine:tSeriesendFrame
			NVAR startStack = root:packages:jb_nidaq:examine:tSeriesstartStack
			startframe =0
			string stackstr
			sprintf stackStr, "root:Nidaq_Scans:%s_%03d:%s_%03d_info", baseName, startStack,baseName, startStack
			svar infostr = $stackStr
			endFrame = NumberByKey("NumFrames", infostr , ":", "\r") -1
		case -1: // control being killed
			break
	endswitch
	return 0
End


Function NQtSeriesAvgButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// read controls and global variables
			controlinfo/w = Nidaq_Controls tseriesCheckChan1
			variable doChans = V_Value
			controlinfo/w= Nidaq_Controls tseriesCheckChan2
			doChans += V_Value * 2
			SVAR baseName = root:packages:jb_nidaq:examine:tSeriesbaseName
			SVAR outputName = root:packages:jb_nidaq:examine:tSeriesoutPutName
			NVAR startStack = root:packages:jb_nidaq:examine:tSeriesstartStack
			NVAR endStack = root:packages:jb_nidaq:examine:tSeriesendStack
			NVAR startFrame = root:packages:jb_nidaq:examine:tSeriesstartFrame
			NVAR endFrame = root:packages:jb_nidaq:examine:tSeriesendFrame
			NQ_StackAvg (basename, startStack, endStack, startFrame, endFrame, outputname, doChans)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


//******************************************************************************************************
// Does a projection for each stack, then puts that projection as a frame in the wave
// Last Modified Jul 09 2011 by Jamie Boyd
Function NQ_StackAvg (basename, startStack, endStack, startFrame, endFrame, outputname, doChans)
	string basename //base name of scans used in stack
	variable startStack, endStack	// range of 3d stacks to do sequentially
	variable startFrame, endFrame // range of frames to do in each stack
	string outputname
	variable doChans
	
	variable iStack, numStacks = endStack - startStack + 1
	variable iFrame, nFrames = endFrame - StartFrame + 1
	string StackStr
	// make sure selected range of scans exists
	for (iStack = startStack; iStack <= endStack; iStack += 1)
		sprintf StackStr, "root:Nidaq_Scans:%s_%03d", baseName, iStack
		if (!(dataFolderExists (StackStr)))
			doAlert 0, "The requested scan \"" + StackStr + "\" does not exist."
			return 1
		endif
	endfor
	
	// make datafolder and output wave and note for outputstack
	if (datafolderexists ("root:Nidaq_Scans:" + outputname))
		doAlert 1, "A Scan with the nname \"" + outPutName + "\" already exists. Overwrite it?"
		if (V_Flag == 2)
			return 1
		endif
	endif
	newDataFolder/O $"root:Nidaq_Scans:" + outPutName
	// duplicate note of first stack, then edit it
	string/G $"root:Nidaq_Scans:" + outPutName + ":" +  outPutName + "_info"
	SVAR noteStr =  $"root:Nidaq_Scans:" + outPutName + ":" +  outPutName + "_info"
	sprintf StackStr, "root:Nidaq_Scans:%s_%03d:%s_%03d_info", baseName, startStack,baseName, startStack
	SVAR startStackNoteStr = $StackStr
	noteStr = startStackNoteStr
	
	// make outPut wave(s)
	variable xPos =NumberByKey("XPos", startStackNoteStr , ":", "\r")
	variable yPos =NumberByKey("YPos", startStackNoteStr , ":", "\r")
	variable xDelta = NumberByKey("XPixSize", startStackNoteStr , ":", "\r")
	variable yDelta = NumberByKey("YPixSize", startStackNoteStr , ":", "\r")
	variable xSize = NumberByKey("PixWidth", startStackNoteStr , ":", "\r")
	variable ySize = NumberByKey("PixHeight", startStackNoteStr , ":", "\r")
	variable zSize =  NumberByKey("NumFrames", startStackNoteStr , ":", "\r")
	variable frameTIme = NumberByKey("FrameTime", startStackNoteStr , ":", "\r")
	
	if (((endFrame > zSize) || (startFrame > endFrame)) || (startFrame < 0))
		doAlert 0, "Range of frames chosen is not possible"
		return 0
	endif
	 variable zSizeOut = (endFrame - startFrame) + 1
	
	if (doChans & 1)
		make/o/d/n = (xSize, ySize, zSizeOut)  $"root:Nidaq_Scans:" + outPutName +":" + outPutName + "_ch1"
		WAVE ch1Wave = $"root:Nidaq_Scans:" + outPutName +":" + outPutName + "_ch1"
		SetScale /P X, xPos, xDelta  , "m" , ch1wave
		SetScale /P Y, yPos, yDelta  , "m" , ch1wave
		SetScale /P Z, 0, (frameTIme)  , "s" , ch1wave
		
		for (iStack = startStack; iStack <= endStack; iStack += 1)
			sprintf StackStr,"root:Nidaq_Scans:%s_%03d:%s_%03d_ch1", baseName, iStack,baseName, iStack
			WAVE iWave = $StackStr
			if (((dimsize (iWave, 0) != xSize)  ||  (dimsize (iWave,1) != ySize))  ||  (dimsize (iWave, 2) != zSize))
				doAlert 0, "All waves need to be the same size"
				return 0
			endif
			ch1Wave += iWave [p] [q] [startFrame + r]
		endfor
		ch1Wave /= numStacks
		redimension/w ch1Wave
	endif
	
	if (doChans & 2)
		make/o/n = (xSize, ySize, zSizeOut)  $"root:Nidaq_Scans:" + outPutName +":" + outPutName + "_ch2"
		WAVE ch2Wave = $"root:Nidaq_Scans:" + outPutName +":" + outPutName + "_ch2"
		SetScale /P X, xPos, xDelta  , "m" , ch2wave
		SetScale /P Y, yPos, yDelta  , "m" , ch2wave
		SetScale /P Z, 0, (frameTIme)  , "s" , ch2wave
		for (iStack = startStack; iStack <= endStack; iStack += 1)
			sprintf StackStr,"root:Nidaq_Scans:%s_%03d:%s_%03d_ch2", baseName, iStack,baseName, iStack
			WAVE iWave = $StackStr
			if (((dimsize (iWave, 0) != xSize)  ||  (dimsize (iWave,1) != ySize))  ||  (dimsize (iWave, 2) != zSize))
				doAlert 0, "All waves need to be the same size"
				return 0
			endif
			ch2Wave += iWave [p] [q] [startFrame + r]
		endfor
		ch2Wave /= numStacks
		redimension/w ch1Wave
	endif
		STRUCT WMPopupAction pa
	pa.eventCode=2
	pa.popStr = outPutName
	NQ_ScansPopMenuProc(pa)


end