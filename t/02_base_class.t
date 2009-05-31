use strict;
use Test::More tests => 2;
use Mouse::Util::MetaRole;

do {
    package MyClass::Role::Object;
    use Mouse::Role;
    has 'foo' => (is => 'rw');

    package MyClass;
    use Mouse;
};

{
    Mouse::Util::MetaRole::apply_base_class_roles(
        for_class => 'MyClass',
        roles     => ['MyClass::Role::Object'],
    );

    my $meta = MyClass->meta;
    ok $meta->does_role('MyClass::Role::Object'),
        'apply MyClass::Role::Object to MyClass base class';
    can_ok 'MyClass' => 'foo';
}
