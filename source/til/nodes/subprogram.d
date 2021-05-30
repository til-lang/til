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
    void addModule(string prefix, CommandHandler[string] commands)
    {
        availableModules[prefix] = commands;
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
