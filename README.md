# Til

A command language. 

https://til-lang.github.io/til/


## Some examples

```tcl
# Most of the syntax is the same as Tcl:
set a 1
set b 2
print "$a $b"
# 1 2

# But with some new features
set (a b) (1 2)
print "$a $b"
# 1 2 

# Til has "simple lists", using "()":
set lista (1 2 3 4)

# And can work with infix notation:
set x $(1 + 2 + 3 + 4)
print $x
# 10

# Infix notation is a syntatic sugar:
# $(1 + 2 + 3 + 4) -> [+ 1 2 3 4]
# $(1 + 2 * 3 - 4) -> [- [* [+ 1 2] 3] 4]
# (And, no, there's no "precedence" besides
# simple left-to-right order of appearance.)

# Infix notation is also implemented as a command:
set operation (1 + 1)
infix $operation | as result
# (It's handy to send operations as arguments, for example.)

# Til also values *comfort*, and offer
# some ways to avoid nesting braces:
# Instead of `set y [list $a $b]`,
list $a $b | as y
print $y
# (1 2)
# Instead of `range [length [list 1 2 3]] | foreach`,
list 1 2 3 | length | range | foreach x { print $x }
# (1 2 3)       3    range 3  ...

# Unlike Tcl, "{}" enclosed things are NOT strings,
# but simply "SubPrograms".
# They are parsed as any other part of the language,
# just not immediately run.
if ($x > 7) {
    print "Great! $x is greater than 7."
}

# (Oh, and comments are **real** comments!)

# Til implements the concept of "streams", almost
# like stdin/stdout in shell script.
range 1 5 | foreach x { print $x }
# 1
# 2
# 3
# 4
# 5

# You can "transform" values from the stream before consuming them:
range 1 5 | transform value {
        return [math ($value * 2)] 
    } | foreach x {
        print $x
    }
# 2
# 4
# 6
# 8
# 10

# Til values your comfort, so there's syntatic sugar for both
# transform and foreach:
range 97 99 | { to.ascii } | { print }
# a
# b
# c
# This is the same as:
range 97 99
    | transform x { return [to.ascii $x]}
    | foreach x { print $x}
# Or, using ".inline" commands:
range 97 99
    | transform.inline { to.ascii }
    | foreach.inline { print }
# (The sugar consists in calling both commands above, actually.
# For all intents and purposes, both options are the same thing.)

# We also have dictionaries!
dict (a 1) (b 2) (c 3) | as d

# Values can be extracted using Til's **extraction** syntax:
print <$d a>
# 1
# It makes it easier to write conditions, for instance:
if (<$d a> == 1) { print "yes, it's 1!" }

# Extraction syntax is used to get values from lists, too:
set lista (a b c d e)
# by index:
print <$lista 0>
# a

# by range:
print <$lista 1 4>
# (b c d)

# And the extraction itself is implemented as a command:
extract $lista 1 4 | range | foreach item { print $item }
# b
# c
# d
```

See more in the `examples/` directory.
