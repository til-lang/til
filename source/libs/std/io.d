module libs.std.io;

import std.algorithm;
import std.stdio;

import til.nodes;

CommandHandler[string] commands;

// Commands:
static this()
{
    commands["out"] = (string path, CommandContext context)
    {
        while(context.size > 1) stdout.write(context.pop!string, " ");
        stdout.write(context.pop!string);
        stdout.writeln();

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    commands["err"] = (string path, CommandContext context)
    {
        while(context.size > 1) stderr.write(context.pop!string, " ");
        stderr.write(context.pop!string);
        stderr.writeln();

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
}
