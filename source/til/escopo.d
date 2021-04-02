module til.escopo;

import std.algorithm.iteration : map, joiner;
import std.array;
import std.conv : to;
import std.stdio : writeln;
import std.string : strip;

import til.grammar;
import til.logic;
import til.nodes;
import til.procedures;
import til.til;


class Escopo
{
    Escopo parent;
    Escopo[string] namespaces;

    ListItem[string] variables;
    ListItem delegate(NamePath, List)[string] commands;
    // string[] freeVariables;

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

    // Execution
    ListItem run(List program)
    {
        auto returnedValue = program.run(this, true);
        return returnedValue;
    }

    // Operators
    // escopo[["std", "out"]]
    ListItem opIndex(string name)
    {
        ListItem value = this.variables.get(name, null);
        if (value is null && this.parent !is null)
        {
            return this.parent[name];
        }
        else
        {
            return value;
        }
    }
    // escopo[["std", "out"]] = {1 2 3}
    void opIndexAssign(ListItem value, NamePath path)
    {
        // TODO: navigate through path...
        string name = to!string(path.joiner("."));
        variables[name] = value;
        writeln(name, " ← ", value);
    }
    // To facilitate our own lives:
    void opIndexAssign(ListItem value, string name)
    {
        variables[name] = value;
        writeln(name, " ← ", value);
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
    ListItem delegate(NamePath, List) getCommand(NamePath path)
    {
        string head = path[0];

        auto namespace = this.namespaces.get(head, null);
        if (namespace !is null)
        {
            return namespace.getCommand(path[1..$]);
        }

        ListItem delegate(NamePath, List) handler = commands.get(head, null);
        if (handler is null)
        {
            if (this.parent is null)
            {
                return null;
            }
            else
            {
                return this.parent.getCommand(path);
            }
        }
        else
        {
            return handler;
        }
    }

    ListItem run_command(NamePath path, List arguments)
    {
        // Normally the end of the program, where
        // all that is left is a simple result:
        /*
        if (path.length == 0)
        {
            return null;
        }
        */

        writeln("run_command:", path, " : ", arguments);
        auto handler = this.getCommand(path);
        if (handler is null)
        {
            return null;
        }
        else
        {
            return handler(path, arguments);
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
        this.commands["set"] = &this.cmd_set;
        this.commands["if"] = &this.cmd_if;
        this.commands["proc"] = &this.proc;
        this.commands["return"] = &this.cmd_return;
    }

    // Commands:
    ListItem cmd_set(NamePath path, List arguments)
    {
        // TODO: navigate through arguments[0].namePath...
        auto varPath = arguments[0].namePath;
        auto value = new List(arguments[1..$]);
        this[varPath] = value;
        return value;
    }

    ListItem cmd_if(NamePath cmd, List arguments)
    {
        /*
        Disclaimer: this is kind of shitty. Beware.
        */
        auto condition = arguments[0];
        ListItem thenBody = arguments[1];
        ListItem elseBody;
        if (arguments.length >= 4)
        {
            elseBody = arguments[3];
            writeln("   else ", elseBody);
        }
        else
        {
            elseBody = null;
        }

        writeln("if ", condition, " then ", thenBody);

        // Run the condition:
        bool result = false;
        foreach(c; condition.items)
        {
            // XXX : it runs but IGNORES the result of every list
            // in the condition, except the last one...
            writeln(" --- IF.c: ", c);
            auto l = new List(c.items);
            auto e = l.evaluate(this);
            writeln(" --- IF.e: ", e);
            result = boolean(e);
        }
        if (result)
        {
            return new List(thenBody.items).run(this, true);
        }
        else if (elseBody !is null)
        {
            return new List(elseBody.items, true).run(this, true);
        }
        else
        {
            // XXX : it seems coherent, but is it correct?
            return arguments;
        }
    }

    ListItem proc(NamePath cmd, List arguments)
    {
        // proc name {parameters} {body}
        ListItem arg0 = arguments[0];
        string name = arg0.asString;
        ListItem parameters = arguments[1];
        ListItem body = arguments[2];

        this.procedures[name] = new Procedure(
            name,
            parameters,
            // TODO: check if it is really a SubList type:
            body
        );

        // Make the procedure available:
        this.commands[name] = &this.runProc;

        return arg0;
    }

    ListItem runProc(NamePath path, List arguments)
    {
        // TODO: navigate through path items properly:
        string cmdName = to!string(path.joiner("."));

        auto proc = this.procedures.get(cmdName, null);
        if (proc is null) {
            throw new Exception(
                "Trying to call " ~ cmdName ~ "but procedure is gone"
            );
        }
        return proc.run(this, cmdName, arguments);
    }

    ListItem cmd_return(NamePath cmdName, List arguments)
    {
        writeln(" --- RETURN: ", arguments);
        auto returnValue = arguments;
        returnValue.execute = false;
        returnValue.scopeExit = ScopeExitCodes.ReturnSuccess;
        return returnValue;
    }
}
