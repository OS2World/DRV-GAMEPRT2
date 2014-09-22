/* , July 1, 2000 by J DaSilva, Vancouver, BC, Canada
 *
 * This program shows how you can access GAMEPRT2.SYS, which is based on
 * Frank Ivan's GAMEPORT.SYS joystick driver (see GAMEPT.ZIP).
 * Advantages of using GAMEPRT2.SYS over GAMEPORT.SYS is that GAMEPRT2.SYS
 * samples the joystick quicker by doing all 4 axis at the same time versus
 * GAMEPORT.SYS which does it 1 axis at a time.
 * Note you can now use this program with GAMEDD.SYS too because it is also
 * backwards compatible with GAMEPORT.SYS and GAMEPRT2.SYS since July 1, 2000
 * (see GAMEDD2.ZIP).
 *
 *	1989,1992	1999,2000
 *	GAMEPT.ZIP	GAMEPRT2.ZIP
 *	GAMEPORT.SYS--->GAMEPRT2.SYS--------+
 *	Frank Ivan	Jose DaSilva	    |
 *					    V
 *	19??,1995			1999,2000
 *	JOYSTICK.ZIP,JOYDOCS.ZIP	GAMEDD2.ZIP
 *	GAMEDD.SYS--------------------->GAMEDD.SYS
 *	GAMEVDD.SYS-------------------->(use original GAMEVDD.SYS)
 *	IBM, ver2.0			Jose Da Silva, Vancouver, Canada
 */

#include <stdlib.h>
#include <stdio.h>
#include <conio.h>
#define INCL_DOSDEVICES
#define INCL_DOSDEVIOCTL
#define INCL_DOSMEMMGR
#include <os2.h>

/****** GAMEPORT.SYS joystick definitions, start *****************************/
#define IOCTL_CAT_USER	0x80
#define GAME_NAME	"GAME$   "
#define GAME_PORT_GET	0x20		// read GAMEPORT.SYS values
#define GAME_PORT_RESET 0x60		// reset joystick mask with given value

#pragma pack(1)				// pack structure size is 1 byte
typedef struct {			// GAMEPORT.SYS structure
	USHORT	usJs_AxCnt;		// Joystick_A X position
	USHORT	usJs_AyCnt;		// Joystick_A Y position
	USHORT	usJs_BxCnt;		// Joystick_B X position
	USHORT	usJs_ByCnt;		// Joystick_B Y position
	USHORT	usJs_ButtonA1Cnt;	// button A1 press count
	USHORT	usJs_ButtonA2Cnt;	// button A2 press count
	USHORT	usJs_ButtonB1Cnt;	// button B1 press count
	USHORT	usJs_ButtonB2Cnt;	// button B2 press count
	UCHAR	ucJs_JoyStickMask;	// mask of connected joystick pots
	UCHAR	ucJs_ButtonStatus;	// bits of switches down
	ULONG	ulJs_Ticks;		// joystick clock ticks
} GAMEPORT_STRUCT;
#pragma pack()				//reset to normal pack size
/****** GAMEPORT.SYS joystick definitions, end *******************************/

