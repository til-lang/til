module til.nodes.type;

import std.range : front, popFront;

import til.nodes;
import til.procedures : Procedure;


class Type : ListItem
{
    string name;

    this(string name)
    {
        this.name = name;
    }

    // ------------------
    // Conversions
    override string toString()
    {
        return "type " ~ name;
    }
}
