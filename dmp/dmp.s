/*
 * dmp.s - Dump sections of binary in a file.
 *
 * v1 - 03-14-2026
 *
 * (C) 2026 Amethyst Crenshaw.
 * Licensed under the MIT License. See LICENSE.
 */

/*
 * dmp -f [file] -s [address]:[offset] -n [num]
 *
 * -f [file]: Specify a file to dump it's binary.
 *
 * -s [address]:[offset]: Specify the starting position & it's offset. Both
 * address or offset can be decimal or hexadecimal, specify hexadecimal with a
 * `0x` prefix.
 *
 * -n [num]: Specify the number of bytes to dump. Can be hexadecimal,
 * specify with a `0x` prefix.
 */

/*
 * BIG OL' LIST OF TODOS (in list of importance):
 * Clean up the code base, proper stack usage, tighter algs, better seperation,
 * consistency, and better comments. Clean up the libraries as well.
 * Assess the software. Retrospect on all development decisions made that were
 * regretable, how may they have been avoided? What are some things you learnt
 * or realized? Compile a list of all the questionable points, and try to
 * resolve them.
 */

.include "std-sym.s"
.include "parse-cmd-line-sym.s"

.section .text

.globl _start
_start:
	call	parse_cmd_line
	cmpq	$FALSE, %rax
	je	print_usage
	movq	%rax, cmd_line_ptr

main:
	/* Check if the file exists */
	movq	$SYS_OPEN, %rax
	movq	cmd_line_ptr, %r14
	movq	FILE_PATH_STR_PTR_CMD_LINE(%r14), %rdi
	movq	$O_RDONLY, %rsi
	xorq	%rdx, %rdx
	syscall
	test	%rax, %rax
	js	open_failed
	movq	%rax, fd

	/* Check if there's bytes to read */
	movl	NUM_BYTES_READ_CMD_LINE(%r14), %esi
	test	%esi, %esi
	jz	exit
	/* Make sure the input isn't insane. */
	cmpl	$0xFFFF, %esi
	jg	really

	/* Get the file size */
	movq	$SYS_LSEEK, %rax
	movq	$0, %rsi
	movq	fd, %rdi
	movq	$SEEK_END, %rdx
	syscall
	test	%rax, %rax
	js	open_failed

	/* Cap NUM_BYTES_READ to file size */
	xorq	%rsi, %rsi
	movl	NUM_BYTES_READ_CMD_LINE(%r14), %esi
	cmpq	%rax, %rsi
	jl	skip_trunc
	movl	%eax, NUM_BYTES_READ_CMD_LINE(%r14)
	
skip_trunc:
	/* Check if we need to offset. */
	xorq	%rsi, %rsi
	movl	ADDR_CMD_LINE(%r14), %esi

	/* Offset the file. */
	movq	$SYS_LSEEK, %rax
	movq	fd, %rdi
	movq	$SEEK_SET, %rdx
	syscall
	test	%rax, %rax
	js 	open_failed

seek_done:
	/* Get current breakpoint. */
	movq	$SYS_BRK, %rax
	movq	$0, %rdi
	syscall
	movq	%rax, mem_ptr

	/* Allocate memory for the file. */
	movq	$SYS_BRK, %rax
	movq	mem_ptr, %rdi
	xorq	%rdx, %rdx
	movl	NUM_BYTES_READ_CMD_LINE(%r14), %edx
	addq	%rdx, %rdi
	syscall
	cmpq	mem_ptr, %rax
	jle	open_failed

	/* Read the bytes. */
	movq	$SYS_READ, %rax
	movq	fd, %rdi
	movq	mem_ptr, %rsi
	syscall
	test	%rax, %rax
	js	open_failed

	/* Get the output string size. */
	xorq	%rdx, %rdx
	xorq	%rax, %rax
	movl	NUM_BYTES_READ_CMD_LINE(%r14), %eax
	movq	$16, %rbx /* Output 16 bytes per line */
	divq	%rbx
	cmpq	$0, %rdx /* If we have any extra bytes... */
	je	cont

	/* Get extra line size */
	pushq	%rax
	movq	%rdx, %rax
	movq	$3, %rbx /* Three bytes ("00 ") per byte. */
	mulq	%rbx
	movq	%rax, %rdx
	popq	%rax
	addq	$15, %rdx /* Add the max offset string ("$00000000: ") size,
			   * AND the extra newlines and zero terminator used. */

cont:
	/* Get full size */
	movq	$59, %rbx /* How large a line can be at maximum */
	mulq	%rbx
	addq	%rdx, %rax
	pushq	%rax /* Store the size. */

	/* Allocate */
	movq	$SYS_BRK, %rax
	movq	$0, %rdi
	syscall
	movq	%rax, alloc_ptr
	pushq	%rax /* Store the current break */
	movq	8(%rsp), %rbx
	addq	%rbx, (%rsp) /* Desired break is current + bytes */
	movq	$SYS_BRK, %rax
	movq	(%rsp), %rdi
	syscall

	/* Verify */
	cmpq	(%rsp), %rax
	jl	alloc_failed

	/* Load... Holy complex */
	addq	$8, %rsp /* Point to previous brk address*/
	movq	alloc_ptr, %r15 /* brk mem index */
	xorq	%r14, %r14 /* mmap mem index */
	movq	mem_ptr, %r13
	movq	cmd_line_ptr, %r12
	movq	$16, %rbx

	movb	$'\n', (%r15) /* Begin! */
	addq	$1, %r15
