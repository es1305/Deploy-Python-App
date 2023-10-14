terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

# Environment Variables Handler
data "external" "env" {
  program = ["jq", "-n", "env"]
}

# Providers
provider "digitalocean" {
  token = data.external.env.result.DO_API_TOKEN
}

provider "aws" {
  region     = "eu-west-1"
  access_key = data.external.env.result.AWS_ACCESS_KEY
  secret_key = data.external.env.result.AWS_SECRET_KEY
}
