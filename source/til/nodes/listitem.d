module til.nodes.listitem;


import til.nodes;


// A base class for all kind of items that
// compose a list (including Lists):
class ListItem
{
    ObjectTypes type;

    // Stubs:
    abstract string asString();
    abstract int asInteger();
    abstract float asFloat();
    abstract bool asBoolean();
    abstract ListItem inverted();

    ListItem extract(Items)
    {
        throw new Exception(
            "Extraction not implemented on "
            ~ to!string(this.type)
        );
    }

    CommandContext evaluate(CommandContext context, bool force) {return this.evaluate(context);}
    CommandContext evaluate(CommandContext context) {return context;}
}
