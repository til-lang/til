module til.logic;

import std.conv : to;
import std.experimental.logger : trace;
import std.range : popFront;

import til.math;
import til.nodes;
import til.ranges;


CommandContext boolean(CommandContext context)
{
    trace(" BOOLEAN ANALYSIS: ", context.escopo);
    // Resolve any math beforehand:
    auto resolvedContext = int_run(context);
    return pureBoolean(resolvedContext);
}

CommandContext pureBoolean(CommandContext context)
{
    // There should be a SimpleList at the top of the stack.
    auto list = cast(SimpleList)context.pop();
    Items items = list.items;

    trace(" PURE BOOLEAN: ", items);

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
        auto operatorName = context.pop().asString;
        auto t1 = context.pop();

        bool newResult = {
            switch(operatorName)
            {
                // -----------------------------------------------
                // Operators implementations:
                // TODO: use asInteger, asFloat and asString
                // TODO: this could be entirely made at compile
                // time, I assume...
                case "<":
                    return (to!int(t1.asString) < to!int(t2.asString));
                case ">":
                    return (to!int(t1.asString) > to!int(t2.asString));
                case ">=":
                    return (to!int(t1.asString) >= to!int(t2.asString));
                case "<=":
                    return (to!int(t1.asString) <= to!int(t2.asString));
                default:
                    throw new Exception(
                        "Unknown operator: "
                        ~ operatorName
                    );
            }
        }();
        trace(t1, operatorName, t2, " bool.result:", newResult);
        currentResult = currentResult || newResult;
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
        trace(" and.nextList:", nextList);
        context.push(nextList);

        auto context = boolean(context);
        auto newResult = context.pop();
        trace(" and.newResult: ", to!string(newResult));
        currentResult = currentResult && newResult.asBoolean;
    }

    // -----------------------------------------------
    // The loop:
    foreach(index, item; items)
    {
        string s = item.asString;
        trace("s: ", s, " ", to!string(item.type));

        if (item.type == ObjectTypes.Operator)
        {
            if (s == "&&")
            {
                and(index+1);
                trace(" returning from AND: ", currentResult);
                trace("  context:", context);
                break;
            }
            else if (s == "||")
            {
                // OR is our default behaviour.
                // So we do nothing, here.
                continue;
            }
        }
        else if (item.type == ObjectTypes.List)
        {
            SimpleList l = cast(SimpleList)item;
            auto listContext = l.evaluate(context, true);
            listContext = boolean(listContext);
            // There should be an Atom(bool) at the top of the stack.
            auto newResult = listContext.pop();
            currentResult = currentResult || newResult.asBoolean;
            continue;
        }

        if (item.type == ObjectTypes.Operator)
        {
            context.push(item);
            continue;
        }
        else if (item.type == ObjectTypes.Boolean)
        {
            currentResult = currentResult || item.asBoolean;
            continue;
        }
        // Not an operator? Must be a value...
        context.push(item);
        operate();
    }
    context.push(currentResult);
    trace("  boolean.returning. result:", currentResult, "; context: ", context);
    return context;
}
