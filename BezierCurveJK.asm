										#  drawing a Bezier curve in BMP file   #
										#        [ARKO] Laboratorium		#
										#          Jakub Kowalczyk	        #         
#README
#Program written in MIPS assembly language. Its purpose is to create bezier curve in a bmp file.
#bmp file width/height should be in (0, 1023) range as higher might not be working. The file has to be 24 bit depth and carry a name "img.bmp"
#X and Y coordinates which will be set by user should be in (-16,16) range to ensure proper drawing. It is because of image scaling.




						                           
	                    .data
temp_buffer:                .space 20
header:		 	    .space 54
filename_in:                .asciiz "img.bmp"
filename_out:		    .asciiz "imgout.bmp"
opening_file_str:           .ascii  "Opening and reading a file.\n"
			    .asciiz "It can take a while...\n...\n"
input_str:		    .ascii  "Loading file complete\n"
			    .ascii  "Now enter 6 numbers which will become coordinates for 3 points, their optimal range is (-16,16).\n"
			    .asciiz "The order is P1(x,y), P2(x,y) P3(x,y), remember to write them separately.\n"
fail_during_opening_str:    .asciiz "Failed to open a file. Is the name of it correct?\n"
fail_during_reading_str:    .asciiz "Failed to properly read a file. Is it a bmp file?\n"
	    		    .text
	    		
	    		#--------------------------------------------------------------------------#
	    				#Used registers#
	    				#s0 = Width
	    				#s1 = Height
	    				#s2 = Size of the bitmap data
	    				#s3 = address to alocated memory of pixel array
	    				#s4 = padding
	    				#s5 = Xscale
	    				#s6 = Yscale
	    				#s7 = file descriptor / #s7 = address to the (0.0) point
			#--------------------------------------------------------------------------#

openingFile:
	li $v0, 4
	la $a0, opening_file_str
	syscall
	
	li $v0, 13
	la $a0, filename_in
	li $a1, 0 			# flags (0=read, 1=write)
	li $a2, 0			# mode = unnecessary
	syscall				#v0 contains file descriptor
	blt $v0, $zero, fail_during_opening
	la $s7, ($v0)			#in s7 descriptor will be stored
	la $a0, ($s7)			#a0 needs to indicate descriptor for file reading
	
readingFile:
	#BMP Header (not needed)
	li $v0, 14
	la $a1, temp_buffer       	#address to the space where we will temporary store information read		
	li $a2, 18			#number of characters to read	
	syscall				#read from file
	blt $v0, $zero, fail_during_reading
	
	#Width and Height of the bitmap
	li $v0, 14
	li $a2, 8
	syscall
	lw $s0, temp_buffer		#s0 = Width
	lw $s1, temp_buffer+4		#s1 = Height
	
	#Color planes/bits per pixel/compression (not needed)
	li $v0, 14
	li $a2, 8
	syscall
	
	#Size of the raw bitmap data (including padding)
	li $v0, 14
	li $a2, 4
	syscall
	lw $s2, temp_buffer		#saving size of bitmap in s2
	
	#allocating memory for bitmap data
	li $v0, 9
	la $a0, ($s2)			#s2 tells us how much memory to allocate
	syscall
	la $s3, ($v0)			#s3 = address to alocated memory
	
	#reading rest of the DIB header (not needed)
	li $v0, 14
	la $a0, ($s7)			#descriptor
	li $a2, 16
	syscall
	
	#reading and saving pixel array
	li $v0, 14
	la $a1, ($s3)			#pointer to allocated memory
	la $a2, ($s2)			#how much to read
	syscall
	
	#closing the file
	li $v0, 16
	syscall
	
	#reopening the file to store whole header
	li $v0, 13
	la $a0, filename_in
	li $a1, 0 			
	li $a2, 0			
	syscall
	la $a0, ($v0)
	
	li $v0, 14
	la $a1, header	
	li $a2, 54			
	syscall
	
	#closing the file definitely
	li $v0, 16
	syscall
	
						
	#calculating padding
	mulo  $t0, $s1, 3		#t0 = width * 3 (cause we use 3 bytes for pixel)
	andi $t0, $t0, 0x3		#t0 = t0%4
	la   $s4, 0			#s4 will store padding value
	beqz $t0, assemblingWorkspace	#move forward if padding = 0
	li   $t1, 4
	sub  $s4, $t1, $t0		#s4 = 4 - padding
	
		
