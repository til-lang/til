module til.nodes.atom;

import til.nodes;

debug
{
    import std.stdio;
}

CommandHandler[string] integerCommands;
CommandHandler[string] nameCommands;


class Atom : ListItem
{
}

class NameAtom : Atom
{
    // x

    string value;

    this(string s)
    {
        this.type = ObjectType.Name;
        this.value = s;
        this.commands = nameCommands;
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

    override ListItem operate(string operator, ListItem rhs, bool reversed)
    {
        switch(operator)
        {
            case "==":
                return new BooleanAtom(to!string(this) == to!string(rhs));
            default:
                return super.operate(operator, rhs, reversed);
        }
    }
}

class SubstAtom : NameAtom
{
    // $x

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
    // 10

    long value;

    this(long value)
    {
        this.value = value;
        this.type = ObjectType.Integer;
        this.commands = integerCommands;
    }
    IntegerAtom opUnary(string operator)
    {
        if (operator != "-")
        {
            throw new Exception(
                "Unsupported operator: " ~ operator
            );
        }
        return new IntegerAtom(-value);
    }

    override bool toBool()
    {
        return cast(bool)value;
    }
    override long toInt()
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
            auto t2 = cast(IntegerAtom) rhs;
            debug {stderr.writeln(" > ", this, " ", operator, " ", t2);}
            debug {stderr.writeln(" > ", this.value, " ", operator, " ", t2.value);}
            final switch(operator)
            {
                // Logic:
                case "==":
                    return new BooleanAtom(this.value == t2.value);
                case ">":
                    return new BooleanAtom(this.value > t2.value);
                case ">=":
                    return new BooleanAtom(this.value >= t2.value);
                case "<":
                    return new BooleanAtom(this.value < t2.value);
                case "<=":
                    return new BooleanAtom(this.value <= t2.value);

                // Math:
                case "+":
                    return new IntegerAtom(this.value + t2.value);
                case "-":
                    return new IntegerAtom(this.value - t2.value);
                case "*":
                    return new IntegerAtom(this.value * t2.value);
                case "/":
                    return new IntegerAtom(this.value / t2.value);
            }
        }
        else if (rhs.type == ObjectType.Float)
        {
            auto t2 = cast(FloatAtom)rhs;
            debug {stderr.writeln(this.value, " ", operator, " ", t2.value);}
            final switch(operator)
            {
                // Logic:
                case "==":
                    return new BooleanAtom(this.value == t2.value);
                case ">":
                    return new BooleanAtom(this.value > t2.value);
                case ">=":
                    return new BooleanAtom(this.value >= t2.value);
                case "<":
                    return new BooleanAtom(this.value < t2.value);
                case "<=":
                    return new BooleanAtom(this.value <= t2.value);

                // Math:
                case "+":
                    return new FloatAtom(this.value + t2.value);
                case "-":
                    return new FloatAtom(this.value - t2.value);
                case "*":
                    return new FloatAtom(this.value * t2.value);
                case "/":
                    return new FloatAtom(this.value / t2.value);
            }
        }
        return null;
    }
}

class FloatAtom : Atom
{
    // 12.34

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
    override long toInt()
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
        if (operator != "-")
        {
            throw new Exception(
                "Unsupported operator: " ~ operator
            );
        }
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

        switch(operator)
        {
            // Logic:
            case "==":
                return new BooleanAtom(this.value == t2.value);
            case ">":
                return new BooleanAtom(this.value > t2.value);
            case ">=":
                return new BooleanAtom(this.value >= t2.value);
            case "<":
                return new BooleanAtom(this.value < t2.value);
            case "<=":
                return new BooleanAtom(this.value <= t2.value);

            // Math:
            case "+":
                return new FloatAtom(this.value + t2.value);
            case "-":
                return new FloatAtom(this.value - t2.value);
            case "*":
                return new FloatAtom(this.value * t2.value);
            case "/":
                return new FloatAtom(this.value / t2.value);

            default:
                return null;
        }
    }
}


class BooleanAtom : Atom
{
    // true
    // false

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
    override long toInt()
    {
        return cast(long)value;
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
    // +

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
