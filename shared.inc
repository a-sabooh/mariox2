; =============================================================
; shared.inc - names, constants and variables shared by both people
; Person 1 WRITES : key_state, key_pressed, tick_count
; Person 2 WRITES : everything else
; Include this file at the BOTTOM of the main file, after the final
; exit code, because it contains data bytes (never at the top).
;
; README deviation: positions use a 16-bit whole-pixel part and an
; 8-bit fraction, because world x goes up to 959 and an 8-bit whole
; part cannot hold it. Velocities are true 8.8 words.
; =============================================================

; ---------- Screen, tile and level constants ----------
TILE_SIZE        equ 16
MAP_COLS         equ 60
MAP_ROWS         equ 12
MAP_SIZE         equ MAP_COLS * MAP_ROWS
LEVEL_WIDTH_PX   equ MAP_COLS * TILE_SIZE
SCREEN_WIDTH     equ 320
SCREEN_HEIGHT    equ 200
SCREEN_MID_X     equ 160
MAX_CAMERA_X     equ LEVEL_WIDTH_PX - SCREEN_WIDTH
PIT_Y            equ 192                ; Section 5.6: top of Mario at or below this = pit
START_X          equ 32
START_Y          equ 160                ; feet position: top of ground row 10

; ---------- Tile codes (Appendix A.2) ----------
TILE_SKY         equ 0
TILE_GROUND      equ 1
TILE_BRICK       equ 2
TILE_Q_COIN      equ 3
TILE_Q_MUSHROOM  equ 4
TILE_EMPTY       equ 5
TILE_PIPE_TL     equ 6
TILE_PIPE_TR     equ 7
TILE_PIPE_BL     equ 8
TILE_PIPE_BR     equ 9
TILE_STAIR       equ 10
TILE_COIN        equ 11
TILE_FLAG        equ 12

; ---------- Game states (Section 5.12) ----------
STATE_TITLE      equ 0
STATE_PLAYING    equ 1
STATE_PAUSED     equ 2
STATE_DYING      equ 3
STATE_LIFE_LOST  equ 4
STATE_WIN_SEQ    equ 5
STATE_LEVEL_DONE equ 6
STATE_GAME_OVER  equ 7
STATE_EXIT       equ 8

; ---------- Scan codes (Appendix A.3, plus the two debug keys) ----------
SC_ESC           equ 01h
SC_T             equ 14h                ; debug key: set the clock to DEBUG_TIME seconds
SC_P             equ 19h
SC_ENTER         equ 1Ch
SC_LSHIFT        equ 2Ah
SC_C             equ 2Eh                ; debug key: set coins to 99
SC_SPACE         equ 39h
SC_UP            equ 48h
SC_LEFT          equ 4Bh
SC_RIGHT         equ 4Dh
SC_DOWN          equ 50h

; DEBUG_KEYS (1 = debug keys T and C active, 0 = off) is defined at the top of logic.asm,
; because NASM needs it before the code that tests it.
DEBUG_TIME       equ 5                  ; seconds left after pressing T

; ---------- Hero values ----------
FORM_SMALL       equ 0
FORM_SUPER       equ 1
HP_SMALL         equ 1
HP_SUPER         equ 2
FACE_RIGHT       equ 0
FACE_LEFT        equ 1
POSE_STAND       equ 0
POSE_RUN         equ 1
POSE_JUMP        equ 2

; Mario's collision box is 12 pixels wide, centred in the 16 pixel sprite
; (Section 5.1). hero_x is the sprite's LEFT edge, so the box covers the
; columns hero_x + HITBOX_LEFT up to hero_x + HITBOX_RIGHT (both included).
HITBOX_LEFT      equ 2
HITBOX_RIGHT     equ 13

; ---------- Hero record layout (offsets from hero_data) ----------
; Every hero procedure receives the ADDRESS of this record on the stack.
; The labels hero_x, hero_y ... stay valid for Person 1's drawing code.
H_X              equ 0                  ; word  whole pixels, LEFT edge, world coordinates
H_XFRAC          equ 2                  ; byte  fraction of x
H_YFRAC          equ 3                  ; byte  fraction of y
H_Y              equ 4                  ; word  whole pixels, FEET position
H_VX             equ 6                  ; word  8.8 signed
H_VY             equ 8                  ; word  8.8 signed
H_PREVY          equ 10                 ; word  feet position in the previous frame (stomp test)
H_FACING         equ 12                 ; byte
H_ONGROUND       equ 13                 ; byte
H_FORM           equ 14                 ; byte
H_HP             equ 15                 ; byte
H_INVULN         equ 16                 ; byte  frames left
H_STOMPCHAIN     equ 17                 ; byte
H_POSE           equ 18                 ; byte
H_VISIBLE        equ 19                 ; byte
H_STOMPED        equ 20                 ; byte  1 = Mario already stomped an enemy in this frame
HERO_SIZE        equ 21

