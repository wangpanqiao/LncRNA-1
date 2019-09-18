#!/usr/bin/perl -w
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use threads;
use FindBin qw($Bin $Script);
use Cwd qw(abs_path);
use File::Basename qw(basename dirname);
use newPerlBase;
my $BEGIN_TIME=time();
my %config=%{readconf("$Bin/../../../../../Config/lncRNA_pip.cfg")};
my $Title=$config{Title};												#���̵����ƣ�����
my $version=$config{version};
my ($ref,$circRNAFa,$od,$q,$m);
GetOptions(
				"help|?" =>\&USAGE,
				"ref:s"=>\$ref,
				"c:s"=>\$circRNAFa,
				"od:s"=>\$od,
				"queue:s" =>\$q,
				"memory:s"=>\$m,
				) or &USAGE;
&USAGE unless ($ref and $circRNAFa and $od);
mkdir $od if(! -e $od);
$od = abs_path($od);
$q=$q || "general.q";
$m = $m || "30G";
my $prefix = basename($ref);
##### blat
#`blat $ref $circRNAFa $od/output.psl`;
#### blast
my $work_sh="$od/work_sh";
&MKDIR($work_sh);
open SH,">$work_sh/blast.sh" or die $!;
open F,">$work_sh/filter.sh" or die $!;
my $refname = basename($ref);
`cd $od/ && $config{formatdb} -i $ref -n $prefix -t $prefix -l $prefix -p F && touch formatdb.finish` unless(-e "$od/formatdb.finish");
mkdir "$od/splitReads" unless(-d "$od/splitReads");
my $lineNumber = `less $circRNAFa|grep \">\"|wc -l`;
chmod $lineNumber;
my $splitNumber = int($lineNumber/100);
`$config{SeqChunker}  --chunk-number $splitNumber --out \"$od/splitReads/\%03d.fa\" $circRNAFa && touch $od/splitReads/Chunker.finish` unless(-e "$od/splitReads/Chunker.finish");
my @files = glob("$od/splitReads/*.fa");
foreach my $file(@files)
{
	my $index = basename $file;
	print SH "$config{blastn}  -db $od/$refname -query $file -outfmt 6 -num_threads 5 -out $od/splitReads/$index.blast.out\n";
}
close SH;
&Cut_shell_qsub("$work_sh/blast.sh",$m,$q);
#`cat $od/splitReads/*.blast.out >$od/splitReads/All.blast.list && touch $od/splitReads/blast.finish` unless (-e "$od/splitReads/blast.finish");
@files = glob("$od/splitReads/*.blast.out");

open( IN, "$ref" )     || die "open file failed\n";
open( OUT, ">$ref.len" )     || die "open file failed\n";
$/=">";
my %hash;
while (<IN>) {
	next if(/^>$/);
	my @line = split/\n/,$_;
	my $id = shift @line;
	my $sequence = join("",@line);
	$sequence =~s/>//;
	$sequence=~s/[\r\n]$//;
	print OUT "$id\t".length($sequence)."\n";
}
close OUT;
foreach my $file(@files)
{
	my $index = basename $file;
	print F "perl $Bin/newblast.pl $ref.len $file $od/splitReads/$index.ratio.out\n";
}
close F;
&Cut_shell_qsub("$work_sh/filter.sh",$m,$q);
`cat $od/splitReads/*.ratio.out >$od/ratio.out && touch $od/ratio.finish` unless (-e "$od/ratio.finish");


######find known and new circRNAs 
my $known = `less $od/ratio.out |cut -f1|grep -v "#"|sort|uniq`;
my $all = `less $circRNAFa|grep ">"|less`;
$all =~s/>//g;
my @known_arr = split/\n/,$known;
my %know_hash;
$know_hash{$_} = 1 foreach @known_arr;
my @all_arr = split/\n/,$all;
my @new = grep {!$know_hash{$_}} @all_arr;
open OUT1,">$od/known.list" or die $!;
open OUT2,">$od/new.list" or die $!;
open OUT3,">$od/all.list" or die $!;
open OUT4,">$od/forpie.list" or die $!;
my $newlist= join("\n",@new);
my $knownlist = join("\n",@known_arr);
my $known_num = @known_arr;
my $new_num = @new;
print OUT1 "$knownlist";
print OUT2 "$newlist";
print OUT3 "$all";
print OUT4 "Known\t$known_num\nNew\t$new_num\n";
close OUT1;
close OUT2;
close OUT3;
close OUT4;
sub MKDIR
{ # &MKDIR($out_dir);
	my ($dir)=@_;
	rmdir($dir) if(-d $dir);
	mkdir($dir) if(!-d $dir);
}
#################################################
sub Cut_shell_qsub 
{
	#Cut shell for qsub 1000 line one file
	my $shell = shift;
    # my $cpu = shift;
    my $vf = shift;
    my $queue = shift;

    my $line = `less -S $shell |wc -l `;
	my $num=1;
	my $count =0;
	if ($line<=1000) 	
	{
		`sh $config{qsub_sh} --queue $queue --resource vf=$vf --reqsub --independent $shell`;
	}
    else
	{
		open IN,"$shell"||die $!;
		open(OUT,">$shell.$num.div.sh")||die $!;
		while(<IN>)
		{
			$count++;
			if($count <=1000)
			{
				print OUT $_;
			}
			else
			{
				$num++;
				$count = 0;
				open(OUT,">$shell.$num.div.sh")||die $!;
				print OUT $_;
			}
		}
        my @div=glob "$shell.*.div*";
        &process_cmds_parallel(\@div);
	}

}
########################################################
sub process_cmds_parallel {
    my $cmds = $_[0];
    my %threads;
    foreach my $cmd (@$cmds) {
        # should only be 2 cmds max
        my $thread = threads->create(sub{
			my $start_time = time();
			unless(-e "$cmd.finish"){
				my $ret = system"sh $config{qsub_sh} --queue $q --resource vf=50G --reqsub --independent $cmd";
				#my $ret = system"sh $cmd>$cmd.log 2>&1";
				if ($ret) {
					die "Error, cmd: $cmd died with ret $ret,$!";
				}
				else{
					system"touch $cmd.finish";
				}
			}
			print "$cmd used time:",time()-$start_time,"s\n";
		},$cmd);
		my $tid=$thread->tid();
		$threads{$tid}=basename($cmd);
		print "$cmd thread id is $tid \n";
    }
                
    my $ret = 0;
    foreach my $thread (threads->list(threads::all)) {
        my $tid=$thread->tid();
		$thread->join();
		print "The thread $tid ($threads{$tid}) to join\n";
        if (my $error = $thread->error()) {
            print STDERR "Error, $threads{$tid} exited with error $error\n";
            $ret++;
        }
    }
    if ($ret) {
        die "Error, $ret threads errored out";
    }

    return;
}
#########################################################
sub USAGE {#
	my $usage=<<"USAGE";
ProgramName:
Contact:	Zhang QiuXue <zhangqx\@biomarker.com.cn> 
Usage:
  Options:
   -h			 Help        
   -ref         <file>   circBase fasta,forced
   -c           <file>   circRNA fasta,forced
   -od			<dir>    output dir,forced
   -queue		defaut general.q;
   -memory		default 30G;
USAGE
	print $usage;
	exit;
}