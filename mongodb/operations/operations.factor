USING: accessors bson.reader bson.writer byte-arrays byte-vectors fry
io io.binary io.encodings.binary io.encodings.string io.encodings.utf8
io.streams.byte-array kernel math mongodb.msg namespaces sequences
locals assocs combinators linked-assocs ;

IN: mongodb.operations

<PRIVATE

PREDICATE: mdb-reply-op < integer OP_Reply = ;
PREDICATE: mdb-query-op < integer OP_Query = ;
PREDICATE: mdb-insert-op < integer OP_Insert = ;
PREDICATE: mdb-update-op < integer OP_Update = ;
PREDICATE: mdb-delete-op < integer OP_Delete = ;
PREDICATE: mdb-getmore-op < integer OP_GetMore = ;
PREDICATE: mdb-killcursors-op < integer OP_KillCursors = ;

PRIVATE>

GENERIC: write-message ( message -- )

<PRIVATE

CONSTANT: MSG-HEADER-SIZE 16

SYMBOL: msg-bytes-read 

: bytes-read> ( -- integer )
    msg-bytes-read get ; inline

: >bytes-read ( integer -- )
    msg-bytes-read set ; inline

: change-bytes-read ( integer -- )
    bytes-read> [ 0 ] unless* + >bytes-read ; inline

: write-byte ( byte -- ) 1 >le write ; inline
: write-int32 ( int -- ) 4 >le write ; inline
: write-double ( real -- ) double>bits 8 >le write ; inline
: write-cstring ( string -- ) utf8 encode B{ 0 } append write ; inline
: write-longlong ( object -- ) 8 >le write ; inline

: read-int32 ( -- int32 ) 4 [ read le> ] [ change-bytes-read ] bi ; inline
: read-longlong ( -- longlong ) 8 [ read le> ] [ change-bytes-read ] bi ; inline
: read-byte-raw ( -- byte-raw ) 1 [ read le> ] [ change-bytes-read ] bi ; inline
: read-byte ( -- byte ) read-byte-raw first ; inline

: (read-cstring) ( acc -- )
    [ read-byte ] dip ! b acc
    2dup push             ! b acc
    [ 0 = ] dip      ! bool acc
    '[ _ (read-cstring) ] unless ; inline recursive

: read-cstring ( -- string )
    BV{ } clone
    [ (read-cstring) ] keep
    [ zero? ] trim-tail
    >byte-array utf8 decode ; inline

GENERIC: (read-message) ( message opcode -- message )

: copy-header ( message msg-stub -- message )
    [ length>> ] keep [ >>length ] dip
    [ req-id>> ] keep [ >>req-id ] dip
    [ resp-id>> ] keep [ >>resp-id ] dip
    [ opcode>> ] keep [ >>opcode ] dip
    flags>> >>flags ;

M: mdb-query-op (read-message) ( msg-stub opcode -- message )
    drop
    [ mdb-query-msg new ] dip copy-header
    read-cstring >>collection
    read-int32 >>skip#
    read-int32 >>return#
    H{ } stream>assoc change-bytes-read >>query 
    dup length>> bytes-read> >
    [ H{ } stream>assoc change-bytes-read >>returnfields ] when ;

