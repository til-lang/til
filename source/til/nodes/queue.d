module til.nodes.queue;

import std.range : front, popFront;

import til.nodes;
import til.ranges;

CommandHandler[string] queueCommands;

class NoWaitQueueRange : Range
{
    Queue queue;
    CommandContext context;
    this(Queue queue, CommandContext context)
    {
        this.queue = queue;
        this.context = context;
    }

    override bool empty()
    {
        return queue.isEmpty();
    }
    override ListItem front()
    {
        return queue.front;
    }
    override void popFront()
    {
        queue.pop();
    }
    override string toString()
    {
        return "QueueRange";
    }
}


class WaitQueueRange : NoWaitQueueRange
{
    this(Queue queue, CommandContext context)
    {
        super(queue, context);
    }
    override bool empty()
    {
        while (queue.isEmpty)
        {
            context.yield();
        }
        return queue.isEmpty();
    }
}


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

    // ------------------
    // Operators
    ListItem opIndex(ulong k)
    {
        // TODO: check boundaries;
        return values[k];
    }
}
