module til.context;

import std.array;

import til.process;
import til.nodes;


struct Context
{
    Escopo escopo;
    Process process;
    ExitCode exitCode = ExitCode.Success;
    uint inputSize = 0;

    /*
    Commands CAN pop beyond local zero, so
    resist the temptation to make it an uint:
    */
    int size = 0;

    @disable this();
    this(Process process, Escopo escopo, int size=0)
    {
        this.process = process;
        this.escopo = escopo;
        this.size = size;
    }

    Context next(int argumentCount=0)
    {
        return this.next(escopo, argumentCount);
    }
    Context next(Escopo escopo, int size=0)
    {
        this.size -= size;
        auto newContext = Context(process, escopo, size);
        return newContext;
    }

    string toString()
    {
        string s = " process " ~ to!string(process.index);
        s ~= " (" ~ to!string(size) ~ ")";
        return s;
    }
    string description()
    {
        string[] path;

        auto pivot = escopo;
        while (pivot !is null)
        {
            if (pivot.description)
            {
                path ~= pivot.description;
            }
            else
            {
                path ~= "?";
            }
            pivot = pivot.parent;
        }

        if (process.description)
        {
            path ~= process.description;
        }
        else
        {
            path ~= "?";
        }

        return path.retro.join("/");
    }

    // Stack-related things:
    Item peek(uint index=1)
    {
        return process.stack.peek(index);
    }
    template pop(T : Item)
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
    Item pop()
    {
        size--;
        return process.stack.pop();
    }
    Item popOrNull()
    {
        if (process.stack.isEmpty)
        {
            return null;
        }
        else
        {
            return this.pop();
        }
    }

    Item[] pop(uint count)
    {
        return this.pop(cast(ulong)count);
    }
    Item[] pop(ulong count)
    {
        size -= count;
        return process.stack.pop(count);
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

    Context push(Item item)
    {
        process.stack.push(item);
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
            process.stack.push(x);
            size++;
            return this;
        }
    }
    Context ret(Item item)
    {
        push(item);
        exitCode = ExitCode.Success;
        return this;
    }
    Context ret(Items items)
    {
        this.push(items);
        exitCode = ExitCode.Success;
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
            return process.stack.pop(x);
        }
        else
        {
            return [];
        }
    }

    // Errors
    Context error(string message, int code, string classe, Item object=null)
    {
        auto e = new Erro(message, code, classe, this, object);
        push(e);
        this.exitCode = ExitCode.Failure;
        return this;
    }
}
