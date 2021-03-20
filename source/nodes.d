module til.nodes;

import std.conv;
import std.algorithm.iteration;
import std.range;

class Atom {
    private string _repr;
    @property string repr()
    {
        return _repr;
    }
    @property void repr(string s)
    {
        _repr = s;
    }
    private int _integer;
    @property int integer()
    {
        return _integer;
    }
    private float _floating_point;
    @property float floating_point()
    {
        return _floating_point;
    }

    this(string s)
    {
        repr = s;
    }

    override string toString()
    {
        return _repr;
    }
}

class ListItem
{
    SubProgram _subProgram;
    DotList _dotList;

    this(SubProgram sp)
    {
        _subProgram = sp;
    }
    this(DotList dl)
    {
        _dotList = dl;
    }

    override string toString()
    {
        if (_subProgram) {
            return to!string(_subProgram);
        } else {
            return to!string(_dotList);
        }
    }
}

class DotList
{
    ColonList[] _colonLists;

    this(ColonList[] colonLists)
    {
        _colonLists = colonLists;
    }

    override string toString()
    {
        auto list = _colonLists
            .map!(x => to!string(x))
            .joiner("-DOT-");
        return to!string(list);
    }
}

class ColonList
{
    Atom[] _atoms;
    this(Atom[] atoms)
    {
        _atoms = atoms;
    }

    override string toString()
    {
        auto list = _atoms
            .map!(x => to!string(x))
            .joiner("-colon-");
        return to!string(list);
    }
}

class SubProgram
{
    Expression[] _expressions;

    this(Expression[] expressions)
    {
        _expressions = expressions;
    }

    override string toString()
    {
        auto list = _expressions
            .map!(x => to!string(x))
            .joiner("\n");
        return to!string(list);
    }

    SubProgram run()
    {
        Expression[] expressions;
        return new SubProgram(expressions);
    }
}

class Expression
{
    ForwardExpression _forwardExpression;
    ExpansionExpression _expansionExpression;
    List _list;

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

    override string toString()
    {
        string x = {
            if (_forwardExpression) {
                return to!string(_forwardExpression);
            } else if (_expansionExpression) {
                return to!string(_expansionExpression);
            } else {
                return to!string(_list);
            }
        }();
        return "expr{" ~ x ~ "}";
    }
}

class ExpressionSet
{
    Expression[] _expressions;
    this(Expression[] expressions)
    {
        _expressions = expressions;
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
        auto exp1 = to!string(_expressions[0]);
        auto exp2 = to!string(_expressions[1]);
        return "f(" ~ exp1 ~ " > " ~ exp2 ~ ")f";
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
        auto exp1 = to!string(_expressions[0]);
        auto exp2 = to!string(_expressions[1]);
        return "e(" ~ exp1 ~ " < " ~ exp2 ~ ")e";
    }
}

class List
{
    ListItem[] _items;

    this(ListItem[] items)
    {
        _items = items;
        Expression[] expressions;
    }

    override string toString()
    {
        auto list = _items
            .map!(x => to!string(x))
            .joiner(" , ");
        return "[" ~ to!string(list) ~ "]";
    }
}
