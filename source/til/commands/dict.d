module til.commands.dict;

import til.nodes;
import til.commands;


// Commands:
static this()
{
    commands["dict"] = new Command((string path, Context context)
    {
        auto dict = new Dict();

        foreach(argument; context.items)
        {
            SimpleList l = cast(SimpleList)argument;
            auto lContext = l.forceEvaluate(context);
            l = cast(SimpleList)lContext.pop();

            Item value = l.items.back;
            l.items.popBack();

            string lastKey = l.items.back.toString();
            l.items.popBack();

            auto nextDict = dict.navigateTo(l.items);
            nextDict[lastKey] = value;
        }
        return context.push(dict);
    });
    dictCommands["set"] = new Command((string path, Context context)
    {
        auto dict = context.pop!Dict();

        foreach(argument; context.items)
        {
            SimpleList l = cast(SimpleList)argument;
            auto lContext = l.forceEvaluate(context);
            l = cast(SimpleList)lContext.pop();

            if (l.items.length < 2)
            {
                auto msg = "`dict." ~ path ~ "` expects lists with at least 2 items";
                return context.error(msg, ErrorCode.InvalidArgument, "dict");
            }

            Item value = l.items.back;
            l.items.popBack();

            string lastKey = l.items.back.toString();
            l.items.popBack();

            auto nextDict = dict.navigateTo(l.items);
            nextDict[lastKey] = value;
        }

        return context;
    });
    dictCommands["unset"] = new Command((string path, Context context)
    {
        auto dict = context.pop!Dict();

        foreach (argument; context.items)
        {
            string key;
            if (argument.type != ObjectType.SimpleList)
            {
                argument = new SimpleList([argument]);
            }

            SimpleList l = cast(SimpleList)argument;
            auto lContext = l.forceEvaluate(context);
            l = cast(SimpleList)lContext.pop();

            key = l.items.back.toString();
            l.items.popBack();

            auto innerDict = dict.navigateTo(l.items, false);
            if (innerDict !is null)
            {
                innerDict.values.remove(key);
            }
        }

        return context;
    });
    dictCommands["extract"] = new Command((string path, Context context)
    {
        Dict dict = context.pop!Dict();
        Items items = context.items;

        auto lastKey = items.back.toString();
        items.popBack();

        auto innerDict = dict.navigateTo(items, false);
        debug {stderr.writeln(" innerDict:", innerDict);}
        if (innerDict is null)
        {
            auto msg = "Key `" ~ to!string(items.map!(x => x.toString()).join(".")) ~ "." ~ lastKey ~ "` not found";
            return context.error(msg, ErrorCode.NotFound, "dict");
        }

        try
        {
            return context.push(innerDict[lastKey]);
        }
        catch (Exception ex)
        {
            return context.error(ex.msg, ErrorCode.NotFound, "dict");
        }
    });
}
