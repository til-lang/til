module til.nodes.simplelist;

import std.array : array;
import std.range : empty, front, popFront;

import til.nodes;


CommandHandler[string] simpleListCommands;

class SimpleList : BaseList
{
    /*
       A SimpleList contains only ONE List inside it.
       Its primary use is for passing parameters,
       like `if ($x > 10) {...}`.
    */

    this(Items items)
    {
        super();
        this.items = items;
        this.commands = simpleListCommands;
        this.type = ObjectType.SimpleList;
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

    override CommandContext extract(CommandContext context)
    {
        if (context.size == 0) return context.push(this);

        auto firstArgument = context.pop();
        // by indexes:
        // <(1 2 3 4 5) (0 2 4)> → (1 3 5)
        switch(firstArgument.type)
        {
            case ObjectType.Integer:
                // by range:
                // <(1 2 3 4 5) 0 2> → (1 2)
                if (context.size == 1)
                {
                    auto nextArg = context.pop();
                    if (nextArg.type == ObjectType.Integer)
                    {
                        context.push(new SimpleList(
                            items[firstArgument.toInt..nextArg.toInt]
                        ));
                        return context;
                    }
                }
                // by index:
                // <(1 2 3) 0> → 1  (not inside any list)
                else if (context.size == 0)
                {
                    context.push(items[firstArgument.toInt]);
                    return context;
                }
                break;
            case ObjectType.Name:
                auto str = firstArgument.toString;
                switch(str)
                {
                    case "head":
                        context.push(items[0]);
                        return context;
                    case "tail":
                        context.push(new SimpleList(items[1..$]));
                        return context;
                    default:
                        break;
                }
                break;
            default:
                break;
        }

        // else...
        auto msg = "Extraction of "
                   ~ to!string(firstArgument.type)
                   ~ " not implemented in SimpleList";
        return context.error(msg, ErrorCode.InvalidArgument, "");
    }
}
