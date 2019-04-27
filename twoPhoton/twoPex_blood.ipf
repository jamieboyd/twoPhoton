#pragma rtGlobals=1	// Use modern global access method.
#pragma version = 1.7	// modification date: 2012/07/03 by Jamie Boyd
#pragma IgorVersion = 6.1

//******************************************************************************************************
//------------------------------- Code for The Blood tab on the 2P Examine TabControl--------------------------------------------
//******************************************************************************************************
//******************************************************************************************************
// Graph Marquee functions to do useful things on the scan graph
Menu "GraphMarquee"
	Submenu "2P Examine"
		"Blood Blocked", /Q, NQ_SetBloodBlocked()
	end
end

Menu "Macros"
	"Median chan 1/1",/Q, mf ()
	"Sixty to Fourty",/q, print Un60()
	submenu "2P"
		submenu "Examine"
			"Set Cortical Surface/3",/Q, NQ_SetTop ()
			"Get Cortical Depth/2",/Q, NQ_GetDepth ()
			"Show Blood Data/4",/Q,  bloodToFront ()
		end
	end
end


function bloodToFront ()
	dowindow/f blood_SW
end

function HB ()
	svar curscan = root:packages:jb_nidaq:examine:curScan
	WAVE blood_FFT = root:blood_FFT
	WAVE/Z theWave = $"root:Nidaq_Scans:" + curScan + ":" +curScan + "_R0_ch1avg"
	if (!(WaveExists (theWave)))
		wave/Z theWave =$"root:nidaq_Scans:" + curScan + ":" + curScan + "_velocityR"
	endif
	if (!(WaveExists (theWave)))
		doalert 0, "No Such ROI or velocity"
		return 1
	endif
	
	variable pts = numpnts (theWave)
	if (mod (pts, 2))
		FFT/OUT=4/WINF=Hanning/RP=[1, pts-1]/DEST=root:blood_FFT theWave
	else
		FFT/OUT=4/WINF=Hanning/DEST=root:blood_FFT theWave
	endif
	// edit note 
	wavestats/q/r = (2.5,10) blood_FFT
	
	SVAR scanInfo = $"root:Nidaq_scans:" + curScan + ":" + curScan + "_info"
	string noteStr = StringByKey("ExpNote", scanInfo, ":", "\r")
	notestr = replaceNumberbykey ("heartbeat", noteStr, round (V_maxloc * 100)/100, "=", ";")
	scanInfo = replaceStringBykey ("ExpNote", scanInfo, noteStr, ":", "\r")
	 NQ_showNote ("root:NIDAQ_Scans:" + CurScan + ":" + curScan +"_info")
	doWIndow/F Graph0
	
	
end

function mf ()
	wave theWave = $sc1()
	NQ_Median (theWave, 3, 1, thewave)
end



