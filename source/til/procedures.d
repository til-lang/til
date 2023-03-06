module til.procedures;

import std.algorithm : canFind;

import til.exceptions;
import til.nodes;


class Procedure : Command
{
    string name;
    Dict parameters;
    SubProgram body;

    this(string name, Dict parameters, SubProgram body)
    {
        this.name = name;
        this.parameters = parameters;
        this.body = body;
        super(null);
    }

    override Context run(string name, Context context)
    {
        auto newScope = new Escopo(context.escopo);
        newScope.description = name;

        string[] parametersAlreadySet;

        // Set every default value in the parameters:
        foreach (parameterName, info; parameters.values)
        {
            Item *defaultValuePtr = ("default" in (cast(Dict)info).values);
            if (defaultValuePtr !is null)
            {
                auto defaultValue = *defaultValuePtr;
                newScope[parameterName] = defaultValue;
                debug {
                    stderr.writeln(parameterName, "(default) = ", defaultValue);
                }
                parametersAlreadySet ~= parameterName;
            }
        }

        auto arguments = context.items;
        debug {
            stderr.writeln("arguments:", arguments);
        }

        string[] namedParametersAlreadySet;
        Items positionalArguments;
        // Search for named arguments:
        bool lookForNamedArguments = true;
        foreach (argument; arguments)
        {
            debug {
                stderr.writeln(" argument:", argument, "/", argument.type);
            }
            if (argument.toString() == "--")
            {
                lookForNamedArguments = false;
                continue;
            }

            if (lookForNamedArguments && argument.type == ObjectType.SimpleList)
            {
                SimpleList pair = cast(SimpleList)argument;
                if (pair.items.length != 2)
                {
                    throw new Exception(
                        "Invalid named parameter: "
                        ~ pair.toString()
                    );
                }
                auto key = pair.items[0].toString();
                auto value = pair.items[1];
                newScope[key] = value;
                debug {
                    stderr.writeln(key, "=", value);
                }
                namedParametersAlreadySet ~= key;
                parametersAlreadySet ~= key;
            }
            else
            {
                positionalArguments ~= argument;
            }
        }

        debug {
            stderr.writeln("positionalArguments:", positionalArguments);
            stderr.writeln("namedParametersAlreadySet:", namedParametersAlreadySet);
        }

        // Now iterate positional parameters to
        // find correspondent arguments
        int currentIndex = 0;
        foreach (parameterName; parameters.order)
        {
            if (namedParametersAlreadySet.canFind(parameterName))
            {
                continue;
            }

            if (currentIndex >= positionalArguments.length)
            {
                if (parametersAlreadySet.canFind(parameterName))
                {
                    continue;
                }
                else
                {
                    auto msg = "Not enough arguments passed to command"
                        ~ " `" ~ name ~ "`.";
                    return context.error(msg, ErrorCode.InvalidSyntax, "");
                }
            }
            auto argument = positionalArguments[currentIndex++];
            newScope[parameterName] = argument;
            debug {
                stderr.writeln(parameterName, "=", argument);
            }
        }

        auto newContext = context.next(newScope, context.size);

        // RUN!
        newContext = context.process.run(body, newContext);
        newContext = context.process.closeCMs(newContext);

        context.size = newContext.size;

        if (newContext.exitCode == ExitCode.Return)
        {
            context.exitCode = ExitCode.Success;
        }
        else
        {
            context.exitCode = newContext.exitCode;
        }

        return context;
    }
}
