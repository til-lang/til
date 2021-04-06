module til.ranges;

import std.conv;
import std.experimental.logger;
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
        if (this.empty)
        {
            return null;
        }
        else
        {
            ListItem x = this.front;
            this.popFront();
            return x;
        }
    }
    ListItem consume(int defaultValue)
    {
        if (this.empty)
        {
            return new Atom(defaultValue);
        }
        else
        {
            ListItem x = this.front;
            this.popFront();
            return x;
        }
    }
    abstract Range exhaust();
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
    override Range exhaust()
    {
        /*
        We COULD "exhaust" an InfiniteRange by forcing
        the remaining range to be empty.
        But not now...
        */
        throw new Exception("Trying to exhaust an InfiniteRange");
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
    override Range exhaust()
    {
        auto copy = this.save();
        this.currentIndex = this._length;
        return copy;
    }
}

class ChainedItems : Range
{
    Range[] _ranges;
    ulong currentRangeIndex = 0;
    ulong _length;

    this(Range[] generators)
    {
        foreach(g; generators)
        {
            if (!g.empty)
            {
                this._ranges ~= g;
                this._length += g.length;
            }
        }
    }

    override string asString()
    {
        if (this.empty)
        {
            return "<ChainedItems:empty>";
        }
        return this.front.asString;
    }
    override string toString()
    {
        if (this.empty)
        {
            return "ChainedItems:empty";
        }

        string s = "ChainedItems(\n";
        foreach(idx, g; _ranges)
        {
            s ~= g.save().toString();
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
        if (currentRangeIndex >= this._ranges.length)
        {
            return null;
        }
        return this._ranges[currentRangeIndex];
    }
    Range getNextRange()
    {
        auto idx = currentRangeIndex + 1;
        if (idx >= _ranges.length)
        {
            return null;
        }
        return _ranges[idx];
    }

    override Range save()
    {
        if (this.empty)
        {
            // TESTE:
            return new ChainedItems([]);
        }

        /*
        A ChainedItems Range with only one range
        left should return this range.
        */
        auto x = currentRangeIndex - 1;
        if (x == _ranges.length)
        {
            trace("ChainedItems changed for its tail!");
            return _ranges[x].save();
        }

        Range[] copies;
        auto index = currentRangeIndex;
        foreach(g; _ranges)
        {
            if (g.empty)
            {
                index--;
            }
            else
            {
                copies ~= g.save();
            }
        }
        auto result = new ChainedItems(copies);
        result.currentRangeIndex = index;
        return result;
    }
    override Range exhaust()
    {
        auto copy = this.save();
        this.currentRangeIndex = this._ranges.length;
        return copy;
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
            return (c is null || c.empty);
        }
    }
    override ListItem front()
    {
        auto c = this.currentRange;
        if (c is null)
        {
            throw new Exception(
                "Trying to get .front from probably"
                ~ " empty ChainedItems Range"
            );
        }
        return c.front();
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
