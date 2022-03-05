import std.stdio : writeln;

import til.nodes;


extern (C) CommandsMap getCommands(Escopo escopo)
{
    CommandsMap commands;

    commands["print"] = new Command((string path, Context context)
    {
        Items arguments = context.items;
        foreach(arg; arguments)
        {
            writeln(arg.toString);
        }

        return context;
    });

    return commands;
}
