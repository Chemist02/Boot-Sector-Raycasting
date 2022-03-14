; ------------- NOTES -------------
; - Position is multiplied by 100 (relative to map coordinates) so we can avoid floating point naughtiness. 
; - Therefore, so are sin values and speed. Angles are in plain old degrees (not scaled).
; - Function calls preserve all registers, arguments pushed onto stack before call.
; - Returns happen in ax register.

; ------------- INITIAL SETUP -------------
; Use 16 bit opcodes.
use16

; Load program into memory at address 0x7C00, to act in place of a bootloader.
org 0x7C00

; Jump to game setup.
jmp start

; ------------- CONSTANTS -------------
; This is a handy flat assembler thing.
; Pointer to base of video memory for color text VGA mode.
VMEM_PTR	equ 0xB800
; Pointer to number of ticks recorded by BIOS since boot.
TICK_COUNTER	equ 0x046C
; Translational speed of player (again, remember that this is multiplied by 100 relative to our actual map).
TRANSL_SPD	equ 50
; Angular speed of player (in degrees per delayTicks); not multiplied by anything.
ANGULAR_SPD		equ 1
; Screen dimensions.
SCREEN_WIDTH	equ 80
SCREEN_HEIGHT	equ 25

; ------------- STATIC DATA -------------
; Number of ticks to delay game by at the end of each game loop iteration.
delayTicks:	dw 2
; Player position in our map (again, multiplied by 100).
xPos:		dw 0
yPos:		dw 0
; Player rotation in degrees.
rot:		dw 0

; ------------- START GAME -------------
start:
	; Set text mode, 80x25 chars, 16 color VGA.
	mov ax, 0x03
	int 0x10

	; Set extra segment base address to be base address for 16 color text VGA video memory.
	; We must go through ax since we can't alter es immediately.
	mov ax, VMEM_PTR
	mov es, ax

	; Start the game loop.
	jmp gameLoop

; ------------- FUNCTIONS -------------
; Prints contents of ax register to top of screen in hexadecimal.
printWord:
	push ax
	push cx
	push dx
	push di
	; A word consists of 4 hex values.
	mov di, 0
	mov cx, 4
	mov dx, ax
	printWordLoop:
		mov ax, dx
		and ax, 0x000F
		add ax, 0x0030
		or ax, 0x0F00
		mov [es:di], ax
		add di, 2
		shr dx, 4
	loop printWordLoop
	pop di
	pop dx
	pop cx
	pop ax
	ret


; ------------- GAME LOOP -------------
gameLoop:
	; Clear out video memory with black (xor uses fewest bytes to zero a register).
	xor ax, ax
	xor di, di
	; Screen is 80 x 25 characters.
	mov cx, 80 * 25
	; Repeatedly black out characters indexed with di for all characters in video memory (i.e. es:di).
	rep stosw
	
	;xor di, di
	mov ax, 0x0F42
	call printWord
	;mov [es:di], ax
	;stosw

	; Apply delay to slow game speed (i.e. arcsonic).
	mov ax, [TICK_COUNTER]
	add ax, [delayTicks]
	delayLoop:
		cmp [TICK_COUNTER], ax
	jl delayLoop	
jmp gameLoop

; ------------- FINISH -------------
; Write boot sector signature on last two bytes.
times 510-($-$$) db 0x00
	db 0x55
	db 0xAA
