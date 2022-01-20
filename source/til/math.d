module til.math;

import std.algorithm : canFind;
import std.conv : to;
import std.range;

import til.nodes;

debug
{
    import std.stdio;
}

SimpleList applyPrecedenceRules(SimpleList list)
{
    /*
    mul/div: 1 + 2 < 3 * 5 || 30 > 20 && 20 > 10
          -> 1 + 2 < (3 * 5) || 30 > 20 && 20 > 10

    sum/sub: 1 + 2 < (3 * 5) || 30 > 20 && 20 > 10
         -> (1 + 2) < (3 * 5) || 30 > 20 && 20 > 10

    comparisons:  (1 + 2) < (3 * 5) || 30 > 20 && 20 > 10
               -> ((1 + 2) < (3 * 5)) || (30 > 20) && (20 > 10)

    and: ((1 + 2) < (3 * 5)) || (30 > 20) && (20 > 10)
      -> ((1 + 2) < (3 * 5)) || ((30 > 20) && (20 > 10))

    or: ((1 + 2) < (3 * 5)) || ((30 > 20) && (20 > 10))
     -> ((1 + 2) < (3 * 5)) || ((30 > 20) && (20 > 10))
    */

    return list;
}

Context math(Context context)
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
        debug {stderr.writeln("math.item:", item);}
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
            if (context.size == 1)
            {
                lastOperator = to!string(item);
            }
            debug {stderr.writeln(" math.push:", item);}
            context.push(item);
        }
    }

    context.exitCode = ExitCode.CommandSuccess;
    return context;
}
