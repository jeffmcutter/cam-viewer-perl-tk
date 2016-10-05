#!/opt/local/bin/perl5.16

use strict;
use Tk;
use Tk::JPEG;
use Tk::Widget;
use File::Basename;
use File::Copy;
#use Win32;
use Time::HiRes;
use Getopt::Std;

my @files;
my $drive = "/Volumes/My HD";
my $camdir = "$drive/Cameras";
my $archivedir = "$drive/Cameras.Archive";
my $savedir = "$drive/saved_images";
my $backupdir = "/Volumes/Other HD/saved_images";
my @servers;
# Automatically collect the list of cameras.
foreach my $file (glob "\"$camdir\"/*") {
	chomp $file;
	if ( -d $file ) {
		push (@servers, File::Basename::basename($file));
	}
}
# Force a particular order instead.
@servers = qw(Camera1 Camera2 Camera3);

my %args;
my $big_groups;
getopts('b', \%args);
if ( $args{h} ) {
	$big_groups = 0;
} else {
	$big_groups = 1;
}

my $main;
my $view;
my $pause;
my $forward;
my $started;
my $count = 0;
my $total;
my $step = 0;
my $jump = 0;
my $jump_scale;
my $jump_count = 10;
my $server_choice;
my $prefix_choice;
my $hour_choice;
my $current_file;
my $botframe;
my $prefixframe;
my $hourframe;

if ( $ARGV[0] ) {
	my $glob = $ARGV[0];
	$glob =~ s/\\/\\\\/g;
	@files = glob $glob;
	view(@files);
} else {
	create_ui();
}

MainLoop();

sub create_ui {
	$main = MainWindow->new();
	$main->title("Image Selector");
	$main->protocol('WM_DELETE_WINDOW' => sub{\&exit(0)});
	my $topframe = $main->Frame(#-label => "Label Here",
				    -borderwidth => 2);
       	$topframe->pack(-side => "top", -fill => "both");#, -expand => "both");
	$topframe->Button(-text => "View Files", -command => sub{@files = &getfiles($server_choice, $prefix_choice, $hour_choice); \&view(@files)})->pack(-side => "left");
	$topframe->Button(-text => "Archive Files", -command => sub{@files = &getfiles($server_choice, $prefix_choice, $hour_choice); \&archive(@files)})->pack(-side => "left");
	$topframe->Button(-text => "View All Files", -command => sub{@files = &getfiles($server_choice, $prefix_choice, ""); \&view(@files)})->pack(-side => "left");
	$topframe->Button(-text => "Archive All Files", -command => sub{@files = &getfiles($server_choice, $prefix_choice, ""); \&archive(@files)})->pack(-side => "left");
	$topframe->Button(-text => "Quit", -command => sub{\&exit(0)})->pack(-side => "left");
	my $topframe2 = $main->Frame(-borderwidth =>2);
       	$topframe2->pack(-side => "top", -fill => "both");#, -expand => "both");
	foreach my $server (@servers) {
		$topframe2->Radiobutton(-text => $server,
				       -variable => \$server_choice,
				       -value => $server,
				       -indicatoron => 0,
				       -command => sub{\&chooseprefix()},
				       )->pack(-side => "left", -fill => "both");
	}

}

