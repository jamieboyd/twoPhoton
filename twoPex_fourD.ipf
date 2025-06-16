#pragma rtGlobals=3
#pragma IgorVersion = 6.2
#pragma version = 2.0 // Last modified 2014/09/18 by Jamie Boyd

//******************************************************************************************************
//------------------------------- Code for The FourD tab on the twoP Examine TabControl--------------------------------------------
//******************************************************************************************************

//******************************************************************************************************
// Graph Marquee function to crop a stack after aligning it 
Menu "GraphMarquee"
	submenu "twop Examine"
	"Crop Scan Data-destructive",/Q, NQ_fourDCropStack()
	end
end

Function NQ_fourDCropStack()
	string vAxis = "left", hAxis = "bottom"
	string axes = axislist ("")
	if ((whichlistItem ("left", axes, ";")) == -1)
		if ((whichlistItem ("right", axes, ";")) == -1)
			doAlert 0, "Neither left nor right vertical axes were found."
			return 1
		else
			vAxis = "right"
		endif
	endif
	if ((whichlistItem ("bottom", axes, ";")) == -1)
		if ((whichlistItem ("top", axes, ";")) == -1)
			doAlert 0, "Neither top nor bottom horizontal axes were found."
			return 1
		else
			hAxis = "top"
		endif
	endif
	//Get the marquee coordinates
	GetMarquee/K $vAxis, $hAxis
	// crop images
	SVAR curscanStr = root:Packages:twoP:examine:CurScan
	SVAR infoStr = $"root:twoP_Scans:" + curscanStr + ":" + curscanStr + "_info"
	variable imchans =  numberbykey ("ImChans", infoStr, ":" , "\r")
	if (imChans&1)
		WAVE aWave = $"root:twoP_Scans:" + curscanStr + ":" + curscanStr + "_ch1"
		Duplicate /O/R=(V_left, V_right)(V_bottom, V_top)  aWave, $"root:twoP_Scans:" + curscanStr + ":" + curscanStr + "_ch1T"
		wave Croppped = $"root:twoP_Scans:" + curscanStr + ":" + curscanStr + "_ch1T"
		GUIPkilldisplayedwave (aWave)
		Rename Croppped, $curscanStr + "_ch1"
		WAVE aWave = $"root:twoP_Scans:" + curscanStr + ":" + curscanStr + "_ch1"
	endif
		if (imChans&2)
		WAVE aWave = $"root:twoP_Scans:" + curscanStr + ":" + curscanStr + "_ch2"
		Duplicate /O/R=(V_left, V_right)(V_bottom, V_top)  aWave, $"root:twoP_Scans:" + curscanStr + ":" + curscanStr + "_ch2T"
		wave Croppped = $"root:twoP_Scans:" + curscanStr + ":" + curscanStr + "_ch2T"
		GUIPkilldisplayedwave (aWave)
		Rename Croppped, $curscanStr + "_ch2"
		WAVE aWave = $"root:twoP_Scans:" + curscanStr + ":" + curscanStr + "_ch2"
	endif
	infoStr = ReplaceNumberByKey("XPos", infoStr, ( dimoffset (aWave, 0)), ":"  , "\r")
	infoStr = ReplaceNumberByKey("YPos", infoStr, (dimOffset (aWave, 1)), ":"  , "\r")
	infoStr = ReplaceNumberByKey("PixWidth", infoStr, (dimSize (aWave, 0)), ":"  , "\r")
	infoStr = ReplaceNumberByKey("PixHeight", infoStr, (dimSize (aWave, 1)), ":"  , "\r")
	doWindow/K twoP_ScanGraph
	NQ_NewScanGraph (curScanStr)
end



 //******************************************************************************************************
