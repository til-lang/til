module til.nodes.command_call;

import til.nodes;

debug
{
    import std.stdio;
}


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
        // return "cmd(" ~ this.name ~ to!string(this.arguments) ~ ")";
        return this.name;
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
            debug {
                stderr.writeln("   evaluating argument ", argument);
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
        return context;
    }

    Command getCommand(Process escopo, ListItem target)
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

    Context run(Context context, uint inputSize=0)
    {
        // evaluate arguments and set proper context.size:
        auto executionContext = this.evaluateArguments(context);
        if (executionContext.exitCode == ExitCode.Failure)
        {
            return executionContext;
        }

        if (inputSize)
        {
            // `input`, when present, is always the last argument:
            executionContext.size += inputSize;
            executionContext.inputSize = inputSize;
        }

        // The target is always the first argument:
        Item target = null;
        if (executionContext.size)
        {
            target = executionContext.peek();
        }

        auto cmd = getCommand(context.escopo, target);
        if (cmd is null)
        {
            return context.error(
                "Command " ~ this.name ~ " not found",
                ErrorCode.CommandNotFound,
                "internal"
            );
        }

        return cmd.run(this.name, executionContext);
    }
}
