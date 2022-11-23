.include "zsaw.inc"

.import ZSAW_NMI_GAME_HANDLER

.segment ZSAW_ZP_SEGMENT

table_entry: .res 1
table_pos: .res 1

zsaw_ptr: .res 2
zsaw_pos: .res 1
zsaw_volume: .res 1
zsaw_count: .res 1

irq_enabled: .res 1
irq_active: .res 1
manual_nmi_needed: .res 1
manual_oam_needed: .res 1

.segment ZSAW_SAMPLES_SEGMENT

.align 64
all_00_byte: .byte $00

.segment ZSAW_FIXED_SEGMENT

.proc zsaw_init
        lda #0
        sta irq_enabled
        sta irq_active
        sta manual_oam_needed
        sta manual_nmi_needed
        rts
.endproc

; note index in A
; assumes interrupts are already enabled
.proc zsaw_play_note
        ; sanity check: is this note index in bounds?
        cmp #ZSAW_MINIMUM_INDEX
        bcc bad_note_index
        cmp #ZSAW_MAXIMUM_INDEX
        bcs bad_note_index
        jmp play_note
bad_note_index:
        jsr zsaw_silence
        rts
play_note:
        asl ; note index to word index for the table lookup
        tax

        sei ; briefly disable interrupts, for pointer safety
        lda blarggsaw_note_lists, x 
        sta zsaw_ptr
        lda blarggsaw_note_lists+1, x 
        sta zsaw_ptr+1
        cli ; the pointer is valid, it should be safe to re-enable interrupts again

        ; Now, if we were newly triggered, start the sample playback from scratch
        lda irq_enabled
        beq done ; Do not pass go. Do not collect $200

        sei ; briefly disable interrupts (again) to start a new note
        lda #0
        sta zsaw_pos
        lda #1
        sta zsaw_count

        ; set up the sample address and size
        lda #<((all_00_byte - $C000) >> 6)
        sta $4012
        lda #0
        sta $4013
        ; start it up (the IRQ will take over future starts after this)
        lda #$8F
        sta $4010
        lda #$1F
        sta $4015

        cli ; enable interrupts
        ; tell the NMI handler that interrupts are active
        lda #$FF
        sta irq_enabled 
done:
        rts
.endproc

