// substrate.h — minimal stub for compile-time only
#ifndef SUBSTRATE_H
#define SUBSTRATE_H

#include <stddef.h>
#include <objc/objc.h>

#ifdef __cplusplus
extern "C" {
#endif

// Basic prototypes used by many tweaks — runtime will actually provide implementations.
void MSHookFunction(void *symbol, void *replacement, void **result);
void MSHookMessageEx(Class _class, SEL sel, IMP imp, IMP *result);
void MSHookIvar(Class _class, const char *name, ptrdiff_t offset);
void MSHookMessage(Class _class, SEL sel, void *imp);

// Convenience macros (no-op for compile-time)
#ifndef MSHook
#define MSHook(a,b,c) MSHookFunction((void*)a,(void*)b,(void**)c)
#endif

#ifdef __cplusplus
}
#endif

#endif // SUBSTRATE_H
