module til.nodes.queue;

import std.range : front, popFront;

import til.nodes;

debug
{
    import std.stdio;
}


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
        if (k >= values.length)
        {
            throw new Exception("Invalid index: " ~ to!string(k));
        }
        return values[k];
    }
}


class WaitingQueue : Queue
{
    this(ulong size)
    {
        super(size);
    }

    override CommandContext next(CommandContext context)
    {
        while (isEmpty)
        {
            debug {stderr.writeln("WaitingQueue isEmpty: yield");}
            context.yield();
        }

        auto item = pop();
        debug {stderr.writeln("WaitingQueue.popped:", item);}
        context.push(item);
        context.exitCode = ExitCode.Continue;
        return context;
    }

}
