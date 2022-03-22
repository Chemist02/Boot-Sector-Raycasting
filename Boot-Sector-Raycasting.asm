; ------------- NOTES -------------
; - Position is multiplied by 128 (relative to map coordinates) so we can avoid floating point naughtiness. 
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
; Translational speed of player (again, remember that this is multiplied by 128 relative to our actual map).
TRANSL_SPD	equ 64
; Angular speed of player (in degrees per delayTicks); not multiplied by anything.
ANGULAR_SPD	equ 2
; Screen dimensions.
SCREEN_WIDTH	equ 80
SCREEN_HEIGHT	equ 25
HALF_SCN_HEIGHT equ 12
; Map width and height (both 16)
MAP_WIDNHEI	equ 16
; Render distance in grid cells times 128.
RENDER_DISTANCE	equ 16 * 128
; Field of view and field of view divided by two in degrees.
FOV		equ 90
HALF_FOV	equ 45
; Keyboard scan codes.
W_KEY		equ 0x11
S_KEY		equ 0x1F
LEFT_KEY	equ 0x4B
RIGHT_KEY	equ 0x4D
; Number of ticks to delay game by at the end of each game loop iteration.
DELAY_TICKS	equ 1

; ------------- STATIC DATA -------------
; Player position in our map (again, multiplied by 128).
xPos:		dw 896
yPos:		dw 768
; Player rotation in degrees.
rot:		dw 0
; Let 1024sin(x) be expressed as 1024sin(x) = mx + b (approx.), where m is slope and b is y intercept.
SIN_SLOPES:	dw 17, 16, 14, 10, 6, 2, 0
SIN_INTERCEPTS:	dw 0, 25, 91, 274, 526, 839, 1024
; Map encoded into 16 two byte numbers. Each number represents a column, where a 1 in the number is a wall. Most 
; significant bits represent the left most column of our map.
MAP:		dw 65535, 36865, 36929, 40897, 33281, 33281, 36927, 32801, 65057, 34833, 34817, 32769, 45695, 41489, 41473, 65535
WALL_CHARS:	db 0xDB, 0xB2, 0xB1, 0xB0, 0x00, 0x00

; ------------- FUNCTIONS -------------
if 0
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
end if

; Returns index in screen array given x and y coordinates (column, row) where column 
; number then row number are pushed onto the stack.
get1DScreenIndex:
	push bp 
	mov bp, sp

	push bx

	; index = row num * width + col num
	; bx is width, ax is row num
	mov bx, SCREEN_WIDTH
	mov ax, [bp + 4]
	mul bx
	add ax, [bp + 6]
	
	pop bx

	mov sp, bp
	pop bp
	ret

; Takes xpos first then ypos pushed onto stack (times 128), and returns greater than 1 if there's a wall, zero otherwise in ax.
isCoordWall:
	push bp
	mov bp, sp
	
	push bx
	push cx

	; Get column index as a mask.
	mov ax, 0x01
	mov cx, [bp + 6]
	shr cx, 7
	; Need to use cl for this, unfortunately. Man x86 is weird.
	shl ax, cl

	; Get row in map then and with column location mask.
	mov bx, MAP
	mov cx, [bp + 4]
	shr cx, 6
	;shl cx, 1
	add bx, cx
	and ax, [bx]
	
	pop cx
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

	; Find linear approximation of 1024sin(x).
	; We'll need our angle back later.
	push ax
	; Find which linear coefficients to use.
	shr ax, 3
	mov si, ax
	mov bx, [SIN_SLOPES + si]
	mov si, [SIN_INTERCEPTS + si]
	; Get angle back and find 1024(sin(ax))
	pop ax
	mul bx
	add ax, si

	; Divide ax by 2^3, to bring down to 128sin(x).
	shr ax, 3

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
	neg si

	doNotNegateSin:
	; Move final answer into position.
	mov ax, si

	pop si
	pop dx
	pop bx

	mov sp, bp
	pop bp
	ret

; ------------- START GAME -------------
start:
	; Set text mode, 80x25 chars, 16 color VGA.
	mov ax, 0x03
	int 0x10

	; Set extra segment base address to be base address for 16 color text VGA video memory.
	; We must go through ax since we can't alter es immediately.
	mov ax, VMEM_PTR
	mov es, ax