// some constants for blood
static constant kBloodAllHiCut = 20 //Hz cut off for filtering image
//******************************************************************************************************
// function for adding  the controls for the Blood tab.
// Last Modified Mar 16 2012 by Jamie Boyd
Function NQexBlood_add (able)
	variable able
	
	// globals for blood tab
	// One or many scans to do
	variable/G root:packages:JB_NIDAQ:examine:BloodDoMatch = 0
	String/G root:packages:JB_NIDAQ:examine:BloodMatchStr
	// which channel to analyze (only one channel can be selected at a time for blood)
	 variable/G root:packages:jb_nidaq:examine:BloodChan =1
	// left and right boundaries of area to analyze
	variable/g root:Packages:JB_NIDAQ:examine:bloodWinLeft
	variable/g root:Packages:JB_NIDAQ:examine:bloodWinRight
	// Do all image at once, or sample by time
	variable/g root:Packages:JB_NIDAQ:examine:bloodDoSample =0
	// sampling frequency and overlap
	variable/g root:Packages:JB_NIDAQ:examine:bloodSampleFreq = 30 // samples/second
	variable/g root:Packages:JB_NIDAQ:examine:bloodSampleOverlap = 150 // overlap of each sample with previous and subsequent sample
	// For Radon Method
	variable/g root:Packages:JB_NIDAQ:examine:bloodDoRadon =1
	variable/G root:packages:jb_nidaq:examine:bloodRadonRays =1 // 0 to do whole range of angles from -¹/2 to ¹/2, 1 to do selected range
	variable/g root:Packages:JB_NIDAQ:examine:bloodEstVelocity = 1.5e-03 // when doing selected range, center speed in M/sec
	variable/g root:Packages:JB_NIDAQ:examine:bloodVelocitySpace = 0.25e-03 // when doing selected range, space on either side of center speed
	variable/g root:Packages:JB_NIDAQ:examine:bloodVelocityPrecision=1e03 // #angles to draw per ¹ radians (more angles translatees to greater precision of result)
	variable/G root:packages:JB_Nidaq:examine:bloodRadonAngle
	// For Counting blood cells
	variable/G root:packages:JB_Nidaq:examine:bloodDoCount =0
	variable/G root:packages:JB_Nidaq:examine:bloodCountHighCut = 10
	variable/G root:packages:JB_Nidaq:examine:bloodCountLowCut = 200
	variable/G root:packages:JB_Nidaq:examine:bloodCountProfileWidth = 50
	variable/G root:packages:JB_Nidaq:examine:bloodCountMaxPeakPos = -0.1
	variable/G root:packages:JB_Nidaq:examine:bloodCountMinPeakSIze= .1
	variable/G root:packages:jb_nidaq:examine:bloodDrmb =0 // used to monitor recursion in blood display graphs
	// Check to show intermediate steps
	variable/g root:Packages:JB_NIDAQ:examine:bloodShowMe = 0 // variable for check box to show each calculation
	// Controls for Blood Tab
	// One or many Scans
	CheckBox BloodCurScanCheck win=Nidaq_controls,disable = able, pos={8,411},size={80,14},proc=TCU_RadioButtonProcSetGlobal,title="Current Scan"
	CheckBox BloodCurScanCheck win=Nidaq_controls,userdata= A"Ec5l<3cJM;CLLjeF#lo[?VX0\\5uB[SG[YH'DIkjqCi=6&6uPe.FCSuI0KVU;Df9/PCi!$[@;^-RBOt[h3r"
	CheckBox BloodCurScanCheck win=Nidaq_controls,fSize=10,value= 1,mode=1
	CheckBox BloodAllScansCheck win=Nidaq_controls,disable = able,pos={100,412},size={109,14},proc=TCU_RadioButtonProcSetGlobal,title="All Scans matching"
	CheckBox BloodAllScansCheck win=Nidaq_controls,userdata= A"Ec5l<3cJM;CLLjeF#lo[?VX0\\5uB[SG[YH'DIkjqCi=6&6uPe.FCSuI0fq^<Df9/RF`LDj@;\\GGARfL;"
	CheckBox BloodAllScansCheck win=Nidaq_controls,fSize=10,value= 0,mode=1
	SetVariable BloodMatchSetVar win=Nidaq_controls,disable = able, pos={212,411},size={68,16},title=" "
	SetVariable BloodMatchSetVar win=Nidaq_controls,help={"This string is wild-card enabled. Use \"*\" to save all scans."}
	SetVariable BloodMatchSetVar win=Nidaq_controls,fSize=10
	SetVariable BloodMatchSetVar win=Nidaq_controls,value= root:Packages:JB_NIDAQ:examine:BloodMatchStr
	// show position buttom
	Button bloodShowLineScanButton win=Nidaq_controls, disable=able, pos={121,427},size={78,19},proc=NQ_BloodShowLSposButtonProc,title="Show Position"
	// Channel checks
	CheckBox BloodCheck1 win=Nidaq_controls,disable = able,pos={9,430},size={48,14},proc=TCU_RadioButtonProcSetGlobal,title="Chan 1"
	CheckBox BloodCheck1 win=Nidaq_controls,userdata= A"Ec5l<3cJM;CLLjeF#n&F?Z'Rg@<\">>G[YH'DIkjqCi=6&6YKnG4Y]#bCi=6&6YL%@CGIs"
	CheckBox BloodCheck1 win=Nidaq_controls,value= 1,mode=1
	CheckBox BloodCheck2 win=Nidaq_controls,disable = able, pos={63,430},size={48,14},proc=TCU_RadioButtonProcSetGlobal,title="Chan 2"
	CheckBox BloodCheck2 win=Nidaq_controls,userdata= A"Ec5l<3cJM;CLLjeF#n&F?Z'Rg@<\">>G[YH'DIkjqCi=6&6YKnG4Yf)cCi=6&6YL%@CG@m"
	CheckBox BloodCheck2 win=Nidaq_controls,value= 0,mode=1
	// window position
	SetVariable bloodWinLeftSetVar win=Nidaq_controls,disable = able, pos={8,449},size={131,15},proc=SIformattedSetVarProc2,title="Window Left"
	SetVariable bloodWinLeftSetVar win=Nidaq_controls,format="%.2W0Pm"
	SetVariable bloodWinLeftSetVar win=Nidaq_controls,limits={-inf,inf,1e-05},value= root:Packages:JB_NIDAQ:examine:bloodWinLeft
	SetVariable bloodWinRightSetVar win=Nidaq_controls,disable =able, pos={145,449},size={100,15},proc=SIformattedSetVarProc2,title="Right"
	SetVariable bloodWinRightSetVar win=Nidaq_controls,format="%.2W0Pm"
	SetVariable bloodWinRightSetVar win=Nidaq_controls,limits={-inf,inf,1e-05},value= root:Packages:JB_NIDAQ:examine:bloodWinRight
	Button bloodFullScaleButton win=Nidaq_controls,disable = able,pos={248,446},size={36,20},proc=NQ_BloodFullScaleProc,title="Full"
	// Timing
	TitleBox BloodTimeTitle win=Nidaq_controls,disable = able,pos={8,472},size={21,12},title="Time",frame=0
	CheckBox BloodAllAtOnceCheck win=Nidaq_controls,pos={34,471},size={29,14},proc=TCU_RadioButtonProcSetGlobal,title="All"
	CheckBox BloodAllAtOnceCheck win=Nidaq_controls,disable = able,userdata= A"Ec5l<3`'6pCLLjeF#lo[?VX0\\5uB[SG[YH'DIkk<Ci=6&6uQ\"4D/a<&4YSraCi=6&;djN^Ch5tIARfL;"
	CheckBox BloodAllAtOnceCheck win=Nidaq_controls,value= 1,mode=1
	CheckBox BloodSampleCheck win=Nidaq_controls,disable = able,pos={67,471},size={49,14},proc=TCU_RadioButtonProcSetGlobal,title="Sample"
	CheckBox BloodSampleCheck win=Nidaq_controls,userdata= A"Ec5l<3`'6pCLLjeF#lo[?VX0\\5uB[SG[YH'DIkk<Ci=6&6uQ\"4D/a<&4Y]#bCi=6&6#:@'FAHdaAOC-B@qu"
	CheckBox BloodSampleCheck win=Nidaq_controls, value= 0,mode=1
	SetVariable BloodTimeSpacingSetvar win=Nidaq_controls,disable = able,pos={120,471},size={74,15},title="freq"
	SetVariable BloodTimeSpacingSetvar win=Nidaq_controls,format="%g Hz"
	SetVariable BloodTimeSpacingSetvar win=Nidaq_controls,limits={1,1000,1},value= root:Packages:JB_NIDAQ:examine:bloodSampleFreq
	SetVariable BloodTimeOverlapSetvar win=Nidaq_controls,disable = able,pos={195,471},size={89,15},title="Overlap"
	SetVariable BloodTimeOverlapSetvar win=Nidaq_controls,format="%g %"
	SetVariable BloodTimeOverlapSetvar win=Nidaq_controls,limits={1,inf,5},value= root:Packages:JB_NIDAQ:examine:bloodSampleOverlap
	// Radon
	CheckBox BloodRadonCheck win=Nidaq_controls,disable = able,pos={9,495},size={45,14},title="Radon"
	CheckBox BloodRadonCheck win=Nidaq_controls,variable= root:Packages:JB_NIDAQ:examine:bloodDoRadon
	SetVariable BloodPrecisionSetvar win=Nidaq_controls,disable = able,pos={62,495},size={146,15},title="Ray Density"
	SetVariable BloodPrecisionSetvar win=Nidaq_controls,format="%g/¹ radians"
	SetVariable BloodPrecisionSetvar win=Nidaq_controls,limits={-inf,inf,1e-06},value= root:Packages:JB_NIDAQ:examine:bloodVelocityPrecision
	Button BloodMaxRaysButton win=Nidaq_controls,disable = able,pos={223,493},size={58,20},proc=NQ_BloodEstMaxRaysButtonProc,title="Est Max"
	TitleBox BloodVelocityRangeTitle win=Nidaq_controls,disable = able,pos={15,516},size={65,12},title="Velocity Range"
	TitleBox BloodVelocityRangeTitle win=Nidaq_controls,frame=0
	CheckBox BloodAngleRangeCheck1 win=Nidaq_controls,disable = able,pos={85,515},size={43,14},proc=TCU_RadioButtonProcSetGlobal,title="Entire"
	CheckBox BloodAngleRangeCheck1 win=Nidaq_controls,userdata= A"Ec5l<3cJM;CLLjeF#n&F?Z'Rg@<\">>G[YH'DIkk<Ci=6&;IO*SDGjngF$23=6>URYA3k*GCh6LQDJ*NJBOt[h1-5"
	CheckBox BloodAngleRangeCheck1 win=Nidaq_controls,value= 1,mode=1
	CheckBox BloodAngleRangeCheck2 win=Nidaq_controls,pos={131,515},size={55,14},proc=TCU_RadioButtonProcSetGlobal,title="Selected"
	CheckBox BloodAngleRangeCheck2 win=Nidaq_controls,disable = able,userdata= A"Ec5l<3cJM;CLLjeF#n&F?Z'Rg@<\">>G[YH'DIkk<Ci=6&;IO*SDGjngF$26>6>URYA3k*GCh6LQDJ*NJBOt[h0fo"
	CheckBox BloodAngleRangeCheck2 win=Nidaq_controls,value= 0,mode=1
	SetVariable BloodEstSpeedSetvar win=Nidaq_controls,disable = able,pos={188,515},size={94,15},proc=SIformattedSetVarProc2,title=" "
	SetVariable BloodEstSpeedSetvar win=Nidaq_controls,userdata= A"4\"W0u/MJqA0kDpj1-74%/MK(E@<H[1Bl7D"
	SetVariable BloodEstSpeedSetvar win=Nidaq_controls,format="%.2W1Pm/sec"
	SetVariable BloodEstSpeedSetvar win=Nidaq_controls,limits={-inf,inf,0.0001},value= root:Packages:JB_NIDAQ:examine:bloodEstVelocity
	SetVariable BloodVelocityRangeSetvar win=Nidaq_controls,disable = able,pos={187,535},size={95,15},proc=SIformattedSetVarProc2,title="+/-"
	SetVariable BloodVelocityRangeSetvar win=Nidaq_controls,format="%.2W1Pm/s"
	SetVariable BloodVelocityRangeSetvar win=Nidaq_controls,limits={-inf,inf,0.0001},value= root:Packages:JB_NIDAQ:examine:bloodVelocitySpace
	// Blood Cell Count
	CheckBox bloodCountCellscheck win=Nidaq_controls,disable = able,pos={9,581},size={44,14},title="Count"
	CheckBox bloodCountCellscheck win=Nidaq_controls,variable= root:Packages:JB_NIDAQ:examine:bloodDoCount
	SetVariable bloodCountMinSizeSetVar win=Nidaq_controls,disable = able,pos={70,581},size={111,15},title="Peak Min Size"
	SetVariable bloodCountMinSizeSetVar win=Nidaq_controls,limits={0,0.5,0.05},value= root:Packages:JB_NIDAQ:examine:bloodCountMinPeakSIze
	SetVariable bloodCountMaxPosSetVar win=Nidaq_controls,disable = able,pos={190,581},size={95,15},title="Max Pos"
	SetVariable bloodCountMaxPosSetVar win=Nidaq_controls,limits={-2,2,0.05},value= root:Packages:JB_NIDAQ:examine:bloodCountMaxPeakPos
	SetVariable BloodCountProfileWidthSetvar win=Nidaq_controls,disable = able,pos={26,600},size={94,15},title="Profile Width"
	SetVariable BloodCountProfileWidthSetvar win=Nidaq_controls,limits={1,inf,1},value= root:Packages:JB_NIDAQ:examine:bloodCountProfileWidth
	SetVariable BloodCountHighCutSetvar win=Nidaq_controls,disable = able,pos={118,600},size={87,15},proc=SIformattedSetVarProc2,title="Cut Hi"
	SetVariable BloodCountHighCutSetvar win=Nidaq_controls,format="%.2W1PHz"
	SetVariable BloodCountHighCutSetvar win=Nidaq_controls,limits={0,inf,0.5},value= root:Packages:JB_NIDAQ:examine:bloodCountHighCut
	SetVariable BloodCountLowCutSetvar win=Nidaq_controls,disable = able,pos={203,600},size={84,15},proc=SIformattedSetVarProc2,title="Lo"
	SetVariable BloodCountLowCutSetvar win=Nidaq_controls,format="%.2W1PHz"
	SetVariable BloodCountLowCutSetvar win=Nidaq_controls,limits={0,inf,10},value= root:Packages:JB_NIDAQ:examine:bloodCountLowCut
	// do it
	CheckBox bloodShowMeCheck win=Nidaq_controls,disable = able,pos={10,635},size={67,14},title="show steps"
	CheckBox bloodShowMeCheck win=Nidaq_controls,variable= root:Packages:JB_NIDAQ:examine:bloodShowMe
	Button bloodVelocityButton win=Nidaq_controls,disable = able,pos={153,632},size={129,20},proc=NQ_BloodMeasureButtonProc,title="Meausure Blood flow"
	// add Blood controls to database
	TCU4_AddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "Blood","Checkbox,BloodCurScanCheck,0;CheckBox,BloodAllScansCheck,0;setvariable,BloodMatchSetVar,0;")
	TCU4_AddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "Blood","CheckBox,BloodCheck1,0;CheckBox,BloodCheck2,0;Button,bloodShowLineScanButton,0;")
	TCU4_AddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "Blood","Setvariable,bloodWinLeftSetVar,0;Setvariable,bloodWinRightSetVar,0;Button,bloodFullScaleButton,0;")
	TCU4_AddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "Blood","Titlebox,BloodTimeTitle,0;CheckBox,BloodAllAtOnceCheck,0;CheckBox,BloodSampleCheck,0;")
	TCU4_AddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "Blood","Setvariable,BloodTimeSpacingSetvar,0;Setvariable,BloodTimeOverlapSetvar,0;")
	TCU4_AddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "Blood","CheckBox,BloodRadonCheck,0;Setvariable,BloodPrecisionSetvar,0;Button,BloodMaxRaysButton,0;")
	TCU4_AddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "Blood","TitleBox,BloodVelocityRangeTitle,0;CheckBox,BloodAngleRangeCheck1,0;")
	TCU4_AddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "Blood","CheckBox,BloodAngleRangeCheck2,0;Setvariable,BloodEstSpeedSetvar,0;")
	TCU4_AddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "Blood","Setvariable,BloodVelocityRangeSetvar,0;CheckBox,bloodCountCellscheck,0;")
	TCU4_AddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "Blood","Setvariable,bloodCountMinSizeSetVar,0;Setvariable,bloodCountMaxPosSetVar,0;")
	TCU4_AddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "Blood","Setvariable,BloodCountProfileWidthSetvar,0;Setvariable,BloodCountHighCutSetvar,0;")
	TCU4_AddCtrls ("Nidaq_Controls", "ExamineTabCtrl", "Blood","Setvariable,BloodCountLowCutSetvar,0;CheckBox,bloodShowMeCheck,0;Button,bloodVelocityButton,0")

End


//******************************************************************************************************
// Delete global variables for blood
// Last Modified Oct 04 2011 by Jamie Boyd
Function NQexBlood_remove ()
	killvariables/z root:packages:JB_NIDAQ:examine:BloodDoMatch
	killStrings/z root:packages:JB_NIDAQ:examine:BloodMatchStr
	killvariables/z root:packages:jb_nidaq:examine:BloodChan
	killvariables/z root:Packages:JB_NIDAQ:examine:bloodWinLeft
	killvariables/z root:Packages:JB_NIDAQ:examine:bloodWinRight
	killvariables/z root:Packages:JB_NIDAQ:examine:bloodDoSample
	killvariables/z root:Packages:JB_NIDAQ:examine:bloodSampleFreq
	killvariables/z root:Packages:JB_NIDAQ:examine:bloodSampleOverlap
	killvariables/z root:Packages:JB_NIDAQ:examine:bloodDoRadon 
	killvariables/z root:packages:jb_nidaq:examine:bloodRadonRays
	killvariables/z root:Packages:JB_NIDAQ:examine:bloodEstVelocity
	killvariables/z root:Packages:JB_NIDAQ:examine:bloodVelocitySpace
	killvariables/z root:Packages:JB_NIDAQ:examine:bloodVelocityPrecision
	killvariables/z root:packages:JB_Nidaq:examine:bloodDoCount
	killvariables/z root:packages:JB_Nidaq:examine:bloodCountHighCut
	killvariables/z root:packages:JB_Nidaq:examine:bloodCountLowCut
	killvariables/z root:packages:JB_Nidaq:examine:bloodCountProfileWidth
	killvariables/z root:packages:JB_Nidaq:examine:bloodCountMaxPeakPos
	killvariables/z root:packages:JB_Nidaq:examine:bloodCountMinPeakSIze
	killvariables/z root:Packages:JB_NIDAQ:examine:bloodShowMe
	killVariables/z root:packages:JB_Nidaq:examine:bloodRadonAngle
