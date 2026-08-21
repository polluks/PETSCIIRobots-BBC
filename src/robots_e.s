; PETSCII Robots - Acorn Electron Port
; Based on C64 version by David Murray 2020
; Ported to BBC Micro by ... and Electron by ...

.include "electron.inc"

; ============================================================
; Zero page variables (matching BBC version)
; ============================================================
TILE        = $00
TEMP_X      = $01
TEMP_Y      = $02
MAP_X       = $03
MAP_Y       = $04
MAP_WIN_X   = $05
MAP_WIN_Y   = $06
UNIT        = $07
TEMP_A      = $08
TEMP_B      = $09
TEMP_C      = $0A
TEMP_D      = $0B
CURSOR_X    = $0C
CURSOR_Y    = $0D
REDRAW_FLAG = $0E
MOVE_RESULT = $0F
UNIT_FIND   = $10
PLAYER_DIR  = $11
RANDOM_SEED = $12
VIEW_COL    = $13
VIEW_ROW    = $14
SCR_PTR_LO  = $15
SCR_PTR_HI  = $16
TMP_PTR_LO  = $17
TMP_PTR_HI  = $18
KEY_PRESS   = $19
KEYTIMER    = $1A
KEY_FAST    = $1B
CLOCK_FRAMES = $1C
CLOCK_SECS  = $1D
CLOCK_MINS  = $1E
CLOCK_HOURS = $1F
CLOCK_ACTIVE = $20
BGTIMER1    = $21
BGTIMER2    = $22
SEARCH_CT   = $23
PLASMA_ACT  = $24
BIG_EXP_ACT = $25
MAGNET_ACT  = $26
GEN_X       = $27
GEN_Y       = $28
GEN_LO      = $29
GEN_HI      = $2A
GEN_TMP     = $2B

; ============================================================
; Constants
; ============================================================
MAP_W      = 128
MAP_H      = 64
MAP_SZ     = MAP_W * MAP_H
MAX_UNITS  = 64
VW         = 38
VH         = 22
VOFFY      = 2

UT_NONE    = 0
UT_PLAYER  = 1
UT_WALKER  = 2
UT_HOVER   = 3
UT_FLOATER = 4
UT_WATER   = 5
UT_BOMB    = 6
UT_TURRET  = 7
UT_REAPER  = 8
UT_BUL_UP  = 12
UT_BUL_DN  = 13
UT_BUL_LT  = 14
UT_BUL_RT  = 15
UT_PL_UP   = 16
UT_PL_DN   = 17
UT_PL_LT   = 18
UT_PL_RT   = 19
UT_MAGNET  = 20
UT_KEY     = 128
UT_TBOMB   = 129
UT_EMPITEM = 130
UT_PISTOL  = 131
UT_PLASMA  = 132
UT_MEDKIT  = 133
UT_MAGITEM = 134

TA_WALK    = 1
TA_MOVE    = 4
TA_DOOR    = 8
TA_WALL    = 16
TA_SEARCH  = 64

; Internal key numbers (BBC/Electron standard layout)
K_UP     = $39
K_DOWN   = $29
K_LEFT   = $19
K_RIGHT  = $79
K_SPACE  = $62
K_X      = $42
K_M      = $65
K_U      = $35
K_D      = $32
K_A      = $41
K_Q      = $10

; Mode 6 screen: 40x25 text, 1 byte per char, $6000 base
; Row 0 = HUD, Rows 1-23 = viewport, Row 24 = message
SCR_HUD     = $6000
SCR_VIEW    = $6028  ; Row 1 start
SCR_MSG     = $63C0  ; Row 24 start (row 24 = $6000 + 24*40 = $63C0)

; ============================================================
; BSS
; ============================================================
.segment "BSS"
MAP_DATA:  .res MAP_SZ
UTYPE:     .res MAX_UNITS
UX:        .res MAX_UNITS
UY:        .res MAX_UNITS
UHP:       .res MAX_UNITS
UTA:       .res MAX_UNITS
UTB:       .res MAX_UNITS
UA:        .res MAX_UNITS
UB:        .res MAX_UNITS
UC:        .res MAX_UNITS
UD:        .res MAX_UNITS
KEYS:      .res 1
AMMO_PI:   .res 1
AMMO_PL:   .res 1
INV_BOMB:  .res 1
INV_EMP:   .res 1
INV_MED:   .res 1
INV_MAG:   .res 1
SEL_WPN:   .res 1
SEL_ITM:   .res 1
P_X:       .res 1
P_Y:       .res 1

; ============================================================
; CODE
; ============================================================
.segment "CODE"

RESET:
    ; Select Mode 6 (40x25 text)
    LDA #22
    JSR OSWRCH
    LDA #6
    JSR OSWRCH
    SEI
    ; Set up VSync-based IRQ or just poll
    CLI
    LDA #0
    STA CLOCK_ACTIVE
    STA REDRAW_FLAG
    STA PLASMA_ACT
    STA BIG_EXP_ACT
    STA MAGNET_ACT
    STA KEY_FAST
    LDA #$A3
    STA RANDOM_SEED
    LDA #12  ; Adjusted for 50Hz (was 15 at 100Hz)
    STA KEYTIMER
    JSR SOUND_INIT
    LDA #<MSG_TITLE
    LDY #>MSG_TITLE
    JSR PRT_STR
    JSR INIT_GAME
    JMP MAIN_LOOP

MSG_TITLE:
    .byte 13,"PETSCII ROBOTS - ELECTRON",13
    .byte "ARROWS=MOVE SPC=FIRE",13
    .byte "X=SEARCH M=MOVE U=USE",13
    .byte "D=WPN A=ITEM Q=QUIT",13,13
    .byte "GENERATING LEVEL...",0

; ============================================================
; VSync wait - OSBYTE 19 waits for next frame fly
; (ULA registers are write-only, cannot poll them)
; ============================================================
WAIT_VSYNC:
    LDA #19
    JSR OSBYTE
    RTS

; ============================================================
; Print null-terminated string at AY
; ============================================================
PRT_STR:
    STA TMP_PTR_LO
    STY TMP_PTR_HI
    LDY #0
PS_L:
    LDA (TMP_PTR_LO),Y
    BEQ PS_E
    JSR OSWRCH
    INY
    BNE PS_L
PS_E:
    RTS

; ============================================================
; Init game
; ============================================================
INIT_GAME:
    LDA #0
    STA KEYS
    STA AMMO_PI
    STA AMMO_PL
    STA INV_BOMB
    STA INV_EMP
    STA INV_MED
    STA INV_MAG
    STA SEL_WPN
    STA SEL_ITM
    STA PLASMA_ACT
    STA BIG_EXP_ACT
    STA MAGNET_ACT
    LDA #15
    STA AMMO_PI
    LDA #1
    STA SEL_WPN
    LDX #0
    LDA #0
IC_L:
    STA UTYPE,X
    INX
    CPX #MAX_UNITS
    BNE IC_L
    JSR GEN_LEVEL
    LDA #UT_PLAYER
    STA UTYPE
    LDA #12
    STA UHP
    LDA #6
    STA PLAYER_DIR
    JSR CENTER_VIEW
    LDA #1
    STA CLOCK_ACTIVE
    LDX #1
IT_L:
    TXA
    STA UTA,X
    LDA #0
    STA UTB,X
    INX
    CPX #48
    BNE IT_L
    JSR DRAW_HUD
    JSR DRAW_MAP
    JSR CLR_MSG
    LDA #1
    STA REDRAW_FLAG
    RTS

CENTER_VIEW:
    LDA P_X
    SEC
    SBC #(VW/2)
    BCC CV_Z1
    STA MAP_WIN_X
    JMP CV_Y
CV_Z1:
    LDA #0
    STA MAP_WIN_X
