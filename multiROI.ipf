#pragma rtGlobals=1		// Use modern global access method.
//#include "2P_examine"
//#include "2P_acquire"

Function MultiROI()
	

	string ROI
	string channel = "ch1"
	string ScanName
	variable darkL, darkR, darkT, darkB
	variable smthMode = 1
	variable/G Gbatchsize = 8 
	string savedFolder = getDataFolder (1)
	variable/G Gnumtrials
	variable/G GbslnSt
	variable/G GbslnEnd
	variable/G GpeakSt
	variable/G GpeakEnd

	
	string curFolder = getdatafolder(1)
	
	if(DataFolderExists("ROI_analysis"))
		setdatafolder ROI_analysis
	else	
		NewDataFolder/S ROI_analysis
	endif
	
	
	string foldername 
	
	NVAR curScanNumber = root:packages:JB_NIDAQ:examine:curScanNum
	wave/T ROIListWave = root:packages:JB_NIDAQ:examine:ROIListWave
	wave ROIListSelWave = root:packages:JB_NIDAQ:examine:ROIListSelWave
	variable ScanNumber = curScanNumber
	variable batchsize = Gbatchsize
	variable numtrials =Gnumtrials
	variable bslnSt = GbslnSt
	variable bslnEnd = GbslnEnd
	variable peakSt = GpeakSt
	variable peakEnd = GpeakEnd

	
	prompt batchsize, "Batch Size:" // number of stimuli in a trial
	prompt numtrials, "Number of trials:" //
	prompt bslnSt, "Baseline Start:"
	prompt bslnEnd, "Baseline End:"
	prompt peakSt, "Peak Start:"
	prompt peakEnd, "Peak End:"
	
	
	DoPrompt "Input:", batchsize, numtrials, bslnSt, bslnEnd, peakSt, peakEnd
	
	Gbatchsize = batchsize
	Gnumtrials = numtrials
	GbslnSt = bslnSt
	GbslnEnd = bslnEnd
	GpeakSt = peakSt
	GpeakEnd = peakEnd
	
	variable ROIList
	variable bsln

for (ROIList = 0; ROIList < numpnts(ROIListWave); ROIList+=1)
if (ROIListSelWave[ROIList] == 1)
	ROI = ROIListWave[ROIList]
	print ROI
	foldername = "root:ROI_analysis:ROI"+ROI
	
	if(DataFolderExists(foldername))
		setdatafolder $foldername
	else	
		NewDataFolder/S $foldername
	endif
	
	
	wave roiX = $("root:Nidaq_ROIs:" + ROI+"_x") // these 2 waves describe a profile over which to
	wave roiY  = $("root:Nidaq_ROIs:" + ROI+"_y")
	
	if(batchsize == 8)
		if(waveExists(order)==0)
			make/n = (batchsize) order 
			order = {3,5,7,0,2,4,6,1}	// traces displayed in this specific order --> {225,270,315,0,45,90,135,180}   //old values: order = {6,1,5,3,7,0,4,2} 	
		else
		endif 
	endif
	
	if (ScanNumber < 10)
		ScanName = "Scan_00"+num2str(ScanNumber)
	elseif(ScanNumber >10 && ScanNumber < 100)
		ScanName = "Scan_0"+num2str(ScanNumber)
	endif
	
	wave inputWave = $("root:Nidaq_Scans:" +ScanName + ":" + ScanName + "_" + channel)  	
	
	variable darkAvg	
	Make/O/N=(DimSize(inputWave, 2)) ROIavg
	
	
	variable getDark = (!((((numtype (darkL) ==2) || (numType (darkR) ==2)) || (numType (darkT) == 2)) || (numType (darkB) == 2)))
	
	variable st_pt = 0,end_pt = 0
	STRING axisname, signals
	
	variable i , j, k, ii, l
	for (i = 0; i < numtrials; i +=1)
		for (j = 0; j < batchsize; j+=1)
		 	if (ScanNumber < 10)
				ScanName = "Scan_00"+num2str(ScanNumber)
			elseif(ScanNumber >10 && ScanNumber < 100)
				ScanName = "Scan_0"+num2str(ScanNumber)
			endif

			wave inputWave = $("root:Nidaq_Scans:" +  ScanName + ":" +  ScanName + "_" + channel)  
			
			if(waveexists(inputWave) == 0)
				abort "root:Nidaq_Scans:" +  ScanName + ":" +  ScanName + "_" + channel + " - does not exist"
			else
			//	print "root:Nidaq_Scans:" +  ScanName + ":" +  ScanName + "_" + channel +" - exists"
			endif
			
			ImageBoundaryToMask ywave=roiY,xwave=roiX,width=(dimSize(inputWave,0)),height=(dimSize(inputWave,1)),scalingwave=inputWave,seedx=(dimOffset(inputWave,0)+dimDelta(inputWave,0)),seedy=(dimOffset(inputWave,1)+dimDelta(inputWave,1))
			WAVE ROIMask = $(GetDataFolder(1) + "M_ROIMask")	
			
			for(k = 0; k < DimSize(inputWave, 2); k += 1)
				ImageStats/M=1/P=(k)/R=ROImask inputWave
				ROIavg[k] = V_avg
			endfor
			
			if(smthMode)
					Smooth/S=2 9, ROIavg //Savitzky-Golay smoothing // SS 10AUG2017 changed num from 15 to 9
			endif
			
			if (getDark)  // calculate dark value	
				for (darkAvg =0, ii=0; ii < DimSize(inputWave, 2); ii += 1)
					imagestats/GS={darkL ,darkR, darkB ,darkT}/P=(ii) inputWave
					darkAvg += V_avg
				endfor
				darkAvg /= DimSize(inputWave, 2)
			else
				darkAvg = 0
			endif
			darkAvg = 80
			//print darkAvg
			ROIavg -= darkAvg 
			wavestats/Q/R = [bslnSt,bslnEnd] ROIavg
			bsln = V_avg
			//bsln = 213
			//print bsln
			Duplicate/O ROIavg, ROIDF 
			ROIDF= (ROIavg-bsln)/bsln
			
			wavestats/Q/R = [peakSt,peakEnd] ROIDF
			print V_avg
			
			duplicate/O ROIDF, $( ScanName+"ROI"+ ROI)
			
			FindValue /V= (j) order
			l = V_value+1
			
			st_pt = 1/batchsize*(l-1)+.005  //divide the graph equally for the number of directions and space the plots for each direction.
	
			end_pt = 1/batchsize*l-.005
	
			k = order(l-1)
			
			wave Source = $( ScanName+"ROI"+ ROI)
			axisname = "axis"+ ScanName+"ROI"+ ROI //axis handle
			signals = "signal"+"ROI"+ROI+"_"+"graph" // window handle
			
			
			DoWindow $signals
			if(V_flag ==0) //if does not window exist
				display /N=$signals/B=$axisname source
				//tag /A=MT /N=$TagName $axisname, 0, DirectionName
				TextBox/C/N=directions/A=MT " { 225 , 270 , 315 , 0 , 45 , 90 ,135 ,180 }" // Create textbox with order of directions
			else
				appendtograph/W = $signals /B=$axisname source
			endif
		
			ModifyGraph axisEnab($axisname)={st_pt,end_pt} //position graph
			ModifyGraph standoff=1,freePos($axisname)={0,left}
		
			if(smthMode ==1) // show smoothened version as a thicker black line
				ModifyGraph lsize(source)=2;DelayUpdate
				ModifyGraph rgb(source)=(0,0,0)
			else
			endif
		
			
			ScanNumber +=1
		endfor
	endfor
endif
endfor
	
	setdatafolder curFolder
	
end
