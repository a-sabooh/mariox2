; =====================================================================
; mario.asm - Super Mario Engine - PERSON 1 (platform and rendering)
; Build (real game, with Person 2's logic.asm):
;       nasm mario.asm -o mario.com
; Build (test alone with the stub that replaces Person 2's code):
;       nasm mario.asm -o mario.com -dUSE_STUB
; Run in DOSBox:  mario.com   (or  afd mario.com;  set cycles=max in the DOSBox config)
;
; File order inside this program:
;       jmp start, constants, shared.inc (data), level data, artwork,
;       Person 1 variables, drawing procedures, Person 2 code,
;       interrupt handlers, start, main loop, exit.
; Program needs an 80186 or newer (push immediate, shift by a constant).
;
; Frame buffer (memory choice for the README):
;   A .COM program owns a whole 64 KB segment.  DOS gives a .COM program
;   all free memory, so the NEXT 64 KB segment (CS + 1000h) is free.
;   The 64000 byte frame buffer lives there.  At start the program checks
;   the top of memory (word at PSP:0002) and stops with a message if the
;   buffer would not fit.
; =====================================================================

[org 0x0100]
                jmp start                       ; skip over data and procedures

; ---------- Person 1 constants ----------
COL_BLACK       equ 0                           ; palette colour numbers (see palette_data)
COL_SKY         equ 1
COL_RED         equ 2
COL_WHITE       equ 5
COL_YELLOW      equ 6
COL_GREEN       equ 7
COL_ORANGE      equ 8
COL_BRICK       equ 12
COL_GRAY        equ 15
PAL_COUNT       equ 19                          ; number of colours we set
LEGEND_LEN      equ 19                          ; characters in sprite_legend
PIT_DIVISOR     equ 39773                       ; 1193182 / 30 = about 30 ticks per second
TILE_FLAG_TOP   equ 13                          ; internal tile: top of the flag pole
TILE_COUNT      equ 14                          ; entries in tile_table
CASTLE_X        equ 928                         ; world x of the castle (columns 58 and 59)

; ---------- Shared data (both people) and level data ----------
%include "shared.inc"
%include "level.inc"
%include "sprdata.inc"

; ---------- Person 1 variables ----------
fb_seg          dw 0                            ; segment of the off-screen frame buffer
font_seg        dw 0                            ; segment of the BIOS 8x8 font table
font_off        dw 0                            ; offset of the BIOS 8x8 font table
old_kbd         dd 0                            ; saved INT 09h vector (offset, segment)
old_timer       dd 0                            ; saved INT 08h vector (offset, segment)
chain_acc       dw 0                            ; adds up PIT_DIVISOR; a carry means "call the old timer"
dm_first        dw 0                            ; DrawMap: first visible map column
dm_xoff         dw 0                            ; DrawMap: pixel offset of that column (camera mod 16)
spr_temp        times 256 db 0                  ; DrawSprite: mirrored copy of a sprite
msg_nomem       db 'Not enough free memory for the frame buffer.', 13, 10, '$'

; ---------- Drawing procedures ----------
%include "video.asm"
%include "sprites.asm"
%include "tiles.asm"
%include "text.asm"
%include "gamedraw.asm"
%include "screens.asm"

; ---------- Person 2's code (or the stub for solo testing) ----------
%ifdef USE_STUB
%include "stub.asm"
%else
%include "logic.asm"
%endif

; =====================================================================
; kbd_isr - our INT 09h keyboard handler
; Purpose : keeps key_state (1 = held) and key_pressed (1 = went down
;           since the last frame, no auto-repeat) for every scan code.
; Notes   : the E0h prefix byte of the arrow keys is ignored, the code
;           that follows is processed.  Bit 7 of a scan code = release.
;           Uses CS: for all data, so DS does not matter.
; Registers: all preserved.
; =====================================================================
kbd_isr:
                push ax
                push bx
                in al, 0x60                     ; read the scan code from the keyboard port
                cmp al, 0xE0                    ; extended key prefix?
                je kb_done                      ; yes - ignore it
                cmp al, 0xE1                    ; pause key prefix?
                je kb_done
                mov bl, al
                and bl, 0x7F                    ; remove the release bit
                mov bh, 0                       ; bx = scan code
                test al, 0x80                   ; bit 7 set = key released
                jnz kb_release
                cmp byte [cs:bx+key_state], 1   ; already down? then it is auto-repeat
                je kb_done
                mov byte [cs:bx+key_state], 1   ; key is held
                mov byte [cs:bx+key_pressed], 1 ; key just went down
                jmp kb_done
kb_release:     mov byte [cs:bx+key_state], 0
kb_done:        mov al, 0x20                    ; end of interrupt to the interrupt controller
                out 0x20, al
                pop bx
                pop ax
                iret

; =====================================================================
; timer_isr - our INT 08h timer handler (30 ticks per second)
; Purpose : counts ticks in tick_count.  The old BIOS timer handler must
;           still run 18.2 times per second to keep the DOS clock right,
;           so chain_acc adds up PIT_DIVISOR; when it overflows we jump
;           to the old handler (which sends the EOI itself).
; Registers: all preserved.
; =====================================================================
timer_isr:
                inc word [cs:tick_count]        ; one more game tick
                add word [cs:chain_acc], PIT_DIVISOR
                jc tm_chain                     ; overflow: time for the old handler
                push ax
                mov al, 0x20                    ; end of interrupt
                out 0x20, al
                pop ax
                iret
tm_chain:       jmp far [cs:old_timer]          ; old handler ends with IRET for us

; =====================================================================
; InstallKeyboard / RemoveKeyboard - hook and unhook INT 09h
; Registers: all preserved.
; =====================================================================
InstallKeyboard:
                push ax
                push bx
                push dx
                push es
                mov ax, 0x3509                  ; DOS: get interrupt vector 09h
                int 0x21
                mov [old_kbd], bx               ; save offset
                mov [old_kbd+2], es             ; save segment
                mov dx, kbd_isr                 ; DS:DX = our handler
                mov ax, 0x2509                  ; DOS: set interrupt vector 09h
                int 0x21
                pop es
                pop dx
                pop bx
                pop ax
                ret

RemoveKeyboard:
                push ax
                push dx
                push ds
                mov dx, [old_kbd]               ; offset of the old handler
                mov ds, [old_kbd+2]             ; segment of the old handler
                mov ax, 0x2509                  ; DOS: set interrupt vector 09h
                int 0x21
                pop ds
                pop dx
                pop ax
                ret

; =====================================================================
; InstallTimer / RemoveTimer - hook INT 08h and program the PIT
; InstallTimer sets the timer to about 30 ticks per second.
; RemoveTimer puts back the divisor 0 (= 65536, 18.2 ticks per second)
; and the old vector.
; Registers: all preserved.
; =====================================================================
InstallTimer:
                push ax
                push bx
                push dx
                push es
                mov ax, 0x3508                  ; DOS: get interrupt vector 08h
                int 0x21
                mov [old_timer], bx
                mov [old_timer+2], es
                mov dx, timer_isr
                mov ax, 0x2508                  ; DOS: set interrupt vector 08h
                int 0x21
                cli                             ; change the timer rate without interruption
                mov al, 0x36                    ; channel 0, low+high byte, mode 3
                out 0x43, al
                mov ax, PIT_DIVISOR
                out 0x40, al                    ; low byte of the divisor
                mov al, ah
                out 0x40, al                    ; high byte of the divisor
                sti
                pop es
                pop dx
                pop bx
                pop ax
                ret

RemoveTimer:
                push ax
                push dx
                push ds
                cli
                mov al, 0x36
                out 0x43, al
                mov al, 0                       ; divisor 0 means 65536 = the original rate
                out 0x40, al
                out 0x40, al
                sti
                mov dx, [old_timer]
                mov ds, [old_timer+2]
                mov ax, 0x2508
                int 0x21
                pop ds
                pop dx
                pop ax
                ret

; =====================================================================
; ClearKeyPressed
; Purpose : sets key_pressed (128 bytes) back to 0 after GameUpdate.
; Registers: all preserved.
; =====================================================================
ClearKeyPressed:
                push ax
                push cx
                push di
                push es
                push ds
                pop es                          ; ES = DS
                mov di, key_pressed
                mov cx, 64                      ; 64 words = 128 bytes
                mov ax, 0
                cld
                rep stosw
                pop es
                pop di
                pop cx
                pop ax
                ret

; =====================================================================
; start - program entry
; =====================================================================
start:
                mov ax, cs
                add ax, 0x1000                  ; the segment after our own 64 KB
                mov [fb_seg], ax
                add ax, 0x0FA0                  ; + 64000 bytes in paragraphs
                cmp ax, [0x0002]                ; PSP:0002 = first segment we may NOT use
                ja no_memory

                call InitFont                   ; BIOS font pointer (must be asked in text mode)
                call BuildSprites               ; turn the art characters into colour numbers
                call SetVideoMode13
                call SetPalette
%ifdef USE_STUB
                call StubInit
%endif
                call InstallKeyboard
                call InstallTimer

; ---------------------------------------------------------------------
; Main loop: wait for tick, GameUpdate, draw, copy to the screen
; ---------------------------------------------------------------------
main_loop:
                mov ax, [tick_count]            ; remember the tick we are in
wait_tick:      cmp ax, [tick_count]            ; wait until the timer moves on
                je wait_tick
                call GameUpdate                 ; Person 2: one frame of game logic
                call ClearKeyPressed            ; "went down" flags are valid for one frame only
                cmp byte [game_state], STATE_EXIT
                je exit_game
                call RenderFrame                ; draw everything into the frame buffer
                call CopyFrame                  ; one block move to video memory
                jmp main_loop

; ---------------------------------------------------------------------
; Clean exit: timer, keyboard, text mode, DOS
; ---------------------------------------------------------------------
exit_game:
                call RemoveTimer
                call RemoveKeyboard
                call SetTextMode
                mov ax, 0x4C00                  ; DOS: terminate, return code 0
                int 0x21

no_memory:
                mov dx, msg_nomem
                mov ah, 0x09                    ; DOS: print a $ terminated string
                int 0x21
                mov ax, 0x4C01                  ; DOS: terminate, return code 1
                int 0x21
