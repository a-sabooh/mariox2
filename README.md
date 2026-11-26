# Super Mario Engine

EL2003 Computer Organization and Assembly Language, BCS Fall 2026, Semester Project.
A 16-bit platform game written in x86 assembly (NASM), running in DOSBox as `MARIO.COM`.

## 1. Team

|        Name        | Roll Number | Modules built |
|--------------------|-------------|---------------|
| Amtul Sabooh Basit | 25F-0786    | Person 1 (Platform and Rendering): Modules 1, 2, 4, 5, 7, 8, the drawing part of 3, 13 and 14, the main loop, clean exit, level data and enemy spawn table |
| Mahnoor Nadeem     | 25F-0714    | Person 2 (Game Logic): Modules 6, 9, 10, 11, 12, the logic part of 3, 13, 14 and 15 |

Section: BSCS-3E|  Group #  |  Lab Instructor: Shehzad Tanveer

Work split in one sentence: Person 1 builds everything the player sees (graphics, keyboard, timer, screens, HUD) and Person 2 builds everything the game decides (physics, collision, enemies, blocks, scoring, state machine). The two sides only share variables (`shared.inc`); the only call between them is the main loop calling `GameUpdate` once per frame.

## 2. Files

| File | Purpose |
|------|---------|
| `mario.asm` | Main file: skeleton, interrupt handlers, main loop, clean exit |
| `shared.inc` | Constants and variables shared by both people (hero record, enemy record, tile codes, states, scan codes, physics constants) |
| `level.inc` | Level map (60 x 12) and enemy spawn table |
| `sprdata.inc` | Original sprite and tile artwork |
| `video.asm`, `sprites.asm`, `tiles.asm`, `text.asm` | Video mode and palette, sprite drawing, tile and map drawing, font and number output |
| `gamedraw.asm`, `screens.asm` | In-game drawing (hero, enemies, items, HUD) and the 7 screens |
| `logic.asm` | All game logic (Person 2) |
| `build.bat` | Real build, produces `MARIO.COM` |
| `stub.asm`, `bstub.bat` | Test-only: a stand-in for `logic.asm` so Person 1 could test drawing alone. Not part of the final game. |

## 3. Build and run

Requirements: NASM and DOSBox 0.74-3 or later. The program needs an 80186 or newer CPU (it uses push-immediate and shifts by a constant), which DOSBox provides.

Inside DOSBox, from the project folder:

```
mount c C:\path\to\project
c:
build.bat
mario.com
```

`build.bat` runs `nasm mario.asm -f bin -o mario.com`. For a smoother game set `cycles=max` in the DOSBox configuration.

(`bstub.bat` builds with `-dUSE_STUB` and is only for solo testing of the drawing code.)

## 4. Controls

| Key | Scan code | Action |
|-----|-----------|--------|
| Left arrow | 4Bh | Move left |
| Right arrow | 4Dh | Move right |
| Left Shift | 2Ah | Run (hold while moving) |
| Space | 39h | Jump (hold for a higher jump) |
| Up / Down arrow | 48h / 50h | Move the menu highlight |
| Enter | 1Ch | Select in the menu, continue on the end screens |
| P | 19h | Pause and resume |
| Esc | 01h | Back to the title (from play or pause), exit (from the title) |

Debug keys (see section 8): **T** and **C**.

## 5. Memory choices

- The program is a single-segment `.COM` file (`ORG 100h`, `jmp start` at the top, data first, `start:` at the bottom).
- **Frame buffer:** the 64,000 byte off-screen buffer lives in the next 64 KB segment, `CS + 1000h`. DOS gives a `.COM` program all free memory, so this segment is free. At startup the program checks the top-of-memory word at `PSP:0002h` and, if the buffer would not fit, prints a message and exits instead of crashing.
- The frame buffer is cleared with `REP STOSW` and copied to video memory (segment `0A000h`) with `REP MOVSW`, once per timer tick.
- Two copies of the level map are kept: the original (never changed) and a working copy (changed by blocks and coins). Restart copies the original back with `REP MOVSB`.

## 6. Interrupts

- **Keyboard (INT 09h):** our own handler reads port 60h, ignores the `E0h` prefix byte of the arrow keys, handles release codes (bit 7 set), keeps a 128 byte key-state table so several keys work together, sends EOI and ends with `IRET`.
- **Timer (INT 08h):** the timer is reprogrammed to about 30 ticks per second (divisor 39773). The handler increments a tick counter and chains to the original handler at the original 18.2 Hz rate using an accumulator, so the DOS clock stays correct. The game loop waits for the tick counter to change, so speed is the same on every computer. No delay loops are used.
- Both vectors and the timer rate are restored on every exit path.

## 7. Game states

The game is driven by a state variable and a jump table (`state_table` in `shared.inc`, `render_table` in `screens.asm`).

| State | What happens |
|-------|--------------|
| TITLE | Up/Down move the highlight. Enter on START begins a new game. Enter on EXIT, or Esc, leaves the game. |
| PLAYING | Runs the frame order of Section 5.13. P goes to PAUSED, Esc to TITLE. Mario dying goes to DYING. Touching the flag goes to WIN SEQUENCE. |
| PAUSED | Updates and the clock are frozen and the picture stays visible with "PAUSED". P resumes, Esc returns to the title. |
| DYING | Death animation (about 1.5 s) with everything frozen. Then LIFE LOST if lives are left, or GAME OVER if not. |
| LIFE LOST | Shows the world name and lives left for about 2 s, then resets the level and returns to PLAYING. |
| WIN SEQUENCE | Mario slides down the pole and walks to the castle, then goes to LEVEL COMPLETE. |
| LEVEL COMPLETE | Shows score, coins, time left and the time bonus (time x 50). Enter returns to the title. |
| GAME OVER | Shows the final score. Enter returns to the title. |
| EXIT | Restores the keyboard and timer vectors and text mode, then returns to DOS. |

## 8. Debug keys

Debug keys are active because `DEBUG_KEYS` is set to 1 at the top of `logic.asm`. They exist only to make the live demo faster, as allowed by Section 7.7 of the manual.

| Key | Effect | Demo test |
|-----|--------|-----------|
| T | Sets the time left to 5 seconds | Test 11 (clock reaches 0) |
| C | Sets the coin counter to 99, so the next coin gives a 1-UP | Test 13 (100 coins) |

To turn them off, change `%define DEBUG_KEYS 1` to `0` in `logic.asm` and rebuild.

## 9. Deviations from the manual

1. **Position format is 16.8, not 8.8.** Positions (`hero_x`, `hero_y`, `ent_x`, `ent_y`) use a 16-bit whole-pixel word plus an 8-bit fraction byte. Reason: the level is 60 tiles of 16 pixels, so world x goes up to 959, which does not fit in the 8-bit whole part of a strict 8.8 number. Velocities are true signed 8.8 words, with the constants from Appendix A.5.

## 10. Bonus features

- **Walking animation:** Mario alternates between the stand and run pictures while running, and the Goomba's legs flip every 8 ticks.

## 11. Known limitations

- Only one level (World 1-1) is included.
- No sound effects.
- The game needs about 128 KB of free memory (the program segment plus the frame buffer segment). If it does not fit, the program stops with a message.
- Timing assumes DOSBox. On a very slow emulator setting the frame rate can drop below 30 per second.
