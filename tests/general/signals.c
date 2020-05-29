#include <signal.h>
#include <string.h>
#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>

// Check for C-standard macros.
#ifndef SIGABRT
#error SIGABRT not defined
#endif
#ifndef SIGFPE
#error SIGFPE not defined
#endif
#ifndef SIGILL
#error SIGILL not defined
#endif
#ifndef SIGINT
#error SIGINT not defined
#endif
#ifndef SIGSEGV
#error SIGSEGV not defined
#endif
#ifndef SIGTERM
#error SIGTERM not defined
#endif

// Make sure this exists.
#include <sys/signal.h>

volatile sig_atomic_t flag = 0;

static void handler(int n) {
    // This is undefined behavior by the spec, but this is just a testcase.
    fflush(stdout);
    printf("handler for signal %s\n", strsignal(n));
    fflush(stdout);
    flag = 1;
}

int main(void) {
    // Test various raise cases that don't abort.
    assert(raise(SIGCHLD) == 0);
#ifdef SIGCLD
    assert(raise(SIGCLD) == 0);
#endif
    assert(raise(SIGURG) == 0);
    assert(raise(SIGWINCH) == 0);

    errno = 0;
    assert(raise(_NSIG) == -1 && errno == EINVAL);

    // Test psignal.
    psignal(SIGINT, "psignal message for SIGINT");

    // Test strsignal.
    printf("strsignal for SIGHUP: '%s'\n", strsignal(SIGHUP));

    // Some signals can't be ignored.
    errno = 0;
    assert(signal(SIGKILL, SIG_IGN) == SIG_ERR && errno == EINVAL);
    errno = 0;
    assert(signal(SIGSTOP, SIG_IGN) == SIG_ERR && errno == EINVAL);

    // Test SIG_IGN.
    assert(signal(SIGINT, SIG_IGN) == SIG_DFL);
    raise(SIGINT);
    assert(signal(SIGINT, SIG_DFL) == SIG_IGN);

    // Install a handler and invoke it.
    printf("beginning handler test:\n");
    assert(signal(SIGWINCH, handler) == SIG_DFL);
    fflush(stdout);
    assert(raise(SIGWINCH) == 0);
    fflush(stdout);
    assert(flag == 1);
    printf("finished handler test\n");

    // Check various API invariants.
    assert(signal(SIGWINCH, SIG_IGN) == handler);
    assert(raise(SIGWINCH) == 0);
    assert(signal(SIGWINCH, SIG_DFL) == SIG_IGN);
    assert(raise(SIGWINCH) == 0);
    assert(signal(SIGWINCH, SIG_DFL) == SIG_DFL);
    assert(raise(SIGWINCH) == 0);

    return EXIT_SUCCESS;
}
