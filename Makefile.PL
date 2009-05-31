use inc::Module::Install;
name 'Mouse-Util-MetaRole';
all_from 'lib/Mouse/Util/MetaRole.pm';

requires 'Mouse' => '0.23';
requires 'List::MoreUtils';
requires 'Carp';
requires 'Scalar::Util' => '1.14';

tests 't/*.t';
test_requires 'Test::More';
test_requires 'Test::UseAllModules';
author_tests 'xt';
use_test_base;

auto_set_repository;
auto_include_deps;
WriteAll;