CV_Y:
    LDA P_Y
    SEC
    SBC #(VH/2)
    BCC CV_Z2
    STA MAP_WIN_Y
    RTS
CV_Z2:
    LDA #0
    STA MAP_WIN_Y
    RTS

; ============================================================
; Background timer tasks
; ============================================================
BTASKS:
    LDX #1
BT_L:
    LDA UTYPE,X
    BEQ BT_N
    LDA UTA,X
    BEQ BT_N
    DEC UTA,X
BT_N:
    INX
    CPX #32
    BNE BT_L
    LDA #1
    STA REDRAW_FLAG
    RTS

; ============================================================
; Clock update (50Hz frame rate)
; ============================================================
UPDATE_CLOCK:
    LDA CLOCK_ACTIVE
    BEQ UC_X
    INC CLOCK_FRAMES
    LDA CLOCK_FRAMES
    CMP #50
    BNE UC_X
    LDA #0
    STA CLOCK_FRAMES
    INC CLOCK_SECS
    LDA CLOCK_SECS
    CMP #60
    BNE UC_X
    LDA #0
    STA CLOCK_SECS
    INC CLOCK_MINS
    LDA CLOCK_MINS
    CMP #60
    BNE UC_X
    LDA #0
    STA CLOCK_MINS
    STA CLOCK_SECS
    INC CLOCK_HOURS
UC_X:
    RTS

; ============================================================
; Main loop
; ============================================================
MAIN_LOOP:
    JSR WAIT_VSYNC
    JSR UPDATE_CLOCK

    JSR BTASKS
    JSR AI_PROC
    LDA UTYPE
    CMP #UT_PLAYER
    BEQ ML_A
    JMP GAMEOVER
ML_A:
    LDA REDRAW_FLAG
    BEQ ML_I
    JSR DRAW_MAP
    JSR DRAW_HUD
    LDA #0
    STA REDRAW_FLAG
ML_I:
    JSR READ_KEY
    CMP #0
    BEQ MAIN_LOOP
    JSR PROC_KEY
    JMP MAIN_LOOP

; ============================================================
; Read key (non-blocking, polled via OSBYTE INKEY scan)
; Returns A = game key code, or 0 if none pressed
; ============================================================
READ_KEY:
    LDA KEYTIMER
    BEQ RK_GO
    DEC KEYTIMER
    LDA #0
    RTS
RK_GO:
    LDX #$4F              ; up
    LDA #K_UP
    JSR KEY_DOWN
    BNE RK_HIT
    LDX #$50              ; down
    LDA #K_DOWN
    JSR KEY_DOWN
    BNE RK_HIT
    LDX #$59              ; left
    LDA #K_LEFT
    JSR KEY_DOWN
    BNE RK_HIT
    LDX #$5A              ; right
    LDA #K_RIGHT
    JSR KEY_DOWN
    BNE RK_HIT
    LDX #$20              ; fire
    LDA #K_SPACE
    JSR KEY_DOWN
    BNE RK_HIT
    LDX #$58              ; search
    LDA #K_X
    JSR KEY_DOWN
    BNE RK_HIT
    LDX #$4D              ; move object
    LDA #K_M
    JSR KEY_DOWN
    BNE RK_HIT
    LDX #$55              ; use item
    LDA #K_U
    JSR KEY_DOWN
    BNE RK_HIT
    LDX #$44              ; cycle weapon
    LDA #K_D
    JSR KEY_DOWN
    BNE RK_HIT
    LDX #$41              ; cycle item
    LDA #K_A
    JSR KEY_DOWN
    BNE RK_HIT
    LDX #$51              ; quit
    LDA #K_Q
    JSR KEY_DOWN
    BNE RK_HIT
    LDA #0
    RTS
RK_HIT:
    STX KEY_PRESS
    LDA #6
    STA KEYTIMER
    LDA KEY_PRESS
    RTS

; Scan single key. A = internal key number, X = game code (preserved).
; Returns A = 1 if pressed, 0 if not.
KEY_DOWN:
    STA TEMP_C
    STX TEMP_D
    LDA TEMP_C
    EOR #$FF              ; negative INKEY value
    TAX
    LDY #$FF
    LDA #$81
    JSR OSBYTE
    CPX #$FF              ; X=$FF on exit => key pressed
    LDX TEMP_D
    LDA #0
    BNE KD_N
    LDA #1
KD_N:
    RTS

; ============================================================
; Process key
; ============================================================
PROC_KEY:
    CMP #$59
    BNE PK_RT
    LDA #12
    STA PLAYER_DIR
    JSR MV_LEFT
    JMP MV_AFTER
PK_RT:
    CMP #$5A
    BNE PK_UP
    LDA #18
    STA PLAYER_DIR
    JSR MV_RIGHT
    JMP MV_AFTER
PK_UP:
    CMP #$4F
    BNE PK_DN
    LDA #0
    STA PLAYER_DIR
    JSR MV_UP
    JMP MV_AFTER
PK_DN:
    CMP #$50
    BNE PK_SPC
    LDA #6
    STA PLAYER_DIR
    JSR MV_DOWN
    JMP MV_AFTER
PK_SPC:
    CMP #$20
    BNE PK_X
    JSR FIRE
    RTS
PK_X:
    CMP #$58
    BNE PK_M
    JSR SEARCH
    RTS
PK_M:
    CMP #$4D
    BNE PK_U
    JSR MOVE_OBJ
    RTS
PK_U:
    CMP #$55
    BNE PK_D
    JSR USE_ITEM
    RTS
PK_D:
    CMP #$44
    BNE PK_A
    JSR CYCLE_WPN
    RTS
PK_A:
    CMP #$41
    BNE PK_Q
    JSR CYCLE_ITM
    RTS
PK_Q:
    CMP #$51
    BNE PK_E
    JMP RESET
PK_E:
    RTS

MV_AFTER:
    LDA MOVE_RESULT
    CMP #1
    BNE MV_X
    JSR CENTER_VIEW
    LDA #1
    STA REDRAW_FLAG
MV_X:
    RTS

; ============================================================
; Movement (identical to BBC version)
; ============================================================
MV_UP:
    LDA P_Y
    BEQ MV_FAIL
    DEC P_Y
    LDA P_Y
    STA MAP_Y
    LDA P_X
    STA MAP_X
    JSR CAN_WALK
    LDA MOVE_RESULT
    BNE MV_OK
    INC P_Y
MV_FAIL:
    LDA #0
    STA MOVE_RESULT
    RTS
MV_OK:
    LDA #1
    STA MOVE_RESULT
    RTS

MV_DOWN:
    LDA P_Y
    CMP #63
    BEQ MV_FAIL2
    INC P_Y
    LDA P_Y
    STA MAP_Y
    LDA P_X
    STA MAP_X
    JSR CAN_WALK
    LDA MOVE_RESULT
    BNE MV_OK2
    DEC P_Y
MV_FAIL2:
    LDA #0
    STA MOVE_RESULT
    RTS
MV_OK2:
    LDA #1
    STA MOVE_RESULT
    RTS

MV_LEFT:
    LDA P_X
    BEQ MV_FAIL3
    DEC P_X
    LDA P_X
    STA MAP_X
    LDA P_Y
    STA MAP_Y
    JSR CAN_WALK
    LDA MOVE_RESULT
    BNE MV_OK3
    INC P_X
MV_FAIL3:
    LDA #0
    STA MOVE_RESULT
    RTS
MV_OK3:
    LDA #1
    STA MOVE_RESULT
    RTS

MV_RIGHT:
    LDA P_X
    CMP #127
    BEQ MV_FAIL4
    INC P_X
    LDA P_X
    STA MAP_X
    LDA P_Y
    STA MAP_Y
    JSR CAN_WALK
    LDA MOVE_RESULT
    BNE MV_OK4
    DEC P_X
