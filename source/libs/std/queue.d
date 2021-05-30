module libs.std.queue;

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


CommandHandler[string] getCommands()
{
    queueCommands[null] = (string path, CommandContext context)
    {
        ulong size = 64;
        if (context.size > 0)
        {
            size = context.pop!ulong;
        }
        auto queue = new Queue(size);

        context.push(queue);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["push"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue;

        foreach(argument; context.items)
        {
            while (queue.isFull)
            {
                context.yield();
            }
            queue.push(argument);
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["push.no_wait"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue;

        foreach(argument; context.items)
        {
            if (queue.isFull)
            {
                auto msg = "queue is full";
                return context.error(msg, ErrorCode.Full, "");
            }
            queue.push(argument);
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["pop"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue;
        long howMany = 1;
        if (context.size > 0)
        {
            auto integer = context.pop!IntegerAtom;
            howMany = integer.value;
        }
        foreach(idx; 0..howMany)
        {
            while (queue.isEmpty)
            {
                context.yield();
            }
            context.push(queue.pop());
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["pop.no_wait"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue;
        long howMany = 1;
        if (context.size > 0)
        {
            auto integer = context.pop!IntegerAtom;
            howMany = integer.value;
        }
        foreach(idx; 0..howMany)
        {
            if (queue.isEmpty)
            {
                auto msg = "queue is empty";
                return context.error(msg, ErrorCode.Empty, "");
            }
            context.push(queue.pop());
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["send"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue;

        foreach (item; context.stream)
        {
            while (queue.isFull)
            {
                context.yield();
            }
            queue.push(item);
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["send.no_wait"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue;

        foreach (item; context.stream)
        {
            if (queue.isFull)
            {
                auto msg = "queue is full";
                return context.error(msg, ErrorCode.Full, "");
            }
            queue.push(item);
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["receive"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue;
        context.stream = new WaitQueueRange(queue, context);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["receive.no_wait"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue;
        context.stream = new NoWaitQueueRange(queue, context);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    return queueCommands;
}
