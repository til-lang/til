module til.nodes.string;

import til.nodes;

debug
{
    import std.stdio;
}


// A string without substitutions:
class String : ListItem
{
    string repr;

    this(string s)
    {
        this.repr = s;
        this.type = ObjectType.String;
    }

    // Conversions:
    override string toString()
    {
        return this.repr;
    }

    // Operators:
    override ListItem operate(string operator, ListItem rhs, bool reversed)
    {
        if (reversed) return null;
        if (rhs.type != ObjectType.String) return null;

        /*
        Remember: we are receiving and
        already-evaluated value, so
        it can only be a "simple"
        String.
        */
        auto t2 = cast(String)rhs;

        return new BooleanAtom(this.repr == t2.repr);
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
    override ListItem extract(Items arguments)
    {
        if (arguments.length == 0) return this;
        auto firstArgument = arguments[0];

        if (firstArgument.type == ObjectType.Integer)
        {
            if (arguments.length == 2 && arguments[1].type == ObjectType.Integer)
            {
                auto idx1 = firstArgument.toInt;
                auto idx2 = arguments[1].toInt;
                return new String(this.repr[idx1..idx2]);
            }
            else if (arguments.length == 1)
            {
                auto idx = firstArgument.toInt;
                return new String(this.repr[idx..idx+1]);
            }
        }
        throw new Exception("not implemented");
    }
}

class SubstString : String
{
    string[] parts;

    this(string[] parts)
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

        debug {stderr.writeln("SubstString.evaluate: ", parts);}
        foreach(part;parts)
        {
            if (part[0] != '$')
            {
                result ~= part;
            }
            else
            {
                auto key = part[1..$];
                debug {
                    stderr.writeln(" key: ", key);
                    stderr.writeln(" escopo: ", context.escopo);
                }
                Items values = context.escopo[key];
                if (values is null)
                {
                    result ~= "<?" ~ key ~ "?>";
                }
                else
                {
                    result ~= to!string(values
                        .map!(x => to!string(x))
                        .joiner(" "));
                }
            }
        }

        context.push(new String(result));
        context.exitCode = ExitCode.Proceed;
        return context;
    }
}
