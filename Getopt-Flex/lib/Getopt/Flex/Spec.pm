package Getopt::Flex::Spec;

use Moose;
use Getopt::Flex::Spec::Argument;
use MooseX::StrictConstructor;

#the raw specification            
has 'spec' => ( is => 'ro',
                isa => 'HashRef[HashRef[Str|CodeRef|ScalarRef|ArrayRef|HashRef]]',
                required => 1,
            );

#maps the various argument aliases onto their argument object
has '_argmap' => ( is => 'rw',
                   isa => 'HashRef[Getopt::Flex::Spec::Argument]',
                   default => sub { {} },
                   init_arg => undef,
                );
                
sub BUILD {
    my ($self) = @_;
    
    my $spec = $self->spec();
    
    my $argmap = $self->_argmap();
    foreach my $switch_spec (keys %{$spec}) {
        $spec->{$switch_spec}->{'switchspec'} = $switch_spec;
        
        my $argument = Getopt::Flex::Spec::Argument->new($spec->{$switch_spec});
        
        my @aliases = @{$argument->aliases()};
        foreach my $alias (@aliases) {
            #no duplicate aliases (or primary names) allowed
            if(defined($argmap->{$alias})) {
                my $sp = $argmap->{$alias}->switchspec();
                confess "alias $alias given by spec $switch_spec already exists and belongs to spec $sp\n";
            }
            $argmap->{$alias} = $argument;
        }
    }
    $self->_argmap($argmap);
}

#one of our switches?
sub check_switch {
    my ($self, $switch) = @_;
    
    return defined($self->_argmap()->{$switch});
}

sub set_switch {
    my ($self, $switch, $val) = @_;
    
    confess "No such switch $switch\n" if !$self->check_switch($switch);
    
    return $self->_argmap()->{$switch}->set_value($val);
}

sub switch_requires_val {
    my ($self, $switch) = @_;
    
    confess "No such switch $switch\n" if !$self->check_switch($switch);
    
    return $self->_argmap()->{$switch}->requires_val($switch);
}

no Moose;

1;
