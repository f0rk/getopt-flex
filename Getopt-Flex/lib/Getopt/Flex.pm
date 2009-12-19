package Getopt::Flex;

use Clone;
use Moose;
use MooseX::StrictConstructor;
use Readonly;
use Getopt::Flex::Config;
use Getopt::Flex::Spec;
use Perl6::Junction qw(any);

#return values for the function that
#determines the type of switch it is
#inspecting
Readonly::Scalar my $_ST_LONG => 1;
Readonly::Scalar my $_ST_SHORT => 2;
Readonly::Scalar my $_ST_BUNDLED => 3;
Readonly::Scalar my $_ST_NONE => 4;

#the raw spec defining the options to be parsed
#and how they are to be handled
has 'spec' => ( is => 'ro',
                isa => 'HashRef[HashRef[Str|CodeRef|ScalarRef|ArrayRef|HashRef]]',
                required => 1,
               );

#the parsed Getopt::Flex::Spec object
has '_spec' => ( is => 'rw',
                isa => 'Getopt::Flex::Spec',
                init_arg => undef,
               );

#the raw config defining any relevant configuration
#parameters               
has 'config' => ( is => 'ro',
                  isa => 'HashRef[Str]',
                  default => sub { {} },
                );

#the parsed Getopt::Flex::Config object                
has '_config' => ( is => 'rw',
                  isa => 'Getopt::Flex::Config',
                  init_arg => undef,
                );

#the arguments passed to the calling script,
#clones @ARGV so it won't be modified                
has '_args' => ( is => 'rw',
                 isa => 'ArrayRef',
                 init_arg => undef,
                 default => sub { my @a = Clone::clone(@ARGV); return \@a },
               ); 

#an array of the valid switches passed to the script               
has 'valid_args' => ( is => 'ro',
                      isa => 'ArrayRef[Str]',
                      writer => '_set_valid_args',
                      reader => '_get_valid_args',
                      init_arg => undef,
                      default => sub { [] },
                    );

#an array of the invalid switches passed to the script                    
has 'invalid_args' => ( is => 'ro',
                        isa => 'ArrayRef[Str]',
                        writer => '_set_invalid_args',
                        reader => '_get_invalid_args',
                        init_arg => undef,
                        default => sub { [] },
                    );

#an array of anything that wasn't a switch that was encountered                    
has 'extra_args' => ( is => 'ro',
                      isa => 'ArrayRef[Str]',
                      writer => '_set_extra_args',
                      reader => '_get_extra_args',
                      init_arg => undef,
                      default => sub { [] },
                    );

=head1 NAME

Getopt::Flex - Option parsing, done differently

=head1 METHODS

=head2 BUILD

This method is used by Moose, please do not attempt to use it

=cut

sub BUILD {
    my $self = shift;
    
    #create the configuration
    $self->_config(Getopt::Flex::Config->new($self->config()));
    
    #create the spec
    $self->_spec(Getopt::Flex::Spec->new({ spec => $self->spec() }));
    
    return;
}

=head2 getopts

Invoking this method will cause the module to parse its current arguments array,
and apply any values found to the appropriate matched references provided.

=cut

