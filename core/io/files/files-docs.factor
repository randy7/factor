USING: help.markup help.syntax io io.styles strings
io.backend io.files.private ;
IN: io.files

ARTICLE: "file-streams" "Reading and writing files"
"File streams:"
{ $subsection <file-reader> }
{ $subsection <file-writer> }
{ $subsection <file-appender> }
"Utility combinators:"
{ $subsection with-file-reader }
{ $subsection with-file-writer }
{ $subsection with-file-appender } ;

ARTICLE: "pathnames" "Pathname manipulation"
"Pathname manipulation:"
{ $subsection parent-directory }
{ $subsection file-name }
{ $subsection last-path-separator }
{ $subsection path+ }
"Pathnames relative to Factor's install directory:"
{ $subsection resource-path }
{ $subsection ?resource-path }
"Pathnames relative to Factor's temporary files directory:"
{ $subsection temp-directory }
{ $subsection temp-file }
"Pathname presentations:"
{ $subsection pathname }
{ $subsection <pathname> } ;

ARTICLE: "file-system" "The file system"
"File system meta-data:"
{ $subsection exists? }
{ $subsection directory? }
{ $subsection file-length }
{ $subsection file-modified }
{ $subsection stat }
"Directory listing:"
{ $subsection directory }
{ $subsection directory* }
"Creating directories:"
{ $subsection make-directory }
{ $subsection make-directories }
"Deleting files:"
{ $subsection delete-file }
{ $subsection delete-directory }
{ $subsection delete-tree }
"Moving files:"
{ $subsection move-file }
{ $subsection move-file-to }
"Copying files:"
{ $subsection copy-file }
{ $subsection copy-file-to }
{ $subsection copy-tree }
"Current and home directories:"
{ $subsection cwd }
{ $subsection cd }
{ $subsection with-directory }
{ $subsection home }
{ $see-also "os" } ;

ARTICLE: "io.files" "Basic file operations"
"The " { $vocab-link "io.files" } " vocabulary provides basic support for working with files."
{ $subsection "file-streams" }
{ $subsection "pathnames" }
{ $subsection "file-system" } ;
ABOUT: "file-streams"

HELP: path-separator?
{ $values { "ch" "a code point" } { "?" "a boolean" } }
{ $description "Tests if the code point is a platform-specific path separator." }
{ $examples
    "On Unix:"
    { $example "USING: io.files prettyprint ;" "CHAR: / path-separator? ." "t" }
} ;

HELP: <file-reader>
{ $values { "path" "a pathname string" } { "stream" "an input stream" } }
{ $description "Outputs an input stream for reading from the specified pathname." }
{ $errors "Throws an error if the file is unreadable." } ;

HELP: <file-writer>
{ $values { "path" "a pathname string" } { "stream" "an output stream" } }
{ $description "Outputs an output stream for writing to the specified pathname. The file's length is truncated to zero." }
{ $errors "Throws an error if the file cannot be opened for writing." } ;

HELP: <file-appender>
{ $values { "path" "a pathname string" } { "stream" "an output stream" } }
{ $description "Outputs an output stream for writing to the specified pathname. The stream begins writing at the end of the file." }
{ $errors "Throws an error if the file cannot be opened for writing." } ;

HELP: with-file-reader
{ $values { "path" "a pathname string" } { "quot" "a quotation" } }
{ $description "Opens a file for reading and calls the quotation using " { $link with-stream } "." }
{ $errors "Throws an error if the file is unreadable." } ;

HELP: with-file-writer
{ $values { "path" "a pathname string" } { "quot" "a quotation" } }
{ $description "Opens a file for writing and calls the quotation using " { $link with-stream } "." }
{ $errors "Throws an error if the file cannot be opened for writing." } ;

HELP: with-file-appender
{ $values { "path" "a pathname string" } { "quot" "a quotation" } }
{ $description "Opens a file for appending and calls the quotation using " { $link with-stream } "." }
{ $errors "Throws an error if the file cannot be opened for writing." } ;

HELP: cwd
{ $values { "path" "a pathname string" } }
{ $description "Outputs the current working directory of the Factor process." }
{ $errors "Windows CE has no concept of ``current directory'', so this word throws an error there." } ;

HELP: cd
{ $values { "path" "a pathname string" } }
{ $description "Changes the current working directory of the Factor process." }
{ $errors "Windows CE has no concept of ``current directory'', so this word throws an error there." } ;

{ cd cwd } related-words

