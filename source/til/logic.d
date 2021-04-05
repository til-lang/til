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
    ListItem lastItem;
    bool currentResult = false;

    trace(" BOOLEAN ANALYSIS: ", items);

    void saver(string s, ListItem x)
    {
        lastItem = x;
    }
    void delegate(string, ListItem) currentHandler = &saver;
    void delegate(string, ListItem)[string] handlers;

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
    void gte(string s, ListItem op)
    {
        ListItem t1 = lastItem;
        void do_gte(string s, ListItem t2)
        {
            currentHandler = &saver;

            // TODO: use asInteger, asFloat and asString
            currentResult = (to!int(t1.asString) >= to!int(t2.asString));
            lastItem = null;
            currentHandler = &saver;
        }
        currentHandler = &do_gte;
    }
    handlers[">="] = &gte;

    void lt(string s, ListItem op)
    {
        ListItem t1 = lastItem;
        void do_lt(string s, ListItem t2)
        {
            currentHandler = &saver;

            // TODO: use asInteger, asFloat and asString
            currentResult = (to!int(t1.asString) < to!int(t2.asString));
            lastItem = null;
            currentHandler = &saver;
        }
        currentHandler = &do_lt;
    }
    handlers["<"] = &lt;

    void parentesis(string s, ListItem parentesis)
    {
        // Consume the "(":
        items.popFront();
        auto newResult = boolean(items);
        return currentHandler(")", new Atom(newResult));
    }
    handlers["("] = &parentesis;

    // SPECIAL CASES:
    /*
    About `and` & `or`:
    AND has precedence over OR.

    Take for instance `f or t and t`. It should return true.
    (The explicit version would be `(f or t) and t`.)
    */
    void and()
    {
        /*
        We are NOT stopping evaluation for now, so
        f1 && f2 && f3 && t4
        will evaluate all three falsy values, the
        last truthy one and, in the end, return
        a "false" result.
        */

        // Consume the `&&`:
        items.popFront();
        auto newResult = boolean(items);
        currentResult = currentResult && newResult;
    }

    void or()
    {
        /*
        We are NOT stopping evaluation for now. So
        `t1 && f2 && f3` will still evaluate the
        last two falsy values, even if the
        first one is already truthy.
        */

        // Consume the `||`:
        items.popFront();
        auto newResult = boolean(items);
        currentResult = currentResult || newResult;
    }

    // The loop:
    foreach(item; items)
    {
        string s = item.asString;
        trace("s: ", s);

        // Special cases:
        if (s == "&&")
        {
            and();
            continue;
        }
        else if (s == "||")
        {
            or();
            continue;
        }
        else if (s == ")")
        {
            // Time to leave:
            break;
        }

        auto handler = handlers.get(s, null);
        if (handler is null)
        {
            // Generally a term (numbers)
            currentHandler(s, item);
        }
        else
        {
            // Generally operators
            handler(s, item);
        }
    }
    return currentResult;
}
