module til.nodes.subprogram;

import til.nodes;

class SubProgram
{
    string name = "<SubProgram>";
    Pipeline[] pipelines;

    CommandHandler[string] commands;
    static CommandHandler[string] globalCommands;
    static CommandHandler[string][string] availableModules;

    this(Pipeline[] pipelines)
    {
        this.pipelines = pipelines;
    }

    void registerGlobalCommands(CommandHandler[string] commands)
    {
        foreach(key, value; commands)
        {
            this.globalCommands[key] = value;
        }
    }
    void addModule(string key, CommandHandler[string] commands)
    {
        availableModules[key] = commands;
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
    string asString()
    {
        return to!string(pipelines
            .map!(x => x.asString)
            .joiner("\n"));
    }
}
