# The Second Great Simplification of Til

I want Til to be again "easy to embed" in any C program so that I can make
good use of any "big lib" without relying on thousand-lines
kind-of-abandoned wrappers written in D.

By "big lib" I mean, for now, **Tk**. I **really** want to have
a `til-tcl` and `til-tk` soon, but my only hope of doing that is using D's
`importC`.

gRPC is another interesting use case I may be using in the future: it
would be lovely to be able to use Til to facilitate my life, but gRPC has
its "languages of choice" and implementing it on a new one, like D, means
**a lot** of effort and a lot of time of maturing for the new libraries to
be production-ready. So I can cut some corners by embedding a Til program
inside a C/C++ one for now.


So I eliminated the async part of Til, specially after I realized that,
curiously, it could be implemented **easily** as a library: the basis of
that is a `AsyncPipeline` class inheriting from
`til.nodes.pipeline.Pipeline` that **yields** after the end of
`super().run`. And the old commands, like `spawn` and all the Pid methods.

Queues are gone, too. I'm publishing that as a separate package, because
anyone could implement such a thing using a SimpleList using Til itself,
so I deemed it as "not atomic enough" to be native to the language.

These two main changes simplified the language a lot and now it became an
easier task to create some C bindings. I'm planning to publish a Tcl
library to run Til code very soon!
