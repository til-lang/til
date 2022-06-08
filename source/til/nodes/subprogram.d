module til.nodes.subprogram;

import til.nodes;


CommandsMap subprogramCommands;


class SubProgram : BaseList
{
    Pipeline[] pipelines;

    this(Pipeline[] pipelines)
    {
        this.pipelines = pipelines;
        this.type = ObjectType.SubProgram;
        this.typeName = "subprogram";
        this.commands = subprogramCommands;
    }

    override string toString()
    {
        string s = "";
        if (pipelines.length < 2)
        {
            foreach(pipeline; pipelines)
            {
                s ~= pipeline.toString();
            }
        }
        else
        {
            s ~= "{\n";
            foreach(pipeline; pipelines)
            {
                s ~= pipeline.toString() ~ "\n";
            }
            s ~= "}";
        }
        return s;
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
            return new ExecList(this).evaluate(context);
        }
    }
}
