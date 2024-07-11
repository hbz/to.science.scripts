#!/usr/bin/perl -w
# Parst die Website merkurist.de/mainz, sucht nach JSON-Dateien für Artikel.
# Hängt URLs für JSON-Dateien Zeile für Zeile an die Datei cdn.txt an.
#|-----------+------------+---------------------------------------------------
#| Autor     | Datum      | Beschreibung
#|-----------+------------+---------------------------------------------------
#| I. Kuss   | 11.07.2024 | Neuanlage
#|-----------+------------+---------------------------------------------------
# Quelle: https://www.linux-magazin.de/ausgaben/2011/11/perl-snapshot/

use strict;
use warnings;
use WWW::Scripter;
use Sysadm::Install qw(:all);
use HTML::TreeBuilder::XPath;
use JSON::Parse 'parse_json';

my $w = WWW::Scripter->new();
$w->use_plugin('Ajax');

$w->get('https://merkurist.de/mainz');

$w->wait_for_timers( max_wait => 1 );

my $tree= HTML::TreeBuilder::XPath->new();
$tree->parse( $w->content() );
my $node;
# Suche "chapterSlug"
my $chapterSlug = "";
foreach( $tree->findnodes( '/html/head/script' )) {
	$node = $_;
	#printf "node found: %s\n", $node->as_HTML;
	if( $node->as_HTML =~ /chapterSlug: '([^']+)',/ ) {
		$chapterSlug=$1;
		#printf "Found chapterSlug: $chapterSlug\n";
		last;
	}
}
# Schreibe-Artikel-URLs (sie führen jeweils zu einer JSON-Datei) in eine Datei
my $filename = 'cdn.txt';
open(my $fh, '>>', $filename) or die "Could not open file '$filename' $!";
# Hole Übersichtsseite für Artikel
$w->get('https://merkurist.de/api/merkurist-de/'.$chapterSlug.'/articles');
#printf "articles %s\n", $w->content();
my $articles_arr = parse_json ($w->content()); # a reference to a Perl array
foreach my $obj (@{$articles_arr}) {
	print $fh "https://merkurist.de/api/merkurist-de/" . $chapterSlug . "/articles/" . $obj->{id} . "\n";
}
# Hole Übersichtsseite für gesponsorte Artikel
$w->get('https://merkurist.de/api/merkurist-de/'.$chapterSlug.'/sponsoredArticles');
$articles_arr = parse_json ($w->content()); # a reference to a Perl array
foreach my $obj (@{$articles_arr}) {
	print $fh "https://merkurist.de/api/merkurist-de/" . $chapterSlug . "/sponsoredArticles/" . $obj->{id} . "\n";
}
close $fh;
exit 0;
