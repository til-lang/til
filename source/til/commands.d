module til.commands;

import std.algorithm.iteration : map, joiner;
import std.conv : to;
import std.experimental.logger : trace, error;
import std.string : strip;

import til.exceptions;
import til.logic;
import til.nodes;
// import til.procedures;


CommandHandler[string] commands;

// Commands:
static this()
{
    commands["set"] = (Process escopo, string path, CommandResult result)
    {
        // TODO: navigate through arguments[0].namePath...
        auto name = escopo.pop().asString;
        auto value = escopo.pop();
        escopo[name] = value;
        result.exitCode = ExitCode.CommandSuccess;
        return result;
    };

    commands["import"] = (Process escopo, string path, CommandResult result)
    {
        // import std.io as x
        auto modulePath = escopo.pop().asString;
        string newName = modulePath;

        // import std.io as x
        //          1    2  3
        if (result.argumentCount == 3)
        {
            // 2
            auto as = escopo.pop().asString;
            if (as != "as")
            {
                throw new InvalidException(
                    "Invalid syntax for import"
                );
            }
            // 3
            newName = escopo.pop().asString;
        }
        trace("IMPORT ", modulePath, " AS ", newName);

        // Check if the submodule actually exists:
        CommandHandler[string] target;
        target = escopo.program.availableModules.get(modulePath, null);
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
            escopo.program.commands[cmdPath] = command;
        }

        result.exitCode = ExitCode.CommandSuccess;
        return result;
    };

    commands["if"] = (Process escopo, string path, CommandResult result)
    {
        trace("Running command if");
        trace(" inside process ", escopo);
        BaseList conditions = cast(BaseList)escopo.pop();
        ListItem thenBody = escopo.pop();
        trace("if ", conditions, " then ", thenBody);

        ListItem elseBody;
        // if (condition) {then} else {else}
        //     1           2     3     4
        if (result.argumentCount == 4)
        {
            auto elseWord = escopo.pop().asString;
            if (elseWord != "else")
            {
                throw new InvalidException(
                    "Invalid format for if/then/else clause"
                );
            }
            elseBody = escopo.pop();
            trace("   else ", elseBody);
        }
        else
        {
            elseBody = null;
        }

        // Run the condition:
        auto evaluatedConditions =  cast(SimpleList)conditions.evaluate(escopo, true);
        trace("evaluatedConditions:", evaluatedConditions);
        bool isConditionTrue = escopo.boolean(evaluatedConditions.items);
        trace(" --- isConditionTrue: ", isConditionTrue);

        // TODO : what is it's not a SubList?
        // Like:
        // if ($x} $y
        // ?
        if (isConditionTrue)
        {
            result = escopo.run((cast(SubList)thenBody).subprogram);
        }
        else if (elseBody !is null)
        {
            result = escopo.run((cast(SubList)elseBody).subprogram);
        }
        result.exitCode = ExitCode.CommandSuccess;
        return result;
    };

    commands["foreach"] = (Process escopo, string path, CommandResult result)
    {
        /*
        DISCLAIMER: this code is very (VERY) inefficient.

        foreach has 2 flavors:
        1: foreach (x) (a b c d e) {...}  (3 arguments)
        2: range > foreach (x) {...}      (2 arguments)
        */
        trace("foreach.escopo: ", escopo);
        auto argNames = cast(SimpleList)escopo.pop();
        SimpleList argRange = null;
        if (result.argumentCount == 3)
        {
            argRange = cast(SimpleList)escopo.pop();
        }
        auto argBody = cast(SubList)escopo.pop();

        trace(" FOREACH ", argNames, " in ", argRange, " : ", argBody);

        string[] names;
        foreach(n; argNames.items)
        {
            names ~= n.asString;
        }
        trace(" names: ", names);

        auto loopScope = new Process(escopo);

        CommandResult iterate(ListItem item)
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
            else
            {
                foreach(name; names)
                {
                    trace(name, "←", item);
                    loopScope[name] = item;
                }
            }

            trace("loopScope: ", loopScope);
            auto iterResult = loopScope.run(argBody.subprogram);
            return iterResult;
        }

        if (argRange !is null)
        {
            foreach(item; argRange.items)
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
        }
        else
        {
            foreach(item; result.stream)
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
        }
        result.exitCode = ExitCode.CommandSuccess;
        return result;
    };
    commands["break"] = (Process escopo, string path, CommandResult result)
    {
        result.exitCode = ExitCode.Break;
        return result;
    };
    commands["continue"] = (Process escopo, string path, CommandResult result)
    {
        result.exitCode = ExitCode.Continue;
        return result;
    };

    static if(false)
    {
    CommandResult cmd_proc(Process escopo, string cmd)
    {
        // proc name {parameters} {body}
        ListItem arg0 = arguments.consume();
        string name = arg0.asString;
        ListItem parameters = arguments.consume();
        ListItem body = arguments.consume();

        escopo.procedures[name] = new Procedure(
            name,
            parameters,
            // TODO: check if it is really a SubList type:
            body
        );

        // Make the procedure available:
        escopo.commands[name] = &escopo.runProc;

        return arg0;
    }

    CommandResult runProc(Process escopo, string path)
    {
        // TODO: navigate through path items properly:
        string cmdName = to!string(path.joiner("."));

        auto proc = escopo.procedures.get(cmdName, null);
        if (proc is null) {
            throw new Exception(
                "Trying to call " ~ cmdName ~ "but procedure is gone"
            );
        }
        return proc.run(escopo, cmdName, arguments);
    }

    CommandResult cmd_return(Process escopo, string cmdName)
    {
        trace(" --- RETURN: ", arguments);
        auto returnValue = new SimpleList(arguments.exhaust());
        returnValue.scopeExit = ExitCode.ReturnSuccess;
        return returnValue;
    }

    // --------------------------------------------
    } // end static if
}
