# seatuya

C wrapper library for the tuyapp C++ Tuya library.

## Rules

- No `#define` except as header file guards. Use `const`, `enum`, `struct`, or `typedef` instead.
- All first-party source code outside of GNU infrastructure (Makefile, configure.ac), vendored dependencies, and bindings must be in **C** or **newLISP**. No Python, Perl, shell scripts beyond trivial glue, or any other language.
