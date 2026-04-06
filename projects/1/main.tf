# ============================================================
# S3 BUCKET - Stores the website files
# ============================================================

resource "aws_s3_bucket" "website" {
  # The bucket name must be globally unique within AWS
  bucket = "${var.project_name}-site-${random_id.suffix.hex}"

  tags = {
    Name        = "${var.project_name}-site"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# A random ID to ensure that the bucket name is unique
resource "random_id" "suffix" {
  byte_length = 4
}

# Block all direct public access to the bucket
# Access to the site will always go via CloudFront; it will never go directly to S3
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable bucket versioning (best practice)
# It allows you to restore previous versions of your files
resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ============================================================
# CLOUDFRONT – A CDN that delivers your website globally
# ============================================================

# Origin Access Control: allows CloudFront to read the S3 bucket
# without making it public
resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${var.project_name}-oac"
  description                       = "OAC para el website"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "Distribución CloudFront para ${var.project_name}"

  # Source: the S3 bucket containing the files
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.website.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  # Default cache behaviour
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.website.id}"
    viewer_protocol_policy = "redirect-to-https" # HTTP always redirects to HTTPS

    # AWS-managed cache policy (optimised for S3)
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  # Customised error pages
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  # Geographical restrictions (none; available worldwide)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # CloudFront's default SSL certificate
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # PriceClass_100 = US, Europe, Asia; cheapest option
  price_class = "PriceClass_100"

  tags = {
    Name        = "${var.project_name}-distribution"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# S3 BUCKET POLICY
# Allow ONLY CloudFront to access the bucket
# ============================================================

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website.json

  # Wait for the public access block to be configured
  depends_on = [aws_s3_bucket_public_access_block.website]
}

data "aws_iam_policy_document" "website" {
  statement {
    sid    = "AllowCloudFrontAccess"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.website.arn]
    }
  }
}

# ============================================================
# Upload website files to S3
# ============================================================

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  source       = "${path.module}/website/index.html"
  content_type = "text/html"

  # It detects changes to the file and updates it automatically
  etag = filemd5("${path.module}/website/index.html")
}
