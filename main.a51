;Nathan Dwek -- Ilias Fassi Fihri
$include(t89c51cc01.inc)

ORG 000h
	LJMP init

ORG 000Bh
	LJMP twentyhzinterrupt

ORG 002Bh
	LJMP ringinginterrupt

;counters
;register bank 0
twentyhz equ 040h

;edge detection
waspushed equ 00h
wasswitch equ 01h

;State machine
;register bank 0
state equ r5
counting equ 07
seth10 equ 06
seth1 equ 05
setm10 equ 04
setm1 equ 03
sets10 equ 02
sets1 equ 01
ringingonoff equ 02h
almstopped equ 03h

alm_clk equ r6
clk_ram equ 030h
alm_ram equ 036h
lims_ram equ 03Ch
lims_ram_end equ 040h

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
	mov TL1, #0200d
	mov TH1, #0200d
	setb TR1

	;timer2
	setb ET2
	mov RCAP2H, #0fBH
	mov RCAP2L, #08eh

	;init state
	mov twentyhz, #020
	mov state, #counting
	clr almstopped
	clr ringingonoff
	
	;init lims
	mov 03ch, #010
	mov 03dh, #06
	mov 03eh, #010
	mov 03fh, #06

	;TEST
	mov 036h, #010
	mov 037h, #01
	mov 038h, #00
	mov 035h, #00
	mov 034h, #00
	mov 033h, #00
	mov 032h, #00
	mov 031h, #04
	mov 030h, #08

	LJMP main

main:
	ljmp main


twentyhzinterrupt:
	djnz twentyhz, readbutton;if a second has passed, handle clock, countdown and then keyboard. Else, only handle kb
	mov twentyhz, #020
	mov r0, #clk_ram
	mov r1, #lims_ram
	
incclkloop:
	cpl p2.3
	inc @r0
	mov A, @r1
	subb A, @r0
	jz clkoverflow
	ljmp deccntdwn
	
clkoverflow:
	cpl p2.4
	mov @r0, #00
	inc r0
	inc r1
	cjne r1, #lims_ram_end, incclkloop

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
	cjne @r0, #00, decsec
	inc r0
	cjne @r0, #00, decmin
	inc r0
	cjne @r0, #00, dechour
	ljmp boum

decsec:
	dec @r0
	ljmp readbutton

decmin:
	dec @r0
	dec r0
	mov @r0, #060
	ljmp readbutton

dechour:
	dec @r0
	dec r0
	mov @r0, #060
	dec r0
	mov @r1, #060
	ljmp readbutton

boum:
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
	djnz state, readswitch
	mov state, #counting
	ljmp readswitch

readswitch:
	jb P2.5, swhours
	mov alm_clk, #alm_ram
	jb wasswitch, swdiff
	ljmp switchtoreadkb

swhours:
	mov alm_clk, #clk_ram
	jnb wasswitch, swdiff
	ljmp switchtoreadkb

swdiff:
	mov state, #counting
	mov C, P2.5
	mov wasswitch, C
	cpl p2.4

switchtoreadkb:
	jb TR2, readkb
	cjne state, #counting, readkb
	LJMP endfiftymsinterrupt

readkb:
	mov P0, #00Fh
	JNB  P0.0,c0
	JNB  P0.1,c1
	JNB  P0.2,c2
	JNB  P0.3,c3
	LJMP endfiftymsinterrupt

c0:
	mov P0, #000111111b
	JNB	P0.0, c0r1r2
	JMP c0r3r4

c0r1r2:
	mov P0, #001111111b
	JNB P0.0, fpushed
	JMP epushed

c0r3r4:
	mov P0, #011101111b
	JNB P0.0, stoppushed
	JMP snoozepushed

c1:
	mov P0, #000111111b
	JNB	P0.1, c1r1r2
	JMP c1r3r4

c1r1r2:
	mov P0, #001111111b
	JNB P0.1, bpushed
	JMP threepushed

c1r3r4:
	mov P0, #011101111b
	JNB P0.1, ninepushed
	JMP sixpushed

c2:
	mov P0, #000111111b
	JNB	P0.2, c2r1r2
	JMP c2r3r4

c2r1r2:
	mov P0, #001111111b
	JNB P0.2, zeropushed
	JMP twopushed

c2r3r4:
	mov P0, #011101111b
	JNB P0.2, eightpushed
	JMP fivepushed
c3:
	mov P0, #000111111b
	JNB	P0.3, c3r1r2
	JMP c3r3r4

c3r1r2:
	mov P0, #001111111b
	JNB P0.3, apushed
	JMP onepushed

c3r3r4:
	mov P0, #011101111b
	JNB P0.3, sevenpushed
	JMP fourpushed

zeropushed:
twopushed:
threepushed:
fivepushed:
sixpushed:
sevenpushed:
eightpushed:
ninepushed:
apushed:
bpushed:
epushed:
fpushed:
onepushed:
fourpushed:
	cpl p2.3
	LJMP endfiftymsinterrupt

snoozepushed:
	clr TR2
	mov 036h, #010
	LJMP endfiftymsinterrupt

stoppushed:
	clr TR2
	setb almstopped
	LJMP endfiftymsinterrupt

endfiftymsinterrupt:
	MOV TH0, #03Ch;load the counter with 15535
	MOV TL0, #0AFh;idem
	RETI

ringinginterrupt:
	clr TF2
	clr exf2
	jnb ringingonoff, retint
	cpl p2.2
retint:
	reti

END
