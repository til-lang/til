module til.nodes.atom;

import std.math.rounding : nearbyint;

import til.nodes;

debug
{
    import std.stdio;
}

CommandsMap integerCommands;
CommandsMap floatCommands;
CommandsMap nameCommands;


class Atom : ListItem
{
}

class NameAtom : Atom
{
    // x

    string value;
    string typeName = "atom";

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

    override Context evaluate(Context context)
    {
        context.push(this);
        context.exitCode = ExitCode.Proceed;
        return context;
    }
}

class SubstAtom : NameAtom
{
    // $x
    string typeName = "subst_atom";

    this(string s)
    {
        super(s);
    }

    override Context evaluate(Context context)
    {
        Items values;
        try
        {
            values = context.escopo[value];
        }
        catch (NotFoundError)
        {
            auto msg = "Variable " ~ to!string(value) ~ " is not set";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        foreach(value; values.retro)
        {
            context.push(value);
        }

        context.exitCode = ExitCode.Proceed;
        return context;
    }
}

class IntegerAtom : Atom
{
    // 10

    long value;
    string typeName = "integer";

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
}

class FloatAtom : Atom
{
    // 12.34

    float value;
    string typeName = "float";
    this(float value)
    {
        this.value = value;
        this.type = ObjectType.Float;
        this.commands = floatCommands;
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

    override Context reverseOperate(Context context)
    {
        auto operator = context.pop();
        auto rhs = context.pop();
        // 1.1 * 2
        //  f op i
        //  ^
        //  |
        // this!
        // IntegerAtom is going to call FloatAtom.reverseOperate
        if (rhs.type != ObjectType.Integer)
        {
            context.push(rhs);
            context.push(operator);
            return super.reverseOperate(context);
        }

        IntegerAtom i = cast(IntegerAtom)rhs;
        FloatAtom t2 = new FloatAtom(cast(float)i.value);

        context.push(this);
        context.push(operator);
        return t2.operate(context);

    }
    override Context operate(Context context)
    {
        auto operator = context.pop();
        auto lhs = context.pop();

        FloatAtom t1;
        if (lhs.type == ObjectType.Integer)
        {
            auto it1 = cast(IntegerAtom)lhs;
            t1 = new FloatAtom(cast(float)it1.value);
        }
        else if (lhs.type == ObjectType.Float)
        {
            t1 = cast(FloatAtom)lhs;
        }
        else
        {
            context.push(this);
            context.push(operator);
            return lhs.reverseOperate(context);
        }

        bool done = true;
        string op = to!string(operator);
        switch(op)
        {
            // Math:
            case "+":
                context.push(t1.value + this.value);
                break;
            case "-":
                context.push(t1.value - this.value);
                break;
            case "*":
                context.push(t1.value * this.value);
                break;
            case "/":
                context.push(t1.value / this.value);
                break;
            default:
                done = false;
                break;
        }
        if (!done)
        {
            // TODO: use something like a `scale` variable to control this:
            auto v1 = nearbyint(t1.value * 100000);
            auto v2 = nearbyint(this.value * 100000);

            switch(op)
            {
                // Logic:
                case "==":
                    context.push(v1 == v2);
                    break;
                case "!=":
                    context.push(v1 != v2);
                    break;
                case ">":
                    context.push(v1 > v2);
                    break;
                case ">=":
                    context.push(v1 >= v2);
                    break;
                case "<":
                    context.push(v1 < v2);
                    break;
                case "<=":
                    context.push(v1 <= v2);
                    break;
                default:
                    context.push(this);
                    context.push(operator);
                    return lhs.reverseOperate(context);
            }
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    }
}


class BooleanAtom : Atom
{
    // true
    // false

    bool value;
    string typeName = "boolean";
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
    override Context operate(Context context)
    {
        auto operator = context.pop();
        auto lhs = context.pop();

        switch(to!string(operator))
        {
            case "==":
                context.push(lhs.toBool() == this.value);
                break;
            case "!=":
                context.push(lhs.toBool() != this.value);
                break;
            default:
                context.push(this);
                context.push(operator);
                return super.reverseOperate(context);
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    }
}

class OperatorAtom : Atom
{
    // +

    string value;
    string typeName = "operator";
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
