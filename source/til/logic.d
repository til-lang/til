module til.logic;

import std.conv : to;
import std.range : popFront;

import til.math;
import til.nodes;
import til.ranges;


CommandContext boolean(CommandContext context)
{
    // Resolve any math beforehand:
    auto resolvedContext = int_run(context);
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
        auto operatorName = context.pop().asString;
        auto t1 = context.pop();

        bool newResult = {
            switch(operatorName)
            {
                // -----------------------------------------------
                // Operators implementations:
                // XXX: this could be entirely made at compile
                // time, I assume...
                case "==":
                    return (t1.asInteger == t2.asInteger);
                case "<":
                    return (t1.asInteger < t2.asInteger);
                case ">":
                    return (t1.asInteger > t2.asInteger);
                case ">=":
                    return (t1.asInteger >= t2.asInteger);
                case "<=":
                    return (t1.asInteger <= t2.asInteger);
                default:
                    throw new Exception(
                        "Unknown operator: "
                        ~ operatorName
                    );
            }
        }();
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
        context.push(nextList);

        auto context = boolean(context);
        auto newResult = context.pop();
        currentResult = currentResult && newResult.asBoolean;
    }

    // -----------------------------------------------
    // The loop:
    foreach(index, item; items)
    {
        string s = item.asString;

        if (item.type == ObjectTypes.Operator)
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
    return context;
}
