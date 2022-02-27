module til.procedures;

import std.conv : to;

import til.exceptions;
import til.nodes;

debug
{
    import std.stdio;
}


class Procedure : Command
{
    string name;
    SimpleList parameters;
    SubList body;

    this(string name, SimpleList parameters, SubList body)
    {
        super(null);
        this.name = name;
        this.parameters = parameters;
        this.body = body;
    }

    override Context run(string name, Context context)
    {
        auto newScope = new Process(context.escopo);
        newScope.description = name;

        // Empty the caller scope context/stack:
        foreach (parameter; parameters.items)
        {
            if (context.size == 0)
            {
                auto msg = "Not enough arguments passed to command"
                    ~ " `" ~ name ~ "`.";
                return context.error(msg, ErrorCode.InvalidSyntax, "");
            }
            string parameterName = to!string(parameter);
            auto argument = context.pop();
            newScope[parameterName] = argument;
        }

        debug {
            stderr.writeln("stack 0:", context.escopo.stackAsString());
        }

        // newScope *shares* the Stack:
        newScope.stack = context.escopo.stack[];
        newScope.stackPointer = context.escopo.stackPointer;
        auto newContext = context.next(newScope, context.size);

        // RUN!
        newContext = newScope.run(body.subprogram, newContext);

        // THIS is weird:
        context.escopo.stack = newScope.stack[];
        // I mean, shouldn't newScope.stack be a reference
        // to context.escopo.stack, already???

        context.escopo.stackPointer = newScope.stackPointer;
        context.size = newContext.size;

        if (newContext.exitCode == ExitCode.Failure)
        {
            context.exitCode = newContext.exitCode;
        }
        else
        {
            context.exitCode = ExitCode.CommandSuccess;
        }

        return context;
    }
}
