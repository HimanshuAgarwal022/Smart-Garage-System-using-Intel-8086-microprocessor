#make_bin#

#LOAD_SEGMENT=FFFFh#
#LOAD_OFFSET=0000h#

#CS=0000h#
#IP=0000h#

#DS=0000h#
#ES=0000h#

#SS=0000h#
#SP=0FFFEh#

#AX=0000h#
#BX=0000h#
#CX=0000h#
#DX=0000h#
#SI=0000h#
#DI=0000h#
#BP=0000h#



vars:
strlen db 0
empty db '0'
full db '2000'
count dw 0


ports:
inputs equ 02h
lcd_data equ 00h
lcd_motor_control equ 04h
creg_io equ 06h

porta2 equ 10h
portb2 equ 12h
creg2 equ 16h

timer_clock equ 08h
timer_remote equ 0Ah
timer_door equ 0Ch
creg_timer equ 0Eh

jmp     st1
db     1024 dup(0)
st1:

init_of_RAM:
mov ax,0200h
mov ds,ax
mov es,ax
mov ss,ax
mov sp,0FFFEH

mov al,10000000b
out creg_io,al

mov al, 00110100b
out creg_timer, al
mov al, 0A8h
out timer_clock, al
mov al, 61h
out timer_clock, al



startup:
LCD_init
call display_on_LCD

garage_is_closed:
in al, inputs
and al, 00000001b
cmp al, 1
je open_the_garage_door
jmp garage_is_closed

garage_to_open:
mov ah, 0                   ; resetting the value in car_flag to 0
in al, inputs
mov bl, al
and bl, 00000001b
cmp bl, 00000001b           ; checking for any remote press
je close_the_garage_door
mov bl, al
and bl, 00010000b
cmp bl, 00010000b           ; checking for, if the  timer is out (300 seconds ie 5 minutes)
je close_the_garage_door
mov bl, al
and bl, 00000010b
cmp bl, 00000010b           ; checking whether the outer IR is triggered
je entering
mov bl, al
and bl, 00001000b
cmp bl, 00001000b           ; checking whether the inner IR is triggerd
je exiting
jmp garage_to_open

close_the_garage_door:
motor_clockwise
start_door_timer
garage_door_is_still_closing:
in al, inputs
and al, 00100000b
cmp al, 00100000b       ; waiting until the door is closing completely
jne garage_door_is_still_closing

stopping_the_motor
jmp garage_is_closed

open_the_garage_door:
start_remote_timer
motor_anticlockwise
start_door_timer
the_door_is_still_open:
in al, inputs
and al, 00100000b
cmp al, 00100000b       ; waiting until the door is opening completely
jne the_door_is_still_open

stopping_the_motor
jmp garage_to_open

entering:
in al, inputs
mov bl, al
and bl, 00000001b
cmp bl, 00000001b           ; checking for remote press
je close_the_garage_door


mov bl, al
and bl, 00010000b
cmp bl, 00010000b           ; checking for timer to finish its 5 minutes timeout
je close_the_garage_door


mov bl, al
and bl, 00000100b
cmp bl, 00000100b           ; checking if the object is a car or not
jne nc00

mov ah, 1
nc00:
mov bl, al
and bl, 00001000b
cmp bl, 00001000b       ; checkin for the triggering of inner IR
jne entering
cmp ah, 1


jne nc01
inc count
call display_on_LCD


nc01:
in al, inputs
mov bl, al
and bl, 00001000b
cmp bl, 00001000b 			; debounce delay
je nc01
jmp garage_to_open

exiting:
in al, inputs
mov bl, al
and bl, 00000001b
cmp bl, 00000001b           ; checking for the remote press
je close_the_garage_door
mov bl, al
and bl, 00010000b
cmp bl, 00010000b           ; checking for the timer for 5 minutes timeout
je close_the_garage_door
mov bl, al
and bl, 00000100b
cmp bl, 00000100b           ; checking if the object is a car or not
jne nc10
mov ah, 1
nc10:
mov bl, al
and bl, 00000010b
cmp bl, 00000010b       ; checking if the outer IP is triggered or not
jne exiting
cmp ah, 1
jne nc11
dec count
call display_on_LCD
nc11:
in al, inputs
mov bl, al
and bl, 00000010b
cmp bl, 00000010b 				; debounce_delay
je nc11
jmp garage_to_open

macros:
motor_anticlockwise macro
in al, lcd_motor_control
and al, 11111100b
or al, 00000010b
out lcd_motor_control, al
endm

motor_clockwise macro
in al, lcd_motor_control
and al, 11111100b
or al, 00000001b
out lcd_motor_control, al
endm

stopping_the_motor macro
in al, lcd_motor_control
and al, 11111100b
or al, 00000000b
out lcd_motor_control, al
endm

start_remote_timer macro
mov al, 01110000b
out creg_timer, al
mov al, 30h
out timer_remote, al
mov al, 75h
out timer_remote, al
endm

start_door_timer macro
		mov al, 10110000b
 		out creg_timer, al
		mov al, 0F4h
		out timer_door, al
		mov al, 01h
		out timer_door, al
endm

set_the_LCD_mode macro
		in al, lcd_motor_control
		and al, 00011111b
		or al, bl
		out lcd_motor_control, al
endm

LCD_init macro
		mov al, 00001111b
		out lcd_data, al
		mov bl, 00100000b
set_the_LCD_mode
		mov bl, 00000000b
set_the_LCD_mode
endm

lcd_clear macro
		mov al, 00000001b
out lcd_data, al
		mov bl,00100000b
set_the_LCD_mode
		mov bl,00000000b
set_the_LCD_mode
endm

lcd_putch macro
		push ax
		out lcd_data,al
		mov bl,10100000b
set_the_LCD_mode
		mov bl,10000000b
set_the_LCD_mode
		pop ax
		endm

putstring_on_LCD macro
		mov ch,0
		mov cl, strlen
putting:
		mov al, [di]
lcd_putch
		inc di
		loop putting
endm

lcd_bcd macro
		mov ax, count
		mov cx, 0
converting:
		mov bl, 10
		div bl
		add ah, '0'
		mov bl, ah
		mov bh, 0
		push bx
		inc cx
		mov ah, 0
		cmp ax, 0
jne converting
printing:
pop ax
lcd_putch
loop printing
endm

procs:
		display_on_LCD proc near
		lcd_clear
		mov al, ' '
		lcd_putch
		cmp count, 0
		jnz notempty
		lea di, empty
		mov strlen, 1

		;set empty led and reset not empty

		mov al, 00000001b
		out creg2 , al

		mov al, 00000010b
		out creg2 , al
		jmp loaded

		notempty:
		cmp count, 2000d
		jl notfull
		lea di, full
		mov strlen, 4
		
		;set full led and reset empty

		mov al, 00000000b
			out creg2 , al

		mov al, 00000011b
			out creg2 , al

		jmp loaded
		notfull:

		;reset both leds
		
		mov al, 00000000b
			out creg2 , al

		mov al, 00000010b
			out creg2 , al

		lcd_bcd
		ret
		loaded:
		putstring_on_LCD
		ret
		display_on_LCD endp




;file is ended here. copy all the above content from "copy the code from here"
