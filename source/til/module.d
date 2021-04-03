import til.escopo;
import til.nodes;


class Module
{
    ListItem delegate(string, Args)[string] commands;

    this()
    {
        this.loadCommands();
    }
    void loadCommands()
    {
    }
}
