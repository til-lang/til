module til.std.msgbox;

import til.nodes;


CommandHandler[string] commands;

static this()
{
    commands["set"] = (string path, CommandContext context)
    {
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["receive"] = (string path, CommandContext context)
    {
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["send"] = (string path, CommandContext context)
    {
        // use `path` to know to which PID to send.
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
}
