/*
 * str.s - Common string functions.
 *
 * (C) 2026 Amethyst Crenshaw.
 * Licensed under the MIT License. See LICENSE.
 */

.include "std-sym.s"

.section .text

/*
 * get_str_len
 * Get the length of a string.
 *
 * Parameters:
 * %rdi - Pointer to the string.
 *
 * Clobber:
 * %rax - Return value.
 *
 * Returns an unsigned count of bytes in the string.
 *
 * String must be null-terminated.
 */
.globl get_str_len
.type get_str_len, @function
get_str_len:
	xorq	%rax, %rax

get_str_len_loop:
	cmpb	$0, (%rdi, %rax)
	je	get_str_len_exit
	incq	%rax
	jmp	get_str_len_loop

get_str_len_exit:
	ret

/*
 * print
 * Print a string out to STDOUT.
 *
 * Parameters:
 * %rdi - Pointer to the string.
 *
 * Clobber:
 * %rax - Syscall number & return value.
 * %rcx - Syscall clobber.
 * %rdx - Syscall parameter.
 * %rdi - Syscall parameter.
 * %rsi - Syscall parameter.
 * %r11 - Syscall clobber.
 *
 * Returns an unsigned count of bytes printed.
 *
 * String must be null-terminated.
 */
.globl print
.type print, @function
print:
	call	get_str_len
	movq	%rax, %rdx
	movq	%rdi, %rsi
	movq	$STDOUT, %rdi
	movq	$SYS_WRITE, %rax
	syscall
	ret

/*
 * cmp_str
 * Compare two strings for equality.
 *
 * Parameters:
 * %rdi - Pointer to the first string.
 * %rsi - Pointer to the second string.
 *
 * Clobber:
 * %rax - Store first string length &  Return value.
 * %rcx - Store second string length & Store current byte for comparison of
 * first string.
 * %dl - Store current byte for comparison of second string.
 *
 * Returns 1 if both strings are equal, 0 if they are not equal.
 *
 * Both strings must be null-terminated.
 */
.globl cmp_str
.type cmp_str, @function
cmp_str:
	/* Get the length of the first string. */
	call	get_str_len
	pushq	%rax

	/* Get the length of the second. */
	pushq	%rdi
	movq	%rsi, %rdi
	call	get_str_len
	popq	%rdi
	popq	%rcx /* Revisit this, I have no clue why (%rsp) wasn't working. */

	/* Check if they are the same length. */
	cmpq	%rax, %rcx
	jne	cmp_str_false_exit

	/* Check byte for byte if the two strings are equal. */
	xorq	%rax, %rax

cmp_str_loop:
	movb	(%rdi, %rax), %cl
	movb	(%rsi, %rax), %dl
	cmpb	$0, %cl
	je	cmp_str_true_exit
	cmpb	%cl, %dl
	jne	cmp_str_false_exit
	incq	%rax
	jmp	cmp_str_loop

cmp_str_true_exit:
	movq	$TRUE, %rax
	ret

cmp_str_false_exit:
	movq	$FALSE, %rax
	ret

/*
 * hex_str_to_int
 * Convert a hexadecimal string to unsigned integer.
 *
 * Parameters:
 * %rdi - Pointer to the string.
 *
 * Clobber:
 * %rax - Main return value.
 * %r15 - Error register.
 *
 * If the string is valid, the %rax register will store the safe-to-use unsigned
 * integer version of the string, and the %r15 register will equal zero.
 * If the string is not valid, the %r15 register will equal -1, and the %rax
 * register should be considered garbage.
 *
 * String must be null-terminated.
 */
.globl hex_str_to_int
.type hex_str_to_int, @function
hex_str_to_int:
	xorq	%r15, %r15
	movq	$1, %rbx

	/* Wrangle the string */
	call	get_str_len
	movq	%rax, %rcx
	subq	$1, %rcx
	
hex_str_to_int_loop:
	xorq	%rax, %rax

	/* Get the character, verify, and turn it into it's int equivelant. */
	movb	(%rdi, %rcx), %al
	subb	$'0', %al
	cmpb	$9, %al
	jle	hex_str_to_int_cont
	subb	$7, %al /* If not a number, is it an uppercase letter? */
	cmpb	$15, %al
	jle	hex_str_to_int_cont
	subb	$32, %al /* If not uppercase, is it lowercase? */
	cmpb	$15, %al
	jg	hex_str_to_int_exit_fail

hex_str_to_int_cont:
	mulq	%rbx
	addq	%rax, %r15

	/* Loop exit */
	cmpq	$0, %rcx
	je	hex_str_to_int_exit_success

	/* Increment the place */
	pushq	%rax
	movq	%rbx, %rax
	movq	$16, %rbx
	mulq	%rbx
	movq	%rax, %rbx
	popq	%rax

	/* Loop continue */
	subq	$1, %rcx
	jmp	hex_str_to_int_loop