MV_FAIL4:
    LDA #0
    STA MOVE_RESULT
    RTS
MV_OK4:
    LDA #1
    STA MOVE_RESULT
    RTS

CAN_WALK:
    JSR GET_TILE
    LDY TILE
    LDA TILE_ATTR,Y
    AND #TA_WALK
    CMP #TA_WALK
    BNE CW_B
    JSR FIND_UNIT
    LDA UNIT_FIND
    CMP #255
    BNE CW_B
    LDA #1
    STA MOVE_RESULT
    RTS
CW_B:
    LDA #0
    STA MOVE_RESULT
    RTS

; ============================================================
; GET_TILE and SET_TILE (identical to BBC version)
; ============================================================
GET_TILE:
    LDA MAP_Y
    STA GEN_LO
    LDA #0
    STA GEN_HI
    LDX #7
GT_M:
    ASL GEN_LO
    ROL GEN_HI
    DEX
    BNE GT_M
    LDA GEN_LO
    CLC
    ADC MAP_X
    STA GEN_LO
    LDA GEN_HI
    ADC #0
    STA GEN_HI
    LDA GEN_LO
    CLC
    ADC #<MAP_DATA
    STA GEN_LO
    LDA GEN_HI
    ADC #>MAP_DATA
    STA GEN_HI
    LDY #0
    LDA (GEN_LO),Y
    STA TILE
    RTS

SET_TILE:
    LDA MAP_Y
    STA GEN_LO
    LDA #0
    STA GEN_HI
    LDX #7
ST_M:
    ASL GEN_LO
    ROL GEN_HI
    DEX
    BNE ST_M
    LDA GEN_LO
    CLC
    ADC MAP_X
    STA GEN_LO
    LDA GEN_HI
    ADC #0
    STA GEN_HI
    LDA GEN_LO
    CLC
    ADC #<MAP_DATA
    STA GEN_LO
    LDA GEN_HI
    ADC #>MAP_DATA
    STA GEN_HI
    LDY #0
    LDA TILE
    STA (GEN_LO),Y
    RTS

; ============================================================
; FIND_UNIT and FIND_HIDDEN (identical to BBC version)
; ============================================================
FIND_UNIT:
    LDX #1
FU_L:
    LDA UTYPE,X
    BEQ FU_N
    LDA UX,X
    CMP MAP_X
    BNE FU_N
    LDA UY,X
    CMP MAP_Y
    BEQ FU_F
FU_N:
    INX
    CPX #MAX_UNITS
    BNE FU_L
    LDA #255
    STA UNIT_FIND
    RTS
FU_F:
    STX UNIT_FIND
    RTS

FIND_HIDDEN:
    LDX #0
FH_L:
    LDA UTYPE,X
    CMP #128
    BCC FH_N
    LDA UX,X
    CMP MAP_X
    BNE FH_N
    LDA UY,X
    CMP MAP_Y
    BEQ FH_F
FH_N:
    INX
    CPX #MAX_UNITS
    BNE FH_L
    LDA #255
    STA UNIT_FIND
    RTS
FH_F:
    STX UNIT_FIND
    RTS

; ============================================================
; Fire, AI, Search, Items, etc. (identical to BBC version)
; ============================================================
FIRE:
    LDA SEL_WPN
    CMP #1
    BNE FW_P
    JMP FIRE_P
FW_P:
    CMP #2
    BNE FW_X
    JMP FIRE_PL
FW_X:
    RTS

FIRE_P:
    LDA AMMO_PI
    BNE FP_A
    RTS
FP_A:
    LDX #28
FP_L:
    LDA UTYPE,X
    BEQ FP_F
    INX
    CPX #32
    BNE FP_L
    RTS
FP_F:
    LDA PLAYER_DIR
    CMP #0
    BNE FP_D
    LDA #UT_BUL_UP
    JMP FP_S
FP_D:
    CMP #6
    BNE FP_LT
    LDA #UT_BUL_DN
    JMP FP_S
FP_LT:
    CMP #12
    BNE FP_R
    LDA #UT_BUL_LT
    JMP FP_S
FP_R:
    LDA #UT_BUL_RT
FP_S:
    STA UTYPE,X
    LDA P_X
    STA UX,X
    LDA P_Y
    STA UY,X
    LDA #3
    STA UA,X
    LDA #0
    STA UB,X
    LDA #0
    STA UTA,X
    DEC AMMO_PI
    JSR FX_PISTOL
    LDA #1
    STA REDRAW_FLAG
    RTS

FIRE_PL:
    LDA PLASMA_ACT
    BNE FP_X2
    LDA BIG_EXP_ACT
    BNE FP_X2
    LDA AMMO_PL
    BNE FP_A2
FP_X2:
    RTS
FP_A2:
    LDX #28
FP_L2:
    LDA UTYPE,X
    BEQ FP_F2
    INX
    CPX #32
    BNE FP_L2
    RTS
FP_F2:
    LDA PLAYER_DIR
    CMP #0
    BNE FP_D2
    LDA #UT_PL_UP
    JMP FP_S2
FP_D2:
    CMP #6
    BNE FP_L2T
    LDA #UT_PL_DN
    JMP FP_S2
FP_L2T:
    CMP #12
    BNE FP_R2
    LDA #UT_PL_LT
    JMP FP_S2
FP_R2:
    LDA #UT_PL_RT
FP_S2:
    STA UTYPE,X
    LDA P_X
    STA UX,X
    LDA P_Y
    STA UY,X
    LDA #3
    STA UA,X
    LDA #1
    STA UB,X
    LDA #1
    STA PLASMA_ACT
    LDA #0
    STA UTA,X
    DEC AMMO_PL
    JSR FX_PLASMA
    LDA #1
    STA REDRAW_FLAG
    RTS

; ============================================================
; AI processing (identical logic, adjusted timers for 50Hz)
; ============================================================
AI_PROC:
    LDX #1
AI_L:
    LDA UTYPE,X
    BEQ AI_N
    CMP #128
    BCS AI_N
    CMP #UT_WALKER
    BNE AI_CHK_H
    JSR AI_WALK
    JMP AI_N
AI_CHK_H:
    CMP #UT_HOVER
    BNE AI_CHK_F
    JSR AI_HOVER
    JMP AI_N
AI_CHK_F:
    CMP #UT_FLOATER
    BNE AI_CHK_B
    JSR AI_FLOAT
    JMP AI_N
AI_CHK_B:
    CMP #UT_BOMB
    BNE AI_CHK_T
    JSR AI_BOMB
    JMP AI_N
AI_CHK_T:
    CMP #UT_TURRET
    BNE AI_CHK_R
    JSR AI_TURRET
    JMP AI_N
AI_CHK_R:
    CMP #UT_REAPER
    BNE AI_CHK_BU
    JSR AI_REAPER
    JMP AI_N
AI_CHK_BU:
    CMP #UT_BUL_UP
    BCC AI_N
    CMP #UT_PL_RT+1
    BCS AI_N
    JSR AI_BULLET
AI_N:
    INX
    CPX #32
    BNE AI_L
    RTS

; ============================================================
; AI toward player (identical)
; ============================================================
AI_TOWARD:
    STX UNIT
    LDA UX,X
    CMP P_X
    BCC AI_GO_R
    BNE AI_GO_L
    LDA UY,X
    CMP P_Y
    BCC AI_GO_D
    BNE AI_GO_U
    JMP AI_ATK
AI_GO_R:
    INC UX,X
    JMP AI_CK
AI_GO_L:
    DEC UX,X
    JMP AI_CK
AI_GO_D:
    INC UY,X
    JMP AI_CK
AI_GO_U:
    DEC UY,X
