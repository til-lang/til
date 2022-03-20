module til.escopo;

import std.array : join, split;
import std.container : DList;

import til.packages;
import til.nodes;
import til.procedures;
import til.scheduler;


class NotFoundError : Exception
{
    this(string msg)
    {
        super(msg);
    }
}


class Escopo
{
    Escopo parent;
    Items[string] variables;
    Items[string] internalVariables;
    CommandsMap commands;
    string description;

    this(Escopo parent=null, string description=null)
    {
        this.parent = parent;
        this.description = description;
    }

    // The "heap":
    // auto x = escopo["x"];
    Items opIndex(string name)
    {
        Items* value = (name in this.variables);
        if (value is null)
        {
            if (this.parent !is null)
            {
                return this.parent[name];
            }
            else
            {
                throw new NotFoundError("`" ~ name ~ "` variable not found!");
            }
        }
        else
        {
            return *value;
        }
    }
    // escopo["x"] = new Atom(123);
    void opIndexAssign(Item value, string name)
    {
        variables[name] = [value];
    }
    void opIndexAssign(Items value, string name)
    {
        variables[name] = value;
    }

    // Debugging information about itself:
    override string toString()
    {
        return (
            "Escopo\n"
            ~ " vars:" ~ to!string(variables.byKey) ~ "\n"
            ~ " cmds:" ~ to!string(commands.byKey) ~ "\n"
        );
    }

    // Commands and procedures
    Command getCommand(string name)
    {
        Command cmd;

        // If it's a local command:
        auto c = (name in commands);
        if (c !is null) return *c;

        // It it's present on parent:
        if (this.parent !is null)
        {
            cmd = parent.getCommand(name);
            if (cmd !is null)
            {
                commands[name] = cmd;
                return cmd;
            }
        }

        // If the command is present in an external package:
        bool success = {
            // exec -> exec
            if (this.importModule(name, name)) return true;

            // http.client.get -> http.client
            string packagePath = to!string(name.split(".")[0..$-1].join("."));
            if (this.importModule(packagePath)) return true;

            // http.client.get -> http
            packagePath = to!string(name.split(".")[0]);
            if (this.importModule(packagePath)) return true;

            return false;
        }();

        if (success) {
            // We imported the package, but we're not sure if this
            // name actually exists inside it:
            // (Important: do NOT call this method recursively!)
            c = (name in commands);
            if (c !is null)
            {
                commands[name] = *c;
                cmd = *c;
            }
        }

        // If such command doesn't seem to exist, `cmd` will be null:
        return cmd;
    }
}
