# Terraform AWS Provider v5.100 Documentation Overview

This document provides a structured overview of the official documentation for the Terraform AWS Provider version 5.100.

## Table of Contents
1. [Introduction](#introduction)
2. [Documentation Structure](#documentation-structure)
   - [Actions](#actions)
   - [Data Sources (d/)](#data-sources)
   - [Guides & Resources](#guides--resources)
3. [API Reference Summary](#api-reference-summary)

## Introduction
This repository contains the generated documentation for the AWS Provider, detailing resources, data sources, and actions available for managing AWS infrastructure via Terraform.

## Documentation Structure

### Actions
The `actions/` directory contains documentation for specific API operations and tasks that trigger processes within AWS services.
* **CloudFront**: `cloudfront_create_inorganism_invalidation`
* **CodeBuild**: `codebuild_start_build`
* **DynamoDB**: `dynamodb_create_backup`
* **EC2**: `ec2_stop_instance`
* **Lambda**: `lambda_invoke`
* **SNS**: `sns_publish`
* *(And other service-specific actions...)*

### Data Sources (`d/`)
The `d/` directory contains the documentation for all available Data Sources. These are used to fetch information from existing AWS resources.
* **Account Information**: `account_regions`, `account_primary_contact`
* **ACM (AWS Certificate Manager)**: `acm_certificate`, `acmpca_certificate_authority`
* **API Gateway**: `api_gateway_rest_api`, `api_gateway_api_key`, `api_gateway_vpc_link`
* **AppConfig**: `appconfig_application`, `appconfig_environment`
* **AppMesh**: `appmesh_mesh`, `appmesh_virtual_node`, `appmesh_virtual_service`
* **EC2**: `ami`, `ami_ids`
* *(Extensive list of AWS services...)*

### Guides & Resources
* **Guides**: Detailed tutorials and best practices for using the provider.
* **List Resources**: Comprehensive lists of supported AWS resources.
* **Ephemeral Resources**: Documentation regarding short-lived or temporary infrastructure components.

## API Reference Summary
Each `.html.markdown` file in the directory contains the specific schema, required arguments, and optional attributes for the corresponding Terraform resource or data source.

---
*Note: This is an automated index of the documentation directory.*