AI_CK:
    LDX UNIT
    LDA UX,X
    STA MAP_X
    LDA UY,X
    STA MAP_Y
    JSR GET_TILE
    LDY TILE
    LDA TILE_ATTR,Y
    AND #TA_WALK
    BNE AI_CK2
    LDX UNIT
    LDA UX,X
    CMP P_X
    BCC AI_RV_R
    BNE AI_RV_L
    LDA UY,X
    CMP P_Y
    BCC AI_RV_D
    BNE AI_RV_U
    RTS
AI_RV_R:
    DEC UX,X
    RTS
AI_RV_L:
    INC UX,X
    RTS
AI_RV_D:
    DEC UY,X
    RTS
AI_RV_U:
    INC UY,X
    RTS
AI_CK2:
    LDA UX,X
    CMP P_X
    BNE AI_DN
    LDA UY,X
    CMP P_Y
    BNE AI_DN
AI_ATK:
    DEC UHP
    JSR FX_HURT
    LDA #1
    STA REDRAW_FLAG
    LDA UHP
    BNE AI_DN
    LDA #0
    STA UTYPE
AI_DN:
    LDX UNIT
    RTS

; AI types with timers adjusted for 50Hz (half of BBC 100Hz values)
AI_WALK:
    JSR AI_TOWARD
    LDA #25
    STA UTA,X
    RTS
AI_HOVER:
    JSR AI_TOWARD
    LDA #13
    STA UTA,X
    RTS
AI_FLOAT:
    JSR AI_TOWARD
    LDA #8
    STA UTA,X
    RTS
AI_BOMB:
    LDA UTA,X
    BNE AI_BB
    LDA UX,X
    STA MAP_X
    LDA UY,X
    STA MAP_Y
    JSR BIG_EXP
    LDA #0
    STA UTYPE,X
AI_BB:
    RTS
AI_TURRET:
    LDA #18
    STA UTA,X
    LDA UX,X
    CMP P_X
    BEQ AI_TF
    LDA UY,X
    CMP P_Y
    BNE AI_TD
AI_TF:
    DEC UHP
    JSR FX_HURT
    LDA #1
    STA REDRAW_FLAG
AI_TD:
    RTS
AI_REAPER:
    JSR AI_TOWARD
    LDA #10
    STA UTA,X
    RTS

; ============================================================
; AI bullets (identical)
; ============================================================
AI_BULLET:
    STX UNIT
    LDA UTYPE,X
    CMP #UT_PL_UP
    BCS AI_BP
    JMP AI_BUL_NORM
AI_BP:
    JMP AI_BUL_PLASMA

AI_BUL_NORM:
    JSR AI_BUL_MOVE
    BCC AI_BN_HIT
    RTS
AI_BN_HIT:
    LDA #0
    STA UTYPE,X
    LDA #1
    STA REDRAW_FLAG
    RTS

AI_BUL_PLASMA:
    JSR AI_BUL_MOVE
    BCC AI_BP_HIT
    RTS
AI_BP_HIT:
    LDA #0
    STA UTYPE,X
    STA PLASMA_ACT
    LDA UX,X
    STA MAP_X
    LDA UY,X
    STA MAP_Y
    JSR BIG_EXP
    LDA #1
    STA REDRAW_FLAG
    RTS

AI_BUL_MOVE:
    LDX UNIT
    LDA UTYPE,X
    CMP #UT_BUL_UP
    BEQ AI_B_U
    CMP #UT_PL_UP
    BEQ AI_B_U
    CMP #UT_BUL_DN
    BEQ AI_B_D
    CMP #UT_PL_DN
    BEQ AI_B_D
    CMP #UT_BUL_LT
    BEQ AI_B_L
    CMP #UT_PL_LT
    BEQ AI_B_L
    CMP #UT_BUL_RT
    BEQ AI_B_R
    CMP #UT_PL_RT
    BEQ AI_B_R
    CLC
    RTS
AI_B_U:
    LDA UY,X
    BNE AI_B_U2
    JMP AI_B_END
AI_B_U2:
    DEC UY,X
    JMP AI_B_CHK
AI_B_D:
    LDA UY,X
    CMP #63
    BEQ AI_B_END
    INC UY,X
    JMP AI_B_CHK
AI_B_L:
    LDA UX,X
    BEQ AI_B_END
    DEC UX,X
    JMP AI_B_CHK
AI_B_R:
    LDA UX,X
    CMP #127
    BEQ AI_B_END
    INC UX,X
AI_B_CHK:
    LDX UNIT
    LDA UX,X
    STA MAP_X
    LDA UY,X
    STA MAP_Y
    JSR GET_TILE
    LDY TILE
    LDA TILE_ATTR,Y
    AND #TA_WALK
    BNE AI_B_CK2
    CLC
    RTS
AI_B_CK2:
    JSR FIND_UNIT
    LDA UNIT_FIND
    CMP #255
    BNE AI_B_HITU
    LDX UNIT
    LDA UA,X
    BEQ AI_B_END
    DEC UA,X
    LDA #1
    STA REDRAW_FLAG
    SEC
    RTS
AI_B_HITU:
    CMP #0
    BNE AI_B_HIT3
    SEC
    RTS
AI_B_HIT3:
    TAY
    LDA UTYPE,Y
    CMP #2
    BCC AI_B_OK
    CMP #12
    BCS AI_B_OK
    LDA UHP,Y
    BEQ AI_B_KILL
    SEC
    SBC #1
    STA UHP,Y
    BNE AI_B_KILL
    LDA #0
    STA UTYPE,Y
AI_B_KILL:
    LDA #0
    STA UTYPE,X
    LDA #1
    STA REDRAW_FLAG
    CLC
    RTS
AI_B_OK:
    SEC
    RTS
AI_B_END:
    LDA #0
    STA UTYPE,X
    CLC
    RTS

; ============================================================
; Big explosion (identical)
; ============================================================
BIG_EXP:
    JSR FX_EXPLODE
    LDA #1
    STA BIG_EXP_ACT
    LDX #1
BE_L:
    LDA UTYPE,X
    BEQ BE_N
    CMP #128
    BCS BE_N
    LDA UX,X
    SEC
    SBC MAP_X
    BPL BE_DX
    EOR #$FF
    CLC
    ADC #1
BE_DX:
    CMP #3
    BCS BE_N
    LDA UY,X
    SEC
    SBC MAP_Y
    BPL BE_DY
    EOR #$FF
    CLC
    ADC #1
BE_DY:
    CMP #3
    BCS BE_N
    LDA #0
    STA UHP,X
    STA UTYPE,X
BE_N:
    INX
    CPX #MAX_UNITS
    BNE BE_L
    LDA #0
    STA BIG_EXP_ACT
    RTS

; ============================================================
; Game over (identical)
; ============================================================
GAMEOVER:
    LDA #12
    JSR OSWRCH
    LDA #<MSG_GO
    LDY #>MSG_GO
    JSR PRT_STR
GO_W:
    LDA #$81
    LDX #0
    LDY #100
    JSR OSBYTE
    TXA
    BEQ GO_W
    JMP RESET

MSG_GO:
    .byte 13,"GAME OVER!",13
    .byte "PRESS ANY KEY",0

; ============================================================
; Cycle weapons/items (identical)
; ============================================================
CYCLE_WPN:
    LDA SEL_WPN
    CMP #1
    BNE CW_N
    LDA #2
    STA SEL_WPN
    JMP CW_DN
CW_N:
    CMP #2
    BNE CW_Z
    LDA #0
    STA SEL_WPN
    JMP CW_DN
CW_Z:
    LDA #1
    STA SEL_WPN
CW_DN:
    LDA #1
    STA REDRAW_FLAG
    RTS

CYCLE_ITM:
    LDA SEL_ITM
    CMP #1
    BNE CI_N
    LDA #2
    STA SEL_ITM
    JMP CI_DN
