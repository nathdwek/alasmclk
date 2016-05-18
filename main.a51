;Nathan Dwek -- Ilias Fassi Fihri
$include(t89c51cc01.inc)

ORG 000h
	LJMP init

ORG 000Bh
	LJMP twentyhzinterrupt

ORG 001Bh
	LJMP screeninterrupt

ORG 002Bh
	LJMP ringinginterrupt

;edge detection/debouncing
waspushed equ 00h
wasswitch equ 01h
digitdown equ 05h
thedigitdown equ 044h


;State machine
;register bank 0
state equ r2
counting equ 07
;single bit states
ringingonoff equ 02h
almstopped equ 03h

;counters for clk and cnt, as well as overflow values for minutes and seconds
alm_clk equ 043h
clk_ram equ 030h
alm_ram equ 036h
lims_ram equ 03Ch
lims_ram_h equ 040h
lims_ram_end equ 042h
twentyhz equ 042h
	
;screen
datab bit P4.1
shiftb bit P4.0
storeb bit P3.2
	
ZERO:  DB 11111b,00001b,01101b,01101b,01101b,01101b,01101b,00001b
ONE:   DB 11111b,11011b,11011b,11011b,11011b,11011b,11011b,11011b
TWO:   DB 11111b,00001b,01111b,01111b,00001b,11101b,11101b,00001b
THREE: DB 11111b,00001b,11101b,11101b,00001b,11101b,11101b,00001b
FOUR:  DB 11111b,11101b,11101b,11101b,00001b,01101b,01101b,01101b
FIVE:  DB 11111b,00001b,11101b,11101b,00001b,01111b,01111b,00001b
SIX:   DB 11111b,00001b,01101b,01101b,00001b,01111b,01111b,00001b
SEVEN: DB 11111b,10111b,10111b,10111b,10111b,11011b,11101b,00001b
EIGHT: DB 11111b,00001b,01101b,01101b,00001b,01101b,01101b,00001b
NINE:  DB 11111b,00001b,11101b,11101b,00001b,01101b,01101b,00001b
COLON: DB 11111b,11111b,11111b,11011b,11111b,11011b,11111b,11111b

init:
	;glb interrupt enable
	setb EA
	
	;Common to timers 0 and 1
	mov TMOD, #000100001b;T0:16bits, T1:8bits w autoreload

	;timer 0
	setb ET0
	MOV TH0, #03Ch;load the counter with 15535
	MOV TL0, #0AFh;idem
	setb TR0

	;timer 1
	setb ET1
	mov TL1, #00d
	mov TH1, #00d
	setb TR1

	;timer2
	setb ET2
	mov RCAP2H, #0fBH
	mov RCAP2L, #08eh
	setb IPL0.5

	;init state
	mov twentyhz, #020
	mov state, #counting
	setb almstopped
	clr ringingonoff
	
	;init overflow values for minutes and seconds
	mov 03ch, #010d
	mov 03dh, #06d
	mov 03eh, #010d
	mov 03fh, #06d
	mov 040h, #010d
	mov 041h, #010d
	
	;init screen stuff
	setb rs0
	mov r2, #02
	MOV R3, #08d ; 7 counter for Pointer
	MOV R4, #08d ; 8 rows
	MOV R5, #05d
	MOV R7, #11111110b;
	MOV R6, #08d
	CLR shiftb
	CLR datab
	CLR storeb
	clr rs0

	;TEST CLK
	mov 038h, #00d
	mov 035h, #00d
	mov 034h, #00d
	mov 033h, #00d
	mov 032h, #00d
	mov 031h, #00d
	mov 030h, #00d
	
	;TEST ALM
	mov 03bh, #00d
	mov 03ah, #00d
	mov 039h, #00d
	mov 038h, #00d
	mov 037h, #00d
	mov 036h, #00d
	
	;
	mov SP, #070h

	LJMP main

main:
	ljmp main


twentyhzinterrupt:
	djnz twentyhz, readbutton;if a second has passed, handle clock, countdown and then keyboard. Else, only handle kb
	mov twentyhz, #020
	mov r0, #clk_ram
	mov r1, #lims_ram
	
