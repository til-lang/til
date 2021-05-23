module til.nodes.error;

import std.conv : to;

import til.nodes;

debug
{
    import std.stdio;
}


enum ErrorCode
{
    Unknown,
    InternalError,
    CommandNotFound,
    InvalidArgument,
    InvalidSyntax,
    SemanticError,
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
        this.commandPrefix = "error";
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
                return context.push(new IntegerAtom(code));
            case "process id":
                return context.push(new IntegerAtom(process.index));
            default:
                auto msg = "Invalid argument to Error extraction";
                return context.error(msg, ErrorCode.InvalidArgument, "");
        }
    }
}
