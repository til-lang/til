module til.nodes.dict;

import til.modules;
import til.nodes;

CommandHandler[string] dictCommands;


class Dict : ListItem
{
    ListItem[string] values;

    this()
    {
        this.type = ObjectType.Dict;
        this.commands = dictCommands;
    }
    this(ListItem[string] values)
    {
        this();
        this.values = values;
    }

    override CommandContext extract(CommandContext context)
    {
        auto arguments = context.items!string;
        string key = to!string(arguments.join("."));
        context.push(this[key]);
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
