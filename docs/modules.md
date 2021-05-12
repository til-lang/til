## Creating your own modules

In order to write your own module you must have, installed in your system:

* The DMD compiler, v2.095.0 or higer;
* Dub, the D package manager.

First, create your new Dub project:

```bash
$ dub init .
```

And add "til" as a dependency. Your `dub.sdl` file should look like this:

```sdl
name "my-til-module"
description "Your module description"
authors "Your Name"
version "0.1.0"

targetType "dynamicLibrary"
dependency "til" version="<til-last-version>"
```
