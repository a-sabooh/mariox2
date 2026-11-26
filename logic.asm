; =============================================================
; logic.asm - Person 2: game logic (Modules 3, 6, 9-15)
; Included by Person 1's main file. Needs DS = ES (true in a .COM).
; Person 1 calls GameUpdate once per frame, in EVERY game state;
; GameUpdate runs the procedure of the current state through the
; jump table state_table (shared.inc).
;
; Calling convention (Section 4):
;  - Inputs go through the STACK. Values are passed by value; data that
;    a procedure must change (the hero record, an entity record, a
;    position) is passed by ADDRESS. The callee removes its parameters
;    with RET n.
;  - Results come back in AX (and DX where noted) or are written into
;    the record whose address was passed in.
;  - Every procedure preserves every register it does not return.
;  - The status helpers AddCoin, AddLife and UpdateClock, and the query
;    CountActiveEnemies, receive the ADDRESS of the data they use on
;    the stack (coins, lives, clock_ticks, time_left, entities).
;    AddScore(points) takes its value on the stack as in the brief.
; =============================================================

; Debug keys for the live demo (list them in the README):
;   T = set the clock to DEBUG_TIME seconds (demo test 11)
;   C = set the coin counter to 99 (demo test 13)
; Set to 0 to remove them from the program.
%define DEBUG_KEYS 1

; =============================================================
; Procedure : GameUpdate
; Purpose   : One frame of game logic. Jumps through state_table
;             (indexed by game_state) to the procedure of the
;             current state (Section 5.12).
; Inputs    : game_state
; Outputs   : whatever the state procedure changes
; Registers : none changed (all registers are preserved)
; =============================================================
GameUpdate:
    push ax
    push bx
    mov bl, [game_state]
    xor bh, bh                      ; BX = state number
    shl bx, 1                       ; words are 2 bytes
    call word [state_table + bx]    ; indirect call through the jump table
    pop bx
    pop ax
    ret

; =============================================================
; Procedure : IsKeyDown
; Purpose   : Tells whether a key is held (key_state table).
; Inputs    : on the stack: scan code (word). Removed by RET 2.
; Outputs   : AX = 1 if held, else 0
; Registers : none changed except AX
; =============================================================
IsKeyDown:
    push bp
    mov bp, sp
    push bx

    mov bx, [bp + 4]                ; scan code
    xor ax, ax
    cmp byte [key_state + bx], 0
    je .done
    mov ax, 1

.done:
    pop bx
    pop bp
    ret 2

; =============================================================
; Procedure : WasKeyPressed
; Purpose   : Tells whether a key went down since the last frame
;             (key_pressed table, no auto-repeat).
; Inputs    : on the stack: scan code (word). Removed by RET 2.
; Outputs   : AX = 1 if pressed, else 0
; Registers : none changed except AX
; =============================================================
WasKeyPressed:
    push bp
    mov bp, sp
    push bx

    mov bx, [bp + 4]                ; scan code
    xor ax, ax
    cmp byte [key_pressed + bx], 0
    je .done
    mov ax, 1

.done:
    pop bx
    pop bp
    ret 2

; =============================================================
; Procedure : StateTitle
; Purpose   : Title screen. Up/Down move the highlight, Enter on
;             START begins a new game, Enter on EXIT or Esc leaves.
; Inputs    : key_pressed, menu_selection (state handler: no stack
;             parameters, it is called through the jump table)
; Outputs   : menu_selection, game_state (NewGame is called)
; Registers : none changed (flags only)
; =============================================================
StateTitle:
    push ax

    push word SC_ESC
    call WasKeyPressed
    cmp ax, 0
    jne .exit

    push word SC_UP
    call WasKeyPressed
    cmp ax, 0
    je .check_down
    mov byte [menu_selection], 0    ; highlight START GAME
.check_down:
    push word SC_DOWN
    call WasKeyPressed
    cmp ax, 0
    je .check_enter
    mov byte [menu_selection], 1    ; highlight EXIT
.check_enter:
    push word SC_ENTER
    call WasKeyPressed
    cmp ax, 0
    je .done
    cmp byte [menu_selection], 0
    jne .exit
    call NewGame                    ; START GAME: also sets STATE_PLAYING
    jmp .done
.exit:
    mov byte [game_state], STATE_EXIT
.done:
    pop ax
    ret

; =============================================================
; Procedure : StatePlaying
; Purpose   : P pauses, Esc returns to the title, otherwise one
;             game frame runs (PlayFrame). The debug keys T and C
;             are handled here when DEBUG_KEYS is 1.
; Inputs    : key_pressed
; Outputs   : game_state and everything PlayFrame changes
; Registers : none changed (flags only)
; =============================================================
StatePlaying:
    push ax

    push word SC_ESC
    call WasKeyPressed
    cmp ax, 0
    jne .to_title
    push word SC_P
    call WasKeyPressed
    cmp ax, 0
    jne .to_pause
%if DEBUG_KEYS
    call DebugKeys
%endif
    call PlayFrame
    jmp .done
.to_title:
    mov byte [game_state], STATE_TITLE
    jmp .done
.to_pause:
    mov byte [game_state], STATE_PAUSED
.done:
    pop ax
    ret

%if DEBUG_KEYS
; =============================================================
; Procedure : DebugKeys
; Purpose   : Debug keys for the live demo (list them in the README):
;             T sets the clock to DEBUG_TIME seconds (test 11),
;             C sets the coin counter to 99 (test 13).
; Inputs    : key_pressed
; Outputs   : time_left, clock_ticks, coins
; Registers : none changed (flags only)
; =============================================================
DebugKeys:
    push ax

    push word SC_T
    call WasKeyPressed
    cmp ax, 0
    je .check_coins
    mov word [time_left], DEBUG_TIME
    mov byte [clock_ticks], 0
.check_coins:
    push word SC_C
    call WasKeyPressed
    cmp ax, 0
    je .done
    mov byte [coins], 99            ; the next coin gives the 1-UP

.done:
    pop ax
    ret
%endif

; =============================================================
; Procedure : StatePaused
; Purpose   : Everything is frozen. P resumes, Esc goes to title.
; Inputs    : key_pressed
; Outputs   : game_state
; Registers : none changed (flags only)
; =============================================================
StatePaused:
    push ax

    push word SC_ESC
    call WasKeyPressed
    cmp ax, 0
    jne .to_title
    push word SC_P
    call WasKeyPressed
    cmp ax, 0
    je .done
    mov byte [game_state], STATE_PLAYING
    jmp .done
.to_title:
    mov byte [game_state], STATE_TITLE
.done:
    pop ax
    ret

; =============================================================
; Procedure : StateExit
; Purpose   : Nothing to do: Person 1's main loop sees STATE_EXIT
;             and restores the vectors and text mode.
; Inputs    : none
; Outputs   : none
; Registers : none changed
; =============================================================
StateExit:
    ret

; =============================================================
; Procedure : StateEndScreen
; Purpose   : Level Complete and Game Over screens: Enter returns
;             to the title (the next START begins a new game).
; Inputs    : key_pressed
; Outputs   : game_state
; Registers : none changed (flags only)
; =============================================================
StateEndScreen:
    push ax

    push word SC_ENTER
    call WasKeyPressed
    cmp ax, 0
    je .done
    mov byte [game_state], STATE_TITLE
.done:
    pop ax
    ret

; =============================================================
; Procedure : PlayFrame
; Purpose   : The PLAYING frame, in the order of Section 5.13 steps
;             3 to 8: hero, enemies, contacts, coins, clock,
;             invulnerability, death and flag checks, camera.
;             It reads the game data and passes it on the stack to
;             the procedures below.
; Inputs    : all game variables
; Outputs   : all game variables
; Registers : none changed (all registers are preserved)
; =============================================================
PlayFrame:
    push ax
    push dx
    push si

    mov si, hero_data               ; SI = address of the hero record

    mov ax, [si + H_Y]
    mov [si + H_PREVY], ax          ; remember the feet for the stomp test

    ; --- step 3: update Mario, one axis at a time ---
    push si                         ; UpdateHorizontalSpeed(hero, left, right, run)
    push word SC_LEFT
    call IsKeyDown
    push ax
    push word SC_RIGHT
    call IsKeyDown
    push ax
    push word SC_LSHIFT
    call IsKeyDown
    push ax
    call UpdateHorizontalSpeed

    push si                         ; UpdateVerticalSpeed(hero, space)
    push word SC_SPACE
    call IsKeyDown
    push ax
    call UpdateVerticalSpeed

    push si                         ; MoveHeroX(hero, camera_x)
    push word [camera_x]
    call MoveHeroX
    push si
    call ResolveHeroX
    push si
    call MoveHeroY
    push si
    call ResolveHeroY
    push si
    call UpdateHeroPose

    ; --- step 4: enemies, shells and mushrooms ---
    push word [camera_x]
    call UpdateEntities

    ; --- step 5: Mario against enemies, items and coins ---
    push si
    call HeroVsEntities             ; AX = 1 if an enemy killed Mario
    cmp ax, 0
    jne .dead
    push si
    call CollectCoins

    ; --- step 6: clock and invulnerability ---
    push word clock_ticks           ; address of the tick counter
    push word time_left             ; address of the seconds left
    call UpdateClock                ; AX = 1 if the time ran out
    cmp ax, 0
    jne .dead
    push si
    call UpdateInvuln

    ; --- step 7: pit and flag ---
    push si
    call CheckPit                   ; AX = 1 if Mario fell into a pit
    cmp ax, 0
    jne .dead
    push si
    call CheckFlag                  ; AX = 1 if he touched the pole, DX = pole column
    cmp ax, 0
    je .camera
    push si
    push dx
    call StartWin
    jmp .camera

.dead:
    push si
    call StartDeath
    jmp .done                       ; the camera stays where it is

    ; --- step 8: camera ---
.camera:
    push word [si + H_X]
    push word [camera_x]
    call UpdateCamera
    mov [camera_x], ax

.done:
    pop si
    pop dx
    pop ax
    ret

; =============================================================
; Procedure : AddFixed
; Purpose   : Adds an 8.8 velocity to a position stored as a whole-
;             pixel word plus a fraction byte (ADD for the fraction,
;             ADC for the whole pixels and the carry).
; Inputs    : on the stack, pushed in this order:
;             address of the whole-pixel word, address of the fraction
;             byte, velocity (8.8 signed word). Removed by RET 6.
; Outputs   : the whole-pixel word and the fraction byte
; Registers : none changed (flags change)
; =============================================================
AddFixed:
    push bp
    mov bp, sp
    push ax
    push bx

    mov ax, [bp + 4]                ; velocity
    mov bx, [bp + 6]                ; address of the fraction byte
    add [bx], al                    ; fraction first, carry goes to CF
    mov al, ah                      ; whole-pixel part of the velocity
    cbw                             ; sign-extend to a word (CF unchanged)
    mov bx, [bp + 8]                ; address of the whole-pixel word
    adc [bx], ax                    ; whole pixels plus the carry

    pop bx
    pop ax
    pop bp
    ret 6