end

//******************************************************************************************************
// Shows position of line scan on the scan oon which it was drawn
// Last modified Oct 19 2011 by Jamie Boyd
Function NQ_BloodShowLSposButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR curScan = root:packages:jb_nidaq:examine:curScan
			NVAR bloodChan = root:packages:jb_nidaq:examine:bloodChan
			NQ_ShowLSpos (curScan, "ch" + num2str (bloodChan))
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//******************************************************************************************************
// sets the min and max for  the X-axis to the full width of the blood image. if shift key is held down, sets min and max to the 
// currrent ScanGraph settings for chosen channel
// Last Modified Oct 05 2011 by Jamie Boyd
Function NQ_BloodFullScaleProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR curScan = root:packages:jb_Nidaq:examine:curScan
			SVAR scanStr = $"root:Nidaq_Scans:" + curScan + ":" + curScan + "_info"
			NVAR bloodChan =  root:packages:jb_nidaq:examine:BloodChan
			variable mode = NumberByKey("mode", scanStr, ":", "\r")
			if (mode != kLineScan)
				doAlert 0, "only line scans can be used for this procedure."
				return 1
			endif 
			NVAR WinLeft = root:Packages:JB_NIDAQ:examine:bloodWinLeft
			NVAR WinRight = root:Packages:JB_NIDAQ:examine:bloodWinRight
			if (ba.eventMod & 2)
				if (bloodChan==1)
					GetAxis /W=Nidaq_ScanGraph#gCh1  bottom
				elseif (bloodCHan ==2)
					GetAxis /W=Nidaq_ScanGraph#gCh1  bottom
				endif
				winLeft = V_min
				winRight = V_max
			else
				WAVE scanWave = $"root:Nidaq_Scans:" + curScan + ":" + curScan + "_ch" + num2str (bloodChan)
				Winleft = dimOffset (scanWave, 0)
				WinRight = winLeft + dimSize (scanWave, 0) * dimdelta (scanWave, 0)
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
//What is smallest useful  angle interval to use in a radon projection?
//smallest resolvable movement is one x pixel over number of line it takes to go from xtart to  x end
// based on estimated speed
// Last Modified Oct 05 by Jamie Boyd
Function NQ_BloodEstMaxRaysButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR curScan = root:packages:jb_Nidaq:examine:curScan
			SVAR scanStr = $"root:Nidaq_Scans:" + curScan + ":" + curScan + "_info"
			variable mode = NumberByKey("mode", scanStr, ":", "\r")
			if (mode != kLineScan)
				doAlert 0, "only line scans can be used for this procedure."
				return 1
			endif 
			variable ySize, ySizeAll=NumberByKey("PixHeight", scanStr, ":", "\r"), yPixSize = NumberByKey("YpixSize", scanStr, ":", "\r")
			variable xLength=NumberByKey("PixWidth", scanStr, ":", "\r") * NumberByKey("XpixSize", scanStr, ":", "\r")
			NVAR doAll =root:Packages:JB_NIDAQ:examine:bloodDoAll
			NVAR estSpeed = root:packages:jb_nidaq:examine:bloodEstVelocity
			if (doAll)
				ySize = ySizeAll
			else
				NVAR sampleFreq = root:packages:jb_nidaq:Examine:BloodSampleFreq
				NVAR overLap = root:packages:jb_nidaq:Examine:BloodSampleOverLap
				variable yDelta = NumberByKey("YpixSize", scanStr, ":", "\r")
				ySize = ( 1/sampleFreq  * (1 + overlap/100))/yDelta
			endif
			// time to go from one side to the other based on estimated speed
			variable xTime =  xLength/estSpeed
			ySize = min (ySize,  xTime/yPixSize)
			variable thetaInc = aTan (1/ySize)
			NVAR precision = root:Packages:JB_NIDAQ:examine:bloodVelocityPrecision
			precision = round (pi/thetaInc)
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//******************************************************************************************************
//does the analysis for all selected scans 
// Last Modified Oct 05 2011 by Jamie Boyd
Function NQ_BloodMeasureButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
		// set folder to examine packages folder to avoid spewing out temp waves where we may not want them
		string savedFolder = getdatafolder (1)
		setdatafolder root:packages:jb_nidaq:examine
			string doBloodList
			NVAR bloodDoMatch = root:packages:JB_NIDAQ:examine:BloodDoMatch
			if (bloodDoMatch) // doing a range of scans
				SVAR bloodMatchStr = root:packages:jb_nidaq:examine:bloodMatchStr
				doBloodList  = ListObjects("root:nidaq_Scans", 4, bloodMatchStr, 2, "") 
			else
				SVAR curScan = root:packages:jb_Nidaq:examine:curScan
				SVAR scanStr = $"root:Nidaq_Scans:" + curScan + ":" + curScan + "_info"
				variable mode = NumberByKey("mode", scanStr, ":", "\r")
				if (mode != kLineScan)
					doAlert 0, "This button only works for LineScan data."
					setdatafolder $SavedFolder
					return 1
				endif
				doBloodList = curScan + ";"
			endif
			variable iScan, nScans = itemsinList (doBloodList)
			string aScan
			for (iScan =0; iScan < nScans; iScan +=1)
				aScan = stringFromList (iScan, doBloodList, ";")
				NQ_DoBlood (aScan)
			endfor
			setdatafolder $SavedFolder
			break
	endSwitch
end

//******************************************************************************************************
// Display graphs that shows intermediate steps of analysis - should fit in 1024 x 768 screen
// Last Modified Oct 20 2011 by Jamie Boyd	
function NQ_showBloodAnalysis(ScanWave, winLeft, WinRight, winBottom, winTop)
	WAVE scanWave
	variable winLeft, WinRight, winBottom, winTop
	
	variable gLeft=0, gTop=40, gRight=300, gBottom=40
	// image of unfiltered lineScans
	Wave bloodBits
	gBottom = gTop + 300
	doWindow/F BloodBitsGraph
	if (!(v_Flag))
		display/n = BloodBitsGraph/W=(gLeft, gTop, gRight, gBottom) as "LineScans"
		appendimage scanWave
		ModifyImage $nameofwave (scanWave) ctabAutoscale=1,lookup= $""
		ModifyGraph margin=1
		ModifyGraph tick=2,standoff=0, btLen=2, tlOffset=-22
		ModifyGraph axRGB=(65535,65535,65535),tlblRGB=(65535,65535,65535)
		ModifyGraph alblRGB=(65535,65535,65535)
	else
		RemoveImage /W=BloodBitsGraph  $stringfromlist (0, ImageNameList("BloodBitsGraph", ";" ), ";")
		appendimage scanWave
		ModifyImage $nameofwave (scanWave) ctabAutoscale=1,lookup= $""
		MoveWindow/W=BloodBitsGraph gLeft, gTop, gRight, gBottom
	endif
	SetAxis/W=BloodBitsGraph bottom, winLeft, WinRight
	SetAxis/W=BloodBitsGraph left , winBottom, WinTop
	NVAR doRadon=root:Packages:JB_NIDAQ:examine:bloodDoRadon 
	NVAR doCount = root:Packages:JB_NIDAQ:examine:bloodDoCount
	// remove blood count markers, if not doing blood count
	if ((doCount==0) && (whichlistItem ("jPeakPos", TraceNameList("BloodBitsGraph", ";", 1 ), ";") > -1))
		removeFromGraph/w=BloodBitsGraph  jPeakPos
	endif 
	if (doRadon)
		// Radon Plot Graph
		WAVE M_projectionSlice
		gTop = gBottom + 20
		// if y size is determined by x size, then:
		gBottom = gTop + (300 * (dimSize (M_projectionSlice, 1))/dimSize (M_projectionSlice,0))
		if (gBottom > gTop + 300) // then recalculate with y = 200 and X based on y
			gBottom =  gTop + 300
			gRight =  300 * (dimSize (M_projectionSlice, 0)/dimSize (M_projectionSlice, 1))
		endif
		doWindow/F RadonGraph
		if (!(v_Flag))
			display/N= RadonGraph/W=(gLeft, gTop, gRight, gBottom) as "Radon Projection"
			appendimage M_projectionSlice
			ModifyGraph margin=1
			ModifyGraph tick(left)=2,standoff(left)=0, btLen(left)=2, tlOffset(left)=-22
			ModifyGraph axRGB(left)=(65535,65535,65535),tlblRGB(left)=(65535,65535,65535)
			ModifyGraph alblRGB(left)=(65535,65535,65535)
		else
			MoveWindow/W=RadonGraph gLeft, gTop, gRight, gBottom
		endif
		// Radon Variance graph
		gRight = 300
		gTop = gBottom + 20
		gBottom = gTop + 200
		if (gBottom > 768)
			gTop = 40
			gBottom = gtop + 200
			gLeft = gRight + 5
			gright = gLeft + 300
		endif
		doWindow/F RadonVarianceGraph
		if (!(V_Flag))
			display/N=RadonVarianceGraph/W=(gLeft, gTop, gRight, gBottom)RadonVar as "Radon Variance"
			modifygraph rgb (RadonVar) = (0,0,0)
		else
			MoveWindow/W=RadonVarianceGraph gLeft, gTop, gRight, gBottom
		endif
	endif

	if (doCount)
		// Cells
		WAVE jPeakPos
		variable MidPt =  (winLeft + WinRight)/2
		make/o/n = (numpnts (jPeakPos)) jPeakPosForBB
		WAVE jPeakPosForBB
		jPeakPosForBB = MidPt
		if (whichlistItem ("jPeakPos", TraceNameList("BloodBitsGraph", ";", 1 ), ";") == -1)
			appendtograph/w=BloodBitsGraph  jPeakPos vs jPeakPosForBB
			modifygraph/w=BloodBitsGraph rgb (jPeakPos) = (65535,0,0), mode (jPeakPos)=3,marker (jPeakPos)=19,msize (jPeakPos)=2
			SetWindow BloodBitsGraph hook (bbHook) =NQ_BloodWindowHook
		endif
		gTop = gBottom + 20
		gBottom = gTop + 200
		if (gBottom > 768)
			gTop = 40
			gBottom = gtop + 300
			gLeft = gRight + 5
			gright = gLeft + 300
		endif
		doWindow/F BloodProfileGraph
		if (!(v_Flag))
			display/N= BloodProfileGraph/W=(gLeft, gTop, gRight, gBottom) W_imageLineProfile as "Blood Profile Plot"
			appendTograph/r/W= BloodProfileGraph W_imageLineProfile_f
			modifygraph/W= BloodProfileGraph margin (left) =30, margin (right) =5
			modifygraph/W= BloodProfileGraph rgb (W_imageLineProfile) =(0,0,0)
			modifygraph/W= BloodProfileGraph rgb (W_imageLineProfile_f) =(0,0,65535)
			appendToGraph/r/W= BloodProfileGraph jPeakHt vs jPeakPos
			ModifyGraph/W=BloodProfileGraph mode(jPeakHt)=3,marker(jPeakHt)=19
			SetAxis/W=BloodProfileGraph/A=2 left
			SetAxis/W= BloodProfileGraph /A=2 right
			SetWindow BloodProfileGraph hook (bbHook) =NQ_BloodWindowHook
		else
			MoveWindow/W=BloodProfileGraph gLeft, gTop, gRight, gBottom
		endif
	endif
	// Display  outPut waves for samples
	NVAR doSample = root:Packages:JB_NIDAQ:examine:bloodDoSample // 0 if doing all at once, 1 for sampling
	if (doSample)
		SVAR curScan = root:packages:jb_nidaq:examine:curScan
		gTop = gBottom + 20
		gBottom = gTop + 200
		if (gBottom > 768)
			gTop = 40
			gBottom = gtop + 200
			gLeft = gRight + 5
			gright = gLeft + 300
		endif
		doWindow/F $curScan + "Velocity"
		if (!(V_Flag))
			display/N=$curScan + "Velocity"/W=(gLeft, gTop, gRight, gBottom)  as  CurScan + " Velocity"
		else
			string traces = TraceNameList(curScan + "Velocity", ";", 1 )
		endif
		if (doRadon)
			WAVE radonOut = $"Root:nidaq_Scans:" +  curScan + ":" + curScan + "_velocityR"
			if ((!(V_Flag)) || (WhichListItem( curScan + "_velocityR", traces, ";") ==-1))
				appendtoGraph /w=$curScan + "Velocity" RadonOut
				ModifyGraph rgb($nameofwave (RadonOut))=(65535,0,0)
			endif
		endif

		if (doCount)
			WAVE/Z CellsOut = $"Root:nidaq_Scans:" +  curScan + ":" + curScan + "_Cells"
			if ((!(V_Flag)) || (WhichListItem( curScan + "_Cells", traces, ";") ==-1))
				appendtoGraph/R /w=$curScan + "Velocity" CellsOut
				ModifyGraph rgb($nameofwave (CellsOut))=(0, 65535, 0)
				label Right "Cells/sec (\U)"
			endif
		endif
		modifyGraph marker = 19, mode =4
		if (V_Flag)
			MoveWindow/W=$curScan + "Velocity" gLeft, gTop, gRight, gBottom
		endif
	endif
