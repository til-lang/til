module til.context;

import til.nodes;
import til.ranges;


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
        auto newContext = CommandContext(this.escopo, argumentCount);
        // Pass along stream and any other data
        // shared between commands int the
        // pipeline:
        newContext.stream = this.stream;
        newContext.escopo = escopo;
        return newContext;
    }

    string toString()
    {
        string s = "STACK:" ~ to!string(escopo.stack[0..escopo.stackPointer]);
        s ~= " (" ~ to!string(size) ~ ")";
        return s;
    }

    // Stack-related things:
    ListItem peek()
    {
        return escopo.peek();
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
    void push(ListItem item)
    {
        escopo.push(item);
        size++;
    }
    template push(T)
    {
        void push(T x)
        {
            escopo.push(x);
            size++;
        }
    }
    ListItem[] items()
    {
        trace("context.items: ", this);
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
}