; =============================================================
; Procedure : UpdateHorizontalSpeed
; Purpose   : Changes hero_vx for one frame. Accelerates toward the
;             walk or run limit while Left/Right is held (braking
;             faster when reversing), applies friction when no single
;             direction is held, and sets hero_facing. A speed above
;             the limit (Shift released while running) is reduced by
;             friction instead of being cut at once.
; Inputs    : on the stack, pushed in this order: address of the hero
;             record, left key (0/1), right key (0/1), run key (0/1).
;             Removed by RET 8.
; Outputs   : hero_vx (8.8 signed), hero_facing
; Registers : none changed (all registers are preserved)
; =============================================================
UpdateHorizontalSpeed:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push si

    mov si, [bp + 10]               ; hero record

    ; --- choose the speed limit: run if Shift is held, else walk ---
    mov bx, MAX_WALK_SPEED
    cmp word [bp + 4], 0
    je .limit_chosen
    mov bx, MAX_RUN_SPEED
.limit_chosen:

    ; --- direction keys: both or neither held means friction ---
    mov ax, [bp + 6]                ; right
    cmp ax, [bp + 8]                ; left
    je .friction
    cmp ax, 0
    jne .go_right

    ; --- only Left held: speed goes more negative, up to minus the limit ---
.go_left:
    mov byte [si + H_FACING], FACE_LEFT
    neg bx                          ; BX = minus the limit
    mov ax, [si + H_VX]
    cmp ax, bx
    jl .left_over                   ; faster than the limit (Shift just released)
    mov cx, WALK_ACCEL
    cmp ax, 0
    jle .left_accel
    add cx, FRICTION                ; moving right: brake harder
.left_accel:
    sub ax, cx
    cmp ax, bx
    jge .left_store                 ; signed compare: still within the limit
    mov ax, bx                      ; clamp to minus the limit
.left_store:
    mov [si + H_VX], ax
    jmp .done
.left_over:
    add ax, FRICTION                ; ease back toward the limit
    cmp ax, bx
    jle .left_store
    mov ax, bx
    jmp .left_store

    ; --- only Right held: speed grows up to the limit ---
.go_right:
    mov byte [si + H_FACING], FACE_RIGHT
    mov ax, [si + H_VX]
    cmp ax, bx
    jg .right_over                  ; faster than the limit (Shift just released)
    mov cx, WALK_ACCEL
    cmp ax, 0
    jge .right_accel
    add cx, FRICTION                ; moving left: brake harder
.right_accel:
    add ax, cx
    cmp ax, bx
    jle .right_store                ; signed compare: still within the limit
    mov ax, bx                      ; clamp to the limit
.right_store:
    mov [si + H_VX], ax
    jmp .done
.right_over:
    sub ax, FRICTION                ; ease back toward the limit
    cmp ax, bx
    jge .right_store
    mov ax, bx
    jmp .right_store

    ; --- no single direction held: friction slows Mario to exactly zero ---
.friction:
    mov ax, [si + H_VX]
    cmp ax, 0
    je .done                        ; already stopped
    jl .friction_left
    sub ax, FRICTION                ; moving right: slow down
    jge .friction_store
    xor ax, ax                      ; overshot zero: stop exactly
    jmp .friction_store
.friction_left:
    add ax, FRICTION                ; moving left: slow down
    jle .friction_store
    xor ax, ax                      ; overshot zero: stop exactly
.friction_store:
    mov [si + H_VX], ax

.done:
    pop si
    pop cx
    pop bx
    pop ax
    pop bp
    ret 8

; =============================================================
; Procedure : UpdateVerticalSpeed
; Purpose   : Changes hero_vy for one frame. Starts a jump when Space
;             is held and Mario is on the ground (no double jump),
;             cuts the rise short when Space is released early
;             (variable jump height), then adds gravity and limits
;             the fall speed.
; Inputs    : on the stack, pushed in this order: address of the hero
;             record, Space key (0/1). Removed by RET 4.
; Outputs   : hero_vy (8.8 signed), hero_on_ground (cleared on jump)
; Registers : none changed (all registers are preserved)
; =============================================================
UpdateVerticalSpeed:
    push bp
    mov bp, sp
    push ax
    push si

    mov si, [bp + 6]                ; hero record
    mov ax, [si + H_VY]

    ; --- start a jump: only from the ground, only while Space is held ---
    cmp byte [si + H_ONGROUND], 0
    je .no_jump
    cmp word [bp + 4], 0
    je .no_jump
    mov ax, JUMP_START              ; big upward speed
    mov byte [si + H_ONGROUND], 0   ; now in the air: blocks a second jump

    ; --- variable jump height: Space released while rising fast ---
.no_jump:
    cmp ax, 0
    jge .gravity                    ; not rising: nothing to cut
    cmp word [bp + 4], 0
    jne .gravity                    ; Space still held: full jump
    cmp ax, JUMP_CUTOFF
    jge .gravity                    ; already slower than the cut-off
    mov ax, JUMP_CUTOFF             ; cut the rise to the cut-off speed

    ; --- gravity every frame, with a maximum fall speed ---
.gravity:
    add ax, GRAVITY
    cmp ax, MAX_FALL_SPEED
    jle .store
    mov ax, MAX_FALL_SPEED          ; clamp the fall speed
.store:
    mov [si + H_VY], ax

    pop si
    pop ax
    pop bp
    ret 4

; =============================================================
; Procedure : MoveHeroX
; Purpose   : Adds hero_vx to the horizontal position (whole pixels
;             plus fraction). Then keeps Mario inside the level:
;             he cannot go left of the camera or past the right end.
;             Hitting either limit stops his horizontal speed.
; Inputs    : on the stack, pushed in this order: address of the hero
;             record, camera_x. Removed by RET 4.
; Outputs   : hero_x, hero_x_frac, hero_vx (zeroed at a limit)
; Registers : none changed (all registers are preserved)
; =============================================================
MoveHeroX:
    push bp
    mov bp, sp
    push ax
    push bx
    push si

    mov si, [bp + 6]                ; hero record

    ; --- add the velocity: AddFixed(&x, &x_frac, vx) ---
    mov ax, si
    add ax, H_X
    push ax
    mov ax, si
    add ax, H_XFRAC
    push ax
    push word [si + H_VX]
    call AddFixed

    ; --- left wall: Mario cannot go left of the camera ---
    mov ax, [bp + 4]                ; camera_x
    cmp [si + H_X], ax
    jge .check_right                ; signed compare: still inside
    mov [si + H_X], ax
    mov byte [si + H_XFRAC], 0
    mov word [si + H_VX], 0

    ; --- right end of the level: last column starts at 944 ---
.check_right:
    cmp word [si + H_X], LEVEL_WIDTH_PX - TILE_SIZE
    jle .done
    mov word [si + H_X], LEVEL_WIDTH_PX - TILE_SIZE
    mov byte [si + H_XFRAC], 0
    mov word [si + H_VX], 0

.done:
    pop si
    pop bx
    pop ax
    pop bp
    ret 4

; =============================================================
; Procedure : MoveHeroY
; Purpose   : Adds hero_vy to the vertical position (whole pixels
;             plus fraction). Floor, ceiling and pit handling are
;             done by the collision procedures, not here.
; Inputs    : on the stack: address of the hero record. Removed by RET 2.
; Outputs   : hero_y, hero_y_frac
; Registers : none changed (all registers are preserved)
; =============================================================
MoveHeroY:
    push bp
    mov bp, sp
    push ax
    push bx

    mov bx, [bp + 4]                ; hero record
    mov ax, bx
    add ax, H_Y
    push ax
    mov ax, bx
    add ax, H_YFRAC
    push ax
    push word [bx + H_VY]
    call AddFixed

    pop bx
    pop ax
    pop bp
    ret 2

; =============================================================
; Procedure : UpdateHeroPose
; Purpose   : Chooses the sprite pose: jumping in the air, running
;             while moving on the ground, standing when still.
; Inputs    : on the stack: address of the hero record. Removed by RET 2.
; Outputs   : hero_pose
; Registers : none changed (all registers are preserved)
; =============================================================
UpdateHeroPose:
    push bp
    mov bp, sp
    push bx

    mov bx, [bp + 4]
    cmp byte [bx + H_ONGROUND], 0
    je .air
    cmp word [bx + H_VX], 0
    je .stand
    mov byte [bx + H_POSE], POSE_RUN
    jmp .done
.air:
    mov byte [bx + H_POSE], POSE_JUMP
    jmp .done
.stand:
    mov byte [bx + H_POSE], POSE_STAND

.done:
    pop bx
    pop bp
    ret 2

; =============================================================
; Procedure : GetBodyHeight
; Purpose   : Returns Mario's body height: 16 (small) or 32 (super).
; Inputs    : on the stack: address of the hero record. Removed by RET 2.
; Outputs   : AX = 16 or 32
; Registers : none changed except AX
; =============================================================
GetBodyHeight:
    push bp
    mov bp, sp
    push bx

    mov bx, [bp + 4]
    mov ax, 16
    cmp byte [bx + H_FORM], FORM_SUPER
    jne .done
    mov ax, 32

.done:
    pop bx
    pop bp
    ret 2

; =============================================================
; Procedure : GetTile
; Purpose   : Returns the tile code of the working map at a pixel
;             position. Outside the level on the left or right the
;             result is TILE_GROUND (an invisible solid wall); above
;             the top or below the bottom it is TILE_SKY (so Mario
;             can jump above the map and fall into a pit).
; Inputs    : on the stack: px (pushed first), py (pushed second),
;             both signed words in world pixels. Removed by RET 4.
; Outputs   : AX = tile code (high byte zero)
; Registers : none changed except AX (BX, CX, DX, BP preserved)
; =============================================================
GetTile:
    push bp
    mov bp, sp
    push bx
    push cx
    push dx

    mov ax, [bp + 6]                ; px
    mov bx, [bp + 4]                ; py

    ; --- outside the level horizontally: solid wall ---
    cmp ax, 0
    jl .solid
    cmp ax, LEVEL_WIDTH_PX
    jge .solid

    ; --- outside the map vertically: sky ---
    cmp bx, 0
    jl .sky
    cmp bx, MAP_ROWS * TILE_SIZE
    jge .sky

    ; --- pixel position to tile column and row (divide by 16) ---
    mov cl, 4
    shr ax, cl                      ; AX = column
    shr bx, cl                      ; BX = row

    ; --- index = row * MAP_COLS + column ---
    push ax                         ; keep the column
    mov ax, MAP_COLS
    mul bx                          ; DX:AX = row * MAP_COLS
    pop bx                          ; BX = column
    add ax, bx
    mov bx, ax                      ; BX = index into the map
    mov al, [level_working + bx]    ; based addressing: label + register
    xor ah, ah
    jmp .done

