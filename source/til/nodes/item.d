module til.nodes.item;

import std.variant;

import til.nodes;


// A base class for all kind of items that
// compose a sequence:
class Item
{
    ObjectType type;
    string typeName;
    CommandsMap commands;

    // For third-party modules encapsulating other classes:
    Variant content;

    // Operators:
    template opUnary(string operator)
    {
        Item opUnary()
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

    // Evaluation:
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

    // Commands:
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
            string msg = 
                name
                ~ " not implemented for "
                ~ info.toString();
            return context.error(msg, ErrorCode.NotImplemented, "");
        }

        context.push(this);
        return cmd.run(name, context);
    }
}
