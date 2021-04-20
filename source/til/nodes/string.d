module til.nodes.string;

import til.nodes;


// A string without substitutions:
class String : ListItem
{
}

class SimpleString : String
{
    string repr;

    this(string s)
    {
        this.repr = s;
        this.type = ObjectTypes.String;
    }

    // Operators:
    override string toString()
    {
        return '"' ~ this.repr ~ '"';
    }

    override CommandContext evaluate(CommandContext context)
    {
        context.push(this);
        return context;
    }

    override string asString()
    {
        return this.repr;
    }
    override int asInteger()
    {
        throw new Exception("Cannot convert a String into an integer");
    }
    override float asFloat()
    {
        throw new Exception("Cannot convert a String into a float");
    }
    override bool asBoolean()
    {
        throw new Exception("Cannot convert a String into a boolean");
    }
    override ListItem inverted()
    {
        string newRepr;
        string repr = this.asString;
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

    // -----------------------------
    override ListItem extract(Items arguments)
    {
        if (arguments.length == 0) return this;
        auto firstArgument = arguments[0];

        if (firstArgument.type == ObjectTypes.Integer)
        {
            if (arguments.length == 2 && arguments[1].type == ObjectTypes.Integer)
            {
                auto idx1 = firstArgument.asInteger;
                auto idx2 = arguments[1].asInteger;
                return new SimpleString(this.repr[idx1..idx2]);
            }
            else if (arguments.length == 1)
            {
                auto idx = firstArgument.asInteger;
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
        return '"' ~ to!string(this.parts
            .map!(x => to!string(x))
            .joiner("")) ~ '"';
    }

    override CommandContext evaluate(CommandContext context)
    {
        string result;
        string subst;
        string value;

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
                        .map!(x => x.asString)
                        .joiner(" "));
                }
            }
        }

        context.push(new SimpleString(result));
        context.exitCode = ExitCode.Proceed;
        return context;
    }

    override string asString()
    {
        return to!string(this.parts.joiner(""));
    }
}
