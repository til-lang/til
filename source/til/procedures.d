module til.procedures;

import std.conv : to;

import til.exceptions;
import til.nodes;

debug
{
    import std.stdio;
}

Context runProc(string path, Context context)
{
    // `runnable` should NEVER be null, actually...
    if (context.command is null && context.command.runnable is null)
    {
        auto msg = "Procedure " ~ path ~ " not found!";
        return context.error(msg, ErrorCode.InvalidSyntax, "");
    }

    auto runnable = context.command.runnable;
    auto proc = cast(Procedure)runnable;
    debug {stderr.writeln(" runProc.procedure:", proc);}
    return proc.run(path, context);
}

class Procedure : Runnable
{
    SimpleList parameters;
    SubList body;

    this(string name, SimpleList parameters, SubList body)
    {
        super(name);
        this.parameters = parameters;
        this.body = body;
    }

    override Context run(string name, Context context)
    {
        debug {
            stderr.writeln("proc.run:", name, " ", context);
            stderr.writeln(" parameters:", parameters.items);
        }
        auto newScope = new Process(context.escopo);
        newScope.description = name;

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
