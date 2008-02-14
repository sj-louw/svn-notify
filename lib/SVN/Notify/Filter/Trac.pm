package SVN::Notify::Filter::Trac;

# $Id$

use strict;
use Text::Trac;
use SVN::Notify;

=begin comment

Fake out Test::Pod::Coverage.

=head3 log_message

=end comment

=cut

SVN::Notify->register_attributes(
    trac_url => 'trac-url=s',
);

sub log_message {
    my $notify = shift;
    my $trac = Text::Trac->new(
        trac_url => $notify->trac_url,
    );
    $trac->parse(  join $/, @{ +shift } );
    return [ $trac->html ];
}

1;

=head1 Name

SVN::Notify::Filter::Trac - Filter SVN::Notify output in Trac format

=head1 Synopsis

Use F<svnnotify> in F<post-commit>:

  svnnotify --p "$1" --r "$2" --handler HTML --filter Trac \
  --trac-url http://trac.example.com

Use the class in a custom script:

  use SVN::Notify;

  my $notifier = SVN::Notify->new(
      repos_path => $path,
      revision   => $rev,
      handler    => 'HTML::ColorDiff',
      filter     => [ 'Trac' ],
      trac_url   => 'http://trac.example.com/',
  );
  $notifier->prepare;
  $notifier->execute;

=head1 Description

This module filters SVN::Notify log message output from Trac markup into HTML.
Essentially, this means that if you write your commit log messages using Trac
wiki markup and like to use L<SVN::Notify::HTML|SVN::Notify::HTML> or
L<SVN::Notify::HTML::ColorDiff|SVN::Notify::HTML::ColorDiff> to format your
commit notifications, you can use this filter to convert the Trac formatting
in the log message to HTML.

If you specify an extra argument, C<trac_url> (or the C<--trac-url> parameter
to C<svnnotify>), it will be used to generate Trac links for revision numbers
and the like in your log messages.

=head1 See Also

=over

=item L<SVN::Notify|SVN::Notify>

=item L<svnnotify|svnnotify>

=back

=head1 Author

David Wheeler <david@kineticode.com>

=head1 Copyright and License

Copyright (c) 2008 Kineticode, Inc. All Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut