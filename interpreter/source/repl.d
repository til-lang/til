module til.interpreter.repl;

import std.stdio;
import std.string : fromStringz;

import til.commands;
import til.exceptions;
import til.grammar;
import til.nodes;
import til.scheduler;

import editline;


int repl()
{
    auto process = new Process(null);
    process.commands = commands;

    while (true)
    {
        auto line = readline("> ");
        if (line is null)
        {
            break;
        }
        string command = to!string(line.fromStringz());
        if (command.length == 0)
        {
            continue;
        }
        stdout.writeln("[" ~ to!string(line.fromStringz()) ~ "]");
        add_history(line);

        auto parser = new Parser(command);
        process.state = ProcessState.New;
        process.program = parser.run();
        auto scheduler = new Scheduler(process);
        scheduler.run();
    }
    stdout.writeln("exiting repl...");
    clear_history();

    return 0;
}
