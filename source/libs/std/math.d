module til.std.math;

import til.escopo;
import til.math;
import til.nodes;


class Math : Escopo
{
    string name = "math";

    Result cmd_run(NamePath path, Args items)
    {
        ListItem result = int_resolve(this, items);
        return result;
    }

    override void loadCommands()
    {
        this.commands["run"] = &cmd_run;
        this.commands["MAIN"] = &cmd_run;
    }
}
