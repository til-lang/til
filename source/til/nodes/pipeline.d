module til.nodes.pipeline;

import til.nodes;

debug
{
    import std.stdio;
}

class Pipeline
{
    Command[] commands;

    this(Command[] commands)
    {
        this.commands = commands;
    }

    override string toString()
    {
        return "<<" ~ this.asString ~ ">>";
    }
    string asString()
    {
        return to!string(commands
            .map!(x => to!string(x))
            .joiner(" | "));
    }

    CommandContext run(CommandContext context)
    {
        /*
        What really IS a pipeline?
        It is a sequence of commands that handle
        a stream. So every "previous command"
        NECESSARILY MUST generate a
        stream or else we found
        an logic bug and it's
        a good idea to
        alert the
        user.
        */

        debug {stderr.writeln("Running Pipeline ", this);}

        foreach(index, command; commands)
        {

            if (index != 0 && context.stream is null)
            {
                throw new Exception(
                    "You cannot have a sink in the middle of a Pipeline!"
                    ~ " command:" ~ command.name
                );
            }

            auto rContext = command.run(context);

            final switch(rContext.exitCode)
            {
                case ExitCode.Undefined:
                    throw new Exception(to!string(command) ~ " returned Undefined");

                case ExitCode.Proceed:
                    throw new InvalidException(
                        "Commands should not return `Proceed`: " ~ to!string(rContext));

                // -----------------
                // Proc execution:
                case ExitCode.ReturnSuccess:
                    // ReturnSuccess should keep stopping
                    // SubPrograms until a procedure
                    // or a program stops.
                    return rContext;

                case ExitCode.Failure:
                    // Failures, for now, are going to be propagated:
                    return rContext;

                // -----------------
                // Loops:
                case ExitCode.Break:
                case ExitCode.Continue:
                    return rContext;

                // -----------------
                case ExitCode.CommandSuccess:
                    // pass
                    break;
            }
            context.size += rContext.size;
            // Pass along the new stream:
            context.stream = rContext.stream;
        }

        /*
        If there is not a sink in the end of the pipeline,
        consume each item so that the data may flow.
        */
        if (context.stream !is null && !context.stream.empty)
        {
            uint counter = 0;
            foreach(item; context.stream)
            {
                if (item is null) break;

                // Each 16 items we yield fiber/thread control:
                if ((counter++ & 0x0F) == 0x0F) context.escopo.scheduler.yield();
            }
        }

        // The expected context of a pipeline is "Proceed".
        context.exitCode = ExitCode.Proceed;
        return context;
    }
}
