module til.math;

import std.algorithm : canFind;
import std.conv : to;
import std.range;

import til.nodes;

debug
{
    import std.stdio;
}

CommandContext math(CommandContext context)
{
    // There should be a SimpleList at the top of the stack.
    auto list = cast(SimpleList)context.pop();
    context = list.evaluate(context, true);
    list = cast(SimpleList)context.pop();
    Items items = list.items;

    // -----------------------------------------------
    // The loop:
    string lastOperator;
    foreach(item; items)
    {
        if (item.type == ObjectType.SimpleList)
        {
            context.push(item);
            auto mathContext = math(context.next(1));
            // TODO: check exitCode.

            // `math` always return a USABLE value,
            // like 123.456 or false.
            item = mathContext.pop();
        }

        // -------------------
        if (context.size == 2)
        {
            switch (lastOperator)
            {
                case "&&":
                    context.pop(); // the operator
                    auto t1 = context.pop();
                    context.push(t1.toBool() && item.toBool());
                    break;
                case "||":
                    context.pop(); // the operator
                    auto t1 = context.pop();
                    context.push(t1.toBool() || item.toBool());
                    break;
                default:
                    context = item.operate(context);
            }
        }
        else
        {
            if (item.type == ObjectType.Operator)
            {
                lastOperator = to!string(item);
            }
            context.push(item);
        }
    }

    context.exitCode = ExitCode.CommandSuccess;
    return context;
}
