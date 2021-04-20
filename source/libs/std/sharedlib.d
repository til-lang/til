module libs.std.sharedlib;

import core.sys.posix.dlfcn;
import std.algorithm.iteration : map, joiner;
import std.array : split;
import std.conv : to;
import std.string : strip, toStringz;

import til.exceptions;
import til.logic;
import til.nodes;
import til.procedures;


CommandHandler[string] commands;
void*[string] sharedLibraries;


// XXX : should we return something?
void fnCall(void* lh, const(char*) functionNameZ)
{
    void function() fn = cast(void function())dlsym(lh, functionNameZ);
    const char* error = dlerror();
    if (error)
    {
        throw new Exception("dlsym error: " ~ to!string(error));
    }
    fn();
}

void lhUnload(string libraryName)
{
    void* lh = sharedLibraries.get(libraryName, null);
    if (lh is null)
    {
        throw new Exception(libraryName ~ " was not loaded");
    }

    dlclose(lh);
    sharedLibraries.remove(libraryName);
}

// ---------------------------------
// Commands:
static this()
{
    CommandContext callAlias(string path, CommandContext context)
    {
        // h.call "hello"
        // path = "h.call"
        // libraryPath = "h"
        // cmdName = "hello"

        string libraryName = path.split(".")[0];

        void* lh = sharedLibraries.get(libraryName, null);
        if (lh is null)
        {
            throw new Exception(libraryName ~ " was not loaded");
        }

        auto functionName = context.pop().asString;
        auto functionNameZ = functionName.toStringz;

        fnCall(lh, functionNameZ);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    }
    CommandContext unloadAlias(string path, CommandContext context)
    {
        // h.unload "hello"
        // path = "h.call"
        // libraryPath = "h"
        // cmdName = "hello"

        string libraryName = path.split(".")[0];
        lhUnload(libraryName);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    }

    commands["load"] = (string path, CommandContext context)
    {
        // sharedlib.load "libhello.so" as h
        auto libraryPath = context.pop().asString;
        auto libraryPathZ = libraryPath.toStringz;

        if (context.size != 2)
        {
            throw new Exception("Invalid number of arguments to `load`");
        }
        auto asWord = context.pop().asString;
        if (asWord != "as")
        {
            throw new Exception(
                "Invalid arguments to `load`."
                ~ " Usage: load \"libname.so\" as name"
            );
        }
        auto cmdName = context.pop().asString;

        // lh = "library handler"
        void* lh = dlopen(libraryPathZ, RTLD_LAZY);
        if (!lh)
        {
            const char* error = dlerror();
            throw new Exception("dlopen error: " ~ to!string(error));
        }

        sharedLibraries[cmdName] = lh;

        /*
        Now we make "cmdName.call" available to the user
        */
        context.escopo.program.commands[cmdName ~ ".call"] = &callAlias;
        context.escopo.program.commands[cmdName ~ ".unload"] = &unloadAlias;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["unload"] = (string path, CommandContext context)
    {
        auto libraryName = context.pop().asString;
        lhUnload(libraryName);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["call"] = (string path, CommandContext context)
    {
        auto cmdName = context.pop().asString;
        void* lh = sharedLibraries.get(cmdName, null);
        if (lh is null)
        {
            throw new Exception(cmdName ~ " is not loaded");
        }

        if (context.size != 1)
        {
            throw new Exception("Wrong arguments to `call`");
        }

        auto functionName = context.pop().asString;
        auto functionNameZ = functionName.toStringz;

        fnCall(lh, functionNameZ);

        dlclose(lh);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
}
