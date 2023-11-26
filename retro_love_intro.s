;
;       .  ______   +[7N I G H T F A L L7];   _____
;       :__\    /___________ _________________\   /
;       !   \  /_/  _____/_/_\  /_ ___/ _  /  /  /\
;       ! \   /  \  /  /  \  / __/__/     /  /_____\
;       !__\  \__/____/  /__/  /__/___/  /_____\___/
;       l__/___\_\___/___\_/__/ /_\__/___\_____/fAZ!
;       <--\___/-----\___/-\__\/-----\___/--------->
;
;----------------------------------------------------------
	SECTION	STARTINGPOINT,CODE

; global variables
;----------------------------------------------------------
background_color=$111
grid_tile_light=$333
grid_tile_middle=$222
grid_tile_dark=$111
bar=$ffc
bar_shadow=$fb5
logo_w=40
logo_h=256
grid_w=40
grid_h=128
text_w=40
text_h=128
dancers_w=40
dancers_h=25

init:
; os related
;----------------------------------------------------------
; stop the os
	move.l	4.w,a6
	jsr	-$78(a6)
	lea	gfx_library(PC),a1
	jsr	-$198(a6)

; override the copperlist
	move.l	d0,gfx_base_address
	move.l	d0,a6
	move.l	$26(a6),old_copper_address

; assign the bitplanes to the logo, grid, text and dancers
;----------------------------------------------------------
; bpl logo
	move.l	#LOGO,d0
	lea	BPLPOINTERS_LOGO,a1
	moveq	#4,d1

logo_bitplane_pointers_loop:
	move.w	d0,6(a1)
	swap	d0
	move.w	d0,2(a1)
	swap	d0
	add.l	#logo_w*logo_h,d0
	addq.w	#8,a1
	dbra	d1,logo_bitplane_pointers_loop
               
; bpl text
	move.l	#BITPLANE_TEXT,d0
	lea	BPLPOINTERS_TEXT,a1
	move.w	d0,6(a1)
	swap	d0
	move.w	d0,2(a1)
        
; bpl grid
	move.l	#BITPLANE_GRID,d0
	lea	BPLPOINTERS_GRID,a1
	move.w	d0,6(a1)
	swap	d0
	move.w	d0,2(a1)
        
; bpl dancers
	move.l	#DANCERS_1,d0
	lea	BPLPOINTERS_DANCERS,a1
        moveq	#2-1,d1
        
dancers_bitplane_pointers_loop:
	move.w	d0,6(a1)
	swap	d0
	move.w	d0,2(a1)
	swap	d0
	add.l	#dancers_w*dancers_h,d0
	addq.w	#8,a1
	dbra	d1,dancers_bitplane_pointers_loop
        
;----------------------------------------------------------        
; point the new copper
	move.l	#START_COPPERLIST,$dff080
	move.w	d0,$dff088

; disable AGA
	move.w	#0,$dff1fc
	move.w	#$c00,$dff106  

; init the track, create grid, determine the initial timeframe vbl window
; of the logo and the dancers, and print the first text 
;----------------------------------------------------------
main:
        move.l	#BITPLANE_TEXT-(40*3),initial_bitplane_text
        
; create the grid
	bsr.w	make_grid
        
; print the text on screen, first page
        bsr.w   set_text_0
        
; init tracker player
       	bsr.w	pt_InitMusic

; we need to wait 25*47 seconds from when the dentro starts
; to synch the logo pattern and the dancers with the change 
; of tone in the track
        move.w  #25*46,timeframe_letters
; one less second for the dancers to "try" to vbl synch with the beat
; ps: I said "try" :)
        move.w  #25*47,timeframe_dancers
        
; main loop to render the dentro
;----------------------------------------------------------
; wait for line $ff(255) for proper smooth vsynch
main_loop:
; wait VBL
        btst    #5,$dff01f
        beq.b   main_loop
; clr VBL bit
        move.w  #$0020,$dff09c

; loop logo palette
        bsr.w   loop_logo_palette
        
; loop flash dancers
        bsr.w   loop_dancers
        bsr.w   check_frame_dancers
        
