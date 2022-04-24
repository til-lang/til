module til.commands.pids;

import core.thread.fiber;
import std.string : toLower;

import til.nodes;
import til.commands;


// Commands:
static this()
{
    pidCommands["extract"] = new Command((string path, Context context)
    {
        if (context.size == 0) return context;

        Pid target = context.pop!Pid;
        auto process = target.process;
        string key = context.pop!string;
        switch (key)
        {
            case "state":
                return context.push(to!string(process.state));

            case "is_running":
                return context.push(process.state != Fiber.State.TERM);

            case "exit_code":
                Context processContext = target.process.context;

                // XXX: is it correct???
                if (&processContext is null)
                {
                    auto msg = "Process " ~ to!string(process.index) ~ " is still running";
                    return context.error(msg, ErrorCode.SemanticError, "pid");
                }
                string exit_code = to!string(processContext.exitCode).toLower();
                return context.push(exit_code);

            default:
                auto msg = "Invalid argument to Pid extraction";
                return context.error(msg, ErrorCode.InvalidArgument, "");
        }
    });
}
