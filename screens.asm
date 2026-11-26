; =====================================================================
; screens.asm - the screens of Section 5.12 (display part of Module 14)
; RenderFrame looks at game_state and calls the matching procedure
; through a jump table.  PLAYING, DYING and WIN SEQUENCE all show the
; normal game picture (Person 2 moves Mario for the animations).
; Everything is drawn into the frame buffer; main_loop copies it.
; =====================================================================

; One entry per game state, in the order of the STATE_ constants.
render_table:   dw RenderTitle                  ; STATE_TITLE
                dw DrawPlayfield                ; STATE_PLAYING
                dw RenderPaused                 ; STATE_PAUSED
                dw DrawPlayfield                ; STATE_DYING
                dw RenderLifeLost               ; STATE_LIFE_LOST
                dw DrawPlayfield                ; STATE_WIN_SEQ
                dw RenderLevelDone              ; STATE_LEVEL_DONE
                dw RenderGameOver               ; STATE_GAME_OVER
                dw RenderNothing                ; STATE_EXIT

; ---------------------------------------------------------------------
; RenderFrame
; Purpose : draws the picture that belongs to game_state.
; Inputs  : none (reads game_state)      Outputs: none
; Registers: all preserved
; ---------------------------------------------------------------------
RenderFrame:
                push bx
                mov bl, [game_state]
                mov bh, 0
                cmp bx, STATE_EXIT
                ja rf_done                      ; unknown state: draw nothing
                shl bx, 1                       ; table of words
                call word [render_table+bx]
rf_done:        pop bx
                ret

RenderNothing:
                ret

; ---------------------------------------------------------------------
; RenderTitle - title screen (Figure 1)
; Brick frame, ground strip, game name, START GAME / EXIT box with the
; highlight taken from menu_selection, team line, Mario and a Goomba.
; ---------------------------------------------------------------------
RenderTitle:
                push ax
                push bx
                push cx
                push word COL_SKY
                call ClearFrame
                ; ----- brick frame: top row and bottom row -----
                mov cx, 0
rt_hloop:       mov ax, cx
                shl ax, 4                       ; column * 16
                push ax
                push word 0
                push word TILE_BRICK
                call DrawTile
                push ax
                push word 176
                push word TILE_BRICK
                call DrawTile
                inc cx
                cmp cx, 20
                jb rt_hloop
                ; ----- brick frame: left and right column -----
                mov cx, 1
rt_vloop:       mov ax, cx
                shl ax, 4                       ; row * 16
                push word 0
                push ax
                push word TILE_BRICK
                call DrawTile
                push word 304
                push ax
                push word TILE_BRICK
                call DrawTile
                inc cx
                cmp cx, 11
                jb rt_vloop
                ; ----- ground strip inside the frame (row 10) -----
                mov cx, 1
rt_gloop:       mov ax, cx
                shl ax, 4
                push ax
                push word 160
                push word TILE_GROUND
                call DrawTile
                inc cx
                cmp cx, 19
                jb rt_gloop
                ; ----- game name with a shadow -----
                push word 30
                push word 28
                push word str_title
                push word COL_BLACK
                push word 3
                call DrawString
                push word 28
                push word 26
                push word str_title
                push word COL_RED
                push word 3
                call DrawString
                push word 72
                push word 62
                push word str_engine
                push word COL_WHITE
                push word 2
                call DrawString
                ; ----- menu box -----
                push word 104
                push word 92
                push word 112
                push word 52
                push word COL_WHITE
                call FillRect
                push word 106
                push word 94
                push word 108
                push word 48
                push word COL_BLACK
                call FillRect
                mov bx, COL_WHITE               ; START GAME is yellow when selected
                cmp byte [menu_selection], 0
                jne rt_c1
                mov bx, COL_YELLOW
rt_c1:          push word 128
                push word 104
                push word str_start
                push bx
                push word 1
                call DrawString
                mov bx, COL_WHITE               ; EXIT is yellow when selected
                cmp byte [menu_selection], 1
                jne rt_c2
                mov bx, COL_YELLOW
rt_c2:          push word 128
                push word 124
                push word str_exit
                push bx
                push word 1
                call DrawString
                mov bx, 104                     ; arrow next to the selected line
                cmp byte [menu_selection], 0
                je rt_arrow
                mov bx, 124