sub getopts {
    my ($self) = @_;
    
    my @args = @{$self->_args()};
    my @valid_args = ();
    my @invalid_args = ();
    my @extra_args = ();
    
    for(my $i = 0; $i <= $#args; ++$i) {
        my $item = $args[$i];
        
        #do we have a switch?
        if($self->_is_switch($item)) {
            #if we have a switch, parse it and return any values we encounter
            #there are a few ways that values are returned: as scalars, when
            #the accompanying value was not present in the switch passed (i.e.
            #the form "-f bar" was encountered and not "-fbar" or "-f=bar").
            #If an array is returned, the value accompanying the switch was
            #found with it, and $arr[0] contains the switch name and $arr[1]
            #contains the value found. If a hash is returned, it was a bundled
            #switch, and the keys are switch names and the values are those
            #values (if any) that were found.
            my $ret = $self->_parse_switch($item);
            
            #handle scalar returns
            if(ref($ret) eq 'SCALAR') {
                $ret = $$ret; #get our var
                if($self->_spec()->check_switch($ret)) { #valid switch?
                    if($self->_spec()->switch_requires_val($ret)) { #requires a value?
                        #peek forward in args, because we didn't find the
                        #necessary value with the switch
                        if($i+1 <= $#args && !$self->_is_switch($args[$i+1])) {
                            $self->_spec()->set_switch($ret, $args[$i+1]);
                            push(@valid_args, $ret);
                            ++$i;
                        } else {
                            Carp::confess "switch $ret requires value, but none given\n";
                        }
                    } else { #doesn't require a value, so just use 1
                        $self->_spec()->set_switch($ret, 1);
                        push(@valid_args, $ret);
                    }
                } else { #switch isn't valid
                    push(@invalid_args, $ret);
                    if($self->_config()->non_option_mode() eq 'STOP') {
                        last;
                    }
                }
            #handle hash returns
            } elsif(ref($ret) eq 'HASH') {
                my %rh = %{$ret}; #get the hash
                foreach my $key (keys %rh) {
                    if($self->_spec()->check_switch($key)) { #one of our switches?
                        if(!defined($rh{$key})) {
                            #no value supplied, check if it needs one
                            if($self->_spec()->switch_requires_val($key)) {
                                #to peek or not to peek
                                if($key eq $rh{'~~last'}) { #ok, peek
                                    if(!$self->_is_switch($args[$i+1])) {
                                        $self->_spec()->set_switch($key, $args[$i+1]);
                                        push(@valid_args, $key);
                                        ++$i;
                                    } else {
                                        Carp::confess "switch $key requires value, but none given\n";
                                    }
                                } else {
                                    #FFFUUUU
                                    Carp::confess "switch $key requires value, but none given\n";
                                }
                            } else { #no value needed, just use 1
                                $self->_spec()->set_switch($key, 1);
                                push(@valid_args, $key);
                            }
                        } else { #value supplied, use it
                            $self->_spec()->set_switch($key, $rh{$key});
                            push(@valid_args, $key);
                        }
                    } else {
                        #no such switch
                        if($key ne '~~last') {
                            push(@invalid_args, $key);
                            if($self->_config()->non_option_mode() eq 'STOP') {
                                last;
                            }
                        }
                    }
                }
            #handle array returns
            } elsif(ref($ret) eq 'ARRAY') {    
                my @arr = @{$ret}; #get the array
                if($#arr != 1) {
                    Carp::confess "array is wrong length, should never happen\n";
                } else {
                    if($self->_spec()->check_switch($arr[0])) { #one of ours?
                        $self->_spec()->set_switch($arr[0], $arr[1]);
                        push(@valid_args, $arr[0]);
                    } else { #nope
                        push(@invalid_args, $arr[0]);
                        if($self->_config()->non_option_mode() eq 'STOP') {
                            last;
                        }
                    }
                }
            } elsif(!defined($ret)) {    
                Carp::cluck "found invalid switch $ret\n";
            } else { #should never happen
                my $rt = ref($ret);
                Carp::confess "returned val $ret of illegal ref type $rt\n" 
            }
        } else { #not a switch, so an extra argument
            push(@extra_args, $item);
            if($self->_config()->non_option_mode() eq 'STOP') {
                last;
            }
        }
    }
    
    #check to see that all required args were set
    my $argmap = $self->_spec()->_argmap();
    foreach my $alias (keys %{$argmap}) {
        if($argmap->{$alias}->required() && !$argmap->{$alias}->is_set()) {
            my $spec = $argmap->{$alias}->switchspec();
            Carp::confess "missing required switch with spec $spec\n";
        }
    }
    
    $self->_set_valid_args(\@valid_args);
    $self->_set_invalid_args(\@invalid_args);
    $self->_set_extra_args(\@extra_args);
    
    return;
}