; make the mirror of the logo        
	bsr.w   start_waves
       
; scroll left<>right the grid       
      	bsr.w   grid_scroll

; text loop with delay between each page
        bsr.w   text_loop
        bsr.w   print_text
        
; play the mod tune
      	bsr.w	pt_PlayMusic
        
; check for left mouse
        btst	#6,$bfe001
        beq.s	exit
       
; cycle back to re-render the screen
        bra     main_loop
        
; exit operations, re-enable the os and set back the system copper
;----------------------------------------------------------
exit:
; stop the music
        bsr.w	pt_StopMusic
        
; set back the old copper of the os
	move.l	old_copper_address(PC),$dff080
	move.w	d0,$dff088

; start the os
	move.l	4.w,a6
	jsr	-$7e(a6)
	move.l	gfx_base_address(PC),a1
	jsr	-$19e(a6)
	
; exit clean from the program
	rts

; 
;----------------------------------------------------------
gfx_library:
	dc.b	"graphics.library",0,0	

gfx_base_address:
	dc.l	0

old_copper_address:
	dc.l	0

; logo mirror wave effect
;----------------------------------------------------------
start_waves:
	lea	WAVE_EFFECT+8,a0
	lea	WAVE_EFFECT,a1
	moveq	#16,d6
        
wave_cycle_values:
	move.w	(a0),(a1)
	addq.w	#8,a0	
	addq.w	#8,a1	
	dbra	d6,wave_cycle_values	

	move.w	WAVE_EFFECT,LAST_WAVE_EFFECT_VALUE

	rts
                                        
; grid
;----------------------------------------------------------
make_grid:
	lea	BITPLANE_GRID,a5
	moveq	#12-1,d2
        bsr.w   randomize_grid ; create every time a new grid pattern
        
make_couple:
	move.l	#(10*16)-1,d3
        not.l   d4             ; invert the pattern
        
make_odd:
	move.l  d4,(a5)+
	dbra	d3,make_odd

	move.l	#(10*16)-1,d3
        not.l   d4             ; invert the pattern
        
make_even:
	move.l	d4,(a5)+
	dbra	d3,make_even
	dbra	d2,make_couple
	rts
        
; not optimized at all but as usual it works :)
randomize_grid:
; check the position of the index and apply the correct pattern
        cmp.b	#0,pattern_index        
        beq.w	set_pattern_a
        
        cmp.b	#1,pattern_index
        beq.w	set_pattern_b
        
        cmp.b	#2,pattern_index
        beq.w	set_pattern_c
        
        cmp.b	#3,pattern_index
        beq.w	set_pattern_d
        
        cmp.b	#4,pattern_index
        beq.w	set_pattern_e
        
        cmp.b	#5,pattern_index
        beq.w	set_pattern_f
        
        rts

set_pattern_a:
        move.l  pattern_a,d4
        move.b  #1,pattern_index
        rts   
        
set_pattern_b:
        move.l  pattern_b,d4
        move.b  #2,pattern_index
        rts 
        
set_pattern_c:
        move.l  pattern_c,d4
        move.b  #3,pattern_index
        rts 
        
set_pattern_d:
        move.l  pattern_d,d4
        move.b  #4,pattern_index
        rts 
        
set_pattern_e:
        move.l  pattern_e,d4
        move.b  #5,pattern_index
        rts 
     
set_pattern_f:
        move.l  pattern_f,d4
        move.b  #0,pattern_index   ; reset the index
        rts 
        
pattern_a:
	dc.l	%11111111111111110000000000000000
pattern_b:
        dc.l	%11110000111100001111000011110000
pattern_c:
        dc.l	%11001100110011001100110011001100
pattern_d:
        dc.l	%01111110000111111000011111100001
pattern_e:
	dc.l	%11111111111111111111111111110000
pattern_f:
	dc.l	%11111100000011111100000011111100
     
pattern_index:
	dc.b	0,0
        
