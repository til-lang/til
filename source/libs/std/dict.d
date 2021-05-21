module libs.std.dict;

import til.nodes;


CommandHandler[string] commands;


static this()
{
    commands[null] = (string path, CommandContext context)
    {
        auto arguments = context.items;
        auto dict = new Dict();

        foreach(argument; arguments)
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
}
