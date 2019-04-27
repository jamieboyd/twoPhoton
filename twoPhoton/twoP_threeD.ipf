#pragma rtGlobals=2		// Use modern global access method.
#pragma version = 1.6		// modification date Jul 27 2010 by Jamie Boyd
#pragma IgorVersion = 5.0 

static constant kRedChan = 1
static constant kGreenChan = 2

//******************************************************************************************************
// Make the graph with 3 subwindows and make the control panel
	Function NQ_3DslicerProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// Get a reference to the current scan wave - it's stored in a global string
			SVAR CurScan = root:packages:twoP:Examine:CurScan
			// reference to string of scan data
			SVAR scanStr = $"root:twoP_Scans:" + curScan + ":" + curScan + "_info"
			// read in scan mode and test for z-stack
			variable mode = numberbykey ("Mode", scanStr, ":", "\r")
			if (!(mode == kZSeries))
				doalert 0, "This function only works with a Z-stack."
				return 1
			endif
			// which channels are selected?
			NVAR stackChan = root:packages:twoP:examine:StackChan
			// which channels are available for this scan?
			variable imChans = numberbykey ("ImChans", scanStr,  ":", "\r")
			variable doChans =0
			if (stackChan & 1)
				if  (imChans & 1)
					doChans += 1
				else
					print "Channel 1 is not available for scan \"" + curScan + "\"."
				endif
			endif
			if (stackChan & 2)
				if  (imChans & 2)
					doChans += 2
				else
					print "Channel 2 is not available for scan \"" + curScan + "\"."
				endif
			endif
			if (stackChan & 4) // do merged image
				if ((imChans & 3) == 3)
					doChans += 4
				else
					print "Channel 1 and Channel 2 are not both available for scan \"" + curScan + "\"."
				endif
			endif
			if (doChans == 0)
				return 1
			endif
			// read in Scaling and offsets
			variable xscaling = numberbykey ("XpixSize", scanStr, ":", "\r")
			variable xOffset = numberbykey ("xPos", scanStr, ":", "\r")
			variable xPix = numberbyKey ("PixWidth", scanStr, ":", "\r")
			variable yscaling =  numberbykey ("YpixSize", scanStr, ":", "\r")
			variable yOffset =numberbykey ("yPos", scanStr, ":", "\r")
			variable yPix = numberbykey ("pixHeight", scanStr, ":", "\r")
			variable zscaling = numberbykey ("ZstepSize", scanStr, ":", "\r")
			variable zOffset = numberbykey ("zPos", scanStr, ":", "\r")
			variable zPix = numberbykey ("NumFrames", scanStr, ":", "\r")
			// Check existence of selected wave(s)
			variable zWaveType
			if ((doChans & 1) || (doChans & 4))
				WAVE zwave1 =  $"root:twoP_scans:" + CurScan +  ":" + curScan + "_ch1"
				if (!(WaveExists (zwave1)))
					doalert 0, "Failure making 3D panel: I can't sem to find channel 1 for that scan, \"" + CurScan + "\"."
					return 1
				endif
				zWaveType = wavetype (zwave1)
			endif
			if ((doChans & 2) || (doChans & 4))
				WAVE zwave2 =  $"root:twop_scans:" + CurScan +  ":" + curScan + "_ch2"
				if (!(WaveExists (zwave2)))
					doalert 0, "Failure making 3D panel: I can't sem to find channel 2 for that scan, \"" + CurScan + "\"."
					return 1
				endif
				zWaveType = wavetype (zwave2)
			endif
			// make requested 3d panels
			SVAR top3d =  root:packages:twoP:examine:Top3D
			variable ii
			string imChanStr
			for (ii=0;ii < 3; ii += 1)
				if (!((2^ii) & doChans))
					continue
				endif
				if (ii ==2)
					imChanStr = "3"
				else
					imChanStr = num2str (2^ii)
				endif
				// Set Top 3d global string to this 3D viewer
				top3D = CurScan + "_3D_" + imChanStr
				// Bring window to front; if it exists, no need to remake globals
				doWindow/F $CurScan + "_3D_" + imChanStr
				if (V_Flag)
					continue
				endif
				//Make a folder to hold temp stuff for this 3Dpanel
				string path = "root:packages:twop:examine:" + CurScan + "_3D_" + imChanStr
				newdatafolder/o $path
				// make global variables for sliders, etc.
				variable/G $path + ":Xslider"
				variable/G $path + ":YSlider"
				variable/G $path + ":ZSlider"
				variable/G $path + ":xStart"
				variable/G $path + ":yStart"
				variable/G $path + ":zStart"
				variable/G $path + ":xEnd"
				variable/G $path + ":Yend"
				variable/G $path + ":startP"
				variable/G $path + ":endP"  
				variable/G $path + ":Zend"
				// make waves for draggers
				make/o  $path + ":INFwave" = {-INF,INF}
				WAVE INFwave =  $path + ":INFwave"
				make/o  $path + ":xValWave" = {xOffset,xOffset}
				WAVE xValWave =  $path + ":xValWave"
				make/o  $path + ":yValWave" = {yOffset,yOffset}
				WAVE yValWave =  $path + ":yValWave"
				make/o  $path + ":zValWave" = {zOffset,zOffset}
				WAVE zValWave =  $path + ":zValWave"
				//Make X ,Y,Z frame waves
				if ((ii ==0) || (ii ==2)) 
					make/o/y=(zWaveType)/n= ((yPix), (zPix)) $path +  ":XsliceCh1"
					WAVE XSliceCh1 =  $path + ":XsliceCh1"
					WAVE XSlice =  $path + ":XsliceCh1"
					SetScale/P x (yOffset),(yScaling),"m", XSliceCh1
					SetScale/P y (zOffset),(zScaling),"m", XSliceCh1
					ProjectXSlice (zwave1, XSliceCh1, 0)
					make/o/y=(zWaveType)/n= ((xPix), (zPix)) $path + ":YsliceCh1"
					WAVE YSliceCh1 =  $path + ":YsliceCh1"
					WAVE YSlice =  $path + ":YsliceCh1"
					SetScale/P x (xOffset),(xScaling),"m", YSliceCh1
					SetScale/P y (zOffset),(zScaling),"m", YSliceCh1
					ProjectYSlice (zwave1, YSliceCh1, 0)
					make/o/y=(zWaveType)/n= ((xPix), (yPix)) $path + ":ZsliceCh1"
					WAVE ZSliceCh1 = $path + ":ZsliceCh1"
					WAVE ZSlice = $path + ":ZsliceCh1"
					SetScale/P x (xOffset),(xScaling),"m", zSliceCh1
					SetScale/P y (yOffset),(yScaling),"m", zSliceCh1
					ProjectZSlice (zwave1, zSliceCh1, 0)
					// reference colortable 
					NVAR FirstLUTColor = root:Packages:twoP:examine:Ch1FirstLUTColor
					NVAR LastLutColor = root:Packages:twoP:examine:Ch1LastLUTColor
					SVAR CTableStr = root:Packages:twoP:examine:Ch1CTableStr
					NVAR inVert =root:Packages:twoP:examine:Ch1LUTInvert
				endif
				if ((ii ==1) || (ii ==2)) 
					make/o/y=(zWaveType)/n= ((yPix), (zPix)) $path + ":XsliceCh2"
					WAVE XSliceCh2 =  $path + ":XsliceCh2"
					WAVE XSlice =  $path + ":XsliceCh2"
					SetScale/P x (yOffset),(yScaling),"m", XSliceCh2
					SetScale/P y (zOffset),(zScaling),"m", XSliceCh2
					ProjectXSlice (zwave2, XSliceCh2, 0)
					make/o/y=(zWaveType)/n= ((xPix), (zPix))$path  + ":YsliceCh2" 
					WAVE YSliceCh2 =  $path + ":YsliceCh2"
					WAVE YSlice =  $path + ":YsliceCh2"
					SetScale/P x (xOffset),(xScaling),"m", YSliceCh2
					SetScale/P y (zOffset),(zScaling),"m", YSliceCh2
					ProjectYSlice (zwave2, ySliceCh2, 0)
					make/o/y=(zWaveType)/n= ((xPix), (yPix)) $path + ":ZsliceCh2"
					WAVE ZSliceCh2 = $path + ":ZsliceCh2"
					WAVE ZSlice = $path + ":ZsliceCh2"
					SetScale/P x (xOffset),(xScaling),"m", zSliceCh2
					SetScale/P y (yOffset),(yScaling),"m", zSliceCh2
					ProjectZSlice (zwave2, zSliceCh2, 0)
					// reference colortable varibales
					NVAR FirstLUTColor = root:Packages:twoP:examine:Ch2FirstLUTColor
					NVAR LastLutColor = root:Packages:twoP:examine:Ch2LastLUTColor
					SVAR CTableStr = root:Packages:twoP:examine:Ch2CTableStr
					NVAR inVert =root:Packages:twoP:examine:Ch2LUTInvert
				endif
				if (ii == 2)
					make/o/w/u/n= ((yPix), (zPix),3) $path + ":XsliceMrg"
					WAVE XSliceMrg =  $path + ":XsliceMrg"
					WAVE XSlice =  $path + ":XsliceMrg"
					SetScale/P x (yOffset),(yScaling),"m", XSliceMrg
					SetScale/P y (zOffset),(zScaling),"m", XSliceMrg
					NQ_3DGetRGBSlice (Top3D, "x")
					make/o/w/u/n= ((xPix), (zPix), 3)$path + ":YsliceMrg" 
					WAVE YSliceMrg =  $path +  ":YsliceMrg"
					WAVE YSlice =  $path +  ":YsliceMrg"
					SetScale/P x (xOffset),(xScaling),"m", YSliceMrg
					SetScale/P y (zOffset),(zScaling),"m", YSliceMrg
					NQ_3DGetRGBSlice (Top3D, "y")
					make/o/w/u/n= ((xPix), (yPix), 3) $path + ":ZsliceMrg"
					WAVE ZSliceMrg = $path + ":ZsliceMrg"
					WAVE ZSlice = $path + ":ZsliceMrg"
					SetScale/P x (xOffset),(xScaling),"m", zSliceMrg
					SetScale/P y (yOffset),(yScaling),"m", zSliceMrg
					NQ_3DGetRGBSlice (Top3D, "z")
				endif
				// Make the graph with subwindows for each view
				// open the graph
				display/k=1/N= $CurScan + "_3D_" + imChanStr/W= (0, 44,800,644 ) as CurScan + "_3D_" + imChanStr
				// Put on the 3 graphs in subwindows
				//Xslice plotted y vs z
				Display/HOST=# INFwave vs yValwave
				ModifyGraph rgb(INFwave)=(0,65535, 0), quickdrag(INFwave)=1
				appendtoGraph  zValwave vs INFwave
				ModifyGraph rgb(zValwave)=(0,0,65535), quickdrag(zValwave)=1
				AppendImage xSlice
				ModifyImage $nameofwave(xSlice)  ctab= {FirstLUTColor,LastLutColor,$CTableStr,inVert}
				ModifyGraph swapXY=1, axThick=0,standoff=0
				SetAxis/A/R bottom
				ModifyGraph margin=1
				ModifyGraph  nticks=0, noLabel=2
				RenameWindow #,GX
				SetActiveSubwindow ##
				// Y slice plotted z vs x
				Display/HOST=#  ZvalWave vs INFwave
				ModifyGraph rgb(ZvalWave)=(0, 0, 65535), quickdrag(ZvalWave)=1
				appendtograph INFwave vs xValWave
				ModifyGraph rgb(INFwave)=(65535, 0,0), quickdrag(INFwave)=1
				AppendImage YSlice
				ModifyImage $nameofwave (YSlice)  ctab= {FirstLUTColor,LastLutColor,$CTableStr,inVert}
				ModifyGraph margin=1, axThick=0,standoff=0
				ModifyGraph  nticks=0, noLabel=2
				RenameWindow #,GY
				SetActiveSubwindow ##
				// Z-slice - plotted Y vs X
				Display/HOST=#  yValWave vs INFwave
				ModifyGraph rgb(yValWave)=(0,65535, 0), quickdrag(yValWave)=1
				appendtograph INFWave vs xValWave
				ModifyGraph rgb(INFWave)=(65535, 0,0), quickdrag(INFWave)=1
				AppendImage zslice
				ModifyImage $nameofwave (zSlice)  ctab= {FirstLUTColor,LastLutColor,$CTableStr,inVert}
				ModifyGraph margin=1, axThick=0,standoff=0
				ModifyGraph  nticks=0, noLabel=2
				RenameWindow #,GZ
				SetActiveSubwindow ##
				// adjust subwindows to size
				NQ_3DResize (top3d, 0, 44, 800, 644)
				// set hook function for window resizing, etc.
				SetWindow  $CurScan + "_3D_" + imChanStr hook (Hook3D)= NQ_3DHook, hookevents = 0
				// make a control panel specific to this 3D viewer
				NewPanel/K=2/W=(2,44,165,287)/N=$CurScan + "_3D_" + imChanStr + "Controls" as CurScan + "_3D_" +  imChanStr
				modifyPanel fixedSIze = 1
				// Draw text titles X,Y, and Z
				SetDrawLayer UserBack
				SetDrawEnv fsize= 20,fstyle= 1, textrgb= (65535,0,0)
				DrawText 23,25,"X"
				SetDrawEnv fsize= 20,fstyle= 1, textrgb= (0, 65535, 0)
				DrawText 77,25,"Y"
				SetDrawEnv fsize= 20,fstyle= 1, textrgb= (0, 0, 65535)
				DrawText 130,25,"Z"
				// SLiders for each
				Slider Xslider,pos={3,26},size={53,144},proc=NQ_3DSliderProc
				Slider Xslider,limits={0,(xPix - 1),1},variable=  $path + ":Xslider",thumbColor= (65535,0,0)
				Slider YSlider,pos={57,27},size={53,144},proc=NQ_3DSliderProc
				Slider YSlider,limits={0,(yPix -1),1},variable=  $path + ":Yslider",thumbColor= (0,65535,0)
				Slider ZSlider,pos={113,27},size={47,144},proc=NQ_3DSliderProc
				Slider ZSlider,limits={0,(zpix-1),1},variable=  $path + ":Zslider",thumbColor= (0,0,65535)
				// Show/Hide axes
				CheckBox xAxisCheck,pos={8,177},size={42,16},proc=NQ_3DAxisCheckProc,title="Axis"
				CheckBox xAxisCheck,fSize=12,value= 0
				CheckBox yAxisCheck,pos={62,177},size={42,16},proc=NQ_3DAxisCheckProc,title="Axis"
				CheckBox yAxisCheck,fSize=12,value= 0
				CheckBox zAxisCheck,pos={115,177},size={42,16},proc=NQ_3DAxisCheckProc,title="Axis"
				CheckBox zAxisCheck,fSize=12,value= 0
				// Save Buttons
				Button XsaveButton,pos={7,195},size={44,20},proc=SaveButtonProc,title="save"
				Button XsaveButton,fSize=12
				Button YsaveButton,pos={61,195},size={44,20},proc=SaveButtonProc,title="save"
				Button YsaveButton,fSize=12
				Button ZsaveButton,pos={114,195},size={44,20},proc=SaveButtonProc,title="save"
				Button ZsaveButton,fSize=12
				// Export Buttons
				Button XexportButton,pos={7,218},size={44,20},proc=SaveButtonProc,title="export"
				Button XexportButton,fSize=12
				Button YexportButton,pos={61,218},size={44,20},proc=SaveButtonProc,title="export"
				Button YexportButton,fSize=12
				Button ZexportButton,pos={114,218},size={44,20},proc=SaveButtonProc,title="export"
				Button ZexportButton,fSize=12
			endfor
			break
	endswitch
	return 0
