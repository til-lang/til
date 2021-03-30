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
    List body;

    this(string name, Parameters parameters, List body)
    {
        this.name = name;
        this.parameters = parameters;
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

        auto parametersCount = this.parameters.length;
        auto argumentsCount = arguments.length;
        if (argumentsCount < parametersCount)
        {
            // TODO:
            // ==========
            // = ARITY! =
            // ==========
            throw new Exception("Not enough parameters");
        }

        foreach(index, argument; arguments.items[0..parametersCount])
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
        procedureScope.setVariable("extra_args", new List(
            arguments.items[parametersCount..$]
        ));

        writeln(" body.run: " ~ to!string(this.body) ~ ";");
        return this.body.run(procedureScope);
    }
}
