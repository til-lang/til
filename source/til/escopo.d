module til.escopo;

import std.algorithm.iteration : map, joiner;
import std.conv : to;
import std.experimental.logger : trace, error;
import std.string : strip;

import til.exceptions;
import til.grammar;
import til.logic;
import til.nodes;
import til.procedures;
import til.ranges;
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
        trace(">>> ", path);
        trace("  > ", value.toString());
        // TODO: navigate through path...
        trace(" opIndexAssign: ", path, " ", value);
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
                 ~ to!string(value) ~ ">\n";
        }
        foreach(namespace; namespaces.byKey)
        {
            r ~= "+" ~ namespace ~ "\n";
        }
        r ~= ".";
        return r;
    }

    // Commands
    Result delegate(NamePath, Args) getCommand(NamePath path)
    {
        string head;
        if (path.length == 0)
        {
            // throw new Exception("Command not found");
            /*
            We imported a module, like
            import fvector
            ...
            Can't we call the module itself? Like
            set my_vector [fvector 250]
            ?
            Yeah, I think we should...
            */
            head = "MAIN";
        }
        else
        {
            head = path[0];
        }
        trace("getCommand: ", head);

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
                error("Command not found: " ~ head);
                return null;
            }
            else
            {
                trace(
                    ">>> SEARCHING FOR COMMAND ",
                    head,
                    " IN PARENT SCOPE <<<"
                );
                handler = parent.getCommand(path);
                if (handler !is null)
                {
                    auto reference = parent.namespaces.get(head, null);
                    if (reference !is null)
                    {
                        this.namespaces[head] = reference;
                    }
                }
                return handler;
            }
        }
        else
        {
            return handler;
        }
    }

    Result runCommand(NamePath path, Args arguments)
    {
        trace("runCommand:", path, " : ", arguments);
        auto handler = this.getCommand(path);
        if (handler is null)
        {
            error("Not found: " ~ to!string(path));
            return null;
        }

        return runCommandWithHandler(
            path, arguments, handler
        );
    }

    Result runCommandWithHandler(NamePath path, Args arguments, Result delegate (NamePath, Args) handler)
    {
        auto result = handler(path, arguments);

        // XXX : this is a kind of "sefaty check".
        // It would be nice to NOT run this part
        // in "release" code.
        if (result is null)
        {
            throw new Exception(
                "Command "
                ~ to!string(path)
                ~ " returned null. The implementation"
                ~ " is probably wrong."
            );
        }

        if (arguments.empty)
        {
            return result;
        }
        else
        {
            trace(" remaining arguments: ", arguments);
            auto items = result.items;
            if (items is null)
            {
                items = new StaticItems([result]);
            }
            return new SimpleList(
                new ChainedItems([items, arguments])
            );
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
        this.commands["continue"] = &this.cmd_continue;
        this.commands["break"] = &this.cmd_break;
        this.commands["proc"] = &this.cmd_proc;
        this.commands["return"] = &this.cmd_return;

        // Modules
        this.commands["import"] = &this.cmd_import;
    }

    // Commands:
    Result cmd_set(NamePath path, Args arguments)
    {
        // TODO: navigate through arguments[0].namePath...
        auto varPath = arguments.consume().namePath;
        trace(" set: ", varPath, " ", arguments);
        auto value = new SimpleList(arguments);
        // XXX : should we "unroll" the value???
        // PROBABLY NOT.
        // -- variables["x"] = list-with-a-Range;
        // io.out $x <-- THAT will consume the Range.
        // (We can save infinite ranges this way, too.)
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

        // Run the condition:
        bool result = false;

        auto conditions = condition.run(this, true);

        trace(" -→ if ", conditions, " then ", thenBody);
        result = this.boolean(conditions.items);
        trace(" --- result: ", result);
        if (result)
        {
            return thenBody.run(this, true);
        }
        else if (elseBody !is null)
        {
            trace(" elseBody.items: ", elseBody.items);
            return elseBody.run(this, true);
        }
        else
        {
            return new SimpleList();
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

        string[] names = argNames.strings;
        trace(" names: ", names);
        auto range = argRange.run(this, true);
        trace(" range: ", range);

        auto loopScope = new DefaultEscopo(
            this, "foreach<" ~ to!string(range) ~ ">"
        );

        Result result;

        // The first iteration checks if our range items
        // are atoms or lists:
        Range theItems = range.items;
        ListItem firstItem = theItems.save().consume();

        // Some helper functions to accelerate things a little bit:
        ListItem iterateWithAtoms(Range items)
        {
            foreach(item; items)
            {
                trace(" item: ", item);
                foreach(name; names)
                {
                    trace("   name: ", name);
                    loopScope[name] = item;
                }
                trace("loopScope: ", loopScope);
                trace("argBody.items: ", argBody.items);
                result = argBody.run(loopScope, true);
                if (result.scopeExit == ScopeExitCodes.Break)
                {
                    break;
                }
                else if (result.scopeExit == ScopeExitCodes.Continue)
                {
                    continue;
                }
            }
            result.scopeExit = ScopeExitCodes.Proceed;
            return result;
        }
        ListItem iterateWithLists(Range items)
        {
            foreach(item; range.items)
            {
                trace(" item: ", item);
                auto subItems = item.items;
                foreach(name; names)
                {
                    trace("   name: ", name);
                    trace("   subItems: ", subItems);
                    loopScope[name] = subItems.consume();

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
                trace("loopScope: ", loopScope);
                trace("argBody.items: ", argBody.items);
                result = argBody.run(loopScope, true);
                if (result.scopeExit == ScopeExitCodes.Break)
                {
                    break;
                }
                else if (result.scopeExit == ScopeExitCodes.Continue)
                {
                    continue;
                }
            }
            result.scopeExit = ScopeExitCodes.Proceed;
            return result;
        }
        // --------------------------------

        // TODO: what if firstItem is null???
        if (firstItem.items is null)
        {
            return iterateWithAtoms(theItems);
        }
        else
        {
            return iterateWithLists(theItems);
        }
    }
    Result cmd_break(NamePath cmdName, Args arguments)
    {
        trace(" --- BREAK: ", arguments);
        auto returnValue = new SimpleList(arguments.exhaust());
        returnValue.scopeExit = ScopeExitCodes.Break;
        return returnValue;
    }
    Result cmd_continue(NamePath cmdName, Args arguments)
    {
        trace(" --- CONTINUE: ", arguments);
        // XXX : should not have any arguments...
        auto returnValue = new SimpleList(arguments.exhaust());
        returnValue.scopeExit = ScopeExitCodes.Continue;
        return returnValue;
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
        auto returnValue = new SimpleList(arguments.exhaust());
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
        trace("IMPORT ", modulePath, " AS ", newName);

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
}
