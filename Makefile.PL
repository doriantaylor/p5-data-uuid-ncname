use inc::Module::Install;

name     'UUID-NCName';
all_from 'lib/UUID/NCName.pm';
author   q{Dorian Taylor <dorian@cpan.org>};
license  'apache';

build_requires 'Test::More';

auto_install;

WriteAll;

