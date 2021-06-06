import std.stdio : writeln;

import til.nodes;


extern (C) CommandHandlerMap getCommands(Process escopo)
{
    CommandHandlerMap commands;

    commands["print"] = (string path, CommandContext context)
    {
        Items arguments = context.items;
        foreach(arg; arguments)
        {
            writeln(arg.toString);
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    return commands;
}
