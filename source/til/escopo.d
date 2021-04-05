module til.escopo;

import std.algorithm.iteration : map, joiner;
import std.array;
import std.conv : to;
import std.experimental.logger;
import std.string : strip;

import til.exceptions;
import til.ranges;
import til.grammar;
import til.logic;
import til.nodes;
import til.procedures;
import til.til;

alias Args = Range;
alias Result = ListItem;

class Escopo
{
    Escopo parent;
    Escopo[string] namespaces;
    static Escopo[string] availableModules;
    string name = "<scope>";

    ListItem[string] variables;
    ListItem delegate(NamePath, Args)[string] commands;
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
    this(Escopo parent, string name)
    {
        this(parent);
        this.name = name;
    }
    abstract void loadCommands()
    {
    }
    Escopo importModule(string name)
    {
        auto theModule = this.availableModules[name];
        this.namespaces[name] = theModule;
        return theModule;
    }

    // Execution
    ListItem run(ListItem program)
    {
        auto returnedValue = program.run(this);
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
        trace(name, " ← ", value);
    }
    // To facilitate our own lives:
    void opIndexAssign(ListItem value, string name)
    {
        variables[name] = value;
        trace(name, " ← ", value);
    }

    override string toString()
    {
        string r = "";
        if (this.parent !is null)
        {
            r ~= this.parent.name ~ "/";
        }
        r ~= this.name ~ ":\n";

        foreach(name, value; variables)
        {
            r ~= "  " ~ name ~ "=<"
                 ~ to!string(value) ~ ">";
        }
        r ~= ".";
        return r;
    }

    // Commands
    Result delegate(NamePath, Args) getCommand(NamePath path)
    {
        string head = path[0];
        trace("getCommand: ", head);
        trace("scope: ", this);

        auto namespace = this.namespaces.get(head, null);
        if (namespace !is null)
        {
            NamePath newPath = path[1..$];
            trace(" searching for ", newPath, " inside namespace ", head);
            return namespace.getCommand(newPath);
        }

        ListItem delegate(NamePath, Args) handler = this.commands.get(head, null);
        if (handler is null)
        {
            if (this.parent is null)
            {
                return null;
            }
            else
            {
                trace(
                    ">>> SEARCHING FOR COMMAND ",
                    head,
                    " IN PARENT SCOPE <<<"
                );
                return this.parent.getCommand(path);
            }
        }
        else
        {
            return handler;
        }
    }

