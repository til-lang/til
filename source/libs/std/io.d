module til.std.io;

import std.algorithm;
import std.conv;
import std.stdio;

import til.nodes;

CommandHandler[string] commands;

// Commands:
static this()
{
    commands["out"] = (Process escopo, string path, CommandResult result)
    {
        ListItem[] arguments;
        for(int i=0; i < result.argumentCount; i++)
        {
            arguments ~= escopo.pop();
        }

        string s = to!string(arguments
            .map!(x => x.asString)
            .joiner(" "));

        stdout.writeln(s);

        result.exitCode = ExitCode.CommandSuccess;
        return result;
    };

    commands["err"] = (Process escopo, string path, CommandResult result)
    {
        ListItem[] arguments;
        for(int i=0; i < result.argumentCount; i++)
        {
            arguments ~= escopo.pop();
        }

        string s = to!string(arguments
            .map!(x => x.asString)
            .joiner(" "));

        stderr.writeln(s);

        result.exitCode = ExitCode.CommandSuccess;
        return result;
    };
}
