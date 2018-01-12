#!/usr/bin/env perl
#===============================================================================
#
#         FILE: get_aws_resources.pl
#
#      DESCRIPTION: Script to get aws resources details.
#
#      VERSION:  1.0
#      CREATED:  04/12/17 12:35:44
#===============================================================================
use strict;
use warnings;
use Getopt::Std;
use JSON qw( decode_json );
use Excel::Writer::XLSX;
use Tie::IxHash;

$0 =~ s/.*(\/|\\)//;
my %options;
sub usage
        {
        print STDERR << "EOF";
          
        Script to get aws resources details
            
        usage:
                    $0 -h
                    $0 <options>
            
        where,
            <options>
                    -b          S3 bucket name.

         *  First form  :     Show this usage message.

EOF
        exit 1;
        }
getopts("o:b:h", \%options);
usage() if $options{h};
my $user = `whoami`;
chomp $user;
unless(($ENV{'AWS_ACCESS_KEY_ID'}) || $ENV{'AWS_SECRET_ACCESS_KEY'})
        {
        print "\nYou have to set AWS_ACCESS_KEY_ID && AWS_SECRET_ACCESS_KEY environment variables!\n\n";
        exit 1;
        }
unless($ENV{'AWS_DEFAULT_REGION'})
        {
        print "\nYou have to set AWS_DEFAULT_REGION environment variable!\n\n";
        exit 1;
        }
my %config =
(
        BUCKET_NAME	=> ($options{b}) ? $options{b} : 0,
);
my $launchTime = getTimeStamp();

if ($config{VERBOSE_MODE})
	{
	displaySection(
        	" $0 | VERBOSE MODE");
	}
else
	{
	displaySection(
        	" $0 ");
	}
getAccount(\%config);

my $filename = "$config{ACCOUNT_ID}-$ENV{'AWS_DEFAULT_REGION'}.xlsx";
$config{workbook}  = Excel::Writer::XLSX->new($filename);

print "* File Name  : $filename\n\n";

if (defined $options{b})
	{
	getS3Contents(\%config)	
	}
else
	{
	getRds(\%config);
	getStack(\%config);
	getElb(\%config);
	getInstances(\%config);
	getASG(\%config);
	getIgw(\%config);
	getNat_gw(\%config);
	getVPC(\%config);
	getElasticache(\%config);
	getAmi(\%config);
	getSecuritygroups(\%config);
	getBuckets(\%config);
	}
displaySection(
        	" Successfully ended ");
###############################################################################
#TAG:get
###############################################################################

sub getAccount
	{
	my $configHR = shift;
	my %info;
	my @matrix;
	my @tags;
	$configHR->{'EXECUTE'}='aws sts get-caller-identity';
	my $raw = execute($configHR);
	return unless($raw);
	my $decoded = decode_json($raw);
	$configHR->{ACCOUNT_ID} = $decoded->{'Account'};
	$configHR->{USER_ID} = $decoded->{'UserId'};
	print "\n* AWS ACCOUNT: $configHR->{ACCOUNT_ID}\n";
	print "* USER ID    : $configHR->{USER_ID}\n";
	print "* REGION     : $ENV{'AWS_DEFAULT_REGION'}\n";
	return 1;
	}

sub getS3Contents
	{
	my $configHR = shift;
	tie my %info, "Tie::IxHash";
	$info{INFO_DETAIL} ='S3 Buckets';
	my @matrix;
	my @tags;
	verbose("Checking s3 bucket contents");
	$configHR->{'EXECUTE'}="aws s3api list-objects --bucket $configHR->{BUCKET_NAME} --output json";
	my $raw = execute($configHR);
	return unless($raw);
	my $decoded = decode_json($raw);
	my @contents = @{$decoded->{'Contents'}};
	foreach my $f (@contents)
		{
                push(@{$info{'Key'}},$f->{'Key'});
                push(@{$info{'LastModified'}},$f->{'LastModified'});
		}
	printTable(\%info, $configHR);
	}