end

//******************************************************************************************************
//does the analysis for one scan for all selected methods 
// Last Modified Oct 11 2011 by Jamie Boyd
Function NQ_DoBlood (curScan)
	string curScan
	
	SVAR scanStr = $"root:Nidaq_Scans:" + curScan + ":" + curScan + "_info"
	variable mode = NumberByKey("mode", scanStr, ":", "\r")
	if (mode != kLineScan)
		return 1
	endif
	// check that selected channel exists
	NVAR bloodChan = root:packages:jb_nidaq:examine:bloodChan
	WAVE/Z scanWave = $"root:Nidaq_Scans:" + curScan + ":" + curScan + "_ch" + num2str (bloodChan)
	if (!(waveExists (scanWave)))
		printf "Selected channel, \"%s\",  does not exist for scan\"%s\".\r", "ch" + num2str (bloodChan), curScan
		return 1
	endif
	// reference global variables needed for all methods
	NVAR doRadon = root:Packages:JB_NIDAQ:examine:bloodDoRadon // use radon projection method
	NVAR doBloodCount = root:packages:JB_Nidaq:examine:bloodDoCount // count cells 
	NVAR WinLeft = root:Packages:JB_NIDAQ:examine:bloodWinLeft // X start
	NVAR WinRight = root:Packages:JB_NIDAQ:examine:bloodWinRight // X end
	NVAR doSample = root:Packages:JB_NIDAQ:examine:bloodDoSample // 0 if doing all at once, 1 for sampling
	NVAR showMe = root:Packages:JB_NIDAQ:examine:bloodShowMe
	NVAR RadonAngle = root:packages:JB_Nidaq:examine:bloodRadonAngle
	// duplicate possibly cropped line scan
	duplicate/o/R=((WinLeft), (winRight)) scanWave, bloodAllF // copy for filtering
	WAVE bloodAllF
	if (doBloodCount)
		// blood count is always all at once first, then "chunked" later if needed
		NQ_BloodCountDoProfile (bloodAllF)
	endif
	// high-pass filter
	variable yPixSize = dimDelta (scanWave, 1)
	FIlterIIR/CASC/DIM=1/HI=(kBloodAllHiCut*yPixSize) bloodAllF
	variable radonSpeed =NaN, cellsHz =NaN
	// check some globals for the different methods
	if (doRadon)
		NVAR rayDensity = root:packages:jb_nidaq:examine:bloodVelocityPrecision
		NVAR doRange = root:packages:jb_nidaq:examine:bloodRadonRays
	endif		

	if (doRange)
		NVAR CenterSpeed = root:packages:jb_nidaq:examine:bloodEstVelocity
		NVAR speedRange = root:Packages:jb_nidaq:examine:bloodVelocitySpace
	endif
	// do sample
	if (doSample)
		NVAR TimeSpacing= root:Packages:JB_NIDAQ:examine:bloodSampleFreq // in Hz (samples/sec)
		NVAR TimeOverlap = root:Packages:JB_NIDAQ:examine:bloodSampleOverlap // overlap with previous and next sample in percent
		// calculate number and spacing of samples
		variable scanTime = dimSize (scanWave, 1) * dimDelta (scanWave,1)
		variable Overlap = (TimeOverlap/100)/TimeSpacing
		variable winYsize = 1/TimeSpacing  +  2* Overlap
		variable nWins = round (scanTime * TimeSpacing)
		if (nWins < 1)
			print "It is not possible to do multiple samples with those parameters for overlap and sample frequency."
			return 1
		endif
		// make outPut waves
		if (doRadon)
			make/o/n = (nWins) $"Root:nidaq_Scans:" +  curScan + ":" + curScan + "_velocityR"
			WAVE radonOut = $"Root:nidaq_Scans:" +  curScan + ":" + curScan + "_velocityR"
			SetScale/P x (0),(1/TimeSpacing),"s", radonOut
			setscale/P d, 0,0, "m/sec", radonOut
			radonOut = Nan
		endif
		if (doBloodCount)
			make/o/n = (nWins) $"Root:nidaq_Scans:" +  curScan + ":" + curScan + "_Cells"
			WAVE CellsOut = $"Root:nidaq_Scans:" +  curScan + ":" + curScan + "_Cells"
			SetScale/P x (0),(1/TimeSpacing),"s", CellsOut
			setscale/P d, 0,0, "Hz", CellsOut
			CellsOut = Nan
			string noteStr
			sprintf noteStr, "SampleFreq:%.6f;WinYSize:%.6f;", TimeSpacing, winYsize
			Note cellsOut noteStr
		endif
		// iterate through samples
		variable iWin, winYStart, winYEnd
		for (iWin = 0, WinYStart =0; iWin < nWins; iWin +=1)
			winYStart = max ((iWin / TimeSpacing)-winYsize/2, 0)
			winYEnd =min ((iWin /TimeSpacing) +winYsize/2 , scanTime)
			if (doRadon)
				duplicate/o/R=((WinLeft), (winRight)) ((winYStart), (winYEnd)) bloodAllF bloodBits
			endif
			if (doRadon)
				radonOut [iWin] =  NQ_BloodRadon(bloodBits, rayDensity, doRange, CenterSpeed, speedRange)
			endif
			if (doBloodCount)
				CellsOut [iWIn] = NQ_BloodCountCells (winYStart, winYEnd)
			endif
			if (showMe)
				if (iWin ==0) // show on first sample
					NQ_showBloodAnalysis(ScanWave, winLeft, WinRight, winYStart, winYEnd)
				endif
				// stuff to show on every sample
				SetAxis /W=BloodBitsGraph left , winYStart, winYEnd
				if (doRadon)
					WAVE M_ProjectionSlice
					WAVE RadonVar
					if (showMe)
						Cursor/A=1/C=(65535,0,0)/H=3/I/L=1/S=2 /W=RadonGraph A  M_ProjectionSlice  0,(RadonAngle)
						Cursor/A=1/C=(65535,0,0)/H=0 /W=RadonVarianceGraph A  RadonVar (RadonAngle)
					endif
				endif
				doupdate
			endif
		endfor
	else // doing all at once
		if (doRadon)
			radonSpeed = NQ_BloodRadon(bloodALLF, rayDensity, doRange, CenterSpeed, speedRange)
			printf "Radon Out Velocity for scan %s was %.2W1Pm /sec\r", curScan, radonSpeed 
		endif
		if (doBloodCount)
			cellsHz = NQ_BloodCountCells (0, (dimSize (scanWave, 1) * dimDelta (scanWave,1)))
			printf "Blood cell flux for scan %s was %.2W1PHz\r", curScan, cellsHz 
		endif
		NQ_BloodCumResults (curScan, radonSpeed, cellsHz)
		if (showMe)
			NQ_showBloodAnalysis(scanWave, WinLeft, winRight, 0,  (dimSize (scanWave, 1) * dimDelta (scanWave,1)))
			if (doRadon)
				WAVE M_ProjectionSlice
				WAVE RadonVar
				Cursor/A=1/C=(65535,0,0)/H=3/I/L=1/S=2 /W=RadonGraph A  M_ProjectionSlice  0,(RadonAngle)
				Cursor/A=1/C=(65535,0,0)/H=0 /W=RadonVarianceGraph A  RadonVar (RadonAngle)
			endif
			doUpdate
		endif
	endif
