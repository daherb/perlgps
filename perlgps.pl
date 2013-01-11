#!/usr/bin/env perl
# Simple GPS-Info and Skyview written in Perl by Herbert Lange
# Based on Hello wxPerl sample by Mattia Barbon; licensed as Perl itself
# With parts from plasma-gps
use strict;
use warnings;
use Wx;
use IO::Socket;
use utf8;

package MyPosDialog;
{
use vars qw(@ISA);
@ISA=qw(Wx::Dialog);

use Data::Dumper;
use Wx qw(wxDECORATIVE wxNORMAL wxBOLD wxMODERN wxFONTENCODING_SYSTEM wxSOLID wxOK);
use Wx qw(wxDefaultPosition);
use Wx::Event qw(EVT_CHAR EVT_BUTTON);
my $dialog;
my $long=0;
my $lat=0;
my $tlong;
my $tlat;

sub GetLong
{
    return $long;
}

sub GetLat
{
    return $lat;
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
    my( $this ) = shift->SUPER::new( undef, -1, 'New Position', [-1, -1], [160, 100] );
    $dialog=$this;
    my $panel = Wx::Panel->new($this, -1,[0,0],[1,1]);
    my $llong = Wx::StaticText->new($this, -1, "Longitude", [5,10]);
    $tlong = Wx::TextCtrl->new($this, -1, "0°0'0\" E", [5,20],[80,20]);
    my $llat = Wx::StaticText->new($this, -1, "Latitude", [5,50]);
    $tlat = Wx::TextCtrl->new($this, -1, "0°0'0\" N", [5,60]);
    my $bsave = Wx::Button->new($this, -1, "Save", [95,20],[60,20]);
    my $bcancel = Wx::Button->new($this, -1, "Cancel", [95,50],[60,20]);
    $panel->SetFocus();
    EVT_CHAR( $panel, \&OnKeyPress);
    EVT_BUTTON( $bsave, -1, \&ParseCoordinates);
    EVT_BUTTON( $bcancel, -1, sub { $dialog->EndModal(-1); });
    return $this;
}

sub OnKeyPress
{
    my( $this, $event ) = @_;
    my $code=$event->GetKeyCode();
    if ($code==ord('q') || $code == ord('c')) # q or c -> Quit
    {
	$dialog->EndModal(-1);
    }
    elsif ($code == ord('s'))
    {
	ParseCoordinates($this,-1);
    }
}

sub ParseCoordinates
{
    my( $this, $event ) = @_;
    my $slong=$tlong->GetLineText(0);
    my $slat=$tlat->GetLineText(0);
    my $longsgn=1;
    my $latsgn=1;
    if ($slong =~ /W\s*$/)
    {
	$longsgn=-1;
    }
    if ($slat =~ /S\s*$/)
    {
	$latsgn=-1;
    }
    if ($slong =~ /^\s*(?<sign>[-+])?
                    \s*(?<deg>\d{1,3})
                       ([,\.](?<decimal>\d+)\s*)?
                    \s*[WEO]?\s*$
                  /x)
    {
	$long=$longsgn*$+{"deg"};
	$long.=".".$+{"decimal"} if (defined $+{"decimal"});
	$long*=-1 if (defined $+{"sign"} && $+{"sign"} eq "-");
    }
    elsif ($slong =~ /^\s*(?<sign>[-+])?
                    \s*(?<deg>\d{1,3})\s*°
                    \s*((?<min>\d{1,2})\s*')?
                    \s*((?<sec>\d+)\s*")?
                    \s*[WEO]?\s*$
                  /x)
    {
	$long=$longsgn;
	$long*=-1 if (defined $+{"sign"} && $+{"sign"} eq "-");
	$long*=$+{"deg"};
	$long+=($+{"min"}/60) if (defined $+{"min"});
	$long+=($+{"sec"}/3600) if (defined $+{"sec"});
    }
    else
    {
	my $error = Wx::MessageDialog->new($this,"Wrong coordinate format for longitude","Format error",wxOK);
	$error->ShowModal();
	$error->Destroy();
	$dialog->EndModal(-1);
    }
    if ($slat =~ /^\s*(?<sign>[-+])?
                    \s*(?<deg>\d{1,3})
                       ([,\.](?<decimal>\d+)\s*)?
                    \s*[NS]?\s*$
                  /x)
    {
	$lat=$latsgn*$+{"deg"};
	$lat.=".".$+{"decimal"} if (defined $+{"decimal"});
	$lat*=-1 if (defined $+{"sign"} && $+{"sign"} eq "-");
    }
    elsif ($slat =~ /^\s*(?<sign>[-+])?
                    \s*(?<deg>\d{1,3})\s*°
                    \s*((?<min>\d{1,2})\s*')?
                    \s*((?<sec>\d+)\s*")?
                    \s*[NS]?\s*$
                  /x)
    {
	$lat=$longsgn;
	$lat*=-1 if (defined $+{"sign"} && $+{"sign"} eq "-");
	$lat*=$+{"deg"};
	$lat+=($+{"min"}/60) if (defined $+{"min"});
	$lat+=($+{"sec"}/3600) if (defined $+{"sec"});
    }
    else
    {
	my $error = Wx::MessageDialog->new($this,"Wrong coordinate format for latitude","Format error",wxOK);
	$error->ShowModal();
	$error->Destroy();
	$dialog->EndModal(-1);
    }
    $dialog->EndModal(1);
}

}

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
	eval {
	    my $data=json_to_perl $_;
	    my $satarray=$data->{"sky"}[0]->{"satellites"};
	    $frame->SetLat($data->{"tpv"}[0]->{"lat"});
	    $frame->SetLong($data->{"tpv"}[0]->{"lon"});
	    $frame->SetAlt($data->{"tpv"}[0]->{"alt"});
	    $frame->SetTime($data->{"tpv"}[0]->{"time"});
	    $frame->SetSpeed($data->{"tpv"}[0]->{"speed"});
	    $frame->SetAngle($data->{"tpv"}[0]->{"track"});
	    if (defined $satarray)
	    {
		my $satcount=scalar @$satarray;
#	    $frame->SetSatCount($satcount);
#	    print Dumper(scalar @$satarray) 
		my $satlist=[];
		for (my $i=0; $i<$satcount; $i++)
		{
		    push @$satlist, {
			"az" => $$satarray[$i]->{"az"}, 
			"el" => $$satarray[$i]->{"el"}, 
			"ss" => $$satarray[$i]->{"ss"}, 
		    "used" => $$satarray[$i]->{"used"}
		    };
		    
		}
		$frame->SetSats($satlist);
	    }
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

use Wx::Event qw(EVT_PAINT EVT_KEY_DOWN EVT_CHAR);
# this imports some constants
use Wx qw(wxDECORATIVE wxNORMAL wxBOLD wxMODERN wxFONTENCODING_SYSTEM wxSOLID);
use Wx qw(wxDefaultPosition);
use Wx qw(wxWHITE);
use Date::Parse;
use Date::Format;
use Data::Dumper;
use Math::Trig;
use Math::Trig qw(great_circle_distance great_circle_direction);
use Math::Round qw/round/;

my $long;
my $lat;
#my $sats;
my $gps;
my $alt;
my $time;
my $angle=0;
my $speed;
my $satlist=[];
my $longpos=0;
my $latpos=0;
my $frame;
# To save a position
my $hasmem=0;
my $memlong=0;
my $memlat=0;

sub DegToRad
{
    my $rad = shift; 
    return $rad * pi / 180;
}

sub SetLong
{
    my $this=shift;
    my $val=shift;
    $longpos=$val;
    $long->SetLabel($val."° E") if defined $val;
}

sub SetLat
{
    my $this=shift;
    my $val=shift;
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


sub SetSpeed
{
    my $this=shift;
    my $val=shift;
    if (defined $val)
    {
	my $kmh=$val*3.6;
	$speed->SetLabel($val."m/s ".$kmh."km/h");
    }
}

sub SetSats
{
    my $this=shift;
    $satlist=shift;
}

sub SetAngle
{
    my $this=shift;
    my $val=shift;
    $angle=$val if defined $val;
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
    my $lspeed = Wx::StaticText->new($this, -1, "Speed", [10,575]);
#    my $lsats = Wx::StaticText->new($this, -1, "Satelites", [10,620]);
    $long = Wx::StaticText->new($this, -1, "0", [60,560]);
    $lat = Wx::StaticText->new($this, -1, "0", [210,560]);
#    $sats = Wx::StaticText->new($this, -1, "0", [60,620]);
    $alt=Wx::StaticText->new($this, -1, "0", [380,560]);
    $time=Wx::StaticText->new($this, -1, "0", [480,560]);
    $speed=Wx::StaticText->new($this, -1, "0", [60,575]);
    $llong->SetFont($font);
    $llat->SetFont($font);
    $lalt->SetFont($font);
    $ltime->SetFont($font);
    $lspeed->SetFont($font);
    $long->SetFont($font);
    $lat->SetFont($font);
    $alt->SetFont($font);
    $time->SetFont($font);
    $speed->SetFont($font);
    # declare that all paint events will be handled with the OnPaint method
    EVT_PAINT( $this, \&OnPaint );
    # declare event handler for key presses
    my $panel = Wx::Panel->new($this, -1);
    $panel->SetFocus();
    EVT_CHAR( $panel, \&OnKeyPress);
    # Test data
#    push $satlist, {"el" => 90, "az" => 235, "used" => 1};
    $frame = $this;
    return $this;
}

sub OnPaint {
#    print "Draw".scalar @$satlist."\n";
    my( $this, $event ) = @_;
    my $radius = 250; # The Radius of the Crosshair
    my $cx=310; # X of the Centre
    my $cy=280; # Y of the Centre
    # create a device context (DC) used for drawing
    my( $dc ) = Wx::PaintDC->new( $this );
    $dc->SetBrush(Wx::wxWHITE_BRUSH);
    $dc->SetPen(Wx::wxBLACK_PEN);
    # Draw the Crosshair
    $dc->DrawRectangle(40,10,540,540);
    $dc->DrawCircle($cx,$cy,$radius);
    $dc->DrawLine($cx,10,$cx,550);
    $dc->DrawLine(40,$cy,580,$cy);
    $dc->DrawText("N",320,15);
    # Draw Arrows
    my $scale=20; # Size of the Arrow
    my $in=5; # Shape of the End of Arrow
    # Compute Polygon for Heading Arrow
    my $heading = DegToRad($angle);
    my @points;
    # Top
    push @points, Wx::Point->new($cx+round(sin($heading)*($radius+10))+round(sin($heading)*$scale/2),$cy-round(cos($heading)*($radius+10))-round(cos($heading)*$scale/2));
    # Lower right
    push @points, Wx::Point->new($cx+round(sin($heading)*($radius+10))+round(sin($heading)*-$scale/2+cos($heading)*$scale/2),$cy-round(cos($heading)*($radius+10))-round(cos($heading)*-$scale/2+sin($heading)*-$scale/2));
    # Lower middle
    push @points, Wx::Point->new($cx+round(sin($heading)*($radius+10))+round(sin($heading)*(-$scale/2+$in)),$cy-round(cos($heading)*($radius+10))-round(cos($heading)*(-$scale/2+$in)));
    # Lower Left
    push @points, Wx::Point->new($cx+round(sin($heading)*($radius+10))+round(sin($heading)*-$scale/2+cos($heading)*-$scale/2),$cy-round(cos($heading)*($radius+10))-round(cos($heading)*-$scale/2+sin($heading)*$scale/2));
    #Top again
    push @points, Wx::Point->new($cx+round(sin($heading)*($radius+10))+round(sin($heading)*$scale/2),$cy-round(cos($heading)*($radius+10))-round(cos($heading)*$scale/2));
    # Compute Polygon for Direction Arrow (Only if $hasmem is true)
    if ($hasmem)
    {
	$scale=25;
	# Compute distance in meters
	sub NESW { DegToRad($_[0]), DegToRad(90 - $_[1]) }
	my @Pos = NESW($longpos, $latpos);
	my @Mem = NESW($memlong, $memlat);
	my $dist = great_circle_distance(@Pos, @Mem, 6378137); # About 9600 km.
	# Compute direction
	my $h2 = great_circle_direction(@Pos, @Mem);
	my @p2;
	# Top
	push @p2, Wx::Point->new($cx+round(sin($h2)*($radius+15))+round(sin($h2)*$scale/2),$cy-round(cos($h2)*($radius+15))-round(cos($h2)*$scale/2));
	# Lower right
	push @p2, Wx::Point->new($cx+round(sin($h2)*($radius+15))+round(sin($h2)*-$scale/2+cos($h2)*$scale/2),$cy-round(cos($h2)*($radius+10))-round(cos($h2)*-$scale/2+sin($h2)*-$scale/2));
	# Lower middle
	push @p2, Wx::Point->new($cx+round(sin($h2)*($radius+15))+round(sin($h2)*(-$scale/2+$in)),$cy-round(cos($h2)*($radius+15))-round(cos($h2)*(-$scale/2+$in)));
	# Lower left
	push @p2, Wx::Point->new($cx+round(sin($h2)*($radius+15))+round(sin($h2)*-$scale/2+cos($h2)*-$scale/2),$cy-round(cos($h2)*($radius+15))-round(cos($h2)*-$scale/2+sin($h2)*$scale/2));
	# Top again
	push @p2, Wx::Point->new($cx+round(sin($h2)*($radius+15))+round(sin($h2)*$scale/2),$cy-round(cos($h2)*($radius+15))-round(cos($h2)*$scale/2));
	$dc->DrawText("$dist m",$cx+round(sin($h2)*($radius+15))+round(sin($h2)*-$scale/2+cos($h2)*-$scale/2),$cy-round(cos($h2)*($radius+15))-round(cos($h2)*-$scale/2+sin($h2)*$scale/2));
	# Draw One or Both Arrows
	$dc->SetPen(Wx::wxCYAN_PEN);
	$dc->SetBrush(Wx::wxCYAN_BRUSH);
	$dc->DrawPolygon(\@p2,0,0);
    }
    $dc->SetPen(Wx::wxRED_PEN);
    $dc->SetBrush(Wx::wxRED_BRUSH);
    $dc->DrawPolygon(\@points,0,0);
    # Draw all the Sattelites
    my $satcount=scalar @$satlist;
    my $curcount=0;
    for (my $i=0; $i<$satcount; $i++)
    {
	# C++-Code from plasma-gps
	#int x = (sin(m_satAzim[i] * M_PI / 180) * (90 - m_satElev[i]));
	#int y = - (cos(m_satAzim[i] * M_PI / 180) * (90 - m_satElev[i]));
	my $y=round($cy+(-$radius)*sin($$satlist[$i]->{"el"}*pi/180)*cos($$satlist[$i]->{"az"}*pi/180));
	my $x=round($cx+$radius*sin($$satlist[$i]->{"el"}*pi/180)*sin($$satlist[$i]->{"az"}*pi/180));
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
	$dc->DrawCircle($x,$y,$$satlist[$i]->{"ss"}/10*5+1);
    }
    $dc->DrawText("$curcount of $satcount satellites used",45,15);
    $dc->DrawText("Current heading $angle°",350,15);
}

sub OnKeyPress
{
    my( $panel, $event ) = @_;
    my $code=$event->GetKeyCode();
#    print Dumper($code);
    if ($code==ord('q')) # q -> Quit
    {
	$frame->Destroy();
    }
    elsif($code == ord('m')) # m -> Memorize Position
    {
	$memlong=$longpos;
	$memlat=$latpos;
	$hasmem=1;
    }
    elsif($code == ord('c')) # c-> Clear Memory
    {
	$hasmem=0;
	$memlong=0;
	$memlat=0;
    }
    elsif($code == ord('g')) # g -> Ask for Place to go to
    {
	my ( $diag ) = MyPosDialog->new();
	if ($diag->ShowModal()==1)
	{
	    $memlong=$diag->GetLong;
	    $memlat=$diag->GetLat;
	    $hasmem=1;
	}
	$diag->Destroy();
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
$t->Exit();
