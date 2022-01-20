module til.commands.queue;

import til.nodes;
import til.commands;


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

        context.exitCode = ExitCode.CommandSuccess;
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
            queue.push(argument);
        }

        context.exitCode = ExitCode.CommandSuccess;
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
            queue.push(argument);
        }

        context.exitCode = ExitCode.CommandSuccess;
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
            context.push(queue.pop());
        }

        context.exitCode = ExitCode.CommandSuccess;
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
            context.push(queue.pop());
        }

        context.exitCode = ExitCode.CommandSuccess;
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
        auto target = context.pop();

        auto nextContext = context;
        do
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
            queue.push(item);
        }
        while(nextContext.exitCode != ExitCode.Break);

        context.exitCode = ExitCode.CommandSuccess;
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
        auto target = context.pop();

        auto nextContext = context;
        do
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
            queue.push(item);
        }
        while(nextContext.exitCode != ExitCode.Break);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    queueCommands["receive"] = new Command((string path, Context context)
    {
        if (context.size != 1)
        {
            auto msg = "`receive` expects one argument";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        class QueueIterator : Item
        {
            Queue queue;
            this(Queue queue)
            {
                this.queue = queue;
            }
            override string toString()
            {
                return "QueueIterator";
            }
            override Context next(Context context)
            {
                while (queue.isEmpty)
                {
                    context.yield();
                }
                auto item = queue.pop();
                context.push(item);
                context.exitCode = ExitCode.Continue;
                return context;
            }
        }

        auto queue = context.pop!Queue();
        context.push(new QueueIterator(queue));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    queueCommands["receive.no_wait"] = new Command((string path, Context context)
    {
        if (context.size != 1)
        {
            auto msg = "`receive` expects one argument";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        class QueueIteratorNoWait : Item
        {
            Queue queue;
            this(Queue queue)
            {
                this.queue = queue;
            }
            override string toString()
            {
                return "QueueIteratorNoWait";
            }
            override Context next(Context context)
            {
                if (queue.isEmpty)
                {
                    context.exitCode = ExitCode.Break;
                }
                else
                {
                    context.exitCode = ExitCode.Continue;
                    auto item = queue.pop();
                    context.push(item);
                }
                return context;
            }
        }

        auto queue = context.pop!Queue();
        context.push(new QueueIteratorNoWait(queue));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
}
