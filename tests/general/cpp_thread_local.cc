struct c { ~c() {} };
thread_local c v;
int main() { (void)v; }
