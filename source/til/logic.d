module til.logic;

import std.conv;
import std.stdio;

import til.nodes;


bool boolean(ListItem[] items)
{
    /*
        Now this is somewhat "clever" implementation
        for a HORRIBLE thing that is "parsing" infix
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
    */
    ListItem lastItem;
    bool currentResult = false;

    bool saver(ulong index, ListItem x)
    {
        lastItem = x;
        return false;
    }
    bool delegate(ulong, ListItem) currentHandler = &saver;

    bool do_gte(ulong index, ListItem t2)
    {
        auto t1 = lastItem;
        writeln("  gte ", t1, " ", t2);
        currentHandler = &saver;

        // TODO: use asInteger, asFloat and asString
        currentResult = (to!int(t1.asString) >= to!int(t2.asString));
        lastItem = null;
        return false;
    }
    bool gte(ulong index, ListItem x)
    {
        currentHandler = &do_gte;
        return false;
    }
    bool do_lt(ulong index, ListItem t2)
    {
        auto t1 = lastItem;
        writeln("  lt ", t1, " ", t2);
        currentHandler = &saver;

        // TODO: use asInteger, asFloat and asString
        currentResult = (to!int(t1.asString) < to!int(t2.asString));
        lastItem = null;
        return false;
    }
    bool lt(ulong index, ListItem x)
    {
        currentHandler = &do_lt;
        return false;
    }
    bool and(ulong index, ListItem x)
    {
        if (currentResult == false)
        {
            return false;
        }
        else
        {
            currentResult = boolean(items[index+1..$]);
            return true;
        }
    }

    auto l = new List(items, false);
    foreach(index, atom; l.atoms)
    {
        string s = atom.asString;
        bool ended = false;
        switch(s)
        {
            case ">=":
                ended = gte(index, atom);
                break;
            case "<":
                ended = lt(index, atom);
                break;
            case "&&":
                ended = and(index, atom);
                break;
            default:
                ended = currentHandler(index, atom);
        }
        if (ended) break;
    }
    writeln("  boolean ", items, " returning ", currentResult);
    return currentResult;
}