.solid:
    mov ax, TILE_GROUND
    jmp .done
.sky:
    mov ax, TILE_SKY

.done:
    pop dx
    pop cx
    pop bx
    pop bp
    ret 4                           ; return and remove the two parameters

; =============================================================
; Procedure : SetTile
; Purpose   : Writes a tile code into the working map at a pixel
;             position. Positions outside the map are ignored.
; Inputs    : on the stack: px, py, code (pushed in this order).
;             Removed by RET 6.
; Outputs   : level_working
; Registers : none changed (all registers are preserved)
; =============================================================
SetTile:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx

    mov ax, [bp + 8]                ; px
    mov bx, [bp + 6]                ; py
    cmp ax, 0
    jl .done
    cmp ax, LEVEL_WIDTH_PX
    jge .done
    cmp bx, 0
    jl .done
    cmp bx, MAP_ROWS * TILE_SIZE
    jge .done

    ; --- same pixel to index conversion as GetTile ---
    mov cl, 4
    shr ax, cl                      ; column
    shr bx, cl                      ; row
    push ax
    mov ax, MAP_COLS
    mul bx                          ; AX = row * MAP_COLS
    pop bx                          ; BX = column
    add ax, bx
    mov bx, ax                      ; BX = index
    mov al, [bp + 4]                ; the new tile code
    mov [level_working + bx], al

.done:
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 6

