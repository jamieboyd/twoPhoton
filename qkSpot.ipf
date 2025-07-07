#pragma TextEncoding = "Windows-1252"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
//quick online analysis for picking out DS cells in Gcamp retinas
//Operates on matrices in the standard folder tree of 2P_LSM
//parent folder is now twoP_Scans (rather than Nidaq_scans)
//indicate channel (1), prefix ("Scan"), firstScan (0), and numTrials (1)
Function qkSpot(channel, prefix, firstScan, numTrials)
	String prefix
	Variable channel, firstScan, numTrials
	
	Variable i, j, z, currentScan
	String zeroPads
	
	Variable xWidth, yHeight, frames
	Variable filterSize = 7 //n x n size of filter
	Variable preFilter = 1
	Variable useDarkSub = 1 //use dark subtracted values for dF calc
	String folderStr
	
	If(firstScan < 10)
		folderStr = "root:twoP_Scans:Scan_00"+num2str(firstScan)
	ElseIf(firstScan > 10 && firstScan < 100)
		folderStr = "root:twoP_Scans:Scan_0"+num2str(firstScan)
	ElseIf(firstScan > 100)
		folderStr = "root:twoP_Scans:Scan_"+num2str(firstScan)
	EndIf
	SetDataFolder folderStr
	
	//fudge baseline of pixels that survive darkF mask (cells)
	//this serves to fix dF/F0 issues arrising from near 0 F0s
	Variable bslnInflate = 1
	Variable inflation = 10 
	
	Make/O angle = {0, 180, 45, 225, 90, 270, 135, 315}
	
	Variable bslnStart, bslnEnd, peakStart, peakEnd
	bslnStart = 10
	bslnEnd = 18
	peakStart = 23
	peakEnd = 30
	
	Variable first = 1
	currentScan = firstScan
	for(i = 1; i <= numTrials; i += 1)
		for(j = 0; j < 8; j += 1)
			if(currentScan < 10)
				zeroPads = "00"
			elseif(currentScan < 100)
				zeroPads = "0"
			else
				zeroPads = ""
			endif
			
			WAVE Matrix = $("root:twoP_Scans:"+prefix+"_"+zeroPads+num2str(currentScan)+":"+prefix+"_"+zeroPads+num2str(currentScan)+"_ch"+num2str(channel)) 
			
			if(first)
				xWidth = DimSize(Matrix, 0) //DimSize returns the size of each dimension (x, y, z) 
				yHeight = DimSize(Matrix, 1)
				frames = DimSize(Matrix, 2)
				Make/O/N=(xWidth,yHeight) tempMatrix
				first = 0
			endif
			
			Duplicate/O/RMD=[][][bslnStart,bslnEnd] Matrix bsln
			Duplicate/O/RMD=[][][peakStart,peakEnd] Matrix peak
			
			if(preFilter)
				for(z = 0; z <= bslnEnd-bslnStart; z+=1)
					tempMatrix[][] = bsln[p][q][z]
					MatrixFilter/N=(filterSize) avg tempMatrix
					bsln[][][z] = tempMatrix[p][q]
				endfor
				for(z = 0; z <= peakEnd-peakStart; z+=1)
					tempMatrix[][] = peak[p][q][z]
					MatrixFilter/N=(filterSize) avg tempMatrix
					peak[][][z] = tempMatrix[p][q]
				endfor
			endif
			
			//subtract global F avg (dark and cells)
			MatrixOp/O avgF = mean(bsln)
			MatrixOp/O bslnSub = bsln - avgF[0][0][0]
			MatrixOp/O peakSub = peak - avgF[0][0][0]
			
			//collapse stacks of bsln and peak regions to 2D
			MatrixOp/O bsln2D =  sumBeams(bsln)/(bslnEnd-bslnStart)
			MatrixOp/O peak2D =  sumBeams(peak)/(peakEnd-peakStart)
			MatrixOp/O bsln2Dsub =  sumBeams(bslnSub)/(bslnEnd-bslnStart)
			MatrixOp/O peak2Dsub =  sumBeams(peakSub)/(peakEnd-peakStart)
			
			//non-cells will be negative from above subtraction
			//replace all negative values with 0 (acts as mask)
			MatrixOp/O negs = sgn(bsln2Dsub)
			MatrixOp/O negs = replace(negs,-1,0)
			MatrixOp/O bsln2D = bsln2D * negs
			MatrixOp/O bsln2Dsub = bsln2Dsub * negs
			if(bslnInflate) //increase base F for cells only
				MatrixOp/O negs = replace(negs,1,inflation)
				MatrixOp/O bsln2Dsub = bsln2Dsub + negs
			endif
			
			//ditto for peak matrix
			MatrixOp/O negs = sgn(peak2Dsub)
			MatrixOp/O negs = replace(negs,-1,0)
			MatrixOp/O peak2D = peak2D * negs
			MatrixOp/O peak2Dsub = peak2Dsub * negs
			if(bslnInflate) //increase base F for cells only
				MatrixOp/O negs = replace(negs,1,inflation)
				MatrixOp/O peak2Dsub = peak2Dsub + negs
			endif
			
			//dividing is creating problems because Fs for cells are too low
			//not much greater than background (so dF/F0 gives #s in 1000s)
			//bslnInflate added above to address this
			if(useDarkSub)
				MatrixOp/O dF = (peak2Dsub - bsln2Dsub)/(bsln2Dsub)
			else
				MatrixOp/O dF = (peak2D - bsln2D)/(bsln2D)
			endif	
			MatrixOp/O negs = sgn(df)
			MatrixOp/O negs = replace(negs,-1,0)
			MatrixOp/O dF = dF * negs
			
			//stacks to store 2D matrices for each direction
			if(!j)
				Make/O/N=(xWidth,yHeight,8) dFstack, xStack, yStack
				Make/O/N=(xWidth,yHeight,8) peak2Dstack, bsln2Dstack
			endif
			
			dFstack[][][j] = dF[p][q]
			//begin vector calculations
			MatrixOp/O tempMatrix = dF * cos(angle[j]*pi/180)
			xStack[][][j] = tempMatrix[p][q]
			MatrixOp/O tempMatrix = dF * sin(angle[j]*pi/180)
			yStack[][][j] = tempMatrix[p][q]
			
			//even if using non-sub matrices for math, store these
			//because the numbers are more intuitive to look at
			bsln2Dstack[][][j] = bsln2Dsub[p][q]
			peak2Dstack[][][j] = peak2Dsub[p][q]
			
			currentScan += 1
		endfor
		
		//calculate theta and DSi from X and Y vectors
		MatrixOp/O x2D =  sumBeams(xStack)
		MatrixOp/O y2D =  sumBeams(yStack)
		MatrixOp/O theta = atan2(y2D, x2D)*180/pi
		MatrixOp/O theta = replace(theta,0,NaN)
		x2D = x2D^2
		y2D = y2D^2
		MatrixOp/O radius = sqrt(x2D + y2D)
		MatrixOp/O DSi = radius / sumBeams(dFStack)
		
		//save for trial
		Duplicate/O bsln2Dstack $("bsln2Dstack_" + num2str(i))
		Duplicate/O peak2Dstack $("peak2Dstack_" + num2str(i))
		Duplicate/O dFstack $("dFstack_" + num2str(i))
		Duplicate/O theta $("theta_" + num2str(i))
		Duplicate/O DSi $("DSi_" + num2str(i))
		
		Wave newDSI = $("DSi_" + num2str(i))
		SetScale/P y,DimSize(newDSI,1),-1,newDSI
		
		//cleanup
		Killwaves/Z bsln,peak,dF,x2D,y2D,radius,bsln2D,peak2D
		KillWaves/Z DSi, theta, peakSub,bslnSub,negs,avgF
		KillWaves/Z bsln2Dsub, peak2Dsub
	endfor
	//cleanup
	KillWaves/Z xStack,yStack,tempMatrix,workMat
	KillWaves/Z dFstack,bsln2Dstack,peak2Dstack
	
End