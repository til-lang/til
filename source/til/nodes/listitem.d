module til.nodes.listitem;


import til.nodes;


// A base class for all kind of items that
// compose a list (including Lists):
class ListItem
{
    ObjectType type;
    CommandHandlerMap commands;

    ListItem operate(string operator, ListItem rhs, bool reversed)
    {
        auto info = typeid(this);
        throw new Exception(
            "operate (" ~ operator ~ ") not implemented in " ~ info.toString()
        );
    }

    CommandHandler *getCommandHandler(string name)
    {
        return (name in this.commands);
    }

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
    CommandContext next(CommandContext context)
    {
        context.exitCode = ExitCode.Break;
        return context;
    }

    // Extractions:
    CommandContext extract(CommandContext context)
    {
        auto info = typeid(this);
        throw new Exception(
            "Extraction not implemented on "
            ~ info.toString()
        );
    }

    CommandContext evaluate(CommandContext context, bool force)
    {
        return this.evaluate(context);
    }
    CommandContext evaluate(CommandContext context)
    {
        context.push(this);
        return context;
    }
}
