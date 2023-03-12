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
    // d[["a", "b", "c"]]
    Item opIndex(string[] keys)
    {
        auto pivot = this;
        foreach (key; keys)
        {
            auto nextDict = (key in pivot.values);
            if (nextDict is null)
            {
                return null;
            }
            else
            {
                pivot = cast(Dict)pivot[key];
            }
        }
        return pivot;
    }
    void opIndexAssign(Item v, string k)
    {
        debug {stderr.writeln(" dict[", k, "] = ", to!string(v));}
        values[k] = v;
        order ~= k;
    }
    void opIndexAssign(Item v, string[] keys)
    {
        auto pivot = this;
        foreach (key; keys[0..$-1])
        {
            auto nextDictPtr = (key in pivot.values);
            if (nextDictPtr is null)
            {
                auto nextDict = new Dict();
                pivot[key] = nextDict;
                pivot = nextDict;
            }
            else
            {
                pivot = cast(Dict)(*nextDictPtr);
            }
        }
        pivot[keys[$-1]] = v;
    }

    template get(T)
    {
        T get(string key, T delegate(Dict) defaultValue)
        {
            auto valuePtr = (key in values);
            if (valuePtr !is null)
            {
                Item value = *valuePtr;
                return cast(T)value;
            }
            else
            {
                return defaultValue(this);
            }
        }
        T get(string[] keys, T delegate(Dict) defaultValue)
        {
            Dict pivot = this;
            foreach (key; keys[0..$-1])
            {
                auto pivotPtr = (key in pivot.values);
                if (pivotPtr !is null)
                {
                    auto item = *pivotPtr;
                    if (item.type != ObjectType.Dict)
                    {
                        throw new Exception(
                            "Cannot index "
                            ~ item.type.to!string
                            ~ " (" ~ item.toString() ~ ")"
                            ~ " on key " ~ key
                        );
                    }
                    pivot = cast(Dict)item;
                }
                else
                {
                    return defaultValue(this);
                }
            }
            return cast(T)(pivot[keys[$-1]]);
        }
    }

    template getOrCreate(T)
    {
        T getOrCreate(string key)
        {
            return this.get!T(
                key,
                delegate (Dict d) {
                    auto newItem = new T();
                    d[key] = newItem;
                    return newItem;
                }
            );
        }
        T getOrCreate(string[] keys)
        {
            Dict pivot = this;
            foreach (key; keys)
            {
                pivot = pivot.getOrCreate!T(key);
            }
            return pivot;
        }
    }

    Dict navigateTo(Items items, bool autoCreate=true)
    {
        // debug {stderr.writeln("navigateTo:", items, "/", autoCreate);}
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
    bool isNumeric = true;
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
        if (values.length > 0 && isNumeric)
        {
            return evaluateAsList(context);
        }
        else
        {
            return evaluateAsDict(context);
        }
    }

    Context evaluateAsDict(Context context)
    {
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
    Context evaluateAsList(Context context)
    {
        context.push(new SimpleList(values.values.array));
        return context;
    }

    override void opIndexAssign(Item v, string k)
    {
        if (k == "-")
        {
            k = this.order.length.to!string;
        }
        else
        {
            isNumeric = false;
        }
        super.opIndexAssign(v, k);
    }
}
