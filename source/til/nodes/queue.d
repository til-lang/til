module til.nodes.queue;

import std.range : front, popFront;

import til.nodes;


class Queue : ListItem
{
    ulong size;
    ListItem[] values;

    this(ulong size)
    {
        this.size = size;
        this.commandPrefix = "queue";
    }

    /*
    // Copied directly from Dict...
    override CommandContext extract(CommandContext context)
    {
        auto arguments = context.items!string;
        string key = to!string(arguments.join("."));
        context.push(this[key]);
        return context;
    }
    */

    // ------------------
    // Conversions
    override string toString()
    {
        string s = "queue " ~ to!string(size);
        s ~= " (" ~ to!string(values.length) ~ ")";
        return s;
    }

    bool isFull()
    {
        return values.length >= size;
    }
    bool isEmpty()
    {
        return values.length == 0;
    }

    void push(ListItem item)
    {
        if (values.length >= size)
        {
            throw new Exception("Queue is full");
        }
        values ~= item;
    }
    ListItem pop()
    {
        if (values.length == 0)
        {
            throw new Exception("Queue is empty");
        }
        auto value = values.front;
        values.popFront();
        return value;
    }

    // ------------------
    // Operators
    ListItem opIndex(ulong k)
    {
        // TODO: check boundaries;
        return values[k];
    }
}
