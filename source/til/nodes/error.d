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
    CommandNotFound,
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
