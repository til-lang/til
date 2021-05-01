module til.nodes.string;

import til.nodes;

debug
{
    import std.stdio;
}


// A string without substitutions:
class SimpleString : ListItem
{
    string repr;

    this(string s)
    {
        this.repr = s;
        this.type = ObjectTypes.String;
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
        if (rhs.type != ObjectTypes.String) return null;

        /*
        Remember: we are receiving and
        already-evaluated value, so
        it can only be a
        SimpleString.
        */
        auto t2 = cast(SimpleString)rhs;

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
            return new SimpleString(newRepr);
        }
    }

    // -----------------------------
    override ListItem extract(Items arguments)
    {
        if (arguments.length == 0) return this;
        auto firstArgument = arguments[0];

        if (firstArgument.type == ObjectTypes.Integer)
        {
            if (arguments.length == 2 && arguments[1].type == ObjectTypes.Integer)
            {
                auto idx1 = firstArgument.toInt;
                auto idx2 = arguments[1].toInt;
                return new SimpleString(this.repr[idx1..idx2]);
            }
            else if (arguments.length == 1)
            {
                auto idx = firstArgument.toInt;
                return new SimpleString(this.repr[idx..idx+1]);
            }
        }
        throw new Exception("not implemented");
    }
}

class SubstString : SimpleString
{
    string[] parts;
    string[int] substitutions;

    this(string[] parts, string[int] substitutions)
    {
        super("");
        this.parts = parts;
        this.substitutions = substitutions;
        this.type = ObjectTypes.String;
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
        string subst;
        string value;

        debug {stderr.writeln("SubstString.evaluate: ", parts);}
        foreach(index, part;parts)
        {
            subst = this.substitutions.get(cast(int)index, null);
            if (subst is null)
            {
                result ~= part;
            }
            else
            {
                Items values = context.escopo[subst];
                if (values is null)
                {
                    result ~= "<?" ~ subst ~ "?>";
                }
                else
                {
                    result ~= to!string(values
                        .map!(x => to!string(x))
                        .joiner(" "));
                }
            }
        }

        context.push(new SimpleString(result));
        context.exitCode = ExitCode.Proceed;
        return context;
    }
}
