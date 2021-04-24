module til.msgbox;

import std.conv : to;
import std.range;

import til.nodes;
import til.ranges;


class MsgboxRange : Range
{
    Process process;
    this(Process process)
    {
        this.process = process;
    }

    override bool empty()
    {
        return process.msgbox.length == 0;
    }
    override ListItem front()
    {
        return process.msgbox[0];
    }
    override void popFront()
    {
        process.msgbox.popFront();
    }
    override string toString()
    {
        return "MsgboxRange for Process " ~ to!string(process.index);
    }
}