; =============================================================
; Procedure : ResetMap
; Purpose   : Restores the working map from the original map with
;             one block move (REP MOVSB). Used when a level or a
;             new game starts.
; Inputs    : level_original (defined in Person 1's leveldata.inc)
; Outputs   : level_working (MAP_SIZE bytes overwritten)
; Registers : none changed (flags, including DF, are preserved)
; Note      : needs DS = ES, which is always true in a .COM program
; =============================================================
ResetMap:
    pushf
    push cx
    push si
    push di

    cld                             ; copy forwards
    mov si, level_original          ; source
    mov di, level_working           ; destination
    mov cx, MAP_SIZE                ; number of bytes
    rep movsb                       ; copy all bytes in one instruction

    pop di
    pop si
    pop cx
    popf
    ret

; =============================================================
; Procedure : IsSolidAt
; Purpose   : Tells whether the tile at a world pixel position
;             blocks Mario. Solid tiles are codes TILE_GROUND (1)
;             up to TILE_STAIR (10): ground, bricks, blocks,
;             pipes and stairs. Sky, coins and the flag are not
;             solid. Positions outside the level follow GetTile
;             (side walls solid, above/below the map not solid).
; Inputs    : on the stack: px (pushed first), py (pushed second),
;             both signed words in world pixels. Removed by RET 4.
; Outputs   : AX = 1 if solid, 0 if not
; Registers : none changed except AX
; =============================================================
IsSolidAt:
    push bp
    mov bp, sp

    ; --- ask GetTile: pass the same two parameters, same order ---
    push word [bp + 6]              ; px
    push word [bp + 4]              ; py
    call GetTile                    ; AX = tile code (GetTile cleans the stack)

    ; --- solid only if 1 <= tile <= 10 ---
    cmp ax, TILE_GROUND
    jb .not_solid                   ; unsigned below: sky (0)
    cmp ax, TILE_STAIR
    ja .not_solid                   ; above 10: coin or flag
    mov ax, 1
    jmp .done

.not_solid:
    xor ax, ax

.done:
    pop bp
    ret 4                           ; return and remove px and py

; =============================================================
; Procedure : IsBodyBlockedAtX
; Purpose   : Checks one vertical line of Mario's body at world
;             column px. Tests three points: bottom (feet-1),
;             middle and top, where the height is 16 (small) or
;             32 (super). Points are at most 16 pixels apart, so
;             no tile row is skipped.
; Inputs    : on the stack, pushed in this order: address of the
;             hero record, px (signed word, world pixels).
;             Removed by RET 4.
; Outputs   : AX = 1 if any of the three points is solid, else 0
; Registers : none changed except AX
; =============================================================
IsBodyBlockedAtX:
    push bp
    mov bp, sp
    push bx
    push cx
    push si

    mov si, [bp + 6]                ; hero record
    push si
    call GetBodyHeight
    mov cx, ax                      ; CX = body height

    ; --- point 1: bottom (feet - 1) ---
    mov bx, [si + H_Y]
    dec bx
    push word [bp + 4]              ; px
    push bx                         ; py
    call IsSolidAt
    cmp ax, 0
    jne .done                       ; solid found: AX is already 1

    ; --- point 2: middle (feet - height / 2) ---
    mov bx, [si + H_Y]
    mov ax, cx
    shr ax, 1                       ; half the height
    sub bx, ax
    push word [bp + 4]
    push bx
    call IsSolidAt
    cmp ax, 0
    jne .done

    ; --- point 3: top (feet - height); AX is the final answer ---
    mov bx, [si + H_Y]
    sub bx, cx
    push word [bp + 4]
    push bx
    call IsSolidAt

.done:
    pop si
    pop cx
    pop bx
    pop bp
    ret 4

; =============================================================
; Procedure : ResolveHeroX
; Purpose   : After MoveHeroX, pushes Mario out of walls. Moving
;             right it checks the right edge of his 12 pixel box,
;             moving left the left edge. If blocked, his position is
;             snapped so the box touches the wall, and his
;             horizontal speed is stopped.
; Inputs    : on the stack: address of the hero record. Removed by RET 2.
; Outputs   : hero_x, hero_x_frac, hero_vx (zeroed when blocked)
; Registers : none changed (all registers are preserved)
; =============================================================
ResolveHeroX:
    push bp
    mov bp, sp
    push ax
    push bx
    push si

    mov si, [bp + 4]                ; hero record

    ; --- which way is Mario moving? ---
    mov ax, [si + H_VX]
    cmp ax, 0
    jg .right
    jl .left
    jmp .done                       ; standing still: nothing to resolve

    ; --- moving right: test the right edge of the box (hero_x + 13) ---
.right:
    mov bx, [si + H_X]
    add bx, HITBOX_RIGHT
    push si
    push bx
    call IsBodyBlockedAtX
    cmp ax, 0
    je .done                        ; free: keep the new position
    and bx, 0FFF0h                  ; left edge of the wall's tile column
    sub bx, HITBOX_RIGHT + 1        ; box edge touches the wall: x = column - 14
    jmp .stop

    ; --- moving left: test the left edge of the box (hero_x + 2) ---
.left:
    mov bx, [si + H_X]
    add bx, HITBOX_LEFT
    push si
    push bx
    call IsBodyBlockedAtX
    cmp ax, 0
    je .done
    and bx, 0FFF0h                  ; left edge of the wall's tile column
    add bx, TILE_SIZE - HITBOX_LEFT ; box edge touches the wall: x = column + 14

    ; --- blocked: snap position and stop moving ---
.stop:
    mov [si + H_X], bx
    mov byte [si + H_XFRAC], 0
    mov word [si + H_VX], 0

.done:
    pop si
    pop bx
    pop ax
    pop bp
    ret 2

; =============================================================
; Procedure : ResolveHeroY
; Purpose   : After MoveHeroY, handles floors and ceilings. When
;             falling or still, tests the two bottom corners of the
;             12 pixel box at the feet row: if solid, Mario lands (feet
;             snapped to the tile top, vy = 0, on_ground = 1, stomp
;             chain reset); if not, on_ground = 0. When rising, tests
;             the two top corners: if either is solid his head hits the
;             ceiling. The block hit is the tile under the horizontal
;             centre of his head (HitBlockAt, Section 5.9); the top is
;             then snapped just below the tile and vy = 0.
; Inputs    : on the stack: address of the hero record. Removed by RET 2.
; Outputs   : hero_y, hero_y_frac, hero_vy, hero_on_ground,
;             hero_stomp_chain, level_working (block hit)
; Registers : none changed (all registers are preserved)
; =============================================================
ResolveHeroY:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si

    mov si, [bp + 4]                ; hero record
    push si
    call GetBodyHeight
    mov cx, ax                      ; CX = body height (16 small, 32 super)

    cmp word [si + H_VY], 0
    jl .rising

    ; --- falling or still: test the feet row at both bottom corners ---
    mov bx, [si + H_Y]              ; py = feet
    mov ax, [si + H_X]
    add ax, HITBOX_LEFT
    push ax
    push bx
    call IsSolidAt
    cmp ax, 0
    jne .land
    mov ax, [si + H_X]
    add ax, HITBOX_RIGHT
    push ax
    push bx
    call IsSolidAt
    cmp ax, 0
    jne .land
    mov byte [si + H_ONGROUND], 0   ; nothing under him: in the air
    jmp .done

    ; --- landed: feet on top of the tile that was hit ---
.land:
    and bx, 0FFF0h
    mov [si + H_Y], bx
    mov byte [si + H_YFRAC], 0
    mov word [si + H_VY], 0
    mov byte [si + H_ONGROUND], 1
    mov byte [si + H_STOMPCHAIN], 0
    jmp .done

    ; --- rising: test Mario's top pixel row at both top corners ---
.rising:
    mov bx, [si + H_Y]
    sub bx, cx                      ; BX = py of Mario's top row
    mov ax, [si + H_X]
    add ax, HITBOX_LEFT
    push ax
    push bx
    call IsSolidAt
    cmp ax, 0
    jne .bump
    mov ax, [si + H_X]
    add ax, HITBOX_RIGHT
    push ax
    push bx
    call IsSolidAt
    cmp ax, 0
    je .done                        ; nothing above: keep rising

    ; --- head hit: block under the centre of the head, then snap ---
.bump:
    mov dx, [si + H_X]
    add dx, TILE_SIZE / 2           ; px = horizontal centre of the head
    mov al, [si + H_FORM]
    xor ah, ah
    push ax                         ; form (a brick breaks only for Super)
    push dx
    push bx                         ; py = top row of Mario
    call HitBlockAt                 ; preserves BX and DX
    and bx, 0FFF0h                  ; top edge of the ceiling tile
    add bx, TILE_SIZE               ; bottom edge of the ceiling tile
    add bx, cx                      ; feet = that + body height
    mov [si + H_Y], bx
    mov byte [si + H_YFRAC], 0
    mov word [si + H_VY], 0

.done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 2

; =============================================================
; Procedure : RectsOverlap
; Purpose   : Tells whether two rectangles overlap. Each is given
;             as left, top, right, bottom in world pixels, where
;             right and bottom are the first pixel OUTSIDE the box.
;             Boxes that only touch at an edge do not overlap.
; Inputs    : on the stack, pushed in this order (signed words):
;             aLeft, aTop, aRight, aBottom,
;             bLeft, bTop, bRight, bBottom. Removed by RET 16.
; Outputs   : AX = 1 if they overlap, else 0
; Registers : none changed except AX
; =============================================================
RectsOverlap:
    push bp
    mov bp, sp

    ; --- horizontal: aLeft < bRight and bLeft < aRight ---
    mov ax, [bp + 18]               ; aLeft
    cmp ax, [bp + 6]                ; bRight
    jge .no
    mov ax, [bp + 10]               ; bLeft
    cmp ax, [bp + 14]               ; aRight
    jge .no

    ; --- vertical: aTop < bBottom and bTop < aBottom ---
    mov ax, [bp + 16]               ; aTop
    cmp ax, [bp + 4]                ; bBottom
    jge .no
    mov ax, [bp + 8]                ; bTop
    cmp ax, [bp + 12]               ; aBottom
    jge .no

    mov ax, 1                       ; all four held: overlap
    jmp .done

.no:
    xor ax, ax

.done:
    pop bp
    ret 16                          ; remove the eight parameters

; =============================================================
; Procedure : IsStomp
; Purpose   : The stomp test of Section 5.6: Mario is moving down and
;             in the previous frame his feet were above the upper half
;             of the enemy. Anything else is a side or bottom contact.
; Inputs    : on the stack, pushed in this order (signed words):
;             Mario's feet in the previous frame, Mario's vertical
;             speed, the enemy's feet. Removed by RET 6.
; Outputs   : AX = 1 for a stomp, 0 for a hurting contact
; Registers : none changed except AX
; =============================================================
IsStomp:
    push bp
    mov bp, sp

    cmp word [bp + 6], 0
    jle .no                         ; not moving down
    mov ax, [bp + 4]                ; enemy feet
    sub ax, TILE_SIZE / 2           ; middle of the enemy
    cmp [bp + 8], ax                ; previous feet against the middle
    jg .no                          ; feet were already in the lower half
    mov ax, 1
    jmp .done

.no:
    xor ax, ax

.done:
    pop bp
    ret 6

; =============================================================
; Procedure : UpdateCamera
; Purpose   : Camera follows Mario once he passes the screen
;             middle. It never scrolls back left and stops at the
;             right end of the level (Section 5.3 rule).
; Inputs    : on the stack, pushed in this order: hero_x, camera_x.
;             Removed by RET 4.
; Outputs   : AX = the new camera_x
; Registers : none changed except AX
; =============================================================
UpdateCamera:
    push bp
    mov bp, sp

    mov ax, [bp + 6]                ; hero_x
    sub ax, SCREEN_MID_X            ; camera position that centres Mario
    cmp ax, [bp + 4]
    jg .limit                       ; ahead of the camera: follow
    mov ax, [bp + 4]                ; otherwise keep the old camera
.limit:
    cmp ax, MAX_CAMERA_X
    jle .done
    mov ax, MAX_CAMERA_X

.done:
    pop bp
    ret 4

; =============================================================
; Procedure : AddScore
; Purpose   : Adds a 32-bit amount to score (ADD then ADC for the
;             carry) and limits the result to MAX_SCORE.
; Inputs    : on the stack: high word of the amount (pushed first),
;             low word (pushed second). Removed by RET 4.
; Outputs   : score
; Registers : none changed (all registers are preserved)
; =============================================================
AddScore:
    push bp
    mov bp, sp
    push ax
    push dx

    mov ax, [bp + 4]                ; low word of the amount
    mov dx, [bp + 6]                ; high word of the amount
    add [score], ax                 ; low words, carry goes to CF
    adc [score + 2], dx             ; high words plus the carry

    ; --- clamp: is score above MAX_SCORE? (unsigned compares) ---
    mov ax, [score + 2]
    cmp ax, MAX_SCORE / 65536
    jb .done                        ; high word smaller: fine
    ja .clamp                       ; high word bigger: too big
    cmp word [score], MAX_SCORE % 65536
    jbe .done                       ; same high word, low word fits
.clamp:
    mov word [score], MAX_SCORE % 65536
    mov word [score + 2], MAX_SCORE / 65536

.done:
    pop dx
    pop ax
    pop bp
    ret 4

; =============================================================
; Procedure : AddLife
; Purpose   : Adds one life, never above MAX_LIVES.
; Inputs    : on the stack: address of the lives byte. Removed by RET 2.
; Outputs   : lives
; Registers : none changed (flags only)
; =============================================================
AddLife:
    push bp
    mov bp, sp
    push bx

    mov bx, [bp + 4]                ; address of lives
    cmp byte [bx], MAX_LIVES
    jae .done
    inc byte [bx]
.done:
    pop bx
    pop bp
    ret 2

; =============================================================
; Procedure : AddCoin
; Purpose   : Counts one collected coin and adds SCORE_COIN. When
;             coins reach 100 they reset to 0 and give a life.
; Inputs    : on the stack, pushed in this order:
;               [bp + 6] address of the coins byte
;               [bp + 4] address of the lives byte
;             Removed by RET 4.
; Outputs   : coins, lives, score
; Registers : none changed (flags only)
; =============================================================
AddCoin:
    push bp
    mov bp, sp
    push bx

    mov bx, [bp + 6]                ; address of coins
    inc byte [bx]
    push word 0                     ; score amount, high word
    push word SCORE_COIN            ; score amount, low word
    call AddScore
    cmp byte [bx], 100
    jb .done
    mov byte [bx], 0
    push word [bp + 4]              ; address of lives
    call AddLife
.done:
    pop bx
    pop bp
    ret 4

; =============================================================
; Procedure : UpdateClock
; Purpose   : Called once per frame while playing. Counts ticks;
;             every TICKS_PER_SECOND frames time_left drops by 1.
; Inputs    : on the stack, pushed in this order:
;               [bp + 6] address of the clock_ticks byte
;               [bp + 4] address of the time_left word
;             Removed by RET 4.
; Outputs   : clock_ticks, time_left
;             AX = 1 when the time has just reached 0 (Mario must
;             die), else 0
; Registers : none changed except AX
; =============================================================
UpdateClock:
    push bp
    mov bp, sp
    push bx

    xor ax, ax
    mov bx, [bp + 6]                ; address of clock_ticks
    inc byte [bx]
    cmp byte [bx], TICKS_PER_SECOND
    jb .done
    mov byte [bx], 0                ; one second passed
    mov bx, [bp + 4]                ; address of time_left
    cmp word [bx], 0
    je .done
    dec word [bx]
    jne .done                       ; still time left
    mov ax, 1                       ; time ran out
.done:
    pop bx
    pop bp
    ret 4

; =============================================================
; Procedure : UpdateInvuln
; Purpose   : Counts the hero's invulnerability down by 1 per frame.
; Inputs    : on the stack: address of the hero record. Removed by RET 2.
; Outputs   : hero_invuln
; Registers : none changed (all registers are preserved)
; =============================================================
UpdateInvuln:
    push bp
    mov bp, sp
    push bx

    mov bx, [bp + 4]
    cmp byte [bx + H_INVULN], 0
    je .done
    dec byte [bx + H_INVULN]

.done:
    pop bx
    pop bp
    ret 2

; =============================================================
; Procedure : HurtHero
; Purpose   : Mario is hit by an enemy. Ignored while invulnerable.
;             Super Mario shrinks to small and becomes invulnerable
;             for INVULN_FRAMES (his feet stay where they are); small
;             Mario must die.
; Inputs    : on the stack: address of the hero record. Removed by RET 2.
; Outputs   : hero_form, hero_hp, hero_invuln
;             AX = 1 if Mario dies (the caller starts the death), else 0
; Registers : none changed except AX
; =============================================================
HurtHero:
    push bp
    mov bp, sp
    push bx

    mov bx, [bp + 4]
    xor ax, ax
    cmp byte [bx + H_INVULN], 0
    jne .done                       ; blinking: cannot be hurt
    cmp byte [bx + H_FORM], FORM_SUPER
    jne .die
    mov byte [bx + H_FORM], FORM_SMALL
    mov byte [bx + H_HP], HP_SMALL
    mov byte [bx + H_INVULN], INVULN_FRAMES
    jmp .done
.die:
    mov ax, 1

.done:
    pop bx
    pop bp
    ret 2

; =============================================================
; Procedure : CheckPit
; Purpose   : Mario dies when the TOP of his body has passed below
;             the bottom of the map (Section 5.6: y >= 192), so he
;             is completely out of the picture.
; Inputs    : on the stack: address of the hero record. Removed by RET 2.
; Outputs   : AX = 1 if he has fallen into a pit, else 0
; Registers : none changed except AX
; =============================================================
CheckPit:
    push bp
    mov bp, sp
    push bx

    mov bx, [bp + 4]
    push bx
    call GetBodyHeight
    mov bx, [bx + H_Y]
    sub bx, ax                      ; BX = top of Mario
    cmp bx, PIT_Y                   ; signed compare
    jl .no
    mov ax, 1
    jmp .done
.no:
    xor ax, ax

.done:
    pop bx
    pop bp
    ret 2

; =============================================================
; Procedure : TileInBodyColumn
; Purpose   : Checks one vertical line of Mario's body (bottom,
;             middle and top points) for a given tile code.
; Inputs    : on the stack, pushed in this order: address of the hero
;             record, px, tile code. Removed by RET 6.
; Outputs   : AX = 1 if one of the three points holds the tile
; Registers : none changed except AX
; =============================================================
TileInBodyColumn:
    push bp
    mov bp, sp
    push bx
    push cx
    push dx
    push si

    mov si, [bp + 8]                ; hero record
    push si
    call GetBodyHeight
    mov cx, ax                      ; CX = body height
    mov dx, [bp + 4]                ; DX = wanted tile code

    mov bx, [si + H_Y]              ; bottom: feet - 1
    dec bx
    push word [bp + 6]
    push bx
    call GetTile
    cmp ax, dx
    je .yes

    mov bx, [si + H_Y]              ; middle: feet - height / 2
    mov ax, cx
    shr ax, 1
    sub bx, ax
    push word [bp + 6]
    push bx
    call GetTile
    cmp ax, dx
    je .yes

    mov bx, [si + H_Y]              ; top: feet - height
    sub bx, cx
    push word [bp + 6]
    push bx
    call GetTile
    cmp ax, dx
    je .yes

    xor ax, ax
    jmp .done
.yes:
    mov ax, 1

.done:
    pop si
    pop dx
    pop cx
    pop bx
    pop bp
    ret 6

; =============================================================
; Procedure : CheckFlag
; Purpose   : Tells whether any part of Mario's 12 pixel box touches
;             a flag pole tile (left and right edge columns of the box,
;             three heights each).
; Inputs    : on the stack: address of the hero record. Removed by RET 2.
; Outputs   : AX = 1 if the pole is touched, else 0
;             DX = left edge of the pole column (0 when AX = 0)
; Registers : none changed except AX and DX
; =============================================================
CheckFlag:
    push bp
    mov bp, sp
    push bx
    push si

    mov si, [bp + 4]                ; hero record

    ; --- left edge column of the box, then right edge column ---
    mov bx, [si + H_X]
    add bx, HITBOX_LEFT
    push si
    push bx
    push word TILE_FLAG
    call TileInBodyColumn
    cmp ax, 0
    jne .hit
    mov bx, [si + H_X]
    add bx, HITBOX_RIGHT
    push si
    push bx
    push word TILE_FLAG
    call TileInBodyColumn
    cmp ax, 0
    je .miss                        ; no flag tile touched

    ; --- touched: DX = left edge of the column that holds the pole ---
