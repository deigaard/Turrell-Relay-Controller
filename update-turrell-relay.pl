#!/usr/bin/perl -w
# use strict;
use POSIX qw(tzset);
use XML::Simple;
use Data::Dumper;
use Date::Parse;
#use diagnostics;
#by Devan Goldstein, total amateur

# read multiple calendars by putting URLs in an array which gets iterated over in the main foreach loop. for more URL options: http://code.google.com/apis/calendar/reference.html#Parameters

my @calurls = ("http://www.google.com/calendar/feeds/turrell.skyspace%40gmail.com/private-<GOOGLECALENDARKEY>/full?futureevents=true&singleevents=true&max-results=1&orderby=starttime&sortorder=a");

my $enable = ("http://turrell-relay.skyspace.rice.edu/cgi-bin/runcommand.sh?rndvar:cmd=254,0,1r1t300");
	my @curlenable = ("/usr/bin/curl", "-f", $enable);
	print @curlenable;

my $disable = ("http://turrell-relay.skyspace.rice.edu/cgi-bin/runcommand.sh?rndvar:cmd=254,8,1r1t300");
	my @curldisable = ("/usr/bin/curl", "-f", $disable);
	print @curldisable;


#UTC−06:00
#America/Chicago

$ENV{TZ} = 'America/Chicago';

my $was = localtime;
print "It is still $was\n";

tzset;

my $now = localtime;
print "It is now   $now\n";


#create variables for current date to check against
my ($tmm, $thh, $tday,$tmonth,$tyear) = (localtime)[1,2,3,4,5];
$tmonth += 1;
$tyear += 1900;
if ($tmonth < 10) { $tmonth = '0' . $tmonth; }

# for debugging
print "Day/Month/Year: ", $tday,", ",$tmonth,", ",$tyear, "\n";

# create our agenda strings, one for normal and one for allday events
my $agenda;
# my $adagenda;

my @data;

my $i = 1;

my $xml = new XML::Simple(forceArray => ["entry","gd:who","id"]);

foreach my $url (@calurls)
{
	my @curlargs = ("/usr/bin/curl", "-f", $url, "-o", "/home/turrell/.gcalfeed_".$i.".xml");
	system(@curlargs);

	# print ("/usr/bin/curl ", "-f ", $url, " -o ", "/home/turrell/.gcalfeed_".$i.".xml");
	# print @curlargs;

my $now = localtime;
print "It is now   $now\n";


	# system(./getcalendar);

	$data[$i] = $xml->XMLin("/home/turrell/.gcalfeed_".$i.".xml");

	# for debugging
	# print Dumper(@data);

	# access <entry> array
	foreach my $e (@{$data[$i]->{'entry'}})
	{
		# setup start and end times
		my $begin = $e->{'gd:when'}->{'startTime'};
		my $end = $e->{'gd:when'}->{'endTime'};
		my ($bss,$bmm,$bhh,$bday,$bmonth,$byear,$bzone) = strptime($begin);
		my ($ess,$emm,$ehh,$eday,$emonth,$eyear,$ezone) = strptime($end);
		$eday -=1;
		$emonth +=1;
		$bmonth +=1;
		$byear +=1900;
		$eyear +=1900;
		if ($bmonth < 10) { $bmonth = '0' . $bmonth; }
	#	$bday doesn't seem to need adjusting...
	#	if ($bday < 10) { $bday = '0' . $bday; }
		if ($emonth < 10) { $emonth = '0' . $emonth; }
		if ($eday < 10) { $eday = '0' . $eday; }
	
		my $where = $e->{'gd:where'}->{valueString};

		my $whocount = 0;
		my @names;
		
		foreach my $who (@{$e->{'gd:who'}})
		{
			my @who = $e->{'gd:who'}->[$whocount]->{valueString};
		
			foreach my $name (@who)
			{
				push (@names,$name);
			}
			
			$whocount++;
		}
		print("PRE-LIGHTS (min): THH $thh, BHH $bhh, EHH $ehh, TMM $tmm, BMM $bmm, EHH $ehh\n");

		# use only non-allday events from this year
		if (($bmm) && ($byear == $tyear)) {
	
			# get upcoming events; add * to today's
			if ($bmonth <= $tmonth+1)
			{
					# add to the agenda string
					if (($bday == $tday) && ($bmonth == $tmonth) && ($byear == $tyear))
					{
						if ($thh == $bhh)
						{
							#if (($tmm >= $bmm) && ($tmm <= $emm))
							if ($tmm >= $bmm)
							{
								# current time is within this hour and start/end times
								print("1 - LIGHTS-ON (hr): THH $thh, BHH $bhh, EHH $ehh\n");
								system(@curlenable);
							}
						}
						# is the current time within the event begin and end?
						elsif (($thh >= $bhh) && ($thh <= $ehh))
						{
							# current time is within event hours
							print("2 - LIGHTS-ON (min): THH $thh, BHH $bhh, EHH $ehh, TMM $tmm, BMM $bmm, EHH $ehh\n");
							system(@curlenable);
						} else
						{
							print "3 - LIGHTS-OFF: THH $thh, BHH $bhh, EHH $ehh, TMM $tmm, BMM $bmm, EHH $ehh\n";
							system(@curldisable);

						}
						$agenda .= "*";
					
					}
					else
					{
						print "4 - LIGHTS-OFF: THH $thh, BHH $bhh, EHH $ehh, TMM $tmm, BMM $bmm, EHH $ehh\n";
						system(@curldisable);
					}
					$agenda .= $bmonth;
					$agenda .= "/$bday, $bhh:$bmm-$ehh:$emm: ";
					$agenda .= $e->{'title'}->{'content'};
					if ($where) {
						$agenda .= " (at $where)";
					}
					# here I strip off my name when it's associated with a calendar event; you should replace mine with yours.
					foreach my $name (@names)
					{
						if (($name !~ m/Devan/) && ($name !~ m/devan/) && ($name !~ m/^Weekly Schedule$/) && (($e->{'title'}->{'content'}) !~ m/^Weekly Status$/))
						{
							$agenda .= "\n   $name";
						}
					}
					$agenda .= "\n";
					$agenda .= "#####";
			}
	
		} 
	
		# use only all-day events from this year
		if ((!($bmm)) && ($byear == $tyear)) {
			# get only this and next month's events; strip out this month's concluded events
			if (($bmonth >= $tmonth) && ($bmonth <= $tmonth+1))
			{				
				# add to the agenda string
				if (($bday <= $tday) && ($tday <= $eday) && ($bmonth == $tmonth))
				{
					$agenda .= "*";
				}
				$agenda .= "$bmonth/$bday-$emonth/$eday: ";
				$agenda .= $e->{'title'}->{'content'};
				if ($where) {
					$agenda .= " (at $where)";
				}
				$agenda .= "\n";
				$agenda .= "#####";
			}
		}
	}

	$i++;

}


# create sorted lists from the agenda strings and print
my @agenda_sorted = sort(split(/#####/,$agenda));
print @agenda_sorted;
# print "\n";
# my @adagenda_sorted = sort(split(/#####/,$adagenda));
# print @adagenda_sorted;