end

//******************************************************************************************************
// Hook function for the graph
Function NQ_3DHook (s)
	STRUCT WMWinHookStruct &s

	Variable hookResult = 0
	switch (s.eventCode)
		case 0:  // activate
			SVAR Top3D = root:packages:twoP:examine:Top3D
			Top3D = s.winName
			hookResult = 1
			break
		case 2:  // kill
			KillWindow $s.winName
			KillWindow $s.winName + "Controls"
			KillDataFolder $"root:packages:twoP:examine:" + s.winName
			hookresult = 1
			break
		case 6:  // resize
			SVAR Top3D = root:packages:twoP:examine:Top3D
			GetWindow $Top3D wsize
			NQ_3DResize (Top3D, V_left, V_top,  V_right, V_bottom)
			hookResult = 1
			break
	endswitch
	return hookResult
end

//******************************************************************************************************
// resizes3D viewer to fit in allotted space, within constraints of proportional scaling
Function NQ_3DResize (The3DScanName, left, top, right, bottom)
	string The3DScanName
	variable  left, top, right, bottom
	
	string theScan =removeEnding (removeEnding (removeEnding (the3dscanName, "_3D_1"), "_3D_2"), "_3D_3")
	SVAR scanStr = $"root:twoP_scans:" + theScan + ":" + theScan + "_info"
	// read in Scaling and offsets
	variable xscaling = numberbykey ("XpixSize", scanStr, ":", "\r")
	variable xPix = numberbyKey ("PixWidth", scanStr, ":", "\r")
	variable yscaling =  numberbykey ("YpixSize", scanStr, ":", "\r")
	variable yPix = numberbykey ("pixHeight", scanStr, ":", "\r")
	variable zscaling = abs (numberbykey ("ZstepSize", scanStr, ":", "\r"))
	variable zPix = numberbykey ("NumFrames", scanStr, ":", "\r")
	// width and height of resized panel
	variable WinWidth = right - left 
	variable WinHeight = bottom - top
	//calculate height and width and multiplier to fit in the box
	variable Pixwidth = xPix * xScaling + zPix * zScaling
	variable Pixheight =  yPix * yScaling +  zPix * zScaling
	variable mult = min (WinWidth/Pixwidth, WinHeight/Pixheight)
	// Move main window
	variable pleft = left, ptop = top
	variable pright = left + pixWidth * mult, pBottom = top + pixHeight * mult
	movewindow/w=$The3DScanName pleft, ptop, pright, pbottom
	// variables for moving subwindows
	string CommandStr
	variable gLeft, gRight, gTop, gBottom
	string SubWinName
	//Xslice
	GLeft =0
	gright = zPix * zScaling * mult
	gtop =  zPix * zScaling * mult
	gBottom = gtop + yPix * yScaling * mult
	subwinName = The3DScanName + "#GX"
	sprintf CommandStr "MoveSubWindow/W=%s, fnum = (%d, %d, %d, %d)", subwinName, gLeft, gTop, gRight, gBottom
	Execute CommandStr
	//Yslice
	gleft = zPix * zScaling * mult
	gright = gleft + xPix * xScaling * mult
	gtop = 0
	gbottom = zPix * zScaling * mult
	subwinName = The3DScanName + "#GY"
	sprintf CommandStr "MoveSubWindow/W=%s, fnum = (%d, %d, %d, %d)", subwinName, gLeft, gTop, gRight, gBottom
	Execute CommandStr
	// Z-slice
	gLeft = zPix * zScaling * mult
	gright = gleft + xPix * xScaling * mult
	gtop = zPix * zScaling * mult 
	gbottom = gtop + yPix * yScaling * mult
	subwinName = The3DScanName + "#GZ"
	sprintf CommandStr "MoveSubWindow/W=%s, fnum = (%d, %d, %d, %d)", subwinName, gLeft, gTop, gRight, gBottom
	Execute CommandStr