.hit:
    and bx, 0FFF0h
    mov dx, bx
    mov ax, 1
    jmp .done

.miss:
    xor dx, dx                      ; AX is already 0

.done:
    pop si
    pop bx
    pop bp
    ret 2

; =============================================================
; Procedure : FindFreeEntity
; Purpose   : Searches the entities table for an empty slot
;             (type = ENT_NONE).
; Inputs    : entities
; Outputs   : AX = address of the free slot, or 0 if none
; Registers : none changed except AX
; =============================================================
FindFreeEntity:
    push bx
    push cx

    mov bx, entities                ; first slot
    mov cx, MAX_ENTITIES            ; LOOP counts CX down
.next:
    cmp byte [bx + ENT_TYPE], ENT_NONE
    je .found
    add bx, ENT_SIZE                ; next slot
    loop .next                      ; CX = CX - 1, repeat while CX != 0
    xor ax, ax                      ; table full
    jmp .done
.found:
    mov ax, bx
.done:
    pop cx
    pop bx
    ret

; =============================================================
; Procedure : SpawnMushroom
; Purpose   : Creates a mushroom standing on top of the block at
;             the given pixel, moving right.
; Inputs    : on the stack: px, py (any pixel inside the block).
;             Removed by RET 4.
; Outputs   : one entity slot filled (nothing if table is full)
; Registers : none changed (all registers are preserved)
; =============================================================
SpawnMushroom:
    push bp
    mov bp, sp
    push ax
    push bx

    call FindFreeEntity
    cmp ax, 0
    je .done                        ; no free slot
    mov bx, ax                      ; BX = the new record
    mov byte [bx + ENT_TYPE], ENT_MUSHROOM
    mov byte [bx + ENT_STATE], ES_WALKING
    mov byte [bx + ENT_DIR], FACE_RIGHT
    mov byte [bx + ENT_TIMER], 0
    mov byte [bx + ENT_X_FRAC], 0
    mov byte [bx + ENT_Y_FRAC], 0
    mov ax, [bp + 6]                ; px
    and ax, 0FFF0h                  ; left edge of the block
    mov [bx + ENT_X], ax
    mov ax, [bp + 4]                ; py
    and ax, 0FFF0h                  ; top of the block = mushroom feet
    mov [bx + ENT_Y], ax
    mov word [bx + ENT_VX], MUSHROOM_SPEED
    mov word [bx + ENT_VY], 0

.done:
    pop bx
    pop ax
    pop bp
    ret 4

; =============================================================
; Procedure : HitBlockAt
; Purpose   : Mario's head hit the tile at this pixel. ? coin block:
;             becomes empty, gives a coin. ? mushroom block: becomes
;             empty, spawns a mushroom. Brick: broken (tile becomes
;             sky, SCORE_BRICK) only when Mario is super. Anything
;             else: nothing happens.
; Inputs    : on the stack, pushed in this order: Mario's form
;             (FORM_SMALL / FORM_SUPER), px, py. Removed by RET 6.
; Outputs   : level_working, coins, score, entities
; Registers : none changed (all registers are preserved)
; =============================================================
HitBlockAt:
    push bp
    mov bp, sp
    push ax

    push word [bp + 6]
    push word [bp + 4]
    call GetTile                    ; AX = the tile that was hit
    cmp ax, TILE_Q_COIN
    je .q_coin
    cmp ax, TILE_Q_MUSHROOM
    je .q_mushroom
    cmp ax, TILE_BRICK
    jne .done

    ; --- brick: only super Mario breaks it ---
    cmp word [bp + 8], FORM_SUPER
    jne .done
    push word [bp + 6]
    push word [bp + 4]
    push word TILE_SKY
    call SetTile
    push word 0
    push word SCORE_BRICK
    call AddScore
    jmp .done

.q_coin:
    push word [bp + 6]
    push word [bp + 4]
    push word TILE_EMPTY
    call SetTile
    push word coins                 ; address of the coin counter
    push word lives                 ; address of the lives counter
    call AddCoin
    jmp .done

.q_mushroom:
    push word [bp + 6]
    push word [bp + 4]
    push word TILE_EMPTY
    call SetTile
    push word [bp + 6]
    push word [bp + 4]
    call SpawnMushroom

.done:
    pop ax
    pop bp
    ret 6

; =============================================================
; Procedure : TryCollectCoin
; Purpose   : If the tile at the pixel is a coin, turns it into sky
;             and counts it (AddCoin).
; Inputs    : on the stack: px, py (pushed in this order). RET 4.
; Outputs   : level_working, coins, lives, score
; Registers : none changed (all registers are preserved)
; =============================================================
TryCollectCoin:
    push bp
    mov bp, sp
    push ax

    push word [bp + 6]
    push word [bp + 4]
    call GetTile
    cmp ax, TILE_COIN
    jne .done
    push word [bp + 6]
    push word [bp + 4]
    push word TILE_SKY
    call SetTile
    push word coins                 ; address of the coin counter
    push word lives                 ; address of the lives counter
    call AddCoin

.done:
    pop ax
    pop bp
    ret 4

; =============================================================
; Procedure : CollectCoinsColumn
; Purpose   : Tries to collect coins along one vertical line of
;             Mario's body (bottom, middle and top points).
; Inputs    : on the stack, pushed in this order: address of the hero
;             record, px. Removed by RET 4.
; Outputs   : level_working, coins, lives, score
; Registers : none changed (all registers are preserved)
; =============================================================
CollectCoinsColumn:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push si

    mov si, [bp + 6]                ; hero record
    push si
    call GetBodyHeight
    mov cx, ax                      ; CX = body height

    mov bx, [si + H_Y]              ; bottom: feet - 1
    dec bx
    push word [bp + 4]
    push bx
    call TryCollectCoin

    mov bx, [si + H_Y]              ; middle: feet - height / 2
    mov ax, cx
    shr ax, 1
    sub bx, ax
    push word [bp + 4]
    push bx
    call TryCollectCoin

    mov bx, [si + H_Y]              ; top: feet - height
    sub bx, cx
    push word [bp + 4]
    push bx
    call TryCollectCoin

    pop si
    pop cx
    pop bx
    pop ax
    pop bp
    ret 4

; =============================================================
; Procedure : CollectCoins
; Purpose   : Picks up coin tiles that Mario touches. Tests the two
;             side columns of his 12 pixel box at three heights, so a
;             coin touched at the side is collected.
; Inputs    : on the stack: address of the hero record. Removed by RET 2.
; Outputs   : level_working, coins, lives, score
; Registers : none changed (all registers are preserved)
; =============================================================
CollectCoins:
    push bp
    mov bp, sp
    push ax
    push si

    mov si, [bp + 4]                ; hero record
    push si
    mov ax, [si + H_X]
    add ax, HITBOX_LEFT
    push ax
    call CollectCoinsColumn
    push si
    mov ax, [si + H_X]
    add ax, HITBOX_RIGHT
    push ax
    call CollectCoinsColumn

    pop si
    pop ax
    pop bp
    ret 2

; =============================================================
; Procedure : RemoveEntity
; Purpose   : Empties one entity slot (all ENT_SIZE bytes become 0,
;             so the type is ENT_NONE) with REP STOSB.
; Inputs    : on the stack: the address of the record. RET 2.
; Outputs   : the record
; Registers : none changed (flags, including DF, are preserved)
; Note      : needs DS = ES
; =============================================================
RemoveEntity:
    push bp
    mov bp, sp
    pushf
    push ax
    push cx
    push di

    cld
    mov di, [bp + 4]                ; the record
    mov cx, ENT_SIZE
    xor al, al
    rep stosb                       ; fill the record with zeros

    pop di
    pop cx
    pop ax
    popf
    pop bp
    ret 2

; =============================================================
; Procedure : CountActiveEnemies
; Purpose   : Counts Goombas and Koopas that have been activated
;             (state is not ES_WAITING). Used for the limit of 8.
; Inputs    : on the stack: address of the entity table. Removed by RET 2.
; Outputs   : AX = number of active enemies
; Registers : none changed except AX
; =============================================================
CountActiveEnemies:
    push bp
    mov bp, sp
    push bx
    push cx
    push dx

    xor dx, dx                      ; DX = the count
    mov bx, [bp + 4]                ; address of the entity table
    mov cx, MAX_ENTITIES
.next:
    mov al, [bx + ENT_TYPE]
    cmp al, ENT_GOOMBA
    je .enemy
    cmp al, ENT_KOOPA
    jne .skip
.enemy:
    cmp byte [bx + ENT_STATE], ES_WAITING
    je .skip
    inc dx
.skip:
    add bx, ENT_SIZE
    loop .next
    mov ax, dx

    pop dx
    pop cx
    pop bx
    pop bp
    ret 2

; =============================================================
; Procedure : EntityBlockedAtX
; Purpose   : Tells whether the entity's body is blocked at a world
;             column: tests the bottom point (feet-1) and the top
;             point (feet-16).
; Inputs    : on the stack: record address (pushed first), px
;             (pushed second). RET 4.
; Outputs   : AX = 1 if blocked, else 0
; Registers : none changed except AX
; =============================================================
EntityBlockedAtX:
    push bp
    mov bp, sp
    push bx

    mov bx, [bp + 6]                ; the record
    mov ax, [bx + ENT_Y]
    dec ax                          ; bottom point
    push word [bp + 4]
    push ax
    call IsSolidAt
    cmp ax, 0
    jne .done
    mov ax, [bx + ENT_Y]
    sub ax, TILE_SIZE               ; top point
    push word [bp + 4]
    push ax
    call IsSolidAt

.done:
    pop bx
    pop bp
    ret 4

; =============================================================
; Procedure : EntityStepX
; Purpose   : Moves an entity horizontally by its ENT_VX (whole
;             pixels plus fraction). If the leading edge hits a wall
;             (or the end of the level) it is snapped to the tile
;             edge and turns around (VX negated, direction flipped).
; Inputs    : on the stack: the record address. RET 2.
; Outputs   : ENT_X, ENT_X_FRAC, ENT_VX, ENT_DIR
; Registers : none changed (all registers are preserved)
; =============================================================
EntityStepX:
    push bp
    mov bp, sp
    push ax
    push bx
    push dx

    mov bx, [bp + 4]

    ; --- move: AddFixed(&x, &x_frac, vx) ---
    mov ax, bx
    add ax, ENT_X
    push ax
    mov ax, bx
    add ax, ENT_X_FRAC
    push ax
    push word [bx + ENT_VX]
    call AddFixed

    mov ax, [bx + ENT_VX]
    cmp ax, 0
    jg .right
    jl .left
    jmp .done                       ; not moving

