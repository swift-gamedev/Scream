# Platforms

What each supported system needs, and what differs between them.

## Overview

Flecs needs little from the system beyond the C runtime and threads, so Scream has no system
dependencies to install. The same Swift code builds on every platform with no `#if os(...)`.

## Linux

A Swift toolchain. Nothing else.

## Windows

The Swift toolchain for Windows plus the MSVC build tools and Windows SDK, which Swift needs but
does not install; the [Swift installation instructions](https://www.swift.org/install/windows/)
list them. Flecs links `Ws2_32` for its HTTP addon and `DbgHelp` for backtraces.

## macOS

A Swift toolchain, from swift.org or Xcode.

## Web

The Swift SDK for Wasm, which targets WASI (`wasm32-unknown-wasip1`), installed with
`swift sdk install` from [swift.org](https://www.swift.org/install/). Build with
`swift build --swift-sdk swift-6.4.2-RELEASE_wasm --product Scream`; the result runs under any WASI runtime,
including Node's `node:wasi`, or in a browser through
[JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit)'s PackageToJS plugin.

WASI has no sockets and no threads, so the HTTP and REST addons are compiled out there, which
means the Flecs Explorer cannot connect to a world running in a browser. Integers are 32 bits
wide, so Flecs' structs are smaller; never hardcode a size.
