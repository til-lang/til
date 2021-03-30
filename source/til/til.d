module til.til;

import pegged.grammar;


mixin(grammar(`
    Til:
        Program             <- List* blank* endOfInput
        Comment             <~ "#" (!eol .)*
        List                <- blank* ListItem (" " ListItem)*
        ListItem            <- Pipe / ExecList / SubList / String / Atom
        Pipe                <- ForwardPipe
        ForwardPipe         <- ">"
        ExecList            <- "[" List* "]"
        SubList             <- "{" List* blank* "}"
        String              <- ["] (Substitution / NotSubstitution)* ["]
        Substitution        <~ "$" [A-Za-z0-9_.]+
        NotSubstitution     <~ (!doublequote !"$" .)*
        Atom                <~ [$A-Za-z0-9_] [.:A-Za-z0-9\-+_]*
    `));
