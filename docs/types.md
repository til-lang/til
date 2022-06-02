# Til types

## Numerical atoms

There are two types of numbers in Til: `IntegerAtom` and `FloatAtom`.

```tcl
set integer 123
set float 12.34
```

A `FloatAtom` is represented by a `float`, internally, while `IntegerAtom`
is a `long`.


An `IntegerAtom` can be defined with **units** and Til will apply the
appropriate multiplier for each one:

```tcl
set value 1k   # 1000
set value 1M   # 1000000
set value 1G   # 1000000000
set value 1Ki  # 1024
set value 1Mi  # 1048576
set value 1Gi  # 1073741824
```

Please note that units are only intended as **input facilitators** and are
not going to be carried around or displayed anywhere.

## NameAtom

```tcl
set this_is_a_name_atom 0
```

## SubstAtom

It's defined by using a `$` token right before the name and indicates
a substitution by an available name:

```tcl
set x 10
io.out $x
```

## Strings

There are two kinds of strings in Til: a `String` is merely a sequence of
characters, while a `SubstString` has "substitutions" inside it on
definition:

```tcl
set string "a simple string"
set subs_string "this string contains ($string) and is a SubstString"
```

## Dictionaries

A `Dict` holds a relation of keys and values and is created with the
`dict` command.

You can extract its values using an `Extraction` and set values using
a proper `set` command, where the first argument is the dict you want to
update:

```tcl
set d [dict (a 11)]  # "a" value is going to be `11`
io.out <$dict a>     # Prints `11`
set $d (b 22) (c 33) # Set values for new keys "b" and "c"
io.out <$dict b>     # Prints `22`
```

And you can `unset` values, too:

```tcl
set d [dict (a 11) (b 22)]
unset $d a  # Now $d has only a "b" key
```