; ---------- Physics, 8.8 fixed point (Appendix A.5) ----------
; Hex values that start with a letter need a leading 0 in NASM.
WALK_ACCEL       equ 0020h
FRICTION         equ 0010h
MAX_WALK_SPEED   equ 0180h
MAX_RUN_SPEED    equ 0280h
GRAVITY          equ 0040h
JUMP_START       equ 0FA80h             ; -5.5
JUMP_CUTOFF      equ 0FE00h             ; -2.0
MAX_FALL_SPEED   equ 0400h
STOMP_BOUNCE     equ 0FD00h             ; -3.0
GOOMBA_SPEED     equ 0080h
KOOPA_SPEED      equ 00C0h
SHELL_SPEED      equ 0300h
MUSHROOM_SPEED   equ 0100h

; ---------- Game limits (Appendix A.4) ----------
START_LIVES      equ 3
MAX_LIVES        equ 99
LEVEL_TIME       equ 300
MAX_SCORE        equ 999999
TICKS_PER_SECOND equ 30                 ; Person 1 programs the timer to exactly 30 ticks/s and calls GameUpdate once per tick
INVULN_FRAMES    equ TICKS_PER_SECOND * 2
KICK_GRACE       equ 8
FLAT_FRAMES      equ TICKS_PER_SECOND
MAX_ACTIVE_ENEMIES equ 8                ; Section 5.5: at most 8 active enemies

; ---------- [P2 ADD] Death, win and screen timing ----------
DEATH_HOP_FRAMES equ 12                 ; frames of the upward hop
DEATH_HOP_SPEED  equ 4                  ; 12 * 4 = 48 pixels up (Section 5.8)
DEATH_HOP        equ 0                  ; death_phase values
DEATH_FALL       equ 1
LIFE_LOST_FRAMES equ TICKS_PER_SECOND * 2
WIN_SLIDE_SPEED  equ 4                  ; pixels per frame down the pole (about 1 s)
WIN_WAIT_FRAMES  equ TICKS_PER_SECOND

; ---------- Score values (Section 5.4) ----------
SCORE_COIN         equ 200
SCORE_KICK         equ 400
SCORE_SHELL_KILL   equ 500
SCORE_MUSHROOM     equ 1000
SCORE_BRICK        equ 50
SCORE_TIME_PER_SEC equ 50

; ---------- Entity record layout (enemies, shells, mushrooms) ----------
ENT_TYPE         equ 0                  ; byte
ENT_STATE        equ 1                  ; byte
ENT_DIR          equ 2                  ; byte (FACE_RIGHT / FACE_LEFT)
ENT_TIMER        equ 3                  ; byte (flat time / kick grace)
ENT_X            equ 4                  ; word, whole pixels
ENT_X_FRAC       equ 6                  ; byte
ENT_Y_FRAC       equ 7                  ; byte
ENT_Y            equ 8                  ; word, whole pixels (feet)
ENT_VX           equ 10                 ; word, 8.8 signed (the real velocity, sign = direction)
ENT_VY           equ 12                 ; word, 8.8 signed
ENT_SIZE         equ 14
MAX_ENTITIES     equ 12

ENT_NONE         equ 0                  ; empty slot
ENT_GOOMBA       equ 1
ENT_KOOPA        equ 2
ENT_MUSHROOM     equ 3

ES_WAITING       equ 0
ES_WALKING       equ 1
ES_FLAT          equ 2
ES_SHELL_STILL   equ 3
ES_SHELL_SLIDE   equ 4

; ---------- [P1 ADD] Enemy spawn table (level data, written by Person 1) ----------
; spawn_table is a list of 6-byte records that ends with a record whose type is ENT_NONE.
; ResetLevel copies each record into an entities slot (state = ES_WAITING,
; speed from the type, x and y are WORLD pixels, y = FEET).
SPAWN_TYPE       equ 0                  ; byte: ENT_GOOMBA / ENT_KOOPA (ENT_NONE = end of table)
SPAWN_DIR        equ 1                  ; byte: FACE_LEFT / FACE_RIGHT
SPAWN_X          equ 2                  ; word: left edge, world pixels
SPAWN_Y          equ 4                  ; word: feet, world pixels
SPAWN_SIZE       equ 6
; level_original (MAP_SIZE bytes, index = row * MAP_COLS + column) and spawn_table
; are defined in Person 1's level.inc. Person 2 only READS them (labels are global).

; =============================================================
; VARIABLES
; =============================================================

; ---------- Written by Person 1, read by Person 2 ----------
key_state        times 128 db 0         ; 1 = key held, indexed by scan code
key_pressed      times 128 db 0         ; [P1 ADD] 1 = key went DOWN since the last frame (no auto-repeat).
                                        ; Person 1 sets it in the keyboard ISR and clears it right after
                                        ; GameUpdate returns. Used for Enter, P, Esc, Up, Down, T and C.
tick_count       dw 0

