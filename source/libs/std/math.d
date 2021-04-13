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
        auto newContext = int_run(context);
        if (newContext.size != 1)
        {
            throw new Exception(
                "math.run: error. Should return 1 item.\n"
                ~ to!string(context.escopo)
            );
        }
        // int_run already consumes one item and push another,
        // so we shouldn't mess with the context or the stack, here.
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
}
