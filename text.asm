; =====================================================================
; text.asm - letters, strings and numbers (display part of Module 13)
; The 8x8 letter shapes come from the BIOS (INT 10h, AX = 1130h returns
; a pointer to the 8x8 font table).  A glyph is 8 bytes, one per row,
; the highest bit is the left pixel.  Scale 1 draws 8x8 pixels, scale 2
; draws 16x16 and so on.
; =====================================================================

; ---------------------------------------------------------------------
; InitFont
; Purpose : asks the BIOS where its 8x8 font table is and saves it in
;           font_seg and font_off.  Call it before the first draw.
; Inputs  : none      Outputs: font_seg, font_off      Registers: all preserved
; ---------------------------------------------------------------------
InitFont:
                push ax
                push bx
                push cx
                push dx
                push bp
                push es
                mov ax, 0x1130                  ; BIOS: get font information
                mov bh, 3                       ; 8x8 ROM font, characters 0 to 127
                int 0x10                        ; returns ES:BP = table
                mov [font_seg], es
                mov [font_off], bp
                pop es
                pop bp
                pop dx
                pop cx
                pop bx
                pop ax
                ret

; ---------------------------------------------------------------------
; DrawGlyph(x, y, seg, off, colour, scale)
; Purpose : draws one 8x8 bit pattern (any 8 bytes in memory).
;           Scale 1 writes the pixels directly; a larger scale draws a
;           small filled square for every set bit (FillRect).
; Inputs  : [bp+14] = x, [bp+12] = y, [bp+10] = segment of the 8 bytes,
;           [bp+8] = offset of the 8 bytes, [bp+6] = colour,
;           [bp+4] = scale (1 or more)
; Outputs : none      Registers: all preserved
; Local   : [bp-2] = current y while drawing large glyphs
; ---------------------------------------------------------------------
DrawGlyph:
                push bp
                mov bp, sp
                sub sp, 2                       ; room for one local word
                push ax
                push bx
                push cx
                push dx
                push si
                push di
                push es
                push ds
                cmp word [bp+4], 1
                jne dg_big
                ; ----- scale 1: write the pixels straight into the buffer -----
                mov ax, [bp+14]                 ; x
                mov bx, [bp+12]                 ; y
                cmp ax, 0
                jge dg_xok                      ; x is 0 or more: go on
                jmp near dg_done                ; x is negative: keep the whole glyph inside the screen
dg_xok:
                cmp ax, 312
                jg dg_done
                cmp bx, 0
                jl dg_done
                cmp bx, 192
                jg dg_done
                mov di, bx
                shl di, 8
                shl bx, 6
                add di, bx
                add di, ax                      ; di = y*320 + x
                mov es, [fb_seg]
                mov dl, [bp+6]                  ; colour
                mov si, [bp+8]
                mov ds, [bp+10]                 ; DS = segment of the glyph bytes
                cld
                mov dh, 8                       ; 8 rows
dg_row1:        lodsb                           ; one row of 8 pixels
                mov cx, 8
dg_bit1:        shl al, 1                       ; left pixel goes into the carry flag
                jnc dg_skip1
                mov [es:di], dl                 ; pixel is set
dg_skip1:       inc di
                loop dg_bit1
                add di, 312                     ; 320 - 8 to the next row
                dec dh
                jnz dg_row1
                jmp dg_done
                ; ----- larger scale: a square for every set bit -----
dg_big:         mov si, [bp+8]
                mov ax, [bp+12]
                mov [bp-2], ax                  ; current y
                mov dx, 8                       ; 8 rows
dg_row2:        push ds
                mov ds, [bp+10]
                mov al, [si]                    ; one row of the glyph
                pop ds
                inc si
                mov bx, [bp+14]                 ; current x
                mov cx, 8
dg_bit2:        shl al, 1
                jnc dg_skip2
                push bx                         ; x
                push word [bp-2]                ; y
                push word [bp+4]                ; width  = scale
                push word [bp+4]                ; height = scale
                push word [bp+6]                ; colour
                call FillRect
dg_skip2:       add bx, [bp+4]
                loop dg_bit2
                mov ax, [bp+4]
                add [bp-2], ax                  ; next row down
                dec dx
                jnz dg_row2
dg_done:        pop ds
                pop es
                pop di
                pop si
                pop dx
                pop cx
                pop bx
                pop ax
                mov sp, bp
                pop bp
                ret 12

; ---------------------------------------------------------------------
; DrawChar(x, y, char, colour, scale)
; Purpose : draws one ASCII character with the BIOS font.
; Inputs  : [bp+12] = x, [bp+10] = y, [bp+8] = ASCII code,
;           [bp+6] = colour, [bp+4] = scale
; Outputs : none      Registers: all preserved
; ---------------------------------------------------------------------
DrawChar:
                push bp
                mov bp, sp
                push ax
                mov ax, [bp+8]
                shl ax, 3                       ; 8 bytes per character
                add ax, [font_off]              ; address of this glyph
                push word [bp+12]               ; x
                push word [bp+10]               ; y
                push word [font_seg]            ; segment of the font
                push ax                         ; offset of the glyph
                push word [bp+6]                ; colour
                push word [bp+4]                ; scale
                call DrawGlyph
                pop ax
                pop bp
                ret 10