assemblingWorkspace:												
	#creating Y axis
	li   $t0, 0			#t0 = iterator = 0	
	srl  $t1, $s0, 1		#t1 = width / 2		
	mulo $t1, $t1, 3		#t1 = t1 * 3 (cause pixel has 3 bytes)
	addu $t1, $t1, $s3		#t1 = pointer to the middle of first row
	mulo $t2, $s0, 3		
	addu $t2, $t2, $s4		#t2 = width * 3 + padding (how much bytes in one row)
											
createY:
	sb $zero, ($t1)
	sb $zero, 1($t1)		#couloring pixels black
	sb $zero, 2($t1)
	addiu $t0, $t0, 1		#incrementing iterator
	addu $t1, $t1, $t2		#moving pointer to the middle of next row
	blt $t0, $s1, createY		#loop if iterator < height
	
	
	#creating X axis
	li   $t0, 0			#t0 = iterator = 0
	srl  $t1, $s1, 1		#t1 = height / 2
	mulo $t1, $t1, $t2		#t1 = height/2 * number of bytes in a row
	addu $t1, $t1, $s3		#t1 = pointer to the middle of first column
											
createX:
	sb $zero, ($t1)
	sb $zero, 1($t1)		#couloring pixels black
	sb $zero, 2($t1)
	addiu $t0, $t0, 1		#incrementing iterator
	addiu $t1, $t1, 3		#moving pointer to the right
	blt $t0, $s0, createX		#loop if iterator < width
	
	#calculate scale
	srl $s5, $s0, 5			#s5 = Xscale = width/32
	srl $s6, $s1, 5			#s6 = Yscale = height/32
	
	#find (0.0) point
	srl  $t1, $s0, 1		#t1 = width / 2
	mulo $t1, $t1, 3		
	addu $t1, $t1, $s3		#t1 = pointer to the middle of first row
	mulo $t2, $s0, 3		
	addu $t2, $t2, $s4		#t2 = width * 3 + padding (how much bytes in one row)
	srl  $t3, $s1, 1		#t3 = height / 2
	mulo $t2, $t2, $t3		#we have the number of bytes which we have to pass going to (0.0) point)
	addu $s7, $t1, $t2		#s7 = (0.0)
	
	
cin:
	li $v0,4
	la $a0, input_str
	syscall
	
	li $v0,5
	syscall				#1. coord
	la $t4, ($v0)
	
	li $v0,5
	syscall				#2. coord 
	la $t5, ($v0)
	
	li $v0,5
	syscall				#3. coord
	la $t6, ($v0)	
				
	li $v0,5
	syscall				#4. coord
	la $t7, ($v0)	
	
	li $v0,5
	syscall				#5. coord
	la $t8, ($v0)
	
	li $v0,5
	syscall				#6. coord 
	la $t9, ($v0)
	



					#I assumed here a fixed point number with 12 bit integer and 20 bit fraction
					#It is because I will calculate 1024 points so my "t" consumes 10 bits for fraction, but because it is t^2 we need actually 20 bits there.
					#12 integer bits were needed for (1024 width-height / 32[scale]) and x/y which is in range (-16,16). Total of 11 bits is required (one for sign)
					
					
					
					
	#Iterators for creatingBezier
	li $t0, 0x00000000 		#t0 = 2^-10 (iterator)
	li $t1, 0x00100000		#t1 = 1-iterator
	la $fp, 0($sp)			#initializing stack
	
