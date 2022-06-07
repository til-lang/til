module til.nodes.pipeline;

import til.nodes;


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
            .map!(x => x.toString())
            .join(" | "));
    }

    Context run(Context context)
    {
        debug {stderr.writeln("Running Pipeline: ", this);}

        foreach(index, command; commandCalls)
        {
            debug {stderr.writeln(command.name, ">run:", context.size, "/", context.inputSize);}
            context = command.run(context);
            debug {stderr.writeln(command.name, ">run.exitCode:", context.exitCode);}
            debug {stderr.writeln(command.name, ">context.size:", context.size);}

            final switch(context.exitCode)
            {
                case ExitCode.Undefined:
                    throw new Exception(to!string(command) ~ " returned Undefined");

                // -----------------
                // Proc execution:
                case ExitCode.Return:
                    // That is what a `return` command returns.
                    // Return should keep stopping SubPrograms
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
                case ExitCode.Success:
                    context.inputSize = context.size;
                    break;
            }
        }

        context.exitCode = ExitCode.Success;
        return context;
    }
}
