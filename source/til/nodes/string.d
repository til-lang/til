module til.nodes.string;

import til.nodes;

debug
{
    import std.stdio;
}


CommandHandler[string] stringCommands;


// A string without substitutions:
class String : ListItem
{
    string repr;

    this(string s)
    {
        this.repr = s;
        this.type = ObjectType.String;
        this.commands = stringCommands;
    }

    // Conversions:
    override string toString()
    {
        return this.repr;
    }

    // Operators:
    override CommandContext operate(CommandContext context)
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



    // 
    override CommandContext evaluate(CommandContext context)
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

    // -----------------------------
    override CommandContext extract(CommandContext context)
    {
        if (context.size == 0) return context.push(this);

        auto start = context.pop().toInt();
        if (start < 0)
        {
            start = this.repr.length + start;
        }

        auto end = start + 1;
        if (context.size)
        {
            end = context.pop().toInt();
            if (end < 0)
            {
                end = this.repr.length + end;
            }
        }

        return context.push(new String(this.repr[start..end]));
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
            .joiner(""));
    }

    override CommandContext evaluate(CommandContext context)
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
                result ~= to!string(values
                    .map!(x => to!string(x))
                    .joiner(" "));
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
