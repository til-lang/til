module til.logic;

import std.conv;

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
    ListItem lastItem;
    bool currentResult = false;

    bool saver(string s, ListItem x)
    {
        lastItem = x;
        return false;
    }
    bool delegate(string s, ListItem) currentHandler = &saver;

    bool do_gte(string s, ListItem t2)
    {
        auto t1 = lastItem;
        currentHandler = &saver;

        // TODO: use asInteger, asFloat and asString
        currentResult = (to!int(t1.asString) >= to!int(t2.asString));
        lastItem = null;
        return false;
    }
    bool gte(string s, ListItem x)
    {
        currentHandler = &do_gte;
        return false;
    }
    bool do_lt(string s, ListItem t2)
    {
        auto t1 = lastItem;
        currentHandler = &saver;

        // TODO: use asInteger, asFloat and asString
        currentResult = (to!int(t1.asString) < to!int(t2.asString));
        lastItem = null;
        return false;
    }
    bool lt(string s, ListItem x)
    {
        currentHandler = &do_lt;
        return false;
    }
    bool and(string s, ListItem x)
    {
        if (currentResult == true)
        {
            // Consume the `&&`:
            items.popFront();
            currentResult = boolean(items);
        }
        return true;
    }

    auto index = 0;
    foreach(item; items)
    {
        string s = item.asString;
        bool ended = false;
        switch(s)
        {
            case ">=":
                ended = gte(s, item);
                break;
            case "<":
                ended = lt(s, item);
                break;
            case "&&":
                ended = and(s, item);
                break;
            default:
                ended = currentHandler(s, item);
        }
        if (ended) break;
    }
    return currentResult;
}
