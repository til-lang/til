module til.sharedlibs;

import core.sys.posix.dlfcn;
import std.algorithm.iteration : map, joiner;
import std.array : split;
import std.conv : to;
import std.string : strip, toStringz;

import til.exceptions;
import til.logic;
import til.nodes;
import til.procedures;


void*[string] sharedLibraries;


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
void loadCommands(CommandHandlerMap commands)
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
            auto msg = libraryName ~ " was not loaded";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto functionName = context.pop!string;
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
        auto libraryPath = context.pop!string;
        auto libraryPathZ = libraryPath.toStringz;

        if (context.size != 2)
        {
            auto msg = "Invalid number of arguments to `load`";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        auto asWord = context.pop!string;
        if (asWord != "as")
        {
            auto msg = "Invalid arguments to `load`."
                       ~ " Usage: load \"libname.so\" as name";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        auto cmdName = context.pop!string;

        // lh = "library handler"
        void* lh = dlopen(libraryPathZ, RTLD_LAZY);
        if (!lh)
        {
            const char* error = dlerror();
            auto msg = "dlopen error: " ~ to!string(error);
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        sharedLibraries[cmdName] = lh;

        /*
        Now we make "cmdName.call" available to the user
        */
        context.escopo.commands[cmdName ~ ".call"] = &callAlias;
        context.escopo.commands[cmdName ~ ".unload"] = &unloadAlias;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["unload"] = (string path, CommandContext context)
    {
        auto libraryName = context.pop!string;
        lhUnload(libraryName);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["call"] = (string path, CommandContext context)
    {
        auto cmdName = context.pop!string;
        void* lh = sharedLibraries.get(cmdName, null);
        if (lh is null)
        {
            auto msg = cmdName ~ " is not loaded";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        if (context.size != 1)
        {
            auto msg = "Wrong arguments to `call`";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto functionName = context.pop!string;
        auto functionNameZ = functionName.toStringz;

        fnCall(lh, functionNameZ);

        dlclose(lh);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
}
