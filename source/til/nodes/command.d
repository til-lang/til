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

            /*
            But what if this argument is an ExecList and
            while evaluating it returned an Error???
            */
            if (context.exitCode == ExitCode.Failure)
            {
                /*
                Well, we quit imediately:
                */
                return context;
            }

            realArgumentsCounter += context.size;
        }
        context.size = cast(int)realArgumentsCounter;
        debug {stderr.writeln("    context.size (arguments count): ", context.size);}
        return context;
    }

    CommandHandler getHandler(Process escopo, ListItem target)
    {
        CommandHandler *handler;

        debug {
            stderr.writeln("getCommand ", name, " target:", target);
            stderr.writeln(" process:", escopo);
        }

        if (target !is null)
        {
            debug {
                stderr.writeln(
                    "Searching for ", name, " in ", target,
                    " type:", target.type,
                    "\n", target.commands
                );
            }
            handler = target.getCommandHandler(name);
            if (handler !is null) return *handler;
        }

        auto h = escopo.getCommand(name);
        if (h !is null && target !is null)
        {
            /*
            This is not exactly a "cache", because
            any import could simply overwrite
            this value: thus, we don't need
            to worry a bit about
            eviction. :)
            */
            target.commands[name] = h;
        }
        return h;
    }

    CommandContext run(CommandContext context, bool hasInput=false)
    {
        debug {
            stderr.writeln(" Running Command ", this, " ", this.arguments);
            stderr.writeln("  context: ", context);
        }

        // evaluate arguments and set proper context.size:
        context = this.evaluateArguments(context);
        if (context.exitCode == ExitCode.Failure)
        {
            return context;
        }

        if (hasInput)
        {
            debug {stderr.writeln("    HAS INPUT");}
            // Consider the input, that is,
            // the last "argument" for
            // the command:
            context.size++;
            context.hasInput = true;
        }
        debug {stderr.writeln("    context.size: ", context.size);}

        // The target is always the first argument:
        Item target = null;
        if (context.size)
        {
            target = context.peek();
        }

        debug {
            stderr.writeln("  target: ", target);
        }

        // append $item $list
        //        target
        //
        // range 10 | append $list
        //  stream           target
        auto handler = getHandler(context.escopo, target);
        if (handler is null)
        {
            return context.error(
                "Command " ~ this.name ~ " not found",
                ErrorCode.CommandNotFound,
                "internal"
            );
        }

        return this.runHandler(context, handler, target);
    }
    CommandContext runHandler(
        CommandContext context, CommandHandler handler, Item target
    )
    {
        // Run the command:
        // We set the exitCode to Undefined as a flag
        // to check if the handler is really doing
        // the basics, at least.
        context.exitCode = ExitCode.Undefined;
        auto newContext = handler(this.name, context);

        debug
        {
            if (newContext.exitCode == ExitCode.Undefined)
            {
                throw new Exception(
                    "Command "
                    ~ to!string(name)
                    ~ " returned Undefined. The implementation"
                    ~ " is probably wrong."
                );
            }
        }
        return newContext;
    }
}
