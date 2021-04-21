# TODO

## Utilities

* Debugging system for the language itself.
* REPL - (it would be very nice to allow multi-line commands).


## Language-wise

* Run programs inside a *scheduler* (WIP).
* Error handling! Capture exceptions in D and reflect it as
  ExitCode.Failure in Til.
* User-defined search path for dynamic libraries.

### Error handling

Initial conception:

```tcl
proc remove (filename) {
    on_error (e) {
        # If not found, it's already removed, so it's okay:
        if (<$e code> == $file_not_found) { return }
        
        # If it's another error, pop it to the caller to
        # decide what to do:
        throw $e
    }

    shell.rm $filename
}
```

If an error occurs inside the current scope, `on_error` is "called" and
it's scope will be considered instead of the previous one (so that the
programmer can choose to return a "neutral" ou "default" value, for
example, or throw the error up in the call stack).

## Commands

* `exit $exit_code` - quits the program with a numerical value (like
  "exit" from unix shells).
* `list a b c` → `(a b c)`.
* `type` → :Atom/:String/:List/:ExecList/:SubProgram (so we can have some
  type of "pattern matching" using `case`.