; ------------- GAME LOOP -------------
gameLoop:
	; Clear out video memory with black (xor uses fewest bytes to zero a register).
	xor ax, ax
	xor di, di
	; Screen is 80 x 25 characters.
	mov cx, 80 * 25
	; Repeatedly black out characters indexed with di for all characters in video memory (i.e. es:di).
	rep stosw

	; Handle player input and adjust position/angle.
	; Check if any button was pressed.
	mov ah, 1
	int 0x16
	jz endInput

	; If so, find out what it was.
	cbw
	int 0x16
	
	cmp ah, W_KEY
	je moveForward
	cmp ah, LEFT_KEY
	je angleLeft
	cmp ah, RIGHT_KEY
	je angleRight

	moveForward:
	jmp endInput

	angleLeft:
	mov ax, [rot]
	add ax, -1 * ANGULAR_SPD
	jmp angle

	angleRight:
	mov ax, [rot]
	add ax, ANGULAR_SPD
	angle:
	mov [rot], ax
		
	endInput:

	; Loop through columns and for each, cast ray, get distance, and draw wall at relavent scale/position.
	; Current column.
	xor cx, cx
	columnsLoop:
		; Local variables.
		; bp - 0 --> distance until wall.
		; DELbp - 2 --> current x pos to check times 128.
		; DELbp - 4 --> current y pos to check times 128.
		; bp - 6 --> change in x position to check per iteration times 128.
		; bp - 8 --> change in y position to check per iteration times 128.
		; bp - 10 --> vertical distance to ceiling (in terms of screen rows).
		; bp - 12 --> vertical distance to floor (in terms of screen rows).
		; bp - 14 --> initial value of cx this iteration.
		add sp, -16

		; Find angle to cast ray at.
		mov bx, [rot]	
		sub bx, HALF_FOV
		mov ax, FOV * 100
		mul cx
		mov si, SCREEN_WIDTH * 100
		div si
		add ax, bx
		; ax now contains angle to cast ray at.
		; Player angle is always greater than or equal to 0, so the least possible angle here is -45, so we can make
		; positive just by adding 360.
		mov bx, 360
		add ax, bx

		push ax
		call sin
		add sp, 2
		; ax now contains normalized y-component of change in position per iteration times 128.
		mov [bp - 8], ax

		; Becuase sin and cos are complementary, we can take this from 128.	
		mov bx, 128
		sub bx, ax
		; bx now contains normalized x-component of change in position per iteration times 128.
		mov [bp - 6], bx
		
		; Initialize raycast vars.	
		xor ax, ax
		mov [bp], ax
		mov ax, [xPos]
		push ax
		mov ax, [yPos]
		push ax
		rayMarchLoop:
			; Check if we're at a wall.
			call isCoordWall
			test ax, ax
			; If ax is non-zero, we're at a wall, so end.
			jnz endRayMarch

			; Check if we traveled too far.
			mov ax, [bp]
			mov bx, RENDER_DISTANCE
			cmp ax, bx
			jg endRayMarch

			; Increment, if we got this far.
			add ax, 128
			mov [bp], ax
			pop ax
			add ax, [bp - 8]
			pop bx
			add bx, [bp - 6]
			push bx
			push ax
		jmp rayMarchLoop
		endRayMarch:
		; Clean up stack.
		add sp, 4
		
		; Now that we have our distance, we can actually draw the mother flippin wall.
		; Find distance to ceiling from the top of the screen. Please bear in mind that the diatnce we just
		; found is currently multiplied by 128.
		; Multiply by 128 so we can get back to rows.
		xor dx, dx
		mov ax, SCREEN_HEIGHT * 128
		mov bx, [bp]
		div bx
		mov bx, HALF_SCN_HEIGHT
		sub bx, ax
		mov [bp - 10], bx
		mov ax, SCREEN_HEIGHT
		sub ax, bx
		mov [bp - 12], ax

		; Loop through rows and actually draw.
		mov [bp - 14], cx
		xor cx, cx
		rowsLoop:
			; Find location in screen buffer to draw to.
			mov ax, [bp - 14]
			push ax
			push cx
			call get1DScreenIndex
			add sp, 4
			shl ax, 1
			mov di, ax
		
			; See if cx is greater than ceiling height (below ceiling). 
			mov ax, [bp - 10]
			cmp cx, ax
			jg notCeiling

			; Draw ceiling.
			mov ax, 0x08DB
			jmp draw	

			notCeiling:
			; See if cx is a floor height.
			mov ax, [bp - 12]
			cmp cx, ax
			jg notWall

			; Draw Wall.
			; mov ax, 0x0ADB
			; jmp draw

			mov si, [bp]
			shr si, 9
			mov al, [WALL_CHARS + si]
			;shr ax, 8
			or ax, 0x0A00
			jmp draw

			notWall:

			; Draw floor.
			mov ax, 0x02DB

			draw:
			mov [es:di], ax

			inc cx
		mov ax, SCREEN_HEIGHT
		cmp cx, ax
		jl rowsLoop	
		; Recover counter.
		mov cx, [bp - 14]
		add sp, 16	
		inc cx
	mov ax, SCREEN_WIDTH
	cmp cx, ax	
	jl columnsLoop
	; End of columns loop.

	; Apply delay to slow game speed (i.e. arcsonic).
	mov ax, [TICK_COUNTER]
	add ax, [DELAY_TICKS]
	delayLoop:
		cmp [TICK_COUNTER], ax
	jl delayLoop	
jmp gameLoop

; ------------- FINISH -------------
; Write boot sector signature on last two bytes.
times 510-($-$$) db 0x00
	db 0x55
	db 0xAA
