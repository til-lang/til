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

    override string toString()
    {
        return "[" ~ this.subprogram.toString() ~ "]";
    }
    override Context evaluate(Context context)
    {
        /*
        We must run in a sub-Escopo because of how `on.error`
        procedures are called. Besides, we don't want
        SubProgram names messing up with the caller
        context names, anyway.
        */
        auto escopo = new Escopo(context.escopo);
        escopo.description = "ExecList.evaluate";

        auto returnedContext = context.process.run(this.subprogram, context.next(escopo));
        returnedContext = context.process.closeCMs(returnedContext);

        context.size += returnedContext.size;
        context.exitCode = returnedContext.exitCode;
        return context;
    }
}
