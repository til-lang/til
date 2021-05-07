module til.nodes.extraction;

import til.nodes;


class Extraction : BaseList
{
    this(Items items)
    {
        super();
        this.items = items;
    }

    override string toString()
    {
        return "<" ~ to!string(items) ~ ">";
    }

    override CommandContext evaluate(CommandContext context)
    {
        context.size = 0;
        foreach(item; this.items.retro)
        {
            context.run(&(item.evaluate));
        }

        ListItem target = context.pop();
        Items arguments = context.items;

        auto result = target.extract(arguments);
        context.push(result);

        context.exitCode = ExitCode.Proceed;
        return context;
    }
}
