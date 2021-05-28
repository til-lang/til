module libs.std.pid;

import til.nodes;


CommandHandler[string] commands;


static this()
{
    commands["send"] = (string path, CommandContext context)
    {
        if (context.size > 2)
        {
            auto msg = "`send` expect only two arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        Pid pid = cast(Pid)context.pop();
        auto value = context.pop();

        // If we *have* the Pid, the input *is* a ProcessIORange.
        auto input = cast(ProcessIORange)pid.process.input;
        input.write(value);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
}
