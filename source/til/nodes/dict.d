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

    override ListItem extract(Items arguments)
    {
        string key = to!string(arguments.map!(x => to!string(x)).join("."));
        return this[key];
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
