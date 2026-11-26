; =====================================================================
; tiles.asm - DrawTile and DrawMap (drawing part of Module 3)
; Tiles are opaque 16x16 pictures, so a tile inside the screen is
; copied with REP MOVSW (8 words per row).  Tiles half outside the
; screen (the scrolling edge) go through DrawSprite, which clips.
; The sky tile is not drawn at all: the frame is cleared to sky colour.
; =====================================================================

; Address of the picture for every tile code (0 = nothing to draw).
tile_table:     dw 0                            ; 0  sky
                dw tile_ground                  ; 1  ground
                dw tile_brick                   ; 2  brick
                dw tile_q                       ; 3  ? block (coin)
                dw tile_q                       ; 4  ? block (mushroom) - looks the same
                dw tile_empty                   ; 5  empty block
                dw tile_pipe_tl                 ; 6  pipe top left
                dw tile_pipe_tr                 ; 7  pipe top right
                dw tile_pipe_bl                 ; 8  pipe body left
                dw tile_pipe_br                 ; 9  pipe body right
                dw tile_stair                   ; 10 stair block
                dw tile_coin                    ; 11 coin
                dw tile_flag                    ; 12 flag pole
                dw tile_flagtop                 ; 13 top of the flag pole (internal code)

; ---------------------------------------------------------------------
; DrawTile(x, y, tile)
; Purpose : draws one tile at screen position (x, y).
; Inputs  : [bp+8] = x (signed), [bp+6] = y, [bp+4] = tile code
; Outputs : none      Registers: all preserved
; ---------------------------------------------------------------------
DrawTile:
                push bp
                mov bp, sp
                push ax
                push bx
                push cx
                push dx
                push si
                push di
                push es
                mov bx, [bp+4]                  ; tile code
                cmp bx, TILE_COUNT
                jae dt_done                     ; unknown code: draw nothing
                shl bx, 1                       ; table of words
                mov si, [tile_table+bx]         ; address of the picture
                cmp si, 0
                je dt_done                      ; sky
                mov ax, [bp+8]                  ; x
                mov bx, [bp+6]                  ; y
                cmp ax, 0
                jl dt_slow
                cmp ax, 304                     ; 304 = last x where all 16 pixels fit
                jg dt_slow
                cmp bx, 0
                jl dt_slow
                cmp bx, 184                     ; 184 = last y where all 16 rows fit
                jg dt_slow
                mov di, bx
                shl di, 8
                shl bx, 6
                add di, bx
                add di, ax                      ; di = y*320 + x
                mov es, [fb_seg]
                cld
                mov dx, 16                      ; 16 rows
dt_row:         mov cx, 8                       ; 8 words = 16 pixels
                rep movsw
                add di, 304                     ; 320 - 16 to the next row
                dec dx
                jnz dt_row
                jmp dt_done
dt_slow:        push ax                         ; partly outside: use the clipping routine
                push bx
                push si
                push word 0                     ; no mirror
                call DrawSprite
dt_done:        pop es
                pop di
                pop si
                pop dx
                pop cx
                pop bx
                pop ax
                pop bp
                ret 6

; ---------------------------------------------------------------------
; DrawMap
; Purpose : draws the visible part of level_working (rows 1 to 11; row 0
;           is covered by the HUD).  First column = camera_x / 16, its
;           x position on the screen = -(camera_x mod 16), so the world
;           scrolls one pixel at a time.  21 columns are drawn.
;           The top flag pole tile gets the flag picture.
; Inputs  : none (reads camera_x and level_working)
; Outputs : none      Registers: all preserved
; ---------------------------------------------------------------------
DrawMap:
                push ax
                push bx
                push cx
                push dx
                push si
                mov ax, [camera_x]
                mov bx, ax
                and bx, 15                      ; camera mod 16
                mov [dm_xoff], bx
                shr ax, 4                       ; camera / 16
                mov [dm_first], ax
                mov si, 1                       ; map row (row 0 is the HUD)
dm_row:         mov cx, 0                       ; screen column 0 to 20
dm_col:         mov bx, [dm_first]
                add bx, cx                      ; bx = map column
                cmp bx, MAP_COLS
                jae dm_next                     ; beyond the end of the level
                mov ax, si
                shl ax, 6                       ; row * 64
                mov dx, si
                shl dx, 2                       ; row * 4
                sub ax, dx                      ; row * 60
                add bx, ax                      ; bx = row * 60 + column
                mov al, [level_working+bx]      ; tile code
                mov ah, 0
                cmp al, 0
                je dm_next                      ; sky: nothing to draw
                cmp al, TILE_FLAG
                jne dm_draw
                cmp byte [level_working+bx-MAP_COLS], TILE_FLAG
                je dm_draw                      ; pole continues above: normal pole piece
                mov al, TILE_FLAG_TOP           ; this is the top piece
dm_draw:        mov dx, cx
                shl dx, 4                       ; column * 16
                sub dx, [dm_xoff]               ; minus the scroll offset
                push dx                         ; x
                mov dx, si
                shl dx, 4                       ; row * 16
                push dx                         ; y
                push ax                         ; tile code
                call DrawTile
dm_next:        inc cx
                cmp cx, 21
                jb dm_col
                inc si
                cmp si, MAP_ROWS
                jb dm_row
                pop si
                pop dx
                pop cx
                pop bx
                pop ax
                ret
