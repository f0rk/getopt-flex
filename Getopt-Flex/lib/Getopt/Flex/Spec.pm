package Getopt::Flex::Spec;

# ABSTRACT: Getopt::Flex's way of handling an option spec

use Moose;
use Getopt::Flex::Spec::Argument;
use MooseX::StrictConstructor;

#the raw specification            
has 'spec' => (
    is => 'ro',
    isa => 'HashRef[HashRef[Str|CodeRef|ScalarRef|ArrayRef|HashRef]]',
    required => 1,
);

#maps the various argument aliases onto their argument object
has '_argmap' => (
    is => 'rw',
    isa => 'HashRef[Getopt::Flex::Spec::Argument]',
    default => sub { {} },
    init_arg => undef,
);
                
=head1 NAME

Getopt::Flex::Spec - Specification class for Getopt::Flex

=head1 DESCRIPTION

This class is only meant to be used by Getopt::Flex
and should not be used directly.

=head1 METHODS

=cut
                
sub BUILD {
    my ($self) = @_;
    
    my $spec = $self->spec();
    
    my $argmap = $self->_argmap();
    
    #create each argument in turn
    foreach my $switch_spec (keys %{$spec}) {
        $spec->{$switch_spec}->{'switchspec'} = $switch_spec;
        
        my $argument = Getopt::Flex::Spec::Argument->new($spec->{$switch_spec});
        
        my @aliases = @{$argument->aliases()};
        
        #map each argument onto its aliases
        foreach my $alias (@aliases) {
            #no duplicate aliases (or primary names) allowed
            if(defined($argmap->{$alias})) {
                my $sp = $argmap->{$alias}->switchspec();
                Carp::confess "alias $alias given by spec $switch_spec already exists and belongs to spec $sp\n";
            }
            $argmap->{$alias} = $argument;
        }
    }
    $self->_argmap($argmap);
}

=head2 check_switch

Check whether or a not a switch belongs to this specification

=cut

sub check_switch {
    my ($self, $switch) = @_;
    return defined($self->_argmap()->{$switch});
}

=head2 set_switch

Set a switch to the supplied value

=cut

sub set_switch {
    my ($self, $switch, $val) = @_;
    
    Carp::confess "No such switch $switch\n" if !$self->check_switch($switch);
    
    return $self->_argmap()->{$switch}->set_value($val);
}

=head2 switch_requires_val

Check whether or not a switch requires a value

=cut

sub switch_requires_val {
    my ($self, $switch) = @_;
    
    Carp::confess "No such switch $switch\n" if !$self->check_switch($switch);
    
    return $self->_argmap()->{$switch}->requires_val();
}

=head2 get_switch_error

Given a switch return any associated error message.

=cut

sub get_switch_error {
    my ($self, $switch) = @_;
    
    Carp::confess "No such switch $switch\n" if !$self->check_switch($switch);
    
    return $self->_argmap()->{$switch}->error();
}

=begin Pod::Coverage

  BUILD

=end Pod::Coverage

=cut

no Moose;

1;