loop:
	/* Find if we need to do anything special */
	xorq	%rdx, %rdx 
	movq	%r14, %rax
	divq	%rbx
	cmpq	$0, %rdx
	je	special_offset
	cmpq	$15, %rdx
	je	special_newline

norm:
	/* Add a byte to the string */
	call	get_byte
	addq	$1, %r15
	cmpb	$0, (%r15)
	jne	skip

	subq	$1, %r15
	movb	(%r15), %r9b
	movb	$'0', (%r15)
	addq	$1, %r15
	movb	%r9b, (%r15) 

skip:
	addq	$1, %r15
	movb	$' ', (%r15)
	addq	$1, %r15
	addq	$1, %r14
	cmpq	NUM_BYTES_READ_CMD_LINE(%r12), %r14
	je	exit_loop
	jmp	loop

special_offset:
	movb	$'$', (%r15)
	addq	$1, %r15

	xorq	%rdi, %rdi
	movl	OFF_CMD_LINE(%r12), %edi
	movq	$16, %rsi
	movq	%r15, %rdx
	movq	$9, %rcx
	call	int_to_str

	cmpq	$9, %rax
	je	fin_off

	/* Move the digits to the end */
	movq	%r15, %r10
	addq	$9, %r10
	subq	%rax, %r10
	movq	(%r15), %r11
	movq	%r11, (%r10)

mini_loop:
	/* Fill the rest with zeros */
	subq	$1, %r10
	cmpq	%r10, %r15
	jg	fin_off
	movb	$'0', (%r10)
	jmp	mini_loop

fin_off:
	addq	$8, %r15
	movw	$0x203A, (%r15) /* ": " */
	addq	$2, %r15
	addl	$0x10, OFF_CMD_LINE(%r12)
	jmp	norm /* Complete with norm */

special_newline:	
	call	get_byte
	addq	$1, %r15
	cmpb	$0, (%r15)
	jne	skip_2

	subq	$1, %r15
	movb	(%r15), %r9b
	movb	$'0', (%r15)
	addq	$1, %r15
	movb	%r9b, (%r15) 

skip_2:
	addq	$1, %r15
	movb	$'\n', (%r15)
	addq	$1, %r15
	addq	$1, %r14
	cmpq	NUM_BYTES_READ_CMD_LINE(%r12), %r14
	je	exit_loop
	jmp	loop

/* Special little subroutine */
get_byte:
	xorq	%rdi, %rdi
	movb	(%r13, %r14), %dil
	movq	$16, %rsi
	movq	%r15, %rdx
	movq	$3, %rcx
	call	int_to_str
	ret

exit_loop:
	subq	$1, %r15 /* Overwrite any extra newline/space */
	movl	$0x00000A0A, (%r15) /* "\n\n\0\0" */

	movq	alloc_ptr, %rdi
	call	print

	/* Clean up. */
	movq	$SYS_BRK, %rax
	movq	alloc_ptr, %rdi
	syscall

	/* TODO: Verify this is a proper stack clean (it's probs not) */
	addq	$8, %rsp

	movq	$SYS_CLOSE, %rax
	movq	fd, %rdi
	syscall

exit:
	movq	$EXIT_SUCCESS, %rdi
	movq	$SYS_EXIT, %rax
	syscall

exit_bad:
	movq	$EXIT_FAILURE, %rdi
	movq	$SYS_EXIT, %rax
	syscall

really:
	/* Kind of a hack, but come on. Really? */
	movq	$really_str, %rdi
	call	print
	jmp	exit

print_usage:
	movq	$usage_str, %rdi
	call	print
	jmp	exit

open_failed:
	movq	$failed_to_open_str_1, %rdi
	call	print
	movq	cmd_line_ptr, %rdi
	movq	FILE_PATH_STR_PTR_CMD_LINE(%rdi), %rdi
	call	print
	movq	$failed_to_open_str_2, %rdi
	call 	print
	jmp	exit_bad

mmap_failed:
	movq	$failed_to_mmap_str, %rdi
	call	print
	jmp	exit_bad

alloc_failed:
	movq	$failed_to_alloc_str, %rdi
	call	print
	jmp	exit_bad

.section .rodata

really_str:
	.ascii "\ndmp: Number of bytes to read is out of range. You aren't reading more than 65\n"
	.asciz "thousand bytes.\n\n"

failed_to_open_str_1:
	.asciz "\ndmp: The provided file:\n\n"
failed_to_open_str_2:
	.ascii "\n\n...was not found or some other error occured.\n"
	.ascii "Please ensure that the file exists, and is readable by this\n"
	.asciz "program.\n\n"

failed_to_mmap_str:
	.ascii "\ndmp: A significant error occured and the program could not\n"
	.asciz "continue. Error: mmap failure.\n\n"

failed_to_alloc_str:
	.ascii "\ndmp: A significant error occured and the program could not\n"
	.asciz "continue. Error: allocation failure.\n\n"

usage_str:
	.ascii "\nUsage:\n"
	.ascii "dmp -f [file] -s [address]:[offset] -n [num]\n\n"
	.ascii "-f [file]: Specify a file to dump it's binary.\n\n"
	.ascii "-s [address]:[offset]: Specify the starting position & it's\n"
        .ascii "offset. Both address or offset can be decimal or hexadecimal,\n"
	.ascii "specify hexadecimal with a `0x` prefix.\n\n"
 	.ascii "-n [num]: Specify the number of bytes to dump. Can be\n"
	.asciz "hexadecimal, specify with a `0x` prefix.\n\n"

.section .bss

.lcomm str, 65
.lcomm cmd_line_ptr, 8
.lcomm fd, 8
.lcomm mem_ptr, 8
.lcomm alloc_ptr, 8
