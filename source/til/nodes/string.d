module til.nodes.string;

import til.nodes;

debug
{
    import std.stdio;
}


CommandsMap stringCommands;


// A string without substitutions:
class String : ListItem
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

    // Operators:
    override Context operate(Context context)
    {
        auto operator = context.pop();
        auto rhs = context.pop();

        if (rhs.type != ObjectType.String)
        {
            context.push(this);
            context.push(operator);
            return rhs.reverseOperate(context);
        }

        auto t2 = cast(String)rhs;

        context.push(this.repr == t2.repr);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
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
        override ListItem opUnary()
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
                catch (NotFoundError)
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

        context.push(new String(result));
        context.exitCode = ExitCode.Proceed;
        return context;
    }
}
