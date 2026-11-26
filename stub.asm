; =====================================================================
; stub.asm - TEST STUB for Person 1 (not part of the final game)
; Replaces Person 2's logic.asm when you build with  -dUSE_STUB.
; It only moves Mario sideways and lets you look at every screen.
;
; Keys in the stub:
;   Left / Right          walk (Shift = faster), camera follows like Section 5.3
;   Space (held)          jump pose
;   1 to 8                show state 0 to 7 (title, playing, paused, dying,
;                         life lost, win sequence, level complete, game over)
;   Enter                 title -> playing, end screens -> title
;   Up / Down             move the menu highlight on the title screen
;   P                     pause / resume        M  toggle Small / Super
;   I                     2 seconds of blinking (invulnerable)
;   Esc                   leave the program
; shared.inc needs these labels for its state_table, so the stub defines
; them all (they do nothing).
; =====================================================================

SC_M            equ 32h                         ; scan code of the M key
SC_I            equ 17h                         ; scan code of the I key

; Labels that shared.inc expects from Person 2's code
StateTitle:
StatePlaying:
StatePaused:
StateDying:
StateLifeLost:
StateWinSeq:
StateEndScreen:
StateExit:
                ret

; ---------------------------------------------------------------------
; StubInit
; Purpose : copies the original map into the working map, copies the
;           spawn table into the entities table, adds one mushroom and
;           puts sample values into score, coins and time.
; ---------------------------------------------------------------------
StubInit:
                push ax
                push cx
                push si
                push di
                push es
                push ds
                pop es                          ; ES = DS
                cld
                mov si, level_original
                mov di, level_working
                mov cx, MAP_SIZE
                rep movsb                       ; one block move restores the map
                mov si, spawn_table
                mov di, entities
su_spawn:       cmp byte [si+SPAWN_TYPE], ENT_NONE
                je su_spawndone
                mov al, [si+SPAWN_TYPE]
                mov [di+ENT_TYPE], al
                mov byte [di+ENT_STATE], ES_WALKING
                mov al, [si+SPAWN_DIR]
                mov [di+ENT_DIR], al
                mov ax, [si+SPAWN_X]
                mov [di+ENT_X], ax
                mov ax, [si+SPAWN_Y]
                mov [di+ENT_Y], ax
                add si, SPAWN_SIZE
                add di, ENT_SIZE
                jmp su_spawn
su_spawndone:   mov byte [di+ENT_TYPE], ENT_MUSHROOM    ; a mushroom to look at
                mov word [di+ENT_X], 200
                mov word [di+ENT_Y], 160
                mov word [score], 12345
                mov word [score+2], 0
                mov byte [coins], 7
                mov word [time_left], 245
                pop es
                pop di
                pop si
                pop cx
                pop ax
                ret

; ---------------------------------------------------------------------
; GameUpdate (stub version)
; ---------------------------------------------------------------------
GameUpdate:
                push ax
                push bx
                cmp byte [key_pressed+SC_ESC], 1
                jne su_noesc
                mov byte [game_state], STATE_EXIT
                jmp su_done
su_noesc:
                ; ----- number keys 1 to 8 choose a state (scan codes 02h to 09h) -----
                mov bx, 0
su_numloop:     cmp byte [key_pressed+2+bx], 1
                jne su_numnext
                mov [game_state], bl            ; state number = key number - 1
                cmp bl, STATE_LEVEL_DONE
                jne su_numnext
                mov word [bonus_points], 9350   ; fake a level complete result
                mov word [bonus_points+2], 0
                mov word [score], 14200
                mov word [score+2], 0
su_numnext:     inc bx
                cmp bx, 8
                jb su_numloop
                ; ----- menu and Enter -----
                cmp byte [key_pressed+SC_ENTER], 1
                jne su_noenter
                cmp byte [game_state], STATE_TITLE
                jne su_enterend
                mov byte [game_state], STATE_PLAYING
                jmp su_noenter
su_enterend:    cmp byte [game_state], STATE_LEVEL_DONE
                je su_totitle
                cmp byte [game_state], STATE_GAME_OVER
                jne su_noenter
su_totitle:     mov byte [game_state], STATE_TITLE
su_noenter:     cmp byte [game_state], STATE_TITLE
                jne su_notitle
                cmp byte [key_pressed+SC_UP], 1
                jne su_noup
                mov byte [menu_selection], 0
su_noup:        cmp byte [key_pressed+SC_DOWN], 1
                jne su_done
                mov byte [menu_selection], 1
                jmp su_done
su_notitle:     ; ----- pause with P -----
                cmp byte [key_pressed+SC_P], 1
                jne su_nop
                cmp byte [game_state], STATE_PAUSED
                je su_unpause
                cmp byte [game_state], STATE_PLAYING
                jne su_nop
                mov byte [game_state], STATE_PAUSED
                jmp su_nop
su_unpause:     mov byte [game_state], STATE_PLAYING
su_nop:         ; ----- M toggles the form, I starts the blinking -----
                cmp byte [key_pressed+SC_M], 1
                jne su_nom
                cmp byte [hero_form], FORM_SMALL
                jne su_tosmall
                mov byte [hero_form], FORM_SUPER
                mov byte [hero_hp], HP_SUPER
                jmp su_nom
su_tosmall:     mov byte [hero_form], FORM_SMALL
                mov byte [hero_hp], HP_SMALL
su_nom:         cmp byte [key_pressed+SC_I], 1
                jne su_noi
                mov byte [hero_invuln], INVULN_FRAMES
su_noi:         cmp byte [hero_invuln], 0
                je su_noinv
                dec byte [hero_invuln]
su_noinv:       cmp byte [game_state], STATE_PLAYING
                jne su_done
                ; ----- walking -----
                mov byte [hero_pose], POSE_STAND
                mov bx, 2                       ; speed
                cmp byte [key_state+SC_LSHIFT], 1
                jne su_slow
                mov bx, 4
su_slow:        cmp byte [key_state+SC_RIGHT], 1
                jne su_noright
                add [hero_x], bx
                mov byte [hero_facing], FACE_RIGHT
                mov byte [hero_pose], POSE_RUN
su_noright:     cmp byte [key_state+SC_LEFT], 1
                jne su_noleft
                mov ax, [hero_x]
                sub ax, bx
                cmp ax, [camera_x]
                jl su_noleft                    ; left wall = left edge of the screen
                mov [hero_x], ax
                mov byte [hero_facing], FACE_LEFT
                mov byte [hero_pose], POSE_RUN
su_noleft:      cmp byte [key_state+SC_SPACE], 1
                jne su_nospace
                mov byte [hero_pose], POSE_JUMP
su_nospace:     ; ----- camera rule of Section 5.3 -----
                mov ax, [hero_x]
                sub ax, SCREEN_MID_X            ; new camera = hero_x - 160
                jl su_done                      ; hero is left of the middle
                cmp ax, MAX_CAMERA_X
                jbe su_camok
                mov ax, MAX_CAMERA_X            ; clamp to the last position
su_camok:       cmp ax, [camera_x]
                jbe su_done                     ; the camera never moves back
                mov [camera_x], ax
su_done:        pop bx
                pop ax
                ret
