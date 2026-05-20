; BBC Micro hardware definitions for ca65
; System VIA (6522)
VIA_PORTB    = $FE40
VIA_PORTA    = $FE41
VIA_DDRB     = $FE42
VIA_DDRA     = $FE43
VIA_T1CL     = $FE44
VIA_T1CH     = $FE45
VIA_T1LL     = $FE46
VIA_T1LH     = $FE47
VIA_IFR      = $FE4D
VIA_IER      = $FE4E
VIA_PORTA_NH = $FE4F

; Video ULA
VIDULA_CTL   = $FE20
VIDULA_PAL   = $FE21

; CRTC (6845)
CRTC_REG     = $FE00
CRTC_DATA    = $FE01

; ROM selection
ROM_SEL      = $FE30

; ADC
ADC_CTL      = $FEC0
ADC_DATA_LO  = $FEC1
ADC_DATA_HI  = $FEC2

; OS entry points
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

; OS vectors
BRKV         = $0200
IRQ1V        = $0204
IRQ2V        = $0206
CLIV         = $0208
BYTEV        = $020A
WORDV        = $020C
WRCHV        = $020E
RDCHV        = $0210
FILEV        = $0212
ARGSV        = $0214
BGETV        = $0216
BPUTV        = $0218
GBPBV        = $021A
FINDV        = $021C

; Screen modes - base addresses
SCR_MODE7    = $7C00

; OS variables
OS_FRAG      = $8E
OSHWM        = $0244
VIDULA_CPY   = $0248
PAL_CPY      = $0249
CURSOR_POS   = $034A
SCREEN_BOT   = $034E
BYTES_CHAR   = $034F
SCREEN_TOP   = $0350
SCREEN_SIZE  = $0354
CURMODE      = $0355
MAP_TYPE     = $0356

; Keyboard buffer
KYBUF        = $03E0
KYBUF_TAIL   = $00C6

; OSBYTE functions
OSBYTE_TV    = $81  ; Read key with timeout
OSBYTE_READ  = $82  ; Read HIMEM
OSBYTE_PAGE  = $83  ; Read OSHWM
OSBYTE_DISP  = $84  ; Read screen base
OSBYTE_MODE  = $85  ; Set screen mode
OSBYTE_POS   = $86  ; Read cursor pos
OSBYTE_CURM  = $87  ; Read current mode
OSBYTE_KEY   = $93  ; Read key (no wait)
