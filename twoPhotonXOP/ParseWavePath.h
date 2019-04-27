/* Last Modified 2014/09/23 by Jamie Boyd 
   added conditional typedef for UInt16 */
#include "XOPStandardHeaders.h"
#include "XOPResources.h"				// Contains definition of XOP_TOOLKIT_VERSION

#if XOP_TOOLKIT_VERSION < 600
typedef long SInt32;
typedef unsigned long UInt32;
typedef unsigned char UInt8;
typedef unsigned short UInt16;
#endif

// typedefs for paramater string handling
typedef char DFPATH [MAXCMDLEN + 1];
typedef char WVNAME [MAX_OBJ_NAME + 1];

/* Prototypes */
void ParseWavePath (Handle fullPath, DFPATH dataFolderName, WVNAME waveName);
waveHndl* ParseWaveListPaths (Handle pathsList, UInt16 *nWavesPtr);