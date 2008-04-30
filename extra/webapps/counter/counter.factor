USING: math kernel accessors http.server http.server.actions
http.server.sessions http.server.templating.fhtml locals ;
IN: webapps.counter

SYMBOL: count

TUPLE: counter-app < dispatcher ;

M: counter-app init-session*
    drop 0 count sset ;

:: <counter-action> ( quot -- action )
    <action> [
        count quot schange
        "" f <standard-redirect>
    ] >>display ;

: <display-action> ( -- action )
    <action> [
        "text/html" <content>
           "resource:extra/webapps/counter/counter.fhtml" <fhtml> >>body
    ] >>display ;

: <counter-app> ( -- responder )
    counter-app new-dispatcher
        [ 1+ ] <counter-action> "inc" add-responder
        [ 1- ] <counter-action> "dec" add-responder
        <display-action> "" add-responder
    <sessions> ;