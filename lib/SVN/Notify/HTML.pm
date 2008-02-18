package SVN::Notify::HTML;

# $Id$

use strict;
use HTML::Entities;
use SVN::Notify ();

$SVN::Notify::HTML::VERSION = '2.70';
@SVN::Notify::HTML::ISA = qw(SVN::Notify);

__PACKAGE__->register_attributes(
    linkize   => 'linkize',
    css_url   => 'css-url=s',
    wrap_log  => 'wrap-log',
);

=head1 Name

SVN::Notify::HTML - Subversion activity HTML notification

=head1 Synopsis

Use F<svnnotify> in F<post-commit>:

  svnnotify --repos-path "$1" --revision "$2" \
    --to developers@example.com --handler HTML [options]

Use the class in a custom script:

  use SVN::Notify::HTML;

  my $notifier = SVN::Notify::HTML->new(%params);
  $notifier->prepare;
  $notifier->execute;

=head1 Description

This subclass of L<SVN::Notify|SVN::Notify> sends HTML formatted email
messages for Subversion activity, rather than the default plain text.

=head1 Prerequisites

In addition to the modules required by SVN::Notify, this class requires:

=over

=item HTML::Entities

=back

=head1 Usage

To use SVN::Notify::HTML, simply follow the L<instructions|SVN::Notify/Usage>
in SVN::Notify, but when using F<svnnotify>, specify C<--handler HTML>.

=cut

##############################################################################

=head1 Class Interface

=head2 Constructor

=head3 new

  my $notifier = SVN::Notify::HTML->new(%params);

Constructs and returns a new SVN::Notify object. All parameters supported by
SVN::Notity are supported here, but SVN::Notify::HTML supports a few
additional parameters:

=over

=item linkize

  svnnotify --linkize

A boolean attribute to specify whether or not to "linkize" the SVN log
message--that is, to turn any URLs or email addresses in the log message into
links.

=item css_url

  svnnotify --css-url http://example.com/svnnotify.css

URL for a CSS file that will can style the HTML output by SVN::Notify::HTML or
its subclasses. Note that the URL will be added to the output via a
C<< <link rel="stylesheet"> >> tag I<after> the CSS generated by
SVN::Notify::HTML or its subclasses. What that means is that the CSS file
specified by C<css_url> need not completely style the HTML, but simply
override the default settings. This approach nicely takes advantage of the
"cascading" abilities of CSS.

=item ticket_map

  svnnotify --ticket-map '(BUG-(\d+))=http://bugs.example.com/?show=%s'

This attribute is inherited from L<SVN::Notify|SVN::Notify>, but its semantics
are slightly different: the regular expression passed as the regular
expression used for the key should return I<two> matches instead of one: the
text to linkify and the ticket ID itself. For example, '(BUG-(\d+))' will
match "BUG-1234567", and "BUG-1234567" will be used for the link text, while
"1234567" will be used to fill in the C<ticket_url> format string. The first
set of parentheses capture the whole string, while the parentheses around
C<\d+> match the number only. Also note that it is wise to use "\b" on either
side of the regular expression to insure that you don't get spurious matches.
So a better version would be '\b(BUG-(\d+))\b'.

As a fallback, if your regular expression returns only a single match string,
it will be used both for the link text and for the the ticket URL generated
from C<ticket_url>. For example, '\bBUG-(\d+)\b' would make a link only of the
number in 'BUG-1234567', as only the number has been captured by the regular
expression. But two matches are of course recommended (and likely to work
better, as well).

