# TODO

* push $list x
* set x [pop $list]
* push.front $list x
* set sorted [sort $list]
* set new_list [cat $list_1 item $list_2]
* if ([contains $list item]) { ... }
* test (?) -- To create unit tests, maybe...

```tcl
test "conversion to float" {
    assert ([to.float "1.23"] == 1.23])
}
```

## Utilities

* Debugging system for the language itself.
* REPL - (it would be very nice to allow multi-line commands).

## Language-wise

* Should we act like a shell and run system commands automatically???
* Improve error messages about compilation/syntax.
* Procs can be considered "higher order" or not?
* Should we be able to "append" new methods to already defined types?
* Profiling!

### File system

* Python's `PosixPath`-like object, with related methods.
    * Specially  `open`, so we can, you know... open files.
