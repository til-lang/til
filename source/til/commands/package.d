module til.commands;

import std.algorithm.iteration : joiner, map;
import std.algorithm.sorting : sort;
import std.array;
import std.conv : to, ConvException;
import std.file : read;
import std.stdio;
import std.string : indexOf, toLower;

import til.grammar;

import til.conv;
import til.exceptions;
import til.exec;
import til.math;
import til.modules;
import til.nodes;
import til.procedures;
import til.sharedlibs;


// Global variable:
CommandsMap commands;


// Commands:
static this()
{
    // ---------------------------------------------
    // Stack
    commands["push"] = new Command((string path, Context context)
    {
        // Do nothing, the value is already on stack.
        return context;
    });
    commands["pop"] = new Command((string path, Context context)
    {
        if (context.escopo.stackPointer == 0)
        {
            auto msg = "Stack is empty";
            return context.error(msg, ErrorCode.SemanticError, "");
        }
        context.size++;
        return context;
    });
    commands["stack"] = new Command((string path, Context context)
    {
        context.size = cast(int)context.escopo.stackPointer;
        return context;
    });

    // ---------------------------------------------
    // Modules / includes
    stringCommands["include"] = new Command((string path, Context context)
    {
        import std.stdio;
        import std.file;

        string filePath = context.pop!string();
        debug {stderr.writeln("include.filePath:", filePath);}

        auto parser = new Parser(to!string(read(filePath)));
        auto program = parser.run();
        if (program is null)
        {
            auto msg = "Program in " ~ filePath ~ " is invalid";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }

        context = context.escopo.run(program, context);

        // XXX: maybe this is wrong.
        // What if I want to include a code that returns Continue?
        if (context.exitCode != ExitCode.Failure)
        {
            context.exitCode = ExitCode.CommandSuccess;
        }
        return context;
    });
    nameCommands["import"] = new Command((string path, Context context)
    {
        // import std.io as x
        auto modulePath = context.pop!string();
        string newName = modulePath;

        // import std.io x
        if (context.size == 1)
        {
            newName = context.pop!string();
        }

        if (!context.escopo.importModule(modulePath, newName))
        {
            auto msg = "Module not found: " ~ modulePath;
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        return context;
    });

    // ---------------------------------------------
    stringCommands["eval"] = new Command((string path, Context context)
    {
        import til.grammar;

        auto code = context.pop!string();

        auto parser = new Parser(code);
        SubProgram subprogram = parser.run();

        context = context.escopo.run(subprogram);
        if (context.exitCode == ExitCode.Proceed)
        {
            context.exitCode = ExitCode.CommandSuccess;
        }
        return context;
    });

    // ---------------------------------------------
    // System commands
    commands["exec"] = new Command((string path, Context context)
    {
        import std.process : ProcessException;

        string[] command;
        ListItem inputStream;

        if (context.hasInput)
        {
            command = context.pop(context.size - 1).map!(x => to!string(x)).array;
            inputStream = context.pop();
        }
        else
        {
            command = context.items.map!(x => to!string(x)).array;
        }

        try
        {
            context.push(new SystemProcess(command, inputStream));
        }
        catch (ProcessException ex)
        {
            return context.error(ex.msg, ErrorCode.Unknown, "");
        }
        return context;
    });

    // ---------------------------------------------
    // Native types, nodes and conversion
    commands["typeof"] = new Command((string path, Context context)
    {
        Item target = context.pop();
        context.push(new NameAtom(to!string(target.type).toLower()));

        return context;
    });
    commands["type.name"] = new Command((string path, Context context)
    {
        Item target = context.pop();
        context.push(new NameAtom(to!string(target.typeName).toLower()));

        return context;
    });
    stringCommands["to.int"] = new Command((string path, Context context)
    {
        string target = context.pop!string();

        auto result = toLong(target);
        if (!result.success)
        {
            auto msg = "Could not convert to integer";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        context.push(result.value);
        return context;
    });
    stringCommands["to.float"] = new Command((string path, Context context)
    {
        string target = context.pop!string();

        if (target.length == 0)
        {
            target = "0.0";
        }

        float result;
        try
        {
            result = to!float(target);
        }
        catch (ConvException)
        {
            auto msg = "Could not convert to float";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        context.push(result);
        return context;
    });
    commands["to.string"] = new Command((string path, Context context)
    {
        foreach(item; context.items.retro)
        {
            context.push(item.toString());
        }

        return context;
    });
    commands["to.bool"] = new Command((string path, Context context)
    {
        auto target = context.pop();
        return context.push(target.toBool());
    });
    commands["to.int"] = new Command((string path, Context context)
    {
        auto target = context.pop();
        return context.push(target.toInt());
    });
    commands["to.float"] = new Command((string path, Context context)
    {
        auto target = context.pop();
        return context.push(target.toFloat());
    });


    // ---------------------------------------------
    // Flow control
    simpleListCommands["if"] = new Command((string path, Context context)
    {
        while(true)
        {
            // NOT popping the conditions: `math` will take care of that, already.
            auto mathContext = math(context.next(1));
            auto isConditionTrue = mathContext.pop!bool();

            auto thenBody = context.pop!SubList();

            if (isConditionTrue)
            {
                // Get rid of eventual "else":
                context.items();
                // Run body:
                context = context.escopo.run(thenBody.subprogram);
                break;
            }
            // no else:
            else if (context.size == 0)
            {
                context.exitCode = ExitCode.CommandSuccess;
                break;
            }
            // else {...}
            // else if {...}
            else
            {
                auto elseWord = context.pop!string();
                if (elseWord != "else")
                {
                    auto msg = "Invalid format for if/then/else clause:"
                               ~ " elseWord found was " ~ elseWord  ~ ".";
                    return context.error(msg, ErrorCode.InvalidSyntax, "");
                }

                // If only one part is left, it's for sure the last "else":
                if (context.size == 1)
                {
                    auto elseBody = context.pop!SubList();
                    context = context.escopo.run(elseBody.subprogram);
                    break;
                }
                else
                {
                    auto ifWord = context.pop!string();
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

        if (context.exitCode == ExitCode.Proceed)
        {
            context.exitCode = ExitCode.CommandSuccess;
        }
        return context;
    });
    nameCommands["foreach"] = new Command((string path, Context context)
    {
        /*
        range 5 | foreach x { ... }
        */
        auto argName = context.pop!string();
        auto argBody = context.pop!SubList();

        /*
        Do NOT create a new scope for the
        body of foreach.
        */
        auto loopScope = context.escopo;

        uint yieldStep = 0x07;

        uint index = 0;
        auto target = context.pop();

        // Remember: `context` is going to change a lot from now on.
        auto nextContext = context;
forLoop:
        while (true)
        {
            nextContext = target.next(context.next());
            switch (nextContext.exitCode)
            {
                case ExitCode.Break:
                    break forLoop;
                case ExitCode.Failure:
                    return nextContext;
                case ExitCode.Skip:
                    continue;
                case ExitCode.Continue:
                    break;
                default:
                    return nextContext;
            }

            loopScope[argName] = nextContext.items;

            context = loopScope.run(argBody.subprogram);

            if (context.exitCode == ExitCode.Break)
            {
                break;
            }
            else if (context.exitCode == ExitCode.ReturnSuccess)
            {
                // Return should always return
                // until a procedure or
                // a program is
                // stopped:
                return context;
            }

            if ((index++ & yieldStep) == yieldStep)
            {
                context.yield();
            }
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    commands["transform"] = new Command((string path, Context context)
    {
        class Transformer : Item
        {
            Item target;
            SubList body;
            Process escopo;
            string varName;
            bool empty;

            this(Item target, string varName, SubList body, Process escopo)
            {
                this.target = target;
                this.varName = varName;
                this.body = body;
                this.escopo = escopo;
            }

            override string toString()
            {
                return "transform";
            }

            override Context next(Context context)
            {
                auto targetContext = this.target.next(context);
                switch (targetContext.exitCode)
                {
                    case ExitCode.Break:
                    case ExitCode.Failure:
                    case ExitCode.Skip:
                        return targetContext;
                    case ExitCode.Continue:
                        break;
                    default:
                        throw new Exception(
                            to!string(this.target)
                            ~ ".next returned "
                            ~ to!string(targetContext.exitCode)
                        );
                }

                escopo[varName] = targetContext.items;

                context = escopo.run(body.subprogram);

                switch(context.exitCode)
                {
                    case ExitCode.ReturnSuccess:
                    case ExitCode.CommandSuccess:
                    case ExitCode.Proceed:
                        context.exitCode = ExitCode.Continue;
                        break;

                    default:
                        break;
                }
                return context;
            }
        }

        auto varName = context.pop!string();
        auto body = context.pop!SubList();

        if (context.size == 0)
        {
            auto msg = "no target to transform";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        auto target = context.pop();

        auto iterator = new Transformer(
            target, varName, body, context.escopo
        );
        context.push(iterator);
        return context;
    });
    commands["break"] = new Command((string path, Context context)
    {
        context.exitCode = ExitCode.Break;
        return context;
    });
    commands["continue"] = new Command((string path, Context context)
    {
        context.exitCode = ExitCode.Continue;
        return context;
    });
    commands["skip"] = new Command((string path, Context context)
    {
        context.exitCode = ExitCode.Skip;
        return context;
    });

    // ---------------------------------------------
    // Procedures-related
    nameCommands["alias"] = new Command((string path, Context context)
    {
        string origin = context.pop!string();
        string target = context.pop!string();

        auto command = context.escopo.getCommand(origin);
        if (command is null)
        {
            auto msg = "Command `" ~ origin ~ "` not found";
            return context.error(msg, ErrorCode.CommandNotFound, "");
        }
        commands[target] = command;
        return context;
    });
    nameCommands["proc"] = new Command((string path, Context context)
    {
        // proc name (parameters) {body}
        string name = context.pop!string();

        auto parameters = context.pop!SimpleList();
        auto body = context.pop!SubList();

        auto proc = new Procedure(
            name,
            parameters,
            body
        );

        context.escopo.commands[name] = proc;

        return context;
    });
    commands["return"] = new Command((string path, Context context)
    {
        context.exitCode = ExitCode.ReturnSuccess;
        return context;
    });
    commands["scope"] = new Command((string path, Context context)
    {
        string name = context.pop!string();
        SubList body = context.pop!SubList();

        auto process = new Process(context.escopo);
        process.description = name;
        process.variables = context.escopo.variables;

        auto returnedContext = process.run(body.subprogram, context.next(process, 0));

        if (returnedContext.exitCode == ExitCode.Proceed)
        {
            returnedContext.exitCode = ExitCode.CommandSuccess;
        }

        Items managers = process.internalVariables.require("cm", []);
        foreach (contextManager; managers)
        {
            returnedContext = contextManager.runCommand("close", returnedContext);
        }

        return returnedContext;
    });
    commands["with"] = new Command((string path, Context context)
    {
        // with cm [context_manager 1 2 3]
        string name = context.pop!string();
        auto contextManager = context.pop();

        auto process = context.escopo;

        process[name] = contextManager;
        context = contextManager.runCommand("open", context);

        Items managers = process.internalVariables.require("cm", []);
        managers ~= contextManager;
        process.internalVariables["cm"] = managers;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    commands["uplevel"] = new Command((string path, Context context)
    {
        /*
        uplevel set parent_value x
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

        // 1- create a new CommandCall
        auto command = new CommandCall(cmdName, cmdArguments);

        // 2- create a new context, with the parent
        //    scope as the context.escopo
        auto newContext = context.next();
        newContext.escopo = parentScope;
        newContext.size = context.size;

        // 3- run the command
        auto returnedContext = command.run(newContext);

        if (returnedContext.exitCode != ExitCode.Failure)
        {
            context.exitCode = ExitCode.CommandSuccess;
        }
        return context;
    });

    // ---------------------------------------------
    // Scheduler-related:
    nameCommands["spawn"] = new Command((string path, Context context)
    {
        // set pid [spawn f $x]
        // spawn f | read | foreach x { ... }
        // range 5 | spawn g | foreach y { ... }

        auto commandName = context.pop!string();
        Items arguments = context.items;
        ListItem input = null;
        if (context.hasInput)
        {
            input = arguments[$-1];
            arguments.popBack();
        }

        auto command = new CommandCall(commandName, arguments);
        auto pipeline = new Pipeline([command]);
        auto subprogram = new SubProgram([pipeline]);
        auto process = new Process(context.escopo, subprogram);
        process.description = commandName;

        // Piping:
        if (input !is null)
        {
            // receive $queue | spawn some_procedure
            process.input = input;
        }
        else
        {
            process.input = new WaitingQueue(64);
        }
        process.output = new WaitingQueue(64);

        auto pid = context.escopo.scheduler.add(process);
        context.push(pid);

        // Give some time for the new process to start:
        context.yield();

        return context;
    });

    // ---------------------------------------------
    // Printing:
    commands["print"] = new Command((string path, Context context)
    {
        while(context.size) stdout.write(context.pop!string());
        stdout.writeln();
        return context;
    });
    commands["print.error"] = new Command((string path, Context context)
    {
        while(context.size) stderr.write(context.pop!string());
        stderr.writeln();
        return context;
    });

    // ---------------------------------------------
    // Piping
    commands["read"] = new Command((string path, Context context)
    {
        if (context.escopo.input is null)
        {
            auto msg = "`read.no_wait`: process input is null";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        // Probably a WaitingQueue:
        context.push(context.escopo.input);
        return context;
    });
    commands["read.no_wait"] = new Command((string path, Context context)
    {
        if (context.escopo.input is null)
        {
            auto msg = "`read.no_wait`: process input is null";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        // Probably a WaitingQueue, let's change its behavior to
        // a regular Queue:
        auto q = cast(WaitingQueue)context.escopo.input;
        context.push(new Queue(q));
        return context;
    });
    commands["write"] = new Command((string path, Context context)
    {
        if (context.size > 1)
        {
            auto msg = "`write` expects only one argument";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        Queue output = cast(Queue)context.escopo.output;
        output.push(context.pop());
        return context;
    });
    // ---------------------------------------------
    // Time
    integerCommands["sleep"] = new Command((string path, Context context)
    {
        import std.datetime.stopwatch;

        auto ms = context.pop!long();

        auto sw = StopWatch(AutoStart.yes);
        while(true)
        {
            auto passed = sw.peek.total!"msecs";
            if (passed >= ms)
            {
                break;
            }
            else
            {
                context.yield();
            }
        }
        return context;
    });
    // ---------------------------------------------
    // Errors
    commands["error"] = new Command((string path, Context context)
    {
        string classe = "";
        int code = -1;
        string message = "An error ocurred";

        // "Full" call:
        // error message code class
        // error "Not Found" 404 http
        // error "segmentation fault" 11 os
        if (context.size > 0)
        {
            message = context.pop!string();
        }
        if (context.size > 0)
        {
            code = cast(int)context.pop!long();
        }
        if (context.size > 0)
        {
            classe = context.pop!string();
        }

        return context.error(message, code, classe);
    });

    // ---------------------------------------------
    // Debugging
    commands["assert"] = new Command((string path, Context context)
    {
        while (context.size)
        {
            auto target = context.peek();
            auto mathContext = math(context.next(1));
            auto isTrue = mathContext.pop!bool();
            if (!isTrue)
            {
                auto msg = "assertion error: " ~ target.toString();
                return context.error(msg, ErrorCode.Assertion, "");
            }
        }

        return context;
    });

    /*
    We can't really use module constructors inside
    til.nodes.* because then your're triggering
    cyclic dependencies all around, so we
    implement each builtin type methods here.
    */

    // ---------------------------------------------
    integerCommands["exit"] = new Command((string path, Context context)
    {
        string classe = "";
        string message = "Process was stopped";

        IntegerAtom code = cast(IntegerAtom)context.pop();

        if (context.size > 0)
        {
            message = context.pop!string();
        }

        return context.error(message, cast(int)code.value, classe);
    });

    // Names:
    commands["set"] = new Command((string path, Context context)
    {
        if (context.size < 2)
        {
            auto msg = "`name.set` must receive at least two arguments.";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto key = context.pop!string();
        context.escopo[key] = context.items;

        return context;
    });
    nameCommands["unset"] = new Command((string path, Context context)
    {
        auto firstArgument = context.pop();
        context.escopo.variables.remove(to!string(firstArgument));
        return context;
    });

    simpleListCommands["math"] = new Command((string path, Context context)
    {
        // NOT popping the SimpleList: `math` will handle that, already:
        context = math(context.next(1));
        if (context.size != 1)
        {
            auto msg = "math.run: error. Should return 1 item.\n"
                       ~ to!string(context.escopo)
                       ~ " returned " ~ to!string(context.size);
            return context.error(msg, ErrorCode.InternalError, "til.internal");
        }

        // NOT pushing the result: `math` already did that.
        return context;
    });

    // ---------------------------------------
    // Sequences
    commands["zip"] = new Command((string path, Context context)
    {
        class Zipper : Item
        {
            Items items;
            this(Items items)
            {
                this.items = items;
            }
            override string toString()
            {
                return "Zipper";
            }
            override Context next(Context context)
            {
                Items iterationItems;
                foreach (item; items.retro)
                {
zipIteration:
                    while (true)
                    {
                        auto itemContext = item.next(context.next());
                        switch (itemContext.exitCode)
                        {
                            case ExitCode.Skip:
                                continue;
                            case ExitCode.Break:
                            case ExitCode.Failure:
                                return itemContext;
                            default:
                                iterationItems ~= itemContext.items;
                                break zipIteration;
                        }
                    }
                }

                context.push(iterationItems);
                context.exitCode = ExitCode.Continue;
                return context;
            }
        }

        context.push(new Zipper(context.items));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });

    // ---------------------------------------
    // Information about escopo/process
    commands["cmds"] = new Command((string path, Context context)
    {
        auto process = context.escopo;
        auto cmdsList = new SimpleList([]);

        do
        {
            auto list = new SimpleList([]);
            foreach (cmdName; process.commands.byKey)
            {
                list.items ~= new String(cmdName);
            }
            cmdsList.items ~= list;

            process = process.parent;
        }
        while (process !is null);

        return context.push(cmdsList);
    });
    commands["vars"] = new Command((string path, Context context)
    {
        auto process = context.escopo;
        auto varsList = new SimpleList([]);

        do
        {
            auto list = new SimpleList([]);
            foreach (varName; process.variables.byKey)
            {
                list.items ~= new String(varName);
            }
            varsList.items ~= list;

            process = process.parent;
        }
        while (process !is null);

        return context.push(varsList);
    });
}
