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
            => where { $_ =~ m/^[a-zA-Z0-9|_?-]+$/ && $_ !~ m/\|\|/ && $_ !~ /--/ && $_ !~ /-$/ };

#special type defining what a parsed  switch should look like          
subtype 'Switch'
            => as 'Str'
            => where { $_ =~ m/^[a-zA-Z0-9_?-]+$/ };

#the argument specification supplied
has 'switchspec' => (
    is => 'ro',
    isa => 'SwitchSpec',
    required => 1,
);

#the primary name of this switch
has 'primary_name' => (
    is => 'ro',
    isa => 'Switch',
    writer => '_set_primary_name',
    init_arg => undef,
);

#any aliases this switch has
has 'aliases' => (
    is => 'ro',
    isa => 'ArrayRef[Switch]',
    writer => '_set_aliases',
    init_arg => undef,
);

#the reference to the variable to populate when this switch is found
has 'var' => (
    is => 'ro',
    isa => 'ScalarRef|ArrayRef|HashRef',
    required => 1,
);

#the type of values to accept for this variable                
has 'type' => (
    is => 'ro',
    isa => 'ValidType',
    required => 1,
);

#the description of this variable, for autohelp
has 'desc' => (
    is => 'ro',
    isa => 'Str',
    default => '',
    writer => '_set_desc',
);

#whether or not this switch must be found
has 'required' => (
    is => 'ro',
    isa => 'Int',
    default => 0,
);

#a function to call to validate the value found by this switch
has 'validator' => (
    is => 'ro',
    isa => 'CodeRef',
    predicate => 'has_validator',
);

#a function to call whenever this switch is found, passing in the
#value found, if any
has 'callback' => (
    is => 'ro',
    isa => 'CodeRef',
);

#default to populate the provided variable reference with
has 'default' => (
    is => 'ro',
    isa => 'Str|ArrayRef|HashRef|CodeRef',
    predicate => 'has_default',
    writer => '_set_default',
);

#whether or not this argument has had its variable set                
has '_set' => (
    is => 'rw',
    isa => 'Int',
    init_arg => undef,
    predicate => 'is_set',
);
            
            
=head1 NAME

Getopt::Flex::Spec::Argument - Specification class for Getopt::Flex

=head1 DESCRIPTION

This class is only meant to be used by Getopt::Flex::Spec
and should not be used directly.

=head1 METHODS

=cut

sub BUILD {
    my ($self) = @_;
    
    #check supplied reference type
    my $reft = ref($self->var());
    if($reft eq none(qw(ARRAY HASH SCALAR))) {
        Carp::confess "supplied var must be a reference to an ARRAY, HASH, or SCALAR\n";
    }
    
    #make sure the reference has the correct type
    if($reft eq any(qw(ARRAY HASH))) {
        my $re = qr/$reft/i;
        
        if($self->type() !~ $re) {
            my $type = $self->type();
            Carp::confess "supplied var has wrong type $type\n";
        }
    }
    
    #set the default appropriately
    if($self->has_default() && find_type_constraint('CodeRef')->check($self->default())) {
        my $fn = $self->default();
        $self->_set_default(&$fn());
    }
    
    #check the type of the default
    if($self->has_default() && !Moose::Util::TypeConstraints::find_or_parse_type_constraint($self->type())->check($self->default())) {
        my $def = $self->default();
        my $type = $self->type();
        Carp::confess "default $def fails type constraint $type\n";
    }
    
    #check the default against the validator
    if($self->has_default() && $self->has_validator()) {
        my $fn = $self->validator();
        if($self->type() =~ /^ArrayRef/) {
            my @defs = @{$self->default()};
            foreach my $def (@defs) {
                if(!&$fn($def)) {
                    Carp::confess "default $def fails supplied validation check\n";
                }
            }
        } elsif($self->type() =~ /^HashRef/) {
            my %defs = %{$self->default()};
            foreach my $key (keys %defs) {
                if(!&$fn($defs{$key})) {
                    Carp::confess "default $defs{$key} (with key $key) fails supplied validation check\n";
                }
            }
        } else {
            if(!&$fn($self->default())) {
                my $def = $self->default();
                Carp::confess "default $def fails supplied validation check\n";
            }
        }
    }
    
    #set the default value onto the supplied var
    if($self->has_default()) {
        if($self->type() =~ /^ArrayRef/) {
            my $var = $self->var();
            @$var = @{$self->default()};
        } elsif($self->type() =~ /^HashRef/) {
            my $var = $self->var();
            %$var = %{$self->default()};
        } else { #scalar
            my $var = $self->var();
            $$var = $self->default();
        }
    }
    
    #parse the switchspec
    my @aliases = split(/\|/, $self->switchspec);
    $self->_set_primary_name($aliases[0]);
    $self->_set_aliases(\@aliases);
    
    #create appropriate description
    if($self->desc() ne '') {
        my @use = ();
        foreach my $al (sort @{$self->aliases()}) {
            if(length($al) < 22) { push(@use, $al) } #not too long
        }
        
        #all the options were too long, probably should die or issue a warning
        if($#use != -1) {
            $self->_set_desc($self->_create_desc_block(\@use));
        }
    }
}

