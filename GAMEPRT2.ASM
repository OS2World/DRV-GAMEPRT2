	page	59,132
	title	"GAMEPRT2.SYS version 1.20 OS/2 Joystick GAME$ Driver"
;************************************************************************
;*									*
;*		      Game Port Driver Version 1.20			*
;*									*
;************************************************************************
;*									*
;* GAMEPRT2.ASM is an update based on GAMEPORT.ASM written in 1989-1992 *
;* by Frank Ivan of ICA Systems Inc.  You can find the original program *
;* and source code in GAMEPT.ZIP.					*
;*									*
;* Compatibility Chart:							*
;*									*
;* 1989,1992	1999,2000						*
;* GAMEPT.ZIP	GAMEPRT2.ZIP						*
;* GAMEPORT.SYS-GAMEPRT2.SYS--------+					*
;* Frank Ivan	Jose DaSilva	    |		^ 286 or better		*
;*				    V		---------------		*
;* 19??,1995			1999,2000	v 386 or better		*
;* JOYSTICK.ZIP,JOYDOCS.ZIP	GAMEDD2.ZIP				*
;* GAMEDD.SYS------------------>GAMEDD.SYS				*
;* GAMEVDD.SYS----------------->(use original GAMEVDD.SYS)		*
;* IBM, ver2.0			Jose Da Silva, Vancouver, Canada	*
;*									*
;* Version Copyrights:							*
;* 1.00 * Source code here from GAMEPORT.ASM is Copyright by Frank Ivan *
;*	  of ICA Systems Inc, 1989-1992					*
;* 1.10 * GAMEPORT.ASM original code Copyright by Frank Ivan while new	*
;*	  GAMEPRT2.ASM improvements Copyright by Jose Da Silva, 1999	*
;*	- 4 joystick axis are polled at once versus one axis at a time. *
;*	- Axis measurements made every 4.5 cycles versus every 9th for	*
;*	  better joystick response. No speed penalty if reading both XY *
;*	  for 1 joystick, plus you get 2x faster response. 1/2 the time *
;*	  penalty of GAMEPORT.SYS and 2x faster response if reading XY	*
;*	  for 2 joysticks.						*
;*	- DEVICE= option-switches added so you can tune GAMEPRT2.SYS	*
;*	  /P:xxxx lets you read another gameport instead of 201h.	*
;*	  /W:xxxx lets you decrement wait loop for lower time penalty	*
;*		  or increment it for faster computers that would time- *
;*		  out using previous GAMEPORT.SYS driver. Default=7D0	*
;*	  /VB displays latest version (default now quiet mode).		*
;*	- Word-aligned data, and start locations of most often used	*
;*	  routines so that clock cycles not lost due to odd-byte access *
;* 1.20 * GAMEPORT.ASM original code Copyright by Frank Ivan while new	*
;*	  GAMEPRT2.ASM improvements Copyright by Jose Da Silva, 2000	*
;*	- Tested, debugged, verified, GAMEPRT2.SYS TO return values	*
;*	  like GAMEPORT.SYS (except GAMEPRT2.SYS has quicker response). *
;*	- Created JOY_PORT.CPP and JOY_PORT.EXE to demonstrate access	*
;*	  to GAMEPRT2.SYS or GAMEPORT.SYS				*
;*	- Cleaned-up and included GAMEPRT2.ASM within GAMEPRT2.ZIP	*
;*									*
;************************************************************************
	page
	.286p
	.seq
	extrn	DosWrite:far
;------------------------------------------------------------------------
;Structure of an INIT request packet, used only during INIT (32byte)
;------------------------------------------------------------------------
IP	equ   es:[bx]	;request packet location
INITpkt struc
	db	?	;0	request packet length
	db	?	;1	(unit code for block DD only)
iCmd	db	?	;2	command code
iStat	dw	?	;3,4	status word
	dd	?	;5,6,7,8 reserved
	dd	?	;9,10,11,12 queue linkage
	db	?	;13	number of units
