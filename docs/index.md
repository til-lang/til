## A command language on top of D

Til is a **command language**, like [Tcl](https://www.tcl.tk/), built
on top of [D](https://dlang.org/), so it kind of has a foot in both
worlds.


Being a command language means it is **easy to learn** and the syntax is
very extensible. And being built with D means it is **very simple to build
new modules** for it.


Til makes use of **Fibers** so the interpreter is **async by default** and
spawning a new *process* ("process" not in the OS sense, but in the
**Erlang** sense) is trivial.

And, finally, Til has **data streams** that allow you to process data
using a (hopefully) familiar concept: **pipes**.

## So, in brief, Til is

* an **interpreted** and **dynamic** command language;
* loosely based on **Tcl**;
* built with **D**;
* easily extensible;
* async by default.

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
import std.io as io

set s "Hello, World!"
io.out $s
```

The snippet above will print `Hello, World!` using the `std.io` builtin
package. Til has the concept of **Atoms**, so in `set s "Hello, World!"`
we have 2 Atoms (`set` and `s`) and 1 String (`"Hello, World!"`). And in
`io.out $s` we have, again, 2 Atoms (`io.out` and `$s`), being the second
one a Substitution Atom, that is, an Atom that, when **evaluated**,
returns the value stored in the current context with name `s`.

### ExecLists, auto-import, Math and String substitutions

```tcl
set a 11
set b 22
set result [math ($a + $b)]
io.out "The result is $result"
```

The snippet above will print `The result is 33`. The first new concept is
the use of square brackets (`[]`). They form what we call an ExecList.

An ExecList contains any SubProgram and **are evaluated immediately**,
that is, the SubProgram is executed before the command (in this case,
`set`) is run. So, when saying `set result [math ($a + $b)]`,
`math ($a + $b)` will be executed and the result (`33`) will become the
last argument of the `set` command, becoming `set result 33`.


But where `math` came from? Well, it´s not a builtin command of the
language (although the language **has** some builtin commands), but,
instead, is a **module** whose complete name is `std.math`. When Til
interpreter faces an unknown command name it tries to import a proper
module automatically, so you don´t need to clog every program header with
a lot of `import` statements.


And, besides that, **a module can be called as a command**. `std.math`,
for instance, implements a `run` command, but also can be called simply as
`std.math` (or `math` if you´re using it as an alias). That´s because lots
of modules have a very, very, common usage to the point where forcing
developers to always use a "qualified name" feels simply wrong. And
boring.

An interesting example is the `std.dict` module. It´s main purpose is
inevitably going to be to **create new dictionaries** ("dict" in the
Python sense: it´s like an "associative array" in D or an "object" in
Javascript). So that would feel boring to always call `dict.create`, like
in:

```tcl
import std.dict as dict
set d1 [dict.create (a "alfa") (b "beta") (c "gama")]
set d2 [dict.create (alfa 1) (beta 2) (gama 3)]
```

It´s much easier to simply write:

```tcl
set d1 [dict (a "alfa") (b "beta") (c "gama")]
set d2 [dict (alfa 1) (beta 2) (gama 3)]
```

**That´s the case for `std.math` module**: you don´t have to call
`math.run` every time, because that´s the main purpose of the module, so
simply calling `math` will do.


And, the last item in this session is **string substitution**. It works as
expected, really: you can reference values inside a string using the `$`
sign.

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
io.out "alfa is " <$d alfa>
# Output: alfa is 11
```

The `<>` syntax follows the pattern `<data index>` or `<data range>`. One
can retrieve elements from a list easily:

```tcl
set lista (a b c d e)
io.out "Second element is " <$lista 1>
# a
io.out "Fourth and fifth elements are " <$lista 3 5>
# (d e)
io.out "First element is " <$lista head>
# a
io.out "Tail is " <$lista tail>
# (b c d e)
io.out "Even-indexed elements are " <$lista (0 2 4)>
# (a c e)
```

This makes the code much cleaner and easier to understand. The example
from LMDB could be written this way:

```tcl
proc cmd_push {fd argv dir} {
    if {list.length <$db <$argv 1>> > 0} {
    ...
```

## Procedures, SubLists and SimpleLists

```tcl
proc f (x y) {
    return [math ($x * $y)]
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

## Ranges, foreach, comments and Streams

The simplest example showing the use of streams is this `foreach` that
prints the current number from a range of some integer numbers:

```tcl
range 3 | foreach x {
    io.out $x
}

# The expected output is:
# 0
# 1
# 2
# 3
```

(Yup, `range` **will** include the "limit" -- "3" in this case.)


`range` is a very versatile command (it´s actually the **module**
`std.range`) that allows you to create various kinds of ranges and even
transform a SimpleList into a data stream.

**Data streams travel through pipes** (`|`) and various commands connected
by pipes are called a **Pipeline**.


The rules governing the use of data streams are these:

* if you can easily predict the number of items, use common parameters;
* if you have no idea how many items there are, use streams.


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
    set origin headers data $item
}
```

That is because the `set` command can be used to "destructure"
a SimpleList:

```tcl
set a b c (1 2 3)
```

## Spawning processes, messages and backpressure

```tcl
proc ping (target) {
    receive | foreach msg {
        send $target $msg
        break
    }
}

proc pong () {
    receive | foreach msg {
        io.out "Received $msg"
        break
    }
}

set writer_process [spawn pong]
set sender_process [spawn ping $writer_process]

send $sender_process "a message and exited"
```

The expected output of this program would be:

`Received a message and exited`

The summary of what happened is as follows:

* `ping` procedure is defined;
* `pong` procedure is defined;
* A `pong` process is spawned and its **Pid** is stored into
  `writer_process` variable;
* A `ping` process is spawned and its Pid is stored into `sender_process`
  variable;
* The main process sends a message `"a message and exited"` to
  `$sender_process`, that is the Pid of the `ping` process, **and quits**.
* The `ping` process receives the message, sends it to `$target` (that is
  the `pong` process), breaks the loop and quits.
* The `pong` process prints to standard output, breaks the loop and quits.

About **backpressure**: each process has a **message box** with limited
size. If your own process is trying to send a message to another one whose
message box is already full, **your process will be blocked**.

(It will block its execution, but not the *scheduler* itself, of course.
That is: other processes won´t be affected.)

## Includes

There is a core concept in Til that is: **every program is one file
only**. There is no "module" in the Python or Ruby sense, like an entity
that lives somewhere inside the interpreter´s memory. In Til your modules
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
in D** and share it as a module.

The rationale is going to be explained in more details in another article,
but for now it suffices to say that **Til is a scripting language** and
you are not encouraged to write much more than "a program" in it, that is,
it´s expected to be used as a "command and control" of other components,
not as the main language implementing algorithms or data structures.

## Error handling

See `examples/error-handler.til` and `examples/unhandled-error.til`.

## And more

In the Til repository, look for the `examples` directory.

## Building your own modules

See [Building your own module](modules).
