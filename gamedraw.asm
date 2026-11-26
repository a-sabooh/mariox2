; =====================================================================
; gamedraw.asm - everything inside the game picture
; Reads Person 2's variables, never changes them.
; Drawing conventions (see the end of shared.inc):
;   hero_x / ent_x = left edge, hero_y / ent_y = FEET (first row below the sprite)
;   screen x = world x - camera_x
; =====================================================================

; ---------------------------------------------------------------------
; DrawHUD
; Purpose : black strip on top with SCORE, COINS, WORLD, TIME, LIVES and
;           the HEALTH hearts (Section 5.14).  Labels sit on row y = 0,
;           the values on row y = 8.
; Inputs  : none (reads score, coins, time_left, lives, hero_hp)
; Outputs : none      Registers: all preserved
; ---------------------------------------------------------------------
DrawHUD:
                push ax
                push bx
                push word 0                     ; black strip, 320 x 16
                push word 0
                push word SCREEN_WIDTH
                push word 16
                push word COL_BLACK
                call FillRect
                ; ----- labels -----
                push word 4
                push word 0
                push word str_score
                push word COL_YELLOW
                push word 1
                call DrawString
                push word 68
                push word 0
                push word str_coins
                push word COL_YELLOW
                push word 1
                call DrawString
                push word 120
                push word 0
                push word str_world
                push word COL_YELLOW
                push word 1
                call DrawString
                push word 172
                push word 0
                push word str_time
                push word COL_YELLOW
                push word 1
                call DrawString
                push word 220
                push word 0
                push word str_lives
                push word COL_YELLOW
                push word 1
                call DrawString
                push word 272
                push word 0
                push word str_health
                push word COL_YELLOW
                push word 1
                call DrawString
                ; ----- score: 6 digits from the 32-bit variable -----
                push word 4
                push word 8
                push word [score]               ; low word
                push word [score+2]             ; high word
                push word 6
                push word COL_WHITE
                push word 1
                call DrawNumber
                ; ----- coins: x and 2 digits -----
                push word 68
                push word 8
                push word 'x'
                push word COL_WHITE
                push word 1
                call DrawChar
                mov al, [coins]
                mov ah, 0
                push word 76
                push word 8
                push ax
                push word 0
                push word 2
                push word COL_WHITE
                push word 1
                call DrawNumber
                ; ----- world -----
                push word 120
                push word 8
                push word str_w11
                push word COL_WHITE
                push word 1
                call DrawString
                ; ----- time: 3 digits -----
                push word 172
                push word 8
                push word [time_left]
                push word 0
                push word 3
                push word COL_WHITE
                push word 1
                call DrawNumber
                ; ----- lives: x and 1 or 2 digits -----
                push word 220
                push word 8
                push word 'x'
                push word COL_WHITE
                push word 1
                call DrawChar
                mov al, [lives]
                mov ah, 0
                mov bx, 1                       ; one digit ...
                cmp ax, 10
                jb hud_onedigit
                mov bx, 2                       ; ... or two when lives is 10 or more
hud_onedigit:   push word 228
                push word 8
                push ax
                push word 0
                push bx
                push word COL_WHITE
                push word 1
                call DrawNumber
                ; ----- hearts: first one is always filled, second one if hp = 2 -----
                mov bl, [hero_hp]
                mov ax, COL_RED
                cmp bl, 1
                jae hud_heart1
                mov ax, COL_GRAY
hud_heart1:     push word 272
                push word 8
                push cs                         ; the heart bits live in our own segment
                push word heart_bits
                push ax
                push word 1
                call DrawGlyph
                mov ax, COL_RED
                cmp bl, 2
                jae hud_heart2
                mov ax, COL_GRAY                ; empty heart is gray
hud_heart2:     push word 284
                push word 8
                push cs
                push word heart_bits
                push ax
                push word 1
                call DrawGlyph
                pop bx
                pop ax
                ret

