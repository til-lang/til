module til.nodes.pid;

import std.conv : to;
import std.string : toLower;

import til.nodes;
import til.scheduler : ProcessFiber;


CommandsMap pidCommands;


class Pid : ListItem
{
    ProcessFiber fiber;
    Process process;
    auto type = ObjectType.Pid;
    const typeName = "pid";

    this(ProcessFiber fiber)
    {
        this.fiber = fiber;
        this.process = fiber.process;
        this.commands = pidCommands;
    }

    override string toString()
    {
        return "Pid for Process " ~ to!string(this.process.index);
    }
    override Context next(Context context)
    {
        return this.process.output.next(context);
    }
}
