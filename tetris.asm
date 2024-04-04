################ CSC258H1F Winter 2024 Assembly Final Project ##################
# This file contains our implementation of Tetris.
#
# Student 1: Han Xheng Chew, 1009562340
# Student 2: Name, Student Number (if applicable)
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       128
# - Unit height in pixels:      256
# - Display width in pixels:    8
# - Display height in pixels:   8
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000
    
# Address of tetronominoes that have been placed. 
# Simulates the display.
# DSPL + 65536
ADDR_TET_BOARD: 
    .word 0x10018000
    
ADDR_DSPL_TOP:
    .word 0x1000810C
    
    # Address of current tetromino location on bitmap
ADDR_TET:
    .word 0x1000819C
    
# Address of current tetromino "sprite"
# Sprite stored as values to add to tetromino location to draw pixels.
# E.g, drawing a straight horizontal 3 pixel line would be stored as 4, 4, 4, 0xffffff.
# When reading, go to next memory location until value is 0xffffff, indicating end.
# then, the next memory location indicates THE SPACE AFTER the lowest point, used for checking collisions.
ADDR_TET_SPRITES:
    .word 0x20000000

ADDR_TET_SPRITE:
    .word 0x20000000
    
# Address of tetromino orientation
# values can be 0 to 3.
ADDR_TET_ORI:
    .word 0x30000000
    
L: .word 0x20000000
Sq: .word 0x20000100
I: .word 0x20000200
S: .word 0x20000300
Z: .word 0x20000400
J: .word 0x20000500
T: .word 0x20000600

##############################################################################
# Mutable Data
##############################################################################
TIME_COUNT:
    .word 0
    
SPEED_COUNT:
    .word 0
    
CURR_SPEED: 
    .word 32 # number that count has to reach. lower is faster

IS_PAUSED:
    .byte 0 # 0 if not paused, 1 if paused.
    
IS_GAME_OVER:
    .byte 0 # 0 if not game over, 1 if game over.
    
BEEP:
    .byte 72
DURATION:
    .byte 100
VOLUME: 
    .byte 70
##############################################################################
# Code
##############################################################################
	.text
	.globl main
	
## NOTES FOR ME 
# reserve jal for main

	# Run the Tetris game.
main:

    # Initialize the game
    jal m_draw_scene
    
    # set initial tetromino location
    lw $a0 ADDR_TET     # initialize tetromino location
    sw $zero ADDR_TET_ORI   # store current tetromino orientation in 0x3000000
    jal store_tetromino_sprites
    
    # draw initial tetromino
    lw $a0 ADDR_TET 
    li $a1 0xAA336A # color pink
    jal m_draw_tetromino
    
    li $a0 1484
    jal fill_random_rows
    li $a0 1548
    jal fill_random_rows
    li $a0 1612
    jal fill_random_rows
    li $a0 1676
    jal fill_random_rows
    li $a0 1740
    jal fill_random_rows
    
    


game_loop:	

    lb $t0 IS_PAUSED
    beq $t0 1 skip_move
    lb $t0 IS_GAME_OVER
    beq $t0 1 skip_move
    # update count. if count reaches CURR_SPEED, move tetromino down.
    lw $t0 TIME_COUNT
    addi $t0 $t0 1
    lw $t1 CURR_SPEED
    sw $t0 TIME_COUNT
    sub $t2 $t0 $t1 
    bgtz $t2 respond_to_S
    
    
    lw $t0 SPEED_COUNT
    addi $t0 $t0 1
    sw $t0 SPEED_COUNT
    beq $t0 24 increase_speed
    
    skip_move:
	# 1a. Check if key has been pressed
	lw $t0, ADDR_KBRD               # $t0 = base address for keyboard
    lw $t8, 0($t0)                  # Load first word from keyboard
    
    # 1b. Check which key has been pressed
    beq $t8, 1, keyboard_input      # If first word 1, key is pressed
	
    # 2a. Check for collisions
	# 2b. Update locations (paddle, ball)
	
	lb $t0 IS_GAME_OVER
    beq $t0 1 skip_draw
	# 3. Draw the screen
	jal m_draw_scene
	
	lw $a0 ADDR_TET
	li $a1 0xAA336A # color pink
    jal m_draw_tetromino
    
    jal place_stored_tetrominoes
    jal clear_lines
    
    jal check_game_over
    
    skip_draw:
	# 4. Sleep
    li 		$v0, 32
	li 		$a0, 50
	syscall
    #5. Go back to 1
    b game_loop
    
######################################################################
# MILESTONE 1
# our game area is 10 x 24 pixels
# PART A
m_draw_scene:
    li $t0, 0xffffff        # $t0 = white
    add $s0 $zero $ra           # save address of main
    
    li $a0, 12               # set wall width (w * 4)
    jal draw_left
    jal draw_right
    
    li $a0, 256            # set floor and ceiling width (w * 64)
    jal draw_top
    jal draw_bottom
        
    li $t0, 0x555555    #$t0 = grey
    li $t1, 0x000000    #$t1 = black
    jal draw_grid
    
    jal draw_paused
    
    jr $s0                  # return to main
    
