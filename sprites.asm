; =====================================================================
; sprites.asm - turning the art text into colours, and DrawSprite
; =====================================================================

; ---------------------------------------------------------------------
; BuildSprites
; Purpose : the art in sprdata.inc is written with letters.  This
;           procedure walks over all of it once and replaces every
;           letter by its position in sprite_legend (= palette colour).
;           REPNE SCASB does the search.  Call it ONCE at program start.
; Inputs  : none      Outputs: none      Registers: all preserved
; ---------------------------------------------------------------------
BuildSprites:
                push ax
                push cx
                push si
                push di
                push es
                push ds
                pop es                          ; ES = DS for SCASB
                mov si, sprite_art_start
                cld
bs_loop:        mov al, [si]                    ; the letter
                mov di, sprite_legend
                mov cx, LEGEND_LEN
                repne scasb                     ; look for it in the legend
                mov ax, di                      ; DI is one past the match
                sub ax, sprite_legend + 1       ; position of the match = colour number
                mov [si], al                    ; store the colour number
                inc si
                cmp si, sprite_art_end
                jb bs_loop
                pop es
                pop di
                pop si
                pop cx
                pop ax
                ret

; ---------------------------------------------------------------------
; DrawSprite(x, y, address, flags)
; Purpose : draws a 16x16 picture (256 bytes, colour 0 = transparent)
;           into the frame buffer.  Clips on all four screen edges: every
;           pixel is checked, so nothing outside the screen is written.
; Inputs  : [bp+10] = x of the left edge (signed, screen coordinates)
;           [bp+8]  = y of the top edge  (signed, screen coordinates)
;           [bp+6]  = address of the 256 picture bytes
;           [bp+4]  = flags, bit 0 = 1: mirror left-right
; Outputs : none      Registers: all preserved
; ---------------------------------------------------------------------
DrawSprite:
                push bp
                mov bp, sp
                push ax
                push bx
                push cx
                push dx
                push si
                push di
                push es
                mov es, [fb_seg]
                mov si, [bp+6]                  ; start of the picture
                test word [bp+4], 1             ; mirrored?
                jz ds_normal
                ; --- mirrored: make a reversed copy of every row in spr_temp ---
                mov di, spr_temp
                mov dx, 16                      ; 16 rows
ds_mrow:        mov bx, si
                add bx, 15                      ; last pixel of the source row
                mov cx, 16
ds_mpix:        mov al, [bx]
                mov [di], al                    ; copy it backwards
                inc di
                dec bx
                loop ds_mpix
                add si, 16                      ; next source row
                dec dx
                jnz ds_mrow
                mov si, spr_temp                ; draw from the reversed copy
ds_normal:      mov dl, 16                      ; row counter
ds_row:         mov bx, [bp+8]                  ; y of this row
                cmp bx, SCREEN_HEIGHT
                jae ds_skiprow                  ; row is above or below the screen
                mov di, bx
                shl di, 8                       ; y * 256
                shl bx, 6                       ; y * 64
                add di, bx                      ; di = y * 320
                mov ax, [bp+10]                 ; ax = x of the first pixel
                mov cx, 16                      ; 16 pixels per row
ds_pix:         cmp ax, SCREEN_WIDTH
                jae ds_nextpix                  ; pixel left or right of the screen
                mov dh, [si]                    ; colour of this pixel
                cmp dh, 0
                je ds_nextpix                   ; colour 0 is transparent
                mov bx, di
                add bx, ax                      ; offset = y*320 + x
                mov [es:bx], dh
ds_nextpix:     inc si
                inc ax
                loop ds_pix
                jmp ds_nextrow
ds_skiprow:     add si, 16                      ; skip this row of the picture
ds_nextrow:     inc word [bp+8]                 ; next screen row
                dec dl
                jnz ds_row
                pop es
                pop di
                pop si
                pop dx
                pop cx
                pop bx
                pop ax
                pop bp
                ret 8
