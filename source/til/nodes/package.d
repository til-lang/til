module til.nodes;

debug
{
    public import std.stdio;
}

public import std.algorithm.iteration : map;
public import std.range : back, popBack, retro;
public import std.array : join;
public import std.conv : to;

public import til.exceptions;

public import til.escopo;
public import til.context;

public import til.command;
public import til.nodes.item;

public import til.nodes.baselist;
public import til.nodes.extraction;
public import til.nodes.simplelist;
public import til.nodes.execlist;

public import til.nodes.dict;
public import til.nodes.vectors;

public import til.nodes.error;

public import til.nodes.subprogram;
public import til.nodes.pipeline;
public import til.nodes.command_call;
public import til.nodes.string;
public import til.nodes.atom;

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
}
