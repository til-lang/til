# Til

A better Tcl. :)


## Example

```tcl
import std.io as std
import std.math as math

# Most of the syntax is the same as Tcl, except
# we have "simple lists" using "()":
set x [math.run (1 + 2 + 3 + 1)]
std.out $x
# → 7

# Contrary to Tcl, "{}" enclosed things are
# not strings, but simply a SubProgram.
# They are parsed as any other part
# of the language.
if ($x > 6) {
    std.out "Great!"
}

# Til implements the concept of "streams", almost
# like stdin/stdout in shell script.
import std.posix as shell

shell.ls | foreach (filename) {
    std.out $filename
}
```


## Objectives

This language must be simple, easy to use and, above all things,
**pleasant to use**, to the point that coming back to an old project after
2 years without touching it feel like a simple and totally manageable
task.


## Plans

1. Make the basics usable: (flow control, loops, ranges, stack
   manipulation, introspection, etc)
1. Improve the implementation (better use of Pegged features, specially)
1. ~Allow **dynamic loading** of libraries (compiled as shared object
   files)~
1. Implement **Actor Model**
1. Integrate properly with **Tk** or other good cross-platform GUI library
1. Make code execution faster (without byte-compiling)
