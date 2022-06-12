import til.commands;
import til.nodes;


// Commands:
static this()
{
    commands["if"] = new Command((string path, Context context)
    {
        auto isConditionTrue = context.pop!bool();
        auto thenBody = context.pop!SubProgram();

        if (isConditionTrue)
        {
            // Get rid of eventual "else":
            context.items();
            // Run body:
            context = context.process.run(thenBody, context.next());
        }
        // no else:
        else if (context.size == 0)
        {
            context.exitCode = ExitCode.Success;
        }
        // else {...}
        // else if {...}
        else
        {
            auto elseWord = context.pop!string();
            if (elseWord != "else" || context.size != 1)
            {
                auto msg = "Invalid format for if/then/else clause:"
                           ~ " elseWord found was " ~ elseWord  ~ ".";
                return context.error(msg, ErrorCode.InvalidSyntax, "");
            }

            auto elseBody = context.pop!SubProgram();
            context = context.process.run(elseBody, context.next());
        }

        return context;
    });

    commands["when"] = new Command((string path, Context context)
    {
        auto isConditionTrue = context.pop!bool();
        auto thenBody = context.pop!SubProgram();

        if (isConditionTrue)
        {
            context = context.process.run(thenBody, context.next());
            debug {stderr.writeln("when>returnedContext.size:", context.size);}

            // Whatever the exitCode was (except Failure), we're going
            // to force a return:
            if (context.exitCode != ExitCode.Failure)
            {
                context.exitCode = ExitCode.Return;
            }
        }

        return context;
    });
    commands["default"] = new Command((string path, Context context)
    {
        auto body = context.pop!SubProgram();

        context = context.process.run(body, context.next());

        // Whatever the exitCode was (except Failure), we're going
        // to force a return:
        if (context.exitCode != ExitCode.Failure)
        {
            context.exitCode = ExitCode.Return;
        }

        return context;
    });
}
