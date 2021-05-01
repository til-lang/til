module libs.std.range;

import core.stdc.time;
import std.conv;

import til.nodes;
import til.ranges;

debug
{
    import std.stdio;
}


class IntegerRange : InfiniteRange
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
        return new IntegerAtom(current);
    }
    override bool empty()
    {
        return (current > limit);
    }
}


class ItemsRange : Range
{
    Items list;
    int currentIndex = 0;
    ulong _length;

    this(Items list)
    {
        this.list = list;
        this._length = list.length;
    }

    override bool empty()
    {
        return (this.currentIndex >= this._length);
    }
    override ListItem front()
    {
        return this.list[this.currentIndex];
    }
    override void popFront()
    {
        this.currentIndex++;
    }
}

class TimeRange : InfiniteRange
{
    float current = 0.23;
    override ListItem front()
    {
        current += 1.0;
        debug {stderr.writeln("TimeRange.front(): ", current);}
        return new FloatAtom(current);
        /*
        time_t tx;
        auto t = time(&tx);
        return new FloatAtom(tx);
        */
    }
    override void popFront()
    {
    }

    override string toString()
    {
        return "TimeRange";
    }
}

// The module:
CommandHandler[string] commands;

// Commands:
static this()
{
    CommandContext rangeFromIntegers(string path, CommandContext context)
    {
        /*
           range 10       # [zero, 10]
           range 10 20    # [10, 20]
           range 10 14 2  # 10 12 14
        */
        auto start = context.pop!int;
        int limit = 0;
        if (context.size)
        {
            limit = context.pop!int;
        }
        else
        {
            // zero to...
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
            step = context.pop!int;
        }

        auto range = new IntegerRange(start, limit, step);
        context.stream = range;
        return context;
    }

    CommandContext rangeFromList(string path, CommandContext context)
    {
        /*
        range (1 2 3 4 5)
        */
        SimpleList list = context.pop!SimpleList;
        context.stream = new ItemsRange(list.items);
        return context;
    }

    commands["range"] = (string path, CommandContext context)
    {
        auto firstArgument = context.peek();
        if (firstArgument.type == ObjectTypes.List)
        {
            context = rangeFromList(path, context);
        }
        else
        {
            context = rangeFromIntegers(path, context);
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands[null] = commands["range"];

    commands["time"] = (string path, CommandContext context)
    {
        context.stream = new TimeRange();
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
}
