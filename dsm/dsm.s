/*
 * dsm.s - Disassemble 6502 machine code from file.
 *
 * v1 - N/A
 *
 * (C) 2026 Amethyst Crenshaw.
 * Licensed under the MIT License. See LICENSE.
 */

/*
 * dsm -f [file] -s [address]:[offset] -n [num]
 *
 * -f [file]: Specify a file to disassemble.
 *
 * -s [address]:[offset]: Specify the starting position & it's offset. Both
 * address or offset can be decimal or hexadecimal, specify hexadecimal with a
 * `0x` prefix.
 *
 * -n [num]: Specify the number of bytes to disassemble. Can be hexadecimal,
 * specify with a `0x` prefix.
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
	movq	cmd_line_ptr, %r15 /* Prepare to use the pointer throughout. */

	/* Open file. */
	movq	$SYS_OPEN, %rax
	movq	FILE_PATH_STR_PTR_CMD_LINE(%r15), %rdi
	movq	$O_RDONLY, %rsi
	xorq	%rdx, %rdx
	syscall
	test	%rax, %rax
	js	open_failed
	movq	%rax, fd

	/* Get size of file. */
	movq	$SYS_LSEEK, %rax
	movq	fd, %rdi
	xorq	%rsi, %rsi
	movq	$SEEK_END, %rdx
	syscall
	test	%rax, %rax
	js	open_failed
	movq	%rax, file_size

	/* Clamp NUM_BYTES_READ to file size. */
	movl	NUM_BYTES_READ_CMD_LINE(%r15), %ebx
	cmpq	%rax, %rbx
	jge	after_clamp
	movl	%eax, NUM_BYTES_READ_CMD_LINE(%r15)

after_clamp:
	/* Set offset. */
	movq	$SYS_LSEEK, %rax
	movq	fd, %rdi
	movq	ADDR_CMD_LINE(%r15), %rsi
	movq	$SEEK_SET, %rdx
	syscall
	test	%rax, %rax
	js	open_failed

	/* Get the base break. */
	movq	$SYS_BRK, %rax
	xorq	%rdi, %rdi
	syscall
	movq	%rax, base_brk

	/* Allocate file & string buffers. */
	movq	$SYS_BRK, %rax
	movq	base_brk, %rdi
	addq	$0x19000, %rdi /* 100KiB */
	syscall
	cmpq	%rax, %rdi
	jl	alloc_failed

	/* Get string allocation pointer. */
	movq	base_brk, %rdi
	addq	$0x6400, %rdi /* 25KiB */
	movq	%rdi, str_alloc_ptr

	/* Prep values. */
	movl	OFF_CMD_LINE(%r15), %r12d
	movl	NUM_BYTES_READ_CMD_LINE(%r15), %r11d

main_loop:
	/* If there are no bytes left, exit the program. */
	test	%r11d, %r11d
	jz	clean

	/* Seek file. */
	movq	$SYS_LSEEK, %rax
	movq	fd, %rdi
	movl	OFF_CMD_LINE(%r15), %esi
	subl	%r12d, %esi
	movq	$SEEK_SET, %rdx
	syscall
	test	%rax, %rax
	js	main_read_failed

	/* Reset working pointers. */
	movq	base_brk, %r13
	movq	str_alloc_ptr, %r14

	/* Load amount of file to iterate over. */
	movl	$0x6400, %edx
	cmpl	$0x6400, %r11d
	jge	load
	movl	%r11d, %edx
load:
	movq	$SYS_READ, %rax
	movq	fd, %rdi
	movq	base_brk, %rsi
	syscall
	test	%rax, %rax
	js	main_read_failed

internal_loop:
	/* Get the 6502 mnemonic & addressing mode handler. */
	xorq	%rax, %rax
	movb	(%r13), %al
	xorq	%rdx, %rdx
	movq	$12, %rbx /* Offset for mnemonic */
	mulq	%rbx
	addq	$opcode_table, %rax /* Get the mnemonic by adding the address of
				       the opcode table. */
	movq	%rax, %rdi /* Mnemonic is a parameter */
	addq	$4, %rax /* Pointer to handler */
	/*movq	(%rax), %rax*/

	/* Call the handler.
	call	abs_handler
	test	%rax, %rax
	jnz	internal_loop
	*/

	jmp	clean

	/* If there was a failure. */
	movb	$0, (%r14)
	movq	str_alloc_ptr, %rdi
	call	print
	jmp	main_loop

/* The handlers print everything to the text buffer, including the offset, and
 * should increment the pointers and offset, and should subtract from working
 * NUM_BYTES_READ. Return 1 on success, zero on failure.  */

clean:
	/* Close file. */
	movq	$SYS_CLOSE, %rax
	movq	fd, %rdi
	syscall

	/* Clean up allocation. */
	movq	$SYS_BRK, %rax
	movq	base_brk, %rdi
	syscall

exit:
	movq	$EXIT_SUCCESS, %rdi
	movq	$SYS_EXIT, %rax
	syscall

