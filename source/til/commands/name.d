module til.commands.name;

import til.nodes;


// Commands:
static this()
{
    nameCommands["eq"] = new Command((string path, Context context)
    {
        if (context.size < 2)
        {
            auto msg = "`" ~ path ~ "` expects at least 2 arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "int");
        }

        string first = context.pop!string();
        foreach (item; context.items)
        {
            if (item.toString() != first)
            {
                return context.push(false);
            }
        }
        return context.push(true);
    });
    nameCommands["=="] = nameCommands["eq"];
    nameCommands["neq"] = new Command((string path, Context context)
    {
        if (context.size < 2)
        {
            auto msg = "`" ~ path ~ "` expects at least 2 arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "int");
        }

        string first = context.pop!string();
        foreach (item; context.items)
        {
            if (item.toString() == first)
            {
                return context.push(false);
            }
        }
        return context.push(true);
    });
    nameCommands["!="] = nameCommands["neq"];
}
