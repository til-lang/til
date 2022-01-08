# TODO

## Utilities

* Debugging system for the language itself.
* REPL - (it would be very nice to allow multi-line commands).

## Language-wise

* Improve error messages about compilation/syntax.
* Procs can be considered "higher order" or not?
* Should we be able to "append" new methods to already defined types?
* Profiling!

## Commands

* `test`? -- To create unit tests, maybe...
* Should we act like a shell and run system commands automatically???

### Types and nodes

* Pid: get Process exit code.
* `eval "cmd"` (currently it only evaluates a SimpleList).

### Lists

* push
* pop
* insert
* sort
* flatten $list_1 item $list_2
* contains $list item

### File system

* Python's `PosixPath`-like object, with related methods.
    * Specially  `open`, so we can, you know... open files.