.right:
    mov dx, [bx + ENT_X]
    add dx, TILE_SIZE - 1           ; right edge pixel
    push bx
    push dx
    call EntityBlockedAtX
    cmp ax, 0
    je .done
    and dx, 0FFF0h                  ; left edge of the wall's column
    sub dx, TILE_SIZE               ; entity's left edge: one tile to the left
    jmp .bounce

.left:
    mov dx, [bx + ENT_X]            ; left edge pixel
    push bx
    push dx
    call EntityBlockedAtX
    cmp ax, 0
    je .done
    and dx, 0FFF0h
    add dx, TILE_SIZE               ; entity's left edge: right of the wall

.bounce:
    mov [bx + ENT_X], dx
    mov byte [bx + ENT_X_FRAC], 0
    neg word [bx + ENT_VX]          ; turn around
    xor byte [bx + ENT_DIR], 1      ; FACE_RIGHT <-> FACE_LEFT

.done:
    pop dx
    pop bx
    pop ax
    pop bp
    ret 2

; =============================================================
; Procedure : EntityStepY
; Purpose   : Gravity for an entity: adds GRAVITY to ENT_VY (capped
;             at MAX_FALL_SPEED), moves it down and lands it on the
;             first solid tile under its two bottom corners.
; Inputs    : on the stack: the record address. RET 2.
; Outputs   : AX = 1 if the entity stands on the ground, else 0
;             ENT_Y, ENT_Y_FRAC, ENT_VY
; Registers : none changed except AX
; =============================================================
EntityStepY:
    push bp
    mov bp, sp
    push bx
    push dx

    mov bx, [bp + 4]
    mov ax, [bx + ENT_VY]
    add ax, GRAVITY
    cmp ax, MAX_FALL_SPEED
    jle .speed_ok
    mov ax, MAX_FALL_SPEED
.speed_ok:
    mov [bx + ENT_VY], ax

    ; --- move: AddFixed(&y, &y_frac, vy) ---
    mov dx, bx
    add dx, ENT_Y
    push dx
    mov dx, bx
    add dx, ENT_Y_FRAC
    push dx
    push ax
    call AddFixed

    mov dx, [bx + ENT_Y]            ; DX = feet row
    mov ax, [bx + ENT_X]
    add ax, 2                       ; left foot
    push ax
    push dx
    call IsSolidAt
    cmp ax, 0
    jne .land
    mov ax, [bx + ENT_X]
    add ax, TILE_SIZE - 3           ; right foot
    push ax
    push dx
    call IsSolidAt
    cmp ax, 0
    jne .land
    xor ax, ax                      ; nothing below: in the air
    jmp .done

.land:
    and dx, 0FFF0h                  ; top of the tile it fell into
    mov [bx + ENT_Y], dx
    mov byte [bx + ENT_Y_FRAC], 0
    mov word [bx + ENT_VY], 0
    mov ax, 1

.done:
    pop dx
    pop bx
    pop bp
    ret 2

; =============================================================
; Procedure : EntitiesTouch
; Purpose   : Tells whether two 16 x 16 entities overlap (their x
;             and y differences are both smaller than a tile).
; Inputs    : on the stack: address of record A (pushed first),
;             address of record B (pushed second). RET 4.
; Outputs   : AX = 1 if they overlap, else 0
; Registers : none changed except AX
; =============================================================
EntitiesTouch:
    push bp
    mov bp, sp
    push bx
    push si

    mov bx, [bp + 6]                ; record A
    mov si, [bp + 4]                ; record B
    mov ax, [bx + ENT_X]
    sub ax, [si + ENT_X]
    jns .dx_positive
    neg ax                          ; absolute value
.dx_positive:
    cmp ax, TILE_SIZE
    jge .no
    mov ax, [bx + ENT_Y]
    sub ax, [si + ENT_Y]
    jns .dy_positive
    neg ax
.dy_positive:
    cmp ax, TILE_SIZE
    jge .no
    mov ax, 1
    jmp .done
.no:
    xor ax, ax
.done:
    pop si
    pop bx
    pop bp
    ret 4

; =============================================================
; Procedure : EntityBumpOthers
; Purpose   : A walking enemy that touches another walking enemy
;             turns around (Section 5.5), but only when it is walking
;             TOWARD that enemy. This stops a fast Koopa and a slow
;             Goomba walking the same way from flipping every frame.
; Inputs    : on the stack: the record address. RET 2.
; Outputs   : ENT_VX, ENT_DIR of that enemy
; Registers : none changed (all registers are preserved)
; =============================================================
EntityBumpOthers:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push si

    mov bx, [bp + 4]                ; this enemy
    mov si, entities                ; walks over every record
    mov cx, MAX_ENTITIES
.next:
    cmp si, bx
    je .skip                        ; not itself
    cmp byte [si + ENT_STATE], ES_WALKING
    jne .skip
    mov al, [si + ENT_TYPE]
    cmp al, ENT_GOOMBA
    je .candidate
    cmp al, ENT_KOOPA
    jne .skip                       ; mushrooms and empty slots are ignored
.candidate:
    push bx
    push si
    call EntitiesTouch
    cmp ax, 0
    je .skip

    ; --- touching: turn only if walking toward the other enemy ---
    mov ax, [si + ENT_X]
    sub ax, [bx + ENT_X]            ; AX = other x - my x
    cmp word [bx + ENT_VX], 0
    jl .walking_left
    cmp ax, 0
    jl .skip                        ; walking right, other is on my left: no turn
    jmp .turn
.walking_left:
    cmp ax, 0
    jg .skip                        ; walking left, other is on my right: no turn
.turn:
    neg word [bx + ENT_VX]
    xor byte [bx + ENT_DIR], 1
    jmp .done
.skip:
    add si, ENT_SIZE
    loop .next

.done:
    pop si
    pop cx
    pop bx
    pop ax
    pop bp
    ret 2

; =============================================================
; Procedure : KoopaLedgeCheck
; Purpose   : A Koopa standing on the ground turns around when the
;             tile just ahead of its feet is not solid (platform edge).
; Inputs    : on the stack: the record address. RET 2.
; Outputs   : ENT_VX, ENT_DIR of that Koopa
; Registers : none changed (all registers are preserved)
; =============================================================
KoopaLedgeCheck:
    push bp
    mov bp, sp
    push ax
    push bx

    mov bx, [bp + 4]
    mov ax, [bx + ENT_X]
    cmp word [bx + ENT_VX], 0
    jl .looking_left
    add ax, TILE_SIZE               ; first pixel right of the Koopa
    jmp .test
.looking_left:
    dec ax                          ; pixel left of the Koopa
.test:
    push ax
    push word [bx + ENT_Y]          ; feet row: the tile it stands on
    call IsSolidAt
    cmp ax, 0
    jne .done                       ; ground continues: keep walking
    neg word [bx + ENT_VX]          ; edge: turn around
    xor byte [bx + ENT_DIR], 1

.done:
    pop bx
    pop ax
    pop bp
    ret 2

; =============================================================
; Procedure : ShellHitsEnemies
; Purpose   : A sliding shell removes every walking Goomba or Koopa
;             it touches and scores SCORE_SHELL_KILL for each.
; Inputs    : on the stack: the shell's record address. RET 2.
; Outputs   : entities, score
; Registers : none changed (all registers are preserved)
; =============================================================
ShellHitsEnemies:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push si

    mov bx, [bp + 4]                ; the shell
    mov si, entities
    mov cx, MAX_ENTITIES
.next:
    cmp si, bx
    je .skip
    cmp byte [si + ENT_STATE], ES_WALKING
    jne .skip
    mov al, [si + ENT_TYPE]
    cmp al, ENT_GOOMBA
    je .candidate
    cmp al, ENT_KOOPA
    jne .skip
.candidate:
    push bx
    push si
    call EntitiesTouch
    cmp ax, 0
    je .skip
    push si
    call RemoveEntity               ; the enemy is gone
    push word 0
    push word SCORE_SHELL_KILL
    call AddScore
.skip:
    add si, ENT_SIZE
    loop .next

    pop si
    pop cx
    pop bx
    pop ax
    pop bp
    ret 2

; =============================================================
; Procedure : UpdateEntity
; Purpose   : One frame for one entity record. Waiting enemies start
;             walking when within one tile of the screen (and fewer
;             than 8 are active). Walking Goombas/Koopas move, fall,
;             turn (Koopas also at ledges) and bump each other.
;             Mushrooms move and fall. A flat Goomba counts down and
;             vanishes. A still shell only falls; a sliding shell
;             moves fast, bounces and removes enemies. Every entity
;             that falls below the map or is more than 32 pixels left
;             of the camera is removed.
; Inputs    : on the stack, pushed in this order: the record address,
;             camera_x. Removed by RET 4.
; Outputs   : the record, entities, score
; Registers : none changed (all registers are preserved)
; =============================================================
UpdateEntity:
    push bp
    mov bp, sp
    push ax
    push bx

    mov bx, [bp + 6]
    cmp byte [bx + ENT_TYPE], ENT_MUSHROOM
    jne .not_mushroom
    jmp .mushroom
.not_mushroom:
    mov al, [bx + ENT_STATE]
    cmp al, ES_WAITING
    jne .not_waiting
    jmp .waiting
.not_waiting:
    cmp al, ES_WALKING
    jne .not_walking
    jmp .walking
.not_walking:
    cmp al, ES_FLAT
    jne .not_flat
    jmp .flat
.not_flat:
    cmp al, ES_SHELL_STILL
    jne .not_shell_still
    jmp .shell_still
.not_shell_still:
    cmp al, ES_SHELL_SLIDE
    jne .not_shell_slide
    jmp .shell_slide
.not_shell_slide:
    jmp .check_remove

    ; --- waiting: activate within one tile of the visible screen ---
.waiting:
    mov ax, [bx + ENT_X]
    sub ax, [bp + 4]                ; screen x = world x - camera_x
    cmp ax, SCREEN_WIDTH + TILE_SIZE
    jl .check_active                ; still too far to the right
    jmp .done
.check_active:
    push word entities              ; address of the entity table
    call CountActiveEnemies
    cmp ax, MAX_ACTIVE_ENEMIES
    jb .activate                    ; already 8 active
    jmp .done
.activate:
    mov byte [bx + ENT_STATE], ES_WALKING
    jmp .done

    ; --- walking Goomba or Koopa ---
.walking:
    push bx
    call EntityStepX
    push bx
    call EntityStepY                ; AX = 1 when standing
    cmp byte [bx + ENT_TYPE], ENT_KOOPA
    jne .bump
    cmp ax, 0
    je .bump                        ; falling: no ledge test
    push bx
    call KoopaLedgeCheck
.bump:
    push bx
    call EntityBumpOthers
    jmp .check_remove

    ; --- mushroom: walks right, falls, turns at walls ---
