# TODO

## Questions

* Should commands return SimpleList or sequence?
    * Answer: SimpleList, because it has extractions and methods.

* Why are commands (D) delegates???
    * Answer: basically because the way we implemented `proc`.
    * **FIXED!**

* Could we get rid of `Object.type`?
    * Probably not, unless we disallow operations between types.
    * **Should we disallow operations between types?**
* Procs can be considered "higher order" or not? Do they need to?
* Should we be able to "append" new methods to already defined types?
    * In some scenarios it could be nice, but in most cases it would tend
      to be simply confusing (methods all over the place).
* Should procs also act as delegates?
    * It's kinda easy to save a reference to the escopo/process...
    * But do we **want** that? It seems confusing for most programmers.
    * And makes the code more complex.

## Low hanging fruits

* Make **all** examples `assert` things instead of simply printing.
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

## Very important for 1.0

* Make sure it's **easy** to install and use external modules!
* Make sure it's **easy** to distribute external modules.
    * Allow modules to assert the interpreter's **version**, maybe?
* Make the language feel comfortable enough as a **shell** - we won't have
  many external modules, so it's important to make the best with available
  Unix tools.
