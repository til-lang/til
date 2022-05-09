module til.commands.queue;

import til.nodes;
import til.commands;

debug
{
    import std.stdio;
}

// Commands:
static this()
{
    commands["queue"] = new Command((string path, Context context)
    {
        ulong size = 64;
        if (context.size > 0)
        {
            size = context.pop!ulong();
        }
        auto queue = new Queue(size);

        context.push(queue);

        return context;
    });
    queueCommands["push"] = new Command((string path, Context context)
    {
        auto queue = context.pop!Queue();

        foreach(argument; context.items)
        {
            while (queue.isFull)
            {
                context.yield();
            }
            queue.write(argument);
        }

        return context;
    });
    queueCommands["push.no_wait"] = new Command((string path, Context context)
    {
        auto queue = context.pop!Queue();

        foreach(argument; context.items)
        {
            if (queue.isFull)
            {
                auto msg = "queue is full";
                return context.error(msg, ErrorCode.Full, "");
            }
            queue.write(argument);
        }

        return context;
    });
    queueCommands["pop"] = new Command((string path, Context context)
    {
        auto queue = context.pop!Queue();
        long howMany = 1;
        if (context.size > 0)
        {
            auto integer = context.pop!IntegerAtom();
            howMany = integer.value;
        }
        foreach(idx; 0..howMany)
        {
            while (queue.isEmpty)
            {
                context.yield();
            }
            context.push(queue.read());
        }

        return context;
    });
    queueCommands["pop.no_wait"] = new Command((string path, Context context)
    {
        auto queue = context.pop!Queue();
        long howMany = 1;
        if (context.size > 0)
        {
            auto integer = context.pop!IntegerAtom();
            howMany = integer.value;
        }
        foreach(idx; 0..howMany)
        {
            if (queue.isEmpty)
            {
                auto msg = "queue is empty";
                return context.error(msg, ErrorCode.Empty, "");
            }
            context.push(queue.read());
        }

        return context;
    });
    queueCommands["send"] = new Command((string path, Context context)
    {
        auto queue = context.pop!Queue();

        if (context.size == 0)
        {
            auto msg = "no target to send from";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        foreach(target; context.items)
        {
            auto nextContext = context;
            while (true)
            {
                nextContext = target.next(context);
                if (nextContext.exitCode == ExitCode.Break)
                {
                    break;
                }
                auto item = nextContext.pop();

                while (queue.isFull)
                {
                    context.yield();
                }
                queue.write(item);
            }
        }
        return context;
    });
    queueCommands["send.no_wait"] = new Command((string path, Context context)
    {
        auto queue = context.pop!Queue();

        if (context.size == 0)
        {
            auto msg = "no target to send from";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        foreach (target; context.items)
        {
            auto nextContext = context;
            while (true)
            {
                nextContext = target.next(context);
                if (nextContext.exitCode == ExitCode.Break)
                {
                    break;
                }
                auto item = nextContext.pop();
                if (queue.isFull)
                {
                    auto msg = "queue is full";
                    return context.error(msg, ErrorCode.Full, "");
                }
                queue.write(item);
            }
        }

        return context;
    });
    queueCommands["receive"] = new Command((string path, Context context)
    {
        if (context.size != 1)
        {
            auto msg = "`receive` expects one argument";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto queue = context.pop!Queue();
        return context.push(new WaitingQueue(queue));
    });
    queueCommands["receive.no_wait"] = new Command((string path, Context context)
    {
        if (context.size != 1)
        {
            auto msg = "`receive.no_wait` expects one argument";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto queue = context.pop!Queue();
        return context.push(queue);
    });
    queueCommands["length"] = new Command((string path, Context context)
    {
        auto queue = context.pop!Queue();
        return context.push(queue.values.length);
    });
}
