module til.std.stack;

import std.algorithm.mutation : reverse;
import std.conv;
import std.experimental.logger : trace;

import til.nodes;

CommandHandler[string] commands;

// Commands:
static this()
{
    commands["pop"] = (string path, CommandContext context)
    {
        int itemsCounter = 1;
        if (context.size > 0)
        {
            auto argument = context.pop();
            itemsCounter = argument.asInteger;
        }
        // The items are already at the stack, we
        // just need to inform our caller how
        // many they are.
        context.size = itemsCounter;
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["push"] = (string path, CommandContext context)
    {
        /*
        push 1 2 3 4
        The stack already has [4 3 2 1] as content.
        All we need to do is say that
        WE pushed N items.
        */

        // context.size = context.size;

        /*
        Clarification: it's the same as:
        CALL push 1 2 3 4
          STACK: [4 3 2 1]
        push: context.items
          STACK: []
        push: push all its arguments in a form that
        other procedure can use it (push
        in writer order)
          STACK: [4 3 2 1]
        push: context.size = 4 and return.
        */

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
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
