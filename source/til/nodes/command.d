module til.nodes.command;

import til.nodes;

debug
{
    import std.stdio;
}

class Command
{
    string name;
    Items arguments;
    CommandHandler handler = null;

    this(string name, Items arguments)
    {
        this.name = name;
        this.arguments = arguments;
    }

    override string toString()
    {
        // return "cmd(" ~ this.name ~ to!string(this.arguments) ~ ")";
        return "cmd(" ~ this.name ~ ")";
    }

    CommandContext evaluateArguments(CommandContext context)
    {
        // Evaluate and push each argument, starting from
        // the last one:
        ulong realArgumentsCounter = 0;
        foreach(argument; this.arguments.retro)
        {
            /*
            Each item already pushes its evaluation
            result into the stack
            */
            debug {stderr.writeln("   evaluating argument ", argument);}
            context = argument.evaluate(context.next);
            realArgumentsCounter += context.size;
        }
        context.size = cast(int)realArgumentsCounter;
        debug {stderr.writeln("    context.size (arguments count): ", context.size);}
        return context;
    }

    CommandContext run(CommandContext context)
    {
        debug {stderr.writeln(" Running Command ", this);}
        if (this.handler is null)
        {
            this.handler = context.escopo.getCommand(this.name);
            if (this.handler is null)
            {
                // error("Command not found: " ~ this.name);
                debug {stderr.writeln("  Command not found ", this.name);}
                context.exitCode = ExitCode.Failure;
                return context;
            }
        }

        // evaluate arguments and set proper context.size:
        context = this.evaluateArguments(context);

        return this.runHandler(context, this.handler);
    }
    CommandContext runHandler(CommandContext context, CommandHandler handler)
    {
        // Run the command:
        // We set the exitCode to Undefined as a flag
        // to check if the handler is really doing
        // the basics, at least.
        context.exitCode = ExitCode.Undefined;
        auto newContext = handler(this.name, context);

        // XXX : this is a kind of "sefaty check".
        // It would be nice to NOT run this part
        // in "release" code.
        if (newContext.exitCode == ExitCode.Undefined)
        {
            throw new Exception(
                "Command "
                ~ to!string(name)
                ~ " returned Undefined. The implementation"
                ~ " is probably wrong."
            );
        }
        return newContext;
    }
}