// function for adding  the FourD tab.
Function NQexFourD_add (able)
	variable able
	
	// globals for FourD tab
	string/G root:packages:twoP:examine:FourDbaseName
	variable/G root:packages:twoP:examine:FourDstartStack
	variable/G root:packages:twoP:examine:FourDendStack
	variable/G root:packages:twoP:examine:FourDstartFrame
	variable/G root:packages:twoP:examine:FourDendFrame
	variable/G root:packages:twoP:examine:FourDCenterFrame
	variable/G root:packages:twoP:examine:FourDFillVal=-2047
	string/G root:packages:twoP:examine:FourDoutputname
	make/o/n=0 root:Packages:twoP:examine:fourdAdjustmentWaveX, root:Packages:twoP:examine:fourdAdjustmentWaveY
	// Controls for FourD panel
	SetVariable FourDbaseNameSetVar, win =twoP_Controls, disable = able,pos={10,412},size={123,16},title="Base Name"
	SetVariable FourDbaseNameSetVar, win =twoP_Controls,value= root:Packages:twoP:examine:FourDbaseName
	SetVariable fourDOutPutNameSetVar, win =twoP_Controls, disable=able,pos={143,412},size={132,16},title="Out Name"
	SetVariable fourDOutPutNameSetVar, win =twoP_Controls,value= root:Packages:twoP:examine:FourDoutputname
	SetVariable fourDStartStackSetVar, win =twoP_Controls, disable=able,pos={9,432},size={98,16},title="Start Stack"
	SetVariable fourDStartStackSetVar ,win =twoP_Controls, value= root:Packages:twoP:examine:FourDstartStack
	SetVariable fourDEndStackSetVar , win =twoP_Controls,disable=able,pos={116,432},size={96,16},title="End Stack"
	SetVariable fourDEndStackSetVar, win =twoP_Controls,value= root:Packages:twoP:examine:FourDendStack
	Button fourDallStacksButton, win =twoP_Controls, disable=able,pos={222,430},size={57,20},proc=NQ_FourDallStacksProc,title="All Stacks"
	SetVariable fourDStartFrameSetVar, win =twoP_Controls,disable=able,pos={8,456},size={98,16},title="Start Frame"
	SetVariable fourDStartFrameSetVar, win =twoP_Controls,value= root:Packages:twoP:examine:FourDstartFrame
	SetVariable fourDEndFrameSetVar, win =twoP_Controls,disable=able,pos={116,456},size={95,16},title="End Frame"
	SetVariable fourDEndFrameSetVar, win =twoP_Controls,value= root:Packages:twoP:examine:FourDendFrame
	Button fourDallFramesButton, win =twoP_Controls,disable=able,pos={222,454},size={57,20},proc=NQ_FOurDallFramesProc,title="All Frames"
	Button FourDMakeStackButton, win =twoP_Controls,disable=able,pos={217,491},size={63,20},proc=NQ_FourDMakeStackProc,title="Make Stack"
	SetVariable fourDFillValSetVar, win =twoP_Controls,disable=able,pos={16,519},size={110,16},title="Fill Value"
	SetVariable fourDFillValSetVar, win =twoP_Controls,limits={-2047,2046,1},value= root:Packages:twoP:examine:FourDFillVal
	SetVariable fourDCenterFrameSetVar, win =twoP_Controls,disable=able,pos={12,535},size={110,16},title="Center Frame"
	SetVariable fourDCenterFrameSetVar, win =twoP_Controls,value= root:Packages:twoP:examine:FourDCenterFrame
	Button fourdmarkalignButton, win =twoP_Controls, disable=able,pos={180,536},size={91,20},proc=NQ_fourDmarkalignButtonProc,title="Mark for Aligning"
	// Add FourD controls to database
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "FourD","Setvariable FourDbaseNameSetVar 0;Setvariable fourDEndFrameSetVar 0;Setvariable fourDEndStackSetVar 0;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "FourD","Button FourDMakeStackButton 0;Setvariable fourDStartFrameSetVar 0;Setvariable fourDStartStackSetVar 0;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "FourD","Setvariable fourDOutPutNameSetVar 0;Button fourDallStacksButton 0;Button fourDallFramesButton 0;",applyAbleState=0)
	GUIPTabAddCtrls ("twoP_Controls", "ExamineTabCtrl", "FourD","Setvariable fourDCenterFrameSetVar 0;Setvariable fourDFillValSetVar 0;Button fourdmarkalignButton 0;",applyAbleState=0)
end

