module til.math;

import std.conv : to;
import std.experimental.logger : trace;
import std.range;

import til.nodes;
import til.ranges;


ListItem int_resolve(Process escopo, Items items)
{
    Items r = int_run(escopo, items);

    // Resolve:
    // (We will assume r2 already has only one ListItem/Atom
    // that represents the result.)
    return r.front;
}

Items int_run(Process escopo, Items items)
{
    /*
    (1 + 2 * 3)
    run precedence_1 → (1 + 6)
    run precedence_2 → (7)
    resolve → 7
    */
    Items r1 = int_run(escopo, items, &int_precedence_1);
    Items r2 = int_run(escopo, r1, &int_precedence_2);
    return r2;
}

Items int_run(Process escopo, Items items, ListItem function(ListItem, ListItem, ListItem) resolver)
{
    /*
    set x [math.run 1 + 1]
    */
    trace(" MATH.int_run: ", items);

    ListItem lastItem;
    ListItem[] newItems;
    void delegate(ListItem) currentHandler;
    int function(ListItem, ListItem)[string] operators;

    final void defaultHandler(ListItem x)
    {
        trace("  lastItem: ", x);
        lastItem = x;
        return;
    }
    currentHandler = &defaultHandler;

    /*
    The most usual way of implementing an operation handler
    is by returnin a CLOSURE whose "first argument" is
    the first value of an infix notation. For
    instance, `1 + 2` would first save `1`,
    then make a "sum-with-one" closure
    the currentHandler and then apply
    sum-with-one to `2`, resulting
    a `3`.
    */

    // -----------------------------------------------
    void operatorHandler(ListItem operator)
    {
        ListItem t1 = lastItem;
        void operate(ListItem t2)
        {
            auto newResult = resolver(operator, t1, t2);
            trace(" newResult for ", t1, operator, t2, ": ", newResult);

            if (newResult is null)
            {
                trace("  pushing: ", t1, operator, t2);
                // It's not the right time, yet...
                newItems ~= t1;
                newItems ~= operator;
                lastItem = t2;
                trace("  newItems: ", newItems);
            }
            else
            {
                lastItem = newResult;
                // newItems ~= newResult;
            }
            currentHandler = &defaultHandler;
        }
        currentHandler = &operate;
    }

    // -----------------------------------------------
    // The loop:
    foreach(item; items)
    {
        if (item.type == ObjectTypes.List)
        {
            // The next item is the result from the list:
            // item = int_resolve(escopo, item.run(escopo, true).items);
            auto x = item.evaluate(escopo, true);
            Items rList = escopo.int_run((cast(BaseList)x).items);
            /*
            rList can be both a proper result like
            StaticItems([:12])
            or an semi-unresolved list like
            StaticItems([:12 < :13])
            */
            if (rList.length == 1)
            {
                // XXX ?
                item = rList[0];
                trace(" rList[0]: ", item);
            }
            else
            {
                item = new SimpleList(rList);
                // newItems ~= item;
                trace(" rList incorporated. newItems: ", newItems);
            }
        }

        /*
        It should not be an "else if", because after resolving
        a list we should simply proceed using the result
        as the current item, but it's a fact that
        a list resolution should never yield
        an Operator, so it makes no sense
        to evaluate another if right
        after a list resolution.
        */
        else if (item.type == ObjectTypes.Operator)
        {
            operatorHandler(item);
            continue;
        }
        // Not an operator? Must be a value...
        currentHandler(item);
    }
    if (lastItem !is null)
    {
        newItems ~= lastItem;
    }
    trace("  (", items, ") returning ", newItems);
    return newItems;
}

ListItem int_precedence_1(ListItem operator, ListItem t1, ListItem t2)
{
    switch(operator.asString)
    {
        // -----------------------------------------------
        // Operators implementations:
        // TODO: use asInteger, asFloat and asString
        // TODO: this could be entirely made at compile
        // time, I assume...
        case "*":
            return new Atom(to!int(t1.asString) * to!int(t2.asString));
        case "/":
            return new Atom(to!int(t1.asString) / to!int(t2.asString));
        default:
            return null;
    }
}
ListItem int_precedence_2(ListItem operator, ListItem t1, ListItem t2)
{
    switch(operator.asString)
    {
        // -----------------------------------------------
        // Operators implementations:
        // TODO: use asInteger, asFloat and asString
        // TODO: this could be entirely made at compile
        // time, I assume...
        case "+":
            return new Atom(to!int(t1.asString) + to!int(t2.asString));
        case "-":
            return new Atom(to!int(t1.asString) - to!int(t2.asString));
        default:
            return null;
    }
}

