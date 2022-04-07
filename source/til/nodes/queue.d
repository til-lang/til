module til.nodes.queue;

import std.range : front, popFront;

import til.nodes;


CommandsMap queueCommands;


class Queue : Item
{
    ulong size;
    Items values;

    this(ulong size)
    {
        this.size = size;
        this.commands = queueCommands;
        this.type = ObjectType.Queue;
        this.typeName = "queue";
    }
    this(ulong size, Items values)
    {
        this(size);
        this.values = values;
    }
    this(Queue q)
    {
        this(q.size, q.values);
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
        return values.length > size;
    }
    bool isEmpty()
    {
        return values.length == 0;
    }

    Item front()
    {
        return values.front;
    }
    void push(Item item)
    {
        if (isFull)
        {
            throw new Exception("Queue is full");
        }
        values ~= item;
    }
    Item pop()
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
    override Context next(Context context)
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
    Item opIndex(uint k)
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
    this(Queue q)
    {
        super(q);
    }

    override Context next(Context context)
    {
        while (isEmpty)
        {
            context.yield();
        }

        auto item = pop();
        context.push(item);
        context.exitCode = ExitCode.Continue;
        return context;
    }
}
