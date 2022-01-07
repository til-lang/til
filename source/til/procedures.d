module til.procedures;

import std.conv : to;

import til.exceptions;
import til.nodes;

debug
{
    import std.stdio;
}


class Procedure
{
    string name;
    SimpleList parameters;
    SubList body;

    this(string name, SimpleList parameters, SubList body)
    {
        this.name = name;
        this.parameters = parameters;
        this.body = body;
    }

    CommandContext run(string name, CommandContext context)
    {
        debug {
            stderr.writeln("proc.run:", name, " ", context);
            stderr.writeln(" parameters:", parameters.items);
        }
        auto newScope = new Process(context.escopo);

        // Empty the caller scope context/stack:
        foreach (parameter; parameters.items)
        {
            if (context.size == 0)
            {
                throw new InvalidException(
                    "Not enough arguments passed to command"
                    ~ " \"" ~ name ~ "\"."
                );
            }
            string parameterName = to!string(parameter);
            auto argument = context.pop();
            newScope[parameterName] = argument;
        }
        debug {stderr.writeln("caller scope:", context.escopo);}

        // newScope *shares* the Stack:
        newScope.stack = context.escopo.stack[];
        newScope.stackPointer = context.escopo.stackPointer;
        auto newContext = context.next(newScope, context.size);

        debug {stderr.writeln("newScope:", newScope);}

        // RUN!
        newContext = newContext.escopo.run(body.subprogram, newContext);

        if (newContext.exitCode == ExitCode.Proceed)
        {
            newContext.exitCode = ExitCode.CommandSuccess;
        }
        return newContext;
    }
}
