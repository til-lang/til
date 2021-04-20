module libs.std.lists;

import std.algorithm.mutation : reverse;
import std.conv;

import til.nodes;

CommandHandler[string] commands;

// Commands:
static this()
{
    commands["eval"] = (string path, CommandContext context)
    {
        // Expect a SimpleList:
        auto list = context.pop();

        // Force evaluation:
        auto newContext = list.evaluate(context, true);

        newContext.exitCode = ExitCode.CommandSuccess;
        return newContext;
    };
}
