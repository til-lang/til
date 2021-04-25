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
        while(context.size > 1) stdout.write(context.pop().asString, " ");
        stdout.write(context.pop().asString);
        stdout.writeln();

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    commands["err"] = (string path, CommandContext context)
    {
        while(context.size > 1) stderr.write(context.pop().asString, " ");
        stderr.write(context.pop().asString);
        stderr.writeln();

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
}
