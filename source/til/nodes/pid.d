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
