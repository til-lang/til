module til.math;

import std.algorithm : canFind;
import std.conv : to;
import std.range;

import til.nodes;
import til.ranges;

debug
{
    import std.stdio;
}

string[][2] precedences = [
    ["*", "/"],
    ["+", "-"],
];

CommandContext int_run(CommandContext context)
{
    /*
    (1 + 2 * 3)
    run precedence_1 → (1 + 6)
    run precedence_2 → (7)
    resolve → 7
    */
    assert(context.size == 1);
    CommandContext lastContext = null;
    foreach(operators; precedences)
    {
        lastContext = int_run(context, operators);
    }
    assert(context.size == 1);
    return lastContext;
}

CommandContext int_run(CommandContext context, string[] operators)
{
    // There should be a SimpleList at the top of the stack.
    auto list = cast(SimpleList)context.pop();
    Items items = list.items;

    // -----------------------------------------------
    // The loop:
    foreach(item; items)
    {
        if (item.type == ObjectType.SimpleList)
        {
            SimpleList l = cast(SimpleList)item;
            // "evaluate" will push all evaluated sub-items
            auto lContext = l.evaluate(context, true);
            assert(lContext.size == 1);
            // Now we have an evaluated SimpleList in the stack,
            // just like our own initial condition.
            auto rContext = int_run(lContext);
            assert(rContext.size == 1);
            // Assimilate the result into our own context:
            context.size += rContext.size;

            /*
            The result (now in the stack) can be both a proper one like
            [:12]
            or an semi-unresolved list like
            [:12 :< :13]
            */

            /*
            Whatever the result was (a single item or a new List),
            it is in the top of the stack, now, as we want.
            */
        }
        else if (item.type == ObjectType.Operator)
        {
            context.push(item);
        }
        else
        {
            // Not an operator? Must be a value...
            context.push(item);
            context = resolver(context, operators);
        }
    }

    // XXX : check if this is right:
    auto terms = context.items;
    // un-reverse the list...
    Items resultItems;
    foreach(term; terms.retro)
    {
        resultItems ~= term;
    }
    auto resultList = new SimpleList(resultItems);
    context.push(resultList);
    return context;
}

CommandContext resolver(CommandContext context, string[] operators)
{
    if (context.size < 3)
    {
        return context;
    }

    // The terms were pushed in reading order...
    auto t2 = context.pop();
    auto operator = context.pop();
    auto t1 = context.pop();
    debug {stderr.writeln(" >> ", to!string(t1.type), " ", operator, " ", to!string(t2.type));}

    if ((t1.type == ObjectType.SimpleList || t1.type == ObjectType.Operator)
        || (operator.type != ObjectType.Operator))
    {
        context.push(t1);
        context.push(operator);
        context.push(t2);
        return context;
    }

    auto operatorStr = to!string(operator);

    if (operators.canFind(operatorStr))
    {
        ListItem result = t1.operate(operatorStr, t2, false);
        if (result is null)
        {
            result = t2.operate(operatorStr, t1, true);
        }
        if (result is null)
        {
            throw new Exception(
                "Cannot operate "
                ~ t1.toString() ~ " "
                ~ operatorStr ~ " "
                ~ t2.toString()
            );
        }
        context.push(result);
    }
    else
    {
        context.push(t1);
        context.push(operator);
        context.push(t2);
    }
    return context;
}
