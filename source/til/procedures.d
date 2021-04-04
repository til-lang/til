module til.procedures;

import std.conv;
import std.experimental.logger;

import til.escopo;
import til.exceptions;
import til.ranges;
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

    ListItem run(Escopo escopo, string name, Range arguments)
    {
        trace(
            "proc.run:"
            ~ this.name ~ "(" ~ to!string(arguments) ~ ") "
        );


        auto procedureScope = new Escopo(escopo);

        foreach(index, parameter; this.parameters)
        {
            // TODO: save parameters as strings already:
            auto parameterName = parameter.asString;
            if (arguments.empty)
            {
                throw new InvalidException(
                    "Wrong number of parameters to command "
                    ~ name
                );
            }
            else
            {
                auto argument = arguments.consume();
                procedureScope[parameterName] = argument;
                trace(" argument ", parameterName, "=", argument);
            }
        }
        procedureScope[["extra_args"]] = new SubList(arguments);

        trace(" body.run: " ~ to!string(this.body) ~ ";");
        return new ExecList(this.body.items).run(procedureScope);
    }
}
