package Mouse::Util::MetaRole;

use 5.008_001;
use strict;
use warnings;
use List::MoreUtils qw(all);
use Mouse::Meta::Class;
use Mouse::Util;

our $VERSION = '0.01';

sub apply_metaclass_roles {
    my %opts = @_;
    return _make_new_metaclass($opts{for_class}, \%opts);
}

sub apply_base_class_roles {
    my %opts = @_;

    my $meta = Mouse::Meta::Class->initialize($opts{for_class});
    my $new_base = _make_new_class($meta->name, $opts{roles} || [], [ $meta->superclasses ]);

    if ($new_base ne $meta->name) {
        $meta->superclasses($new_base);
    }

    return $meta;
}

sub _make_new_metaclass {
    my $for  = shift;
    my $opts = shift;

    my $meta = Mouse::Meta::Class->initialize($for);
    return $meta unless grep { exists $opts->{$_ . '_roles'} } qw(metaclass attribute_metaclass);

    # create new meta
    my $new_metaclass = _make_new_class(ref $meta, $opts->{metaclass_roles} || []);
    my $new_meta = $new_metaclass->new(name => $for);

    if (exists $opts->{attribute_metaclass_roles}) {
        my $attribute_metaclass = _make_new_class(
            $meta->attribute_metaclass,
            $opts->{attribute_metaclass_roles},
        );

        no strict 'refs';
        no warnings 'redefine';
        *{ $new_metaclass . '::attribute_metaclass' } = sub { $attribute_metaclass };
    }

    return _reinitialize_metaclass($for, $new_meta);
}

sub _make_new_class {
    my $class        = shift;
    my $roles        = shift;
    my $superclasses = shift || [$class];

    my $meta = Mouse::Meta::Class->initialize($class);
    return $class unless $roles;
    return $class if $meta->can('does_role') and all { $meta->does_role($_) } @$roles;

    my $new_metaclass = Mouse::Meta::Class->create_anon_class(
        superclasses => $superclasses,
    )->name;

    Mouse::Util::apply_all_roles($new_metaclass, @$roles);

    return $new_metaclass;
}

sub _reinitialize_metaclass {
    my ($for, $meta) = @_;

    Mouse::Meta::Class::store_metaclass_by_name($for, $meta);
    {
        no strict 'refs';
        no warnings 'redefine';
        *{ $for . '::meta' } = sub { Mouse::Meta::Class->initialize($for) };
    }

    return $meta;
}

{ # FIXME: Mouse::Meta::Class#add_attribute should use attribute_metaclass()
    package # hide from PAUSE
        Mouse::Meta::Class;
    use Carp 'confess';
    use Scalar::Util 'blessed';
    use Mouse::Util;
    no warnings 'redefine';

    *attribute_metaclass = sub { 'Mouse::Meta::Attribute' };

    *add_attribute = sub {
        my $self = shift;

        if (@_ == 1 && blessed($_[0])) {
            my $attr = shift @_;
            $self->{'attributes'}{$attr->name} = $attr;
        } else {
            my $names = shift @_;
            $names = [$names] if !ref($names);
            my $metaclass = $self->attribute_metaclass;
            my %options = @_;

            if ( my $metaclass_name = delete $options{metaclass} ) {
                my $new_class = Mouse::Util::resolve_metaclass_alias(
                    'Attribute',
                    $metaclass_name
                );
                if ( $metaclass ne $new_class ) {
                    $metaclass = $new_class;
                }
            }

            for my $name (@$names) {
                if ($name =~ s/^\+//) {
                    $metaclass->clone_parent($self, $name, @_);
                }
                else {
                    $metaclass->create($self, $name, @_);
                }
            }
        }
    };

    *create = sub {
        my ($self, $package_name, %options) = @_;

        (ref $options{superclasses} eq 'ARRAY')
            || confess "You must pass an ARRAY ref of superclasses"
                if exists $options{superclasses};

        (ref $options{attributes} eq 'ARRAY')
            || confess "You must pass an ARRAY ref of attributes"
                if exists $options{attributes};

        (ref $options{methods} eq 'HASH')
            || confess "You must pass a HASH ref of methods"
                if exists $options{methods};

        do {
            ( defined $package_name && $package_name )
                || confess "You must pass a package name";

            my $code = "package $package_name;";
            $code .= "\$$package_name\:\:VERSION = '" . $options{version} . "';"
                if exists $options{version};
            $code .= "\$$package_name\:\:AUTHORITY = '" . $options{authority} . "';"
                if exists $options{authority};

            eval $code;
            confess "creation of $package_name failed : $@" if $@;
        };

        my %initialize_options = %options;
        delete @initialize_options{qw(
            package
            superclasses
            attributes
            methods
            version
            authority
        )};
        my $meta = $self->initialize( $package_name => %initialize_options );

        # FIXME totally lame
        $meta->add_method('meta' => sub {
            $self->initialize(ref($_[0]) || $_[0]);
        });

        $meta->superclasses(@{$options{superclasses}})
            if exists $options{superclasses};
        # NOTE:
        # process attributes first, so that they can
        # install accessors, but locally defined methods
        # can then overwrite them. It is maybe a little odd, but
        # I think this should be the order of things.
        if (exists $options{attributes}) {
            foreach my $attr (@{$options{attributes}}) {
                $self->attribute_metaclass->create($meta, $attr->{name}, %$attr);
            }
        }
        if (exists $options{methods}) {
            foreach my $method_name (keys %{$options{methods}}) {
                $meta->add_method($method_name, $options{methods}->{$method_name});
            }
        }
        return $meta;
    };
}

1;

=head1 NAME

Mouse::Util::MetaRole - Apply role to class and attribute metaclass.

=head1 SYNOPSIS

    package MyApp::Mouse;

    use Mouse;
    use Mouse::Util::MetaRole;

    sub import {
        my $caller = shift;

        Mouse->import({ into_level => 1 });

        Mouse::Util::MetaRole::apply_metaclass_roles(
            for_class                 => $caller,
            metaclass_roles           => [],
            attribute_metaclass_roles => [],
        );
    }

=head1 DESCRIPTION

This utility module is designed to help authors of Mouse extensions
write extensions that are able to cooperate with other Mouse
extensions. To do this, you must write your extensions as roles, which
can then be dynamically applied to the caller's metaclasses.

This module makes sure to preserve any existing superclasses and roles
already set for the meta objects, which means that any number of
extensions can apply roles in any order.

=head1 FUNCTIONS

=head2 apply_metaclass_roles(%args)

This function will apply roles to one or more metaclasses for the
specified class. It accepts the following parameters:

=over 4

=item * for_class => $name

This specifies the class for which to alter the meta classes.

=item * metaclass_roles => \@roles

=item * attribute_metaclass_roles => \@roles

These parameter all specify one or more roles to be applied to the
specified metaclass. You can pass any or all of these parameters at
once.

=back

=head1 AUTHOR

NAKAGAWA Masaki E<lt>masaki@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