incclkloop:
	inc @r0
	mov A, @r1
	subb A, @r0
	jc clkoverflow
	ljmp deccntdwn
	
clkoverflow:
	mov @r0, #00
	inc r0
	inc r1
	cjne r1, #lims_ram_h, incclkloop

incclkhours1:
	inc @r0
	cjne @r0, #010, incclkhours2
	mov @r0, #00
	inc r0
	inc @r0
	ljmp deccntdwn

incclkhours2:
	cjne @r0, #04, deccntdwn
	inc r0
	cjne @r0, #02, deccntdwn
	mov @r0, #00
	dec r0
	mov @r0, #00

deccntdwn:
	jb TR2, ringing
	jb almstopped, readbutton
	mov r0, #alm_ram
	mov r1, #lims_ram
	
deccntloop:
	cjne r1, #lims_ram_end, notboum
	jmp boum

notboum:
	cjne @r0, #00, nounderflow
	mov A, @r1
	mov @r0, A
	dec @r0
	inc r0
	inc r1
	jmp deccntloop

nounderflow:
	dec @r0
	ljmp readbutton

boum:
	mov r7, #06d
	mov r0, #alm_ram
zeroloop:
	mov @r0, #00d
	inc r0
	djnz r7, zeroloop
	setb TR2
	ljmp readbutton

ringing:
	cpl ringingonoff

readbutton:
	jb P2.6, notpushed;
	setb waspushed;
	ljmp readswitch

notpushed:
	jb waspushed, nextstate
	clr waspushed
	ljmp readswitch

nextstate:
	clr waspushed;
	clr p2.4
	mov state, #counting
	dec state
	jb P2.5, readswitch
	setb almstopped
	clr TR2
	ljmp readswitch

readswitch:
	jb P2.5, swclk
	mov alm_clk, #alm_ram
	jb wasswitch, swdiff
	ljmp switchtoreadkb

swclk:
	mov alm_clk, #clk_ram
	jnb wasswitch, swdiff
	ljmp switchtoreadkb

swdiff:
	mov state, #counting
	setb p2.4
	mov C, P2.5
	mov wasswitch, C

switchtoreadkb:
	jb TR2, readkb
	cjne state, #counting, readkb
	LJMP endfiftymsinterrupt

readkb:
	mov P0, #00Fh
	jb digitdown, waitrelease
	JNB  P0.0,c0
	JNB  P0.1,c1
	JNB  P0.2,c2
	JNB  P0.3,c3
	LJMP endfiftymsinterrupt
	
waitrelease:
	JNB  P0.0,stilldown
	JNB  P0.1,stilldown
	JNB  P0.2,stilldown
	JNB  P0.3,stilldown
	clr digitdown
	LJMP digitreleased

stilldown:
	ljmp endfiftymsinterrupt

c0:
	mov P0, #000111111b
	JNB	P0.0, c0r1r2
	JMP c0r3r4

c0r1r2:
	mov P0, #001111111b
	JNB P0.0, fpushed
	JMP epushed
	
fpushed:
	LJMP endfiftymsinterrupt

c0r3r4:
	mov P0, #011101111b
	JNB P0.0, stoppushed
	JMP snoozepushed
	
stoppushed:
	clr TR2
	setb almstopped
	LJMP endfiftymsinterrupt

c1:
	mov P0, #000111111b
	JNB	P0.1, c1r1r2
	JMP c1r3r4

c1r1r2:
	mov P0, #001111111b
	JNB P0.1, ninepushed
	JMP sixpushed

ninepushed:
	mov thedigitdown, #09d
	ljmp digitpressed

c1r3r4:
	mov P0, #011101111b
	JNB P0.1, bpushed
	JMP threepushed
	
bpushed:
	LJMP endfiftymsinterrupt

c2:
	mov P0, #000111111b
	JNB	P0.2, c2r1r2
	JMP c2r3r4

c2r1r2:
	mov P0, #001111111b
	JNB P0.2, eightpushed
	JMP fivepushed

