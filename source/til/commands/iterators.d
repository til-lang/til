module til.commands.iterators;

import til.commands;
import til.nodes;


// Iterators for "transform":
class Transformer : Item
{
    Items targets;
    size_t targetIndex = 0;
    SubProgram body;
    Context context;
    string varName;
    bool empty;

    this(
        Items targets,
        string varName,
        SubProgram body,
        Context context
    )
    {
        this.targets = targets;
        this.varName = varName;
        this.body = body;
        this.context = context;
    }

    override string toString()
    {
        return "transform";
    }

    override Context next(Context context)
    {
        auto target = targets[targetIndex];
        auto targetContext = target.next(context);

        switch (targetContext.exitCode)
        {
            case ExitCode.Break:
                targetIndex++;
                if (targetIndex < targets.length)
                {
                    return next(context);
                }
                goto case;
            case ExitCode.Failure:
            case ExitCode.Skip:
                return targetContext;
            case ExitCode.Continue:
                break;
            default:
                throw new Exception(
                    to!string(target)
                    ~ ".next returned "
                    ~ to!string(targetContext.exitCode)
                );
        }

        int inputSize = 0;
        if (varName)
        {
            context.escopo[varName] = targetContext.items;
        }
        else
        {
            foreach (item; targetContext.items.retro)
            {
                debug {stderr.writeln("transform> pushing:", item);}
                context.push(item);
                inputSize++;
            }
        }

        auto execContext = context.process.run(body, context, inputSize);

        switch(execContext.exitCode)
        {
            case ExitCode.Return:
            case ExitCode.Success:
                execContext.exitCode = ExitCode.Continue;
                break;

            default:
                break;
        }
        return execContext;
    }
}



// Commands:
static this()
{
    commands["transform"] = new Command((string path, Context context)
    {
        auto varName = context.pop!string();
        auto body = context.pop!SubProgram();

        if (context.size == 0)
        {
            auto msg = "no target to transform";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        auto targets = context.items;

        auto iterator = new Transformer(
            targets, varName, body, context
        );
        context.push(iterator);
        return context;
    });
    commands["transform.inline"] = new Command((string path, Context context)
    {
        auto body = context.pop!SubProgram();

        if (context.size == 0)
        {
            auto msg = "no target to transform";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        auto targets = context.items;

        auto iterator = new Transformer(
            targets, null, body, context
        );
        context.push(iterator);
        return context;
    });

    nameCommands["foreach"] = new Command((string path, Context context)
    {
        /*
        range 5 | foreach x { print $x }
        */
        auto argName = context.pop!string();
        auto argBody = context.pop!SubProgram();

        /*
        Do NOT create a new scope for the
        body of foreach.
        */
        auto loopScope = context.escopo;

        uint index = 0;

        foreach (target; context.items)
        {
            debug {stderr.writeln("foreach.target:", target);}
    forLoop:
            while (true)
            {
                auto nextContext = target.next(context.next());
                debug {stderr.writeln("foreach next.exitCode:", nextContext.exitCode);}
                switch (nextContext.exitCode)
                {
                    case ExitCode.Break:
                        break forLoop;
                    case ExitCode.Failure:
                        return nextContext;
                    case ExitCode.Skip:
                        continue;
                    case ExitCode.Continue:
                        break;  // <-- break the switch, not the while.
                    default:
                        return nextContext;
                }

                loopScope[argName] = nextContext.items;

                context = context.process.run(argBody, context.next());
                debug {stderr.writeln("foreach context.exitCode:", context.exitCode);}

                if (context.exitCode == ExitCode.Break)
                {
                    break;
                }
                else if (context.exitCode == ExitCode.Return)
                {
                    /*
                    Return propagates up into the
                    processes stack:
                    */
                    return context;
                }
                else if (context.exitCode == ExitCode.Failure)
                {
                    return context;
                }
            }
        }

        context.exitCode = ExitCode.Success;
        return context;
    });
    commands["foreach.inline"] = new Command((string path, Context context)
    {
        /*
        range 5 | foreach.inline { print }
        */
        auto argBody = context.pop!SubProgram();

        /*
        Do NOT create a new scope for the
        body of foreach.
        */
        auto loopScope = context.escopo;

        uint index = 0;

        foreach (target; context.items)
        {
            debug {stderr.writeln("foreach.target:", target);}
    forLoop:
            while (true)
            {
                auto nextContext = target.next(context.next());
                debug {stderr.writeln("foreach next.exitCode:", nextContext.exitCode);}
                switch (nextContext.exitCode)
                {
                    case ExitCode.Break:
                        break forLoop;
                    case ExitCode.Failure:
                        return nextContext;
                    case ExitCode.Skip:
                        continue;
                    case ExitCode.Continue:
                        break;  // <-- break the switch, not the while.
                    default:
                        return nextContext;
                }

                auto bodyContext = context.next();

                // XXX: aren't we sharing the Stack?
                // Shouldn't adjust .size be enough???
                int inputSize = 0;
                foreach (item; nextContext.items.retro)
                {
                    debug {stderr.writeln("foreach.push:", item);}
                    bodyContext.push(item);
                    inputSize++;
                }

                context = context.process.run(argBody, bodyContext, inputSize);
                debug {stderr.writeln("foreach context.exitCode:", context.exitCode);}

                if (context.exitCode == ExitCode.Break)
                {
                    break;
                }
                else if (context.exitCode == ExitCode.Return)
                {
                    /*
                    Return propagates up into the
                    processes stack:
                    */
                    return context;
                }
                else if (context.exitCode == ExitCode.Failure)
                {
                    return context;
                }
            }
        }

        context.exitCode = ExitCode.Success;
        return context;
    });

    commands["collect"] = new Command((string path, Context context)
    {
        if (context.size == 0)
        {
            auto msg = "`" ~ path ~ "` needs at least one input stream";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }

        Items items;

        foreach (input; context.items)
        {
            while (true)
            {
                auto nextContext = input.next(context.next());
                if (nextContext.exitCode == ExitCode.Break)
                {
                    break;
                }
                else if (nextContext.exitCode == ExitCode.Skip)
                {
                    continue;
                }
                else if (nextContext.exitCode == ExitCode.Failure)
                {
                    return nextContext;
                }
                auto x = nextContext.items;
                items ~= x;
            }
        }

        return context.push(new SimpleList(items));
    });

}
