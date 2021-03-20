import std.stdio;

import pegged.grammar;

import til.grammar;
import til.nodes;

// ---------------------------------------

void main()
{
    mixin(grammar(`
    Til:
        Program             <- SubProgram !.
        SubProgram          <- [ \n]* Expression* ("\n" [ \n]* Expression)* [ \n]*
        Expression          <- ForwardExpression / ExpansionExpression / List
        ForwardExpression   <- Expression ForwardPipe Expression
        ExpansionExpression <- Expression ExpansionPipe Expression
        ForwardPipe         <- " > "
        ExpansionPipe       <- " < "
        List                <- ListItem (' ' ListItem)*
        ListItem            <- "{" SubProgram "}" / DotList
        DotList             <- ColonList ('.' ColonList)*
        ColonList           <- Atom (':' Atom)*
        Atom                <~ [A-z0-9\-+$]+
    `));

    string[5] code = [
        "set y {10 + 10 > math.run}",
        "run x {
            run y {run z {
                f 23}}
        }",
        "{$a + $b}",
        "{$a + $b} > fill > math.run",
        "$a $b $c > fill < std.out",
    ];

    foreach (index, line; code)
    {
        auto tree = Til(line);
        writeln(index, ": ", line);
        // writeln(index, ": ", line, " :\n", tree);
        execute(tree);
        writeln("==============");
    }
}
