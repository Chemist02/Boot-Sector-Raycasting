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
ANGULAR_SPD	equ 1
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
; Let 1000sin(x) be expressed as 1000sin(x) = mx + b (approx.), where m is slope and b is y intercept.
SIN_SLOPES:	dw 17, 16, 13, 10, 6, 2, 0
SIN_INTERCEPTS:	dw 0, 18, 109, 257, 506, 815, 1000

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
	push bp 
	mov bp, sp

	push ax
	push cx
	push dx
	push di
	; A word consists of 4 hex values.
	xor di, di
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

	mov sp, bp
	pop bp
	ret

; Returns index in board/screen array given x and y coordinates (column, row) and width of array, where column 
; number, then row number, then width are pushed onto the stack.
get2DArrayIndex:
	push bp 
	mov bp, sp

	push bx

	; index = row num * width + col num
	; bx is width, ax is row num
	mov bx, [bp + 4]
	mov ax, [bp + 6]
	mul bx
	add ax, [bp + 8]
	
	pop bx

	mov sp, bp
	pop bp
	ret

; Returns sin(x) multiplied by 100 in ax, where x is the top most member of the stack and must be positive.
sin:
	push bp
	mov bp, sp
	
	push bx
	push dx
	push si

	; Get angle from stack.
	mov ax, [bp + 4]
	
	; Get angle mod 180.
	xor dx, dx
	mov bx, 180
	div bx
	; Remainder (normalized angle) is now in dx.

	; Ensure angle is between 0 and 90
	mov bx, 90
	cmp dx, bx
	; If angle is less than 90, we're good.
	jl dontMakeLessThan90
	; Otherwise, subtract it from 180.
	mov ax, 180
	sub ax, dx
	mov dx, ax
	; ax now contains our value for x, between 0 and 90.
	dontMakeLessThan90:
	mov ax, dx

	; Find linear approximation of 1000sin(x).
	; We'll need our angle back later.
	push ax
	; Find which linear coefficients to use.
	xor dx, dx
	mov bx, 15
	div bx
	shl ax, 1
	mov si, ax
	mov bx, [SIN_SLOPES + si]
	mov si, [SIN_INTERCEPTS + si]
	; Get angle back and find 1000(sin(ax))
	pop ax
	mul bx
	add ax, si

	; Divide ax by 10.
	mov bx, 10
	div bx

	; Determine if we need to negate and if so, do it.
	xor dx, dx
	mov si, ax
	mov ax, [bp + 4]
	mov bx, 360
	div bx
	; If normalized angle is greater than or equal to 180, negate.
	shr bx, 1
	cmp dx, bx
	jl doNotNegateSin
	; Negate (2s complement).
	not si
	inc si

	doNotNegateSin:
	; Move final answer into position.
	mov ax, si

	pop si
	pop dx
	pop bx

	mov sp, bp
	pop bp
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