end

//******************************************************************************************************
// runs the sliders for position
Function NQ_3DSliderProc(sa) : SliderControl
	STRUCT WMSliderAction &sa

	switch( sa.eventCode )
		case -1: // kill
			break
		default:
			if ((( sa.eventCode & 1 ) || (sa.eventCode & 4)) || (sa.eventCode & 2)) // value set or mouse up
				Variable curval = sa.curval
				SVAR Top3D = root:packages:twoP:examine:Top3D
				string theScan = removeEnding (removeEnding (removeEnding (Top3D, "_3D_1"), "_3D_2"), "_3D_3")
				variable theChannel = str2num (Top3D [strlen (top3D)-1])
				// slider for each dimension, name starts with X, Y, or Z
				string DimStr =sa.ctrlName
				DimStr = DimStr [0]
				variable dimension
				if (cmpStr (DimStr, "X") == 0)
					dimension = 0
				elseif (cmpStr (DimStr, "Y") == 0)
					dimension = 1
				else
					dimension = 2
				endif
				if (sa.eventmod & 2)  // shift held down, so save start location in global or make maximum projection
					if (sa.eventCode & 2)  // mouse down event
						NVAR startP = $"root:packages:twoP:examine:" + Top3D + ":startP" 
						startP = curval
					elseif  (sa.eventCode & 4) // mouse up event 
						NVAR startP = $"root:packages:twoP:examine:" + Top3D + ":startP"
						printf "%s-projection of %s: Start Position = %g, EndPosition = %g\r", DimStr, theScan, StartP, curval
						if (theChannel & 1)		
							WAVE InPutWave1 =  $"root:twoP_Scans:" + theScan + ":" + theScan + "_ch1"
							WAVE Slice1 =  $"root:packages:twoP:examine:" + Top3D + ":" + dimStr + "sliceCh1"
							ProjectSpecFrames (inputWave1, min (startP, curval), max (startP, curval), Slice1, 0, dimension,1) //^^^
						endif
						if (theChannel & 2)		
							WAVE InPutWave2 = $"root:twoP_Scans:" + theScan + ":" + theScan + "_ch2"
							WAVE Slice2 =  $"root:packages:twoP:examine:" + Top3D + ":" + dimStr + "sliceCh2"
							ProjectSpecFrames (inputWave2, min (startP, curval), max (startP, curval), Slice2, 0, dimension,1)
						endif
						if (theChannel== 3)
							NQ_3DGetRGBSlice (Top3D, dimStr)
						endif
					else // for other events with shift key held down, such as mouse moved, just do the usual thing of getting a single frame
						sa.eventmod = 0 // call the function with same structure after setting event mods to 0
						NQ_3DSliderProc (sa)
					endif
				else // Shift not held down, just show a single frame, and move draggers to position
					SVAR scanStr = $"root:twoP_Scans:" + theScan + ":" + theScan + "_info"
					variable scaling, offset
					FUNCREF NQ_3DPST ProjectSlice = $"Project" + DimStr + "Slice"		
					if (theChannel & 1)	
						WAVE InPutWave1 = $"root:twoP_Scans:" + theScan + ":" + theScan + "_ch1"
						WAVE Slice1 =  $"root:packages:twoP:examine:" + Top3D + ":" + dimStr + "sliceCh1"
						ProjectSlice  (InPutWave1, Slice1, curval)						
					endif
					if (theChannel & 2)	
						WAVE InPutWave2 = $"root:twoP_Scans:" + theScan + ":" + theScan + "_ch2"
						WAVE Slice2 =  $"root:packages:twoP:examine:" + Top3D + ":" + dimStr + "sliceCh2"

						ProjectSlice  (InPutWave2, Slice2, curval)
					endif
					if (theChannel== 3)
						NQ_3DGetRGBSlice (Top3D, dimStr)
					endif
					// move dragger
					scaling =  numberbykey (DimStr + SelectString((cmpstr (dimStr, "Z")) , "stepsize", "pixsize"), scanStr, ":", "\r")
					offset = numberbykey (DimStr + "pos", scanStr, ":", "\r")
					WAVE ValWave = $"root:packages:twoP:examine:" + Top3D + ":" + dimStr + "ValWave"
					ValWave = offset + curVal * scaling
				endif
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
// FYI you can't use a function from an XOP as a function reference template, but you  CAN MAKE a reference to an XOP function 
threadsafe Function NQ_3DPST (InPutWave, Slice, curval)
	WAVE inputWave
	WAVE Slice
	variable curVal
