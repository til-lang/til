# TODO

## Questions

* Is it possible for an external module to add commands to native types?
    * Use case: string handling and vectors.

* Should commands return SimpleList or sequence?
    * Answer: SimpleList, because it has extractions and methods.
* Why are commands (D) delegates???
    * Answer: basically because the way we implemented `proc`.
    * **FIXED!**
* Should we be able to "append" new methods to already defined types?
    * In some scenarios it could be nice, but in most cases it would tend
      to be simply confusing (methods all over the place).
    * **No, let's keep things simple.**

* Could we get rid of `Object.type`?
    * Probably not, unless we disallow operations between types.
    * **Should we disallow operations between types?**

* Procs can be considered "higher order" or not? Do they need to?
    * How could I write a `map` proc?
* Should procs also act as delegates?
    * It's kinda easy to save a reference to the escopo/process...
    * But do we **want** that? It seems confusing for most programmers.
    * And makes the code more complex.

## Low hanging fruits

* collect: `set content [exec cat $file_path | collect]` - ?

## A little more complex ones

* Improve **string handling**!
* Make the REPL a command.
    * `repl $prompt_string $handler_command`
    * Don't execute the input, just pass that to the handler command.
    * Allow to configure the prompt while using it, like changing the
      prompt string.
* Print `Process.description` for each process in the "stack" when an
  error occur and is not handled.
* test (?) -- To create unit tests, maybe...

```tcl
test "conversion to float" {
    assert ([to.float "1.23"] == 1.23])
}
```

## Complex

* Step-by-step debugging.
* Profiling!

## Very important for 1.0

* Make sure it's **easy** to install and use external modules!
* Make sure it's **easy** to distribute external modules.
    * Allow modules to assert the interpreter's **version**, maybe?
* Make the language feel comfortable enough as a **shell** - we won't have
  many external modules, so it's important to make the best with available
  Unix tools.
