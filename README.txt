# get_aws_resources.pl

Script to dump aws resources details to .xlsx file. Nothing fancy about this script its just a wrapper on top of aws cli.


### Prerequisites

```
cpan Excel::Writer::XLSX
cpan Tie::IxHash
```

### Limitation 

Due to limitation of AWS CLI this script does not dump all AWS resources. Example, 

```
aws cloudfront:  AWS CLI support for this service is only available in a preview stage.
```

End with an example of getting some data out of the system or using it for a little demo

## Running

##### Set AWS variables, 

```
export AWS_ACCESS_KEY_ID=XXXXXXXXXXXXXXXXXXXX
export AWS_SECRET_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
export AWS_DEFAULT_REGION=ap-southeast-2
```

* Make sure user/role have read permission.

##### Help, 

```
perl  get_aws_resources.pl -h

        Script to get aws resources details

        usage:
                    get_aws_resources.pl -h
                    get_aws_resources.pl <options>

        where,
            <options>
                    -b          S3 bucket name.

         *  First form  :     Show this usage message.
```


##### Get all the resources, 

```
--------------------------------------------------------------------------------
[ get_aws_resources.pl  | Fri Jan 12 11:18:06 2018                             ]
--------------------------------------------------------------------------------

* AWS ACCOUNT: 012222222222
* USER ID    : AROAIYUZHSQR6XGOC3FWO
* REGION     : ap-southeast-2
* File Name  : 012222222222-ap-southeast-2.xlsx

11:18:08  [ Checking rds ]
11:18:09  [ Checking cfn stacks ]
11:18:09  [ Checking elb ]
11:18:10  [ Load Balancers: N/A ]
11:18:10  [ Checking instances ]
11:18:11  [ Checking autoscale groups ]
11:18:12  [ Checking internet gateways ]
11:18:13  [ Checking nat gateways ]
11:18:13  [ Checking aws vpc ]
11:18:14  [ Checking elasticache ]
11:18:15  [ Elasticache: N/A ]
11:18:15  [ Checking images ]
11:18:16  [ Checking SecurityGroups ]
11:18:17  [ Checking s3 buckets ]
--------------------------------------------------------------------------------
[ Successfully ended  | Fri Jan 12 11:18:18 2018                               ]
--------------------------------------------------------------------------------

```


##### Get the content of S3 bucket,


```
perl get_aws_resources.pl -b test
--------------------------------------------------------------------------------
[ get_aws_resources.pl  | Fri Jan 12 11:21:20 2018                             ]
--------------------------------------------------------------------------------

* AWS ACCOUNT: 03333333333
* USER ID    : AROAIYUZHSQR6XGOC3FWO8
* REGION     : ap-southeast-2
* File Name  : 03333333333-ap-southeast-2.xlsx

11:21:22  [ Checking s3 bucket contents ]
--------------------------------------------------------------------------------
[ Successfully ended  | Fri Jan 12 11:21:24 2018                               ]
--------------------------------------------------------------------------------
```
]

