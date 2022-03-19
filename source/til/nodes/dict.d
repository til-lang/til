module til.nodes.dict;

import til.nodes;


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
        string s = "dict("
            ~ to!string(
                values.keys.map!(key => key ~ "=" ~ values[key].toString()).join(" ")
            )
            ~ ")";
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

    Dict navigateTo(Items items, bool autoCreate=true)
    {
        debug {stderr.writeln("navigateTo:", items, "/", autoCreate);}
        auto pivot = this;
        foreach (item; items)
        {
            string key = item.toString();
            auto nextDict = (key in pivot.values);
            if (nextDict is null)
            {
                if (autoCreate)
                {
                    auto d = new Dict();
                    pivot[key] = d;
                    pivot = d;
                }
                else
                {
                    return null;
                }
            }
            else
            {
                pivot = cast(Dict)pivot[key];
            }
        }
        return pivot;
    }
}