end

//******************************************************************************************************
//does Radon transform and returns speed in m/s
// Last Modified Oct 07 2011 by Jamie Boyd
Function NQ_BloodRadon(theWave, rayDensity, doRange, CenterSpeed, speedRange)
	wave theWave
	variable rayDensity // number of rays per ¹ radians
	variable doRange	// 1 if doing a limited range of angles, 0 if doing from -¹/2 to ¹/2
	variable CenterSpeed // if doing limited range, estimated best speed
	variable speedRange  // if doing limited range, look from centerSpeed +/- speedRange
	
	variable xSize = dimsize (theWave, 0)
	variable xDelta = dimdelta (theWave, 0)
	variable yDelta = dimdelta (theWave, 1)
	variable startAngle, endAngle, incAngle, nRays
	if (doRange)
		// translate speeds to starting and ending angle
		// speed =  tan (angle)*(xDelta/yDelta) so angle = atan (speed /(xDelta/yDelta))
		startAngle = max (atan (( CenterSpeed - speedRange)/(xDelta/yDelta)), -pi/2)
		endAngle = min (atan ((CenterSpeed +  speedRange)/(xDelta/yDelta)), pi/2)
		nRays = round (rayDensity * ((EndAngle - StartAngle)/pi))
	else // full Range
		startAngle = -pi/2
		endAngle = pi/2
		nRays = rayDensity 
	endif
	incAngle= (EndAngle - StartAngle)/nRays
	ImageTransform /PSL={(-xSize/2),(1),(xSize),(startAngle),(incAngle),(nRays)} projectionSlice theWave
	WAVE M_ProjectionSlice
	Matrixop/o RadonVar=varcols(M_ProjectionSlice)^t
	WAVE RadonVar
	SetScale /I X startAngle, (EndAngle - incAngle), "radians", RadonVar
	// Find biggest peak
	NVAR radonAngle = root:packages:JB_Nidaq:examine:bloodRadonAngle
	FindPeak/Q/B=3/R=((startAngle), (endAngle)), RadonVar
	if (V_Flag)
		radonAngle = NaN
		return NaN
	endif
	variable bestPeakLoc=V_PeakLoc, bestPeakSize=V_PeakVal, peakStart
	for (peakStart = bestPeakLoc + 2 * incAngle; V_Flag==0; peakStart =V_PeakLoc + 2 * incAngle)
		FindPeak/Q/B=3/R=((peakStart), (endAngle)), RadonVar
		if (v_flag ==0)
			if ((V_PeakVal > bestPeakSize) && ((V_PeakLoc > startAngle + incAngle) && (V_PeakLoc < endAngle -incAngle)))
				bestPeakSize = V_PeakVal
				bestPeakLoc = V_PeakLoc
			endif
		endif
	endfor
	radonAngle = bestPeakLoc
	return tan (bestPeakLoc)*(xDelta/YDelta)
end
	

//******************************************************************************************************
//Hook function to assist editing and revewing blood count results
// Command-click to add a point
// Shift-click to delete a point
// shift-x to delete point cursor A is currently on
// Last Modified Oct 19 2011 by Jamie Boyd
Function NQ_BloodWindowHook(s)
	STRUCT WMWinHookStruct &s

	Variable hookResult = 0
	switch(s.eventCode)
		case 5: //"mouseup"
			// shift click on a point to remove it. Command/ctrl click  to add a point
			if ((s.eventMod & 2)== 2)
				string hit = TraceFromPixel( s.mouseLoc.h, s.mouseLoc.v, "" )
				if (cmpStr (hit,"") != 0)
					string trace = stringbykey ("TRACE", hit, ":", ";")
					if ((cmpStr (trace, "jPeakPos") ==0) || (cmpStr (trace, "jPeakHt") ==0))
						variable pt = numberbykey ("HITPOINT", hit, ":", ";")
						wave jPeakHt= root:packages:jb_nidaq:examine:jPeakHt
						wave jPeakPos=root:packages:jb_nidaq:examine:jPeakPos
						wave jPeakPosForBB=root:packages:jb_nidaq:examine:jPeakPosForBB
						variable xPos = jPeakPos[pt]
						deletepoints pt, 1, jPeakHt, jPeakPos, jPeakPosForBB
						NQ_BloodCellsModded (xPos, 0)
						hookresult= 1
					endif
				endif
			elseif ((s.eventMod &8) ==8) //command/ctrl click  to add a point
				wave jPeakHt= root:packages:jb_nidaq:examine:jPeakHt
				wave jPeakPos=root:packages:jb_nidaq:examine:jPeakPos
				wave jPeakPosForBB=root:packages:jb_nidaq:examine:jPeakPosForBB
				wave profile= root:packages:jb_nidaq:examine:w_imageLineProfile_f
				variable xLoc, yLoc
				if (cmpStr (s.winName, "BloodProfileGraph") ==0)
					xLoc=AxisValFromPixel(s.winName, "bottom", s.mouseLoc.h )
				elseif (cmpStr (s.winName, "bloodBitsGraph") ==0)
					xLoc= AxisValFromPixel(s.winName, "left", s.mouseLoc.v)
				endif
				pt = floor (BinarySearch(jPeakPos, xLoc))
				if (pt ==-3) // no points in wave yet, need to calculate center of bloodbits wave
					insertpoints 0, 1, jPeakHt, jPeakPos, jPeakPosForBB
					jPeakPos [0] = xLoc
					getaxis/q/w =BloodBitsGraph bottom
					jPeakPosForBB [0] =(V_max - V_min)/2
					jPeakHt [0]= profile (xLoc)
				else
					if (pt == -2) // search places pt after last point in wave. 
						pt = numpnts (jPeakPos)
					endif
					// if search places pt before first point in wave, pt = -1, and will be inserted correctly
					insertpoints (pt +1), 1, jPeakHt, jPeakPos, jPeakPosForBB
					jPeakPos [pt + 1] = xLoc
					if (pt ==-1) // use point one, as point 0 has just been inserted and has value zero
						jPeakPosForBB [pt + 1] =jPeakPosForBB [1]
					else // we can just copy from previous values, whih should all be the same
						jPeakPosForBB [pt + 1] =jPeakPosForBB [0]
					endif
					jPeakHt [pt +1]= profile (xLoc)
				endif
				NQ_BloodCellsModded (jPeakPos[pt + 1], 1)
				hookResult=1
			endif
			break
		case 7:   //"cursormoved"
			string thisAxis, otherAxis, thisGraph=s.winName, otherGraph, otherTrace
			variable pos, val, axisRange, axisStart
			NVAR drmb = root:packages:jb_nidaq:examine:bloodDrmb
			drmb =1
			if (cmpStr (thisGraph, "bloodBitsGraph") ==0)
				val = vcsr (A, thisGraph)
				thisAxis = "left"
				otherAxis = "bottom"
				otherGraph = "BloodProfileGraph"
				otherTrace="jPeakHt"
			else
				val = hcsr (A, thisGraph)
				thisAxis = "bottom"
				otherAxis = "left"
				otherGraph="bloodBitsGraph"
				otherTrace="jPeakPos"
			endif
			// move correspondin cursor on other graph
			pos= pcsr(A,  thisGraph)
			Cursor/W=$otherGraph/P A $otherTrace  pos
			// if outside axis range, adjust axis range on both graphs
			getaxis/q/w =$thisGraph $thisAxis
			if ((val < V_min) || (val > V_max))
				axisRange = V_max - V_min
				if (val < V_Min)
					axisStart = V_min - axisRange/2
				else
					axisStart = V_min + axisRange/2
				endif
				setaxis/w=$thisGraph $thisAxis (axisStart), (axisStart + axisRange)
			endif
			hookResult = 1
			break
		case 8:	//"modified"
			NVAR drmb = root:packages:jb_nidaq:examine:bloodDrmb // don't recurse me, bro
			if (drmb==1)
				drmb=0
			else
				if (cmpStr (s.winName, "bloodBitsGraph") ==0)
					getaxis/q/w =bloodBitsGraph left
					setaxis/w=BloodProfileGraph bottom (V_min), (V_Max)
					doUpdate/w=BloodProfileGraph
				elseif  (cmpStr (s.winName, "BloodProfileGraph") ==0)
					getaxis/q/w =BloodProfileGraph bottom
					setaxis/w= bloodBitsGraph left (V_min), (V_Max)
					doupdate/w=bloodBitsGraph
				endif
				drmb=1
			endif
			break
		case 11: //"keyboard"
			if ((s.keycode == 88) && ((s.eventMod & 2)== 2)) // Shift-X to delete point Cursor is currently on
				if (cmpStr (s.winName, "bloodBitsGraph") ==0)
					pos= pcsr(A,  "bloodBitsGraph")
					NQ_BloodCellsModded (vcsr(A,  "bloodBitsGraph"), 0)
				else
					pos= pcsr(A,  "BloodProfileGraph")
					NQ_BloodCellsModded (hcsr(A,  "BloodProfileGraph"), 0)
				endif
				wave jPeakHt= root:packages:jb_nidaq:examine:jPeakHt
				wave jPeakPos=root:packages:jb_nidaq:examine:jPeakPos
				wave jPeakPosForBB=root:packages:jb_nidaq:examine:jPeakPosForBB
				deletepoints pos, 1, jPeakHt, jPeakPos, jPeakPosForBB
				hookResult = 1
			endif
			break
	endswitch
	return hookResult
end

//******************************************************************************************************
// Updates results after the hook hunction modifies blood cell profile results
// Last Modified Oct 18 2011 by Jamie Boyd
function NQ_BloodCellsModded (modX, wasAdded)
	variable modX // x value of point that was modified
	variable wasAdded // 0 if point subtracted, non-zero if a point was added
	
	SVAR curScan = root:packages:jb_nidaq:examine:Curscan
	//redo cumulative results
	SVAR infoStr = $"root:nidaq_Scans:" + curScan + ":" + curScan + "_info"
	variable nLines = NumberByKey("PixHeight", infoStr, ":", "\r")
	variable lineTime = NumberByKey("LineTime", infoStr, ":", "\r")
	variable scanTime = (nLines * lineTime)
	wave jPeakPos=root:packages:jb_nidaq:examine:jPeakPos 
	NQ_BloodCumResults (curScan, Nan, numPnts (jPeakPos)/scanTime)
	// do we have  cells wave to modify?
	WAVE/Z cellWave = $"root:nidaq_Scans:" + curScan + ":" + curScan + "_Cells"
	if (WaveExists (CellWave))
		string noteStr = note (CellWave)
		variable SampleFreq = numberbykey ("SampleFreq", noteStr, ":", ";")
		variable WinYSize =  numberbykey ("WinYSize", noteStr, ":", ";")
		variable iStart = floor ((modX - WinYSize) *SampleFreq)
		variable iEnd = ceil ((modX + WinYSize)*SampleFreq)
		variable iWin, winYStart, winYEnd
		for (iWin = iStart; iWin <=iEnd ; iWin +=1)
			 winYStart = max ((iWin / SampleFreq)-winYsize/2, 0)
			 winYEnd =min ((iWin /SampleFreq) +winYsize/2 , scanTime)
			 if ((modX > winYStart) && (modX < winYEnd))
			 	if (wasAdded)
			 		CellWave [iWin] += 1/WinYSize
			 	else
			 		CellWave [iWin] -= 1/WinYSize	
				 endif
			endif
		endfor
	endif
