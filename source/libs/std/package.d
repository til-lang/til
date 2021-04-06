module til.std;


import til.escopo;
import til.std.io;
import til.std.math;
import til.std.ranges;
import til.std.stack;


class Std : Escopo
{
    string name = "std";
    this()
    {
        super();
        this.availableModules["io"] = new IO();
        this.availableModules["math"] = new Math();
        this.availableModules["ranges"] = new Ranges();
        this.availableModules["stack"] = new Stack();
    }
    override void loadCommands()
    {
    }
}
