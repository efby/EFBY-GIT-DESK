#ifndef EFBY_PTY_H
#define EFBY_PTY_H
#include <sys/types.h>
int efby_pty_start(const char *directory, const char *shell, int columns, int rows, int login, int *master, pid_t *child);
int efby_pty_resize(int master, int columns, int rows);
#endif