M: mdb-insert-op (read-message) ( msg-stub opcode -- message )
    drop
    [ mdb-insert-msg new ] dip copy-header
    read-cstring >>collection
    V{ } clone >>objects
    [ '[ _ length>> bytes-read> > ] ] keep tuck
    '[ H{ } stream>assoc change-bytes-read _ objects>> push ]
    while ;

M: mdb-delete-op (read-message) ( msg-stub opcode -- message )
    drop
    [ mdb-delete-msg new ] dip copy-header
    read-cstring >>collection
    H{ } stream>assoc change-bytes-read >>selector ;

M: mdb-getmore-op (read-message) ( msg-stub opcode -- message )
    drop
    [ mdb-getmore-msg new ] dip copy-header
    read-cstring >>collection
    read-int32 >>return#
    read-longlong >>cursor ;

M: mdb-killcursors-op (read-message) ( msg-stub opcode -- message )
    drop
    [ mdb-killcursors-msg new ] dip copy-header
    read-int32 >>cursors#
    V{ } clone >>cursors
    [ [ cursors#>> ] keep 
      '[ read-longlong _ cursors>> push ] times ] keep ;

M: mdb-update-op (read-message) ( msg-stub opcode -- message )
    drop
    [ mdb-update-msg new ] dip copy-header
    read-cstring >>collection
    read-int32 >>upsert?
    H{ } stream>assoc change-bytes-read >>selector
    H{ } stream>assoc change-bytes-read >>object ;

M: mdb-reply-op (read-message) ( msg-stub opcode -- message )
    drop
    [ <mdb-reply-msg> ] dip copy-header
    read-longlong >>cursor
    read-int32 >>start#
    read-int32 [ >>returned# ] keep
    [ <linked-hash> stream>assoc drop ] accumulator [ times ] dip >>objects ;    

: read-header ( message -- message )
    read-int32 >>length
    read-int32 >>req-id
    read-int32 >>resp-id
    read-int32 >>opcode
    read-int32 >>flags ; inline

: write-header ( message length -- )
    MSG-HEADER-SIZE + write-int32
    [ req-id>> write-int32 ] keep
    [ resp-id>> write-int32 ] keep 
    opcode>> write-int32 ; inline

PRIVATE>

: read-message ( -- message )
    mdb-msg new
    0 >bytes-read
    read-header
    [ ] [ opcode>> ] bi (read-message) ;

<PRIVATE

: (write-message) ( message quot -- )
     [ binary ] dip with-byte-writer 
     [ length write-header ] keep 
     write flush ; inline

: build-query-object ( query -- selector )
    [let | selector [ <linked-hash> ] |
        { [ orderby>> [ "orderby" selector set-at ] when* ]
          [ explain>> [ "$explain" selector set-at ] when* ]
          [ hint>> [ "$hint" selector set-at ] when* ] 
          [ query>> "query" selector set-at ]
        } cleave
        selector
    ] ;     

PRIVATE>

M: mdb-query-msg write-message ( message -- )
     dup
     '[ _ 
        [ flags>> write-int32 ] keep 
        [ collection>> write-cstring ] keep
        [ skip#>> write-int32 ] keep
        [ return#>> write-int32 ] keep
        [ build-query-object assoc>array write ] keep
        returnfields>> [ assoc>array write ] when* 
     ] (write-message) ;
 
M: mdb-insert-msg write-message ( message -- )
    dup
    '[ _
       [ flags>> write-int32 ] keep
       [ collection>> write-cstring ] keep
       objects>> [ assoc>array write ] each
    ] (write-message) ;

M: mdb-update-msg write-message ( message -- )
    dup
    '[ _
       [ flags>> write-int32 ] keep
       [ collection>> write-cstring ] keep
       [ upsert?>> write-int32 ] keep
       [ selector>> assoc>array write ] keep
       object>> assoc>array write
    ] (write-message) ;

M: mdb-delete-msg write-message ( message -- )
    dup
    '[ _
       [ flags>> write-int32 ] keep
       [ collection>> write-cstring ] keep
       0 write-int32
       selector>> assoc>array write
    ] (write-message) ;

M: mdb-getmore-msg write-message ( message -- )
    dup
    '[ _
       [ flags>> write-int32 ] keep
       [ collection>> write-cstring ] keep
       [ return#>> write-int32 ] keep
       cursor>> write-longlong
    ] (write-message) ;

M: mdb-killcursors-msg write-message ( message -- )
    dup
    '[ _
       [ flags>> write-int32 ] keep
       [ cursors#>> write-int32 ] keep
       cursors>> [ write-longlong ] each
    ] (write-message) ;

