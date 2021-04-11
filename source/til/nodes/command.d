module til.nodes.command;

// import std.algorithm : max;

import til.nodes;

class Command
{
    string name;
    Items arguments;

    this(string name, Items arguments)
    {
        this.name = name;
        this.arguments = arguments;
        trace("new Command:", name, " ", arguments);
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
            context = argument.evaluate(context.next);
            trace(" > ", argument, " context.size:", context.size);
            realArgumentsCounter += context.size;
        }
        trace(this.name, " >>> realArgumentsCounter:", realArgumentsCounter);
        context.size = cast(int)realArgumentsCounter;
        return context;
    }

    CommandContext run(CommandContext context)
    {
        trace(" Command.run:", this.name, " ", this.arguments);
        auto handler = context.escopo.getCommand(this.name);
        if (handler is null)
        {
            error("Command not found: " ~ this.name);
            context.exitCode = ExitCode.Failure;
            return context;
        }

        // evaluate arguments and set proper context.size:
        context = this.evaluateArguments(context);

        return this.runHandler(context, handler);
    }
    CommandContext runHandler(CommandContext context, CommandHandler handler)
    {
        // Run the command:
        // We set the exitCode to Undefined as a flag
        // to check if the handler is really doing
        // the basics, at least.
        context.exitCode = ExitCode.Undefined;
        trace(" calling handler(", this.name, "). context: ", context);
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
