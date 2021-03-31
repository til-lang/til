import til.nodes;

class Module
{
    List delegate(string, List)[string] commands;

    this()
    {
        this.loadCommands();
    }
    void loadCommands()
    {
    }
}