sub getBuckets
	{
	my $configHR = shift;
	tie my %info, "Tie::IxHash";
	$info{INFO_DETAIL} ='S3 Buckets';
	my @matrix;
	my @tags;
	verbose("Checking s3 buckets");
	$configHR->{'EXECUTE'}='aws s3api list-buckets --output json';
	my $raw = execute($configHR);
	return unless($raw);
	my $decoded = decode_json($raw);
	my @buckets = @{$decoded->{'Buckets'}};
	foreach my $f (@buckets)
		{
                push(@{$info{'Name'}},$f->{'Name'});
                push(@{$info{'CreationDate'}},$f->{'CreationDate'});
		}
	printTable(\%info, $configHR);
	}

sub getASG
	{
	my $configHR = shift;
	my $size = 0;
	my %info =(
		INFO_DETAIL=>'Auto Scaling Groups'
	);
	my @matrix;
	my @tags;
	verbose("Checking autoscale groups");
	$configHR->{'EXECUTE'}='aws autoscaling describe-auto-scaling-groups --output json';
	my $raw = execute($configHR);
	return unless($raw);
	my $decoded = decode_json($raw);
	my @asg = @{$decoded->{'AutoScalingGroups'}};
	foreach my $f (@asg)
		{
                push(@{$info{AutoScalingGroupName}},$f->{'AutoScalingGroupName'});
                push(@{$info{MinSize}},$f->{MinSize});
                push(@{$info{MaxSize}},$f->{MaxSize});
                push(@{$info{DesiredCapacity}},$f->{DesiredCapacity});
                push(@{$info{VPCZoneIdentifier}},$f->{VPCZoneIdentifier});
		@tags = @{ $f->{'Tags'} } if ($f->{'Tags'});
		foreach my $t (@tags)
			{
			if($t->{'Key'} eq 'Name')
				{
                		push(@{$info{'TAG_NAME'}},$t->{'Value'});
				}
			}
                	push(@{$info{'TAG_NAME'}},'N/A') if(not exists $info{'TAG_NAME'});
		}
	printTable(\%info, $configHR);
	}

sub getVPC
	{
	my $configHR = shift;
	my $size = 0;
	my %info =(
		INFO_DETAIL=>'VPC'
	);
	my @matrix;
	my @tags;
	verbose("Checking aws vpc");
	$configHR->{'EXECUTE'}='aws ec2 describe-vpcs --output json';
	my $raw = execute($configHR);
	return unless($raw);
	my $decoded = decode_json($raw);
	my @vpcid = @{$decoded->{'Vpcs'}};
	foreach my $f (@vpcid)
		{
                push(@{$info{'VpcId'}},$f->{'VpcId'});
                push(@{$info{'CidrBlock'}},$f->{'CidrBlock'});
                push(@{$info{'IsDefault'}},$f->{'IsDefault'});
		@tags = @{ $f->{'Tags'} } if ($f->{'Tags'});
		foreach my $t (@tags)
			{
			if($t->{'Key'} eq 'Name')
				{
                		push(@{$info{'TAG_NAME'}},$t->{'Value'});
				}
			}
                	push(@{$info{'TAG_NAME'}},'N/A') if(not exists $info{'TAG_NAME'});
		}
	printTable(\%info, $configHR);
	}

