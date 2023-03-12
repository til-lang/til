module now.nodes.baselist;

import now.nodes;


class BaseList : Item
{
    Items items;

    this()
    {
        this([]);
    }
    this(Item item)
    {
        this([item]);
    }
    this(Items items)
    {
        this.items = items;
    }

    // Operators:
    template opUnary(string operator)
    {
        override Item opUnary()
        {
            throw new Exception("Cannot apply " ~ operator ~ " to a List!");
        }
    }
}

