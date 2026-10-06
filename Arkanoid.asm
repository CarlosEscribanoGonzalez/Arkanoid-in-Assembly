# ----- Constants -----
.eqv DISPLAY_BASE      0x10010000   # Base address of the bitmap display
.eqv COLS              32           # Display width in units (256 / 8)
.eqv ROWS              32           # Display height in units (256 / 8)
.eqv LAST_ROW          31           # Last row of the display (ROWS - 1)
.eqv DISPLAY_CELLS     1024         # COLS * ROWS

.eqv COLOR_BACKGROUND  0x8CD9D3
.eqv COLOR_PADDLE      0xD52222
.eqv COLOR_BALL        0x40783E
.eqv COLOR_LIFE        0xD52222

.eqv PADDLE_ROW        30           # Row where the paddle lives
.eqv PADDLE_WIDTH      5            # Paddle width in cells
.eqv PADDLE_LAST       4            # Offset of the last paddle cell
.eqv PADDLE_MAX_X      27           # Rightmost x for the paddle's left end
.eqv PADDLE_START_X    13

.eqv BALL_START_X      15
.eqv BALL_START_Y      24

.eqv BLOCK_FIRST_ROW   2            # Blocks occupy rows 2, 3 and 4
.eqv BLOCK_LAST_ROW    4
.eqv BLOCK_FIRST_COL   1            # Blocks occupy columns 1 to 30
.eqv BLOCKS_PER_ROW    30

.eqv SOUND_ENABLED     1            # 1 = sound effects on, 0 = off
.eqv START_DELAY_MS    100          # Delay between frames at the start of a round
.eqv MIN_DELAY_MS      30           # Fastest possible game speed
.eqv SPEED_STEP_MS     10           # Delay reduction at each speed increase
.eqv HITS_PER_SPEEDUP  3            # Paddle bounces needed to speed the ball up

# ----- Data -----
# Placed after the display memory (0x10010000 - 0x10010FFF) so that the
# variables are never overwritten by the pixels.
.data 0x10011000
blockColors:  .word 0xF2A93B, 0xB05CC8, 0x3B6FD9   # One color for each row of blocks
paddleHits:   .word 0                              # Paddle bounces since the last speed increase
msgWin:       .asciiz "You win! All the blocks have been destroyed.\n"
msgLose:      .asciiz "Game over. You have run out of lives.\n"
msgQuit:      .asciiz "Game ended by the player.\n"

# ----- Game logic -----
.text
main:
	li	$s1, 5				# The player starts with 5 lives
	jal	paintBackground			# Paint the whole display with the background color
	jal	drawBlocks			# Draw the blocks (also sets $s0)
	jal	drawLives			# Draw the lives in the top row
	jal	resetRound			# Place the paddle and the ball

gameLoop:
	# Keyboard input:
	lui	$t0, 0xffff			# $t0 = 0xffff0000
	lw	$t1, 0($t0)			# Receiver control register
	andi	$t1, $t1, 1			# Ready bit
	beqz	$t1, moveBall			# No key pressed: skip input
	lw	$t2, 4($t0)			# Receiver data (reading it clears the ready bit)
	beq	$t2, 97, pressedLeft		# 'a'
	beq	$t2, 65, pressedLeft		# 'A'
	beq	$t2, 100, pressedRight		# 'd'
	beq	$t2, 68, pressedRight		# 'D'
	beq	$t2, 32, quitGame		# Space bar
	b	moveBall			# Any other key is ignored

pressedLeft:
	blez	$s2, moveBall			# Paddle already at the left margin
	addi	$a0, $s2, PADDLE_LAST		# The rightmost paddle cell is erased
	li	$a1, PADDLE_ROW
	li	$a2, COLOR_BACKGROUND
	jal	drawCell
	addi	$s2, $s2, -1			# Move one cell to the left
	move	$a0, $s2			# A new cell is painted on the left
	li	$a1, PADDLE_ROW
	li	$a2, COLOR_PADDLE
	jal	drawCell
	b	moveBall

