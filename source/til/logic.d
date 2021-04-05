module til.logic;

import std.conv;
import std.experimental.logger;

import til.ranges;
import til.nodes;

bool boolean(Range items)
{
    /***************************************************
    Now this is a somewhat "clever" implementation
    for a HORRIBLE thing that is dealing with infix
    notation without the help of the language parser.
    Now you see there's a good reason why Lisp
    dialects prefer to "keep it simple" and only
    implement operators as usual functions, or
    stack-based languages that simply make things...
    well... stack-based.

    C:         1 < 2 && 1 > 2 || 1 < 2
    "Human":  (1 < 2) && ((1 > 2) || (1 < 2))
    Lisp:     (and (lt 1 2) (or (gt 1 2) (lt 1 2)))
    Stack      1 2 lt 1 2 gt 1 2 lt or and
    Tcl       {1 < 2 && 1 > 2 || 1 < 2} (just like C)

    (Interesting to note: it seems stack-based languages
    must evaluate ALL the conditions, always...)
    ****************************************************/

    trace(" BOOLEAN ANALYSIS: ", items);

    ListItem lastItem;
    bool currentResult = false;
    void delegate(string, ListItem) currentHandler;
    bool delegate(ListItem, ListItem)[string] operators;


    final void defaultHandler(string s, ListItem x)
    {
        trace("  defaultHandler ", s);
        trace( "saving item");
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
    void operatorHandler(string operatorName, ListItem opItem)
    {
        ListItem t1 = lastItem;
        void operate(string strT2, ListItem t2)
        {
            auto newResult = {
                switch(operatorName)
                {
                    // -----------------------------------------------
                    // Operators implementations:
                    // TODO: use asInteger, asFloat and asString
                    // TODO: this could be entirely made at compile
                    // time, I assume...
                    case "<":
                        return to!int(t1.asString) < to!int(t2.asString);
                    case ">":
                        return to!int(t1.asString) > to!int(t2.asString);
                    case ">=":
                        return to!int(t1.asString) >= to!int(t2.asString);
                    case "<=":
                        return to!int(t1.asString) <= to!int(t2.asString);
                    default:
                        throw new Exception(
                            "Unknown operator: "
                            ~ operatorName
                        );
                }
            }();
            trace(" newResult: ", to!string(newResult));

            lastItem = null;
            currentResult = currentResult || newResult;
            currentHandler = &defaultHandler;
        }
        currentHandler = &operate;
    }

    // -----------------------------------------------
    void parentesisOpen()
    {
        // Consume the "(":
        items.popFront();

        auto newResult = boolean(items);
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
    void and()
    {
        // Consume the `&&`:
        items.popFront();
        auto newResult = boolean(items);
        trace(" and.newResult: ", to!string(newResult));
        currentResult = currentResult && newResult;
        trace(" and.currentResult: ", to!string(currentResult));
    }

    // -----------------------------------------------
    // The loop:
    foreach(item; items)
    {
        string s = item.asString;
        trace("s: ", s, " ", to!string(item.type));

        if (item.type == ObjectTypes.Operator)
        {
            if (s == "&&")
            {
                and();
                trace(" returning from AND: ", to!string(currentResult));
                break;
            }
            else if (s == "||")
            {
                // OR is our default behaviour.
                // So we do nothing, here.
                continue;
            }
        }
        else if (item.type == ObjectTypes.Parentesis)
        {
            if (s == "(")
            {
                parentesisOpen();
                continue;
            }
            else if (s == ")")
            {
                // Time to leave:
                break;
            }
        }

        if (item.type == ObjectTypes.Operator)
        {
            operatorHandler(s, item);
            continue;
        }
        // Not an operator? Must be a value...
        currentHandler(s, item);
    }
    trace("  returning ", to!string(currentResult));
    return currentResult;
}
