; =====================================================================
; video.asm - video mode, palette, PutPixel, FillRect, frame buffer
; All procedures take their inputs through the stack (pushed left to
; right, removed by RET n) and preserve every register.
; All drawing goes into the frame buffer (segment fb_seg), never
; straight to video memory.  CopyFrame sends it to the screen.
; =====================================================================

; ---------------------------------------------------------------------
; SetVideoMode13 / SetTextMode
; Purpose : switch to VGA 320x200x256 or back to 80x25 text mode.
; Inputs  : none      Outputs: none      Registers: all preserved
; ---------------------------------------------------------------------
SetVideoMode13:
                push ax
                mov ax, 0x0013                  ; BIOS: set video mode 13h
                int 0x10
                pop ax
                ret

SetTextMode:
                push ax
                mov ax, 0x0003                  ; BIOS: set video mode 03h (text)
                int 0x10
                pop ax
                ret

; ---------------------------------------------------------------------
; SetPalette
; Purpose : loads palette_data (PAL_COUNT colours, 6 bits per colour
;           part) into the VGA colour registers starting at colour 0.
; Inputs  : none      Outputs: none      Registers: all preserved
; ---------------------------------------------------------------------
SetPalette:
                push ax
                push cx
                push dx
                push si
                mov dx, 0x3C8                   ; palette write index port
                mov al, 0                       ; start at colour 0
                out dx, al
                mov dx, 0x3C9                   ; palette data port
                mov si, palette_data
                mov cx, PAL_COUNT * 3           ; red, green, blue for every colour
                cld
pal_loop:       lodsb
                out dx, al
                loop pal_loop
                pop si
                pop dx
                pop cx
                pop ax
                ret

; Palette: red, green, blue, each 0 to 63.  The order matches sprite_legend.
palette_data:
                db  0,  0,  0                   ; 0  .  black (transparent in sprites)
                db 23, 37, 63                   ; 1  S  sky
                db 54, 10,  0                   ; 2  R  red
                db 63, 47, 38                   ; 3  F  skin
                db 34, 17,  5                   ; 4  N  brown
                db 63, 63, 63                   ; 5  W  white
                db 63, 52,  0                   ; 6  Y  yellow
                db  0, 42,  0                   ; 7  G  green
                db 62, 38, 14                   ; 8  O  orange
                db 53, 40, 23                   ; 9  T  tan
                db  0, 26,  0                   ; 10 D  dark green
                db  0, 21, 62                   ; 11 B  blue
                db 49, 18,  4                   ; 12 C  brick
                db  5,  5,  5                   ; 13 K  dark outline
                db 35, 56, 10                   ; 14 L  light green
                db 42, 42, 42                   ; 15 A  gray
                db 46, 26,  7                   ; 16 E  dirt
                db 24, 12,  2                   ; 17 M  dark brown
                db 40, 12, 52                   ; 18 P  purple

; ---------------------------------------------------------------------
; PutPixel(x, y, colour)
; Purpose : one pixel into the frame buffer.  Offset = y*320 + x, done
;           with shifts: y*256 + y*64.  Pixels outside the screen are
;           ignored.
; Inputs  : [bp+8] = x, [bp+6] = y, [bp+4] = colour (low byte)
; Outputs : none      Registers: all preserved
; ---------------------------------------------------------------------
PutPixel:
                push bp
                mov bp, sp
                push ax
                push bx
                push di
                push es
                mov ax, [bp+8]                  ; x
                cmp ax, SCREEN_WIDTH
                jae pp_done                     ; unsigned compare also catches negative x
                mov bx, [bp+6]                  ; y
                cmp bx, SCREEN_HEIGHT
                jae pp_done
                mov di, bx
                shl di, 8                       ; y * 256
                shl bx, 6                       ; y * 64
                add di, bx                      ; y * 320
                add di, ax                      ; + x
                mov es, [fb_seg]
                mov al, [bp+4]
                mov [es:di], al
pp_done:        pop es
                pop di
                pop bx
                pop ax
                pop bp
                ret 6

; ---------------------------------------------------------------------
; FillRect(x, y, w, h, colour)
; Purpose : filled rectangle in the frame buffer, clipped to the screen
;           (no stray pixels, no memory damage).
; Inputs  : [bp+12] = x, [bp+10] = y, [bp+8] = width, [bp+6] = height,
;           [bp+4] = colour (low byte)
; Outputs : none      Registers: all preserved
; ---------------------------------------------------------------------
FillRect:
                push bp
                mov bp, sp
                push ax
                push bx
                push cx
                push dx
                push di
                push es
                mov ax, [bp+12]                 ; ax = left edge
                mov cx, [bp+8]
                add cx, ax                      ; cx = right edge (not included)
                cmp ax, 0
                jge fr_xok
                mov ax, 0                       ; clip the left edge
fr_xok:         cmp cx, SCREEN_WIDTH
                jle fr_x2ok
                mov cx, SCREEN_WIDTH            ; clip the right edge
fr_x2ok:        cmp cx, ax
                jle fr_done                     ; nothing visible
                sub cx, ax                      ; cx = visible width
                mov bx, [bp+10]                 ; bx = top edge
                mov dx, [bp+6]
                add dx, bx                      ; dx = bottom edge (not included)
                cmp bx, 0
                jge fr_yok
                mov bx, 0                       ; clip the top edge
fr_yok:         cmp dx, SCREEN_HEIGHT
                jle fr_y2ok
                mov dx, SCREEN_HEIGHT           ; clip the bottom edge
fr_y2ok:        cmp dx, bx
                jle fr_done
                sub dx, bx                      ; dx = visible height
                mov di, bx
                shl di, 8                       ; top * 256
                shl bx, 6                       ; top * 64
                add di, bx
                add di, ax                      ; di = top*320 + left
                mov es, [fb_seg]
                mov al, [bp+4]                  ; colour
                cld
fr_row:         push cx
                rep stosb                       ; one row of the rectangle
                pop cx
                add di, SCREEN_WIDTH
                sub di, cx                      ; down to the same column in the next row
                dec dx
                jnz fr_row
fr_done:        pop es
                pop di
                pop dx
                pop cx
                pop bx
                pop ax
                pop bp
                ret 10

; ---------------------------------------------------------------------
; ClearFrame(colour)
; Purpose : fills the whole frame buffer with one colour (REP STOSW).
; Inputs  : [bp+4] = colour (low byte)
; Outputs : none      Registers: all preserved
; ---------------------------------------------------------------------
ClearFrame:
                push bp
                mov bp, sp
                push ax
                push cx
                push di
                push es
                mov es, [fb_seg]
                mov di, 0
                mov al, [bp+4]
                mov ah, al                      ; two pixels per word
                mov cx, 32000                   ; 64000 bytes = 32000 words
                cld
                rep stosw
                pop es
                pop di
                pop cx
                pop ax
                pop bp
                ret 2

; ---------------------------------------------------------------------
; CopyFrame
; Purpose : copies the frame buffer to video memory (A000h) with one
;           block move (REP MOVSW).  Called once per timer tick.
; Inputs  : none      Outputs: none      Registers: all preserved
; ---------------------------------------------------------------------
CopyFrame:
                push ax
                push cx
                push si
                push di
                push ds
                push es
                mov ax, [fb_seg]                ; read it before DS changes
                mov ds, ax                      ; source = frame buffer
                mov ax, 0xA000
                mov es, ax                      ; destination = video memory
                mov si, 0
                mov di, 0
                mov cx, 32000
                cld
                rep movsw
                pop es
                pop ds
                pop di
                pop si
                pop cx
                pop ax
                ret