exit_bad:
	movq	$EXIT_FAILURE, %rdi
	movq	$SYS_EXIT, %rax
	syscall

print_usage:
	movq	$usage_str, %rdi
	call	print
	jmp	exit

open_failed:
	movq	$open_fail_str_1, %rdi
	call	print
	movq	FILE_PATH_STR_PTR_CMD_LINE(%r15), %rdi
	call	print
	movq	$open_fail_str_2, %rdi
	call	print
	jmp	exit_bad

alloc_failed:
	movq	$alloc_fail_str, %rdi
	call	print
	jmp	exit_bad

main_read_failed:
	movq	$main_read_fail_str, %rdi
	call	print
	jmp	exit_bad

/* function docs here */
a_handler:
	movq	str_alloc_ptr, %rcx
	addq	$0x12BFF, %rcx
	cmpq	%r14, %rcx
	jge 	a_handler_fail
	test	%r11, %r11
	jz	a_handler_fail

/* If we have room. */
	addq	$1, %r13
	addq	$1, %r14
	addl	$1, %r12d
	subl	$1, %r11d
	call	print
	movq	$a_handler_str, %rdi
	call	print
	movq	$1, %rax
	ret

/* If we don't. */
a_handler_fail:
	xorq	%rax, %rax
	ret

abs_handler:
	jmp	clean
	movq	str_alloc_ptr, %rcx
	addq	$0x12BFF, %rcx
	cmpq	%r14, %rcx
	jge	abs_handler_fail
	test	%r11, %r11
	jz	abs_handler_fail

/* If we have room. */
	addq	$1, %r13
	addq	$1, %r14
	addl	$1, %r12d
	subl	$1, %r11d
	call	print
	movq	$abs_handler_str, %rdi
	call	print
	movq	$1, %rax
	ret

/* If we don't. */
abs_handler_fail:
	xorq	%rax, %rax
	ret

abs_x_handler:
	movq	str_alloc_ptr, %rcx
	addq	$0x12BFF, %rcx
	cmpq	%r14, %rcx
	jge	abs_x_handler_fail
	test	%r11, %r11
	jz	abs_x_handler_fail

/* If we have room. */
	addq	$1, %r13
	addq	$1, %r14
	addl	$1, %r12d
	subl	$1, %r11d
	call	print
	movq	$abs_x_handler_str, %rdi
	call	print
	movq	$1, %rax
	ret

/* If we don't. */
abs_x_handler_fail:
	xorq	%rax, %rax
	ret

abs_y_handler:
	movq	str_alloc_ptr, %rcx
	addq	$0x12BFF, %rcx
	cmpq	%r14, %rcx
	jge	abs_y_handler_fail
	test	%r11, %r11
	jz	abs_y_handler_fail

/* If we have room. */
	addq	$1, %r13
	addq	$1, %r14
	addl	$1, %r12d
	subl	$1, %r11d
	call	print
	movq	$abs_y_handler_str, %rdi
	call	print
	movq	$1, %rax
	ret

/* If we don't. */
abs_y_handler_fail:
	xorq	%rax, %rax
	ret

imm_handler:
	movq	str_alloc_ptr, %rcx
	addq	$0x12BFF, %rcx
	cmpq	%r14, %rcx
	jge	imm_handler_fail
	test	%r11, %r11
	jz	imm_handler_fail

/* If we have room. */
	addq	$1, %r13
	addq	$1, %r14
	addl	$1, %r12d
	subl	$1, %r11d
	call	print
	movq	$imm_handler_str, %rdi
	call	print
	movq	$1, %rax
	ret

/* If we don't. */
imm_handler_fail:
	xorq	%rax, %rax
	ret

impl_handler:
	movq	str_alloc_ptr, %rcx
	addq	$0x12BFF, %rcx
	cmpq	%r14, %rcx
	jge	impl_handler_fail
	test	%r11, %r11
	jz	impl_handler_fail

/* If we have room. */
	addq	$1, %r13
	addq	$1, %r14
	addl	$1, %r12d
	subl	$1, %r11d
	call	print
	movq	$impl_handler_str, %rdi
	call	print
	movq	$1, %rax
	ret

/* If we don't. */
impl_handler_fail:
	xorq	%rax, %rax
	ret

ind_handler:
	movq	str_alloc_ptr, %rcx
	addq	$0x12BFF, %rcx
	cmpq	%r14, %rcx
	jge	ind_handler_fail
	test	%r11, %r11
	jz	ind_handler_fail

/* If we have room. */
	addq	$1, %r13
	addq	$1, %r14
	addl	$1, %r12d
	subl	$1, %r11d
	call	print
	movq	$ind_handler_str, %rdi
	call	print
	movq	$1, %rax
	ret

/* If we don't. */
ind_handler_fail:
	xorq	%rax, %rax
	ret

