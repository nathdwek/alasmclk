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
twentyhz equ r0
	
;edge detection
waspushed equ 00h

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
	setb RS0
	mov clks, #00;clock of seconds
	mov clkm, #00;clock of minutes
	mov clkh, #00;clock of hours
	clr RS0
	LJMP main
	  
main:
	ljmp main
	
fiftymsinterrupt:
	djnz twentyhz, readbutton
	mov twentyhz, #020
	setb RS0
	inc clks;increment the clock of the seconds 
	cjne clks, #060, readbutton; if the clock is not equal to 60 seconds we jump to the reqdbutton part
	mov clks, #00
	inc clkm;increment the clock of the minutes
	cjne clkm, #060, readbutton; if the clock is not equal to 60 minutes we jump to the reqdbutton part
	mov clkm, #00
	inc clkh;increment the clock of the hours
	cjne clkh, #024, readbutton; if the clock is not equal to 24 hours we jump to the reqdbutton part
	mov clkh, #00

readbutton:
	jb P2.6, notpushed;
	setb waspushed;
	ljmp buttontoreadkb;
	
notpushed:
	jb waspushed, nextstate
	clr waspushed
	ljmp buttontoreadkb
	
nextstate:
	clr waspushed;
	cpl p2.4
	djnz state, buttontoreadkb
	mov state, #counting
	ljmp buttontoreadkb	

buttontoreadkb:
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