end

//******************************************************************************************************
//Counts already-identified peaks (in wave jPeakPos) and returns Cell Flux in Hz  - number between start and end time /( endTime - startTime)
// Last Modified Oct 14 2011 by Jamie Boyd
function NQ_BloodCountCells (timeStart, timeEnd)
	variable timeStart, timeEnd
	
	wave jPeakPos=root:packages:jb_nidaq:examine:jPeakPos
	variable endP, startP = BinarySearch(jPeakPos, timeStart)
	if ((startP == -3) || (startP == -2))  //BinarySearch returns -3 if the wave has zero points, -2 if val would fall after the last value 
		return 0
	elseif (startP == -1) //BinarySearch returns -1 if val would fall before the first value in the wave.
		startP =0
	endif
	endP =  BinarySearch(jPeakPos, timeEnd)
	if (endp == -2)
		endP = numpnts (jPeakPos)-1
	elseif (endp == -1)
		return 0
	endif
	return (endP - StartP + 1)/(timeEnd - timeStart)
end

Static Constant kCellPeakBox = 3 // box for smoothing
Static Constant kCellPeakMinWid = 5e-03 //minimum time between adjacent peaks, in seconds
//******************************************************************************************************
//Does profile plot on bloodBits wave, filters it, identifies paeaks, and places dentified peaks in wave jPeakPos
// Last Modified Oct 18 2011 by Jamie Boyd
function NQ_BloodCountDoProfile (bloodBits)
	wave bloodBits
	
	string savedfldr = GetDataFolder(1)
	setdatafolder root:packages:jb_nidaq:examine
	NVAR minPeakSize = bloodCountMinPeakSize
	NVAR maxPeakPos = bloodCountMaxPeakPos
	NVAR profileWidth =bloodCountProfileWidth
	NVAR HiCut =bloodCountHighCut
	NVAR LowCut = bloodCountLowCut
	variable xSize =dimsize (bloodBits, 0)
	variable xDelta = dimdelta (bloodBits,0) 
	variable xOffset = dimoffset (bloodBits, 0)
	variable ySize =dimsize (bloodBits, 1)
	variable yDelta = dimdelta (bloodBits,1) 
	variable yOffset = dimoffset (bloodBits, 1)
	// make profile plot down center of bloodBits wave
	make/o/n =2 cX, cY
	WAVE cX
	WAVE cY
	cx=  xOffset  + (xSize/2) * xDelta
	cY [0] = yOffset + yDelta
	cY [1] = yOffset + (ySize-1) * yDelta
	ImageLineProfile  srcWave=bloodBits, xWave=cx, yWave=cY, width=(profileWidth)
	WAVE w_imagelineprofile
	SetScale /I x, cy [0], cY [1], "s", w_imagelineprofile
	// filter the profile plot
	duplicate/O w_imageLineProfile w_imageLineProfile_f
	WAVE w_imagelineProfile_f
	FilterIIR /CASC /HI=(HiCut * yDelta)/LO=(lowCut * yDelta) w_imageLineProfile_f
	// Normalize filtered plot to -1 to 1 (2 standard deviations)
	wavestats/q w_imagelineProfile_f
	variable startLevel = V_avg - v_SDEV *2
	variable endLevel = V_avg + V_SDEV *2
	variable rangeRatio = (endLevel - startlevel)/2
	w_imagelineProfile_f  = (w_imagelineProfile_f - V_avg)/rangeRatio
	// find ALL peaks in profile that are below maxPeakPos
	make/o/n=0 jPeakPos, jPeakHt
	WAVE jPeakPos, jPeakHt
	variable startP=0, endP = numpnts (w_imagelineProfile_f) -1
	variable peakLoc,nPeaks = 0
	for (;;)
		// find next peak
		FindPeak /B=(kCellPeakBox) /M=(maxPeakPos) /N/P/Q/R=[startP, endP] w_imagelineProfile_f
		if (v_flag) // no peak found; exit loop
			break
		endif
		// set starting position for next peak
		startP = V_PeakLoc + kCellPeakBox/2
		// insert peak into jPeakPos and jPeakht waves
		insertpoints (nPeaks), 1,  jPeakPos, jPeakHt
		jPeakPos [nPeaks] =pnt2x(w_imagelineProfile_f, V_PeakLoc )
		jPeakHt [nPeaks] = V_PeakVal
		nPeaks +=1
	endfor
	// Limit peaks by looking at disatance between adjacent peaks
	variable iPeak
	for (iPeak = 1; iPeak < nPeaks; iPeak +=1)
		// check distance to previous peak
		 if (jPeakPos [iPeak] - jPeakPos [iPeak-1] < kCellPeakMinWid)
		 	// minimum separation was not met. Keep more negative peak, delete other peak
			if (jPeakHt [iPeak] <  jPeakHt [iPeak-1]) 
				deletepoints (iPeak -1), 1, jPeakPos, jPeakHt
			else
				deletepoints (iPeak), 1, jPeakPos, jPeakHt
			endif
			iPeak -=1
			nPeaks -=1
		endif
	endfor
	// Limit peaks by minimum size
	for (iPeak = 0; iPeak < nPeaks; iPeak +=1)
		if (NQ_CheckPkHt (w_imagelineProfile_f, jPeakPos, jPeakHt, maxPeakPos, minPeakSize, iPeak) ==0)
			// size of this peak relative to adjacent positive peaks is too small. delete it
			deletepoints (iPeak), 1, jPeakPos, jPeakHt
			iPeak -=1
			nPeaks -=1
		endif
	endfor			
end

//******************************************************************************************************
// returns 1 if peak, relative to both left and right adjacent  positive peaks, is greater than minPeakHt
// Last Modified Oct 18 2011 by Jamie boyd
function  NQ_CheckPkHt (w_imagelineProfile_f, jPeakPos, jPeakHt, maxPeakPos, minPeakHt, peakNum)
	wave w_imagelineProfile_f, jPeakPos, jPeakHt
	variable minPeakHt, maxPeakPos, peakNum
		
	variable maxLeft, maxRight, maxVal, startPos, endPos
	// find largest  positive peak between last peak and this peak
	for (maxLeft = -INF,startPos = (peakNum == 0 ? leftx (w_imagelineProfile_f) : jPeakPos [peakNum-1]);;)
		FindPeak /B=(kCellPeakBox)/M=(maxPeakPos)/P/Q/R=(startPos, jPeakPos [peakNum]) w_imagelineProfile_f
		if (v_flag) // no peak found; exit loop
			break
		elseif (V_peakVal > maxLeft)
			maxLeft = V_peakVal
		endif
		startPos = V_PeakLoc + kCellPeakBox/2
		if (startPos > jPeakPos [peakNum])
			break
		endif
	endfor
	// if no positive peaks found, use maximum of wave between the points
	if (numtype (maxLeft) == 1)
		wavestats/m=1/Q/R=((peakNum == 0 ? leftx (w_imagelineProfile_f) : jPeakPos [peakNum-1]), jPeakPos [peakNum]) w_imagelineProfile_f
		maxLeft = V_max
	endif
	if ((maxLeft -  jPeakHt [peakNum]) < minPeakHt)
		return 0
	endif
	// find largest positive peak between this peak and next peak
	for (maxRight = -INF,startPos = ((peakNum < numpnts (jPeakPos) -1) ? jPeakPos [peakNum +1] : rightx (w_imagelineProfile_f));;)
		FindPeak /B=(kCellPeakBox)/M=(maxPeakPos)/P/Q/R=(startPos, jPeakPos [peakNum]) w_imagelineProfile_f
		if (v_flag) // no peak found; exit loop
			break
		elseif (V_peakVal > maxRight)
			maxRight = V_peakVal
		endif
		startPos = V_PeakLoc - kCellPeakBox/2
		if (startPos < jPeakPos [peakNum])
			break
		endif
	endfor
	// if no positive peaks found, use maximum of wave between the points
	if (numtype (maxRight) == 1)
		wavestats/m=1/Q/R=(jPeakPos [peakNum], (peakNum < numpnts (jPeakPos) -1) ? jPeakPos [peakNum +1] : rightx (w_imagelineProfile_f)) w_imagelineProfile_f
		maxRight = V_max
	endif
	if ((maxRight - jPeakHt [peakNum]) < minPeakht)
		return 0
	else
		return 1
	endif
end


//******************************************************************************************************
// adds speed and cell flux values to cumulative results.See SharedWavesManager for definition of SharedWavesStruct
// Last Modified Jan 17 2012 by Jamie Boyd
Function NQ_BloodCumResults (curScan, SpeedRad, cellHz)
	string curScan
	variable speedRad, cellHz
	
	STRUCT  SharedWavesStruct s
	s.swmInstance = "Blood"
	// 0th pos is run name
	s.resultWaveNames [0] = "Run"
	s.resultWaveTypes [0] = 0
	s.resultStrings[0] = curScan
	s.resultWaveUnits [0] = ""
	// 1st pos is Run DateTime - which is used as unique identifier for a scan
	s.isUnique = 2
	SVAR scanStr = $"root:Nidaq_Scans:" + curScan + ":" + curScan + "_info" 
	s.resultWaveNames [1] = "RunDateTime"
	s.resultWaveTypes [1] = 4
	s.resultVariables[1] = NumberByKey("ExpTime", scanStr , ":", "\r")
	s.resultWaveUnits [1] = "dat"
	// 2nd Pos is date
	s.resultWaveNames [2] = "ExpDate"
	s.resultStrings [2] =secs2date (s.resultVariables[1], 2) // 2 is date format
	s.resultWaveTypes [2] = 0
	s.resultWaveUnits [2] =""
	// add whatever data is given from speed and cell flux
	variable iResult =3
	if (numtype (SpeedRad) ==0)
		s.resultVariables [iResult] = speedRad
		s.resultWaveNames [iresult]= "SpeedRad"
		s.resultWaveTypes [iResult] = 2
		s.resultWaveUnits [iresult] = "m/s"
		iResult += 1
	endif

	if (numtype (cellHz) ==0)
		s.resultVariables [iResult] = cellHz
		s.resultWaveNames [iresult]= "CellHz"
		s.resultWaveTypes [iResult] = 2
		s.resultWaveUnits [iresult] = "Hz"
		iResult += 1
	endif
	s.nResults =iresult
	// Parse key=value pairs in experiment note and add them to struct
	NQ_ParseNoteKeys(stringByKey ("ExpNote", scanStr, ":", "\r"), s)
	// add results
	// look for "vessel" field in new result
	for (iResult -=1;iResult < s.nResults; iResult +=1)
		if (Cmpstr (s.resultWaveNames [iResult], "vessel") ==0)
			s.isUnique += 2^(iResult)
			break
		endif
	endfor
	SharedWaves_AddResults (s)
