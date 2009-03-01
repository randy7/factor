USING: accessors assocs fry io.sockets kernel math mongodb.msg formatting linked-assocs destructors continuations
mongodb.operations namespaces sequences splitting math.parser io.encodings.binary combinators io.streams.duplex
arrays io memoize constructors sets strings ;

IN: mongodb.driver

TUPLE: mdb-node master? inet ;

TUPLE: mdb name nodes collections ;

TUPLE: mdb-cursor collection id return# ;

UNION: boolean t POSTPONE: f ;

TUPLE: mdb-collection
{ name string }
{ capped boolean initial: f }
{ size integer initial: -1 }
{ max integer initial: -1 } ;

CONSTRUCTOR: mdb-cursor ( id collection return# -- cursor ) ;
CONSTRUCTOR: mdb-collection ( name -- collection ) ;

CONSTANT: MDB-GENERAL-ERROR 1

CONSTANT: MDB_OID "_id"
CONSTANT: MDB_PROPERTIES  "_mdb_"

CONSTANT: PARTIAL? "partial?"
CONSTANT: DIRTY? "dirty?"

ERROR: mdb-error id msg ;

<PRIVATE

SYMBOL: mdb-socket-stream

: mdb-stream>> ( -- stream )
    mdb-socket-stream get ; inline

: check-ok ( result -- ? )
     [ "ok" ] dip key? ; inline 

PRIVATE>

: mdb>> ( -- mdb )
    mdb get ; inline

: master>> ( mdb -- inet )
    nodes>> [ t ] dip at inet>> ;

: slave>> ( mdb -- inet )
    nodes>> [ f ] dip at inet>> ;

: with-db ( mdb quot -- ... )
    [ [ '[ _ [ mdb set ] keep master>>
           [ remote-address set ] keep
           binary <client>
           local-address set
           mdb-socket-stream set ] ] dip compose
      [ mdb-stream>> [ dispose ] when* ] [ ] cleanup
    ] with-scope ;

<PRIVATE

: index-collection ( -- ns )
   mdb>> name>> "%s.system.indexes" sprintf ; inline

: namespaces-collection ( -- ns )
    mdb>> name>> "%s.system.namespaces" sprintf ; inline

: cmd-collection ( -- ns )
    mdb>> name>> "%s.$cmd" sprintf ; inline
 
: index-ns ( colname -- index-ns )
    [ mdb>> name>> ] dip "%s.%s" sprintf ; inline

: ismaster-cmd ( node -- result )
    binary "admin.$cmd" H{ { "ismaster" 1 } } <mdb-query-msg>
    1 >>return# '[ _ write-message read-message ] with-client
    objects>> first ; 

: split-host-str ( hoststr -- host port )
    ":" split [ first ] keep
    second string>number ; inline

: eval-ismaster-result ( node result -- node result )
    [ [ "ismaster" ] dip at
      >fixnum 1 =
      [ t >>master? ] [ f >>master? ] if ] keep ;

: check-node ( node -- node remote )
    dup inet>> ismaster-cmd  
    eval-ismaster-result
    [ "remote" ] dip at ;

: check-nodes ( node -- nodelist )
    check-node
    [ V{ } clone [ push ] keep ] dip
    [ split-host-str <inet> [ f ] dip
      mdb-node boa check-node drop
      swap tuck push
    ] when* ;

: verify-nodes ( -- )
    mdb>> nodes>> [ t ] dip at
    check-nodes
    H{ } clone tuck
    '[ dup master?>> _ set-at ] each
    [ mdb>> ] dip >>nodes drop ;

: send-message ( message -- )
    [ mdb-stream>> ] dip '[ _ write-message ] with-stream* ;

: send-query-plain ( query-message -- result )
    [ mdb-stream>> ] dip
    '[ _ write-message read-message ] with-stream* ;

