module til.nodes.listitem;


import til.nodes;


// A base class for all kind of items that
// compose a list (including Lists):
class ListItem
{
    ObjectTypes type;

    ListItem operate(string operator, ListItem rhs, bool reversed)
    {
        auto info = typeid(this);
        throw new Exception(
            "_operate (" ~ operator ~ ") not implemented in " ~ info.toString()
        );
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
    int toInt()
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

    // Extractions:
    ListItem extract(Items)
    {
        auto info = typeid(this);
        throw new Exception(
            "Extraction not implemented on "
            ~ info.toString()
        );
    }

    CommandContext evaluate(CommandContext context, bool force) {return this.evaluate(context);}
    CommandContext evaluate(CommandContext context) {context.push(this); return context;}
}
