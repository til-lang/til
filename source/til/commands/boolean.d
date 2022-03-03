module til.commands.boolean;

import std.array;
import std.regex : matchAll, matchFirst;
import std.string;

import til.nodes;

template CreateComparisonOperator(string cmdName, string operator)
{
    const string CreateComparisonOperator = "
        booleanCommands[\"" ~ cmdName ~ "\"] = new Command((string path, Context context)
        {
            if (context.size < 2)
            {
                auto msg = \"`\" ~ path ~ \"` expects at least 2 arguments\";
                return context.error(msg, ErrorCode.InvalidArgument, \"int\");
            }

            bool pivot = context.pop!bool();
            foreach (item; context.items)
            {
                bool x = item.toBool();
                if (!(pivot " ~ operator ~ " x))
                {
                    return context.push(false);
                }
                pivot = x;
            }
            return context.push(true);
        });
        booleanCommands[\"" ~ operator ~ "\"] = booleanCommands[\"" ~ cmdName ~ "\"];
        ";
}

// Commands:
static this()
{
    mixin(CreateComparisonOperator!("eq", "=="));
    mixin(CreateComparisonOperator!("neq", "!="));

    booleanCommands["||"] = new Command((string path, Context context)
    {
        if (context.size < 2)
        {
            auto msg = "`" ~ path ~ "` expects at least 2 arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "bool");
        }

        foreach (item; context.items)
        {
            if (item.toBool())
            {
                return context.push(true);
            }
        }
        return context.push(false);
    });
    booleanCommands["&&"] = new Command((string path, Context context)
    {
        if (context.size < 2)
        {
            auto msg = "`" ~ path ~ "` expects at least 2 arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "bool");
        }

        foreach (item; context.items)
        {
            if (!item.toBool())
            {
                return context.push(false);
            }
        }
        return context.push(true);
    });
}
