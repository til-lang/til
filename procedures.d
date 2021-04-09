module til.procedures;

import std.conv : to;
import std.experimental.logger : trace;

import til.exceptions;
import til.ranges;
import til.nodes;


class Procedure
{
    string name;
    ListItem parameters;
    ListItem body;

    this(string name, ListItem parameters, ListItem body)
    {
        this.name = name;
        this.parameters = parameters;
        this.body = body;

        trace(
            "proc.define: ", this.name,
            "(", this.parameters, ")",
            ": ", this.body
        );
    }

    ListItem run(SubProgram escopo, string name, Range arguments)
    {
        trace(
            "proc.run:"
            ~ this.name ~ "(" ~ to!string(arguments) ~ ") "
        );


        auto procedureScope = new DefaultEscopo(escopo, "proc " ~ this.name);

        foreach(index, parameterName; this.parameters.strings)
        {
            if (arguments.empty)
            {
                trace("parameterName:", parameterName);
                throw new InvalidException(
                    "Wrong number of parameters to command "
                    ~ "\"" ~ name ~ "\"."
                );
            }
            else
            {
                auto argument = arguments.consume();
                procedureScope[parameterName] = argument;
                trace(" argument ", parameterName, "=", argument);
            }
        }
        procedureScope[["args"]] = new SubList(arguments);

        trace(" body.run: " ~ to!string(this.body) ~ ";");

        auto result = new ExecList(this.body.items).run(procedureScope);
        return result;
    }
}
