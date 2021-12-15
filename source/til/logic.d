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
        if (context.size < 3)
        {
            return;
        }

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
        debug {stderr.writeln("context before AND: ", context);}
        auto nextList = new SimpleList(items[index..$]);
        context.push(nextList);

        context = boolean(context.next(1));
        auto newResult = context.pop();
        currentResult = currentResult && newResult.toBool();
        debug {stderr.writeln("context after AND: ", context);}
    }

    // -----------------------------------------------
    // The loop:
    foreach(index, item; items)
    {
        string s = to!string(item);

        if (item.type == ObjectType.Operator)
        {
            if (s == "&&")
            {
                and(index+1);
                break;
            }
            else if (s == "||")
            {
                // OR is our default behaviour.
                // So we do nothing, here.
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
            debug {stderr.writeln("newResult for OR: ", newResult);}
            currentResult = currentResult || newResult.toBool();
            continue;
        }

        if (item.type == ObjectType.Operator)
        {
            context.push(item);
            continue;
        }
        else if (item.type == ObjectType.Boolean)
        {
            currentResult = currentResult || item;
            continue;
        }
        // Not an operator? Must be a value...
        context.push(item);
        operate();
    }
    context.push(currentResult);
    debug {
        stderr.writeln(" pureBoolean result for ", list, " : ", currentResult);
    }
    assert(context.size == 1);
    return context;
}