; grid scroll
grid_scroll:
	lea	BPLPOINTERS_GRID,a0
	move.w	2(a0),d0
	swap	d0	
	move.w	6(a0),d0
			
	tst.b	up_or_down
	beq.w	move_down
        
	cmp.l	#BITPLANE_GRID,d0
	beq.s	switch_down
	sub.l	#40,d0	
        
        bsr.w   fade_grid
	bra.s	complete

switch_down:
	bsr.w	make_grid
	clr.b	up_or_down	
	bra.s	complete

move_down:
	cmpi.l	#BITPLANE_GRID+(grid_w*250),d0
	beq.s	switch_up
	add.l	#40,d0	
        bsr.w   fade_grid
	bra.s	complete

switch_up:
	bsr.w	make_grid
	move.b	#$ff,up_or_down
	rts			
	  
complete:
	lea	BPLPOINTERS_GRID,a0
	move.w	d0,6(a0)
	swap	d0
	move.w	d0,2(a0)
	rts
 
; this is not optimized at all but at least it works :) 
fade_grid:
; reaching toward the bottom scroll
        cmp.l	#BITPLANE_GRID+(grid_w*250),d0
        beq.s	fade_1
        cmp.l	#BITPLANE_GRID+(grid_w*246),d0
        beq.s	fade_2
        cmp.l	#BITPLANE_GRID+(grid_w*242),d0
        beq.s	fade_3
; reaching toward the top scroll
        cmp.l	#BITPLANE_GRID,d0
        beq.s	fade_1
        cmp.l	#BITPLANE_GRID+(grid_w*4),d0
        beq.s	fade_2
        cmp.l	#BITPLANE_GRID+(grid_w*8),d0
        beq.s	fade_3        
        rts

fade_1:
        move.w  #$111,GRID_COLOR
        rts
fade_2:
        move.w  #$222,GRID_COLOR
        rts
fade_3:
        move.w  #$333,GRID_COLOR
        rts
    
up_or_down:
	dc.b	0,0
    
; text
;----------------------------------------------------------  
text_loop:
        add.w	#1,counter              ; add 1 at every second  
        cmp.w	#25*28,counter          ; did we reach 28 seconds? (25fps == 1 second * 28)
        beq.w   print_page       
        rts

print_page:
        clr.w	counter                 ; reset the counter to wait N seconds before printing the next one

        cmp.b	#0,page_index           ; decide which text to print     
        beq.w	set_text_0
        
        cmp.b	#1,page_index        
        beq.w	set_text_1
        
        cmp.b	#2,page_index 
        beq.w	set_text_2

        cmp.b	#3,page_index 
        beq.w	set_text_3
        
        cmp.b	#4,page_index 
        beq.w	set_text_4
        
        cmp.b	#5,page_index 
        beq.w	set_text_5
        
        rts

set_text_0:
        clr.b   text_line_index
        move.l  initial_bitplane_text,point_text_bitplane
        move.l	#text_0,point_text
        add.b	#1,page_index
        rts
        
set_text_1:
        clr.b   text_line_index
        move.l  initial_bitplane_text,point_text_bitplane
        move.l	#text_1,point_text
        add.b	#1,page_index
        rts
        
set_text_2:
        clr.b   text_line_index
        move.l  initial_bitplane_text,point_text_bitplane
        move.l	#text_2,point_text
        add.b	#1,page_index
        rts
        
set_text_3:
        clr.b   text_line_index
        move.l  initial_bitplane_text,point_text_bitplane
        move.l	#text_3,point_text
        add.b	#1,page_index
        rts
        
set_text_4:
        clr.b   text_line_index
        move.l  initial_bitplane_text,point_text_bitplane
        move.l	#text_4,point_text
        add.b	#1,page_index 
        rts
        
set_text_5:
        clr.b   text_line_index
        move.l  initial_bitplane_text,point_text_bitplane
        move.l	#text_5,point_text
        clr.b   page_index              ; reaching the last page we need to reset
        rts
        
counter:
	dc.w	0,0
page_index:
	dc.b	0,0
        
print_text:
        cmp.b	#14,text_line_index     ; check if we have reach the last line
	beq.w	skip_print	        ; if yes let's not render anymore the text
        
        move.l	point_text(PC),a0
	move.l	point_text_bitplane,a3 
	moveq	#14-1,d3	; 14 lines