pressedRight:
	li	$t0, PADDLE_MAX_X
	bge	$s2, $t0, moveBall		# Paddle already at the right margin
	move	$a0, $s2			# The leftmost paddle cell is erased
	li	$a1, PADDLE_ROW
	li	$a2, COLOR_BACKGROUND
	jal	drawCell
	addi	$s2, $s2, 1			# Move one cell to the right
	addi	$a0, $s2, PADDLE_LAST		# A new cell is painted on the right
	li	$a1, PADDLE_ROW
	li	$a2, COLOR_PADDLE
	jal	drawCell

moveBall:
	move	$a0, $s3			# Erase the ball from its current cell
	move	$a1, $s4
	li	$a2, COLOR_BACKGROUND
	jal	drawCell

	add	$t4, $s3, $s5			# $t4 = next x of the ball
	add	$t5, $s4, $s6			# $t5 = next y of the ball

	# Side walls
	bltz	$t4, bounceSide			# Left margin
	li	$t0, COLS
	blt	$t4, $t0, checkTopWall		# Inside the screen: no side bounce
bounceSide:
	sub	$s5, $zero, $s5			# Invert horizontal speed
	add	$t4, $s3, $s5			# Recalculate next x
	jal	playSound

	# Top wall (row 0 is reserved for the lives)
checkTopWall:
	bgtz	$t5, checkBottom		# Next y >= 1: no top bounce
	sub	$s6, $zero, $s6			# Invert vertical speed
	add	$t5, $s4, $s6			# Recalculate next y
	jal	playSound

	# Bottom margin and paddle
checkBottom:
	li	$t0, LAST_ROW
	bgt	$t5, $t0, loseLife		# The ball went below the screen: lose a life
	bne	$t5, PADDLE_ROW, checkBlocks	# Only the paddle row can have a paddle collision
	blt	$t4, $s2, checkBlocks		# The ball is to the left of the paddle
	addi	$t0, $s2, PADDLE_LAST
	bgt	$t4, $t0, checkBlocks		# The ball is to the right of the paddle

	# The ball hits the paddle
	sub	$s6, $zero, $s6			# Invert vertical speed
	add	$t5, $s4, $s6			# Recalculate next y
	jal	playSound
	lw	$t0, paddleHits
	addi	$t0, $t0, 1			# One more paddle bounce
	li	$t1, HITS_PER_SPEEDUP
	blt	$t0, $t1, storeHits
	li	$t0, 0				# Reset the counter and speed the ball up
	addi	$s7, $s7, -SPEED_STEP_MS
	li	$t1, MIN_DELAY_MS
	bge	$s7, $t1, storeHits
	li	$s7, MIN_DELAY_MS		# Do not go faster than the limit
storeHits:
	sw	$t0, paddleHits
	b	drawBall

	# Blocks: the three cells the ball can touch when moving diagonally are checked
checkBlocks:
	move	$a0, $s3			# Vertical neighbour: (ballX, nextY)
	move	$a1, $t5
	jal	isBlock
	move	$t6, $v0			# $t6 = 1 if there is a block above/below the ball
	move	$a0, $t4			# Horizontal neighbour: (nextX, ballY)
	move	$a1, $s4
	jal	isBlock
	move	$t7, $v0			# $t7 = 1 if there is a block at the side of the ball
	move	$a0, $t4			# Diagonal cell: (nextX, nextY)
	move	$a1, $t5
	jal	isBlock
	move	$t8, $v0			# $t8 = 1 if there is a block in the diagonal
	or	$t0, $t6, $t7
	or	$t0, $t0, $t8
	beqz	$t0, drawBall			# No block in any of the three cells: no collision

	beqz	$t6, checkHitHorizontal		# Block immediately above/below: it is hit first
	move	$a0, $s3
	move	$a1, $t5
	jal	breakBlock
	sub	$s6, $zero, $s6			# Invert vertical speed
