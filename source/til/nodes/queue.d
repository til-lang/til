module til.nodes.queue;

import std.range : front, popFront;

import til.nodes;

CommandHandler[string] queueCommands;

class Queue : ListItem
{
    ulong size;
    ListItem[] values;

    this(ulong size)
    {
        this.size = size;
        this.commands = queueCommands;
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

    ListItem front()
    {
        return values.front;
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

    // Acting as an Iterator:
    override CommandContext next(CommandContext context)
    {
        // Queue.next is "no_wait".
        if (isEmpty)
        {
            context.exitCode = ExitCode.Break;
        }
        else
        {
            context.push(pop());
            context.exitCode = ExitCode.Continue;
        }
        return context;
    }

    // ------------------
    // Operators
    ListItem opIndex(ulong k)
    {
        // TODO: check boundaries;
        return values[k];
    }
}