ind_x_handler:
	movq	str_alloc_ptr, %rcx
	addq	$0x12BFF, %rcx
	cmpq	%r14, %rcx
	jge	ind_x_handler_fail
	test	%r11, %r11
	jz	ind_x_handler_fail

/* If we have room. */
	addq	$1, %r13
	addq	$1, %r14
	addl	$1, %r12d
	subl	$1, %r11d
	call	print
	movq	$ind_x_handler_str, %rdi
	call	print
	movq	$1, %rax
	ret

/* If we don't. */
ind_x_handler_fail:
	xorq	%rax, %rax
	ret

ind_y_handler:
	movq	str_alloc_ptr, %rcx
	addq	$0x12BFF, %rcx
	cmpq	%r14, %rcx
	jge	ind_y_handler_fail
	test	%r11, %r11
	jz	ind_y_handler_fail

/* If we have room. */
	addq	$1, %r13
	addq	$1, %r14
	addl	$1, %r12d
	subl	$1, %r11d
	call	print
	movq	$ind_y_handler_str, %rdi
	call	print
	movq	$1, %rax
	ret

/* If we don't. */
ind_y_handler_fail:
	xorq	%rax, %rax
	ret

jam_handler:
	movq	str_alloc_ptr, %rcx
	addq	$0x12BFF, %rcx
	cmpq	%r14, %rcx
	jge	jam_handler_fail
	test	%r11, %r11
	jz	jam_handler_fail

/* If we have room. */
	addq	$1, %r13
	addq	$1, %r14
	addl	$1, %r12d
	subl	$1, %r11d
	call	print
	movq	$jam_handler_str, %rdi
	call	print
	movq	$1, %rax
	ret

/* If we don't. */
jam_handler_fail:
	xorq	%rax, %rax
	ret

rel_handler:
	movq	str_alloc_ptr, %rcx
	addq	$0x12BFF, %rcx
	cmpq	%r14, %rcx
	jge	rel_handler_fail
	test	%r11, %r11
	jz	rel_handler_fail

/* If we have room. */
	addq	$1, %r13
	addq	$1, %r14
	addl	$1, %r12d
	subl	$1, %r11d
	call	print
	movq	$rel_handler_str, %rdi
	call	print
	movq	$1, %rax
	ret

/* If we don't. */
rel_handler_fail:
	xorq	%rax, %rax
	ret

zpg_handler:
	movq	str_alloc_ptr, %rcx
	addq	$0x12BFF, %rcx
	cmpq	%r14, %rcx
	jge	zpg_handler_fail
	test	%r11, %r11
	jz	zpg_handler_fail

/* If we have room. */
	addq	$1, %r13
	addq	$1, %r14
	addl	$1, %r12d
	subl	$1, %r11d
	call	print
	movq	$zpg_handler_str, %rdi
	call	print
	movq	$1, %rax
	ret

/* If we don't. */
zpg_handler_fail:
	xorq	%rax, %rax
	ret

zpg_x_handler:
	movq	str_alloc_ptr, %rcx
	addq	$0x12BFF, %rcx
	cmpq	%r14, %rcx
	jge	zpg_x_handler_fail
	test	%r11, %r11
	jz	zpg_x_handler_fail

/* If we have room. */
	addq	$1, %r13
	addq	$1, %r14
	addl	$1, %r12d
	subl	$1, %r11d
	call	print
	movq	$zpg_x_handler_str, %rdi
	call	print
	movq	$1, %rax
	ret

/* If we don't. */
zpg_x_handler_fail:
	xorq	%rax, %rax
	ret

zpg_y_handler:
	movq	str_alloc_ptr, %rcx
	addq	$0x12BFF, %rcx
	cmpq	%r14, %rcx
	jge	zpg_y_handler_fail
	test	%r11, %r11
	jz	zpg_y_handler_fail

/* If we have room. */
	addq	$1, %r13
	addq	$1, %r14
	addl	$1, %r12d
	subl	$1, %r11d
	call	print
	movq	$zpg_y_handler_str, %rdi
	call	print
	movq	$1, %rax
	ret

/* If we don't. */
zpg_y_handler_fail:
	xorq	%rax, %rax
	ret

.section .rodata

debug_str:
	.asciz "FUCK YOUUUUUUU\n"

usage_str:
	.ascii "\nUsage:\n"
	.ascii "dsm -f [file] -s [address]:[offset] -n [num]\n\n"
	.ascii "-f [file]: Specify a file to disassemble.\n\n"
	.ascii "-s [address]:[offset]: Specify the starting position & it's\n"
        .ascii "offset. Both address or offset can be decimal or hexadecimal,\n"
	.ascii "specify hexadecimal with a `0x` prefix.\n\n"
 	.ascii "-n [num]: Specify the number of bytes to disassemble. Can be\n"
	.asciz "hexadecimal, specify with a `0x` prefix.\n\n"

open_fail_str_1:
	.asciz "\ndsm: The provided file:\n\n"
