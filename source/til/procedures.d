module til.procedures;

import til.exceptions;
import til.nodes;


class Procedure : Command
{
    string name;
    string[] parameters;
    SubProgram body;

    this(string name, string[] parameters, SubProgram body)
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
        foreach (parameter; parameters)
        {
            if (context.size == 0)
            {
                auto msg = "Not enough arguments passed to command"
                    ~ " `" ~ name ~ "`.";
                return context.error(msg, ErrorCode.InvalidSyntax, "");
            }
            auto argument = context.pop();
            newScope[parameter] = argument;
        }

        auto newContext = context.next(newScope, context.size);

        // RUN!
        newContext = context.process.run(body, newContext);
        newContext = context.process.closeCMs(newContext);

        context.size = newContext.size;

        if (newContext.exitCode == ExitCode.Return)
        {
            context.exitCode = ExitCode.Success;
        }
        else
        {
            context.exitCode = newContext.exitCode;
        }

        return context;
    }
}