    Result runCommand(NamePath path, Args arguments)
    {
        // Normally the end of the program, where
        // all that is left is a simple result:
        /*
        if (path.length == 0)
        {
            return null;
        }
        */

        trace("runCommand:", path, " : ", arguments);
        trace(" running in scope:", this);
        auto handler = this.getCommand(path);
        if (handler is null)
        {
            trace("NO COMMAND FOUND FOR ", path);
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
    this(Escopo parent, string name)
    {
        super(parent, name);
    }

    override void loadCommands()
    {
        // Basic commands:
        this.commands["set"] = &this.cmd_set;
        this.commands["if"] = &this.cmd_if;
        this.commands["foreach"] = &this.cmd_foreach;
        this.commands["proc"] = &this.cmd_proc;
        this.commands["return"] = &this.cmd_return;

        // Modules
        this.commands["import"] = &this.cmd_import;

        // Tests:
        this.commands["range"] = &this.cmd_range;
    }

    // Commands:
    Result cmd_set(NamePath path, Args arguments)
    {
        // TODO: navigate through arguments[0].namePath...
        auto varPath = arguments.consume().namePath;
        trace(" set: ", arguments);
        auto value = new SubList(arguments);
        // XXX : should we "unroll" the value???
        // PROBABLY NOT.
        // -- variables["x"] = Range;
        // io.out $x  <-- THAT will consume the Range.
        this[varPath] = value;
        return value;
    }

    Result cmd_if(NamePath cmd, Args arguments)
    {
        /*
        Disclaimer: this is kind of shitty. Beware.
        */
        auto condition = arguments.consume();
        ListItem thenBody = arguments.consume();
        trace("if ", condition, " then ", thenBody);

        ListItem elseBody;
        if (!arguments.empty)
        {
            auto elseWord = arguments.consume().asString;
            if (elseWord != "else")
            {
                throw new InvalidException(
                    "Invalid format for if/then/else clause"
                );
            }
            elseBody = arguments.consume();
            trace("   else ", elseBody);
        }
        else
        {
            elseBody = null;
        }
        trace("cmd_if.scope: ", this);

        // Run the condition:
        bool result = false;
        auto conditionItems = BaseList.flatten(condition.items);
        trace(" → if ", conditionItems, " then ", thenBody);
        auto conditions = new CommonList(conditionItems).run(this);
        trace(" -→ if ", conditions, " then ", thenBody);
        result = boolean(conditions.items);
        trace(" --- result: ", result);
        if (result)
        {
            return new ExecList(thenBody.items).run(this);
        }
        else if (elseBody !is null)
        {
            trace(" elseBody.items: ", elseBody.items);
            return new ExecList(elseBody.items).run(this);
        }
        else
        {
            return new SubList();
        }
    }

    Result cmd_foreach(NamePath cmd, Args arguments)
    {
        /*
        DISCLAIMER: this code is very (VERY) inefficient.
        */
        auto argNames = arguments.consume();
        auto argRange = arguments.consume();
        auto argBody = arguments.consume();

        trace(" FOREACH ", argNames, " in ", argRange, ":");
        trace("         ", argBody);

        auto anItems = argNames.items;
        ListItem[] names;
        if (anItems is null)
        {
            names = [argNames];
        }
        else {
            names = new CommonList(anItems).atoms;
        }
        trace(" names: ", names);
        auto range = new CommonList(argRange.items).run(this);
        trace(" range: ", range);

        Result result;
        foreach(item; range.items)
        {
            auto loopScope = new DefaultEscopo(this, "foreach " ~ to!string(item));
            trace(" item: ", item);
            auto subItems = item.items;
            if (subItems is null)
            {
                foreach(index, name; names)
                {
                    trace("   name: ", name);
                    loopScope[name.namePath] = item;
                }
            }
            else
            {
                ListItem[] plainItems = BaseList.flatten(subItems);
                foreach(index, name; names)
                {
                    trace("   name: ", name);
                    trace("   plainItems: ", plainItems);
                    loopScope[name.namePath] = plainItems[index];

                    // TODO: analyse each result.scopeExit!
                    // TODO (later): optionally **inline** loops.
                    //  That should be achieved simply putting all
                    // lists run with its own loopScope into a single
                    // ExecList and running this one.
                    // XXX: and THAT is a very nice reason why we
                    // should be using D Ranges system: a List content
                    // could be provided dynamically, so we would turn
                    // this loop range into an... actual range.
                }
            }
            trace("loopScope: ", loopScope);
            trace("argBody.items: ", argBody.items);
            result = new ExecList(argBody.items).run(loopScope);
        }

        trace(" ----- FOREACH END -----");
        return null;
    }

    Result cmd_proc(NamePath cmd, Args arguments)
    {
        // proc name {parameters} {body}
        ListItem arg0 = arguments.consume();
        string name = arg0.asString;
        ListItem parameters = arguments.consume();
        ListItem body = arguments.consume();

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

    Result runProc(NamePath path, Args arguments)
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

    Result cmd_return(NamePath cmdName, Args arguments)
    {
        trace(" --- RETURN: ", arguments);
        auto returnValue = new SubList(arguments);
        returnValue.scopeExit = ScopeExitCodes.ReturnSuccess;
        return returnValue;
    }

    // --------------------------------------------
    Result cmd_import(NamePath path, Args arguments)
    {
        // import std.io as x
        auto modulePath = arguments.consume().namePath;
        string newName = null;

        if (!arguments.empty)
        {
            auto as = arguments.consume().asString;
            if (as != "as")
            {
                throw new InvalidException(
                    "Invalid syntax for import"
                );
            }
            newName = arguments.consume().asString;
        }
        tracef("IMPORT %s AS %s", modulePath, newName);

        // Check if the submodule actually exists:
        Escopo target = this;
        foreach(namePart; modulePath)
        {
            target = target.availableModules.get(namePart, null);
            if (target is null)
            {
                throw new InvalidException(
                    "Module "
                    ~ to!string(modulePath)
                    ~ " not found"
                );
            }
        }
        if (newName is null)
        {
            Escopo m = this;
            foreach(namePart; modulePath)
            {
                m = m.importModule(namePart);
            }
        }
        else
        {
            // An alias sends us direct to the submodule:
            this.namespaces[newName] = target;
        }

        return new Atom(newName);
    }

    // TESTE:
    Result cmd_range(NamePath path, Args arguments)
    {
        class Range : InfiniteRange
        {
            ulong current = 0;
            ulong limit = 0;

            this(ulong limit)
            {
                this.limit = limit;
            }

            override string toString()
            {
                return "range(0," ~ to!string(limit) ~ ")";
            }

            override void popFront()
            {
                current++;
            }
            override ListItem front()
            {
                return new Atom(current);
            }
            override bool empty()
            {
                return (current >= limit);
            }
            override Range save()
            {
                auto x = new Range(limit);
                x.current = current;
                return x;
            }
        }

        // TODO: use asInteger:
        auto limit = arguments.consume().asString;
        tracef(" range.limit:%s", limit);
        auto range = new Range(to!ulong(limit));
        return new SubList(range);
    }
}
