package Data::UUID::NCName;

use 5.008;
use strict;
use warnings FATAL => 'all';

use MIME::Base32 ();
use MIME::Base64 ();
use Carp ();

use base qw(Exporter);

=head1 NAME

Data::UUID::NCName - It's a UUID, AND it's an NCName!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use Data::UUID::NCName qw(:all);

    my $uuid = '1ff916f3-6ed7-443a-bef5-f4c85f18cd10';
    my $ncn  = to_ncname($uuid);

    # from Test::More, this will output 'ok':
    is(from_ncname($ncn), $uuid, 'Decoding result matches original');

=head1 DESCRIPTION

The UUID is a generic identifier which is large enough to be globally
unique.

=over 4

=item XML IDs

The C<ID> production appears to have been constricted, inadvertently
or otherwise, from L<Name|http://www.w3.org/TR/xml11/#NT-Name> in both
the XML 1.0 and 1.1 specifications, to
L<NCName|http://www.w3.org/TR/xml-names/#NT-NCName> by L<XML Schema
Part 2|http://www.w3.org/TR/xmlschema-2/#ID>. This removes the colon
character C<:> from the grammar. The net effect is that

    <foo id="urn:uuid:b07caf81-baae-449d-8a2e-48c0f5fa5538"/>

while being a I<well-formed> ID I<and> valid under DTD validation, is
I<not> valid per XML Schema Part 2 or anything that uses it
(e.g. Relax NG).

=item RDF blank node identifiers

Blank node identifiers in RDF are intended for serialization, to act
as a handle so that multiple RDF statements can refer to the same
blank node. The L<RDF abstract syntax
specifies|http://www.w3.org/TR/rdf-concepts/#section-URI-Vocabulary>
that the validity constraints of blank node identifiers be delegated
to the concrete syntax specifications. The L<RDF/XML syntax
specification|http://www.w3.org/TR/rdf-syntax-grammar/#rdf-id>
lists the blank node identifier as NCName. However, according to
L<the Turtle spec|http://www.w3.org/TR/turtle/#BNodes>, this is a
valid blank node identifier:

    _:42df00ec-30a2-431f-be9e-e3a612b325db

despite L<an older
version|http://www.w3.org/TeamSubmission/turtle/#nodeID> listing a
production equivalent to the more conservative NCName. NTriples
syntax is L<even more
constrained|http://www.w3.org/TR/rdf-testcases/#ntriples>, given as
C<[A-Za-z][0-9A-Za-z]*>.

=item Generated symbols

=back

=head1 EXPORT

No subroutines are exported by default. Be sure to include one of the
following in your C<use> statement:

=over 4

=item :all

Import all functions.

=item :decode

Import decode-only functions.

=item :encode

Import encode-only functions.

=item :32

Import base32-only functions.

=item :64

Import base64-only functions.

=back

=cut

# exporter stuff

our %EXPORT_TAGS = (
    all => [qw(to_ncname from_ncname
               to_ncname_32 from_ncname_32
               to_ncname_64 from_ncname_64)],
    decode => [qw(from_ncname from_ncname_32 from_ncname_64)],
    encode => [qw(to_ncname to_ncname_32 to_ncname_64)],
    32     => [qw(to_ncname_32 from_ncname_32)],
    64     => [qw(to_ncname_64 from_ncname_64)],
);

# export nothing by default
our @EXPORT = ();
our @EXPORT_OK = @{$EXPORT_TAGS{all}};

# uuid format string, so meta.
my $UUF = sprintf('%s-%s-%s-%s-%s', '%02x' x 4, ('%02x' x 2) x 3, '%02x' x 6);
# yo dawg i herd u liek format strings so we put a format string in yo
# format string

# dispatch tables for encoding/decoding

my %ENCODE = (
    32 => sub {
        my $out = MIME::Base32::encode_rfc3548(shift);

        # we want lower case because IT IS RUDE TO SHOUT
        lc substr($out, 0, 25);
    },
    64 => sub {
        my $out = MIME::Base64::encode(shift);
        # note that the rfc4648 sequence ends in +/ or -_
        $out =~ tr!+/!-_!;

        substr($out, 0, 21);
    },
);

my %DECODE = (
    32 => sub {
        my $in = shift;
        $in = uc substr($in, 0, 25) . '0';

        MIME::Base32::decode_rfc3548($in);
    },
    64 => sub {
        my $in = shift;
        #warn $in;
        $in = substr($in, 0, 21) . 'A==';
        # note that the rfc4648 sequence ends in +/ or -_
        $in =~ tr!-_!+/!;

        #warn unpack 'H*', MIME::Base64::decode($in);

        MIME::Base64::decode($in);
    },
);

