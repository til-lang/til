module til.nodes.command_call;

import std.array : join;

import til.nodes;


class CommandCall
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
        return this.name;
        /*
        return this.name
            ~ " "
            ~ arguments.map!(x => x.toString())
                .join(" ");
        */
    }

    Context evaluateArguments(Context context)
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

            /*
            But what if this argument is an ExecList and
            while evaluating it returned an Error???
            */
            if (context.exitCode == ExitCode.Failure)
            {
                /*
                Well, we quit imediately:
                */
                debug {stderr.writeln("   FAILURE!");}
                return context;
            }

            debug {stderr.writeln("   += ", context.size);}
            realArgumentsCounter += context.size;
        }
        context.size = cast(int)realArgumentsCounter;
        return context;
    }

    Command getCommand(Escopo escopo, Item target)
    {
        Command cmd;

        if (target !is null)
        {
            cmd = target.getCommand(name);
            if (cmd !is null) return cmd;
        }

        cmd = escopo.getCommand(name);
        if (cmd !is null && target !is null)
        {
            target.commands[name] = cmd;
        }
        return cmd;
    }

    Context run(Context context)
    {
        // evaluate arguments and set proper context.size:
        auto executionContext = this.evaluateArguments(context);
        if (executionContext.exitCode == ExitCode.Failure)
        {
            return executionContext;
        }

        debug {stderr.writeln(name, ".executionContext.size:", executionContext.size);}
        if (context.inputSize)
        {
            debug {stderr.writeln(name, ".context.inputSize:", context.inputSize);}
            // `input`, when present, is always the last argument:
            executionContext.size += context.inputSize;
            executionContext.inputSize = context.inputSize;
        }
        debug {stderr.writeln(name, ".executionContext.size:", executionContext.size);}
        debug {stderr.writeln(name, ".executionContext.inputSize:", executionContext.inputSize);}

        // The target is always the first argument:
        Item target = null;
        if (executionContext.size)
        {
            target = executionContext.peek();
        }

        auto cmd = getCommand(context.escopo, target);
        debug {stderr.writeln(name, ".cmd:", cmd);}
        if (cmd is null)
        {
            return context.error(
                "Command " ~ this.name ~ " not found",
                ErrorCode.CommandNotFound,
                "internal"
            );
        }

        executionContext.escopo["args.count"] = new IntegerAtom(executionContext.size);
        return cmd.run(this.name, executionContext);
    }
}
