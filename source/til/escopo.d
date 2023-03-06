module til.escopo;

import std.array : join, split;
import std.container : DList;

import til.exceptions;
import til.packages;
import til.nodes;
import til.procedures;


class Escopo
{
    Program program;
    Escopo parent;
    Items[string] variables;
    Items contextManagers;
    string description;

    this(Program program, string description=null)
    {
        this.program = program;
        this.parent = null;
        this.description = description;
    }
    this(Escopo parent, string description=null)
    {
        this.parent = parent;
        this.program = parent.program;
        this.description = description;
    }

    // The "heap":
    // auto x = escopo["x"];
    Items opIndex(string name)
    {
        /*
        I usually favour a well-structured if/else,
        but in this case, early-returning makes
        more sense:
        */
        Items* valuesPtr = (name in this.variables);
        if (valuesPtr !is null)
        {
            return *valuesPtr;
        }

        if (this.parent !is null)
        {
            return this.parent[name];
        }

        debug {stderr.writeln("opIndex:", name);}
        Item* valuePtr = (name in this.program.globals.values);
        if (valuePtr !is null)
        {
            debug {stderr.writeln("     :", *valuePtr);}
            return [*valuePtr];
        }
        throw new NotFoundException("`" ~ name ~ "` variable not found!");
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
            "Escopo " ~ description ~ "\n"
            ~ " vars:" ~ to!string(variables.byKey) ~ "\n"
        );
    }
}