end

//******************************************************************************************************
//Processes a range of scans named numericaly from first run to last run
// Last Modified Oct 19 2011 by Jamie Boyd
Function NQ_BloodMulti (baseName, firstRun, lastRun)
	string baseName
	variable firstRun, lastRun
	
	NVAR showMe= root:Packages:JB_NIDAQ:examine:bloodShowMe
	NVAR doSample = root:Packages:JB_NIDAQ:examine:bloodDoSample
	NVAR bloodChan = root:packages:jb_nidaq:examine:BloodChan
	doSample =0
	showMe = 0
	string theScan
	variable theRun
	for (theRun = firstRun; theRun <= lastRun; theRun += 1)
		if (theRun < 10)
			theScan = baseName + "_00" + num2str (theRun)
		elseif (theRun < 100)
			theScan = baseName + "_0" + num2str (theRun)
		else
			theScan = baseName + "_" + num2str (theRun)
		endif
		if (waveExists ($"root:Nidaq_Scans:" + theScan + ":" + theScan + "_ch" + num2str (bloodChan)))
			NQ_DoBlood(theScan)
		endif
	endfor
end

//******************************************************************************************************
// sets a global variable for  cortical surface from the current Z position of the  Zstack that is the current scan
// Last modified Oct 19 2011 by Jamie Boyd
Function NQ_SetTop ()
	
	SVAR curScan = root:packages:jb_nidaq:examine:curScan
	SVAR  infoStr =  $"root:Nidaq_Scans:" + curScan + ":" + curScan + "_info"
	if (NumberByKey("Mode", infoStr, ":", "\r") != kZSeries)
		return 1
	endif
	NVAR curVal = root:packages:jb_nidaq:examine:curFramePos
	variable curPos = numberbyKey ("zPos", sInfo (), ":", "\r") + curval* numberbyKey ("zStepSize", sInfo (), ":", "\r")
	variable/G root:packages:jb_nidaq:examine:topVal = curPos
end

//******************************************************************************************************
// Calculates depth of a scan from the previously set global variable for cortical surface, and modifies wave note to show it
// Last modified Mar 13 2012 by Jamie Boyd
function NQ_GetDepth ()
	
	SVAR curScan = root:packages:jb_nidaq:examine:curScan
	SVAR  infoStr =  $"root:Nidaq_Scans:" + curScan + ":" + curScan + "_info"
	if (NumberByKey("Mode", infoStr, ":", "\r") == kZSeries)
		return 1
	endif
	NVAR/Z topVal = root:packages:jb_nidaq:examine:topVal
	if (!(NVAR_EXISTS (topVal)))
		return 1
	endif
	variable zPos =  numberbyKey ("zPos", infoStr, ":", "\r")
	variable depth = (zPos -topVal) * 1e06
	string expNote = StringByKey("ExpNote", infoStr, ":", "\r")
	expNote = ReplaceNumberByKey("depth", expNote, depth, "=", ";")
	expNote=RemoveByKey("Rotation", expNote, "=", ";")
	infoStr = ReplaceStringByKey("ExpNote", infoStr, expNote, ":", "\r")
	NQ_showNote ("root:NIDAQ_Scans:" + CurScan + ":" + curScan +"_info")
end

//******************************************************************************************************
// For the linescan that is the current scan, sets current scan to the Scan on which the line scan was drawn, and shows the position of the line scan
// Last modified Oct 19 2011 by Jamie Boyd
Function NQ_ShowLSPos (theLineScan, chanStr)
	string theLineScan
	string chanStr // ch1 or ch2
	
	// make sure it is a linescan we have been passed
	SVAR infoStr = $"root:Nidaq_Scans:" + theLineScan + ":" + theLineScan + "_info"
	if (NumberByKey("Mode", infoStr, ":", "\r") != kLineScan)
		return 1
	endif
	// get the name of the scan on which the linescan was drawn
	string linkWaveStr = StringByKey ("linkWave", infoStr, ":", "\r")
	if (cmpStr (linkWaveStr, "") ==0)
		return 1
	endif
	// calculate position to draw
	variable xPos = NumberByKey("Xpos", infoStr, ":", "\r")
	variable yPos = NumberByKey("Ypos", infoStr, ":", "\r")
	variable pixWidth = NumberByKey("PixWidth", infoStr, ":", "\r")
	variable xPixSize = NumberByKey("XpixSize", infoStr, ":", "\r")
	variable pixHeight = NumberByKey("PixHeight", infoStr, ":", "\r")
	variable yPixSize = NumberByKey("YpixSize", infoStr, ":", "\r")
	variable drawXstart = xPos
	variable drawXend = xPos + pixWidth * xPixSize
	variable drawY = yPos
	// make the linked wave the current scan and open the graph window with subgraph for selected channel shown
	string chanList = stringbykey ("imChanDesc", infoStr, ":", "\r")
	if (WhichListItem(chanStr, chanList , ",") == -1)
		chanStr = stringfromlist (0, chanList, ",")
	endif
	STRUCT WMPopupAction pa	
	pa.eventCode =2
	pa.popStr = linkWaveStr
	NQ_ScansPopMenuProc(pa)
	NVAR showCh = $"root:Packages:JB_Nidaq:examine:show" + chanStr
	showCh =1
	STRUCT WMCheckboxAction cba
	 cba.eventCode = 2
	NQ_ScanGraphDisplayCheckProc(cba)
	// draw line scan position on the subgraph for selected channel
	SetDrawLayer/W=$"Nidaq_ScanGraph#G" + chanStr ProgFront
	SetDrawEnv/W=$"Nidaq_ScanGraph#G" + chanStr xcoord= bottom,ycoord= left,fillpat= 0,linefgc= (0,0,0),linethick= 3.00
	DrawLine/W=$"Nidaq_ScanGraph#G" + chanStr xPos,yPos, xPos + pixWidth * xPixSize, yPos 
	SetDrawEnv/W=$"Nidaq_ScanGraph#G" + chanStr xcoord= bottom,ycoord= left,fillpat= 0,linefgc= (65535,65535,65535),linethick= 1, dash = 2
	DrawLine/W=$"Nidaq_ScanGraph#G" + chanStr drawXstart,drawY, drawXend, drawY 
	SetDrawLayer/W=$"Nidaq_ScanGraph#G" + chanStr UserFront
end

Function PseudoLineScan ()
	
	string chanStr = "ch1"
	SVAR curScan = root:packages:JB_Nidaq:Examine:curScan
	SVAR infoStr = $"root:Nidaq_Scans:" + curScan + ":" + curScan + "_info"
	if (NumberByKey("Mode", infoStr, ":", "\r") != 1)
		return 1
	endif
	WAVE theScan = $"root:nidaq_scans:" + curScan + ":" + curScan + "_" + chanStr
	variable numFrames = NumberByKey("NumFrames", infoStr, ":", "\r")
	variable frameTime = NumberByKey("FrameTime", infoStr, ":", "\r")
	ImageLineProfile /P=0  xWave=W_Xpoly0, yWave=W_ypoly0, srcwave=theScan, width=1
	WAVE W_ImageLineProfile
	WAVE W_lineProfileX
	variable xOffset = W_lineProfileX [0]
	variable xDelta = W_lineProfileX [1] -W_lineProfileX [0]
	variable xSize = numpnts (W_lineProfileX)
	make/o/n = ((xSize), (numFrames)) root:FakeLineScan
	WAVE fls = root:FakeLineScan
	setscale/P X xOffset, xDelta, "m", fls
	setscale/P Y 0, frameTime, "s", fls
	variable iFrame
	for (iFrame = 0; iFrame < numFrames; iFrame += 1)
		ImageLineProfile /P=(iFrame)  xWave=W_Xpoly0, yWave=W_ypoly0, srcwave=theScan, width=4
		fls [] [iFrame] = W_ImageLineProfile [p]
	endfor

end


function Ves2Pos ()

end

function Pos2Exp ()

end



// averages speed and cell flux results for all runs of an indvidual vessel.
function Runs2Ves (lsfolder, idfolder)
	string lsfolder, idFolder
	
	// outPut waves
	make/o/n=0 Ves_runDateTime
	WAVE Ves_expDate
	Wave ves_ves
	Wave ves_Depth
	wave ves_Blockage
	wave ves_velAvg
	wave ves_velStd
	wave ves_CelAvg
	wave ves_celStd
	
	// input waves
	lsfolder = removeending (lsFolder, ":") + ":"
	wave runDateTime = $lsfolder + "runDateTime" 
	wave/t expdate = $lsFolder + "expdate"
	wave/t run = $lsFolder + "run"
	wave position = $lsFolder + "position"
	wave vessel=$lsFolder + "vessel"
	wave speedRad = $lsfolder + "speedrad"
	wave cellHz = $lsFolder + "cellhz"
	wave blockage = $lsFolder + "blockage"
	wave depth= $lsFolder +"depth"
	wave diameter=$lsFolder + "diameter"
	wave heartbeat = $lsFolder + "heartbeat"
	