CI_N:
    CMP #2
    BNE CI_N2
    LDA #3
    STA SEL_ITM
    JMP CI_DN
CI_N2:
    CMP #3
    BNE CI_N3
    LDA #4
    STA SEL_ITM
    JMP CI_DN
CI_N3:
    CMP #4
    BNE CI_Z
    LDA #0
    STA SEL_ITM
    JMP CI_DN
CI_Z:
    LDA #1
    STA SEL_ITM
CI_DN:
    LDA #1
    STA REDRAW_FLAG
    RTS

; ============================================================
; SEARCH (identical)
; ============================================================
SEARCH:
    LDA P_X
    STA MAP_X
    LDA P_Y
    STA MAP_Y
    JSR FIND_HIDDEN
    LDA UNIT_FIND
    CMP #255
    BNE SF_F
    LDA #<MSG_NOTHING
    LDY #>MSG_NOTHING
    JSR PRINT_MSG
    RTS
SF_F:
    LDX UNIT_FIND
    LDA UTYPE,X
    STA TEMP_A
    LDA UA,X
    STA TEMP_B
    LDA #0
    STA UTYPE,X
    LDA TEMP_A
    CMP #UT_KEY
    BNE SF_B
    LDA TEMP_B
    BEQ SF_KS
    CMP #1
    BEQ SF_KH
    LDA KEYS
    ORA #4
    STA KEYS
    JMP SF_KM
SF_KS:
    LDA KEYS
    ORA #1
    STA KEYS
    JMP SF_KM
SF_KH:
    LDA KEYS
    ORA #2
    STA KEYS
SF_KM:
    JSR FX_ITEM
    LDA #<MSG_FKEY
    LDY #>MSG_FKEY
    JSR PRINT_MSG
    RTS
SF_B:
    CMP #UT_TBOMB
    BNE SF_E
    LDA TEMP_B
    CLC
    ADC INV_BOMB
    STA INV_BOMB
    LDA #<MSG_FBOMB
    LDY #>MSG_FBOMB
    JSR PRINT_MSG
    RTS
SF_E:
    CMP #UT_EMPITEM
    BNE SF_P
    LDA TEMP_B
    CLC
    ADC INV_EMP
    STA INV_EMP
    LDA #<MSG_FEMP
    LDY #>MSG_FEMP
    JSR PRINT_MSG
    RTS
SF_P:
    CMP #UT_PISTOL
    BNE SF_PL
    LDA TEMP_B
    CLC
    ADC AMMO_PI
    STA AMMO_PI
    LDA #<MSG_FGUN
    LDY #>MSG_FGUN
    JSR PRINT_MSG
    RTS
SF_PL:
    CMP #UT_PLASMA
    BNE SF_MK
    LDA TEMP_B
    CLC
    ADC AMMO_PL
    STA AMMO_PL
    LDA #<MSG_FPLASMA
    LDY #>MSG_FPLASMA
    JSR PRINT_MSG
    RTS
SF_MK:
    CMP #UT_MEDKIT
    BNE SF_MG
    LDA TEMP_B
    CLC
    ADC INV_MED
    STA INV_MED
    LDA #<MSG_FMED
    LDY #>MSG_FMED
    JSR PRINT_MSG
    RTS
SF_MG:
    CMP #UT_MAGITEM
    BNE SF_DN
    LDA TEMP_B
    CLC
    ADC INV_MAG
    STA INV_MAG
    LDA #<MSG_FMAG
    LDY #>MSG_FMAG
    JSR PRINT_MSG
SF_DN:
    LDA #1
    STA REDRAW_FLAG
    RTS

; ============================================================
; Move object, Use item (identical)
; ============================================================
MOVE_OBJ:
    LDA PLAYER_DIR
    CMP #0
    BNE MO_LT
    LDA P_Y
    BEQ MO_FL
    DEC MAP_Y
    JMP MO_TRY
MO_LT:
    CMP #12
    BNE MO_DN
    LDA P_X
    BEQ MO_FL
    DEC MAP_X
    JMP MO_TRY
MO_DN:
    CMP #6
    BNE MO_RT
    LDA P_Y
    CMP #63
    BEQ MO_FL
    INC MAP_Y
    JMP MO_TRY
MO_RT:
    LDA P_X
    CMP #127
    BEQ MO_FL
    INC MAP_X
MO_TRY:
    JSR GET_TILE
    LDY TILE
    LDA TILE_ATTR,Y
    AND #TA_MOVE
    BNE MO_DO
MO_FL:
    LDA #<MSG_CANT
    LDY #>MSG_CANT
    JSR PRINT_MSG
    RTS
MO_DO:
    JSR FX_MOVE
    LDA #1
    STA REDRAW_FLAG
    RTS

USE_ITEM:
    LDA SEL_ITM
    CMP #1
    BNE UI_E
    JMP USE_BOMB
UI_E:
    CMP #2
    BNE UI_M
    JMP USE_EMP
UI_M:
    CMP #3
    BNE UI_G
    JMP USE_MEDKIT
UI_G:
    CMP #4
    BNE UI_X
    JMP USE_MAG
UI_X:
    RTS

USE_BOMB:
    LDA INV_BOMB
    BEQ UB_X
    LDX #28
UB_L:
    LDA UTYPE,X
    BEQ UB_F
    INX
    CPX #32
    BNE UB_L
    RTS
UB_F:
    LDA #UT_BOMB
    STA UTYPE,X
    LDA P_X
    STA UX,X
    LDA P_Y
    STA UY,X
    LDA #25  ; Adjusted for 50Hz (was 50)
    STA UTA,X
    LDA #0
    STA UA,X
    DEC INV_BOMB
    JSR FX_MOVE
    LDA #1
    STA REDRAW_FLAG
UB_X:
    RTS

USE_EMP:
    LDA INV_EMP
    BEQ UE_X
    DEC INV_EMP
    LDX #1
UE_L:
    LDA UTYPE,X
    BEQ UE_N
    CMP #128
    BCS UE_N
    LDA UX,X
    SEC
    SBC P_X
    BPL UE_DX
    EOR #$FF
    CLC
    ADC #1
UE_DX:
    CMP #8
    BCS UE_N
    LDA UY,X
    SEC
    SBC P_Y
    BPL UE_DY
    EOR #$FF
    CLC
    ADC #1
UE_DY:
    CMP #6
    BCS UE_N
    LDA #255
    STA UTA,X
UE_N:
    INX
    CPX #28
    BNE UE_L
    LDA #<MSG_EMP
    LDY #>MSG_EMP
    JSR PRINT_MSG
    JSR FX_EMP
    LDA #1
    STA REDRAW_FLAG
UE_X:
    RTS

USE_MEDKIT:
    LDA INV_MED
    BEQ UM_X
    LDA UHP
    CMP #12
    BEQ UM_X
    LDA #12
    SEC
    SBC UHP
    STA TEMP_A
    LDA INV_MED
    SEC
    SBC TEMP_A
    BCC UM_P
    LDA #12
    STA UHP
    LDA INV_MED
    SEC
    SBC TEMP_A
    STA INV_MED
    JMP UM_D
UM_P:
    LDA INV_MED
    CLC
    ADC UHP
    STA UHP
    LDA #0
    STA INV_MED
UM_D:
    LDA #<MSG_HEAL
    LDY #>MSG_HEAL
    JSR PRINT_MSG
    JSR FX_MEDKIT
    LDA #1
    STA REDRAW_FLAG
UM_X:
    RTS

USE_MAG:
    LDA INV_MAG
    BEQ UMG_X
    LDA MAGNET_ACT
    BNE UMG_X
    LDX #28
UMG_L:
    LDA UTYPE,X
    BEQ UMG_F
    INX
    CPX #32
    BNE UMG_L
    RTS
