module til.nodes.subprogram;

import til.nodes;

class SubProgram
{
    Pipeline[] pipelines;

    this(Pipeline[] pipelines)
    {
        this.pipelines = pipelines;
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
}
