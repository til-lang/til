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
        this.commandPrefix = "pid";
    }

    override CommandContext extract(CommandContext context)
    {
        if (context.size == 0) return context.push(this);

        string key = context.pop!string;
        switch (key)
        {
            case "state":
                return context.push(to!string(process.state));

            default:
                auto msg = "Invalid argument to Pid extraction";
                return context.error(msg, ErrorCode.InvalidArgument, "");
        }
    }

    override string toString()
    {
        return "Pid for Process " ~ to!string(this.process.index);
    }
}