sub view {
	my @files = @_;
	my $total = scalar @files;
	$started = 0;
	$view = MainWindow->new();
	$view->title("Image Viewer");
	my $menu_bar = $view->Frame()->pack(-side => "top", -fill => "both");
	$menu_bar->Button(-text => "Start", -command => sub{$pause = 0; $forward = 1; $step = 0; $count = 1; unless ( $started ) { $started = 1 ; $count = 1 ; \&display()}})->pack(-side => "left");
	$menu_bar->Radiobutton(-text => "Play", -variable => \$pause, -value => 0, -indicatoron => 0, -command => sub{unless ( $started ) { $started = 1; \&display()}})->pack(-side => "left", -fill => "both");
	$menu_bar->Radiobutton(-text => "Pause", -variable => \$pause, -value => 1, -indicatoron => 0)->pack(-side => "left", -fill => "both");
	$menu_bar->Radiobutton(-text => "Forward", -variable => \$forward, -value => 1, -indicatoron => 0)->pack(-side => "left", -fill => "both");
	$menu_bar->Radiobutton(-text => "Reverse", -variable => \$forward, -value => 0, -indicatoron => 0)->pack(-side => "left", -fill => "both");
	$menu_bar->Button(-text => "Step Forward", -command => sub{$step = 1; $forward = 1, $pause = 0})->pack(-side => "left");
	$menu_bar->Button(-text => "Step Backward", -command => sub{$step = 1; $forward = 0, $pause = 0})->pack(-side => "left");
	$menu_bar->Button(-text => "Jump Forward", -command => sub{$count+=$jump_count; $jump = 1;})->pack(-side => "left");
	$menu_bar->Button(-text => "Jump Backward", -command => sub{$count-=$jump_count; $jump = 1;})->pack(-side => "left");
	$menu_bar->Button(-text => "Save", -command => sub{\&save_image($current_file)})->pack(-side => "left");
	$menu_bar->Button(-text => "Close", -command => [destroy => $view])->pack(-side => "left");
	my $speedscale_frame = $view->Frame()->pack(-side => "top", -fill => "both");
	my $speedscale = $speedscale_frame->Scale(-orient => "horizontal", -from => -20, -to => 20, -variable => \$jump_scale, -length => 240);
	$speedscale->pack(-side => "left", -expand => "yes");
	my $position_label_frame = $view->Frame()->pack(-side => "top", -fill => "both");
	my $position_label_left = $position_label_frame->Label(-text => "  1")->pack(-side => "left", -fill => "both");
	my $position_label_right = $position_label_frame->Label(-text => "$total   ")->pack(-side => "right", -fill => "both");
	my $position_frame = $view->Frame()->pack(-side => "top", -fill => "both");
	my $position = $position_frame->Scale(-orient => "horizontal", -from => 1, -to => $total, -variable => \$count, -length => 640);
	$position->pack(-side => "left", -expand => "yes");
}

sub display {
	$total = scalar @files;
	while (1) {
		my $image_area = $view;
		$current_file = $files[$count - 1];
		my $image = $image_area->Photo(-format => "jpeg", -file => $current_file);
		my $show = $view->Label(-image => $image);
		$show->pack;#(-side => "top");
		$show->update;
		if ( $forward == 0 && $count <= 1 ) {
			$pause = 1;
		}
		if ( $forward == 1 && $count >= $total ) {
			$pause = 1;
		}
		if ( $step ) {
			$step = 0;
			$pause = 1;
		}
		PAUSE: while ( $pause ) {
			#Win32::Sleep(250);
			Time::HiRes::sleep(0.250);
			$show->update;
			if ( $jump ) {
				$jump = 0;
				last PAUSE;
			}
		}
		$show->destroy;
		undef $show;
		if ( $forward ) {
			if ( $jump_scale == 0 || $jump_scale == 1 ) {
				$count++;
			} elsif ( $jump_scale >= 2 ) {
				$count+=$jump_scale;
			} elsif ( $jump_scale <= -1 ) {
				$count++;
				my $delay = -$jump_scale;
				$delay = $delay * 50;
				#Win32::Sleep($delay);
				Time::HiRes::sleep($delay / 1000);
			}
		} else {
			if ( $jump_scale == 0 || $jump_scale == 1 ) {
				$count--;
			} elsif ( $jump_scale >= 2 ) {
				$count-=$jump_scale;
			} elsif ( $jump_scale <= -1 ) {
				$count--;
				my $delay = -$jump_scale;
				$delay = $delay * 25;
				#Win32::Sleep($delay);
				Time::HiRes::sleep($delay / 1000);
			}
		}
	}
}

