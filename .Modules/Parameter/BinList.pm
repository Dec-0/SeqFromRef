# Package Name
package Parameter::BinList;

# Exported name
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(BinListGet BinSearch DayStamp TimeStamp DayTimeStamp ScriptBegin TimeString IfFileExist Chr2Num Num2Chr);

use FindBin qw($Bin);
use File::Basename;

sub BinListGet
{
	my $BinList = $Bin . "/.BinList.xls";
	return $BinList if(-s $BinList);
	
	$BinList = "/biobiggen/data/headQuarter/user/xiezhangdong/Scripts/.BinList.xls";
	die "[ Error ] File not exist ($BinList).\n" unless(-s $BinList);
	
	return $BinList;
}

sub BinSearch
{
	my ($BinName,$BinList,$JumpConfirmFlag) = @_;
	
	die "[ Error ] File not exist ($BinList).\n" unless(-s $BinList);
	my $Return = `grep '^$BinName'\$'\\t' $BinList`;
	chomp $Return;
	
	die "Name ($BinName) not unique.\n($Return)\n" if($Return =~ /\n/);
	#print "[ Info ] $Return\n";
	my @Cols = split /\t/, $Return;
	# 替换成Bin目录
	if($Cols[1] =~ s/^BINDIR//)
	{
		$Cols[1] = $Bin . $Cols[1];
	}
	# 替换成Scripts目录
	elsif($Cols[1] =~ s/^DEFAULTDIR//)
	{
		my @Items = split /\//, $Bin;
		my $LastId = -1;
		for($i = $#Items;$i >= 0;$i --)
		{
			if($Items[$i] eq "Scripts")
			{
				$LastId = $i - 1;
				last;
			}
			elsif($Items[$i] eq "xiezhangdong")
			{
				$LastId = $i;
				last;
			}
		}
		
		if($LastId >= 0)
		{
			my $RDir = join("/",@Items[0 .. $LastId]);
			$Cols[1] = $RDir . $Cols[1];
		}
	}
	die "[ Error ] $Cols[1] for $BinName not exist!\n" unless($Cols[1] && (-e $Cols[1] || $JumpConfirmFlag ));
	
	return $Cols[1];
}

sub DayStamp
{
	my @temp_time = localtime();
	my $localtime_year = $temp_time[5] + 1900;
	my $localtime_month = $temp_time[4] + 1;
	my $DayStamp = $localtime_year . "/" . $localtime_month . "/" . $temp_time[3];
	
	return $DayStamp;
}

sub TimeStamp
{
	my @temp_time = localtime();
	my $TimeStamp = $temp_time[2] . ":" . $temp_time[1] . ":" . $temp_time[0];
	
	return $TimeStamp;
}

sub DayTimeStamp
{
	my $DayStamp = &DayStamp();
	my $TimeStamp = &TimeStamp();
	my $Stamp = $DayStamp . " " . $TimeStamp;
	
	return $Stamp;
}

sub ScriptBegin
{
	my ($MuteFlag,$Name) = @_;
	
	$BeginTime = time;
	if($BeginTime && !$MuteFlag)
	{
		my $Stamp = &DayTimeStamp();
		print "[ $Stamp ] This script begins.\n" unless($Name);
		print "[ $Stamp ] This script ($Name) begins.\n" if($Name);
	}
	elsif(!$BeginTime)
	{
		die "[ Error ] Fail to get system time with 'time'.\n";
	}
	
	return $BeginTime;
}

sub TimeString
{
	my ($TimeCurrent,$TimeBegin) = @_;
	my $TimeString = "";
	
	my $Sec = $TimeCurrent - $TimeBegin;
	
	my $Day = int($Sec / 86400);
	$TimeString .= $Day . "d" if($Day);
	
	my $Tail = $Sec % 86400;
	my $Hour = int($Tail / 3600);
	$TimeString .= $Hour . "h" if($Hour);
	
	$Tail = $Tail % 3600;
	my $Min = int($Tail / 60);
	$TimeString .= $Min . "min" if($Min);
	
	$Sec = $Tail % 60;
	$TimeString .= $Sec . "s" if($Sec);
	
	$TimeString = "0s" unless($TimeString);
	
	return $TimeString;
}

sub IfFileExist
{
	my @File = @_;
	
	for my $i (0 .. $#File)
	{
		die "[ Error ] File ($File[$i]) not exist.\n" unless($File[$i] && -e $File[$i]);
	}
	
	return 1;
}

sub Chr2Num
{
	my $Chr = $_[0];
	my $Num;
	
	if($Chr =~ /X/i)
	{
		$Num = 23;
	}
	elsif($Chr =~ /Y/i)
	{
		$Num = 24;
	}
	elsif($Chr =~ /M/i)
	{
		$Num = 25;
	}
	else
	{
		$Chr =~ s/chr//i;
		$Num = $Chr;
	}
	
	return $Num;
}

sub Num2Chr
{
	my $Num = $_[0];
	my $Chr = "chr";
	
	if($Num <= 22)
	{
		$Chr .= $Num;
	}
	elsif($Num == 23)
	{
		$Chr .= "X";
	}
	elsif($Num == 24)
	{
		$Chr .= "Y";
	}
	elsif($Num == 25)
	{
		$Chr .= "M";
	}
	
	return $Chr;
}

1;