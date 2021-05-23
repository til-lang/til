module libs.std.dict;

import til.nodes;


CommandHandler[string] commands;


static this()
{
    commands[null] = (string path, CommandContext context)
    {
        auto dict = new Dict();

        foreach(argument; context.items)
        {
            SimpleList l = cast(SimpleList)argument;
            ListItem value = l.items.back;
            l.items.popBack();
            string key = to!string(l.items.map!(x => to!string(x)).join("."));
            dict[key] = value;
        }
        context.push(dict);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["set"] = (string path, CommandContext context)
    {
        auto dict = context.pop!Dict;

        foreach(argument; context.items)
        {
            SimpleList l = cast(SimpleList)argument;
            ListItem value = l.items.back;
            l.items.popBack();
            string key = to!string(l.items.map!(x => to!string(x)).join("."));
            dict[key] = value;
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
}
