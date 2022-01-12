# TODO

* Is `{}` a valid SubList? And `{ }`???
* improve extractions: get rid of SimpleLists as arguments
    * for list ranges, use a command, like `range $lista 0 5`
* strings
    * special characters, line newline and tab.
    * multi-line strings
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

* Decimal type!
* JSON
    * Save `.representation` together with native types.
* Jinja-like templates
* protobuf
* curl
* Vectors!

## Language-wise

* Procs can be considered "higher order" or not? Do they need to?
* Should we be able to "append" new methods to already defined types?
* Profiling!

* Should procs and variables occupy the same namespace?

```
set l (1 2 3 4 5)
proc f (x) {}

# Higher order procs:
set fcopy $f
fcopy 7
map $f $l
fold $f $l 1

# Other possibilities:
f 9  # Just call the proc
l | foreach x {}  # Make $l a range???
```

* Being higher order, should procs also act as delegates?

### File system

* Python's `PosixPath`-like object, with related methods.
    * Specially  `open`, so we can, you know... open files.
