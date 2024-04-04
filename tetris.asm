################ CSC258H1F Winter 2024 Assembly Final Project ##################
# This file contains our implementation of Tetris.
#
# Student 1: Name, Student Number
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

##############################################################################
# Mutable Data
##############################################################################
# Address of current tetromino location on bitmap
ADDR_TET:
    .word 0x1000819C
    
# Address of current tetromino "sprite"
# Sprite stored as values to add to tetromino location to draw pixels.
# E.g, drawing a straight horizontal 3 pixel line would be stored as 4, 4, 4, 0xffffff.
# When reading, go to next memory location until value is 0xffffff, indicating end.
# then, the next memory location indicates THE SPACE AFTER the lowest point, used for checking collisions.

ADDR_TET_SPRITE:
    .word 0x20000000
    
# Address of tetromino orientation
# values can be 0 to 3.
ADDR_TET_ORI:
    .word 0x30000000
    
COUNT:
    .word 0
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
    
    


game_loop:	
    # update count. if count reaches 10, move tetromino down.
    lw $t0 COUNT
    addi $t0 $t0 1
    beq $t0 10 respond_to_S
    sw $t0 COUNT
    

	# 1a. Check if key has been pressed
	lw $t0, ADDR_KBRD               # $t0 = base address for keyboard
    lw $t8, 0($t0)                  # Load first word from keyboard
    
    # 1b. Check which key has been pressed
    beq $t8, 1, keyboard_input      # If first word 1, key is pressed
	
    # 2a. Check for collisions
	# 2b. Update locations (paddle, ball)
	
	# 3. Draw the screen
	jal m_draw_scene
	
	lw $a0 ADDR_TET
	li $a1 0xAA336A # color pink
    jal m_draw_tetromino
    
    jal place_stored_tetrominoes
    jal clear_lines
    
	# 4. Sleep
    li 		$v0, 32
	li 		$a0, 100
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

    beq $a0, 0x61, respond_to_A     # Check if the key A was pressed
    beq $a0, 0x73, respond_to_S
    beq $a0, 0x77, respond_to_W 
    beq $a0, 0x64, respond_to_D  
    beq $a0, 0x71, respond_to_Q

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
    sw $zero COUNT
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
    
##################
# PLACE SPRITES IN MEMORY
store_tetromino_sprites:
    # hard code store L rotation 0
    lw $t0 ADDR_TET_SPRITE
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
    lw $t0 ADDR_TET_SPRITE
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
    lw $t0 ADDR_TET_SPRITE
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
    lw $t0 ADDR_TET_SPRITE
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
    jr $ra
    
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
        lw $t5 0($t2)   # get value to move brush
        addi $t2 $t2 4
        bne $t5 0xffffff check_sprite_col_loop
        addi $v0 $zero 0
        jr $ra
   col_detected: 
        addi $v0 $zero 1
        jr $ra

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
    lw $t1 ADDR_TET
    addi $t1 $zero 0x1000819C
    sw $t1 ADDR_TET
    jr $ra 
     
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
    
    