end

//******************************************************************************************************
//  
Function NQ_3DSaveButtonProc (ctrlName) : ButtonControl
	String ctrlName
	
	SVAR Top3D = root:packages:twoP:examine:Top3D
	strswitch (ctrlName)
		case "saveXButton":
			WAVE Slice =  $"root:packages:twoP:examine:" + Top3D + "_3D:Xslice"
			break
		case "SaveYButton":
			WAVE Slice =  $"root:packages:twoP:examine:" + Top3D + "_3D:Yslice"
			break
		case "SaveZButton":
			WAVE Slice =  $"root:packages:twoP:examine:" + Top3D + "_3D:Zslice"
			break
	endswitch
	imagesave/D=16/T="TIFF" Slice	
End


//ExportGreyScaleTIFF (datawave, ExportPath, outPutType, Scaling, [minVal, maxVal, TimeInSecs, FileNameStr])
//******************************************************************************************************
// 
Function NQ_3DGetRGBSlice (Top3D, dimStr)
	string Top3D
	string dimStr // x,y, or z
	// Get curScan from top3D string
	String curScan = stringfromlist (0, Top3D ,"_")
	// Variables for brightness/contrast of the 2 channels
	NVAR first1 = root:packages:twoP:examine:CH1FirstLutColor
	NVAR Last1 = root:packages:twoP:examine:CH1LastLutColor
	NVAR first2 = root:packages:twoP:examine:CH2FirstLutColor
	NVAR Last2 = root:packages:twoP:examine:CH2LastLutColor
	// keep track of which channel is red, which green
	variable rangeVarRed, rangeVarGreen
	string chanSuffixRed, chanSuffixGreen
	// range scaling and channel selection for red and green
	if (kRedChan == 1)
		rangeVarRed = 65536/(last1 - first1)
		rangeVarGreen = 65536/(last2 - first2)
		chanSuffixRed = "sliceCh1"
		chanSuffixGreen = "sliceCh2"
	else
		rangeVarGreen = 65536/(last1 - first1)
		rangeVarRed = 65536/(last2 - first2)
		chanSuffixGreen = "sliceCh1"
		chanSuffixRed = "sliceCh2"
	endif
	// reference input waves and outPutWave
	WAVE RedWave =  $"root:packages:twoP:examine:" + Top3D + ":"  + dimStr + chanSuffixRed
	WAVE GreenWave = $"root:packages:twoP:examine:" + Top3D + ":"  + dimStr + chanSuffixGreen
	WAVE MrgWave =  $"root:packages:twoP:examine:" + Top3D + ":"  + dimStr + "sliceMrg"
	// red plane is layer 0 and green plane is layer 1
	MrgWave [] [] [0] =  min (65535, max (0,(RedWave [p] [q] - first1) * rangeVarRed))
	MrgWave [] [] [1] =  min (65535, max (0,(GreenWave [p] [q] - first1) * rangeVarGreen))
end

Function NQ_3DAxisCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			break
	endswitch

	return 0
End
