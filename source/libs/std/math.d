module libs.std.math;

import std.conv : to;

import til.math;
import til.nodes;

CommandHandler[string] commands;

// Commands:
static this()
{
    commands["run"] = (string path, CommandContext context)
    {
        auto list = cast(SimpleList)context.pop();
        context.run(&list.forceEvaluate);

        auto newContext = int_run(context);
        if (newContext.size != 1)
        {
            throw new Exception(
                "math.run: error. Should return 1 item.\n"
                ~ to!string(newContext.escopo)
                ~ " returned " ~ to!string(newContext.size)
            );
        }

        // int_run pushes a new list, but we don't want that.
        auto resultList = cast(SimpleList)context.pop();
        foreach(item; resultList.items)
        {
            context.push(item);
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands[null] = commands["run"];
}
