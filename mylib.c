// mylib.c -- single-file example
#include <stdio.h>

__attribute__((visibility("default")))
void mylib_init(void) {
    // called by your injector (or by constructor if you choose)
    printf("mylib_init() called\n");
}

__attribute__((visibility("default")))
int add_one(int x) {
    return x + 1;
}
