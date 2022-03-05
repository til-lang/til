module til.commands.error;

import til.nodes;


// Commands:
static this()
{
    errorCommands["extract"] = new Command((string path, Context context)
    {
        if (context.size == 0) return context;

        Erro target = context.pop!Erro();
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
}
