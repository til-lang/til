module til.nodes.atom;

import til.nodes;


class Atom : ListItem
{
    int integer;
    float floatingPoint;
    bool boolean;
    string _repr;
    bool hasSubstitution = true;

    this(string s)
    {
        this.repr = s;
    }
    this(string s, ObjectTypes t)
    {
        this(s);
        this.type = t;
    }
    this(int i)
    {
        this.integer = i;
        this._repr = to!string(i);
        this.type = ObjectTypes.Integer;
    }
    this(float f)
    {
        this.floatingPoint = f;
        this._repr = to!string(f);
        this.type = ObjectTypes.Float;
    }
    this(bool b)
    {
        this.boolean = b;
        this.integer = to!int(b);
        this._repr = to!string(b);
        this.type = ObjectTypes.Boolean;
        this.hasSubstitution = false;
    }

    // Utilities and operators:
    override string toString()
    {
        // return ":" ~ this.repr ~ "_" ~ to!string(this.type);
        return ":" ~ this.repr;
    }
    string debugRepr()
    {
        string context = "";
        context ~= "int:" ~ to!string(this.integer) ~ ";";
        context ~= "float:" ~ to!string(this.floatingPoint) ~ ";";
        context ~= "bool:" ~ to!string(this.boolean) ~ ";";
        context ~= "string:" ~ this.repr;
        return context;
    }

    // Methods:
    @property
    string repr()
    {
        return this._repr;

    }
    @property
    string repr(string s)
    {
        this._repr = s;

        this.hasSubstitution = (
            s[0] == '$' || s.length >= 3 && s[0] == '-' && s[1] == '$'
        );

        return s;
    }

    override CommandContext evaluate(CommandContext context)
    {
        if (!this.hasSubstitution)
        {
            context.push(this);
            context.exitCode = ExitCode.Proceed;
            return context;
        }

        string repr = this.repr;
        char firstChar = repr[0];
        if (firstChar == '$')
        {
            string key = repr[1..$];
            auto values = context.escopo[key];
            if (values is null)
            {
                throw new Exception(
                    "Key not found: " ~ key
                );
            }
            else
            {
                foreach(value; values.retro)
                {
                    context.push(value);
                }
            }
        }
        else if (repr.length >= 3 && firstChar == '-' && repr[1] == '$')
        {
            string key = repr[2..$];
            // set x 10
            // set y -$x
            //  → set y -10
            auto values = context.escopo[key];
            /*
            It's not a good idea to simply return
            a `new Atom(value.repr)` because we
            don't want to lose information
            about the value, as its
            integer or float
            values...
            */
            foreach(value; values)
            {
                context.push(value.inverted);
            }
        }
        else {
            this.hasSubstitution = false;
            context.push(this);
        }

        context.exitCode = ExitCode.Proceed;
        return context;
    }

    override string asString()
    {
        return this.repr;
    }

    override int asInteger()
    {
        switch(this.type)
        {
            case ObjectTypes.Integer:
                return this.integer;
            case ObjectTypes.Float:
                return cast(int)this.floatingPoint;
            default:
                throw new Exception(
                    "Cannot convert a "
                    ~ to!string(this.type)
                    ~ " into an integer"
                );
        }
    }
    override float asFloat()
    {
        switch(this.type)
        {
            case ObjectTypes.Float:
                return this.floatingPoint;
            case ObjectTypes.Integer:
                return cast(float)this.integer;
            default:
                throw new Exception(
                    "Cannot convert a "
                    ~ to!string(this.type)
                    ~ " into a float"
                );
        }
    }
    override bool asBoolean()
    {
        if (this.type == ObjectTypes.Boolean)
        {
            return this.boolean;
        }
        else
        {
            throw new Exception(
                "Cannot convert a "
                ~ to!string(this.type)
                ~ " into a boolean"
            );
        }
    }

    override ListItem inverted()
    {
        switch(this.type)
        {
            case ObjectTypes.Integer:
                return new Atom(-this.integer);
            case ObjectTypes.Float:
                return new Atom(-this.floatingPoint);
            default:
                throw new Exception(
                    "Atom: don't know how to invert a "
                    ~ to!string(this.type)
                );
        }
    }
}
