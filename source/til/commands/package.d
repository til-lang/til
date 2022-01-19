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


CommandHandlerMap commands;


SubProgram parse(string code)
{
    auto parser = new Parser(code);
    return parser.run();
}


// Commands:
static this()
{
    // ---------------------------------------------
    // Stack
    commands["push"] = (string path, CommandContext context)
    {
        // Do nothing, the value is already on stack.
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["pop"] = (string path, CommandContext context)
    {
        context.size++;
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["stack"] = (string path, CommandContext context)
    {
        context.size = cast(int)context.escopo.stackPointer;
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Modules / includes
    stringCommands["include"] = (string path, CommandContext context)
    {
        import std.stdio;
        import std.file;

        string filePath = context.pop!string();
        debug {stderr.writeln("include.filePath:", filePath);}

        auto program = parse(to!string(read(filePath)));
        if (program is null)
        {
            auto msg = "Program in " ~ filePath ~ " is invalid";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }

        context = context.escopo.run(program, context);

        if (context.exitCode != ExitCode.Failure)
        {
            context.exitCode = ExitCode.CommandSuccess;
        }
        return context;
    };
    nameCommands["import"] = (string path, CommandContext context)
    {
        // import std.io as x
        auto modulePath = context.pop!string();
        string newName = modulePath;

        // import std.io as x
        if (context.size == 2)
        {
            string asWord = context.pop!string();
            if (asWord != "as")
            {
                auto msg = "Invalid syntax for import";
                return context.error(msg, ErrorCode.InvalidArgument, "");
            }
            newName = context.pop!string();
        }

        if (!context.escopo.importModule(modulePath, newName))
        {
            auto msg = "Module not found: " ~ modulePath;
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    stringCommands["eval"] = (string path, CommandContext context)
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
    };

    // ---------------------------------------------
    // System commands
    commands["exec"] = (string path, CommandContext context)
    {
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

        context.push(new SystemProcess(command, inputStream));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Native types, nodes and conversion
    commands["typeof"] = (string path, CommandContext context)
    {
        if (context.size == 0)
        {
            auto msg = "`" ~ path ~ "` expects one argument";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        Item target = context.pop();
        context.push(new NameAtom(to!string(target.type).toLower()));

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    stringCommands["to.int"] = (string path, CommandContext context)
    {
        string target = context.pop!string();

        auto result = toLong(target);
        if (!result.success)
        {
            auto msg = "Could not convert to integer";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        context.push(result.value);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    stringCommands["to.float"] = (string path, CommandContext context)
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
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["to.string"] = (string path, CommandContext context)
    {
        if (context.size == 0)
        {
            auto msg = "`" ~ path ~ "` expects at least one argument";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        foreach(item; context.items.retro)
        {
            context.push(item.toString());
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Flow control
    simpleListCommands["if"] = (string path, CommandContext context)
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
    };
    nameCommands["foreach"] = (string path, CommandContext context)
    {
        /*
        range 5 | foreach x { ... }
        */
        if (context.size < 2)
        {
            auto msg = "`foreach` expects two arguments";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }

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
    commands["transform"] = (string path, CommandContext context)
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

            override CommandContext next(CommandContext context)
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

        if (context.size < 2)
        {
            auto msg = "`transform` expects two arguments";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
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
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Procedures-related
    nameCommands["proc"] = (string path, CommandContext context)
    {
        // proc name (parameters) {body}

        if (context.size != 3)
        {
            auto msg = "`proc` expects three arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        string name = context.pop!string();
        auto parameters = context.pop!SimpleList();
        auto body = context.pop!SubList();

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
        context.escopo.commands[name] = &closure;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["return"] = (string path, CommandContext context)
    {
        context.exitCode = ExitCode.ReturnSuccess;
        return context;
    };
    commands["skip"] = (string path, CommandContext context)
    {
        context.exitCode = ExitCode.Skip;
        return context;
    };
    commands["scope"] = (string path, CommandContext context)
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
            returnedContext = contextManager.runCommand(returnedContext, "close");
        }

        return returnedContext;
    };
    commands["with"] = (string path, CommandContext context)
    {
        // with cm [context_manager 1 2 3]
        string name = context.pop!string();
        auto contextManager = context.pop();

        auto process = context.escopo;

        process[name] = contextManager;
        context = contextManager.runCommand(context, "open");

        Items managers = process.internalVariables.require("cm", []);
        managers ~= contextManager;
        process.internalVariables["cm"] = managers;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["uplevel"] = (string path, CommandContext context)
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

        // 1- create a new Command
        auto command = new Command(cmdName, cmdArguments);

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
    };

    // ---------------------------------------------
    // Scheduler-related:
    nameCommands["spawn"] = (string path, CommandContext context)
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

        auto command = new Command(commandName, arguments);
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

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Printing:
    commands["print"] = (string path, CommandContext context)
    {
        while(context.size) stdout.write(context.pop!string());
        stdout.writeln();

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["print.error"] = (string path, CommandContext context)
    {
        while(context.size) stderr.write(context.pop!string());
        stderr.writeln();

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Piping
    commands["read"] = (string path, CommandContext context)
    {
        if (context.escopo.input is null)
        {
            auto msg = "`read.no_wait`: process input is null";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        // Probably a WaitingQueue:
        context.push(context.escopo.input);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["read.no_wait"] = (string path, CommandContext context)
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
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["write"] = (string path, CommandContext context)
    {
        if (context.size > 1)
        {
            auto msg = "`write` expects only one argument";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        Queue output = cast(Queue)context.escopo.output;
        output.push(context.pop());

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    // ---------------------------------------------
    // Time
    integerCommands["sleep"] = (string path, CommandContext context)
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
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    // ---------------------------------------------
    // Errors
    commands["error"] = (string path, CommandContext context)
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
    };

    // ---------------------------------------------
    // Debugging
    commands["assert"] = (string path, CommandContext context)
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

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    /*
    We can't really use module constructors inside
    til.nodes.* because then your're triggering
    cyclic dependencies all around, so we
    implement each builtin type methods here.
    */

    // ---------------------------------------------
    integerCommands["exit"] = (string path, CommandContext context)
    {
        string classe = "";
        string message = "Process was stopped";

        IntegerAtom code = cast(IntegerAtom)context.pop();

        if (context.size > 0)
        {
            message = context.pop!string();
        }

        return context.error(message, cast(int)code.value, classe);
    };

    // Names:
    commands["set"] = (string path, CommandContext context)
    {
        string[] names;

        if (context.size < 2)
        {
            auto msg = "`name.set` must receive at least two arguments.";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto key = context.pop!string();
        context.escopo[key] = context.items;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    nameCommands["unset"] = (string path, CommandContext context)
    {
        string[] names;

        auto firstArgument = context.pop();

        context.escopo.variables.remove(to!string(firstArgument));

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    simpleListCommands["math"] = (string path, CommandContext context)
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
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------
    // Sequences
    commands["zip"] = (string path, CommandContext context)
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
            override CommandContext next(CommandContext context)
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
    };

    // ---------------------------------------
    // Pids:
    pidCommands["send"] = (string path, CommandContext context)
    {
        if (context.size > 2)
        {
            auto msg = "`send` expects only two arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        Pid pid = cast(Pid)context.pop();
        auto value = context.pop();

        // Process input should be a Queue:
        Queue input = cast(Queue)pid.process.input;
        input.push(value);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
}