open_fail_str_2:
	.ascii "\n\n...was not found or some other error occured.\n"
	.ascii "Please ensure that the file exists, and is readable by this\n"
	.asciz "program.\n\n"

alloc_fail_str:
	.ascii "\ndsm: A significant error occured and the program could not\n"
	.asciz "continue. Error: allocation failure.\n\n"

main_read_fail_str:
	.ascii "\ndsm: A significant error occured and the program could not\n"
	.asciz "continue. Error: main runtime read failure.\n\n"

a_handler_str:
	.asciz "a_handler"

abs_handler_str:
	.asciz "abs_handler"

abs_x_handler_str:
	.asciz "abs_x_handler"

abs_y_handler_str:
	.asciz "abs_y_handler"

imm_handler_str:
	.asciz "imm_handler"

impl_handler_str:
	.asciz "impl_handler"

ind_handler_str:
	.asciz "ind_handler"

ind_x_handler_str:
	.asciz "ind_x_handler"

ind_y_handler_str:
	.asciz "ind_y_handler"

jam_handler_str:
	.asciz "jam_handler"

rel_handler_str:
	.asciz "rel_handler"

zpg_handler_str:
	.asciz "zpg_handler"

zpg_x_handler_str:
	.asciz "zpg_x_handler"

zpg_y_handler_str:
	.asciz "zpg_y_handler"

