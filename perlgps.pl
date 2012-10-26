#!/usr/bin/env perl
# Simple GPS-Info and Skyview written in Perl by Herbert Lange
# Based on Hello wxPerl sample by Mattia Barbon; licensed as Perl itself
# With parts from plasma-gps
use strict;
use warnings;
use Wx;
use IO::Socket;
use utf8;


package MyTimer;
{
use vars qw(@ISA);
use Data::Dumper;
use JSON::Parse 'json_to_perl'; 

@ISA=qw(Wx::Timer);
my $frame;
my $sock=new IO::Socket::INET(
    PeerAddr => 'localhost',
    PeerPort => '2947',
    Proto => 'tcp',
    Blocking => 0
    );

sub new
{
    my( $this ) = shift->SUPER::new();
    $sock->print("?WATCH={\"enable\":true};\n");
    while(<$sock>)
    {
# Empty buffer
    }
    return $this;
}

sub Notify
{
    my( $this ) = shift;
    $sock->print("?POLL;\n");
    while(<$sock>)
    {
	my $data=json_to_perl $_;
	my $satarray=$data->{"sky"}[0]->{"satellites"};
	$frame->SetLat($data->{"tpv"}[0]->{"lat"});
	$frame->SetLong($data->{"tpv"}[0]->{"lon"});
	$frame->SetAlt($data->{"tpv"}[0]->{"alt"});
	$frame->SetTime($data->{"tpv"}[0]->{"time"});
	if (defined $satarray)
	{
	    my $satcount=scalar @$satarray;
#	    $frame->SetSatCount($satcount);
#	    print Dumper(scalar @$satarray) 
	    my $satlist=[];
	    for (my $i=0; $i<$satcount; $i++)
	    {
		push $satlist, {
		    "az" => $$satarray[$i]->{"az"}, 
		    "el" => $$satarray[$i]->{"el"}, 
		    "ss" => $$satarray[$i]->{"ss"}, 
		    "used" => $$satarray[$i]->{"used"}
		};

	    }
	    $frame->SetSats($satlist);
	}
    }
    $frame->Refresh();
}

sub SetFrame
{
    my $this=shift;
    $frame=shift;
}

sub Exit
{
    close($sock);
}

}
# every program must have a Wx::App-derive class
package MyApp;
{
use vars qw(@ISA);

@ISA = qw(Wx::App);

# this is called automatically on object creation
my $frame;
sub OnInit {
    my( $this ) = shift;
    
    # create a new frame
    ( $frame ) = MyFrame->new();
    # set as top frame
    $this->SetTopWindow( $frame );
    # show it
    $frame->Show( 1 );
}

sub Frame
{
    return $frame;
}

}

