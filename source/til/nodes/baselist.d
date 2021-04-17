module til.nodes.baselist;

import til.nodes;


class BaseList : ListItem
{
    Items items;

    this()
    {
        this([]);
    }
    this(ListItem item)
    {
        this([item]);
    }
    this(Items items)
    {
        this.items = items;
        this.type = ObjectTypes.List;
    }

    // Methods:
    override string asString()
    {
        string s = to!string(this.items
            .map!(x => x.asString)
            .joiner(" "));
        return "BaseList:(" ~ s ~ ")";
    }
    override int asInteger()
    {
        // XXX : or can we???
        throw new Exception("Cannot convert a List into an integer");
    }
    override float asFloat()
    {
        // XXX : or can we???
        throw new Exception("Cannot convert a List into a float");
    }
    override bool asBoolean()
    {
        // XXX : or can we???
        throw new Exception("Cannot convert a List into a boolean");
    }
    override ListItem inverted()
    {
        throw new Exception("Cannot invert a List!");
        // XXX : or can?
        // XXX : should we?
    }
}

