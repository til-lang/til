module til.procedures;


import std.stdio;
import std.conv;

import til.escopo;
import til.nodes;


class Procedure
{
    string name;
    // proc f {x=10}
    // → parameters["x"] = "10"
    List parameters;
    ListItem body;

    this(string name, ListItem parameters, ListItem body)
    {
        this.name = name;
        this.parameters = new List(parameters);
        this.body = body;

        writeln(
            "proc.define: " ~ name ~ "(" ~ to!string(parameters) ~ ")"
            ~ ": " ~ to!string(body));
    }

    List run(Escopo escopo, string name, List arguments)
    {
        writeln(
            "proc.run:"
            ~ this.name ~ "(" ~ to!string(arguments) ~ ") "
        );

        auto procedureScope = new Escopo(escopo);

        auto parametersCount = parameters.length;
        auto argumentsCount = arguments.length;
        if (argumentsCount < parametersCount)
        {
            // TODO:
            // ==========
            // = ARITY! =
            // ==========
            throw new Exception("Not enough parameters");
        }

        foreach(index, argument; arguments[0..parametersCount])
        {
            // TODO: save parameters as strings already:
            auto parameterName = this.parameters[index].asString;
            procedureScope[parameterName] = argument;
            writeln(" argument ", parameterName, "=", argument);
        }
        procedureScope[["extra_args"]] = new List(
            arguments.items[parametersCount..$]
        );

        writeln(" body.run: " ~ to!string(this.body) ~ ";");
        return cast(List)this.body.run(procedureScope);
    }
}
