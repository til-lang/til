module til.commands.error;

import til.nodes;


// Commands:
static this()
{
    errorCommands["extract"] = new Command((string path, Context context)
    {
        auto target = context.pop!Erro();
        auto args = context.items!string;
        auto arg = args.join(" ");

        switch(arg)
        {
            case "code":
                return context.push(target.code);
            case "message":
                return context.push(target.message);
            case "class":
                return context.push(target.classe);
            case "object":
                return context.push(target.object);
            default:
                auto msg = "Invalid argument to Error extraction";
                return context.error(msg, ErrorCode.InvalidArgument, "");
        }
    });
    errorCommands["return"] = new Command((string path, Context context)
    {
        // Do not pop the error: we would stack it back, anyway...
        // auto target = context.pop!Erro();
        context.exitCode = ExitCode.Failure;
        return context;
    });
}