sub printTable
	{
	my $info = shift;
	my $configHR = shift;
	if (! defined $configHR->{'workbook'})
		{
		my $i=0;
		my @matrix;
		print "\n* $info->{INFO_DETAIL}\n";
		print '=' x (2 + (length $info->{INFO_DETAIL}));
		print "\n\n";
		delete $info->{INFO_DETAIL};
		for my $k (keys %$info)
			{
			my $y=0;
			$matrix[$i][$y] = $k;
			$y++;
			my @val = @{$info->{$k}};
			foreach my $a(@val)
				{
				$matrix[$i][$y] = $a;	
				$y++;
				}
			$i++;
			}
		if (!defined $matrix[0])
			{
			print "N/A";
			}
		else
			{
			for(my $k=0; $k < scalar (@{$matrix[0]}); $k++)
				{
				for(my $y=0; $y < scalar @matrix; $y++)
					{
					my $out = $matrix[$y][$k];
					if(length $out > 2500)
						{
						my @name_part = $out =~ /(.{1,25})/g;
						my $flag = 0;
						foreach(@name_part)
							{
							if($flag == 0)
								{
								print "\t$_\n";
								}
						else
							{
							print "\t" x $y;
							print "$_";
							$flag = 1;
							}
						printf("%-25s", $_); 
						}
					}
				else
					{
					printf("%-25s\t", $out); 
					}
				}
				print "\n";
				}
			}
		delete $info->{INFO_DETAIL};
		print "\n";
		}
	else
		{
		my $i=0;
		my @matrix;
 		my $worksheet_name = $info->{INFO_DETAIL};
		delete $info->{INFO_DETAIL};
		for my $k (keys %$info)
			{
			my $y=0;
			$matrix[$i][$y] = $k;
			$y++;
			my @val = @{$info->{$k}};
			foreach my $a(@val)
				{
				$matrix[$i][$y] = $a;	
				$y++;
				}
			$i++;
			}
		if (!defined $matrix[1])
			{
			#$worksheet->write( 0, 0, "N/A" );
			verbose("$worksheet_name: N/A");
			}
		else
			{
			my $worksheet = $configHR->{workbook}->add_worksheet($worksheet_name);
			#for(my $k=0; $k < scalar (@{$matrix[1]}); $k++)
			for(my $k=0; $k < scalar @matrix; $k++)
				{
				for(my $y=0; $y < scalar (@{$matrix[1]}); $y++)
					{
 					$worksheet->write( $y, $k, $matrix[$k][$y]) if($matrix[$k][$y]);
 					#print "k: $k | y: $y | $matrix[$k][$y]\n";
					}
				}
			}
		delete $info->{INFO_DETAIL};
		}	
	}

sub getSecuritygroups
	{
	my $configHR = shift;
	my %info =(
		INFO_DETAIL=>'Security Groups'
	);
	verbose("Checking SecurityGroups");
	$configHR->{'EXECUTE'}= 'aws ec2 describe-security-groups';
	my $raw = execute($configHR);
	return unless($raw);
	my $decoded = decode_json($raw);
	my @sg = @{$decoded->{'SecurityGroups'}};
	foreach my $f (@sg)
		{
                push(@{$info{'GroupName'}},$f->{'GroupName'});
                push(@{$info{'VpcId'}},$f->{'VpcId'});
                push(@{$info{'Description'}},$f->{'Description'});
		my $IpPermissions_hr = $f->{IpPermissions}[0];
		my $IpRanges_hr = $IpPermissions_hr->{IpRanges}[0];
                push(@{$info{'ToPort'}},$IpPermissions_hr->{'ToPort'});
                push(@{$info{'FromPort'}},$IpPermissions_hr->{'FromPort'});
                push(@{$info{'CidrIp'}},$IpRanges_hr->{'CidrIp'});
		}
	printTable(\%info, $configHR);
	return;
	}

sub getAmi
	{
	my $configHR = shift;
	my %info =(
		INFO_DETAIL=>'AMI'
	);
	verbose("Checking images");
	$configHR->{'EXECUTE'}= 'aws ec2 describe-images --owners self';
	my $raw = execute($configHR);
	return unless($raw);
	my $decoded = decode_json($raw);
	my @ami = @{$decoded->{'Images'}};
	foreach my $f (@ami)
		{
                push(@{$info{'Name'}},$f->{'Name'});
                push(@{$info{'ImageId'}},$f->{'ImageId'});
                push(@{$info{'CreationDate'}},$f->{'CreationDate'});
                push(@{$info{'VirtualizationType'}},$f->{'VirtualizationType'});
                push(@{$info{'Hypervisor'}},$f->{'Hypervisor'});
		}
	printTable(\%info, $configHR);
	return;
	}

sub getElasticache
	{
	my $configHR = shift;
	my %info =(
		INFO_DETAIL=>'Elasticache'
	);
	verbose("Checking elasticache");
	$configHR->{'EXECUTE'}= 'aws elasticache describe-cache-clusters --output json';
	my $raw = execute($configHR);
	return unless($raw);
	my $decoded = decode_json($raw);
	my @elasticache = @{$decoded->{'CacheClusters'}};
	foreach my $f (@elasticache)
		{
                push(@{$info{'CacheClusterId'}},$f->{'CacheClusterId'});
                push(@{$info{'NumCacheNodes'}},$f->{'NumCacheNodes'});
                push(@{$info{'CacheClusterCreateTime'}},$f->{'CacheClusterCreateTime'});
                push(@{$info{'AutoMinorVersionUpgrade'}},$f->{'AutoMinorVersionUpgrade'});
                push(@{$info{'EngineVersion'}},$f->{'EngineVersion'});
                push(@{$info{'CacheNodeType'}},$f->{'CacheNodeType'});
                push(@{$info{'PreferredMaintenanceWindow'}},$f->{'PreferredMaintenanceWindow'});
                push(@{$info{'SnapshotWindow'}},$f->{'SnapshotWindow'});
		}
	printTable(\%info, $configHR);
	return;
	}

