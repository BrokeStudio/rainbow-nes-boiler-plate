/*
                                                               
                                          88  88  88           
                                          88  ""  88           
                                          88      88           
8b,dPPYba,   8b,dPPYba,   88       88     88  88  88,dPPYba,   
88P'    "8a  88P'    "8a  88       88     88  88  88P'    "8a  
88       d8  88       d8  88       88     88  88  88       d8  
88b,   ,a8"  88b,   ,a8"  "8a,   ,a88     88  88  88b,   ,a8"  
88`YbbdP"'   88`YbbdP"'    `"YbbdP'Y8     88  88  8Y"Ybbd8"'   
88           88                                                
88           88                                                
*/
.out    "# PPU library..."

.scope PPU

  off         = ppu_off_all
  on          = ppu_on_all

  MASK_VAR    = PPU_MASK_VAR
  CTRL_VAR    = PPU_CTRL_VAR

/*
                                                                                                  
                                                                                                  
                                                                                                  
                                                                                                  
888888888   ,adPPYba,  8b,dPPYba,   ,adPPYba,   8b,dPPYba,   ,adPPYYba,   ,adPPYb,d8   ,adPPYba,  
     a8P"  a8P_____88  88P'   "Y8  a8"     "8a  88P'    "8a  ""     `Y8  a8"    `Y88  a8P_____88  
  ,d8P'    8PP"""""""  88          8b       d8  88       d8  ,adPPPPP88  8b       88  8PP"""""""  
,d8"       "8b,   ,aa  88          "8a,   ,a8"  88b,   ,a8"  88,    ,88  "8a,   ,d88  "8b,   ,aa  
888888888   `"Ybbd8"'  88           `"YbbdP"'   88`YbbdP"'   `"8bbdP"Y8   `"YbbdP"Y8   `"Ybbd8"'  
                                                88                        aa,    ,88              
                                                88                         "Y8bbdP"               
*/
  .pushseg
  .zeropage

  FRAME_CNT1:         .res 1
  FRAME_CNT2:         .res 1

  PPU_CTRL_VAR:       .res 1
  PPU_MASK_VAR:       .res 1

  tvSystem:           .res 1

; palUpdate : %f------u
; f : fade palette (execute fadePalette proc)
; u : update / flush palette (flush palette buffer to PPU)
  palUpdate:          .res 1
  PAL_BG_PTR:         .res 2
  PAL_SPR_PTR:        .res 2

  palBrightness:      .res 1
  palFadeTo:          .res 1
  palFadeDelay:       .res 1
  palFadeCounter:     .res 1

  PTR:                .res 2
  LEN:                .res 1
  VRAM_UPDATE:        .res 1
  NAME_UPD_ENABLE:    .res 1
  NAME_UPD_ADR:       .res 2
  ; NAME_UPD_PTR:       .res 2 ; not used for now

  TEMP                = $00
  .popseg

