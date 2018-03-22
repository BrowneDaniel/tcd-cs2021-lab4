; Definitions  -- references to 'UM' are to the User Manual.

; Timer Stuff -- UM, Table 173

T0	equ	0xE0004000		; Timer 0 Base Address
T1	equ	0xE0008000

IR	equ	0			; Add this to a timer's base address to get actual register address
TCR	equ	4
MCR	equ	0x14
MR0	equ	0x18

STACKSIZE equ 1024

TimerCommandReset	equ	2
TimerCommandRun	equ	1
TimerModeResetAndInterrupt	equ	3
TimerResetTimer0Interrupt	equ	1
TimerResetAllInterrupts	equ	0xFF

; VIC Stuff -- UM, Table 41
VIC	equ	0xFFFFF000		; VIC Base Address
IntEnable	equ	0x10
VectAddr	equ	0x30
VectAddr0	equ	0x100
VectCtrl0	equ	0x200

Timer0ChannelNumber	equ	4	; UM, Table 63
Timer0Mask	equ	1<<Timer0ChannelNumber	; UM, Table 63
IRQslot_en	equ	5		; UM, Table 58

IO1DIR	EQU	0xE0028018
IO1SET	EQU	0xE0028014
IO1CLR	EQU	0xE002801C
IO1PIN	EQU	0xE0028010

	AREA	InitialisationAndMain, CODE, READONLY
	IMPORT	main

; (c) Mike Brady, 2014–2016.

	EXPORT	start
start
; initialisation code

; Initialise the VIC
	ldr	r0,=VIC			; looking at you, VIC!

	ldr	r1,=irqhan
	str	r1,[r0,#VectAddr0] 	; associate our interrupt handler with Vectored Interrupt 0

	mov	r1,#Timer0ChannelNumber+(1<<IRQslot_en)
	str	r1,[r0,#VectCtrl0] 	; make Timer 0 interrupts the source of Vectored Interrupt 0

	mov	r1,#Timer0Mask
	str	r1,[r0,#IntEnable]	; enable Timer 0 interrupts to be recognised by the VIC

	mov	r1,#0
	str	r1,[r0,#VectAddr]   	; remove any pending interrupt (may not be needed)

; Initialise Timer 0
	ldr	r0,=T0			; looking at you, Timer 0!

	mov	r1,#TimerCommandReset
	str	r1,[r0,#TCR]

	mov	r1,#TimerResetAllInterrupts
	str	r1,[r0,#IR]

	ldr	r1,=(14745600/10)-1	 ; 5 ms = 1/200 second
	str	r1,[r0,#MR0]

	mov	r1,#TimerModeResetAndInterrupt
	str	r1,[r0,#MCR]

	mov	r1,#TimerCommandRun
	str	r1,[r0,#TCR]
	
	ldr	r1,=IO1DIR
	ldr	r2,=0x000f0000	;select P1.19--P1.16
	str	r2,[r1]		;make them outputs
	ldr	r1,=IO1SET
	str	r2,[r1]		;set them to turn the LEDs off
	ldr	r2,=IO1CLR
	
	ldr r5, =leftLight
	ldr r4, =stack0
	str r5, [r4, #56]
	str r5, [r4, #60]
	
	ldr r5, =rightLight
	ldr r4, =stack1
	str r5, [r4, #56]
	str r5, [r4, #60]
	

leftLight
	ldr	r1,=IO1DIR
	ldr	r2,=0x000f0000	;select P1.19--P1.16
	str	r2,[r1]		;make them outputs
	ldr	r1,=IO1SET
	str	r2,[r1]		;set them to turn the LEDs off
	ldr	r2,=IO1CLR
	ldr r3, =0x000C0000
	str	r3,[r1]		;set the bit -> turn off the right LED
	ldr	r3,=0x00030000	; start with P1.16.
	str	r3,[r2]	   	; clear the bit -> turn on the LED
	b leftLight
	
rightLight
	ldr	r1,=IO1DIR
	ldr	r2,=0x000f0000	;select P1.19--P1.16
	str	r2,[r1]		;make them outputs
	ldr	r1,=IO1SET
	str	r2,[r1]		;set them to turn the LEDs off
	ldr	r2,=IO1CLR
	ldr r3, =0x00030000
	str	r3,[r1]		;set the bit -> turn off the right LED
	ldr	r3,=0x000C0000	; start with P1.16.
	str	r3,[r2]	   	; clear the bit -> turn on the LED
	b rightLight

	

;from here, initialisation is finished, so it should be the main body of the main program
wloop	b	wloop  		; branch always
;main program execution will never drop below the statement above.

	AREA	InterruptStuff, CODE, READONLY
irqhan	sub	lr,lr,#4
	stmfd	sp!,{r0-r12, lr, pc}	; the lr will be restored to the pc
	
	;ldr r1, pc
	;sub r1, r1, #8
	;stmfd sp! {r1}
;this is the body of the interrupt handler

;here you'd put the unique part of your interrupt handler
;all the other stuff is "housekeeping" to save registers and acknowledge interrupts

	ldr r0, =lastThread
	ldr r1, [r0]
	cmp r1, #0
	bne stackThread1
stackThread0
	ldr r0, =stack0
	b manage
stackThread1
	ldr r0, =stack1
manage
	mov r6, #0
stackLoop
	cmp r6, #15
	beq endLoop
	ldmfd sp!, {r1}
	str r1, [r0]
	add r0, r0, #4
	add r6, r6, #1
	b stackLoop
endLoop

	ldr r0, =lastThread
	ldr r1, [r0]
	cmp r1, #0
	beq reloadThread1
reloadThread0
	ldr r0, =stack0
	b reload
reloadThread1
	ldr r0, =stack1
reload

	mov r6, #60
unstackLoop
	cmp r6, #0
	ble endUnstack
	ldr r1, [r0, r6]
	sub r6, r6, #4
	stmfd sp!, {r1}
	b unstackLoop
endUnstack
	
	ldr r0, =lastThread
	ldr r1, [r0]
	cmp r1, #0
	beq toOne
	ldr r2, =0
	b skip
toOne
	ldr r2, =1
skip
	str r2, [r0]

;this is where we stop the timer from making the interrupt request to the VIC
;i.e. we 'acknowledge' the interrupt
	ldr	r0,=T0
	mov	r1,#TimerResetTimer0Interrupt
	str	r1,[r0,#IR]	   	; remove MR0 interrupt request from timer

;here we stop the VIC from making the interrupt request to the CPU:
	ldr	r0,=VIC
	mov	r1,#0
	str	r1,[r0,#VectAddr]	; reset VIC

	ldmfd	sp!,{r0-r12,lr, pc}^	; return from interrupt, restoring pc from lr
				; and also restoring the CPSR

	AREA	Subroutines, CODE, READONLY

	AREA	Stuff, DATA, READWRITE
stack0 SPACE STACKSIZE
stack1 SPACE STACKSIZE
lastThread DCB 0x00


	END