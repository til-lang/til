module til.escopo;

import std.array;
import std.conv : to;
import std.stdio : writeln;
import std.string : strip;

import til.grammar;
import til.nodes;
import til.procedures;
import til.til;


class Escopo
{
    List[string] variables;
    // string[] freeVariables;
    Escopo parent;
    List delegate(string, List)[string] commands;

    this()
    {
        this(cast(Escopo) null);
    }
    this(Escopo parent)
    {
        this.parent = parent;
        this.loadCommands();
    }
    void loadCommands()
    {
    }

    // Variables manipulation
    void setVariable(string name, List value)
    {
        variables[name] = value;
        writeln(name ~ " ← " ~ to!string(value));
    }

    // Execution
    List run(List program)
    {
        auto returnedValue = program.run(this);
        return returnedValue;
    }

    // Operators
    List opIndex(string name)
    {
        return this.variables.get(name, null);
    }
    override string toString()
    {
        string r = "scope:\n";
        foreach(name, value; variables)
        {
            r ~= "  " ~ name ~ "=<"
                 ~ to!string(value) ~ ">"
                 ~ "(" ~ to!string(value.length) ~")\n";
        }
        r ~= ".";
        return r;
    }

    // Commands
    List delegate(string, List arguments) getCommand(string cmdName)
    {
        List delegate(string, List arguments) handler = this.commands.get(cmdName, null);
        if (handler is null)
        {
            if (this.parent is null)
            {
                return null;
            }
            else
            {
                return this.parent.getCommand(cmdName);
            }
        }
        else
        {
            return handler;
        }
    }

    List run_command(string cmdName, List arguments)
    {
        auto handler = this.getCommand(cmdName);
        if (handler is null)
        {
            writeln(
                "COMMAND NOT FOUND: <" ~ cmdName ~ "> : "
                ~ to!string(arguments)
            );
            return new List();
        }
        else
        {
            return handler(cmdName, arguments);
        }
    }
}

class DefaultEscopo : Escopo
{
    Procedure[string] procedures;

    this()
    {
        this(null);
    }

    this(Escopo parent)
    {
        super(parent);

        /*
        We could take two different ways, here:

        1- Copy all the parent variables
        That would work very fine, but the copying  process
        could end up being very expensive.
        (O(n) on every new scope creation).

        2- Create a "linked list" of sorts, where failture
        to find a name in current scope would trigger a
        search in parent scope.
        That would make the new scope creation operation
        much cheaper and also searching for a name inside
        the local scope, but searching on parent scopes
        would obey a linear cost.
        (O(n) for searching parent scopes).

        We prefer the second option.
        So, actually, nothing to do, here. :)
        GO AWAY, NOW!!!
        */
    }

    override void loadCommands()
    {
        this.commands["set"] = &this.set;
        this.commands["proc"] = &this.proc;
        this.commands["return"] = &this.retorne;
    }

    // Commands:
    List set(string cmd, List arguments)
    {
        string varName = to!string(arguments[0]);
        auto value = new List(arguments[1..$]);
        setVariable(varName, value);

        return value;
    }

    List proc(string cmd, List arguments)
    {
        // proc name {parameters} {body}
        string name = to!string(arguments[0].evaluate(this));
        ListItem parameters = arguments[1];
        ListItem body = arguments[2];

        this.procedures[name] = new Procedure(
            name,
            parameters.values(this),
            // TODO: check if it is really a SubList type:
            body.sublist
        );

        // Make the procedure available:
        this.commands[name] = &this.runProc;

        auto result = new List(arguments[0..1]);
        return result;
    }

    List runProc(string cmdName, List arguments)
    {
        auto proc = this.procedures.get(cmdName, null);
        if (proc is null) {
            throw new Exception(
                "Trying to call " ~ cmdName ~ "but procedure is gone"
            );
        }
        return proc.run(this, cmdName, arguments);
    }

    List retorne(string cmdName, List arguments)
    {
        auto evaluatedItems = arguments.evaluate(this);
        writeln(" --- RETORNE ---");
        writeln(" --- → " ~ to!string(arguments));
        writeln(" --- ← " ~ to!string(evaluatedItems));
        auto returnValue = new List(evaluatedItems);
        returnValue.scopeExit = ScopeExitCodes.Success;
        return returnValue;
    }
}
