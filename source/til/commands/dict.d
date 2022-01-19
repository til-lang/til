module til.commands.dict;

import til.nodes;
import til.commands;


// Commands:
static this()
{
    commands["dict"] = (string path, CommandContext context)
    {
        auto dict = new Dict();

        foreach(argument; context.items)
        {
            SimpleList l = cast(SimpleList)argument;
            context = l.forceEvaluate(context);
            l = cast(SimpleList)context.pop();

            ListItem value = l.items.back;
            l.items.popBack();
            string key = to!string(l.items.map!(x => to!string(x)).join("."));
            dict[key] = value;
        }
        context.push(dict);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    dictCommands["set"] = (string path, CommandContext context)
    {
        auto dict = context.pop!Dict();

        foreach(argument; context.items)
        {
            SimpleList l = cast(SimpleList)argument;
            context = l.forceEvaluate(context);
            l = cast(SimpleList)context.pop();

            ListItem value = l.items.back;
            l.items.popBack();
            string key = to!string(l.items.map!(x => to!string(x)).join("."));
            dict[key] = value;
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    dictCommands["unset"] = (string path, CommandContext context)
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
    };
    dictCommands["extract"] = (string path, CommandContext context)
    {
        Dict d = context.pop!Dict();
        auto arguments = context.items!string;
        string key = to!string(arguments.join("."));
        context.push(d[key]);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
}
