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
        string key = to!string(arguments.map!(x => x.asString).join("."));
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

    // ------------------
    // Other bureaucracy:
    override string asString()
    {
        return "DICT";
    }
    override int asInteger()
    {
        throw new Exception("Cannot convert a dict to integer");
    }
    override float asFloat()
    {
        throw new Exception("Cannot convert a dict to float");
    }
    override bool asBoolean()
    {
        throw new Exception("Cannot convert a dict to boolean");
    }
    override ListItem inverted()
    {
        throw new Exception("Cannot invert a dict");
    }
}
