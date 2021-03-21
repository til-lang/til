module til.escopo;

import std.conv : to;
import std.stdio : writeln;
import std.array;

import til.nodes;


alias Arguments = ListItem[];

class BaseEscopo
{
    ListItem[][string] variables;
    // string[] freeVariables;
    Escopo parent;

    void setVariable(string name, Arguments value)
    {
        variables[name] = value;
        writeln(name ~ " ← " ~ to!string(value));
    }

    this(Escopo parent)
    {
        this.parent = parent;
    }

    SubProgram set(Arguments arguments)
    {
        writeln("STUB:SET " ~ to!string(arguments));
        return null;
    }

    SubProgram run(Arguments arguments)
    {
        writeln("STUB:RUN " ~ to!string(arguments));
        return null;
    }

    SubProgram fill(Arguments arguments)
    {
        writeln("STUB:FILL " ~ to!string(arguments));
        return null;
    }

    SubProgram retorne(Arguments arguments)
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

        // Copy all parent variables:
        if (parent !is null)
        {
            foreach(varName, value; parent.variables)
            {
                variables[varName] = value;
            }
        }
    }

    override SubProgram set(Arguments arguments)
    {
        string varName = to!string(arguments[0]);
        ListItem[] value = arguments[1..$];
        setVariable(varName, value);

        // TESTE:
        auto expressions = new Expression[1];
        auto list = new List(value);
        expressions[0] = new Expression(list);
        auto sp = new SubProgram(expressions);
        return sp;
    }

    override SubProgram run(Arguments arguments)
    {
        string varName = to!string(arguments[0]);

        SubProgram sp = arguments[1].subProgram;
        SubProgram value = sp.run(this);

        auto li = new ListItem(value);
        auto list = new ListItem[1];
        list[0] = li;
        setVariable(varName, list);
        return null;
    }

    override SubProgram fill(Arguments arguments)
    {
        writeln("FILL! " ~ to!string(variables));

        string result = to!string(arguments);

        foreach(varName, value; variables)
        {
            string key = "$" ~ varName;
            result = result.replace(key, to!string(value));
        }

        auto expressions = new Expression[1];
        expressions[0] = new Expression(result);
        auto sp = new SubProgram(expressions);
        writeln(" - filled: " ~ to!string(sp));
        return sp;
    }

    override SubProgram retorne(Arguments arguments)
    {
        auto varName = to!string(arguments[0]);
        auto value = variables[varName];

        auto expressions = new Expression[1];
        auto list = new List(value);
        expressions[0] = new Expression(list);
        auto sp = new SubProgram(expressions);
        // XXX: A subprogram returning itself? WEIRD!
        sp.returnValue = sp;

        return sp;
    }
}