iDHptr	dd	?	;14,15,16,17 dev help pointer
iIparms dd	?	;18,19,20,21 parms on "DEVICE=" in config.sys
	db	?	;22	(drive#)
INITpkt ends
;------------------------------------------------------------------------
;Structure of a General IOCTL request packet (32byte)
;------------------------------------------------------------------------
GIO	equ	es:[bx] ;general IOCTL request packet location
GIOpkt	struc
	db	?	;0	request packet length
	db	?	;1	(unit code for block DD only)
gCmd	db	?	;2	command code
gStat	dw	?	;3,4	status word
	dd	?	;5,6,7,8 reserved
	dd	?	;9,10,11,12 (request packet queue linkage)
gCat	db	?	;13	category code
gCode	db	?	;14	function code
gParm	dd	?	;15,16,17,18 address of input parameters
gData	dd	?	;19,20,21,22 address of data buffer
gParm_l dw	?	;23,24	length of parm area  (IOCTL2 only)
gData_l dw	?	;25,26	length of data area  (IOCTL2 only)
GIOpkt ends
;------------------------------------------------------------------------

ADATA	SEGMENT PARA PUBLIC 'AUTO'
;------------------------------------------------------------------------
;GAMEPRT2.SYS device driver header
;------------------------------------------------------------------------
nexthdr dd	-1		;pointer to next device driver
devattr dw	9880h		;attribute flags
stratof dw	OFFSET stratgy	;strategy routine entry point
reserv1 dw	0		;IDC entry
devname db	'GAME$   '	;device name for "DosOpen"
reserv2 dw	0		;protect-mode CS Strategy Selector
	dw	0		;protect-mode DS selector
	dw	0		;real-mode CS Strategy Segment
	dw	0		;real-mode DS segment

;------------------------------------------------------------------------
;DevHelp entry point variable:
;This far (16:16) pointer into the kernel is the entry point for all
;device help calls made through the dhcalls lib.  It must be assigned
;at init to the value passed in the INIT request packet.
devHelp dd	0		;save DevHelp pointer here

dhStIRQ equ	1Bh		;device help, set IRQ
dhUnIRQ equ	1Ch		;device help, unset IRQ
dhStTmr equ	1Dh		;device help, set timer
dhRsTmr equ	1Eh		;device help, reset timer
dhEOI	equ	31h
;------------------------------------------------------------------------

tickCnt dw	0		;timer tick count

joyPstr equ	201h		;joy stick port
joyNotD equ	2000		;allow 2000 ticks (GAMEPORT.SYS default)
joyPort dw	joyPstr		;start with default joystick port 201h
joyMaxC dw	joyNotD		;start with default runaway count

jy_ax	equ	01h		;joystick ax bit
jy_ay	equ	02h		;joystick ay bit
jy_bx	equ	04h		;joystick bx bit
jy_by	equ	08h		;joystick by bit
jy_a1	equ	10h		;button a1
jy_a2	equ	20h		;button a2
jy_b1	equ	40h		;button b1
jy_b2	equ	80h		;button b2

joyMask db	00Fh		;joystick mask	(default=4 axis)
butStat db	0		;button status	(keep next to joyMask)

b1_cnt	dw	1		;button 1 count (1 used by verbose)
b2_cnt	dw	0		;button 2 count
a1_cnt	dw	0		;button 3 count
a2_cnt	dw	0		;button 4 count

js_cnt	dd	0		;joystick check count

	PUBLIC	ax_cnt, ay_cnt, bx_cnt, by_cnt, joyMask ;for debugging
ax_cnt	dw	0		;ax count
ay_cnt	dw	0		;ay count
bx_cnt	dw	0		;bx count
by_cnt	dw	0		;by count
axTcnt	dw	0		;ax temporary count
ayTcnt	dw	0		;ay temporary count
bxTcnt	dw	0		;bx temporary count
byTcnt	dw	0		;by temporary count

timTick dw	4		;clock ticks (cycle 4-->0)
clkTick dw	4		;check joysticks (cycle 4-->0 + 5-->0)
tickflg dw	0		;timer active flag

opncnt	dw	0		;count of opens

dbrk	MACRO
ifdef	DEBUG
	int	3
endif
	ENDM

;------------------------------------------------------------------------
;throw-away this DATA after INIT done
;------------------------------------------------------------------------
end_of_data	label	byte	;the rest isn't needed after init

initMsg db	0Dh,0Ah
	db	'Game Port Driver',0Dh,0Ah
	db	'Version 1.00 * Copyright (c) 1989,1992 ICA Systems Inc'
	db	0Dh,0Ah
;continue copyright protection for new source code updates (prior to GPL)
;GAMEPORT.ASM source is copyright Frank Ivan, new modifications here is:
	db	'Version 1.20 * Copyright (c) 1999,2000 by Jose Da Silva'
	db	0Dh,0Ah,0Ah
initMsL equ	$-OFFSET initMsg
bytesWr dw	0

ADATA	ENDS

DGROUP	GROUP	ADATA
CODE	SEGMENT PARA	'CODE'
	ASSUME	CS:CODE,DS:ADATA

;************************************************************************
	PUBLIC	stratgy		;make strategy public for debugging
stratgy PROC	FAR
;these are valid IOCTL request values encountered in strategy routine
rqInit	equ	0		;initialize
rqOpen	equ	13		;open
rqClose equ	14		;close
rqIOctl equ	16		;generic IOCTL
;these are valid IOCTL return call values when done particular strategy
rcDone	equ	0100h		;code for DONE
rcError equ	8000h		;status code for error
rcDev	equ	4000h		;also set ERR; error code defined by DD
rcGFail equ	000ch		;general failure error code
rcInUse equ	0014h		;device already in use error code
rcUnkwn equ	0003h		;unknown command error code

;examine command code in request packet, then go do that strategy
;	dbrk			;break on debug
	mov	al,es:[bx+2]	;get strategy code to do
chkIOC: cmp	al,rqIOctl	;if IOCtl, go do it
	je	IOCtlBd
	cmp	al,rqInit	;if initialize, go setup this driver
	jne	chkOpn
	jmp	NEAR PTR InitBrd
chkOpn: cmp	al,rqOpen	;if open, go open joystick port
	jne	chkCls
	jmp	NEAR PTR OpenBrd
chkCls: cmp	al,rqClose	;if close, go close joystick port
	jne	chkExt
	jmp	NEAR PTR CloseBd

;if none of above, execute default stuff
chkExt: mov	WORD PTR es:[bx+3],rcDone ;if here, then return "done"
	ret
stratgy ENDP

;************************************************************************
; IOCtl Routine - General IO control routine
;************************************************************************
	align	WORD			;word align for quicker start
	PUBLIC	IOCtlBd			;make public for debugging
IOCtlBd PROC	FAR
;	dbrk				;debug break point
	mov	al,es:[bx+14]		;get command to run

;GAMEPORT.SYS (20h) joystick read?
IOCjs:	cmp	al,20h			;read joystick?
	jne	IOCrst			;no, go try next command
	push	es			;hold ES for now
	les	di,DWORD PTR es:[bx+19] ;get the result block location
	mov	ax,ax_cnt		;store joystick counts
	mov	WORD PTR es:[di],ax
	mov	ax,ay_cnt
	mov	WORD PTR es:[di+2],ax
	mov	ax,bx_cnt
	mov	WORD PTR es:[di+4],ax
	mov	ax,by_cnt
	mov	WORD PTR es:[di+6],ax
	mov	ax,a1_cnt		;store pushbutton counts
	mov	WORD PTR es:[di+8],ax
	mov	ax,a2_cnt
	mov	WORD PTR es:[di+10],ax
	mov	ax,b1_cnt
	mov	WORD PTR es:[di+12],ax
	mov	ax,b2_cnt
	mov	WORD PTR es:[di+14],ax
;note: since both values next to each other, did a mov ax instead
;	mov	al,joyMask		;get the joystick mask
;	mov	ah,butStat		;get the button state
	mov	ax,WORD PTR joyMask	;get butStat & joystick Mask
	mov	WORD PTR es:[di+16],ax	;store the active mask
	mov	ax,WORD Ptr js_cnt	;store joystick check count
	mov	WORD PTR es:[di+18],ax
	mov	ax,WORD Ptr js_cnt+2
	mov	WORD PTR es:[di+20],ax
	pop	es			;restore register and exit
	jmp	SHORT IOCrtn

;GAMEPORT.SYS (60h) reset joysticks?
IOCrst: cmp	al,60h			;reset joysticks?
	jne	IOCerr			;error
	push	es			;hold ES for now
	les	di,DWORD PTR es:[bx+15] ;point to input param block
	mov	ax,WORD PTR es:[di]	;store new joystick mask
	mov	joyMask,al
	pop	es			;restore es and exit

;all okay, exit general IO control routine back to calling app
IOCrtn: mov	WORD PTR es:[bx+3],rcDone ;set the "done" flag
	ret

;return error if command not recognized
IOCerr: mov	WORD PTR es:[bx+3],rcDone+rcGFail+rcError+rcDev
	ret
IOCtlBd ENDP

;************************************************************************
; Open routine -  grab interrupt and set timer to read joysticks
;************************************************************************
	PUBLIC	OpenBrd		;make routine public for debugging
OpenBrd PROC	FAR
;	dbrk			;debug breakpoint
	push	es		;hold registers
	push	bx
	xor	ax,ax		;we need a zero
	cmp	opncnt,ax	;is TimerRtn already open?
	jne	OpenD		;yes, exit
	mov	a1_cnt,ax	;clear the button counts
	mov	a2_cnt,ax
	mov	b1_cnt,ax
	mov	b2_cnt,ax
	mov	al,4		;set countdown for joysticks
	mov	timTick,ax
	mov	al,0Fh		;start with all 4 joystick pots
	mov	joyMask,al
	mov	ax,OFFSET CS:TimeRtn ;get the timer routine
	mov	dx,dhStTmr	;set the timer function
	call	devHelp		;and call device help
	mov	tickflg,-1	;say we have a timer
OpenD:	inc	opncnt		;count this "open"
	pop	bx		;restore regs and exit with "done"
	pop	es
	mov	WORD PTR es:[bx+3],rcDone
	ret
OpenBrd ENDP

;************************************************************************
; Close routine - give up the interrupt
;************************************************************************
	PUBLIC	CloseBd		;make routine public for debugging
CloseBd PROC	FAR
;	dbrk			;debug breakpoint
	push	es		;hold registers
	push	bx
	cmp	opncnt,1	;is this the last open?
	jne	CloseD		;no - go on
	cmp	tickflg,0	;do we have a timer?
	je	CloseD		;no go on
	mov	ax,OFFSET CS:TimeRtn ;clear the timer
	mov	dx,dhRsTmr	;get the ResetTimer function
	call	devHelp		;and do it
	mov	tickflg,0	;no more timer running now
CloseD: dec	opncnt		;count this "close"
	pop	bx		;restore regs and exit with "done"
	pop	es
	mov	WORD PTR es:[bx+3],rcDone
	ret
CloseBd ENDP

;************************************************************************
; Timer Routine - Routine reads joystick values and pushbuttons
;************************************************************************
	align	WORD		;word align for a quicker start
	PUBLIC	TimeRtn		;make routine public for debugging
TimeRtn PROC	FAR
	pushf			;save the flags
	push	ax		;save registers affected
	push	bx
	push	cx
	push	dx
	push	si
	push	di
TimeCt: dec	WORD PTR timTick ;time to check joystick?
	jnz	TimeBt		;not yet, go check buttons again

;get joysticks and pushbuttons this time (2x per 9 cycles)
	mov	ax,clkTick	;get countdown timer
	xor	al,1		;(alternate between 4 and 5)
	mov	clkTick,ax
	mov	timTick,ax	;reset countdown timer
	and	al,1		;time to increment checkcount?
	jnz	TimeJs
	inc	WORD PTR js_cnt ;bump checkcount every 5+4 cycles
	adc	WORD PTR js_cnt+2,ax
TimeJs: call	JsCount		;go get joysticks and pushbuttons
	jmp	SHORT TimeSk	;go update pushbuttons

;get pushbuttons only, ignore joysticks this time
TimeBt: mov	dx,joyPort	;get pushbuttons only
	in	al,dx

;update pushbutton status
TimeSk: xor	al,0F0h		;status of all buttons, 0=nil
	and	al,0F0h
	mov	ah,butStat	;get old status
	mov	butStat,al	;update status
	and	ah,al		;set al with only NEW down presses
	xor	al,ah

;increment counts for only NEW pushbutton presses
TimeB2: shl	al,1		;update joystick2 button2 if pressed
	jnc	TimeB1
	inc	WORD PTR b2_cnt
TimeB1: shl	al,1		;update joystick2 button1 if pressed
	jnc	TimeA2
	inc	WORD PTR b1_cnt
TimeA2: shl	al,1		;update joystick1 button2 if pressed
	jnc	TimeA1
	inc	WORD PTR a2_cnt
TimeA1: shl	al,1		;update joystick1 button1 if pressed
	jnc	TimeDn
	inc	WORD PTR a1_cnt

TimeDn: pop	di		;restore the register and flags
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	popf
	ret
TimeRtn ENDP

;************************************************************************
; Joystick Count Routine - 4 at a time
; input : joyPort, joyMaxC, joyMask properly initialized
; output: joystick counts updated, al=pushbuttons
;************************************************************************
	PUBLIC	JsCount		;make routine public for debugging
JsCount PROC	NEAR
	push	bx		;hold affected registers
	push	cx
	push	dx
	mov	cx,joyMaxC	;load runaway counter
	mov	dx,joyPort	;point to gameport
	xor	bx,bx		;reset temporary counters
	mov	axTcnt,bx
	mov	ayTcnt,bx
	mov	bxTcnt,bx
	mov	byTcnt,bx
	mov	al,bl
	cli			;timing sensitive, don't interrupt
	out	dx,al		;trigger gameport timing
	mov	ah,joyMask	;timing break, get ports to measure
	in	al,dx		;read gameport
	push	ax		;hold buttons for later check
	jmp	SHORT JsLskp	;skip next read since we have a val

JsLoop: in	al,dx		;read gameport for next measurement
JsLskp: and	al,ah		;mask off unwanted ports
	jz	JsLdne		;exit loop if counting done
	shr	al,1		;update joystick Ax
	adc	axTcnt,bx
	shr	al,1		;update joystick Ay
	adc	ayTcnt,bx
	shr	al,1		;update joystick Bx
	adc	bxTcnt,bx
	shr	al,1		;update joystick By
	adc	byTcnt,bx
	loop	JsLoop		;loop until runaway count done

JsLdne: sti			;timing sensitive stuff done
	mov	bh,ah		;hold a copy of JoyMask for later
	mov	cx,joyMaxC	;prepare to turn off unused ports

JsAx:	shr	ah,1		;did we measure joystick ax?
	jnc	JsAy		;no, go do next port
	mov	dx,axTcnt	;yes, prepare to update ax_cnt
	cmp	dx,cx		;is there a joystick ax?
	jne	JsAxSt		;yes, go update ax_cnt
	xor	dx,dx		;no, return a zero
	or	bl,1		;turn-off ax count next-time
JsAxSt: mov	ax_cnt,dx	;update joystick ax

JsAy:	shr	ah,1		;did we measure joystick ay?
	jnc	JsBx		;no, go do next port
	mov	dx,ayTcnt	;yes, prepare to update ay_cnt
	cmp	dx,cx		;is there a joystick ay?
	jne	JsAySt		;yes, go update ay_cnt
	xor	dx,dx		;no, return a zero
	or	bl,2		;turn-off ay count next-time
JsAySt: mov	ay_cnt,dx	;update joystick ay

JsBx:	shr	ah,1		;did we measure joystick bx?
	jnc	JsBy		;no, go do next port
	mov	dx,bxTcnt	;yes, prepare to update bx_cnt
	cmp	dx,cx		;is there a joystick bx?
	jne	JsBxSt		;yes, go update bx_cnt
	xor	dx,dx		;no, return a zero
	or	bl,4		;turn-off bx count next-time
JsBxSt: mov	bx_cnt,dx	;update joystick bx

JsBy:	shr	ah,1		;did we measure joystick by?
	jnc	JsMask		;no, go update joystick mask
	mov	dx,byTcnt	;yes, prepare to update by_cnt
	cmp	dx,cx		;is there a joystick by?
	jne	JsBySt		;yes, go update by_cnt
	xor	dx,dx		;no, return a zero
	or	bl,8		;turn-off by count next-time
JsBySt: mov	by_cnt,dx	;update joystick by

JsMask: not	bl		;prepare to update joyMask
	and	bl,0Fh
	and	bl,bh		;turn-off bits for unused ports
	cli			;don't interrupt update
	cmp	bh,joyMask	;did user update mask?
	jne	JsMdne		;yes, don't update mask then
	cmp	bh,bl		;did our mask change?
	je	JsMdne		;no, don't update mask
	mov	joyMask,bl	;yes, update, remove unused ports
JsMdne: sti			;joyMask done, interrupts allowed

	pop	ax		;pick-up joystick pushbuttons
	pop	dx		;restore affected registers and return
	pop	cx
	pop	bx
	ret
JsCount ENDP

;************************************************************************
;throw-away this CODE after INIT done
;************************************************************************
end_of_code	label	byte	;code after this point is needed
				;only at initialization time

;************************************************************************
; Get Hex characters at [ds:si] and convert to value in DX subroutine
; input : es:si=pointer to char string to convert to hex
; output: dx=output hex value, cx=hex.char.count, es:si=next.char.ptr
;************************************************************************
GetHex	PROC	NEAR
	inc	si		;move to ':'
	xor	cx,cx		;0 chars, 0 char count
	xor	dx,dx		;return '0' sofar
GetNxt: inc	si		;move to character to test
	mov	al,es:[si]	;get character to test
	mov	ah,al
	and	ah,0F0h
	cmp	ah,40h		;upper case A-F?
	je	GetAlp		;yes, go add A-F
	cmp	ah,60h		;lower case a-f?
	je	GetAlp		;yes, go add a-f
	cmp	ah,30h		;number 0-9?
	je	GetNum		;yes, go add 0-9
GetDne: and	cx,cx		;no value if no hex number
	jz	GetExt
	cmp	cx,5		;1 to 4 digits found, so okay
	jl	GetExt
GetErr: xor	cx,cx		;cx=0 and zflag=true if error
GetExt: and	cx,cx
	ret

GetNum: and	al,0Fh		;get 0-9, exit if not
	cmp	al,9
	jg	GetDne
	jmp	SHORT GetTot

GetAlp: and	al,0Fh		;make A-F to 10-15, exit if not
	cmp	al,1
	jl	GetDne
	cmp	al,6
	jg	GetDne
	add	al,9

GetTot: shl	dx,4		;add digit to hex total
	add	dl,al
	and	dx,dx		;don't count digit if a starting zero
	jz	GetNxt
	inc	cx		;increment digit count and loop
	jmp	GetNxt
GetHex	ENDP

;************************************************************************
; initialization routine - Just set things up
;************************************************************************
	PUBLIC	InitBrd		;make routine public for debugging
InitBrd PROC	FAR
;	dbrk			;debug breakpoint

;save "DevHlp" call address
	mov	ax,es:[bx+14]	;store device-help far-call address
	mov	WORD PTR devHelp,ax
	mov	ax,es:[bx+16]
	mov	WORD PTR devHelp+2,ax

;initialize default values (these values already built-into data)
;	mov	b1_cnt,1	;verbose<>0 means no banner
;	mov	joyPort,joyPstr ;default joystick port =201h
;	mov	joyMaxC,joyNotD ;no-joystick found runaway count
;	mov	joyMask,0Fh	;all 4 joysticks

;check for options on "DEVICE=" in config file
	push	es		;hold pointers affected
	push	si
	mov	si,es:[bx+18]	;get the DEVICE= parameter address
	mov	ax,es:[bx+20]
	mov	es,ax
InitLp: mov	al,es:[si]
	inc	si
	cmp	al,0		;exit loop if end of data
	je	InitDn
	cmp	al,'/'		;loop for next char if no option
	jne	InitLp
	mov	ax,es:[si]	;get next 2 chars after '/'
	or	ax,2020h	;make lower-case
InitVb: cmp	ax,'bv'		;display title if verbose '/vb'
	jne	InitSp
	xor	ax,ax
	mov	b1_cnt,ax
	jmp	InitLp
InitSp: cmp	ax,':p'		;update port address if '/p:'
	jne	InitSw
	call	GetHex		;get new joystick port
	jz	InitLp		;error, invalid number found
	mov	joyPort,dx	;new joystick port address
	jmp	InitLp		;loop for another option
InitSw: cmp	ax,':w'		;update wait if '/w:'
	jne	InitLp
	call	GetHex		;get new wait value
	jz	InitLp		;error, invalid number found
	mov	joyMaxC,dx	;new joystick runaway time-out
	jmp	InitLp		;loop for another option
InitDn: pop	si		;restore pointers
	pop	es

;display message if /vb=verbose option on
	mov	ax,b1_cnt	;temporarily stored here
	and	ax,ax
	jnz	InitJs		;skip display of message
	push	1		;display the initial message at bootup
	push	ds
	push	OFFSET initMsg
	push	initMsL
	push	ds
	push	OFFSET bytesWr	;(return how many bytes got written)
	call	DosWrite

;now checkout all 4 joystick pots
InitJs: call	JsCount

;set ending offsets (throw away code not needed anymore after init)
cjsdon: mov	WORD PTR es:[bx+14],OFFSET end_of_code ;how much code
	mov	WORD PTR es:[bx+16],OFFSET end_of_data ;and data

;set other request packet fields
	mov	WORD PTR es:[bx+18],0
	mov	WORD PTR es:[bx+20],0

;set status and exit
	mov	WORD PTR es:[bx+3],rcDone ;"done"
	ret
InitBrd ENDP

CODE	ENDS
	end