rt_arrow:       push word 112
                push bx
                push word '>'
                push word COL_YELLOW
                push word 1
                call DrawChar
                ; ----- Mario, Goomba and the team line -----
                push word 32
                push word 144
                push word spr_mario_stand
                push word 0
                call DrawSprite
                push word 272
                push word 144
                push word spr_goomba
                push word 0
                call DrawSprite
                push word 166
                push word team_text
                push word COL_WHITE
                push word 1
                call DrawCentered
                pop cx
                pop bx
                pop ax
                ret

; ---------------------------------------------------------------------
; RenderPaused - game picture with a PAUSED box on top (Figure 12)
; ---------------------------------------------------------------------
RenderPaused:
                call DrawPlayfield
                push word 88
                push word 72
                push word 144
                push word 56
                push word COL_WHITE
                call FillRect
                push word 90
                push word 74
                push word 140
                push word 52
                push word COL_BLACK
                call FillRect
                push word 84
                push word str_paused
                push word COL_YELLOW
                push word 2
                call DrawCentered
                push word 108
                push word str_resume
                push word COL_WHITE
                push word 1
                call DrawCentered
                ret

; ---------------------------------------------------------------------
; RenderLifeLost - "WORLD 1-1, Mario x lives left" (Figure 7b)
; lives has already been reduced by Person 2.
; ---------------------------------------------------------------------
RenderLifeLost:
                push ax
                push bx
                push word COL_BLACK
                call ClearFrame
                push word 40
                push word str_worldfull
                push word COL_WHITE
                push word 2
                call DrawCentered
                push word 112
                push word 88
                push word spr_mario_stand
                push word 0
                call DrawSprite
                push word 136
                push word 88
                push word 'x'
                push word COL_WHITE
                push word 2
                call DrawChar
                mov al, [lives]
                mov ah, 0
                mov bx, 1                       ; one digit or two
                cmp ax, 10
                jb rl_onedigit
                mov bx, 2
rl_onedigit:    push word 160
                push word 88
                push ax
                push word 0
                push bx
                push word COL_WHITE
                push word 2
                call DrawNumber
                push word 140
                push word str_liveslft
                push word COL_YELLOW
                push word 2
                call DrawCentered
                pop bx
                pop ax
                ret

; ---------------------------------------------------------------------
; RenderLevelDone - LEVEL COMPLETE (Figure 10)
; Person 2 has ALREADY added bonus_points to score, so the first SCORE
; line shows score - bonus_points, the time shown is bonus_points / 50.
; ---------------------------------------------------------------------
RenderLevelDone:
                push ax
                push bx
                push dx
                push word COL_BLACK
                call ClearFrame
                push word 24                    ; yellow frame
                push word 20
                push word 272
                push word 152
                push word COL_YELLOW
                call FillRect
                push word 27
                push word 23
                push word 266
                push word 146
                push word COL_BLACK
                call FillRect
                push word 36
                push word str_levdone
                push word COL_YELLOW
                push word 2
                call DrawCentered
                ; ----- labels -----
                push word 40
                push word 72
                push word str_score
                push word COL_WHITE
                push word 1
                call DrawString
                push word 40
                push word 88
                push word str_coins
                push word COL_WHITE
                push word 1
                call DrawString
                push word 40
                push word 104
                push word str_timeleft
                push word COL_WHITE
                push word 1
                call DrawString
                push word 40
                push word 120
                push word str_timebonus
                push word COL_WHITE
                push word 1
                call DrawString
                push word 40
                push word 136
                push word str_finalscore
                push word COL_YELLOW
                push word 1
                call DrawString
                ; ----- SCORE before the bonus = score - bonus_points (32-bit) -----
                mov ax, [score]
                mov dx, [score+2]
                sub ax, [bonus_points]
                sbb dx, [bonus_points+2]
                push word 208
                push word 72
                push ax                         ; low word
                push dx                         ; high word
                push word 6
                push word COL_WHITE
                push word 1
                call DrawNumber
                ; ----- COINS -----
                push word 200
                push word 88
                push word 'x'
                push word COL_WHITE
                push word 1
                call DrawChar
                mov al, [coins]
                mov ah, 0
                push word 208
                push word 88
                push ax
                push word 0
                push word 2
                push word COL_WHITE
                push word 1
                call DrawNumber
                ; ----- TIME LEFT  nnn x 50 = bonus -----
                mov ax, [bonus_points]
                mov dx, 0
                mov bx, SCORE_TIME_PER_SEC
                div bx                          ; ax = seconds that were left
                push word 120
                push word 104
                push ax
                push word 0
                push word 3
                push word COL_WHITE
                push word 1
                call DrawNumber
                push word 152
                push word 104
                push word str_x50
                push word COL_WHITE
                push word 1
                call DrawString
                push word 208
                push word 104
                push word [bonus_points]
                push word [bonus_points+2]
                push word 5
                push word COL_WHITE
                push word 1
                call DrawNumber
                ; ----- TIME BONUS -----
                push word 200
                push word 120
                push word '+'
                push word COL_WHITE
                push word 1
                call DrawChar
                push word 208
                push word 120
                push word [bonus_points]
                push word [bonus_points+2]
                push word 5
                push word COL_WHITE
                push word 1
                call DrawNumber
                ; ----- FINAL SCORE -----
                push word 208
                push word 136
                push word [score]
                push word [score+2]
                push word 6
                push word COL_YELLOW
                push word 1
                call DrawNumber
                push word 156
                push word str_pressenter
                push word COL_GREEN
                push word 1
                call DrawCentered
                pop dx
                pop bx
                pop ax
                ret

