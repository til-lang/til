# autoclose and Processes I/O

## Context managers with autoclose

While implementing `til-file` I realized how awkward using the `with`
command was. I'm not a big fan of using "token words" for commands (that
is: words that are pure syntax, with no real purpose or value), so `with`
ended up being `with <name> <context_manager_instance>`. And you know
what? I was writing my tests of `til-file` using
`with <context_manager_instance> <name>` everywhere...

After some Hammock Time I realized there's a **much better way** of
working with context managers, one that does not create "new syntax" and,
specially, make use of the commands that already exist (because, you see,
`with` was setting a variable in the context, as if having `set x` **and**
`something | as x` was not enough): the `autoclose` command.

This command pops one argument from the stack, configures the current
context and pushes it back (what we actually achieve with a `peek`, that's
cheaper). Since it's being pushed back, it's **very** easy to use it in
a pipeline like this:

```tcl
open.read $path | autoclose | as file
```

Or even:

```tcl
autoclose [open.read $path] | as file
```

It won't work as intended, though, if used inside an ExecList, since they
have their own sub-scope:

```tcl
# Avoid calling autoclose inside an ExecList:
set file [open.read $path | autoclose]
```

In the case above, the file will be opened and immediately closed, so that
`$file` will contain an already closed file...

### Every scope calls "autoclosed" context managers

At first I implemented the calls to "`contextManager.close`" in the
`scope` command implementation itself. It was enough for validating the
concept, but it would be weird to not allow context manager to be used
**inside procedures**, for instance. Or even in the MainProcess itself.

So now every call to `Process.run` will call the scope.contextManagers
"close" command. That encompasses any SubProgram, including the
MainProcess scope.

## Processes I/O

One thing I'm trying to achieve is **simplicity**, both in Til as
a language as in the implementation itself.

Previously, each Process had it's own `.input` and `.output` properties,
just like Unix-style processes. I did that because it just felt natural.
But the results, in the end, were increased complexity: it wasn't obvious
when a Process expected to read something from its input, for instance,
since the presence of an input was itself too implicit.

From the implementation part, the command names were all over the place:
read/write were actually pop/push, since any sub-Process had Queues as
input/output, and there was the `.no_wait` version of each. The D code had
a lot of kind-of-unnecessary-and-complex `if/else` structures (the main
villain I always try to avoid), some ad-hoc class definitions, etc.
I never liked that corner of the code, to be honest.

Also, making sub-Processes inputs and outputs Queues was a good idea, but
the MainProcess would have it's own classes and differentiating between
each was also kind of a pain.

The question I asked myself, then, was: *do we really need it?* If
sub-Processes inputs and outputs were all Queues, couldn't we live without
it and simply send queues **explicitly** to spawned code we want to
communicate with?

**Sure!** And that's how it works, now: everything is explicit: if you are
going to spawn a new Process and want to send and/or receive data from it,
you should pass a Queue to do that. This way it becomes obvious by the
parameters list of the to-be-spawned `proc` that it's going to use one or
more Queues as a way of communication with other processes.

(Yeap, it resembles the "channels" concept. Well, good thing I'm not alone
in this way of doing things, at least...)

## Deprecation warnings

There was a good reason to make every command an object: now we can mark
some of then as `isDeprecated = true` and then every time a user calls it,
a warning is sent to stderr saying:

`Warning: the command `with` is deprecated`