draw_bottom:
    lw $a2, ADDR_DSPL
    add $t9 $zero $zero     # initialize width counter
    addi $a2 $a2 1792   # offset brush
    b draw_horizontal_line_width
draw_top:
    lw $a2, ADDR_DSPL
    add $t9 $zero $zero
    b draw_horizontal_line_width
draw_right:
    lw $a2, ADDR_DSPL
    addi $a2 $a2 52
    add $t9 $zero $zero
    b draw_vertical_line_width
draw_left:                  # draw left wall, call with $a0 as wall width
    lw $a2, ADDR_DSPL       
    add $t9 $zero $zero     # $t9 = initalize counter to draw wall width
draw_vertical_line_width:
    # let $a0 contain the width in number of pixels 
    add $t1, $a2, $zero      # $t1 = base address for display
    add $t1, $t1, $t9
draw_vertical_line:
    add $t2 $zero $zero    # initialize counter
draw_vertical_line_loop:
    sw $t0, 0($t1)      # paint
    addi $t1, $t1, 64   # move to next pixel in bitmap
    addi $t2, $t2, 1    # increase counter by 1
    bne $t2, 32 draw_vertical_line_loop

    addi $t9, $t9, 4    # increment counter 
    bne $t9 $a0 draw_vertical_line_width    # draw the next vertical line
    jr $ra

draw_horizontal_line_width:
    # let $a0 contain the width in number of pixels 
    add $t1, $a2, $zero      # $t1 = base address for display
    add $t1, $t1, $t9
draw_horizontal_line:
    add $t2 $zero $zero    # initialize counter
draw_horizontal_line_loop:
    sw $t0, 0($t1)      # paint
    addi $t1, $t1, 4   # move to next pixel in bitmap
    addi $t2, $t2, 1    # increase counter by 1
    bne $t2, 16 draw_horizontal_line_loop

    addi $t9, $t9, 64   # increment counter 
    bne $t9 $a0 draw_horizontal_line_width    # draw the next horizontal line
    jr $ra
    
   
######################
# PART B
draw_grid:
    add $s1 $ra $zero   # store address to go back to after function run
    add $t3 $zero $zero     # counter for number of times to draw 2 rows
    
    lw $t4 ADDR_DSPL    # starting point of draw_2_rows
draw_2_rows:
    add $t2 $zero $zero # initialize counter to 0. want to count to 5
    add $a2, $zero $t4
    addi $a2 $a2 268
    jal draw_checkers1
    
    add $t2 $zero $zero # initialize counter to 0. want to count to 5
    add $a2, $zero $t4
    addi $a2 $a2 332
    jal draw_checkers2
    
    addi $t3 $t3 1
    addi $t4 $t4 128
    bne $t3 12 draw_2_rows

    jr $s1
    
draw_checkers1:
    sw $t0 0($a2)
    addi $a2 $a2 4
    sw $t1 0($a2)
    addi $a2 $a2 4
    addi $t2 $t2 1
    bne $t2 5 draw_checkers1
    jr $ra
    
draw_checkers2:
    sw $t1 0($a2)
    addi $a2 $a2 4
    sw $t0 0($a2)
    addi $a2 $a2 4
    addi $t2 $t2 1
    bne $t2 5 draw_checkers2
    jr $ra
    
#########################
# PART C
# assume position at $a0
# assume colour in $a1
# draw a new tetromino
m_draw_tetromino:   # draw L tetromino
    lw $t2 ADDR_TET_SPRITE
    lw $t3 ADDR_TET_ORI
    add $t1 $a0 $zero   # initialize brush location
    add $t4 $zero $zero
    
    # get memory location of correct orientation
    get_sprite_location:
        beq $t4 $t3 draw_sprite
        addi $t2 $t2 64
        addi $t4 $t4 1
        bne $t4 $t3 get_sprite_location
        beq $t4 $t3 draw_sprite
    
    draw_sprite:
        lw $t5 0($t2)   # get value to move brush
    draw_sprite_loop:
        add $t1 $t1 $t5 # add value to current brush location
        sw $a1 0($t1)   # draw
        lw $t5 0($t2)   # get value to move brush
        addi $t2 $t2 4
        bne $t5 0xffffff draw_sprite_loop
        
    jr $ra
    

    
##########################################
# MILESTONE 2
# PART A
keyboard_input:
    lw $a0, 4($t0)                  # Load second word from keyboard
    beq $a0, 0x70, respond_to_P
    
    lb $t0 IS_PAUSED
    beq $t0 1 game_loop

    beq $a0, 0x61, respond_to_A     # Check if the key A was pressed
    beq $a0, 0x73, respond_to_S
    beq $a0, 0x77, respond_to_W 
    beq $a0, 0x64, respond_to_D  
    beq $a0, 0x71, respond_to_Q
    beq $a0, 0x72, respond_to_R
    

respond_to_A:
    lw $t1 ADDR_TET     # load current tetromino address
    addi $a0 $t1 -4     # run collision check
    lw $a1 ADDR_TET_ORI
    jal check_collision
    lw $t1 ADDR_TET     # load current tetromino address
    beq $v0 1 game_loop
    addi $t1 $t1 -4    # move 
    sw $t1 ADDR_TET     # store tetromino address
    b game_loop       # return to game loop

