module til.context;

import std.array;

import til.nodes;


struct Context
{
    Process escopo;
    Command command;
    ExitCode exitCode = ExitCode.Proceed;
    bool hasInput = false;

    /*
    Commands CAN pop beyond local zero, so
    resist the temptation to make it
    an uint.
    */
    int size = 0;

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
    Context next()
    {
        return this.next(0);
    }
    Context next(int argumentCount)
    {
        return this.next(escopo, argumentCount);
    }
    Context next(Process escopo)
    {
        return this.next(escopo, 0);
    }
    Context next(Process escopo, int argumentCount)
    {
        this.size -= argumentCount;
        auto newContext = Context(escopo, argumentCount);
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
    ListItem peek(uint index=1)
    {
        return escopo.peek(index);
    }
    template pop(T : ListItem)
    {
        T pop()
        {
            auto info = typeid(T);
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

    Context push(ListItem item)
    {
        escopo.push(item);
        size++;
        return this;
    }
    Context push(Items items)
    {
        foreach(item; items)
        {
            push(item);
        }
        return this;
    }
    template push(T)
    {
        Context push(T x)
        {
            escopo.push(x);
            size++;
            return this;
        }
    }
    Context ret(ListItem item)
    {
        push(item);
        exitCode = ExitCode.CommandSuccess;
        return this;
    }
    Context ret(Items items)
    {
        this.push(items);
        exitCode = ExitCode.CommandSuccess;
        return this;
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

    void assimilate(Context other)
    {
        this.size += other.size;
    }

    // Scheduler-related things
    void yield()
    {
        escopo.yield();
    }

    // Execution
    void run(Context function(Context) f)
    {
        return this.run(f, 0);
    }
    void run(Context function(Context) f, int argumentCount)
    {
        auto rContext = f(this.next(argumentCount));
        this.assimilate(rContext);
    }
    void run(Context delegate(Context) f)
    {
        auto rContext = f(this.next);
        this.assimilate(rContext);
    }

    // Errors
    Context error(string message, int code, string classe)
    {
        return this.error(message, code, classe, null);
    }
    Context error(string message, int code, string classe, Item object)
    {
        auto e = new Erro(escopo, message, code, classe, object);
        push(e);
        this.exitCode = ExitCode.Failure;
        return this;
    }
}
