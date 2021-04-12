module libs.std.io;

import std.algorithm;
import std.conv;
import std.stdio;

import til.nodes;

CommandHandler[string] commands;

// Commands:
static this()
{
    commands["out"] = (string path, CommandContext context)
    {
        string s = to!string(context.items
            .map!(x => x.asString)
            .joiner(" "));

        stdout.writeln(s);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    commands["err"] = (string path, CommandContext context)
    {
        string s = to!string(context.items
            .map!(x => x.asString)
            .joiner(" "));

        stderr.writeln(s);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
}
