[Blog](posts) | [Examples](https://github.com/til-lang/til/tree/master/examples)

---

## A command language on top of D

Til is a **command language**, like [Tcl](https://www.tcl.tk/), built
using [D](https://dlang.org/).


Being a command language means it is **easy to learn** -- the syntax is
restricted. And being built with D means it is **very simple to build
new packages** for it.


(But beware: [Til is very opinionated](opinionated.md).)


## So, in brief, Til is

* an **interpreted** and **dynamic** command language;
* loosely based on **Tcl**;
* built with **D**;
* easily extensible;

## Examples

### Variables

```tcl
set x 1
set y 2
set z 3
```

Sure, it´s a bit unusual to use "set" instead of the much more common
syntax `x = 1` and to many it may feel too strange but if you can overcome
this feeling you´ll see that it´s actually a very elegant way of
**setting** values in a **command** language.

You see, one of the goals of the language is to have a coherent and simple
enough syntax so that you´ll never be trapped in the "*but there is more*"
cycle -- instead, learn it once, learn it fast and expect **no surprises**
after that.

### Variables values and printing

```tcl
set s "Hello, World!"
print $s
```

The snippet above will print `Hello, World!`. Til has the concept of
**Atoms**, so in `set s "Hello, World!"` we have 2 Atoms (`set` and `s`)
and 1 String (`"Hello, World!"`). And in `print $s` we have, again,
2 Atoms (`print` and `$s`), being the second one a Substitution Atom, that
is, an Atom that, when **evaluated**, returns the value stored in the
current context with name `s`.

### ExecLists, Math and String substitutions

```tcl
set a 11
set b 22
set result [+ $a $b]
print "The result is $result"
```

The snippet above will print `The result is 33`. The first new concept is
the use of square brackets (`[]`). They form what we call an ExecList.

An ExecList contains any SubProgram and **are evaluated immediately**,
that is, the SubProgram is executed before the command (in this case,
`set`) is run. So, when saying `set result [+ $a $b]`, `+ $a
$b` will be executed and the result (`33`) will become the last
argument of the `set` command, becoming `set result 33`.


The last item in this session is **string substitution**. It works as
expected, really: you can reference values inside a string using the `$`
sign.

## Infix notation

Til cares about your *comfort*, so you don't have to work with prefix
notation! Instead of writing

```tcl
set result [+ $a $b]
```

you can write

```tcl
set result $($a + $b)
```

Til tries to **avoid creating new syntax** whenever possible, but this
kind of "sugar" makes the programmer's life **much** easier.

Notice that prefix notation is the default way of working in Til, since
it's a *command language*. What the `$()` does is simply to turn infix
into prefix notation.

Thus,

```tcl
$(t1 op1 t2 op2 t3 op3 t4)
```

will become

```tcl
[op3 [op2 [op1 t1 t2] t3] t4]
```

## Extractions

The following snippet come from [the first version of
Redis](https://gist.github.com/antirez/6ca04dd191bdb82aad9fb241013e88a8),
when it was still called LMDB:

```tcl
proc cmd_push {fd argv dir} {
    if {[catch {
        llength $::db([lindex $argv 1])
    }]} {
    ...
```

What is being said is "*if there is something in the in-memory database
slot whose key is given by the second item inside argv*". The problem is:
phew!, that´s a lot of commands, specially for so common operations.

In Til there´s the concept of **Extractions**:

```tcl
set d [dict (alfa 11) (beta 22) (gama 33)]
print "alfa is " <$d alfa>
# Output: alfa is 11
```

The `<>` syntax follows the pattern `<data index>` or `<data range>`. One
can retrieve elements from a list easily:

```tcl
set lista (a b c d e)
print "Second element is " <$lista 1>
# a
print "Fourth and fifth elements are " <$lista 3 5>
# (d e)
print "First element is " <$lista head>
# a
print "Tail is " <$lista tail>
# (b c d e)
print "Even-indexed elements are " <$lista (0 2 4)>
# (a c e)
```

This makes the code much cleaner and easier to understand. The example
from LMDB could be written this way:

```tcl
proc cmd_push {fd argv dir} {
    if ([list.length <$db <$argv 1>>] > 0) {
    ...
```

## Procedures, SubLists and SimpleLists

```tcl
proc f (x y) {
    return $($x * $y)
}
```

In this example you can see how new "functions" are declared. Technically
a *procedure* should not return a value but, you know... It´s so much
easier to follow some traditions -- for developers coming from Tcl the
`proc` syntax will feel very familiar, so we go with it.


The parameters list, `(x y)` is a **SimpleList**. That means its content
is not a SubProgram, but simply a list of "ListItems". This content is not
supposed to be executed as a program, but evaluated as a list.

Now, the procedure body **is** supposed to be executed at some time, so
it´s declared as being a **SubList**, that is, a list of commands that
represents a SubProgram. But, contrary to what happens with an ExecList,
**a SubList will not be executed immediately**.

You see, **Til is a command language**. So `proc` is, in the end, just
another command. It´s signature is `proc name parameters body`, in which:

* `name` must be an Atom;
* `parameters` must be a SimpleList;
* `body` must be a SubList.

So you must pass these "types" to the command or at least **something that
evauates to these types**. If you store a SubList into a variable named
`body` you could say:

```tcl
proc f (x y) $body
```

And that´s okay, too. If your parameters list is stored into another
variable, you also could say:

```tcl
proc f $parameters_list $body
```

And, finally, if your procedure name is also stored into a variable, you
coud also say:

```tcl
proc $procedure_name $parameters_list $body
```

As long as each variable represents an Atom, a SimpleList and a SubList,
you´ll be able to define a new procedure without any problem.

## Pipes

There's not much magic in pipes: basically, whatever is left on the stack
by the command on the left is kept there to be "consumed" by the command
on the right.

```tcl
list 1 2 3 | print
# (1 2 3)
```

A sequence of commands connected through pipes is called a Pipeline.

## Ranges, foreach, comments and Streams

The simplest example showing the use of streams is this `foreach` that
prints the current number from a range of some integer numbers:

```tcl
range 3 | foreach x {
    print $x
}

# The expected output is:
# 0
# 1
# 2
# 3
```

(Yup, `range` **will** include the "limit" -- "3" in this case.)


`range` is a very versatile command that allows you to create various
kinds of ranges and even transform a SimpleList into a data stream.

Any object that have a "method" `next` is considered a Stream. You can
even create your own:

```tcl
type my_generator {
    proc init () {
        return 0
    }
    proc next ($obj) {
        incr $obj
        if $($obj > 5) { break }
        continue $obj
    }
}

my_generator | foreach x { print $x }
# 1
# 2
# 3
# 4
# 5
```

### When to use a Stream?

The rules governing the use of Streams are these:

* if you can easily predict the number of items, use common parameters;
* if you have no idea how many items there are, use Streams.


So, for instance, if you want to *walk through a directory* you should use
a data stream, since you usually cannot guarantee how many entries there
are in the directory. And the same applies to data being received from
a socket or read from a file.

Interestingly, **foreach only works with data streams**. And it only
accepts one atom to name the current item. If your stream is composed of
SimpleLists (that is: if each item is composed of multiple values) you can
use **destructuring set** to store each one into a variable:

```tcl
my_stream | foreach item {
    # $item is (origin headers data)
    set (origin headers data) $item
}
```

That is because the `set` command can be used to "destructure"
a SimpleList:

```tcl
set a b c (1 2 3)
```

## Includes

There is a core concept in Til that is: **every program is one file
only**. There is no "package" in the Python or Ruby sense, like an entity
that lives somewhere inside the interpreter´s memory. In Til your packages
are only **commands providers** and any Til code you would want to include
into your program must be... **included** in your program.

Including a file has the same effect as copying its content and
pasting where the `include` command is called.

The syntax is:

```tcl
include "path/my_code.til"
```

You see, Til is a nice language, but **you´re not supposed to write
complex code in Til**. If you want to implement some algorithm, **write it
in D** and share it as a package.

The rationale is going to be explained in more details in another article,
but for now it suffices to say that **Til is a scripting language** and
you are not encouraged to write much more than "a program" in it, that is,
it´s expected to be used as a "command and control" of other components,
not as the main language implementing algorithms or data structures.

## Errors and error handling

```tcl
proc throw_error () {
    error "Test error"
}

proc on.error (x) {
    print "on.error:"
    print "  received: $x"
    print "  IGNORING IT!"
}

print "Calling procedure `throw_error`..."
throw_error
print "Procedure `throw_error` was called and the error was handled."
```

## Scopes

If you want to divide a long algorithm in different scopes but can't do
that using new procedures (for instance: when loading a lot of local
variables), you can create a new `scope`:

```tcl

scope "load all the necessary variables" {
    # load them all here
}

The new scope share variables with its parent, so they are still visible
when it closes, but don't share new procedures, so you can define them as
needed without messing with the parent scope -- it's useful if you have
many procedures with the same name but for different contexts

## And more

* [Til built-in types](types)

In the Til repository, look for the `examples` directory.

## Building your own packages

See [Building your own package](packages).
