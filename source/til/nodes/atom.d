module til.nodes.atom;

import til.nodes;

debug
{
    import std.stdio;
}


class Atom : ListItem
{
}

class NameAtom : Atom
{
    string value;

    this(string s)
    {
        this.type = ObjectType.Name;
        this.value = s;
    }

    // Utilities and operators:
    override string toString()
    {
        return this.value;
    }

    override CommandContext evaluate(CommandContext context)
    {
        context.push(this);
        context.exitCode = ExitCode.Proceed;
        return context;
    }
}

class InputNameAtom : NameAtom
{
    this(string s)
    {
        this.type = ObjectType.InputName;
        super(s);
    }

    override CommandContext evaluate(CommandContext context)
    {
        context.push(this);
        context.exitCode = ExitCode.Proceed;
        return context;
    }
}

class SubstAtom : NameAtom
{
    this(string s)
    {
        super(s);
    }

    override CommandContext evaluate(CommandContext context)
    {
        auto values = context.escopo[value];
        if (values is null)
        {
            throw new Exception(
                "Key not found: " ~ value
            );
        }
        else
        {
            foreach(value; values.retro)
            {
                context.push(value);
            }
        }

        context.exitCode = ExitCode.Proceed;
        return context;
    }
}

class IntegerAtom : Atom
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

class FloatAtom : Atom
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


class BooleanAtom : Atom
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

class OperatorAtom : Atom
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
