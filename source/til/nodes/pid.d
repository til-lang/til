module til.nodes.pid;

import std.conv : to;

import til.nodes;

debug
{
    import std.stdio;
}

class Pid : ListItem
{
    Process process = null;
    this(Process process)
    {
        this.process = process;
    }

    override string asString()
    {
        return "PID(" ~ to!string(process.index) ~ ")";
    }
    override int asInteger()
    {
        return cast(int)process.index;
    }
    override float asFloat()
    {
        return cast(float)process.index;
    }
    override bool asBoolean()
    {
        return true;
    }
    override ListItem inverted()
    {
        throw new Exception("Cannot invert a PID");
    }

    // TODO: extractions
    // state : process.state
    // msgbox.size
    // msgbox.counter
    // msgbox.state (full or not)

    // -------------------
    void send(ListItem message)
    {
        debug {stderr.writeln("Sending ", message, " to ", process.index, " msgbox...");}
        // Block current process until there's enough
        // space in the other process msgbox:
        while(process.msgbox.length >= process.msgboxSize)
        {
            debug {stderr.writeln(" msgbox full!!! ");}
            process.scheduler.yield();
        }
        process.msgbox ~= message;
        debug {stderr.writeln(this, " msgbox: ", process.msgbox);}
    }
}
