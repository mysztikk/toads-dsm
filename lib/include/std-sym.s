/*
 * std-sym.s - Common symbols.
 *
 * (C) 2026 Amethyst Crenshaw.
 * Licensed under the MIT License. See LICENSE.
 */

/* System calls. */
.equ SYS_READ, 0
.equ SYS_WRITE, 1
.equ SYS_OPEN, 2
.equ SYS_CLOSE, 3
.equ SYS_LSEEK, 8
.equ SYS_MMAP, 9
.equ SYS_MUNMAP, 11
.equ SYS_BRK, 12
.equ SYS_EXIT, 60

/* File descriptors. */
.equ STDIN, 0
.equ STDOUT, 1
.equ STDERR, 2

/* Open syscall flags. */
.equ O_RDONLY, 00000000
.equ O_WRONLY, 00000001
.equ O_RDWR, 00000002

.equ O_CREAT, 00000100
.equ O_EXCL, 00000200
.equ O_NOCTTY, 00000400

.equ O_TRUNC, 00001000
.equ O_APPEND, 00002000
.equ O_NONBLOCK, 00004000

.equ S_IXOTH, 00000001
.equ S_IWOTH, 00000002
.equ S_IROTH, 00000004
.equ S_IRWXO, 00000007

/* Open syscall modes. */
.equ S_IXGRP, 00000010
.equ S_IWGRP, 00000020
.equ S_IRGRP, 00000040
.equ S_IRWXP, 00000070

.equ S_IXUSR, 00000100
.equ S_IWUSR, 00000200
.equ S_IRUSR, 00000400
.equ S_IRWXR, 00000700

.equ S_IXALL, 00000111
.equ S_IWALL, 00000222
.equ S_IRALL, 00000444
.equ S_IRWXL, 00000777

/* Lseek syscall whence. */
.equ SEEK_SET, 0
.equ SEEK_CUR, 1
.equ SEEK_END, 2

/* Mmap syscall protocol. */
.equ PROT_NONE, 0
.equ PROT_READ, 1
.equ PROT_WRITE,2
.equ PROT_EXEC, 4
.equ PROT_GROWSDOWN, 0x01000000
.equ PROT_GROWSUP, 0x02000000

/* Mmap syscall flags. */
.equ MAP_SHARED, 1
.equ MAP_PRIVATE, 2

/* Miscellaneous. */
.equ NULL, 0
.equ EOF, 0
.equ FALSE, 0
.equ TRUE, 1
.equ EXIT_SUCCESS, 0
.equ EXIT_FAILURE, 1
