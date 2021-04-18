module libs.std.dict;

import til.nodes;


CommandHandler[string] commands;


static this()
{
    commands["create"] = (string path, CommandContext context)
    {
        auto arguments = context.items;
        auto dict = new Dict();

        foreach(argument; arguments)
        {
            SimpleList l = cast(SimpleList)argument;
            ListItem value = l.items.back;
            l.items.popBack();
            string key = to!string(l.items.map!(x => x.asString).join("."));
            dict[key] = value;
        }
        context.push(dict);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands[null] = commands["create"];

    commands["set"] = (string path, CommandContext context)
    {
        auto dictVariable = context.pop();
        auto dict = cast(Dict)dictVariable;

        auto kvPairs = context.items;
        foreach(kvPair; kvPairs)
        {
            SimpleList kvList = cast(SimpleList)kvPair;
            auto value = kvList.items.back;
            auto key = to!string(kvList.items[0..$-1].map!(x => x.asString).join("."));
            dict[key] = value;
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
}
