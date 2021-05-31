module til.nodes.subprogram;

import til.nodes;

class SubProgram
{
    string name = "<SubProgram>";
    Pipeline[] pipelines;

    this(Pipeline[] pipelines)
    {
        this.pipelines = pipelines;
    }

    override string toString()
    {
        string s = "SubProgram " ~ this.name ~ ":\n";
        foreach(pipeline; pipelines)
        {
            s ~= to!string(pipeline) ~ "\n";
        }
        return s;
    }
}
