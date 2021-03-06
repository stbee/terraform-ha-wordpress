resource "aws_vpc" "wordpressVpc" {
  cidr_block = "10.0.0.0/22"

  tags {
    Name        = "Demo WP"
    generatedBy = "Terraform"
  }
}

### Subnets
resource "aws_subnet" "public" {
  vpc_id                  = "${aws_vpc.wordpressVpc.id}"
  cidr_block              = "10.0.0.0/25"
  map_public_ip_on_launch = true

  tags {
    Tier = "Public"
    Name = "Demo WP Public"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = "${aws_vpc.wordpressVpc.id}"
  cidr_block        = "${element(var.private_subnet_cidr_list, count.index)}"
  availability_zone = "${element("${var.private_subnet_az_list}", count.index)}"

  tags {
    Tier = "Private"
    Name = "Demo WP Private-${count.index}"
  }
}

### Gateways
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.wordpressVpc.id}"

  tags {
    Name = "Demo WP"
  }
}

resource "aws_nat_gateway" "natGw" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${aws_subnet.public.id}"

  depends_on = ["aws_internet_gateway.gw"]

  tags {
    Name = "Demo WP"
  }
}

### Elastic IP (Required for NAT Gateway)
resource "aws_eip" "nat" {
  vpc = true

  tags {
    Name = "Demo WP"
  }
}

### Route Tables

resource "aws_route_table" "publicRt" {
  vpc_id = "${aws_vpc.wordpressVpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags {
    Name = "Demo WP Public"
  }
}

resource "aws_route_table" "privateRt" {
  vpc_id = "${aws_vpc.wordpressVpc.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.natGw.id}"
  }

  tags {
    Name = "Demo WP Private"
  }
}

# Public subnet to public route table association
resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.publicRt.id}"
}

# Private subnet to private route table association
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = "${element("${aws_subnet.private.*.id}", count.index)}"
  route_table_id = "${aws_route_table.privateRt.id}"
}
