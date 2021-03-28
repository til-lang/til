module til.procedures;


import std.stdio;
import std.conv;

import til.escopo;
import til.nodes;


alias Parameters = Value[];

class Procedure
{
    string name;
    // proc f {x=10}
    // → parameters["x"] = "10"
    Parameters parameters;
    SubProgram body;

    this(string name, Parameters parameters, SubProgram body)
    {
        this.name = name;
        this.parameters = parameters;
        this.body = body;

        writeln(
            "PROC: " ~ name ~ "(" ~ to!string(parameters) ~ ")"
            ~ ": " ~ to!string(body));
    }

    List run(Escopo escopo, string name, List arguments)
    {
        writeln(
            "Procedure.run:"
            ~ this.name ~ "(" ~ to!string(arguments) ~ ")"
        );
        return new List();
    }
}
