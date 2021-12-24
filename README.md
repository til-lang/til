# Til

Just another programming language.

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
set x [math (1 + 2 + 3 + 4)]
print $x
# 10

# Contrary to Tcl, "{}" enclosed things are
# NOT strings, but simply a "SubProgram".
# They are parsed as any other part
# of the language, just not
# immediately run.
if ($x > 7) {
    print "Great! $x is greater than 7."
}

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

# We also have dictionaries!
set d [dict (a 1) (b 2) (c 3)]

# Values can be extracted using Til extraction syntax:
print <$d a>
# 1

# Extraction syntax is used to get values from lists, too:
set lista (a b c d e)
# by index:
print <$lista 0>
# a

# by range:
print <$lista 1 4>
# b c d
```

See more in the `examples/` directory.
