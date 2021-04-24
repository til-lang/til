module til.commands;

import std.algorithm.iteration : map, joiner;
import std.array;
import std.conv : to;

import til.exceptions;
import til.logic;
import til.msgbox;
import til.modules;
import til.nodes;
import til.procedures;
import til.ranges;

debug
{
    import std.stdio;
}

CommandHandler[string] commands;


// Commands:
static this()
{
    // ---------------------------------------------
    // Variables
    commands["set"] = (string path, CommandContext context)
    {
        string[] names;

        if (context.size < 2)
        {
            throw new Exception("`set` must receive at least two arguments.");
        }

        auto firstArgument = context.pop();
        auto secondArgument = context.pop();

        if (firstArgument.type == ObjectTypes.List)
        {
            if (secondArgument.type != ObjectTypes.List)
            {
                throw new Exception(
                    "You can only use destructuring `set` with two SimpleLists"
                );
            }

            auto l1 = cast(SimpleList)firstArgument;
            names = l1.items.map!(x => x.asString).array;

            Items values;

            auto l2 = cast(SimpleList)secondArgument;
            context = l2.forceEvaluate(context);
            auto l3 = cast(SimpleList)context.pop();
            values = l3.items;

            if (values.length < names.length)
            {
                throw new Exception(
                    "Insuficient number of items in the second list"
                );
            }

            string lastName;
            foreach(name; names)
            {
                auto nextValue = values.front;
                if (!values.empty) values.popFront();

                context.escopo[name] = nextValue;
                lastName = name;
            }
            while(!values.empty)
            {
                // Everything else goes to the last name:
                context.escopo[lastName] = context.escopo[lastName] ~ values.front;
                values.popFront();
            }
        }
        else
        {
            context.escopo[firstArgument.asString] = secondArgument;
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Modules / includes
    commands["include"] = (string path, CommandContext context)
    {
        import til.grammar;
        import til.semantics;

        import std.stdio;
        import std.file;

        string filePath = context.pop().asString;
        auto f = File(filePath, "r");
        string code = "";
        foreach(line; f.byLine)
        {
            code ~= line ~ "\n";
        }

        auto tree = Til(code);
        auto program = analyse(tree);

        context = context.escopo.run(program, context);
        if (context.exitCode != ExitCode.Failure)
        {
            context.exitCode = ExitCode.CommandSuccess;
        }
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
        context.escopo.program.importModule(modulePath, newName);

        // import std.io as io
        // "io.out" = command
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Flow control
    commands["if"] = (string path, CommandContext context)
    {
        auto conditions = cast(SimpleList)context.pop();
        auto thenBody = cast(SubList)context.pop();

        SubList elseBody;
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
            elseBody = cast(SubList)context.pop();
        }
        else
        {
            elseBody = null;
        }

        // Run the condition:
        context.run(&conditions.forceEvaluate);
        context.run(&boolean, 1);
        auto isConditionTrue = context.pop().asBoolean;

        if (isConditionTrue)
        {
            context = context.escopo.run(thenBody.subprogram);
        }
        else if (elseBody !is null)
        {
            context = context.escopo.run(elseBody.subprogram);
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    commands["foreach"] = (string path, CommandContext context)
    {
        auto argName = context.pop().asString;
        auto argBody = cast(SubList)context.pop();

        /*
        Do NOT create a new scope for the
        body of foreach.
        */
        auto loopScope = context.escopo;

        uint yieldStep;
        if (argBody.subprogram.pipelines.length >= 8)
        {
            yieldStep = 0x01;
        }
        else if (argBody.subprogram.pipelines.length >= 4)
        {
            yieldStep = 0x03;
        }
        else
        {
            yieldStep = 0x07;
        }

        uint index = 0;
        foreach(item; context.stream)
        {
            loopScope[argName] = item;

            context = loopScope.run(argBody.subprogram);
            debug {stderr.writeln("foreach.subprogram.exitCode:", context.exitCode);}

            if (context.exitCode == ExitCode.Break)
            {
                break;
            }
            else if (context.exitCode == ExitCode.Continue)
            {
                continue;
            }
            else if (context.exitCode == ExitCode.ReturnSuccess)
            {
                // Return should always return
                // until a procedure or
                // a program is
                // stopped:
                return context;
            }

            if ((index++ & yieldStep) == yieldStep) context.yield();
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

    // ---------------------------------------------
    // "switch/case"
    commands["transform"] = (string path, CommandContext context)
    {
        class TransformRange : InfiniteRange
        {
            Range origin;
            SubList body;
            Process escopo;
            string varName;
            this(Range origin, string varName, SubList body, Process escopo)
            {
                this.origin = origin;
                this.varName = varName;
                this.body = body;
                this.escopo = escopo;
            }

            override bool empty()
            {
                return origin.empty;
            }
            override ListItem front()
            {
                auto originalFront = origin.front;
                escopo[varName] = originalFront;
                context = escopo.run(body.subprogram);
                if (context.size > 1)
                {
                    return new SimpleList(context.items);
                }
                else
                {
                    return context.pop();
                }
            }
            override void popFront()
            {
                origin.popFront();
            }
        }

        auto varName = context.pop().asString;
        auto body = context.pop();  // SubList

        auto newStream = new TransformRange(context.stream, varName, cast(SubList)body, context.escopo);
        context.exitCode = ExitCode.CommandSuccess;
        context.stream = newStream;
        return context;
    };
    commands["case"] = (string path, CommandContext context)
    {
        /*
        | case (>name "txt") { io.out "$name is a plain text file" }
        */
        class CaseRange : InfiniteRange
        {
            Range origin;
            SubList body;
            Process escopo;
            Items variables;
            ListItem currentFront;

            this(Range origin, Items variables, SubList body, Process escopo)
            {
                this.origin = origin;
                this.variables = variables;
                this.body = body;
                this.escopo = escopo;
            }

            override bool empty()
            {
                return origin.empty;
            }
            override ListItem front()
            {
                auto originalFront = origin.front;

                SimpleList list;
                if (originalFront.type == ObjectTypes.List)
                {
                    list = cast(SimpleList)originalFront;
                }
                else
                {
                    list = new SimpleList([originalFront]);
                }

                int matched = 0;
                foreach(index, item; list.items)
                {
                    // case (>name, "txt")
                    auto variable = variables[index];
                    if (variable.type == ObjectTypes.InputName)
                    {
                        // Assignment
                        escopo[variable.asString] = item;
                        matched++;
                    }
                    else
                    {
                        // Comparison
                        string value = variable.asString;
                        if (value == item.asString)
                        {
                            matched++;
                        }
                        else
                        {
                            break;
                        }
                    }
                }

                if (matched == variables.length)
                {
                    context = escopo.run(body.subprogram);
                    if (context.exitCode == ExitCode.Break)
                    {
                        // An empty SimpleList won't match with anything:
                        return new SimpleList([]);
                    }
                }
                return originalFront;
            }


            override void popFront()
            {
                origin.popFront();
            }
            override string toString()
            {
                return "CaseRange";
            }
        }

        auto argNames = cast(SimpleList)context.pop();
        auto variables = argNames.items;
        auto body = cast(SubList)context.pop();

        auto newStream = new CaseRange(context.stream, variables, body, context.escopo);
        context.stream = newStream;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Procedures-related
    commands["proc"] = (string path, CommandContext context)
    {
        // proc name (parameters) {body}

        string name = context.pop().asString;
        ListItem parameters = context.pop();
        ListItem body = context.pop();

        auto proc = new Procedure(
            name,
            parameters,
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

    // ---------------------------------------------
    // Scope manipulation
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
            throw new Exception("uplevel/command " ~ cmdName ~ ": Failure");
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Scheduler-related:
    commands["spawn"] = (string path, CommandContext context)
    {
        // set pid [spawn f $x]
        auto commandName = context.pop().asString;
        Items arguments = context.items;

        auto command = new Command(commandName, arguments);
        auto pipeline = new Pipeline([command]);
        auto subprogram = new SubProgram([pipeline]);
        auto process = new Process(context.escopo, subprogram);
        context.escopo.scheduler.add(process);

        context.push(new Pid(process));

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["send"] = (string path, CommandContext context)
    {
        // send $pid "any ListItem"
        auto pid = cast(Pid)context.pop();
        auto message = context.pop();

        pid.send(message);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["receive"] = (string path, CommandContext context)
    {
        // receive | foreach msg { ... }
        auto rootProcess = context.escopo.getRoot();
        debug {
            stderr.writeln(
                "process ", context.escopo.index,
                " has root ", rootProcess.index
            );
            stderr.writeln(
                "receiving in ", rootProcess.index,
                " : ", rootProcess.msgbox
            );
        }
        context.stream = new MsgboxRange(rootProcess);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["receive.wait"] = (string path, CommandContext context)
    {
        // receive.wait | foreach msg { ... }
        auto rootProcess = context.escopo.getRoot();
        debug {
            stderr.writeln(
                "process ", context.escopo.index,
                " has root ", rootProcess.index
            );
            stderr.writeln(
                "receiving in ", rootProcess.index,
                " : ", rootProcess.msgbox
            );
        }
        while(rootProcess.msgbox.empty)
        {
            // TODO: put rootProcess in Receive state
            rootProcess.scheduler.yield();
        }
        context.stream = new MsgboxRange(rootProcess);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Errors
    commands["error"] = (string path, CommandContext context)
    {
        string classe = "";
        int code = -1;
        // TODO: improve default message:
        string message = "An error ocurred";

        // "Full" call:
        // error message code class
        // error "Not Found" 404 http
        // error "segmentation fault" 11 os
        if (context.size > 0)
        {
            message = context.pop().asString;
        }
        if (context.size > 0)
        {
            code = context.pop().asInteger;
        }
        if (context.size > 0)
        {
            classe = context.pop().asString;
        }

        auto e = new Erro(
            context.escopo,
            message, code, classe
        );
        // Put it in the stack so the
        // handler can access it:
        context.push(e);

        // `error` is a sink!
        context.stream = null;

        // And, for a little change, we
        // return a Failure:
        context.exitCode = ExitCode.Failure;
        return context;
    };
}
