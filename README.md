# OSEv3 AWS workshop

#### Jim Minter, 12/10/2015

## Very rough setup instructions

This is currently a disgusting and excessively laborious process.  Corrections,
clarifications and improved automation gratefully received as pull requests.
For now, read this carefully and practice with one instance first!

## Prerequisites

* AWS account

* [AWS CLI](https://aws.amazon.com/cli/) installed on management host - see
  [instructions](http://docs.aws.amazon.com/cli/latest/userguide/installing.html)

* AWS CLI configured - see [instructions](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html)

  * My settings were as follows:

    ```
    $ aws configure
    AWS Access Key ID [None]: <your akid>
    AWS Secret Access Key [None]: <your sak>
    Default region name [None]: eu-west-1
    Default output format [None]: json
    ```

* Sufficient AWS quota

  * Essential: by default AWS will probably allow you to spin up 20 x m4.large
    on-demand instances in a region.  See [here](http://docs.aws.amazon.com/general/latest/gr/aws_service_limits.html#limits_ec2)
    and [here](http://aws.amazon.com/ec2/faqs/#How_many_instances_can_I_run_in_Amazon_EC2)
    for details.  If you will need more quota, see [here](http://docs.aws.amazon.com/general/latest/gr/aws_service_limits.html)
    for how to request it.  Amazon were quick to respond to my request when I
    asked them, but don't count on it!
  * Nice to have: by default AWS will give you 5 long-term Elastic IP addresses.
    *If* you want to be able to poweroff your class instances between
    pre-preparation and the class itself, you must use one of these per
    instance, otherwise the elastic IP and DNS will change!

* Appropriate AWS setup

  * Ensure your VPC has *DNS hostnames* set to yes
  * Ensure your VPC subnet is in the 192.168 range, not 172.anything (otherwise
    a k8s conflict is possible)
  * Include the following inbound ports in your VPC security group: 22, 80, 443,
    5900, 8443
  * Sanity check your VPC internet routing, elastic IP, public DNS resolution,
    firewall works with a standard Linux instance!

* Access to the base AMI, currently **ami-1becd86c**.  E-mail me your
  AWS account number to get access

* Customer briefed that they will need to be able to VNC an AWS instance at a
  minimum.  Ideally access on ports 22, 80, 443, 5900 and 8443 is best

## Quick Setup

1. Create instances
   
   * Edit `start.sh` to match your requirements, one run make a node of the **RunName** value (date-time)
   * `AMI=ami-1becd86c` - change AMI ID if required
   * `KEYNAME=$USER` - we expect that your security key is named the same as your current user
   * `SECGROUP=sg-xxxxxxx` - you'll need to change this to match the security group of your VPC
   * `SUBNET=subnet-xxxxxxxx` - you'll need to change this to match the subnet ID on your VPC 
   * `N=2` - this is the number of instances that will be created, set to required number

1. Generate demo user passwords

   * Run the `generate-creds.sh` with the RunName value from reported at the end of the `start.sh` run. 
   * You should get a new `creds.csv` file that lists each instance with a unique random demo user password

1. Tweak AWS instance configuration

   * Take a deep breath
   * Run `provision-all.sh` passing the path to your AWS private key, e.g. `$HOME/.aws/$USER.pem`
   * During the run log files for each instance should appear in a `log` directory

1. Generate Labels

   * **requires: glabels** `dnf install glabels -y`
   * **requires: qrencode** `dnf install qrencode -y`
   * The label template `merge.glabels` is currently formatted for Avery J8161 A4 labels
   * Run `generate-labels.sh` this will read `creds.csv` and generate some new files:
     * `label-data.csv` - data file for label
     * `qrcodes/<img>.png` - QRCode images for labels, should open OpenShift master web console
     * `output.pdf` - rendered label file as PDF, send to printer (make sure scaling is turned off)  

## Setup

1. Get the instance(s) up and running

   * Edit `start.sh` to match your environment
   * Run the `aws ec2 run-instances` command to create the instance(s).  I
     suggest creating 10% extra instances for contingency, as well as having a
     spare one for you to use to ensure everything is working
   * Check the instances come up OK, and manually number them in the AWS
     interface for your sanity
   * Run the `aws ec2 describe-instances` command to save the instance details
     to `creds.csv`.  This file should have the following columns: name, IP,
     DNS, automatically generated password of the form [a-z]{8}

1. Prepare `docs/passwords.ods` by copy-pasting in the contents of `creds.csv`.
   This spreadsheet will be used manually for preparing the following scripts
   and labels

1. Set the password for the demo user

   * Edit `set-passwords.sh` by copy-pasting column G from `docs/passwords.ods`
   * Run `set-passwords.sh`

1. Furkle with the instance(s) as appropriate.  Currently this implies updating
   $IPS in provision.sh, uncommenting then recommenting single instructions *one
   by one*, running `provision.sh` and checking the results.

   Currently, `provision.sh` covers the following steps:

   * Copy the scripts in target/ to the instance
   * Only necessary if not VNCing in: run the re-ip script (this binds OpenShift
     to the new hostname and IP of the instance, rebuilds the SSL certs, etc.)
   * Only necessary if not VNCing in: enable password-based ssh authentication
     (so the demo user can ssh in)
   * [Pre-warm the EBS volume](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-prewarm.html)
     (note that this is quite time-consuming)
   * Pre-warm OpenShift by doing a NodeJS and Java build
   * Cleanup aforementioned builds

1. Customise and print worksheets, feedback forms and labels

   * `docs/worksheet.odt` and `docs/feedback.odt` should only need dates
     changing and can then be printed
   * `docs/labels.odt` should be populated from column F of
     `docs/passwords.ods`.  Use Avery L7163 laser labels
