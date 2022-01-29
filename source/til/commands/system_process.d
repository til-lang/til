module til.commands.system_process;

import til.nodes;
import til.commands;


// Commands:
static this()
{
    systemProcessCommands["wait"] = new Command((string path, Context context)
    {
        auto p = context.pop!SystemProcess();
        p.wait();
        return context.push(p.returnCode);
    });
}
