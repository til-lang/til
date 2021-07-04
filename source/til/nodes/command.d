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
    bool inBackground;

    this(string name, Items arguments)
    {
        this.name = name;
        this.arguments = arguments;
        this.inBackground = false;
    }
    this(string name, Items arguments, bool inBackground)
    {
        this(name, arguments);
        this.inBackground = inBackground;
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

        if (context.exitCode == ExitCode.Failure)
        {
            return context;
        }

        if (inBackground)
        {
            return runInBackground(context);
        }

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

    CommandContext runInBackground(CommandContext context)
    {
        debug {stderr.writeln(" IN BACKGROUND: ", this);}

        // original arguments were already evaluated at this point.
        auto newArguments = context.items;

        // Run in other process - in FOREGROUND!
        auto newCommand = new Command(name, newArguments, false);

        auto pipeline = new Pipeline([newCommand]);
        auto subprogram = new SubProgram([pipeline]);
        auto process = new Process(context.escopo, subprogram);

        // Piping:
        if (context.stream is null)
        {
            process.input = new ProcessIORange(context.escopo, name ~ ":in");
            debug {stderr.writeln("process.input: ", context.escopo);}
        }
        else
        {
            process.input = context.stream;
        }
        // Important: it's not the current process, but the new one, here:
        process.output = new ProcessIORange(process, name ~ ":out");

        auto pid = context.escopo.scheduler.add(process);

        context.push(pid);

        // Piping out:
        context.stream = process.output;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    }
}
