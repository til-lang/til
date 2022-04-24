module til.procedures;

import std.conv : to;

import til.exceptions;
import til.nodes;


class Procedure : Command
{
    string name;
    SimpleList parameters;
    SubProgram body;

    this(string name, SimpleList parameters, SubProgram body)
    {
        this.name = name;
        this.parameters = parameters;
        this.body = body;
        super(null);
    }

    override Context run(string name, Context context)
    {
        auto newScope = new Escopo(context.escopo);
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

        auto newContext = context.next(newScope, context.size);

        // RUN!
        newContext = context.process.run(body, newContext);
        newContext = context.process.closeCMs(newContext);

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
