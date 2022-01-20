module til.nodes.pipeline;

import til.nodes;

debug
{
    import std.stdio;
}

class Pipeline
{
    CommandCall[] commandCalls;

    this(CommandCall[] commandCalls)
    {
        this.commandCalls = commandCalls;
    }

    ulong size()
    {
        return commandCalls.length;
    }

    override string toString()
    {
        return to!string(commandCalls
            .map!(x => to!string(x))
            .joiner(" | "));
    }

    Context run(Context context)
    {
        debug {stderr.writeln("Running Pipeline ", this);}

        bool hasInput = false;
        foreach(index, command; commandCalls)
        {
            context = command.run(context, hasInput);

            final switch(context.exitCode)
            {
                case ExitCode.Undefined:
                    throw new Exception(to!string(command) ~ " returned Undefined");

                case ExitCode.Proceed:
                    throw new InvalidException(
                        "Commands should not return `Proceed`: " ~ to!string(context)
                        ~ " (command: " ~ to!string(command) ~ ")"
                    );

                // -----------------
                // Proc execution:
                case ExitCode.ReturnSuccess:
                    // That is what a `return` command returns.
                    // ReturnSuccess should keep stopping SubPrograms
                    // until a procedure or a program stops.
                    // (Imagine a `return` inside some nested loops.)
                    return context;

                case ExitCode.Failure:
                    // Failures, for now, are going to be propagated:
                    return context;

                // -----------------
                // Loops:
                case ExitCode.Break:
                case ExitCode.Continue:
                case ExitCode.Skip:
                    return context;

                // -----------------
                case ExitCode.CommandSuccess:
                    if (context.size > 0)
                    {
                        hasInput = true;
                    }
                    break;
            }
        }

        // The expected exit code of a pipeline is "Proceed".
        context.exitCode = ExitCode.Proceed;
        return context;
    }
}
