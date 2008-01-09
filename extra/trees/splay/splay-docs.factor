USING: help.syntax help.markup trees.splay assocs ;

HELP: SPLAY{
{ $syntax "SPLAY{ { key value }... }" }
{ $values { "key" "a key" } { "value" "a value" } }
{ $description "Literal syntax for an splay tree." } ;

HELP: <splay>
{ $values { "tree" splay } }
{ $description "Creates an empty splay tree" } ;

HELP: >splay
{ $values { "assoc" assoc } { "splay" splay } }
{ $description "Converts any " { $link assoc } " into an splay tree." } ;

HELP: splay
{ $class-description "This is the class for splay trees. Splay trees have amortized average-case logarithmic time storage and retrieval operations, and better complexity on more skewed lookup distributions, though in bad situations they can degrade to linear time, resembling a linked list. These conform to the assoc protocol." } ;

ARTICLE: { "splay" "intro" } "Splay trees"
"This is a library for splay trees. Splay trees have amortized average-case logarithmic time storage and retrieval operations, and better complexity on more skewed lookup distributions, though in bad situations they can degrade to linear time, resembling a linked list. These trees conform to the assoc protocol."
{ $subsection splay }
{ $subsection <splay> }
{ $subsection >splay }
{ $subsection POSTPONE: SPLAY{ } ;

IN: trees.splay
ABOUT: { "splay" "intro" }