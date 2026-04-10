/*
 * str-test-2 - Test common string functions. (2)
 *
 * (C) 2026 Amethyst Crenshaw.
 * Licensed under the MIT License. See LICENSE.
 */

.include "std-sym.s"

.section .text

.globl _start
_start:
	movq	$16, %rdi
	movq	$16, %rsi
	movq	$twothirtyfour, %rdx
	movq	$8, %rcx
	call	int_to_str

	movq	$twothirtyfour, %rdi
	call	print

	movq	$0, %rdi
	movq	$SYS_EXIT, %rax
	syscall

.section .data

debug_str:
	.asciz "DEBUG\n"

.section .bss

.lcomm twothirtyfour, 8
