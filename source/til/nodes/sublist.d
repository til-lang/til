module til.nodes.sublist;

import til.nodes;


class SubList : BaseList
{
    SubProgram subprogram;

    this(SubProgram subprogram)
    {
        super();
        this.subprogram = subprogram;
    }

    // -----------------------------
    // Utilities and operators:
    override string toString()
    {
        string s = this.subprogram.asString;
        return "{" ~ s ~ "}";
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
