#!perl

use strict;
use warnings FATAL => 'all';
use Test::More;

our @UUIDS;

BEGIN {
    open my $csv, 't/samples.csv' or die 'no test content';
    while (my $line = <$csv>) {
        chomp $line;
        my @line = split /\s*,\s*/, $line;
        push @UUIDS, \@line;
    }
}

plan tests => 6 * @UUIDS + 7;

use_ok('Data::UUID::NCName', ':all');

# EXPECTED OUTPUTS

my $z = '00000000-0000-0000-0000-000000000000';

my $z64 = to_ncname_64($z, version => 0);
my $z32 = to_ncname_32($z, version => 0);

is($z64, 'AAAAAAAAAAAAAAAAAAAAAA',     'Null64 UUID OK');
is($z32, 'aaaaaaaaaaaaaaaaaaaaaaaaaa', 'Null32 UUID OK');

my $f = 'ffffffff-ffff-ffff-ffff-ffffffffffff';

my $f64 = to_ncname_64($f, version => 0);
my $f32 = to_ncname_32($f, version => 0);

#diag('E' . MIME::Base64::encode_base64url(pack 'C*', (255) x 15, 15 << 2));

is($f64, 'P____________________P',     'FF64 UUID OK');
is($f32, 'p777777777777777777777777p', 'FF32 UUID OK');

my $f0 = 'ffffffff-ffff-4fff-ffff-fffffffffff0';
# my $z0 = '00000000-0000-4000-0000-00000000000f';
# my $x0 = 'ffffffff-ffff-4fff-0fff-ffffffffffff';
# my $y0 = '00000000-0000-4000-f000-000000000000';

my $f064   = to_ncname_64($f0, version => 0);
# my $z064   = to_ncname_64($z0, version => 0);
# my $f064v1 = to_ncname_64($f0, version => 1);
# my $z064v1 = to_ncname_64($z0, version => 1);
# my $y064v1 = to_ncname_64($y0, version => 1);
# my $x064v1 = to_ncname_64($x0, version => 1);

# diag($f064);
# diag($f064v1);

# diag($z064);
# diag($z064v1);

# diag($x064v1);
# diag($y064v1);

#my $lint = substr
#    MIME::Base64::encode_base64url(pack 'C*', (0) x 15, 0xf << 2), 0, 21;

#diag(MIME::Base64::encode_base64url(pack 'C*', 0b00001111));
#diag(MIME::Base64::encode_base64url(pack 'C*', 0b00111100));
#diag(MIME::Base64::encode_base64url(pack 'C*', 0b11110000));

#diag(unpack 'H*', MIME::Base64::decode_base64url('8PA'));

# D    w
# 0x03 0x30

#diag("E$lint");

is($f064, 'E____________________A', 'F064 ends with A');

#diag($f064);
#diag($z064);

my $rando = 'bd6fbdd8-ca6a-43d4-8360-5d7cb1aee563';
my $v1n = to_ncname($rando, radix => 64, version => 1);
my $v1u = from_ncname($v1n, version => 1);
is($v1u, $rando, 'identifier version 1 matches');

# FUZZ TESTING

for my $uu (@UUIDS) {
    #diag($uu);
    mooltipass(@$uu);
}

sub mooltipass {
    my ($v, $uuid, $t32, $t58, $t64) = @_;

    # diag("version $v: $uuid -> $t32, $t58, $t64");

    my %p = (version => $v);

    # try turning the uuid into respective values
    my $ncn32 = Data::UUID::NCName::to_ncname($uuid, 32, %p);
    my $ncn58 = Data::UUID::NCName::to_ncname($uuid, 58, %p);
    my $ncn64 = Data::UUID::NCName::to_ncname($uuid, 64, %p);

    is($ncn32, $t32, 'base32 converts ok');
    is($ncn58, $t58, 'base58 converts ok');
    is($ncn64, $t64, 'base64 converts ok');

    my $t32u = Data::UUID::NCName::from_ncname($t32, %p, radix => 32);
    my $t58u = Data::UUID::NCName::from_ncname($t58, %p, radix => 58);
    my $t64u = Data::UUID::NCName::from_ncname($t64, %p, radix => 64);

    is($t32u, $uuid, 'base32 round trip ok');
    is($t58u, $uuid, 'base58 round trip ok');
    is($t64u, $uuid, 'base64 round trip ok');
}

#diag(to_ncname('00000000-0000-4000-0000-00000000000f'));
#diag(from_ncname('EAAAAAAAAAAAAAAAAAAAAP'));
