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
    override ListItem extract(Items items)
    {
        if (items.length == 0) return this;
        auto arg = items.map!(x => to!string(x)).join(" ");

        switch(arg)
        {
            case "code":
                return new IntegerAtom(code);
            case "process id":
                return new IntegerAtom(process.index);
            default:
                throw new Exception(
                    "`" ~ arg ~ "` extraction not implemented"
                );
        }
    }
}
