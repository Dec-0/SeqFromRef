#!/usr/bin/perl
use strict;
use Getopt::Long;
Getopt::Long::Configure qw(no_ignore_case);
use File::Basename;
use FindBin qw($Bin);
use lib "$Bin/.Modules";
use Parameter::BinList;

my ($HelpFlag,$BinList,$BeginTime);
my $ThisScriptName = basename $0;
my ($Bed,$Reference,$LogFile);
my $HelpInfo = <<USAGE;

 $ThisScriptName
 Contact: zhangdongxie\@foxmail.com

 This script is designed for capturing sequences from reference like hg38.fa.
 
 Corresponding patent: CN109949865B.
 
 -b      ( Required ) File in bed format which records the segments\' coordinate to be extracted;
                      Format like (chr\\t12345\\t23456\\n).The segments can be overlapped or one embeded in another.
 -o      ( Required ) File for result;
 
 -r      ( Optional ) Reference (default: hg38.fa);
 -bin    ( Optional ) List for searching of related bin or scripts; 
 -h      ( Optional ) Help infomation;

USAGE

GetOptions(
	'b=s' => \$Bed,
	'o=s' => \$LogFile,
	'r:s' => \$Reference,
	'bin:s' => \$BinList,
	'help|h!' => \$HelpFlag
) or die $HelpInfo;


if($HelpFlag || !$Bed || !$LogFile)
{
	die $HelpInfo;
}
else
{
	$BeginTime = ScriptBegin(0,$ThisScriptName);
	
	
	$BinList = BinListGet() if(!$BinList);
	$Reference = BinSearch("Reference",$BinList) unless($Reference);
	IfFileExist($Bed,$Reference);
}

