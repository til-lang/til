# TODO

* Should commands return SimpleList or a sequence?????????
* Some ListItem methods should try to **resolve into commands** before
  throwing Exceptions.
    * `.to<type>` -> `"to_<type>"`
* Could we get rid of `Object.type`?
    * Probably not, unless we disallow operations between types.
* strings
    * multi-line strings
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

```tcl
type context_manager {
    proc init (name) {
        return [dict (name $name)]
    }
    proc open (d) {
        set $d open true
    }
    proc close (d error) {
        set $d open false
    }
}

* Vectors!
    * bytes, first, to act as generic non-encoded strings.
    * integers
    * floats

scope "context manager test" {
    with cm [context_manager "teste"]
    # with: gets the context_manager instance,
    # calls .open right away,
    # and attribute the instance to $cm.

    ...

    # Also, errors are resolved by local on.error.
}
# call "close $cm" when the scope ends.
```

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