print_line:                      
	moveq	#40-1,d0        ; 40 columns	
print_char:                     
	moveq	#0,d2		
	move.b	(a0)+,d2	
	sub.b	#$20,d2			
	mulu.w	#8,d2		
	move.l	d2,a2           
	add.l	#FONT,a2	
	move.b	(a2)+,(a3)	
	move.b	(a2)+,40(a3)	
	move.b	(a2)+,40*2(a3)	
	move.b	(a2)+,40*3(a3)	
	move.b	(a2)+,40*4(a3)	
	move.b	(a2)+,40*5(a3)	
	move.b	(a2)+,40*6(a3)	
	move.b	(a2)+,40*7(a3)	
	addq.w	#1,a3		       
	dbra	d0,print_char	

; move to the next line position in the screen
        add.l	#40*9,point_text_bitplane      
; move to the next line	in the text        
	add.l	#40,point_text                     
; add one line in the index       
        add.b	#1,text_line_index  
        
        rts

skip_print:
        rts

text_line_index:
        dc.b    0,0

point_text:
        dc.l    0

initial_bitplane_text:
        dc.l    0
        
point_text_bitplane:
        dc.l    BITPLANE_TEXT-(40*3)
        
text_0:   
                ; columns
                ;          111111111122222222223333333333
                ; 123456789012345678901234567890123456789
        dc.b	'                                        '
        dc.b	'                                        '
	dc.b	'  HOWDY FOLKS, HERE WE ARE, BACK AGAIN  '
	dc.b	' WITH A NEW FRESH DENTRO FROM NIGHTFALL '
	dc.b	'                CALLED:                 '
	dc.b	'                                        '
	dc.b	'                                        '
	dc.b	'                                        '
	dc.b	'             "RETRO LOVE"               '
	dc.b	'                                        '
	dc.b	'                                        '
        dc.b	'                                        '
        dc.b	'     AGES PASSES BUT WE REMAIN HERE     '
        dc.b	'                                        '
	even
        
text_1: 
        dc.b	'                                        '
        dc.b	'                                        '
	dc.b	'    A TINY PRODUCTION MADE WITH LOVE,   '
        dc.b    '   LOTS OF INGENUITY, AND TONS OF FUN.  '
	dc.b	'                                        '
	dc.b	'                                        '
        dc.b	'                                        '
	dc.b	'     CODE IS LIMITED, NON-OPTIMIZED,    '
	dc.b	'     CHEESY EFFECTS, BUT CONSIDERING    '
	dc.b	'   ONLY TWO MONTHS OF ASSEMBLY STUDIES  '
	dc.b	' FROM SCRATCH, THIS IS A GREAT SUCCESS. '
	dc.b	'                                        '
        dc.b	'                              :) LYNX   '
        dc.b	'                                        '
	even        

text_2:
        dc.b	'                                        '
	dc.b	'              LYNX GREETZ:              '
        dc.b	'                                        '
	dc.b	'        SANDERS/FOCUS,DANNYHEY!         '
        dc.b	'      RANDY/RAMJAM,PRINCE/PHAZE101      '
        dc.b	'     PSIONIKAL/ORANGES,ARNE/ORANGES     '
	dc.b	'             SPLIXX/ORANGES             '
        dc.b	'                                        '
	dc.b	'      APOLLO COMPUTERS COMMUNITY:       '
        dc.b	'   GUN,ARNE,TIM,TOMMO,PISKLAK,MORTEN    '
        dc.b	'     KAMELITO,REDBUG,DANNYPPC,FANTA     '
        dc.b	'           AND ALL THE REST...          '
        dc.b	'                                        '
	dc.b	'        ALSO: ROBY T., ANDREW F.        '
	even

