; References:
; https://en.wikipedia.org/wiki/BIOS_interrupt_call
; www.columbia.edu/~em36/wpdos/videomodes.txt
; https://www.fountainware.com/EXPL/vga_color_palettes.htm
; https://www.freepascal.org/docs-html/current/rtl/keyboard/kbdscancode.html

BITS 16

; Video Constants
%define WIDTH           		 (320)    ; 320 cols
%define HEIGHT          		 (200)    ; 200 rows
%define VIDEO_BUFFER    		 (0xA000) ; Pixel Data Segment
%define PREFERED_VIDOE_MODE      (0x13)
%define SET_VIDEO_MODE_FUNC_IDX  (0x00)
%define VIDEO_SERVICES_INTERRUPT (0x10)

; Game Constants
%define SNAKE_X_BUFFER  		 (0x1000)
%define SNAKE_Y_BUFFER  		 (0x2000)
%define SNAKE_LEFT_BIT			 (0b1000)
%define SNAKE_RIGHT_BIT 		 (0b0100)
%define SNAKE_UP_BIT			 (0b0010)
%define SNAKE_DOWN_BIT 		     (0b0001)

; Timing Constants
%define IRQ0_TIMER_ADDR 		 (0x046C)

; Boot Sector Constants
%define BOOT_SECTOR_MAGIC        (0xAA55)
%define BOOT_SECTOR_SIZE		 (0x0200)
%define BOOT_SECTOR_LOAD_ADDRESS (0x7C00)

; Colors
%define BACKGROUND_COLOR         (0x00)
%define SNAKE_COLOR 			 (0x02)
%define APPLE_COLOR 			 (0x04)

; Key Constants
%define KEYBOARD_SERVICES_INTERRUPT         (0x16)
%define KEYBOARD_READ_CHARACTER_FUNC_IDX    (0x00)
%define KEYBOARD_READ_INPUT_STATUS_FUNC_IDX (0x01)
%define KEY_LEFT_SCAN_CODE		    		(0x4B)
%define KEY_RIGHT_SCAN_CODE         		(0x4D)
%define KEY_UP_SCAN_CODE		    		(0x48)
%define KEY_DOWN_SCAN_CODE 		    		(0x50)


start:
.init_vga:
	; Set Video Mode
	MOV AX, ((SET_VIDEO_MODE_FUNC_IDX << 8) | PREFERED_VIDOE_MODE)
	INT VIDEO_SERVICES_INTERRUPT

	; Save the segment of the video buffer
	MOV AX, VIDEO_BUFFER
	MOV ES, AX

.init_snake:
	MOV WORD[SNAKE_X_BUFFER],   5 ; Head X
	MOV WORD[SNAKE_Y_BUFFER],   6 ; Head Y
	MOV WORD[SNAKE_X_BUFFER+2], 4 ; Tail X
	MOV WORD[SNAKE_Y_BUFFER+2], 6 ; Tail Y
	MOV WORD[SNAKE_X_BUFFER+4], 3 ; Tail X
	MOV WORD[SNAKE_Y_BUFFER+4], 6 ; Tail Y

.game_loop:
	; Clear the screen buffer
	MOV AL, BACKGROUND_COLOR  ; Background Color
	XOR DI, DI	     	      ; Base Index Start: 0
	MOV CX, WIDTH*HEIGHT      ; Base Index End:   Whole Screen
	REP STOSB 	    	 	  ; 

.draw_snake:
	XOR BX, BX ; Loop Index
	.draw_snake_loop:
		SHL  BX, 1 ; Multiply the Loop Index by 2 because we are indexing words
		IMUL AX, WORD[SNAKE_Y_BUFFER+BX], WIDTH ; AX=y*width
		ADD  AX, WORD[SNAKE_X_BUFFER+BX]		; AX=y*width+x
		MOV  DI, AX								; Offset into video memory
		SHR  BX, 1 ; Restore the Loop Index

		MOV BYTE[ES:DI], SNAKE_COLOR

		INC BX
		CMP BX, WORD[BOOT_SECTOR_LOAD_ADDRESS+snake_len]
		JNE .draw_snake_loop

.draw_apple:
	IMUL AX, WORD[BOOT_SECTOR_LOAD_ADDRESS+apple_y], WIDTH
	ADD  AX, WORD[BOOT_SECTOR_LOAD_ADDRESS+apple_x]
	MOV  DI, AX

	MOV BYTE[ES:DI], APPLE_COLOR