.proc zsaw_silence
        ; halt playback
        lda #$0F
        sta $4015 ; acknowledges DMC interrupt, if one is active
        ; disable DMC interrupts
        lda #0
        sta $4010

        ; Tell the NMI handler that interrupts are no longer active
        ; (It'll need to do its own OAM DMA)
        lda #$00
        sta irq_enabled
        rts
.endproc



.proc zsaw_irq ; (7)
        dec irq_active ; (5) signal to NMI that the IRQ routine is in progress
        pha ; (3) save A and Y
        tya ; (2)
        pha ; (3)
        ; decrement the RLE counter
        dec zsaw_count ; (5)
        ; if this is still positive, simply continue playing the last sample
        bne restart_dmc ; (2) (3t)
        ; otherwise it's time to load the next entry
        ldy zsaw_pos ; (3)
        lda (zsaw_ptr), y ; (5)
        bne load_entry ; (2) (3t)
        ; if the count is zero, it's time to reset the sequence. First write the volume
        ; to the PCM level
        lda zsaw_volume ; (3)
        sta $4011 ; (4)
        ; then reset the postion counter to the beginning
        ldy #0 ; (2)
        lda (zsaw_ptr), y ; (5)
load_entry:
        sta zsaw_count ; (3)
        iny ; (2)
        lda (zsaw_ptr), y ; (5)
        ora #$80 ; (2) set the interrupt flag
        sta $4010 ; (4) set the period + interrupt for this sample
        iny ; (2)
        sty zsaw_pos ; (3)
restart_dmc:
        lda #$1F ; (2)
        sta $4015 ; (4)
        ; Now for housekeeping.
        ; At this point it is safe for NMI interrupt the IRQ routine
        inc irq_active
        ; If we need to perform a manual NMI, do that now
        bit manual_nmi_needed
        bpl no_nmi_needed
        inc manual_nmi_needed
        jsr zsaw_manual_nmi ; this should preserve all registers, including X
no_nmi_needed:
        ; Similarly, if NMI asked us to perform OAM DMA, do that here
        bit manual_oam_needed
        bpl no_oam_needed
        lda #$00
        sta $2003 ; OAM ADDR
        lda #ZSAW_SHADOW_OAM
        sta $4014 ; OAM DMA
        inc manual_oam_needed
no_oam_needed:
        pla ; (4) restore A and Y
        tay ; (2)
        pla ; (4)
        rti
.endproc

.proc zsaw_nmi
        bit irq_active
        bpl safe_to_run_nmi
        dec manual_nmi_needed
        rti ; exit immediately; IRQ will continue and call NMI when it is done
safe_to_run_nmi:
        jsr zsaw_manual_nmi
        rti
.endproc

.proc zsaw_manual_nmi
        ; preserve registers
        pha
        txa
        pha
        tya
        pha

        ; is NMI disabled? if so get outta here fast
        lda NmiSoftDisable
        bne nmi_soft_disable

        bit irq_enabled
        bpl perform_oam_dma
        dec manual_oam_needed ; Perform OAM DMA during the IRQ routine
        ; allow interrupts during nmi as early as possible
        cli
        jmp done_with_oam
perform_oam_dma:
        ; do the sprite thing
        lda #$00
        sta OAMADDR
        lda #$02
        sta OAM_DMA
done_with_oam:
        jsr ZSAW_NMI_GAME_HANDLER

        ; restore registers
        pla
        tay
        pla
        tax
        pla
        rts
.endproc

zsaw_note_lists:
  .word zsaw_note_period_23
  .word zsaw_note_period_24
  .word zsaw_note_period_25
  .word zsaw_note_period_26
  .word zsaw_note_period_27
  .word zsaw_note_period_28
  .word zsaw_note_period_29
  .word zsaw_note_period_30
  .word zsaw_note_period_31
  .word zsaw_note_period_32
  .word zsaw_note_period_33
  .word zsaw_note_period_34
  .word zsaw_note_period_35
  .word zsaw_note_period_36
  .word zsaw_note_period_37
  .word zsaw_note_period_38
  .word zsaw_note_period_39
  .word zsaw_note_period_40
  .word zsaw_note_period_41
  .word zsaw_note_period_42
  .word zsaw_note_period_43
  .word zsaw_note_period_44
  .word zsaw_note_period_45
  .word zsaw_note_period_46
  .word zsaw_note_period_47
  .word zsaw_note_period_48
  .word zsaw_note_period_49
  .word zsaw_note_period_50
  .word zsaw_note_period_51
  .word zsaw_note_period_52
  .word zsaw_note_period_53
  .word zsaw_note_period_54
  .word zsaw_note_period_55
  .word zsaw_note_period_56
  .word zsaw_note_period_57
  .word zsaw_note_period_58
  .word zsaw_note_period_59
  .word zsaw_note_period_60
  .word zsaw_note_period_61
  .word zsaw_note_period_62
  .word zsaw_note_period_63
  .word zsaw_note_period_64
  .word zsaw_note_period_65
  .word zsaw_note_period_66
  .word zsaw_note_period_67
  .word zsaw_note_period_68
  .word zsaw_note_period_69
  .word zsaw_note_period_70
  .word zsaw_note_period_71
  .word zsaw_note_period_72
  .word zsaw_note_period_73
  .word zsaw_note_period_74
  .word zsaw_note_period_75
  .word zsaw_note_period_76
  .word zsaw_note_period_77
  .word zsaw_note_period_78
  .word zsaw_note_period_79
  .word zsaw_note_period_80
  .word zsaw_note_period_81
  .word zsaw_note_period_82
  .word zsaw_note_period_83
  .word zsaw_note_period_84
zsaw_note_period_23:
; Note: B1, Target Frequency: 30.87, Actual Frequency: 30.87, Tuning Error: 0.00
  .byte $20, $08, $03, $0a, $02, $0b, $03, $0c
  .byte $02, $0d, $00
zsaw_note_period_24:
; Note: C2, Target Frequency: 32.70, Actual Frequency: 32.71, Tuning Error: 0.00
  .byte $24, $08, $00
zsaw_note_period_25:
; Note: Cs2, Target Frequency: 34.65, Actual Frequency: 34.64, Tuning Error: 0.01
  .byte $1b, $08, $01, $09, $03, $0a, $02, $0b
  .byte $03, $0c, $02, $0d, $00
zsaw_note_period_26:
; Note: D2, Target Frequency: 36.71, Actual Frequency: 36.71, Tuning Error: 0.00
  .byte $1e, $08, $01, $09, $01, $0b, $01, $0c
  .byte $00
zsaw_note_period_27:
; Note: Ds2, Target Frequency: 38.89, Actual Frequency: 38.89, Tuning Error: 0.00
  .byte $1b, $08, $03, $09, $01, $0a, $00
zsaw_note_period_28:
; Note: E2, Target Frequency: 41.20, Actual Frequency: 41.20, Tuning Error: 0.00
  .byte $16, $08, $03, $09, $02, $0a, $03, $0c
  .byte $02, $0d, $00
zsaw_note_period_29:
; Note: F2, Target Frequency: 43.65, Actual Frequency: 43.66, Tuning Error: 0.01
  .byte $18, $08, $03, $09, $01, $0d, $00
zsaw_note_period_30:
; Note: Fs2, Target Frequency: 46.25, Actual Frequency: 46.24, Tuning Error: 0.01
  .byte $11, $08, $03, $09, $03, $0a, $03, $0b
  .byte $03, $0c, $00
zsaw_note_period_31:
; Note: G2, Target Frequency: 49.00, Actual Frequency: 49.00, Tuning Error: 0.00
  .byte $12, $08, $03, $0a, $02, $0b, $02, $0c
  .byte $03, $0d, $00
zsaw_note_period_32:
; Note: Gs2, Target Frequency: 51.91, Actual Frequency: 51.91, Tuning Error: 0.01
  .byte $10, $08, $01, $09, $02, $0a, $02, $0b
  .byte $03, $0c, $03, $0d, $00
zsaw_note_period_33:
; Note: A2, Target Frequency: 55.00, Actual Frequency: 55.00, Tuning Error: 0.00
  .byte $0e, $08, $03, $09, $01, $0a, $03, $0b
  .byte $03, $0c, $01, $0d, $00
zsaw_note_period_34:
; Note: As2, Target Frequency: 58.27, Actual Frequency: 58.26, Tuning Error: 0.01
  .byte $0d, $08, $03, $09, $03, $0a, $02, $0c
  .byte $03, $0d, $00
zsaw_note_period_35:
; Note: B2, Target Frequency: 61.74, Actual Frequency: 61.73, Tuning Error: 0.00
  .byte $0d, $08, $02, $0a, $03, $0b, $03, $0c
  .byte $02, $0d, $00
zsaw_note_period_36:
; Note: C3, Target Frequency: 65.41, Actual Frequency: 65.42, Tuning Error: 0.01
  .byte $12, $08, $00
zsaw_note_period_37:
; Note: Cs3, Target Frequency: 69.30, Actual Frequency: 69.31, Tuning Error: 0.01
  .byte $0e, $08, $02, $09, $01, $0a, $01, $0c
  .byte $00
zsaw_note_period_38:
; Note: D3, Target Frequency: 73.42, Actual Frequency: 73.40, Tuning Error: 0.02
  .byte $07, $08, $03, $09, $02, $0a, $03, $0b
  .byte $03, $0c, $03, $0d, $00
zsaw_note_period_39:
; Note: Ds3, Target Frequency: 77.78, Actual Frequency: 77.79, Tuning Error: 0.01
  .byte $0c, $08, $03, $0b, $02, $0c, $00
zsaw_note_period_40:
; Note: E3, Target Frequency: 82.41, Actual Frequency: 82.43, Tuning Error: 0.03
  .byte $0d, $08, $01, $09, $01, $0d, $00
zsaw_note_period_41:
; Note: F3, Target Frequency: 87.31, Actual Frequency: 87.32, Tuning Error: 0.02
  .byte $09, $08, $02, $09, $03, $0a, $01, $0c
  .byte $00
zsaw_note_period_42:
; Note: Fs3, Target Frequency: 92.50, Actual Frequency: 92.52, Tuning Error: 0.02
  .byte $0b, $08, $01, $09, $02, $0d, $00
zsaw_note_period_43:
; Note: G3, Target Frequency: 98.00, Actual Frequency: 98.04, Tuning Error: 0.04
  .byte $09, $08, $02, $09, $03, $0d, $00
zsaw_note_period_44:
; Note: Gs3, Target Frequency: 103.83, Actual Frequency: 103.86, Tuning Error: 0.04
  .byte $09, $08, $01, $09, $02, $0a, $00
zsaw_note_period_45:
; Note: A3, Target Frequency: 110.00, Actual Frequency: 109.99, Tuning Error: 0.01
  .byte $04, $08, $03, $0a, $03, $0b, $02, $0c
  .byte $03, $0d, $00
zsaw_note_period_46:
; Note: As3, Target Frequency: 116.54, Actual Frequency: 116.52, Tuning Error: 0.02
  .byte $02, $08, $01, $09, $03, $0a, $03, $0b
  .byte $03, $0c, $03, $0d, $00
zsaw_note_period_47:
; Note: B3, Target Frequency: 123.47, Actual Frequency: 123.47, Tuning Error: 0.00
  .byte $05, $08, $01, $0a, $02, $0b, $02, $0c
  .byte $03, $0d, $00
zsaw_note_period_48:
; Note: C4, Target Frequency: 130.81, Actual Frequency: 130.83, Tuning Error: 0.02
  .byte $09, $08, $00
zsaw_note_period_49:
; Note: Cs4, Target Frequency: 138.59, Actual Frequency: 138.61, Tuning Error: 0.02
  .byte $07, $08, $02, $0a, $00
zsaw_note_period_50:
; Note: D4, Target Frequency: 146.83, Actual Frequency: 146.80, Tuning Error: 0.03
  .byte $01, $08, $03, $09, $02, $0a, $03, $0c
  .byte $03, $0d, $00
zsaw_note_period_51:
; Note: Ds4, Target Frequency: 155.56, Actual Frequency: 155.58, Tuning Error: 0.01
  .byte $05, $08, $02, $09, $02, $0d, $00
zsaw_note_period_52:
; Note: E4, Target Frequency: 164.81, Actual Frequency: 164.74, Tuning Error: 0.07
  .byte $01, $08, $03, $0a, $02, $0b, $03, $0c
  .byte $02, $0d, $00
zsaw_note_period_53:
; Note: F4, Target Frequency: 174.61, Actual Frequency: 174.51, Tuning Error: 0.10
  .byte $02, $08, $01, $09, $02, $0b, $03, $0c
  .byte $02, $0d, $00
zsaw_note_period_54:
; Note: Fs4, Target Frequency: 185.00, Actual Frequency: 184.89, Tuning Error: 0.10
  .byte $02, $09, $03, $0a, $02, $0c, $03, $0d
  .byte $00
zsaw_note_period_55:
; Note: G4, Target Frequency: 196.00, Actual Frequency: 195.90, Tuning Error: 0.09
  .byte $01, $09, $02, $0a, $01, $0b, $03, $0c
  .byte $03, $0d, $00
zsaw_note_period_56:
; Note: Gs4, Target Frequency: 207.65, Actual Frequency: 207.53, Tuning Error: 0.12
  .byte $02, $08, $01, $0b, $03, $0c, $03, $0d
  .byte $00
zsaw_note_period_57:
; Note: A4, Target Frequency: 220.00, Actual Frequency: 220.20, Tuning Error: 0.20
  .byte $04, $08, $02, $0b, $00
zsaw_note_period_58:
; Note: As4, Target Frequency: 233.08, Actual Frequency: 233.04, Tuning Error: 0.04
  .byte $01, $09, $01, $0a, $02, $0b, $03, $0c
  .byte $01, $0d, $00
zsaw_note_period_59:
; Note: B4, Target Frequency: 246.94, Actual Frequency: 246.93, Tuning Error: 0.01
  .byte $01, $0a, $03, $0b, $02, $0c, $02, $0d
  .byte $00
zsaw_note_period_60:
; Note: C5, Target Frequency: 261.63, Actual Frequency: 261.36, Tuning Error: 0.27
  .byte $02, $09, $02, $0a, $03, $0d, $00
zsaw_note_period_61:
; Note: Cs5, Target Frequency: 277.18, Actual Frequency: 277.57, Tuning Error: 0.39
  .byte $02, $08, $02, $09, $01, $0c, $00
zsaw_note_period_62:
; Note: D5, Target Frequency: 293.66, Actual Frequency: 293.60, Tuning Error: 0.07
  .byte $01, $09, $02, $0a, $03, $0c, $00
zsaw_note_period_63:
; Note: Ds5, Target Frequency: 311.13, Actual Frequency: 310.72, Tuning Error: 0.40
  .byte $02, $0b, $02, $0c, $03, $0d, $00
zsaw_note_period_64:
; Note: E5, Target Frequency: 329.63, Actual Frequency: 329.97, Tuning Error: 0.35
  .byte $01, $08, $02, $09, $02, $0d, $00
zsaw_note_period_65:
; Note: F5, Target Frequency: 349.23, Actual Frequency: 348.48, Tuning Error: 0.75
  .byte $02, $0a, $01, $0c, $03, $0d, $00
zsaw_note_period_66:
; Note: Fs5, Target Frequency: 369.99, Actual Frequency: 370.40, Tuning Error: 0.41
  .byte $02, $09, $02, $0a, $00
zsaw_note_period_67:
; Note: G5, Target Frequency: 392.00, Actual Frequency: 392.49, Tuning Error: 0.50
  .byte $03, $08, $00
zsaw_note_period_68:
; Note: Gs5, Target Frequency: 415.30, Actual Frequency: 414.30, Tuning Error: 1.01
  .byte $02, $0a, $02, $0b, $00
zsaw_note_period_69:
; Note: A5, Target Frequency: 440.00, Actual Frequency: 440.40, Tuning Error: 0.40
  .byte $02, $08, $01, $0b, $00
zsaw_note_period_70:
; Note: As5, Target Frequency: 466.16, Actual Frequency: 466.09, Tuning Error: 0.08
  .byte $03, $09, $00
zsaw_note_period_71:
; Note: B5, Target Frequency: 493.88, Actual Frequency: 494.96, Tuning Error: 1.08
  .byte $02, $0a, $02, $0d, $00
zsaw_note_period_72:
; Note: C6, Target Frequency: 523.25, Actual Frequency: 525.17, Tuning Error: 1.92
  .byte $02, $09, $01, $0c, $00
zsaw_note_period_73:
; Note: Cs6, Target Frequency: 554.37, Actual Frequency: 553.77, Tuning Error: 0.60
  .byte $02, $09, $01, $0d, $00
zsaw_note_period_74:
; Note: D6, Target Frequency: 587.33, Actual Frequency: 588.74, Tuning Error: 1.41
  .byte $02, $08, $00
zsaw_note_period_75:
; Note: Ds6, Target Frequency: 622.25, Actual Frequency: 624.92, Tuning Error: 2.67
  .byte $01, $08, $02, $0d, $00
zsaw_note_period_76:
; Note: E6, Target Frequency: 659.26, Actual Frequency: 658.00, Tuning Error: 1.25
  .byte $01, $0b, $02, $0c, $00
zsaw_note_period_77:
; Note: F6, Target Frequency: 698.46, Actual Frequency: 699.13, Tuning Error: 0.67
  .byte $02, $09, $00
zsaw_note_period_78:
; Note: Fs6, Target Frequency: 739.99, Actual Frequency: 740.80, Tuning Error: 0.81
  .byte $01, $09, $01, $0a, $00
zsaw_note_period_79:
; Note: G6, Target Frequency: 783.99, Actual Frequency: 787.75, Tuning Error: 3.76
  .byte $02, $0a, $00
zsaw_note_period_80:
; Note: Gs6, Target Frequency: 830.61, Actual Frequency: 828.60, Tuning Error: 2.01
  .byte $01, $0a, $01, $0b, $00
zsaw_note_period_81:
; Note: A6, Target Frequency: 880.00, Actual Frequency: 873.91, Tuning Error: 6.09
  .byte $02, $0b, $00
zsaw_note_period_82:
; Note: As6, Target Frequency: 932.33, Actual Frequency: 916.89, Tuning Error: 15.44
  .byte $01, $09, $01, $0d, $00
zsaw_note_period_83:
; Note: B6, Target Frequency: 987.77, Actual Frequency: 989.92, Tuning Error: 56.58
  .byte $01, $0a, $01, $0d, $00
zsaw_note_period_84:
; Note: C7, Target Frequency: 1046.50, Actual Frequency: 1055.29, Tuning Error: 8.79
  .byte $01, $0b, $01, $0d, $00
