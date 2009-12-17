package Getopt::Flex::Spec::Argument;

use Carp;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::StrictConstructor;
use Perl6::Junction qw(any none);

#types an argument know how to be
enum 'ValidType' => qw(Bool Str Num Int ArrayRef[Str] ArrayRef[Num] ArrayRef[Int] HashRef[Str] HashRef[Num] HashRef[Int] Inc);

#special type for an incremental argument
subtype 'Inc'
            => as 'Int';

#special type defining what a switch spec should look like            
subtype 'SwitchSpec'
            => as 'Str'
            => where { $_ =~ m/^[a-zA-Z0-9|_?-]+$/ && $_ !~ m/\|\|/ };

#special type defining what a parsed  switch should look like          
subtype 'Switch'
            => as 'Str'
            => where { $_ =~ m/^[a-zA-Z0-9_?-]+$/ };

#the argument specification supplied
has 'switchspec' => ( is => 'ro',
                      isa => 'SwitchSpec',
                      required => 1,
                    );

#the primary name of this switch
has 'primary_name' => ( is => 'ro',
                        isa => 'Switch',
                        writer => '_set_primary_name',
                        init_arg => undef,
                    );

#any aliases this switch has
has 'aliases' => ( is => 'ro',
                   isa => 'ArrayRef[Switch]',
                   writer => '_set_aliases',
                   init_arg => undef,
                );

#the reference to the variable to populate when this switch is found
has 'var' => ( is => 'ro',
               isa => 'ScalarRef|ArrayRef|HashRef',
               required => 1,
            );

#the type of values to accept for this variable                
has 'type' => ( is => 'ro',
                isa => 'ValidType',
                required => 1,
            );

#the description of this variable, for autohelp
has 'description' => ( is => 'ro',
                       isa => 'Str',
                       default => '',
                    );

#whether or not this switch must be found
has 'required' => ( is => 'ro',
                    isa => 'Int',
                    default => 0,
                );

#a function to call to validate the value found by this switch
has 'validator' => ( is => 'ro',
                     isa => 'CodeRef',
                     predicate => 'has_validator',
                );

#a function to call whenever this switch is found, passing in the
#value found, if any
has 'callback' => ( is => 'ro',
                    isa => 'CodeRef',
                );

#default to populate the provided variable reference with
has 'default' => ( is => 'ro',
                   isa => 'Str|ArrayRef|HashRef|CodeRef',
                   predicate => 'has_default',
                   writer => '_set_default',
                );
                
has '_set' => ( is => 'rw',
                isa => 'Int',
                init_arg => undef,
                default => 0,
                predicate => 'is_set',
            );
                
sub BUILD {
    my ($self) = @_;
    
    my $reft = ref($self->var());
    if($reft eq none(qw(ARRAY HASH SCALAR))) {
        confess "supplied var must be a reference to an ARRAY, HASH, or SCALAR\n";
    }
    
    if($reft eq any(qw(ARRAY HASH))) {
        my $re = qr/$reft/i;
        
        if($self->type() !~ $re) {
            my $type = $self->type();
            confess "supplied var has wrong type $type\n";
        }
    }
    
    if($self->has_default() && find_type_constraint('CodeRef')->check($self->default())) {
        my $fn = $self->default();
        $self->_set_default(&$fn());
    }
    
    if($self->has_default() && !Moose::Util::TypeConstraints::find_or_parse_type_constraint($self->type())->check($self->default())) {
        my $def = $self->default();
        my $type = $self->type();
        confess "default $def fails type constraint $type\n";
    }
    
    if($self->has_default() && $self->has_validator()) {
        my $fn = $self->validator();
        if(!&$fn($self->default())) {
            my $def = $self->default();
            confess "default $def fails supplied validation check\n";
        }
    }
    
    my @aliases = split(/\|/, $self->switchspec);
    
    $self->_set_primary_name($aliases[0]);
    $self->_set_aliases(\@aliases);
}

sub set_value {
    my ($self, $val) = @_;
    
    $self->type() =~ m/([a-zA-Z]+)\[([a-zA-Z]+)\]/;
    my $m = $1;
    my $p = $2;
    
    if(!Moose::Util::TypeConstraints::find_type_constraint($p)->check($val)) {
        my $type = $self->type();
        confess "Invalid value $val does not conform to type constraint $type\n";
    } elsif(defined($self->validator)) {
        my $fn = $self->validator;
        if(!&$fn($val)) {
            confess "Invalid value $val fails supplied validation check\n";
        }
    }
    
    #handle different types
    my $var = $self->var;
    if($self->type eq 'ArrayRef') {
        push(@$var, $val);
    } elsif($self->type eq 'HashRef') {
        my @kv = split(/=/, $val);
        $var->{$kv[0]} = $kv[1];
    } elsif($self->type eq 'Inc') {
        ++$$var;
    } elsif($self->type eq 'Bool') {
        $$var = 1;
    } else {
        $$var = $val;
    }
    $self->_set(1);
    
    if(defined($self->callback)) {
        my $fn = $self->callback;
        &$fn($val);
    }
}

sub requires_val {
    my ($self) = @_;
    
    return !($self->type eq any(qw(Bool Inc)));
}

no Moose;

1;
