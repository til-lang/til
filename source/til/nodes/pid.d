module til.nodes.pid;

import std.conv : to;
import std.string : toLower;

import til.nodes;
import til.scheduler : ProcessFiber;

debug
{
    import std.stdio;
}

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

    override Context extract(Context context)
    {
        if (context.size == 0) return context.push(this);

        string key = context.pop!string;
        switch (key)
        {
            case "state":
                return context.push(to!string(process.state));

            case "is_running":
                return context.push(process.state != ProcessState.Finished);

            case "exit_code":
                Context processContext = fiber.context;

                // XXX: is it correct???
                if (&processContext is null)
                {
                    auto msg = "Process " ~ to!string(process.index) ~ " is still running";
                    return context.error(msg, ErrorCode.SemanticError, "");
                }
                string exit_code = to!string(processContext.exitCode).toLower();
                return context.push(exit_code);

            default:
                auto msg = "Invalid argument to Pid extraction";
                return context.error(msg, ErrorCode.InvalidArgument, "");
        }
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
