module til.commands;

import std.algorithm.iteration : map, joiner;
import std.conv : to;
import std.experimental.logger : trace, error;
import std.string : strip;

import til.exceptions;
import til.logic;
import til.nodes;
import til.procedures;


CommandHandler[string] commands;

// Commands:
static this()
{
    commands["set"] = (string path, CommandContext context)
    {
        auto name = context.pop().asString;
        // set x "1"
        // set y 11 22 33
        context.escopo[name] = context.items;
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    commands["import"] = (string path, CommandContext context)
    {
        // import std.io as x
        auto modulePath = context.pop().asString;
        string newName = modulePath;

        // import std.io as x
        if (context.size == 2)
        {
            auto as = context.pop().asString;
            if (as != "as")
            {
                throw new InvalidException(
                    "Invalid syntax for import"
                );
            }
            newName = context.pop().asString;
        }
        trace("IMPORT ", modulePath, " AS ", newName);

        // Check if the submodule actually exists:
        CommandHandler[string] target;
        target = context.escopo.program.availableModules.get(modulePath, null);
        if (target is null)
        {
            throw new InvalidException(
                "Module "
                ~ to!string(modulePath)
                ~ " not found"
            );
        }

        // import std.io as io
        // "io.out" = command
        foreach(name, command; target)
        {
            string cmdPath = newName ~ "." ~ name;
            context.escopo.program.commands[cmdPath] = command;
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    commands["if"] = (string path, CommandContext context)
    {
        trace("Running command if");
        trace(" inside process ", context.escopo);
        BaseList conditions = cast(BaseList)context.pop();
        ListItem thenBody = context.pop();
        trace("if ", conditions, " then ", thenBody);

        ListItem elseBody;
        // if (condition) {then} else {else}
        if (context.size == 2)
        {
            auto elseWord = context.pop().asString;
            if (elseWord != "else")
            {
                throw new InvalidException(
                    "Invalid format for if/then/else clause"
                );
            }
            elseBody = context.pop();
            trace("   else ", elseBody);
        }
        else
        {
            elseBody = null;
        }

        // Run the condition:
        auto c = cast(SimpleList)conditions;
        auto conditionsContext = c.evaluate(context, true);
        conditionsContext = boolean(conditionsContext);
        trace(" --- conditionsContext: ", conditionsContext);
        trace(context.escopo);
        auto isConditionTrue = conditionsContext.pop().asBoolean;
        trace(" --- isConditionTrue: ", conditionsContext);

        // TODO: extract 1 Atom(bool);

        // TODO : what is it's not a SubList?
        // Like:
        // if ($x} $y
        // ?
        if (isConditionTrue)
        {
            context = context.escopo.run((cast(SubList)thenBody).subprogram);
        }
        else if (elseBody !is null)
        {
            context = context.escopo.run((cast(SubList)elseBody).subprogram);
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    commands["foreach"] = (string path, CommandContext context)
    {
        /*
        DISCLAIMER: this code is very (VERY) inefficient.

        foreach has 2 flavors:
        1: foreach (x) (a b c d e) {...}  (3 arguments)
        2: range > foreach (x) {...}      (2 arguments)
        */
        trace("foreach.context: ", context);
        auto argNames = cast(SimpleList)context.pop();
        SimpleList argRange = null;
        if (context.size == 2)
        {
            argRange = cast(SimpleList)context.pop();
        }
        auto argBody = cast(SubList)context.pop();

        trace(" FOREACH ", argNames, " in ", argRange, " : ", argBody);

        string[] names;
        foreach(n; argNames.items)
        {
            names ~= n.asString;
        }
        trace(" names: ", names);

        auto loopScope = new Process(context.escopo);

        CommandContext iterate(ListItem item, CommandContext context)
        {
            trace(" item: ", item, " ", item.type);
            if (item.type == ObjectTypes.List)
            {
                auto subItems = (cast(BaseList)item).items;
                foreach(index, name; names)
                {
                    trace("   name: ", name);
                    trace("   subItems: ", subItems);
                    loopScope[name] = subItems[index];

                    // TODO: analyse each context.scopeExit!
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
            else
            {
                foreach(name; names)
                {
                    trace(name, "←", item);
                    loopScope[name] = item;
                }
            }

            trace("loopScope: ", loopScope);
            auto iterContext = loopScope.run(argBody.subprogram);
            return iterContext;
        }

        if (argRange !is null)
        {
            foreach(item; argRange.items)
            {
                context = iterate(item, context);
                if (context.exitCode == ExitCode.Break)
                {
                    break;
                }
                else if (context.exitCode == ExitCode.Continue)
                {
                    continue;
                }
            }
        }
        else
        {
            throw new Exception("streams not implemented yet");
            /*
            foreach(item; context.stream)
            {
                auto iterResult = iterate(item);
                if (iterResult.exitCode == ExitCode.Break)
                {
                    break;
                }
                else if (iterResult.exitCode == ExitCode.Continue)
                {
                    continue;
                }
            }
            */
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["break"] = (string path, CommandContext context)
    {
        context.exitCode = ExitCode.Break;
        return context;
    };
    commands["continue"] = (string path, CommandContext context)
    {
        context.exitCode = ExitCode.Continue;
        return context;
    };

    commands["proc"] = (string path, CommandContext context)
    {
        // proc name (parameters) {body}

        string name = context.pop().asString;
        ListItem parameters = context.pop();
        ListItem body = context.pop();

        auto proc = new Procedure(
            name,
            parameters,
            // TODO: check if it is really a SubList type:
            body
        );

        CommandContext closure(string path, CommandContext context)
        {
            return proc.run(path, context);
        }

        // Make the procedure available:
        context.escopo.program.commands[name] = &closure;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    commands["return"] = (string path, CommandContext context)
    {
        context.exitCode = ExitCode.ReturnSuccess;
        return context;
    };
}
