module til.nodes.sublist;

import til.nodes;


class SubList : BaseList
{
    SubProgram subprogram;

    this(SubProgram subprogram)
    {
        super();
        this.subprogram = subprogram;
        this.commandPrefix = "sublist";
    }

    // -----------------------------
    // Utilities and operators:
    override string toString()
    {
        return "{" ~ to!string(this.subprogram) ~ "}";
    }

    override CommandContext evaluate(CommandContext context)
    {
        return this.evaluate(context, false);
    }
    override CommandContext evaluate(CommandContext context, bool force)
    {
        if (!force)
        {
            context.push(this);
            return context;
        }
        else
        {
            return new ExecList(this.subprogram).evaluate(context);
        }
    }
}
