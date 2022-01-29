module til.commands.pids;

import til.nodes;
import til.commands;


// Commands:
static this()
{
    pidCommands["send"] = new Command((string path, Context context)
    {
        if (context.size > 2)
        {
            auto msg = "`send` expects only two arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        auto pid = context.pop!Pid();
        auto value = context.pop();

        // Process input should be a Queue:
        Queue input = cast(Queue)pid.process.input;
        input.push(value);

        return context;
    });
}