opcode_table:
	/* .asciz adds a implied fourth byte (true 0) to all except USBC, which
	   uses the .ascii directive. This aligns all the handler ptrs
	   nicely. */

	/* mnemonic = opcode × 12 */
	/* handler ptr = mnemonic + 4 */
	.asciz "BRK"         /* 00 */
	.quad impl_handler   /* 00 */
	.asciz "ORA"         /* 01 */
	.quad ind_x_handler  /* 01 */
	.asciz "JAM"         /* 02 */
	.quad jam_handler    /* 02 */
	.asciz "SLO"         /* 03 */
	.quad ind_x_handler  /* 03 */
	.asciz "NOP"         /* 04 */
	.quad zpg_handler    /* 04 */
	.asciz "ORA"         /* 05 */
	.quad zpg_handler    /* 05 */
	.asciz "ASL"         /* 06 */
	.quad zpg_handler    /* 06 */
	.asciz "SLO"         /* 07 */
	.quad zpg_handler    /* 07 */
	.asciz "PHP"         /* 08 */
	.quad impl_handler   /* 08 */
	.asciz "ORA"         /* 09 */
	.quad imm_handler    /* 09 */
	.asciz "ASL"         /* 0a */
	.quad a_handler      /* 0a */
	.asciz "ANC"         /* 0b */
	.quad imm_handler    /* 0b */
	.asciz "NOP"         /* 0c */
	.quad abs_handler    /* 0c */
	.asciz "ORA"         /* 0d */
	.quad abs_handler    /* 0d */
	.asciz "ASL"         /* 0e */
	.quad abs_handler    /* 0e */
	.asciz "SLO"         /* 0f */
	.quad abs_handler    /* 0f */
	.asciz "BPL"         /* 10 */
	.quad rel_handler    /* 10 */
	.asciz "ORA"         /* 11 */
	.quad ind_y_handler  /* 11 */
	.asciz "JAM"         /* 12 */
	.quad jam_handler    /* 12 */
	.asciz "SLO"         /* 13 */
	.quad ind_y_handler  /* 13 */
	.asciz "NOP"         /* 14 */
	.quad zpg_x_handler  /* 14 */
	.asciz "ORA"         /* 15 */
	.quad zpg_x_handler  /* 15 */
	.asciz "ASL"         /* 16 */
	.quad zpg_x_handler  /* 16 */
	.asciz "SLO"         /* 17 */
	.quad zpg_x_handler  /* 17 */
	.asciz "CLC"         /* 18 */
	.quad impl_handler   /* 18 */
	.asciz "ORA"         /* 19 */
	.quad abs_y_handler  /* 19 */
	.asciz "NOP"         /* 1a */
	.quad impl_handler   /* 1a */
	.asciz "SLO"         /* 1b */
	.quad abs_y_handler  /* 1b */
	.asciz "NOP"         /* 1c */
	.quad abs_x_handler  /* 1c */
	.asciz "ORA"         /* 1d */
	.quad abs_x_handler  /* 1d */
	.asciz "ASL"         /* 1e */
	.quad abs_x_handler  /* 1e */
	.asciz "SLO"         /* 1f */
	.quad abs_x_handler  /* 1f */
	.asciz "JSR"         /* 20 */
	.quad abs_handler    /* 20 */
	.asciz "AND"         /* 21 */
	.quad ind_x_handler  /* 21 */
	.asciz "JAM"         /* 22 */
	.quad jam_handler    /* 22 */
	.asciz "RLA"         /* 23 */
	.quad ind_x_handler  /* 23 */
	.asciz "BIT"         /* 24 */
	.quad zpg_handler    /* 24 */
	.asciz "AND"         /* 25 */
	.quad zpg_handler    /* 25 */
	.asciz "ROL"         /* 26 */
	.quad zpg_handler    /* 26 */
	.asciz "RLA"         /* 27 */
	.quad zpg_handler    /* 27 */
	.asciz "PLP"         /* 28 */
	.quad impl_handler   /* 28 */
	.asciz "AND"         /* 29 */
	.quad imm_handler    /* 29 */
	.asciz "ROL"         /* 2a */
	.quad a_handler      /* 2a */
	.asciz "ANC"         /* 2b */
	.quad imm_handler    /* 2b */
	.asciz "BIT"         /* 2c */
	.quad abs_handler    /* 2c */
	.asciz "AND"         /* 2d */
	.quad abs_handler    /* 2d */
	.asciz "ROL"         /* 2e */
	.quad abs_handler    /* 2e */
	.asciz "RLA"         /* 2f */
	.quad abs_handler    /* 2f */
	.asciz "BMI"         /* 30 */
	.quad rel_handler    /* 30 */
	.asciz "AND"         /* 31 */
	.quad ind_y_handler  /* 31 */
	.asciz "JAM"         /* 32 */
	.quad jam_handler    /* 32 */
	.asciz "RLA"         /* 33 */
	.quad ind_y_handler  /* 33 */
	.asciz "NOP"         /* 34 */
	.quad zpg_x_handler  /* 34 */
	.asciz "AND"         /* 35 */
	.quad zpg_x_handler  /* 35 */
	.asciz "ROL"         /* 36 */
	.quad zpg_x_handler  /* 36 */
	.asciz "RLA"         /* 37 */
	.quad zpg_x_handler  /* 37 */
	.asciz "SEC"         /* 38 */
	.quad impl_handler   /* 38 */
	.asciz "AND"         /* 39 */
	.quad abs_y_handler  /* 39 */
	.asciz "NOP"         /* 3a */
	.quad impl_handler   /* 3a */
	.asciz "RLA"         /* 3b */
	.quad abs_y_handler  /* 3b */
	.asciz "NOP"         /* 3c */
	.quad abs_x_handler  /* 3c */
	.asciz "AND"         /* 3d */
	.quad abs_x_handler  /* 3d */
	.asciz "ROL"         /* 3e */
	.quad abs_x_handler  /* 3e */
	.asciz "RLA"         /* 3f */
	.quad abs_x_handler  /* 3f */
	.asciz "RTI"         /* 40 */
	.quad impl_handler   /* 40 */
	.asciz "EOR"         /* 41 */
	.quad ind_x_handler  /* 41 */
	.asciz "JAM"         /* 42 */
	.quad jam_handler    /* 42 */
	.asciz "SRE"         /* 43 */
	.quad ind_x_handler  /* 43 */
	.asciz "NOP"         /* 44 */
	.quad zpg_handler    /* 44 */
	.asciz "EOR"         /* 45 */
	.quad zpg_handler    /* 45 */
	.asciz "LSR"         /* 46 */
	.quad zpg_handler    /* 46 */
	.asciz "SRE"         /* 47 */
	.quad zpg_handler    /* 47 */
	.asciz "PHA"         /* 48 */
	.quad impl_handler   /* 48 */
	.asciz "EOR"         /* 49 */
	.quad imm_handler    /* 49 */
	.asciz "LSR"         /* 4a */
	.quad a_handler      /* 4a */
	.asciz "ALR"         /* 4b */
	.quad imm_handler    /* 4b */
	.asciz "JMP"         /* 4c */
	.quad abs_handler    /* 4c */
	.asciz "EOR"         /* 4d */
	.quad abs_handler    /* 4d */
	.asciz "LSR"         /* 4e */
	.quad $abs_handler   /* 4e */
	.asciz "SRE"         /* 4f */
	.quad abs_handler    /* 4f */
	.asciz "BVC"         /* 50 */
	.quad rel_handler    /* 50 */
	.asciz "EOR"         /* 51 */
	.quad ind_y_handler  /* 51 */
	.asciz "JAM"         /* 52 */
	.quad jam_handler    /* 52 */
	.asciz "SRE"         /* 53 */
	.quad ind_y_handler  /* 53 */
	.asciz "NOP"         /* 54 */
	.quad zpg_x_handler  /* 54 */
	.asciz "EOR"         /* 55 */
	.quad zpg_x_handler  /* 55 */
	.asciz "LSR"         /* 56 */
	.quad zpg_x_handler  /* 56 */
	.asciz "SRE"         /* 57 */
	.quad zpg_x_handler  /* 57 */
	.asciz "CLI"         /* 58 */
	.quad impl_handler   /* 58 */
	.asciz "EOR"         /* 59 */
	.quad abs_y_handler  /* 59 */
	.asciz "NOP"         /* 5a */
	.quad impl_handler   /* 5a */
	.asciz "SRE"         /* 5b */
	.quad abs_y_handler  /* 5b */
	.asciz "NOP"         /* 5c */
	.quad abs_x_handler  /* 5c */
	.asciz "EOR"         /* 5d */
	.quad abs_x_handler  /* 5d */
	.asciz "LSR"         /* 5e */
	.quad abs_x_handler  /* 5e */
	.asciz "SRE"         /* 5f */
	.quad abs_x_handler  /* 5f */
	.asciz "RTS"         /* 60 */
	.quad impl_handler   /* 60 */
	.asciz "ADC"         /* 61 */
	.quad ind_x_handler  /* 61 */
	.asciz "JAM"         /* 62 */
	.quad jam_handler    /* 62 */
	.asciz "RRA"         /* 63 */
	.quad ind_x_handler  /* 63 */
	.asciz "NOP"         /* 64 */
	.quad zpg_handler    /* 64 */
	.asciz "ADC"         /* 65 */
	.quad zpg_handler    /* 65 */
	.asciz "ROR"         /* 66 */
	.quad zpg_handler    /* 66 */
	.asciz "RRA"         /* 67 */
	.quad zpg_handler    /* 67 */
	.asciz "PLA"         /* 68 */
	.quad impl_handler   /* 68 */
	.asciz "ADC"         /* 69 */
	.quad imm_handler    /* 69 */
	.asciz "ROR"         /* 6a */
	.quad a_handler      /* 6a */
	.asciz "ARR"         /* 6b */
	.quad imm_handler    /* 6b */
	.asciz "JMP"         /* 6c */
	.quad ind_handler    /* 6c */
	.asciz "ADC"         /* 6d */
	.quad abs_handler    /* 6d */
	.asciz "ROR"         /* 6e */
	.quad abs_handler    /* 6e */
	.asciz "RRA"         /* 6f */
	.quad abs_handler    /* 6f */
	.asciz "BVS"         /* 70 */
	.quad rel_handler    /* 70 */
	.asciz "ADC"         /* 71 */
	.quad ind_y_handler  /* 71 */
	.asciz "JAM"         /* 72 */
	.quad imm_handler    /* 72 */
	.asciz "RRA"         /* 73 */
	.quad ind_y_handler  /* 73 */
	.asciz "NOP"         /* 74 */
	.quad zpg_x_handler  /* 74 */
	.asciz "ADC"         /* 75 */
	.quad zpg_x_handler  /* 75 */
	.asciz "ROR"         /* 76 */
	.quad zpg_x_handler  /* 76 */
	.asciz "RRA"         /* 77 */
	.quad zpg_x_handler  /* 77 */
	.asciz "SEI"         /* 78 */
	.quad impl_handler   /* 78 */
	.asciz "ADC"         /* 79 */
	.quad abs_y_handler  /* 79 */
	.asciz "NOP"         /* 7a */
	.quad impl_handler   /* 7a */
	.asciz "RRA"         /* 7b */
	.quad abs_y_handler  /* 7b */
	.asciz "NOP"         /* 7c */
	.quad abs_x_handler  /* 7c */
	.asciz "ADC"         /* 7d */
	.quad abs_x_handler  /* 7d */
	.asciz "ROR"         /* 7e */
	.quad abs_x_handler  /* 7e */
	.asciz "RRA"         /* 7f */
	.quad abs_x_handler  /* 7f */
	.asciz "NOP"         /* 80 */
	.quad imm_handler    /* 80 */
	.asciz "STA"         /* 81 */
	.quad ind_x_handler  /* 81 */
	.asciz "NOP"         /* 82 */
	.quad imm_handler    /* 82 */
	.asciz "SAX"         /* 83 */
	.quad ind_x_handler  /* 83 */
	.asciz "STY"         /* 84 */
	.quad zpg_handler    /* 84 */
	.asciz "STA"         /* 85 */
	.quad zpg_handler    /* 85 */
	.asciz "STX"         /* 86 */
	.quad zpg_handler    /* 86 */
	.asciz "SAX"         /* 87 */
	.quad zpg_handler    /* 87 */
	.asciz "DEY"         /* 88 */
	.quad impl_handler   /* 88 */
	.asciz "NOP"         /* 89 */
	.quad imm_handler    /* 89 */
	.asciz "TXA"         /* 8a */
	.quad impl_handler   /* 8a */
	.asciz "ANE"         /* 8b */
	.quad imm_handler    /* 8b */
	.asciz "STY"         /* 8c */
	.quad abs_handler    /* 8c */
	.asciz "STA"         /* 8d */
	.quad abs_handler    /* 8d */
	.asciz "STX"         /* 8e */
	.quad abs_handler    /* 8e */
	.asciz "SAX"         /* 8f */
	.quad abs_handler    /* 8f */
	.asciz "BCC"         /* 90 */
	.quad rel_handler    /* 90 */
	.asciz "STA"         /* 91 */
	.quad ind_y_handler  /* 91 */
	.asciz "JAM"         /* 92 */
	.quad jam_handler    /* 92 */
	.asciz "SHA"         /* 93 */
	.quad ind_y_handler  /* 93 */
	.asciz "STY"         /* 94 */
	.quad zpg_x_handler  /* 94 */
	.asciz "STA"         /* 95 */
	.quad zpg_x_handler  /* 95 */
	.asciz "STX"         /* 96 */
	.quad zpg_y_handler  /* 96 */
	.asciz "SAX"         /* 97 */
	.quad zpg_y_handler  /* 97 */
	.asciz "TYA"         /* 98 */
	.quad impl_handler   /* 98 */
	.asciz "STA"         /* 99 */
	.quad abs_y_handler  /* 99 */
	.asciz "TXS"         /* 9a */
	.quad impl_handler   /* 9a */
	.asciz "TAS"         /* 9b */
	.quad abs_y_handler  /* 9b */
	.asciz "SHY"         /* 9c */
	.quad abs_x_handler  /* 9c */
	.asciz "STA"         /* 9d */
	.quad abs_x_handler  /* 9d */
	.asciz "SHX"         /* 9e */
	.quad abs_y_handler  /* 9e */
	.asciz "SHA"         /* 9f */
	.quad abs_y_handler  /* 9f */
	.asciz "LDY"         /* a0 */
	.quad imm_handler    /* a0 */
	.asciz "LDA"         /* a1 */
	.quad ind_x_handler  /* a1 */
	.asciz "LDX"         /* a2 */
	.quad imm_handler    /* a2 */
	.asciz "LAX"         /* a3 */
	.quad ind_x_handler  /* a3 */
	.asciz "LDY"         /* a4 */
	.quad zpg_handler    /* a4 */
	.asciz "LDA"         /* a5 */
	.quad zpg_handler    /* a5 */
	.asciz "LDX"         /* a6 */
	.quad zpg_handler    /* a6 */
	.asciz "LAX"         /* a7 */
	.quad zpg_handler    /* a7 */
	.asciz "TAY"         /* a8 */
	.quad impl_handler   /* a8 */
	.asciz "LDA"         /* a9 */
	.quad imm_handler    /* a9 */
	.asciz "TAX"         /* aa */
	.quad impl_handler   /* aa */
	.asciz "LXA"         /* ab */
	.quad imm_handler    /* ab */
	.asciz "LDY"         /* ac */
	.quad abs_handler    /* ac */
	.asciz "LDA"         /* ad */
	.quad abs_handler    /* ad */
	.asciz "LDX"         /* ae */
	.quad abs_handler    /* ae */
	.asciz "LAX"         /* af */
	.quad abs_handler    /* af */
	.asciz "BCS"         /* b0 */
	.quad rel_handler    /* b0 */
	.asciz "LDA"         /* b1 */
	.quad ind_y_handler  /* b1 */
	.asciz "JAM"         /* b2 */
	.quad jam_handler    /* b2 */
	.asciz "LAX"         /* b3 */
	.quad ind_y_handler  /* b3 */
	.asciz "LDY"         /* b4 */
	.quad zpg_x_handler  /* b4 */
	.asciz "LDA"         /* b5 */
	.quad zpg_x_handler  /* b5 */
	.asciz "LDX"         /* b6 */
	.quad zpg_y_handler  /* b6 */
	.asciz "LAX"         /* b7 */
	.quad zpg_y_handler  /* b7 */
	.asciz "CLV"         /* b8 */
	.quad impl_handler   /* b8 */
	.asciz "LDA"         /* b9 */
	.quad abs_y_handler  /* b9 */
	.asciz "TSX"         /* ba */
	.quad impl_handler   /* ba */
	.asciz "LAS"         /* bb */
	.quad abs_y_handler  /* bb */
	.asciz "LDY"         /* bc */
	.quad abs_x_handler  /* bc */
	.asciz "LDA"         /* bd */
	.quad abs_x_handler  /* bd */
	.asciz "LDX"         /* be */
	.quad abs_y_handler  /* be */
	.asciz "LAX"         /* bf */
	.quad abs_y_handler  /* bf */
	.asciz "CPY"         /* c0 */
	.quad imm_handler    /* c0 */
	.asciz "CMP"         /* c1 */
	.quad ind_x_handler  /* c1 */
	.asciz "NOP"         /* c2 */
	.quad imm_handler    /* c2 */
	.asciz "DCP"         /* c3 */
	.quad ind_x_handler  /* c3 */
	.asciz "CPY"         /* c4 */
	.quad zpg_handler    /* c4 */
	.asciz "CMP"         /* c5 */
	.quad zpg_handler    /* c5 */
	.asciz "DEC"         /* c6 */
	.quad zpg_handler    /* c6 */
	.asciz "DCP"         /* c7 */
	.quad zpg_handler    /* c7 */
	.asciz "INY"         /* c8 */
	.quad impl_handler   /* c8 */
	.asciz "CMP"         /* c9 */
	.quad imm_handler    /* c9 */
	.asciz "DEX"         /* ca */
	.quad impl_handler   /* ca */
	.asciz "SBX"         /* cb */
	.quad imm_handler    /* cb */
	.asciz "CPY"         /* cc */
	.quad abs_handler    /* cc */
	.asciz "CMP"         /* cd */
	.quad abs_handler    /* cd */
	.asciz "DEC"         /* ce */
	.quad abs_handler    /* ce */
	.asciz "DCP"         /* cf */
	.quad abs_handler    /* cf */
	.asciz "BNE"         /* d0 */
	.quad rel_handler    /* d0 */
	.asciz "CMP"         /* d1 */
	.quad ind_y_handler  /* d1 */
	.asciz "JAM"         /* d2 */
	.quad jam_handler    /* d2 */
	.asciz "DCP"         /* d3 */
	.quad ind_y_handler  /* d3 */
	.asciz "NOP"         /* d4 */
	.quad zpg_x_handler  /* d4 */
	.asciz "CMP"         /* d5 */
	.quad zpg_x_handler  /* d5 */
	.asciz "DEC"         /* d6 */
	.quad zpg_x_handler  /* d6 */
	.asciz "DCP"         /* d7 */
	.quad zpg_x_handler  /* d7 */
	.asciz "CLD"         /* d8 */
	.quad impl_handler   /* d8 */
	.asciz "CMP"         /* d9 */
	.quad abs_y_handler  /* d9 */
	.asciz "NOP"         /* da */
	.quad impl_handler   /* da */
	.asciz "DCP"         /* db */
	.quad abs_y_handler  /* db */
	.asciz "NOP"         /* dc */
	.quad abs_x_handler  /* dc */
	.asciz "CMP"         /* dd */
	.quad abs_x_handler  /* dd */
	.asciz "DEC"         /* de */
	.quad abs_x_handler  /* de */
	.asciz "DCP"         /* df */
	.quad abs_x_handler  /* df */
	.asciz "CPX"         /* e0 */
	.quad imm_handler    /* e0 */
	.asciz "SBC"         /* e1 */
	.quad ind_x_handler  /* e1 */
	.asciz "NOP"         /* e2 */
	.quad imm_handler    /* e2 */
	.asciz "ISC"         /* e3 */
	.quad ind_x_handler  /* e3 */
	.asciz "CPX"         /* e4 */
	.quad zpg_handler    /* e4 */
	.asciz "SBC"         /* e5 */
	.quad zpg_handler    /* e5 */
	.asciz "INC"         /* e6 */
	.quad zpg_handler    /* e6 */
	.asciz "ISC"         /* e7 */
	.quad zpg_handler    /* e7 */
	.asciz "INX"         /* e8 */
	.quad impl_handler   /* e8 */
	.asciz "SBC"         /* e9 */
	.quad imm_handler    /* e9 */
	.asciz "NOP"         /* ea */
	.quad impl_handler   /* ea */
	.ascii "USBC"        /* eb */
	.quad imm_handler    /* eb */
	.asciz "CPX"         /* ec */
	.quad abs_handler    /* ec */
	.asciz "SBC"         /* ed */
	.quad abs_handler    /* ed */
	.asciz "INC"         /* ee */
	.quad abs_handler    /* ee */
	.asciz "ISC"         /* ef */
	.quad abs_handler    /* ef */
	.asciz "BEQ"         /* f0 */
	.quad rel_handler    /* f0 */
	.asciz "SBC"         /* f1 */
	.quad ind_y_handler  /* f1 */
	.asciz "JAM"         /* f2 */
	.quad jam_handler    /* f2 */
	.asciz "ISC"         /* f3 */
	.quad ind_y_handler  /* f3 */
	.asciz "NOP"         /* f4 */
	.quad zpg_x_handler  /* f4 */
	.asciz "SBC"         /* f5 */
	.quad zpg_x_handler  /* f5 */
	.asciz "INC"         /* f6 */
	.quad zpg_x_handler  /* f6 */
	.asciz "ISC"         /* f7 */
	.quad zpg_x_handler  /* f7 */
	.asciz "SED"         /* f8 */
	.quad impl_handler   /* f8 */
	.asciz "SBC"         /* f9 */
	.quad abs_y_handler  /* f9 */
	.asciz "NOP"         /* fa */
	.quad impl_handler   /* fa */
	.asciz "ISC"         /* fb */
	.quad abs_y_handler  /* fb */
	.asciz "NOP"         /* fc */
	.quad abs_x_handler  /* fc */
	.asciz "SBC"         /* fd */
	.quad abs_x_handler  /* fd */
	.asciz "INC"         /* fe */
	.quad abs_x_handler  /* fe */
	.asciz "ISC"         /* ff */
	.quad abs_x_handler  /* ff */

.section .bss

.lcomm cmd_line_ptr, 8
.lcomm fd, 8
.lcomm file_size, 8
.lcomm base_brk, 8
.lcomm str_alloc_ptr, 8