UMG_F:
    LDA #UT_MAGNET
    STA UTYPE,X
    LDA P_X
    STA UX,X
    LDA P_Y
    STA UY,X
    LDA #1
    STA UTA,X
    LDA #255
    STA UTB,X
    LDA #5
    STA UA,X
    LDA #1
    STA MAGNET_ACT
    DEC INV_MAG
    JSR FX_MOVE
    LDA #1
    STA REDRAW_FLAG
UMG_X:
    RTS

; ============================================================
; Draw viewport (Mode 6 - 40x25 text, single byte per char)
; ============================================================
DRAW_MAP:
    LDA #<SCR_VIEW
    STA SCR_PTR_LO
    LDA #>SCR_VIEW
    STA SCR_PTR_HI

    LDA #0
    STA VIEW_ROW
DR_L:
    LDA SCR_PTR_LO
    STA TMP_PTR_LO
    LDA SCR_PTR_HI
    STA TMP_PTR_HI

    LDA #0
    STA VIEW_COL
DC_L:
    LDA VIEW_COL
    CLC
    ADC MAP_WIN_X
    STA MAP_X
    LDA VIEW_ROW
    CLC
    ADC MAP_WIN_Y
    STA MAP_Y
    JSR GET_TILE

    LDA MAP_X
    CMP P_X
    BNE DC_CK
    LDA MAP_Y
    CMP P_Y
    BNE DC_CK
    LDA #'@'
    LDY #0
    STA (TMP_PTR_LO),Y
    JMP DC_N

DC_CK:
    JSR FIND_UNIT
    LDA UNIT_FIND
    CMP #255
    BEQ DC_NOU
    TAY
    LDA UTYPE,Y
    CMP #1
    BEQ DC_PLAYER
    CMP #128
    BCS DC_HID
    CMP #12
    BCS DC_WP
    LDA UTYPE,Y
    CLC
    ADC #64
    CMP #91
    BCC DC_WR
    LDA #'R'
DC_WR:
    LDY #0
    STA (TMP_PTR_LO),Y
    JMP DC_N
DC_PLAYER:
    LDA #'@'
    LDY #0
    STA (TMP_PTR_LO),Y
    JMP DC_N
DC_HID:
    LDA #'?'
    LDY #0
    STA (TMP_PTR_LO),Y
    JMP DC_N
DC_WP:
    LDA #'*'
    LDY #0
    STA (TMP_PTR_LO),Y
    JMP DC_N

DC_NOU:
    LDY TILE
    LDA TILE_CHRS,Y
DC_DF:
    LDY #0
    STA (TMP_PTR_LO),Y

DC_N:
    INC TMP_PTR_LO
    BNE DC_N2
    INC TMP_PTR_HI
DC_N2:
    INC VIEW_COL
    LDA VIEW_COL
    CMP #VW
    BEQ DC_R
    JMP DC_L
DC_R:
    LDA SCR_PTR_LO
    CLC
    ADC #40
    STA SCR_PTR_LO
    LDA SCR_PTR_HI
    ADC #0
    STA SCR_PTR_HI
    INC VIEW_ROW
    LDA VIEW_ROW
    CMP #VH
    BEQ DR_END
    JMP DR_L
DR_END:
    RTS

; ============================================================
; Draw HUD (Mode 6 - single byte per char, no colour)
; ============================================================
DRAW_HUD:
    LDA #<SCR_HUD
    STA SCR_PTR_LO
    LDA #>SCR_HUD
    STA SCR_PTR_HI
    LDY #0

    LDA #'H'
    STA (SCR_PTR_LO),Y
    INY
    LDA #'P'
    STA (SCR_PTR_LO),Y
    INY
    LDA #':'
    STA (SCR_PTR_LO),Y
    INY
    LDA UHP
    JSR DEC2

    LDA #' '
    STA (SCR_PTR_LO),Y
    INY

    LDA #'W'
    STA (SCR_PTR_LO),Y
    INY
    LDA #':'
    STA (SCR_PTR_LO),Y
    INY
    LDA SEL_WPN
    CMP #1
    BNE DH_WP
    LDA #'P'
    STA (SCR_PTR_LO),Y
    INY
    LDA #'I'
    STA (SCR_PTR_LO),Y
    INY
    LDA #' '
    STA (SCR_PTR_LO),Y
    INY
    LDA AMMO_PI
    JSR DEC2
    JMP DH_I
DH_WP:
    CMP #2
    BNE DH_WN
    LDA #'P'
    STA (SCR_PTR_LO),Y
    INY
    LDA #'L'
    STA (SCR_PTR_LO),Y
    INY
    LDA #' '
    STA (SCR_PTR_LO),Y
    INY
    LDA AMMO_PL
    JSR DEC2
    JMP DH_I
DH_WN:
    LDA #'N'
    STA (SCR_PTR_LO),Y
    INY
    LDA #'O'
    STA (SCR_PTR_LO),Y
    INY
    LDA #'N'
    STA (SCR_PTR_LO),Y
    INY
    LDA #'E'
    STA (SCR_PTR_LO),Y
    INY

DH_I:
    LDA #' '
    STA (SCR_PTR_LO),Y
    INY
    LDA #'I'
    STA (SCR_PTR_LO),Y
    INY
    LDA #':'
    STA (SCR_PTR_LO),Y
    INY
    LDA SEL_ITM
    CMP #1
    BNE DH_IE
    LDA #'B'
    STA (SCR_PTR_LO),Y
    INY
    LDA INV_BOMB
    JSR DEC1
    JMP DH_K
DH_IE:
    CMP #2
    BNE DH_IM
    LDA #'E'
    STA (SCR_PTR_LO),Y
    INY
    LDA INV_EMP
    JSR DEC1
    JMP DH_K
DH_IM:
    CMP #3
    BNE DH_IG
    LDA #'M'
    STA (SCR_PTR_LO),Y
    INY
    LDA INV_MED
    JSR DEC1
    JMP DH_K
DH_IG:
    CMP #4
    BNE DH_IN
    LDA #'G'
    STA (SCR_PTR_LO),Y
    INY
    LDA INV_MAG
    JSR DEC1
    JMP DH_K
DH_IN:
    LDA #'N'
    STA (SCR_PTR_LO),Y
    INY

DH_K:
    LDA #' '
    STA (SCR_PTR_LO),Y
    INY
    LDA #'K'
    STA (SCR_PTR_LO),Y
    INY
    LDA #':'
    STA (SCR_PTR_LO),Y
    INY
    LDA KEYS
    AND #1
    BEQ DH_KS
    LDA #'S'
    STA (SCR_PTR_LO),Y
    INY
    JMP DH_KH
DH_KS:
    LDA #'-'
    STA (SCR_PTR_LO),Y
    INY
DH_KH:
    LDA KEYS
    AND #2
    BEQ DH_KHN
    LDA #'H'
    STA (SCR_PTR_LO),Y
    INY
    JMP DH_KST
DH_KHN:
    LDA #'-'
    STA (SCR_PTR_LO),Y
    INY
DH_KST:
    LDA KEYS
    AND #4
    BEQ DH_KSN
    LDA #'*'
    STA (SCR_PTR_LO),Y
    INY
    JMP DH_CLK
DH_KSN:
    LDA #'-'
    STA (SCR_PTR_LO),Y
    INY

DH_CLK:
    LDA #' '
    STA (SCR_PTR_LO),Y
    INY
    LDA CLOCK_MINS
    JSR DEC2
    LDA #':'
    STA (SCR_PTR_LO),Y
    INY
    LDA CLOCK_SECS
    JSR DEC2

DH_FILL:
    TYA
    CMP #40
    BCS DH_DN
    LDA #' '
    STA (SCR_PTR_LO),Y
    INY
    JMP DH_FILL
DH_DN:
    RTS

