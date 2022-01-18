# TODO

* Should commands return SimpleList or sequence?
    * Answer: SimpleList, because it has extractions and methods.
* Could we get rid of `Object.type`?
    * Probably not, unless we disallow operations between types.
    * Should we disallow operations between types?

* test (?) -- To create unit tests, maybe...

```tcl
test "conversion to float" {
    assert ([to.float "1.23"] == 1.23])
}
```

* Vectors!
    * bytes, first, to act as generic non-encoded strings.
    * integers
    * floats

* Decimal type!
* JSON
    * Save `.representation` together with native types.
* curl
* Jinja-like templates
* protobuf
* gRPC

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
