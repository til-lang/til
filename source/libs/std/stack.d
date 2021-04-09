module til.std.stack;

import std.algorithm.mutation : reverse;
import std.conv;
import std.experimental.logger : trace;

import til.nodes;

CommandHandler[string] commands;

// Commands:
static this()
{
    commands["dup"] = (Process escopo, string path, CommandResult result)
    {
        auto head = escopo.pop();
        escopo.push(head);
        escopo.push(head);
        result.exitCode = ExitCode.CommandSuccess;
        return result;
    };
    commands["reverse"] = (Process escopo, string path, CommandResult result)
    {
        auto head = escopo.pop();
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
        escopo.push(new SimpleString(cast(string)r));

        result.exitCode = ExitCode.CommandSuccess;
        return result;
    };
    commands["equals?"] = (Process escopo, string path, CommandResult result)
    {
        trace("equals? escopo:", escopo);
        auto t1 = escopo.pop();
        auto t2 = escopo.pop();
        trace("equals? ", t1, t2);
        escopo.push(new Atom(t1.asString == t2.asString));
        result.exitCode = ExitCode.CommandSuccess;
        return result;
    };
}
