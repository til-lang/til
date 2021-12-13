---
layout: default
title:  "New streams"
author: cleber
categories: [ releases ]
tags: [ releases, 0.6 ]
description: "About new streams system on 0.6 release"
---

# 0.6.0: new streams system

Until now, *streams* was something running kind of outside the "normal"
way values were passed around inside Til VM. The results were also awful,
since commands that generated data could also return values (that is, push
them to the stack), and these values would end up "hanging around" in the
stack whenever they was called in the middle of a Pipeline, so I was
forced to "zero" the stack at end of each one - a very "patchy" approach.

Now, if your command want to pass along "continuous" data, as lines from
a file, bytes from a socket or messages from a queue, it must implement an
"iterator" (I'll probably improve on that name) that is going to be pushed
to the stack. Then, `Pipeline.run` is going to make sure that
`context.hasInput` is `true`, so the next command can decide what to do.

Ignoring `context.hasInput`, from the point of view of the next command,
the iterator seems just like any other argument, being the last to be
passed to the command and, therefore, the last to be popped from the
stack.

In some cases, it's vital to check for `hasInput`. `spawn` is a good
example: if the command ignore this flag, how is it going to decide if the
last argument is an iterator or is actually an argument to be passed to
the command being spawned?

An iterator is a regular ListItem (or simply `Item`) and must implement
a method `CommandContext next(CommandContext)`. Each new item from the
current iteration must be pushed to the stack and the `exitCode` may be
`Continue`, indicating there **is** a new item pushed to the stack and
that the next command in the pipeline should also "continue" iterating or
`Break`, meaning the end of the iteration was reached.

**I really liked this new approach**, as it seems more fit with the
workings and idioms of the rest of the VM while also easing the process of
creating a new iterator class (now you only need to implement **one**
method).

## No more pushing data

There was a special command that made me specially discomfortable:
`write`. In Til, data should be always **pulled**, not pushed. But when
running a procedure "in background" in the middle of a Pipeline, you would
like to write things into the next pipe, right? And trying to implement
that in such a way that things would behave kind of in the same way as if
you were implementing a stream in the old way (with ranges), I ended up
creating a special "process i/o range" that would allow the background
process to write one item and forced it to wait until it was consumed by
the pipeline in the original process.

Well, **no more**. Now, if you spawn a new process, the output of this new
one will be **a Queue**.

### "Run in background"

Previously I had added a `&` token that, being present in the end of
a Pipeline, would indicate that it should be run "in background", that is,
scheduled in another Process in the Scheduler. The sole purpose was to
make it a little easier to use Til-defined procedures in the middle of
Pipelines.

I didn't enjoy that syntax change very much, since the idea of Til is
being a "command language", without much syntax to be learned. Also, the
presence of "pipes" plus a `&` sign makes it **way too much** similar to
Shell Script, something that may be wise to avoid for now (some people
seems to understand "*being an alternative to Shell Script*" as an
objective of the language, and that is not the case).

Also, this notion of "in background" **kinds of** clouds the concept of
the Scheduler, and I think it's nice to have this later concept very clear
in the programmers minds (see how difficult it is for some Python
developers to grasp the concepts of `async` in Python...).

I started all this bunch of changes by trying to make a Til-defined
procedure in the middle of two pipes to *automatically* run "in
background", but now I see how detrimental it may be for the clarity of
the whole program, specially now that new processes **do not share** the
main process input and output (I'm playing with this concept of making the
"main process" a place with some specific purposes for the programmer).

Now this kind of thing is the role of `transform`. If you have Til-defined
procedures you want to use in your pipelines, you must call them using
`transform` and yes, for now we're going to live with that. In the end,
I **really** want to incentivise programmers to create their modules **in
D, not Til itself**, so the language is not going to become that much more
complicated to try to mimic in Til everything that can be done in D.

## Simplicity and next steps

I'm happy that I was able to get rid of **a lot** of code and, overall,
the language (I mean, *the implementation* of the language) has become
more simple and easy to understand.

For the next step, my plan is to work on the **object orientation
support** of Til. Initially I was tempted to not go this route, but (i)
I really enjoy programming with classes and objects and (ii) **that's
inevitable**. If I'm not the guy doing that, someone else will be. So
I prefer to implement that now and avoid the proliferation of too much
alternatives, that I also see as detrimental to the whole "ecosytem" of
any language.
