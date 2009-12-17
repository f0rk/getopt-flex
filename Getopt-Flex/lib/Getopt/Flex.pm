package Getopt::Flex;

use Clone;
use Moose;
use MooseX::StrictConstructor;
use Readonly;
use Getopt::Flex::Config;
use Getopt::Flex::Spec;

Readonly::Scalar my $_ST_LONG => 1;
Readonly::Scalar my $_ST_SHORT => 2;
Readonly::Scalar my $_ST_BUNDLED => 3;
Readonly::Scalar my $_ST_NONE => 4;

has 'spec' => ( is => 'ro',
                isa => 'HashRef[HashRef[Str|CodeRef|ScalarRef|ArrayRef|HashRef]]',
                required => 1,
               );

has '_spec' => ( is => 'rw',
                isa => 'Getopt::Flex::Spec',
                init_arg => undef,
               );
               
has 'config' => ( is => 'ro',
                  isa => 'HashRef[Str]',
                  default => sub { {} },
                );
                
has '_config' => ( is => 'rw',
                  isa => 'Getopt::Flex::Config',
                  init_arg => undef,
                );
                
has '_args' => ( is => 'rw',
                 isa => 'ArrayRef',
                 init_arg => undef,
               ); 
               
has 'valid_args' => ( is => 'ro',
                      isa => 'ArrayRef[Str]',
                      writer => '_set_valid_args',
                      init_arg => undef,
                      default => sub { [] },
                    );
                    
has 'invalid_args' => ( is => 'ro',
                        isa => 'ArrayRef[Str]',
                        writer => '_set_invalid_args',
                        init_arg => undef,
                        default => sub { [] },
                    );
                    
has 'extra_args' => ( is => 'ro',
                      isa => 'ArrayRef[Str]',
                      writer => '_set_extra_args',
                      init_arg => undef,
                      default => sub { [] },
                    );
                    
has 'usage' => ( is => 'ro',
                 isa => 'Str',
                );
               
sub BUILD {
    my $self = shift;
    
    #create the configuration
    $self->_config(Getopt::Flex::Config->new($self->config()));
    
    #create the spec
    $self->_spec(Getopt::Flex::Spec->new({ spec => $self->spec() }));
    
    return;
}

sub getopts {
    my ($self) = @_;
    
    my @args;
    if(!defined($self->_args())) {
        @args = $self->_args(clone(@ARGV));
    } else {
        @args = $self->_args();
    }
    
    my @valid_args = ();
    my @invalid_args = ();
    my @extra_args = ();
    
    for(my $i = 0; $i <= $#args; ++$i) {
        my $item = $args[$i];
        if(_is_switch($item)) {
            my $ret = _parse_switch($item);
            if(ref($ret) eq 'SCALAR') {
                if($self->_spec()->check_switch($ret)) {
                    if($self->_spec()->switch_requires_val($ret)) {
                        #peek forward in args
                        if(!_is_switch($args[$i+1])) {
                            $self->_spec()->set_switch($ret, $args[$i+1]);
                            push(@valid_args, $ret);
                            ++$i;
                        } else {
                            confess "switch $ret requires value, but none given\n";
                        }
                    } else {
                        $self->_spec()->set_switch($ret, 1);
                        push(@valid_args, $ret);
                    }
                } else {
                    push(@invalid_args, $ret);
                }
            } elsif(ref($ret) eq 'HASH') {
                my %rh = %{$ret};
                foreach my $key (keys %rh) {
                    if($self->_spec()->check_switch($key)) {
                        if(!defined($rh{$key})) {
                            #no value supplied, check if it needs one
                            if($self->_spec()->switch_requires_val($key)) {
                                #to peek or not to peek
                                if($key eq $rh{'~~last'}) { #ok, peek
                                    if(!_is_switch($args[$i+1])) {
                                        $self->_spec()->set_switch($key, $args[$i+1]);
                                        push(@valid_args, $key);
                                        ++$i;
                                    } else {
                                        confess "switch $key requires value, but none given\n";
                                    }
                                } else {
                                    #FFFUUUU
                                    confess "switch $key requires value, but none given\n";
                                }
                            } else {
                                $self->_spec()->set_switch($key, 1);
                                push(@valid_args, $key);
                            }
                        } else {
                            $self->_spec()->set_switch($key, $rh{$key});
                            push(@valid_args, $key);
                        }
                    } else {
                        #no such switch
                        push(@invalid_args, $key);
                    }
                }
            } elsif(ref($ret) eq 'ARRAY') {    
                my @arr = @{$ret};
                if($#arr != 1) {
                    confess "array is wrong length, should never happen\n";
                } else {
                    if($self->_spec()->check_switch($arr[0])) {
                        $self->_spec()->set_switch($arr[0], $arr[1]);
                        push(@valid_args, $arr[0]);
                    } else {
                        push(@invalid_args, $arr[0]);
                    }
                }
            } else {
                my $rt = ref($ret);
                confess "returned illegal ref type $rt\n" 
            }
        } else {
            push(@extra_args, $item);
        }
    }
    
    $self->_set_valid_args(@valid_args);
    $self->_set_invalid_args(@invalid_args);
    $self->_set_extra_args(@extra_args);
    
    return;
}

