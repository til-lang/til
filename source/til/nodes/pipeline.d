module til.nodes.pipeline;

import til.nodes;


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
        foreach(command; commands)
        {
            trace("running command:", command);
            context = command.run(context);
            trace("  context: ", context);

            final switch(context.exitCode)
            {
                case ExitCode.Undefined:
                    throw new Exception(to!string(command) ~ " returned Undefined");

                case ExitCode.Proceed:
                    throw new InvalidException(
                        "Commands should not return `Proceed`: " ~ to!string(context));

                // -----------------
                // Proc execution:
                case ExitCode.ReturnSuccess:
                    // ReturnSuccess is received here when
                    // we are still INSIDE A PROC.
                    // We return the context, but out caller
                    // doesn't necessarily have to break:
                    return context;

                case ExitCode.Failure:
                    throw new Exception("Failure: " ~ to!string(context));

                // -----------------
                // Loops:
                case ExitCode.Break:
                case ExitCode.Continue:
                    return context;

                // -----------------
                // List execution:
                case ExitCode.CommandSuccess:
                    // pass
                    break;
            }
        }
        // The expected context of a pipeline is "Proceed".
        context.exitCode = ExitCode.Proceed;
        return context;
    }
}