respond_to_S:
    sw $zero TIME_COUNT
    lw $t1 ADDR_TET
    addi $a0 $t1 64    # run collision check
    lw $a1 ADDR_TET_ORI
    jal check_collision
    lw $t1 ADDR_TET     # load current tetromino address
    beq $v0 1 game_loop
    addi $t1 $t1 64
    sw $t1 ADDR_TET
    add $a0 $t1 $zero  # run touch check
    jal check_bottom_touching
    beq $v0 1 handle_placement
    b game_loop
    handle_placement:
        jal place_tetronomino
        jal play_sound_place
        jal reset_position
        b game_loop

respond_to_W:
    lw $t1 ADDR_TET
    lw $t2 ADDR_TET_ORI
    addi $t2 $t2 1
    beq $t2 4 reset_ori     # if orientation = 4, want to reset to 0
    store_ori:
        add $a0 $t1 $zero   # tetris location
        add $a1 $t2 $zero   # orientation number
        jal check_collision # check if rotation causes collision
        beq $v0 1 game_loop # if collide, return to game loop.
        sw $a1 ADDR_TET_ORI 
        jal play_sound_r
        b game_loop
    reset_ori:
        add $t2 $zero $zero
        b store_ori
    b game_loop

respond_to_D:
    lw $t1 ADDR_TET
    addi $a0 $t1 4     # run collision check
    lw $a1 ADDR_TET_ORI
    jal check_collision
    lw $t1 ADDR_TET     # load current tetromino address
    beq $v0 1 game_loop
    addi $t1 $t1 4
    sw $t1 ADDR_TET
    b game_loop
    
respond_to_Q:
    li $v0, 10                      # Quit gracefully
	syscall
	
respond_to_P:
    lb $t0 IS_PAUSED
    beq $t0 0 pause_to_1
    beq $t0 1 pause_to_0
    pause_to_1:
        li $t0 1
        sb $t0 IS_PAUSED
        b game_loop
    pause_to_0:
        li $t0 0
        sb $t0 IS_PAUSED
        b game_loop
    
respond_to_R:
    lb $t0 IS_GAME_OVER
    beq $t0 0 game_loop
    jal clear_board
    li $t0 32
    sw $t0 CURR_SPEED
    li $t0 0x1000819C
    sw $t0 ADDR_TET
    
    li $a0 1484
    jal fill_random_rows
    li $a0 1548
    jal fill_random_rows
    li $a0 1612
    jal fill_random_rows
    li $a0 1676
    jal fill_random_rows
    li $a0 1740
    jal fill_random_rows
    
    b game_loop
    
    
############################
# Collision detection
# sets $v0 to 0 if no collision and 1 if collision
# $a0 = new location
# $a1 = new orientation
check_collision:
    lw $t2 ADDR_TET_SPRITE
    lw $t3 ADDR_TET_ORI
    add $t4 $zero $zero # current orientation
    
     # get memory location of correct orientation
    get_sprite_location_col:
        beq $t4 $a1 check_sprite_col
        addi $t2 $t2 64
        addi $t4 $t4 1
        bne $t4 $a1 get_sprite_location_col
        beq $t4 $a1 check_sprite_col
    
    check_sprite_col:
        lw $t5 0($t2)   # get value to move pointer
    check_sprite_col_loop:
        add $a0 $a0 $t5 # add value to current pointer location
        lw $t1 0($a0) # get current pixel value
        beq $t1 0xffffff col_detected
        beq $t1 0x87cefa col_detected
        lw $t5 0($t2)   # get value to move brush
        addi $t2 $t2 4
        bne $t5 0xffffff check_sprite_col_loop
        beq $t5 0x87cefa check_sprite_col_loop
        addi $v0 $zero 0
        jr $ra
   col_detected: 
        add $t0 $ra $zero
        jal play_sound_c
        addi $v0 $zero 1
        jr $t0

# sets $v0 to 0 if not touching and 1 if touching
check_bottom_touching:
    lw $t2 ADDR_TET_SPRITE
    lw $t3 ADDR_TET_ORI
    add $t4 $zero $zero # current orientation
    
     # get memory location of correct orientation
    get_sprite_location_touch:
        beq $t4 $t3 get_sprite_lowest
        addi $t2 $t2 64
        addi $t4 $t4 1
        bne $t4 $t3 get_sprite_location_touch
        beq $t4 $t3 get_sprite_lowest
    get_sprite_lowest:  # go to next location until end pointer of sprite
        addi $t2 $t2 4
        lw $t0 0($t2)
        bne $t0 0xffffff get_sprite_lowest
        
    check_sprite_touch:
        addi $t2 $t2 4
        lw $t5 0($t2)   # load location of lowest point pixel
        beq $t5 0xffffff no_touch
        add $t0 $a0 $t5 # location of lowest point on bitmap
        lw $t5 0($t0)   # check colour at location of lowest point
        beq $t5 0x555555 check_sprite_touch   # no touch, go to next lowest point
        beq $t5 0x0000000 check_sprite_touch
        addi $v0 $zero 1
        jr $ra
    no_touch:
        add $v0 $zero $zero
        jr $ra
    
