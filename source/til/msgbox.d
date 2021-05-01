module til.msgbox;

import std.conv : to;
import std.range;

import til.nodes;
import til.ranges;

debug
{
    import std.stdio;
}


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
        debug {stderr.writeln("process.msgbox:", process.msgbox);}
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
