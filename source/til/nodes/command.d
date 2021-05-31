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

    this(string name, Items arguments)
    {
        this.name = name;
        this.arguments = arguments;
    }

    override string toString()
    {
        // return "cmd(" ~ this.name ~ to!string(this.arguments) ~ ")";
        return this.name;
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
            debug {
                stderr.writeln("   evaluating argument ", argument);
                stderr.writeln("    in context ", context);
            }
            context = argument.evaluate(context.next);
            realArgumentsCounter += context.size;
        }
        context.size = cast(int)realArgumentsCounter;
        debug {stderr.writeln("    context.size (arguments count): ", context.size);}
        return context;
    }

    CommandHandler getHandler(Process escopo, ListItem arg1)
    {
        CommandHandler *handler;

        debug {
            stderr.writeln("getCommand ", name);
            stderr.writeln(" process:", escopo);
        }

        if (arg1 !is null)
        {
            debug {
                stderr.writeln(
                    "Searching for ", name, " in ", arg1.type,
                    "\n", arg1.commands
                );
            }
            handler = (name in arg1.commands);
            if (handler !is null) return *handler;
        }

        auto h = escopo.getCommand(name);
        if (h !is null && arg1 !is null)
        {
            /*
            This is not exactly a "cache", because
            any import could simply overwrite
            this value: thus, we don't need
            to worry a bit about
            eviction. :)
            */
            arg1.commands[name] = h;
        }
        return h;
    }

    CommandContext run(CommandContext context)
    {
        debug {
            stderr.writeln(" Running Command ", this, " ", this.arguments);
            stderr.writeln("  context: ", context);
        }

        // evaluate arguments and set proper context.size:
        context = this.evaluateArguments(context);

        ListItem arg1 = null;
        if (context.size)
        {
            arg1 = context.peek();
        }
        auto handler = getHandler(context.escopo, arg1);
        if (handler is null)
        {
            return context.error(
                "Command " ~ this.name ~ " not found",
                ErrorCode.CommandNotFound,
                "internal"
            );
        }

        return this.runHandler(context, handler);
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
