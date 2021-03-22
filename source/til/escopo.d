module til.escopo;

import std.array;
import std.conv : to;
import std.stdio : writeln;
import std.string : strip;

import til.grammar;
import til.nodes;
import til.til;


class BaseEscopo
{
    List[string] variables;
    // string[] freeVariables;
    Escopo parent;

    void setVariable(string name, List value)
    {
        variables[name] = value;
        writeln(name ~ " ← " ~ to!string(value));
    }

    this()
    {
        this.parent = null;
    }
    this(Escopo parent)
    {
        this.parent = parent;
    }

    List set(List arguments)
    {
        writeln("STUB:SET " ~ to!string(arguments));
        return null;
    }

    List run(List arguments)
    {
        writeln("STUB:RUN " ~ to!string(arguments));
        return null;
    }

    List fill(List arguments)
    {
        writeln("STUB:FILL " ~ to!string(arguments));
        return null;
    }

    List retorne(List arguments)
    {
        writeln("STUB:RETORNE " ~ to!string(arguments));
        return null;
    }

    List run_command(string strCmd, List arguments)
    {
        switch(strCmd)
        {
            case "set":
                return this.set(arguments);
            case "run":
                return this.run(arguments);
            case "fill":
                return this.fill(arguments);
            case "return":
                return this.retorne(arguments);
            default:
                break;
        }

        writeln(
            "STUB:RUN_COMMAND " ~ strCmd ~ " " ~ to!string(arguments)
        );
        return null;
    }
}

class Escopo : BaseEscopo
{
    this()
    {
        this(null);
    }

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

    override List set(List arguments)
    {
        string varName = to!string(arguments[0]);
        auto value = new List(arguments[1..$]);
        setVariable(varName, value);

        return value;
    }

    override List run(List arguments)
    {
        string varName = to!string(arguments[0]);
        List value;

        ListItem sp = arguments[1];
        if (sp.type == ListItemType.SubProgram)
        {
            writeln("run: it is a subprogram! " ~ to!string(sp));
            auto tree = Til(to!string(sp));
            writeln(tree);
            value = execute(this, tree);
        }
        else
        {
            value = new List(arguments[1..$]);
        }

        setVariable(varName, value);
        return value;
    }

    override List fill(List arguments)
    {
        writeln("FILL! " ~ to!string(variables));

        ListItem target = arguments[0];
        string result = to!string(arguments[0]);

        if (target.type == ListItemType.SubProgram)
        {
            auto tree = Til(result);
            writeln(tree);
            auto value = execute(this, tree);
            return fill(value);
        }

        if (target.type == ListItemType.String)
        {
            result = result.strip("\"");
        }
        writeln("  - result: ", result, " : ", to!string(target.type));

        foreach(varName, value; variables)
        {
            string key = "$" ~ varName;
            result = result.replace(key, to!string(value));
            writeln("  value: ", value, " ", to!string(value));
        }

        writeln(" - fill.result: ", result);
        auto li = new ListItem(result, ListItemType.SubProgram);
        auto items = new ListItem[1];
        items[0] = li;
        auto list = new List(items);
        writeln(" - filled: " ~ to!string(list));
        return list;
    }

    override List retorne(List arguments)
    {
        auto newList = new List();
        newList.scopeExit = ScopeExitCodes.Success;
        return newList;
    }
}
