module til.escopo;

import std.conv : to;
import std.stdio : writeln;

import til.nodes;


class BaseEscopo
{
    Expression[string] variables;
    // string[] freeVariables;
    Escopo parent;

    this(Escopo parent)
    {
        this.parent = parent;
    }

    SubProgram set(ListItem[] arguments)
    {
        writeln("STUB:SET " ~ to!string(arguments));
        return null;
    }

    SubProgram run(ListItem[] arguments)
    {
        writeln("STUB:RUN " ~ to!string(arguments));
        return null;
    }

    SubProgram fill(ListItem[] arguments)
    {
        writeln("STUB:FILL " ~ to!string(arguments));
        return null;
    }

    SubProgram retorne(ListItem[] arguments)
    {
        writeln("STUB:RETORNE " ~ to!string(arguments));
        return null;
    }

    SubProgram run_command(DotList cmd, ListItem[] arguments)
    {
        writeln(
            "STUB:RUN_COMMAND " ~ to!string(cmd) ~ " " ~ to!string(arguments)
        );
        return null;
    }
}

class Escopo : BaseEscopo
{
    this(Escopo parent)
    {
        super(parent);
    }
}
