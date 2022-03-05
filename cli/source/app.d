import std.array : array;
import std.datetime.stopwatch;
import std.file;
import std.process : environment;
import std.stdio;
import std.string : stripRight;

import til.commands;
import til.exceptions;
import til.grammar;
import til.nodes;
import til.process;
import til.scheduler;

import cli.repl;


class InterpreterInput : Item
{
    File inputFile;

    this(File inputFile)
    {
        this.inputFile = inputFile;
    }

    override Context next(Context context)
    {
        if (inputFile.eof)
        {
            context.exitCode = ExitCode.Break;
        }
        else
        {
            auto input = inputFile.readln();
            context.push(new String(to!string(input).stripRight("\n")));
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

    SimpleList argumentsList = new SimpleList(
        cast(Items)args.map!(x => new String(x)).array
    );
    Dict envVars = new Dict();
    foreach(key, value; environment.toAA())
    {
        envVars[key] = new String(value);
    }

    debug
    {
        auto sw = StopWatch(AutoStart.no);
        sw.start();
    }

    // Potential small speed-up:
    commands.rehash;

    if (args.length == 1)
    {
        return repl(envVars, argumentsList);
    }

    auto filename = args[1];
    if (filename == "-")
    {
        parser = new Parser(to!string(stdin.byLine.join("\n")));
    }
    else
    {
        try
        {
            parser = new Parser(to!string(read(filename)));
        }
        catch (FileException ex)
        {
            stderr.writeln(
                "Error ",
                ex.errno, ": ",
                ex.msg
            );
            return ex.errno;
        }
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

    // The scheduler:
    auto scheduler = new Scheduler();

    // The main Process:
    auto process = new Process(scheduler, program);
    process.description = "main";
    process.input = new InterpreterInput(stdin);
    process.output = new InterpreterOutput(stdout);

    // The scope:
    auto escopo = new Escopo();
    escopo["args"] = argumentsList;
    escopo["env"] = envVars;
    escopo.commands = commands;
    process.context = process.context.next(escopo);

    // Start!
    debug {sw.start();}
    scheduler.add(process);
    scheduler.run();

    // Print everything remaining in the stack:
    int returnCode = 0;
    foreach(p; scheduler.processes)
    {
        stderr.write("Process ", p.index, ": ");
        if (p.context.exitCode == ExitCode.Failure)
        {
            stderr.writeln("ERROR");
            auto e = p.context.pop!Erro();
            stderr.writeln(e);
            returnCode = e.code;
        }
        else
        {
            stderr.writeln("Success");
            debug {stderr.writeln("  context.size:", p.context.size);}
            foreach(item; p.context.items)
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