int main (int argc, char *argv[]) {
	APIRET		rc;
	HFILE		hGame;
	GAMEPORT_STRUCT stJoyStatus;
	ULONG		ulAction, ulDataLen, ulLastTick;
	UCHAR		ucNewJoystickMask;

	printf("GAMEPORT.SYS & GAMEPRT2.SYS test program\n\n");

	printf("  1) Open a handle to GAME$ device.\n");
	rc = DosOpen((PSZ)GAME_NAME, &hGame, &ulAction, 0, FILE_READONLY,
		FILE_OPEN, OPEN_ACCESS_READONLY | OPEN_SHARE_DENYNONE, NULL);
	if (rc != 0) {
		printf("ERROR %d Could not open GAME$ device.", rc);
		exit(-1);
	}

	printf("  2) Send Reset. Read only joystick axis shown in mask.\n");
	ucNewJoystickMask = 0x01;	// read only joystick1 X-axis
	ucNewJoystickMask = 0x02;	// read only joystick1 Y-axis
	ucNewJoystickMask = 0x03;	// read only joystick1 X & Y-axis
	ucNewJoystickMask = 0x04;	// read only joystick2 X-axis
	ucNewJoystickMask = 0x08;	// read only joystick2 Y-axis
	ucNewJoystickMask = 0x0C;	// read only joystick2 X & Y-axis
	ucNewJoystickMask = 0x0F;	// read all 4 joystick axis
	printf("     Mask will be set to >0x0%x<\n", ucNewJoystickMask);
	printf("     Note: mask updates itself if no joystick(s) found.\n");

	ulDataLen = sizeof(ucNewJoystickMask);
	rc = DosDevIOCtl(hGame, IOCTL_CAT_USER, GAME_PORT_RESET,
		&ucNewJoystickMask, ulDataLen, &ulDataLen, NULL, 0, NULL);
	if (rc != 0) {
		printf("ERROR %d Could not Reset GAME$ joystick mask.", rc);
		DosClose(hGame);
		exit(-1);
	}

	printf("  3) Wait for Reset action to take effect in GAME$.\n");
	/* If you are testing to see how many joysticks exist (0,1 or 2) then
	 * you need to wait for the GAME$ device to implement the change before
	 * checking to see. When the joysticks are tested, then the joystick
	 * mask is set to zero for any joysticks not found and no measurements
	 * will be made for that bit any more, unless the joystick mask is
	 * reset again with a new value. GAMEPORT.SYS seems to take about 1/3
	 * of a second on Warp3.0 before the change happens. A good place to
	 * check is ulJs_Ticks but you should wait for it to change twice
	 * since GAMEPORT.SYS updates ulJs_Ticks before testing. GAMEPRT2.SYS
	 * and GAMEDD.SYS will happen sooner since the joysticks are tested
	 * more frequently.  Below are results for Warp3.0 on a 40MHz 80486.
	 *
	 * GAMEPORT.SYS (from GAMEPT.ZIP)
	 * ulJs_Ticks is updated during count 6 of 0-->9 cycle.
	 * JoystickA X is measured during 6, joystickA Y is measured during 7,
	 * joystickB X is measured during 8, joystickB Y is measured during 9
	 * and count is set to zero again. No measurements made during 0-->5.
	 * ulJs_Ticks increments at about 3.58 per second.
	 * Joystick response is about 3.58 tests per second.
	 *
	 * GAMEPRT2.SYS (from GAMEPRT2.ZIP)
	 * All joysticks tested at same time, so measurements doubled by making
	 * cycle 4-->0 instead of previous 0-->9 cycle.
	 * ulJs_Ticks still increments about 3.58 per second for compatibility.
	 * Joystick response is actually about 7.16 tests per second.
	 *
	 * GAMEDD.SYS (from GAMEDD2.ZIP)
	 * ulJs_Ticks increments about 3.58 per second for compatibility.
	 * Joystick response is actually about 16.12 tests per second default.
	 */
	ulDataLen = sizeof(stJoyStatus);
	rc = DosDevIOCtl(hGame, IOCTL_CAT_USER, GAME_PORT_GET,
		NULL, 0, NULL, &stJoyStatus, ulDataLen, &ulDataLen);
	if (rc != 0) {
		printf("ERROR %d Could not call IOCtl", rc);
		DosClose(hGame);
		exit(-1);
	}
	ulLastTick = stJoyStatus.ulJs_Ticks;
	while (stJoyStatus.ulJs_Ticks == ulLastTick) {
		rc = DosDevIOCtl(hGame, IOCTL_CAT_USER, GAME_PORT_GET,
			NULL, 0, NULL, &stJoyStatus, ulDataLen, &ulDataLen);
	}

	printf("  4) Report GAME$ results through structure stJoyStatus.\n");
	printf("\nCurrent Joystick Response Settings, press a key to quit\n");
	ulDataLen = sizeof(stJoyStatus);
	while(!kbhit()) {
		rc = DosDevIOCtl( hGame, IOCTL_CAT_USER, GAME_PORT_GET,
			NULL, 0, NULL, &stJoyStatus, ulDataLen, &ulDataLen);
		if (rc != 0)
		{
			printf("ERROR %d Could not call IOCtl", rc);
			DosClose(hGame);
			exit(-1);
		}

		printf("\x0D");
		printf("Mask %x", stJoyStatus.ucJs_JoyStickMask);
		printf("\tAxy: %x %x", stJoyStatus.usJs_AxCnt, stJoyStatus.usJs_AyCnt);
		printf("\tBxy: %x %x", stJoyStatus.usJs_BxCnt, stJoyStatus.usJs_ByCnt);

		printf("\tButS %x", stJoyStatus.ucJs_ButtonStatus);
		printf("\tButC ");
		printf("%d ", stJoyStatus.usJs_ButtonA1Cnt);
		printf("%d ", stJoyStatus.usJs_ButtonA2Cnt);
		printf("%d ", stJoyStatus.usJs_ButtonB1Cnt);
		printf("%d",  stJoyStatus.usJs_ButtonB2Cnt);
		printf("\tTick %d", stJoyStatus.ulJs_Ticks);
	}
	printf("\n\n  5) Close handle to GAME$ device and exit.\n");
	DosClose(hGame);
}
