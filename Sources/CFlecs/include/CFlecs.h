// The umbrella header for the CFlecs module. Both flecs.c and the Swift importer read it, so every
// macro that changes what flecs.h declares is set here and nowhere else; a define in Package.swift
// would reach the C compile only.
#ifndef CFLECS_H
#define CFLECS_H

#if defined(__wasm__)
// WASI has no sockets, and the HTTP addon includes netdb.h. REST needs HTTP, so both go.
#define FLECS_NO_HTTP
#define FLECS_NO_REST
#endif

// Do not define FLECS_ACCURATE_COUNTERS: in 4.2.0 five counters are int32_t and the atomic
// increment it switches to writes 64 bits. The plain increments race between worker threads,
// which Tests/tsan-suppressions.txt covers.

#include "../flecs/distr/flecs.h"

#endif