sub _is_switch {
    my ($self, $switch) = @_;
    
    #does he look like a switch?
    return $switch =~ /^(-|--)[a-zA-Z0-9?][a-zA-Z0-9=_?-]*/;
}

sub _parse_switch {
    my ($self, $switch) = @_;
    
    my $switch_type = _switch_type($switch);
    
    if($switch_type == $_ST_LONG) {
        return _parse_long_switch($switch);
    } elsif($switch_type == $_ST_SHORT) {
        return _parse_short_switch($switch);
    } elsif($switch_type == $_ST_BUNDLED) {
        return _parse_bundled_switch($switch);
    } elsif($switch_type == $_ST_NONE) {
        return undef;
    } else {
        #something is wrong here...
        confess "returned illegal switch type $switch_type\n";
    }
}

sub _switch_type {
    my ($self, $switch) = @_;
    
    if($switch =~ /^--/) {
        return $_ST_LONG;
    } else { #begins with a single dash
        if($switch =~ /^-[a-zA-Z0-9?]$/) {
            return $_ST_SHORT;
        } elsif($switch =~ /^-[a-zA-Z0-9?]=.+$/) {
            return $_ST_SHORT;
        } else {
            if($self->_config()->long_option_mode() eq 'SINGLE_OR_DOUBLE') {
                return $_ST_LONG;
            } else { #could be short, bundled, or none
                $switch =~ s/^-//;
                my $c1 = substr($switch, 0, 1);
                my $c2 = substr($switch, 1, 2);
                if(!$self->_spec()->check_switch($c1)) {
                    return $_ST_NONE;
                } elsif($self->_spec()->check_switch($c1) && !$self->_spec()->check_switch($c2)) {
                    return $_ST_SHORT;
                } else {
                    return $_ST_BUNDLED;
                }
            }
        }
    }
}

sub _parse_long_switch {
    my ($self, $switch) = @_;
    
    $switch =~ s/^(-|--)//;
    
    my @vals = split(/=/, $switch, 2);
    
    if($#vals == 0) {
        return $vals[0];
    } else {
        return ($vals[0], $vals[1]);
    }
}

sub _parse_short_switch {
    my ($self, $switch) = @_;
    
    $switch =~ s/^-//;
    
    if(length($switch) == 1) {
        return $switch;
    } elsif(index($switch, '=') >= 0) {
        my @vals = split(/=/, $switch, 2);
        return ($vals[0] => $vals[1]);
    } else {
        return (substr($switch, 0, 1), substr($switch, 1));
    }
}

sub _parse_bundled_switch {
    my ($self, $switch) = @_;
    
    $switch =~ s/^-//;
    
    my %rh = ();
    
    my $last_switch;
    for(my $i = 0; $i < length($switch); ++$i) {
        my $c = substr($switch, $i, $i + 1);
        if($self->_spec()->check_switch($c)) {
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
                confess "illegal switch $switch\n";
            } 
        }
        $last_switch = $c;
    }
    
    $rh{'~~last'} = $last_switch;
    
    return %rh;
}

sub set_args {
    my $self = shift @_;
    
    return $self->_args(clone(@_));
}

sub get_args {
    my ($self) = @_;
    
    return $self->_args;
}

sub num_valid_args {
    my ($self) = @_;
    return $#{$self->valid_args} + 1;
}

sub num_invalid_args {
    my ($self) = @_;
    return $#{$self->invalid_args} + 1;
}

sub num_extra_args {
    my ($self) = @_;
    return $#{$self->extra_args} + 1;
}

sub get_usage {
    
}

sub get_help {
    
}

no Moose;

1;
