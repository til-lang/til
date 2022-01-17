module til.nodes;

public import std.algorithm.iteration : map, joiner;
public import std.range : back, popBack, retro;
public import std.array : join;
public import std.conv : to;

public import til.exceptions;

public import til.context;
public import til.process;

public import til.nodes.listitem;

public import til.nodes.baselist;
public import til.nodes.extraction;
public import til.nodes.simplelist;
public import til.nodes.execlist;
public import til.nodes.sublist;

public import til.nodes.type;
public import til.nodes.dict;
public import til.nodes.queue;

public import til.nodes.error;
public import til.nodes.pid;

public import til.nodes.subprogram;
public import til.nodes.pipeline;
public import til.nodes.command;
public import til.nodes.string;
public import til.nodes.atom;

alias Item = ListItem;
alias Items = ListItem[];
alias Cmd = string;
alias CommandHandler = CommandContext delegate(Cmd, CommandContext);
alias CommandHandlerMap = CommandHandler[string];

enum ExitCode
{
    Undefined,
    Proceed,          // keep running
    ReturnSuccess,    // returned without errors
    Failure,          // terminated with errors
    CommandSuccess,   // A command was executed with success
    Break,            // Break the current loop
    Continue,         // Continue to the next iteraction
    Skip,             // Skip this iteration and call `next` again
}

enum ObjectType
{
    Undefined,
    Other,
    None,
    SimpleList,
    ExecList,
    SubList,
    SubProgram,
    Dict,
    String,
    Name,
    Atom,
    Operator,
    Float,
    Integer,
    Boolean,
    Numerical,
    Vector,
}