end
	
	
	
	
	
	
	
	wave BloodOut_SpeedRad
	wave BloodOut_CellHz
	wave BloodOut_depth
	wave BloodOut_DateTime

	// waves needed because we will sort them with the other waves
	wave/T bloodOut_date
	wave BloodOut_run 
	
	// wave that shows which exp done on which date
	wave expDate_Code
	

	Sort {bloodOut_date, BloodOut_position, BloodOut_vessel}, BloodOut_position, BloodOut_vessel, BloodOut_SpeedRad, BloodOut_CellHz, BloodOut_depth, BloodOut_DateTime, bloodOut_date,BloodOut_run
	
	variable secsPerDay = 86400
	variable ii, iExp, iMinus1Exp, iPos, iMinus1Pos, iVessel, iMinus1Vessel, in = dimsize (BloodOut_vessel, 0)
	variable col, row, expCode
	variable outN = numPnts (Ves_exp)
	variable startP, endP
	// for each experiment
	iMinus1Exp = bloodOut_dateTime [0] - mod (bloodOut_dateTime [0],secsPerDay)
	for (ii=0, iExp = iMinus1Exp; (ii < in) && (iExp == iMinus1Exp); iMinus1Exp = iExp)
		// find expCode
		 iExp = bloodOut_dateTime [ii] - mod (bloodOut_dateTime [ii],secsPerDay)
		findValue/v=(iExp) expDate_Code
		col=floor(V_value/3)
		row=V_value-col*in
		expCode = expDate_Code [row] [1]
		// for each position in this experiment
		iMinus1Pos = BloodOut_position [ii]
		for (iPos = iMinus1Pos; ((ii < in) && (iPos == iMinus1Pos)); iMinus1Pos = iPos)
			iPos = BloodOut_position [ii]
			// for each vessel at this position
			iMinus1Vessel = BloodOut_vessel [ii]
			for (startP = ii, iVessel = iMinus1Vessel; ((ii < in) && (iVessel == iMinus1Vessel)); ii +=1)
				 iVessel = BloodOut_Vessel [ii] 
			endfor
			endP = ii-1
			// insert a row into outPut data
			InsertPoints outN, 1,Ves_exp, Ves_pos, ves_ves, ves_Depth,	ves_Blockage, ves_velAvg, ves_velStd, ves_CelAvg, ves_celStd
			outN +=1
			Ves_exp [outN] = expCode
			Ves_pos [outN] = iPos
			ves_ves [outN] = iVessel
			ves_Depth [OutN] = BloodOut_depth [ii]
			wavestats/Q/R=[startP,endP] BloodOut_SpeedRad
			ves_velAvg [OutN] = V_avg
			ves_velStd [outN] = V_sdev
			wavestats/Q/R=[startP,endP] BloodOut_CellHz
			ves_CelAvg [OutN] = V_avg
			ves_celStd [outN] = V_sdev
		endfor
	endfor
end

// if shift key is pressed, adds new value to old blockage value, instead of replacing old value
// if ctrl/command key pressed, sets blockage to 0. kinda silly for a graph marquee proc to not use the marquee, but there it is
// Last Modified Feb 08 2012 by Jamie Boyd
 function NQ_SetBloodBlocked()
 	
 	variable flags = GetKeyState(0)
 	variable deadZone
 	// get scan str
	SVAR curScan = root:packages:JB_Nidaq:Examine:curScan
	SVAR infoStr = $"root:Nidaq_Scans:" + curScan + ":" + curScan + "_info"
	if (NumberByKey("Mode", infoStr, ":", "\r") != 3)
		return 1
	endif
	string expNote = StringByKey("ExpNote", infoStr, ":", "\r")
 	if (flags & 1) // ctrl/command key to set blockage to 0
 		deadZone =0
 	else
		 //Get the marquee coordinates and calculate xsize as distance between left and right
		string vAxis = "left", hAxis = "bottom"
		string axes = axislist ("")
		if ((whichlistItem ("left", axes, ";")) == -1)
			if ((whichlistItem ("right", axes, ";")) == -1)
				doAlert 0, "Neither left nor right vertical axes were found."
			else
				vAxis = "right"
			endif
		endif
		if ((whichlistItem ("bottom", axes, ";")) == -1)
			if ((whichlistItem ("top", axes, ";")) == -1)
				doAlert 0, "Neither top nor bottom horizontal axes were found."
			else
				hAxis = "top"
			endif
		endif
		//Get the marquee coordinates and calculate xsize as distance between left and right
		GetMarquee/K $vAxis, $hAxis
		variable ySize = abs ((V_bottom - V_top))
		variable frametime = NumberByKey("FrameTime", infoStr, ":", "\r")
		deadZone = numberbyKey ("Blockage", expNote, "=", ";")
		if (numType (deadZone) == 2)
			 deadZone =0
		endif
		if (flags & 4) // shift key to add blockage to old value, not replace value
			deadZone = round (ySize/frametime *1000)/1000
		else
			deadZone += round (ySize/frametime *1000)/1000
		endif
	endif
	expNote = ReplaceNumberByKey("blockage", expNote, deadZone, "=", ";")
	infoStr = ReplaceStringByKey("ExpNote", infoStr, expNote, ":", "\r")
	NQ_showNote ("root:NIDAQ_Scans:" + CurScan + ":" + curScan +"_info")
 end
 
 
function/s Un60 ()
 
	string aScan, scans = ListObjects("root:Nidaq_Scans:", 4, "*", 2, ""), objStr, returnStr = ""
	variable iScan, nScans = itemsinList (scans, ";")
	for (iScan =0; iscan < nScans; iScan +=1)
		aScan = stringfromlist (iScan, scans)
		SVAR scanStr = $"root:Nidaq_Scans:" + aScan + ":" + aScan + "_info"
		objStr =stringbykey ("Obj", scanStr, ":", "\r")
		if (cmpStr (objStr, "40X") != 0)
			returnStr += aScan + ":" + objStr + ";"
			if (cmpStr (objStr, "60X") == 0)
				ObjOops(aScan, "60X", "40X")
			endif
		endif
	endfor 
	return returnSTr
end
 
 
 function ObjOops(CurScan, fromObj, toObj)
	string curScan, fromObj, toObj
	
	SVAR scanInfo = $"root:Nidaq_scans:" + curScan + ":" + curScan + "_info"
	
	variable mode = NumberByKey("Mode", scanInfo , ":" , "\r")
	string imChanDesc = StringByKey ("imChanDesc", scanInfo, ":", "\r")
	if (mode == kEphysOnly)
		return 1
	endif
	
	string objStr = stringbykey ("Obj", scanInfo , ":", "\r")
	if (cmpStr (objStr, fromObj) != 0)
		return 1
	endif
	
	WAVE/T objWave = root:Packages:jb_nidaq:acquire:ObjWave
	FindValue /TEXT=fromObj/TXOP=4 objWave
	variable fromPos = V_value
	FindValue /TEXT=toObj/TXOP=4 objWave
	variable toPos = V_value
	// X offset in note
	variable  sixtyxXpos = NumberByKey("Xpos", scanInfo , ":" , "\r")
	variable xSV = NumberByKey("XSV", scanInfo , ":" , "\r")
	variable xCenterV = (kNQxVoltStart + kNQxVoltEnd)/2
	variable xStage = sixtyxXpos - ((XSV - xCenterV) * str2num (ObjWave [(fromPos)] [1]))  -  str2num (ObjWave [(fromPos)] [3])
	variable fortyxXpos=  xStage + ((XSV - xCenterV) * str2num (ObjWave [(toPos)] [1]))  +  str2num (ObjWave [(toPos)] [3])
	scanInfo = ReplaceNumberByKey("Xpos", scanInfo, fortyxXpos, ":", "\r") 
	//x Scaling in note
	variable xpixSize = NumberByKey("xpixSIze", scanInfo , ":" , "\r")
	xPixSize *= (str2num (ObjWave [(toPos)] [1])/str2num (ObjWave [(fromPos)] [1]))
	scanInfo = ReplaceNumberByKey("xPixSize", scanInfo, xPixSize, ":", "\r") 
	// Y offset in note
	variable sixtyxYpos = NumberByKey("Ypos", scanInfo , ":" , "\r")
	variable ySV
	if (mode == kLineScan)
		ysv= NumberByKey("YLSV", scanInfo , ":" , "\r")
	else	
		ysv= NumberByKey("YSV", scanInfo , ":" , "\r")
	endif
	variable yCenterV = (kNQyVoltStart + kNQyVoltEnd)/2
	variable yStage = sixtyxYpos - ((YSV - xCenterV) * str2num (ObjWave [(fromPos)] [2]))  -  str2num (ObjWave [(fromPos)] [4])
	variable fortyxYpos=  YStage + ((YSV - xCenterV) * str2num (ObjWave [(toPos)] [2]))  +  str2num (ObjWave [(toPos)] [4])
	scanInfo = ReplaceNumberByKey("Ypos", scanInfo, fortyxYpos, ":", "\r") 
	// y Scaling in note
	if (mode != kLineScan)
		variable ypixSIze = NumberByKey("ypixSIze", scanInfo , ":" , "\r")
		yPixSize *=  (str2num (ObjWave [(toPos)] [2])/str2num (ObjWave [(fromPos)] [2]))
		scanInfo = ReplaceNumberByKey("yPixSize", scanInfo, yPixSize, ":", "\r") 
	endif
	//offset, scaling for waves
	variable iChan, nChans = itemsinlist (imChanDesc, ",")
	string aChan
	for (iChan = 0; iChan < nChans; iChan +=1)
		aChan = stringFromList (iCHan, imChanDesc, ",")
		WAVE aWave = $"root:Nidaq_scans:" + curScan + ":" + curScan + "_" + aChan
		 SetSCale/P  X, fortyxXpos, xPixSize, "m", aWave
		if (mode != kLineScan)
			 SetSCale/P  Y, fortyxYpos, yPixSize, "m", aWave
		endif
	endfor
	scanInfo = replacestringbykey ("Obj", scanInfo, toObj, ":", "\r")
	// now look at stuff already in Shared Waves Manager
	variable isValid
	string swdf = SharedWaves_GetDataFolder ("blood", isValid)
	if (!(isValid))
		doAlert 0, "No shared Waves Manager for blood"
		return 1
	endif
	wave runDateTimeWave = $swdf + "runDateTime"
	variable thisRundateTime = NumberByKey ("ExpTime", scanInfo, ":", "\r")
	wave/T runWave = $swdf + "run"
	wave speedRad = $swdf + "speedrad"
	wave diameter = $swdf + "diameter"
	variable iPt, nPts = numpnts (runDateTimeWave)
	for (iPt =0;iPt < nPts; iPt +=1)
		if (((runDateTimeWave [ipt] < thisRundateTime +10) && (runDateTimeWave [ipt] > thisRundateTime - 10)) && (cmpstr (curScan, runWave [ipt]) ==0))
			speedRad [iPt] *=  (str2num (ObjWave [(toPos)] [1])/str2num (ObjWave [(fromPos)] [1]))
			diameter [iPt]  *=  (str2num (ObjWave [(toPos)] [1])/str2num (ObjWave [(fromPos)] [1]))
			printf "Scan %s at point %g.\r", curScan, iPt
		endif
	endfor
	return 0
end