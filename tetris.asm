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
    
##############################################################################
# Mutable Data
##############################################################################
# Address of current tetromino location on bitmap
ADDR_TET:
    .word 0x1000810c
    
# Address of current tetromino "sprite"
# Sprite stored as values to add to tetromino location to draw pixels.
# E.g, drawing a straight horizontal 3 pixel line would be stored as 4, 4, 4.
# When reading, go to next memory location until value is 0xffffff, indicating end.
ADDR_TET_SPRITE:
    .word 0x20000000
    
# Address of tetromino orientation
# values can be 0 to 3.
ADDR_TET_ORI:
    .word 0x30000000
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
    
    lw $a0 ADDR_TET     # initialize tetromino location
    sw $zero ADDR_TET_ORI
    jal store_tetromino_sprites
    # store current tetromino location in 0x20008000
    lw $a0 ADDR_TET 
    jal m_draw_tetromino


game_loop:	
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
    jal m_draw_tetromino
    
	# 4. Sleep
    li 		$v0, 32
	li 		$a0, 1
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

m_draw_tetromino:   # draw L tetromino
    lw $t2 ADDR_TET_SPRITE
    lw $t3 ADDR_TET_ORI
    li $t0 0xAA336A # color pink
    add $t1 $a0 $zero   # initialize brush location
    
   
    add $t4 $zero $zero
    
    # get memory location of correct orientation
    get_sprite_location:
        beq $t4 $t3 draw_sprite
        addi $t2 $t2 32
        addi $t4 $t4 1
        bne $t4 $t3 get_sprite_location
        beq $t4 $t3 draw_sprite
    
    draw_sprite:
        lw $t5 0($t2)   # get value to move brush
    draw_sprite_loop:
        add $t1 $t1 $t5 # add value to current brush location
        sw $t0 0($t1)   # draw
        lw $t5 0($t2)   # get value to move brush
        addi $t2 $t2 4
        bne $t5 0xffffff draw_sprite_loop
        
    jr $ra
    

    
##########################################
# MILESTONE 2
# PART A
keyboard_input:
    lw $a0, 4($t0)                  # Load second word from keyboard

    beq $a0, 0x61, respond_to_A     # Check if the key a was pressed
    beq $a0, 0x73, respond_to_S
    beq $a0, 0x77, respond_to_W 
    beq $a0, 0x64, respond_to_D  
    beq $a0, 0x71, respond_to_Q

respond_to_A:
    lw $t1 ADDR_TET     # load current tetromino address
    addi $t2 $zero 4    # move 
    sub $t1 $t1 $t2
    sw $t1 ADDR_TET     # store tetromino address
    b game_loop       # return to game loop

respond_to_S:
    lw $t1 ADDR_TET
    addi $t1 $t1 64
    sw $t1 ADDR_TET
    b game_loop

respond_to_W:
    lw $t2 ADDR_TET_ORI
    addi $t2 $t2 1
    beq $t2 4 reset_ori     # if orientation = 4, want to reset to 0
    sw $t2 ADDR_TET_ORI 
    b game_loop
    reset_ori:
        sw $zero ADDR_TET_ORI 
    b game_loop

respond_to_D:
    lw $t1 ADDR_TET
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
    
    # L rotation 1
    lw $t0 ADDR_TET_SPRITE
    addi $t0 $t0 32 # offset memory
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
    
    # L rotation 2
    lw $t0 ADDR_TET_SPRITE
    addi $t0 $t0 64 #offset memory
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
    
    # L rotation 3
    lw $t0 ADDR_TET_SPRITE
    addi $t0 $t0 96
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
    jr $ra
    
