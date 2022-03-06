# HTTPSScaled

## General

This is a Scaling Group joined HTTPS Server with igw, scaling group, load balancer and firewalling to allow just ssh and https.

This has been created on Mac OSX using Visual Studio Code.

It spins up a simple web page to only allow https (and ssh for ec2 instance connect access) connections to an EC2 instance.

This sets up a simple security group to only accept 443 HTTPS and 22 ssh traffic.

It then starts an EC2 Linux instance of t2 micro and installs httpd, php and ssl.

## Providers
provider.tf gets the aws module to allow for the other sections to control aws.

## Outputs
At the end of the run the created AMI ID, Initial Instance ID and Load Balancer name is output. In order to hit the web page you can https to the output of the build script and you will see the application webpage.

## Main
main.tf has all the rest as I have kept this fairly flat. There isn't that much in the solution so it made sense to keep it in one place.

## Variables
The variables required to be set are:

aws_region="<Set as the region you want to build into>" - This is currently eu-west-2

vpc_net="<subnet>" - This is the overall vpc IP range. In this example it has been set to 10.10.0.0

subnet1="<subnet>" - This is the subnet you want in the first AZ. In this example it has been set to 10.10.1.0

subnet2="<subnet>" - This is the subnet you want in the second AZ. In this example it has been set to 10.10.2.0

subnet3="<subnet>" - This is the subnet you want in the third AZ. In this example it has been set to 10.10.3.0

build_ami_id="<AMI ID>" - This is the AMI ID of the AMI you would like to base the build on. The build runs on Amazon Linux and ami-060c4f2d72966500a is used as the available AMI in eu-west-2. This should be set accordingly if a different region is used.

## Networking
The networking forms the basis of the solution

### VPC
The first thing to setup is the VPC - This is setup using the variable provided. In this case 10.10.0.0

### Subnets
One subnet is setup for each AZ within the given region. This example uses London region and a, b and c AZs for resilience. Each subnet is given the range specified in the variables.

### Internet gateway
In order to get to the service an Internet Gateway is required by the solution. This allows for the service to be accessible from the web.

### Routing Table
The routing table allows traffic out to the web and associates the subnets that have been created with that routing.

### Security Group
The security group setup allows only port 22 (ssh) and port 443 (https) ingress. All outgoing traffic is allowed.

### Load Balancer
The Load Balancer is setup in order to act as the front end of the application. It includes all 3 subnets and is accessible from the web.

### Load Balancer Target Group
The Load Balancer Target group tells the load balancer where to forward traffic to and is populated by the scaling group (mentioned below) when instances are started and added to the group. The scaling group can add a target or multiple targets to spread the load across.

### Load balancer Listener
The load balancer listener passes all https traffic straight through to the application instances when port 443 is hit.

## Instance setup
An Instance is started with the ami set in the variables. This AMI will be dependent on region and should be changed accordingly. It will use the security group setup above so it allows https and ssh traffic into the instance. Although this initial instance is started in Availability Zone a it can be started in any zone in the region. This instance should be shutdown once the user is satisfied that the build and AMI is complete and correct. It should not be terminated as it can be used for upgrades while not affecting the core application and then the launch template can be updated to reflect this.

During the instance creation the user_data section creates the http server to accept only https and adds a default webpage to serve as a test.

## HTTPD Setup
The index page of the application is populated during the user_data section of the instance start so that when you hit view the page you are told your IP, ISP etc (Thanks to Jeff Starr on perishable Press for the code for that). It allows for testing of the load balancing section of this solution.

## AMI Creation
Once built the AMI is created for scaling instances. This initial instance can be shutdown but should be used for upgrade purposes to allow for updating the AMI offline so as not to affect service.

## Launch Template
The launch template uses the AMI created by the step above and allows for consistent, uniform and repeatable rollout of the application service.

## Scaling Group
The scaling group is currently set to start 3 instances of the application which all run behind the Load Balancer that is created. The scaling group manages the instances and adds more or starts new ones if instances are found not to be healthy. If required this number could be set as a variable but 3 demonstrates the resilience across AZs suitably for this purpose. The Scaling Group will create an instance in each AZ, allowing for resilience in the unlikely event of an AZ outage.

# Using the build and Application
Once your development environment is setup to connect to AWS with a user with suitable privileges to create and change resources you should be able to run terraform init and terraform apply in order to build the project. If the IPs that are in the variables do not clash with anything you already have setup then this should run completely.

Once the run has completed you will have 4 instances started (You may have to allow a few minutes for the scaling group to complete the start of the 3 instances within the group).

The first instance built (Tagged as HTTPSWebServer) can be shutdown but should not be terminated. This instance should be used for AMI updates in order to allow OS and application updates to be applied without impact to the service. Once this instance has been updated and tested the AMI can be updated, at which point the scaling group can update the instances it has without outage, while sharing service across the Target Group.

## Accessing the application
The output from the build run gives the https web address for the service in the output. If you copy and paste this address into a web browser (once the service is up and running) you will be presented with a web page that tells you your IP address and the IP address of the host serving the page. Although this is not desirable from a security perspective it is useful for the purposes of this project in order to show how the load balancer is working and that you are presented the webpage from multiple hosts.

If you allow time for the load balancer, scaling group, instances and associated listeners to start and become healthy then you will be able to see that you are served by all of the load balanced targets due to the load balancer.

## Monitoring
Monitoring has not been put in place for this project yet. This is for future development.
