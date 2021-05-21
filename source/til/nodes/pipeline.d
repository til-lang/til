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
        a logic bug - and it
        is a good idea to
        alert the
        user.
        */

        debug {stderr.writeln("Running Pipeline ", this);}

        Command previous = null;
        foreach(index, command; commands)
        {
            if (index != 0)
            {
                if (context.stream is null)
                {
                    throw new Exception(
                        "You cannot have a sink in the middle of a Pipeline!"
                        ~ " command:" ~ previous.name
                    );
                }

                /*
                set x [a | b | c]
                `c` can return a value, but the first
                two commands in the pipeline must
                have any return values
                OBLITERATED!
                */
                if (context.size != 0)
                {
                    // Just pop everything:
                    context.items;
                }
            }

            auto runContext = command.run(context);
            previous = command;

            final switch(runContext.exitCode)
            {
                case ExitCode.Undefined:
                    throw new Exception(to!string(command) ~ " returned Undefined");

                case ExitCode.Proceed:
                    throw new InvalidException(
                        "Commands should not return `Proceed`: " ~ to!string(runContext)
                        ~ " (command: " ~ to!string(command) ~ ")"
                    );

                // -----------------
                // Proc execution:
                case ExitCode.ReturnSuccess:
                    // ReturnSuccess should keep stopping
                    // SubPrograms until a procedure
                    // or a program stops.
                    return runContext;

                case ExitCode.Failure:
                    // Failures, for now, are going to be propagated:
                    return runContext;

                // -----------------
                // Loops:
                case ExitCode.Break:
                case ExitCode.Continue:
                    return runContext;

                // -----------------
                case ExitCode.CommandSuccess:
                    // pass
                    break;
            }
            context.size += runContext.size;
            // Pass along the new stream:
            context.stream = runContext.stream;
        }

        /*
        If there is not a sink in the end of the pipeline,
        consume each item so that the data may flow.
        */
        /*
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
        */

        // The expected context of a pipeline is "Proceed".
        context.exitCode = ExitCode.Proceed;
        return context;
    }
}
