import std.datetime.stopwatch;
import std.file;
import std.stdio;

import til.commands;
import til.exceptions;
import til.grammar;
import til.nodes;
import til.scheduler;

import til.interpreter.repl;


class InterpreterInput : Item
{
    File inputFile;

    this(File inputFile)
    {
        this.inputFile = inputFile;
    }

    override CommandContext next(CommandContext context)
    {
        if (inputFile.eof)
        {
            context.exitCode = ExitCode.Break;
        }
        else
        {
            context.push(new String(inputFile.readln()));
            context.exitCode = ExitCode.Continue;
        }
        return context;
    }

    override string toString()
    {
        return "InterpreterInput";
    }
}

class InterpreterOutput : Queue
{
    File outputFile;

    this(File outputFile)
    {
        super(0);
        this.outputFile = outputFile;
    }

    override void push(ListItem item)
    {
        // outputFile.write(to!string(item));
        stdout.write(to!string(item));
    }

    override string toString()
    {
        return "stdout";
    }
}

int main(string[] args)
{
    Parser parser;

    debug
    {
        auto sw = StopWatch(AutoStart.no);
        sw.start();
    }

    if (args.length == 1)
    {
        return repl();
    }

    auto filename = args[1];
    if (filename == "-")
    {
        parser = new Parser(to!string(stdin.byLine.join("\n")));
    }
    else
    {
        parser = new Parser(to!string(read(filename)));
    }

    debug
    {
        sw.stop();
        stderr.writeln(
            "Code was loaded in ",
            sw.peek.total!"msecs", " miliseconds"
        );
    }

    SubProgram program;
    debug {sw.start();}

    program = parser.run();

    debug
    {
        sw.stop();
        stderr.writeln(
            "Semantic analysis took ",
            sw.peek.total!"msecs", " miliseconds"
        );
    }

    auto process = new Process(null, program);
    process.commands = commands;
    process.input = new InterpreterInput(stdin);
    process.output = new InterpreterOutput(stdout);

    debug {sw.start();}
    auto scheduler = new Scheduler(process);
    scheduler.run();

    // Print everything remaining in the stack:
    int returnCode = 0;
    foreach(fiber; scheduler.fibers)
    {
        stderr.write("Process ", fiber.process.index, ": ");
        if (fiber.context.exitCode == ExitCode.Failure)
        {
            stderr.writeln("ERROR");
            auto e = cast(Erro)fiber.context.pop();
            stderr.writeln(e);
            returnCode = e.code;
        }
        else
        {
            stderr.writeln("Success");
            debug {stderr.writeln("  context.size:", fiber.context.size);}
            foreach(item; fiber.context.items)
            {
                stderr.writeln(item);
            }
        }
    }
    debug
    {
        sw.stop();
        stderr.writeln(
            "Program was run in ",
            sw.peek.total!"msecs", " miliseconds"
        );
    }
    return returnCode;
}
