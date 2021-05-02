module til.nodes.atom;

import til.nodes;

debug
{
    import std.stdio;
}

class NameAtom : ListItem
{
    string value;
    bool hasSubstitution = false;

    this(string s)
    {
        this.value = s;
        this.type = ObjectType.String;

        // 1- Check if it is an InputName:
        auto len = s.length;
        if (len > 1)
        {
            auto firstChar = s[0];

            if (firstChar == '>')
            {
                type = ObjectType.InputName;
                s = s[1..$];
            }
            else
            {
                type = ObjectType.Name;
            }
        }

        // 2- Check if it has substitutions:
        len = s.length;
        if (len > 1)
        {
            auto firstChar = s[0];
            hasSubstitution = (
                firstChar == '$'
                || len >= 3 && firstChar == '-' && s[1] == '$'
            );
        }
    }

    // Utilities and operators:
    override string toString()
    {
        return this.value;
    }

    override CommandContext evaluate(CommandContext context)
    {
        if (!this.hasSubstitution)
        {
            context.push(this);
            context.exitCode = ExitCode.Proceed;
            return context;
        }

        char firstChar = value[0];
        if (firstChar == '$')
        {
            string key = value[1..$];
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
        else if (value.length >= 3 && firstChar == '-' && value[1] == '$')
        {
            string key = value[2..$];
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
                context.push(-value);
            }
        }
        else {
            this.hasSubstitution = false;
            context.push(this);
        }

        context.exitCode = ExitCode.Proceed;
        return context;
    }
}

class IntegerAtom : ListItem
{
    int value;

    this(int value)
    {
        this.value = value;
        this.type = ObjectType.Integer;
    }
    IntegerAtom opUnary(string operator)
    {
        // TODO: filter by `operator`
        return new IntegerAtom(-value);
    }

    override bool toBool()
    {
        return cast(bool)value;
    }
    override int toInt()
    {
        return value;
    }
    override float toFloat()
    {
        return cast(float)value;
    }
    override string toString()
    {
        return to!string(value);
    }

    override ListItem operate(string operator, ListItem rhs, bool reversed)
    {
        if (reversed) return null;

        debug {stderr.writeln(" > ", this.type, " ", operator, " ", rhs.type);}

        if (rhs.type == ObjectType.Integer)
        {
            auto t2 = cast(IntegerAtom)rhs;
            int result = {
                final switch(operator)
                {
                    // Logic:
                    case "==":
                        return this.value == t2.value;
                    case ">":
                        return this.value > t2.value;
                    case ">=":
                        return this.value >= t2.value;
                    case "<":
                        return this.value < t2.value;
                    case "<=":
                        return this.value <= t2.value;

                    // Math:
                    case "+":
                        return this.value + t2.value;
                    case "-":
                        return this.value - t2.value;
                    case "*":
                        return this.value * t2.value;
                    case "/":
                        return this.value / t2.value;
                }
            }();
            return new IntegerAtom(result);
        }
        else if (rhs.type == ObjectType.Float)
        {
            auto t2 = cast(FloatAtom)rhs;
            debug {stderr.writeln(this.value, " ", operator, " ", t2.value);}
            float result = {
                final switch(operator)
                {
                    // Logic:
                    case "==":
                        return this.value == t2.value;
                    case ">":
                        return this.value > t2.value;
                    case ">=":
                        return this.value >= t2.value;
                    case "<":
                        return this.value < t2.value;
                    case "<=":
                        return this.value <= t2.value;

                    // Math:
                    case "+":
                        return this.value + t2.value;
                    case "-":
                        return this.value - t2.value;
                    case "*":
                        return this.value * t2.value;
                    case "/":
                        return this.value / t2.value;
                }
            }();
            return new FloatAtom(result);
        }
        return null;
    }
}

class FloatAtom : ListItem
{
    float value;
    this(float value)
    {
        this.value = value;
        this.type = ObjectType.Float;
    }
    override bool toBool()
    {
        return cast(bool)value;
    }
    override int toInt()
    {
        return cast(int)value;
    }
    override float toFloat()
    {
        return value;
    }
    override string toString()
    {
        return to!string(this.value);
    }

    // Operators:
    FloatAtom opUnary(string operator)
    {
        // TODO: filter by `operator`
        return new FloatAtom(-value);
    }

    override ListItem operate(string operator, ListItem rhs, bool reversed)
    {
        if (reversed) return null;

        debug {stderr.writeln(" > ", this.type, " ", operator, " ", rhs.type);}

        FloatAtom t2;

        if (rhs.type == ObjectType.Integer)
        {
            auto it2 = cast(IntegerAtom)rhs;
            t2 = new FloatAtom(cast(float)it2.value);
        }
        else if (rhs.type == ObjectType.Float)
        {
            t2 = cast(FloatAtom)rhs;
        }
        else
        {
            return null;
        }

        float result = {
            final switch(operator)
            {
                case "+":
                    return this.value + t2.value;
                case "-":
                    return this.value - t2.value;
                case "*":
                    return this.value * t2.value;
                case "/":
                    return this.value / t2.value;
            }
        }();
        return new FloatAtom(result);
    }
}


class BooleanAtom : ListItem
{
    bool value;
    this(bool value)
    {
        this.value = value;
        this.type = ObjectType.Boolean;
    }
    override bool toBool()
    {
        return cast(bool)value;
    }
    override int toInt()
    {
        return cast(int)value;
    }
    override float toFloat()
    {
        return value;
    }
    override string toString()
    {
        return to!string(value);
    }
}

class OperatorAtom : ListItem
{
    string value;

    this(string s)
    {
        value = s;
        this.type = ObjectType.Operator;
    }

    // Utilities and operators:
    override string toString()
    {
        return this.value;
    }
}
