use strict;
use Test::More tests => 11;
use Mouse::Util::MetaRole;

do {
    package MyClass::Role::Class;
    use Mouse::Role;
    has 'foo' => (is => 'ro');

    package MyClass::Role::Attribute;
    use Mouse::Role;
    has 'foo' => (is => 'ro');

    package MyClass;
    use Mouse;
};

{
    Mouse::Util::MetaRole::apply_metaclass_roles(
        for_class       => 'MyClass',
        metaclass_roles => ['MyClass::Role::Class'],
    );

    my $meta = MyClass->meta;
    ok $meta->meta->does_role('MyClass::Role::Class'),
        'apply MyClass::Role::Class to Mouse::Meta::Class';
    can_ok $meta => 'foo';
}

{
    Mouse::Util::MetaRole::apply_metaclass_roles(
        for_class                 => 'MyClass',
        attribute_metaclass_roles => ['MyClass::Role::Attribute'],
    );

    my $meta = MyClass->meta;

    ok $meta->attribute_metaclass->meta->does_role('MyClass::Role::Attribute'),
        'apply MyClass::Role::Attribute to Mouse::Meta::Attribute';
    ok $meta->meta->does_role('MyClass::Role::Class'),
        '... Mouse::Meta::Class still does MyClass::Role::Class';

    $meta->add_attribute(size => (is => 'rw'));
    can_ok $meta->get_attribute('size') => 'foo';
}

do {
    package MyClass2::Role::Class;
    use Mouse::Role;
    has 'foo' => (is => 'ro');

    package MyClass2::Role::Attribute;
    use Mouse::Role;
    has 'foo' => (is => 'ro');

    package MyClass2;
    use Mouse;
};

{
    Mouse::Util::MetaRole::apply_metaclass_roles(
        for_class                 => 'MyClass2',
        metaclass_roles           => ['MyClass2::Role::Class'],
        attribute_metaclass_roles => ['MyClass2::Role::Attribute'],
    );

    my $meta = MyClass2->meta;

    ok $meta->meta->does_role('MyClass2::Role::Class'),
        'apply MyClass2::Role::Class to Mouse::Meta::Class';
    can_ok $meta => 'foo';

    ok $meta->attribute_metaclass->meta->does_role('MyClass2::Role::Attribute'),
        'apply MyClass2::Role::Attribute to Mouse::Meta::Attribute';
    can_ok $meta->attribute_metaclass => 'foo';

    $meta->add_attribute(size => (is => 'rw'));
    my $attr = $meta->get_attribute('size');

    ok $attr->meta->does_role('MyClass2::Role::Attribute'),
        'apply MyClass2::Role::Attribute to attribute metaclass';
    can_ok $attr => 'foo';
}
