#pragma rtGlobals=3
#pragma version = 2.1  	// Last Modified: 2016/11/08 by Jamie Boyd.
#pragma IgorVersion = 6.2

//******************************************************************************************************
// let's use some constant names for the scan modes to make things easier to remember.
// The various scaning modes are: 0:Live Mode; 1:Time Series; 2:Single (possibly with Averaging); 3:Line Scan; 4:Z Series; 5: electrophysiology only

constant kNQtoUnsigned = 2048 //2^(kNQimageBits-1) number to add to signed acquistion to convert to unsigned representation
// Which channel is red signal and which is green?
Constant kNQRedChan = 2
Constant kNQGreenChan =1
Constant kNQChan1Layer =0
Constant kNQChan2Layer =1
// Default Window sizes/positions for some of the more common graphs/panels
StrConstant kNQScanGraphPos = "293,96,1023,270"
StrConstant kNQTracesGraphPos = "130,492,779,748"
StrConstant kNQHistGraphPos = "224,455,590,650" 

