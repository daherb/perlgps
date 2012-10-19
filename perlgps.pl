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
	    $frame->SetSatCount($satcount);
#	    print Dumper(scalar @$satarray) 
	    my $satlist=[];
	    for (my $i=0; $i<$satcount; $i++)
	    {
		push $satlist, {
		    "az" => $$satarray[$i]->{"az"}, 
		    "el" => $$satarray[$i]->{"el"}, 
		    "used" => $$satarray[$i]->{"used"}
		};

	    }
	    $frame->SetSats($satlist);
	}
    }
}

sub SetFrame
{
    my $this=shift;
    $frame=shift;
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
use Wx qw(wxDECORATIVE wxNORMAL wxBOLD);
use Wx qw(wxDefaultPosition);
use Wx qw(wxWHITE);
use Date::Parse;
use Date::Format;
use Data::Dumper;
use Math::Trig;

my $long;
my $lat;
my $sats;
my $gps;
my $alt;
my $time;
my $satlist=[];

sub SetLong
{
    my $this=shift;
    my $val=shift;
    $long->SetLabel($val."° E") if defined $val;
}

sub SetLat
{
    my $this=shift;
    my $val=shift;
    $lat->SetLabel($val."° N") if defined $val;
}

sub SetSatCount
{
    my $this=shift;
    my $val=shift;
    $sats->SetLabel($val) if defined $val;
}

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
    my( $this ) = shift->SUPER::new( undef, -1, 'PerlGPS', [-1, -1], [300, 350] );
    my $llong = Wx::StaticText->new($this, -1, "Longitude", [10,280]);
    my $lalt = Wx::StaticText->new($this, -1, "Altitude", [10,300]);
    my $llat = Wx::StaticText->new($this, -1, "Latitude", [155,280]);
    my $ltime = Wx::StaticText->new($this, -1, "Time", [155,300]);
    my $lsats = Wx::StaticText->new($this, -1, "Satelites", [10,320]);
    $long = Wx::StaticText->new($this, -1, "0", [60,280]);
    $lat = Wx::StaticText->new($this, -1, "0", [205,280]);
    $sats = Wx::StaticText->new($this, -1, "0", [60,320]);
    $alt=Wx::StaticText->new($this, -1, "0", [60,300]);
    $time=Wx::StaticText->new($this, -1, "0", [190,300]);
    $this->SetIcon( Wx::GetWxPerlIcon() );
    # declare that all paint events will be handled with the OnPaint method
    EVT_PAINT( $this, \&OnPaint );
    
    return $this;
}

sub OnPaint {
#    print "Draw".scalar @$satlist."\n";
    my( $this, $event ) = @_;
    # create a device context (DC) used for drawing
    my( $dc ) = Wx::PaintDC->new( $this );
    $dc->SetBrush(Wx::wxWHITE_BRUSH);
    $dc->SetPen(Wx::wxBLACK_PEN);
    $dc->DrawRectangle(25,25,250,250);
    $dc->DrawCircle(150,150,110);
    $dc->DrawLine(150,25,150,275);
    $dc->DrawLine(25,150,275,150);
    for (my $i=0; $i<scalar @$satlist; $i++)
    {
	# C++-Code from plasma-gps
	#int x = (sin(m_satAzim[i] * M_PI / 180) * (90 - m_satElev[i]));
	#int y = - (cos(m_satAzim[i] * M_PI / 180) * (90 - m_satElev[i]));
	my $x=125+sin($$satlist[$i]->{"az"}*pi/180)*(90-$$satlist[$i]->{"el"});
	my $y=125-cos($$satlist[$i]->{"az"}*pi/180)*(90-$$satlist[$i]->{"el"});
#	print "X $x Y $y Used ".$$satlist[$i]->{"used"}."\n";
	if (defined $$satlist[$i]->{"used"})
	{
	    $dc->SetPen(Wx::wxGREEN_PEN);
	}
	else
	{
	    $dc->SetPen(Wx::wxRED_PEN);
	}
	$dc->DrawCircle($x,$y,3);
    }
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
 
