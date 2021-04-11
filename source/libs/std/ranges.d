module til.std.ranges;

import std.conv;
import std.experimental.logger;

import til.nodes;
import til.ranges;


class Range : InfiniteRange
{
    int start = 0;
    int limit = 0;
    int step = 1;
    int current = 0;

    this(int limit)
    {
        this.limit = limit;
    }
    this(int start, int limit)
    {
        this(limit);
        this.current = start;
        this.start = start;
    }
    this(int start, int limit, int step)
    {
        this(start, limit);
        this.step = step;
    }

    override string toString()
    {
        return
            "range("
            ~ to!string(start)
            ~ ","
            ~ to!string(limit)
            ~ ")";
    }

    override void popFront()
    {
        current += step;
    }
    override ListItem front()
    {
        return new Atom(current);
    }
    override bool empty()
    {
        return (current > limit);
    }
    override Range save()
    {
        auto x = new Range(limit);
        x.current = current;
        return x;
    }
}


// The module:
CommandHandler[string] commands;

// Commands:
static this()
{
    commands["zero_to"] = (string path, CommandContext context)
    {
        auto limit = context.pop().asInteger;
        auto range = new Range(limit);
        context.stream = range;
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["range"] = (string path, CommandContext context)
    {
        /*
           range 10       # [zero, 10]
           range 10 20    # [10, 20]
           range 10 14 2  # 10 12 14
        */
        auto start = context.pop().asInteger;
        int limit = 0;
        if (context.size)
        {
            limit = context.pop().asInteger;
        }
        else
        {
            // zero_to...
            limit = start;
            start = 0;
        }
        if (limit <= start)
        {
            throw new Exception("Invalid range");
        }

        int step = 1;
        if (context.size)
        {
            step = context.pop().asInteger;
        }
        tracef(" range.step:%s", step);

        auto range = new Range(start, limit, step);
        context.stream = range;
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands[null] = commands["range"];
}
