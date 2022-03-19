## Creating your own packages

In order to write your own package you must have, installed in your system:

* The LDC2 compiler, version 1.26.0 or higher;
* Dub, the D package manager.

## Real world example

See [til_exec](https://github.com/til-lang/til-exec) package.


## Dub init

First, create your new Dub project:

```bash
$ dub init .
```

And add "til" as a dependency. Your `dub.sdl` file should look like this
(I´ll use the name "teste" for the package, but you should choose a more
adequate one):

```sdl
name "til_teste"
description "Your package description"
authors "Your Name"

dependency "til" version="~>0.3.0"
targetType "dynamicLibrary"
dflags "-L-L$LIBTIL_PATH" "-L-ltil"
```

Note that it´s very important that **your package name be prefixed with
`til_`**. The end result should be a file in the format
`libtil_<your_package_name>.so`.

Also, note that you must set an environment variable called `LIBTIL_PATH`,
that is the path where the `libtil.so` library you're going to use is
located.

## Your package code

You can write your package code in `source/app.d` (Dub creates it
automatically for you). Start with the following example:

```d
import std.stdio;

import til.nodes;


extern (C) CommandHandlerMap getCommands(Process escopo)
{
    CommandHandlerMap commands;

    commands["test"] = (string path, CommandContext context)
    {
        Items arguments = context.items;
        foreach(arg; arguments)
        {
            writeln(arg);
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    return commands;
}
```

The package `til.nodes` includes everything you´ll need: CommandContext,
Process, all internal "types" (Atom, String, Dict and so on) and even
`std.conv : to` and some very commonly used things. See
`source/til/nodes/package.d` file to know more.

## Build

Simply ask Dub to build your package:

```bash
$ dub build --compiler=ldc2
```

After building it, there should be a file named `libtil_teste.so` in your
project directory.


## Test file

Now let´s write a simple test file in Til so you can load your package and
see it working:

```tcl
teste.test alfa beta gama delta
```

Save it as "test.til"

## Run!

To allow Til to find your new package while developing it, you must export
a `TIL_PATH` environment variable. Inside your project directory, run:

```bash
$ export TIL_PATH=$PWD
```

And, after that, call Til interpreter to run your test script:

```bash
$ dub run -b release til:run -- test.til
```

The expected output would be:

```
alfa
beta
gama
delta
```

(Some debugging info can be presented to you, but that is sent to
`stderr`.)

## Using your package as a command

If you want your package´s users to be able to simply call `teste` (that
is: your own package name) as a command in Til you can simply name the main
command `null`, like this:

```d
    commands[null] = (string path, CommandContext context) ...
```

If you want **both** things (a named command in the package and the call to
the package itself), you can create this kind of "alias":

```d
    commands["test"] = (string path, CommandContext context) ...
    commands[null] = commands["test"];
```
