# Questions

## Open

* Is it possible for an external package to add commands to native types?
    * Use case: string handling and vectors.
* Procs can be considered "higher order" or not? Do they need to?
    * How could I write a `map` proc?
* Should procs also act as delegates?
    * It's kinda easy to save a reference to the escopo/process...
    * But do we **want** that? It seems confusing for most programmers.
    * And makes the code more complex.

## Answered

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
