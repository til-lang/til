module til.nodes.simplelist;

import til.nodes;


class SimpleList : BaseList
{
    /*
       A SimpleList contains only ONE List inside it.
       Its primary use is for passing parameters
       for `if`, for instance, like
       if ($x > 10) {...}
    */

    this(Items items)
    {
        super();
        this.items = items;
    }

    // -----------------------------
    // Utilities and operators:
    override string toString()
    {
        return to!string(this.items
            .map!(x => to!string(x))
            .joiner(" "));
    }

    override CommandContext evaluate(CommandContext context, bool force)
    {
        if (!force)
        {
            return this.evaluate(context);
        }
        else
        {
            return this.forceEvaluate(context);
        }
    }
    override CommandContext evaluate(CommandContext context)
    {
        /*
        Returning itself has some advantages:
        1- We can use SimpleLists as "liquid" lists
        the same way as SubLists (if a proc returns only
        a SimpleList it is "diluted" in the CommonList
        that called it as a command, like in
        set eagle [f 15 E]
         → set eagle "strike" "eagle"
        2- It is more suitable to return SimpleLists
        instead of SubLists because semantically
        the returns are only one list, not
        a list of lists.
        */
        context.push(this);
        context.exitCode = ExitCode.Proceed;
        return context;
    }
    CommandContext forceEvaluate(CommandContext context)
    {
        context.size = 0;
        foreach(item; this.items.retro)
        {
            context.run(&(item.evaluate));
        }

        /*
        What resides in the stack, at the end, is not
        the items inside the original SimpleLists,
        but a new SimpleLists with its original
        items already evaluated. We are only
        using the stack as temporary space.
        */
        auto newList = new SimpleList(context.items);
        context.push(newList);
        return context;
    }

    override ListItem extract(Items arguments)
    {
        if (arguments.length == 0) return this;

        auto firstArgument = arguments[0];
        // by indexes:
        // <(1 2 3 4 5) (0 2 4)> → (1 3 5)
        switch(firstArgument.type)
        {
            case ObjectTypes.Integer:
                // by range:
                // <(1 2 3 4 5) 0 2> → (1 2)
                if (arguments.length == 2 && arguments[1].type == ObjectTypes.Integer)
                {
                }
                // by index:
                // <(1 2 3) 0> → 1  (not inside any list)
                else if (arguments.length == 1)
                {
                    return items[firstArgument.toInt];
                }
                break;
            case ObjectTypes.Name:
                auto str = firstArgument.toString;
                switch(str)
                {
                    case "head":
                        return items[0];
                    case "tail":
                        return new SimpleList(items[1..$]);
                    default:
                        break;
                }
                break;
            default:
                break;
        }

        // else...
        throw new Exception(
            "Extraction not implemented in SimpleList for ("
            ~ to!string(arguments.map!(x => to!string(x)).join(" "))
            ~ ")"
        );
    }
}
