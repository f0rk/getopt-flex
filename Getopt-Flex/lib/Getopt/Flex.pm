package Getopt::Flex;

# ABSTRACT: Option parsing, done different.

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

=head1 SYNOPSIS

  use Getopt::Flex;
  my $foo; my $use; my $num; my %has; my @arr;
  
  my $cfg = {
      'non_option_mode' => 'STOP',
  };
  
  my $spec = {
      'foo|f' => {'var' => \$foo, 'type' => 'Str'},
      'use|u' => {'var' => \$use, 'type' => 'Bool'},
      'num|n' => {'var' => \$num, 'type' => 'Num'},
      'has|h' => {'var' => \%has, 'type' => 'HashRef[Int]'},
      'arr|a' => {'var' => \@arr, 'type' => 'ArrayRef[Str]'}
  };
  
  my $op = Getopt::Flex->new({spec => $spec, config => $cfg});
  $op->getopts();

=head1 DESCRIPTION

Getopt::Flex is an object-oriented way to go about option parsing.
Creating an option specification is easy and declarative, and
configuration is optional and defualts to a few, smart parameters.
Generally, it adheres to the POSIX syntax with GNU extensions for
command line options. As a result, options may be longer than a
single letter, and would begin with "--". Support also exists
for bundling of command line options, but is not enabled by defualt.

=head1 Getting started with Getopt::Flex

Getopt::Flex supports long and single character options. Any character
from [a-zA-Z0-9_?-] may be used when specifying an option. Options
must not end in -, nor may they contain two consecutive dashes.

To use Getopt::Flex in your perl program, it must contain the following
line:

  use Getopt::Flex;

In the default configuration, bundling is not enabled, long options
must start with "--" and non-options may be placed between options.

=head2 Specifying Options

Options are specified by way of a hash whose keys define valid option
forms and whose values are hashes which contain information about the
options. For instance,

  my $spec = {
      'file|f' => {
          'var' => \$file,
          'type' => 'Str'
      }
  };

Defines a switch called I<file> with an alias I<f> which will set variable
C<$var> with a value when encountered during processing. I<type> specifies
the type that the input must conform to. Both I<var> and I<type> are required
when specifying an option. In general, options must conform to the following:

  $_ =~ m/^[a-zA-Z0-9|_?-]+$/ && $_ !~ m/\|\|/ && $_ !~ /--/ && $_ !~ /-$/

The following is an example of all possible arguments to an option specification:

  my $spec = {
      'file|f' => {
          'var' => \$file,
          'type' => 'Str',
          'desc' => 'The file to process',
          'required' => 1,
          'validator' => sub { $_[0] =~ /\.txt$/ },
          'callback' => sub { print "File found\n" },
          'default' => 'input.txt',
      }
  };

=head2 Specifying a var

When specifying a I<var>, you must provide a reference to the variable,
and not the variable itself. So C<\$file> is ok, while C<$file> is not.
You may also pass in an array reference or a hash reference, please see
L<Specifying a type> for more information.

=head2 Specifying a type

A valid type is one of the following:

  Bool Str Num Int ArrayRef[Str] ArrayRef[Num] ArrayRef[Int] HashRef[Str] HashRef[Num] HashRef[Int] Inc

