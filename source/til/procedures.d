module til.procedures;

import std.conv : to;

import til.exceptions;
import til.ranges;
import til.nodes;


class Procedure
{
    string name;
    SimpleList parameters;
    SubList body;

    this(string name, ListItem parameters, ListItem body)
    {
        this.name = name;
        this.parameters = cast(SimpleList)parameters;
        this.body = cast(SubList)body;
    }

    CommandContext run(string name, CommandContext context)
    {
        // We open a new scope only because we
        // want a new namespace that do not
        // interfere with the caller one
        auto newContext = context;   // struct copy
        newContext.escopo = new Process(context.escopo);

        foreach(parameter; parameters.items)
        {
            if (newContext.size == 0)
            {
                throw new InvalidException(
                    "Not enough arguments passed to command"
                    ~ " \"" ~ name ~ "\"."
                );
            }
            string parameterName = parameter.asString;
            auto argument = newContext.pop();
            newContext.escopo[parameterName] = argument;
        }

        // RUN!
        newContext = newContext.escopo.run(body.subprogram, newContext);

        if (newContext.exitCode != ExitCode.Failure)
        {
            context.exitCode = ExitCode.CommandSuccess;

            // Now we must COPY the stack
            // and update context.size
            context.size = newContext.size;
            context.escopo.stack = newContext.escopo.stack;
        }
        return context;
    }
}