sub _reassemble {
    my $list = shift;

    my @new;
    for my $i (0..$#$list) {
        my $j = int($i/2);
        if ($i % 2) {
            $new[$j] |= ($list->[$i] << 4);
        }
        else {
            $new[$j] = $list->[$i];
        }
    }

    pack 'C*', @new;
}

sub _bin_uuid_to_pair {
    my $data = shift;

    # this seems to do the right thing
    # warn unpack 'H*', $data;

    # XXX could probably do this whole thing with some bit-shifting
    # three-card monte but i don't really feel up to it.

    # vec tries to be clever for <= 4-bit chunks, so the nybbles of
    # each byte come out flipped around.
    my @list = map { vec($data, $_, 4) } (0..31);

    # zero-pad the list, because i'm about to...
    splice @list, 31, 0, 0;

    # ...pull out the version.
    my $ver = splice @list, 13, 1;

    warn join('-', @list);

    # rebuild as octets
    my $out = _reassemble(\@list);

    # yup
    # warn unpack 'H*', $out;

    # this should be an integer and a binary string
    return ($ver, $out);
}

sub _pair_to_bin_uuid {
    my ($ver, $data) = @_;

    #warn unpack 'H*', $data;

    # the version should be between 0 and 15.
    $ver &= 15;

    my @list = map { vec($data, $_, 4) } (0..31);
    # get rid of the second-to-last quartet
    splice @list, 30, 1;
    # put the version back
    splice @list, 13, 0, $ver;

    #warn join('-', @list);

    # remove any accumulated overhang
    @list = @list[0..31];

    _reassemble(\@list);
}

sub _encode_version {
    my $ver = $_[0] & 15;
    # A (0) starts at 65. this should never be higher than F (version
    # 5) for a valid UUID, but even an invalid one will never be
    # higher than P (15).

    # XXX boo-hoo, this will break in EBCDIC.
    chr($ver + 65);
}

sub _decode_version {
    # modulo makes sure this always returns between 0 and 15
    return((ord(uc $_[0]) - 65) % 16);
}

=head1 SUBROUTINES

=head2 to_ncname $UUID [, $RADIX ]

Turn C<$UUID> into an NCName. The UUID can be in the canonical
(hyphenated) hexadecimal form, non-hyphenated hexadecimal, Base64
(regular and base64url), or binary. The function returns a legal
NCName equivalent to the UUID, in either Base32 or Base64 (url), given
a specified C<$RADIX> of 32 or 64. If the radix is omitted, Base64
is assumed.

=cut

sub to_ncname {
    my ($uuid, $radix) = @_;

    if ($radix) {
        Carp::croak("Radix must be either 32 or 64, not $radix")
              unless $radix == 32 || $radix == 64;
    }
    else {
        $radix = 64;
    }

    # get the uuid into a binary string
    my $bin;
    if (length $uuid == 16) {
        # this is already a binary string
        $bin = $uuid;
    }
    else {
        # get rid of any whitespace
        $uuid =~ s/\s+//g;

        # handle hexadecimal
        if ($uuid =~ /^[0-9A-Fa-f-]{32,}$/) {
            $uuid =~ s/-//g;
            #warn $uuid;
            $bin = pack 'H*', $uuid;
        }
        # handle base64
        elsif ($uuid =~ m!^[0-9A-Za-z=+/_-]$!) {
            # canonicalize first
            $uuid =~ tr!-_!+/!;
            $bin = MIME::Base64::decode($uuid);
        }
        else {
            Carp::croak("Couldn't figure out what to do with putative UUID.");
        }
    }


    # extract the version
    my ($version, $content) = _bin_uuid_to_pair($bin);
    #warn $version;

    # wah-lah.
    _encode_version($version) . $ENCODE{$radix}->($content);
}

=head2 from_ncname $NCNAME [, $FORMAT, $RADIX ]

Turn an appropriate C<$NCNAME> back into a UUID, where I<appropriate>,
unless overridden by C<$RADIX>, is defined beginning with one initial
alphabetic letter (A to Z, case-insensitive) followed by either:

=over 4

=item B<25> Base32 characters, or

=item B<21> Base64URL characters.

=back

The function will return C<undef> immediately if it cannot match
either of these patterns. Input past the 21-character mark (for
Base64) or 25-character mark (for Base32) is ignored.

