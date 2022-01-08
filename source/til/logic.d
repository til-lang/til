module til.logic;

import std.conv : to;
import std.range : popFront;

import til.math;
import til.nodes;

debug
{
    import std.stdio;
}


CommandContext boolean(CommandContext context)
{
    assert(context.size == 1);
    // Resolve any math beforehand:
    auto resolvedContext = int_run(context);
    assert(resolvedContext.size == 1);
    return pureBoolean(resolvedContext);
}

CommandContext pureBoolean(CommandContext context)
{
    // There should be a SimpleList at the top of the stack.
    auto list = cast(SimpleList)context.pop();
    Items items = list.items;

    bool currentResult = false;

    // -----------------------------------------------
    void operate()
    {
        // It was pushed in reading order...
        auto t2 = context.pop();
        auto operator = context.pop!string;
        auto t1 = context.pop();

        ListItem newResult = t1.operate(operator, t2, false);
        if (newResult is null)
        {
            newResult = t2.operate(operator, t1, true);
        }

        if (newResult is null)
        {
            throw new Exception(
                "Unknown operator: "
                ~ operator
            );
        }
        currentResult = currentResult || newResult.toBool();
    }

    // -----------------------------------------------
    // Logical operators:
    /*
    About `and` & `or`:
    AND has precedence over OR.

    Take for instance `f or t and t`. It should return true.
    (The explicit version would be `(f or t) and t`.)
    */
    void and(ulong index)
    {
        auto nextList = new SimpleList(items[index..$]);
        context.push(nextList);

        context = boolean(context.next(1));
        auto newResult = context.pop();
        currentResult = currentResult && newResult.toBool();
    }

    // -----------------------------------------------
    // The loop:
    foreach(index, item; items)
    {
        string s = to!string(item);

        debug {stderr.writeln(" item: ", s);}

        if (item.type == ObjectType.Operator)
        {
            /*
           A logic expression is just a sequence
           of ands and ors. "Or" is the default
           operation.
            */
            if (s == "&&")
            {
                and(index + 1);
                break;
            }
            else if (s == "||")
            {
                // situation                         : context.size
                // (1 > 2 || true)                   : 0
                // (1 > 2 || false || true)          : 1
                //                 ^^
                // (1 > 2 || false != true || 1 < 2) : 3
                //                         ^^
                if (context.size == 3)
                {
                    // (1 > 2 || false != true || 1 < 2)
                    //                         ^^
                    debug {stderr.writeln(" context.size is 3");}
                    operate();
                }
                else if (context.size == 1)
                {
                    // (1 > 2 || false || 1 < 2)
                    //  false      ^   ^^
                    //       lastItem  item
                    auto lastItem = context.pop();
                    debug {stderr.writeln(" context.size is 1: ", lastItem);}
                    currentResult = currentResult || lastItem.toBool();
                }
                else if (context.size == 2)
                {
                    throw new Exception(
                        "Invalid operation (only "
                        ~ to!string(context.size)
                        ~ " items)"
                    );
                }
                continue;
            }
        }
        else if (item.type == ObjectType.SimpleList)
        {
            SimpleList l = cast(SimpleList)item;
            auto listContext = l.evaluate(context, true);
            listContext = boolean(listContext);
            // There should be an Atom(bool) at the top of the stack.
            auto newResult = listContext.pop();
            currentResult = currentResult || newResult.toBool();
            continue;
        }

        if (item.type == ObjectType.Operator)
        {
            context.push(item);
            continue;
        }

        // Not an operator? Must be a value...
        context.push(item);
        if (context.size >= 3)
        {
            operate();
        }
    }

    // assert (true) -> context.size = 1
    if (context.size != 1)
    {
        context.push(currentResult);
    }

    if (context.size != 1)
    {
        throw new Exception(
            "Context size is not 1: "
            ~ to!string(context.items)
            ~ " (currentResult: "
            ~ to!string(currentResult)
            ~ ")"
        );
    }
    return context;
}
