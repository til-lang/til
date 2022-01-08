module til.nodes.error;

import std.conv : to;

import til.nodes;

debug
{
    import std.stdio;
}


enum ErrorCode
{
    Unknown = 1,
    InternalError,
    CommandNotFound,
    InvalidArgument,
    InvalidSyntax,
    SemanticError,
    Empty,
    Full,
    Overflow,
    Underflow,
    Assertion,
}


class Erro : ListItem
{
    int code = -1;
    string classe;
    string message;
    Process process = null;

    this(Process process, string message, int code, string classe)
    {
        this.process = process;
        this.message = message;
        this.code = code;
        this.classe = classe;
    }

    // Conversions:
    override string toString()
    {
        string s = "Error " ~ to!string(code)
                   ~ ": " ~ message;
        if (classe)
        {
            s ~= " (" ~ classe ~ ")";
        }
        return s;
    }

    // Extractions:
    override CommandContext extract(CommandContext context)
    {
        if (context.size == 0) return context.push(this);
        auto args = context.items!string;
        auto arg = args.join(" ");

        switch(arg)
        {
            case "code":
                return context.push(code);
            case "process id":
                return context.push(process.index);
            case "message":
                return context.push(message);
            default:
                auto msg = "Invalid argument to Error extraction";
                return context.error(msg, ErrorCode.InvalidArgument, "");
        }
    }
}
