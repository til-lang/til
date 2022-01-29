module til.nodes.sublist;

import til.nodes;


class SubList : BaseList
{
    SubProgram subprogram;

    this(SubProgram subprogram)
    {
        super();
        this.subprogram = subprogram;
        this.type = ObjectType.SubList;
        this.typeName = "sub_list";
    }

    // -----------------------------
    // Utilities and operators:
    override string toString()
    {
        return "{" ~ to!string(this.subprogram) ~ "}";
    }

    override Context evaluate(Context context)
    {
        return this.evaluate(context, false);
    }
    override Context evaluate(Context context, bool force)
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
