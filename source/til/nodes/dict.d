module til.nodes.dict;

import til.nodes;


class Dict : ListItem
{
    ListItem[string] values;

    this()
    {
    }
    this(ListItem[string] values)
    {
        this.values = values;
    }

    override CommandContext extract(CommandContext context)
    {
        auto arguments = context.items!string;
        string key = to!string(arguments.join("."));
        context.push(this[key]);
        return context;
    }
    override CommandContext set(CommandContext context)
    {
        // set $d (a 11) (b 22)
        foreach(argument; context.items)
        {
            auto list = cast(SimpleList)argument;
            auto argContext = list.evaluate(context.next());
            auto evaluatedList = cast(SimpleList)argContext.pop();
            auto arguments = evaluatedList.items;

            // (a 11)
            // (a b c 123)
            ListItem value = arguments.back;
            arguments.popBack;

            string key = to!string(
                arguments.map!(x => to!string(x)).join(".")
            );
            this[key] = value;
        }
        return context;
    }
    override CommandContext unset(CommandContext context)
    {
        // set $d a 11
        // set $d (a b c 123)
        // unset $d a (a b c)
        foreach (argument; context.items)
        {
            string key;
            if (argument.type == ObjectType.List)
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
            this.values.remove(key);
        }
        return context;
    }

    // ------------------
    // Conversions
    override string toString()
    {
        string s = "dict ";
        foreach(key, value; values)
        {
            s ~= key ~ "=" ~ to!string(value) ~ " ";
        }
        return s;
    }

    // ------------------
    // Operators
    ListItem opIndex(string k)
    {
        auto v = values.get(k, null);
        if (v is null)
        {
            throw new Exception("key " ~ k ~ " not found");
        }
        return v;
    }
    void opIndexAssign(ListItem v, string k)
    {
        values[k] = v;
    }
}