; ---------------------------------------------------------------------
; RenderGameOver - GAME OVER with the final score (Figure 11)
; ---------------------------------------------------------------------
RenderGameOver:
                push ax
                push word COL_BLACK
                call ClearFrame
                push word 40                    ; red frame
                push word 28
                push word 240
                push word 136
                push word COL_RED
                call FillRect
                push word 43
                push word 31
                push word 234
                push word 130
                push word COL_BLACK
                call FillRect
                push word 50
                push word str_gameover
                push word COL_RED
                push word 3
                call DrawCentered
                push word 80
                push word 88
                push word str_final
                push word COL_WHITE
                push word 1
                call DrawString
                push word 184
                push word 88
                push word [score]
                push word [score+2]
                push word 6
                push word COL_WHITE
                push word 1
                call DrawNumber
                push word 80
                push word 108
                push word str_coinsc
                push word COL_YELLOW
                push word 1
                call DrawString
                mov al, [coins]
                mov ah, 0
                push word 136
                push word 108
                push ax
                push word 0
                push word 2
                push word COL_YELLOW
                push word 1
                call DrawNumber
                push word 176
                push word 108
                push word str_timec
                push word COL_YELLOW
                push word 1
                call DrawString
                push word 224
                push word 108
                push word [time_left]
                push word 0
                push word 3
                push word COL_YELLOW
                push word 1
                call DrawNumber
                push word 140
                push word str_entertitle
                push word COL_GREEN
                push word 1
                call DrawCentered
                pop ax
                ret

; ---------------------------------------------------------------------
; Texts (each ends with a 0 byte)
; ---------------------------------------------------------------------
str_score:      db 'SCORE', 0
str_coins:      db 'COINS', 0
str_world:      db 'WORLD', 0
str_w11:        db '1-1', 0
str_time:       db 'TIME', 0
str_lives:      db 'LIVES', 0
str_health:     db 'HEALTH', 0
str_title:      db 'SUPER MARIO', 0
str_engine:     db 'E N G I N E', 0
str_start:      db 'START GAME', 0
str_exit:       db 'EXIT', 0
team_text:      db 'Group # | Mahnoor , Sabooh', 0
str_paused:     db 'PAUSED', 0
str_resume:     db 'Press P to resume', 0
str_worldfull:  db 'WORLD 1-1', 0
str_liveslft:   db 'LIVES LEFT', 0
str_levdone:    db 'LEVEL COMPLETE!', 0
str_timeleft:   db 'TIME LEFT', 0
str_timebonus:  db 'TIME BONUS', 0
str_finalscore: db 'FINAL SCORE', 0
str_x50:        db 'x 50 =', 0
str_pressenter: db 'Press ENTER to continue', 0
str_gameover:   db 'GAME OVER', 0
str_final:      db 'Final Score:', 0
str_coinsc:     db 'Coins:', 0
str_timec:      db 'Time:', 0
str_entertitle: db 'Press ENTER for the title', 0
