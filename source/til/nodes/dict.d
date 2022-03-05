module til.nodes.dict;

import til.modules;
import til.nodes;

debug
{
    import std.stdio;
}

CommandsMap dictCommands;


class Dict : Item
{
    Item[string] values;

    this()
    {
        this.type = ObjectType.Dict;
        this.commands = dictCommands;
        this.typeName = "dict";
    }
    this(Item[string] values)
    {
        this();
        this.values = values;
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
    Item opIndex(string k)
    {
        auto v = values.get(k, null);
        if (v is null)
        {
            throw new Exception("key " ~ k ~ " not found");
        }
        return v;
    }
    void opIndexAssign(Item v, string k)
    {
        debug {stderr.writeln(" dict[", k, "] = ", to!string(v));}
        values[k] = v;
    }
}
