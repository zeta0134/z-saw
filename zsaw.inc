; Z-Saw requires 11 bytes in zeropage
ZSAW_ZP_SEGMENT = "ZEROPAGE"
; interrupt vectors and lookup tables
ZSAW_FIXED_SEGMENT = "PRG_C000"
ZSAW_SAMPLES_SEGMENT = "PRG_C000"
; Shadow OAM high page, for OAM DMA
ZSAW_SHADOW_OAM = $02
; Your custom NMI handler, will be called automatically when vblank begins
; Note: 
;   - Do not perform OAM DMA, Z-Saw will handle that for you
;   - Interrupts will be enabled upon entry
;   - DO remember to preserve registers
;   - Return with rts, not rti
ZSAW_NMI_GAME_HANDLER = nmi_handler

; TODO: sanitize this list
.global zsaw_irq, zsaw_nmi
.global irq_active, irq_enabled, manual_nmi_needed, manual_oam_needed, zsaw_volume

; Music defines, for manually playing notes
ZSAW_B1  = 0
ZSAW_C2  = 1
ZSAW_CS2 = 2
ZSAW_D2  = 3
ZSAW_DS2 = 4
ZSAW_E2  = 5
ZSAW_F2  = 6
ZSAW_FS2 = 7
ZSAW_G2  = 8
ZSAW_GS2 = 9
ZSAW_A2  = 10
ZSAW_AS2 = 11
ZSAW_B2  = 12
ZSAW_C3  = 13
ZSAW_CS3 = 14
ZSAW_D3  = 15
ZSAW_DS3 = 16
ZSAW_E3  = 17
ZSAW_F3  = 18
ZSAW_FS3 = 19
ZSAW_G3  = 20
ZSAW_GS3 = 21
ZSAW_A3  = 22
ZSAW_AS3 = 23
ZSAW_B3  = 24
ZSAW_C4  = 25
ZSAW_CS4 = 26
ZSAW_D4  = 27
ZSAW_DS4 = 28
ZSAW_E4  = 29
ZSAW_F4  = 30
ZSAW_FS4 = 31
ZSAW_G4  = 32
ZSAW_GS4 = 33
ZSAW_A4  = 34
ZSAW_AS4 = 35
ZSAW_B4  = 36
ZSAW_C5  = 37
ZSAW_CS5 = 38
ZSAW_D5  = 39
ZSAW_DS5 = 40
ZSAW_E5  = 41
ZSAW_F5  = 42
ZSAW_FS5 = 43
ZSAW_G5  = 44
ZSAW_GS5 = 45
ZSAW_A5  = 46
ZSAW_AS5 = 47
ZSAW_B5  = 48
ZSAW_C6  = 49
ZSAW_CS6 = 50
ZSAW_D6  = 51
ZSAW_DS6 = 52
ZSAW_E6  = 53
ZSAW_F6  = 54
ZSAW_FS6 = 55
ZSAW_G6  = 56
ZSAW_GS6 = 57
ZSAW_A6  = 58
ZSAW_AS6 = 59
ZSAW_B6  = 60
ZSAW_C7  = 61

ZSAW_MINIMUM_INDEX = ZSAW_B1
ZSAW_MAXIMUM_INDEX = ZSAW_C7