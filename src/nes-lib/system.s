/*
                                                                                                   
                                                                              88  88  88           
                                     ,d                                       88  ""  88           
                                     88                                       88      88           
,adPPYba,  8b       d8  ,adPPYba,  MM88MMM  ,adPPYba,  88,dPYba,,adPYba,      88  88  88,dPPYba,   
I8[    ""  `8b     d8'  I8[    ""    88    a8P_____88  88P'   "88"    "8a     88  88  88P'    "8a  
 `"Y8ba,    `8b   d8'    `"Y8ba,     88    8PP"""""""  88      88      88     88  88  88       d8  
aa    ]8I    `8b,d8'    aa    ]8I    88,   "8b,   ,aa  88      88      88     88  88  88b,   ,a8"  
`"YbbdP"'      Y88'     `"YbbdP"'    "Y888  `"Ybbd8"'  88      88      88     88  88  8Y"Ybbd8"'   
               d8'                                                                                 
              d8'                                                                                  
*/
.out    "# system library..."

/*
                                                                                
                                                                                
                                                                                
                                                                                
88,dPYba,,adPYba,   ,adPPYYba,   ,adPPYba,  8b,dPPYba,   ,adPPYba,   ,adPPYba,  
88P'   "88"    "8a  ""     `Y8  a8"     ""  88P'   "Y8  a8"     "8a  I8[    ""  
88      88      88  ,adPPPPP88  8b          88          8b       d8   `"Y8ba,   
88      88      88  88,    ,88  "8a,   ,aa  88          "8a,   ,a8"  aa    ]8I  
88      88      88  `"8bbdP"Y8   `"Ybbd8"'  88           `"YbbdP"'   `"YbbdP"'  
                                                                                
                                                                                
*/

.macro showCPUstart
  ; sprites + background
  ;lda #%10011111  ; blue
  ;lda #%01011111  ; green
  lda #%00111111  ; red
  ;lda #%00011111  ; monochrome
  sta PPU_MASK
  ldy #10 ;21     ; add about 23 for each additional line
:
  dey
  bne :-
.endmacro

.macro showCPUend
  lda PPU::MASK_VAR
  sta PPU_MASK
.endmacro

.scope system

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

  ; prng var
  seed:               .res 2  ; initialize 16-bit seed to any value except 0

  ; mult8x8 / mult16x8 / mult16x16

  multNum1    = $00   ; word
  multNum2    = $01   ; byte / word
  product     = $03   ; double

  ; div16_16

  divisor     = $00   ; word
  dividend    = $01   ; word
  remainder   = $03   ; word
  result      = dividend  ; save memory by reusing dividend to store the result

  ; Binary2Decimal vars

  tempBinary:         .res 2
  decimalResult:      .res 5
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

  .proc delayNMI
    ; X = number of NMIs
  :
    jsr PPU::waitNMI
    dex
    bne :-

    rts
  .endproc

  .proc delayFrame
   ; X = number of frames
  :
    jsr PPU::waitFrame
    dex
    bne :-

    rts
  .endproc

  .proc div16_16

  divide:
    lda #0          ;preset remainder to 0
    sta remainder
    sta remainder+1
    ldx #16         ;repeat for each bit: ...

  divloop:
    asl dividend    ;dividend lb & hb*2, msb -> Carry
    rol dividend+1  
    rol remainder   ;remainder lb & hb * 2 + msb from carry
    rol remainder+1
    lda remainder
    sec
    sbc divisor     ;substract divisor to see if it fits in
    tay             ;lb result -> Y, for we may need it later
    lda remainder+1
    sbc divisor+1
    bcc skip        ;if carry=0 then divisor didn't fit in yet

    sta remainder+1 ;else save substraction result as new remainder,
    sty remainder   
    inc result      ;and INCrement result cause divisor fit in 1 times

  skip:
    dex
    bne divloop

    rts

  .endproc

  ; prng
  ; 
  ; Returns a random 8-bit number in A (0-255), clobbers X (0).
  ; 
  ; Requires a 2-byte value on the zero page called "seed".
  ; Initialize seed to any value except 0 before the first call to prng.
  ; (A seed value of 0 will cause prng to always return 0.)
  ; 
  ; This is a 16-bit Galois linear feedback shift register with polynomial $002D.
  ; The sequence of numbers it generates will repeat after 65535 calls.
  ; 
  ; The value loaded in X controls the quality of randomness. Each iteration produces another bit worth of entropy.
  ; 8 bits will produce maximum entropy, but this value can be lowered to increase speed.
  ; Valid values are 8, 7, 4, 2, 1. (Avoid 6, 5 and 3, as they shorten the sequence by having common factors with 65535.)
  ; 
  ; Execution time is an average of 125 cycles (excluding jsr and rts)
  ; https://wiki.nesdev.com/w/index.php/Random_number_generator

  .proc prng
    ldx #8     ; iteration count: controls entropy quality (max 8,7,4,2,1 min)
    lda seed+0
  :
    asl        ; shift the register
    rol seed+1
    bcc :+
    eor #$2D   ; apply XOR feedback whenever a 1 bit is shifted out
  :
    dex
    bne :--
    sta seed+0
    cmp #0     ; reload flags
    rts
  .endproc

/*
  .proc prng

    lda seed+1
    tay ; store copy of high byte
    ; compute seed+1 ($39>>1 = %11100)
    lsr ; shift to consume zeroes on left...
    lsr
    lsr
    sta seed+1 ; now recreate the remaining bits in reverse order... %111
    lsr
    eor seed+1
    lsr
    eor seed+1
    eor seed+0 ; recombine with original low byte
    sta seed+1
    ; compute seed+0 ($39 = %111001)
    tya ; original high byte
    sta seed+0
    asl
    eor seed+0
    asl
    eor seed+0
    asl
    asl
    asl
    eor seed+0
    sta seed+0
    rts

  .endproc
*/
.endscope