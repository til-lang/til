module til.nodes.extraction;

import til.nodes;


class Extraction : BaseList
{
    this(Items items)
    {
        super();
        this.items = items;
    }

    override CommandContext evaluate(CommandContext context)
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
        ListItem target = context.pop();
        Items arguments = context.items;

        auto result = target.extract(arguments);
        context.push(result);

        return context;
    }
}
