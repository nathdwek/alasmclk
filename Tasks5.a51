
;$include(t89c51cc01.inc)

;BSEG
;hihihi bit P2.4
;CSEG
			
;ORG 000h
;main:	LJMP loop1


;ORG 0000h
;LJMP init
;ORG 000Bh
;LJMP timer0int

;ORG 
;LJMP timer1int 

;ORG 000Bh
;LJMP timer0interrupt
;loop1: 
	;MOV R1,#0FFh

;loop2: 
	;MOV R2,#0FFh

;loopit: 
	
	;DJNZ R2,loopit
	;DJNZ R1,loop2
	;CPL P2.4
	;LJMP main

;END
$include(t89c51cc01.inc)
	
BSEG
datab bit P4.1
shiftb bit P4.0
storeb bit P3.2
CSEG	


ORG 0000h
LJMP init
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
POINT: DB 11111b,11111b,11111b,11011b, 11111b, 11011b, 11111b, 11111b
	
	
init:					
						mov r2, #00d
						MOV R3, #08d ; 7 counter for Pointer
						MOV R4, #08d ; 8 rows
						MOV R5, #05d
						MOV R7, #11111110b;
						MOV R6, #08d
						CLR shiftb
						CLR datab
						CLR storeb
						CLR A
						MOV DPTR,#ZERO ; pointer goes to the first element of ONE

main:											

outerloop:
						mov A, r2
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
						inc r2
						djnz r6, outerloop
						mov r6, #08d
						mov r2, #00d
						
						MOV A,R7;
						
lines1:				

						RRC A;
						MOV datab,C
						SETB shiftb
						CLR shiftb
						DJNZ R4,lines1
						MOV R4, #08h;
						SETB storeb
						CLR storeb ; store bit
						MOV A,R7 
						RR A;
						MOV R7,A
						DJNZ R3,reset
						MOV R3, #08h
						MOV A,R3
						LJMP main
reset:
						MOV A,R3
						LJMP main
									
endr:
	RETI
				
END 

