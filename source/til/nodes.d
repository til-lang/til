module til.nodes;

import std.conv : to;
import std.stdio : writeln;
import std.algorithm.iteration : map, joiner;

import til.escopo;
import til.exceptions;
import til.grammar;


alias Value = string;


class Program
{
    SubProgram subprogram;

    this(SubProgram subprogram)
    {
        this.subprogram = subprogram;
    }

    List run(Escopo escopo)
    {
        return this.subprogram.run(escopo);
    }
}

class SubProgram
{
    Expression[] expressions;

    this(Expression[] expressions)
    {
        this.expressions = expressions;
    }
    this(List list)
    {
        // Create a Expression to contain the List:
        Expression e = new Expression(list);
        this.expressions ~= e;
    }

    override string toString()
    {
        auto list = expressions
            .map!(x => to!string(x))
            .joiner("\n");
        return to!string(list);
    }

    ulong length()
    {
        return expressions.length;
    }

    List run(Escopo escopo)
    {
        List returned;
        List lastValidReturn;

        foreach(expression; expressions)
        {
            writeln("Program.run-expression> " ~ to!string(expression));
            // XXX: fill "firstArguments" with "argv", maybe...
            returned = expression.run(escopo, null);
            writeln(" - returned: " ~ to!string(returned));
            if (returned !is null && returned.scopeExit != ScopeExitCodes.Continue)
            {
                break;
            }
            else
            {
                lastValidReturn = returned;
            }
        }

        // Returns whatever was the result of the last Expression,
        writeln(" - lastValidReturn: " ~ to!string(lastValidReturn));
        return lastValidReturn;
    }

    // How to "resolve" an entire program into an value???
    Value resolve(Escopo escopo)
    {
        List returned = this.run(escopo);
        // TODO: handle "null" properly.
        return to!string(returned);
    }
}

class Expression
{
    ForwardExpression forwardExpression;
    ExpansionExpression expansionExpression;
    List list;

    this(ForwardExpression expr)
    {
        this.forwardExpression = expr;
    }
    this(ExpansionExpression expr)
    {
        this.expansionExpression = expr;
    }
    this(List l)
    {
        this.list = l;
    }

    override string toString()
    {
        if (forwardExpression) {
            return to!string(forwardExpression);
        } else if (expansionExpression) {
            return to!string(expansionExpression);
        } else {
            return to!string(list);
        }
    }

    List run(Escopo escopo, List firstArguments)
    {
        if (forwardExpression) {
            return forwardExpression.run(escopo, firstArguments);
        } else if (expansionExpression) {
            return expansionExpression.run(escopo, firstArguments);
        } else {
            return list.run(escopo, firstArguments);
        }
    }
}

class ExpressionSet
{
    Expression[] expressions;
    this(Expression[] expressions)
    {
        this.expressions = expressions;
    }
}

class ForwardExpression : ExpressionSet
{
    this(Expression[] expressions)
    {
        super(expressions);
    }

    override string toString()
    {
        writeln(expressions);
        string r = "f(" ~ to!string(expressions[0]);
        foreach(expression; expressions[1..$])
        {
            r ~= " > " ~ to!string(expression);
        }
        r ~= ")f";
        return r;
    }

    List run(Escopo escopo, List firstArguments)
    {
        List returned = null;

        foreach(expression; expressions)
        {
            writeln("ForwardExpression.run> " ~ to!string(expression));
            returned = expression.run(escopo, firstArguments);

            // SubPrograms are valid ListItems:
            auto sp = new SubProgram(returned);
            firstArguments = new List(sp, false);
        }
        return returned;
    }
}

class ExpansionExpression : ExpressionSet
{
    this(Expression[] expressions)
    {
        super(expressions);
    }

    override string toString()
    {
        string r = "f(" ~ to!string(expressions[0]);
        foreach(expression; expressions[1..$])
        {
            r ~= " < " ~ to!string(expression);
        }
        r ~= ")f";
        return r;
    }

    List run(Escopo escopo, List firstArguments)
    {
        foreach(expression; expressions)
        {
            writeln("ExpansionExpression.run> " ~ to!string(expression));
            firstArguments = expression.run(escopo, firstArguments);
        }
        return firstArguments;
    }
}

enum ScopeExitCodes
{
    Continue,
    Success,
    Failure,
}

class List
{
    ListItem[] items;
    ScopeExitCodes scopeExit = ScopeExitCodes.Continue;

    this()
    {
    }
    this(ListItem[] items)
    {
        this.items = items;
    }
    this(SubProgram sp, bool execute)
    {
        this.items ~= new ListItem(sp, execute);
    }

    override string toString()
    {
        auto list = items
            .map!(x => to!string(x))
            .joiner(" , ");
        return to!string(list);
    }
    ListItem opIndex(int i)
    {
        return items[i];
    }
    ListItem[] opSlice(ulong start, ulong end)
    {
        return items[start..end];
    }
    ulong length()
    {
        return items.length;
    }
    @property ulong opDollar()
    {
        return this.length;
    }

    List run(Escopo escopo, List firstArguments)
    {
        // std.out 1 2 3
        ListItem command = items[0];
        List arguments;

        if (firstArguments !is null)
        {
            arguments = new List(firstArguments.items ~ items[1..$]);
        }
        else
        {
            arguments = new List(items[1..$]);
        }

        // lists.order 3 4 1 2 > std.out
        if (command.type == ListItemType.Atom)
        {
            auto cmd = command.resolve(escopo);
            return escopo.run_command(cmd, arguments);
        }
        // {lists.order} $my_lists < lists.map
        else
        {
            // SubPrograms, Strings and Atoms just return themselves.
            return this;
        }
    }
}

enum ListItemType
{
    Undefined,
    Atom,
    String,
    SubProgram,
}

class ListItem
{
    Atom atom;
    string str;
    SubProgram subprogram;
    bool execute;
    ListItemType type;

    this(Atom a)
    {
        this.atom = a;
        this.type = ListItemType.Atom;
    }
    this(string s)
    {
        this.str = s;
        this.type = ListItemType.String;
    }
    this(SubProgram s, bool execute)
    {
        this.subprogram = s;
        this.type = ListItemType.SubProgram;
        this.execute = execute;
    }

    Value resolve(Escopo escopo)
    {
        switch(this.type)
        {
            case ListItemType.Atom:
                return this.atom.resolve(escopo);
            case ListItemType.String:
                return this.str;
            case ListItemType.SubProgram:
                return this.subprogram.resolve(escopo);
            default:
                throw new Exception("wut?");
        }
        assert(0);
    }
}

class Atom
{
    string repr;

    this(string s)
    {
        this.repr = s;
    }

    Value resolve(Escopo escopo)
    {
        return this.repr;
    }
}
