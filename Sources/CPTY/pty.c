#include "CPTY.h"
#include <util.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <signal.h>
#include <errno.h>
extern char **environ;

int efby_pty_start(const char *directory, const char *shell, int columns, int rows, int login, int *master, pid_t *child) {
    int slave;
    struct winsize size = { .ws_row = (unsigned short)rows, .ws_col = (unsigned short)columns };
    if (openpty(master, &slave, NULL, NULL, &size) == -1) return -1;
    int count = 0;
    while (environ[count]) count++;
    char **environment = calloc((size_t)count + 3, sizeof(char *));
    if (!environment) { close(*master); close(slave); return -1; }
    int n = 0;
    for (int i = 0; i < count; i++) {
        if (strncmp(environ[i], "TERM=", 5) != 0 && strncmp(environ[i], "COLORTERM=", 10) != 0 && (login || strncmp(environ[i], "ENV=", 4) != 0)) environment[n++] = environ[i];
    }
    environment[n++] = "TERM=xterm-256color";
    environment[n++] = "COLORTERM=truecolor";
    char *arguments[] = { (char *)shell, login ? "-l" : NULL, NULL };
    pid_t pid = fork();
    if (pid == -1) { free(environment); close(*master); close(slave); return -1; }
    if (pid == 0) {
        // Only async-signal-safe operations after fork: no Swift/ObjC runtime.
        close(*master);
        if (setsid() == -1 || ioctl(slave, TIOCSCTTY, NULL) == -1 || chdir(directory) == -1) _exit(126);
        dup2(slave, STDIN_FILENO); dup2(slave, STDOUT_FILENO); dup2(slave, STDERR_FILENO);
        if (slave > STDERR_FILENO) close(slave);
        execve(shell, arguments, environment);
        _exit(127);
    }
    free(environment);
    close(slave);
    fcntl(*master, F_SETFD, FD_CLOEXEC);
    fcntl(*master, F_SETFL, fcntl(*master, F_GETFL) | O_NONBLOCK);
    *child = pid;
    return 0;
}
int efby_pty_resize(int master, int columns, int rows) {
    struct winsize size = { .ws_row = (unsigned short)rows, .ws_col = (unsigned short)columns };
    return ioctl(master, TIOCSWINSZ, &size);
}
