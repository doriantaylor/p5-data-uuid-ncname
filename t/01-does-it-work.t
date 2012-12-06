#!perl

use strict;
use warnings FATAL => 'all';
use Test::More;

our @UUIDS;

BEGIN {
    my $obj;
    my $gen = sub {};
    eval { require OSSP::uuid };
    if ($@) {
        local $@;
        eval { require Data::UUID };
        if ($@) {
            my $x = `uuidgen`;
            if ($? == 0) {
                $gen = sub { chomp(my $x = `uuidgen`) };
            }
            else {
                plan skip_all => 'Require something that generates UUIDs';
                exit;
            }
        }
        else {
            $obj = Data::UUID->new;
            $gen = sub { lc $obj->create_str };
        }
    }
    else {
        $obj = OSSP::uuid->new;
        $gen = sub { $obj->make('v4'); $obj->export('str') };
    }

    for my $i (1..100) {
        push @UUIDS, $gen->();
    }
}

plan tests => 4 * @UUIDS + 1;

use_ok('Data::UUID::NCName');

#my $uu = 'e846399e-e8ab-4d47-bb97-26f870eec17b';

for my $uu (@UUIDS) {
    #diag($uu);
    mooltipass($uu);
}

diag(Data::UUID::NCName::to_ncname('00000000-0000-0000-0000-000000000000'));

my $wtf = Data::UUID::NCName::to_ncname('f0000000-0000-4000-0000-00000000000f');
diag($wtf);
diag(Data::UUID::NCName::from_ncname($wtf));

my $ff = Data::UUID::NCName::to_ncname('ffffffff-ffff-4fff-ffff-fffffffffff1');

diag($ff);

diag(Data::UUID::NCName::from_ncname($ff));

diag(Data::UUID::NCName::from_ncname('E_wAAAAAAAAAAAAAAAAAAP'));

sub mooltipass {
    my $uuid = shift;

    my $ncn64 = Data::UUID::NCName::to_ncname($uuid);
    my $ncn32 = Data::UUID::NCName::to_ncname($uuid, 32);

    #diag($ncn64);
    is(length $ncn64, 22, "Base64 NCName is 22 characters long");

    my $uu64 = Data::UUID::NCName::from_ncname_64($ncn64);
    is($uu64, $uuid, 'Base64 content matches original UUID');

    #diag($ncn32);
    is(length $ncn32, 26, "Base32 NCName is 26 characters long");

    my $uu32 = Data::UUID::NCName::from_ncname_32($ncn32);
    is($uu32, $uuid, 'Base32 content matches original UUID');

}