.move_snake:
	.move_body:
		MOV BX, WORD[BOOT_SECTOR_LOAD_ADDRESS+snake_len]
		DEC BX
		
		.move_body_loop:
			SHL BX, 1 ; Multiply the Loop Index by 2 because we are indexing words
			MOV AX, WORD[SNAKE_X_BUFFER-2+BX] ; X
			MOV WORD[SNAKE_X_BUFFER+BX], AX   ; X
			MOV AX, WORD[SNAKE_Y_BUFFER-2+BX] ; Y
			MOV WORD[SNAKE_Y_BUFFER+BX], AX   ; Y
			SHR BX, 1 ; Restore the Loop Index

			DEC BX
			CMP BX, 0
			JNE .move_body_loop

	.move_head:
		CMP  WORD[BOOT_SECTOR_LOAD_ADDRESS+snake_movement_flags], SNAKE_LEFT_BIT
		JE  .move_head_left
		CMP  WORD[BOOT_SECTOR_LOAD_ADDRESS+snake_movement_flags], SNAKE_RIGHT_BIT
		JE  .move_head_right
		CMP  WORD[BOOT_SECTOR_LOAD_ADDRESS+snake_movement_flags], SNAKE_UP_BIT
		JE  .move_head_up
		CMP  WORD[BOOT_SECTOR_LOAD_ADDRESS+snake_movement_flags], SNAKE_DOWN_BIT
		JE  .move_head_down
		JMP .input

		.move_head_left:
			DEC WORD[SNAKE_X_BUFFER]
			JMP .input
		.move_head_right:
			INC WORD[SNAKE_X_BUFFER]
			JMP .input
		.move_head_up:
			DEC WORD[SNAKE_Y_BUFFER]
			JMP .input
		.move_head_down:
			INC WORD[SNAKE_Y_BUFFER]
			JMP .input
.input:
	MOV AH, KEYBOARD_READ_INPUT_STATUS_FUNC_IDX
	INT KEYBOARD_SERVICES_INTERRUPT
	JZ  .collisions

	MOV AH, KEYBOARD_READ_CHARACTER_FUNC_IDX
	INT KEYBOARD_SERVICES_INTERRUPT

	CMP AH, KEY_LEFT_SCAN_CODE
	JE  .input_left
	CMP AH, KEY_RIGHT_SCAN_CODE
	JE  .input_right
	CMP AH, KEY_UP_SCAN_CODE
	JE  .input_up
	CMP AH, KEY_DOWN_SCAN_CODE
	JE  .input_down
	JMP .collisions
	.input_left:
		MOV WORD[BOOT_SECTOR_LOAD_ADDRESS+snake_movement_flags], (SNAKE_LEFT_BIT)
		JMP .collisions
	.input_right:
		MOV WORD[BOOT_SECTOR_LOAD_ADDRESS+snake_movement_flags], (SNAKE_RIGHT_BIT)
		JMP .collisions
	.input_up:
		MOV WORD[BOOT_SECTOR_LOAD_ADDRESS+snake_movement_flags], (SNAKE_UP_BIT)
		JMP .collisions
	.input_down:
		MOV WORD[BOOT_SECTOR_LOAD_ADDRESS+snake_movement_flags], (SNAKE_DOWN_BIT)
		JMP .collisions

.collisions:
	.collisions_apple:
		MOV AX, WORD[BOOT_SECTOR_LOAD_ADDRESS+apple_x]
		CMP AX, WORD[SNAKE_X_BUFFER]
		JNE .collisions_self
		MOV BX, WORD[BOOT_SECTOR_LOAD_ADDRESS+apple_y]
		CMP BX, WORD[SNAKE_Y_BUFFER]
		JNE .collisions_self

		.collisions_apple_handle: ; TODO: Random New Position
			MOV WORD[BOOT_SECTOR_LOAD_ADDRESS+apple_x], BX
			MOV WORD[BOOT_SECTOR_LOAD_ADDRESS+apple_y], AX
			INC WORD[BOOT_SECTOR_LOAD_ADDRESS+snake_len]

	.collisions_self:
		;TODO:::

	.collisions_border:
		; X-Left-Right Axis Intersection
		MOV AX, WORD[SNAKE_X_BUFFER]
		CMP AX, 0
		JL  .game_over
		CMP AX, WIDTH
		JGE .game_over

		; Y-Top-Bottom Axis Intersection
		MOV AX, WORD[SNAKE_Y_BUFFER]
		CMP AX, 0
		JL  .game_over
		CMP AX, HEIGHT
		JGE .game_over

.wait_next_frame:
	MOV AX, WORD[IRQ0_TIMER_ADDR]	
	ADD AX, 1
	
	.wait_next_frame_loop:
		CMP AX, WORD[IRQ0_TIMER_ADDR]	
		JG  .wait_next_frame_loop
	
	JMP .game_loop 

.game_over:
	HLT

; Variables (most of them could be single bytes but oh well)
snake_len: 			  dw 3
snake_movement_flags: dw SNAKE_RIGHT_BIT
apple_x:   			  dw 10
apple_y:   			  dw 20

; Configure the boot sector image
times BOOT_SECTOR_SIZE - 2 - ($-$$) db 0
dw 	  BOOT_SECTOR_MAGIC
