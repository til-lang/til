module til.commands.integer;

import til.nodes;


template CreateOperator(string cmdName, string operator)
{
    const string CreateOperator = "
        integerCommands[\"" ~ cmdName ~ "\"] = new Command((string path, Context context)
        {
            if (context.size < 2)
            {
                auto msg = \"`\" ~ path ~ \"` expects at least 2 arguments\";
                return context.error(msg, ErrorCode.InvalidArgument, \"int\");
            }

            long result = context.pop!long();
            foreach (item; context.items)
            {
                result = result " ~ operator ~ " item.toInt();
            }
            return context.push(result);
        });
        integerCommands[\"" ~ operator ~ "\"] = integerCommands[\"" ~ cmdName ~ "\"];
        ";
}
template CreateComparisonOperator(string cmdName, string operator)
{
    const string CreateComparisonOperator = "
        integerCommands[\"" ~ cmdName ~ "\"] = new Command((string path, Context context)
        {
            if (context.size < 2)
            {
                auto msg = \"`\" ~ path ~ \"` expects at least 2 arguments\";
                return context.error(msg, ErrorCode.InvalidArgument, \"int\");
            }

            long pivot = context.pop!long();
            foreach (item; context.items)
            {
                long x = item.toInt();
                if (!(pivot " ~ operator ~ " x))
                {
                    return context.push(false);
                }
                pivot = x;
            }
            return context.push(true);
        });
        integerCommands[\"" ~ operator ~ "\"] = integerCommands[\"" ~ cmdName ~ "\"];
        ";
}


// Commands:
static this()
{
    // (Please notice: `incr` and `decr` do NOT conform to Tcl "equivalents"!)
    integerCommands["incr"] = new Command((string path, Context context)
    {
        if (context.size != 1)
        {
            auto msg = "`" ~ path ~ "` expects only 1 argument, not " ~ to!string(context.size);
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        foreach (item; context.items)
        {
            auto integer = cast(IntegerAtom)item;

            if (integer.value > ++integer.value)
            {
                auto msg = "integer overflow";
                return context.error(msg, ErrorCode.Overflow, "");
            }
        }
        return context;
    });
    integerCommands["decr"] = new Command((string path, Context context)
    {
        if (context.size != 1)
        {
            auto msg = "`" ~ path ~ "` expects at least 1 argument";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        foreach (item; context.items)
        {
            auto integer = cast(IntegerAtom)item;
            if (integer.value < --integer.value)
            {
                auto msg = "integer underflow";
                return context.error(msg, ErrorCode.Underflow, "");
            }
        }
        return context;
    });
    integerCommands["range"] = new Command((string path, Context context)
    {
        /*
           range 10       # [zero, 10]
           range 10 20    # [10, 20]
           range 10 14 2  # 10 12 14
        */
        auto start = context.pop!long();
        long limit = 0;
        if (context.size)
        {
            limit = context.pop!long();
        }
        else
        {
            // zero to...
            limit = start;
            start = 0;
        }
        if (limit <= start)
        {
            auto msg = "Invalid range";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        long step = 1;
        if (context.size)
        {
            step = context.pop!long();
        }

        class IntegerRange : Item
        {
            long start = 0;
            long limit = 0;
            long step = 1;
            long current = 0;

            this(long limit)
            {
                this.limit = limit;
                this.type = ObjectType.Range;
                this.typeName = "integer_range";
            }
            this(long start, long limit)
            {
                this(limit);
                this.current = start;
                this.start = start;
            }
            this(long start, long limit, long step)
            {
                this(start, limit);
                this.step = step;
            }

            override string toString()
            {
                return
                    "range("
                    ~ to!string(start)
                    ~ ","
                    ~ to!string(limit)
                    ~ ")";
            }

            override Context next(Context context)
            {
                long value = current;
                if (value > limit)
                {
                    context.exitCode = ExitCode.Break;
                }
                else
                {
                    context.push(value);
                    context.exitCode = ExitCode.Continue;
                }
                current += step;
                return context;
            }
        }

        auto range = new IntegerRange(start, limit, step);
        return context.push(range);
    });
    integerCommands["to.char"] = new Command((string path, Context context)
    {
        foreach (item; context.items)
        {
            long x = item.toInt();
            context.push(to!string(cast(char)x));
        }
        return context;
    });
    integerCommands["to.ascii"] = new Command((string path, Context context)
    {
        foreach (item; context.items)
        {
            long l = item.toInt();
            char c = cast(char)(l);
            string s = "" ~ c;
            context.push(s);
        }
        return context;
    });

    mixin(CreateOperator!("sum", "+"));
    mixin(CreateOperator!("sub", "-"));
    mixin(CreateOperator!("mul", "*"));
    mixin(CreateOperator!("div", "/"));
    mixin(CreateOperator!("mod", "%"));
    mixin(CreateComparisonOperator!("eq", "=="));
    mixin(CreateComparisonOperator!("neq", "!="));
    mixin(CreateComparisonOperator!("gt", ">"));
    mixin(CreateComparisonOperator!("lt", "<"));
    mixin(CreateComparisonOperator!("gte", ">="));
    mixin(CreateComparisonOperator!("lte", "<="));
}
