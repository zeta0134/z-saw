        .include "../zsaw.inc"

.segment "HEADER"
        .byte "NES", $1a
        .byte $02               ; 2x 16KB PRG-ROM banks = 32 KB total
        .byte $01               ; 1x 8KB CHR-ROM banks = 8 KB total
        .byte $00, $00          ; MMC3 without battery-backed PRG RAM
        .byte $00               ; No PRG RAM (ines 1.0 will give us 8k, which we will ignore)
        .byte $00               ;
        .byte $00
        .byte $00
        .byte $00
        .byte $00
        .byte $00
        .byte $00

.segment "CHR0"


.segment "CHR1"


.zeropage
note_sequence_ptr: .res 2

.segment "RAM"

delay_counter: .res 1
nmi_counter: .res 1

.segment "PRG_C000"

.macro spinwait_for_vblank
.scope
loop:
        bit $2002 ; PPUSTATUS
        bpl loop
.endscope
.endmacro

.macro clear_page ADDR
.scope
        ldy #0
        lda #0
loop:
        dey
        sta ADDR,y
        bne loop
.endscope
.endmacro

.proc clear_internal_ram
        clear_page $0200
        clear_page $0300
        clear_page $0400
        clear_page $0500
        clear_page $0600
        clear_page $0700
        rts
.endproc

.proc reset
        sei            ; Disable interrupts
        cld            ; make sure decimal mode is off (not that it does anything)
        ldx #$ff       ; initialize stack
        txs

        ; Wait for the PPU to finish warming up
        spinwait_for_vblank
        spinwait_for_vblank

        ; Initialize zero page and stack
        clear_page $0000
        clear_page $0100
        ; now that the stack is usable, clear internal ram with a jsr
        jsr clear_internal_ram

        ; Jump to main loop
        jmp start
.endproc
        

.proc nmi_handler
        ; In this barebones example, all NMI needs to do is tell the game loop
        ; that it ran. We use this for timing purposes.
        inc nmi_counter
        rts
.endproc
.export nmi_handler ; so zsaw.s can see it

.proc wait_for_nmi
        lda nmi_counter
loop:
        cmp nmi_counter
        beq loop
        rts
.endproc

.proc start
        lda #$00
        sta $2001 ; PPUMASK: disable rendering
        sta $2000 ; PPUCTRL: and NMI

        ; disable unusual IRQ sources
        lda #%01000000
        sta $4017 ; APU frame counter
        lda #0
        sta $4010 ; DMC DMA

        ; first time init
        jsr zsaw_init

        ; re-enable rendering and NMI
        lda #$1E
        sta $2002
        lda #$88
        sta $2000

        ; Setup to play a simple note sequence
        lda #<note_sequence
        sta note_sequence_ptr
        lda #>note_sequence
        sta note_sequence_ptr+1

        ; For now, loop infinitely
gameloop:
        jsr play_note_sequence
        jsr wait_for_nmi
        jmp gameloop
.endproc

.proc advance_to_next_note
        lda #2
        clc
        adc note_sequence_ptr
        sta note_sequence_ptr
        lda #0
        adc note_sequence_ptr+1
        sta note_sequence_ptr+1
        ; sanity check: are we at the end of the sequence?
        ldy #1
        lda (note_sequence_ptr), y
        cmp #$FF
        bne done

        ; If so, return to the beginning
        lda #<note_sequence
        sta note_sequence_ptr
        lda #>note_sequence
        sta note_sequence_ptr+1

done:
        rts
.endproc

.proc play_note_sequence
        lda delay_counter
        beq start_next_note
        dec delay_counter

        lda zsaw_volume
        beq done_with_decay
        dec zsaw_volume
done_with_decay:
        rts

start_next_note:
        ldy #0
        lda (note_sequence_ptr), y
        jsr zsaw_play_note
        ldy #1
        lda (note_sequence_ptr), y
        sta delay_counter
        jsr advance_to_next_note

        lda #64
        sta zsaw_volume

        rts
.endproc

WHOLE = 60
HALF = 30
QUARTER = 15

note_sequence:
        .byte ZSAW_C2, HALF
        .byte ZSAW_D2, QUARTER
        .byte ZSAW_E2, QUARTER
        .byte ZSAW_F2, QUARTER
        .byte ZSAW_G2, QUARTER
        .byte ZSAW_A2, QUARTER
        .byte ZSAW_B2, QUARTER
        .byte ZSAW_C3, HALF
        .byte ZSAW_D3, QUARTER
        .byte ZSAW_E3, QUARTER
        .byte ZSAW_F3, QUARTER
        .byte ZSAW_G3, QUARTER
        .byte ZSAW_A3, QUARTER
        .byte ZSAW_B3, QUARTER
        .byte ZSAW_C4, HALF
        .byte ZSAW_D4, QUARTER
        .byte ZSAW_E4, QUARTER
        .byte ZSAW_F4, QUARTER
        .byte ZSAW_G4, QUARTER
        .byte ZSAW_A4, QUARTER
        .byte ZSAW_B4, QUARTER
        .byte ZSAW_C5, HALF
        .byte ZSAW_D5, QUARTER
        .byte ZSAW_E5, QUARTER
        .byte ZSAW_F5, QUARTER
        .byte ZSAW_G5, QUARTER
        .byte ZSAW_A5, QUARTER
        .byte ZSAW_B5, QUARTER
        .byte ZSAW_C6, HALF
        .byte ZSAW_D6, QUARTER
        .byte ZSAW_E6, QUARTER
        .byte ZSAW_F6, QUARTER
        .byte ZSAW_G6, QUARTER
        .byte ZSAW_A6, QUARTER
        .byte ZSAW_B6, QUARTER
        .byte ZSAW_C7, HALF
        .byte ZSAW_B6, QUARTER
        .byte ZSAW_A6, QUARTER
        .byte ZSAW_G6, QUARTER
        .byte ZSAW_F6, QUARTER
        .byte ZSAW_E6, QUARTER
        .byte ZSAW_D6, QUARTER
        .byte ZSAW_C6, HALF
        .byte ZSAW_B5, QUARTER
        .byte ZSAW_A5, QUARTER
        .byte ZSAW_G5, QUARTER
        .byte ZSAW_F5, QUARTER
        .byte ZSAW_E5, QUARTER
        .byte ZSAW_D5, QUARTER
        .byte ZSAW_C5, HALF
        .byte ZSAW_B4, QUARTER
        .byte ZSAW_A4, QUARTER
        .byte ZSAW_G4, QUARTER
        .byte ZSAW_F4, QUARTER
        .byte ZSAW_E4, QUARTER
        .byte ZSAW_D4, QUARTER
        .byte ZSAW_C4, HALF
        .byte ZSAW_B3, QUARTER
        .byte ZSAW_A3, QUARTER
        .byte ZSAW_G3, QUARTER
        .byte ZSAW_F3, QUARTER
        .byte ZSAW_E3, QUARTER
        .byte ZSAW_D3, QUARTER
        .byte ZSAW_C3, HALF
        .byte ZSAW_B2, QUARTER
        .byte ZSAW_A2, QUARTER
        .byte ZSAW_G2, QUARTER
        .byte ZSAW_F2, QUARTER
        .byte ZSAW_E2, QUARTER
        .byte ZSAW_D2, QUARTER
        .byte ZSAW_C2, WHOLE
        .byte $FF, WHOLE ; this invalid note index should play silence
        .byte $FF, $FF ; this signals that we should restart the sequence

        .segment "VECTORS"
        .addr zsaw_nmi
        .addr reset
        ;.addr irq
        .addr zsaw_irq