.mushroom:
    push bx
    call EntityStepX
    push bx
    call EntityStepY
    jmp .check_remove

    ; --- flat Goomba: wait FLAT_FRAMES, then vanish ---
.flat:
    dec byte [bx + ENT_TIMER]
    jnz .done
    push bx
    call RemoveEntity
    jmp .done

    ; --- still shell: kick grace counts down, shell only falls ---
.shell_still:
    cmp byte [bx + ENT_TIMER], 0
    je .still_fall
    dec byte [bx + ENT_TIMER]
.still_fall:
    push bx
    call EntityStepY
    jmp .check_remove

    ; --- sliding shell: moves, bounces off walls, removes enemies ---
.shell_slide:
    cmp byte [bx + ENT_TIMER], 0
    je .slide_move
    dec byte [bx + ENT_TIMER]
.slide_move:
    push bx
    call EntityStepX
    push bx
    call EntityStepY
    push bx
    call ShellHitsEnemies

    ; --- removal: far left of the camera, or fallen below the map ---
.check_remove:
    mov ax, [bx + ENT_X]
    sub ax, [bp + 4]
    cmp ax, -(TILE_SIZE * 2)
    jl .remove
    cmp word [bx + ENT_Y], MAP_ROWS * TILE_SIZE + TILE_SIZE
    jle .done
.remove:
    push bx
    call RemoveEntity

.done:
    pop bx
    pop ax
    pop bp
    ret 4

; =============================================================
; Procedure : UpdateEntities
; Purpose   : Walks through the whole entities table and updates
;             every used record (Section 5.13 step 4).
; Inputs    : on the stack: camera_x. Removed by RET 2.
; Outputs   : entities, score
; Registers : none changed (all registers are preserved)
; =============================================================
UpdateEntities:
    push bp
    mov bp, sp
    push bx
    push cx

    mov bx, entities
    mov cx, MAX_ENTITIES
.next:
    cmp byte [bx + ENT_TYPE], ENT_NONE
    je .skip
    push bx
    push word [bp + 4]
    call UpdateEntity
.skip:
    add bx, ENT_SIZE
    loop .next

    pop cx
    pop bx
    pop bp
    ret 2

; =============================================================
; Procedure : AwardStomp
; Purpose   : Scores one stomp from the stomp chain table (stomps 1
;             to 10), gives a 1-UP from the 11th stomp on, and
;             counts the stomp in hero_stomp_chain.
; Inputs    : on the stack: address of the hero record. Removed by RET 2.
; Outputs   : score, lives, hero_stomp_chain
; Registers : none changed (all registers are preserved)
; =============================================================
AwardStomp:
    push bp
    mov bp, sp
    push ax
    push bx
    push si

    mov si, [bp + 4]                ; hero record
    mov bl, [si + H_STOMPCHAIN]
    cmp bl, 10
    jae .one_up                     ; stomp 11 and later
    xor bh, bh
    shl bx, 1                       ; word table index
    push word 0
    push word [stomp_points + bx]
    call AddScore
    inc byte [si + H_STOMPCHAIN]
    jmp .done
.one_up:
    push word lives                 ; address of the lives counter
    call AddLife

.done:
    pop si
    pop bx
    pop ax
    pop bp
    ret 2

; =============================================================
; Procedure : HeroVsEntity
; Purpose   : Applies the collision outcomes of Section 5.6 to one
;             entity: mushroom collected (+1000, Small becomes
;             Super, feet fixed); still shell kicked (+400, slides
;             away); stomp (decided by IsStomp): chain points, bounce,
;             Goomba flat, Koopa or sliding shell becomes a still
;             shell; any other contact hurts Mario (HurtHero).
;             Flat Goombas and shells in their kick grace are ignored.
;             Mario's box is 12 pixels wide (2 pixels in on each side).
; Inputs    : on the stack, pushed in this order: address of the hero
;             record, address of the entity record. Removed by RET 4.
; Outputs   : the entity record, score, hero record
;             AX = 1 if Mario must die, else 0
; Registers : none changed except AX
; =============================================================
HeroVsEntity:
    push bp
    mov bp, sp
    push bx
    push cx
    push si

    mov si, [bp + 6]                ; hero record
    mov bx, [bp + 4]                ; entity record

    ; --- states that cannot touch Mario ---
    mov al, [bx + ENT_STATE]
    cmp al, ES_FLAT
    jne .not_flat
    jmp .survive
.not_flat:
    cmp al, ES_SHELL_STILL
    je .grace_test
    cmp al, ES_SHELL_SLIDE
    jne .overlap_test
.grace_test:
    cmp byte [bx + ENT_TIMER], 0
    je .overlap_test
    jmp .survive                    ; shell still ignores Mario

    ; --- rectangle overlap: Mario's box (A, 12 wide) against the entity (B) ---
.overlap_test:
    push si
    call GetBodyHeight
    mov cx, ax                      ; CX = Mario's height
    mov ax, [si + H_X]
    add ax, HITBOX_LEFT
    push ax                         ; aLeft
    mov ax, [si + H_Y]
    sub ax, cx
    push ax                         ; aTop
    mov ax, [si + H_X]
    add ax, HITBOX_RIGHT + 1
    push ax                         ; aRight
    push word [si + H_Y]            ; aBottom
    push word [bx + ENT_X]          ; bLeft
    mov ax, [bx + ENT_Y]
    sub ax, TILE_SIZE
    push ax                         ; bTop
    mov ax, [bx + ENT_X]
    add ax, TILE_SIZE
    push ax                         ; bRight
    push word [bx + ENT_Y]          ; bBottom
    call RectsOverlap
    cmp ax, 0
    jne .touching
    jmp .survive

    ; --- what did Mario touch? ---
.touching:
    cmp byte [bx + ENT_TYPE], ENT_MUSHROOM
    jne .not_mushroom
    jmp .mushroom
.not_mushroom:
    cmp byte [bx + ENT_STATE], ES_SHELL_STILL
    jne .not_kick
    jmp .kick
.not_kick:

    ; --- stomp or hurt: IsStomp(previous feet, vy, enemy feet) ---
    push word [si + H_PREVY]
    push word [si + H_VY]
    push word [bx + ENT_Y]
    call IsStomp
    cmp ax, 0
    je .not_stomp
    jmp .stomp
.not_stomp:
    cmp byte [si + H_STOMPED], 0
    je .not_already_stomped
    jmp .survive                    ; already stomped this frame: no damage
.not_already_stomped:
    push si
    call HurtHero                   ; ignored while invulnerable; AX = 1 if Mario dies
    jmp .out

.stomp:
    mov byte [si + H_STOMPED], 1
    mov word [si + H_VY], STOMP_BOUNCE ; bounce (UpdateVerticalSpeed cuts it if Space is up)
    push si
    call AwardStomp
    cmp byte [bx + ENT_TYPE], ENT_GOOMBA
    jne .make_shell
    mov byte [bx + ENT_STATE], ES_FLAT
    mov byte [bx + ENT_TIMER], FLAT_FRAMES
    mov word [bx + ENT_VX], 0
    jmp .survive
.make_shell:                        ; Koopa or sliding shell: still shell
    mov byte [bx + ENT_STATE], ES_SHELL_STILL
    mov byte [bx + ENT_TIMER], KICK_GRACE
    mov word [bx + ENT_VX], 0
    jmp .survive

.kick:
    push word 0
    push word SCORE_KICK
    call AddScore
    mov byte [bx + ENT_STATE], ES_SHELL_SLIDE
    mov byte [bx + ENT_TIMER], KICK_GRACE
    mov ax, [bx + ENT_X]
    cmp ax, [si + H_X]
    jg .slide_right                 ; shell is right of Mario: slide right
    mov word [bx + ENT_VX], -SHELL_SPEED
    mov byte [bx + ENT_DIR], FACE_LEFT
    jmp .survive
.slide_right:
    mov word [bx + ENT_VX], SHELL_SPEED
    mov byte [bx + ENT_DIR], FACE_RIGHT
    jmp .survive

.mushroom:
    push word 0
    push word SCORE_MUSHROOM
    call AddScore
    mov byte [si + H_FORM], FORM_SUPER ; feet stay fixed: hero_y is the feet
    mov byte [si + H_HP], HP_SUPER
    push bx
    call RemoveEntity

.survive:
    xor ax, ax

.out:
    pop si
    pop cx
    pop bx
    pop bp
    ret 4

; =============================================================
; Procedure : HeroVsEntities
; Purpose   : Runs HeroVsEntity for every active entity (waiting
;             enemies are off screen and cannot be touched). Stops
;             as soon as an enemy kills Mario.
; Inputs    : on the stack: address of the hero record. Removed by RET 2.
; Outputs   : hero_stomped and everything HeroVsEntity changes
;             AX = 1 if Mario must die, else 0
; Registers : none changed except AX
; =============================================================
HeroVsEntities:
    push bp
    mov bp, sp
    push bx
    push cx
    push si

    mov si, [bp + 4]                ; hero record
    mov byte [si + H_STOMPED], 0
    mov bx, entities
    mov cx, MAX_ENTITIES
.next:
    cmp byte [bx + ENT_TYPE], ENT_NONE
    je .skip
    cmp byte [bx + ENT_STATE], ES_WAITING
    je .skip
    push si
    push bx
    call HeroVsEntity
    cmp ax, 0
    jne .done                       ; Mario dies: stop (AX = 1)
.skip:
    add bx, ENT_SIZE
    loop .next
    xor ax, ax                      ; nobody killed him

.done:
    pop si
    pop cx
    pop bx
    pop bp
    ret 2

; =============================================================
; Procedure : StartDeath
; Purpose   : Mario dies (enemy, pit or clock). Enters STATE_DYING:
;             enemies, clock and keys freeze. Jump pose; a death by
;             enemy or clock first hops up (DEATH_HOP_FRAMES), a pit
;             death just keeps falling. Ignored unless PLAYING.
; Inputs    : on the stack: address of the hero record. Removed by RET 2.
; Outputs   : game_state, hero_pose, hero_vx, death_phase, state_timer
; Registers : none changed (all registers are preserved)
; =============================================================
StartDeath:
    push bp
    mov bp, sp
    push bx

    cmp byte [game_state], STATE_PLAYING
    jne .done
    mov bx, [bp + 4]
    mov byte [game_state], STATE_DYING
    mov byte [bx + H_POSE], POSE_JUMP
    mov word [bx + H_VX], 0
    mov byte [death_phase], DEATH_HOP
    mov word [state_timer], DEATH_HOP_FRAMES
    cmp word [bx + H_Y], PIT_Y
    jl .done
    mov byte [death_phase], DEATH_FALL  ; pit: skip the hop, keep the fall speed

.done:
    pop bx
    pop bp
    ret 2

