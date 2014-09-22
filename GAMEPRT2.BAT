echo off
echo This batch file will compile GAMEPRT2.ASM using masm 5.10 for OS/2

echo LIBRARY GAMEPRT2 INITGLOBAL >gameprt2.def
echo DATA PRELOAD NONSHARED	>>gameprt2.def
echo CODE PRELOAD IOPL		>>gameprt2.def
echo PROTMODE			>>gameprt2.def
echo DESCRIPTION 'gameprt2.sys OS/2 Joystick Device Driver' >>gameprt2.def

echo gameprt2.obj		 >gameprt2.lnk
echo gameprt2.sys		>>gameprt2.lnk
echo gameprt2.map		>>gameprt2.lnk
echo c:\masmP\bin\doscalls.lib	>>gameprt2.lnk
echo gameprt2.def		>>gameprt2.lnk

echo on
c:\masmP\bin\masm -mx -l gameprt2.asm;
pause
c:\masmP\bin\link /noe /nod /map @gameprt2.lnk
pause
echo off

del gameprt2.def
del gameprt2.lnk
del gameprt2.obj

del gameprt2.lst
del gameprt2.map
