module til.std.stack;

import std.algorithm.mutation : reverse;
import std.conv;
import std.experimental.logger;

import til.escopo;
import til.nodes;


class Stack : Escopo
{
    string name = "stack";

    Result cmd_dup(NamePath path, Args args)
    {
        auto head = args.consume();
        return new SubList([head, head]);
    }
    Result cmd_reverse(NamePath path, Args args)
    {
        auto head = args.consume();
        if (head.type != ObjectTypes.String)
        {
            throw new Exception(
                "Cannot reverse a "
                ~ to!string(head.type)
                ~ " (" ~ head.asString ~ ")"
            );
        }
        char[] r = reverse!(char[])(cast(char[])head.asString);
        return new String(cast(string)r);
    }
    Result cmd_equals(NamePath path, Args args)
    {
        auto t1 = args.consume();
        auto t2 = args.consume();
        // XXX: compare based on types, maybe.
        return new Atom(t1.asString == t2.asString);
    }

    override void loadCommands()
    {
        this.commands["dup"] = &cmd_dup;
        this.commands["reverse"] = &cmd_reverse;
        this.commands["equals?"] = &cmd_equals;
    }
}
