terraform {
  required_providers {
    gandi = {
      source = "go-gandi/gandi"
      version = "2.3.0"
    }
    bunnynet = {
      source = "BunnyWay/bunnynet"
      version = "0.11.4"
    }
  }


  backend "remote" {
    organization = "gliwka"
    workspaces {
      name = "infrastructure"
    }
  }
}

provider "gandi" {}