//******************************************************************************************************
// kills global variables for this tab
Function NQexFourD_remove()
	killvariables root:packages:twoP:examine:FourDbaseName
	killvariables root:packages:twoP:examine:FourDstartStack
	killvariables root:packages:twoP:examine:FourDendStack
	killvariables root:packages:twoP:examine:FourDstartFrame
	killvariables root:packages:twoP:examine:FourDendFrame
	killvariables root:packages:twoP:examine:FourDCenterFrame
	killvariables root:packages:twoP:examine:FourDFillVal
	killstrings root:packages:twoP:examine:FourDoutputname
	killwaves/z root:Packages:twoP:examine:fourdAdjustmentWaveX, root:Packages:twoP:examine:fourdAdjustmentWaveY
end

//******************************************************************************************************
// Gets the base name from the current scan
// last modified Jul 24 2011 by Jamie Boyd
Function NQexFourD_Update()
	
	SVAR baseName = root:packages:twoP:examine:fourDbaseName
	SVAR outPutName = root:packages:twoP:examine:FourDoutputname
	SVAR curScan =root:packages:twoP:examine:curScan
	variable slen = strlen (curScan)
	variable curnum = str2num (curScan [slen -3, slen -1])		// try to make a number from last three characters of the wave
	if (((numtype (curnum)) == 0) && ((cmpstr ("_", curScan [slen -4])) == 0))
		// wavename ends with underscore followed by a three digit number, so probably  a numbered wavename
		baseName = curscan [0, slen-5]
	endif
	outPutName = baseName + "_4D"
end

//******************************************************************************************************
// Selects all the stacks for a given base name
// Last Modified Jul 09 2011 by Jamie Boyd
Function NQ_FourDallStacksProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR baseName = root:packages:twoP:examine:fourDbaseName
			NVAR startStack = root:packages:twoP:examine:fourDstartStack
			NVAR endStack = root:packages:twoP:examine:fourDendStack
			string StackStr
			variable iStack=0
			// find first stack - it may not be 0
			do
				sprintf StackStr, "root:twoP_Scans:%s_%03d", baseName, iStack
				if  (dataFolderExists (StackStr))
					break
				endif
				iStack +=1
			while (1)
			startStack = iStack
			// find last stack in this series
			do
				sprintf StackStr, "root:twoP_Scans:%s_%03d", baseName, iStack +1
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

//******************************************************************************************************
// Selects all the frames for the starting stack (assumes all stacks will be same size)
// Last Modified Jul 09 2011 by Jamie Boyd
Function NQ_FourDallFramesProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR baseName = root:packages:twoP:examine:fourDbaseName
			NVAR startFrame = root:packages:twoP:examine:fourDstartFrame
			NVAR endFrame = root:packages:twoP:examine:fourDendFrame
			NVAR startStack = root:packages:twoP:examine:fourDstartStack
			startframe =0
			string stackstr
			sprintf stackStr, "root:twoP_Scans:%s_%03d:%s_%03d_info", baseName, startStack,baseName, startStack
			svar infostr = $stackStr
			endFrame = NumberByKey("NumFrames", infostr , ":", "\r") -1
		case -1: // control being killed
			break
	endswitch
	return 0
End

//******************************************************************************************************
// makes a single 3D stack from maximum intensity projections of multiple 3D stacks
// Last Modified Jul 07 2011 by Jamie Boyd
Function NQ_FourDMakeStackProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// read controls and global variables
			controlinfo/w = twoP_Controls FourDCheckCh1
			variable doChans = V_Value
			controlinfo/w= twoP_Controls FourDCheckCh2
			doChans += V_Value * 2
			SVAR baseName = root:packages:twoP:examine:fourDbaseName
			SVAR outputName = root:packages:twoP:examine:fourDoutPutName
			NVAR startStack = root:packages:twoP:examine:fourDstartStack
			NVAR endStack = root:packages:twoP:examine:fourDendStack
			NVAR startFrame = root:packages:twoP:examine:fourDstartFrame
			NVAR endFrame = root:packages:twoP:examine:fourDendFrame
			NQ_SubStacks2Stack (basename, startStack, endStack, startFrame, endFrame, outputname)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//******************************************************************************************************
