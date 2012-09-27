use 5.008003;
use strict;
use warnings;

package RT::Extension::PriorityAsString;

our $VERSION = '0.03';

=head1 NAME

RT::Extension::PriorityAsString - show priorities in RT as strings instead of numbers

=head1 SYNOPSIS

    # in RT config
    Set(@Plugins, qw(... RT::Extension::PriorityAsString ...));

    # in extension config

    # Specify a mapping between priority strings and the internal
    # numeric representation
    Set(%PriorityAsString, (Low => 0, Medium => 50, High => 100));

    # which order to display the priority strings
    # if you don't specify this, the strings in the PriorityAsString
    # hash will be sorted and displayed
    Set(@PriorityAsStringOrder, qw(Low Medium High));

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

require RT::Ticket;
package RT::Ticket;

=head2 PriorityAsString

Returns String: Various Ticket Priorities as either a string or integer

=cut

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

    my %map = RT->Config->Get('PriorityAsString');
    if ( my ($res) = grep $map{$_} == $priority, keys %map ) {
        return $res;
    }

    my @order = reverse grep defined && length, RT->Config->Get('PriorityAsStringOrder');
    @order = sort { $map{$b} <=> $map{$a} } keys %map
        unless @order;

    # XXX: not supported yet
    #my $show  = RT->Config->Get('PriorityAsStringShow') || 'string';

    foreach my $label ( @order ) {
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
