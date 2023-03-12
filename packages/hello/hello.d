import std.stdio : writeln;

import now.nodes;


extern (C) void init(Program program)
{
    auto commands = program.commands;
    commands["hello.print"] = new Command((string path, Context context)
    {
        Items arguments = context.items;
        foreach(arg; arguments)
        {
            writeln(arg.toString);
        }

        return context;
    });
}
