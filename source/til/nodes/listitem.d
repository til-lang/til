module til.nodes.listitem;


import til.nodes;


// A base class for all kind of items that
// compose a list (including Lists):
class ListItem
{
    ObjectType type;
    string typeName;
    CommandHandlerMap commands;

    ListItem operate(string operator, ListItem rhs, bool reversed)
    {
        auto info = typeid(this);
        throw new Exception(
            "operate (" ~ operator ~ ") not implemented in " ~ info.toString()
        );
    }

    CommandHandler* getCommandHandler(string name)
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
        context = runCommand(context, "next");
        return context;
    }

    // Extractions:
    CommandContext extract(CommandContext context)
    {
        context = runCommand(context, "extract");
        return context;
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

    CommandContext runCommand(
        CommandContext context, string name
    )
    {
        CommandHandler* handler = this.getCommandHandler(name);

        if (handler is null)
        {
            auto info = typeid(this);
            throw new Exception(
                name
                ~ " not implemented for "
                ~ info.toString()
            );
        }

        // Run the command:
        // We set the exitCode to Undefined as a flag
        // to check if the handler is really doing
        // the basics, at least.
        context.exitCode = ExitCode.Undefined;

        context.push(this);
        context = (*handler)(name, context);

        debug
        {
            if (context.exitCode == ExitCode.Undefined)
            {
                throw new Exception(
                    "Command "
                    ~ to!string(name)
                    ~ " returned Undefined. The implementation"
                    ~ " is probably wrong."
                );
            }
        }
        return context;
    }
}
