module til.procedures;

import std.conv;
import std.experimental.logger;

import til.escopo;
import til.nodes;


class Procedure
{
    string name;
    // proc f {x=10}
    // → parameters["x"] = "10"
    ListItem[] parameters;
    ListItem body;

    this(string name, ListItem parameters, ListItem body)
    {
        this.name = name;
        this.parameters = parameters.atoms;
        this.body = body;

        trace(
            "proc.define: ", this.name,
            "(", this.parameters, ")",
            ": ", this.body
        );
    }

    ListItem run(Escopo escopo, string name, ListItem[] arguments)
    {
        trace(
            "proc.run:"
            ~ this.name ~ "(" ~ to!string(arguments) ~ ") "
        );


        auto procedureScope = new Escopo(escopo);

        auto parametersCount = parameters.length;
        auto argumentsCount = arguments.length;
        trace(
            "  parameters: ", this.parameters,
            " (", parametersCount, ")"
        );
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
            trace(" argument ", parameterName, "=", argument);
        }
        procedureScope[["extra_args"]] = new SubList(
            arguments[parametersCount..$]
        );

        trace(" body.run: " ~ to!string(this.body) ~ ";");
        return new ExecList(this.body.items).run(procedureScope);
    }
}
