# OSEv3 AWS workshop

## Description

Build scripts for instantiating the OSEv3 AWS workshop, including end-user
documentation, using a [demobuilder](https://github.com/RedHatEMEA/demobuilder)
OSEv3 AWS image

## Install

Corrections, clarifications and improved automation are gratefully received as
pull requests.  For now, read this carefully and practice with one instance
first!

### Prerequisites

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

  * Ensure your VPC has an Internet Gatway and route, new ones don't by default
  * Ensure your VPC has *DNS hostnames* set to yes
  * Ensure your VPC subnet is in the 192.168 range, not 172.anything (otherwise
    a k8s conflict is possible)
  * Include the following inbound ports in your VPC security group: 22, 80, 443,
    5900, 8443
  * Sanity check your VPC internet routing, elastic IP, public DNS resolution,
    firewall works with a standard Linux instance!

* Access to the base AMI, currently **ami-654bcd16**.  E-mail me your
  AWS account number to get access

* Customer briefed that they will need to be able to VNC an AWS instance at a
  minimum.  Ideally access on ports 22, 80, 443, 5900 and 8443 is best

### Setup

1. Configure environment

   * `cp config.example config`
   * Edit `config` to match your environment
   * `SECGROUP=sg-xxxxxxx` - you'll need to change this to match the security
     group of your VPC
   * `SUBNET=subnet-xxxxxxxx` - you'll need to change this to match the subnet
     ID on your VPC
   * `AMI=ami-654bcd16` - change AMI ID if required
   * `KEYNAME=$USER` - by default we expect your AWS SSH key is named the same
     as your current user, but you can change this if required

1. Create instances

   * Run `./start.sh N` where N is the number of instances that will be created.
     I suggest creating 10% extra instances for contingency, as well as having a
     spare one for you to use to ensure everything is working
   * Once run, make a note of the *RunName* value (date/time)
   * You should get a new `creds.csv` file that lists each instance.  This file
     will have the following columns: name, IP, DNS, automatically generated
     password of the form [a-z]{8}
   * Wait for the instances come up OK and complete booting

1. Tweak AWS instance configuration

   * Take a deep breath!
   * Run `./provision-all.sh [KEY]` passing the path to your AWS private key,
     e.g. `$HOME/.aws/$USER.pem`, if required

  * Currently, `provision-all.sh` covers the following steps:

     * Copy the scripts in target/ to the instance
     * [Pre-warm the EBS volume](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-prewarm.html)
       (note that this typically takes around an hour)
     * Run the re-ip script (this binds OpenShift to the new hostname and IP of
       the instance, rebuilds the SSL certs, etc.)
     * Enable password-based ssh authentication (so the demo user can ssh in)
     * Pre-warm OpenShift by doing a NodeJS and Java build
     * Cleanup aforementioned builds

   * During the run, log files for each instance should appear in the `logs`
     directory

1. Generate labels

   * Run `dnf install -y glabels qrencode`
   * Run `./generate-labels.sh`.  This will read `creds.csv` and generate
     `labels/labels.pdf`

1. Customise and print worksheets, feedback forms and labels

   * `docs/worksheet.odt` and `docs/feedback.odt` should only need dates
     changing and can then be printed
   * `docs/labels.pdf` contains the labels - print (make sure scaling is turned
     off) on Avery 7163 A4 laser labels

## Clean up

You can clean up using the AWS API and the RunName tag that was
generated and set on each instance as part of the start script.

   * Run the following replacing $RUNNAME:
     `aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances --filter="Name=tag:RunName,Values=$RUNNAME" --query Reservations[].Instances[].InstanceId --output text)`
 

## Authors

* Jim Minter
* Ed Seymour

## License

[Apache License Version 2.0, January 2004](LICENSE)