sub getRds
	{
	my $configHR = shift;
	my %info =(
		INFO_DETAIL=>'RDS'
	);
	verbose("Checking rds");
	$configHR->{'EXECUTE'}= 'aws rds describe-db-instances --output json';
	my $raw = execute($configHR);
	return unless($raw);
	my $decoded = decode_json($raw);
	my @rds = @{$decoded->{'DBInstances'}};
	foreach my $f (@rds)
		{
                push(@{$info{'DBInstanceIdentifier'}},$f->{'DBInstanceIdentifier'});
                push(@{$info{'StorageEncrypted'}},$f->{'StorageEncrypted'});
                push(@{$info{'DBName'}},$f->{'DBName'});
                push(@{$info{'AllocatedStorage'}},$f->{'AllocatedStorage'});
                push(@{$info{'MultiAZ'}},$f->{'MultiAZ'});
                push(@{$info{'Engine'}},$f->{'Engine'});
                push(@{$info{'PubliclyAccessible'}},$f->{'PubliclyAccessible'});
                push(@{$info{'LicenseModel'}},$f->{'LicenseModel'});
                push(@{$info{'InstanceCreateTime'}},$f->{'InstanceCreateTime'});
                push(@{$info{'AutoMinorVersionUpgrade'}},$f->{'AutoMinorVersionUpgrade'});
                push(@{$info{'PreferredBackupWindow'}},$f->{'PreferredBackupWindow'});
                push(@{$info{'DBInstanceArn'}},$f->{'DBInstanceArn'});
                push(@{$info{'BackupRetentionPeriod'}},$f->{'BackupRetentionPeriod'});
                push(@{$info{'DBInstanceStatus'}},$f->{'DBInstanceStatus'});
                push(@{$info{'StorageType'}},$f->{'StorageType'});
                push(@{$info{'DBInstanceClass'}},$f->{'DBInstanceClass'});
		}
	printTable(\%info, $configHR);
	return;
	}

sub getStack
	{
	my $configHR = shift;
	my %info =(
		INFO_DETAIL=>'Cloudformation Stacks'
	);
	verbose("Checking cfn stacks");
	$configHR->{'EXECUTE'}= 'aws cloudformation list-stacks --stack-status-filter CREATE_IN_PROGRESS CREATE_COMPLETE ROLLBACK_IN_PROGRESS UPDATE_IN_PROGRESS UPDATE_COMPLETE UPDATE_ROLLBACK_IN_PROGRESS UPDATE_ROLLBACK_FAILED  UPDATE_ROLLBACK_COMPLETE UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS  --output json';
	my $raw = execute($configHR);
	return unless($raw);
	my $decoded = decode_json($raw);
	my @stacks = @{$decoded->{'StackSummaries'}};
	foreach my $f (@stacks)
		{
                push(@{$info{'StackName'}},$f->{'StackName'});
                push(@{$info{'StackStatus'}},$f->{'StackStatus'});
                push(@{$info{'TemplateDescription'}},$f->{'TemplateDescription'});
                push(@{$info{'StackId'}},$f->{'StackId'});
                push(@{$info{'CreationTime'}},$f->{'CreationTime'}) if($f->{'CreationTime'});
		}
	printTable(\%info, $configHR);
	return;
	}

