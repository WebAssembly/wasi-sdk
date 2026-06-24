add_testcase(abort.c PASS_REGULAR_EXPRESSION "wasm trap.*unreachable")
add_testcase(argc_argv_main.c PASS_REGULAR_EXPRESSION "hello from argc argv main")
add_testcase(argc_argv_main.cc PASS_REGULAR_EXPRESSION "hello from C\\+\\+ argc argv main")
add_testcase(assert-fail.c PASS_REGULAR_EXPRESSION "Assertion failed: false.*wasm trap:.*unreachable")
add_testcase(assert-pass.c)
add_testcase(clocks.c EMULATED_CLOCKS)
add_testcase(cpp_thread_local.cc)
add_testcase(ctors_dtors.c PASS_REGULAR_EXPRESSION "\
hello from_constructor101
hello from_constructor
hello from_constructor65535
hello main
goodbye main
hello another_from_atexit
hello from_atexit
hello from_destructor65535
hello from_destructor
hello from_destructor101
"
)
add_testcase(ctors_dtors.cc PASS_REGULAR_EXPRESSION "\
hello from_constructor101
hello from_constructor
hello from_constructor65535
hello StaticObject::StaticObject
hello main
goodbye main
hello another_from_atexit
hello from_atexit
hello from_destructor65535
hello from_destructor
hello StaticObject::~StaticObject
hello from_destructor101
")
add_testcase(empty.c)
add_testcase(env-absent.c PASS_REGULAR_EXPRESSION "HELLO = \\(null\\)")
add_testcase(env.c ENV HELLO=hello PASS_REGULAR_EXPRESSION "HELLO = hello")
add_testcase(environ.c ENV HELLO=hello PASS_REGULAR_EXPRESSION "HELLO = hello")
add_testcase(exceptions.cc)
add_testcase(getentropy.c)
add_testcase(iostream_main.cc PASS_REGULAR_EXPRESSION "hello from C\\+\\+ main with cout")
add_testcase(main_errno.c PASS_REGULAR_EXPRESSION "initial errno is 0: Success")
add_testcase(mmap.c EMULATED_MMAN FSDIR PASS_REGULAR_EXPRESSION "\
“Would you tell me, please, which way I ought to go from here\\?”

“That depends a good deal on where you want to get to,” said the Cat.
"
)
add_testcase(no_arg_main.c PASS_REGULAR_EXPRESSION "hello from no-arg main")
add_testcase(no_arg_main.cc PASS_REGULAR_EXPRESSION "hello from C\\+\\+ no-arg main")
add_testcase(opendir.c FSDIR)
add_testcase(printf-long-double-enabled.c PRINTSCAN_LONG_DOUBLE PASS_REGULAR_EXPRESSION "the answer is 42.000000")
add_testcase(printf-no-float.c PASS_REGULAR_EXPRESSION "the answer is 42")
add_testcase(printf-no-long-double.c PASS_REGULAR_EXPRESSION "the answer is 42.000000")
add_testcase(sigabrt.c EMULATED_SIGNAL PASS_REGULAR_EXPRESSION "\
raising SIGABRT...
Program received fatal signal: Aborted
.*failed to run main module.*
")
add_testcase(signals.c EMULATED_SIGNAL PASS_REGULAR_EXPRESSION "\
psignal message for SIGINT: Interrupt
strsignal for SIGHUP: 'Hangup'
beginning handler test:
handler for signal Window changed
finished handler test
")
add_testcase(stat.c FSDIR)
add_testcase(void_main.c PASS_REGULAR_EXPRESSION "hello from void main")
add_testcase(void_main.cc PASS_REGULAR_EXPRESSION "hello from C\\+\\+ void main")
