module til.std;


import til.escopo;
import til.std.io;


class Std : Escopo
{
    string name = "std";
    this()
    {
        super();
        this.availableModules["io"] = new IO();
    }
    override void loadCommands()
    {
    }
}
