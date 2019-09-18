#!/usr/bin/perl
use strict;
use warnings;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use FindBin qw($Bin $Script);
use File::Basename qw(basename dirname);
my $BEGIN_TIME=time();
my $version="1.0.0";
my ($fIn,$fOut,$lnc);
## input is CIRI output file;
GetOptions(
                "help|?" =>\&USAGE,
                "o:s"=>\$fOut,
                "i:s"=>\$fIn,
				"lnc:s"=>\$lnc
                ) or &USAGE;
&USAGE unless ($fIn and $fOut and $lnc);
## all_gene_counts_detail.list
open (IN,$fIn) or die $!;
## All_gene_fpkm.list
open (FILE,$lnc) or die $!;
open (OUT,">$fOut") or die $!;

my %Lnc = ();
## ������all_gene_fpkm;
my @line = split (/\t/,<FILE>);
shift @line;
my $lncSampleName = join("\t",@line);
$lncSampleName =~s/[\r\n]$//;
while(<FILE>)
{
	next if(/\#/);
	my @line = split (/\t/,$_);
	my $gene_id = shift @line;
	my $fpkm = join("\t",@line);
	$fpkm =~s/[\r\n]$//;
	$Lnc{$gene_id}=$fpkm;
}
close FILE;

my $head = <IN>;
my @head = split (/\t/,$head);
shift @head;
pop @head;
pop @head;
my $cirsam = join("\t",@head);
my %expression = ();
while  (<IN>) {
        next if(/\#/);
		s/[\r\n]$//;
		my @line = split /\t/,$_;
		shift @line;
		my $gene_id = pop @line;
		pop @line;
		for(my $i=0;$i<@head;$i++){
			my $sample = $head[$i];
			$expression{$gene_id}{$sample}+=$line[$i];
		}

	}
close IN;

#my $lncsam =~s/(T)\d+/L/;
print OUT "gend_id\t$lncSampleName\t$cirsam\n";

foreach my $gene_id ( sort keys %expression){
	next unless($Lnc{$gene_id});
	my $lncFPKM = $Lnc{$gene_id};
	print OUT "$gene_id\t$lncFPKM\t";
	my $fpkm;
	foreach my $sample ( sort keys %{$expression{$gene_id}}) {
		my $value = $expression{$gene_id}{$sample};
		$fpkm .= "$value\t";
	}
	$fpkm =~ s/(\t$)//;
	print OUT "$fpkm\n";
}
	   

close OUT;
#######################################################################################
print STDOUT "\nDone. Total elapsed time : ",time()-$BEGIN_TIME,"s\n";
#######################################################################################

# ------------------------------------------------------------------
# sub function
# ------------------------------------------------------------------
################################################################################################################

sub ABSOLUTE_DIR{ #$pavfile=&ABSOLUTE_DIR($pavfile);
    my $cur_dir=`pwd`;chomp($cur_dir);
    my ($in)=@_;
    my $return="";
    if(-f $in){
        my $dir=dirname($in);
        my $file=basename($in);
        chdir $dir;$dir=`pwd`;chomp $dir;
        $return="$dir/$file";
    }elsif(-d $in){
        chdir $in;$return=`pwd`;chomp $return;
    }else{
        warn "Warning just for file and dir\n";
        exit;
    }
    chdir $cur_dir;
    return $return;
}

################################################################################################################

sub max{#&max(lists or arry);
    #���б��е����ֵ
    my $max=shift;
    my $temp;
    while (@_) {
        $temp=shift;
        $max=$max>$temp?$max:$temp;
    }
    return $max;
}

################################################################################################################

sub min{#&min(lists or arry);
    #���б��е���Сֵ
    my $min=shift;
    my $temp;
    while (@_) {
        $temp=shift;
        $min=$min<$temp?$min:$temp;
    }
    return $min;
}

################################################################################################################

sub revcom(){#&revcom($ref_seq);
    #��ȡ�ַ������еķ��򻥲����У����ַ�����ʽ���ء�ATTCCC->GGGAAT
    my $seq=shift;
    $seq=~tr/ATCGatcg/TAGCtagc/;
    $seq=reverse $seq;
    return uc $seq;           
}

################################################################################################################

sub GetTime {
    my ($sec, $min, $hour, $day, $mon, $year, $wday, $yday, $isdst)=localtime(time());
    return sprintf("%4d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $day, $hour, $min, $sec);
}

################################################################################################################
sub USAGE {
    my $usage=<<"USAGE";
 ProgramName:
     Version:   $version
     Contact:   Simon Young <yangxh\@biomarker.com.cn> 
Program Date:   2012.07.02
      Modify:   
 Description:   This program is used to ......
       Usage:
        Options:
        -i <file>   input file,xxx format,forced
        -o <file>   output file,forced
	 -lnc <file> input file,forced
        -h      help

USAGE
    print $usage;
    exit;
}