text_3:
        dc.b	'                                        '
        dc.b	'                                        '
	dc.b	'               XAD GREETZ:              '
        dc.b	'                                        '
	dc.b	'  ALL DUDES IN HOKUTO FORCE (C64 SCENE) '
        dc.b	'  ESPECIALLY TO E$G AND THE OVERKILLER. '
        dc.b	'                                        '
        dc.b	'    ALSO GREET ALL THOSE WHO KNOW ME    '
        dc.b	'  FROM THE OLD C64/AMIGA/SNES/GB SCENE  '
        dc.b	'   THAT I HAD THE PLEASURE OF CHATTING  '
        dc.b	'       WITH OR MEETING PERSONALLY       '
        dc.b	'            MANY YEARS AGO.             '
        dc.b	'                                        '
        dc.b	'                                        '
	even

text_4:  
        dc.b	'                                        '
        dc.b	'                                        '
	dc.b	'                                        '
	dc.b	'                                        '
	dc.b	'                                        '
        dc.b	'                CREDITS:                '
        dc.b	'                                        '
	dc.b	'  CODE+GFX: LYNX/ NIGHTFALL^ORANGES     '
        dc.b	'        TRACK: PSIONIKAL/ORANGES        '
        dc.b	'                                        '
        dc.b	'                                        '
        dc.b	'                                        '
        dc.b	'                                        '
	dc.b	'                                        '
	even    
      
text_5: 
        dc.b	'                                        '
	dc.b	'                                        '
	dc.b	'                                        '
        dc.b	'                                        '
        dc.b	'                                        '
        dc.b	'                                        '
        dc.b	'                                        '
	dc.b	'         WWW.NIGHTFALLCREW.COM          '
        dc.b	'                                        '
        dc.b	'                                        '
        dc.b	'                                        '
	dc.b	'                                        '
	dc.b	'                                        '
	dc.b	'                                        '
	even   
        
; logo palette swap
;---------------------------------------------------------- 
loop_logo_palette:
        add.w	#1,counter_swap         ; add 1 at every second  
        move.w  timeframe_letters,d0    ; compare the current counter with the timeframe
        move.w  counter_swap,d1
        cmp.w   d0,d1                   
        beq.s   palette_logo_swap       ; change color of the letters if we have wait enough
        rts
  
palette_logo_swap:
; the timeframe to change color palette is now set to 3 seconds
        move.w  #25*3,timeframe_letters
; reset the counter to wait N seconds before printing the next one
        clr.w	counter_swap            
; decide which color pattern assign to the letters
        cmp.b	#0,index_swap           
        beq.w	palette_random_0
        
        cmp.b	#1,index_swap   
        beq.w	palette_random_1
        
        cmp.b	#2,index_swap   
        beq.w	palette_random_2
        
        cmp.b	#3,index_swap   
        beq.w	palette_random_3
        
        cmp.b	#4,index_swap   
        bsr.w	palette_random_4
        clr.w	index_swap              ; reset the index to create the loop
        rts

palette_random_0:
        lea     green_palette,a0
        lea     blue_palette,a1
        lea     red_palette,a2
        bra.s   palette_swap

palette_random_1:
        lea     red_palette,a0
        lea     blue_palette,a1
        lea     green_palette,a2
        bra.s   palette_swap

palette_random_2:
        lea     blue_palette,a0
        lea     green_palette,a1
        lea     red_palette,a2
        bra.s   palette_swap

palette_random_3:
        lea     green_palette,a0
        lea     red_palette,a1
        lea     blue_palette,a2
        bra.s   palette_swap
 
palette_random_4:
        lea     blue_palette,a0
        lea     green_palette,a1
        lea     red_palette,a2
        bra.w   palette_swap
        
palette_swap:
        move.w  (a0)+,g_col1     ; copy the color into the letter G
        move.w  (a0)+,g_col2
        move.w  (a0)+,g_col3
        move.w  (a0)+,g_col4
        move.w  (a0)+,g_col5
        move.w  (a0)+,g_col6
        move.w  (a0)+,g_col7
        move.w  (a1)+,t_col1     ; copy the color into the letter T
        move.w  (a1)+,t_col2
        move.w  (a1)+,t_col3
        move.w  (a1)+,t_col4
        move.w  (a1)+,t_col5
        move.w  (a1)+,t_col6
        move.w  (a1)+,t_col7
        move.w  (a2)+,a_col1     ; copy the color into the letter T
        move.w  (a2)+,a_col2
        move.w  (a2)+,a_col3
        move.w  (a2)+,a_col4
        move.w  (a2)+,a_col5
        move.w  (a2)+,a_col6
        move.w  (a2)+,a_col7
        add.b	#1,index_swap
        rts
     