hex_str_to_int_exit_fail:
	movq	$-1, %r15
	ret

hex_str_to_int_exit_success:
	movq	%r15, %rax
	movq	$0, %r15
	ret

/*
 * dec_str_to_int
 * Convert a decimal string to unsigned integer.
 *
 * Parameters:
 * %rdi - Pointer to the string.
 *
 * Clobber:
 * %rax - Current character & main return value.
 * %rbx - Place of number (like tenths, hundreths, thousandths).
 * %rcx - Current character index.
 * %r15 - Temporary holder for the return value & error register.
 *
 * If the string is valid, the %rax register will store the safe-to-use unsigned
 * integer version of the string, and the %r15 register will equal zero.
 * If the string is not valid, the %r15 register will equal -1, and the %rax
 * register should be considered garbage.
 *
 * String must be null-terminated.
 */
.globl dec_str_to_int
.type dec_str_to_int, @function
dec_str_to_int:
	xorq	%r15, %r15
	movq	$1, %rbx

	/* Wrangle the string */
	call	get_str_len
	movq	%rax, %rcx
	subq	$1, %rcx
	
dec_str_to_int_loop:
	xorq	%rax, %rax

	/* Get the character, verify, and turn it into it's int equivelant. */
	movb	(%rdi, %rcx), %al
	subb	$'0', %al
	cmpb	$9, %al
	jg	dec_str_to_int_exit_fail
	mulq	%rbx
	addq	%rax, %r15

	/* Loop exit */
	cmpq	$0, %rcx
	je	dec_str_to_int_exit_success

	/* Increment the place */
	pushq	%rax
	movq	%rbx, %rax
	movq	$10, %rbx
	mulq	%rbx
	movq	%rax, %rbx
	popq	%rax

	/* Loop continue */
	subq	$1, %rcx
	jmp	dec_str_to_int_loop

dec_str_to_int_exit_fail:
	movq	$-1, %r15
	ret

dec_str_to_int_exit_success:
	movq	%r15, %rax
	movq	$0, %r15
	ret

/*
 * int_to_str
 * Convert an unsigned integer to a string.
 *
 * Parameters:
 * %rdi - The integer to be converted.
 * %rsi - Base (2, 10, 16) of the string.
 * %rdx - A pointer to accessible memory for the string.
 * %rcx - Amount of available bytes allocated at the string pointer.
 *
 * Clobber:
 * %rax - Return value.
 * %rdx - Conversion math.
 * %r9 - Count of bytes needed for the string.
 * %r10 - General purpose pointer.
 *
 * Returns the number of bytes needed if the function succeeded, 0 if it failed.
 *
 * May segfault if %rcx improperly reports the amount of available memory.
 *
 * Failure reasons:
 * Not enough memory at the pointer according to %rcx.
 * %rsi, %rdx, or %rcx are zero.
 * %rsi is above 16.
 */
.globl int_to_str
.type int_to_str, @function
/* Not the greatest thing ever but it works... */
int_to_str:
	/* Make sure the inputs can be worked with */
	test	%rdx, %rdx
	jz	int_to_str_exit_bad
	test	%rdi, %rdi
	jz	int_to_str_zero
	test	%rsi, %rsi
	jz	int_to_str_exit_bad
	cmpq	$16, %rsi
	jg	int_to_str_exit_bad
	test	%rcx, %rcx
	jz	int_to_str_exit_bad

	movq	%rdi, %rax
	movq	%rdx, %r10
	xorq	%rdx, %rdx
	xorq	%r9, %r9

int_to_str_loop_one:
	/* Iterate to find how many digits */
	divq	%rsi
	addq	$1, %r9
	xorq	%rdx, %rdx
	test	%rax, %rax
	jz	int_to_str_loop_one_exit
	jmp	int_to_str_loop_one

int_to_str_loop_one_exit:
	/* Check if we supposedly have room */
	cmpq	%rcx, %r9
	jg	int_to_str_exit_bad

	movq	%rdi, %rax
	xorq	%rdx, %rdx
	addq	%r9, %r10
	movb	$0, (%r10)

int_to_str_loop_two:
	/* Load */
	subq	$1, %r10
	divq	%rsi
	movb	%dl, (%r10)
	xorq	%rdx, %rdx
	addb	$'0', (%r10)
	cmpb	$'9', (%r10)
	jle	int_to_str_loop_two_cont
	addb	$7, (%r10)

int_to_str_loop_two_cont:
	test	%rax, %rax
	jz	int_to_str_exit
	jmp	int_to_str_loop_two

int_to_str_zero:
	cmpq	$2, %rcx
	jl	int_to_str_exit_bad
	movw	$0x0030, (%rdx)
	movq	$1, %r9

int_to_str_exit:
	addq	$1, %r9 /* Null byte */
	movq	%r9, %rax
	ret

int_to_str_exit_bad:
	xorq	%rax, %rax
	ret
