# Til

A better Tcl. :)


## Example

```tcl
import std.io as io
import std.math as math

# Most of the syntax is the same as Tcl, except
# we have "simple lists" using "()":
set x [math.run (1 + 2 + 3 + 1)]
io.out $x
# → 7

# Contrary to Tcl, "{}" enclosed things are
# not strings, but simply a SubProgram.
# They are parsed as any other part
# of the language.
if ($x > 6) {
    io.out "Great!"
}

# Til implements the concept of "streams", almost
# like stdin/stdout in shell script.
import std.posix as shell

shell.ls | foreach filename {
    io.out $filename
}

range 0 5 | foreach x { io.out $x }

# We also have dictionaries!
set d [dict (a 1) (b 2) (c 3)]

# Values can be extracted using Til extraction syntax:
io.out <$d a>  # prints "1"

# Extraction syntax is used to get values from lists, too:
set lista (a b c d e)
io.out <$lista 0>    # prints "a"
io.out <$lista 1 5>  # prints "(b c d e)"
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
