module til.ranges;

import std.conv;
import std.range;

import til.nodes;

/*
This Range implements a ForwardRange interface.
It's not explicitly put here because... well,
it just breaks everything and I'm in no
mood right now to find the proper way
of using it.

Contributions are welcome. I believe the
right way would be
class Range : ForwardRange!(ListItem)
but, again, that breaks things so
I'm not very sure.
*/
class Range
{
    abstract bool empty();
    abstract ListItem front();
    abstract void popFront();
    abstract ulong length();
    abstract Range save();
    override abstract string toString();

    // It's actually VERY important that
    // every new Range you create implement
    // it's own asString since the resulting
    // value is used INSIDE the language
    // itself (not only as as debugging tool).
    abstract string asString();

    ListItem consume()
    {
        ListItem x = this.front;
        this.popFront();
        return x;
    }
}

class InfiniteRange : Range
{
    override ulong length()
    {
        return 0;
    }
    override bool empty()
    {
        return false;
    }

    /*
       The thing with infinite ranges
       is that their representation as
       strings is kind of useless in any
       scenario so in this particular case
       it's wiser to simply represent them
       in a way that helps the user to
       detect when a unintended
       conversion was made.
    */
    override string asString()
    {
        return this.toString();
    }
}

class StaticItems : Range
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

    override StaticItems save()
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

class ChainedItems : Range
{
    Range[] _generators;
    ulong currentRangeIndex = 0;
    ulong _length;

    this(Range[] generators)
    {
        this._generators = generators;
        foreach(g; generators)
        {
            this._length += g.length;
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
            if (currentRangeIndex == idx)
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

    Range currentRange()
    {
        if (currentRangeIndex >= this._generators.length)
        {
            return null;
        }
        return this._generators[currentRangeIndex];
    }
    Range getNextRange()
    {
        auto idx = currentRangeIndex + 1;
        if (idx >= _generators.length)
        {
            return null;
        }
        return _generators[idx];
    }

    override ChainedItems save()
    {
        Range[] copies;
        foreach(g; _generators)
        {
            copies ~= g.save();
        }
        auto result = new ChainedItems(copies);
        result.currentRangeIndex = this.currentRangeIndex;
        return result;
    }

    override ulong length()
    {
        return this._length;
    }
    override bool empty()
    {
        auto c = this.currentRange;
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
            c = this.getNextRange();
            return (c is null);
        }
    }
    override ListItem front()
    {
        return currentRange.front();
    }
    override void popFront()
    {
        currentRange.popFront();
        if (currentRange.empty)
        {
            this.currentRangeIndex++;
        }
    }
}
