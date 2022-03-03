module til.commands.floats;

import til.nodes;


template CreateOperator(string cmdName, string operator)
{
    const string CreateOperator = "
        floatCommands[\"" ~ cmdName ~ "\"] = new Command((string path, Context context)
        {
            if (context.size < 2)
            {
                auto msg = \"`\" ~ path ~ \"` expects at least 2 arguments\";
                return context.error(msg, ErrorCode.InvalidArgument, \"float\");
            }

            float result = context.pop!float();
            foreach (item; context.items)
            {
                result = result " ~ operator ~ " item.toFloat();
            }
            return context.push(result);
        });
        floatCommands[\"" ~ operator ~ "\"] = floatCommands[\"" ~ cmdName ~ "\"];
        ";
}
template CreateComparisonOperator(string cmdName, string operator)
{
    const string CreateComparisonOperator = "
        floatCommands[\"" ~ cmdName ~ "\"] = new Command((string path, Context context)
        {
            if (context.size < 2)
            {
                auto msg = \"`\" ~ path ~ \"` expects at least 2 arguments\";
                return context.error(msg, ErrorCode.InvalidArgument, \"float\");
            }

            float pivot = context.pop!float();
            foreach (item; context.items)
            {
                float x = item.toFloat();
                if (!(pivot " ~ operator ~ " x))
                {
                    return context.push(false);
                }
                pivot = x;
            }
            return context.push(true);
        });
        floatCommands[\"" ~ operator ~ "\"] = floatCommands[\"" ~ cmdName ~ "\"];
        ";
}


// Commands:
static this()
{
    mixin(CreateOperator!("sum", "+"));
    mixin(CreateOperator!("sub", "-"));
    mixin(CreateOperator!("mul", "*"));
    mixin(CreateOperator!("div", "/"));
    mixin(CreateOperator!("mod", "%"));

    floatCommands["eq"] = new Command((string path, Context context)
    {
        if (context.size < 2)
        {
            auto msg = "`" ~ path ~ "` expects at least 2 arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "float");
        }

        float pivot = cast(int)(context.pop!float() * 1000);
        foreach (item; context.items)
        {
            float x = cast(int)(item.toFloat() * 1000);
            if (pivot != x)
            {
                return context.push(false);
            }
            pivot = x;
        }
        return context.push(true);
    });
    floatCommands["=="] = floatCommands["eq"];

    floatCommands["neq"] = new Command((string path, Context context)
    {
        if (context.size < 2)
        {
            auto msg = "`" ~ path ~ "` expects at least 2 arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "float");
        }

        float pivot = cast(int)(context.pop!float() * 1000);
        foreach (item; context.items)
        {
            float x = cast(int)(item.toFloat() * 1000);
            if (pivot == x)
            {
                return context.push(false);
            }
            pivot = x;
        }
        return context.push(true);
    });
    floatCommands["!="] = floatCommands["neq"];

    mixin(CreateComparisonOperator!("gt", ">"));
    mixin(CreateComparisonOperator!("lt", "<"));
    mixin(CreateComparisonOperator!("gte", ">="));
    mixin(CreateComparisonOperator!("lte", "<="));
}
