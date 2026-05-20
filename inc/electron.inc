; Acorn Electron hardware definitions for ca65

; Electron ULA
ULA_BASE     = $FE00
ULA_CTL      = $FE00  ; Control register
ULA_PALETTE  = $FCE0  ; Palette RAM
ULA_MODE     = $FCED  ; Mode control

; Sound (ULA tone generator)
SOUND_FREQ   = $FE07  ; Write frequency value (0=off, 1-255= tone)

; OS entry points (same as BBC)
OSCLI        = $FFF7
OSBYTE       = $FFF4
OSWORD       = $FFF1
OSWRCH       = $FFEE
OSRDCH       = $FFE0
OSFILE       = $FFDD
OSARGS       = $FFDA
OSBGET       = $FFD7
OSBPUT       = $FFD4
OSGBPB       = $FFD1
OSFIND       = $FFCE
OSNEWL       = $FFE7

; OS vectors (same as BBC for most)
IRQ1V        = $0204
IRQ2V        = $0206
CLIV         = $0208
BYTEV        = $020A
WORDV        = $020C
WRCHV        = $020E
RDCHV        = $0210

; Screen modes - base addresses
SCR_MODE6    = $6000  ; Mode 6 screen base (40x25 text)

; OS variables
OS_FRAG      = $8E
CURSOR_POS   = $034A
SCREEN_BOT   = $034E
BYTES_CHAR   = $034F
SCREEN_TOP   = $0350
SCREEN_SIZE  = $0354
CURMODE      = $0355

; Keyboard buffer
KYBUF        = $03E0
KYBUF_TAIL   = $00C6

; OSBYTE functions
OSBYTE_TV    = $81  ; Read key with timeout
OSBYTE_READ  = $82  ; Read HIMEM
OSBYTE_PAGE  = $83  ; Read OSHWM
OSBYTE_DISP  = $84  ; Read screen base
OSBYTE_MODE  = $85  ; Set screen mode
OSBYTE_KEY   = $93  ; Read key (no wait)
