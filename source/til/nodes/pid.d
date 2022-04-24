module til.nodes.pid;

import std.conv : to;
import std.string : toLower;

import til.nodes;
import til.process;


CommandsMap pidCommands;


class Pid : Item
{
    Process process;
    auto type = ObjectType.Pid;
    const typeName = "pid";

    this(Process process)
    {
        this.process = process;
        this.commands = pidCommands;
    }

    override string toString()
    {
        return "Pid for Process " ~ to!string(this.process.index);
    }
}
