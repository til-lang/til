module til.til;

import pegged.grammar;


mixin(grammar(`
    Til:
        Program             <- List* blank* endOfInput
        Comment             <~ [ \t]* "#" (!eol .)*
        List                <- blank* ListItem (" " ListItem)*
        ListItem            <- Comment / Pipe / ExecList / SubList / String / Atom
        Pipe                <- ForwardPipe
        ForwardPipe         <- "|>"
        ExecList            <- "[" List* blank* "]"
        SubList             <- "{" List* blank* "}"
        String              <- ["] (Substitution / NotSubstitution)* ["]
        Substitution        <~ "$" [A-Za-z0-9_.]+
        NotSubstitution     <~ (!doublequote !"$" .)*
        Atom                <- Float / Integer / Boolean / CommonAtom
        CommonAtom          <~ [$A-Za-z0-9_<>+\-_=.:&]+
        Float               <~ [0-9]+ "." [0-9]+
        Integer             <~ [0-9]+
        Boolean             <- BooleanTrue / BooleanFalse
        BooleanTrue         <~ "true" / "yes"
        BooleanFalse        <~ "false" / "no"
    `));