/*
                                                  
                                  88              
                                  88              
                                  88              
 ,adPPYba,   ,adPPYba,    ,adPPYb,88   ,adPPYba,  
a8"     ""  a8"     "8a  a8"    `Y88  a8P_____88  
8b          8b       d8  8b       88  8PP"""""""  
"8a,   ,aa  "8a,   ,a8"  "8a,   ,d88  "8b,   ,aa  
 `"Ybbd8"'   `"YbbdP"'    `"8bbdP"Y8   `"Ybbd8"'  
                                                  
                                                  
*/

  ;
  ; NES TV system detection code
  ; Copyright 2011 Damian Yerrick
  ;
  ; Copying and distribution of this file, with or without
  ; modification, are permitted in any medium without royalty provided
  ; the copyright notice and this notice are preserved in all source
  ; code copies.  This file is offered as-is, without any warranty.
  ;
  ;.segment "CODE"
  .align 32
  ;;
  ; Detects which of NTSC, PAL, or Dendy is in use by counting cycles
  ; between NMIs.
  ;
  ; NTSC NES produces 262 scanlines, with 341/3 CPU cycles per line.
  ; PAL NES produces 312 scanlines, with 341/3.2 CPU cycles per line.
  ; Its vblank is longer than NTSC, and its CPU is slower.
  ; Dendy is a Russian famiclone distributed by Steepler that uses the
  ; PAL signal with a CPU as fast as the NTSC CPU.  Its vblank is as
  ; long as PAL's, but its NMI occurs toward the end of vblank (line
  ; 291 instead of 241) so that cycle offsets from NMI remain the same
  ; as NTSC, keeping Balloon Fight and any game using a CPU cycle-
  ; counting mapper (e.g. FDS, Konami VRC) working.
  ;
  ; nmis is a variable that the NMI handler modifies every frame.
  ; Make sure your NMI handler finishes within 1500 or so cycles (not
  ; taking the whole NMI or waiting for sprite 0) while calling this,
  ; or the result in A will be wrong.
  ;
  ; @return A: TV system (0: NTSC, 1: PAL, 2: Dendy; 3: unknown
  ;         Y: high byte of iterations used (1 iteration = 11 cycles)
  ;         X: low byte of iterations used
  .proc getTVSystem

    nmis = FRAME_CNT1

    ldx #0
    ldy #0
    lda nmis
  nmiwait1:
    cmp nmis
    beq nmiwait1
    lda nmis

  nmiwait2:
    ; Each iteration takes 11 cycles.
    ; NTSC NES: 29780 cycles or 2707 = $A93 iterations
    ; PAL NES:  33247 cycles or 3022 = $BCE iterations
    ; Dendy:    35464 cycles or 3224 = $C98 iterations
    ; so we can divide by $100 (rounding down), subtract ten,
    ; and end up with 0=ntsc, 1=pal, 2=dendy, 3=unknown
    inx
    bne :+
    iny
  :
    cmp nmis
    beq nmiwait2
    tya
    sec
    sbc #10
    cmp #3
    bcc notAbove3
    lda #3
  notAbove3:
    sta tvSystem
    rts
  .endproc

  ;.segment "CODE"
  /*
  .proc pal_clear
    lda #$0F
    ldx #$00
  :
    sta PALETTE,X   ; STA PAL_BUF,x
    inx
    cpx #$20
    bne :-
    stx <palUpdate

    lda palBrightness
    jmp setPaletteBrightness

    ;rts
  .endproc
  */
  .proc ppu_off_all

    lda PPU_MASK_VAR
    and #%11100111
    jmp ppu_onoff

  .endproc

  .proc ppu_off_bg

    lda PPU_MASK_VAR
    and #%11110111
    jmp ppu_onoff

  .endproc

  .proc ppu_off_spr

    lda PPU_MASK_VAR
    and #%11101111
    jmp ppu_onoff

  .endproc

  .proc ppu_on_all

    lda PPU_MASK_VAR
    ora #%00011000
  ;    JMP ppu_onoff ; ???????

  .endproc

  .proc ppu_onoff

    sta PPU_MASK_VAR
    jmp waitNMI
  ;    STA PPU_MASK
    ;RTS

  .endproc
  /*
  .proc ppu_on_bg

    LDA PPU_MASK_VAR
    ORA #%00001000
    BNE ppu_onoff    ;bra

  .endproc

  .proc ppu_on_spr

    LDA PPU_MASK_VAR
    ORA #%00010000
    BNE ppu_onoff    ;bra

  .endproc

  .proc ppu_white
      LDA PPU_MASK_VAR
      AND #%00011111
      STA PPU_MASK_VAR
      RTS
  .endproc
  .endif

  .proc ppu_red
      LDA PPU_MASK_VAR
  ;    AND #%00011111
  ;    ORA #%01000000
      LDX NTSC_MODE
      LDX tvSystem
      BNE :+
                              ; PAL
          ORA #%00100000
          JMP @skipNTSC                               
  :
      ORA #%01000000
                              ; NTSC
  @skipNTSC:
      STA PPU_MASK_VAR
      RTS
  .endproc

  .proc ppu_blue
      LDA PPU_MASK_VAR
  ;    AND #%00011111
  ;    ORA #%10000000
      ORA #%10000000
      STA PPU_MASK_VAR
      RTS
  .endproc

  .proc ppu_green
      LDA PPU_MASK_VAR
  ;    AND #%00011111
  ;    ORA #%00100000
  ;    LDX NTSC_MODE
      LDX tvSystem
      BNE :+
                              ; PAL
          ORA #%01000000
          JMP @skipNTSC                               
  :
      ORA #%00100000
                              ; NTSC
  @skipNTSC:
      STA PPU_MASK_VAR
      RTS
  .endproc

  .proc ppu_color
      LDA PPU_MASK_VAR
      AND #%11111110
      STA PPU_MASK_VAR
      RTS
  .endproc

  .proc ppu_mono
      LDA PPU_MASK_VAR
      ORA #%00000001
      STA PPU_MASK_VAR
      RTS
  .endproc

  */
  .proc oam_clear
    ldx #0
    lda #$FF
  loop:
    sta OAM_BUF,x
    inx
    inx
    inx
    inx
    bne loop
    rts
  .endproc

  .proc oam_meta_spr
    ; IN
    ; PTR: pointer to sprite data
    ; X: x position
    ; Y: y position
    ; A: sprite id (0-64)
    ;
    ; OUT
    ; A: OAM index

    SCRX    = $00
    SCRY    = $01

    stx SCRX
    sty SCRY
    tax
    ldy #0

  @1:
    lda (PTR),y     ; x offset
    cmp #$80
    beq @2
    iny
    clc
    adc <SCRX
    sta OAM_BUF+3,x
    lda (PTR),y     ; y offset
    iny
    clc
    adc <SCRY
    sta OAM_BUF+0,x
    lda (PTR),y     ; tile
    iny
    sta OAM_BUF+1,x
    lda (PTR),y     ; attribute
    iny
    sta OAM_BUF+2,x
    inx
    inx
    inx
    inx
    jmp @1

  @2:

    txa

    ; return
    rts
  .endproc

  .proc oam_hide_rest
    tax
    lda #240
  :
    sta OAM_BUF,x
    inx
    inx
    inx
    inx
    bne :-

    ; return
    rts
  .endproc

  .proc waitFrame

    ;lda #1
    ;sta VRAM_UPDATE
    lda FRAME_CNT1
  :
    cmp FRAME_CNT1
    beq :-
    lda tvSystem
    beq :++
  :
    lda FRAME_CNT2
    cmp #5
    beq :-
  :

    rts

  .endproc

  .proc waitNMI

    ;lda #1
    ;sta VRAM_UPDATE
    lda FRAME_CNT1
  :
    cmp FRAME_CNT1
    beq :-
    rts

  .endproc

  .proc setPaletteBrightness

    sta palBrightness
    jsr pal_spr_bright
    txa
    jmp pal_bg_bright

  .endproc

  .proc pal_bg_bright

    tax
    lda palBrightTableL,x
    sta <PAL_BG_PTR
    lda palBrightTableH,x    ;MSB is never zero
    sta <PAL_BG_PTR+1
    lda #$01
    sta <palUpdate

    jmp pal_bg_to_buf

  .endproc

  .proc pal_spr_bright

    tax
    lda palBrightTableL,x
    sta <PAL_SPR_PTR
    lda palBrightTableH,x    ;MSB is never zero
    sta <PAL_SPR_PTR+1
    lda #$01
    sta <palUpdate

    jmp pal_spr_to_buf

  .endproc

  .proc pal_bg_to_buf

    .repeat 4,J
    .repeat 4,I
    ldy PALETTE+(J*4)+I
    lda (PAL_BG_PTR),Y
    sta PAL_BUF+(J*4)+I
    .endrepeat
    .endrepeat

    rts

  .endproc

  .proc pal_spr_to_buf

    .repeat 4,J
    .repeat 4,I
    ldy PALETTE+16+(J*4)+I
    lda (PAL_SPR_PTR),Y
    sta PAL_BUF+16+(J*4)+I
    .endrepeat
    .endrepeat

    rts

  .endproc

  .proc setSPR_bank

    and #$01
    asl A
    asl A
    asl A
    sta TEMP
    lda PPU_CTRL_VAR
    and #%11110111
    ora TEMP
    sta PPU_CTRL_VAR

    rts

  .endproc

  .proc setBG_bank

    and #$01
    asl A
    asl A
    asl A
    asl A
    sta TEMP
    lda PPU_CTRL_VAR
    and #%11101111
    ora TEMP
    sta PPU_CTRL_VAR

    rts

  .endproc

  .proc pal_bg

    sta <PTR
    stx <PTR+1
    ldx #$00
    lda #$10
    jmp pal_copy

  .endproc

  .proc pal_spr

    sta <PTR
    stx <PTR+1
    ldx #$10
    txa
    bne pal_copy ;bra

  .endproc

  ;.proc pal_col
  ;
  ;;    STA <PTR
  ;;    JSR popa
  ;;    AND #$1f
  ;;    TAX
  ;;    LDA <PTR
  ;;    STA PAL_BUF,x
  ;;    INC <palUpdate
  ;    RTS
  ;
  ;.endproc

  .proc pal_all

    sta <PTR
    stx <PTR+1
    ldx #$00
    lda #$20

  .endproc

  .proc pal_copy

    sta <LEN
    ldy #$00
  :
    lda (PTR),y
    sta PALETTE,X   ;STA PAL_BUF,x
    inx
    iny
    dec <LEN
    bne :-

    inc <palUpdate

    jsr pal_bg_to_buf
    jmp pal_spr_to_buf

  .endproc

  .proc flushPalette

    ldx #$00
    lda #$3F
    sta PPU_ADDR
    stx PPU_ADDR

    .repeat 4,I
    lda PAL_BUF+I
    sta PPU_DATA
    .endrepeat

    .repeat 3,J
    lda PPU_DATA            ;skip background color
    .repeat 3,I
    lda PAL_BUF+5+(J*4)+I
    sta PPU_DATA
    .endrepeat
    .endrepeat

    .repeat 4,J
    lda PPU_DATA            ;skip background color
    .repeat 3,I
    lda PAL_BUF+17+(J*4)+I
    sta PPU_DATA
    .endrepeat
    .endrepeat

    ; clear 'flush-palette' flag
    dec palUpdate

    rts

  .endproc

  .proc fadePalette
    
    ; decrement palette fade counter
    dec palFadeCounter
    beq :+
      ; return
      rts
  :
    lda palFadeTo
    cmp palBrightness
    ;bmi :+
    bcc :+
    inc palBrightness
    jmp :++
  :
    dec palBrightness
  :
    lda palBrightness
    jsr setPaletteBrightness

    lda palFadeTo
    cmp palBrightness
    beq :+

    ; reset fade counter
    lda palFadeDelay
    sta palFadeCounter

    ; set flags
    lda #$81
    sta palUpdate

    jmp flushPalette

  :
    ; palette faded
    lda #$01
    sta palUpdate

    jmp flushPalette

  .endproc

  .proc fadePaletteNoWait

    sta palFadeTo

    ; init fade counter
    lda palFadeDelay
    sta palFadeCounter

    ; set pal update status
    lda #$80
    sta palUpdate

    ; return
    rts

  .endproc

  .proc fadePaletteWait

    sta palFadeTo

    ; init fade counter
    lda palFadeDelay
    sta palFadeCounter

    ; set pal update status
    lda #$80
    sta palUpdate

    ; check palUpdate status - if 0 then update done
  :
    jsr waitNMI
    lda palUpdate
    bne :-

    ; return
    rts

  .endproc

  .proc fillNT
    ; argument(s) :
    ;   - A = nametable hi byte
    ;   - X = tile ID
    ; destroys :
    ;   - A
    ;   - X
    ;   - Y

    sta PPU_ADDR
    lda #$00
    sta PPU_ADDR

    txa
    ldx #$60
    ldy #$0A
  :
    sta PPU_DATA
    dex
    bne :-
    ldx #$60
    dey
    bne :-

    ; return
    rts

  .endproc

  .proc set_vram_update

    sta <NAME_UPD_ADR+0
    stx <NAME_UPD_ADR+1
    ora <NAME_UPD_ADR+1
    sta <NAME_UPD_ENABLE

    sta VRAM_UPDATE     ; added

    rts

  .endproc

  .proc flush_vram_update

    sta <NAME_UPD_ADR+0
    stx <NAME_UPD_ADR+1

  .endproc

  ; VRAM update data format:
  ; MSB, LSB, byte for a non-sequental write
  ; MSB|NT_UPD_HORZ, LSB, LEN, [bytes] for a horizontal sequence
  ; MSB|NT_UPD_VERT, LSB, LEN, [bytes] for a vertical sequence
  ; NT_UPD_EOF to mark end of the buffer

  ;length of this data should be under 256 bytes

  .proc flush_vram_update_nmi

    ldy #0

  updName:

    lda (NAME_UPD_ADR),y
    iny
    cmp #$40                ;is it a non-sequental write?
    bcs updNotSeq
    sta PPU_ADDR
    lda (NAME_UPD_ADR),y
    iny
    sta PPU_ADDR
    lda (NAME_UPD_ADR),y
    iny
    sta PPU_DATA
    jmp updName

  updNotSeq:

    tax
    lda PPU_CTRL_VAR
    cpx #$80                ;is it a horizontal or vertical sequence?
    bcc updHorzSeq
    cpx #$ff                ;is it end of the update?
    beq updDone

  updVertSeq:

    ora #$04
    bne updNameSeq         ;bra

  updHorzSeq:

    and #$fb

  updNameSeq:

    sta PPU_CTRL

    txa
    and #$3f
    sta PPU_ADDR
    lda (NAME_UPD_ADR),y
    iny
    sta PPU_ADDR
    lda (NAME_UPD_ADR),y
    iny
    tax

  updNameLoop:

    lda (NAME_UPD_ADR),y
    iny
    sta PPU_DATA
    dex
    bne updNameLoop

    lda PPU_CTRL_VAR
    sta PPU_CTRL

    jmp updName

  updDone:

    lda #$00
    sta NAME_UPD_ENABLE

    rts

  .endproc

  .proc vram_unrle

    RLE_TAG     = $00
    RLE_BYTE    = $01

    tay
    stx PTR+1
    lda #0
    sta PTR+0

    lda (PTR),y
    sta RLE_TAG
    iny
    bne loop
      inc PTR+1
  loop:

    lda (PTR),y
    iny
    bne :+
      inc PTR+1
  :

    cmp RLE_TAG
    beq :+
      sta PPU_DATA
      sta RLE_BYTE
      bne loop
  :

    lda (PTR),y
    beq done
    iny
    bne :+
      inc PTR+1
  :

    tax
    lda RLE_BYTE

  :
    sta PPU_DATA
    dex
    bne :-
      beq loop

  done:

    rts

  .endproc

  /*
                                                
         88                                   
         88                ,d                 
         88                88                 
 ,adPPYb,88  ,adPPYYba,  MM88MMM  ,adPPYYba,  
a8"    `Y88  ""     `Y8    88     ""     `Y8  
8b       88  ,adPPPPP88    88     ,adPPPPP88  
"8a,   ,d88  88,    ,88    88,    88,    ,88  
 `"8bbdP"Y8  `"8bbdP"Y8    "Y888  `"8bbdP"Y8  
                                              
                                              
  */

  palBrightTableL:
    .byte <palBrightTable0,<palBrightTable1,<palBrightTable2
    .byte <palBrightTable3,<palBrightTable4,<palBrightTable5
    .byte <palBrightTable6,<palBrightTable7,<palBrightTable8
  palBrightTableH:
    .byte >palBrightTable0,>palBrightTable1,>palBrightTable2
    .byte >palBrightTable3,>palBrightTable4,>palBrightTable5
    .byte >palBrightTable6,>palBrightTable7,>palBrightTable8
  palBrightTable0:
    .byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f    ;black
  palBrightTable1:
    .byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
  palBrightTable2:
    .byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
  palBrightTable3:
    .byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
  palBrightTable4:
    .byte $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0f,$0f,$0f    ;normal colors
  palBrightTable5:
    .byte $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1a,$1b,$1c,$00,$00,$00
  palBrightTable6:
    .byte $10,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2a,$2b,$2c,$10,$10,$10    ;$10 because $20 is the same as $30
  palBrightTable7:
    .byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3a,$3b,$3c,$20,$20,$20
  palBrightTable8:
    .byte $30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30    ;white
    .byte $30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30
    .byte $30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30
    .byte $30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30

.endscope