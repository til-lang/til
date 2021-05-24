module libs.std.queue;

import til.nodes;


CommandHandler[string] commands;


static this()
{
    commands[null] = (string path, CommandContext context)
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
    commands["push"] = (string path, CommandContext context)
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
    commands["push.no_wait"] = (string path, CommandContext context)
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
    commands["pop"] = (string path, CommandContext context)
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
    commands["pop.no_wait"] = (string path, CommandContext context)
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
}
