module til.nodes;

import std.conv : to;
import std.stdio : writeln;
import std.algorithm.iteration : map, joiner;

import til.escopo;
import til.exceptions;


enum ListItemType
{
    Undefined,
    SubProgram,
    String,
    Name,
    Atom
}

class Program
{
    Escopo escopo;
    Expression[] expressions;

    this(Escopo escopo, Expression[] expressions)
    {
        this.escopo = escopo;
        this.expressions = expressions;
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

    List run()
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
}

class Expression
{
    ForwardExpression _forwardExpression;
    ExpansionExpression _expansionExpression;
    List _list;
    string _string;

    this(ForwardExpression expr)
    {
        _forwardExpression = expr;
    }
    this(ExpansionExpression expr)
    {
        _expansionExpression = expr;
    }
    this(List l)
    {
        _list = l;
    }
    this(string s)
    {
        _string = s;
    }

    override string toString()
    {
        if (_forwardExpression) {
            return to!string(_forwardExpression);
        } else if (_expansionExpression) {
            return to!string(_expansionExpression);
        } else if (_list) {
            return to!string(_list);
        } else {
            return _string;
        }
    }

    List run(Escopo escopo, List firstArguments)
    {
        if (_forwardExpression) {
            return _forwardExpression.run(escopo, firstArguments);
        } else if (_expansionExpression) {
            return _expansionExpression.run(escopo, firstArguments);
        } else if (_list) {
            return _list.run(escopo, firstArguments);
        } else {
            writeln("Expression returning: " ~ _string);
            auto newItems = new ListItem[1];
            newItems[0] = new ListItem(_string, ListItemType.String);
            return new List(newItems);
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
        auto feedback = new ListItem[1];

        foreach(expression; expressions)
        {
            writeln("ForwardExpression.run> " ~ to!string(expression));
            returned = expression.run(escopo, firstArguments);

            auto subProgram = to!string(returned);
            feedback[0] = new ListItem(subProgram, ListItemType.SubProgram);
            firstArguments = new List(feedback);
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
        if (command.type == ListItemType.Name)
        {
            auto strCmd = to!string(command);
            return escopo.run_command(strCmd, arguments);
        }
        // {lists.order} $my_lists < lists.map
        else
        {
            // SubPrograms, Strings and Atoms just return themselves.
            return this;
        }
    }
}

class ListItem
{
    string repr;
    ListItemType type = ListItemType.Undefined;

    this(string s, ListItemType type)
    {
        this.repr = s;
        this.type = type;
    }

    override string toString()
    {
        return this.repr;
    }
}


