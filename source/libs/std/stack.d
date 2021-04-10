module til.std.stack;

import std.algorithm.mutation : reverse;
import std.conv;
import std.experimental.logger : trace;

import til.nodes;

CommandHandler[string] commands;

// Commands:
static this()
{
    commands["dup"] = (string path, CommandContext context)
    {
        auto head = context.pop();
        context.push(head);
        context.push(head);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["reverse"] = (string path, CommandContext context)
    {
        auto head = context.pop();
        if (head.type != ObjectTypes.String)
        {
            throw new Exception(
                "Cannot reverse a "
                ~ to!string(head.type)
                ~ " (" ~ head.asString ~ ")"
            );
        }
        string copy = "";
        copy ~= head.asString;
        char[] r = reverse!(char[])(cast(char[])copy);
        context.push(new SimpleString(cast(string)r));

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["equals?"] = (string path, CommandContext context)
    {
        auto t1 = context.pop();
        auto t2 = context.pop();
        context.push(new Atom(t1.asString == t2.asString));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
}
