module til.nodes.execlist;

import til.nodes;


class ExecList : BaseList
{
    SubProgram subprogram;

    this(SubProgram subprogram)
    {
        super();
        this.subprogram = subprogram;
        this.type = ObjectType.ExecList;
    }

    // Utilities and operators:
    override string toString()
    {
        string s = to!string(this.subprogram);
        return "[" ~ s ~ "]";
    }

    override CommandContext evaluate(CommandContext context)
    {
        /*
        We must run in a sub-Escopo because of how `on.error`
        procedures are called. Besides, we don't want
        SubProgram names messing up with the caller
        context names, anyway.
        */
        auto escopo = new Process(context.escopo);
        escopo.description = "ExecList.evaluate";
        return escopo.run(this.subprogram, context);

        // return context.escopo.run(this.subprogram, context);
    }
}
