#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later



#define hasNIDAQ

#undef hasNIDAQ






//******************************************************************************************************
// Sets the output voltage on the galvos to 0
// Last Modified 2025/07/07 by Jamie Boyd
function NQ_ZeroGalvos(imageboard)	
	string imageboard
#ifdef hasNIDAQ
	fDAQmx_WriteChan(imageBoard, 0, 0, -10, 10)
	fDAQmx_WriteChan(imageBoard, 1, 0, -10, 10)
#endif
end

