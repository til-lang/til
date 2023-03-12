module now.nodes;

debug
{
    public import std.stdio;
}

public import std.algorithm.iteration : map;
public import std.range : back, popBack, retro;
public import std.array : join;
public import std.conv : to;

public import now.exceptions;

public import now.escopo;
public import now.context;

public import now.command;
public import now.nodes.item;

public import now.nodes.baselist;
public import now.nodes.simplelist;
public import now.nodes.execlist;

public import now.nodes.dict;
public import now.nodes.vectors;

public import now.nodes.error;

public import now.nodes.program;
public import now.nodes.subprogram;
public import now.nodes.pipeline;
public import now.nodes.command_call;
public import now.nodes.string;
public import now.nodes.atom;

// TODO: get rid of "ListItem" after some more versions.
alias ListItem = Item;
alias Items = Item[];


enum ExitCode
{
    Undefined,
    Success,  // A command was executed with success
    Failure,  // terminated with errors
    Return,  // returned without errors
    Break,  // Break the current loop
    Continue,  // Continue to the next iteraction
    Skip,  // Skip this iteration and call `next` again
}

enum ErrorCode
{
    Unknown = 1,
    InternalError,
    CommandNotFound,
    InvalidArgument,
    InvalidSyntax,
    InvalidInput,
    NotImplemented,
    SemanticError,
    Empty,
    Full,
    Overflow,
    Underflow,
    Assertion,
    RuntimeError,
    NotFound,
}

enum ObjectType
{
    Undefined,
    Other,
    None,
    SimpleList,
    ExecList,
    SubProgram,
    SystemProcess,
    Error,
    Dict,
    String,
    Name,
    Atom,
    Float,
    Integer,
    Boolean,
    Numerical,
    Vector,
    Range,
    Program,
}
