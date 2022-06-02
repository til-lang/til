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
        // TODO: improve this:
        // <[obj, key]> -> <obj key>
        return "<" ~ to!string(items) ~ ">";
    }

    override Context evaluate(Context context)
    {
        context.size = 0;
        foreach(item; this.items.retro)
        {
            context = item.evaluate(context);
            if (context.exitCode == ExitCode.Failure)
            {
                return context;
            }
        }

        Item target = context.pop();

        try
        {
            context = target.runCommand("extract", context);
        }
        catch (Exception ex)
        {
            return context.error(ex.msg, ErrorCode.Unknown, "");
        }

        return context;
    }
}