HELP: stat ( path -- directory? permissions length modified )
{ $values { "path" "a pathname string" } { "directory?" "boolean indicating if the file is a directory" } { "permissions" "a Unix permission bitmap (0 on Windows)" } { "length" "the length in bytes as an integer" } { "modified" "the last modification time, as milliseconds since midnight, January 1st 1970 GMT" } }
{ $description
    "Queries the file system for file meta data. If the file does not exist, outputs " { $link f } " for all four values."
} ;

{ stat exists? directory? file-length file-modified } related-words

HELP: path+
{ $values { "str1" "a string" } { "str2" "a string" } { "str" "a string" } }
{ $description "Concatenates two pathnames." } ;

HELP: exists?
{ $values { "path" "a pathname string" } { "?" "a boolean" } }
{ $description "Tests if the file named by " { $snippet "path" } " exists." } ;

HELP: directory?
{ $values { "path" "a pathname string" } { "?" "a boolean" } }
{ $description "Tests if " { $snippet "path" } " names a directory." } ;

HELP: (directory)
{ $values { "path" "a pathname string" } { "seq" "a sequence of " { $snippet "{ name dir? }" } " pairs" } }
{ $description "Outputs the contents of a directory named by " { $snippet "path" } "." }
{ $notes "This is a low-level word, and user code should call " { $link directory } " instead." } ;

HELP: directory
{ $values { "path" "a pathname string" } { "seq" "a sequence of " { $snippet "{ name dir? }" } " pairs" } }
{ $description "Outputs the contents of a directory named by " { $snippet "path" } "." } ;

HELP: file-length
{ $values { "path" "a pathname string" } { "n" "a non-negative integer or " { $link f } } }
{ $description "Outputs the length of the file in bytes, or " { $link f } " if it does not exist." } ;

HELP: file-modified
{ $values { "path" "a pathname string" } { "n" "a non-negative integer or " { $link f } } }
{ $description "Outputs a file's last modification time, since midnight January 1, 1970. If the file does not exist, outputs " { $link f } "." } ;

HELP: parent-directory
{ $values { "path" "a pathname string" } { "parent" "a pathname string" } }
{ $description "Strips the last component off a pathname." }
{ $examples { $example "USE: io.files" "\"/etc/passwd\" parent-directory print" "/etc/" } } ;

HELP: file-name
{ $values { "path" "a pathname string" } { "string" string } }
{ $description "Outputs the last component of a pathname string." }
{ $examples
    { "\"/usr/bin/gcc\" file-name ." "\"gcc\"" }
    { "\"/usr/libexec/awk/\" file-name ." "\"awk\"" }
} ;

HELP: resource-path
{ $values { "path" "a pathname string" } { "newpath" "a pathname string" } }
{ $description "Resolve a path relative to the Factor source code location. This first checks if the " { $link resource-path } " variable is set to a path, and if not, uses the parent directory of the current image." } ;

HELP: ?resource-path
{ $values { "path" "a pathname string" } { "newpath" "a string" } }
{ $description "If the path is prefixed with " { $snippet "\"resource:\"" } ", prepends the resource path." } ;

{ resource-path ?resource-path } related-words

HELP: pathname
{ $class-description "Class of pathname presentations. Path name presentations can be created by calling " { $link <pathname> } ". Instances can be passed to " { $link write-object } " to output a clickable pathname." } ;

HELP: normalize-directory
{ $values { "str" "a pathname string" } { "newstr" "a new pathname string" } }
{ $description "Called by the " { $link directory } " word to prepare a pathname before passing it to the " { $link (directory) } " primitive." } ;

HELP: normalize-pathname
{ $values { "str" "a pathname string" } { "newstr" "a new pathname string" } }
{ $description "Called by the " { $link stat } " word, and possibly " { $link <file-reader> } " and " { $link <file-writer> } ", to prepare a pathname before passing it to underlying code." } ;

HELP: <pathname> ( str -- pathname )
{ $values { "str" "a pathname string" } { "pathname" pathname } }
{ $description "Creates a new " { $link pathname } "." } ;

HELP: home
{ $values { "dir" string } }
{ $description "Outputs the user's home directory." } ;

HELP: delete-file
{ $values { "path" "a pathname string" } }
{ $description "Deletes a file." }
{ $errors "Throws an error if the file could not be deleted." } ;

HELP: make-directory
{ $values { "path" "a pathname string" } }
{ $description "Creates a directory." }
{ $errors "Throws an error if the directory could not be created." } ;

HELP: delete-directory
{ $values { "path" "a pathname string" } }
{ $description "Deletes a directory. The directory must be empty." }
{ $errors "Throws an error if the directory could not be deleted." } ;
