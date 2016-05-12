;Nathan Dwek -- Ilias Fassi Fihri
$include(t89c51cc01.inc)
	
ORG 000h
	LJMP init

ORG 000Bh
	LJMP fiftymsinterrupt

ORG 002Bh
	LJMP ringinginterrupt

;counters
;register bank 0
twentyhz equ r6
	
;edge detection
waspushed equ 00h
wasswitch equ 01h

;State machine
;register bank 0
state equ r5
counting equ 04
seth equ 03
setm equ 02
sets equ 01
ringingonoff equ 02h
almstopped equ 03h

alm_clk equ r7
alm_ram equ 02Fh
clk_ram equ 032h

init:
	setb EA
	mov TMOD, #011h;select both 16 bit counters
	MOV TH0, #03Ch;load the counter with 15535
	MOV TL0, #0AFh;idem
	setb TR0
	mov twentyhz, #020
	mov state, #counting
	clr almstopped
	clr ringingonoff
	
	;TEST
	mov 030h, #010
	
	LJMP main
	  
main:
	ljmp main
	
fiftymsinterrupt:
	djnz twentyhz, readbutton
	mov twentyhz, #020
	mov r0, #clk_ram
	inc r0
	inc @r0
	cjne @r0, #060, deccntdwn; if the clock is not equal to 60 seconds we jump to the reqdbutton part
	mov @r0, #00
	inc r0
	inc @r0;increment the clock of the minutes
	cjne @r0, #060, deccntdwn; if the clock is not equal to 60 minutes we jump to the reqdbutton part
	mov @r0, #00
	inc r0
	inc @r0;increment the clock of the hours
	cjne @r0, #024, deccntdwn; if the clock is not equal to 24 hours we jump to the reqdbutton part
	mov @r0, #00

deccntdwn:
	jb TR2, ringing
	jb almstopped, readbutton
	mov r0, #alm_ram
	inc r0
	cjne @r0, #00, decsec
	inc r0
	cjne @r0, #00, decmin
	inc r0
	cjne @r0, #00, dechour
	ljmp boum
	
decsec:
	dec @r0
	cpl p2.3
	ljmp readbutton

decmin:
	cpl p2.4
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
	JNB P0.0, cpushed
	JMP dpushed
	
c0r3r4:
	mov P0, #011101111b
	JNB P0.0, fpushed
	JMP epushed

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
cpushed:
dpushed:
epushed:
fpushed:
onepushed:
fourpushed:
	cpl p2.3
	LJMP endfiftymsinterrupt
	
endfiftymsinterrupt:
	MOV TH0, #03Ch;load the counter with 15535
	MOV TL0, #0AFh;idem
	RETI

END