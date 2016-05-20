;Nathan Dwek -- Ilias Fassi Fihri
$include(t89c51cc01.inc)

ORG 000h
	ljmp init

ORG 000Bh
	ljmp twentyhzinterrupt

ORG 001Bh
	ljmp screeninterrupt

ORG 002Bh
	ljmp ringinginterrupt

;edge detection/debouncing
waspushed EQU 00h;Previous state of the button
wasswitch EQU 01h;Previous state of the switch
digitdown EQU 05h;If a numeric button has been pressed and not released yet
thedigitdown EQU 044h;Which one

;State machine
;register bank 0
state EQU r2;Which digit the user is changing
counting EQU 07;Reset value (i.e. everything running and user can't touch anything)
;is 7 because there are 6 digits and we don't use zero because djnz

;single bit states
ringingonoff EQU 02h;use to obtain the "beep...beep" effect
almstopped BIT P2.3;Is the alarm running

;counters for clk and cnt, as well as overflow values for minutes and seconds
alm_clk EQU 043h;This contains the address to either clk_ram or alm_ram depending on the display mode
clk_ram EQU 030h;Start of the memory of the clock (seconds, tens of seconds, and so forth)
alm_ram EQU 036h;Start of the memory of the alarm/countdown (idem)
lims_ram EQU 03Ch;Start of the memory of the overflow values (10, 6, 10, 6, 10, 10)
;(see further for the hours overflow)
lims_ram_h EQU 040h
lims_ram_end EQU 042h;We have to know those values to make some checks easier
twentyhz EQU 042h;This counter is used to go from the 20Hz timer 1 to a single second clock

;screen
;register bank 1
datab BIT P4.1
shiftb BIT P4.0
storeb BIT P3.2
matrixmodtwo EQU r2
matrixrow EQU r3
matrixcolumn EQU r5
matrix EQU r6
rowmask EQU r7

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
	mov TH0, #03Ch;load the counter with 15535 to get 20Hz
	mov TL0, #0AFh
	setb TR0;

	;timer 1
	setb ET1
	mov TL1, #00d
	mov TH1, #00d;Slowest 8bit timer 1e6/256
	setb TR1

	;timer2
	setb ET2
	mov RCAP2H, #0fBH
	mov RCAP2L, #08eh; 880Hz to get 440Hz with CPL
	setb IPL0.5;timer1 is very rapid and has higher priority than timer2. Change this in order to service the very short timer 2 interruption consistently

	;init state
	mov twentyhz, #020
	mov state, #counting
	setb almstopped

	;init overflow values for minutes and seconds
	mov 03ch, #010d
	mov 03dh, #06d
	mov 03eh, #010d
	mov 03fh, #06d
	mov 040h, #010d
	mov 041h, #010d

	;init screen stuff
	setb rs0
	mov matrixmodtwo, #03d
	mov matrixrow, #08d ; 7 counter for Pointer
	mov r4, #08d ; 8 rows
	mov matrixcolumn, #05d
	mov rowmask, #11111110b;
	mov matrix, #08d
	clr shiftb
	clr datab
	clr storeb
	clr rs0

	;ZERO CLK
	mov 038h, #00d
	mov 035h, #00d
	mov 034h, #00d
	mov 033h, #00d
	mov 032h, #00d
	mov 031h, #00d
	mov 030h, #00d

	;ZERO ALM
	mov 03bh, #00d
	mov 03ah, #00d
	mov 039h, #00d
	mov 038h, #00d
	mov 037h, #00d
	mov 036h, #00d

	;Move the stack pointer to a safer place since we use RB1, bit adressable ram and ram
	mov SP, #070h

	ljmp main

main:
	ljmp main

twentyhzinterrupt:;Timer 1
	djnz twentyhz, readbutton;if a second has passed, handle clock, countdown and then keyboard. Else, only handle kb
	mov twentyhz, #020
	mov r0, #clk_ram
	mov r1, #lims_ram

incclkloop:
	inc @r0;increment current digit
	mov A, @r1
	subb A, @r0;compare to current overflow value
	jc clkoverflow;branch accordingly
	ljmp deccntdwn

clkoverflow:;There was an overflow, zero current digit, go to next digit and limit, loop
	mov @r0, #00
	inc r0
	inc r1
	cjne r1, #lims_ram_h, incclkloop;If we reached the hours digit, the handling is more complex

incclkhours1:;This basically check for the overflow at 24, which spans to digits
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
	jb TR2, ringing;TR2 (buzzer) indicates if the alarm is ringing
	jb almstopped, readbutton
	mov r0, #alm_ram
	mov r1, #lims_ram

;read notboum first, it's easier that way
deccntloop:
	cjne r1, #lims_ram_end, notboum;if there was an underflow and we looped 6 times, than we reached zero!
	jmp boum

notboum:
	cjne @r0, #00, nounderflow
	mov A, @r1;Underflow: load the corresponding overflow value in the digit, and decrement it
	;(for example if overflow at 10 then the underflow value is 9)
	mov @r0, A
	dec @r0
	inc r0;And go decrement the next digit from which we borrowed
	inc r1
	jmp deccntloop

nounderflow:
	dec @r0
	ljmp readbutton

boum:;Basically start the buzzer timer, but also zero the cntdwn properly because
	;For some reason it sometimes decrements one too many times
	mov r7, #06d
	mov r0, #alm_ram
zeroloop:
	mov @r0, #00d
	inc r0
	djnz r7, zeroloop
	setb TR2
	ljmp readbutton

ringing:
	cpl ringingonoff;If ringing rather then decrement the timer every second
	;We should only toggle this bit on and off every second which is used to produce
	;The "Beep Beep effect"

;Debouncing routines for the button and the switch
;Compare current state to previous state, and do something on a change
readbutton:
	jb P2.6, notpushed;
	setb waspushed;
	ljmp readswitch

notpushed:
	jb waspushed, nextstate;Only do something on the release
	clr waspushed
	ljmp readswitch

nextstate:
	clr waspushed;
	clr p2.4
	mov state, #counting
	dec state;Allow user to start setting the alarm or clock value
	jb P2.5, readswitch;If in alarm mode, stop the alarm and the buzzer
	setb almstopped
	clr TR2

readswitch:
	jb P2.5, swclk
	mov alm_clk, #alm_ram
	jb wasswitch, swdiff;This time we do something at every change
	ljmp switchtoreadkb

swclk:
	mov alm_clk, #clk_ram
	jnb wasswitch, swdiff
	ljmp switchtoreadkb

swdiff:
	mov state, #counting;The user can't set up the alarm/clock by default
	setb p2.4
	mov C, P2.5
	mov wasswitch, C

switchtoreadkb:
	jb TR2, readkb;If buzzer ringing, allow read kb because user can snooze or stop
	cjne state, #counting, readkb;If state allows user to set up alarm or clock, read kb
	ljmp endtwentyhzisr;Else, not

readkb:
	mov P0, #00Fh;First check if any key is pressed
	;We use the check+two steps method
	jb digitdown, waitrelease;If we're waiting for a release, then do just that
	jnb  P0.0,c0
	jnb  P0.1,c1
	jnb  P0.2,c2
	jnb  P0.3,c3
	ljmp endtwentyhzisr

waitrelease:
	jnb  P0.0,stilldown
	jnb  P0.1,stilldown
	jnb  P0.2,stilldown
	jnb  P0.3,stilldown
	clr digitdown
	ljmp digitreleased

stilldown:
	ljmp endtwentyhzisr

c0:
	mov P0, #000111111b
	jnb	P0.0, c0r1r2
	jmp c0r3r4

c0r1r2:
	mov P0, #001111111b
	jnb P0.0, fpushed
	jmp epushed

fpushed:
	ljmp endtwentyhzisr

c0r3r4:
	mov P0, #011101111b
	jnb P0.0, stoppushed
	jmp snoozepushed

stoppushed:
	clr TR2
	setb almstopped
	ljmp endtwentyhzisr

c1:
	mov P0, #000111111b
	jnb	P0.1, c1r1r2
	jmp c1r3r4

c1r1r2:
	mov P0, #001111111b
	jnb P0.1, ninepushed
	jmp sixpushed

ninepushed:
	mov thedigitdown, #09d
	ljmp digitpressed

c1r3r4:
	mov P0, #011101111b
	jnb P0.1, bpushed
	jmp threepushed

bpushed:
	ljmp endtwentyhzisr

c2:
	mov P0, #000111111b
	jnb	P0.2, c2r1r2
	jmp c2r3r4

c2r1r2:
	mov P0, #001111111b
	jnb P0.2, eightpushed
	jmp fivepushed

c2r3r4:
	mov P0, #011101111b
	jnb P0.2, zeropushed
	jmp twopushed
c3:
	mov P0, #000111111b
	jnb	P0.3, c3r1r2
	jmp c3r3r4

c3r1r2:
	mov P0, #001111111b
	jnb P0.3, sevenpushed
	jmp fourpushed

c3r3r4:
	mov P0, #011101111b
	jnb P0.3, apushed
	jmp onepushed

;Memorize which digit was pushed, and that a digit is being pushed
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

;Those don't do anything
apushed:
epushed:
	ljmp endtwentyhzisr

snoozepushed:
	jnb TR2, endtwentyhzisr
	clr TR2
	mov 038h, #03d;3minutes
	ljmp endtwentyhzisr

digitpressed:
	setb digitdown
	ljmp endtwentyhzisr

digitreleased:
	;Check if value is within boundaries and if so load it in the adequate digit
	mov A, #lims_ram
	add A, state
	dec A
	mov r0, A
	mov A, @r0
	mov r0, thedigitdown
	inc r0
	subb A, r0
	jc endtwentyhzisr
	jnb p2.5, usedigit
	cjne state, #06d, chkhourfurther
	mov A, #02d
	subb A, thedigitdown
	jc endtwentyhzisr
	ljmp usedigit

chkhourfurther:
	cjne state, #05d, usedigit
	mov r7, 035h
	cjne r7, #02d, usedigit
	mov A, #03d
	subb A, thedigitdown
	jc endtwentyhzisr

usedigit:
	mov A, alm_clk
	add A, state
	dec A
	mov r0, A
	mov A, thedigitdown
	mov @r0, A
	djnz state, endtwentyhzisr
	mov state, #counting
	jb p2.5, shutled
	clr almstopped;When the user has set all alarm digits, immediately start the alarm

shutled:
	setb p2.4
	ljmp endtwentyhzisr

endtwentyhzisr:
	mov TH0, #03Ch;reload
	mov TL0, #0AFh
	reti

ringinginterrupt:
	push psw;This ISR interrupts screen interrupts, and both use the carry!
	clr TF2
	clr exf2
	jb ringingonoff, endbuzzerint;For the "beep beep" effect
	cpl p2.2

endbuzzerint:
	pop psw
	reti

screeninterrupt:
	;We do the one line per ISR method
	setb rs0
	mov r0, alm_clk
	mov matrixmodtwo, #03d;Display a colon every two digits
	mov DPTR,#ZERO
outerloop:
	djnz matrixmodtwo, digit
	mov matrixmodtwo, #03d
	mov A, #010;10 corresponds to a colon in the array defined at the beginning
	dec r0
	ljmp valtorepr
digit:
	mov A, @r0
valtorepr:
	mov B, #08d
	mul AB
	ADD A,matrixrow;
	movc A,@A+DPTR;The right byte is at 8*digit+row, digit to represent is in @r0
innerloop:
	rrc A ; rotate right and put in the carry
	mov datab,C ;then give to shift register
	setb shiftb; trigger shift
	clr shiftb
	djnz matrixcolumn,innerloop; redo 5 times
	mov matrixcolumn, #05h
	inc r0
	djnz matrix, outerloop
	mov matrix, #08d
	
	mov A,rowmask
activatesingleline:
	rrc A;
	mov datab,C
	setb shiftb
	clr shiftb
	djnz r4, activatesingleline
	mov r4, #08h;
	setb storeb
	clr storeb
	mov A,rowmask
	rr A;
	mov rowmask,A
	djnz matrixrow,endscreenint
	mov matrixrow, #08h

endscreenint:
	clr rs0
	reti

END