sub archive {
	my @files = @_;
	return unless (@files);
	my $year;
	my $month;
	my $day;
	if ( $hour_choice =~ /-/ ) {
		my @date = split (/-/, $hour_choice);
		$year = $date[0];
		$month = $date[1];
		$day = substr ($date[2], 0, 2);
	} else {
		$year = substr ($hour_choice, 0, 4);
		$month = substr ($hour_choice, 4, 2);
		$day = substr ($hour_choice, 6, 2);
	}
	my $dir = File::Basename::dirname($files[0]);
	my $filename = File::Basename::basename($files[0]);
	my @filename = split (/-/, $filename);
	my $camera = $filename[0];
	my $camarchivedir = "$archivedir/$camera";
	if ( ! -d $camarchivedir ) {
		print "Making $camarchivedir...";
		mkdir $camarchivedir;
	}
	my $datedir = "$camarchivedir/$year-$month-$day";
	if ( ! -d $datedir ) {
		print "Making $datedir...\n";
		mkdir $datedir;
	}
	print "Moving files to $datedir...";
	foreach my $file (@files) {
		my $basename = File::Basename::basename($file);
		rename $file, "$datedir/$basename";
	}
	print "  Done!\n";
}

sub save_image {
	my $pic = $_[0];
	print "Copying $pic to $savedir...\n";
	copy($pic, $savedir) || warn "Copy of $pic to $savedir failed: $!";
	print "Copying $pic to $backupdir...\n";
	copy($pic, $backupdir) || warn "Copy $pic to $backupdir failed: $!";
}

sub chooseprefix {
	my @prefixes = getprefixes($server_choice);

	if ( $hourframe ) {
		$hourframe->destroy;
		undef $hourframe;
	}
	if ( $prefixframe ) {
		$prefixframe->destroy;
		undef $prefixframe;
	}


	$prefixframe = $main->Frame();
	$prefixframe->pack(-side => "top", -fill => "both");
	foreach my $prefix (@prefixes) {
		$prefixframe->Radiobutton(-text => $prefix,
					  -variable => \$prefix_choice,
					  -value => $prefix,
					  -indicatoron => 0,
					  -command => sub{\&choosehour()},
				)->pack(-side => "left", -fill => "both");
	}
}

sub choosehour {
	my @hours = gethours($server_choice, $prefix_choice);
	if ( $hourframe ) {
		$hourframe->destroy;
	}
	$hourframe = $main->Frame();
	$hourframe->pack(-side => "bottom", -fill => "both");
	foreach my $hour (@hours) {
		$hourframe->Radiobutton(-text => $hour,
				       -variable => \$hour_choice,
				       -value => $hour,
				       -indicatoron => 0,
			       )->pack(-side => "left", -fill => "both");

	}
}

sub getprefixes {
	my $server = $_[0];
	my @prefixes;
	foreach my $match (glob "\"$camdir\"/$server/$server*.jpg") {
		chomp $match;
		my $file = File::Basename::basename($match);
		next if ( $file eq "$server-motion.jpg" );
		my @file = split (/_/, $file);
		push (@prefixes, $file[0]);
	}
	my @prefixes = sortuniq(@prefixes);
	return @prefixes;
}

sub gethours {
	my $server = $_[0];
	my $prefix = $_[1];
	my @hours;
	foreach my $match (glob "\"$camdir\"/$server/$prefix*.jpg") {
		chomp $match;
		my @match = split (/\//, $match);
		my $file = File::Basename::basename($match);
		my @file = split (/_/, $file);
		if ( $file =~ /Panasonic/ ) {
			my $hour;
			if ( $file =~ /Timelapse/ || $big_groups ) {
				$hour = substr ($file[1], 0, 8);
			} else {
				$hour = substr ($file[1], 0, 11);
			}
			push (@hours, $hour);
		} else {
			if ( $file =~ /Timelapse/ || $big_groups ) {
				my $date = $file[1];
				push (@hours, $date);
			} else {
				my $date = $file[1];
				my $time = $file[2];
				my @time = split (/-/, $time);
				push (@hours, "${date}_$time[0]");
			}
		}
	}
	my @hours = sortuniq(@hours);
	return @hours;
}

sub getfiles {
	my $server = $_[0];
	my $prefix = $_[1];
	my $hour = $_[2];
	my @files;
	foreach my $match (glob "\"$camdir\"/$server/${prefix}_$hour*.jpg") {
		chomp $match;
		push (@files, $match);
	}
	@files = sortuniq(@files);
	return @files;
}

sub sortuniq {
   my @var = @_;
   my %seen = ();
   @var = grep { ! $seen{$_} ++ } @var;
   @var = sort @var;
}
