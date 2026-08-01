#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

#pragma IndependentModule = RGBthread
threadsafe Function twoP_examineRGBthread(RGBWave, RGBsources, RGBfirstLasts)
	WAVE RGBWave
	WAVE/WAVE RGBsources
	WAVE RGBfirstLasts
	
	variable slope
	for(;;)
		DFREF dfr = ThreadGroupGetDFR(0, inf)
		NVAR toDo = dfr:toDoG  // bitwise 1 for red, 2 for green, 3 for blue
		// red layer
		WAVE redWave = rgbSources[0]
		if ((toDo & 1) && (waveexists(redWave)))
			slope = 255/(rgbfirstLasts[%lastRed] - rgbfirstLasts[%firstRed]) 
			rgbwave [] [] [0] = min (255, max (0, (redwave [p][q] - rgbfirstLasts[%firstRed]) * slope))
		endif

		// green layer
		WAVE greenWave = rgbSources[1]
		if ((toDo & 2) && (waveexists(greenWave)))
			slope = 255/(rgbfirstLasts [%lastGreen] - rgbfirstLasts [%firstGreen])
			rgbwave [] [] [1] = min (255, max (0, (greenwave [p][q] - rgbfirstLasts[%firstGreen]) * slope))
		endif

		// blue layer
		WAVE blueWave = rgbSources[2]
		if ((toDo & 4) && (waveexists(blueWave)))
			slope = 255/(rgbfirstLasts [%lastBlue] - rgbfirstLasts [%firstBlue])
			rgbwave [] [] [2] = min (255, max (0, (bluewave [p][q] - rgbfirstLasts[%firstBlue]) * slope))
		endif
	endfor

	return 0
end