checkHitHorizontal:
	beqz	$t7, checkHitDiagonal		# Block at the side of the ball
	move	$a0, $t4
	move	$a1, $s4
	jal	breakBlock
	sub	$s5, $zero, $s5			# Invert horizontal speed
checkHitDiagonal:
	or	$t0, $t6, $t7
	bnez	$t0, afterBlockHit		# The diagonal block only counts if it is the only one (corner hit)
	move	$a0, $t4
	move	$a1, $t5
	jal	breakBlock
	sub	$s5, $zero, $s5			# A corner hit inverts both speeds
	sub	$s6, $zero, $s6
afterBlockHit:
	move	$t4, $s3			# The ball stays in place during this frame
	move	$t5, $s4
	beqz	$s0, winGame			# No blocks left: the player wins

drawBall:
	move	$s3, $t4			# Update the ball position
	move	$s4, $t5
	move	$a0, $s3
	move	$a1, $s4
	li	$a2, COLOR_BALL
	jal	drawCell

	move	$a0, $s7			# Wait for the current frame delay
	jal	waitMs
	b	gameLoop

loseLife:
	addi	$s1, $s1, -1			# One life less
	jal	drawLives			# Update the lives display
	jal	playSound
	beqz	$s1, gameOver			# No lives left: the game is over
	li	$a2, COLOR_BACKGROUND
	jal	drawPaddle			# Erase the paddle from its current position
	jal	resetRound			# Everything goes back to its initial state
	b	gameLoop

winGame:
	li	$v0, 4
	la	$a0, msgWin
	syscall
	b	exitProgram

gameOver:
	li	$v0, 4
	la	$a0, msgLose
	syscall
	b	exitProgram

quitGame:
	li	$v0, 4
	la	$a0, msgQuit
	syscall

exitProgram:
	li	$v0, 10				# Syscall 10: exit
	syscall

resetRound:
	addi	$sp, $sp, -4
	sw	$ra, 0($sp)
	li	$s2, PADDLE_START_X
	li	$s3, BALL_START_X
	li	$s4, BALL_START_Y
	li	$s5, 1				# The ball starts going right
	li	$s6, -1				# and up
	li	$s7, START_DELAY_MS
	sw	$zero, paddleHits
	li	$a2, COLOR_PADDLE
	jal	drawPaddle
	move	$a0, $s3
	move	$a1, $s4
	li	$a2, COLOR_BALL
	jal	drawCell
	li	$a0, 700			# Short pause so that the player can get ready
	jal	waitMs
	lw	$ra, 0($sp)
	addi	$sp, $sp, 4
	jr	$ra

paintBackground:
	li	$t0, DISPLAY_BASE
	li	$t1, DISPLAY_CELLS
	li	$t2, COLOR_BACKGROUND
paintBackgroundLoop:
	sw	$t2, 0($t0)
	addi	$t0, $t0, 4			# Next cell
	addi	$t1, $t1, -1
	bgtz	$t1, paintBackgroundLoop
	jr	$ra

drawLives:
	li	$t0, DISPLAY_BASE
	li	$t1, COLS
	li	$t2, COLOR_BACKGROUND
clearLivesLoop:
	sw	$t2, 0($t0)
	addi	$t0, $t0, 4
	addi	$t1, $t1, -1
	bgtz	$t1, clearLivesLoop
	blez	$s1, drawLivesDone		# No lives to draw
	li	$t0, DISPLAY_BASE
	move	$t1, $s1
	li	$t2, COLOR_LIFE
drawLivesLoop:
	sw	$t2, 0($t0)
	addi	$t0, $t0, 4
	addi	$t1, $t1, -1
	bgtz	$t1, drawLivesLoop
drawLivesDone:
	jr	$ra

drawBlocks:
	li	$s0, 0
	li	$t0, BLOCK_FIRST_ROW		# $t0 = current row
