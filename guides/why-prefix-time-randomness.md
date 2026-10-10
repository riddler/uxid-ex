# Why a UXID has a prefix, a time and randomness

A UXID such as `usr_01epey2p06tr1rtv07xa82zgjj` is three things joined
together: a prefix that names the resource, a timestamp, and a run of random
bits. Each part answers a different question about an identifier, and each
one costs characters. This page is about why the format spends its characters
that way, and what you give up or gain when you turn the dial on any of them.

## The prefix: an ID that says what it points at

An identifier spends most of its life outside the code that minted it: in a
log line, a URL, an error report, a support conversation, a spreadsheet
someone pasted together. A bare number or a bare UUID is anonymous in all of
those places. You can see that it is an ID, but not which kind of resource
it names, so every reader has to go and look it up.

The prefix moves that knowledge into the ID itself. An ID that starts `usr_`
names a user before anyone queries anything. That is also what makes an ID routable: given
only the string, code can split off the prefix and decide which resource, and
which table, it belongs to. The [prefix registry](registry.md) is built on
exactly this, and it is why the registry insists that every prefix in an app
is unique. Two resources sharing a prefix would make the ID lie about what it
names.

A hand-rolled CI test is a weak place to keep that rule, and the prefix's
format with it, so `UXID.Registry` makes both the compiler's job. It also
turns the same declarations into a runtime routing table (prefix to schema) for the ID-driven patterns Adam
Kirk describes in his ElixirConf US 2025 talk, [_UXIDs in Elixir/Ecto_][uxid_talk_url]:
authorization and IDOR checks, admin auto-linking, and Relay global IDs.

The prefix is joined to the body by a delimiter that can never appear in the
body, so the split is unambiguous without consulting anything. The default is
an underscore rather than a hyphen because a double-click selects a word, and
most tools treat `usr_01epey2p06tr1rtv07xa82zgjj` as one word but stop at a
hyphen.

What the prefix costs is length, and a small amount of disclosure: anyone who
sees the ID learns what kind of thing it names. For an identifier that is
shown to people that is usually the point. Where it is not wanted, the prefix
is optional; with no prefix, the body alone is a plain ULID.

## The timestamp: an ID that sorts by when it was made

The body starts with the time the ID was minted, in milliseconds, encoded so
that a later time always sorts after an earlier one. That ordering is what
"K-sortable" means: sort a set of IDs that share a prefix as plain strings and
you get them in roughly the order they were created.

The reason to want that is mostly the database. A primary key that arrives in
creation order is appended to the end of an index, the same way an
auto-increment key is, instead of landing at a random position the way a
random UUID does. Recent rows stay close together, and a range of IDs is also
a range of time. The timestamp is also simply useful to read: `UXID.decode/1` tells you when an ID
was minted without a lookup.

An auto-increment key gives you ordering too, but only by asking the
datastore for the next number. A timestamp gives ordering with no
coordination at all: any process on any node can mint an ID from its own
clock, before the row exists, and the IDs still interleave in time order. The
price is that the ordering is only as good as the clocks involved, and only to
the millisecond. Within one millisecond the order is decided by the random
part, which is arbitrary, unless you ask for [monotonic IDs](monotonic.md).

The timestamp also discloses something: anyone holding an ID can read when it
was created. For most resources that is harmless, and often already visible
elsewhere. When it is not, a [deterministic ID](deterministic.md) carries no
timestamp at all, at the cost of having no time order.

## The randomness: an ID that does not collide and cannot be guessed

The timestamp alone would make two IDs minted in the same millisecond
identical. The random bits that follow it are what keep them apart, and they
are drawn from a cryptographically strong source, so they also make the next
ID impossible to predict from the last one. That second property is the one
an auto-increment key lacks: given `1041` you can guess `1042`, and a public
API that accepts guessable IDs invites people to walk through its records.

Because the timestamp already separates IDs from different milliseconds, the
randomness only has to separate IDs minted in the *same* millisecond. That is
the observation behind making the amount of randomness a choice rather than a
constant. A resource minted a few times per millisecond at its busiest needs
far fewer random bits than one filled by bulk imports, and every bit saved is
a shorter ID to read, copy and say aloud. The [Sizes & Encoding](sizes.md)
page sets out what each size carries and the collision odds that follow.

The trade-off runs in both directions. Fewer random bits mean shorter IDs,
but also a smaller space within each millisecond, so a burst collides sooner
and a guess is more likely to land. The smallest size carries no randomness
at all and is only sound when something else guarantees uniqueness. More
random bits mean longer IDs that are, in practice, unguessable. The right size
is decided by the peak burst rate and by whether the ID is exposed to people
who should not be able to guess it, not by how many rows the table will
eventually hold.

## How the three parts work together

None of the parts is enough alone. A prefix with a counter is readable but
guessable and needs coordination. A timestamp alone collides. Randomness alone
is the random UUID: safe and coordination-free, but anonymous and unordered.
The format layers them so each covers what the others cannot: the prefix says
what the ID is, the time says when it was made and gives it an order, and the
randomness makes it unique within that moment and hard to guess.

Two options trade one part against another, and both are easier to reason
about with that picture in mind. Compact time takes eight bits from the
timestamp and gives them to the randomness, which buys collision resistance
in fewer characters at the cost of a timestamp that only reaches about
mid-2038. Monotonic mode keeps the random start but steps forward from it
within a millisecond, which guarantees uniqueness and order inside one
process at the cost of IDs that are easier to predict from their neighbours.
[Deterministic IDs](deterministic.md) drop the time and the randomness
altogether in favour of a hash of a known input, which buys stability and
gives up both order and secrecy.

The body is written in Crockford Base32, lowercase by default, for the same reason the
prefix exists: an ID is something people handle. The alphabet leaves out
letters that are easily confused with digits, so an ID read over the phone or
copied by hand comes back the way it was sent.

<!-- LINKS -->
[uxid_talk_url]: https://www.youtube.com/watch?v=YIIJClhjxOA
