# ============================================================
# S3 BUCKET ; Stores the static website files
# ============================================================

resource "aws_s3_bucket" "website" {
  # Bucket names must be globally unique across all AWS accounts and regions.
  # The random suffix ensures no name collision when multiple people deploy this project.
  bucket = "${var.project_name}-site-${random_id.suffix.hex}"

  tags = {
    Name        = "${var.project_name}-site"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Generates a random 4-byte hex string (e.g. "a1b2c3d4") appended to the bucket name
# to guarantee global uniqueness without any manual configuration
resource "random_id" "suffix" {
  byte_length = 4
}

# Blocks all forms of public access to the bucket at the account level.
# This is a security best practice ; users will never access S3 directly.
# All traffic must go through CloudFront, which enforces HTTPS and caching.
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true # Reject any request that includes a public ACL
  block_public_policy     = true # Reject any bucket policy that grants public access
  ignore_public_acls      = true # Ignore any existing public ACLs on objects
  restrict_public_buckets = true # Block cross-account access to publicly accessible buckets
}

# Enables versioning on the bucket ; every time a file is overwritten,
# the previous version is retained and can be restored if needed.
# This protects against accidental deletions or bad deployments.
resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ============================================================
# CLOUDFRONT ; Global CDN that delivers the website to users
# ============================================================

# Origin Access Control (OAC) is the mechanism that allows CloudFront
# to authenticate itself when reading objects from the private S3 bucket.
# It replaces the older Origin Access Identity (OAI) and is the current
# AWS-recommended approach. Without this, CloudFront cannot read the bucket.
resource "aws_cloudfront_origin_access_control" "website" {
  name        = "${var.project_name}-oac"
  description = "OAC for ${var.project_name} website"

  origin_access_control_origin_type = "s3"      # The origin is an S3 bucket
  signing_behavior                  = "always"   # Always sign requests to S3
  signing_protocol                  = "sigv4"    # Use AWS Signature Version 4
}

# The CloudFront distribution is the CDN configuration that defines:
# - where the content comes from (S3 origin)
# - how it is cached and served (cache behavior)
# - what happens on errors (custom error responses)
# - who can access it (geo restrictions, SSL)
resource "aws_cloudfront_distribution" "website" {
  enabled             = true         # Distribution is active immediately after creation
  is_ipv6_enabled     = true         # Support IPv6 requests
  default_root_object = "index.html" # Serve index.html when the root URL is requested

  # The origin defines where CloudFront fetches content from.
  # We point it to the S3 bucket's regional domain to avoid redirect issues.
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.website.id}" # Unique ID referenced by cache behaviors
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  # The default cache behavior defines how CloudFront handles requests.
  # We only allow GET and HEAD since this is a read-only static website.
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.website.id}"
    viewer_protocol_policy = "redirect-to-https" # Automatically upgrade HTTP to HTTPS

    # This is the AWS-managed "CachingOptimized" policy, designed for S3 origins.
    # It caches based on the query string and compresses responses automatically.
    # Policy ID: 658327ea-f89d-4fab-a63d-7e88639e58f6
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  # When S3 returns a 403 (object not found or access denied),
  # redirect to index.html with a 200 ; useful for single-page applications.
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  # When S3 returns a 404 (object does not exist),
  # redirect to index.html with a 200 ; same reason as above.
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  # No geographic restrictions ; the website is accessible worldwide
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Uses CloudFront's shared SSL certificate (*.cloudfront.net).
  # No custom domain or ACM certificate is needed for this project.
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # PriceClass_100 covers edge locations in the US, Europe and Asia.
  # It is the most cost-effective option and covers the majority of users.
  # PriceClass_200 adds more regions; PriceClass_All covers every edge location.
  price_class = "PriceClass_100"

  tags = {
    Name        = "${var.project_name}-distribution"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# S3 BUCKET POLICY ; Grants CloudFront access to the bucket
# ============================================================

# Attaches the policy document below to the bucket.
# The depends_on ensures the public access block is applied first ;
# without it, applying the policy could fail due to a race condition.
resource "aws_s3_bucket_policy" "website" {
  bucket     = aws_s3_bucket.website.id
  policy     = data.aws_iam_policy_document.website.json
  depends_on = [aws_s3_bucket_public_access_block.website]
}

# Defines the IAM policy that allows ONLY this specific CloudFront distribution
# to call s3:GetObject on any object in the bucket.
# The condition on AWS:SourceArn scopes the permission to this distribution only ;
# no other CloudFront distribution can access this bucket.
data "aws_iam_policy_document" "website" {
  statement {
    sid    = "AllowCloudFrontAccess"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"] # All objects inside the bucket

    # This condition is what makes OAC secure ; it restricts access
    # to requests that originate specifically from this distribution's ARN
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.website.arn]
    }
  }
}

# ============================================================
# S3 OBJECT ; Uploads the website file to the bucket
# ============================================================

# Uploads index.html from the local filesystem to S3.
# The etag uses an MD5 hash of the file ; if the file changes,
# Terraform detects the new hash and re-uploads the file automatically.
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"                        # Path in S3 where the file will be stored
  source       = "${path.module}/website/index.html" # Path relative to this Terraform module
  content_type = "text/html"                         # Tells browsers how to interpret the file
  etag         = filemd5("${path.module}/website/index.html")
}
