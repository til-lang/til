module til.std.math;

import til.math;
import til.nodes;

CommandHandler[string] commands;

// Commands:
static this()
{
    commands["run"] = (Process escopo, string path, CommandResult result)
    {
        auto arguments = result.arguments(escopo);
        ListItem r = int_resolve(escopo, arguments);
        escopo.push(r);
        result.exitCode = ExitCode.CommandSuccess;
        return result;
    };
}