red_palette:        
	dc.w	$fdd,$ebb,$d99,$c66,$b44,$a22,$900,$000       
green_palette:
	dc.w	$cfe,$aec,$0d0,$0b0,$080,$274,$041,$000
blue_palette:
	dc.w	$cef,$adf,$7cf,$4af,$27f,$05f,$03c,$000    

timeframe_letters:
        dc.w    0,0
        
counter_swap:
	dc.w	0,0
        
index_swap:
	dc.b	0,0

; dancers footer
;---------------------------------------------------------- 
loop_dancers:
        add.w	#1,counter_dancers      ; add 1 at every second  
        move.w  timeframe_dancers,d0    ; compare the current counter with the timeframe
        move.w  counter_dancers,d1
        cmp.w   d0,d1                   
        beq.w   reset_timeframe_dancers
        rts
        
reset_timeframe_dancers:
; the timeframe to flash the dancers is now set to 48 frames
        move.w  #48,timeframe_dancers
        clr.w   counter_dancers
        
; update bpl dancers
        tst     index_bitplane_dancers
        beq.s   update_1     
        move.l	#DANCERS_2,d0
        clr.b   index_bitplane_dancers
        bra.s   proceed
        
update_1:
        move.l	#DANCERS_1,d0
        addq.b  #1,index_bitplane_dancers
proceed:
	lea	BPLPOINTERS_DANCERS,a1
        moveq	#2-1,d1
        
loop_update_bpl_pntrs:
	move.w	d0,6(a1)
	swap	d0
	move.w	d0,2(a1)
	swap	d0
	add.l	#dancers_w*dancers_h,d0
	addq.w	#8,a1
	dbra	d1,loop_update_bpl_pntrs
        
        rts

; static (and not soo pretty) check on frame counter to tint the dancers colors
check_frame_dancers:
        move.w  timeframe_dancers,d0
        subq.w  #1,d0
        cmpi.w  counter_dancers,d0
        beq.s   flash_0
        
        subq.w  #1,d0
        cmpi.w  counter_dancers,d0
        beq.s   flash_1
        
        subq.w  #1,d0
        cmpi.w  counter_dancers,d0
        beq.s   flash_2
        
        subq.w  #1,d0
        cmpi.w  counter_dancers,d0
        beq.s   flash_3
      
        subq.w  #1,d0
        cmpi.w  counter_dancers,d0
        beq.s   flash_4
        
        subq.w  #1,d0
        cmpi.w  counter_dancers,d0
        beq.s   flash_5
        
        subq.w  #1,d0
        cmpi.w  counter_dancers,d0
        beq.s   flash_6
        
        rts
        
flash_0:
        move.w  #$111,DANCERS_COLOR_1
        move.w  #$000,DANCERS_COLOR_2
        rts

flash_1:
        move.w  #$222,DANCERS_COLOR_1
        move.w  #$111,DANCERS_COLOR_2
        rts
        
flash_2:
        move.w  #$333,DANCERS_COLOR_1
        move.w  #$222,DANCERS_COLOR_2
        rts
        
flash_3:
        move.w  #$444,DANCERS_COLOR_1
        move.w  #$333,DANCERS_COLOR_2
        rts
        
flash_4:
        move.w  #$555,DANCERS_COLOR_1
        move.w  #$444,DANCERS_COLOR_2
        rts

flash_5:
        move.w  #$666,DANCERS_COLOR_1
        move.w  #$555,DANCERS_COLOR_2
        rts

flash_6:
        move.w  #$777,DANCERS_COLOR_1
        move.w  #$666,DANCERS_COLOR_2
        rts
        
timeframe_dancers:
        dc.w    0,0
  
counter_dancers:
	dc.w	0,0

index_bitplane_dancers:
        dc.b    0,0
        
; protracker player
        include	"AMIGASHARED:Nightfall_Dentro_OCS/pt_player_3b.s"
        
