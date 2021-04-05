module til.std;


import til.escopo;
import til.std.io;
import til.std.math;


class Std : Escopo
{
    string name = "std";
    this()
    {
        super();
        this.availableModules["io"] = new IO();
        this.availableModules["math"] = new Math();
    }
    override void loadCommands()
    {
    }
}