c2r3r4:
	mov P0, #011101111b
	JNB P0.2, zeropushed
	JMP twopushed
c3:
	mov P0, #000111111b
	JNB	P0.3, c3r1r2
	JMP c3r3r4

c3r1r2:
	mov P0, #001111111b
	JNB P0.3, sevenpushed
	JMP fourpushed

c3r3r4:
	mov P0, #011101111b
	JNB P0.3, apushed
	JMP onepushed

zeropushed:
	mov thedigitdown, #00d
	ljmp digitpressed
onepushed:
	mov thedigitdown, #01d
	ljmp digitpressed
twopushed:
	mov thedigitdown, #02d
	ljmp digitpressed
threepushed:
	mov thedigitdown, #03d
	ljmp digitpressed
fourpushed:
	mov thedigitdown, #04d
	ljmp digitpressed
fivepushed:
	mov thedigitdown, #05d
	ljmp digitpressed
sixpushed:
	mov thedigitdown, #06d
	ljmp digitpressed
sevenpushed:
	mov thedigitdown, #07d
	ljmp digitpressed
eightpushed:
	mov thedigitdown, #08d
	ljmp digitpressed

apushed:
epushed:
	LJMP endfiftymsinterrupt

snoozepushed:
	jnb TR2, endfiftymsinterrupt
	clr TR2
	mov 038h, #03d
	LJMP endfiftymsinterrupt
	
digitpressed:
	setb digitdown
	ljmp endfiftymsinterrupt
	
digitreleased:
	
	mov A, #lims_ram
	add A, state
	dec A
	mov r0, A
	mov A, @r0
	mov r0, thedigitdown
	inc r0
	subb A, r0
	jc endfiftymsinterrupt
	jnb p2.5, usedigit
	cjne state, #06d, chkhourfurther
	mov A, #02d
	subb A, thedigitdown
	jc endfiftymsinterrupt
	ljmp usedigit
chkhourfurther:
	cjne state, #05d, usedigit
	mov r7, 035h
	cjne r7, #02d, usedigit
	mov A, #03d
	subb A, thedigitdown
	jc endfiftymsinterrupt

usedigit:
	mov A, alm_clk
	add A, state
	dec A
	mov R0, A
	mov A, thedigitdown
	mov @R0, A
	djnz state, endfiftymsinterrupt
	mov state, #counting
	jb p2.5, shutled
	clr almstopped

shutled:
	setb p2.4
	ljmp endfiftymsinterrupt
	

endfiftymsinterrupt:
	MOV TH0, #03Ch;load the counter with 15535
	MOV TL0, #0AFh;idem
	RETI

ringinginterrupt:
	push psw
	clr TF2
	clr exf2
	jb ringingonoff, endtwentyhzint
	cpl p2.2

endtwentyhzint:
	pop psw
	reti

screeninterrupt:
	setb rs0
	mov r0, alm_clk
	mov r2, #03d
	MOV DPTR,#ZERO ; pointer goes to the first element of ZERO
outerloop:
	djnz r2, digit
	mov r2, #03d
	mov A, #010
	dec r0
	ljmp valtorepr
digit:
	mov A, @r0
valtorepr:
	mov B, #08d
	mul AB
	ADD A,R3;
	MOVC A,@A+DPTR
innerloop:
	RRC A ; rotate right and put in the carry
	MOV datab,C ; then put the value of carry in tghe data bit 
	SETB shiftb; we shift
	CLR shiftb; we clear
	DJNZ R5,innerloop; redo 5 times
	MOV R5, #05h
	inc r0
	djnz r6, outerloop
	mov r6, #08d
	mov r0, alm_clk
	
	MOV A,R7;
	
lines:				
	RRC A;
	MOV datab,C
	SETB shiftb
	CLR shiftb
	DJNZ R4,lines
	MOV R4, #08h;
	SETB storeb
	CLR storeb ; store bit
	MOV A,R7 
	RR A;
	MOV R7,A
	DJNZ R3,endscreenint
	MOV R3, #08h
	
endscreenint:
	MOV A,R3
	clr rs0
	reti

END
