module til.commands.dict;

import til.nodes;
import til.commands;

debug
{
    import std.stdio;
}


// Commands:
static this()
{
    commands["dict"] = new Command((string path, Context context)
    {
        auto dict = new Dict();

        foreach(argument; context.items)
        {
            SimpleList l = cast(SimpleList)argument;
            debug {stderr.writeln(" l:", l); }
            context = l.forceEvaluate(context);
            l = cast(SimpleList)context.pop();

            Item value = l.items.back;
            l.items.popBack();
            string key = to!string(l.items.map!(x => to!string(x)).join("."));
            dict[key] = value;
            debug {stderr.writeln(" ", key, ":", value); }
        }
        debug {stderr.writeln("new dict:", dict.toString()); }
        context.push(dict);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    dictCommands["set"] = new Command((string path, Context context)
    {
        auto dict = context.pop!Dict();

        foreach(argument; context.items)
        {
            SimpleList l = cast(SimpleList)argument;
            context = l.forceEvaluate(context);
            l = cast(SimpleList)context.pop();

            Item value = l.items.back;
            l.items.popBack();
            string key = to!string(l.items.map!(x => to!string(x)).join("."));
            dict[key] = value;
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    dictCommands["unset"] = new Command((string path, Context context)
    {
        auto dict = context.pop!Dict();

        foreach (argument; context.items)
        {
            string key;
            if (argument.type == ObjectType.SimpleList)
            {
                auto list = cast(SimpleList)argument;
                auto keysContext = list.evaluate(context.next());
                auto evaluatedList = cast(SimpleList)keysContext.pop();
                auto parts = evaluatedList.items;

                key = to!string(
                    parts.map!(x => to!string(x)).join(".")
                );
            }
            else
            {
                key = to!string(argument);
            }
            dict.values.remove(key);
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    dictCommands["extract"] = new Command((string path, Context context)
    {
        Dict d = context.pop!Dict();
        auto arguments = context.items!string;
        string key = to!string(arguments.join("."));
        context.push(d[key]);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
}
