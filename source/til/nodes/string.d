module til.nodes.string;

import til.nodes;

debug
{
    import std.stdio;
}


CommandsMap stringCommands;


// A string without substitutions:
class String : Item
{
    string repr;

    this(string s)
    {
        this.repr = s;
        this.type = ObjectType.String;
        this.typeName = "string";
        this.commands = stringCommands;
    }

    // Conversions:
    override string toString()
    {
        return this.repr;
    }

    override Context evaluate(Context context)
    {
        context.push(this);
        return context;
    }

    template opCast(T : string)
    {
        string opCast()
        {
            return this.repr;
        }
    }
    template opUnary(string operator)
    {
        override Item opUnary()
        {
            string newRepr;
            string repr = to!string(this);
            if (repr[0] == '-')
            {
                newRepr = repr[1..$];
            }
            else
            {
                newRepr = "-" ~ repr;
            }
            return new String(newRepr);
        }
    }

    byte[] toBytes()
    {
        byte[] bytes;

        string s = this.toString();
        foreach (c; s)
        {
            bytes ~= cast(byte)c;
        }

        return bytes;
    }
}

// Part of a SubstString
class StringPart
{
    string value;
    bool isName;
    this(string value, bool isName)
    {
        this.value = value;
        this.isName = isName;
    }
    this(char[] chr, bool isName)
    {
        this(cast(string)chr, isName);
    }
}


class SubstString : String
{
    StringPart[] parts;

    this(StringPart[] parts)
    {
        super("");
        this.parts = parts;
        this.type = ObjectType.String;
    }

    // Operators:
    override string toString()
    {
        return to!string(this.parts
            .map!(x => to!string(x))
            .join(""));
    }

    override Context evaluate(Context context)
    {
        string result;
        string value;

        foreach(part; parts)
        {
            if (part.isName)
            {
                Items values;
                try
                {
                    values = context.escopo[part.value];
                }
                catch (NotFoundException)
                {
                    auto msg = "Variable " ~ to!string(part.value) ~ " is not set";
                    return context.error(msg, ErrorCode.InvalidArgument, "");
                }

                foreach (v; values)
                {
                    auto newContext = v.runCommand("to.string", context.next(), true);
                    result ~= to!string(newContext.items
                        .map!(x => to!string(x))
                        .join(" "));
                    }
            }
            else
            {
                result ~= part.value;
            }
        }

        return context.push(new String(result));
    }
}
