module til.commands;

import std.algorithm.iteration : map, joiner;
import std.conv : to;
import std.experimental.logger : trace, error;

import til.exceptions;
import til.logic;
import til.modules;
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
        context.escopo.program.importModule(modulePath, newName);

        // import std.io as io
        // "io.out" = command
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
        context.run(&c.forceEvaluate);
        context.run(&boolean, 1);
        trace(context.escopo);
        auto isConditionTrue = context.pop().asBoolean;

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
        trace("foreach.context: ", context);
        auto argName = context.pop().asString;
        auto argBody = cast(SubList)context.pop();

        trace(" FOREACH ", argName, " : ", argBody);

        /*
        Do NOT create a new scope for the
        body of foreach.
        */
        auto loopScope = context.escopo;

        foreach(item; context.stream)
        {
            trace(" item: ", item, " ", item.type);
            loopScope[argName] = item;

            trace("loopScope: ", loopScope);
            context = loopScope.run(argBody.subprogram);

            if (context.exitCode == ExitCode.Break)
            {
                break;
            }
            else if (context.exitCode == ExitCode.Continue)
            {
                continue;
            }
        }

        /*
        `foreach` is NOT a "sink", because you can simply
        break the loop "in the middle" of a stream and
        the rest can be passed to other command to
        process.
        */
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

    // SCOPE MANIPULATION
    commands["uplevel"] = (string path, CommandContext context)
    {
        /*
        */
        auto parentScope = context.escopo.parent;
        if (parentScope is null)
        {
            throw new Exception("No upper level to access.");
        }

        /*
        It is very important to do this `pop` **before**
        copying the context.size into
        newContext.size!
        You see,
        uplevel set x 1 2 3  ← this command has 5 arguments
           -    set x 1 2 3  ← and this one has 4
        */
        auto cmdName = context.pop().asString;

        /*
        Also important to remember: `uplevel` is a command itself.
        As such, all its arguments were already evaluated
        when it was called, so we can safely assume
        there's no further  substitutions to be
        made and this is going to apply to
        the command we are calling
        */
        auto cmdArguments = context.items;

        // 1- create a new Command
        auto command = new Command(cmdName, cmdArguments);

        // 2- create a new context, with the parent
        //    scope as the context.escopo
        auto newContext = context.next;
        newContext.escopo = parentScope;
        newContext.size = context.size;

        // 3- run the command
        /*
        IMPORTANT: always remember the previous (parent) scope
        has an outdated stack that is NOT synchronized
        with the current one. So we need to let
        Command.run "evaluate" all arguments
        again (remember: we passed them
        as a simple Items list), so
        that they end up in the
        old stack as it
        is expected.
        */

        auto returnedContext = command.run(newContext);

        if (returnedContext.exitCode == ExitCode.Failure)
        {
            throw new Exception("upleval/command " ~ cmdName ~ ": Failure");
        }
        context.exitCode = ExitCode.ReturnSuccess;
        return context;
    };
}