##########################################
# place tetronominoes
# store tetronomino locations in ADDR_TET_BOARD
# $a0 has current tetronomino location
place_tetronomino:
    lw $t0 ADDR_TET_BOARD
    lw $t2 ADDR_TET_SPRITE
    lw $t3 ADDR_TET_ORI
    lw $t6 ADDR_TET
    li $t1 0x87CEFA # colour
    addi $t0 $a0 0x00010000

    
    # get memory location of correct orientation
    add $t4 $zero $zero
    get_sprite_location_store:
        beq $t4 $t3 sprite_store
        addi $t2 $t2 64
        addi $t4 $t4 1
        bne $t4 $t3 get_sprite_location_store
        beq $t4 $t3 sprite_store
        
    sprite_store:
        lw $t5 0($t2)   # get value to move pointer
    sprite_store_loop:
        add $t0 $t0 $t5 # add value to current pointer location
        sw $t1 0($t0)   # store colour at offset location
        addi $t2 $t2 4    # next sprite pointer
        lw $t5 0($t2)   # get value to move brush
        bne $t5 0xffffff sprite_store_loop            
        jr $ra
    
place_stored_tetrominoes:
    lw $t0 ADDR_TET_BOARD # pointer
    lw $t7 ADDR_TET_BOARD # starting point
    li $t1 0  # initialize row counter (up to 16)
    li $t2 0   # initialize column counter (up to 32)
    li $t3 0x87CEFA # colour
    lw $t4 ADDR_DSPL_TOP
    
    
    place_stored_column_loop:
        beq $t2 32 exit_place_stored
        addi $t2 $t2 1
        add $t7 $t7 64
        add $t0 $zero $t7
        
        li $t1 0 
        place_stored_row_loop:
            beq $t1 16 place_stored_column_loop
            addi $t1 $t1 1
            add $t0 $t0 4
            lw $t5 0($t0)
            bne $t5 0x87CEFA place_stored_row_loop
            addi $t5 $t0 -65536
            sw $t3 0($t5) 
            b place_stored_row_loop
        
    exit_place_stored:
        jr $ra
    
reset_position:
    add $t0 $zero $ra
    lw $t1 ADDR_TET
    addi $t1 $zero 0x1000819C
    sw $t1 ADDR_TET
    
    jal get_random_sprite
    jr $t0
     
#########################
# CLEARING LINES
clear_lines:
    lw $t0 ADDR_TET_BOARD   
    lw $t1 ADDR_DSPL_TOP    # set memory pointer
    addi $t1 $t1 65536
    lw $t6 0($t1)   # colour pointer
    li $t2 0    # row counter, multiple of 4
    li $t3 0    # column counter, multiple of 64
    li $t4 0    # filled pixel counter
    
    check_line:
        bne $t6 0x87CEFA check_next_line
        count_filled_pixel:
            addi $t4 $t4 1
        check_next_pixel:
            addi $t2 $t2 4
            addi $t1 $t1 4    # move pointer
            lw $t6 0($t1)
            beq $t4 10 clear_line
            bne $t4 10 check_line
        clear_line:
            lw $t1 ADDR_DSPL_TOP
            addi $t1 $t1 65536
            li $t2 0    # row counter, up to 10
            li $t4 0
            add $t1 $t1 $t3
            clear_line_loop:
                sw $t4 0($t1)
                addi $t1 $t1 4
                addi $t2 $t2 1
                beq $t2 10 bring_lines_down
                bne $t2 10 clear_line_loop
        check_next_line:
            addi $t3 $t3 64    # column counter, multiple of 64
            lw $t1 ADDR_DSPL_TOP
            addi $t1 $t1 65536
            add $t1 $t1 $t3
            lw $t6 0($t1)
            li $t2 0    # row counter, multiple of 4
            
            li $t4 0    # filled pixel counter
            bne $t3 1536 check_line
            beq $t3 1536 exit_clear_stored
        bring_lines_down:
            lw $t1 ADDR_DSPL_TOP
            addi $t1 $t1 65536  
            li $t4 0    # row counter, up to 10
            add $t1 $t1 $t3 # current memory pointer of cleared row
            add $t2 $t1 $zero  # memory pointer of row to move to
            addi $t1 $t1 -64    # memory pointer of row to move from
            bring_lines_down_loop:
                lw $t5 0($t1)   
                sw $t5 0($t2)   # bring down line
                addi $t4 $t4 1
                addi $t1 $t1 4
                addi $t2 $t2 4
                beq $t4 10 bring_down_next_line
                bne $t4 10 bring_lines_down_loop
            bring_down_next_line:
                addi $t3 $t3 -64
                beq $t3 -64 exit_clear_stored
                bne $t3 -64 bring_lines_down
    exit_clear_stored:
        jr $ra
    
    
increase_speed:
    lw $t0 CURR_SPEED
    beq $t0 2 exit_increase_speed
    addi $t0 $t0 -1
    sw $t0 CURR_SPEED
    
    
    exit_increase_speed:
        sw $zero SPEED_COUNT
        b game_loop
    
