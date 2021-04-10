module til.context;

import til.nodes;


struct CommandContext
{
    Process escopo;
    ExitCode exitCode = ExitCode.Proceed;
    uint size = 0;
    // Range stream = null;

    @disable this();
    this(Process escopo)
    {
        this.escopo = escopo;
        this.size = 0;
    }
    CommandContext next()
    {
        return this.next(escopo);
    }
    CommandContext next(Process escopo)
    {
        auto newContext = CommandContext(this.escopo);
        // Pass along stream and any other data
        // shared between commands int the
        // pipeline:
        // TODO: re-enable this: newContext.stream = this.stream;
        newContext.escopo = escopo;
        return newContext;
    }

    string toString()
    {
        string s = "STACK:" ~ to!string(escopo.stack);
        s ~= " (" ~ to!string(size) ~ ")";
        return s;
    }

    // Stack-related things:
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

    ulong stackSize()
    {
        return this.escopo.stack.length;
    }
}
