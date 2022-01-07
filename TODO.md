# TODO

## Utilities

* Debugging system for the language itself.
* REPL - (it would be very nice to allow multi-line commands).

## Code

* Get rid of excessive "debug" messages.
* Get rid of any `TODO` and `XXX`.

## Language-wise

* Improve error messages about compilation/syntax.
* Procs can be considered "higher order" or not?
* Should we be able to "append" new methods to already defined types?
* Profiling!

## Commands

* `assert`
* `test`? -- To create unit tests, maybe...
* `exit $exit_code` - quits the program with a numerical value (like
  "exit" from unix shells).

### Types and nodes

* Create native types, like "int" or "float".
* Create nodes, like SubList.
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
