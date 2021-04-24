module til.nodes.error;

import std.conv : to;

import til.nodes;

debug
{
    import std.stdio;
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

    override string asString()
    {
        return "Error " ~ to!string(code)
               ~ " for process" ~ to!string(process.index);
    }
    override int asInteger()
    {
        return code;
    }
    override float asFloat()
    {
        return cast(float)code;
    }
    override bool asBoolean()
    {
        return false;
    }
    override ListItem inverted()
    {
        throw new Exception("Cannot invert an Error");
    }

    override ListItem extract(Items items)
    {
        if (items.length == 0) return this;
        auto arg = items.map!(x => x.asString).join(" ");

        switch(arg)
        {
            case "code":
                return new Atom(code);
            case "process id":
                return new Atom(process.index);
            default:
                throw new Exception(
                    "`" ~ arg ~ "` extraction not implemented"
                );
        }
    }
}
