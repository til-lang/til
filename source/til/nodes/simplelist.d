module til.nodes.simplelist;

import std.array : array;
import std.range : empty, front, popFront;

import til.nodes;

debug
{
    import std.stdio;
}

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
        this.typeName = "list";
    }

    // -----------------------------
    // Utilities and operators:
    override string toString()
    {
        return "(" ~ to!string(this.items
            .map!(x => to!string(x))
            .joiner(" ")) ~ ")";
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
        the items inside the original SimpleList,
        but a new SimpleList with its original
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

        // start:
        auto start = context.pop().toInt();

        if (start < 0)
        {
            start = this.items.length + start;
        }

        // end:
        auto end = start + 1;
        if (context.size)
        {
            end = context.pop().toInt();
            if (end < 0)
            {
                end = this.items.length + end;
            }
        }

        // slice:
        context.push(new SimpleList(items[start..end]));

        return context;
    }
}
