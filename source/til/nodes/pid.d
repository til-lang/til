module til.nodes.pid;

import std.conv : to;

import til.nodes;
import til.scheduler : ProcessFiber;

debug
{
    import std.stdio;
}

CommandHandler[string] pidCommands;


class Pid : ListItem
{
    ProcessFiber fiber;
    Process process;

    this(ProcessFiber fiber)
    {
        this.fiber = fiber;
        this.process = fiber.process;
        this.commands = pidCommands;
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
