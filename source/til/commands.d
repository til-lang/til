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
            auto msg = "`set` must receive at least two arguments.";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto firstArgument = context.pop();

        if (firstArgument.type == ObjectType.List)
        {
            auto secondArgument = context.pop();
            if (secondArgument.type != ObjectType.List)
            {
                auto msg = "You can only use destructuring `set` with two SimpleLists";
                return context.error(msg, ErrorCode.InvalidArgument, "");
            }

            auto l1 = cast(SimpleList)firstArgument;
            names = l1.items.map!(x => to!string(x)).array;

            Items values;

            auto l2 = cast(SimpleList)secondArgument;
            context = l2.forceEvaluate(context);
            auto l3 = context.pop!SimpleList;
            values = l3.items;

            if (values.length < names.length)
            {
                auto msg = "Insuficient number of items in the second list";
                return context.error(msg, ErrorCode.InvalidArgument, "");
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
            context.escopo[to!string(firstArgument)] = context.items;
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

        string filePath = context.pop!string;
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
        auto modulePath = context.pop!string;
        string newName = modulePath;

        // import std.io as x
        if (context.size == 2)
        {
            string asWord = context.pop!string;
            debug {stderr.writeln("asWord:", asWord);}
            if (asWord != "as")
            {
                auto msg = "Invalid syntax for import";
                return context.error(msg, ErrorCode.InvalidArgument, "");
            }
            newName = context.pop!string;
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
        context = ()
        {
            while(true)
            {
                auto conditions = context.pop!SimpleList;
                auto thenBody = context.pop!SubList;

                debug {stderr.writeln("context before conditions evaluation:", context);}
                conditions.forceEvaluate(context);
                // auto resultContext = boolean(context.next(1));
                context.run(&boolean, 1);

                auto isConditionTrue = context.pop!bool;
                debug {stderr.writeln("context AFTER conditions evaluation:", context);}

                debug {stderr.writeln(conditions, " is ", isConditionTrue);}

                // if (x == 0) {...}
                if (isConditionTrue)
                {
                    return context.escopo.run(thenBody.subprogram);
                }
                // no else:
                else if (context.size == 0)
                {
                    context.exitCode = ExitCode.CommandSuccess;
                    return context;
                }
                // else {...}
                // else if {...}
                else
                {
                    auto elseWord = context.pop!string;
                    if (elseWord != "else")
                    {
                        auto msg = "Invalid format for if/then/else clause:"
                                   ~ " elseWord found was " ~ elseWord;
                        return context.error(msg, ErrorCode.InvalidSyntax, "");
                    }

                    debug {stderr.writeln("context:", context);}

                    // If only one part is left, it's for sure the last "else":
                    if (context.size == 1)
                    {
                        auto elseBody = context.pop!SubList;
                        return context.escopo.run(elseBody.subprogram);
                    }
                    else
                    {
                        auto ifWord = context.pop!string;
                        if (ifWord != "if")
                        {
                            auto msg = "Invalid format for if/then/else clause"
                                       ~ " ifWord found was " ~ ifWord;
                            return context.error(msg, ErrorCode.InvalidSyntax, "");
                        }
                        // The next item is an "if", so we can
                        // simply return to the beginning:
                        continue;
                    }
                }
            }
        }();
        if (context.exitCode == ExitCode.Proceed)
        {
            context.exitCode = ExitCode.CommandSuccess;
        }
        return context;
    };

    commands["foreach"] = (string path, CommandContext context)
    {
        auto argName = context.pop!string;
        auto argBody = context.pop!SubList;

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
        debug {stderr.writeln("foreach context.stream: ", context.stream);}
        foreach(item; context.stream)
        {
            debug {stderr.writeln("foreach item: ", item);}
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

        auto varName = context.pop!string;
        auto body = context.pop!SubList;

        auto newStream = new TransformRange(context.stream, varName, body, context.escopo);
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
                if (originalFront.type == ObjectType.List)
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
                    if (variable.type == ObjectType.InputName)
                    {
                        // Assignment
                        escopo[to!string(variable)] = item;
                        matched++;
                    }
                    else
                    {
                        // Comparison
                        string value = to!string(variable);
                        if (value == to!string(item))
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

        auto argNames = context.pop!SimpleList;
        auto variables = argNames.items;
        auto body = context.pop!SubList;

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

        string name = context.pop!(string);
        auto parameters = context.pop!SimpleList;
        auto body = context.pop!SubList;

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
            auto msg = "No upper level to access.";
            return context.error(msg, ErrorCode.SemanticError, "");
        }

        /*
        It is very important to do this `pop` **before**
        copying the context.size into
        newContext.size!
        You see,
        uplevel set x 1 2 3  ← this command has 5 arguments
           -    set x 1 2 3  ← and this one has 4
        */
        auto cmdName = context.pop!(string);

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
        auto returnedContext = command.run(newContext);

        if (returnedContext.exitCode != ExitCode.Failure)
        {
            context.exitCode = ExitCode.CommandSuccess;
        }
        return context;
    };

    // ---------------------------------------------
    // Scheduler-related:
    commands["spawn"] = (string path, CommandContext context)
    {
        // set pid [spawn f $x]
        auto commandName = context.pop!string;
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
        auto pid = context.pop!Pid;
        auto message = context.pop();

        pid.send(message);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["receive"] = (string path, CommandContext context)
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
            message = context.pop!string;
        }
        if (context.size > 0)
        {
            code = context.pop!int;
        }
        if (context.size > 0)
        {
            classe = context.pop!string;
        }

        return context.error(message, code, classe);
    };
}