; ---------- Hero record (Person 2 writes, Person 1 reads) ----------
; The order of the fields must match the H_ offsets above (checked below).
hero_data:                              ; address of the record = address of hero_x
hero_x           dw START_X
hero_x_frac      db 0
hero_y_frac      db 0
hero_y           dw START_Y
hero_vx          dw 0
hero_vy          dw 0
hero_prev_y      dw START_Y
hero_facing      db FACE_RIGHT
hero_on_ground   db 1
hero_form        db FORM_SMALL
hero_hp          db HP_SMALL
hero_invuln      db 0
hero_stomp_chain db 0
hero_pose        db POSE_STAND          ; POSE_JUMP is also used for the death animation
hero_visible     db 1                   ; [P1 ADD] 0 = do not draw Mario (win sequence: walked into the castle)
hero_stomped     db 0

; --- assembly-time check: every label sits at its H_ offset (a mismatch stops NASM with a TIMES error) ---
%macro CHECK_HERO_OFFSET 2
    times ((%1 - hero_data) - %2) db 0
    times (%2 - (%1 - hero_data)) db 0
%endmacro
CHECK_HERO_OFFSET hero_x,           H_X
CHECK_HERO_OFFSET hero_x_frac,      H_XFRAC
CHECK_HERO_OFFSET hero_y_frac,      H_YFRAC
CHECK_HERO_OFFSET hero_y,           H_Y
CHECK_HERO_OFFSET hero_vx,          H_VX
CHECK_HERO_OFFSET hero_vy,          H_VY
CHECK_HERO_OFFSET hero_prev_y,      H_PREVY
CHECK_HERO_OFFSET hero_facing,      H_FACING
CHECK_HERO_OFFSET hero_on_ground,   H_ONGROUND
CHECK_HERO_OFFSET hero_form,        H_FORM
CHECK_HERO_OFFSET hero_hp,          H_HP
CHECK_HERO_OFFSET hero_invuln,      H_INVULN
CHECK_HERO_OFFSET hero_stomp_chain, H_STOMPCHAIN
CHECK_HERO_OFFSET hero_pose,        H_POSE
CHECK_HERO_OFFSET hero_visible,     H_VISIBLE
CHECK_HERO_OFFSET hero_stomped,     H_STOMPED
CHECK_HERO_OFFSET hero_stomped + 1, HERO_SIZE

camera_x         dw 0

; ---------- Game status (Person 2 writes, Person 1 reads) ----------
score            dd 0                   ; 32-bit
coins            db 0
lives            db START_LIVES
time_left        dw LEVEL_TIME
clock_ticks      db 0                   ; ticks counted inside the current second
game_state       db STATE_TITLE
menu_selection   db 0                   ; 0 = START GAME, 1 = EXIT (Person 2 changes it with Up/Down)
bonus_points     dd 0                   ; [P1 ADD] time_left * 50, ALREADY added to score by Person 2
                                        ; when entering STATE_LEVEL_DONE (the screen shows score - bonus
                                        ; as SCORE, then the bonus, then score as FINAL SCORE)

; ---------- [P2 ADD] Private variables of Person 2 (Person 1 never needs them) ----------
state_timer      dw 0                   ; frames left in the current timed state
death_phase      db DEATH_HOP           ; DEATH_HOP or DEATH_FALL
win_phase        db 0                   ; 0 = sliding down the pole, 1 = in the castle

; ---------- Score tables (Section 5.4) ----------
; Stomp number 1 to 10. Stomp 11 and later gives a 1-UP instead.
stomp_points     dw 100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, 8000
; Flag pole points by map row of Mario's feet, rows 2 to 8 (index = row - 2)
flag_points      dw 5000, 5000, 2000, 800, 400, 400, 100

; ---------- [P2 ADD] State machine jump table (Section 5.12), indexed by game_state * 2 ----------
state_table      dw StateTitle, StatePlaying, StatePaused, StateDying, StateLifeLost
                 dw StateWinSeq, StateEndScreen, StateEndScreen, StateExit

; ---------- Maps and entities ----------
level_working    times MAP_SIZE db 0
entities         times MAX_ENTITIES * ENT_SIZE db 0

; =============================================================
; [P1 ADD] DRAWING CONVENTIONS (what Person 1's drawing code assumes)
;  - hero_x and ent_x are the LEFT edge of the 16-pixel-wide sprite box (world pixels).
;  - hero_y and ent_y are the FEET: the first pixel row BELOW the sprite.
;    The sprite is drawn from (feet - 16) for Small / enemies, (feet - 32) for Super.
;  - Row r of the map is at y = r * 16. Row 0 is covered by the HUD.
;  - Entities are drawn when ent_type != ENT_NONE and -16 < ent_x - camera_x < 320
;    (also while ES_WAITING). Goomba ES_FLAT = flat sprite; Koopa ES_SHELL_STILL and
;    ES_SHELL_SLIDE = shell sprite. ENT_DIR = FACE_LEFT mirrors the sprite.
;  - STATE_DYING, STATE_WIN_SEQ and STATE_PAUSED show the normal game picture, so
;    Person 2 moves hero_y for the death animation / flag slide and sets hero_pose.
;  - Person 1's main loop leaves the game when game_state = STATE_EXIT.
; =============================================================
