/*
                                                              
                                  88     88  88  88           
                                  88     88  ""  88           
                                  88     88      88           
8b,dPPYba,   ,adPPYYba,   ,adPPYb,88     88  88  88,dPPYba,   
88P'    "8a  ""     `Y8  a8"    `Y88     88  88  88P'    "8a  
88       d8  ,adPPPPP88  8b       88     88  88  88       d8  
88b,   ,a8"  88,    ,88  "8a,   ,d88     88  88  88b,   ,a8"  
88`YbbdP"'   `"8bbdP"Y8   `"8bbdP"Y8     88  88  8Y"Ybbd8"'   
88                                                            
88                                                            
*/

.out    "# pad/controller library..."
.scope pad

  state     = padState
  pressed   = padPressed
  released  = padReleased

  read      = padRead

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

  padStateOld:        .res 1
  padState:           .res 1
  padPressed:         .res 1
  padReleased:        .res 1

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

  .proc padRead
    ; Y = controller # ( 0 | 1 )

    lda padState
    sta padStateOld         ; save previous joypad data
    lda #%01111111
    sta padState
    sta $4016
    asl A
    sta $4016
  :
    lda $4016,y
    and #$03                ; props to Disch for Famicon support
    cmp #$01
    ror padState            ; right, left, down, up, start, select, B, A
    bcs :-
    
    lda #0
    sta $4016
    lda #1
    sta $4016
    
    lda padStateOld
    eor #$FF
    and padState
    sta padPressed          ; this tracks off-to-on transitions.
    
    lda padState
    eor #$FF
    and padStateOld
    sta padReleased         ; this tracks on-to-off transitions

    lda padState

    rts

  .endproc

.endscope