sub getElb
	{
	my $configHR = shift;
	my %info =(
		INFO_DETAIL=>'Load Balancers'
	);
	verbose("Checking elb");
	$configHR->{'EXECUTE'}= 'aws elb describe-load-balancers  --output json';
	my $raw = execute($configHR);
	return unless($raw);
	my $decoded = decode_json($raw);
	my @elb = @{$decoded->{'LoadBalancerDescriptions'}};
	foreach my $f (@elb)
		{
                push(@{$info{'DNSName'}},$f->{'DNSName'});
                push(@{$info{'LoadBalancerName'}},$f->{'LoadBalancerName'});
                push(@{$info{'Scheme'}},$f->{'Scheme'});
                my $listener_hr = $f->{ListenerDescriptions}[0];
                push(@{$info{'InstancePort'}},$listener_hr->{'Listener'}{'InstancePort'});
                push(@{$info{'LoadBalancerPort'}},$listener_hr->{'Listener'}{'LoadBalancerPort'});
                push(@{$info{'Protocol'}},$listener_hr->{'Listener'}{'Protocol'});
                push(@{$info{'InstanceProtocol'}},$listener_hr->{'Listener'}{'InstanceProtocol'});
		}
	printTable(\%info, $configHR);
	return;
	}

sub getInstances
	{
	my $configHR = shift;
	my %info =(
		INFO_DETAIL=>'EC2 Instances'
	);
	verbose("Checking instances");
	$configHR->{'EXECUTE'}= 'aws ec2 describe-instances --output json';
	my $raw = execute($configHR);
	return unless($raw);
	my $decoded = decode_json($raw);
	my @ngw = @{$decoded->{'Reservations'}};
	foreach my $f (@ngw)
		{
                my $reservation_id = $f->{'ReservationId'};
                my $reservation_hr = @{$f->{Instances}}[0];
                push(@{$info{'InstanceId'}},$reservation_hr->{'InstanceId'});
                push(@{$info{'ImageId'}},$reservation_hr->{'ImageId'});
                push(@{$info{'InstanceType'}},$reservation_hr->{'InstanceType'});
                push(@{$info{'SubnetId'}},$reservation_hr->{'SubnetId'});
                push(@{$info{'VpcId'}},$reservation_hr->{'VpcId'});
                push(@{$info{'LaunchTime'}},$reservation_hr->{'LaunchTime'});
                push(@{$info{'PrivateIpAddress'}},$reservation_hr->{'PrivateIpAddress'});
                push(@{$info{'KeyName'}},$reservation_hr->{'KeyName'});
                push(@{$info{'PublicDnsName'}},$reservation_hr->{'PublicDnsName'});
		}
	printTable(\%info, $configHR);
	return;
	}

sub getNat_gw
	{
	my $configHR = shift;
	my %info =(
		INFO_DETAIL=>'NAT Gateways'
	);
	verbose("Checking nat gateways");
	$configHR->{'EXECUTE'}= 'aws ec2 describe-nat-gateways --output json';
	my $raw = execute($configHR);
	return unless($raw);
	my $decoded = decode_json($raw);
	my @ngw = @{$decoded->{'NatGateways'}};
	foreach my $f (@ngw)
		{
                my $ngw_id = $f->{'NatGatewayId'};
                my $ngw_Addresses_hr = @{$f->{NatGatewayAddresses}}[0];
                push(@{$info{'NatGatewayId'}},$f->{'NatGatewayId'});
                push(@{$info{'VpcId'}},$f->{'VpcId'});
                push(@{$info{'SubnetId'}},$f->{'SubnetId'});
                push(@{$info{'PublicIp'}},$ngw_Addresses_hr->{'PublicIp'});
                push(@{$info{'PrivateIp'}},$ngw_Addresses_hr->{'PrivateIp'});
		}
	printTable(\%info, $configHR);
	return;
	}

sub getIgw
	{
	my $configHR = shift;
	my %info =(
		INFO_DETAIL=>'Internet Gateways'
	);
	verbose("Checking internet gateways");
	my @tags;
	$configHR->{'EXECUTE'}= 'aws ec2 describe-internet-gateways --output json';
	my $raw = execute($configHR);
	return unless($raw);
	my $decoded = decode_json($raw);
	my @igw = @{$decoded->{'InternetGateways'}};
	foreach my $f (@igw)
		{
		my $tag_name ='N/A';
		my $vpcid_hr = @{$f->{'Attachments'}}[0];
                push(@{$info{'InternetGatewayId'}},$f->{'InternetGatewayId'});
		
                push(@{$info{'VpcId'}},$vpcid_hr->{VpcId});
                my @tags = @{$f->{'Tags'}};
		foreach my $key (@tags)
			{
			if ($key->{'Key'} eq 'Name')
				{
				$tag_name = $key->{'Value'};
				}
			}
                push(@{$info{'TAG_NAME'}}, $tag_name);
		}
	printTable(\%info, $configHR);
	return;
	}