; =============================================================
; Procedure : StateDying
; Purpose   : Death animation (Section 5.8): hop up 48 pixels, then
;             fall with gravity and no collisions until Mario is off
;             the screen. Then lives - 1: the Life-lost screen if
;             lives remain, otherwise Game Over.
; Inputs    : death_phase, state_timer, the hero record, lives
; Outputs   : hero_y, hero_vy, lives, game_state, state_timer
; Registers : none changed (all registers are preserved)
; =============================================================
StateDying:
    push ax
    push bx
    push si

    mov si, hero_data

    cmp byte [death_phase], DEATH_HOP
    jne .fall

    ; --- hop: move up DEATH_HOP_SPEED pixels per frame ---
    sub word [si + H_Y], DEATH_HOP_SPEED
    dec word [state_timer]
    jnz .done
    mov byte [death_phase], DEATH_FALL
    mov word [si + H_VY], 0
    jmp .done

    ; --- fall: gravity, capped, no collision ---
.fall:
    mov ax, [si + H_VY]
    add ax, GRAVITY
    cmp ax, MAX_FALL_SPEED
    jle .speed_ok
    mov ax, MAX_FALL_SPEED
.speed_ok:
    mov [si + H_VY], ax
    mov bx, si
    add bx, H_Y
    push bx
    mov bx, si
    add bx, H_YFRAC
    push bx
    push ax
    call AddFixed

    ; --- off the screen when the TOP of his body is below the last row ---
    push si
    call GetBodyHeight
    mov bx, [si + H_Y]
    sub bx, ax
    cmp bx, SCREEN_HEIGHT
    jl .done                        ; still on the way down

    ; --- animation finished: lose the life ---
    dec byte [lives]
    jz .game_over
    mov byte [game_state], STATE_LIFE_LOST
    mov word [state_timer], LIFE_LOST_FRAMES
    jmp .done
.game_over:
    mov byte [game_state], STATE_GAME_OVER

.done:
    pop si
    pop bx
    pop ax
    ret

; =============================================================
; Procedure : StateLifeLost
; Purpose   : Life-lost screen for LIFE_LOST_FRAMES (about 2 s), then
;             the level restarts (score and coins are kept).
; Inputs    : state_timer
; Outputs   : state_timer, game_state (and ResetLevel changes)
; Registers : none changed (flags only)
; =============================================================
StateLifeLost:
    dec word [state_timer]
    jnz .done
    call ResetLevel
    mov byte [game_state], STATE_PLAYING
.done:
    ret

; =============================================================
; Procedure : StartWin
; Purpose   : The flag pole was touched (Section 5.11). Adds the flag
;             points for the map row of Mario's feet (row clamped to
;             2..8), enters STATE_WIN_SEQ and snaps Mario to the pole.
;             The clock and keys are frozen because StatePlaying no
;             longer runs. Ignored unless PLAYING.
; Inputs    : on the stack, pushed in this order: address of the hero
;             record, left edge of the pole column. Removed by RET 4.
; Outputs   : score, game_state, win_phase, hero_x, hero_vx, hero_vy,
;             hero_pose
; Registers : none changed (all registers are preserved)
; =============================================================
StartWin:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push si

    cmp byte [game_state], STATE_PLAYING
    jne .done
    mov si, [bp + 6]                ; hero record
    mov byte [game_state], STATE_WIN_SEQ
    mov byte [win_phase], 0

    ; --- points from the map row of the feet ---
    mov bx, [si + H_Y]
    dec bx                          ; last pixel row of Mario's feet
    jns .feet_row_ok                ; negative means above the map
    xor bx, bx                      ; treat it as row 0, raised to row 2 below
.feet_row_ok:
    mov cl, 4
    shr bx, cl                      ; BX = map row of the feet
    cmp bx, 2
    jge .row_low_ok
    mov bx, 2
.row_low_ok:
    cmp bx, 8
    jle .row_high_ok
    mov bx, 8
.row_high_ok:
    sub bx, 2                       ; table index
    shl bx, 1                       ; words are 2 bytes
    push word 0                     ; points, high word
    push word [flag_points + bx]    ; points, low word
    call AddScore

    ; --- snap to the pole and stop ---
    mov ax, [bp + 4]
    mov [si + H_X], ax
    mov byte [si + H_XFRAC], 0
    mov word [si + H_VX], 0
    mov word [si + H_VY], 0
    mov byte [si + H_POSE], POSE_STAND

.done:
    pop si
    pop cx
    pop bx
    pop ax
    pop bp
    ret 4

; =============================================================
; Procedure : StateWinSeq
; Purpose   : Win sequence (Section 5.11). Phase 0: Mario slides down
;             the pole until the tile under his feet is solid (about
;             1 s). Phase 1: he disappears into the castle for about
;             1 s (hero_visible = 0). Then FinishWin.
; Inputs    : win_phase, state_timer, the hero record
; Outputs   : hero_y, hero_visible, win_phase, state_timer
; Registers : none changed (all registers are preserved)
; =============================================================
StateWinSeq:
    push ax
    push si

    mov si, hero_data

    cmp byte [win_phase], 0
    jne .in_castle

    ; --- slide: stop when the tile under the feet (pole base) is solid ---
    mov ax, [si + H_X]
    add ax, TILE_SIZE / 2
    push ax
    push word [si + H_Y]
    call IsSolidAt
    cmp ax, 0
    jne .reached
    add word [si + H_Y], WIN_SLIDE_SPEED
    jmp .done
.reached:
    and word [si + H_Y], 0FFF0h     ; feet exactly on the base block
    mov byte [si + H_VISIBLE], 0    ; walks into the castle
    mov byte [win_phase], 1
    mov word [state_timer], WIN_WAIT_FRAMES
    jmp .done

.in_castle:
    dec word [state_timer]
    jnz .done
    call FinishWin

.done:
    pop si
    pop ax
    ret

; =============================================================
; Procedure : FinishWin
; Purpose   : Turns the time left into points: bonus_points =
;             time_left * 50, added to score (the screen shows both).
;             Then enters STATE_LEVEL_DONE. No life is given.
; Inputs    : time_left
; Outputs   : bonus_points, score, game_state
; Registers : none changed (all registers are preserved)
; =============================================================
FinishWin:
    push ax
    push bx
    push dx

    mov ax, [time_left]
    mov bx, SCORE_TIME_PER_SEC
    mul bx                          ; DX:AX = time_left * 50
    mov [bonus_points], ax
    mov [bonus_points + 2], dx
    push dx                         ; high word
    push ax                         ; low word
    call AddScore
    mov byte [game_state], STATE_LEVEL_DONE

    pop dx
    pop bx
    pop ax
    ret

; =============================================================
; Procedure : InitHero
; Purpose   : Puts the hero record into its start state: Small Mario
;             (HP 1) at the start position, standing, visible, no
;             invulnerability and no speed.
; Inputs    : on the stack: address of the hero record. Removed by RET 2.
; Outputs   : the whole hero record
; Registers : none changed (all registers are preserved)
; =============================================================
InitHero:
    push bp
    mov bp, sp
    push bx

    mov bx, [bp + 4]
    mov word [bx + H_X], START_X
    mov byte [bx + H_XFRAC], 0
    mov word [bx + H_Y], START_Y
    mov word [bx + H_PREVY], START_Y
    mov byte [bx + H_YFRAC], 0
    mov word [bx + H_VX], 0
    mov word [bx + H_VY], 0
    mov byte [bx + H_FACING], FACE_RIGHT
    mov byte [bx + H_ONGROUND], 1
    mov byte [bx + H_FORM], FORM_SMALL
    mov byte [bx + H_HP], HP_SMALL
    mov byte [bx + H_INVULN], 0
    mov byte [bx + H_STOMPCHAIN], 0
    mov byte [bx + H_POSE], POSE_STAND
    mov byte [bx + H_VISIBLE], 1
    mov byte [bx + H_STOMPED], 0

    pop bx
    pop bp
    ret 2

; =============================================================
; Procedure : ResetLevel
; Purpose   : Prepares a level start: working map restored from the
;             original, Mario back at the start as Small Mario (HP 1,
;             no invulnerability, camera 0), clock 300, entities
;             cleared and refilled from spawn_table (all waiting).
;             Score, coins and lives are NOT touched (see NewGame).
; Inputs    : level_original, spawn_table (Person 1's leveldata.inc)
; Outputs   : level_working, hero record, camera_x, time_left,
;             clock_ticks, entities
; Registers : none changed (flags, including DF, are preserved)
; Note      : needs DS = ES
; =============================================================
ResetLevel:
    pushf
    push ax
    push cx
    push si
    push di

    call ResetMap

    ; --- Mario, camera, clock and sequence variables ---
    push word hero_data
    call InitHero
    mov word [camera_x], 0
    mov byte [win_phase], 0
    mov byte [death_phase], DEATH_HOP
    mov word [time_left], LEVEL_TIME
    mov byte [clock_ticks], 0

    ; --- entities: clear the whole table with one block fill ---
    cld
    mov di, entities
    mov cx, MAX_ENTITIES * ENT_SIZE
    xor al, al
    rep stosb

    ; --- entities: copy the spawn table (records of SPAWN_SIZE bytes) ---
    mov si, spawn_table
    mov di, entities
    mov cx, MAX_ENTITIES            ; never more records than slots
.spawn:
    mov al, [si + SPAWN_TYPE]
    cmp al, ENT_NONE
    je .done                        ; end marker
    mov [di + ENT_TYPE], al
    mov byte [di + ENT_STATE], ES_WAITING
    mov al, [si + SPAWN_DIR]
    mov [di + ENT_DIR], al
    mov ax, [si + SPAWN_X]
    mov [di + ENT_X], ax
    mov ax, [si + SPAWN_Y]
    mov [di + ENT_Y], ax
    mov ax, GOOMBA_SPEED            ; speed from the type
    cmp byte [si + SPAWN_TYPE], ENT_GOOMBA
    je .speed_chosen
    mov ax, KOOPA_SPEED
.speed_chosen:
    cmp byte [si + SPAWN_DIR], FACE_LEFT
    jne .store_speed
    neg ax                          ; walking left: negative speed
.store_speed:
    mov [di + ENT_VX], ax
    add si, SPAWN_SIZE
    add di, ENT_SIZE
    loop .spawn

.done:
    pop di
    pop si
    pop cx
    pop ax
    popf
    ret

; =============================================================
; Procedure : NewGame
; Purpose   : Starts a new game from the title: score 0, coins 0,
;             lives 3, then ResetLevel, then STATE_PLAYING.
; Inputs    : none
; Outputs   : score, bonus_points, coins, lives, game_state, and
;             everything ResetLevel sets
; Registers : none changed (flags only)
; =============================================================
NewGame:
    mov word [score], 0
    mov word [score + 2], 0
    mov word [bonus_points], 0
    mov word [bonus_points + 2], 0
    mov byte [coins], 0
    mov byte [lives], START_LIVES
    call ResetLevel
    mov byte [game_state], STATE_PLAYING
    ret