;----------------------------------------------------------
	SECTION COPPERLIST,DATA_C

START_COPPERLIST:
	dc.w	$120,$0000,$122,$0000,$124,$0000,$126,$0000,$128,$0000
	dc.w	$12a,$0000,$12c,$0000,$12e,$0000,$130,$0000,$132,$0000
	dc.w	$134,$0000,$136,$0000,$138,$0000,$13a,$0000,$13c,$0000
	dc.w	$13e,$0000

	dc.w	$8e,$2c81
	dc.w	$90,$2cc1
	dc.w	$92,$0038
	dc.w	$94,$00d0
	dc.w	$102,0
	dc.w	$104,0
	dc.w	$108,0
	dc.w	$10a,0

; set the screen at 5bpl aka 32 colors for the logo
		     ;111111
                     ;5432109876543210
	dc.w	$100,%0101001000000000

BPLPOINTERS_LOGO:           
	dc.w	$e0,$0,$e2,$0	; bpl1pt
	dc.w 	$e4,$0,$e6,$0	; bpl2pt
	dc.w 	$e8,$0,$ea,$0	; bpl3pt
	dc.w 	$ec,$0,$ee,$0	; bpl4pt
	dc.w 	$f0,$0,$f2,$0	; bpl5pt
	        
	dc.w	$180,background_color

; full palette logo
	dc.w	$182,$fff       ; gray scale
	dc.w	$184,$eee
	dc.w	$186,$ccc
	dc.w	$188,$aaa
	dc.w	$18a,$888
	dc.w	$18c,$666
	dc.w	$18e,$444
        
; g_letter > blue scale
	dc.w	$190
g_col1: 
        dc.w    $cef       
	dc.w	$192
g_col2: 
        dc.w    $adf
	dc.w	$194
g_col3: 
        dc.w    $7cf
	dc.w	$196
g_col4: 
        dc.w    $4af
	dc.w	$198
g_col5: 
        dc.w    $27f
	dc.w	$19a
g_col6: 
        dc.w    $05f
	dc.w	$19c
g_col7: 
        dc.w    $03c   
  
; t_letter > red scale    
	dc.w	$19e
t_col1:
        dc.w    $fdd
	dc.w	$1a0
t_col2:
        dc.w    $ebb
	dc.w	$1a2
t_col3: 
        dc.w    $d99
	dc.w	$1a4
t_col4: 
        dc.w    $c66
	dc.w	$1a6
t_col5:
        dc.w    $b44
	dc.w	$1a8
t_col6: 
        dc.w    $a22
	dc.w	$1aa
t_col7: 
        dc.w    $900      
 
; a_letter > green scale
	dc.w	$1ac
a_col1:
        dc.w    $cfe   
	dc.w	$1ae
a_col2:
        dc.w    $aec
	dc.w	$1b0
a_col3:
        dc.w    $0d0
	dc.w	$1b2
a_col4:
        dc.w    $0b0
	dc.w	$1b4
a_col5:
        dc.w    $080
	dc.w	$1b6
a_col6:
        dc.w    $274
	dc.w	$1b8
a_col7:
        dc.w    $041

unused:
	dc.w	$1ba,$000
	dc.w	$1bc,$000
	dc.w	$1be,$000
        
; logo reflection
	dc.w	$5a07,$fffe
	dc.w	$108,-40*3
	dc.w	$10a,-40*3

; wave effect of the "logo mirrored effect"
	dc.w	$5a07,$fffe,$102
WAVE_EFFECT:
	dc.w	$00
	dc.w	$5b07,$fffe,$102,$11
        dc.w	$5c07,$fffe,$102,$22
        dc.w	$5d07,$fffe,$102,$33
        dc.w	$5e07,$fffe,$102,$22
	dc.w	$5f07,$fffe,$102,$44
        dc.w	$6007,$fffe,$102,$33
	dc.w	$6107,$fffe,$102,$44
        dc.w	$6207,$fffe,$102,$66
        dc.w	$6307,$fffe,$102,$55
	dc.w	$6407,$fffe,$102,$66
        dc.w	$6507,$fffe,$102,$44
        dc.w	$6607,$fffe,$102,$22
        dc.w	$6707,$fffe,$102,$33
        dc.w	$6807,$fffe,$102,$11
        dc.w	$6907,$fffe,$102,$22
	dc.w	$6a07,$fffe,$102
