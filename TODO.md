# TODO

## Low hanging fruits

* collect: `set content [exec cat $file_path | collect]` - ?

## A little more complex ones

* `--version` CLI option.
* Improve **string handling**!
* Make the REPL a command.
    * `repl $prompt_string $handler_command`
    * Don't execute the input, just pass that to the handler command.
    * Allow to configure the prompt while using it, like changing the
      prompt string.
* Print `Process.description` for each process in the "stack" when an
  error occur and is not handled.
* Use `scope` to create unit tests:

```tcl
scope "conversion to float" {
    assert ([to.float "1.23"] == 1.234])
}

"conversion to float": assertion failed: 1.23 (float) == 1.234 (float)
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
