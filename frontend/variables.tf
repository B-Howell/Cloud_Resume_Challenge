variable "domain_name" {
  default = "brettmhowell.com"
}

variable "bucket_name" {
  default = "index.brettmhowell.com"
}

variable "a_records" {
  type = map(object({
    type = string
    name = string
  }))
  default = {
    a1 = {
      type = "A"
      name = "brettmhowell.com"
    }
    a2 = {
      type = "A"
      name = "www.brettmhowell.com"
    }
  }
}

variable "acm_certificate_domain" {
  default     = "bhowellresume.com"
  description = "Domain of the ACM certificate"
}

variable "cloudfront_aliases" {
  default = ["brettmhowell.com", "www.brettmhowell.com"]
  description = "the cnames that your acm certificate is attached to"
}

variable "objects" {
  type = map(object({
    path         = string
    content_type = string
  }))
  default = {
    "index.html" = {
      path         = "resume_s3_bucket/index.html"
      content_type = "text/html"
    }
    "error.html" = {
      path         = "resume_s3_bucket/error.html"
      content_type = "text/html"
    }
    "resume_photo.jpg" = {
      path         = "resume_s3_bucket/resume_photo.jpg"
      content_type = "image/jpeg"
    }
    "script.js" = {
      path         = "resume_s3_bucket/script.js"
      content_type = "application/javascript"
    }
    "style.css" = {
      path         = "resume_s3_bucket/style.css"
      content_type = "text/css"
    }
    "hangman.html" = {
      path         = "resume_s3_bucket/hangman.html"
      content_type = "text/html"
    }
    "hangman.css" = {
      path         = "resume_s3_bucket/hangman.css"
      content_type = "text/css"
    }
    "favicon.ico" = {
      path         = "resume_s3_bucket/favicon.ico"
      content_type = "image/x-icon"
    }
  }
}