; An 8x8 heart: one byte per row, 1 bits are pixels.
heart_bits:     db 01100110b, 11111111b, 11111111b, 11111111b
                db 01111110b, 00111100b, 00011000b, 00000000b

; ---------------------------------------------------------------------
; DrawHero
; Purpose : draws Mario.  Small Mario = one 16x16 sprite, Super Mario =
;           a 16x16 top piece and a 16x16 bottom piece (16x32).  The
;           sprites look to the right; FACE_LEFT mirrors them.  While
;           invulnerable Mario is drawn only on every second frame
;           (blinking).  Running alternates between two pictures.
; Inputs  : none (reads the hero_ variables and camera_x)
; Outputs : none      Registers: all preserved
; ---------------------------------------------------------------------
DrawHero:
                push ax
                push bx
                push cx
                push dx
                push si
                cmp byte [hero_visible], 0
                jne dh_visible                  ; Mario is on the screen: go on
                jmp near dh_done                ; Mario is inside the castle: draw nothing
dh_visible:     cmp byte [hero_invuln], 0
                je dh_show
                test byte [hero_invuln], 1      ; blink: skip every second frame
                jz dh_show                      ; even frame: draw him
                jmp near dh_done                ; odd frame: skip
dh_show:        mov cx, [hero_x]
                sub cx, [camera_x]              ; cx = screen x
                mov dx, 0                       ; dx = flags
                cmp byte [hero_facing], FACE_LEFT
                jne dh_faceok
                mov dx, 1                       ; mirror
dh_faceok:      mov bl, [hero_pose]
                cmp bl, POSE_RUN
                jne dh_poseok
                test word [tick_count], 4       ; walking animation: stand and run in turns
                jz dh_poseok
                mov bl, POSE_STAND
dh_poseok:      cmp byte [hero_form], FORM_SUPER
                je dh_super
                ; ----- Small Mario -----
                mov si, spr_mario_stand
                cmp bl, POSE_RUN
                jne dh_s1
                mov si, spr_mario_run
dh_s1:          cmp bl, POSE_JUMP
                jne dh_s2
                mov si, spr_mario_jump
dh_s2:          mov ax, [hero_y]
                sub ax, 16                      ; top = feet - 16
                push cx
                push ax
                push si
                push dx
                call DrawSprite
                jmp dh_done
                ; ----- Super Mario -----
dh_super:       mov ax, [hero_y]
                sub ax, 32                      ; top piece starts at feet - 32
                push cx
                push ax
                push word spr_super_top
                push dx
                call DrawSprite
                mov si, spr_super_bot_stand
                cmp bl, POSE_RUN
                jne dh_b1
                mov si, spr_super_bot_run
dh_b1:          cmp bl, POSE_JUMP
                jne dh_b2
                mov si, spr_super_bot_jump
dh_b2:          mov ax, [hero_y]
                sub ax, 16                      ; bottom piece starts at feet - 16
                push cx
                push ax
                push si
                push dx
                call DrawSprite
dh_done:        pop si
                pop dx
                pop cx
                pop bx
                pop ax
                ret

; ---------------------------------------------------------------------
; DrawEntities
; Purpose : walks through the entities table and draws every enemy and
;           mushroom that is on the screen (-16 < screen x < 320).
;           Goomba: walking picture flips every 8 ticks (animation),
;           flat picture in state ES_FLAT.  Koopa: shell picture in the
;           two shell states, mirrored when it walks to the left.
; Inputs  : none (reads entities and camera_x)
; Outputs : none      Registers: all preserved
; ---------------------------------------------------------------------
DrawEntities:
                push ax
                push bx
                push cx
                push dx
                push si
                push di
                mov bx, entities                ; pointer to the current record
                mov cx, MAX_ENTITIES
