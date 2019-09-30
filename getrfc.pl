#!/usr/bin/perl
# Name          : getrfc
# Author        : Benjamin Ahola
# Date          : 03/02/2018
# Version       : 1.0
# Description   : Retrieves RFC document based on user specified
#               : number.
# Usage         : getrfc [RFC NUM]

#TODO: Add functionality to parse a regular expression for rfc names and descriptions

use strict;
use v5.14;
use warnings;

use LWP::UserAgent;
use URI;
use HTML::TableExtract;
use File::Temp qw/tempfile/;

use constant HOST=> "https://www.rfc-editor.org";
use constant URI_SEARCH_PATH=> "search/rfc_search_detail.php";
use constant UA_STRING=> "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2227.1 Safari/537.36";

sub fetch_by_keywords(@);
sub fetch_by_num($);
sub display_output($);
sub usage(_);

display_output do {

  usage() unless @ARGV;

  my $output;

  for($ARGV[0]) { 
    #Starts with a letter
    if( m/^[\p{Lu}\p{Ll}]/ ){ $output= fetch_by_keywords @ARGV }
    #Starts with a digit
    elsif( m/^\p{Nd}/ )     { $output= fetch_by_num $ARGV[0] }
    else                    { die "Invalid entry" }
  }

  $output; #Passed to display_output
};

=pod
=cut
sub usage(_)
{
  #TODO: Create a proper usage msg
  print "Usage: getrfc [rfc number]\n"; 
  exit 1;
}

=pod
=cut
sub display_output($) {
  my ($fh, $fn)= tempfile(UNLINK=> 1);
  print ${fh} $_[0];
  close $fh;
  system( 'less', $fn ) == 0 or die "system: \$?=$?";
}

=pod
=cut
sub fetch_by_num($) {
  die qq/Invalid RFC Number "$_[0]"/ unless $_[0] =~ m/^\p{Nd}+$/; 

  my ($rfc_num)= @_;
  my $req_uri;

  $req_uri= build_uri( HOST, "rfc/rfc$rfc_num.txt" );
  return make_req( build_ua(), $req_uri );
}

#TODO: Retrieve a complete listing of all results from search 
=pod
=head1 fetch_by_keywords
  Builds and sends a request uri using keywords instead of 
  an RFC number.
=cut
sub fetch_by_keywords(@) {
  #TODO: join all keywords passed to function together.
  my $keywords= shift;
  my $req_uri;

  $req_uri= build_uri( HOST, URI_SEARCH_PATH ); 
  $req_uri->query_form( "title"=> $keywords );

  return make_req( build_ua(), $req_uri );
}

=pod
=cut
sub build_uri {
  my ($host, $path)= @_;
  my $uri= URI->new( $host );

  $uri->path( $path );
  return $uri;
}

=pod
  Creates a user agent to make requests to the
  server.
=cut
sub build_ua(_) {
  my $user_agent_string;
  $user_agent_string= $_[0] // UA_STRING;

  my $ua= LWP::UserAgent->new;
  $ua->agent( $user_agent_string ); 

  return $ua;
}

=pod
=cut
sub make_req {
  my ( $ua, $req_uri )= @_;

  my $req= HTTP::Request->new( GET=> $req_uri );
  $req->header( Accept=> "text/html" );

  my $res= $ua->request( $req );

  if( $res->code !~ m/200/ ) {
    die do {
      my $error_msg;
      for( $res->code ) {
        if( m/404/ )    { $error_msg= "RFC was not found!" }
        elsif( m/500/ ) { $error_msg= "Server error!" }
        else            { $error_msg= "Something went wrong!" }
      }
      $error_msg;
    }
  }
  return $res->decoded_content;
}

=pod
=cut
sub parse_table_data {
  my $te= HTML::TableExtract->new( 
    headers=> [ qw( Number Title Date Status ) ] );
  $te->parse( @_ );

  return $te->table;
}

#TODO: Remove non-printable characters
#TODO: Make output a little more pretty.
=pod
=cut
sub print_listing{
  my $cntr;
  foreach my $row ( @_->rows ){
    print " ". ++$cntr. " [ @$row[0] ] @$row[1]\n";
    print "\tDate\t: @$row[2]\n";
    print "\tStatus\t: @$row[3]\n";
    print "-" x 50 ."\n";
  }
}