You can use more complicated regular expressions if commit messages are likely
to format ticket numbers in various ways. For example, this regular
expression:

  \b\[?\s*(Ticket\s*#\s*(\d+))\s*\]?\b'

Will match:

   String Matched           Link Text        Ticket Number
  --------------------|--------------------|---------------
   [Ticket#1234]         [Ticket#1234]       1234
   [ Ticket # 1234 ]     [ Ticket # 1234 ]   1234
   Ticket #1234          Ticket #1234        1234
   Ticket # 1234         Ticket  #1234       1234

In any of these cases, you can see that the match is successful, properly
creates the link text (simply using the text as typed in by the committer, and
correctly extracts the ticket number for use in the URL.

To learn more about the power of Regular expressions, I highly recommend
_Mastering Regular Expressions, Second Edition_, by Jeffrey Friedl.

=item wrap_log

  svnnotify --wrap-log

A boolean attribute to specify whether or not to wrap the log message in the
output HTML. By default, log messages are I<not> wrapped, on the assumption
that they should appear exactly as typed. But if that's not the case, specify
this option to wrap the log message.

=back

=cut

##############################################################################

=head2 Class Methods

=head3 content_type

Returns the content type of the notification message, "text/html". Used to set
the Content-Type header for the message.

=cut

sub content_type { 'text/html' }

##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 start_html

  $notifier->start_html($file_handle);

This method starts the HTML of the notification message. It outputs the
opening C<< <html> >>, C<< <head> >>, and C<< <body> >> tags. Note that if the
C<language> attribute is set to a value, it will be specified in the
C<< <html> >> tag.

All of the HTML will be passed to any "start_html" output filters. See
L<Writing Output Filters|SVN::Notify/"Writing Output Filters"> for details on
filters.

=cut

sub start_html {
    my ($self, $out) = @_;
    my $lang = $self->language;
    my $char = lc $self->charset;

    my @html = (
        qq{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"\n},
        qq{"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">\n},
        qq{<html xmlns="http://www.w3.org/1999/xhtml"},
        ($lang ? qq{ xml:lang="$lang"} : ()),
        qq{>\n<head><meta http-equiv="content-type" content="text/html; },
        qq{charset=$char" />\n},
        ( $self->{css_url}
              ? (
                  '<link rel="stylesheet" type="text/css" href="',
                  encode_entities($self->{css_url}),
                  qq{" />\n}
              ) : ()
        ),
        '<title>', encode_entities($self->subject, '<>&"'),
        qq{</title>\n</head>\n<body>\n\n}
    );

    print $out @{ $self->run_filters( start_html => \@html ) };
    return $self;
}

##############################################################################

=head3 start_body

This method starts the body of the HTML notification message. It first calls
C<start_html()>, and then outputs the C<< <style> >> tag, calling
C<output_css()> between them. It then outputs an opening C<< <div> >> tag.

If the C<header> attribute is set, C<start_body()> outputs it between
C<< <div> >> tags with the ID "header". Furthermore, if the header happens to
start with the character "E<lt>", C<start_body()> assumes that it contains
valid HTML and therefore will not escape it.

If a "start_body" output filter has been specified, it will be passed the
lines with the C<< <div> >> tag and the header. To filter the CSS, use a "css"
filter, and to filter the declaration of the HTML document and its C<< <head>
>> section, use a "start_html" filter. See L<Writing Output
Filters|SVN::Notify/"Writing Output Filters"> for details on filters.

=cut

sub start_body {
    my ($self, $out) = @_;
    $self->start_html($out);
    print $out qq{<style type="text/css"><!--\n};
    $self->output_css( $out );
    print $out qq{--></style>\n};

    my @html = ( qq{<div id="msg">\n} );
    if (my $header = $self->header) {
        push @html, (
            '<div id="header">',
            ( $header =~ /^</  ? $header : encode_entities($header, '<>&"') ),
            "</div>\n",
        );
    }

    print $out @{ $self->run_filters( start_body => \@html ) };
    return $self;
}

##############################################################################

=head3 output_css

  $notifier->output_css($file_handle);

This method starts outputs the CSS for the HTML message. It is called by
C<start_body()>, and which wraps the output of C<output_css()> in the
appropriate C<< <style> >> tags.

An output filter named "css" may be added to modify the output of CSS. The
filter subrutine name should be C<css> and expect an array reference of lines
of CSS. See L<Writing Output Filters|SVN::Notify/"Writing Output Filters"> for
details on filters.

=cut

sub output_css {
    my ($self, $out) = @_;
    # We use _css() so that ColorDiff can override it and the filters then
    # applied only one to all of the CSS.
    print $out @{ $self->run_filters( css => $self->_css ) };
    return $self;
}

##############################################################################

=head3 output_metadata

  $notifier->output_metadata($file_handle);

This method outputs a definition list containting the metadata of the commit,
including the revision number, author (user), and date of the revision. If the
C<revision_url> attribute has been set, then the appropriate URL for the
revision will be used to turn the revision number into a link.

If there are any C<log_message> filters, this method will do no HTML
formatting, but redispatch to
L<SVN::Notify::output_metadata|SVN::Notify/"output_metadata">. See L<Writing
Output Filters|SVN::Notify/"Writing Output Filters"> for details on filters.

=cut

sub output_metadata {
    my ($self, $out) = @_;
    if ( $self->filters_for('metadata') ) {
        return $self->SUPER::output_metadata($out);
    }

    $self->print_lines($out, "<dl>\n<dt>Revision</dt> <dd>");

    my $rev = $self->revision;
    if (my $url = $self->revision_url) {
        $url = encode_entities($url, '<>&"');
        # Make the revision number a URL.
        printf $out qq{<a href="$url">$rev</a>}, $rev;
    } else {
        # Just output the revision number.
        print $out $rev;
    }

    # Output the committer and a URL, if there is one.
    print $out "</dd>\n<dt>Author</dt> <dd>";
    my $user = encode_entities($self->user, '<>&"');
    if (my $url = $self->author_url) {
        $url = encode_entities($url, '<>&"');
        printf $out qq{<a href="$url">$user</a>}, $user;
    } else {
        # Just output the username
        print $out $user;
    }

    $self->print_lines(
        $out,
        "</dd>\n",
        '<dt>Date</dt> <dd>',
        encode_entities($self->date, '<>&"'), "</dd>\n",
        "</dl>\n\n"
    );

    return $self;
}

##############################################################################

=head3 output_log_message

  $notifier->output_log_message($file_handle);

Outputs the commit log message in C<< <pre> >> tags, and the label "Log
Message" in C<< <h3> >> tags. If the C<bugzilla_url> attribute is set, then
any strings like "Bug 2" or "bug # 567" will be turned into links.

If there are any C<log_message> filters, the filters will be assumed to escape
the HTML, linkize, and link ticket URLs. Otherwise, this method will do those
things. See L<Writing Output Filters|SVN::Notify/"Writing Output Filters">
for details on filters.

=cut

sub output_log_message {
    my ($self, $out) = @_;
    $self->_dbpnt( "Outputting log message as HTML") if $self->verbose > 1;

    # Assemble the message.
    my $msg;
    my $filters = $self->filters_for('log_message');
    if ( $filters ) {
        $msg = join(
            "\n",
            @{ $self->run_filters( log_message => [ @{ $self->message } ] ) }
        );
    } else {
        $msg = encode_entities( join( "\n", @{ $self->message } ), '<>&"');

        # Turn URLs and email addresses into links.
        if ($self->linkize) {
            # These regular expressions modified from "Mastering Regular
            # Expressions" 2ed., pp 70-75.

            # Make email links.
            $msg =~ s{\b(\w[-.\w]*\@[-a-z0-9]+(?:\.[-a-z0-9]+)*\.[-a-z0-9]+)\b}
                     {<a href="mailto:$1">$1</a>}gi;

            # Make URLs linkable.
            $msg =~ s{\b([a-z0-9]+://[-a-z0-9]+(?:\.[-a-z0-9]+)*\.[-a-z0-9]+\b(?:/(?:[-a-z0-9_:\@?=+,.!/~*I'%\$]|&amp;)*(?<![.,?!]))?)}
                     {<a href="$1">$1</a>}gi;
        }

        # Make Revision links.
        if (my $url = $self->revision_url) {
            $url = encode_entities($url, '<>&"');
            $msg =~ s|\b(rev(?:ision)?\s*#?\s*(\d+))\b|sprintf qq{<a href="$url">$1</a>}, $2|ige;
        }

        # Make ticketing system links.
        if (my $map = $self->ticket_map) {
            $self->run_ticket_map ( sub {
                my ($regex, $url) = @_;
                $url = encode_entities($url, '<>&"');
                $msg =~ s{$regex}{ sprintf qq{<a href="$url">$1</a>}, $2 || $1 }ige;
            });
        }
    }

    $self->print_lines( $out, "<h3>Log Message</h3>\n" );
    if ($filters || $self->wrap_log) {
        $msg = join( "</p>\n\n<p>", '<p>', split( /\n\s*\n/, $msg ), '</p>' )
            if !$filters && $self->wrap_log;
        $self->print_lines(
            $out,
            qq{<div id="logmsg">\n},
            $msg,
            qq{</div>\n\n},
        )
    } else {
        $self->print_lines( $out, "<pre>$msg</pre>\n\n" );
    }
    return $self;
}

##############################################################################

=head3 output_file_lists

  $notifier->output_log_message($file_handle);

Outputs the lists of modified, added, deleted, files, as well as the list of
files for which properties were changed as unordered lists. The labels used
for each group are pulled in from the C<file_label_map()> class method and
output in C<< <h3> >> tags.

If there are any C<file_lists> filters, this method will do no HTML
formatting, but redispatch to
L<SVN::Notify::output_file_lists|SVN::Notify/"output_file_lists">. See
L<Writing Output Filters|SVN::Notify/"Writing Output Filters"> for details on
filters.

=cut

sub output_file_lists {
    my ($self, $out) = @_;
    my $files = $self->files or return $self;

    if ( $self->filters_for('file_lists') ) {
        return $self->SUPER::output_file_lists($out);
    }

    my $map = $self->file_label_map;
    # Create the lines that will go underneath the above in the message.
    my %dash = ( map { $_ => '-' x length($map->{$_}) } keys %$map );

    foreach my $type (qw(U A D _)) {
        # Skip it if there's nothing to report.
        next unless $files->{$type};

        # Identify the action and output each file.
        print $out "<h3>$map->{$type}</h3>\n<ul>\n";
        if ($self->with_diff && !$self->attach_diff) {
            for (@{ $files->{$type} }) {
                my $file = encode_entities($_, '<>&"');
                if ($file =~ m{/$} && $type ne '_') {
                    # Directories don't link, unless it's a prop change.
                    print $out qq{<li>$file</li>\n};
                } else {
                    # Strip out letters illegal for IDs.
                    (my $id = $file) =~ s/[^\w_]//g;
                    print $out qq{<li><a href="#$id">$file</a></li>\n};
                }
            }
        } else {
            print $out "  <li>" . encode_entities($_, '<>&"') . "</li>\n"
              for @{ $files->{$type} };
        }
        print $out "</ul>\n\n";
    }
}

##############################################################################

=head3 end_body

  $notifier->end_body($file_handle);

Closes out the body of the email by outputting the closing C<< </body> >> and
C<< </html> >> tags. Designed to be called when the body of the message is
complete, and before any call to C<output_attached_diff()>.

If the C<footer> attribute is set, C<end_body()> outputs it between
C<< <div> >> tags with the ID "footer". Furthermore, if the footer happens to
end with the character "E<lt>", C<end_body()> assumes that it contains valid
HTML and therefore will not escape it.

All of the HTML will be passed to any "end_body" output filters. See L<Writing
Output Filters|SVN::Notify/"Writing Output Filters"> for details on filters.

=cut

sub end_body {
    my ($self, $out) = @_;
    $self->_dbpnt( "Ending body") if $self->verbose > 2;
    my @html;
    if (my $footer = $self->footer) {
        push @html, (
            '<div id="footer">',
            ( $footer =~ /^</  ? $footer : encode_entities($footer, '<>&"') ),
            "</div>\n",
        );
    }
    push @html, "\n</div>" unless $self->with_diff && !$self->attach_diff;
    push @html, "\n</body>\n</html>\n";

    print $out @{ $self->run_filters( end_body => \@html ) };
    return $self;
}

##############################################################################

=head3 output_diff

  $notifier->output_diff($out_file_handle, $diff_file_handle);

Sends the output of C<svnlook diff> to the specified file handle for inclusion
in the notification message. The diff is output between C<< <pre> >> tags, and
Each line of the diff file is escaped by C<HTML::Entities::encode_entities()>.
The diff data will be read from C<$diff_file_handle> and printed to
C<$out_file_handle>.

If there are any C<diff> filters, this method will do no HTML formatting, but
redispatch to L<SVN::Notify::output_diff|SVN::Notify/"output_diff">. See
L<Writing Output Filters|SVN::Notify/"Writing Output Filters"> for details on
filters.

=cut

sub output_diff {
    my ($self, $out, $diff) = @_;
    if ( $self->filters_for('diff') ) {
        return $self->SUPER::output_diff($out, $diff);
    }

    $self->_dbpnt( "Outputting HTML diff") if $self->verbose > 1;

    print $out qq{</div>\n<div id="patch"><pre>\n};
    my ($length, %seen) = 0;
    my $max = $self->max_diff_length;

    while (<$diff>) {
        if (!$max || ($length += length) < $max) {
            s/[\n\r]+$//;
            if (/^(Modified|Added|Deleted|Copied|Property changes on): (.*)/
                    && !$seen{$2}++) {
                my $action = $1;
                my $file = encode_entities($2, '<>&"');
                (my $id = $file) =~ s/[^\w_]//g;
                print $out qq{<a id="$id">$action: $file</a>\n};
            }
            else {
                $self->print_lines($out, encode_entities($_, '<>&"'), "\n");
            }
        } else {
            print $out
                "\n\@\@ Diff output truncated at $max characters. \@\@\n";
            last;
        }

    }
    print $out "</pre></div>\n";

    close $diff or warn "Child process exited: $?\n";
    return $self;
}

##############################################################################

=head2 Accessors

In addition to those supported by L<SVN::Notify|SVN::Notify/Accessors>,
SVN::Notify::HTML supports the following accessors:

=head3 linkize

  my $linkize = $notifier->linkize;
  $notifier = $notifier->linkize($linkize);

Gets or sets the value of the C<linkize> attribute.

=head3 css_url

  my $css_url = $notifier->css_url;
  $notifier = $notifier->css_url($css_url);

Gets or sets the value of the C<css_url> attribute.

=cut

##############################################################################

sub _css {
    return [
        q(#msg dl { border: 1px #006 solid; background: #369; ),
            qq(padding: 6px; color: #fff; }\n),
        qq(#msg dt { float: left; width: 6em; font-weight: bold; }\n),
        qq(#msg dt:after { content:':';}\n),
        q(#msg dl, #msg dt, #msg ul, #msg li, #header, #footer { font-family: ),
            qq(verdana,arial,helvetica,sans-serif; font-size: 10pt;  }\n),
        qq(#msg dl a { font-weight: bold}\n),
        qq(#msg dl a:link    { color:#fc3; }\n),
        qq(#msg dl a:active  { color:#ff0; }\n),
        qq(#msg dl a:visited { color:#cc6; }\n),
        q(h3 { font-family: verdana,arial,helvetica,sans-serif; ),
            qq(font-size: 10pt; font-weight: bold; }\n),
        q(#logmsg { background: #ffc; border: 1px #fc0 solid; padding: 0 6px; ),
            q(font-family: verdana,arial,helvetica,sans-serif; ),
            qq(font-size: 10pt; }\n),
        q(#msg pre { overflow: auto; background: #ffc; ),
            qq(border: 1px #fc0 solid; padding: 6px; }\n),
        qq(#msg ul { overflow: auto; }\n),
        q(#header, #footer { color: #fff; background: #636; ),
        qq(border: 1px #300 solid; padding: 6px; }\n),
        qq(#patch { width: 100%; }\n),
    ];
}

1;
__END__

=head1 See Also

=over

=item L<SVN::Notify|SVN::Notify>

=back

=head1 Author

David E. Wheeler <david@kineticode.com>

=head1 Copyright and License

Copyright (c) 2004-2008 Kineticode, Inc. All Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
