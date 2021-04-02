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
    ListItem[] parameters;
    List body;

    this(string name, ListItem parameters, ListItem body)
    {
        this.name = name;
        this.parameters = parameters.atoms;
        this.body = new List(body.items, true);

        writeln(
            "proc.define: ", this.name,
            "(", this.parameters, ")",
            ": ", this.body
        );
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
        return cast(List)this.body.run(procedureScope, true);
    }
}
