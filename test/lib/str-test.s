/*
 * str-test - Test common string functions.
 *
 * (C) 2026 Amethyst Crenshaw.
 * Licensed under the MIT License. See LICENSE.
 */

.include "std-sym.s"

.section .text

.globl _start
_start:
	movq	$test_str_1, %rdi
	call	print

	movq	$test_str_2, %rdi
	call	print

	movq	$test_str_3, %rdi
	call	print

	movq	$test_str_4, %rdi
	call	print

	movq	$test_str_1, %rdi
	movq	$test_str_6, %rsi
	call	cmp_str
	cmpq	$1, %rax
	je	print_true_1

print_false_1:
	movq	$false_str, %rdi
	call	print
	jmp	second

print_true_1:
	movq	$true_str, %rdi
	call	print

second:
	movq	$test_str_1, %rdi
	movq	$test_str_5, %rsi
	call	cmp_str
	cmpq	$1, %rax
	je	print_true_2

print_false_2:
	movq	$false_str, %rdi
	call	print
	jmp	exit

print_true_2:
	movq	$true_str, %rdi
	call	print

exit:
	movq	$EXIT_SUCCESS, %rdi
	movq	$SYS_EXIT, %rax
	syscall

.section .data

test_str_1:
	.asciz "Hello, there!\n"

test_str_2:
	.asciz "e\n"

test_str_3:
	.asciz "summalummauassuminimahumanwhatigottadotoprovetouimsuperhumaninnovativeandimmadeofrubbersothatanythingyousayisrichocheitngoffofmeanditllgluetouimneverstatingmorethaneverdemonstratinghowtomakeamffeellikeheslevitatingcuziknowthehatersareforeverwaitingkljsljflksjdflkjslkdjflkjsdklfjskldfjklsjdfkljsdfkljskldjfklsjdfkljdsklreallyreallyreallyreallyreallyreallyreallylongstring\n"

test_str_4:
	.asciz "\t\n\n\n\nsf\dn\\nts\n\tsn\tn\sn\t\stn\snt\ns\tn\nst\ns\tn\st\ns\tn\snt\nst\ns\tn\snt\n"
test_str_5:
	.asciz "Hello, world!\n"

test_str_6:
	.asciz "Hello, there!\n"

false_str:
	.asciz "FALSE!\n"

true_str:
	.asciz "TRUE!\n"
