module til.commands;

import std.algorithm.iteration : joiner, map;
import std.algorithm.searching : canFind;
import std.algorithm.sorting : sort;
import std.array;
import std.conv : to, ConvException;
import std.file : read;
import std.stdio;

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
    // Strings commands
    stringCommands["eval"] = (string path, CommandContext context)
    {
        import til.grammar;

        auto code = context.pop!string();

        debug {stderr.writeln("eval.code:", code);}
        auto parser = new Parser(code);
        SubProgram subprogram = parser.run();
        debug {stderr.writeln("eval.subprogram:", subprogram);}

        context = context.escopo.run(subprogram);
        if (context.exitCode == ExitCode.Proceed)
        {
            context.exitCode = ExitCode.CommandSuccess;
        }
        return context;
    };
    stringCommands["length"] = (string path, CommandContext context)
    {
        auto s = context.pop!String();
        return context.push(s.repr.length);
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

    // ---------------------------------------------
    // Flow control
    simpleListCommands["if"] = (string path, CommandContext context)
    {
        while(true)
        {
            // NOT popping the conditions: `math` will take care of that, already.
            auto mathContext = math(context.next(1));
            auto isConditionTrue = mathContext.pop!bool();
            debug {stderr.writeln(" isConditionTrue:", isConditionTrue);}
            debug {stderr.writeln(" context.size:", context.size);}
            debug {stderr.writeln(" escopo.stackPointer:", context.escopo.stackPointer);}

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
                    debug {
                        foreach (item; context.items)
                        {
                            stderr.writeln(" elseWord.item:", item);
                        }
                    }
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
        debug {
            stderr.writeln("foreach context.size:", context.size);
            stderr.writeln(" > ", context.escopo.peek());
        }

        if (context.size < 2)
        {
            auto msg = "`foreach` expects two arguments";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }

        auto argName = context.pop!string();
        debug {stderr.writeln(" > ", context.escopo.peek());}
        auto argBody = context.pop!SubList();
        debug {stderr.writeln(" > ", context.escopo.peek());}

        /*
        Do NOT create a new scope for the
        body of foreach.
        */
        auto loopScope = context.escopo;

        uint yieldStep = 0x07;

        uint index = 0;
        auto target = context.pop();
        debug {stderr.writeln("foreach target: ", target);}

        auto nextContext = context;
        // Remember: `context` is going to change a lot from now on.
        do
        {
            nextContext = target.next(context);
            if (nextContext.exitCode == ExitCode.Break)
            {
                break;
            }
            debug {stderr.writeln("foreach.nextContext.exitCode:", nextContext.exitCode);}

            loopScope[argName] = nextContext.items;

            context = loopScope.run(argBody.subprogram);
            debug {stderr.writeln("foreach.subprogram.exitCode:", context.exitCode);}

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
                debug {stderr.writeln("foreach yieldStep");}
                context.yield();
            }
        }
        while(nextContext.exitCode == ExitCode.Continue);

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
                if (targetContext.exitCode == ExitCode.Break)
                {
                    return targetContext;
                }
                else if (targetContext.exitCode != ExitCode.Continue)
                {
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

    // ---------------------------------------------
    // Scope manipulation
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

        // Piping:
        if (input !is null)
        {
            // receive $queue | spawn some_procedure
            debug {stderr.writeln("New process input is: ", input);}
            process.input = input;
        }
        else
        {
            debug {stderr.writeln("New process input is a generic Queue");}
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
    commands["sleep"] = (string path, CommandContext context)
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

    // ---------------------------------------
    // Dict:
    commands["dict"] = (string path, CommandContext context)
    {
        auto dict = new Dict();

        foreach(argument; context.items)
        {
            SimpleList l = cast(SimpleList)argument;
            context = l.forceEvaluate(context);
            l = cast(SimpleList)context.pop();

            ListItem value = l.items.back;
            l.items.popBack();
            string key = to!string(l.items.map!(x => to!string(x)).join("."));
            dict[key] = value;
        }
        context.push(dict);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------
    // Queue:
    commands["queue"] = (string path, CommandContext context)
    {
        ulong size = 64;
        if (context.size > 0)
        {
            size = context.pop!ulong();
        }
        auto queue = new Queue(size);

        context.push(queue);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    /*
    We can't really use module constructors inside
    til.nodes.* because then your're triggering
    cyclic dependencies all around, so we
    implement each builtin type here.

    "Built-in type" == anything that the parser is able to instantiate
    */

    // ---------------------------------------------
    // Atoms:
    // (Please notice: `incr` and `decr` do NOT conform to Tcl "equivalents"!)
    integerCommands["incr"] = (string path, CommandContext context)
    {
        if (context.size != 1)
        {
            auto msg = "`incr` expects one argument";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto integer = context.pop!IntegerAtom();

        if (integer.value > ++integer.value)
        {
            auto msg = "integer overflow";
            return context.error(msg, ErrorCode.Overflow, "");
        }
        context.push(integer);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    integerCommands["decr"] = (string path, CommandContext context)
    {
        if (context.size != 1)
        {
            auto msg = "`decr` expects one argument";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto integer = context.pop!IntegerAtom();
        if (integer.value < --integer.value)
        {
            auto msg = "integer underflow";
            return context.error(msg, ErrorCode.Underflow, "");
        }
        context.push(integer);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    integerCommands["range"] = (string path, CommandContext context)
    {
        /*
           range 10       # [zero, 10]
           range 10 20    # [10, 20]
           range 10 14 2  # 10 12 14
        */
        auto start = context.pop!long();
        long limit = 0;
        if (context.size)
        {
            limit = context.pop!long();
        }
        else
        {
            // zero to...
            limit = start;
            start = 0;
        }
        if (limit <= start)
        {
            auto msg = "Invalid range";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        long step = 1;
        if (context.size)
        {
            step = context.pop!long();
        }

        class IntegerRange : Item
        {
            long start = 0;
            long limit = 0;
            long step = 1;
            long current = 0;

            this(long limit)
            {
                this.limit = limit;
            }
            this(long start, long limit)
            {
                this(limit);
                this.current = start;
                this.start = start;
            }
            this(long start, long limit, long step)
            {
                this(start, limit);
                this.step = step;
            }

            override string toString()
            {
                return
                    "range("
                    ~ to!string(start)
                    ~ ","
                    ~ to!string(limit)
                    ~ ")";
            }

            override CommandContext next(CommandContext context)
            {
                long value = current;
                if (value > limit)
                {
                    context.exitCode = ExitCode.Break;
                }
                else
                {
                    context.push(value);
                    context.exitCode = ExitCode.Continue;
                }
                current += step;
                return context;
            }
        }

        debug {stderr.writeln("range: ", start, " ", limit, " ", step);}
        auto range = new IntegerRange(start, limit, step);
        context.push(range);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
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
    integerCommands["operate"] = (string path, CommandContext context)
    {
        IntegerAtom t2 = context.pop!IntegerAtom();
        Item operator = context.pop();
        Item lhs = context.pop();

        string op = to!string(operator);

        debug {
            stderr.writeln(
                "IntegerAtom.operate:", lhs,
                " (", lhs.type, ")",
                " ", op,
                " ", t2
            );
        }

        if (lhs.type != ObjectType.Integer)
        {
            context.push(t2);
            context.push(operator);
            return lhs.reverseOperate(context);
        }

        auto t1 = cast(IntegerAtom)lhs;
        final switch(op)
        {
            // Logic:
            case "==":
                context.push(t1.value == t2.value);
                break;
            case "!=":
                context.push(t1.value != t2.value);
                break;
            case ">":
                context.push(t1.value > t2.value);
                break;
            case ">=":
                context.push(t1.value >= t2.value);
                break;
            case "<":
                context.push(t1.value < t2.value);
                break;
            case "<=":
                context.push(t1.value <= t2.value);
                break;

            // Math:
            case "+":
                context.push(t1.value + t2.value);
                break;
            case "-":
                context.push(t1.value - t2.value);
                break;
            case "*":
                context.push(t1.value * t2.value);
                break;
            case "/":
                context.push(t1.value / t2.value);
                break;
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
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
    nameCommands["operate"] = (string path, CommandContext context)
    {
        Item rhs = context.pop();
        Item operator = context.pop();
        Item lhs = context.pop();

        switch(to!string(operator))
        {
            case "==":
                context.push(to!string(lhs) == to!string(rhs));
                break;
            case "!=":
                context.push(to!string(lhs) != to!string(rhs));
                break;
            default:
                context.push(rhs);
                context.push(operator);
                return lhs.reverseOperate(context);
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------
    // SimpleLists:
    commands["list"] = (string path, CommandContext context)
    {
        /*
        set l [list 1 2 3 4]
        # l = (1 2 3 4)
        */
        context.exitCode = ExitCode.CommandSuccess;
        return context.push(new SimpleList(context.items));
    };
    simpleListCommands["set"] = (string path, CommandContext context)
    {
        string[] names;

        if (context.size != 2)
        {
            auto msg = "`list.set` must receive two arguments.";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto l1 = context.pop!SimpleList();
        auto l2 = context.pop!SimpleList();

        if (l2.type != ObjectType.SimpleList)
        {
            auto msg = "You can only use `list.set` with two SimpleLists";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        names = l1.items.map!(x => to!string(x)).array;

        Items values;
        context = l2.forceEvaluate(context);
        values = l2.items;

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

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    simpleListCommands["range"] = (string path, CommandContext context)
    {
        /*
        range (1 2 3 4 5)
        */
        class ItemsRange : Item
        {
            Items list;
            int currentIndex = 0;
            ulong _length;

            this(Items list)
            {
                this.list = list;
                this._length = list.length;
            }
            override string toString()
            {
                return "ItemsRange";
            }
            override CommandContext next(CommandContext context)
            {
                if (this.currentIndex >= this._length)
                {
                    context.exitCode = ExitCode.Break;
                }
                else
                {
                    context.push(this.list[this.currentIndex++]);
                    context.exitCode = ExitCode.Continue;
                }
                return context;
            }
        }

        SimpleList list = context.pop!SimpleList();
        context.push(new ItemsRange(list.items));
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
    // SimpleList commands:
    simpleListCommands["eval"] = (string path, CommandContext context)
    {
        auto list = context.pop();

        // Force evaluation:
        auto newContext = list.evaluate(context, true);

        newContext.exitCode = ExitCode.CommandSuccess;
        return newContext;
    };
    simpleListCommands["expand"] = (string path, CommandContext context)
    {
        SimpleList list = context.pop!SimpleList();

        foreach (item; list.items.retro)
        {
            context.push(item);
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    simpleListCommands["push"] = (string path, CommandContext context)
    {
        SimpleList list = context.pop!SimpleList();

        Items items = context.items;
        list.items ~= items;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    simpleListCommands["pop"] = (string path, CommandContext context)
    {
        SimpleList list = context.pop!SimpleList();

        if (list.items.length == 0)
        {
            auto msg = "Cannot pop: the list is empty";
            return context.error(msg, ErrorCode.Empty, "");
        }

        auto lastItem = list.items[$-1];
        context.push(lastItem);
        list.items.popBack;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    simpleListCommands["sort"] = (string path, CommandContext context)
    {
        SimpleList list = context.pop!SimpleList();

        class Comparator
        {
            ListItem item;
            CommandContext context;
            this(CommandContext context, ListItem item)
            {
                this.context = context;
                this.item = item;
            }

            override int opCmp(Object o)
            {
                Comparator other = cast(Comparator)o;

                context.push(other.item);
                context.push("<");
                context = item.operate(context);
                auto result = cast(BooleanAtom)context.pop();

                if (result.value)
                {
                    return -1;
                }
                else
                {
                    return 0;
                }
            }
        }

        Comparator[] comparators = list.items.map!(x => new Comparator(context, x)).array;
        Items sorted = comparators.sort.map!(x => x.item).array;
        context.push(new SimpleList(sorted));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    simpleListCommands["reverse"] = (string path, CommandContext context)
    {
        SimpleList list = context.pop!SimpleList();
        Items reversed = list.items.retro.array;
        context.push(new SimpleList(reversed));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    simpleListCommands["contains"] = (string path, CommandContext context)
    {
        if (context.size != 2)
        {
            auto msg = "`send` expects two arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        SimpleList list = context.pop!SimpleList();
        ListItem item = context.pop();

        context.exitCode = ExitCode.CommandSuccess;
        return context.push(
            list.items
                .map!(x => to!string(x))
                .canFind(to!string(item))
        );
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

    // ---------------------------------------
    // Dicts:
    dictCommands["set"] = (string path, CommandContext context)
    {
        auto dict = context.pop!Dict();

        foreach(argument; context.items)
        {
            SimpleList l = cast(SimpleList)argument;
            context = l.forceEvaluate(context);
            l = cast(SimpleList)context.pop();

            ListItem value = l.items.back;
            l.items.popBack();
            string key = to!string(l.items.map!(x => to!string(x)).join("."));
            dict[key] = value;
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    dictCommands["unset"] = (string path, CommandContext context)
    {
        auto dict = context.pop!Dict();

        foreach (argument; context.items)
        {
            string key;
            if (argument.type == ObjectType.SimpleList)
            {
                auto list = cast(SimpleList)argument;
                auto keysContext = list.evaluate(context.next());
                auto evaluatedList = cast(SimpleList)keysContext.pop();
                auto parts = evaluatedList.items;

                key = to!string(
                    parts.map!(x => to!string(x)).join(".")
                );
            }
            else
            {
                key = to!string(argument);
            }
            dict.values.remove(key);
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------
    // Queues:
    queueCommands["push"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue();

        foreach(argument; context.items)
        {
            while (queue.isFull)
            {
                context.yield();
            }
            queue.push(argument);
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["push.no_wait"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue();

        foreach(argument; context.items)
        {
            if (queue.isFull)
            {
                auto msg = "queue is full";
                return context.error(msg, ErrorCode.Full, "");
            }
            queue.push(argument);
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["pop"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue();
        long howMany = 1;
        if (context.size > 0)
        {
            auto integer = context.pop!IntegerAtom();
            howMany = integer.value;
        }
        foreach(idx; 0..howMany)
        {
            while (queue.isEmpty)
            {
                context.yield();
            }
            context.push(queue.pop());
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["pop.no_wait"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue();
        long howMany = 1;
        if (context.size > 0)
        {
            auto integer = context.pop!IntegerAtom();
            howMany = integer.value;
        }
        foreach(idx; 0..howMany)
        {
            if (queue.isEmpty)
            {
                auto msg = "queue is empty";
                return context.error(msg, ErrorCode.Empty, "");
            }
            context.push(queue.pop());
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["send"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue();

        if (context.size == 0)
        {
            auto msg = "no target to send from";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        auto target = context.pop();

        auto nextContext = context;
        do
        {
            nextContext = target.next(context);
            if (nextContext.exitCode == ExitCode.Break)
            {
                break;
            }
            auto item = nextContext.pop();

            while (queue.isFull)
            {
                context.yield();
            }
            queue.push(item);
        }
        while(nextContext.exitCode != ExitCode.Break);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["send.no_wait"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue();

        if (context.size == 0)
        {
            auto msg = "no target to send from";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        auto target = context.pop();

        auto nextContext = context;
        do
        {
            nextContext = target.next(context);
            if (nextContext.exitCode == ExitCode.Break)
            {
                break;
            }
            auto item = nextContext.pop();
            if (queue.isFull)
            {
                auto msg = "queue is full";
                return context.error(msg, ErrorCode.Full, "");
            }
            queue.push(item);
        }
        while(nextContext.exitCode != ExitCode.Break);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["receive"] = (string path, CommandContext context)
    {
        if (context.size != 1)
        {
            auto msg = "`receive` expects one argument";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        class QueueIterator : Item
        {
            Queue queue;
            this(Queue queue)
            {
                this.queue = queue;
            }
            override string toString()
            {
                return "QueueIterator";
            }
            override CommandContext next(CommandContext context)
            {
                while (queue.isEmpty)
                {
                    context.yield();
                }
                auto item = queue.pop();
                context.push(item);
                context.exitCode = ExitCode.Continue;
                return context;
            }
        }

        auto queue = context.pop!Queue();
        context.push(new QueueIterator(queue));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["receive.no_wait"] = (string path, CommandContext context)
    {
        if (context.size != 1)
        {
            auto msg = "`receive` expects one argument";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        class QueueIteratorNoWait : Item
        {
            Queue queue;
            this(Queue queue)
            {
                this.queue = queue;
            }
            override string toString()
            {
                return "QueueIteratorNoWait";
            }
            override CommandContext next(CommandContext context)
            {
                if (queue.isEmpty)
                {
                    context.exitCode = ExitCode.Break;
                }
                else
                {
                    context.exitCode = ExitCode.Continue;
                    auto item = queue.pop();
                    context.push(item);
                }
                return context;
            }
        }

        auto queue = context.pop!Queue();
        context.push(new QueueIteratorNoWait(queue));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Custom types
    commands["type"] = (string path, CommandContext context)
    {
        /*
        type coordinates {
            proc init (x y) {
                return [dict (x $x) (y $y)
            }
        }
        */
        auto name = context.pop!string();
        auto sublist = context.pop();
        auto subprogram = (cast(SubList)sublist).subprogram;

        auto newScope = new Process(context.escopo);

        auto newContext = context.next(newScope, context.size);

        // RUN!
        newContext = newContext.escopo.run(subprogram, newContext);

        if (newContext.exitCode == ExitCode.Failure)
        {
            // Simply pop up the error:
            return newContext;
        }
        else
        {
            newContext.exitCode = ExitCode.CommandSuccess;
        }

        debug {stderr.writeln(" creating new Type:", newScope.commands);}
        auto type = new Type(name);
        type.commands = newScope.commands;
        CommandHandler* initMethod = ("init" in newScope.commands);
        if (initMethod is null)
        {
            auto msg = "The type " ~ name ~ " must have a `init` method";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }

        context.escopo.commands[name] = (string path, CommandContext context)
        {
            auto returnContext = (*initMethod)(path, context);
            if (returnContext.exitCode == ExitCode.Failure)
            {
                return returnContext;
            }

            CommandHandlerMap newCommands;

            auto returnedObject = returnContext.pop();

            string prefix1 = returnedObject.typeName ~ ".";
            string prefix2 = name ~ ".";
            debug {stderr.writeln("prefix1:", prefix1); }
            debug {stderr.writeln("prefix2:", prefix2); }

            // set -> dict.set
            // set -> myclass.set
            foreach(cmdName, command; returnedObject.commands)
            {
                newCommands[cmdName] = command;
                newCommands[prefix1 ~ cmdName] = command;
                newCommands[prefix2 ~ cmdName] = command;
            }

            // (type.)set -> set (simple copy)
            foreach(cmdName, command; type.commands)
            {
                debug {stderr.writeln(cmdName, "->", command); }
                newCommands[cmdName] = command;
            }
            returnedObject.commands = newCommands;
            returnedObject.typeName = name;
            returnContext.push(returnedObject);
            return returnContext;
        };

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------
    // Shared libraries:
    til.sharedlibs.loadCommands(commands);
}
