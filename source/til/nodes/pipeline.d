module til.nodes.pipeline;

import til.nodes;

debug
{
    import std.stdio;
}

class Pipeline
{
    /*
    >>cmd1 a b > cmd2 > cmd3 x<<
    */
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
            .joiner(" > "));
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
            if (index > 0 && context.stream is null)
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
                    // ReturnSuccess is received here when
                    // we are still INSIDE A PROC.
                    // We return the context, but out caller
                    // doesn't necessarily have to break:
                    return rContext;

                case ExitCode.Failure:
                    throw new Exception("Failure: " ~ to!string(rContext));

                // -----------------
                // Loops:
                case ExitCode.Break:
                case ExitCode.Continue:
                    return rContext;

                // -----------------
                // List execution:
                case ExitCode.CommandSuccess:
                    // pass
                    break;
            }
            context.size += rContext.size;
            // Pass along the new stream:
            context.stream = rContext.stream;
        }

        /*
        If there is not sink in the end of the pipeline,
        consume each item so that the data may flow.
        */
        if (context.stream !is null && !context.stream.empty)
        {
            foreach(item; context.stream)
            {
                if (item is null) break;
            }
        }

        // The expected context of a pipeline is "Proceed".
        context.exitCode = ExitCode.Proceed;
        return context;
    }
}
