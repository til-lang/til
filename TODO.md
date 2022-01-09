# TODO

* set sorted [sort $list]
* if ([contains $list item]) { ... }
* test (?) -- To create unit tests, maybe...

```tcl
test "conversion to float" {
    assert ([to.float "1.23"] == 1.23])
}
```

## Language-wise

* Procs can be considered "higher order" or not? Do they need to?
* Should we be able to "append" new methods to already defined types?
* Profiling!

### File system

* Python's `PosixPath`-like object, with related methods.
    * Specially  `open`, so we can, you know... open files.