draw_paused:
    lb $t0 IS_PAUSED
    beq $t0 0 exit_draw_paused
    lw $t0 ADDR_DSPL
    li $t1 0x2222dd
    
    #p
    sw $t1 0($t0)
    sw $t1 64($t0)
    sw $t1 128($t0)
    sw $t1 192($t0)
    sw $t1 4($t0)
    sw $t1 72($t0)
    sw $t1 132($t0)
    
    #a
    addi $t0 $t0 320
    sw $t1 4($t0)
    sw $t1 64($t0)
    sw $t1 128($t0)
    sw $t1 192($t0)
    sw $t1 132($t0)
    sw $t1 136($t0)
    sw $t1 72($t0)
    sw $t1 200($t0)
    
    #u
    addi $t0 $t0 320
    sw $t1 0($t0)
    sw $t1 8($t0)
    sw $t1 64($t0)
    sw $t1 128($t0)
    sw $t1 192($t0)
    sw $t1 196($t0)
    sw $t1 136($t0)
    sw $t1 72($t0)
    sw $t1 200($t0)
    
    #s
    addi $t0 $t0 320
    sw $t1 0($t0)
    sw $t1 4($t0)
    sw $t1 8($t0)
    sw $t1 64($t0)
    sw $t1 128($t0)
    sw $t1 132($t0)
    sw $t1 136($t0)
    sw $t1 200($t0)
    sw $t1 264($t0)
    sw $t1 260($t0)
    sw $t1 256($t0)
    
    #e
    addi $t0 $t0 384
    sw $t1 0($t0)
    sw $t1 4($t0)
    sw $t1 8($t0)
    sw $t1 64($t0)
    sw $t1 128($t0)
    sw $t1 132($t0)
    sw $t1 136($t0)
    sw $t1 192($t0)
    sw $t1 256($t0)
    sw $t1 260($t0)
    sw $t1 264($t0)
    
    #d
    addi $t0 $t0 384
    sw $t1 0($t0)
    sw $t1 4($t0)
    sw $t1 64($t0)
    sw $t1 72($t0)
    sw $t1 128($t0)
    sw $t1 136($t0)
    sw $t1 192($t0)
    sw $t1 196($t0)
    
    exit_draw_paused:
        jr $ra
    
check_game_over:
    lw $t0 ADDR_DSPL_TOP
    addi $t0 $t0 256    # offset 2 rows
    addi $t0 $t0 65536  # move to tet board
    li $t1 0    # counter to find end of row
    check_game_over_loop:
        lw $t2 0($t0)
        beq $t2 0x87CEFA trigger_game_over
        addi $t1 $t1 1
        addi $t0 $t0 4
        bne $t1 10 check_game_over_loop
    jr $ra
        
    
trigger_game_over:
    lw $t0 ADDR_DSPL
    li $t1 0xff6688
    #g
    sw $t1 0($t0)
    sw $t1 4($t0)
    sw $t1 8($t0)
    sw $t1 64($t0)
    sw $t1 128($t0)
    sw $t1 136($t0)
    sw $t1 192($t0)
    sw $t1 200($t0)
    sw $t1 256($t0)
    sw $t1 260($t0)
    sw $t1 264($t0)
    
    #a
    addi $t0 $t0 16
    sw $t1 4($t0)
    sw $t1 64($t0)
    sw $t1 72($t0)
    sw $t1 128($t0)
    sw $t1 132($t0)
    sw $t1 136($t0)
    sw $t1 192($t0)
    sw $t1 200($t0)
    sw $t1 256($t0)
    sw $t1 264($t0)
    
    #m
    addi $t0 $t0 16
    sw $t1 4($t0)
    sw $t1 12($t0)
    sw $t1 64($t0)
    sw $t1 72($t0)
    sw $t1 80($t0)
    sw $t1 128($t0)
    sw $t1 136($t0)
    sw $t1 144($t0)
    sw $t1 192($t0)
    sw $t1 200($t0)
    sw $t1 208($t0)
    sw $t1 256($t0)
    sw $t1 264($t0)
    sw $t1 272($t0)

    #e 
    addi $t0 $t0 24
    sw $t1 0($t0)
    sw $t1 4($t0)
    sw $t1 64($t0)
    sw $t1 128($t0)
    sw $t1 132($t0)
    sw $t1 192($t0)
    sw $t1 256($t0)
    sw $t1 260($t0)
    
    #o
    lw $t0 ADDR_DSPL
    addi $t0 $t0 384
    sw $t1 0($t0)
    sw $t1 4($t0)
    sw $t1 8($t0)
    sw $t1 64($t0)
    sw $t1 72($t0)
    sw $t1 128($t0)
    sw $t1 136($t0)
    sw $t1 192($t0)
    sw $t1 200($t0)
    sw $t1 256($t0)
    sw $t1 260($t0)
    sw $t1 264($t0)
    
    #v
    addi $t0 $t0 16
    sw $t1 0($t0)
    sw $t1 8($t0)
    sw $t1 64($t0)
    sw $t1 72($t0)
    sw $t1 128($t0)
    sw $t1 136($t0)
    sw $t1 192($t0)
    sw $t1 200($t0)
    sw $t1 260($t0)
    
    #e
    addi $t0 $t0 16
    sw $t1 0($t0)
    sw $t1 4($t0)
    sw $t1 8($t0)
    sw $t1 64($t0)
    sw $t1 128($t0)
    sw $t1 132($t0)
    sw $t1 136($t0)
    sw $t1 192($t0)
    sw $t1 256($t0)
    sw $t1 260($t0)
    sw $t1 264($t0)
    
    #r
    addi $t0 $t0 16
    sw $t1 0($t0)
    sw $t1 4($t0)
    sw $t1 64($t0)
    sw $t1 72($t0)
    sw $t1 128($t0)
    sw $t1 132($t0)
    sw $t1 192($t0)
    sw $t1 200($t0)
    sw $t1 256($t0)
    sw $t1 264($t0)
    
    li $t0 1
    sb $t0 IS_GAME_OVER
    
    jal play_sound_over
    
    b game_loop

