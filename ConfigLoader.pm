package App::Ack::ConfigLoader;

use strict;
use warnings;

use App::Ack::Filter;
use Carp ();
use Getopt::Long ();
use Text::ParseWords ();

=head1 App::Ack::ConfigLoader

=head1 FUNCTIONS

=head2 process_args( @sources )



=cut

sub process_filter_spec {
    my ( $spec ) = @_;

    if($spec =~ /^(\w+),(\w+),(.*)/) {
        return ( $1, App::Ack::Filter->create_filter($2, split(/,/, $3)) );
    } else {
        Carp::croak "invalid filter specification '$spec'";
    }
}

sub process_filetypes {
    my ( $opt, $arg_sources ) = @_;

    Getopt::Long::Configure('default'); # start with default options
    Getopt::Long::Configure(
        'no_ignore_case',
        'no_auto_abbrev',
        'pass_through',
    );
    my %additional_specs;
    my %type_filters;

    my $add_spec = sub {
        my ( undef, $spec ) = @_;

        my ( $name, $filter ) = process_filter_spec($spec);

        push @{ $type_filters{$name} }, $filter;

        $additional_specs{$name} = sub {
            push @{ $opt->{'filters'} }, @{ $type_filters{$name} };
        };
    };

    my $set_spec = sub {
        my ( undef, $spec ) = @_;

        my ( $name, $filter ) = process_filter_spec($spec);

        $type_filters{$name} = [ $filter ];

        $additional_specs{$name} = sub {
            push @{ $opt->{'filters'} }, @{ $type_filters{$name} };
        };
    };

    my %type_arg_specs = (
        'type-add=s' => $add_spec,
        'type-set=s' => $set_spec,
    );

    for(my $i = 0; $i < @$arg_sources; $i += 2) {
        my ( $source_name, $args ) = @$arg_sources[ $i, $i + 1];

        if( ref($args) ) {
            # $args are modified in place, so no need to munge $arg_sources
            Getopt::Long::GetOptionsFromArray($args, %type_arg_specs);
        } else {
            ( undef, $arg_sources->[$i + 1] ) =
                Getopt::Long::GetOptionsFromString($args, %type_arg_specs);
        }
    }

    return ( \%additional_specs, \%type_filters  );
}

sub get_arg_spec {
    my ( $opt, $extra_specs ) = @_;

    return {
        1                   => sub { $opt->{1} = $opt->{m} = 1 },
        'A|after-context=i' => \$opt->{after_context},
        'B|before-context=i'
                            => \$opt->{before_context},
        'C|context:i'       => sub { shift; my $val = shift; $opt->{before_context} = $opt->{after_context} = ($val || 2) },
        'a|all-types'       => \$opt->{all},
        'break!'            => \$opt->{break},
        c                   => \$opt->{count},
        'color|colour!'     => \$opt->{color},
        'color-match=s'     => \$ENV{ACK_COLOR_MATCH},
        'color-filename=s'  => \$ENV{ACK_COLOR_FILENAME},
        'color-lineno=s'    => \$ENV{ACK_COLOR_LINENO},
        'column!'           => \$opt->{column},
        count               => \$opt->{count},
        'env!'              => sub { }, # ignore this option, it is handled beforehand
        f                   => \$opt->{f},
        'filter!'           => \$App::Ack::is_filter_mode,
        flush               => \$opt->{flush},
        'follow!'           => \$opt->{follow},
        'g=s'               => sub { shift; $opt->{G} = shift; $opt->{f} = 1 },
        'G=s'               => \$opt->{G},
        'group!'            => sub { shift; $opt->{heading} = $opt->{break} = shift },
        'heading!'          => \$opt->{heading},
        'h|no-filename'     => \$opt->{h},
        'H|with-filename'   => \$opt->{H},
        'i|ignore-case'     => \$opt->{i},
        'ignore-directory|ignore-dir=s@' 
                            => \$opt->{idirs},
        'ignore-file=s@'    => \$opt->{ifiles},
        'invert-file-match' => \$opt->{invert_file_match},
        'lines=s'           => sub { shift; my $val = shift; push @{$opt->{lines}}, $val },
        'l|files-with-matches'
                            => \$opt->{l},
        'L|files-without-matches'
                            => sub { $opt->{l} = $opt->{v} = 1 },
        'm|max-count=i'     => \$opt->{m},
        'match=s'           => \$opt->{regex},
        'n|no-recurse'      => \$opt->{n},
        o                   => sub { $opt->{output} = '$&' },
        'output=s'          => \$opt->{output},
        'pager=s'           => \$opt->{pager},
        'nopager'           => sub { $opt->{pager} = undef },
        'passthru'          => \$opt->{passthru},
        'print0'            => \$opt->{print0},
        'Q|literal'         => \$opt->{Q},
        'r|R|recurse'       => sub { $opt->{n} = 0 },
        'show-types'        => \$opt->{show_types},
        'smart-case!'       => \$opt->{smart_case},
        'sort-files'        => \$opt->{sort_files},
        'u|unrestricted'    => \$opt->{u},
        'v|invert-match'    => \$opt->{v},
        'w|word-regexp'     => \$opt->{w},

        'version'           => sub { App::Ack::print_version_statement(); exit; },
        'help|?:s'          => sub { shift; App::Ack::show_help(@_); exit; },
        'help-types'        => sub { App::Ack::show_help_types(); exit; },
        'man'               => sub {
            require Pod::Usage;
            Pod::Usage::pod2usage({
                -verbose => 2,
                -exitval => 0,
            });
        }, # man sub
        $extra_specs ? %$extra_specs : (),
    }; # arg_specs
}