; ---------------------------------------------------------------------
; DrawString(x, y, address, colour, scale)
; Purpose : draws a string that ends with a 0 byte.
; Inputs  : [bp+12] = x, [bp+10] = y, [bp+8] = address of the string,
;           [bp+6] = colour, [bp+4] = scale
; Outputs : none      Registers: all preserved
; ---------------------------------------------------------------------
DrawString:
                push bp
                mov bp, sp
                push ax
                push bx
                push dx
                push si
                mov si, [bp+12]                 ; x of the next character
                mov bx, [bp+8]                  ; pointer into the string
                mov dx, [bp+4]
                shl dx, 3                       ; width of one character = 8 * scale
dstr_loop:      mov al, [bx]
                cmp al, 0
                je dstr_done
                mov ah, 0
                push si                         ; x
                push word [bp+10]               ; y
                push ax                         ; the character
                push word [bp+6]                ; colour
                push word [bp+4]                ; scale
                call DrawChar
                add si, dx
                inc bx
                jmp dstr_loop
dstr_done:      pop si
                pop dx
                pop bx
                pop ax
                pop bp
                ret 10

; ---------------------------------------------------------------------
; DrawCentered(y, address, colour, scale)
; Purpose : draws a 0-terminated string in the middle of the screen.
; Inputs  : [bp+10] = y, [bp+8] = address, [bp+6] = colour, [bp+4] = scale
; Outputs : none      Registers: all preserved
; ---------------------------------------------------------------------
DrawCentered:
                push bp
                mov bp, sp
                push ax
                push bx
                push cx
                push dx
                mov bx, [bp+8]
                mov cx, 0                       ; cx = number of characters
dcen_len:       cmp byte [bx], 0
                je dcen_lenok
                inc cx
                inc bx
                jmp dcen_len
dcen_lenok:     mov ax, cx
                mov dx, [bp+4]
                shl dx, 3                       ; 8 * scale
                mul dx                          ; ax = text width in pixels
                mov bx, SCREEN_WIDTH
                sub bx, ax
                shr bx, 1                       ; x = (320 - width) / 2
                push bx                         ; x
                push word [bp+10]               ; y
                push word [bp+8]                ; address
                push word [bp+6]                ; colour
                push word [bp+4]                ; scale
                call DrawString
                pop dx
                pop cx
                pop bx
                pop ax
                pop bp
                ret 8

; ---------------------------------------------------------------------
; DrawNumber(x, y, low, high, digits, colour, scale)
; Purpose : draws an unsigned 32-bit number (high:low) as a fixed number
;           of decimal digits, with leading zeros.  Repeated division by
;           10: the remainders are pushed on the stack and popped in
;           reverse order, so the first digit comes out first.
; Inputs  : [bp+16] = x, [bp+14] = y, [bp+12] = low word, [bp+10] = high
;           word, [bp+8] = number of digits, [bp+6] = colour, [bp+4] = scale
; Outputs : none      Registers: all preserved
; Local   : [bp-2] = high word being divided, [bp-4] = low word
; ---------------------------------------------------------------------
DrawNumber:
                push bp
                mov bp, sp
                sub sp, 4                       ; two local words
                push ax
                push bx
                push cx
                push dx
                push si
                mov ax, [bp+10]
                mov [bp-2], ax                  ; high word
                mov ax, [bp+12]
                mov [bp-4], ax                  ; low word
                mov cx, [bp+8]                  ; digits to make
                cmp cx, 0
                je dn_done
                mov bx, 10
dn_div:         mov dx, 0
                mov ax, [bp-2]
                div bx                          ; high / 10: ax = quotient, dx = remainder
                mov [bp-2], ax
                mov ax, [bp-4]                  ; dx:ax = remainder * 65536 + low
                div bx                          ; ax = new low word, dx = last digit
                mov [bp-4], ax
                add dl, '0'                     ; digit to ASCII (dh is 0)
                push dx                         ; remainders go on the stack
                dec cx
                jnz dn_div
                mov cx, [bp+8]
                mov si, [bp+16]                 ; x of the next digit
                mov bx, [bp+4]
                shl bx, 3                       ; width of one digit = 8 * scale
dn_draw:        pop ax                          ; most significant digit first
                push si                         ; x
                push word [bp+14]               ; y
                push ax                         ; the digit
                push word [bp+6]                ; colour
                push word [bp+4]                ; scale
                call DrawChar
                add si, bx
                dec cx
                jnz dn_draw
dn_done:        pop si
                pop dx
                pop cx
                pop bx
                pop ax
                mov sp, bp
                pop bp
                ret 14
