module til.commands.name;

import til.nodes;


// Commands:
static this()
{
    nameCommands["operate"] = new Command((string path, Context context)
    {
        Item rhs = context.pop();
        Item operator = context.pop();
        Item lhs = context.pop();

        switch(to!string(operator))
        {
            case "==":
                context.push(to!string(lhs) == to!string(rhs));
                break;
            case "!=":
                context.push(to!string(lhs) != to!string(rhs));
                break;
            default:
                context.push(rhs);
                context.push(operator);
                return lhs.reverseOperate(context);
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
}
