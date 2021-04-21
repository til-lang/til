module til.math;

import std.conv : to;
import std.range;

import til.nodes;
import til.ranges;

CommandContext int_run(CommandContext context)
{
    /*
    (1 + 2 * 3)
    run precedence_1 → (1 + 6)
    run precedence_2 → (7)
    resolve → 7
    */
    assert(context.size == 1);
    auto r1Context = int_run(context, &int_precedence_1);
    auto r2Context = int_run(r1Context, &int_precedence_2);
    return r2Context;
}

CommandContext int_run(CommandContext context, CommandContext function(CommandContext) resolver)
{
    // There should be a SimpleList at the top of the stack.
    auto list = cast(SimpleList)context.pop();
    Items items = list.items;

    // -----------------------------------------------
    // The loop:
    foreach(item; items)
    {
        if (item.type == ObjectTypes.List)
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
            // TODO: make it a method, like context.assimilate(rContext);

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
        else if (item.type == ObjectTypes.Operator)
        {
            context.push(item);
        }
        else
        {
            // Not an operator? Must be a value...
            context.push(item);
            context = resolver(context);
        }
    }
    // WRONG!
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

// CommandContext int_precedence_1(ListItem operator, ListItem t1, ListItem t2)
CommandContext int_precedence_1(CommandContext context)
{
    if (context.size < 3)
    {
        return context;
    }

    // It was pushed in reading order...
    auto t2 = context.pop();
    auto operator = context.pop();
    auto t1 = context.pop();
    if ((t1.type == ObjectTypes.List || t1.type == ObjectTypes.Operator) ||
        (operator.type != ObjectTypes.Operator) ||
        (t2.type == ObjectTypes.List || t2.type == ObjectTypes.Operator))
    {
        context.push(t1);
        context.push(operator);
        context.push(t2);
        return context;
    }

    switch(operator.asString)
    {
        // -----------------------------------------------
        // Operators implementations:
        // TODO: use asInteger, asFloat and asString
        // TODO: this could be entirely made at compile
        // time, I assume...
        case "*":
            context.push(new Atom(to!int(t1.asString) * to!int(t2.asString)));
            break;
        case "/":
            context.push(new Atom(to!int(t1.asString) / to!int(t2.asString)));
            break;
        default:
            context.push(t1);
            context.push(operator);
            context.push(t2);
            break;
    }
    return context;
}

CommandContext int_precedence_2(CommandContext context)
{
    if (context.size < 3)
    {
        return context;
    }

    // It was pushed in reading order...
    auto t2 = context.pop();
    auto operator = context.pop();
    auto t1 = context.pop();
    if ((t1.type == ObjectTypes.List || t1.type == ObjectTypes.Operator) ||
        (operator.type != ObjectTypes.Operator) ||
        (t2.type == ObjectTypes.List || t2.type == ObjectTypes.Operator))
    {
        context.push(t1);
        context.push(operator);
        context.push(t2);
        return context;
    }

    switch(operator.asString)
    {
        // -----------------------------------------------
        // Operators implementations:
        // TODO: use asInteger, asFloat and asString
        // TODO: this could be entirely made at compile
        // time, I assume...
        case "+":
            context.push(new Atom(to!int(t1.asString) + to!int(t2.asString)));
            break;
        case "-":
            context.push(new Atom(to!int(t1.asString) - to!int(t2.asString)));
            break;
        default:
            context.push(t1);
            context.push(operator);
            context.push(t2);
            break;
    }
    return context;
}