sub _create_desc_block {
    my ($self, $alsref) = @_;
    
    #don't do so much string concatenation
    my @ret = ();
    push(@ret, '  ');
    my $os = $self->_create_option_string($alsref);
    if($os =~ /^--/) {
        push(@ret, '    '); #align the long options after the short
    }
    push(@ret, $os);
    my $less = $os =~ /^--/ ? 4 : 0; #need four less spaces if we start with a long option
    push(@ret, ' 'x(30-length($os)-$less));
    push(@ret,$self->desc()); #add the description
    push(@ret,"\n");
    
    #process all remaining options
    until((my $t = $self->_create_option_string($alsref)) eq '') {
        if($t =~ /^--/) {
            push(@ret, '      ');
        } else {
            push(@ret, '    ');
        }
        push(@ret, $t);
        push(@ret, "\n");
    }
    
    return join('', @ret);
    
}

sub _create_option_string {
    my ($self, $alsref) = @_;
    my $ret = '';
    while(my $sw = shift @$alsref) {
        next if !defined($sw);
        my $add = length($sw) == 1 ? '-' : '--'; #add dashes
        $add .= $sw;
        $add .= $#{$alsref} == -1 ? '' : ', '; #add a comma, if not last
        if(length($ret.$add) > 25) { unshift(@$alsref, $sw); last; }
        $ret .= $add;
    }
    
    return $ret;
}

=head2 set_value

Set the value of this argument

=cut

sub set_value {
    my ($self, $val) = @_;
    
    #get the type parameter of the compound type
    my $type = $self->type();
    if($type =~ m/^([a-zA-Z]+)\[([a-zA-Z]+)\]$/) {
        $type = $2;
    }
    
    #handle different types
    my $var = $self->var;
    if($self->type =~ /ArrayRef/) {
        $self->_check_val($type, $val);
        push(@$var, $val);
    } elsif($self->type =~ /HashRef/) {
        my @kv = split(/=/, $val);
        $self->_check_val($type, $kv[1]);
        $var->{$kv[0]} = $kv[1];
        $val = $kv[1];
    } elsif($self->type eq 'Inc') {
        ++$$var;
    } elsif($self->type eq 'Bool') {
        $$var = 1;
    } else {
        $self->_check_val($type, $val);
        $$var = $val;
    }
    $self->_set(1); #var has been set
    
    if(defined($self->callback)) {
        my $fn = $self->callback;
        &$fn($val);
    }
}

sub _check_val {
    my ($self, $type, $val) = @_;
    
    if(!Moose::Util::TypeConstraints::find_type_constraint($type)->check($val)) {
        Carp::confess "Invalid value $val does not conform to type constraint $type\n";
    }
    
    if(defined($self->validator)) {
        my $fn = $self->validator;
        if(!&$fn($val)) {
            Carp::confess "Invalid value $val fails supplied validation check\n";
        }
    }
}

=head2 requires_val

Check whether or not this argument requires a value

=cut

sub requires_val {
    my ($self) = @_;
    return $self->type eq none(qw(Bool Inc));
}

=begin Pod::Coverage

  BUILD

=end Pod::Coverage

=cut

no Moose;

1;
