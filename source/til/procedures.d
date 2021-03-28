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

        auto procedureScope = new Escopo(escopo);

        foreach(index, argument; arguments.items)
        {
            auto parameterName = this.parameters[index];
            // auto value = argument.resolve(procedureScope);
            auto li = new ListItem[1];
            li[0] = argument;
            auto value = new List(li);
            procedureScope.setVariable(parameterName, value);
            writeln(
                " argument " ~ parameterName ~ "=" ~ to!string(value)
            );
        }
        return this.body.run(procedureScope);
    }
}
