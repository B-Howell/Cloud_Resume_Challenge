variable "table_name" {
  default     = "visitor_count"
  description = "name of the dynamodb table"
}

variable "hash_key" {
  default = "id"
  description = "pk for thr dynamodb table"
}

variable "api_name" {
  default = "brettmhowell"
}