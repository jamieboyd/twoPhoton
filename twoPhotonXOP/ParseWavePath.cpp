#include "ParseWavePath.h"
/*******************************************************************************************************
Takes a handle to a string containing either the name of an Igor Wave in the current data folder or the full path 
to an Igor Wave and copies the data folder path (if one is given) and the wave name into the given strings
Last Modified 2013/07/16 by Jamie Boyd - return full path to data folder when a relative path was passed in */
void ParseWavePath (Handle fullPath, DFPATH dataFolderName, WVNAME waveName){
	
	//char temp[256]; 
	// ignore leading and trailing spaces
	SInt32 startPos, stopPos, pathLen= (SInt32)WMGetHandleSize(fullPath);
	for (startPos = 0; (*(*fullPath + startPos) == ' ') && (startPos < pathLen); startPos++);
	for (stopPos = pathLen -1; (*(*fullPath + stopPos) == ' ') && (stopPos > startPos); stopPos--);
	pathLen = 1 + stopPos - startPos;
	// Find last colon, the break between the dataFolder and the waveName
	SInt32 waveNameBreak;
	for (waveNameBreak = stopPos;((*(*fullPath + waveNameBreak) != ':') && (waveNameBreak >= startPos)); waveNameBreak--);
	//copy wavename
	memcpy (waveName, *fullPath + waveNameBreak + 1, (stopPos  - waveNameBreak));
	waveName [(stopPos - waveNameBreak)] = 0;
	//sprintf(temp, "Wave Name = %s"CR_STR, waveName); 
	//XOPNotice (temp);
	// rest of string is folder path
	// If count down gets to startPos, then no colon, so no datafolder, just wavename	
	if (waveNameBreak < startPos){
		// no data folder so return path to current folder
		GetDataFolderNameOrPath(NULL, 1, dataFolderName);
		//sprintf(temp, "current: dataFolder Name = %s"CR_STR, dataFolderName); 
		//XOPNotice (temp);
	}else{ // there is at least one colon, so there is a datafolder
		   // check for absolute path (starts with root:)
		if (waveNameBreak - startPos + 1 > 4){
			char rootStr[6];
			rootStr [0] ='r';
			rootStr [1] ='o';
			rootStr [2] = 'o';
			rootStr [3] = 't';
			rootStr [4] = ':';
			rootStr [5] = 0;
			char rootCompStr[6];
			memcpy (rootCompStr, *fullPath + startPos, 5);
			rootCompStr [5] = 0;
			if (CmpStr(rootCompStr, rootStr)==0){ // absolute path from root:
				memcpy (dataFolderName, *fullPath + startPos, (waveNameBreak + 1 - startPos));
				dataFolderName [waveNameBreak + 1 - startPos] = 0;
				//sprintf(temp, "absolute: dataFolder Name = %s"CR_STR, dataFolderName); 
				//XOPNotice (temp);
				return;
			}
		}// to get to here, we must have relative path from current folder
		stopPos = waveNameBreak;
		SInt32 curPathLen, curPathPos, iLevel, pathLevels;
		DFPATH curPath;
		GetDataFolderNameOrPath(NULL, 1, curPath);
		//sprintf(temp, "Current Path= %s"CR_STR, curPath); 
		//XOPNotice (temp);
		curPathLen = (SInt32)strlen (curPath);
		// first colon can safely be ignored because root: vs :root: has already been disambiguated
		if (*(*fullPath + startPos) == ':')
			startPos++;
		// count levels of datafolder traversal
		for (pathLevels=0; *(*fullPath + startPos) == ':'; startPos++, pathLevels++);
		// go back that many levels in curpath
		for (iLevel=0, curPathPos = curPathLen; iLevel < pathLevels && curPathPos > 1; curPathPos--){
			if (curPath[curPathPos-2] == ':')
				iLevel++;
		}
		if (curPathPos ==1){ // we can't go back that far!Start from root: instead
			dataFolderName [0] ='r';
			dataFolderName [1] ='o';
			dataFolderName [2] = 'o';
			dataFolderName [3] = 't';
			dataFolderName [4] = ':';
			//sprintf(temp, "Too many colons! dataFolder starts from root"CR_STR); 
			//XOPNotice (temp);
			curPathPos = 5;
		}else{ // start full path from root to wherever the colons take us from the current folder
			memcpy (dataFolderName, curPath, curPathPos);
		}
		// finish the part of the path that is relative to the current folder
		memcpy (dataFolderName + curPathPos, *fullPath + startPos, (stopPos - startPos +1));
		dataFolderName [curPathPos + (stopPos - startPos +1)] = 0;
		//sprintf(temp, "relative: dataFolder Name = %s"CR_STR, dataFolderName); 
		//XOPNotice (temp);
	}
}

/*******************************************************************************************************
Takes a handle to a string containing a semicolon- or comma-separated list of names of Igor waves in the current datafolder
or full paths to Igor waves and returns a pointer to an array of Wave Handles corresponding to those waves.
Also sets the variable pointed to by nWavesPtr to the number of waves in the list
Last Modified 2013/07/16 by Jamie Boyd  */
waveHndl* ParseWaveListPaths (Handle pathsList, UInt16* nWavesPtr){
 
	SInt32 listLen = (SInt32)WMGetHandleSize (pathsList);
	// Count semicolons/commas to see how many waves we have.
	UInt16 nWaves = 1;
	// ignore trailing semicolon/comma if present
	if ((*(*pathsList + listLen -1) == ';')|| (*(*pathsList + listLen -1) == ','))
		listLen--;
	for (UInt16 iList =0; iList < listLen -1 ; iList++){
		if ((*(*pathsList + iList) == ';') || (*(*pathsList + iList) == ',')) nWaves ++;
	}
	// make array of waveHandles
	waveHndl* handleList = (waveHndl*)WMNewPtr (nWaves * sizeof(waveHndl));
	// make a handle and 2 strings to pass to parseWavePath
	Handle aPath=WMNewHandle ((MAXCMDLEN + 1) * sizeof (char));
	DFPATH dataFolderPath;
	DataFolderHandle pathDFHandle;
	WVNAME nameOfWave;
	UInt16 iWave =0;
	SInt32 startPos=0;
	SInt32 nameLen =0;
	// find each wave name/path by looking for semicolons/commas and parse it
	for (iWave =0, startPos=0; iWave < nWaves ; startPos += nameLen + 1, iWave++){
		// find next semicolon/comma, or end of list
		for (nameLen =0 ; (((*(*pathsList + startPos + nameLen) != ';') && (*(*pathsList + startPos + nameLen) != ',')) && (startPos + nameLen < listLen)) ; nameLen ++);
		// copy the wave name/path into a handle and Parse it into datafolder path and wavename
		WMSetHandleSize (aPath, (nameLen * sizeof (char)));
		if (aPath == NULL){
			handleList[iWave] = NULL; 
			continue;
		}
		memcpy ((void*)*aPath, (void*)(*pathsList + startPos), (nameLen * sizeof (char)));
		ParseWavePath (aPath, dataFolderPath, nameOfWave);
		// Make reference to dataFolder
		GetNamedDataFolder (NULL, dataFolderPath, &pathDFHandle);
		// get wave reference and add to handleList
		handleList[iWave] = FetchWaveFromDataFolder(pathDFHandle, nameOfWave);
	}
	// free aPath handle
	WMDisposeHandle (aPath);
	*nWavesPtr = nWaves;
	// return pointer to wave handles array
	return handleList;
}
