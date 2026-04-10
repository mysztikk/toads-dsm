/*
 * curiousity.s - Random file for random stuff.
 * (C) 2026 Amethyst Crenshaw.
 */

/* Half broke but it told me what I needed to know. */

.include "std-sym.s"

.section .text

.globl _start
_start:
	movq	$ptr, %rdi
	call	print

	movq	$ptr, %rdi
	addq	$18, %rdi
	movq	(%rdi), %rdi
	call	print

	movq	$SYS_EXIT, %rax
	movq	$EXIT_SUCCESS, %rdi
	syscall


.section .data

ptr:
	.asciz "Data at pointer.\n"

ptr_indirect:
	.quad	ptr
