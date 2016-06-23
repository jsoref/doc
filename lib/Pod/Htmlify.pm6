unit module Pod::Htmlify;

use URI::Escape;

my %tm = q:w!
    < langle
    > rangle
    & amp
    % percent
    # hash
    - dash
    . dot
    ? question
    / slash
    \ blackslash
    " quote
    { lcurly
    } rcurly
    [ lbracket
    ] rbracket
    | pipe
    ^ caret
!;
sub english-for-tokens is export {
  $^a.comb.map({ %tm{$_} ?? "-%tm{$_}-" !! $_ })
     .join.subst(/'--'/, '-', :g)
     .subst: /^\-|\-<before \s>|<after \s>\-|\-$/, '', :g
};

#| Escape special characters in URLs if necessary
sub url-munge($_) is export {
    return $_ if m{^ <[a..z]>+ '://'};
    # this needs to do some magic unescaping
    # right now it ends up eating its own tail.
    #
    # it needs to cut off /type/ | /routine/
    # it needs to un-percent-escape
    # it needs to english-for-tokens
    # it needs to re-percent-escape
    if (m!^<[#]>(.*)!) {
        my $hash = $0;
        $hash = '#' ~ english-for-tokens $hash;
        return $hash;
    }
    if (m!(\/<-[/]>*\/)(<-[#]>*)[<[#]>(.*) || '']!) {
        my $base = $0;
        my $tail = $1;
        my $hash = $2;
        $tail = uri_unescape $tail;
        $tail = english-for-tokens $tail;
        $hash = $hash ?? '#' ~ english-for-tokens $hash !! '';
        my $r = $base ~ $tail ~ $hash;
        return $r;
    }
    my $escaped = uri_escape (english-for-tokens $_);
    return "/type/$escaped" if m/^<[A..Z]>/;
    return "/routine/$escaped" if m/^<[a..z]>|^<-alpha>*$/;
    # poor man's <identifier>
    if m/ ^ '&'( \w <[[\w'-]>* ) $/ {
        $escaped = uri_escape (english-for-tokens $0);
        return "/routine/$escaped";
    }
    return $_;
}

#| Return the footer HTML for each page
sub footer-html($pod-path) is export {
    my $footer = slurp 'template/footer.html';
    $footer.subst-mutate(/DATETIME/, ~DateTime.now.utc.truncated-to('seconds'));
    my $pod-url;
    my $gh-link = q[<a href='https://github.com/perl6/doc'>perl6/doc on GitHub</a>];
    if $pod-path eq "unknown" {
        $pod-url = "the sources at $gh-link";
    }
    else {
        $pod-url = "<a href='https://github.com/perl6/doc/raw/master/doc/$pod-path'>$pod-path\</a\> from $gh-link";
    }
    $footer.subst-mutate(/SOURCEURL/, $pod-url);
    state $source-commit = qx/git rev-parse --short HEAD/.chomp;
    $footer.subst-mutate(:g, /SOURCECOMMIT/, $source-commit);

    return $footer;
}

#| Return the SVG for the given file, without its XML header
sub svg-for-file($file) is export {
    join "\n", grep { /^'<svg'/ ff False }, $file.IO.lines;
}

# vim: expandtab shiftwidth=4 ft=perl6