sub _is_switch {
    my ($self, $switch) = @_;
    
    if(!defined($switch)) {
        return 0;
    }
    
    #does he look like a switch?
    return $switch =~ /^(-|--)[a-zA-Z0-9?][a-zA-Z0-9=_?-]*/;
}

sub _parse_switch {
    my ($self, $switch) = @_;
    
    #get the switch type
    my $switch_type = $self->_switch_type($switch);
    
    #no given/when, so use this ugly thing
    if($switch_type == $_ST_LONG) {
        return $self->_parse_long_switch($switch);
    } elsif($switch_type == $_ST_SHORT) {
        return $self->_parse_short_switch($switch);
    } elsif($switch_type == $_ST_BUNDLED) {
        return $self->_parse_bundled_switch($switch);
    } elsif($switch_type == $_ST_NONE) {
        return undef;
    } else {
        #something is wrong here...
        Carp::confess "returned illegal switch type $switch_type\n";
    }
}

sub _switch_type {
    my ($self, $switch) = @_;
    
    #anything beginning with "--" is a
    #long switch
    if($switch =~ /^--/) {
        return $_ST_LONG;
    } else { #could be any kind
        #single dash, single letter, definitely short
        if($switch =~ /^-[a-zA-Z0-9?]$/) {
            return $_ST_SHORT;
        #single dash, single letter, equal sign, definitely short
        } elsif($switch =~ /^-[a-zA-Z0-9?]=.+$/) {
            return $_ST_SHORT;
        #short or bundled
        } else {
            #already determined it isn't a single letter switch, so check
            #the non_option_mode to see if it is long
            if($self->_config()->long_option_mode() eq 'SINGLE_OR_DOUBLE') {
                return $_ST_LONG;
            #could be short, bundled, or none
            } else {
                $switch =~ s/^-//;
                my $c1 = substr($switch, 0, 1);
                my $c2 = substr($switch, 1, 1);
                #the first letter doesn't belong to a short switch
                #so this isn't a valid switch
                if(!$self->_spec()->check_switch($c1)) {
                    return $_ST_NONE;
                #first letter belongs to a switch, but not the second
                #so this is a short switch of the form "-fboo" where
                #-f is the switch
                } elsif($self->_spec()->check_switch($c1) && !$self->_spec()->check_switch($c2)) {
                    return $_ST_SHORT;
                #no other choices, it's bundled
                } else {
                    return $_ST_BUNDLED;
                }
            }
        }
    }
}

sub _parse_long_switch {
    my ($self, $switch) = @_;
    
    $switch =~ s/^(--|-)//;
    
    my @vals = split(/=/, $switch, 2);
    
    if($#vals == 0) {
        return \$vals[0];
    } else {
        return [$vals[0], $vals[1]];
    }
}

sub _parse_short_switch {
    my ($self, $switch) = @_;
    
    $switch =~ s/^-//;
    
    if(length($switch) == 1) {
        return \$switch;
    } elsif(index($switch, '=') >= 0) {
        my @vals = split(/=/, $switch, 2);
        return {$vals[0] => $vals[1]};
    } else {
        return [substr($switch, 0, 1), substr($switch, 1)];
    }
}

sub _parse_bundled_switch {
    my ($self, $switch) = @_;
    
    $switch =~ s/^-//;
    
    my %rh = ();
    
    my $last_switch;
    for(my $i = 0; $i < length($switch); ++$i) {
        my $c = substr($switch, $i, 1);
        if($c eq any(keys %rh)) {
            #switch appears again in bundle, rest of string is an argument to last switch
            if(defined($last_switch)) {
                $rh{$last_switch} = substr($switch, $i);
            } else { #oops, illegal switch
                #should never get here, make sure switch
                #is valid and of correct type sooner
                Carp::confess "illegal switch $switch\n";
            }
            $i = length($switch);
        } elsif($self->_spec()->check_switch($c)) {
            $rh{$c} = undef;
        } else { #rest of the string was an argument to last switch
            if(defined($last_switch)) {
                if($c eq '=') {
                    $rh{$last_switch} = substr($switch, $i + 1);
                } else {
                    $rh{$last_switch} = substr($switch, $i);
                }
            } else { #oops, illegal switch
                #should never get here, make sure switch
                #is valid and of correct type sooner
                Carp::confess "illegal switch $switch\n";
            } 
            $i = length($switch);
        }
        $last_switch = $c;
    }
    
    #special value so we can pass on
    #what the last switch was
    $rh{'~~last'} = $last_switch;
    
    return \%rh;
}

