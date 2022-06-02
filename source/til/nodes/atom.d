module til.nodes.atom;

import til.nodes;


CommandsMap booleanCommands;
CommandsMap integerCommands;
CommandsMap floatCommands;
CommandsMap nameCommands;


class Atom : Item
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
        this.typeName = "atom";
    }

    // Utilities and operators:
    override string toString()
    {
        return this.value;
    }

    override Context evaluate(Context context)
    {
        return context.push(this);
    }
}

class SubstAtom : NameAtom
{
    // $x

    this(string s)
    {
        super(s);
        this.typeName = "subst_atom";
    }

    override Context evaluate(Context context)
    {
        Items values;
        try
        {
            values = context.escopo[value];
        }
        catch (NotFoundException)
        {
            auto msg = "Variable " ~ to!string(value) ~ " is not set";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        foreach(value; values.retro)
        {
            context.push(value);
        }

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
        this.typeName = "integer";
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
    this(float value)
    {
        this.value = value;
        this.type = ObjectType.Float;
        this.typeName = "float";
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
        return to!string(value);
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
        this.typeName = "boolean";
        this.commands = booleanCommands;
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
