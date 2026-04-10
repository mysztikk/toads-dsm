/*
 * parse-cmd-line.s
 *
 * (C) 2026 Amethyst Crenshaw.
 * Licensed under the MIT License. See LICENSE.
 */

.include "std-sym.s"
.include "parse-cmd-line-sym.s"

.section .text

/*
 * parse_cmd_line
 * Since dmp and dsm both utilize the same logic, it is extracted so it can
 * exist once and be used twice.
 * 
 * Clobber:
 * Assume no register is safe.
 *
 * Returns a pointer to the filled cmd_line structure on success. Else, returns
 * 0.
 *
 * Assumes that it is called immediately, before any stack adjustments.
 *
 * Assumes the specific command line layout:
 * 	prg -f filename.ext -s [addr]:[offset] -n [num]
 * 	addr, offset, and num can be a hexadecimal (0x*) or decimal number.
 *
 * See ROOT/dmp/dmp.s or ROOT/dsm/dsm.s for example usage.
 *
 * Include the `ROOT/lib/include/parse-cmd-line-sym.s` file and store the
 * pointer of the cmd_line structure. Index into the cmd_line structure using
 * the symbols defined in the included file for program logic.
 */
.globl parse_cmd_line
parse_cmd_line:
	xorq	%r9, %r9

.equ TOTAL_ARGS, 7
.equ COUNT_ARGS, 6

	cmpq	$TOTAL_ARGS, 8(%rsp)
	jne	fail
cmd_line_loop:
	/* Load the argument */
	movq	24(%rsp, %r9, 8), %rdi

	/* Do */
	movq	$f_flag_str, %rsi
	call	cmp_str
	cmpq	$1, %rax
	je	found_f

	movq	$s_flag_str, %rsi
	call	cmp_str
	cmpq	$1, %rax
	je	found_s

	movq	$n_flag_str, %rsi
	call	cmp_str
	cmpq	$1, %rax
	je	found_n

	/* If we're here, something ran wild, fail. */
	jmp	fail

found_f:
	/* Load the next argument */
	incq	%r9
	movq	24(%rsp, %r9, 8), %rdi

	/* Check if things are right */
	cmpb	$TRUE, cmd_line+F_FLAG_CMD_LINE
	je	fail
	cmpb	$'-', (%rdi)
	je	fail

	/* Do */
	movb	$TRUE, cmd_line+F_FLAG_CMD_LINE
	movq	%rdi, cmd_line+FILE_PATH_STR_PTR_CMD_LINE
	jmp	found_exit

found_s:
	/* Load the next argument */
	incq	%r9
	movq	24(%rsp, %r9, 8), %rdi

	/* Check if things are right */
	cmpb	$TRUE, cmd_line+S_FLAG_CMD_LINE
	je	fail
	cmpb	$'-', (%rdi)
	je	fail

	/* Do */
	movb	$TRUE, cmd_line+S_FLAG_CMD_LINE
	xorq	%r10, %r10

found_s_loop:
	cmpb	$':', (%rdi, %r10)
	je	found_s_found_colon
	cmpb	$NULL, (%rdi, %r10)
	je	fail
	incq	%r10
	jmp	found_s_loop

found_s_found_colon:
	cmpq	$0, %r10 /* Has to at least have a character before it */
	je	fail

	movb	$NULL, (%rdi, %r10)

	cmpb	$'0', (%rdi)
	je	maybe_found_s_hex_addr

found_s_dec_addr:
	call	dec_str_to_int
	cmpq	$-1, %r15
	je	fail
	movl	%eax, cmd_line+ADDR_CMD_LINE
	jmp	found_s_step_2

maybe_found_s_hex_addr:
	cmpb	$'x', 1(%rdi)
	jne	found_s_dec_addr

found_s_hex_addr:
	addq	$2, %rdi
	cmpb	$NULL, (%rdi)
	je	fail
	call	hex_str_to_int
	cmpq	$-1, %r15
	je	fail
	movl	%eax, cmd_line+ADDR_CMD_LINE
	subq	$2, %rdi

found_s_step_2:
	incq	%r10
	addq	%r10, %rdi
	cmpb	$'0', (%rdi)
	je	maybe_found_s_hex_off

found_s_dec_off:
	call	dec_str_to_int
	cmpq	$-1, %r15
	je	fail
	movl	%eax, cmd_line+OFF_CMD_LINE
	jmp	found_exit

maybe_found_s_hex_off:
	cmpb	$'x', 1(%rdi)
	jne	found_s_dec_off

found_s_hex_off:
	addq	$2, %rdi
	cmpb	$NULL, (%rdi)
	je	fail
	call	hex_str_to_int
	cmpq	$-1, %r15
	je	fail
	movl	%eax, cmd_line+OFF_CMD_LINE
	subq	$2, %rdi
	jmp	found_exit

found_n:
	/* Load the next argument */
	incq	%r9
	movq	24(%rsp, %r9, 8), %rdi

	/* Check if things are right */
	cmpb	$TRUE, cmd_line+N_FLAG_CMD_LINE
	je	fail
	cmpb	$'-', (%rdi)
	je	fail

	/* Do */
	movb	$TRUE, cmd_line+N_FLAG_CMD_LINE
	cmpb	$'0', (%rdi)
	je	maybe_found_n_hex

found_n_dec:
	call	dec_str_to_int
	cmpq	$-1, %r15
	je	fail
	movl	%eax, cmd_line+NUM_BYTES_READ_CMD_LINE
	jmp	found_exit

maybe_found_n_hex:
	cmpb	$'x', 1(%rdi)
	jne	found_n_dec

found_n_hex:
	addq	$2, %rdi
	cmpb	$NULL, (%rdi)
	je	fail
	call	hex_str_to_int
	cmpq	$-1, %r15
	je	fail
	movl	%eax, cmd_line+NUM_BYTES_READ_CMD_LINE
	subq	$2, %rdi

found_exit:
	/* Main loop */
	incq	%r9
	cmpq	$COUNT_ARGS, %r9 
	je	success
	jmp	cmd_line_loop

success:
	movq	$cmd_line, %rax
	ret

fail:
	movq	$0, %rax
	ret

.section .rodata

f_flag_str:
	.asciz "-f"

s_flag_str:
	.asciz "-s"

n_flag_str:
	.asciz "-n"

.section .bss

.equ F_FLAG_CMD_LINE, 0
.equ S_FLAG_CMD_LINE, 1
.equ N_FLAG_CMD_LINE, 2
.equ FILE_PATH_STR_PTR_CMD_LINE, 3
.equ ADDR_CMD_LINE, 11
.equ OFF_CMD_LINE, 15
.equ NUM_BYTES_READ_CMD_LINE, 19
.equ PADDING_CMD_LINE, 23
.lcomm cmd_line, 24
