module til.procedures;

import std.conv : to;

import til.exceptions;
import til.nodes;


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
                throw new InvalidException(
                    "Not enough arguments passed to command"
                    ~ " `" ~ name ~ "`."
                );
            }
            string parameterName = to!string(parameter);
            auto argument = context.pop();
            newScope[parameterName] = argument;
        }

        // newScope *shares* the Stack:
        newScope.stack = context.escopo.stack[];
        newScope.stackPointer = context.escopo.stackPointer;
        auto newContext = context.next(newScope, context.size);

        // RUN!
        newContext = newContext.escopo.run(body.subprogram, newContext);

        if (newContext.exitCode == ExitCode.Proceed)
        {
            newContext.exitCode = ExitCode.CommandSuccess;
        }
        return newContext;
    }
}
