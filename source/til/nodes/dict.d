module til.nodes.dict;

import std.algorithm.iteration : filter;
import std.array : array;

import til.nodes;


CommandsMap dictCommands;


class Dict : Item
{
    Item[string] values;
    string[] order;

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
        order ~= values.keys;
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
        order ~= k;
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

    void remove(string key)
    {
        values.remove(key);
        this.order = this.order.filter!(x => x != key).array;
    }
}


class SectionDict : Dict
{
    this()
    {
        super();
    }
    this(Item[string] values)
    {
        super(values);
    }

    override Context evaluate(Context context)
    {
        debug {
            stderr.writeln("Evaluating SectionDict: ", this);
        }
        auto d = new Dict();
        foreach (key, value; values)
        {
            auto newContext = context.next();
            newContext = value.evaluate(newContext);
            if (newContext.exitCode == ExitCode.Failure)
            {
                return newContext;
            }
            // XXX: but what if an item evaluates to a sequence?
            d[key] = newContext.pop();
            debug {
                stderr.writeln("  d[", key, "] = ", d[key]);
            }
        }
        debug {
            stderr.writeln("    Result:", d);
        }
        context.push(d);
        return context;
    }
}
