module til.nodes.extraction;

import til.nodes;


class Extraction : BaseList
{
    this(Items items)
    {
        super();
        this.items = items;
        this.commandPrefix = "extraction";
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

        context = target.extract(context);

        context.exitCode = ExitCode.Proceed;
        return context;
    }
}
