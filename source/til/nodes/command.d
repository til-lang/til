module til.nodes.command;

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

        ulong realArgumentsCounter = 0;

        // Evaluate and push each argument, starting from
        // the last one:
        ulong initialStackSize = context.stackSize;
        foreach(argument; this.arguments.retro)
        {
            /*
            Each item already pushes its evaluation
            result into the stack
            */
            context = argument.evaluate(context);
        }
        realArgumentsCounter = context.stackSize - initialStackSize;
        trace(this.name, " >>> realArgumentsCounter:", realArgumentsCounter);

        // Run the command:
        // We set the exitCode to Undefined as a fla
        // to check if the hander is really doing
        // the basics, at least.
        context.exitCode = ExitCode.Undefined;
        // TESTE: Limit the context size to the number of arguments:
        context.size = cast(uint)realArgumentsCounter;
        trace(" calling handler(", this.name, "). context: ", context);
        trace("  realArgumentsCounter:", realArgumentsCounter);
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