sub process_other {
    my ( $opt, $extra_specs, $arg_sources ) = @_;

    Getopt::Long::Configure('default'); # start with default options
    Getopt::Long::Configure(
        'no_ignore_case',
        'no_auto_abbrev',
    );

    my $arg_specs = get_arg_spec($opt, $extra_specs);

    for(my $i = 0; $i < @$arg_sources; $i += 2) {
        my ($source_name, $args) = @$arg_sources[$i, $i + 1];

        my $ret;
        if ( ref($args) ) {
            $ret = Getopt::Long::GetOptionsFromArray( $args, %{$arg_specs} );
        }
        else {
            ( $ret, $arg_sources->[$i + 1] ) =
                Getopt::Long::GetOptionsFromString( $args, %{$arg_specs} );
        }
        if ( !$ret ) {
            my $where = $source_name eq 'ARGV' ? 'on command line' : "in $source_name";
            App::Ack::die( "Invalid option $where" );
        }
    }

    # XXX We need to check on a -- in the middle of a non-ARGV source
}

sub should_dump_options {
    my ( $sources ) = @_;

    for(my $i = 0; $i < @{$sources}; $i += 2) {
        my ( $name, $options ) = @{$sources}[$i, $i + 1];
        if($name eq 'ARGV') {
            my $dump;
            Getopt::Long::Configure('default', 'pass_through');
            Getopt::Long::GetOptionsFromArray($options,
                'dump' => \$dump,
            );
            return $dump;
        }
    }
    return;
}

sub explode_sources {
    my ( $sources ) = @_;

    my @new_sources;

    Getopt::Long::Configure('default', 'pass_through');

    my %opt;
    my $arg_spec = get_arg_spec(\%opt);

    my $add_type = sub {
        my ( undef, $arg ) = @_;

        ( $arg ) = split /,/, $arg;
        $arg_spec->{$arg} = sub {};
    };

    for(my $i = 0; $i < @{$sources}; $i += 2) {
        my ( $name, $options ) = @{$sources}[$i, $i + 1];
        unless(ref($options) eq 'ARRAY') {
            $sources->[$i + 1] = $options =
                [ Text::ParseWords::shellwords($options) ];
        }
        for(my $j = 0; $j < @{$options}; $j++) {
            next unless $options->[$j] =~ /^-/;
            my @chunk = ( $options->[$j] );
            push @chunk, $options->[$j] while ++$j < @{$options} && $options->[$j] !~ /^-/;
            $j--;

            my @copy = @chunk;
            Getopt::Long::GetOptionsFromArray(\@chunk,
                'type-add=s' => $add_type,
                'type-set=s' => $add_type,
            );
            Getopt::Long::GetOptionsFromArray(\@chunk, %{$arg_spec});

            splice @copy, -1 * @chunk if @chunk; # XXX explain this
            push @new_sources, $name, \@copy;
        }
    }

    return \@new_sources;
}

sub compare_opts {
    my ( $a, $b ) = @_;

    my $first_a = $a->[0];
    my $first_b = $b->[0];

    $first_a =~ s/^--?//;
    $first_b =~ s/^--?//;

    return $first_a cmp $first_b;
}

sub dump_options {
    my ( $sources ) = @_;

    $sources = explode_sources($sources);

    my %opts_by_source;
    my @source_names;

    for(my $i = 0; $i < @{$sources}; $i += 2) {
        my ( $name, $contents ) = @{$sources}[$i, $i + 1];
        unless($opts_by_source{$name}) {
            $opts_by_source{$name} = [];
            push @source_names, $name;
        }
        push @{$opts_by_source{$name}}, $contents;
    }

    foreach my $name (@source_names) {
        my $contents = $opts_by_source{$name};

        print $name, "\n";
        print '=' x length($name), "\n";
        print "  ", join(' ', @{$_}), "\n" foreach sort { compare_opts($a, $b) } @{$contents};
    }
}

sub process_args {
    my $arg_sources = \@_;

    my %opt;

    if(should_dump_options($arg_sources)) {
        dump_options($arg_sources);
        exit(0);
    }

    my ( $type_specs, $type_filters ) = process_filetypes(\%opt, $arg_sources);
    process_other(\%opt, $type_specs, $arg_sources);
    while ( @{$arg_sources} ) {
        my ( $source_name, $args ) = splice( @$arg_sources, 0, 2 );

        # by this point in time, all of our sources should be transformed
        # into an array ref
        if ( ref($args) ) {
            if ($source_name eq 'ARGV') {
                @ARGV = @{$args};
            }
            elsif (@{$args}) {
                Carp::croak "source '$source_name' has extra arguments!";
            }
        }
        else {
            Carp::croak "The impossible has occurred!";
        };
    }
    return \%opt;
}

1; # End of App::Ack::ConfigLoader