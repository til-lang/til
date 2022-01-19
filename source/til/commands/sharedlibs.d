module til.commands.sharedlibs;

import std.array : split;

import til.nodes;
import til.commands;
import til.sharedlibs;


// Commands:
static this()
{

    // Helper "commands":
    CommandContext callAlias(string path, CommandContext context)
    {
        // h.call "hello"
        // path = "h.call"
        // libraryPath = "h"
        // cmdName = "hello"

        string libraryName = path.split(".")[0];

        auto lib = sharedLibraries.get(libraryName, null);
        if (lib is null)
        {
            auto msg = libraryName ~ " was not loaded";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto functionName = context.pop!string;

        lib.call(functionName);

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

    // "Static" commands:
    commands["load"] = (string path, CommandContext context)
    {
        // sharedlib.load "libhello.so" as h
        auto libraryPath = context.pop!string;

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
        // void* lh = loadDynamicLib(libraryPath);
        auto lib = loadDynamicLib(libraryPath);
        if (!lib.success)
        {
            return context.error(lib.errorMessage, ErrorCode.InvalidArgument, "");
        }

        sharedLibraries[cmdName] = lib;

        /*
        Now we make "cmdName.call" available to the user
        */
        // TODO: create a type for dynamic libraries and
        // use METHODS, like `call $dlib function_name`
        // or `unload $dlib`.
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
        auto lib = sharedLibraries.get(cmdName, null);
        if (lib is null)
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

        lib.call(functionName);

        // XXX: why are we closing it?
        lib.close();

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
}
