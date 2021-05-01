module til.ranges;

import til.nodes;


class Range
{
    abstract bool empty();
    abstract ListItem front();
    abstract void popFront();
    override string toString()
    {
        return "Range";
    }
}

class InfiniteRange : Range
{
    override bool empty()
    {
        return false;
    }
    override string toString()
    {
        return "InfiniteRange";
    }
}