// Does a projection for each stack, then puts that projection as a frame in the wave
// Last Modified Jul 09 2011 by Jamie Boyd
Function NQ_SubStacks2Stack (basename, startStack, endStack, startFrame, endFrame, outputname)
	string basename //base name of scans used in stack
	variable startStack, endStack	// range of 3d stacks to do sequentially
	variable startFrame, endFrame // range of frames to do in each stack
	string outputname
	
	variable iStack, numStacks = endStack - startStack + 1
	variable iFrame, nFrames = endFrame - StartFrame + 1
	string StackStr
	// make sure selected range of scans exists
	for (iStack = startStack; iStack <= endStack; iStack += 1)
		sprintf StackStr, "root:twoP_Scans:%s_%03d", baseName, iStack
		if (!(dataFolderExists (StackStr)))
			doAlert 0, "The requested scan \"" + StackStr + "\" does not exist."
			return 1
		endif
	endfor
	
	// make datafolder and output wave and note for outputstack
	if (datafolderexists ("root:twoP_Scans:" + outputname))
		doAlert 1, "A Scan with the nname \"" + outPutName + "\" already exists. Overwrite it?"
		if (V_Flag == 2)
			return 1
		endif
	endif
	newDataFolder/O $"root:twoP_Scans:" + outPutName
	// duplicate note of first stack, then edit it
	string/G $"root:twoP_Scans:" + outPutName + ":" +  outPutName + "_info"
	SVAR noteStr =  $"root:twoP_Scans:" + outPutName + ":" +  outPutName + "_info"
	sprintf StackStr, "root:twoP_Scans:%s_%03d:%s_%03d_info", baseName, startStack,baseName, startStack
	SVAR startStackNoteStr = $StackStr
	noteStr = startStackNoteStr
	noteStr = ReplaceNumberByKey("Mode", noteStr, kTimeSeries , ":" , "\r" )
	noteStr =ReplaceStringByKey ("Scan Type", noteStr, "Time Series", ":" , "\r" )
	noteStr =  ReplaceNumberByKey("NumFrames", noteStr, numStacks , ":" , "\r" )
	variable zPos = NumberByKey("ExpTime", noteStr , ":", "\r")
	sprintf StackStr, "root:twoP_Scans:%s_%03d:%s_%03d_info", baseName, startStack + 1,baseName, startStack + 1
	SVAR startStack2NoteStr = $StackStr
	variable zDelta = NumberByKey("ExpTime", startStack2NoteStr , ":", "\r") - zPos
	noteStr = ReplaceNumberByKey("FrameTime", noteStr, zDelta , ":" , "\r" )
	noteStr = RemoveByKey("Zavg", noteStr, ":" , "\r" )
	noteStr = RemoveByKey("ZstepSize", noteStr, ":" , "\r" )
	// make outPut wave(s)
	variable xPos =NumberByKey("XPos", startStackNoteStr , ":", "\r")
	variable yPos =NumberByKey("YPos", startStackNoteStr , ":", "\r")
	variable xDelta = NumberByKey("XPixSize", startStackNoteStr , ":", "\r")
	variable yDelta = NumberByKey("YPixSize", startStackNoteStr , ":", "\r")
	variable xSize = NumberByKey("PixWidth", startStackNoteStr , ":", "\r")
	variable ySize = NumberByKey("PixHeight", startStackNoteStr , ":", "\r")
	
	variable doChans=  NumberByKey("ImChans", startStackNoteStr , ":", "\r")
	if (doChans&1)
		make/w/o/n= (xSize, ySize, numStacks)$"root:twoP_Scans:" + outPutName +":" + outPutName + "_ch1"
		WAVE ch1Wave = $"root:twoP_Scans:" + outPutName +":" + outPutName + "_ch1"
		SetScale /P X, xPos, xDelta  , "m" , ch1wave
		SetScale /P Y, yPos, yDelta  , "m" , ch1wave
		SetScale /P Z, zPos, zDelta  , "m" , ch1wave
	endif
	if (doChans&2)
		make/w/o/n= (xSize, ySize, numStacks)$"root:twoP_Scans:" + outPutName +":" + outPutName + "_ch2"
		WAVE ch2Wave = $"root:twoP_Scans:" + outPutName +":" + outPutName + "_ch2"
		SetScale /P X, xPos, xDelta  , "m" , ch2wave
		SetScale /P Y, yPos, yDelta  , "m" , ch2wave
		SetScale /P Z, zPos, zDelta  , "m" , ch2wave
	endif
	for (iStack = startStack; iStack <= endStack; iStack += 1)
		sprintf StackStr, "root:twoP_Scans:%s_%03d:%s_%03d_ch", baseName, iStack, baseName, iStack
		if (doChans&1)
			WAVE inWave = $StackStr + "1"
			ProjectSpecFrames (inWave, startFrame, endFrame, ch1Wave, (iStack - startStack), 2,0)//^^
		endif
		if (doChans&2)
			WAVE inWave = $StackStr + "2"
			ProjectSpecFrames (inWave, startFrame, endFrame, ch2Wave, (iStack - startStack), 2, 0)//^^
		endif
	endfor
	STRUCT WMPopupAction pa
	pa.eventCode=2
	pa.popStr = outPutName
	NQ_ScansPopMenuProc(pa)
