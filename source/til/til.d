module til.til;

import pegged.grammar;

mixin(grammar(`
    Til:
        Program             <- SubProgram endOfInput
        SubProgram          <- blank* Expression? (eol blank* Expression)* blank*
        Expression          <- Comment / ForwardExpression / ExpansionExpression / List
        Comment             <~ "#" (!eol .)*
        ForwardExpression   <- Expression ForwardPipe Expression
        ExpansionExpression <- Expression ExpansionPipe Expression
        ForwardPipe         <- " "+ ">" " "+
        ExpansionPipe       <- " "+ "<" " "+
        List                <- ListItem (" "+ ListItem)*
        ListItem            <- SubProgramCall / StringProgram / String / Atom
        SubProgramCall      <- "[" SubProgram "]"
        StringProgram       <- "{" SubProgram "}"
        String              <~ doublequote (!doublequote .)* doublequote
        Atom                <~ [$A-Za-z0-9_] [.:A-Za-z0-9\-+_]*
    `));
