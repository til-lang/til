module til.stack;


import til.nodes;


class Stack
{
    Item[64] stack;
    uint stackPointer = 0;

    // Stack manipulation:
    Item peek(uint index=1)
    {
        uint pointer = stackPointer - index;
        if (pointer < 0)
        {
            return null;
        }
        return stack[pointer];
    }
    Item pop()
    {
        auto item = stack[--stackPointer];
        return item;
    }
    Items pop(int count)
    {
        return this.pop(cast(ulong)count);
    }
    Items pop(ulong count)
    {
        Items items;
        foreach(i; 0..count)
        {
            items ~= pop();
        }
        return items;
    }
    void push(Item item)
    {
        stack[stackPointer++] = item;
    }
    template push(T : int)
    {
        void push(T x)
        {
            return push(new IntegerAtom(x));
        }
    }
    template push(T : long)
    {
        void push(T x)
        {
            return push(new IntegerAtom(x));
        }
    }
    template push(T : float)
    {
        void push(T x)
        {
            return push(new FloatAtom(x));
        }
    }
    template push(T : bool)
    {
        void push(T x)
        {
            return push(new BooleanAtom(x));
        }
    }
    template push(T : string)
    {
        void push(T x)
        {
            return push(new String(x));
        }
    }

    bool isEmpty()
    {
        return stackPointer == 0;
    }

    override string toString()
    {
        if (stackPointer == 0) return "empty";
        return to!string(stack[0..stackPointer]);
    }
}