end

//******************************************************************************************************
//  Sets a hook funtion to mark landmarks an save XY values in a pair of waves, and changes button name, color
// Last Modified Jul 18 2011 by Jamie Boyd
Function NQ_fourDmarkalignButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			button fourdmarkalignButton title = "Do Align", win = twoP_Controls, proc = NQ_fourDdoneMarkingButtonProc,  fColor=(65535,0,0)
			SetWindow twoP_ScanGraph hook (Alignhook) = NQ_FourDmarkalignHookProc, hookevents = 1
			SVAR CurScanStr = root:Packages:twoP:examine:curScan
			SVAR infostr = $"root:twoP_Scans:" + CurScanStr + ":" + CurScanStr + "_info"
			variable zsize= NumberByKey("NumFrames", infostr , ":", "\r")
			WAVE AdjustmentY = root:Packages:twoP:examine:fourdAdjustmentWaveY
			WAVE AdjustmentX= root:Packages:twoP:examine:fourdAdjustmentWaveX
			redimension/n= (zsize) AdjustmentY, AdjustmentX
			//edit AdjustmentY, AdjustmentX
			AdjustmentY = NaN
			AdjustmentX=Nan
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//******************************************************************************************************
//   the hook-function for setting the landmark in each frame
// Last Modified Jul 22 2011 by Jamie Boyd
Function NQ_FourDmarkalignHookProc(s)
	STRUCT WMWinHookStruct &s

	Variable hookResult = 0
	switch(s.eventCode)
		case 5: //mouseup
				//if (s.eventMod == 2)		//then shiftkey is pressed
					WAVE AdjustmentX= root:Packages:twoP:examine:fourdAdjustmentWaveX
					WAVE AdjustmentY = root:Packages:twoP:examine:fourdAdjustmentWaveY
					Nvar curframepos = root:packages:twoP:examine:curframepos
					AdjustmentX [CurFramePos] = AxisvalFromPixel (s.winName, "bottom", s.mouseLoc.h)
					AdjustmentY [CurFramePos]  =  AxisvalFromPixel (s.winName, "left", s.mouseLoc.v)
					hookResult=1
				//endif
			break
	endswitch
	return hookResult
end

