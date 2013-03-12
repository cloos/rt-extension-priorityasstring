use 5.008003;
use strict;
use warnings;

package RT::Extension::PriorityAsString;

our $VERSION = '0.04_02';

=head1 NAME

RT::Extension::PriorityAsString - show priorities in RT as strings instead of numbers

=head1 SYNOPSIS

    # in RT config
    Set(@Plugins, qw(... RT::Extension::PriorityAsString ...));

    # in extension config

    # Specify a mapping between priority strings and the internal
    # numeric representation
    Set(%PriorityAsString, (Low => 0, Medium => 50, High => 100));

    # Fine-tuned control of the order of priorities as displayed in the
    # drop-down box; usually this computed automatically and need not be
    # set explicitly.  It can be used to limit the set of options
    # presented during update, but allow a richer set of levels when
    # they are adjusted automatically.
    # Set(@PriorityAsStringOrder, qw(Low Medium High));

    # Uncomment if you want to apply different configurations to
    # different queues.  Each key is the name of a different queue;
    # queues which do not appear in this configuration will use RT's
    # default numeric scale.
    # This option means that %PriorityAsString and
    # @PriorityAsStringOrder are ignored (no global override, you must
    # specify a set of priorities per queue). You can safely leave them
    # out of your RT_SiteConfig.pm to avoid confusion.
    # Set(%PriorityAsStringQueues,
    #    General => { Low => 0, Medium => 50, High => 100 },
    #    Binary  => { Low => 0, High => 10 },
    # );

=head1 INSTALLATION

*NOTE* that it only works with RT 3.8.3 and newer.

    perl Makefile.PL
    make
    make install (may need root permissions)

    Edit your /opt/rt3/etc/RT_SiteConfig.pm (example is in synopsis above)

    Edit your /opt/rt3/local/plugins/RT-Extension-PriorityAsString/etc/PriorityAsString_Config.pm
    and change the defaults

    rm -rf /opt/rt3/var/mason_data/obj
    Restart your webserver

=cut

use RT;
RT->AddStyleSheets('priorityasstring.css');

require RT::Ticket;
package RT::Ticket;

$RT::Config::META{PriorityAsString}{Type} = 'HASH';
$RT::Config::META{PriorityAsStringOrder}{Type} = 'ARRAY';
$RT::Config::META{PriorityAsStringQueues}{Type} = 'HASH';


# Returns String: Various Ticket Priorities as either a string or integer
sub PriorityAsString {
    my $self = shift;
    return $self->_PriorityAsString($self->Priority);
}

sub InitialPriorityAsString {
    my $self = shift;
    return $self->_PriorityAsString( $self->InitialPriority );
}

sub FinalPriorityAsString {
    my $self=shift;
    return $self->_PriorityAsString( $self->FinalPriority );
}

sub _PriorityAsString {
    my $self = shift;
    my $priority = shift;
    return undef unless defined $priority && length $priority;

    my %map;
    my $queues = RT->Config->Get('PriorityAsStringQueues');
    if (@_) {
        %map = %{ shift(@_) };
    } elsif ($queues and $queues->{$self->QueueObj->Name}) {
        %map = %{ $queues->{$self->QueueObj->Name} };
    } else {
        %map = RT->Config->Get('PriorityAsString');
    }

    # Count from high down to low until we find one that our number is
    # greater than or equal to.
    foreach my $label ( sort { $map{$b} <=> $map{$a} } keys %map ) {
        return $label if $priority >= $map{ $label };
    }
    return "unknown";
}

use RT::Transaction;
$RT::Transaction::_BriefDescriptions{'Set'} = sub {
    my $self = shift;
    if ( $self->Field eq 'Password' ) {
        return $self->loc('Password changed');
    }
    elsif ( $self->Field eq 'Queue' ) {
        my $q1 = RT::Queue->new( $self->CurrentUser );
        $q1->Load( $self->OldValue );
        my $q2 = RT::Queue->new( $self->CurrentUser );
        $q2->Load( $self->NewValue );
        return $self->loc("[_1] changed from [_2] to [_3]",
            $self->loc($self->Field) , $q1->Name , $q2->Name);
    }

    # Write the date/time change at local time:
    elsif ($self->Field =~ /Due|Starts|Started|Told/) {
        my $t1 = RT::Date->new($self->CurrentUser);
        $t1->Set(Format => 'ISO', Value => $self->NewValue);
        my $t2 = RT::Date->new($self->CurrentUser);
        $t2->Set(Format => 'ISO', Value => $self->OldValue);
        return $self->loc( "[_1] changed from [_2] to [_3]", $self->loc($self->Field), $t2->AsString, $t1->AsString );
    }
    elsif ( $self->Field eq 'Owner' ) {
        my $Old = RT::User->new( $self->CurrentUser );
        $Old->Load( $self->OldValue );
        my $New = RT::User->new( $self->CurrentUser );
        $New->Load( $self->NewValue );

        if ( $Old->id == RT->Nobody->id ) {
            if ( $New->id == $self->Creator ) {
                return $self->loc("Taken");
            }
            else {
                return $self->loc( "Given to [_1]",  $New->Name );
            }
        }
        else {
            if ( $New->id == $self->Creator ) {
                return $self->loc("Stolen from [_1]",  $Old->Name);
            }
            elsif ( $Old->id == $self->Creator ) {
                if ( $New->id == RT->Nobody->id ) {
                    return $self->loc("Untaken");
                }
                else {
                    return $self->loc( "Given to [_1]", $New->Name );
                }
            }
            else {
                return $self->loc(
                    "Owner forcibly changed from [_1] to [_2]",
                    $Old->Name, $New->Name );
            }
        }
    }

    # show priority as string
    elsif ($self->Field =~ /Priority|InitialPriority|FinalPriority/) {
        return $self->loc( "[_1] changed from [_2] to [_3]",
            $self->loc($self->Field),
            "'" . $self->loc($self->TicketObj->_PriorityAsString($self->OldValue)) . "'",
            "'" . $self->loc($self->TicketObj->_PriorityAsString($self->NewValue)) . "'");
    }
    else {
        return $self->loc( "[_1] changed from [_2] to [_3]",
            $self->loc($self->Field),
                ($self->OldValue? "'".$self->OldValue ."'" : $self->loc("(no value)")) , "'". $self->NewValue."'" );
    }
};

=head1 COPYRIGHT AND LICENCE

Copyright (C) 2008, Best Practical Solutions LLC.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Ruslan Zakirov E<lt>ruz@bestpractical.comE<gt>

=cut

1;
