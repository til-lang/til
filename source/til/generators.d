module til.generators;

import std.conv;

import til.nodes;


class Generator
{
    bool isInfinite = false;

    abstract bool empty();
    abstract ListItem front();
    abstract void popFront();
    abstract ulong length();
    abstract Generator copy();
    override abstract string toString();
    abstract string asString();

    ListItem consume()
    {
        ListItem x = this.front;
        this.popFront();
        return x;
    }
}

class InfiniteGenerator : Generator
{
    bool isInfinite = true;

    override ulong length()
    {
        return 0;
    }
    override bool empty()
    {
        return false;
    }
    override string asString()
    {
        return this.toString();
    }
}

class StaticItems : Generator
{
    ListItem[] _items;
    ulong currentIndex = 0;
    ulong _length;

    this(ListItem item)
    {
        this([item]);
    }
    this(ListItem[] items)
    {
        this._items = items;
        this._length = items.length;
    }

    override string asString()
    {
        return this.toString();
    }
    override string toString()
    {
        return to!string(this._items);
    }

    override StaticItems copy()
    {
        auto result = new StaticItems(this._items);
        result.currentIndex = this.currentIndex;
        return result;
    }

    override ulong length()
    {
        return this._length;
    }
    override bool empty()
    {
        return currentIndex >= this._length;
    }
    override ListItem front()
    {
        return _items[this.currentIndex];
    }
    override void popFront()
    {
        currentIndex++;
    }
}

class ChainedItems : Generator
{
    Generator[] _generators;
    ulong currentGeneratorIndex = 0;
    ulong _length;

    this(Generator[] generators)
    {
        this._generators = generators;
        foreach(g; generators)
        {
            if (g.isInfinite)
            {
                // If g is a INFINITE Generator,
                // this one is infinite, too.
                this.isInfinite = true;
                this._length = 0;
                break;
            }
            else
            {
                this._length += g.length;
            }
        }
    }

    override string asString()
    {
        return this.front.asString;
    }
    override string toString()
    {
        string s = "ChainedItems(\n";
        foreach(idx, g; _generators)
        {
            s ~= g.toString();
            if (currentGeneratorIndex == idx)
            {
                s ~= " ←\n";
            }
            else
            {
                s ~= "\n";
            }
        }
        s ~= ")";
        return s;
    }

    Generator currentGenerator()
    {
        if (currentGeneratorIndex >= this._generators.length)
        {
            return null;
        }
        return this._generators[currentGeneratorIndex];
    }
    Generator getNextGenerator()
    {
        auto idx = currentGeneratorIndex + 1;
        if (idx >= _generators.length)
        {
            return null;
        }
        return _generators[idx];
    }

    override ChainedItems copy()
    {
        Generator[] copies;
        foreach(g; _generators)
        {
            copies ~= g.copy();
        }
        auto result = new ChainedItems(copies);
        result.currentGeneratorIndex = this.currentGeneratorIndex;
        return result;
    }

    override ulong length()
    {
        return this._length;
    }
    override bool empty()
    {
        auto c = this.currentGenerator;
        if (c is null)
        {
            return true;
        }
        if (!c.empty)
        {
            return false;
        }
        else
        {
            c = this.getNextGenerator();
            return (c is null);
        }
    }
    override ListItem front()
    {
        return currentGenerator.front();
    }
    override void popFront()
    {
        currentGenerator.popFront();
        if (currentGenerator.empty)
        {
            this.currentGeneratorIndex++;
        }
    }
}