package MyFrame;
{
use vars qw(@ISA);

@ISA = qw(Wx::Frame);

use Wx::Event qw(EVT_PAINT);
# this imports some constants
use Wx qw(wxDECORATIVE wxNORMAL wxBOLD wxMODERN wxFONTENCODING_SYSTEM wxSOLID);
use Wx qw(wxDefaultPosition);
use Wx qw(wxWHITE);
use Date::Parse;
use Date::Format;
use Data::Dumper;
use Math::Trig;

my $long;
my $lat;
#my $sats;
my $gps;
my $alt;
my $time;
my $satlist=[];
my $oldlat=0;
my $oldlong=0;
my $longpos=0;
my $latpos=0;

sub SetLong
{
    my $this=shift;
    my $val=shift;
    $oldlong=$longpos;
    $longpos=$val;
    $long->SetLabel($val."° E") if defined $val;
}

sub SetLat
{
    my $this=shift;
    my $val=shift;
    $oldlat=$latpos;
    $latpos=$val;
    $lat->SetLabel($val."° N") if defined $val;
}

#sub SetSatCount
#{
#    my $this=shift;
#    my $val=shift;
#    $sats->SetLabel($val) if defined $val;
#}

sub SetTime
{
    my $this=shift;
    my $val=shift;
    if (defined $val)
    {
	my $datetime = str2time($val);
	$time->SetLabel(time2str("%H:%M:%S %d.%m.%Y",$datetime));
    }
}

sub SetAlt
{
    my $this=shift;
    my $val=shift;
    $alt->SetLabel($val."m") if defined $val;
}

sub SetSats
{
    my $this=shift;
    $satlist=shift;
}

sub new {
    # new frame with no parent, id -1
    my $font = Wx::Font->new(7,                 # font size
			      wxMODERN,       # font family
			      wxNORMAL,           # style
			      wxNORMAL,           # weight
			      0,                  
			      'Verdana',    # face name
			      wxFONTENCODING_SYSTEM);
    my( $this ) = shift->SUPER::new( undef, -1, 'PerlGPS', [-1, -1], [620, 590] );
    my $llong = Wx::StaticText->new($this, -1, "Longitude", [10,560]);
    my $llat = Wx::StaticText->new($this, -1, "Latitude", [165,560]);
    my $lalt = Wx::StaticText->new($this, -1, "Altitude", [330,560]);
    my $ltime = Wx::StaticText->new($this, -1, "Time", [440,560]);
#    my $lsats = Wx::StaticText->new($this, -1, "Satelites", [10,620]);
    $long = Wx::StaticText->new($this, -1, "0", [60,560]);
    $lat = Wx::StaticText->new($this, -1, "0", [210,560]);
#    $sats = Wx::StaticText->new($this, -1, "0", [60,620]);
    $alt=Wx::StaticText->new($this, -1, "0", [380,560]);
    $time=Wx::StaticText->new($this, -1, "0", [480,560]);
    $llong->SetFont($font);
    $llat->SetFont($font);
    $lalt->SetFont($font);
    $ltime->SetFont($font);
    $long->SetFont($font);
    $lat->SetFont($font);
    $alt->SetFont($font);
    $time->SetFont($font);
    # declare that all paint events will be handled with the OnPaint method
    EVT_PAINT( $this, \&OnPaint );
    # Test data
#    push $satlist, {"el" => 90, "az" => 235, "used" => 1};
    return $this;
}

sub OnPaint {
#    print "Draw".scalar @$satlist."\n";
    my( $this, $event ) = @_;
    # create a device context (DC) used for drawing
    my( $dc ) = Wx::PaintDC->new( $this );
    $dc->SetBrush(Wx::wxWHITE_BRUSH);
    $dc->SetPen(Wx::wxBLACK_PEN);
    $dc->DrawRectangle(40,10,540,540);
    $dc->DrawCircle(310,280,250);
    $dc->DrawLine(310,10,310,550);
    $dc->DrawLine(40,280,580,280);
    $dc->DrawText("N",320,15);
    my $satcount=scalar @$satlist;
    my $curcount=0;
    for (my $i=0; $i<$satcount; $i++)
    {
	# C++-Code from plasma-gps
	#int x = (sin(m_satAzim[i] * M_PI / 180) * (90 - m_satElev[i]));
	#int y = - (cos(m_satAzim[i] * M_PI / 180) * (90 - m_satElev[i]));
	my $y=280+-250*sin($$satlist[$i]->{"el"}*pi/180)*cos($$satlist[$i]->{"az"}*pi/180);
	my $x=310+250*sin($$satlist[$i]->{"el"}*pi/180)*sin($$satlist[$i]->{"az"}*pi/180);
#	print "X $x Y $y Used ".$$satlist[$i]->{"used"}."\n";
	if (defined $$satlist[$i]->{"used"})
	{
	    $curcount++;
	    $dc->SetPen(Wx::wxGREEN_PEN);
 	    $dc->SetBrush(Wx::wxGREEN_BRUSH);
	}
	else
	{
	    $dc->SetPen(Wx::wxRED_PEN);
 	    $dc->SetBrush(Wx::wxRED_BRUSH);
	}
	$dc->DrawCircle($x,$y,$$satlist[$i]->{"ss"}/10*5);
    }
    $dc->DrawText("$curcount of $satcount satellites used",45,15);
    my $dy = $latpos - $oldlat;
    my $dx = cos(pi/180*$oldlat)*($longpos - $oldlong);
    my $angle = atan2($dy, $dx);
    pritn $angle;
    $dc->DrawText("Current heading $angle°",350,15);
}

}
package main;

# create an instance of the Wx::App-derived class
my( $app ) = MyApp->new();

my ( $t ) = MyTimer->new();
$t->SetFrame($app->Frame());
$t->Start(100);

# start processing events
$app->MainLoop();
$t->Exit();
