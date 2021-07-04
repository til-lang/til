# Til

Just another programming language.


## Example

```tcl
# Most of the syntax is the same as Tcl, except
# we have "simple lists" using "()":
set x [math (1 + 2 + 3 + 1)]
print $x
# → 7

# Contrary to Tcl, "{}" enclosed things are
# NOT strings, but simply a "SubProgram".
# They are parsed as any other part
# of the language, just not
# immediately run.
if ($x > 6) {
    print "Great!"
}

# Til implements the concept of "streams", almost
# like stdin/stdout in shell script.
range 1 5 | foreach x { print $x }

# We also have dictionaries!
set d [dict (a 1) (b 2) (c 3)]

# Values can be extracted using Til extraction syntax:
print <$d a>  # prints "1"

# Extraction syntax is used to get values from lists, too:
set lista (a b c d e)
print <$lista 0>    # prints "a"
print <$lista 1 5>  # prints "(b c d e)"
```
