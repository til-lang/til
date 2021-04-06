module til.std.io;

import std.algorithm;
import std.conv;
import std.stdio;

import til.escopo;
import til.nodes;


class IO : Escopo
{
    string name = "io";

    Result cmd_out(NamePath path, Args arguments)
    {
        string s = to!string(arguments
            .save()
            .map!(x => x.asString)
            .joiner(" "));
        stdout.writeln(s);
        return new SimpleList(arguments);
    }

    Result cmd_err(NamePath path, Args arguments)
    {
        string s = to!string(arguments
            .save()
            .map!(x => x.asString)
            .joiner(" "));
        stderr.writeln(s);
        return new SimpleList(arguments);
    }


    override void loadCommands()
    {
        this.commands["out"] = &cmd_out;
        this.commands["err"] = &cmd_err;
    }
}