de_loop:        cmp byte [bx+ENT_TYPE], ENT_NONE
                je de_next                      ; empty slot
                mov ax, [bx+ENT_X]
                sub ax, [camera_x]              ; screen x
                cmp ax, -16
                jle de_next                     ; completely left of the screen
                cmp ax, SCREEN_WIDTH
                jge de_next                     ; completely right of the screen
                mov dx, ax                      ; dx = screen x
                mov ax, [bx+ENT_Y]
                sub ax, 16                      ; ax = top of the sprite
                mov di, 0                       ; di = flags
                cmp byte [bx+ENT_DIR], FACE_LEFT
                jne de_dirok
                mov di, 1                       ; walks left: mirror
de_dirok:       cmp byte [bx+ENT_TYPE], ENT_GOOMBA
                jne de_notgoomba
                mov si, spr_goomba
                cmp byte [bx+ENT_STATE], ES_FLAT
                jne de_gwalk
                mov si, spr_goomba_flat
                jmp de_draw
de_gwalk:       mov di, 0
                test word [tick_count], 8       ; flip every 8 ticks = leg animation
                jz de_draw
                mov di, 1
                jmp de_draw
de_notgoomba:   cmp byte [bx+ENT_TYPE], ENT_KOOPA
                jne de_mush
                mov si, spr_koopa
                cmp byte [bx+ENT_STATE], ES_SHELL_STILL
                je de_shell
                cmp byte [bx+ENT_STATE], ES_SHELL_SLIDE
                jne de_draw
de_shell:       mov si, spr_shell
                jmp de_draw
de_mush:        cmp byte [bx+ENT_TYPE], ENT_MUSHROOM
                jne de_next
                mov si, spr_mushroom
                mov di, 0
de_draw:        push dx                         ; x
                push ax                         ; y
                push si                         ; picture
                push di                         ; flags
                call DrawSprite
de_next:        add bx, ENT_SIZE                ; next record
                dec cx
                jnz de_loop
                pop di
                pop si
                pop dx
                pop cx
                pop bx
                pop ax
                ret

; ---------------------------------------------------------------------
; DrawCastle
; Purpose : a small castle made of rectangles next to the flag pole
;           (map columns 58 and 59).  Drawn only when it is on screen.
; Inputs  : none      Outputs: none      Registers: all preserved
; ---------------------------------------------------------------------
DrawCastle:
                push ax
                push bx
                mov ax, CASTLE_X
                sub ax, [camera_x]              ; screen x of the castle
                cmp ax, SCREEN_WIDTH
                jge dcas_done
                push ax                         ; wall: 32 x 24
                push word 136
                push word 32
                push word 24
                push word COL_BRICK
                call FillRect
                push ax                         ; battlement 1
                push word 128
                push word 6
                push word 8
                push word COL_BRICK
                call FillRect
                mov bx, ax
                add bx, 9
                push bx                         ; battlement 2
                push word 128
                push word 6
                push word 8
                push word COL_BRICK
                call FillRect
                add bx, 9
                push bx                         ; battlement 3
                push word 128
                push word 6
                push word 8
                push word COL_BRICK
                call FillRect
                add bx, 8
                push bx                         ; battlement 4
                push word 128
                push word 6
                push word 8
                push word COL_BRICK
                call FillRect
                mov bx, ax
                add bx, 11
                push bx                         ; door
                push word 142
                push word 10
                push word 18
                push word COL_BLACK
                call FillRect
dcas_done:      pop bx
                pop ax
                ret

; ---------------------------------------------------------------------
; DrawPlayfield
; Purpose : the whole game picture in the order of Section 5.13 step 9:
;           sky, map, castle, enemies, Mario, black bottom strip, HUD.
; Inputs  : none      Outputs: none      Registers: all preserved
; ---------------------------------------------------------------------
DrawPlayfield:
                push word COL_SKY
                call ClearFrame
                call DrawMap
                call DrawCastle
                call DrawEntities
                call DrawHero
                push word 0                     ; the bottom 8 rows stay black (also hides
                push word 192                   ; Mario falling into a pit)
                push word SCREEN_WIDTH
                push word 8
                push word COL_BLACK
                call FillRect
                call DrawHUD
                ret