creatingBezier:				#B(t) = ( (1-t)^2 * P0 + 2 * t * (1-t) * P1 + t^2 * P2 ) * width/32 or height/32
	#Calculating X coord
	srl $t2, $t1, 10
	mul $t2, $t2, $t2		#t2 = (1-t)^2
	mul $t2, $t2, $t4      		 #t2 = (1-t)^2 * x0
	
	
	srl $a0, $t0, 10
	srl $t3, $t1, 10 
	mul $t3, $a0, $t3		#t3 = t*(1-t)
	mul $t3, $t3, $t6		#t3= t*(1-t) * x1
	sll $t3, $t3, 1
	
	add $t2, $t2, $t3		#t2 = (t^2) * x0 + t*(1-t) * x1
	
	srl $t3, $t0, 10
	mul $t3, $t3, $t3
	mul $t3, $t3, $t8		#t3 = t^2 * x2
	
	add $t2, $t2, $t3		#t2 = t^2 * x0 + t*(1-t) * x1 + t^2 * x2	
	
	mul $t2, $t2, $s5		#t2 * width/32 ---> t2 = complete X coord
	

	addiu $sp, $sp, -4		#storing in stack because I run out of "t" registers
	sw $t2, 0($sp)
	
	#Calculating Y coord
	srl $t2, $t1, 10
	mul $t2, $t2, $t2		#t2 = (1-t)^2
	mul $t2, $t2, $t5      		#t2 = (1-t)^2 * y0
	
	srl $a0, $t0, 10
	srl $t3, $t1, 10
	mul $t3, $a0, $t3		#t3 = t*(1-t)
	mul $t3, $t3, $t7		#t3= t*(1-t) * x1
	sll $t3, $t3, 1
	
	add $t2, $t2, $t3		#t2 = t^2 * y0 + t*(1-t) * y1
	
	srl $t3, $t0, 10
	mul $t3, $t3, $t3
	mul $t3, $t3, $t9		#t3 = t^2 * y2
	
	add $t2, $t2, $t3		#t2 = t^2 * y0 + t*(1-t) * y1 + t^2 * y2
	mul $t2, $t2, $s6		#t2 * height/32 --->t2 = complete Y coord
		
	
	addiu $sp, $sp, -4
	sw $t2, 0($sp)	
	la $a0, ($zero)			 #clearing a0 register which I used in calculations
	
	#painting a pixel
	lw $t3, -8($fp)			#t3 = Y coord
	addiu $sp, $sp, 4
	sra $t3, $t3, 20		#removing fraction of the coordinate				
	mul $t2, $s0, 3		
	addu $t2, $t2, $s4		#t2 = width * 3 + padding (how much bytes in one row)
	mul $t2, $t2, $t3
	add $t2, $t2, $s7		#t2 = address in Pixel array where indicates Y
	
	
	lw $t3, -4($fp)			#t3 = X coord
	addiu $sp, $sp, 4
	sra $t3, $t3, 20
	mul $t3, $t3, 3			#t3 = x * 3bytes per pixel
	add $t2, $t2, $t3		#t2 = address of Pixel to color
	sb $zero, ($t2)
	sb $zero, 1($t2)		#couloring pixels black
	sb $zero, 2($t2)
	
	#condition
	addiu $t0, $t0, 1024 		# iterator +=1     1024==0x00000400
	addiu $t1, $t1, -1024
	blt $t0, 0x00100000, creatingBezier #loop


	#opening output file
	li $v0, 13
	la $a0, filename_out
	li $a1, 1			# writing flag
	li $a2, 0		
	syscall
	la $a0, ($v0)
	
	#storing file header
	li $v0, 15			# syscall for writing to file
	la $a1, header			# loading address of the header
	li $a2, 54			# how much bites to write
	syscall
	
	#storing pixel array
	li $v0, 15
	la $a1, ($s3)			# memory address of processed data
	la $a2, ($s2)			# size of the memory
	syscall


exit:
	li $v0, 10 
	syscall


						#ERRORS
fail_during_opening:
	li $v0, 4
 	la $a0, fail_during_opening_str
 	syscall
	j exit
 
fail_during_reading:
	li $v0, 4
	la $a0, fail_during_reading_str
	syscall
	j exit