clear_board:
    sb $zero IS_GAME_OVER
    lw $t0 ADDR_TET_BOARD
    li $t1 0
    clear_board_loop:
        sw $zero 0($t0)
        addi $t1 $t1 1
        addi $t0 $t0 4
        beq $t1 512 exit_clear_board
        bne $t1 512 clear_board_loop
    exit_clear_board:
        jr $ra
    
play_sound_r:
    li $v0,31
    lb $a0, BEEP
    addi $t2,$a0,12 
    lb $a1, DURATION
    li $a2, 2
    lb $a3, VOLUME
    
    move $t2,$a0
    move $t3,$a1
    
    syscall
    jr $ra
    
play_sound_c:
    li $v0,31
    lb $a0, BEEP
    addi $t2,$a0,12 
    lb $a1, DURATION
    li $a2, 6
    lb $a3, VOLUME
    
    move $t2,$a0
    move $t3,$a1
    
    syscall
    jr $ra
    
play_sound_place:
    li $v0,31
    li $a0, 40
    addi $t2,$a0,12 
    lb $a1, DURATION
    li $a2, 4
    lb $a3, VOLUME
    
    move $t2,$a0
    move $t3,$a1
    
    syscall
    jr $ra
    
play_sound_over:
    li $v0,31
    li $a0, 80
    li $a1, 50
    li $a2, 4
    li $a3,70
    syscall
    li $v0,31
    li $a0, 100
    syscall
    
    li $v0,31
    li $a0, 60
    li $a1, 50
    li $a2, 4
    li $a3,70
    syscall
    li $v0,31
    li $a0, 100
    syscall
    li $v0,31
    li $a0, 40
    li $a1, 50
    li $a2, 4
    li $a3,70
    syscall
    jr $ra
    

# a0 is number to offset from top
fill_random_rows:
    lw $t0 ADDR_TET_BOARD
    li $t2 0x87CEFA
    add $t0 $t0 $a0
    li $t3 0

    b get_random_number
    fill_random_row_loop:
        sw $t2 0($t0)
        addi $t3 $t3 1
        addi $t0 $t0 4
        beq $t3 $a0 exit_fill_random
        bne $t3 $a0 fill_random_row_loop
    
    get_random_number:
        li $v0 42
        li $a0 0
        li $a1 9
        syscall
        addi $a0 $a0 1
        b fill_random_row_loop
    exit_fill_random:
        jr $ra
        
