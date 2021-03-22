module til.til;

import pegged.grammar;

mixin(grammar(`
    Til:
        Program             <- blank* Expression* (eol blank* Expression)* blank* endOfInput
        Expression          <- ForwardExpression / ExpansionExpression / List
        ForwardExpression   <- Expression ForwardPipe Expression
        ExpansionExpression <- Expression ExpansionPipe Expression
        ForwardPipe         <- " > "
        ExpansionPipe       <- " < "
        List                <- ListItem (' ' ListItem)*
        ListItem            <- "{" SubProgram "}" / String / Name / Atom
        SubProgram          <~ blank* Expression* (eol blank* Expression)* blank*
        String              <~ doublequote (!doublequote .)* doublequote
        Name                <~ [A-z0-9_] [.:A-z0-9\-+_]*
        Atom                <~ [$-+]? [A-z0-9\_]+
    `));