; ============================================================
; Decimal printing (same as BBC)
; ============================================================
DEC2:
    STA TEMP_A
    LDA #0
    STA TEMP_B
    LDA TEMP_A
D2_L:
    CMP #10
    BCC D2_D
    SBC #10
    INC TEMP_B
    JMP D2_L
D2_D:
    PHA
    LDA TEMP_B
    CMP #0
    BEQ D2_LD
    CLC
    ADC #'0'
    STA (SCR_PTR_LO),Y
    INY
    JMP D2_U
D2_LD:
    LDA #' '
    STA (SCR_PTR_LO),Y
    INY
D2_U:
    PLA
    CLC
    ADC #'0'
    STA (SCR_PTR_LO),Y
    INY
    RTS

DEC1:
    CLC
    ADC #'0'
    STA (SCR_PTR_LO),Y
    INY
    RTS

; ============================================================
; Clear message line (Mode 6)
; ============================================================
CLR_MSG:
    LDA #<SCR_MSG
    STA TMP_PTR_LO
    LDA #>SCR_MSG
    STA TMP_PTR_HI
    LDA #' '
    LDY #0
CM_L:
    STA (TMP_PTR_LO),Y
    INY
    CPY #40
    BNE CM_L
    RTS

; ============================================================
; Print message on row 24 (Mode 6)
; ============================================================
PRINT_MSG:
    STA GEN_LO
    STY GEN_HI
    JSR CLR_MSG
    LDA #<SCR_MSG
    STA SCR_PTR_LO
    LDA #>SCR_MSG
    STA SCR_PTR_HI
    LDY #0
    LDX #0
PM_L:
    LDA (GEN_LO),Y
    BEQ PM_D
    STA (SCR_PTR_LO),Y
    INY
    INX
    CPX #39
    BCC PM_L
PM_D:
    RTS

; ============================================================
; Electron ULA Sound driver (single tone channel)
; ============================================================
SOUND_INIT:
    LDA #0
    STA SOUND_FREQ
    RTS

; Play tone at frequency A (0=off, 1-255=tone)
; Electron ULA: write to $FE07, 0=off
ULA_TONE:
    STA SOUND_FREQ
    RTS

; Simple delay for sound duration
; A = delay length (0-255, roughly 10ms units at 1MHz)
SND_DELAY:
    STA TEMP_A
SD_L:
    LDX #0
SD_L2:
    DEX
    BNE SD_L2
    DEC TEMP_A
    BNE SD_L
    RTS

; Sound effects
FX_PISTOL:
    LDA #200
    JSR ULA_TONE
    LDA #10
    JSR SND_DELAY
    LDA #0
    JSR ULA_TONE
    RTS

FX_PLASMA:
    LDA #100
    JSR ULA_TONE
    LDA #15
    JSR SND_DELAY
    LDA #50
    JSR ULA_TONE
    LDA #15
    JSR SND_DELAY
    LDA #0
    JSR ULA_TONE
    RTS

FX_EXPLODE:
    LDA #30
    JSR ULA_TONE
    LDA #20
    JSR SND_DELAY
    LDA #10
    JSR ULA_TONE
    LDA #20
    JSR SND_DELAY
    LDA #0
    JSR ULA_TONE
    RTS

FX_MOVE:
    LDA #150
    JSR ULA_TONE
    LDA #5
    JSR SND_DELAY
    LDA #0
    JSR ULA_TONE
    RTS

FX_ITEM:
    LDA #180
    JSR ULA_TONE
    LDA #8
    JSR SND_DELAY
    LDA #220
    JSR ULA_TONE
    LDA #8
    JSR SND_DELAY
    LDA #0
    JSR ULA_TONE
    RTS

FX_MEDKIT:
    LDA #120
    JSR ULA_TONE
    LDA #10
    JSR SND_DELAY
    LDA #160
    JSR ULA_TONE
    LDA #10
    JSR SND_DELAY
    LDA #0
    JSR ULA_TONE
    RTS

FX_EMP:
    LDA #60
    JSR ULA_TONE
    LDA #15
    JSR SND_DELAY
    LDA #30
    JSR ULA_TONE
    LDA #15
    JSR SND_DELAY
    LDA #10
    JSR ULA_TONE
    LDA #15
    JSR SND_DELAY
    LDA #0
    JSR ULA_TONE
    RTS

FX_HURT:
    LDA #40
    JSR ULA_TONE
    LDA #15
    JSR SND_DELAY
    LDA #0
    JSR ULA_TONE
    RTS

; ============================================================
; Procedural level generation (identical to BBC version)
; ============================================================
GEN_LEVEL:
    LDA #0
    STA GEN_Y
GL_YL:
    LDA #0
    STA GEN_X
GL_XL:
    LDA #2
    STA TILE
    JSR GL_SET
    INC GEN_X
    LDA GEN_X
    CMP #MAP_W
    BNE GL_XL
    INC GEN_Y
    LDA GEN_Y
    CMP #MAP_H
    BNE GL_YL

    LDX #0
    LDA #0
GL_CL:
    STA UTYPE,X
    INX
    CPX #MAX_UNITS
    BNE GL_CL

    LDA #5
    STA GEN_X
    LDA #5
    STA GEN_Y
    JSR GL_ROOM

    LDA #25
    STA GEN_X
    LDA #5
    STA GEN_Y
    JSR GL_ROOM

    LDA #50
    STA GEN_X
    LDA #5
    STA GEN_Y
    JSR GL_ROOM

    LDA #5
    STA GEN_X
    LDA #25
    STA GEN_Y
    JSR GL_ROOM

    LDA #25
    STA GEN_X
    LDA #25
    STA GEN_Y
    JSR GL_ROOM

    LDA #50
    STA GEN_X
    LDA #25
    STA GEN_Y
    JSR GL_ROOM

    LDA #5
    STA GEN_X
    LDA #45
    STA GEN_Y
    JSR GL_ROOM

    LDA #25
    STA GEN_X
    LDA #45
    STA GEN_Y
    JSR GL_ROOM

    LDA #50
    STA GEN_X
    LDA #45
    STA GEN_Y
    JSR GL_ROOM

    LDA #90
    STA GEN_X
    LDA #25
    STA GEN_Y
    JSR GL_ROOM

    LDA #90
    STA GEN_X
    LDA #45
    STA GEN_Y
    JSR GL_ROOM

    LDA #13
    STA GEN_X
    LDA #13
    STA GEN_Y
GL_CH1:
    LDA GEN_X
    CMP #25
    BCS GL_CH2
    LDA #1
    STA TILE
    JSR GL_SET
    INC GEN_X
    JMP GL_CH1
GL_CH2:
    LDA #33
    STA GEN_Y
    LDA #25
    STA GEN_X
GL_CH3:
    LDA GEN_X
    CMP #50
    BCS GL_CH4
    LDA #1
    STA TILE
    JSR GL_SET
    INC GEN_X
    JMP GL_CH3
GL_CH4:
    LDA #13
    STA GEN_Y
    LDA #5
    STA GEN_X
GL_CH5:
    LDA GEN_X
    CMP #13
    BCS GL_CV1
    LDA #1
    STA TILE
    JSR GL_SET
    INC GEN_X
    JMP GL_CH5
GL_CV1:
    LDA #13
    STA GEN_X
    LDA #5
    STA GEN_Y
GL_CV2:
    LDA GEN_Y
    CMP #13
    BCS GL_CH6
    LDA #1
    STA TILE
    JSR GL_SET
    INC GEN_Y
    JMP GL_CV2
GL_CH6:
    LDA #33
    STA GEN_X
    LDA #13
    STA GEN_Y
GL_CV3:
    LDA GEN_Y
    CMP #25
    BCS GL_CH7
    LDA #1
    STA TILE
    JSR GL_SET
    INC GEN_Y
    JMP GL_CV3