##################
# PLACE SPRITES IN MEMORY
store_tetromino_sprites:
    # hard code store L rotation 0
    lw $t0 L
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero 64
    sw $t1 4($t0) 
    addi $t1 $zero 64
    sw $t1 8($t0) 
    addi $t1 $zero 4
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 192
    sw $t1 20($t0) 
    li $t1 196
    sw $t1 24($t0) 
    li $t1 0xffffff
    sw $t1 28($t0) 
    
    # L rotation 1
    lw $t0 L
    addi $t0 $t0 64 # offset memory
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero 4
    sw $t1 4($t0) 
    addi $t1 $zero 4
    sw $t1 8($t0) 
    addi $t1 $zero -64
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0)
    li $t1 64
    sw $t1 20($t0) 
    li $t1 68
    sw $t1 24($t0) 
    li $t1 72
    sw $t1 28($t0) 
    li $t1 0xffffff
    sw $t1 32($t0) 
    
    # L rotation 2
    lw $t0 L
    addi $t0 $t0 128 #offset memory
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero -64
    sw $t1 4($t0) 
    addi $t1 $zero -64
    sw $t1 8($t0) 
    addi $t1 $zero -4
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0)
    li $t1 64
    sw $t1 20($t0) 
    li $t1 -68
    sw $t1 24($t0)
    li $t1 0xffffff
    sw $t1 28($t0)
    
    # L rotation 3
    lw $t0 L
    addi $t0 $t0 192
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero -4
    sw $t1 4($t0) 
    addi $t1 $zero -4
    sw $t1 8($t0) 
    addi $t1 $zero 64
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 60
    sw $t1 20($t0) 
    li $t1 64
    sw $t1 24($t0) 
    li $t1 120
    sw $t1 28($t0) 
    li $t1 0xffffff
    sw $t1 32($t0) 
    
    ###################################
    # hard code store square rotation 0
    lw $t0 Sq
    addi $t0 $t0 0
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero 4
    sw $t1 4($t0) 
    addi $t1 $zero 64
    sw $t1 8($t0) 
    addi $t1 $zero -4
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 128
    sw $t1 20($t0) 
    li $t1 132
    sw $t1 24($t0) 
    li $t1 0xffffff
    sw $t1 28($t0) 
    
    lw $t0 Sq
    addi $t0 $t0 64
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero -64
    sw $t1 4($t0) 
    addi $t1 $zero 4
    sw $t1 8($t0) 
    addi $t1 $zero 64
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 64
    sw $t1 20($t0) 
    li $t1 68
    sw $t1 24($t0) 
    li $t1 0xffffff
    sw $t1 28($t0) 
    
    lw $t0 Sq
    addi $t0 $t0 128
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero -4
    sw $t1 4($t0) 
    addi $t1 $zero -64
    sw $t1 8($t0) 
    addi $t1 $zero 4
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 64
    sw $t1 20($t0) 
    li $t1 60
    sw $t1 24($t0) 
    li $t1 0xffffff
    sw $t1 28($t0) 
    
    lw $t0 Sq
    addi $t0 $t0 196
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero 64
    sw $t1 4($t0) 
    addi $t1 $zero -4
    sw $t1 8($t0) 
    addi $t1 $zero -64
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 128
    sw $t1 20($t0) 
    li $t1 124
    sw $t1 24($t0) 
    li $t1 0xffffff
    sw $t1 28($t0) 
    
    ###################################
    # hard code store i rotation 0
    lw $t0 I
    addi $t0 $t0 0
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero 64
    sw $t1 4($t0) 
    addi $t1 $zero 64
    sw $t1 8($t0) 
    addi $t1 $zero 64
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 256
    sw $t1 20($t0) 
    li $t1 0xffffff
    sw $t1 24($t0) 
    
    lw $t0 I
    addi $t0 $t0 64
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero 4
    sw $t1 4($t0) 
    addi $t1 $zero 4
    sw $t1 8($t0) 
    addi $t1 $zero 4
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 64
    sw $t1 20($t0) 
    li $t1 68
    sw $t1 24($t0) 
    li $t1 72
    sw $t1 28($t0) 
    li $t1 76
    sw $t1 32($t0) 
    li $t1 0xffffff
    sw $t1 36($t0) 
    
    lw $t0 I
    addi $t0 $t0 128
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero -64
    sw $t1 4($t0) 
    addi $t1 $zero -64
    sw $t1 8($t0) 
    addi $t1 $zero -64
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 64
    sw $t1 20($t0) 
    li $t1 0xffffff
    sw $t1 24($t0) 
    
    lw $t0 I
    addi $t0 $t0 196
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero -4
    sw $t1 4($t0) 
    addi $t1 $zero -4
    sw $t1 8($t0) 
    addi $t1 $zero -4
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 64
    sw $t1 20($t0) 
    li $t1 60
    sw $t1 24($t0) 
    li $t1 56
    sw $t1 28($t0) 
    li $t1 52
    sw $t1 32($t0) 
    li $t1 0xffffff
    sw $t1 36($t0)  
    
    #############
    # s rotation
    lw $t0 S
    addi $t0 $t0 0
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero 4
    sw $t1 4($t0) 
    addi $t1 $zero -64
    sw $t1 8($t0) 
    addi $t1 $zero 4
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 64
    sw $t1 20($t0) 
    li $t1 68
    sw $t1 24($t0) 
    li $t1 8
    sw $t1 28($t0) 
    li $t1 0xffffff
    sw $t1 32($t0) 
    
    lw $t0 S
    addi $t0 $t0 64
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero -64
    sw $t1 4($t0) 
    addi $t1 $zero -4
    sw $t1 8($t0) 
    addi $t1 $zero -64
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 64
    sw $t1 20($t0) 
    li $t1 -4
    sw $t1 24($t0) 
    li $t1 0xffffff
    sw $t1 28($t0) 
    
    lw $t0 S
    addi $t0 $t0 128
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero -4
    sw $t1 4($t0) 
    addi $t1 $zero 64
    sw $t1 8($t0) 
    addi $t1 $zero -4
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 64
    sw $t1 20($t0) 
    li $t1 124
    sw $t1 24($t0) 
    li $t1 120
    sw $t1 28($t0) 
    li $t1 0xffffff
    sw $t1 32($t0) 
    
    lw $t0 S
    addi $t0 $t0 192
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero 64
    sw $t1 4($t0) 
    addi $t1 $zero 4
    sw $t1 8($t0) 
    addi $t1 $zero 64
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 128
    sw $t1 20($t0) 
    li $t1 196
    sw $t1 24($t0) 
    li $t1 0xffffff
    sw $t1 28($t0) 
    
    ####################
    # z rotation
    lw $t0 Z
    addi $t0 $t0 0
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero 4
    sw $t1 4($t0) 
    addi $t1 $zero 64
    sw $t1 8($t0) 
    addi $t1 $zero 4
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 64
    sw $t1 20($t0) 
    li $t1 132
    sw $t1 24($t0) 
    li $t1 136
    sw $t1 28($t0) 
    li $t1 0xffffff
    sw $t1 32($t0) 
    
    lw $t0 Z
    addi $t0 $t0 64
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero -64
    sw $t1 4($t0) 
    addi $t1 $zero 4
    sw $t1 8($t0) 
    addi $t1 $zero -64
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 64
    sw $t1 20($t0) 
    li $t1 -60
    sw $t1 24($t0) 
    li $t1 0xffffff
    sw $t1 28($t0) 
    
    lw $t0 Z
    addi $t0 $t0 128
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero -4
    sw $t1 4($t0) 
    addi $t1 $zero -64
    sw $t1 8($t0) 
    addi $t1 $zero -4
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 64
    sw $t1 20($t0) 
    li $t1 60
    sw $t1 24($t0) 
    li $t1 -8
    sw $t1 28($t0) 
    li $t1 0xffffff
    sw $t1 32($t0) 
    
    lw $t0 Z
    addi $t0 $t0 192
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero 64
    sw $t1 4($t0) 
    addi $t1 $zero -4
    sw $t1 8($t0) 
    addi $t1 $zero 64
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 128
    sw $t1 20($t0) 
    li $t1 188
    sw $t1 24($t0) 
    li $t1 0xffffff
    sw $t1 28($t0) 
    
    ################
    # j rotation
    lw $t0 J
    addi $t0 $t0 0
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero 64
    sw $t1 4($t0) 
    addi $t1 $zero 64
    sw $t1 8($t0) 
    addi $t1 $zero -4
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 192
    sw $t1 20($t0) 
    li $t1 188
    sw $t1 24($t0) 
    li $t1 0xffffff
    sw $t1 28($t0) 
    
    lw $t0 J
    addi $t0 $t0 64
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero 4
    sw $t1 4($t0) 
    addi $t1 $zero 4
    sw $t1 8($t0) 
    addi $t1 $zero 64
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 64
    sw $t1 20($t0) 
    li $t1 68
    sw $t1 24($t0) 
    li $t1 136
    sw $t1 28($t0) 
    li $t1 0xffffff
    sw $t1 32($t0) 
    
    lw $t0 J
    addi $t0 $t0 128
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero -64
    sw $t1 4($t0) 
    addi $t1 $zero -64
    sw $t1 8($t0) 
    addi $t1 $zero 4
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 64
    sw $t1 20($t0) 
    li $t1 -60
    sw $t1 24($t0) 
    li $t1 0xffffff
    sw $t1 28($t0) 
    
    lw $t0 J
    addi $t0 $t0 192
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero -4
    sw $t1 4($t0) 
    addi $t1 $zero -4
    sw $t1 8($t0) 
    addi $t1 $zero -64
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 64
    sw $t1 20($t0) 
    li $t1 60
    sw $t1 24($t0) 
    li $t1 56
    sw $t1 28($t0) 
    li $t1 0xffffff
    sw $t1 32($t0) 
    
    ################
    # t rotation
    lw $t0 T
    addi $t0 $t0 0
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero 4
    sw $t1 4($t0) 
    addi $t1 $zero 4
    sw $t1 8($t0) 
    addi $t1 $zero 60
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 64
    sw $t1 20($t0) 
    li $t1 132
    sw $t1 24($t0) 
    li $t1 72
    sw $t1 28($t0) 
    li $t1 0xffffff
    sw $t1 32($t0) 
    
    lw $t0 T
    addi $t0 $t0 64
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero -64
    sw $t1 4($t0) 
    addi $t1 $zero -64
    sw $t1 8($t0) 
    addi $t1 $zero 68
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 64
    sw $t1 20($t0) 
    li $t1 4
    sw $t1 24($t0) 
    li $t1 0xffffff
    sw $t1 28($t0) 
    
    lw $t0 T
    addi $t0 $t0 128
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero -4
    sw $t1 4($t0) 
    addi $t1 $zero -64
    sw $t1 8($t0) 
    addi $t1 $zero 60
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 64
    sw $t1 20($t0) 
    li $t1 60
    sw $t1 24($t0) 
    li $t1 56
    sw $t1 28($t0) 
    li $t1 0xffffff
    sw $t1 32($t0) 
    
    lw $t0 T
    addi $t0 $t0 192
    li $t1 0x000000
    sw $t1 0($t0) 
    addi $t1 $zero 64
    sw $t1 4($t0) 
    addi $t1 $zero -4
    sw $t1 8($t0) 
    addi $t1 $zero 68
    sw $t1 12($t0) 
    li $t1 0xffffff
    sw $t1 16($t0) 
    li $t1 192
    sw $t1 20($t0) 
    li $t1 124
    sw $t1 24($t0) 
    li $t1 0xffffff
    sw $t1 28($t0) 
    
    jr $ra
    
get_random_sprite:
    lw $t1 ADDR_TET_SPRITES
    li $t2 0 # counter
    
    li $v0 42
    li $a0 0
    li $a1 7
    syscall # get random number from 0 -6  
    
    get_random_sprite_loop:
        beq $t2 $a0 exit_get_random_sprite
        addi $t1 $t1 256
        addi $t2 $t2 1
        bne $t2 $a0 get_random_sprite_loop
        
    exit_get_random_sprite:
        sw $t1 ADDR_TET_SPRITE
        jr $ra
    
    