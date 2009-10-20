! (c) 2009 Durian Software. See LICENSE for the goods
USING: accessors arrays assocs calendar combinators hashtables
io.directories io.encodings.utf8 io.files io.files.info
io.pathnames kernel locals math math.order math.parser memoize
sequences sorting strings xml.entities generalizations ;
IN: rowsdower

CONSTANT: dest-directory "vocab:rowsdower/out"
CONSTANT: source-directory "vocab:rowsdower/in"
CONSTANT: site-title "Rowsdower's Blog"
CONSTANT: site-root "http://rowsdower.example.ca/"

: articles-directory ( -- x ) source-directory resource-path "articles" append-path ;
: page-template-file ( -- x ) source-directory resource-path "template.html" append-path ;
: article-template-file ( -- x ) source-directory resource-path "article.html" append-path ;
: feed-template-file ( -- x ) source-directory resource-path "template.rss" append-path ;
: article-feed-template-file ( -- x ) source-directory resource-path "article.rss" append-path ;

TUPLE: article path title mtime ;

: filter-hidden ( seq -- seq' )
    [ "." head? not ] filter ;

: sort-by-mtime ( seq -- seq' )
    [ [ mtime>> ] compare invert-comparison ] sort ;

: <article> ( parent-path title -- article )
    [ append-path ] [ nip ] 2bi over file-info modified>> article boa ;
: articles ( dir -- x )
    dup directory-files filter-hidden [ <article> ] with map sort-by-mtime ;

: article-url ( article -- link )
    title>> H{ { CHAR: \s CHAR: - } } substitute ".html" append ;
: article-contents ( article -- contents )
    path>> utf8 file-contents ;

MEMO: template-contents ( template -- contents ) utf8 file-contents ;

: ${key} ( key -- ${key} )
    "${" "}" surround ;

:: subst-string ( string from to -- string' )
    string from string start
    [ [ head ] [ from length + tail ] 2bi [ to ] 2dip surround ] when* ;

: replace-template-arg ( template-contents key value -- template-contents' )
    [ ${key} ] dip subst-string ;

: expand-template ( template assoc -- string )
    [ template-contents ] dip [ replace-template-arg ] assoc-each ;

: unknown-zone ( gmt-offset -- string )
    [ number>string ] keep 0 > [ CHAR: + prefix ] when "GMT" prepend ;
    
: duration>timezone-name ( duration -- string )
    hour>> {
        { -5 [ "CDT" ] }
        { -6 [ "CST" ] }
        { -7 [ "PDT" ] }
        { -8 [ "PST" ] }
        [ unknown-zone ]
    } case ;

: format-time ( timestamp -- string )
    {
        [ month>>  month-name                              " " append ]
        [ day>>    number>string append                    ", " append ]
        [ year>>   number>string append                    " " append ]
        [ hour>>   number>string 2 CHAR: 0 pad-head append ":" append ]
        [ minute>> number>string 2 CHAR: 0 pad-head append ":" append ]
        [ second>> number>string 2 CHAR: 0 pad-head append " " append ]
        [ gmt-offset>> duration>timezone-name append ]
    } cleave ;

: format-time-rss ( timestamp -- string )
    0 hours convert-timezone
    {
        [ year>>   number>string 4 CHAR: 0 pad-head        "-" append ]
        [ month>>  number>string 2 CHAR: 0 pad-head append "-" append ]
        [ day>>    number>string 2 CHAR: 0 pad-head append "T" append ]
        [ hour>>   number>string 2 CHAR: 0 pad-head append ":" append ]
        [ minute>> number>string 2 CHAR: 0 pad-head append ":" append ]
        [ second>> number>string 2 CHAR: 0 pad-head append "+00:00" append ]
    } cleave ;

: article-template-args ( article -- assoc )
    {
        [ "TITLE" swap title>> 2array ]
        [ "DATE"  swap mtime>> format-time 2array ]
        [ "BODY"  swap article-contents 2array ]
        [ "URL"   swap article-url escape-quoted-string site-root prepend 2array ] 
    } cleave 4array >hashtable ;

: article-feed-template-args ( article -- assoc )
    {
        [ "TITLE" swap title>> escape-string 2array ]
        [ "DATE"  swap mtime>> format-time-rss 2array ]
        [ "BODY"  swap article-contents escape-string 2array ]
        [ "URL"   swap article-url escape-string site-root prepend 2array ] 
        [ "GUID"  swap article-url escape-string site-root prepend 2array ] 
    } cleave 5 narray >hashtable ;

: article-body ( article -- html )
    article-template-file swap article-template-args expand-template ;

: article-feed-body ( article -- rss )
    article-feed-template-file swap article-feed-template-args expand-template ;

: take ( seq n -- seq' ) over length min head ; inline

: index-body ( articles -- html )
     5 take [ article-body ] map concat ;

: feed-body ( articles -- rss )
     10 take [ article-feed-body ] map concat ;

: archive-entry ( article -- html )
    [ title>> ] [ article-url escape-quoted-string site-root prepend "<a href=\"" "\">" surround ] bi "</a>" surround ;

: archive-body ( articles -- html )
    [ archive-entry "<li>" "</li>\n" surround ] map concat
    "<ul class=\"archives\">" "</ul>\n" surround ;

: page-template-args ( title body -- assoc )
    [ "TITLE" swap 2array ] [ "BODY" swap 2array ] bi* 2array >hashtable ;
: feed-template-args ( body -- assoc )
    "BODY" swap 2array 1array >hashtable ;
: page ( title body -- html )
    [ page-template-file ] 2dip page-template-args expand-template ;
: feed ( body -- rss )
    feed-template-file swap feed-template-args expand-template ;

: index-page ( articles -- html )
    site-title swap index-body page ;
: archive-page ( articles -- html )
    site-title ": Archives" append swap archive-body page ;
: article-page ( article -- html )
    [ title>> site-title ": " append prepend ] [ article-body ] bi page ;
: feed-page ( articles -- html )
    feed-body feed ;

: write-dest-page ( page file -- )
    dest-directory resource-path swap append-path utf8 set-file-contents ;
: make-site ( -- )
    articles-directory articles {
        [ index-page "index.html" write-dest-page ]
        [ archive-page "archives.html" write-dest-page ]
        [ feed-page "index.rss" write-dest-page ]
        [ [ [ article-page ] [ article-url ] bi write-dest-page ] each ]
    } cleave ;

MAIN: make-site