drawBlocksRowLoop:
	la	$t3, blockColors
	addi	$t4, $t0, -BLOCK_FIRST_ROW
	sll	$t4, $t4, 2			# Index of the row color (4 bytes per word)
	add	$t3, $t3, $t4
	lw	$t2, 0($t3)			# $t2 = color of this row
	sll	$t1, $t0, 5			# row * 32
	addi	$t1, $t1, BLOCK_FIRST_COL
	sll	$t1, $t1, 2			# * 4 bytes
	li	$t5, DISPLAY_BASE
	add	$t1, $t1, $t5			# $t1 = address of the first block of the row
	li	$t6, BLOCKS_PER_ROW
drawBlocksColLoop:
	sw	$t2, 0($t1)
	addi	$t1, $t1, 4
	addi	$s0, $s0, 1			# Count the block
	addi	$t6, $t6, -1
	bgtz	$t6, drawBlocksColLoop
	addi	$t0, $t0, 1			# Next row
	li	$t7, BLOCK_LAST_ROW
	ble	$t0, $t7, drawBlocksRowLoop
	jr	$ra

drawPaddle:
	li	$t0, PADDLE_ROW
	sll	$t0, $t0, 5			# row * 32
	add	$t0, $t0, $s2			# + x
	sll	$t0, $t0, 2			# * 4 bytes
	li	$t1, DISPLAY_BASE
	add	$t0, $t0, $t1			# $t0 = address of the leftmost paddle cell
	li	$t2, PADDLE_WIDTH
drawPaddleLoop:
	sw	$a2, 0($t0)
	addi	$t0, $t0, 4
	addi	$t2, $t2, -1
	bgtz	$t2, drawPaddleLoop
	jr	$ra

drawCell:
	sll	$t0, $a1, 5			# y * 32
	add	$t0, $t0, $a0			# + x
	sll	$t0, $t0, 2			# * 4 bytes
	li	$t1, DISPLAY_BASE
	add	$t0, $t0, $t1
	sw	$a2, 0($t0)
	jr	$ra

isBlock:
	li	$v0, 0
	li	$t0, BLOCK_FIRST_ROW
	blt	$a1, $t0, isBlockDone		# Above the block rows
	li	$t0, BLOCK_LAST_ROW
	bgt	$a1, $t0, isBlockDone		# Below the block rows
	sll	$t0, $a1, 5
	add	$t0, $t0, $a0
	sll	$t0, $t0, 2
	li	$t1, DISPLAY_BASE
	add	$t0, $t0, $t1
	lw	$t1, 0($t0)			# Color of the cell
	li	$t2, COLOR_BACKGROUND
	beq	$t1, $t2, isBlockDone		# Background color: empty cell
	li	$v0, 1
isBlockDone:
	jr	$ra

breakBlock:
	addi	$sp, $sp, -4
	sw	$ra, 0($sp)
	li	$a2, COLOR_BACKGROUND
	jal	drawCell			# Erase the block
	addi	$s0, $s0, -1			# One block less
	jal	playSound
	lw	$ra, 0($sp)
	addi	$sp, $sp, 4
	jr	$ra

waitMs:
	move	$t3, $a0			# $t3 = milliseconds to wait
	li	$v0, 30
	syscall
	move	$t2, $a0			# $t2 = start time (low 32 bits)
waitMsLoop:
	li	$v0, 30
	syscall
	subu	$t1, $a0, $t2			# Elapsed time
	blt	$t1, $t3, waitMsLoop
	jr	$ra

playSound:
	li	$t9, SOUND_ENABLED
	beqz	$t9, playSoundDone
	li	$a0, 90				# Pitch
	li	$a1, 750			# Duration (in ms)
	li	$a2, 13				# Instrument
	li	$a3, 127			# Volume
	li	$v0, 31
	syscall
playSoundDone:
	jr	$ra
