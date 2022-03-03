module til.nodes.listitem;

import til.nodes;


class NotImplementedError : Exception
{
    this(string msg)
    {
        super(msg);
    }
}


// A base class for all kind of items that
// compose a list (including Lists):
class ListItem
{
    ObjectType type;
    string typeName;
    CommandsMap commands;

    // Operators:
    template opUnary(string operator)
    {
        ListItem opUnary()
        {
            throw new Exception(
                "Cannot apply " ~ operator ~ " to " ~ this.toString()
            );
        }
    }

    // Conversions:
    bool toBool()
    {
        auto thisInfo = typeid(this);
        throw new Exception(
            "Conversion from "
            ~ thisInfo.toString() ~ " to bool not implemented."
        );
    }
    long toInt()
    {
        auto thisInfo = typeid(this);
        throw new Exception(
            "Conversion from "
            ~ thisInfo.toString() ~ " to int not implemented."
        );
    }
    float toFloat()
    {
        auto thisInfo = typeid(this);
        throw new Exception(
            "Conversion from "
            ~ thisInfo.toString() ~ " to float not implemented."
        );
    }
    override string toString()
    {
        auto thisInfo = typeid(this);
        throw new Exception(
            "Conversion from "
            ~ thisInfo.toString() ~ " to string not implemented."
        );
    }

    Context evaluate(Context context, bool force)
    {
        return this.evaluate(context);
    }
    Context evaluate(Context context)
    {
        context.push(this);
        return context;
    }
    Context next(Context context)
    {
        context = runCommand("next", context);
        return context;
    }

    Command getCommand(string name)
    {
        auto cmd = (name in this.commands);
        if (cmd is null)
        {
            return null;
        }
        else
        {
            return *cmd;
        }
    }
    Context runCommand(CommandName name, Context context, bool allowGlobal=false)
    {
        Command cmd = this.getCommand(name);

        if (cmd is null && allowGlobal)
        {
            cmd = context.escopo.getCommand(name);
        }

        if (cmd is null)
        {
            auto info = typeid(this);
            throw new NotImplementedError(
                name
                ~ " not implemented for "
                ~ info.toString()
            );
        }

        context.push(this);
        return cmd.run(name, context);
    }
}
