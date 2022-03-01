module til.nodes.error;

import std.conv : to;

import til.nodes;

debug
{
    import std.stdio;
}

CommandsMap errorCommands;


class Erro : ListItem
{
    int code = -1;
    string classe;
    string message;
    Process process;
    Item object;

    this(Process process, string message, int code, string classe)
    {
        this(process, message, code, classe, null);
    }
    this(Process process, string message, int code, string classe, Item object)
    {
        this.object = object;
        this.process = process;
        this.message = message;
        this.code = code;
        this.classe = classe;
        this.type = ObjectType.Error;
        this.typeName = "error";
        this.commands = errorCommands;
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
}
