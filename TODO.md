# TODO

* BUG: `print [math (($x + 1) * 10)]`
* `object.Exception@source/til/process.d(79): <x> variable not found!`
    * Make it an context.error.
* improve extractions: get rid of SimpleLists as arguments
    * for list ranges, use a command, like `range $lista 0 5`
* strings
    * split
    * join
    * find
* regexps
* get the script's command line arguments

* test (?) -- To create unit tests, maybe...

```tcl
test "conversion to float" {
    assert ([to.float "1.23"] == 1.23])
}
```

* ExitCode.Skip
* Allow `transform` to skip
* Allow `foreach` to skip

* range 0 10 | zip [range 20 30] -> (0 20) , (1 21) , ...

* Jinja-like templates
* JSON
* protobuf
* curl
* Vectors!

## Language-wise

* Procs can be considered "higher order" or not? Do they need to?
* Should we be able to "append" new methods to already defined types?
* Profiling!

### File system

* Python's `PosixPath`-like object, with related methods.
    * Specially  `open`, so we can, you know... open files.