=head2 set_args

Set the array of args to be parsed. Expects an array reference.

=cut

sub set_args {
    my ($self, $ref) = @_;
    return $self->_args(Clone::clone($ref));
}

=head2 get_args

Get the array of args to be parsed.

=cut

sub get_args {
    my ($self) = @_;
    return @{Clone::clone($self->_args)};
}

=head2 num_valid_args

After parsing, this returns the number of valid switches passed to the script.

=cut

sub num_valid_args {
    my ($self) = @_;
    return $#{$self->valid_args} + 1;
}

=head2 get_valid_args

After parsing, this returns the valid arguments passed to the script.

=cut

sub get_valid_args {
    my ($self) = @_;
    return @{Clone::clone($self->_get_valid_args())};
}

=head2 num_invalid_args

After parsing, this returns the number of invalid switches passed to the script.

=cut

sub num_invalid_args {
    my ($self) = @_;
    return $#{$self->invalid_args} + 1;
}

=head2 get_invalid_args

After parsing, this returns the invalid arguments passed to the script.

=cut

sub get_invalid_args {
    my ($self) = @_;
    return @{Clone::clone($self->_get_invalid_args())};
}

=head2 num_extra_args

After parsing, this returns anything that wasn't matched to a switch, or that was not a switch at all.

=cut

sub num_extra_args {
    my ($self) = @_;
    return $#{$self->extra_args} + 1;
}

=head2 get_extra_args

After parsing, this returns the extra parameter passed to the script.

=cut

sub get_extra_args {
    my ($self) = @_;
    return @{Clone::clone($self->_get_extra_args())};
}

=head2 get_usage

Returns the supplied usage message, or a single newline if none given.

=cut

sub get_usage {
    my ($self) = @_;
    
    if($self->_config()->usage() eq '') {
        return "\n";
    }
    return 'Usage: '.$self->_config()->usage()."\n";
}

=head2 get_help

Returns an automatically generated help message

=cut

sub get_help {
    my ($self) = @_;
    
    #find the keys that will give use a unique
    #set of arguments, using the primary_key
    #of each argument object
    my $argmap = $self->_spec()->_argmap();
    my @primaries = ();
    foreach my $key (keys %$argmap) {
        if($argmap->{$key}->primary_name() eq $key && $argmap->{$key}->desc() ne '') {
            push(@primaries, $key);
        }
    }
    
    my @help = ();
    
    #if we have a usage message, include it
    if($self->_config()->usage() ne '') {
        push(@help, 'Usage: ');
        push(@help, $self->_config()->usage());
        push(@help, "\n\n");
    }
    
    #if we have a description, include it
    if($self->_config()->desc() ne '') {
        push(@help, $self->_config()->desc());
        push(@help, "\n\n");
    }
    
    #if any of the keys have a description, then...
    if($#primaries != -1) {
        #...give us a listing of the options
        push(@help, "Options:\n\n");
        foreach my $key (sort @primaries) {
            if($argmap->{$key}->desc() ne '') {
                push(@help, $argmap->{$key}->desc());
            }
        }
    }
    
    #friends don't let friends end things with two newlines
    if($help[$#help] =~ /\n\n$/) { pop(@help); push(@help, "\n"); }
    
    return join('', @help);
}

=head2 get_desc

Returns the supplied description, or a single newline if none provided.

=cut

sub get_desc {
    my ($self) = @_;
    return $self->_config()->desc()."\n";
}

no Moose;

1;