//******************************************************************************************************
//  unsets the hook-function, changes the button back to noral, and does the registration of individual frames
// Last Modified Jul 18 2011 by Jamie Boyd
Function NQ_fourDdoneMarkingButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			button fourdmarkalignButton title = "Mark for Aligning", win = twoP_Controls, proc = NQ_fourDmarkalignButtonProc, fColor=(0,0,0)
			SetWindow twoP_ScanGraph hook (Alignhook) =$""
			// do the alignment - duplicate data wave, then redimension datawave and copy back data aligned from the dupe
			if ((ba.eventMod &2) ==2)		//then shiftkey is pressed
				doAlert 0, "Alignment cancelled."
				return 1
			endif
			SVAR CurScan = root:Packages:twoP:examine:curScan
			SVAR noteStr =  $"root:twoP_Scans:" + CurScan + ":" +  CurScan + "_info"
			variable xPixSize = NumberByKey("XpixSize", NoteStr , ":", "\r")
			variable xPos = NumberByKey("Xpos", NoteStr , ":", "\r")
			variable yPos = NumberByKey("Ypos", NoteStr , ":", "\r")
			variable yPixSize =  NumberByKey("YpixSize", NoteStr , ":", "\r")
			variable xsize = NumberByKey("PixWidth", NoteStr , ":", "\r") 
			variable Ysize = NumberByKey("PixHeight", NoteStr , ":", "\r")
			variable zSize = NumberByKey("NumFrames", NoteStr , ":", "\r")
			variable zPixSize = NumberByKey("ZstepSize", NoteStr , ":", "\r")
			variable zPos =  NumberByKey("Zpos", NoteStr , ":", "\r")
			variable doChans = NumberByKey("ImChans", NoteStr , ":", "\r")
			// copy adjustment wave and change from meters to pixels from center
			NVAR fillVal = root:Packages:twoP:examine:FourDFillVal
			WAVE GAdjustmentY = root:Packages:twoP:examine:fourdAdjustmentWaveY
			WAVE GAdjustmentX= root:Packages:twoP:examine:fourdAdjustmentWaveX
			// first interpolate any remaining nans
			variable firstNanPos, LastNanPos =-1, hasFirstVal=0, hasLastVal
			variable xInc, yInc, iInc, nIncs
			do
				// find first NaN
				for (firstNanPos = LastNanPos+1;(numtype (GAdjustmentY [firstNanPos]) == 0) && (firstNanPos< zSize);  firstNanPos+=1)
				endfor
				if (firstNanPos == zSize)
					break
				endif
				if (numtype (GAdjustmentY [firstNanPos-1]) ==0)
					hasFirstVal =1
				else
					hasfirstVal =0
				endif
				//find last Nan in this run of nans
				for (LastNanPos = firstNanPos;(numtype (GAdjustmentY [LastNanPos + 1]) == 2) && (LastNanPos< zSize);  LastNanPos+=1)
				endfor
				if (LastNanPos == zSize)
					hasLastVal =0
				else
					hasLastVal =1
				endif
				// if no first value, and no last value, we have nothing to work with
				if ((hasLastVal ==0) && (hasFirstVal ==0))
					print "FourD alignment failed because no landmarks were set."
					return 1
					break
				endif
				// if only a first value, set range to first value
				if (hasLastVal ==0)
					GAdjustmentY [firstNanPos, LastNanPos] = GAdjustmentY [firstNanPos -1]
					GAdjustmentX [firstNanPos, LastNanPos] = GAdjustmentX [firstNanPos -1]
				// if only a last value, set range to last value
				elseif (hasFirstVal ==0)
					GAdjustmentY [firstNanPos, LastNanPos] = GAdjustmentY [LastNanPos +1]
					GAdjustmentX [firstNanPos, LastNanPos] = GAdjustmentX [LastNanPos +1]
				else // interpolate
					nIncs = LastNanPos - FirstNanPos + 1
					yInc = (GAdjustmentY [LastNanPos +1] - GAdjustmentY [firstNanPos -1])/nIncs
					xInc = (GAdjustmentY [LastNanPos +1] - GAdjustmentX [firstNanPos -1])/nIncs
					for (iInc = 0; iInc < nIncs;iInc+=1)
						GAdjustmentY [firstNanPos + iInc] = GAdjustmentY [firstNanPos -1] + yInc * (iInc +1)
						GAdjustmentX [firstNanPos + iInc] = GAdjustmentX [firstNanPos -1] + xInc * (iInc+1)
					endfor
				endif
			while (1)

			// where is the center?
			NVAR CenterFrame = root:packages:twoP:examine:FourDCenterFrame
			Duplicate/o GAdjustmentY root:Packages:twoP:examine:fourdAdjustmentWaveYCopy
			Duplicate/o GAdjustmentX root:Packages:twoP:examine:fourdAdjustmentWaveXCopy
			WAVE AdjustmentY = root:Packages:twoP:examine:fourdAdjustmentWaveYCopy
			WAVE AdjustmentX = root:Packages:twoP:examine:fourdAdjustmentWaveXCopy
			AdjustmentX -=  GAdjustmentX [CenterFrame]
			AdjustmentY -=  GAdjustmentY [CenterFrame]
			//edit AdjustmentX, AdjustmentY;doupdate
			wavestats/q AdjustmentX
			variable newXPos = xPos + V_min
			wavestats/q AdjustmentY
			variable newYPos = yPos + V_min
			noteStr = ReplaceNumberByKey("Xpos", NoteStr, newXPos  , ":", "\r")
			noteStr = ReplaceNumberByKey("Ypos", NoteStr, newYPos  , ":", "\r")
			AdjustmentX = round (AdjustmentX/xPixSize)
			AdjustmentY = round (AdjustmentY/yPixSize)
			// calculate new wave size
			WaveStats/q AdjustmentX
			variable xPixOffset =  -V_min
			variable newXSize = xSize +(V_Max - V_min)
			WaveStats/q AdjustmentY
			variable yPixOffset =  -V_min
			variable newYSize = ySize + (V_Max - V_min)
			noteStr = ReplaceNumberByKey("PixWidth", NoteStr, newXSize  , ":", "\r")
			noteStr = ReplaceNumberByKey("PixHeight", NoteStr, newYSize  , ":", "\r")
			if (doChans&1)
				WAVE ch1Old =  $"root:twoP_Scans:" + curScan + ":" + curscan + "_ch1"
				Rename ch1Old, ch1Old
				make/w/n=((newXSize), (newYSize), (zSize)) $"root:twoP_Scans:" + curScan + ":" + curscan + "_ch1"
				WAVE ch1New =  $"root:twoP_Scans:" + curScan + ":" + curscan + "_ch1"
				SetScale/P X (newXPos), (xPixsize), "m" , ch1New
				SetScale/P Y (newYPos), (yPixsize), "m" , ch1New
				SetScale/P Z (zPos), (zPixsize), "s" , ch1New
				note/k ch1New
				note ch1New, note (ch1old)
				ch1New =  FillVal
			endif
			if (dochans&2)
				WAVE ch2Old = $"root:twoP_Scans:" + curScan + ":" + curscan + "_ch2"
				redimension/n= ((xSIZE), (Ysize), (zsize)) ch2Old
				Rename ch2Old, ch2Old
				make/w/n=((newXSize), (newYSize), (zSize)) $"root:twoP_Scans:" + curScan + ":" + curscan + "_ch2"
				WAVE ch2New =  $"root:twoP_Scans:" + curScan + ":" + curscan + "_ch2"
				SetScale/P X (newXPos), (xPixsize), "m" , ch2New
				SetScale/P Y (newYPos), (yPixsize), "m" , ch2New
				SetScale/P Z (zPos), (zPixsize), "s" , ch2New
				note/k ch2New
				note ch2New, note (ch2old)
				ch2New =  FillVal
			endif
			// fill new wave(s)
			variable iZ, startX, endX, startY, endY
			for (iZ =0; iZ < zSize; iZ += 1)
				startX = (xPixOffset-AdjustmentX [iZ])
				endX = startX + xSize
				startY = (yPixOffset-AdjustmentY [iZ])
				endY = startY + ySize
				if (doChans&1)
					ch1New [(startX),(endX)] [(startY), (endY)] [iZ] =  ch1Old [(p -startX)] [(q -starty)] [r]
				endif
				if (doChans&2)
					ch2New [(startX),(endX)] [(startY), (endY)] [iZ] =  ch2Old [(p -startX)] [(q -starty)] [r]
				endif
			endfor
			if (doChans&1)
				killwaves ch1old
			endif
			if (doChans&2)
				killwaves ch2old
			endif
			doWindow/K twoP_ScanGraph
			NQ_NewScanGraph (curScan)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
