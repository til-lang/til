# TODO

## Questions

* Should commands return SimpleList or sequence?
    * Answer: SimpleList, because it has extractions and methods.
* Could we get rid of `Object.type`?
    * Probably not, unless we disallow operations between types.
    * Should we disallow operations between types?
* Procs can be considered "higher order" or not? Do they need to?
* Should we be able to "append" new methods to already defined types?
* Should procs also act as delegates?
    * It's kinda easy to save a reference to the escopo/process...

## Low hanging fruits

* collect: `set content [exec cat $file_path | collect]`
* Some command to list currently available commands.
* Some command to list all currently set variables.

## A little more complex ones

* Print `Process.description` for each process in the "stack" when an
  error occur and is not handled.
* test (?) -- To create unit tests, maybe...

```tcl
test "conversion to float" {
    assert ([to.float "1.23"] == 1.23])
}
```

* Step-by-step debugging.
* Profiling!

### "script" support

* "script" scope, maybe?
    * Let's make it **real** easy to create "subcommands"
    * `myproject.til users add`
* Support for common flags
    * `-h / --help`
    * `--version`
    * `--usage`
        * Getting command line flags/options should be trivial

## Quite some work

* Python's `PosixPath`-like object, with related methods.

```tcl
scope "work with files from some directory" {
    with dir [directory $path]
    with file [open $dir $file_name]

    range $file | foreach line {
        print $line
    }

    glob $dir "*.til" | foreach file_name {
        with file [open $dir $file_name]
        set content [read $file]
        print "$file_name content: $content"
        print "---"
    }
}
```

* Decimal type!

```tcl
# Draft:
set a [dec 1.200]  # decimal with 3 digits mantissa
set b [dec 2.300]
print [math ($a + $b)]
# 3.500
```

* Vectors!
    * bytes, first, to act as generic non-encoded strings.
    * integers
    * floats
* JSON
    * Save `.representation` together with native types, maybe.
    * extract: allow `jq` syntax: `<$json ".data.entries[0].id">`
* curl
* Jinja-like templates
* protobuf
* gRPC

