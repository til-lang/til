module til.context;

import std.array;

import til.nodes;
import til.ranges;

debug
{
    import std.stdio;
}

struct CommandContext
{
    Process escopo;
    ExitCode exitCode = ExitCode.Proceed;

    /*
    Commands CAN pop beyond local zero, so
    resist the temptation to make it
    an uint.
    */
    int size = 0;

    Range stream = null;

    @disable this();
    this(Process escopo)
    {
        this(escopo, 0);
    }
    this(Process escopo, int argumentCount)
    {
        this.escopo = escopo;
        this.size = argumentCount;
    }
    CommandContext next()
    {
        return this.next(0);
    }
    CommandContext next(int argumentCount)
    {
        return this.next(escopo, argumentCount);
    }
    CommandContext next(Process escopo)
    {
        return this.next(escopo, 0);
    }
    CommandContext next(Process escopo, int argumentCount)
    {
        auto newContext = CommandContext(escopo, argumentCount);
        // Pass along stream and any other data
        // shared between commands int the
        // pipeline:
        newContext.stream = this.stream;
        return newContext;
    }

    string toString()
    {
        string s = "STACK:" ~ to!string(escopo.stackAsString);
        s ~= " (" ~ to!string(size) ~ ")";
        s ~= " process " ~ to!string(this.escopo.index);
        return s;
    }

    // Stack-related things:
    ListItem peek()
    {
        return escopo.peek();
    }
    template pop(T : ListItem)
    {
        T pop()
        {
            auto info = typeid(T);
            debug {stderr.writeln("popping as a class: ", info);}
            auto value = this.pop();
            return cast(T)value;
        }
    }
    template pop(T : long)
    {
        T pop()
        {
            auto value = this.pop();
            return value.toInt;
        }
    }
    template pop(T : float)
    {
        T pop()
        {
            auto value = this.pop();
            return value.toFloat;
        }
    }
    template pop(T : bool)
    {
        T pop()
        {
            auto value = this.pop();
            return value.toBool;
        }
    }
    template pop(T : string)
    {
        T pop()
        {
            auto value = this.pop();
            return value.toString;
        }
    }
    ListItem pop()
    {
        size--;
        return escopo.pop();
    }
    ListItem[] pop(uint count)
    {
        return this.pop(cast(ulong)count);
    }
    ListItem[] pop(ulong count)
    {
        size -= count;
        return escopo.pop(count);
    }
    template pop(T)
    {
        T[] pop(ulong count)
        {
            T[] items;
            foreach(i; 0..count)
            {
                items ~= pop!T;
            }
            return items;
        }
    }

    CommandContext push(ListItem item)
    {
        escopo.push(item);
        size++;
        return this;
    }
    template push(T)
    {
        CommandContext push(T x)
        {
            escopo.push(x);
            size++;
            return this;
        }
    }
    template items(T)
    {
        T[] items()
        {
            if (size > 0)
            {
                return pop!T(size);
            }
            else
            {
                return [];
            }
        }
    }
    Items items()
    {
        if (size > 0)
        {
            auto x = size;
            size = 0;
            return escopo.pop(x);
        }
        else
        {
            return [];
        }
    }

    void assimilate(CommandContext other)
    {
        this.size += other.size;
        // XXX : should we care about other.stream???
        // I don't think so, but not sure...
    }

    // Scheduler-related things
    void yield()
    {
        escopo.yield();
    }

    // Execution
    void run(CommandContext function(CommandContext) f)
    {
        return this.run(f, 0);
    }
    void run(CommandContext function(CommandContext) f, int argumentCount)
    {
        auto rContext = f(this.next(argumentCount));
        this.assimilate(rContext);
    }
    void run(CommandContext delegate(CommandContext) f)
    {
        auto rContext = f(this.next);
        this.assimilate(rContext);
    }

    // Errors
    CommandContext error(string message, int code, string classe)
    {
        auto e = new Erro(escopo, message, code, classe);
        push(e);
        this.exitCode = ExitCode.Failure;
        this.stream = null;

        /*
        Return this so we can simply write
        "return context.error(...)"
        inside commands
        implementations
        */
        return this;
    }
}