LAST_WAVE_EFFECT_VALUE:
	dc.w	$00
 
; reset to normality
        dc.w	$7007,$fffe
	dc.w	$102,0
	dc.w	$104,0
	dc.w	$108,0
	dc.w	$10a,0
        
; set zero bitplanes
;		     ;111111
;              	     ;5432109876543210
	dc.w	$100,%0000001000000000
      
; 1st bar
        dc.w	$8707,$fffe
	dc.w	$180,bar
	dc.w	$8d07,$fffe
	dc.w	$180,bar_shadow	
	dc.w	$9007,$fffe
	dc.w	$180,background_color

; set 2 bitplanes for the dancers bitplane
;		     ;111111
;              	     ;5432109876543210
	dc.w	$100,%0010011000000000
        
BPLPOINTERS_TEXT:
	dc.w	$e0,$0,$e2,$0	; bpl1pt

BPLPOINTERS_GRID:           
        dc.w	$e4,$0,$e6,$0	; bpl2pt
        dc.w 	$ec,$0,$ee,$0	; bpl4pt
        dc.w 	$f0,$0,$f2,$0   ; bpl6pt
        
; grid and text palette
	dc.w 	$182,$fff               ; palette bpl1 playfield 1
        dc.w	$192
GRID_COLOR:
        dc.w    grid_tile_light         ; palette bpl2 playfield 2
        
; wait line 255 line for PAL
	dc.w	$ffdf,$fffe

; reset to the normal at line 10, where the 2nd bar starts
        dc.w	$1007,$fffe
       	dc.w	$180,bar
; trick to hide some pixels of the dancers bitmap over the bar
        dc.w	$184,bar        
        
; set the screen at 1bpl (we have nothing below the grid)
		     ;111111
                     ;5432109876543210
	dc.w	$100,%0010001000000000
        
BPLPOINTERS_DANCERS:
	dc.w	$e0,$0,$e2,$0	; bpl1pt
	dc.w 	$e4,$0,$e6,$0	; bpl2pt
        
; 2nd bar
	dc.w	$1607,$fffe
	dc.w	$180,bar_shadow
; trick to hide some pixels of the dancers bitmap over the bar
        dc.w	$184,bar_shadow
	dc.w	$1907,$fffe
	dc.w	$180,background_color

; colors for the dancers
        dc.w	$182
DANCERS_COLOR_1:
        dc.w    background_color
        dc.w	$184
DANCERS_COLOR_2:
        dc.w    background_color
        dc.w	$186,$111
        
END_COPPERLIST:
	dc.w	$ffff,$fffe
;----------------------------------------------------------
	SECTION ASSETS,DATA_C

Module:
        incbin	"AMIGASHARED:Nightfall_Dentro_OCS/orange_lights.mod"
        
; prefill with empty space because we need to make the mirror effect
; so we do not want to see random bytes
	dcb.b 	logo_w*logo_h,0
        
LOGO:
	incbin	"AMIGASHARED:Nightfall_Dentro_OCS/logo.raw"
FONT:
	incbin	"AMIGASHARED:Nightfall_Dentro_OCS/custom_font_8.raw"
DANCERS_1:        
        dcb.b 	dancers_w*10,0
	incbin	"AMIGASHARED:Nightfall_Dentro_OCS/dancers_1.raw" 
DANCERS_2:        
        dcb.b 	dancers_w*10,0
	incbin	"AMIGASHARED:Nightfall_Dentro_OCS/dancers_2.raw"        
;----------------------------------------------------------
	SECTION	BITPLANES,BSS_C

BITPLANE_GRID:
	ds.b    grid_w*(grid_h*3)    
BITPLANE_TEXT:
	ds.b    text_w*(text_h*2)
BITPLANE_DANCERS:
	ds.b    dancers_w*dancers_h
;----------------------------------------------------------
	end