This function returns a UUID of type C<$FORMAT>, which if not left
undefined, must be one of the following:

=over 4

=item str

The canonical UUID format, like so:
C<33fcc995-5d10-477e-a9b4-c9cc405bbf04>. This is the default.

=item hex

The same thing, minus the hyphens.

=item b64

Base64.

=item bin

A binary string.

=back

=cut

my %FORMAT = (
    str => sub {
        sprintf $UUF, unpack 'C*', shift;
    },
    hex => sub {
        unpack 'H*', shift;
    },
    b64 => sub {
        my $x = MIME::Base64::encode(shift);
        $x =~ s/=+$//;
        $x;
    },
    bin => sub {
        shift;
    },
);

sub from_ncname {
    my ($ncname, $format, $radix) = @_;

    # handle formatter
    $format ||= 'str';
    Carp::croak("Invalid format $format") unless $FORMAT{$format};
    # reuse this variable because it doesn't get used for anything else
    $format = $FORMAT{$format};

    # obviously this must be defined
    return unless defined $ncname;

    # no whitespace
    $ncname =~ s/^\s*(.*?)\s*$/$1/;

    # note that the rfc4648 sequence ends in +/ or -_
    my ($version, $content) = ($ncname =~ /^([A-Za-z])([0-9A-Za-z_-]{21,})$/)
        or return;

    if ($radix) {
        Carp::croak("Radix must be either 32 or 64, not $radix")
              unless $radix == 32 || $radix == 64;
    }
    else {
        # detect what to do based on input
        my $len = length $ncname;
        if ($ncname =~ m![_-]!) {
            # containing these characters means base64url
            $radix = 64;
        }
        elsif ($len >= 26) {
            # if it didn't contain those characters and is this long
            $radix = 32;
        }
        elsif ($len >= 22) {
            $radix = 64;
        }
        else {
            # the regex above should ensure this is never reached.
            Carp::croak
                  ("Not sure what to do with an identifier of length $len.");
        }
    }

    # get this stuff back to canonical form
    $version = _decode_version($version);
    # warn $version;
    $content = $DECODE{$radix}->($content);
    # warn  unpack 'H*', $content;

    # reassemble the pair
    my $bin = _pair_to_bin_uuid($version, $content);

    # *now* format.
    $format->($bin);
}

=head2 to_ncname_64 $UUID

Shorthand for Base64 NCNames.

=cut

sub to_ncname_64 {
    to_ncname(shift, 64);
}

=head2 from_ncname_64 $NCNAME [, $FORMAT ]

Ditto.

=cut

sub from_ncname_64 {
    from_ncname(shift, shift, 64);
}

=head2 to_ncname_32 $UUID

Shorthand for Base32 NCNames.

=cut

sub to_ncname_32 {
    to_ncname(shift, 32);
}

=head2 from_ncname_32 $NCNAME [, $FORMAT ]

Ditto.

=cut

sub from_ncname_32 {
    from_ncname(shift, shift, 32);
}

=head1 AUTHOR

Dorian Taylor, C<< <dorian at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-uuid-ncname at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=UUID-NCName>.  I will
be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Data::UUID::NCName

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=UUID-NCName>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/UUID-NCName>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/UUID-NCName>

=item * Search CPAN

L<http://search.cpan.org/dist/UUID-NCName/>

=back

=head1 SEE ALSO

=over 4

=item L<Data::UUID>

=item L<OSSP::uuid>

=item L<RFC 4122|http://tools.ietf.org/html/rfc4122>

=item L<RFC 4648|http://tools.ietf.org/html/rfc4648>

=item L<Namespaces in XML|http://www.w3.org/TR/xml-names/#NT-NCName> (NCName)

=item L<W3C XML Schema Definition Language (XSD) 1.1 Part 2: Datatypes|http://www.w3.org/TR/xmlschema11-2/#ID> (ID)

=item L<RDF/XML Syntax Specification (Revised)|http://www.w3.org/TR/rdf-syntax-grammar/#rdf-id>

=item L<Turtle|http://www.w3.org/TR/turtle/#BNodes>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Dorian Taylor.

Licensed under the Apache License, Version 2.0 (the "License"); you
may not use this file except in compliance with the License.  You may
obtain a copy of the License at
L<http://www.apache.org/licenses/LICENSE-2.0> .

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied.  See the License for the specific language governing
permissions and limitations under the License.

=cut

1; # End of Data::UUID::NCName