These work like exactly like Moose type constraints of the same name, except C<Inc>.
C<Inc> defines an incremental type (actually simply an alias for Moose's C<Int> type),
whose value will be increased by one each time
its appropriate switch is encountered on the command line. When using an C<ArrayRef>
type, the supplied var must be an array reference, like C<\@arr> and NOT C<@arr>.
Likewise, when using a C<HashRef> type, the supplied var must be a hash reference,
e.g. C<\%hash> and NOT C<%hash>. For more information about types, see
L<Moose::Manual::Types>.

All of the following arguments to the option specification are optional.

=head2 Specifying a desc

I<desc> is used to provide a description for an option. It can be used
to provide an autogenerated help message for that switch. If left empty,
no information about that switch will be displayed in the specification.
See L<Using Getopt::Flex> for more information.

=head2 Specifying required

Setting I<required> to a true value will cause it make that value required
during option processing, and if it is not found will cause an error condition.

=head2 Specifying a validator

A I<validator> is a function that takes a single argument and returns a boolean
value. Getopt::Flex will call the validator function when the option is
encountered on the command line and pass to it the value it finds. If the value
does not pass the supplied validation check, an error condition is caused.

=head2 Specifying a callback

A I<callback> is a function that takes a single argument which Getopt::Flex will
then call when the option is encountered on the command line, passing to it the value it finds.

=head2 Specifying a default

I<default>s come in two flavors, raw values and subroutine references.
For instance, one may specify a string as a default value, or a subroutine
which returns a string:

  'default' => 'some string'

or

  'default' => sub { return "\n" }

When specifying a default for an array or hash, it is necessary to use
a subroutine to return the reference like,

  'default' => sub { {} }

or

  'default' => sub { [] }

This is due to the way Perl handles such syntax. Additionally, defaults
must be valid in relation to the specified type and any specified
validator function. If not, an error condition is signalled.

=head1 Configuring Getopt::Flex

Configuration of Getopt::Flex is very simple. Such a configuration
is specified by a hash whose keys are the names of configuration
option, and whose values indicate the configuration. Below is a
configuration with all possible options:

  my $cfg = {
      'non_option_mode' => 'STOP',
      'bundling' => 0,
      'long_option_mode' => 'SINGLE_OR_DOUBLE',
      'usage' => 'foo [OPTIONS...] [FILES...]',
      'desc' => 'Use foo to manage your foo archives'
  };

What follows is a discussion of each option.

=head2 Configuring non_option_mode

I<non_option_mode> tells the parser what to do when it encounters anything
which is not a valid option to the program. Possible values are as follows:

  STOP IGNORE

C<STOP> indicates that upon encountering something that isn't an option, stop
processing immediately. C<IGNORE> is the opposite, ignoring everything that
isn't an option. The default value is C<IGNORE>.

=head2 Configuring bundling

I<bundling> is a boolean indicating whether or not bundled switches may be used.
A bundled switch is something of the form:

  -laR

Where equivalent unbundled representation is:

  -l -a -R

By turning I<bundling> on, I<long_option_mode> will automatically be set to
C<REQUIRE_DOUBLE_DASH>.

=head2 Configuring long_option_mode

This indicates what long options should look like. It may assume the
following values:

  REQUIRE_DOUBLE_DASH SINGLE_OR_DOUBLE

C<REQUIRE_DOUBLE_DASH> is the default. Therefore, by default, options
that look like:

  --verbose

Will be treated as valid, and:

  -verbose

Will be treated as invalid. Setting I<long_option_mode> to C<SINGLE_OR_DOUBLE>
would make the second example valid as well. Attempting to set I<bundling> to
C<1> and I<long_option_mode> to C<SINGLE_OR_DOUBLE> will signal an error.

=head2 Configuring usage

I<usage> may be set with a string indicating appropriate usage of the program.
It will be used to provide help automatically.

=head2 Configuring desc

I<desc> may be set with a string describing the program. It will be used when
providing help automatically.

=head1 Using Getopt::Flex

Using Getopt::Flex is simple. You define a specification, as described above,
optionally define a configuration, as desribed above, and then construct a new
Getopt::Flex object.

  my $spec = {
      'foo|f' => {'var' => \$foo, 'type' => 'Str'},
  };
  
  my $op = Getopt::Flex->new({spec => $spec});

You then call C<$op->getopts()> to process options. Getopt::Flex automatically
uses the global @ARGV array for options. If you would like to supply your own,
you may use C<set_args>, like this:

  $op->set_args(\@args);

Which expects an array reference. Getopt::Flex also stores information about
valid options, invalid options and extra options. Valid options are those
which Getopt::Flex recognized as valid, and invalid are those that were not.
Anything that is not an option can be found in extra options. These values
can be retrieved via:

  my @va = $op->get_valid_args();
  my @ia = $op->get_invalid_args();
  my @ea = $op->get_extra_args();

Getopt::Flex may also be used to provide an automatically formatted help
message. By setting the appropriate I<desc> when specifying an option,
and by setting I<usage> and I<desc> in the configuration, a full help
message can be provided, and is available via:

  my $help = $op->get_help();

Usage and description are also available, via:

  my $usage = $op->get_usage();
  my $desc = $op->get_desc();

An automatically generated help message would look like this:

  Usage: foo [OPTIONS...] [FILES...]
  
  Use this to manage your foo files
  
  Options:
  
        --alpha, --beta,          Pass any greek letters to this argument
        --delta, --eta, --gamma
    -b, --bar                     When set, indicates to use bar
    -f, --foo                     Expects a string naming the foo

=head1 METHODS

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
        
        #stop processing immediately
        if($item =~ /^--$/) {
            last;
        }
        
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

=begin Pod::Coverage

  BUILD

=end Pod::Coverage

=cut

no Moose;

1;