GL_CH7:
    LDA #50
    STA GEN_X
    LDA #5
    STA GEN_Y
GL_CV4:
    LDA GEN_Y
    CMP #25
    BCS GL_CH8
    LDA #1
    STA TILE
    JSR GL_SET
    INC GEN_Y
    JMP GL_CV4
GL_CH8:
    LDA #90
    STA GEN_X
    LDA #13
    STA GEN_Y
GL_CV5:
    LDA GEN_Y
    CMP #25
    BCS GL_CH9
    LDA #1
    STA TILE
    JSR GL_SET
    INC GEN_Y
    JMP GL_CV5
GL_CH9:
    LDA #50
    STA GEN_X
    LDA #33
    STA GEN_Y
GL_CV6:
    LDA GEN_Y
    CMP #45
    BCS GL_CH10
    LDA #1
    STA TILE
    JSR GL_SET
    INC GEN_Y
    JMP GL_CV6
GL_CH10:
    LDA #90
    STA GEN_X
    LDA #33
    STA GEN_Y
GL_CV7:
    LDA GEN_Y
    CMP #45
    BCS GL_DONE
    LDA #1
    STA TILE
    JSR GL_SET
    INC GEN_Y
    JMP GL_CV7

GL_DONE:
    LDA #7
    STA P_X
    LDA #7
    STA P_Y

    ; Place enemies - timers adjusted for 50Hz
    LDX #1
    LDA #UT_WALKER
    STA UTYPE,X
    LDA #27
    STA UX,X
    LDA #7
    STA UY,X
    LDA #3
    STA UHP,X
    LDA #25
    STA UTA,X

    LDX #2
    LDA #UT_HOVER
    STA UTYPE,X
    LDA #52
    STA UX,X
    LDA #7
    STA UY,X
    LDA #2
    STA UHP,X
    LDA #13
    STA UTA,X

    LDX #3
    LDA #UT_WALKER
    STA UTYPE,X
    LDA #7
    STA UX,X
    LDA #27
    STA UY,X
    LDA #4
    STA UHP,X
    LDA #25
    STA UTA,X

    LDX #4
    LDA #UT_FLOATER
    STA UTYPE,X
    LDA #27
    STA UX,X
    LDA #27
    STA UY,X
    LDA #1
    STA UHP,X
    LDA #8
    STA UTA,X

    LDX #5
    LDA #UT_TURRET
    STA UTYPE,X
    LDA #52
    STA UX,X
    LDA #27
    STA UY,X
    LDA #5
    STA UHP,X
    LDA #18
    STA UTA,X

    LDX #6
    LDA #UT_WALKER
    STA UTYPE,X
    LDA #7
    STA UX,X
    LDA #47
    STA UY,X
    LDA #3
    STA UHP,X
    LDA #25
    STA UTA,X

    LDX #7
    LDA #UT_HOVER
    STA UTYPE,X
    LDA #27
    STA UX,X
    LDA #47
    STA UY,X
    LDA #2
    STA UHP,X
    LDA #13
    STA UTA,X

    LDX #8
    LDA #UT_REAPER
    STA UTYPE,X
    LDA #52
    STA UX,X
    LDA #47
    STA UY,X
    LDA #6
    STA UHP,X
    LDA #10
    STA UTA,X

    LDX #9
    LDA #UT_WALKER
    STA UTYPE,X
    LDA #92
    STA UX,X
    LDA #27
    STA UY,X
    LDA #3
    STA UHP,X
    LDA #25
    STA UTA,X

    LDX #10
    LDA #UT_TURRET
    STA UTYPE,X
    LDA #92
    STA UX,X
    LDA #47
    STA UY,X
    LDA #5
    STA UHP,X
    LDA #18
    STA UTA,X

    ; Hidden items
    LDX #20
    LDA #UT_PISTOL
    STA UTYPE,X
    LDA #27
    STA UX,X
    LDA #9
    STA UY,X
    LDA #10
    STA UA,X

    LDX #21
    LDA #UT_MEDKIT
    STA UTYPE,X
    LDA #52
    STA UX,X
    LDA #9
    STA UY,X
    LDA #2
    STA UA,X

    LDX #22
    LDA #UT_KEY
    STA UTYPE,X
    LDA #9
    STA UX,X
    LDA #27
    STA UY,X
    LDA #0
    STA UA,X

    LDX #23
    LDA #UT_TBOMB
    STA UTYPE,X
    LDA #29
    STA UX,X
    LDA #27
    STA UY,X
    LDA #1
    STA UA,X

    LDX #24
    LDA #UT_EMPITEM
    STA UTYPE,X
    LDA #52
    STA UX,X
    LDA #27
    STA UY,X
    LDA #1
    STA UA,X

    LDX #25
    LDA #UT_PISTOL
    STA UTYPE,X
    LDA #9
    STA UX,X
    LDA #47
    STA UY,X
    LDA #8
    STA UA,X

    LDX #26
    LDA #UT_PLASMA
    STA UTYPE,X
    LDA #29
    STA UX,X
    LDA #47
    STA UY,X
    LDA #5
    STA UA,X

    LDX #27
    LDA #UT_MEDKIT
    STA UTYPE,X
    LDA #52
    STA UX,X
    LDA #47
    STA UY,X
    LDA #3
    STA UA,X

    RTS

GL_ROOM:
    LDA #0
    STA TEMP_C
GR_Y2:
    LDA #0
    STA TEMP_D
GR_X2:
    LDA GEN_X
    CLC
    ADC TEMP_D
    STA MAP_X
    LDA GEN_Y
    CLC
    ADC TEMP_C
    STA MAP_Y
    LDA #1
    STA TILE
    JSR SET_TILE
    INC TEMP_D
    LDA TEMP_D
    CMP #8
    BNE GR_X2
    INC TEMP_C
    LDA TEMP_C
    CMP #6
    BNE GR_Y2
    RTS

GL_SET:
    LDA GEN_X
    STA MAP_X
    LDA GEN_Y
    STA MAP_Y
    JMP SET_TILE

; ============================================================
; Read-only data
; ============================================================
.segment "RODATA"

; Tile characters for Mode 6 (standard ASCII)
; Same tile indices as BBC version: 0=void, 1=floor, 2=wall, 3=wall, 4=wall,
; 5=door, 6=bridge, 7=water, 8-15=various
TILE_CHRS:
    .byte ' ', '.', '#', '#', '#', '+', '/', '~'
    .byte ',', '.', '.', '.', '.', '.', '#', '.'
.repeat 240
    .byte '.'
.endrepeat

; Tile attributes (same as BBC version)
TILE_ATTR:
    .byte $00, TA_WALK, TA_WALL, TA_WALL, TA_WALL
    .byte TA_WALK+TA_DOOR, TA_WALK, TA_WALK
    .byte TA_WALK, TA_WALK, TA_WALK, TA_WALK
    .byte TA_WALK, TA_WALK, TA_WALL, TA_WALK
.repeat 240
    .byte TA_WALK
.endrepeat

; Messages
MSG_NOTHING: .byte "NOTHING HERE.", 0
MSG_FKEY:    .byte "FOUND A KEY!", 0
MSG_FBOMB:   .byte "FOUND A BOMB!", 0
MSG_FEMP:    .byte "FOUND AN EMP!", 0
MSG_FGUN:    .byte "FOUND A PISTOL!", 0
MSG_FPLASMA: .byte "FOUND A PLASMA GUN!", 0
MSG_FMED:    .byte "FOUND A MEDKIT!", 0
MSG_FMAG:    .byte "FOUND A MAGNET!", 0
MSG_HEAL:    .byte "AHHH MUCH BETTER!", 0
MSG_EMP:     .byte "EMP ACTIVATED!", 0
MSG_CANT:    .byte "CAN'T MOVE THAT!", 0