###############################################################################
#TAG:LOG
###############################################################################
sub Log
    {
    my $msg = shift;
    if(ref($msg) eq "ARRAY")
        {
        foreach my $line(@$msg)
            {
            $line = trim($line) || next;
            print LOG "=== $line\n";
            }
        return 1;
        }
    $msg = trim($msg) || return 1;
    if($msg =~ /^\+\+\+/)
        {
        print LOG $msg ."\n";
        }
    else
        {
        print LOG "=== $msg\n";
        }
    return 1;
    }
sub execute
        {
        my $configHR = shift;
	#verbose($configHR->{'EXECUTE'});
        $configHR->{STDOUT} = `$configHR->{'EXECUTE'} 2>&1`;
        if ($?)
		{
		print "Error, \n";
		print "\t  $configHR->{STDOUT}\n";
                exit 1;
	 	}
	#verbose($configHR);
	delete $configHR->{EXECUTE};
	my $STDOUT =  $configHR->{STDOUT};
	delete $configHR->{STDOUT};
        return $STDOUT;
        }
###############################################################################
#TAG:COMMON.
###############################################################################
sub appendZero
        {
        my $val = shift;
        $val = trimSpace($val) || '0';
        return '0' unless($val);
        return "0$val";
        }
sub returnError
        {
        my $infoHR = shift;
        my $errorMessage = shift;
        $infoHR->{ERROR} = ($errorMessage) ? $errorMessage : 'N/A';
        return;
        }
sub returnVerbose
        {
        my $msg = shift;
        my $time = sprintf '%02d:%02d:%02d', ( localtime )[2,1,0];
        if($msg =~ /^\s*\+\s*/)
                {
                $msg =~ s/^\+\s*/\+\+\+\+\+\+\+\+\+\+ /;
                }
        elsif($msg =~ /^\s*\*/)
                {
                $msg =~ s/^\*\s*/\*\*\*\*\*\*\*\*\*\* /;
                }
        else
                {
                $msg =~ s/^\s*/[$time] /;
                }
        return $msg;
        }
sub showError
        {
        my $err=shift;
        my $sub=shift;
        my $msg;
        unless($sub)
                {
                $sub="Error";
                }
        else
                {
                $sub="Error $sub";
                }
        if($err)
                {
                $msg="$sub :\n\t$err\n";
                }
        else
                {
                $msg="$sub :\n\tPlease try log file/debug mode for further details.\n";
                }
        return $msg;
        }
sub trimSpace
        {
        my $val = shift;
        return unless($val);
        $val =~ s/^\s+//;
        $val =~ s/\s+$//;
        return unless($val);
        return $val;
        }
sub trim
    {
    my $val = shift;
    return unless($val);
    $val =~ s/^\s+//;
    $val =~ s/\s+$//;
    return unless($val);
    return $val;
    }
sub verbose
	{
    	my $msg = shift;
    	my $time = sprintf '%02d:%02d:%02d', ( localtime )[2,1,0];
	print "$time  [ $msg ]\n";
    	return 1;
    	}

sub getTimeStamp
        {
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
        $year +=1900;
        #Format:
        #   Year Month Day hour min sec.
        #
        $mon = appendZero($mon + 1); #Month range 0-11.
        $mday = appendZero($mday);
        $min = appendZero($min);
        $hour = appendZero($hour);
        return "$year$mon$mday-$hour$min$sec";
        }
sub displaySection
        {
        my $message = shift;
        $message = "$message | ".localtime();
        my $out =  '-' x 80;
        $out .= "\n";
        my $len = length($message);
        $len = 78 - $len;
        $out .= "[$message";
        $out .= ' ' x $len;
        $out .= "]\n";
        $out .=  '-' x 80;
        $out .= "\n";
        print $out;
        return 1;
        }
