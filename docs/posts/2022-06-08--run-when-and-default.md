# run, when and default commands

One collateral effect of changing the conditions of `if` from a SimpleList
(and, therefore, from a delegational style) to an actual boolean value
(that is: evaluating eagerly using the language itself) is that the old
way of doing if/else-if/else will end up evaluating **every** condition
before actually running the `if` command. See:

```tcl
if [very_slow_proc] {
    do something
} else if [another very slow proc] {
    do other thing
} else if [yet another slow proc] {
    do yet another thing
}
```

(Remember that using `$()` of `[]` is basically the same thing. The first
is syntatic sugar for the second.)

Also, it's counter-intuitive: the programmer is easily deluded by the
sensation that `if` is syntax, not a command, thinking that the ExecLists
(`[]`) **won't** be executed, when in fact they will.

Besides, **I never really liked the way this structure looks**. Thinking
about language design, it's simply a lot of noise. Thinking about language
implementation, it's also a lot of noise: the `if` command demands an
internal loop and asserts for the `else` string, that, again, is not
syntax, but simply an Atom passed as yet another argument. (I'm even
thinking about getting rid of the `else if` option.)


Seeing this effect, I was thinking that maybe the change was an error, but
at the same time going to a path with the language where it can be less
delegational and more reliant on the language features itself seems to be
a good thing, so I started thinking about alternatives.

The solution was to think about the if/else-if/else structure as some sort
of "guard clauses", like "*when this is true, do one thing, but when that
is true, do that other thing*", in a mutually exclusive way.

The way to go was to create a command that evaluates a condition and, in
the case it's true, **auto-return**.

Except that `ExitCode.Return` is a chain reaction and must be contained
somehow, or the programmer would be forced to use this new command always
inside a `proc`, and that would be uncomfortable and extremely
undesirable.

What was needed was a command that simply ran a SubProgram in its own
scope and contained the `Return`, turning it into a `ExitCode.Success`.
`scope` was not the solution, since it's not supposed to contain returns.
So I came up with the `run` command:

```tcl
run {
    # This scope will return:
    return
}
# But THIS scope won't!
```

Next, the "guard clauses". `when` is a command with two parameters:
a boolean value (that you'll probably want to generate with `$()` or `[]`)
and a SubProgram (`{}`) that, if the first one is true, will not only run
this SubProgram **but also auto-return** (so the only possible `ExitCode`
are actually `Success` and `Failure`):

```tcl
proc p (x) {
    when $($x == 0) {
        print "this proc will return"
    }
}
```

This, altogether with `run`, allows a better looking if/else-if/else
structure:

```tcl
run {
    when $($x == 0) {
        do0
    }
    when $($x == 1) {
        do1
    }
    when $($x == 2) {
        do2
    }
}
```

And **now** we have a good reason for the existence of the `default`
command: because the `else` part of the above structure now is simply
"just staying in the scope", and that is **ugly**, unfortunately:

```tcl
run {
    when $($x == 0) {
        do0
    }
    do_other_thing
}
```

The programmer would be tempted to always comment the "else" part with
a `# else:` or something similar. Again: ugly. So the `default` comes in
handy:

```tcl
run {
    when $($x == 0) {
        do0
    }
    default {
        do_other_thing
    }
}
```

`default` has no conditions, always executes and, specially, **also
auto-returns**. So after a `default` command, no other command is actually
being executed on that scope.
