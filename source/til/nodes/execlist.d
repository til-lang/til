module til.nodes.execlist;

import til.nodes;


class ExecList : BaseList
{
    SubProgram subprogram;

    this(SubProgram subprogram)
    {
        super();
        this.subprogram = subprogram;
    }

    // Utilities and operators:
    override string toString()
    {
        string s = to!string(this.subprogram);
        return "[" ~ s ~ "]";
    }

    override CommandContext evaluate(CommandContext context)
    {
        return context.escopo.run(this.subprogram, context);
    }
}
