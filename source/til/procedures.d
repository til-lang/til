module til.procedures;

import std.conv : to;

import til.exceptions;
import til.ranges;
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

        // "Empty" caller scope context/stack:
        foreach(parameter; parameters.items)
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
        /*
        XXX : yeap, this is kind of messy, but
        we must make this copy...
        */
        newScope.stack = context.escopo.stack;
        newScope.stackPointer = context.escopo.stackPointer;
        auto newContext = context.next(newScope, context.size);

        debug {stderr.writeln("newScope:", newScope);}

        // RUN!
        newContext = newContext.escopo.run(body.subprogram, newContext);

        // Empty procedure stack:
        foreach(item; newContext.items.retro)
        {
            debug {stderr.writeln("PROC STACK MOVING ", item);}
            context.push(item);
        }

        /*
        We will simply COPY the exitCode and, yes, that will
        allow procedures to end with `continue` or `break`
        and, yes, this is kind weird, but also good,
        because this way you won't need to
        "uplevel" these things and
        separate a lot of
        behaviours in
        some common
        procs.
        */
        if (newContext.exitCode == ExitCode.Proceed)
        {
            context.exitCode = ExitCode.CommandSuccess;
        }
        else
        {
            context.exitCode = newContext.exitCode;
        }
        return context;
    }
}