: send-query ( query-message -- cursor result )
    [ send-query-plain ] keep
    { [ collection>> >>collection drop ]
      [ return#>> >>requested# ]
    } 2cleave
    [ [ cursor>> 0 > ] keep
      '[ _ [ cursor>> ] [ collection>> ] [ requested#>> ] tri <mdb-cursor> ]
      [ f ] if
    ] [ objects>> ] bi ;

PRIVATE>

: <mdb> ( db host port -- mdb )
    [ f ] 2dip <inet> mdb-node boa
    check-nodes
    H{ } clone tuck
    '[ dup master?>> _ set-at ] each
    H{ } clone mdb boa ;

: create-collection ( name -- )
    [ cmd-collection ] dip
    "create" H{ } clone [ set-at ] keep 
     <mdb-query-msg> 1 >>return# send-query-plain objects>> first check-ok
    [ "could not create collection" throw ] unless ;

: load-collection-list ( -- collection-list )
    namespaces-collection
    H{ } clone <mdb-query-msg> send-query-plain objects>> ;

<PRIVATE

: ensure-valid-collection-name ( collection -- )
    [ ";$." intersect length 0 > ] keep
    '[ _ "%s contains invalid characters ( . $ ; )" sprintf throw ] when ; inline

: (ensure-collection) ( collection --  )
    mdb>> collections>> dup keys length 0 = 
    [ load-collection-list      
      [ [ "options" ] dip key? ] filter
      [ [ "name" ] dip at "." split second <mdb-collection> ] map
      over '[ [ ] [ name>> ] bi _ set-at ] each ] [ ] if
    [ dup ] dip key? [ drop ]
    [ [ ensure-valid-collection-name ] keep create-collection ] if ; inline

MEMO: reserved-namespace? ( name -- ? )
    [ "$cmd" = ] [ "system" head? ] bi or ;
    
PRIVATE>

MEMO: ensure-collection ( collection -- fq-collection )
    "." split1 over mdb>> name>> =
    [ [ drop ] dip ] [ drop ] if
    [ ] [ reserved-namespace? ] bi
    [ [ (ensure-collection) ] keep ] unless
    [ mdb>> name>> ] dip "%s.%s" sprintf ; inline

: <query> ( collection query -- mdb-query )
    [ ensure-collection ] dip
    <mdb-query-msg> ; inline

GENERIC# limit 1 ( mdb-query limit# -- mdb-query )
M: mdb-query-msg limit ( query limit# -- mdb-query )
    >>return# ; inline
 
GENERIC# skip 1 ( mdb-query skip# -- mdb-query )
M: mdb-query-msg skip ( query skip# -- mdb-query )
    >>skip# ; inline

: asc ( key -- spec ) [ 1 ] dip H{ } clone [ set-at ] keep ; inline
: desc ( key -- spec ) [ -1 ] dip H{ } clone [ set-at ] keep ; inline

GENERIC# sort 1 ( mdb-query quot -- mdb-query )
M: mdb-query-msg sort ( query qout -- mdb-query )
    [ { } ] dip with-datastack >>orderby ;

GENERIC# hint 1 ( mdb-query index-hint -- mdb-query )
M: mdb-query-msg hint ( mdb-query index-hint -- mdb-query )
    >>hint ;

: find ( mdb-query -- cursor result )
     send-query ;

: explain ( mdb-query -- result )
    t >>explain find [ drop ] dip ;

GENERIC: get-more ( mdb-cursor -- mdb-cursor objects )
M: mdb-cursor get-more ( mdb-cursor -- mdb-cursor objects )
    [ [ collection>> ] [ return#>> ] [ id>> ] tri <mdb-getmore-msg> send-query ] 
    [ f f ] if* ;

: find-one ( mdb-query -- result )
    1 >>return# send-query-plain ;

: count ( collection query -- result )
    [ "count" H{ } clone [ set-at ] keep ] dip
    [ over [ "query" ] dip set-at ] when*
    [ cmd-collection ] dip <mdb-query-msg> find-one objects>> first
    [ check-ok ] keep '[ "n" _ at >fixnum ] [ f ] if ;
 
: lasterror ( -- error )
    cmd-collection H{ { "getlasterror" 1 } } <mdb-query-msg>
    find-one objects>> [ "err" ] at ;

: validate ( collection -- )
    [ cmd-collection ] dip
    "validate" H{ } clone [ set-at ] keep
    <mdb-query-msg> find-one objects>> first [ check-ok ] keep
    '[ "result" _ at print ] when ;

<PRIVATE

: send-message-check-error ( message -- )
    send-message lasterror [ [ MDB-GENERAL-ERROR ] dip mdb-error ] when* ;

PRIVATE>

: save ( collection object -- )
    [ ensure-collection ] dip
    <mdb-insert-msg> send-message-check-error ;

: save-unsafe ( collection object -- )
    [ ensure-collection ] dip
    <mdb-insert-msg> send-message ;

: ensure-index ( collection name spec -- )
    H{ } clone
    [ [ "key" ] dip set-at ] keep
    [ [ "name" ] dip set-at ] keep
    [ [ index-ns "ns" ] dip set-at ] keep
    [ index-collection ] dip
    save ;

: drop-index ( collection name -- )
    H{ } clone
    [ [ "index" ] dip set-at ] keep
    [ [ "deleteIndexes" ] dip set-at ] keep
    [ cmd-collection ] dip <mdb-query-msg> find-one objects>> first
    check-ok [ "could not drop index" throw ] unless ;

: update ( collection selector object -- )
    [ ensure-collection ] dip
    <mdb-update-msg> send-message-check-error ;

: update-unsafe ( collection selector object -- )
    [ ensure-collection ] dip
    <mdb-update-msg> send-message ;
 
: delete ( collection selector -- )
    [ ensure-collection ] dip
    <mdb-delete-msg> send-message-check-error ;

: delete-unsafe ( collection selector -- )
    [ ensure-collection ] dip
    <mdb-delete-msg> send-message ;

: load-index-list ( -- index-list )
    index-collection
    H{ } clone <mdb-query-msg> find [ drop ] dip ;

: drop-collection ( name -- )
    [ cmd-collection ] dip
    "drop" H{ } clone [ set-at ] keep
    <mdb-query-msg> find-one objects>> first check-ok
    [ "could not drop collection" throw ] unless ;