if(1)
{
	# Coord Info;
	my (@Chr,@SeqStart,@SeqEnd);
	my (@ChrFlag,@ChrStartId,@ChrEndId);
	if($Bed)
	{
		my ($Id1,$Id2) = (0,1);
		my (@SChr,@SStart,@SEnd);
		my @Index;
		
		# read in bed info;
		open(BED,"< $Bed") or die $!;
		while(my $LineId = <BED>)
		{
			chomp $LineId;
			my @Cols = split /\t/, $LineId;
			
			push @SChr, Chr2Num($Cols[0]);
			push @SStart, $Cols[1];
			push @SEnd, $Cols[2];
		}
		close BED;
		printf "[ %s ] Reading of bed file (%s) finished.\n", TimeString(time,$BeginTime), $Bed;
		
		# bed sorting;
		for my $i (0 .. $#SChr)
		{
			$Index[$Id1][$i] = $i;
		}
		my $tmp = @SChr;
		my $To = $#SChr;
		my $MaxDulSpan = $tmp * 2;
		for(my $DulSpan = 2;$DulSpan < $MaxDulSpan;$DulSpan = $DulSpan * 2)
		{
			my $MinSpan = $DulSpan / 2;
			my $tmpId = 0;
			
			for(my $i = 0;$i <= $To;$i += $DulSpan)
			{
				my $LeftBegin = $i;
				my $RightBegin = $LeftBegin + $MinSpan;
				if($RightBegin <= $To)
				{
					my $LeftEnd = $RightBegin - 1;
					my $RightEnd = $LeftEnd + $MinSpan;
					if($RightEnd > $To)
					{
						$RightEnd = $To;
					}
					
					while($LeftBegin <= $LeftEnd || $RightBegin <= $RightEnd)
					{
						if($LeftBegin > $LeftEnd)
						{
							$Index[$Id2][$tmpId] = $Index[$Id1][$RightBegin];
							$RightBegin ++;
						}
						elsif($RightBegin > $RightEnd)
						{
							$Index[$Id2][$tmpId] = $Index[$Id1][$LeftBegin];
							$LeftBegin ++;
						}
						else
						{
							if($SChr[$Index[$Id1][$LeftBegin]] > $SChr[$Index[$Id1][$RightBegin]] || ($SChr[$Index[$Id1][$LeftBegin]] == $SChr[$Index[$Id1][$RightBegin]] && $SStart[$Index[$Id1][$LeftBegin]] > $SStart[$Index[$Id1][$RightBegin]]))
							{
								$Index[$Id2][$tmpId] = $Index[$Id1][$RightBegin];
								$RightBegin ++;
							}
							else
							{
								$Index[$Id2][$tmpId] = $Index[$Id1][$LeftBegin];
								$LeftBegin ++;
							}
						}
						$tmpId ++;
					}
				}
				else
				{
					for(my $j = $LeftBegin;$j <= $To;$j ++)
					{
						$Index[$Id2][$tmpId] = $Index[$Id1][$j];
						$tmpId ++;
					}
				}
			}
			$tmp = $Id2;
			$Id2 = $Id1;
			$Id1 = $tmp;
		}
		for my $i (0 .. $#SChr)
		{
			push @Chr, $SChr[$Index[$Id1][$i]];
			push @SeqStart, $SStart[$Index[$Id1][$i]] + 1;
			push @SeqEnd, $SEnd[$Index[$Id1][$i]];
		}
		printf "[ %s ] Sorting by chr number and start coord finished.\n", TimeString(time,$BeginTime);
		
		for my $i (1 .. 25)
		{
			$ChrFlag[$i] = 0;
			$ChrStartId[$i] = 0;
			$ChrEndId[$i] = 0;
			for my $j (0 .. $#Chr)
			{
				if($Chr[$j] == $i)
				{
					$ChrFlag[$i] ++;
					if($ChrFlag[$i] == 1)
					{
						$ChrStartId[$i] = $j; 
					}
					$ChrEndId[$i] = $j;
				}
			}
		}
	}

	# Real Capture;
	my @Seq;
	if(-e $Reference)
	{
		my ($Left,$Right,$LineId);
		my ($tChr,$SeqNum,$MaxLine,$tmp,$tmpLine,$tmpCol);
		my (@StartLine,@StartCol,@EndLine,@EndCol);
		my (@UnfinishFlag,@RetraceId);
		
		for my $i (0 .. $#Chr)
		{
			$UnfinishFlag[$i] = 1;
		}
		
		open(REF,"< $Reference") or die $!;
		while(my $Line = <REF>)
		{
			# the start flag of one chromosome;
			if($Line =~ /^>/)
			{
				chomp $Line;
				
				if($Line =~ /X/i)
				{
					$tChr = 23;
				}
				elsif($Line =~ /Y/i)
				{
					$tChr = 24;
				}
				elsif($Line =~ /M/i)
				{
					$tChr = 25;
				}
				else
				{
					$Line =~ s/>chr//;
					$tChr = $Line;
				}
				
				$SeqNum = 0;
				if($ChrFlag[$tChr])
				{
					$MaxLine = 0;
					for my $i ($ChrStartId[$tChr] .. $ChrEndId[$tChr])
					{
						$RetraceId[$SeqNum] = $i;
						
						$tmpLine = int($SeqStart[$i] / 50);
						$tmpCol = $SeqStart[$i] % 50;
						if($tmpCol == 0)
						{
							$tmpLine --;
							$tmpCol = 49;
						}
						else
						{
							$tmpCol --;
						}
						$StartLine[$SeqNum] = $tmpLine;
						$StartCol[$SeqNum] = $tmpCol;
						
						$tmpLine = int($SeqEnd[$i] / 50);
						$tmpCol = $SeqEnd[$i] % 50;
						if($tmpCol == 0)
						{
							$tmpLine --;
							$tmpCol = 49;
						}
						else
						{
							$tmpCol --;
						}
						$EndLine[$SeqNum] = $tmpLine;
						$EndCol[$SeqNum] = $tmpCol;
						
						$SeqNum ++;
						if($tmpLine > $MaxLine)
						{
							$MaxLine = $tmpLine;
						}
					}
					
					$Left = 0;
					$Right = 0;
					$LineId = 0;
				}
			}
			else
			{
				if($SeqNum == 0)
				{
				}
				elsif($LineId < $StartLine[$Left] || $LineId > $MaxLine)
				{
				}
				else
				{
					chomp $Line;
					
					# $Left = 0;
					# extend the right boundary if needed;
					if($StartLine[$Right] <= $LineId)
					{
						$tmp = 0;
						for my $i ($Right + 1 .. $SeqNum - 1)
						{
							$tmp ++;
							if($StartLine[$i] > $LineId)
							{
								$Right += $tmp;
								last;
							}
						}
					}
					
					$tmp = 0;
					for my $i ($Left .. $Right)
					{
						# Always reserve a position for the next possible;
						if($UnfinishFlag[$RetraceId[$i]])
						{
							$tmp ++;
							if($tmp == 1)
							{
								$Left = $i;
							}
							
							if($LineId == $StartLine[$i])
							{
								if($LineId < $EndLine[$i])
								{
									$Seq[$RetraceId[$i]] = substr($Line,$StartCol[$i],(50 - $StartCol[$i]));
								}
								elsif($LineId == $EndLine[$i])
								{
									$Seq[$RetraceId[$i]] = substr($Line,$StartCol[$i],($EndCol[$i] - $StartCol[$i] + 1));
									$UnfinishFlag[$RetraceId[$i]] = 0;
								}
							}
							elsif($StartLine[$i] < $LineId && $LineId < $EndLine[$i])
							{
								$Seq[$RetraceId[$i]] .= $Line;
							}
							elsif($LineId == $EndLine[$i])
							{
								$Seq[$RetraceId[$i]] .= substr($Line,0,($EndCol[$i] + 1));
								$UnfinishFlag[$RetraceId[$i]] = 0;
							}
						}
					}
				}
				
				$LineId ++;
			}
		}	
		close REF;
		printf "[ %s ] Sequence capturing finished.\n", TimeString(time,$BeginTime);
	}

	# Logging;
	if($LogFile)
	{
		open(LOG,"> $LogFile") or die $!;
		for my $i (0 .. $#Chr)
		{
			$Chr[$i] = Num2Chr($Chr[$i]);
			print LOG ">$Chr[$i]:",$SeqStart[$i] - 1,"-$SeqEnd[$i]\n$Seq[$i]\n";
		}
		close LOG;
		printf "[ %s ] Sequence recording done.\n", TimeString(time,$BeginTime);
	}
}


######### Sub functions ##########